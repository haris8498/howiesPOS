import 'dart:typed_data';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/offline_print_jobs_table.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/database/tables/local_daily_calculations_table.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory NativeDatabase with foreign keys enabled
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift Database & DAOs In-Memory Tests', () {
    test('Atomicity: saveOrderAtomic commits all records or rolls back completely', () async {
      const orderId = '019283a0-1234-7000-8000-000000000001';
      const orderNumber = 'P1-101';
      const opId = '019283a0-1234-7000-8000-000000000002';

      // 1. Successful atomic commit
      await db.ordersDao.saveOrderAtomic(
        order: LocalOrdersCompanion(
          id: const Value(orderId),
          orderNumber: const Value(orderNumber),
          orderType: const Value('dineIn'),
          subtotal: const Value(25.00),
          grandTotal: const Value(25.00),
          deviceId: const Value('POS-P1'),
          paymentStatus: const Value('PAID'),
          isPaid: const Value(true),
        ),
        items: [
          LocalOrderItemsCompanion(
            id: const Value('019283a0-1234-7000-8000-000000000003'),
            orderId: const Value(orderId),
            itemName: const Value('Pepperoni Pizza'),
            unitPrice: const Value(20.00),
            quantity: const Value(1),
            subtotal: const Value(20.00),
          ),
          LocalOrderItemsCompanion(
            id: const Value('019283a0-1234-7000-8000-000000000004'),
            orderId: const Value(orderId),
            itemName: const Value('Coke 500ml'),
            unitPrice: const Value(5.00),
            quantity: const Value(1),
            subtotal: const Value(5.00),
          ),
        ],
        payments: [
          LocalOrderPaymentsCompanion(
            id: const Value('019283a0-1234-7000-8000-000000000005'),
            orderId: const Value(orderId),
            paymentMethod: const Value('cash'),
            amount: const Value(25.00),
            tenderedAmount: const Value(30.00),
            changeReturned: const Value(5.00),
          ),
        ],
        outboxEntry: SyncOutboxCompanion(
          operationId: const Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value(orderId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_id": "$orderId", "total": 25.00}'),
          dependencyOrder: const Value(2),
        ),
        printJob: OfflinePrintJobsCompanion(
          jobType: const Value(PrintJobType.customerReceipt),
          orderId: const Value(orderId),
          printerTarget: const Value('WIN_DEFAULT'),
          rawEscPosData: Value(Uint8List.fromList([0x1B, 0x40])),
        ),
      );

      // Verify all rows exist
      final order = await db.ordersDao.getOrderById(orderId);
      expect(order, isNotNull);
      expect(order!.orderNumber, equals(orderNumber));

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));

      final payments = await db.ordersDao.getOrderPayments(orderId);
      expect(payments.length, equals(1));
      expect(payments.first.paymentMethod, equals('cash'));

      final outbox = await db.outboxDao.getEntryByOperationId(opId);
      expect(outbox, isNotNull);
      expect(outbox!.status, equals(SyncOutboxStatus.pending));

      final printJobs = await db.printJobsDao.getQueuedJobs();
      expect(printJobs.length, equals(1));
      expect(printJobs.first.orderId, equals(orderId));

      // 2. Rollback verification: when an error occurs inside transaction, ZERO rows remain
      const failingOrderId = '019283a0-9999-7000-8000-000000000001';
      const failingOpId = '019283a0-9999-7000-8000-000000000002';

      expect(
        () => db.transaction(() async {
          await db.into(db.localOrders).insert(
                LocalOrdersCompanion(
                  id: const Value(failingOrderId),
                  orderNumber: const Value('P1-999'),
                  orderType: const Value('takeaway'),
                  subtotal: const Value(15.00),
                  grandTotal: const Value(15.00),
                  deviceId: const Value('POS-P1'),
                ),
              );
          // Simulate sudden crash or failure before commit
          throw StateError('Simulated unexpected hardware disconnect');
        }),
        throwsA(isA<StateError>()),
      );

      final failedOrder = await db.ordersDao.getOrderById(failingOrderId);
      expect(failedOrder, isNull);
      final failedOutbox = await db.outboxDao.getEntryByOperationId(failingOpId);
      expect(failedOutbox, isNull);
    });

    test('Unique Constraint: duplicate operation_id on SyncOutbox is rejected', () async {
      const opId = '019283a0-5555-7000-8000-000000000001';

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-5555-7000-8000-000000000002'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
        ),
      );

      // Attempting to insert duplicate operationId throws constraint exception
      expect(
        () => db.outboxDao.insertEntry(
          SyncOutboxCompanion(
            operationId: const Value(opId),
            deviceId: const Value('POS-P1'),
            entityType: const Value('order'),
            entityId: const Value('019283a0-5555-7000-8000-000000000003'),
            operationType: const Value('INSERT'),
            payload: const Value('{}'),
          ),
        ),
        throwsA(anyOf(
          isA<sqlite.SqliteException>(),
          isA<DriftWrappedException>(),
        )),
      );
    });

    test('FK Behavior: cascade deletes child items and payments, rejects orphaned items', () async {
      const orderId = '019283a0-7777-7000-8000-000000000001';

      // 1. Inserting item with non-existent orderId fails FK check
      expect(
        () => db.into(db.localOrderItems).insert(
              LocalOrderItemsCompanion(
                id: const Value('019283a0-7777-7000-8000-000000000002'),
                orderId: const Value('019283a0-nonexistent-order-id-000000'),
                itemName: const Value('Orphan Pizza'),
                unitPrice: const Value(12.0),
                quantity: const Value(1),
                subtotal: const Value(12.0),
              ),
            ),
        throwsA(anyOf(
          isA<sqlite.SqliteException>(),
          isA<DriftWrappedException>(),
        )),
      );

      // 2. Insert valid order + items + payment
      await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: const Value(orderId),
              orderNumber: const Value('P1-105'),
              orderType: const Value('takeaway'),
              subtotal: const Value(20.0),
              grandTotal: const Value(20.0),
              deviceId: const Value('POS-P1'),
            ),
          );

      await db.into(db.localOrderItems).insert(
            LocalOrderItemsCompanion(
              id: const Value('019283a0-7777-7000-8000-000000000003'),
              orderId: const Value(orderId),
              itemName: const Value('Valid Burger'),
              unitPrice: const Value(20.0),
              quantity: const Value(1),
              subtotal: const Value(20.0),
            ),
          );

      await db.into(db.localOrderPayments).insert(
            LocalOrderPaymentsCompanion(
              id: const Value('019283a0-7777-7000-8000-000000000004'),
              orderId: const Value(orderId),
              paymentMethod: const Value('card'),
              amount: const Value(20.0),
            ),
          );

      expect((await db.ordersDao.getOrderItems(orderId)).length, equals(1));
      expect((await db.ordersDao.getOrderPayments(orderId)).length, equals(1));

      // 3. Delete parent order -> cascades to items and payments
      await db.ordersDao.deleteOrder(orderId);

      expect(await db.ordersDao.getOrderById(orderId), isNull);
      expect((await db.ordersDao.getOrderItems(orderId)).isEmpty, isTrue);
      expect((await db.ordersDao.getOrderPayments(orderId)).isEmpty, isTrue);
    });

    test('Outbox Ordering & Status Filtering: ORDER BY dependency_order, created_at LIMIT 25', () async {
      final now = DateTime.now();

      // Seed outbox entries with varied dependency orders and statuses
      // Item A: Dep 3, PENDING, created now - 10s
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000a'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order_item'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001a'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(3),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now.subtract(const Duration(seconds: 10))),
        ),
      );

      // Item B: Dep 1, PENDING, created now - 5s
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000b'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('shift'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001b'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now.subtract(const Duration(seconds: 5))),
        ),
      );

      // Item C: Dep 1, PENDING, created now - 20s (older than B, same dep)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000c'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('shift'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001c'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now.subtract(const Duration(seconds: 20))),
        ),
      );

      // Item D: Dep 2, FAILED_RETRYABLE, due now
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000d'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001d'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.failedRetryable),
          nextRetryAt: Value(now.subtract(const Duration(seconds: 1))),
          createdAt: Value(now.subtract(const Duration(seconds: 15))),
        ),
      );

      // Item E: Dep 1, AUTH_PAUSED (Deviation #3 - must NOT be picked)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000e'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001e'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.authPaused),
          createdAt: Value(now.subtract(const Duration(seconds: 30))),
        ),
      );

      // Item F: Dep 1, FAILED_RETRYABLE but NOT DUE YET (nextRetry in 10 mins)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000f'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001f'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.failedRetryable),
          nextRetryAt: Value(now.add(const Duration(minutes: 10))),
          createdAt: Value(now.subtract(const Duration(seconds: 25))),
        ),
      );

      // Item G: Dep 1, SYNCED (must NOT be picked)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-00000000000g'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-00000000001g'),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.synced),
          createdAt: Value(now.subtract(const Duration(seconds: 40))),
        ),
      );

      final batch = await db.outboxDao.getPushBatch(limit: 25, now: now);

      // Must contain only C, B, D, A in strict (dependency_order, created_at) sequence
      expect(batch.length, equals(4));
      expect(batch[0].operationId, equals('019283a0-0000-7000-8000-00000000000c')); // Dep 1, older
      expect(batch[1].operationId, equals('019283a0-0000-7000-8000-00000000000b')); // Dep 1, newer
      expect(batch[2].operationId, equals('019283a0-0000-7000-8000-00000000000d')); // Dep 2, due retryable
      expect(batch[3].operationId, equals('019283a0-0000-7000-8000-00000000000a')); // Dep 3
    });

    test('Approved Deviation #3: AUTH_PAUSED pauses queue and resumeAuthPaused restores to PENDING', () async {
      final entryId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value('019283a0-4010-7000-8000-000000000001'),
          deviceId: Value('POS-P1'),
          entityType: Value('order'),
          entityId: Value('019283a0-4010-7000-8000-000000000002'),
          operationType: Value('INSERT'),
          payload: Value('{}'),
          dependencyOrder: Value(1),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      // 1. Simulate 401 Unauthorized -> Pause queue entry
      await db.outboxDao.markAuthPaused(entryId, error: 'HTTP 401 Unauthorized: token expired');

      var batch = await db.outboxDao.getPushBatch();
      expect(batch.any((e) => e.id == entryId), isFalse);

      final paused = await db.outboxDao.getEntryByOperationId('019283a0-4010-7000-8000-000000000001');
      expect(paused!.status, equals(SyncOutboxStatus.authPaused));
      expect(paused.lastError, contains('401'));

      // 2. Token refreshed or user re-authenticates -> resume paused entries
      final resumedCount = await db.outboxDao.resumeAuthPaused();
      expect(resumedCount, equals(1));

      batch = await db.outboxDao.getPushBatch();
      expect(batch.any((e) => e.id == entryId), isTrue);
      expect(batch.firstWhere((e) => e.id == entryId).status, equals(SyncOutboxStatus.pending));
    });

    test('Catalog DAO: batch upsert and retrieval for categories, items, and settings', () async {
      // 1. Categories
      await db.catalogDao.upsertMenuCategories([
        const LocalMenuCategoriesCompanion(
          id: Value('cat_pizza'),
          name: Value('Pizzas'),
          displayOrder: Value(1),
          isActive: Value(true),
        ),
        const LocalMenuCategoriesCompanion(
          id: Value('cat_drinks'),
          name: Value('Drinks'),
          displayOrder: Value(2),
          isActive: Value(true),
        ),
      ]);

      final categories = await db.catalogDao.getAllCategories();
      expect(categories.length, equals(2));
      expect(categories.first.name, equals('Pizzas'));

      // 2. Menu Items & Sizes
      await db.catalogDao.upsertMenuItems([
        const LocalMenuItemsCompanion(
          id: Value('item_howie_special'),
          categoryId: Value('cat_pizza'),
          name: Value('Howie Special'),
          basePrice: Value(18.50),
          isAvailable: Value(true),
        ),
      ]);

      await db.catalogDao.upsertMenuItemSizes([
        const LocalMenuItemSizesCompanion(
          id: Value('size_large'),
          menuItemId: Value('item_howie_special'),
          sizeName: Value('Large'),
          priceMultiplier: Value(1.5),
          isDefault: Value(true),
        ),
      ]);

      final items = await db.catalogDao.getMenuItemsByCategory('cat_pizza');
      expect(items.length, equals(1));
      expect(items.first.name, equals('Howie Special'));

      final sizes = await db.catalogDao.getMenuItemSizes('item_howie_special');
      expect(sizes.length, equals(1));
      expect(sizes.first.sizeName, equals('Large'));

      // 3. Upsert update existing item
      await db.catalogDao.upsertMenuItems([
        const LocalMenuItemsCompanion(
          id: Value('item_howie_special'),
          categoryId: Value('cat_pizza'),
          name: Value('Howie Special (Updated Price)'),
          basePrice: Value(22.00),
          isAvailable: Value(true),
        ),
      ]);

      final updatedItems = await db.catalogDao.getMenuItemsByCategory('cat_pizza');
      expect(updatedItems.length, equals(1));
      expect(updatedItems.first.name, equals('Howie Special (Updated Price)'));
      expect(updatedItems.first.basePrice, equals(22.00));

      // 4. Store Settings
      await db.catalogDao.upsertStoreSettings(
        const LocalStoreSettingsCompanion(
          id: Value('store_singleton'),
          chainName: Value("Hungry Howie's"),
          branchCode: Value('Branch #402'),
          branchName: Value('Gujrat Medical College Branch'),
          storePhone: Value('+92 300 1234567'),
          taxPercentage: Value(16.0),
        ),
      );

      final settings = await db.catalogDao.getStoreSettings();
      expect(settings, isNotNull);
      expect(settings!.branchCode, equals('Branch #402'));
      expect(settings.taxPercentage, equals(16.0));
    });

    test('Sync Cursors: get and set sequence positions', () async {
      const feedKey = 'GLOBAL_PULL_CURSOR';

      // Initial state
      final initialSeq = await db.syncCursorsDao.getLastPulledSequence(feedKey);
      expect(initialSeq, equals(0));

      // Update cursor
      final now = DateTime.now();
      await db.syncCursorsDao.setCursor(
        feedKey,
        150,
        lastSyncAttempt: now,
        lastSuccessfulSync: now,
      );

      final updatedSeq = await db.syncCursorsDao.getLastPulledSequence(feedKey);
      expect(updatedSeq, equals(150));

      final cursor = await db.syncCursorsDao.getCursor(feedKey);
      expect(cursor, isNotNull);
      expect(cursor!.lastPulledSequence, equals(150));
      expect(cursor.lastSuccessfulSync, isNotNull);
    });

    test('Retention Pruning: 30-day synced data pruned, pending/recent data preserved', () async {
      final now = DateTime.now();
      final fortyDaysAgo = now.subtract(const Duration(days: 40));
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      // 1. Synced order older than 30 days -> MUST BE PRUNED
      const oldSyncedOrderId = '019283a0-0040-7000-8000-000000000001';
      await db.ordersDao.saveOrderAtomic(
        order: LocalOrdersCompanion(
          id: const Value(oldSyncedOrderId),
          orderNumber: const Value('P1-001'),
          orderType: const Value('dineIn'),
          subtotal: const Value(10.0),
          grandTotal: const Value(10.0),
          deviceId: const Value('POS-P1'),
          syncStatus: const Value('synced'),
          createdAt: Value(fortyDaysAgo),
        ),
        items: [
          LocalOrderItemsCompanion(
            id: const Value('019283a0-0040-7000-8000-000000000002'),
            orderId: const Value(oldSyncedOrderId),
            itemName: const Value('Old Pizza'),
            unitPrice: const Value(10.0),
            quantity: const Value(1),
            subtotal: const Value(10.0),
          ),
        ],
        payments: [],
        outboxEntry: SyncOutboxCompanion(
          operationId: const Value('019283a0-0040-7000-8000-000000000003'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value(oldSyncedOrderId),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.synced),
          createdAt: Value(fortyDaysAgo),
        ),
        printJob: OfflinePrintJobsCompanion(
          jobType: const Value(PrintJobType.customerReceipt),
          orderId: const Value(oldSyncedOrderId),
          printerTarget: const Value('WIN_DEFAULT'),
          rawEscPosData: Value(Uint8List.fromList([0x1B])),
          status: const Value(PrintJobStatus.printed),
          createdAt: Value(fortyDaysAgo),
        ),
      );

      // 2. Synced order from 10 days ago -> MUST BE PRESERVED
      const recentSyncedOrderId = '019283a0-0010-7000-8000-000000000001';
      await db.ordersDao.saveOrderAtomic(
        order: LocalOrdersCompanion(
          id: const Value(recentSyncedOrderId),
          orderNumber: const Value('P1-002'),
          orderType: const Value('dineIn'),
          subtotal: const Value(15.0),
          grandTotal: const Value(15.0),
          deviceId: const Value('POS-P1'),
          syncStatus: const Value('synced'),
          createdAt: Value(tenDaysAgo),
        ),
        items: [],
        payments: [],
        outboxEntry: SyncOutboxCompanion(
          operationId: const Value('019283a0-0010-7000-8000-000000000003'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value(recentSyncedOrderId),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.synced),
          createdAt: Value(tenDaysAgo),
        ),
      );

      // 3. Pending order from 40 days ago (e.g. prolonged offline) -> MUST NEVER BE PRUNED
      const oldPendingOrderId = '019283a0-0040-7000-8000-000000000099';
      await db.ordersDao.saveOrderAtomic(
        order: LocalOrdersCompanion(
          id: const Value(oldPendingOrderId),
          orderNumber: const Value('P1-099'),
          orderType: const Value('dineIn'),
          subtotal: const Value(30.0),
          grandTotal: const Value(30.0),
          deviceId: const Value('POS-P1'),
          syncStatus: const Value('pending_insert'),
          createdAt: Value(fortyDaysAgo),
        ),
        items: [],
        payments: [],
        outboxEntry: SyncOutboxCompanion(
          operationId: const Value('019283a0-0040-7000-8000-000000000098'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value(oldPendingOrderId),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(fortyDaysAgo),
        ),
      );

      // Run pruning
      final result = await db.pruneSyncedDataOlderThan(
        olderThan: const Duration(days: 30),
        referenceDate: now,
      );

      expect(result.ordersDeleted, equals(1));
      expect(result.outboxDeleted, equals(1));
      expect(result.printJobsDeleted, equals(1));

      // Verify old synced order was removed and its items cascaded
      expect(await db.ordersDao.getOrderById(oldSyncedOrderId), isNull);
      expect((await db.ordersDao.getOrderItems(oldSyncedOrderId)).isEmpty, isTrue);

      // Verify recent synced order remains
      expect(await db.ordersDao.getOrderById(recentSyncedOrderId), isNotNull);

      // Verify old pending order remains safely preserved
      expect(await db.ordersDao.getOrderById(oldPendingOrderId), isNotNull);
      final pendingOutbox = await db.outboxDao.getEntryByOperationId('019283a0-0040-7000-8000-000000000098');
      expect(pendingOutbox, isNotNull);
    });

    test('Terminal Sequences: cycles 101 to 999 and resets on new business date', () async {
      const key = 'ORDER_NUMBER';

      // 1. Initial on Day 1 starts at 101
      final seq1 = await db.terminalSequencesDao.getNextSequence(key, '2026-10-17');
      expect(seq1, equals(101));

      // 2. Second on Day 1 increments to 102
      final seq2 = await db.terminalSequencesDao.getNextSequence(key, '2026-10-17');
      expect(seq2, equals(102));

      // 3. Rollover to Day 2 resets to 101
      final seqDay2 = await db.terminalSequencesDao.getNextSequence(key, '2026-10-18');
      expect(seqDay2, equals(101));

      // 4. Sequence cycles back when exceeding max
      await db.terminalSequencesDao.setSequence(key, '2026-10-18', 999);
      final seqCycled = await db.terminalSequencesDao.getNextSequence(key, '2026-10-18');
      expect(seqCycled, equals(101));
    });

    test('Local Daily Calculations: active shift and offline closure with variance', () async {
      const shiftId = '019283a0-8888-7000-8000-000000000001';
      const cashierId = 'staff_cashier_01';

      // 1. Open shift
      await db.dailyCalculationsDao.insertCalculation(
        const LocalDailyCalculationsCompanion(
          id: Value(shiftId),
          cashierId: Value(cashierId),
          cashierName: Value('Zain Cashier'),
          startingCash: Value(1000.0),
          expectedCashDrawer: Value(1500.0),
          status: Value(DailyCalculationStatus.active),
        ),
      );

      final active = await db.dailyCalculationsDao.getActiveCalculation(cashierId);
      expect(active, isNotNull);
      expect(active!.startingCash, equals(1000.0));
      expect(active.status, equals(DailyCalculationStatus.active));

      // 2. Offline shift close with PKR 50 cash shortage
      await db.dailyCalculationsDao.closeShiftOffline(
        id: shiftId,
        actualCashCounted: 1450.0,
        cashVariance: -50.0,
        closingNotes: 'Shortage PKR 50 due to change discrepancy',
      );

      final closed = await db.dailyCalculationsDao.getCalculationById(shiftId);
      expect(closed, isNotNull);
      expect(closed!.status, equals(DailyCalculationStatus.offlineClosed));
      expect(closed.actualCashCounted, equals(1450.0));
      expect(closed.cashVariance, equals(-50.0));
      expect(closed.syncStatus, equals('pending_update'));

      // No longer active
      expect(await db.dailyCalculationsDao.getActiveCalculation(cashierId), isNull);
    });
  });
}
