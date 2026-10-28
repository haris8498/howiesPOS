import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectivityNotifier connectivityNotifier;
  late SyncBackgroundWorker worker;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    connectivityNotifier = ConnectivityNotifier();
    worker = SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
    );
  });

  tearDown(() async {
    connectivityNotifier.dispose();
    worker.dispose();
    await db.close();
  });

  group('Wave-5b #22: Active Orders Cold Bootstrap', () {
    test('1. bootstrap creates order plus items locally', () async {
      const orderId = '0194a000-0000-7000-8000-000000000001';
      const itemId1 = '0194a000-0000-7000-8000-000000000002';
      const itemId2 = '0194a000-0000-7000-8000-000000000003';
      const tableId = 'tbl-uuid-1';

      final bootstrapPayload = {
        'max_global_sequence': 100,
        'tables': [
          {
            'id': tableId,
            'table_number': 'T-01',
            'name': 'Table 1',
            'capacity': 4,
            'status': 'occupied',
            'active_order_id': orderId,
            'version': 1,
            'is_deleted': false,
          }
        ],
        'active_orders': [
          {
            'id': orderId,
            'order_number': 'ORD-101',
            'order_type': 'dineIn',
            'status': 'inKitchen',
            'subtotal': '25.50',
            'discount_percentage': '0',
            'discount_amount': '0',
            'tax_amount': '2.55',
            'grand_total': '28.05',
            'payment_status': 'UNPAID',
            'is_paid': false,
            'is_held': false,
            'version': 2,
            'created_at': DateTime.now().toIso8601String(),
            'dine_in_detail': {
              'table_id': tableId,
            },
            'order_items': [
              {
                'id': itemId1,
                'menu_item_id': 'item-pizza-1',
                'item_name': 'Pepperoni Pizza',
                'selected_size': 'Large',
                'unit_price': '20.00',
                'quantity': 1,
                'subtotal': '20.00',
                'is_cancelled': false,
              },
              {
                'id': itemId2,
                'menu_item_id': 'item-drink-1',
                'item_name': 'Coke',
                'selected_size': 'Can',
                'unit_price': '5.50',
                'quantity': 1,
                'subtotal': '5.50',
                'is_cancelled': false,
              },
            ],
          }
        ],
      };

      await worker.ingestBootstrapData(bootstrapPayload);

      // Verify order ingested into Drift
      final order = await db.ordersDao.getOrderById(orderId);
      expect(order, isNotNull);
      expect(order!.id, equals(orderId));
      expect(order.orderNumber, equals('ORD-101'));
      expect(order.status, equals('inKitchen'));
      expect(order.grandTotal, equals(28.05));
      expect(order.syncStatus, equals('synced'));
      expect(order.serverVersion, equals(2));

      // Verify items ingested into Drift
      final items = await db.ordersDao.getOrderItems(orderId);
      expect(items.length, equals(2));
      expect(items.map((i) => i.id), containsAll([itemId1, itemId2]));
      expect(items.firstWhere((i) => i.id == itemId1).itemName, equals('Pepperoni Pizza'));
      expect(items.firstWhere((i) => i.id == itemId1).unitPrice, equals(20.00));
      expect(items.firstWhere((i) => i.id == itemId2).itemName, equals('Coke'));

      // Verify occupied table is present and linked
      final table = await (db.select(db.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingleOrNull();
      expect(table, isNotNull);
      expect(table!.activeOrderId, equals(orderId));
      expect(table.status, equals('occupied'));
    });

    test('2. bootstrap skips an order that has a pending local outbox mutation', () async {
      const pendingOrderId = '0194a000-0000-7000-8000-000000000099';
      const otherOrderId = '0194a000-0000-7000-8000-000000000088';

      // Seed local order with pending local edits
      await db.into(db.localOrders).insert(
        LocalOrdersCompanion(
          id: const Value(pendingOrderId),
          orderNumber: const Value('LOCAL-99'),
          orderType: const Value('dineIn'),
          status: const Value('newOrder'),
          subtotal: const Value(15.00),
          grandTotal: const Value(15.00),
          paymentStatus: const Value('UNPAID'),
          isPaid: const Value(false),
          isHeld: const Value(false),
          deviceId: const Value('POS-01'),
          createdAt: Value(DateTime.now()),
          serverVersion: const Value(1),
          syncStatus: const Value('pending_update'),
        ),
      );

      // Seed pending outbox mutation for this order
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('0194a000-0000-7000-8000-000000000090'),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: const Value(pendingOrderId),
          operationType: const Value('ITEM_ADD'),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      final bootstrapPayload = {
        'max_global_sequence': 105,
        'active_orders': [
          {
            'id': pendingOrderId,
            'order_number': 'SERVER-OVERWRITE-99',
            'order_type': 'dineIn',
            'status': 'cancelled',
            'subtotal': '0.00',
            'grand_total': '0.00',
            'version': 5,
            'order_items': [],
          },
          {
            'id': otherOrderId,
            'order_number': 'ORD-OTHER-88',
            'order_type': 'takeaway',
            'status': 'newOrder',
            'subtotal': '10.00',
            'grand_total': '10.00',
            'version': 1,
            'order_items': [],
          },
        ],
      };

      await worker.ingestBootstrapData(bootstrapPayload);

      // The pending order must NOT be overwritten by the server bootstrap
      final localOrder = await db.ordersDao.getOrderById(pendingOrderId);
      expect(localOrder, isNotNull);
      expect(localOrder!.orderNumber, equals('LOCAL-99'), reason: 'Pending local work must win over bootstrap');
      expect(localOrder.status, equals('newOrder'), reason: 'Pending local status must be preserved');
      expect(localOrder.syncStatus, equals('pending_update'), reason: 'Pending sync status must be preserved');

      // The non-pending order must be ingested successfully
      final ingestedOther = await db.ordersDao.getOrderById(otherOrderId);
      expect(ingestedOther, isNotNull);
      expect(ingestedOther!.orderNumber, equals('ORD-OTHER-88'));
      expect(ingestedOther.syncStatus, equals('synced'));
    });
  });
}
