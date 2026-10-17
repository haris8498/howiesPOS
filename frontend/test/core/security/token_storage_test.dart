import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/security/token_storage.dart';
import 'package:hungry_howies_pos/domain/models/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TokenStorage.resetCacheForTesting();
  });

  group('TokenStorage DPAPI Security Tests (§16.3)', () {
    test('1. saveToken encrypts token with DPAPI and caches in memory', () async {
      SharedPreferences.setMockInitialValues({});

      const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-payload-12345';
      await TokenStorage.saveToken(testToken);

      // Verify in-memory synchronous cache
      expect(TokenStorage.cachedToken, equals(testToken));

      // Verify token retrieved via getToken
      final retrieved = await TokenStorage.getToken();
      expect(retrieved, equals(testToken));

      // Verify data on disk in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final diskValue = prefs.getString('enc_dpapi_jwt_token');
      expect(diskValue, isNotNull);
      expect(diskValue!.isNotEmpty, isTrue);

      if (Platform.isWindows) {
        // Must be DPAPI ciphertext (base64 blob, not plaintext)
        expect(diskValue, isNot(equals(testToken)));
      }

      // Legacy plaintext key must not exist
      expect(prefs.containsKey('auth_jwt_token'), isFalse);
    });

    test('2. saveUserSession encrypts all user credentials at rest', () async {
      SharedPreferences.setMockInitialValues({});

      await TokenStorage.saveUserSession(
        token: 'secret-token-abc',
        userId: 'usr-uuid-777',
        username: 'StoreManager1',
        email: 'manager@hungryhowies.com',
        role: 'manager',
        isDefault: false,
      );

      final session = await TokenStorage.getUserSession();
      expect(session, isNotNull);
      expect(session!['token'], equals('secret-token-abc'));
      expect(session['userId'], equals('usr-uuid-777'));
      expect(session['username'], equals('StoreManager1'));
      expect(session['email'], equals('manager@hungryhowies.com'));
      expect(session['role'], equals(UserRole.manager));
      expect(session['isDefault'], isFalse);

      final prefs = await SharedPreferences.getInstance();
      if (Platform.isWindows) {
        expect(prefs.getString('enc_dpapi_jwt_token'), isNot(equals('secret-token-abc')));
        expect(prefs.getString('enc_dpapi_user_id'), isNot(equals('usr-uuid-777')));
        expect(prefs.getString('enc_dpapi_user_name'), isNot(equals('StoreManager1')));
      }

      // Verify zero legacy plaintext keys remain
      final hasLegacy = await TokenStorage.hasLegacyPlaintextKeysForTesting();
      expect(hasLegacy, isFalse);
    });

    test('3. Transparent first-run migration: reads legacy plaintext, encrypts, and purges plaintext', () async {
      // Simulate existing installation with pre-existing plaintext keys
      SharedPreferences.setMockInitialValues({
        'auth_jwt_token': 'legacy-plain-jwt-token-999',
        'auth_user_id': 'usr-legacy-id-1',
        'auth_user_name': 'Noman',
        'auth_user_email': 'noman@hungryhowies.com',
        'auth_user_role': 'owner',
        'auth_user_is_default': true,
      });

      // Reset in-memory cache to force reading from disk
      TokenStorage.resetCacheForTesting();

      final prefsBefore = await SharedPreferences.getInstance();
      expect(prefsBefore.containsKey('auth_jwt_token'), isTrue);
      expect(prefsBefore.containsKey('enc_dpapi_jwt_token'), isFalse);

      // Trigger retrieval - triggers transparent migration
      final session = await TokenStorage.getUserSession();
      expect(session, isNotNull);
      expect(session!['token'], equals('legacy-plain-jwt-token-999'));
      expect(session['userId'], equals('usr-legacy-id-1'));
      expect(session['username'], equals('Noman'));
      expect(session['email'], equals('noman@hungryhowies.com'));
      expect(session['role'], equals(UserRole.owner));
      expect(session['isDefault'], isTrue);

      // Verify all legacy plaintext keys were purged from disk
      final hasLegacyAfter = await TokenStorage.hasLegacyPlaintextKeysForTesting();
      expect(hasLegacyAfter, isFalse);
      expect(prefsBefore.containsKey('auth_jwt_token'), isFalse);
      expect(prefsBefore.containsKey('auth_user_id'), isFalse);
      expect(prefsBefore.containsKey('auth_user_name'), isFalse);

      // Verify new encrypted key exists
      expect(prefsBefore.containsKey('enc_dpapi_jwt_token'), isTrue);
      if (Platform.isWindows) {
        expect(prefsBefore.getString('enc_dpapi_jwt_token'), isNot(equals('legacy-plain-jwt-token-999')));
      }

      // Subsequent read works seamlessly from encrypted keys
      TokenStorage.resetCacheForTesting();
      final session2 = await TokenStorage.getUserSession();
      expect(session2!['token'], equals('legacy-plain-jwt-token-999'));
      expect(session2['username'], equals('Noman'));
    });

    test('4. clearSession wipes memory cache and both encrypted and legacy keys', () async {
      SharedPreferences.setMockInitialValues({
        'enc_dpapi_jwt_token': 'some-ciphertext',
        'enc_dpapi_user_id': 'some-id',
        'auth_jwt_token': 'lingering-legacy-token',
      });

      await TokenStorage.clearSession();

      expect(TokenStorage.cachedToken, isNull);
      final session = await TokenStorage.getUserSession();
      expect(session, isNull);

      final token = await TokenStorage.getToken();
      expect(token, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('enc_dpapi_jwt_token'), isFalse);
      expect(prefs.containsKey('auth_jwt_token'), isFalse);
    });

    test('5. Sync engine resume flow from AUTH_PAUSED with updated token', () async {
      SharedPreferences.setMockInitialValues({});
      TokenStorage.resetCacheForTesting();

      // Initial state: old expired token
      await TokenStorage.saveToken('expired-token-111');
      expect(await TokenStorage.getToken(), equals('expired-token-111'));

      // Re-authentication occurs (cashier logs in after 401 pause)
      const refreshedToken = 'refreshed-fresh-jwt-token-222';
      await TokenStorage.saveUserSession(
        token: refreshedToken,
        userId: 'cashier-1',
        username: 'cashier1',
        email: 'cashier1@hungryhowies.com',
        role: 'cashier',
      );

      // Sync engine accesses token synchronously and asynchronously
      expect(TokenStorage.cachedToken, equals(refreshedToken));
      expect(await TokenStorage.getToken(), equals(refreshedToken));
    });
  });
}
