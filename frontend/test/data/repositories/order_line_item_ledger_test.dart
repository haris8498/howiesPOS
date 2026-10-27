import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/data/repositories/drift_offline_first_order_repository.dart';
import 'package:hungry_howies_pos/domain/models/menu_item.dart';
import 'package:hungry_howies_pos/domain/models/order_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('D-05 (SYNC-032) Order Line-Item Ledger Tests', () {
    late AppDatabase db;
    late DriftOfflineFirstOrderRepository repository;
    const uuid = Uuid();

    const pizzaItem = MenuItem(
      id: 'menu-pizza-01',
      name: 'Cheese Pizza',
      category: 'Pizza',
      description: 'Classic cheese',
      basePrice: 12.00,
      imageUrl: '',
    );

    const wingsItem = MenuItem(
      id: 'menu-wings-01',
      name: 'Buffalo Wings',
      category: 'Sides',
      description: 'Spicy wings',
      basePrice: 8.50,
      imageUrl: '',
    );

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
        deviceId: 'POS-TEST-1',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. saveOrder sets UUID v7, createdByDeviceId, and clientCreatedAt on order items', () async {
      final orderId = uuid.v7();
      final order = OrderModel(
        id: orderId,
        orderNumber: 'HH-100',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: const [
          OrderItem(
            item: pizzaItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 12.00,
        grandTotalOverride: 12.00,
      );

      final saved = await repository.saveOrder(order);
      expect(saved.id, equals(orderId));

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(1));
      expect(items.first.id.length, equals(36)); // UUID v7
      expect(items.first.createdByDeviceId, equals('POS-TEST-1'));
      expect(items.first.clientCreatedAt, isNotNull);
      expect(items.first.voidedAt, isNull);
      expect(items.first.isCancelled, isFalse);
    });

    test('2. updateOrder preserves existing items and voids/supersedes modified items', () async {
      final orderId = uuid.v7();
      final item1Id = uuid.v7();

      // Initial order with 1 item
      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'HH-101',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: item1Id,
            item: pizzaItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 12.00,
        grandTotalOverride: 12.00,
      );
      await repository.saveOrder(initialOrder);

      // Now update order: modify item 1 (quantity changed to 2) and add wings
      final updatedOrder = initialOrder.copyWith(
        subtotalOverride: 32.50,
        grandTotalOverride: 32.50,
        items: [
          OrderItem(
            id: item1Id,
            item: pizzaItem,
            quantity: 2, // Changed quantity
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
          const OrderItem(
            item: wingsItem,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 8.50,
          ),
        ],
      );

      await repository.updateOrder(updatedOrder);

      final allItems = await db.ordersDao.getOrderItems(orderId);
      // Expected items in ledger:
      // 1. item1Id (voided, superseded)
      // 2. new item for pizza (supersedes item1Id)
      // 3. new item for wings
      expect(allItems.length, equals(3));

      final oldItem = allItems.firstWhere((i) => i.id == item1Id);
      expect(oldItem.isCancelled, isTrue);
      expect(oldItem.voidedAt, isNotNull);
      expect(oldItem.voidedBy, equals('LOCAL_EDIT'));

      final supersedingItem = allItems.firstWhere((i) => i.supersedesItemId == item1Id);
      expect(supersedingItem.quantity, equals(2));
      expect(supersedingItem.isCancelled, isFalse);
      expect(supersedingItem.voidedAt, isNull);

      final addedWings = allItems.firstWhere((i) => i.itemName == 'Buffalo Wings');
      expect(addedWings.quantity, equals(1));
      expect(addedWings.isCancelled, isFalse);
      expect(addedWings.voidedAt, isNull);
    });

    test('3. addOrderItem appends to ledger, recalculates subtotal, and enqueues ITEM_ADD outbox mutation', () async {
      final orderId = uuid.v7();
      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'HH-102',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: const [
          OrderItem(
            item: pizzaItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 12.00,
        grandTotalOverride: 12.00,
      );
      await repository.saveOrder(initialOrder);

      // Append wings via addOrderItem
      const newWings = OrderItem(
        item: wingsItem,
        quantity: 2,
        selectedSize: 'Regular',
        backendUnitPrice: 8.50,
      );
      final added = await repository.addOrderItem(orderId, newWings);

      expect(added.id, isNotNull);
      expect(added.createdByDeviceId, equals('POS-TEST-1'));

      // Check database state
      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));

      final updatedOrder = await db.ordersDao.getOrderById(orderId);
      expect(updatedOrder!.subtotal, equals(29.00)); // 12.00 + (8.50 * 2)

      // Verify outbox mutation
      final outboxEntries = await (db.select(db.syncOutbox)..where((t) => t.entityId.equals(orderId))).get();
      final addMutation = outboxEntries.firstWhere((e) => e.operationType == 'ITEM_ADD');
      expect(addMutation.status, equals(SyncOutboxStatus.pending));
      final payload = jsonDecode(addMutation.payload) as Map<String, dynamic>;
      expect(payload['item_name'], equals('Buffalo Wings'));
      expect(payload['quantity'], equals(2));
    });

    test('4. voidOrderItem marks item voided, recalculates subtotal, and enqueues ITEM_VOID outbox mutation', () async {
      final orderId = uuid.v7();
      final item1Id = uuid.v7();
      final item2Id = uuid.v7();

      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'HH-103',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: item1Id,
            item: pizzaItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
          OrderItem(
            id: item2Id,
            item: wingsItem,
            quantity: 1,
            selectedSize: 'Regular',
            backendUnitPrice: 8.50,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 20.50,
        grandTotalOverride: 20.50,
      );
      await repository.saveOrder(initialOrder);

      // Void the wings item
      await repository.voidOrderItem(orderId, item2Id, voidedBy: 'Manager Bob', reason: 'Customer changed mind');

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));

      final voidedItem = items.firstWhere((i) => i.id == item2Id);
      expect(voidedItem.isCancelled, isTrue);
      expect(voidedItem.voidedAt, isNotNull);
      expect(voidedItem.voidedBy, equals('Manager Bob'));
      expect(voidedItem.cancelReason, equals('Customer changed mind'));

      final updatedOrder = await db.ordersDao.getOrderById(orderId);
      expect(updatedOrder!.subtotal, equals(12.00)); // Wings excluded from active subtotal

      // Verify outbox mutation
      final outboxEntries = await (db.select(db.syncOutbox)..where((t) => t.entityId.equals(orderId))).get();
      final voidMutation = outboxEntries.firstWhere((e) => e.operationType == 'ITEM_VOID');
      expect(voidMutation.status, equals(SyncOutboxStatus.pending));
      final payload = jsonDecode(voidMutation.payload) as Map<String, dynamic>;
      expect(payload['item_id'], equals(item2Id));
      expect(payload['voided_by'], equals('Manager Bob'));
      expect(payload['reason'], equals('Customer changed mind'));
    });

    test('5. Sync Background Worker pull merge: set-union by ID where void always wins', () async {
      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: ConnectivityNotifier(),
        deviceId: 'POS-TEST-1',
      );

      final orderId = uuid.v7();
      final localItemId = uuid.v7();

      // Setup local order with 1 item
      final initialOrder = OrderModel(
        id: orderId,
        orderNumber: 'HH-104',
        type: OrderType.dineIn,
        status: OrderStatus.accepted,
        items: [
          OrderItem(
            id: localItemId,
            item: pizzaItem,
            quantity: 1,
            selectedSize: 'Large',
            backendUnitPrice: 12.00,
          ),
        ],
        createdAt: DateTime.now(),
        subtotalOverride: 12.00,
        grandTotalOverride: 12.00,
      );
      await repository.saveOrder(initialOrder);

      // Mark outbox synced so pending guard does not block pull
      await (db.update(db.syncOutbox)..where((t) => t.entityId.equals(orderId))).write(
        const SyncOutboxCompanion(status: Value(SyncOutboxStatus.synced)),
      );

      // Incoming pull change from another terminal with 2 items:
      // Item A: localItemId marked voided
      // Item B: new item remoteItemId (Garlic Bread)
      final remoteItemId = uuid.v7();
      final pullDelta = {
        'entity_type': 'order',
        'entity_id': orderId,
        'record_version': 2,
        'payload': {
          'id': orderId,
          'status': 'accepted',
          'subtotal': 6.00,
          'grand_total': 6.00,
          'items': [
            {
              'id': localItemId,
              'item_name': 'Cheese Pizza',
              'quantity': 1,
              'unit_price': 12.00,
              'voided_at': DateTime.now().toIso8601String(),
              'voided_by': 'Remote Cashier',
              'cancel_reason': 'Out of dough',
              'is_cancelled': true,
            },
            {
              'id': remoteItemId,
              'item_name': 'Garlic Bread',
              'quantity': 1,
              'unit_price': 6.00,
              'is_cancelled': false,
            },
          ],
        },
      };

      final result = await worker.applyPullChange(pullDelta);
      expect(result, equals(PullApplyResult.applied));

      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));

      final mergedLocalItem = items.firstWhere((i) => i.id == localItemId);
      expect(mergedLocalItem.isCancelled, isTrue);
      expect(mergedLocalItem.voidedAt, isNotNull);
      expect(mergedLocalItem.voidedBy, equals('Remote Cashier'));

      final mergedRemoteItem = items.firstWhere((i) => i.id == remoteItemId);
      expect(mergedRemoteItem.isCancelled, isFalse);
      expect(mergedRemoteItem.itemName, equals('Garlic Bread'));

      // Test void commutativity / void-wins: incoming live copy NEVER revives voided item
      final pullDeltaRevivalAttempt = {
        'entity_type': 'order',
        'entity_id': orderId,
        'record_version': 3,
        'payload': {
          'id': orderId,
          'status': 'accepted',
          'items': [
            {
              'id': localItemId,
              'item_name': 'Cheese Pizza',
              'quantity': 1,
              'unit_price': 12.00,
              'voided_at': null,
              'is_cancelled': false, // Attempt to revive!
            },
          ],
        },
      };

      await worker.applyPullChange(pullDeltaRevivalAttempt);

      final itemsAfterRevivalAttempt = await db.ordersDao.getOrderItems(orderId);
      final stillVoidedItem = itemsAfterRevivalAttempt.firstWhere((i) => i.id == localItemId);
      expect(stillVoidedItem.isCancelled, isTrue, reason: 'Void must always win over live copy');
      expect(stillVoidedItem.voidedAt, isNotNull);
    });
  });
}
