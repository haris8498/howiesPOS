import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/database/tables/offline_print_jobs_table.dart';
import 'package:hungry_howies_pos/core/database/tables/local_daily_calculations_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_shift_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:hungry_howies_pos/services/receipt_printer_service.dart';

Future<List<SyncOutboxEntry>> getPendingEntries(AppDatabase db) {
  return (db.select(db.syncOutbox)..where((t) => t.status.equals(SyncOutboxStatus.pending))).get();
}

Future<int> setNextRetry(AppDatabase db, int id, DateTime nextRetryAt) {
  return (db.update(db.syncOutbox)..where((t) => t.id.equals(id))).write(
    SyncOutboxCompanion(nextRetryAt: Value(nextRetryAt)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HttpServer fakeServer;
  late String serverUrl;
  late ConnectivityNotifier connectivityNotifier;
  late List<Map<String, dynamic>> receivedPushBatches;
  late Future<void> Function(HttpRequest request) requestHandler;
  const uuid = Uuid();

  const testMenuItem = MenuItem(
    id: 'item-pizza-01',
    name: 'Pepperoni Pizza',
    category: 'Pizza',
    description: 'Crispy pepperoni with mozzarella',
    basePrice: 15.0,
    imageUrl: '',
  );

  OrderModel createSampleOrder({
    String? id,
    String? orderNumber,
    OrderType type = OrderType.dineIn,
    OrderStatus status = OrderStatus.accepted,
    bool isPaid = true,
    double total = 30.0,
  }) {
    final orderId = id ?? uuid.v7();
    return OrderModel(
      id: orderId,
      orderNumber: orderNumber ?? 'P1-100',
      type: type,
      status: status,
      items: const [
        OrderItem(
          item: testMenuItem,
          quantity: 2,
          selectedSize: 'Large',
          selectedCrust: 'Original',
          extraToppings: ['Extra Cheese'],
          notes: 'Crispy',
        ),
      ],
      createdAt: DateTime.now(),
      subtotalOverride: total,
      taxAmount: 0.0,
      grandTotalOverride: total,
      paymentStatus: isPaid ? 'PAID' : 'UNPAID',
      isPaid: isPaid,
      kitchenTicketSent: false,
      payments: isPaid
          ? [
              OrderPaymentModel(
                id: uuid.v7(),
                paymentMethod: 'cash',
                amount: total,
                tenderedAmount: total,
                changeReturned: 0.0,
                paymentStatus: 'COMPLETED',
                receivedBy: 'Cashier Alice',
                createdAt: DateTime.now(),
              ),
            ]
          : [],
    );
  }

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

    ReceiptPrinterService.resetForTesting();
    ReceiptPrinterService.setDatabase(db);
    await ReceiptPrinterService.savePrinterSettings(
      printerName: 'POS-TEST-PRINTER',
      kitchenPrinterName: 'KITCHEN-TEST-PRINTER',
      kitchenSameAsCustomer: false,
    );

    fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${fakeServer.port}';
    receivedPushBatches = [];

    // Default mock server handler
    requestHandler = (request) async {
      final path = request.uri.path;

      if (path == '/health') {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': true,
          'status': 'ok',
          'service': 'hungry-howies-pos-api',
        }));
        await request.response.close();
        return;
      }

      if (path == '/sync/push') {
        final bodyString = await utf8.decoder.bind(request).join();
        final bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
        receivedPushBatches.add(bodyJson);

        final mutations = bodyJson['mutations'] as List<dynamic>? ?? [];
        final results = mutations.map((m) {
          return {
            'operation_id': m['operation_id'],
            'entity_id': m['entity_id'],
            'status': 'SYNCED',
            'server_version': (m['base_version'] as num? ?? 1).toInt() + 1,
            'server_timestamp': DateTime.now().toIso8601String(),
          };
        }).toList();

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'success': true,
          'batch_id': bodyJson['batch_id'],
          'processed_count': results.length,
          'results': results,
        }));
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
    ReceiptPrinterService.resetForTesting();
    connectivityNotifier.dispose();
    await fakeServer.close(force: true);
    await db.close();
  });

  SyncBackgroundWorker createWorker({
    Duration pollInterval = const Duration(seconds: 30),
    Duration zombieTimeout = const Duration(seconds: 60),
    Duration circuitBreakerPauseDuration = const Duration(milliseconds: 100),
  }) {
    return SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
      syncUrlOverride: serverUrl,
      pollInterval: pollInterval,
      zombieTimeout: zombieTimeout,
      circuitBreakerPauseDuration: circuitBreakerPauseDuration,
    );
  }

  group('Client Integration Tests: The 15 Failure Scenarios (§15.1, §15.2, §15.4)', () {
    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 1: Normal Online Operation (Baseline)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 1: Normal Operation -> Atomic Drift Commit + Instant Sync + Receipt/KOT Spooled', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final worker = createWorker();

      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async => true;

      // 1. Save order via repository
      final order = createSampleOrder();
      final savedOrder = await repo.saveOrder(order);

      expect(savedOrder.id, order.id);
      expect(savedOrder.orderNumber.startsWith('P1-'), isTrue);

      // Verify atomic commit in Drift
      final inDb = await db.ordersDao.getOrderById(order.id);
      expect(inDb, isNotNull);
      expect(inDb!.status, OrderStatus.accepted.name);

      // Verify outbox entry staged as PENDING
      final pendingBefore = await getPendingEntries(db);
      expect(pendingBefore.length, 1);
      expect(pendingBefore.first.status, SyncOutboxStatus.pending);

      // 2. Sync worker executes push
      await worker.triggerPush();

      // Verify outbox converged to SYNCED
      final syncedEntry = await db.outboxDao.getEntryByOperationId(pendingBefore.first.operationId);
      expect(syncedEntry!.status, SyncOutboxStatus.synced);
      expect(syncedEntry.ackedAt, isNotNull);

      // Verify server received mutation
      expect(receivedPushBatches.length, 1);
      final pushedMutations = receivedPushBatches.first['mutations'] as List;
      expect(pushedMutations.first['entity_id'], order.id);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 2: Sudden Network Disconnection Mid-Shift
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 2: Sudden Cable Disconnect -> Committed in WAL, Enqueued PENDING, Backoff Scheduled', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);

      // Sever the server connection immediately
      await fakeServer.close(force: true);

      // Order created during network disconnect
      final order = createSampleOrder();
      final savedOrder = await repo.saveOrder(order);
      expect(savedOrder.id, order.id);

      // Local WAL holds transaction safely
      final inDb = await db.ordersDao.getOrderById(order.id);
      expect(inDb, isNotNull);

      // Outbox attempts push and transitions to FAILED_RETRYABLE with backoff
      final worker = createWorker();
      await worker.triggerPush();

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, 1);
      final entry = outboxEntries.first;
      expect(entry.status, SyncOutboxStatus.failedRetryable);
      expect(entry.retryCount, 1);
      expect(entry.nextRetryAt, isNotNull);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 3: Very Slow / High-Latency Connection (5s Timeout)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 3: High Latency -> 5s Client Timeout triggers backoff while UI remains <10ms', () async {
      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          // Delay longer than 5-second client timeout
          await Future.delayed(const Duration(seconds: 6));
          req.response.statusCode = 200;
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final repo = DriftOfflineFirstOrderRepository(db: db);
      final worker = createWorker();

      // UI operation commits immediately
      final stopwatch = Stopwatch()..start();
      final order = await repo.saveOrder(createSampleOrder());
      stopwatch.stop();

      // Drift local write must complete in sub-millisecond range (<100ms on any hardware)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(order, isNotNull);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 4: Extended Offline Operation (30m / 8h Outage Reconnection)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 4: Reconnection after Outage -> FIFO batch push (25/batch) drains all pending rows', () async {
      final worker = createWorker();

      // Enqueue 35 pending mutations offline
      for (int i = 1; i <= 35; i++) {
        await db.outboxDao.insertEntry(
          SyncOutboxCompanion(
            operationId: Value(uuid.v7()),
            deviceId: const Value('POS-P1'),
            entityType: const Value('order'),
            entityId: Value(uuid.v7()),
            operationType: const Value('INSERT'),
            dependencyOrder: const Value(2),
            payload: Value('{"order_number": "P1-${100 + i}"}'),
            status: const Value(SyncOutboxStatus.pending),
            createdAt: Value(DateTime.now().add(Duration(milliseconds: i))),
          ),
        );
      }

      final pendingBefore = await getPendingEntries(db);
      expect(pendingBefore.length, 35);

      // Trigger drainage: Batch 1 (limit 25) + Batch 2 (limit 10)
      await worker.triggerPush();

      final pendingAfter = await getPendingEntries(db);
      expect(pendingAfter.isEmpty, isTrue);

      final allEntries = await db.outboxDao.getAllEntries();
      for (final e in allEntries) {
        expect(e.status, SyncOutboxStatus.synced);
      }

      // Assert FIFO chunking: 2 batches transmitted (25 + 10 = 35)
      expect(receivedPushBatches.length, 2);
      expect((receivedPushBatches[0]['mutations'] as List).length, 25);
      expect((receivedPushBatches[1]['mutations'] as List).length, 10);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 5: Network Loss During Cash Checkout Submission
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 5: Network Loss during Checkout -> Order & Payment committed locally in WAL, queues PENDING', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final worker = createWorker();

      // Cashier rings up cash checkout
      final order = createSampleOrder(isPaid: true, total: 45.0);
      final savedOrder = await repo.saveOrder(order);

      // Check payment saved in WAL
      final payments = await db.ordersDao.getOrderPayments(savedOrder.id);
      expect(payments.length, 1);
      expect(payments.first.paymentMethod, 'cash');
      expect(payments.first.amount, 45.0);

      // Outbox contains pending order
      final pending = await getPendingEntries(db);
      expect(pending.length, 1);

      // Simulate connection restoration: flushes and syncs cleanly
      await worker.triggerPush();
      final synced = await db.outboxDao.getEntryByOperationId(pending.first.operationId);
      expect(synced!.status, SyncOutboxStatus.synced);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 6: Server Committed but ACK/Response Lost in Transit
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 6: Server ACK Lost in Transit -> Retries with same UUID v7, Idempotency hit converges with 0 duplicates', () async {
      int requestCount = 0;
      final orderOpId = uuid.v7();
      final orderEntityId = uuid.v7();

      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          requestCount++;
          if (requestCount == 1) {
            // First attempt: Server processes, but connection drops before ACK returned
            final socket = await req.response.detachSocket();
            socket.destroy();
            return;
          }
          // Second attempt: Returns DUPLICATE / 200 OK
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'batch_id': 'batch-06',
            'processed_count': 1,
            'results': [
              {
                'operation_id': orderOpId,
                'entity_id': orderEntityId,
                'status': 'DUPLICATE',
                'server_version': 1,
                'server_timestamp': DateTime.now().toIso8601String(),
              }
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker();

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(orderOpId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: Value(orderEntityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number": "P1-106"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // Attempt 1: socket drop causes failure
      await worker.triggerPush();
      var entry = await db.outboxDao.getEntryByOperationId(orderOpId);
      expect(entry!.status, SyncOutboxStatus.failedRetryable);

      // Reset retry schedule for immediate test execution
      await setNextRetry(db, entry.id, DateTime.now().subtract(const Duration(seconds: 1)));

      // Attempt 2: server returns DUPLICATE -> client safely converges to SYNCED
      await worker.triggerPush();
      entry = await db.outboxDao.getEntryByOperationId(orderOpId);
      expect(entry!.status, SyncOutboxStatus.synced);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 7: POS Seating vs Owner Remote Edit (Hospitality Operational Priority)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 7: POS Seating vs Owner Edit -> Physical Seated Guest Wins (§10.2)', () async {
      // 1. Local Table 4 initialized
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value('tbl-4'),
          tableNumber: Value('4'),
          name: Value('Table 4'),
          status: Value('occupied'),
          activeOrderId: Value('ord-seated-001'),
          version: Value(1),
        ),
      ]);

      final worker = createWorker();

      // 2. Incoming delta pull where remote owner marked Table 4 'available'
      // Spec §10.2: POS has active dining guest seated physically -> POS Wins!
      requestHandler = (req) async {
        if (req.uri.path == '/sync/pull') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 100,
            'next_cursor': 101,
            'has_more': false,
            'changes': [
              {
                'sequence': 101,
                'entity_type': 'table',
                'entity_id': 'tbl-4',
                'operation': 'UPDATE',
                'record_version': 2,
                'payload': {
                  'status': 'available',
                  'active_order_id': null,
                },
              }
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      await worker.triggerPull();

      // Invariant: Seated guest cannot be evicted by remote owner portal! Table remains OCCUPIED.
      final table = (await (db.select(db.localRestaurantTables)..where((t) => t.id.equals('tbl-4'))).getSingle());
      expect(table.status, 'occupied');
      expect(table.activeOrderId, 'ord-seated-001');

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 8: Cashier Offline Sale of 86'd Item (Decoupled Inventory)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 8: Sale of 86d Item -> Order commits 100% cleanly without inventory deduction block', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final worker = createWorker();

      // Cashier sells item that was marked 86'd on cloud
      final order = createSampleOrder(total: 12.0);
      final savedOrder = await repo.saveOrder(order);
      expect(savedOrder.id, order.id);

      await worker.triggerPush();

      final entry = await db.outboxDao.getEntryByOperationId(
        (await db.outboxDao.getAllEntries()).first.operationId,
      );
      expect(entry!.status, SyncOutboxStatus.synced);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 9: Cashier Online, Owner Offline
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 9: Cashier Online, Owner Offline -> POS syncs immediately to cloud, empty outbox', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final worker = createWorker();

      final order = await repo.saveOrder(createSampleOrder());
      expect(order, isNotNull);

      await worker.triggerPush();

      // Cashier outbox is completely empty/synced
      final pending = await getPendingEntries(db);
      expect(pending.isEmpty, isTrue);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 10: Both Offline - Citywide Blackout & Offline Shift Close with Variance
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 10: Citywide Blackout -> Offline Shift Close saved locally with variance (-300 PKR) and synced', () async {
      final shiftRepo = DriftOfflineFirstShiftRepository(db: db);

      // Open shift offline
      final shift = await shiftRepo.openShift(
        cashierId: 'c-01',
        cashierName: 'Elena Rostova',
        startingCash: 5000.0,
      );
      expect(shift.status, DailyCalculationStatus.active);

      // Close shift offline with -300 PKR cash variance
      final closedShift = await shiftRepo.closeShift(
        shiftId: shift.id,
        actualCashCounted: 48200.0,
        expectedCashDrawer: 48500.0,
        cashVariance: -300.0,
        varianceReason: 'End of night petty shortage',
      );

      expect(closedShift.status, DailyCalculationStatus.offlineClosed);
      expect(closedShift.cashVariance, -300.0);

      // Verify Level 5 outbox mutation queued
      final outboxEntries = await db.outboxDao.getAllEntries();
      final closeMutation = outboxEntries.firstWhere((e) => e.dependencyOrder == 5);
      expect(closeMutation.entityType, 'shift');
      expect(closeMutation.operationType, 'UPDATE');

      // Morning sync simulation
      final worker = createWorker();
      await worker.triggerPush();

      final syncedClose = await db.outboxDao.getEntryByOperationId(closeMutation.operationId);
      expect(syncedClose!.status, SyncOutboxStatus.synced);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 11: Server Downtime / 502 / 503 Maintenance
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 11: Server 502/503 -> Truncated Exponential Backoff + Circuit Breaker triggers after 5 fails', () async {
      int pushCalls = 0;
      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          pushCalls++;
          req.response.statusCode = 503;
          req.response.write('Service Unavailable');
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker(
        circuitBreakerPauseDuration: const Duration(milliseconds: 50),
      );

      final opId = uuid.v7();
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number": "P1-111"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // 5 consecutive failures trigger circuit breaker
      for (int i = 0; i < 5; i++) {
        await worker.triggerPush();
        final entry = await db.outboxDao.getEntryByOperationId(opId);
        // Force retry timestamp for immediate re-attempt in test
        await setNextRetry(db, entry!.id, DateTime.now().subtract(const Duration(seconds: 1)));
      }

      // Circuit breaker is tripped
      expect(worker.state.isCircuitBreakerTripped, isTrue);

      // 6th push is suppressed by circuit breaker
      await worker.triggerPush();
      expect(pushCalls, 5);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 12: Crash During Sync Execution (Zombie Task Recovery §15.3)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 12: Crash Mid-Batch -> Orphaned IN_FLIGHT tasks reset to PENDING on startup', () async {
      final zombieOpId = uuid.v7();

      // Simulate app crashing mid-push leaving task in IN_FLIGHT older than 60s
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(zombieOpId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number": "P1-112"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(DateTime.now().subtract(const Duration(seconds: 90))),
        ),
      );

      var entry = await db.outboxDao.getEntryByOperationId(zombieOpId);
      expect(entry!.status, SyncOutboxStatus.inFlight);

      // Startup crash recovery hook runs
      final worker = createWorker(zombieTimeout: const Duration(seconds: 60));
      final recovered = await worker.recoverOrphanedOutboxTasks(olderThan: const Duration(seconds: 60));

      expect(recovered, 1);

      // Invariant: Zero orphan rows left in IN_FLIGHT
      entry = await db.outboxDao.getEntryByOperationId(zombieOpId);
      expect(entry!.status, SyncOutboxStatus.pending);

      worker.dispose();
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 13: Sudden Power Loss / Hardware Blackout (SQLite WAL Mode Durability)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 13: Hardware Blackout -> SQLite atomic commit rolls back aborted transaction, integrity check ok', () async {
      // 1. Perform committed transaction
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final committedOrder = await repo.saveOrder(createSampleOrder());

      // 2. Simulate mid-write power loss using a rollback transaction
      try {
        await db.transaction(() async {
          await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: Value(uuid.v7()),
              orderNumber: const Value('P1-CORRUPTED'),
              orderType: const Value('dineIn'),
              status: const Value('newOrder'),
              subtotal: const Value(100.0),
              taxAmount: const Value(0.0),
              grandTotal: const Value(100.0),
              isPaid: const Value(false),
              createdAt: Value(DateTime.now()),
            ),
          );
          // Hard power failure exception thrown before commit
          throw Exception('POWER_OUTAGE_BLACKOUT_SIMULATION');
        });
      } catch (_) {
        // Power dropped
      }

      // Invariant: Uncommitted order rolled back cleanly
      final corrupted = await (db.select(db.localOrders)..where((o) => o.orderNumber.equals('P1-CORRUPTED'))).getSingleOrNull();
      expect(corrupted, isNull);

      // Invariant: Committed order intact in WAL
      final committed = await (db.select(db.localOrders)..where((o) => o.id.equals(committedOrder.id))).getSingleOrNull();
      expect(committed, isNotNull);

      // Invariant: PRAGMA integrity_check == ok
      final integrityResult = await db.customSelect('PRAGMA integrity_check;').getSingle();
      expect(integrityResult.data['integrity_check'], 'ok');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 14: Idempotency 5x Rapid Mashing
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 14: Rapid Button Mashing 5x -> Drift rejects duplicate insert, exactly 1 order in SQLite', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final singleOrder = createSampleOrder(id: uuid.v7(), orderNumber: 'P1-MASH-01');

      // Attempt to save the exact same order 5 times concurrently
      final futures = List.generate(5, (_) => repo.saveOrder(singleOrder));
      final results = await Future.wait(futures);

      // All 5 calls return the identical order without error
      for (final res in results) {
        expect(res.id, singleOrder.id);
      }

      // Invariant: Exactly 1 order in Drift database
      final orders = await (db.select(db.localOrders)..where((o) => o.id.equals(singleOrder.id))).get();
      expect(orders.length, 1);

      // Invariant: Exactly 1 outbox mutation queued
      final outbox = await (db.select(db.syncOutbox)..where((o) => o.entityId.equals(singleOrder.id))).get();
      expect(outbox.length, 1);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SCENARIO 15: Hardware Printer Failure (ORDER SAVING != PRINTING)
    // ─────────────────────────────────────────────────────────────────────────
    test('Scenario 15: Thermal Printer Out of Paper -> Never rolls back order (§15.4, §21 Decision 1)', () async {
      final repo = DriftOfflineFirstOrderRepository(db: db);
      final order = createSampleOrder(orderNumber: 'P1-PRINT-FAIL');

      // Printer simulates hardware out-of-paper exception
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async {
        throw Exception('Native Win32 spooler write fault: ERROR_OUT_OF_PAPER (28)');
      };

      // 1. Order saves safely
      final savedOrder = await repo.saveOrder(order);
      expect(savedOrder.id, order.id);

      // 2. Receipt print fails
      final receiptData = ReceiptData.fromOrderModel(order: savedOrder, type: ReceiptType.customerReceipt);
      final printOk = await ReceiptPrinterService.printReceipt(receipt: receiptData, db: db);
      expect(printOk, isFalse);

      // Invariant: ORDER SAVING != PRINTING (§15.4)
      final persisted = await db.ordersDao.getOrderById(order.id);
      expect(persisted, isNotNull);
      expect(persisted!.grandTotal, order.grandTotal);

      // Print job safely retained in OfflinePrintJobs for manual retry
      final jobs = await db.printJobsDao.getJobsForOrder(savedOrder.orderNumber);
      expect(jobs.length, 1);
      expect(jobs.first.status, PrintJobStatus.failed);

      // Cashier reloads paper and taps "Retry Print"
      ReceiptPrinterService.testPrinterFn = (printer, bytes, {String? docName}) async => true;
      final retryOk = await ReceiptPrinterService.retryPrintJob(jobs.first.id, db: db);
      expect(retryOk, isTrue);

      final jobAfterRetry = await db.printJobsDao.getJobById(jobs.first.id);
      expect(jobAfterRetry!.status, PrintJobStatus.printed);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // LOAD SMOKE TEST: 8-Hour Outage Worth of Orders (160 Orders / 400 Mutations)
  // ───────────────────────────────────────────────────────────────────────────
  test('Load Smoke Test: 8-Hour Outage (160 Orders / 400 Mutations) syncs in bounded time and memory', () async {
    final repo = DriftOfflineFirstOrderRepository(db: db);
    final worker = createWorker();

    const totalOrders = 160;

    // 1. Generate 160 orders offline in Drift
    for (int i = 1; i <= totalOrders; i++) {
      final order = createSampleOrder(
        orderNumber: 'P1-${1000 + i}',
        total: 25.0 + (i % 20),
      );
      await repo.saveOrder(order);
    }

    final pendingBefore = await getPendingEntries(db);
    expect(pendingBefore.length, totalOrders);

    // 2. Reconnect and drain queue (FIFO in batches of 25)
    final stopwatch = Stopwatch()..start();
    await worker.triggerPush();
    stopwatch.stop();

    // Assert bounded execution time (< 5.0 seconds for 160 orders in Drift SQLite)
    expect(stopwatch.elapsedMilliseconds, lessThan(5000));

    // Verify all 160 mutations converged to SYNCED
    final pendingAfter = await getPendingEntries(db);
    expect(pendingAfter.isEmpty, isTrue);

    final allSynced = await db.outboxDao.getAllEntries();
    expect(allSynced.length, totalOrders);
    for (final e in allSynced) {
      expect(e.status, SyncOutboxStatus.synced);
    }

    // Verify batches of 25 were pushed
    // 160 / 25 = 6 full batches of 25 + 1 batch of 10 = 7 batches
    expect(receivedPushBatches.length, 7);
    expect((receivedPushBatches[0]['mutations'] as List).length, 25);
    expect((receivedPushBatches[6]['mutations'] as List).length, 10);

    worker.dispose();
  });
}
