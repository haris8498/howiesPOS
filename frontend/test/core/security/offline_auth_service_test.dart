import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/security/local_credential_verifier.dart';
import 'package:hungry_howies_pos/core/security/offline_auth_service.dart';
import 'package:hungry_howies_pos/core/security/offline_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineAuthService (SEC-05, SEC-07, SEC-11)', () {
    late OfflineCredentialStore store;
    late OfflineAuthService authService;

    // Fast Argon2 parameters for snappy test execution
    const testParams = VerifierParams(
      algorithm: VerifierParams.algoArgon2id,
      memory: 1024, // 1 MiB
      iterations: 1,
      parallelism: 1,
      hashLength: 32,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = OfflineCredentialStore();
      authService = OfflineAuthService(
        store: store,
        maxOfflineDuration: const Duration(days: 14),
        maxFailedAttemptsBeforeLockout: 5,
        baseLockoutDuration: const Duration(seconds: 30),
      );
    });

    test('cacheOnlineLogin caches credentials and authenticateOffline validates password', () async {
      await authService.cacheOnlineLogin(
        userId: 'usr-101',
        username: 'cashier1',
        role: 'cashier',
        password: 'ValidPassword123!',
        params: testParams,
      );

      // Successful offline login
      final resultSuccess = await authService.authenticateOffline('cashier1', 'ValidPassword123!');
      expect(resultSuccess.isSuccess, isTrue);
      expect(resultSuccess.status, OfflineAuthStatus.success);
      expect(resultSuccess.credential!.userId, 'usr-101');
      expect(resultSuccess.credential!.role, 'cashier');

      // Failed offline login with wrong password
      final resultFail = await authService.authenticateOffline('cashier1', 'WrongPassword!');
      expect(resultFail.isSuccess, isFalse);
      expect(resultFail.status, OfflineAuthStatus.invalidCredentials);

      // Unknown user offline login
      final resultUnknown = await authService.authenticateOffline('unknownuser', 'any');
      expect(resultUnknown.isSuccess, isFalse);
      expect(resultUnknown.status, OfflineAuthStatus.userNotFound);
    });

    test('lockout with exponential backoff triggers after 5 consecutive failures', () async {
      await authService.cacheOnlineLogin(
        userId: 'usr-102',
        username: 'cashier2',
        role: 'cashier',
        password: 'CorrectPass!',
        params: testParams,
      );

      // Attempts 1 to 4 should fail without lockout
      for (int i = 1; i <= 4; i++) {
        final res = await authService.authenticateOffline('cashier2', 'BadPassword');
        expect(res.status, OfflineAuthStatus.invalidCredentials, reason: 'Attempt $i');
        expect(authService.getFailedAttempts('cashier2'), i);
      }

      // 5th attempt triggers lockout
      final res5 = await authService.authenticateOffline('cashier2', 'BadPassword');
      expect(res5.status, OfflineAuthStatus.lockedOut);
      expect(res5.lockoutSecondsRemaining, greaterThan(0));
      expect(res5.errorMessage, contains('locked'));

      // Immediate attempt during lockout is rejected without derivation
      final lockedAttempt = await authService.authenticateOffline('cashier2', 'CorrectPass!');
      expect(lockedAttempt.status, OfflineAuthStatus.lockedOut);
    });

    test('cache expiry rejects offline login when last online login exceeds max duration', () async {
      // Simulate credential cached 15 days ago (max is 14 days)
      final expiredDate = DateTime.now().subtract(const Duration(days: 15));
      final saltBytes = LocalCredentialVerifier.generateRandomSalt(16);
      final verifierBytes = await LocalCredentialVerifier.deriveVerifier(
        password: 'MyPassword!',
        salt: saltBytes,
        params: testParams,
      );

      final cred = OfflineCredential(
        userId: 'usr-exp',
        username: 'expcashier',
        role: 'cashier',
        saltHex: LocalCredentialVerifier.bytesToHex(saltBytes),
        verifierHex: LocalCredentialVerifier.bytesToHex(verifierBytes),
        params: testParams,
        lastOnlineLoginAt: expiredDate,
      );
      await store.saveCredential(cred);

      final res = await authService.authenticateOffline('expcashier', 'MyPassword!');
      expect(res.isSuccess, isFalse);
      expect(res.status, OfflineAuthStatus.expired);
      expect(res.errorMessage, contains('expired'));
      expect(res.errorMessage, contains('14 days'));
    });

    group('verifyManagerCredential (reused by D-03)', () {
      test('successfully verifies manager and owner credentials', () async {
        // Cache manager
        await authService.cacheOnlineLogin(
          userId: 'mgr-1',
          username: 'storemanager',
          role: 'manager',
          password: 'ManagerPin1234',
          params: testParams,
        );

        // Cache owner
        await authService.cacheOnlineLogin(
          userId: 'owner-1',
          username: 'superowner',
          role: 'owner',
          password: 'OwnerPin9999',
          params: testParams,
        );

        final mgrResult = await authService.verifyManagerCredential('storemanager', 'ManagerPin1234');
        expect(mgrResult.isSuccess, isTrue);
        expect(mgrResult.credential!.role, 'manager');

        final ownerResult = await authService.verifyManagerCredential('superowner', 'OwnerPin9999');
        expect(ownerResult.isSuccess, isTrue);
        expect(ownerResult.credential!.role, 'owner');
      });

      test('rejects non-manager (cashier) users from supervisor approval', () async {
        await authService.cacheOnlineLogin(
          userId: 'csh-1',
          username: 'regularcashier',
          role: 'cashier',
          password: 'CashierPass!',
          params: testParams,
        );

        final result = await authService.verifyManagerCredential('regularcashier', 'CashierPass!');
        expect(result.isSuccess, isFalse);
        expect(result.status, OfflineAuthStatus.unauthorizedRole);
        expect(result.errorMessage, contains('not authorized'));
      });

      test('rejects incorrect PIN or password for manager', () async {
        await authService.cacheOnlineLogin(
          userId: 'mgr-2',
          username: 'shiftmanager',
          role: 'manager',
          password: 'CorrectPin5555',
          params: testParams,
        );

        final result = await authService.verifyManagerCredential('shiftmanager', 'WrongPin');
        expect(result.isSuccess, isFalse);
        expect(result.status, OfflineAuthStatus.invalidCredentials);
      });
    });

    test('revokeUser removes user offline access immediately', () async {
      await authService.cacheOnlineLogin(
        userId: 'usr-del',
        username: 'firedstaff',
        role: 'cashier',
        password: 'Pass!',
        params: testParams,
      );

      expect((await authService.authenticateOffline('firedstaff', 'Pass!')).isSuccess, isTrue);

      await authService.revokeUser('usr-del');

      final resAfter = await authService.authenticateOffline('firedstaff', 'Pass!');
      expect(resAfter.status, OfflineAuthStatus.userNotFound);
    });
  });
}
