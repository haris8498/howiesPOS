import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';

import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/shift_close_sync_guard.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';

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

  bool wasTriggered = false;

  @override
  Future<void> start() async {}

  @override
  void dispose() {}

  @override
  Future<SyncCycleResult> triggerSyncCycle({bool force = false}) async {
    wasTriggered = true;
    return const SyncCycleResult(pushedCount: 1, pushSuccess: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await testDb.close();
  });

  Future<void> insertOrderOutboxRow(
    AppDatabase db, {
    required String opId,
    required String entityId,
    String status = SyncOutboxStatus.pending,
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
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  const uuid1 = '019283a0-0001-7000-8000-000000000001';
  const uuid2 = '019283a0-0001-7000-8000-000000000002';

  testWidgets('with pending order mutations, close attempt while online waits for drain; while offline it shows the warning and still allows close', (tester) async {
    // -------------------------------------------------------------------------
    // PART 1: ONLINE - Waits for drain
    // -------------------------------------------------------------------------
    await insertOrderOutboxRow(testDb, opId: uuid1, entityId: uuid1);
    expect(await testDb.outboxDao.getPendingOrderCount(), equals(1));

    bool? onlineCloseAllowed;
    final onlineWorker = MockSyncBackgroundWorker(
      db: testDb,
      connectivityNotifier: MockOnlineConnectivityNotifier(),
    );

    final onlineContainer = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(testDb),
        connectivityNotifierProvider.overrideWith((ref) => MockOnlineConnectivityNotifier()),
        syncBackgroundWorkerProvider.overrideWithValue(onlineWorker),
      ],
    );
    addTearDown(onlineContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: onlineContainer,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('online_close_btn'),
                onPressed: () async {
                  onlineCloseAllowed = await onlineContainer
                      .read(shiftCloseSyncGuardProvider)
                      .guardShiftClose(context, timeout: const Duration(seconds: 10));
                },
                child: const Text('Close Shift Online'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to attempt close
    await tester.tap(find.byKey(const Key('online_close_btn')));
    await tester.pump(); // Show dialog

    // Dialog is visible in draining mode
    expect(find.byKey(const Key('shift_close_sync_dialog')), findsOneWidget);
    expect(find.text('Syncing Pending Orders'), findsOneWidget);
    expect(find.textContaining('1 order(s) awaiting sync'), findsOneWidget);
    expect(onlineCloseAllowed, isNull, reason: 'Must wait for outbox to drain');
    expect(onlineWorker.wasTriggered, isTrue);

    // Simulate worker successfully syncing the pending order mutation to 0
    final entry = await (testDb.select(testDb.syncOutbox)..where((t) => t.operationId.equals(uuid1))).getSingle();
    await testDb.outboxDao.markSynced(entry.id, DateTime.now());
    expect(await testDb.outboxDao.getPendingOrderCount(), equals(0));

    // Pump timer for poll interval (200ms)
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // Dialog dismissed automatically once drained, allowing shift close to continue
    expect(find.byKey(const Key('shift_close_sync_dialog')), findsNothing);
    expect(onlineCloseAllowed, isTrue, reason: 'Online close must continue after drain');

    // -------------------------------------------------------------------------
    // PART 2: OFFLINE - Shows warning and still allows close
    // -------------------------------------------------------------------------
    await insertOrderOutboxRow(testDb, opId: uuid2, entityId: uuid2);
    expect(await testDb.outboxDao.getPendingOrderCount(), equals(1));

    bool? offlineCloseAllowed;
    final offlineWorker = MockSyncBackgroundWorker(
      db: testDb,
      connectivityNotifier: MockOfflineConnectivityNotifier(),
    );

    final offlineContainer = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(testDb),
        connectivityNotifierProvider.overrideWith((ref) => MockOfflineConnectivityNotifier()),
        syncBackgroundWorkerProvider.overrideWithValue(offlineWorker),
      ],
    );
    addTearDown(offlineContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: offlineContainer,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('offline_close_btn'),
                onPressed: () async {
                  offlineCloseAllowed = await offlineContainer
                      .read(shiftCloseSyncGuardProvider)
                      .guardShiftClose(context);
                },
                child: const Text('Close Shift Offline'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to attempt close while offline
    await tester.tap(find.byKey(const Key('offline_close_btn')));
    await tester.pumpAndSettle();

    // Dialog is visible in offline warning mode
    expect(find.byKey(const Key('shift_close_sync_dialog')), findsOneWidget);
    expect(find.text('Offline Shift Close Warning'), findsOneWidget);
    expect(
      find.textContaining('1 orders have not synced yet and will be recorded as late-synced'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shift_close_sync_close_anyway_button')), findsOneWidget);
    expect(offlineCloseAllowed, isNull, reason: 'Awaits user confirmation');

    // Confirm close by tapping Close Shift Anyway
    await tester.tap(find.byKey(const Key('shift_close_sync_close_anyway_button')));
    await tester.pumpAndSettle();

    // Dialog dismissed and close is allowed
    expect(find.byKey(const Key('shift_close_sync_dialog')), findsNothing);
    expect(offlineCloseAllowed, isTrue, reason: 'Offline close must be allowed after confirmation');
  });
}
