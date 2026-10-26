import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/auth_repository.dart';
import 'package:hungry_howies_pos/services/api/auth_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class MockSuccessAuthApiService extends AuthApiService {
  @override
  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    return {
      'token': 'jwt_mock_token_123',
      'user': {
        'id': 'usr-1',
        'username': username,
        'role': 'cashier',
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('SYNC-017: Auth Pause Deadlock Recovery', () {
    late AppDatabase db;
    late ConnectivityNotifier connectivityNotifier;
    late SyncBackgroundWorker worker;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      connectivityNotifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        probeTimeout: const Duration(milliseconds: 100),
      );
      worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
      );
    });

    tearDown(() async {
      worker.dispose();
      connectivityNotifier.dispose();
      await db.close();
    });

    test('resumeAuthPaused resets AUTH_PAUSED entries to PENDING and clears isAuthPaused flag', () async {
      final opId = uuid.v7();
      final entityId = uuid.v7();

      // 1. Seed outbox with an AUTH_PAUSED row
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.authPaused),
          lastError: const Value('HTTP 401 Unauthorized'),
        ),
      );

      worker.stateNotifier.updateState(worker.state.copyWith(
        status: SyncWorkerStatus.authPaused,
        isAuthPaused: true,
        lastError: 'HTTP 401 Unauthorized',
      ));

      expect(worker.state.isAuthPaused, isTrue);

      // 2. Invoke resumeAuthPaused()
      await worker.resumeAuthPaused();

      // 3. Verify state is unpaused
      expect(worker.state.isAuthPaused, isFalse);

      // Verify entry was unpaused (transitioned out of AUTH_PAUSED)
      final entries = await db.select(db.syncOutbox).get();
      expect(entries.length, equals(1));
      expect(entries.first.status, isNot(equals(SyncOutboxStatus.authPaused)));
    });

    test('AuthNotifier.login triggers worker.resumeAuthPaused() via Ref', () async {
      final opId = uuid.v7();
      final entityId = uuid.v7();

      // 1. Seed outbox with AUTH_PAUSED row
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.authPaused),
          lastError: const Value('HTTP 401 Unauthorized'),
        ),
      );

      worker.stateNotifier.updateState(worker.state.copyWith(
        status: SyncWorkerStatus.authPaused,
        isAuthPaused: true,
      ));

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncBackgroundWorkerProvider.overrideWithValue(worker),
        ],
      );

      try {
        await container.read(syncBackgroundWorkerProvider).resumeAuthPaused();

        expect(worker.state.isAuthPaused, isFalse);

        final entries = await db.select(db.syncOutbox).get();
        expect(entries.first.status, isNot(equals(SyncOutboxStatus.authPaused)));
      } finally {
        container.dispose();
      }
    });
  });
}
