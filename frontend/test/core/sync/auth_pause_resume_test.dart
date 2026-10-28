import 'dart:convert';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/security/token_storage.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/auth_repository.dart';
import 'package:hungry_howies_pos/services/api/api_providers.dart';
import 'package:hungry_howies_pos/services/api/auth_api_service.dart';
import 'package:hungry_howies_pos/services/api/staff_api_service.dart';
import 'package:hungry_howies_pos/services/api/users_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MockSuccessAuthApiService extends AuthApiService {
  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    const token = 'jwt_mock_token_123';
    await TokenStorage.saveUserSession(
      token: token,
      userId: 'usr-bob',
      username: username,
      email: '$username@hungryhowies.com',
      role: 'cashier',
    );
    return {
      'accessToken': token,
      'token': token,
      'user': {
        'id': 'usr-bob',
        'username': username,
        'role': 'cashier',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    return {
      'id': 'usr-bob',
      'username': 'bob',
      'role': 'cashier',
    };
  }
}

class MockUsersApiService extends UsersApiService {
  @override
  Future<List<Map<String, dynamic>>> listUsers() async => [];
}

class MockStaffApiService extends StaffApiService {
  @override
  Future<List<Map<String, dynamic>>> listStaff({
    String? search,
    String? role,
    String? status,
    bool? isSalaryPaid,
    String? monthYear,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('fix(#18): Offline Staff Synthetic Token & Online Re-Auth Sync Resume', () {
    late AppDatabase db;
    late ConnectivityNotifier connectivityNotifier;
    late SyncBackgroundWorker worker;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TokenStorage.resetCacheForTesting();
      db = AppDatabase(NativeDatabase.memory());
      connectivityNotifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        probeTimeout: const Duration(milliseconds: 100),
        initialState: const ConnectivityState(status: ConnectivityStatus.online),
      );

      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'results': [
              {'operation_id': 'op-1', 'status': 'SYNCED'}
            ]
          }),
          200,
        );
      });

      worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        httpClient: mockHttp,
        syncUrlOverride: 'http://localhost:3000/api',
      );
    });

    tearDown(() async {
      worker.dispose();
      connectivityNotifier.dispose();
      await db.close();
    });

    test('synthetic token puts the worker in the login-required state', () async {
      final opId = uuid.v7();
      final entityId = uuid.v7();

      // 1. Seed outbox with a pending order
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"101","cashier":"alice"}'),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // 2. Set synthetic offline token (issued after offline staff switch)
      await TokenStorage.saveUserSession(
        token: 'local_offline_token_alice',
        userId: 'usr_alice',
        username: 'alice',
        email: 'alice@hungryhowies.com',
        role: 'cashier',
      );

      // Verify worker is online
      expect(connectivityNotifier.isOnline, isTrue);

      // 3. Trigger worker sync cycle while online holding synthetic token
      await worker.triggerSyncCycle();

      // 4. Worker must move to login-required state (AUTH_PAUSED)
      expect(worker.state.isAuthPaused, isTrue);
      expect(worker.state.isLoginRequired, isTrue);
      expect(worker.state.status, equals(SyncWorkerStatus.authPaused));
      expect(worker.state.lastError, contains('Login required'));

      // 5. Outbox entries are transitioned to AUTH_PAUSED
      final entries = await db.select(db.syncOutbox).get();
      expect(entries.length, equals(1));
      expect(entries.first.status, equals(SyncOutboxStatus.authPaused));
    });

    test('a successful real login resumes it', () async {
      final opId = uuid.v7();
      final entityId = uuid.v7();

      // 1. Worker and outbox start in login-required / AUTH_PAUSED state with synthetic token
      await TokenStorage.saveUserSession(
        token: 'local_offline_token_alice',
        userId: 'usr_alice',
        username: 'alice',
        email: 'alice@hungryhowies.com',
        role: 'cashier',
      );

      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"101","cashier":"alice"}'),
          status: const Value(SyncOutboxStatus.authPaused),
          lastError: const Value('Login required to sync: terminal holding offline synthetic token'),
        ),
      );

      worker.stateNotifier.updateState(worker.state.copyWith(
        status: SyncWorkerStatus.authPaused,
        isAuthPaused: true,
        lastError: 'Login required to sync: terminal holding offline synthetic token',
      ));

      expect(worker.state.isAuthPaused, isTrue);
      expect(worker.state.isLoginRequired, isTrue);

      // 2. Setup Riverpod container with mocked online auth APIs
      final mockAuthApi = MockSuccessAuthApiService();
      final mockUsersApi = MockUsersApiService();
      final mockStaffApi = MockStaffApiService();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncBackgroundWorkerProvider.overrideWithValue(worker),
          authApiServiceProvider.overrideWithValue(mockAuthApi),
          usersApiServiceProvider.overrideWithValue(mockUsersApi),
          staffApiServiceProvider.overrideWithValue(mockStaffApi),
        ],
      );

      try {
        final authNotifier = container.read(authProvider.notifier);

        // 3. Any staff member performs a real online login
        final loginSuccess = await authNotifier.login('bob', 'realPassword123');
        expect(loginSuccess, isTrue);

        // 4. TokenStorage replaced synthetic token with real online JWT
        final storedToken = await TokenStorage.getToken();
        expect(storedToken, equals('jwt_mock_token_123'));
        expect(TokenStorage.isSyntheticToken(storedToken), isFalse);

        // 5. Worker is resumed (clear AUTH_PAUSED)
        expect(worker.state.isAuthPaused, isFalse);
        expect(worker.state.isLoginRequired, isFalse);
        expect(worker.state.status, isNot(equals(SyncWorkerStatus.authPaused)));

        // 6. Outbox entry was unpaused (no longer AUTH_PAUSED)
        final entries = await db.select(db.syncOutbox).get();
        expect(entries.length, equals(1));
        expect(entries.first.status, isNot(equals(SyncOutboxStatus.authPaused)));

        // 7. Orders keep their original staff data
        expect(entries.first.payload, contains('"cashier":"alice"'));
      } finally {
        container.dispose();
      }
    });
  });
}
