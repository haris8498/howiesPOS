import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:hungry_howies_pos/config/feature_flags.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/outbox_drain_gate.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/repositories/api_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/order_repository_provider.dart';
import 'package:hungry_howies_pos/services/api/api_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase(NativeDatabase.memory());
    FeatureFlags.resetForTesting();
  });

  tearDown(() async {
    FeatureFlags.resetForTesting();
    await testDb.close();
  });

  Future<void> insertOutboxRow(
    AppDatabase db, {
    required String opId,
    required String entityId,
    String status = SyncOutboxStatus.pending,
    String? lastError,
  }) async {
    await db.into(db.syncOutbox).insert(
      SyncOutboxCompanion(
        operationId: Value(opId),
        deviceId: const Value('POS-P1'),
        entityType: const Value('order'),
        entityId: Value(entityId),
        operationType: const Value('INSERT'),
        payload: Value(jsonEncode({'order_id': entityId, 'amount': 100})),
        dependencyOrder: const Value(1),
        status: Value(status),
        lastError: Value(lastError),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  const uuid1 = '019283a0-0001-7000-8000-000000000001';
  const uuid2 = '019283a0-0001-7000-8000-000000000002';
  const uuid3 = '019283a0-0001-7000-8000-000000000003';
  const uuid4 = '019283a0-0001-7000-8000-000000000004';
  const uuid5 = '019283a0-0001-7000-8000-000000000005';
  const uuid6 = '019283a0-0001-7000-8000-000000000006';

  group('OutboxDrainGate: Outbox DAO Read Helpers (D-04)', () {
    test('getNonTerminalCount counts pending, failed-retryable, in-flight, auth-paused rows', () async {
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1, status: SyncOutboxStatus.pending);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2, status: SyncOutboxStatus.failedRetryable);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3, status: SyncOutboxStatus.inFlight);
      await insertOutboxRow(testDb, opId: uuid4, entityId: uuid4, status: SyncOutboxStatus.authPaused);
      await insertOutboxRow(testDb, opId: uuid5, entityId: uuid5, status: SyncOutboxStatus.synced);
      await insertOutboxRow(testDb, opId: uuid6, entityId: uuid6, status: SyncOutboxStatus.failedFatal);

      final count = await testDb.outboxDao.getNonTerminalCount();
      expect(count, equals(4), reason: 'Only non-terminal rows should be counted');
    });

    test('exportOutboxBackupJson produces valid JSON containing every pending and failed row', () async {
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1, status: SyncOutboxStatus.pending);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2, status: SyncOutboxStatus.failedRetryable);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3, status: SyncOutboxStatus.failedFatal, lastError: '400 Bad Request');

      final jsonStr = await testDb.outboxDao.exportOutboxBackupJson();
      expect(jsonStr, isNotEmpty);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded.containsKey('exportedAt'), isTrue);
      expect(decoded['pendingCount'], equals(2));
      expect(decoded['failedCount'], equals(1));
      expect(decoded['totalExported'], equals(3));

      final entries = decoded['entries'] as List<dynamic>;
      expect(entries.length, equals(3));
      final opIds = entries.map((e) => e['operationId']).toList();
      expect(opIds, containsAll([uuid1, uuid2, uuid3]));
    });
  });

  group('OutboxDrainGate: Routing Matrix Tests (Flag × Outbox × Network)', () {
    test('Routing Matrix 1: Flag=ON, Outbox=0, Network=Online -> Local-first route', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>());
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isFalse);
    });

    test('Routing Matrix 2: Flag=ON, Outbox=0, Network=Offline -> Local-first route', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
          connectivityNotifierProvider.overrideWith((ref) => ConnectivityNotifier(
            initialState: const ConnectivityState(status: ConnectivityStatus.offline),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>());
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isFalse);
    });

    test('Routing Matrix 3: Flag=ON, Outbox=3, Network=Online -> Local-first route', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>());
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isFalse, reason: 'Modal not needed when flag is ON');
    });

    test('Routing Matrix 4: Flag=ON, Outbox=3, Network=Offline -> Local-first route', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(true);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
          connectivityNotifierProvider.overrideWith((ref) => ConnectivityNotifier(
            initialState: const ConnectivityState(status: ConnectivityStatus.offline),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>());
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isFalse);
    });

    test('Routing Matrix 5: Flag=OFF, Outbox=0, Network=Online -> Online-only route, NO modal', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<ApiOrderRepository>(), reason: 'Flag is false and outbox empty -> 100% legacy online behavior');
      expect(gate.shouldUseLocalFirst, isFalse);
      expect(gate.shouldShowDrainModal, isFalse);
    });

    test('Routing Matrix 6: Flag=OFF, Outbox=0, Network=Offline -> Online-only route, NO modal', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
          connectivityNotifierProvider.overrideWith((ref) => ConnectivityNotifier(
            initialState: const ConnectivityState(status: ConnectivityStatus.offline),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<ApiOrderRepository>());
      expect(gate.shouldUseLocalFirst, isFalse);
      expect(gate.shouldShowDrainModal, isFalse);
    });

    test('Routing Matrix 7: Flag=OFF, Outbox=3, Network=Online -> Local-first route, MODAL shown', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>(),
          reason: 'Never switch routing silently with rows pending: local-first path remains active!');
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isTrue);
      expect(gate.nonTerminalCount, equals(3));
    });

    test('Routing Matrix 8: Flag=OFF, Outbox=3, Network=Offline -> Local-first route, MODAL shown, app keeps working locally', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
          connectivityNotifierProvider.overrideWith((ref) => ConnectivityNotifier(
            initialState: const ConnectivityState(status: ConnectivityStatus.offline),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final repo = container.read(orderRepositoryProvider);
      final gate = container.read(outboxDrainGateProvider);

      expect(repo, isA<DriftOfflineFirstOrderRepository>());
      expect(gate.shouldUseLocalFirst, isTrue);
      expect(gate.shouldShowDrainModal, isTrue);
      expect(gate.isOnline, isFalse);

      // Cashier can dismiss modal for offline session to work locally
      container.read(outboxDrainGateProvider.notifier).dismissModalForOfflineSession();
      final updatedGate = container.read(outboxDrainGateProvider);
      expect(updatedGate.shouldShowDrainModal, isFalse);
      expect(updatedGate.shouldUseLocalFirst, isTrue, reason: 'Still routes local-first so offline writes are safe');
    });

    test('Drain Completion: Flag=OFF + 3 pending rows -> all marked synced -> routing switches to online', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      expect(container.read(orderRepositoryProvider), isA<DriftOfflineFirstOrderRepository>());
      expect(container.read(outboxDrainGateProvider).shouldShowDrainModal, isTrue);

      // Mark all 3 rows synced (simulating sync completion)
      await (testDb.update(testDb.syncOutbox)..where((t) => t.status.equals(SyncOutboxStatus.pending)))
          .write(SyncOutboxCompanion(status: const Value(SyncOutboxStatus.synced), ackedAt: Value(DateTime.now())));

      // Allow stream to emit update
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Now outbox is drained!
      final gate = container.read(outboxDrainGateProvider);
      expect(gate.nonTerminalCount, equals(0));
      expect(gate.shouldUseLocalFirst, isFalse);
      expect(gate.shouldShowDrainModal, isFalse);

      final switchedRepo = container.read(orderRepositoryProvider);
      expect(switchedRepo, isA<ApiOrderRepository>(),
          reason: 'After sync all 3 on the server, routing switches to online');
    });

    test('Support Logging: logs gate decisions with flag, count, and route chosen', () async {
      FeatureFlags.setOfflineFirstEnabledForTesting(false);
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(ApiClient(baseUrl: 'http://localhost:3000')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      final gate = container.read(outboxDrainGateProvider);
      expect(gate.lastDecisionLog, isNotNull);
      expect(gate.lastDecisionLog, contains('flag=false'));
      expect(gate.lastDecisionLog, contains('pendingCount=1'));
      expect(gate.lastDecisionLog, contains('DriftOfflineFirstOrderRepository'));
    });
  });
}
