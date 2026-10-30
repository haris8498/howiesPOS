import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/table_repository.dart';
import 'package:hungry_howies_pos/domain/models/restaurant_table.dart';
import 'package:hungry_howies_pos/services/api/api_providers.dart';
import 'package:hungry_howies_pos/services/api/tables_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTablesApiService extends TablesApiService {
  final List<Map<String, dynamic>> tablesToReturn;

  MockTablesApiService({this.tablesToReturn = const []});

  @override
  Future<List<Map<String, dynamic>>> listTables({String? section, String? status}) async {
    return tablesToReturn;
  }

  @override
  Future<List<Map<String, dynamic>>> listZones() async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #38: Stale Table State Fix Tests', () {
    test('1. cancel clears every table field', () {
      final occupiedTable = RestaurantTable(
        id: 'tbl-101',
        tableNumber: '101',
        name: 'Table 101',
        capacity: 4,
        section: 'Main Hall',
        status: TableStatus.occupied,
        currentCustomerCount: 4,
        currentBillAmount: 1850.50,
        dineInTax: 296.08,
        discountAmount: 100.0,
        discountPercentage: 5.0,
        activeOrderId: '01918a22-3866-7000-8000-000000000101',
        activeOrderNumber: 'P1-101',
        occupiedSince: DateTime(2026, 10, 30, 10, 0),
        reservedCustomerName: 'Reserved Guest',
        reservationTime: DateTime(2026, 10, 30, 12, 0),
        currentOrderItems: [
          {
            'id': 'item-1',
            'name': 'Pepperoni Pizza',
            'price': 1200.0,
            'quantity': 1,
          },
          {
            'id': 'item-2',
            'name': 'Garlic Bread',
            'price': 650.50,
            'quantity': 1,
          },
        ],
      );

      final freedTable = occupiedTable.toAvailable();

      // Verify status is available
      expect(freedTable.status, equals(TableStatus.available));

      // Verify every order/billing/guest/reservation field is completely cleared
      expect(freedTable.currentCustomerCount, equals(0));
      expect(freedTable.currentBillAmount, equals(0.0));
      expect(freedTable.dineInTax, equals(0.0));
      expect(freedTable.discountAmount, equals(0.0));
      expect(freedTable.discountPercentage, equals(0.0));
      expect(freedTable.activeOrderId, isNull);
      expect(freedTable.activeOrderNumber, isNull);
      expect(freedTable.occupiedSince, isNull);
      expect(freedTable.reservedCustomerName, isNull);
      expect(freedTable.reservationTime, isNull);
      expect(freedTable.currentOrderItems, isEmpty);

      // Verify identity/configuration fields are preserved
      expect(freedTable.id, equals('tbl-101'));
      expect(freedTable.tableNumber, equals('101'));
      expect(freedTable.name, equals('Table 101'));
      expect(freedTable.capacity, equals(4));
      expect(freedTable.section, equals('Main Hall'));
    });

    test('2. Amendment 2: server delta says table is available while local order is cancelled or completed; after loadTables() table must show available with all fields cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      const tableId = '01918a22-3866-7000-8000-000000000005';
      const orderId = '01918a22-3866-7000-8000-000000000006';

      // Seed local table in Drift as occupied
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: Value('5'),
          name: Value('Table 5'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value(orderId),
          version: Value(1),
        ),
      ]);

      // Seed local order in Drift as cancelled
      await db.into(db.localOrders).insert(
        LocalOrdersCompanion(
          id: const Value(orderId),
          orderNumber: const Value('P1-105'),
          orderType: const Value('dineIn'),
          status: const Value('cancelled'),
          subtotal: const Value(1500.0),
          grandTotal: const Value(1500.0),
          paymentStatus: const Value('UNPAID'),
          isPaid: const Value(false),
          deviceId: const Value('POS-P1'),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Server delta says table is available
      final mockApi = MockTablesApiService(
        tablesToReturn: [
          {
            'id': tableId,
            'table_number': '5',
            'name': 'Table 5',
            'capacity': 4,
            'status': 'available',
            'section': 'Hall',
            'current_bill_amount': 0.0,
          },
        ],
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tablesApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tableProvider.notifier);

      // Simulate local state having stale occupied data before loadTables
      notifier.setTablesForTesting([
        RestaurantTable(
          id: tableId,
          tableNumber: '5',
          name: 'Table 5',
          capacity: 4,
          section: 'Hall',
          status: TableStatus.occupied,
          currentCustomerCount: 3,
          currentBillAmount: 1500.0,
          dineInTax: 240.0,
          discountAmount: 150.0,
          discountPercentage: 10.0,
          activeOrderId: orderId,
          activeOrderNumber: 'P1-105',
          occupiedSince: DateTime.now(),
          currentOrderItems: [
            {'id': 'i1', 'name': 'Item', 'price': 1500.0, 'quantity': 1}
          ],
        ),
      ]);

      // Execute loadTables() which reconciles local and server delta
      await notifier.loadTables();

      final state = container.read(tableProvider);
      final table = state.tables.firstWhere((t) => t.id == tableId);

      // Table must show available with all fields cleared
      expect(table.status, equals(TableStatus.available));
      expect(table.currentCustomerCount, equals(0));
      expect(table.currentBillAmount, equals(0.0));
      expect(table.dineInTax, equals(0.0));
      expect(table.discountAmount, equals(0.0));
      expect(table.discountPercentage, equals(0.0));
      expect(table.activeOrderId, isNull);
      expect(table.activeOrderNumber, isNull);
      expect(table.occupiedSince, isNull);
      expect(table.reservedCustomerName, isNull);
      expect(table.reservationTime, isNull);
      expect(table.currentOrderItems, isEmpty);

      // Verify Drift SQLite cache was also updated to available with activeOrderId cleared
      final cachedDbTable = await (db.select(db.localRestaurantTables)..where((t) => t.id.equals(tableId))).getSingle();
      expect(cachedDbTable.status, equals('available'));
      expect(cachedDbTable.activeOrderId, isNull);
    });
  });
}
