import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_health_provider.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('SYNC-019: Sync Health Status During Auth Pause Tests', () {
    late AppDatabase db;
    late ConnectivityNotifier connectivityNotifier;
    late SyncBackgroundWorker worker;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      connectivityNotifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        probeTimeout: const Duration(milliseconds: 100),
        initialState: const ConnectivityState(status: ConnectivityStatus.online),
      );
      worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
      );
      await worker.start();
    });

    tearDown(() async {
      worker.stop();
      connectivityNotifier.dispose();
      await db.close();
    });

    test('watchActiveOutboxEntries includes authPaused rows', () async {
      final opId = uuid.v7();
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-100"}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.authPaused),
        ),
      );

      final activeEntries = await db.outboxDao.watchActiveOutboxEntries().first;
      expect(activeEntries.any((e) => e.operationId == opId), isTrue);
    });

    test('rawSyncHealthProvider returns Red when authPaused entries exist', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncBackgroundWorkerProvider.overrideWithValue(worker),
          connectivityNotifierProvider.overrideWith((ref) => connectivityNotifier),
          activeOutboxEntriesProvider.overrideWith((ref) => Stream.value([
            SyncOutboxEntry(
              id: 1,
              operationId: uuid.v7(),
              deviceId: 'POS-01',
              entityType: 'order',
              entityId: uuid.v7(),
              operationType: 'INSERT',
              payload: '{}',
              dependencyOrder: 1,
              baseVersion: 1,
              status: SyncOutboxStatus.authPaused,
              retryCount: 0,
              createdAt: DateTime.now(),
              schemaVersion: 1,
            ),
          ])),
        ],
      );

      await container.read(activeOutboxEntriesProvider.future);
      final health = container.read(rawSyncHealthProvider);
      expect(health.status, equals(SyncHealthStatus.red));
      expect(health.tooltipText, contains('Auth paused'));
      expect(health.isRed, isTrue);

      container.dispose();
    });

    test('rawSyncHealthProvider returns Red when worker isAuthPaused is true', () async {
      worker.stateNotifier.updateState(worker.state.copyWith(isAuthPaused: true));

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncBackgroundWorkerProvider.overrideWithValue(worker),
          connectivityNotifierProvider.overrideWith((ref) => connectivityNotifier),
          activeOutboxEntriesProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await container.read(activeOutboxEntriesProvider.future);
      final health = container.read(rawSyncHealthProvider);
      expect(health.status, equals(SyncHealthStatus.red));
      expect(health.tooltipText, contains('Auth paused'));
      expect(health.isRed, isTrue);

      container.dispose();
    });
  });
}
