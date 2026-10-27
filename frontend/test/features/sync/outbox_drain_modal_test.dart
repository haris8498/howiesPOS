import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:hungry_howies_pos/config/feature_flags.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/outbox_drain_gate.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/features/sync/outbox_drain_modal.dart';

class MockOnlineConnectivityNotifier extends ConnectivityNotifier {
  MockOnlineConnectivityNotifier()
      : super(initialState: const ConnectivityState(status: ConnectivityStatus.online));

  @override
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {}

  @override
  Future<bool> probeHealth() async => true;
}

class MockOfflineConnectivityNotifier extends ConnectivityNotifier {
  MockOfflineConnectivityNotifier()
      : super(initialState: const ConnectivityState(status: ConnectivityStatus.offline));

  @override
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {}

  @override
  Future<bool> probeHealth() async => false;
}

class MockSyncBackgroundWorker extends SyncBackgroundWorker {
  MockSyncBackgroundWorker({
    required super.db,
    required super.connectivityNotifier,
  });

  @override
  Future<void> start() async {}

  @override
  Future<SyncCycleResult> triggerSyncCycle({bool force = false}) async {
    return const SyncCycleResult(pushedCount: 1, pushSuccess: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase(NativeDatabase.memory());
    FeatureFlags.resetForTesting();
    FeatureFlags.setOfflineFirstEnabledForTesting(false);
  });

  tearDown(() async {
    FeatureFlags.resetForTesting();
    await testDb.close();
  });

  const uuid1 = '019283a0-0001-7000-8000-000000000001';
  const uuid2 = '019283a0-0001-7000-8000-000000000002';
  const uuid3 = '019283a0-0001-7000-8000-000000000003';

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

  Widget createTestWidget({
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: OutboxDrainModal(),
        ),
      ),
    );
  }

  group('OutboxDrainModal Widget Tests (D-04 / SYNC-027)', () {
    testWidgets('1. Displays count of unsynced orders, Sync Now, and Export Backup buttons', (tester) async {
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);
      await insertOutboxRow(testDb, opId: uuid2, entityId: uuid2);
      await insertOutboxRow(testDb, opId: uuid3, entityId: uuid3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          connectivityNotifierProvider.overrideWith((ref) => MockOnlineConnectivityNotifier()),
          syncBackgroundWorkerProvider.overrideWith((ref) => MockSyncBackgroundWorker(
            db: testDb,
            connectivityNotifier: ref.watch(connectivityNotifierProvider.notifier),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Check header and pending count
      expect(find.text('Unsynced Orders Gate'), findsOneWidget);
      expect(find.text('3 order(s) awaiting sync'), findsOneWidget);

      // Check Action buttons
      expect(find.byKey(const Key('drain_modal_sync_now_button')), findsOneWidget);
      expect(find.byKey(const Key('drain_modal_export_button')), findsOneWidget);

      // Online status banner
      expect(find.text('Network Online'), findsOneWidget);
    });

    testWidgets('2. Displays offline notice and Work Offline button when network is offline', (tester) async {
      await insertOutboxRow(testDb, opId: uuid1, entityId: uuid1);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          connectivityNotifierProvider.overrideWith((ref) => MockOfflineConnectivityNotifier()),
          syncBackgroundWorkerProvider.overrideWith((ref) => MockSyncBackgroundWorker(
            db: testDb,
            connectivityNotifier: ref.watch(connectivityNotifierProvider.notifier),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      expect(find.text('No Network Connection (Offline Mode)'), findsOneWidget);
      expect(find.textContaining('The app stays in safe local-first mode'), findsOneWidget);
      expect(find.byKey(const Key('drain_modal_work_offline_button')), findsOneWidget);

      // Sync button should be disabled when offline
      final syncBtn = tester.widget<ElevatedButton>(find.byKey(const Key('drain_modal_sync_now_button')));
      expect(syncBtn.onPressed, isNull);

      // Tap Work Offline button
      await tester.tap(find.byKey(const Key('drain_modal_work_offline_button')));
      await tester.pumpAndSettle();

      expect(container.read(outboxDrainGateProvider).isDrainDismissedForSession, isTrue);
    });

    testWidgets('3. Lists permanently failed (4xx) entries with errors without purge/delete options (Task 5)', (tester) async {
      await insertOutboxRow(
        testDb,
        opId: uuid1,
        entityId: uuid1,
        status: SyncOutboxStatus.failedFatal,
        lastError: 'HTTP 400 Bad Request: Invalid line item price',
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          connectivityNotifierProvider.overrideWith((ref) => MockOnlineConnectivityNotifier()),
          syncBackgroundWorkerProvider.overrideWith((ref) => MockSyncBackgroundWorker(
            db: testDb,
            connectivityNotifier: ref.watch(connectivityNotifierProvider.notifier),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Check that permanently failed orders section exists
      expect(find.text('Permanently Failed Orders (1)'), findsOneWidget);
      expect(find.textContaining('HTTP 400 Bad Request'), findsOneWidget);
      expect(find.textContaining('NEVER deleted or purged'), findsOneWidget);

      // CRITICAL VERIFICATION: Ensure NO button exists that clears or purges errors
      expect(find.textContaining('Clear'), findsNothing);
      expect(find.textContaining('Purge'), findsNothing);
      expect(find.textContaining('Delete'), findsNothing);
      expect(find.textContaining('Discard'), findsNothing);
    });

    testWidgets('4. Displays completion message and Continue to Online Mode button when outbox is empty', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(testDb),
          connectivityNotifierProvider.overrideWith((ref) => MockOnlineConnectivityNotifier()),
          syncBackgroundWorkerProvider.overrideWith((ref) => MockSyncBackgroundWorker(
            db: testDb,
            connectivityNotifier: ref.watch(connectivityNotifierProvider.notifier),
          )),
        ],
      );
      addTearDown(container.dispose);

      await container.read(outboxDrainGateProvider.notifier).ready;

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Outbox Drained Successfully'), findsOneWidget);
      expect(find.byKey(const Key('drain_modal_continue_online_button')), findsOneWidget);
    });
  });
}
