import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/security/local_credential_verifier.dart';

void main() {
  group('LocalCredentialVerifier (SEC-05, SEC-07, SEC-11)', () {
    test('generateRandomSalt generates cryptographically distinct salts', () {
      final salt1 = LocalCredentialVerifier.generateRandomSalt(16);
      final salt2 = LocalCredentialVerifier.generateRandomSalt(16);

      expect(salt1.length, 16);
      expect(salt2.length, 16);
      expect(salt1, isNot(equals(salt2)));
    });

    test('deriveArgon2id produces deterministic 32-byte verifier for identical inputs', () async {
      final salt = LocalCredentialVerifier.hexToBytes('0102030405060708090a0b0c0d0e0f10');
      const password = 'TestCashierPassword123!';

      final verifier1 = await LocalCredentialVerifier.deriveArgon2id(
        password: password,
        salt: salt,
        memory: 1024, // Fast params for unit test execution
        iterations: 1,
        parallelism: 1,
      );

      final verifier2 = await LocalCredentialVerifier.deriveArgon2id(
        password: password,
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      expect(verifier1.length, 32);
      expect(verifier2.length, 32);
      expect(verifier1, equals(verifier2));
    });

    test('deriveArgon2id produces different verifiers for different passwords or salts', () async {
      final salt1 = LocalCredentialVerifier.hexToBytes('0102030405060708090a0b0c0d0e0f10');
      final salt2 = LocalCredentialVerifier.hexToBytes('100e0d0c0b0a09080706050403020100');

      final v1 = await LocalCredentialVerifier.deriveArgon2id(
        password: 'PasswordA',
        salt: salt1,
        memory: 1024,
        iterations: 1,
      );
      final v2 = await LocalCredentialVerifier.deriveArgon2id(
        password: 'PasswordB',
        salt: salt1,
        memory: 1024,
        iterations: 1,
      );
      final v3 = await LocalCredentialVerifier.deriveArgon2id(
        password: 'PasswordA',
        salt: salt2,
        memory: 1024,
        iterations: 1,
      );

      expect(v1, isNot(equals(v2)));
      expect(v1, isNot(equals(v3)));
    });

    test('derivePbkdf2 produces valid derived key using HMAC-SHA256', () async {
      final salt = Uint8List.fromList(utf8.encode('salt_test_123456'));
      const password = 'Pbkdf2Password!';

      final verifier = await LocalCredentialVerifier.derivePbkdf2(
        password: password,
        salt: salt,
        iterations: 1000, // Reduced iterations for fast unit test
      );

      expect(verifier.length, 32);
    });

    test('constantTimeEquals detects equality and discrepancies with constant execution flow', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5]);
      final c = Uint8List.fromList([1, 2, 3, 4, 6]); // Diff at end
      final d = Uint8List.fromList([9, 2, 3, 4, 5]); // Diff at start
      final e = Uint8List.fromList([1, 2, 3, 4]); // Diff length

      expect(LocalCredentialVerifier.constantTimeEquals(a, b), isTrue);
      expect(LocalCredentialVerifier.constantTimeEquals(a, c), isFalse);
      expect(LocalCredentialVerifier.constantTimeEquals(a, d), isFalse);
      expect(LocalCredentialVerifier.constantTimeEquals(a, e), isFalse);
    });

    test('hex encoding and decoding roundtrips perfectly', () {
      final original = Uint8List.fromList([0, 15, 16, 255, 128, 42]);
      final hex = LocalCredentialVerifier.bytesToHex(original);
      expect(hex, '000f10ff802a');

      final decoded = LocalCredentialVerifier.hexToBytes(hex);
      expect(decoded, equals(original));
    });
  });
}
