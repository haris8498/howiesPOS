import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/security/local_credential_verifier.dart';
import 'package:hungry_howies_pos/core/security/offline_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineCredentialStore (SEC-05, SEC-07, SEC-11)', () {
    late OfflineCredentialStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = OfflineCredentialStore();
    });

    test('saveCredential and getCredential retrieve offline credentials correctly', () async {
      final cred = OfflineCredential(
        userId: 'usr-1',
        username: 'alice',
        role: 'cashier',
        saltHex: '0102030405060708090a0b0c0d0e0f10',
        verifierHex: 'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
        params: const VerifierParams(algorithm: 'argon2id', memory: 19456, iterations: 2),
        lastOnlineLoginAt: DateTime.now(),
      );

      await store.saveCredential(cred);

      // Lookup by username
      final byUsername = await store.getCredential('alice');
      expect(byUsername, isNotNull);
      expect(byUsername!.userId, 'usr-1');
      expect(byUsername.role, 'cashier');
      expect(byUsername.saltHex, cred.saltHex);
      expect(byUsername.verifierHex, cred.verifierHex);

      // Case insensitive username lookup
      final byCase = await store.getCredential('ALICE');
      expect(byCase, isNotNull);
      expect(byCase!.userId, 'usr-1');

      // Lookup by userId
      final byId = await store.getCredential('usr-1');
      expect(byId, isNotNull);
      expect(byId!.username, 'alice');
    });

    test('getAllCredentials returns all unique cached users', () async {
      final cred1 = OfflineCredential(
        userId: 'usr-1',
        username: 'alice',
        role: 'cashier',
        saltHex: '01',
        verifierHex: 'aa',
        params: const VerifierParams(),
        lastOnlineLoginAt: DateTime.now(),
      );
      final cred2 = OfflineCredential(
        userId: 'usr-2',
        username: 'bob',
        role: 'manager',
        saltHex: '02',
        verifierHex: 'bb',
        params: const VerifierParams(),
        lastOnlineLoginAt: DateTime.now(),
      );

      await store.saveCredential(cred1);
      await store.saveCredential(cred2);

      final all = await store.getAllCredentials();
      expect(all.length, 2);
      expect(all.map((c) => c.username).toSet(), containsAll(['alice', 'bob']));
    });

    test('removeCredential revokes offline access for specific user', () async {
      final cred1 = OfflineCredential(
        userId: 'usr-1',
        username: 'alice',
        role: 'cashier',
        saltHex: '01',
        verifierHex: 'aa',
        params: const VerifierParams(),
        lastOnlineLoginAt: DateTime.now(),
      );
      final cred2 = OfflineCredential(
        userId: 'usr-2',
        username: 'bob',
        role: 'manager',
        saltHex: '02',
        verifierHex: 'bb',
        params: const VerifierParams(),
        lastOnlineLoginAt: DateTime.now(),
      );

      await store.saveCredential(cred1);
      await store.saveCredential(cred2);

      // Revoke usr-1
      await store.removeCredential('usr-1');

      expect(await store.getCredential('alice'), isNull);
      expect(await store.getCredential('usr-1'), isNull);
      expect(await store.getCredential('bob'), isNotNull);
    });

    test('wipeAll purges entire credential cache', () async {
      final cred = OfflineCredential(
        userId: 'usr-1',
        username: 'alice',
        role: 'cashier',
        saltHex: '01',
        verifierHex: 'aa',
        params: const VerifierParams(),
        lastOnlineLoginAt: DateTime.now(),
      );

      await store.saveCredential(cred);
      expect(await store.getCredential('alice'), isNotNull);

      await store.wipeAll();
      expect(await store.getCredential('alice'), isNull);
      expect(await store.getAllCredentials(), isEmpty);
    });

    test('purgeLegacyCache removes un-slowed legacy SHA-256 and custom user keys from storage', () async {
      SharedPreferences.setMockInitialValues({
        'auth_pwd_hash_owner': 'legacy_sha256_hex_hash_value',
        'auth_salt_owner': 'legacy_salt_value',
        'auth_pwd_hash_cashier': 'legacy_sha256_hex_hash_2',
        'auth_custom_staff_users_v1': '["legacy_user_json"]',
        'auth_deleted_staff_users_v1': '["legacy_deleted_user"]',
        'unrelated_app_setting': 'active_store_theme',
      });

      expect(await store.hasLegacyCacheKeys(), isTrue);

      await store.purgeLegacyCache();

      expect(await store.hasLegacyCacheKeys(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('auth_pwd_hash_owner'), isFalse);
      expect(prefs.containsKey('auth_salt_owner'), isFalse);
      expect(prefs.containsKey('auth_custom_staff_users_v1'), isFalse);
      expect(prefs.containsKey('unrelated_app_setting'), isTrue);
    });
  });
}
