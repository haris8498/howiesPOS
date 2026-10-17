import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/security/windows_dpapi.dart';

void main() {
  group('WindowsDpapi Tests', () {
    test('protect and unprotect round trip with raw bytes', () {
      if (!Platform.isWindows) {
        expect(
          () => WindowsDpapi.protect(Uint8List.fromList([1, 2, 3])),
          throwsUnsupportedError,
        );
        return;
      }

      final originalData = Uint8List.fromList([
        0x01, 0x02, 0x03, 0x04, 0x05, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF,
      ]);

      final protected = WindowsDpapi.protect(
        originalData,
        description: 'Test DPAPI Roundtrip',
      );

      expect(protected.isNotEmpty, isTrue);
      expect(protected, isNot(equals(originalData)));

      final unprotected = WindowsDpapi.unprotect(protected);
      expect(unprotected, equals(originalData));
    });

    test('protectString and unprotectString round trip', () {
      if (!Platform.isWindows) {
        return;
      }

      const secretText = 'super-secret-jwt-token-or-db-passphrase-12345';
      final encryptedBase64 = WindowsDpapi.protectString(secretText);

      expect(encryptedBase64, isNotEmpty);
      expect(encryptedBase64, isNot(equals(secretText)));

      final decrypted = WindowsDpapi.unprotectString(encryptedBase64);
      expect(decrypted, equals(secretText));
    });

    test('handles empty data gracefully', () {
      if (!Platform.isWindows) return;

      final empty = Uint8List(0);
      final protected = WindowsDpapi.protect(empty);
      expect(protected, isEmpty);

      final unprotected = WindowsDpapi.unprotect(empty);
      expect(unprotected, isEmpty);
    });

    test('getOrCreateMasterKey generates on first run and retrieves on second run', () {
      if (!Platform.isWindows) return;

      final tempDir = Directory.systemTemp.createTempSync('dpapi_test_');
      final tempKeyPath = '${tempDir.path}${Platform.pathSeparator}test_db.key';

      try {
        final keyFile = File(tempKeyPath);
        expect(keyFile.existsSync(), isFalse);

        // 1st run: Generates key
        final key1 = WindowsDpapi.getOrCreateMasterKey(customKeyPath: tempKeyPath);
        expect(key1.length, equals(32));
        expect(keyFile.existsSync(), isTrue);

        // Verify key file contains DPAPI ciphertext (different from plaintext key1)
        final fileBytes = keyFile.readAsBytesSync();
        expect(fileBytes, isNot(equals(key1)));

        // 2nd run: Reads the existing key
        final key2 = WindowsDpapi.getOrCreateMasterKey(customKeyPath: tempKeyPath);
        expect(key2, equals(key1));

        // Hex derivation
        final hex = WindowsDpapi.getOrCreateSqlCipherKeyHex(customKeyPath: tempKeyPath);
        expect(hex.length, equals(64));
        expect(WindowsDpapi.hexToBytes(hex), equals(key1));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('zeroOut successfully overwrites memory', () {
      final sensitive = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      WindowsDpapi.zeroOut(sensitive);
      expect(sensitive, everyElement(equals(0)));
    });
  });
}
