import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/database/tables/local_daily_calculations_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HttpServer fakeServer;
  late String serverUrl;
  late ConnectivityNotifier connectivityNotifier;
  late Future<void> Function(HttpRequest request) requestHandler;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${fakeServer.port}';

    // Default handler returns 200 for health, 404 otherwise
    requestHandler = (request) async {
      if (request.uri.path == '/health') {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'ok'}));
        await request.response.close();
        return;
      }
      request.response.statusCode = 404;
      await request.response.close();
    };

    fakeServer.listen((req) async {
      try {
        await requestHandler(req);
      } catch (_) {}
    });

    connectivityNotifier = ConnectivityNotifier(
      healthEndpointOverride: '$serverUrl/health',
    );
    connectivityNotifier.setOnlineManually();
  });

  tearDown(() async {
    connectivityNotifier.dispose();
    await fakeServer.close(force: true);
    await db.close();
  });

  SyncBackgroundWorker createWorker() {
    return SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
      syncUrlOverride: serverUrl,
      deviceId: 'POS-TEST-1',
    );
  }

  group('SYNC-004: Push-Pull Sequencing and State Guard Tests', () {
    test('1. Concurrent trigger calls produce serial execution', () async {
      final worker = createWorker();
      final executionOrder = <String>[];
      int pushCalls = 0;

      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          pushCalls++;
          final currentCall = pushCalls;
          executionOrder.add('push_start_$currentCall');
          // Add artificial delay to simulate network latency
          await Future.delayed(const Duration(milliseconds: 50));
          executionOrder.add('push_end_$currentCall');

          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'batch_id': 'batch-$currentCall',
            'results': [
              {
                'operation_id': '019283a0-0000-7000-8000-000000000001',
                'entity_id': '019283a0-0000-7000-8000-000000000002',
                'status': 'SYNCED',
                'server_version': 2,
                'server_timestamp': DateTime.now().toIso8601String(),
              }
            ],
          }));
          await req.response.close();
          return;
        }

        if (req.uri.path == '/sync/pull') {
          executionOrder.add('pull');
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 10,
            'next_cursor': 10,
            'changes': [],
            'has_more': false,
          }));
          await req.response.close();
          return;
        }

        req.response.statusCode = 404;
        await req.response.close();
      };

      // Set cursor so pull does not call bootstrap
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 10);

      // Enqueue one outbox entry so push executes
      await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value('019283a0-0000-7000-8000-000000000001'),
          deviceId: Value('POS-TEST-1'),
          entityType: Value('table'),
          entityId: Value('019283a0-0000-7000-8000-000000000002'),
          operationType: Value('UPDATE'),
          payload: Value('{}'),
        ),
      );

      // Fire 3 overlapping trigger calls concurrently
      final futures = [
        worker.triggerSyncCycle(),
        worker.triggerPush(),
        worker.triggerPull(),
      ];

      await Future.wait(futures);

      // Verify serial execution:
      // Cycle 1 ran (push_start_1, push_end_1, pull).
      // Coalesced cycle 2 ran after cycle 1 finished.
      // At no point did push_start_2 appear before push_end_1!
      expect(executionOrder.contains('push_start_1'), isTrue);
      expect(executionOrder.contains('push_end_1'), isTrue);
      final startIndex1 = executionOrder.indexOf('push_start_1');
      final endIndex1 = executionOrder.indexOf('push_end_1');
      expect(endIndex1 > startIndex1, isTrue);

      worker.dispose();
    });

    test('2. Stale delta cannot reopen a closed shift or re-occupy a freed table', () async {
      final worker = createWorker();

      // ── Sub-test A: Shift closure terminality ──────────────────────────────
      // Seed a shift closed offline by cashier with counted cash
      const shiftId = '019283a0-0000-7000-8000-000000000010';
      await db.dailyCalculationsDao.upsertCalculation(
        LocalDailyCalculationsCompanion(
          id: const Value(shiftId),
          cashierId: const Value('cashier-42'),
          cashierName: const Value('Alice'),
          startingCash: const Value(5000.0),
          expectedCashDrawer: const Value(15500.0),
          actualCashCounted: const Value(15000.0),
          cashVariance: const Value(-500.0),
          status: const Value(DailyCalculationStatus.offlineClosed),
          closingNotes: const Value('Drawer PKR 500 short'),
          submittedAt: Value(DateTime.now()),
          syncStatus: const Value('pending_update'),
          serverVersion: const Value(1),
        ),
      );

      // Incoming stale server delta: server thinks shift is still ACTIVE and actual cash is null
      final staleShiftDelta = {
        'entity_type': 'shift',
        'entity_id': shiftId,
        'record_version': 5, // Higher server version!
        'operation': 'UPDATE',
        'is_deleted': false,
        'payload': {
          'status': 'ACTIVE',
          'starting_cash': 5000.0,
          'actual_cash_counted': null,
          'cash_variance': 0.0,
          'cashier_id': 'cashier-42',
        },
      };

      final shiftApplyResult = await worker.applyPullChange(staleShiftDelta);
      expect(shiftApplyResult, PullApplyResult.applied);

      // Assert: Shift remains OFFLINE_CLOSED, counted cash and variance preserved!
      final preservedShift = await db.dailyCalculationsDao.getCalculationById(shiftId);
      expect(preservedShift, isNotNull);
      expect(preservedShift!.status, DailyCalculationStatus.offlineClosed);
      expect(preservedShift.actualCashCounted, 15000.0);
      expect(preservedShift.cashVariance, -500.0);
      expect(preservedShift.closingNotes, 'Drawer PKR 500 short');

      // ── Sub-test B: Table release preservation ────────────────────────────
      // Seed Table 4 as freed locally (available) at version 2
      const tableId = '019283a0-0000-7000-8000-000000000011';
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: Value('4'),
          name: Value('Booth 4'),
          status: Value('available'),
          activeOrderId: Value(null),
          version: Value(2),
        ),
      ]);

      // Stale delta attempting to re-occupy Table 4 with version 1 (<= local version)
      final staleTableDelta = {
        'entity_type': 'restaurant_table',
        'entity_id': tableId,
        'record_version': 1, // Stale version!
        'operation': 'UPDATE',
        'is_deleted': false,
        'payload': {
          'status': 'occupied',
          'active_order_id': '019283a0-0000-7000-8000-000000000099',
        },
      };

      final tableApplyResult = await worker.applyPullChange(staleTableDelta);
      expect(tableApplyResult, PullApplyResult.ignoredStale);

      // Assert: Table 4 remains AVAILABLE and activeOrderId is null
      final preservedTable = await db.catalogDao.getTableById(tableId);
      expect(preservedTable, isNotNull);
      expect(preservedTable!.status, 'available');
      expect(preservedTable.activeOrderId, isNull);

      worker.dispose();
    });

    test('3. Delta for an entity with pending outbox is skipped, then applied after push drains', () async {
      final worker = createWorker();
      const entityId = '019283a0-0000-7000-8000-000000000020';

      // Seed local table
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(entityId),
          tableNumber: Value('10'),
          name: Value('Local Name'),
          status: Value('available'),
          version: Value(1),
        ),
      ]);

      // Seed cursor to 20
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 20);

      // Enqueue pending outbox entry for this table (e.g. pending cashier edit)
      await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value('019283a0-0000-7000-8000-000000000021'),
          deviceId: Value('POS-TEST-1'),
          entityType: Value('table'),
          entityId: Value(entityId),
          operationType: Value('UPDATE'),
          payload: Value('{"name": "Local Cashier Edit"}'),
          dependencyOrder: Value(3),
        ),
      );

      // Verify _hasPendingOutbox is true
      final entries = await db.outboxDao.getAllEntries();
      expect(entries.any((e) => e.entityId == entityId), isTrue);

      // Delta arriving from server for this table
      final deltaChange = {
        'sequence': 21,
        'entity_type': 'restaurant_table',
        'entity_id': entityId,
        'record_version': 2,
        'operation': 'UPDATE',
        'is_deleted': false,
        'payload': {
          'name': 'Server Cloud Name',
          'status': 'available',
        },
      };

      // ── Step 1: When pending outbox exists, delta is skipped ────────────────
      final skipResult = await worker.applyPullChange(deltaChange);
      expect(skipResult, PullApplyResult.skippedPending);

      // Local table name must NOT be overwritten
      var table = await db.catalogDao.getTableById(entityId);
      expect(table!.name, 'Local Name');

      // ── Step 2: Push drains outbox entry ────────────────────────────────────
      await db.outboxDao.markSynced(entries.first.id, DateTime.now());

      // ── Step 3: Now that outbox is drained, delta is applied ────────────────
      final applyResult = await worker.applyPullChange(deltaChange);
      expect(applyResult, PullApplyResult.applied);

      table = await db.catalogDao.getTableById(entityId);
      expect(table!.name, 'Server Cloud Name');
      expect(table.version, 2);

      worker.dispose();
    });

    test('4. Cursor does not advance when batch transaction fails', () async {
      final worker = createWorker();

      // Seed global pull cursor to 30
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 30);

      // Setup fake server that returns 2 changes: first valid, second causes DB error
      requestHandler = (req) async {
        if (req.uri.path == '/sync/pull') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 32,
            'next_cursor': 32,
            'has_more': false,
            'changes': [
              {
                'sequence': 31,
                'entity_type': 'restaurant_table',
                'entity_id': '019283a0-0000-7000-8000-000000000031',
                'record_version': 2,
                'payload': {'table_number': 'T1', 'name': 'T1', 'status': 'available'},
              },
              {
                'sequence': 32,
                // entity_id shorter than 36 chars will fail Drift check constraint
                'entity_type': 'shift',
                'entity_id': 'invalid-short-id',
                'record_version': 2,
                'payload': {'status': 'ACTIVE'},
              },
            ],
          }));
          await req.response.close();
          return;
        }

        req.response.statusCode = 404;
        await req.response.close();
      };

      // Trigger cycle
      final result = await worker.triggerSyncCycle();
      expect(result.pullSuccess, isFalse);

      // Invariant: Cursor must NOT advance to 32 because the batch transaction failed!
      final cursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      expect(cursor, 30);

      // Invariant: Change 31 must be rolled back by Drift transaction
      final table = await db.catalogDao.getTableById('019283a0-0000-7000-8000-000000000031');
      expect(table, isNull);

      worker.dispose();
    });

    test('5. Pull pauses if push fails with network or auth error', () async {
      final worker = createWorker();
      bool pullWasRequested = false;

      // Seed cursor to 40
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 40);

      // Enqueue outbox mutation
      await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value('019283a0-0000-7000-8000-000000000041'),
          deviceId: Value('POS-TEST-1'),
          entityType: Value('table'),
          entityId: Value('019283a0-0000-7000-8000-000000000042'),
          operationType: Value('UPDATE'),
          payload: Value('{}'),
        ),
      );

      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          // Push fails with HTTP 500 network error
          req.response.statusCode = 500;
          req.response.write('Server error');
          await req.response.close();
          return;
        }

        if (req.uri.path == '/sync/pull') {
          pullWasRequested = true;
          req.response.statusCode = 200;
          req.response.write(jsonEncode({'changes': []}));
          await req.response.close();
          return;
        }

        req.response.statusCode = 404;
        await req.response.close();
      };

      final result = await worker.triggerSyncCycle();

      // Assert push failed with network error
      expect(result.networkOrAuthError, isTrue);
      expect(result.pushSuccess, isFalse);

      // Assert pull was NEVER requested (pull paused per §5)
      expect(pullWasRequested, isFalse);
      expect(result.pullSuccess, isFalse);

      worker.dispose();
    });
  });
}
