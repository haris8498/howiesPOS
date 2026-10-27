import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic parameters used for deriving local offline authentication verifiers.
class VerifierParams {
  static const String algoArgon2id = 'argon2id';
  static const String algoPbkdf2 = 'pbkdf2_hmac_sha256';

  final String algorithm;
  final int memory; // In KiB (for Argon2id)
  final int iterations; // Iterations (time cost)
  final int parallelism; // Parallelism lanes (for Argon2id)
  final int hashLength; // Derived key length in bytes

  const VerifierParams({
    this.algorithm = algoArgon2id,
    this.memory = 19456, // OWASP minimum: 19 MiB
    this.iterations = 2,
    this.parallelism = 1,
    this.hashLength = 32,
  });

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'memory': memory,
        'iterations': iterations,
        'parallelism': parallelism,
        'hashLength': hashLength,
      };

  factory VerifierParams.fromJson(Map<String, dynamic> json) => VerifierParams(
        algorithm: json['algorithm'] as String? ?? algoArgon2id,
        memory: json['memory'] as int? ?? 19456,
        iterations: json['iterations'] as int? ?? 2,
        parallelism: json['parallelism'] as int? ?? 1,
        hashLength: json['hashLength'] as int? ?? 32,
      );
}

/// Cryptographically secure key derivation and constant-time comparison for local offline credentials.
///
/// Implements SEC-05 / SEC-07 / SEC-11 client-side verifier derivation:
/// - Primary: Argon2id (OWASP minimum m=19456 KiB, t=2, p=1).
/// - Secondary / Fallback: PBKDF2-HMAC-SHA256 (>= 600,000 iterations per OWASP).
/// - Constant-time comparison to prevent side-channel timing leaks.
class LocalCredentialVerifier {
  /// Generates a cryptographically secure random salt of [length] bytes (default 16 bytes = 128 bits).
  static Uint8List generateRandomSalt([int length = 16]) {
    final random = Random.secure();
    final salt = Uint8List(length);
    for (int i = 0; i < length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Derives a local offline authentication verifier from [password] and [salt]
  /// using the specified [params].
  static Future<Uint8List> deriveVerifier({
    required String password,
    required Uint8List salt,
    VerifierParams params = const VerifierParams(),
  }) async {
    if (params.algorithm == VerifierParams.algoPbkdf2) {
      return derivePbkdf2(
        password: password,
        salt: salt,
        iterations: params.iterations >= 600000 ? params.iterations : 600000,
        hashLength: params.hashLength,
      );
    }

    return deriveArgon2id(
      password: password,
      salt: salt,
      memory: params.memory,
      iterations: params.iterations,
      parallelism: params.parallelism,
      hashLength: params.hashLength,
    );
  }

  /// Derives a 256-bit verifier using Argon2id via `package:cryptography`.
  ///
  /// Default parameters:
  /// - Memory: 19456 KiB (19 MiB)
  /// - Iterations (Time): 2
  /// - Parallelism: 1
  /// - Output length: 32 bytes (256 bits)
  ///
  /// Benchmark on POS hardware: ~1.0 - 1.1s execution time, memory-hard against GPU/ASIC cracking.
  static Future<Uint8List> deriveArgon2id({
    required String password,
    required Uint8List salt,
    int memory = 19456,
    int iterations = 2,
    int parallelism = 1,
    int hashLength = 32,
  }) async {
    final algorithm = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: hashLength,
    );
    final secretKey = SecretKey(utf8.encode(password));
    final derived = await algorithm.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Derives a 256-bit verifier using PBKDF2-HMAC-SHA256 via `package:cryptography`.
  ///
  /// Default iterations: 600,000 (OWASP recommended minimum for HMAC-SHA256).
  static Future<Uint8List> derivePbkdf2({
    required String password,
    required Uint8List salt,
    int iterations = 600000,
    int hashLength = 32,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: hashLength * 8,
    );
    final secretKey = SecretKey(utf8.encode(password));
    final derived = await algorithm.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Constant-time byte array comparison.
  ///
  /// Accumulates bitwise differences across all bytes to ensure identical
  /// execution time regardless of where any character discrepancy occurs.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Converts bytes to a lowercase hex string.
  static String bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Converts a hex string back to byte array.
  static Uint8List hexToBytes(String hex) {
    final clean = hex.trim();
    if (clean.length % 2 != 0) {
      throw ArgumentError('Hex string must have an even length');
    }
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
