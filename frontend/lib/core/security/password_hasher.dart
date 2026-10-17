import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic password hashing and verification utility for local authentication.
/// Uses SHA-256 with cryptographic salt to ensure zero plaintext credential storage.
class PasswordHasher {
  PasswordHasher._();

  /// Default static salt for local demo seed credentials
  static const String _defaultPepper = 'hungry_howies_pos_pepper_2026';

  /// Hash a plaintext password with a salt using SHA-256
  static String hashPassword(String password, {String? salt}) {
    final effectiveSalt = salt ?? _defaultPepper;
    final bytes = utf8.encode('$effectiveSalt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a candidate password against a stored password hash
  static bool verifyPassword(String candidatePassword, String storedHash, {String? salt}) {
    final candidateHash = hashPassword(candidatePassword, salt: salt);
    return candidateHash == storedHash;
  }
}
