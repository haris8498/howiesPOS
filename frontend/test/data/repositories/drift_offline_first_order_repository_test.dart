import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/offline_print_jobs_table.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriftOfflineFirstOrderRepository Tests (§17.2, §5.2, §11, §15.2, §15.4)', () {
    late AppDatabase db;
    late DriftOfflineFirstOrderRepository repository;
    const uuid = Uuid();

    const testMenuItem = MenuItem(
      id: 'item-001',
      name: 'Pepperoni Pizza',
      category: 'Pizza',
      description: 'Classic Pepperoni',
      basePrice: 14.99,
      imageUrl: '',
    );

    OrderModel createSampleOrder({
      String? id,
      String? orderNumber,
      OrderType type = OrderType.dineIn,
      OrderStatus status = OrderStatus.accepted,
      bool isPaid = true,
      bool isHeld = false,
    }) {
      final orderId = id ?? uuid.v7();
      return OrderModel(
        id: orderId,
        orderNumber: orderNumber ?? 'HH-TEMP-1',
        type: type,
        status: status,
        items: const [
          OrderItem(
            item: testMenuItem,
            quantity: 2,
            selectedSize: 'Large',
            selectedCrust: 'Original',
            extraToppings: ['Extra Cheese'],
            notes: 'Well done',
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 29.98,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 2.55,
        grandTotalOverride: 32.53,
        paymentStatus: isPaid ? 'PAID' : 'UNPAID',
        isPaid: isPaid,
        isHeld: isHeld,
        kitchenTicketSent: true,
        payments: isPaid
            ? [
                OrderPaymentModel(
                  id: uuid.v7(),
                  paymentMethod: 'cash',
                  amount: 32.53,
                  tenderedAmount: 40.00,
                  changeReturned: 7.47,
                  paymentStatus: 'COMPLETED',
                  receivedBy: 'Cashier Elena',
                  createdAt: DateTime.now(),
                ),
              ]
            : [],
      );
    }

    setUp(() {
      db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      repository = DriftOfflineFirstOrderRepository(
        db: db,
        terminalId: '1',
        deviceId: 'POS-P1',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Atomic Transaction: Saves order + items + payment + outbox mutation + print job in ONE ACID transaction', () async {
      final inputOrder = createSampleOrder();
      final savedOrder = await repository.saveOrder(inputOrder);

      // Verify returned order has terminal-prefixed receipt number and UUID v7
      expect(savedOrder.id, equals(inputOrder.id));
      expect(savedOrder.orderNumber, equals('P1-101'));

      // Verify Table 1: local_orders
      final localOrder = await db.ordersDao.getOrderById(savedOrder.id);
      expect(localOrder, isNotNull);
      expect(localOrder!.orderNumber, equals('P1-101'));
      expect(localOrder.syncStatus, equals('pending_insert'));
      expect(localOrder.grandTotal, equals(32.53));
      expect(localOrder.isPaid, isTrue);

      // Verify Table 2: local_order_items
      final localItems = await db.ordersDao.getOrderItems(savedOrder.id);
      expect(localItems.length, equals(1));
      expect(localItems.first.itemName, equals('Pepperoni Pizza'));
      expect(localItems.first.quantity, equals(2));
      expect(localItems.first.syncStatus, equals('pending_insert'));

      // Verify Table 3: local_order_payments
      final localPayments = await db.ordersDao.getOrderPayments(savedOrder.id);
      expect(localPayments.length, equals(1));
      expect(localPayments.first.paymentMethod, equals('cash'));
      expect(localPayments.first.amount, equals(32.53));

      // Verify Table 4: sync_outbox (UUID v7, Level 2 dependency_order, PENDING)
      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(1));
      final outbox = outboxEntries.first;
      expect(outbox.entityType, equals('order'));
      expect(outbox.entityId, equals(savedOrder.id));
      expect(outbox.operationType, equals('INSERT'));
      expect(outbox.dependencyOrder, equals(2), reason: 'Spec §6.3: Order Header must be dependencyOrder = 2');
      expect(outbox.status, equals(SyncOutboxStatus.pending));

      // Verify outbox payload contains JSON data for backend OrderHandler
      final payload = jsonDecode(outbox.payload) as Map<String, dynamic>;
      expect(payload['id'], equals(savedOrder.id));
      expect(payload['order_number'], equals('P1-101'));
      expect(payload['grand_total'], equals(32.53));
      expect(payload['items'], isNotEmpty);

      // Verify Table 5: offline_print_jobs (QUEUED status, raw ESC/POS bytes)
      final queuedPrintJobs = await db.printJobsDao.getQueuedJobs();
      expect(queuedPrintJobs.length, equals(1));
      final printJob = queuedPrintJobs.first;
      expect(printJob.orderId, equals(savedOrder.id));
      expect(printJob.jobType, equals(PrintJobType.customerReceipt));
      expect(printJob.status, equals(PrintJobStatus.queued));
      expect(printJob.rawEscPosData, isNotEmpty);
    });

    test('2. Invariant: ORDER SAVING != PRINTING (§15.4)', () async {
      // The order must commit to SQLite WAL and outbox first;
      // UI returns immediately and print job is safely queued for local thermal printer
      final order = createSampleOrder();
      final stopwatch = Stopwatch()..start();
      final saved = await repository.saveOrder(order);
      stopwatch.stop();

      expect(saved.isPaid, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Local ACID commit must return immediately to UI');

      final printJobs = await db.printJobsDao.getQueuedJobs();
      expect(printJobs.length, equals(1));
      expect(printJobs.first.status, equals(PrintJobStatus.queued));
    });

    test('3. Sequence rollover: P1-101, P1-102, P1-103 sequentially incremented inside order transaction', () async {
      final o1 = await repository.saveOrder(createSampleOrder());
      final o2 = await repository.saveOrder(createSampleOrder());
      final o3 = await repository.saveOrder(createSampleOrder());

      expect(o1.orderNumber, equals('P1-101'));
      expect(o2.orderNumber, equals('P1-102'));
      expect(o3.orderNumber, equals('P1-103'));
    });

    test('3b. Midnight rollover prevention: active shift createdAt binds sequence business date (SYNC-038)', () async {
      final shiftDate = DateTime.now().subtract(const Duration(days: 1));
      final shiftDateStr = DateFormat('yyyy-MM-dd').format(shiftDate);

      // Seed an active shift started yesterday
      await db.into(db.localDailyCalculations).insert(
        LocalDailyCalculationsCompanion(
          id: Value(const Uuid().v7()),
          cashierId: const Value('emp-1'),
          cashierName: const Value('Alice'),
          startingCash: const Value(500.0),
          status: const Value('ACTIVE'),
          createdAt: Value(shiftDate),
        ),
      );

      // Set sequence to 150 for yesterday\'s shiftDate
      await db.terminalSequencesDao.getNextSequence('ORDER_NUMBER', shiftDateStr, start: 150, max: 999);

      // Save order now (which is a different calendar day than the shift start)
      final o = await repository.saveOrder(createSampleOrder());

      // Sequence must continue from yesterday\'s shift sequence (151) instead of resetting to 101 for today
      expect(o.orderNumber, equals('P1-151'));
    });

    test('4. Tier 2 Duplicate Protection (§15.2): Resubmitting same UUID v7 returns existing order without creating duplicate rows', () async {
      final fixedId = uuid.v7();
      final order = createSampleOrder(id: fixedId);

      final firstSave = await repository.saveOrder(order);
      expect(firstSave.id, equals(fixedId));
      expect(firstSave.orderNumber, equals('P1-101'));

      // Resubmit with identical UUID v7
      final secondSave = await repository.saveOrder(order);
      expect(secondSave.id, equals(fixedId));
      expect(secondSave.orderNumber, equals('P1-101'));

      // Verify no duplicates in database
      final allOrders = await repository.getAllOrders();
      expect(allOrders.length, equals(1));

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(1),
          reason: 'Outbox must NOT contain duplicate mutations for the same order');
    });

    test('5. Tier 1 Duplicate Protection (§15.2): Concurrent in-flight checkout invocations are deduplicated', () async {
      final fixedId = uuid.v7();
      final order = createSampleOrder(id: fixedId);

      // Fire 5 concurrent saves with identical order ID
      final results = await Future.wait([
        repository.saveOrder(order),
        repository.saveOrder(order),
        repository.saveOrder(order),
        repository.saveOrder(order),
        repository.saveOrder(order),
      ]);

      expect(results.length, equals(5));
      for (final res in results) {
        expect(res.id, equals(fixedId));
        expect(res.orderNumber, equals('P1-101'));
      }

      final allOrders = await repository.getAllOrders();
      expect(allOrders.length, equals(1));

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(1));
    });

    test('6. Query methods: getOrderById, getAllOrders, getCompletedOrders, getHeldOrders', () async {
      final completedOrder = await repository.saveOrder(createSampleOrder(status: OrderStatus.completed));
      final acceptedOrder = await repository.saveOrder(createSampleOrder(status: OrderStatus.accepted));
      final heldOrder = await repository.saveOrder(createSampleOrder(isHeld: true));

      final fetched = await repository.getOrderById(completedOrder.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(completedOrder.id));

      final all = await repository.getAllOrders();
      expect(all.length, equals(3));
      expect(all.any((o) => o.id == acceptedOrder.id), isTrue);

      final completedList = await repository.getCompletedOrders();
      expect(completedList.length, equals(1));
      expect(completedList.first.id, equals(completedOrder.id));

      final heldList = await repository.getHeldOrders();
      expect(heldList.length, equals(1));
      expect(heldList.first.id, equals(heldOrder.id));
    });

    test('7. Order status update enqueues UPDATE mutation in outbox', () async {
      final saved = await repository.saveOrder(createSampleOrder());

      await repository.updateOrderStatus(saved.id, OrderStatus.preparing);

      final updated = await repository.getOrderById(saved.id);
      expect(updated!.status, equals(OrderStatus.preparing));

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.length, equals(2)); // 1 INSERT + 1 UPDATE
      final updateMutation = outboxEntries.last;
      expect(updateMutation.operationType, equals('UPDATE'));
      expect(updateMutation.entityId, equals(saved.id));

      final payload = jsonDecode(updateMutation.payload) as Map<String, dynamic>;
      expect(payload['status'], equals('preparing'));
    });

    test('8. Cancel order sets status to cancelled and enqueues outbox mutation', () async {
      final saved = await repository.saveOrder(createSampleOrder());

      await repository.cancelOrder(saved.id);

      final updated = await repository.getOrderById(saved.id);
      expect(updated!.status, equals(OrderStatus.cancelled));

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.last.operationType, equals('UPDATE'));
    });

    test('9. Delete held order soft-deletes local record and enqueues DELETE mutation', () async {
      final saved = await repository.saveOrder(createSampleOrder(isHeld: true));

      await repository.deleteHeldOrder(saved.id);

      final fetched = await repository.getOrderById(saved.id);
      expect(fetched, isNull, reason: 'Soft-deleted order must not be returned by getOrderById');

      final outboxEntries = await db.outboxDao.getAllEntries();
      expect(outboxEntries.last.operationType, equals('DELETE'));
    });

    test('10. Reactive stream: watchAllOrders emits in real-time on local commit', () async {
      final stream = repository.watchAllOrders();

      expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
          hasLength(2),
        ]),
      );

      // Trigger first insert
      await repository.saveOrder(createSampleOrder());
      // Trigger second insert
      await repository.saveOrder(createSampleOrder());
    });

    test('11. Reactive stream: watchPendingOrders emits only pending sync orders', () async {
      final stream = repository.watchPendingOrders();

      expectLater(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
        ]),
      );

      final saved = await repository.saveOrder(createSampleOrder());

      // Marking the order synced removes it from watchPendingOrders
      await db.ordersDao.markOrderSynced(saved.id, 2, DateTime.now());
    });

    test('12. Dual-write elimination: simulated create timeout retry results in exactly one order ID and one outbox row (#10)', () async {
      final orderId = uuid.v7();
      final order = createSampleOrder(id: orderId);

      // Initial local-first checkout commit into Drift SQLite WAL + outbox
      final saved1 = await repository.saveOrder(order);
      expect(saved1.id, equals(orderId));

      // Simulate client experiencing a timeout / retry: checkout invoked again with identical order ID
      final saved2 = await repository.saveOrder(order);
      expect(saved2.id, equals(orderId));

      // Exactly one order exists in local database
      final allOrders = await repository.getAllOrders();
      final matchingOrders = allOrders.where((o) => o.id == orderId).toList();
      expect(matchingOrders.length, equals(1));

      // Exactly one outbox row exists (no duplicate mutations queued)
      final outboxEntries = await db.outboxDao.getAllEntries();
      final matchingOutbox = outboxEntries.where((o) => o.entityId == orderId).toList();
      expect(matchingOutbox.length, equals(1),
          reason: 'Checkout retry after simulated timeout must create exactly one outbox row');
    });

    test('13. Offline void marks the item voided, queues exactly one outbox mutation, and updates the order total', () async {
      final orderId = uuid.v7();
      final item1Id = uuid.v7();
      final item2Id = uuid.v7();

      const wingsMenuItem = MenuItem(
        id: 'item-002',
        name: 'Buffalo Wings',
        category: 'Sides',
        description: 'Spicy Buffalo Wings',
        basePrice: 8.50,
        imageUrl: '',
      );

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'HH-VOID-1',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: item1Id,
            item: testMenuItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
          OrderItem(
            id: item2Id,
            item: wingsMenuItem,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 8.50,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20.50,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 0.0,
        grandTotalOverride: 20.50,
        paymentStatus: 'UNPAID',
        isPaid: false,
      );

      await repository.saveOrder(initialOrder);

      // Verify initial state
      final initialOrderInDb = await db.ordersDao.getOrderById(orderId);
      expect(initialOrderInDb!.subtotal, equals(20.50));
      expect(initialOrderInDb.grandTotal, equals(20.50));

      // Perform offline void of the wings item
      await repository.voidOrderItem(
        orderId,
        item2Id,
        voidedBy: 'Cashier Elena',
        reason: 'Customer changed mind',
      );

      // 1. Verify item is marked voided with D-05 ledger columns
      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));
      final voidedItem = items.firstWhere((i) => i.id == item2Id);
      expect(voidedItem.isCancelled, isTrue);
      expect(voidedItem.voidedAt, isNotNull);
      expect(voidedItem.voidedBy, equals('Cashier Elena'));
      expect(voidedItem.cancelReason, equals('Customer changed mind'));

      // 2. Verify exactly one ITEM_VOID outbox mutation is queued matching handleItemVoid
      final allOutbox = await db.outboxDao.getAllEntries();
      final voidMutations = allOutbox.where((e) => e.entityId == orderId && e.operationType == 'ITEM_VOID').toList();
      expect(voidMutations.length, equals(1));
      final voidMutation = voidMutations.first;
      expect(voidMutation.status, equals(SyncOutboxStatus.pending));
      expect(voidMutation.entityType, equals('order'));
      final payload = jsonDecode(voidMutation.payload) as Map<String, dynamic>;
      expect(payload['order_id'], equals(orderId));
      expect(payload['item_id'], equals(item2Id));
      expect(payload['voided_by'], equals('Cashier Elena'));
      expect(payload['reason'], equals('Customer changed mind'));
      expect(payload['voided_at'], isNotNull);

      // 3. Verify local order total is recalculated
      final updatedOrder = await db.ordersDao.getOrderById(orderId);
      expect(updatedOrder!.subtotal, equals(12.00));
      expect(updatedOrder.grandTotal, equals(12.00));
    });

    test('14. Editing an existing order leaves exactly one order and no duplicated items (#35)', () async {
      final orderId = uuid.v7();
      final item1Id = uuid.v7();
      final item2Id = uuid.v7();

      const item2 = MenuItem(
        id: 'item-002',
        name: 'Garlic Bread',
        category: 'Sides',
        description: 'Cheesy Garlic Bread',
        basePrice: 5.99,
        imageUrl: '',
      );

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'P1-201',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: item1Id,
            item: testMenuItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 14.99,
          ),
          OrderItem(
            id: item2Id,
            item: item2,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 5.99,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20.98,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 0.0,
        grandTotalOverride: 20.98,
      );

      await repository.saveOrder(initialOrder);

      // Verify initial state
      final initialOrders = await repository.getAllOrders();
      expect(initialOrders.where((o) => o.id == orderId).length, equals(1));
      final initialItems = await db.ordersDao.getOrderItems(orderId);
      expect(initialItems.length, equals(2));

      // Simulate order edit: editing the order with preserved line-item IDs
      final editedOrder = initialOrder.copyWith(
        status: OrderStatus.accepted,
        subtotalOverride: 20.98,
        grandTotalOverride: 20.98,
        items: [
          OrderItem(
            id: item1Id,
            item: testMenuItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 14.99,
          ),
          OrderItem(
            id: item2Id,
            item: item2,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 5.99,
          ),
        ],
      );

      await repository.updateOrder(editedOrder);

      // Assert exactly one order exists in local DB
      final allOrders = await repository.getAllOrders();
      expect(allOrders.where((o) => o.id == orderId).length, equals(1));

      // Assert no duplicated items exist in local DB
      final allItems = await db.ordersDao.getOrderItems(orderId);
      final activeItems = allItems.where((i) => !i.isCancelled && i.voidedAt == null).toList();
      expect(activeItems.length, equals(2));
      expect(allItems.length, equals(2), reason: 'Editing existing items must not duplicate line items in Drift SQLite');
    });

    test('15. Adding one item adds exactly one line (#35)', () async {
      final orderId = uuid.v7();
      final item1Id = uuid.v7();
      final item2Id = uuid.v7();

      const item2 = MenuItem(
        id: 'item-002',
        name: 'Garlic Bread',
        category: 'Sides',
        description: 'Cheesy Garlic Bread',
        basePrice: 5.99,
        imageUrl: '',
      );

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'P1-202',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: item1Id,
            item: testMenuItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 14.99,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 14.99,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 0.0,
        grandTotalOverride: 14.99,
      );

      await repository.saveOrder(initialOrder);

      // Verify initial state: exactly 1 item
      final initialItems = await db.ordersDao.getOrderItems(orderId);
      expect(initialItems.length, equals(1));

      // Add exactly one new line item to the order (preserving item1Id)
      final orderWithAddedItem = initialOrder.copyWith(
        subtotalOverride: 20.98,
        grandTotalOverride: 20.98,
        items: [
          OrderItem(
            id: item1Id,
            item: testMenuItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 14.99,
          ),
          OrderItem(
            id: item2Id,
            item: item2,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 5.99,
          ),
        ],
      );

      await repository.updateOrder(orderWithAddedItem);

      // Assert exactly one order exists
      final allOrders = await repository.getAllOrders();
      expect(allOrders.where((o) => o.id == orderId).length, equals(1));

      // Assert exactly one line was added (1 initial + 1 new = 2 active items)
      final allItems = await db.ordersDao.getOrderItems(orderId);
      final activeItems = allItems.where((i) => !i.isCancelled && i.voidedAt == null).toList();
      expect(activeItems.length, equals(2));
      expect(allItems.length, equals(2), reason: 'Adding one item must add exactly one line to the ledger');
      expect(activeItems.any((i) => i.id == item1Id), isTrue);
      expect(activeItems.any((i) => i.id == item2Id), isTrue);
    });

    test('16. Partial void qty 1 of qty-2 line reduces original line and creates split voided line (#39)', () async {
      final orderId = uuid.v7();
      final itemId = uuid.v7();

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'P1-203',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: itemId,
            item: testMenuItem,
            quantity: 2,
            backendUnitPrice: 10.25,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20.50,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 0.0,
        grandTotalOverride: 20.50,
      );

      await repository.saveOrder(initialOrder);

      await repository.voidOrderItem(
        orderId,
        itemId,
        voidedBy: 'Cashier',
        reason: 'test',
        quantity: 1,
      );

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));

      final originalLine = items.firstWhere((i) => i.id == itemId);
      expect(originalLine.quantity, equals(1));
      expect(originalLine.isCancelled, isFalse);

      final secondRow = items.firstWhere((i) => i.id != itemId);
      expect(secondRow.isCancelled, isTrue);
      expect(secondRow.quantity, equals(1));
      expect(secondRow.voidedBy, equals('Cashier'));

      final updatedOrder = await db.ordersDao.getOrderById(orderId);
      expect(updatedOrder!.subtotal, equals(10.25));

      final allOutbox = await db.outboxDao.getAllEntries();
      final voidMutations = allOutbox.where((e) => e.entityId == orderId && e.operationType == 'ITEM_VOID').toList();
      expect(voidMutations.length, equals(1));
      final payload = jsonDecode(voidMutations.first.payload) as Map<String, dynamic>;
      expect(payload['quantity'], equals(1));
      expect(payload['split_item_id'], isNotNull);
      expect(payload['split_item_id'], isA<String>());
    });

    test('17. Full void with no quantity param still voids whole line (backward compat)', () async {
      final orderId = uuid.v7();
      final itemId = uuid.v7();

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'P1-204',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: itemId,
            item: testMenuItem,
            quantity: 2,
            backendUnitPrice: 10.25,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20.50,
        discountPercentage: 0.0,
        discountAmount: 0.0,
        taxAmount: 0.0,
        grandTotalOverride: 20.50,
      );

      await repository.saveOrder(initialOrder);

      await repository.voidOrderItem(
        orderId,
        itemId,
        voidedBy: 'Cashier',
        reason: 'test',
      );

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(1));
      expect(items.first.isCancelled, isTrue);

      final updatedOrder = await db.ordersDao.getOrderById(orderId);
      expect(updatedOrder!.subtotal, equals(0.0));
      expect(updatedOrder.grandTotal, equals(0.0));

      final allOutbox = await db.outboxDao.getAllEntries();
      final voidMutations = allOutbox.where((e) => e.entityId == orderId && e.operationType == 'ITEM_VOID').toList();
      expect(voidMutations.length, equals(1));
      final payload = jsonDecode(voidMutations.first.payload) as Map<String, dynamic>;
      expect(payload.containsKey('quantity'), isFalse);
    });
  });
}

