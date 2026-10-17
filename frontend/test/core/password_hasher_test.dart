import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/security/password_hasher.dart';

void main() {
  group('PasswordHasher Security Tests', () {
    test('hashes password consistently with given salt', () {
      final hash1 = PasswordHasher.hashPassword('secret123', salt: 'test_salt_1');
      final hash2 = PasswordHasher.hashPassword('secret123', salt: 'test_salt_1');
      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);
      expect(hash1, isNot(contains('secret123'))); // Plaintext must not be visible
    });

    test('different salts produce distinct hashes for same password', () {
      final hash1 = PasswordHasher.hashPassword('secret123', salt: 'salt_a');
      final hash2 = PasswordHasher.hashPassword('secret123', salt: 'salt_b');
      expect(hash1, isNot(equals(hash2)));
    });

    test('verifies correct password against hash', () {
      final hash = PasswordHasher.hashPassword('ownerPass99', salt: 'owner_salt');
      expect(PasswordHasher.verifyPassword('ownerPass99', hash, salt: 'owner_salt'), isTrue);
      expect(PasswordHasher.verifyPassword('wrongPass', hash, salt: 'owner_salt'), isFalse);
      expect(PasswordHasher.verifyPassword('admin', hash, salt: 'owner_salt'), isFalse); // No backdoor
      expect(PasswordHasher.verifyPassword('123456', hash, salt: 'owner_salt'), isFalse); // No backdoor
    });
  });
}
