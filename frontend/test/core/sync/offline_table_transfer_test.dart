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

class FakeTablesApiService extends TablesApiService {
  final bool shouldThrowOnTransfer;
  final List<Map<String, dynamic>> tablesToReturn;

  FakeTablesApiService({
    this.shouldThrowOnTransfer = false,
    this.tablesToReturn = const [],
  });

  @override
  Future<Map<String, dynamic>> transferTable({required String fromTableId, required String toTableId}) async {
    if (shouldThrowOnTransfer) {
      throw Exception('Network unreachable (Offline)');
    }
    return {'success': true};
  }

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

  group('SYNC-029 & SYNC-031: Offline Table Transfer and Cold Restart Tests', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('SYNC-029: transferTable offline persists to localRestaurantTables and queues outbox mutations', () async {
      const fromId = '01918a22-3866-7000-8000-000000000001';
      const toId = '01918a22-3866-7000-8000-000000000002';
      const activeOrderId = '01918a22-3866-7000-8000-000000000003';

      // Seed local tables
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(fromId),
          tableNumber: Value('1'),
          name: Value('Table 1'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value(activeOrderId),
          version: Value(1),
        ),
        const LocalRestaurantTablesCompanion(
          id: Value(toId),
          tableNumber: Value('2'),
          name: Value('Table 2'),
          capacity: Value(4),
          status: Value('available'),
          version: Value(1),
        ),
      ]);

      final fakeApi = FakeTablesApiService(
        shouldThrowOnTransfer: true,
        tablesToReturn: [
          {
            'id': fromId,
            'table_number': '1',
            'name': 'Table 1',
            'capacity': 4,
            'status': 'occupied',
            'section': 'Hall',
            'active_order_id': activeOrderId,
            'current_bill_amount': 2500.0,
          },
          {
            'id': toId,
            'table_number': '2',
            'name': 'Table 2',
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
          tablesApiServiceProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tableProvider.notifier);
      await notifier.loadTables();

      await notifier.transferTable(fromId, toId);

      // Verify fromTable in local SQLite is now available
      final fromTableDb = await (db.select(db.localRestaurantTables)..where((t) => t.id.equals(fromId))).getSingle();
      expect(fromTableDb.status, 'available');
      expect(fromTableDb.activeOrderId, isNull);

      // Verify toTable in local SQLite is now occupied with the transferred order
      final toTableDb = await (db.select(db.localRestaurantTables)..where((t) => t.id.equals(toId))).getSingle();
      expect(toTableDb.status, 'occupied');
      expect(toTableDb.activeOrderId, activeOrderId);

      // Verify 2 outbox mutations were queued for sync
      final outboxEntries = await db.select(db.syncOutbox).get();
      expect(outboxEntries.length, 2);
      expect(outboxEntries.any((e) => e.entityId == fromId && e.operationType == 'UPDATE'), isTrue);
      expect(outboxEntries.any((e) => e.entityId == toId && e.operationType == 'UPDATE'), isTrue);
    });

    test('SYNC-031: loadTables preserves local occupied table on cold restart when server returns available', () async {
      const tableId = '01918a22-3866-7000-8000-000000000004';
      const orderId = '01918a22-3866-7000-8000-000000000005';

      // Seed local SQLite with occupied table
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: Value('3'),
          name: Value('Table 3'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value(orderId),
          version: Value(2),
        ),
      ]);

      // Server returns available (stale snapshot or unsynced order)
      final fakeApi = FakeTablesApiService(tablesToReturn: [
        {
          'id': tableId,
          'table_number': '3',
          'name': 'Table 3',
          'capacity': 4,
          'status': 'available',
          'section': 'Hall',
          'current_bill_amount': 0,
        }
      ]);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tablesApiServiceProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tableProvider.notifier);
      await notifier.loadTables();

      final state = container.read(tableProvider);
      final table = state.tables.firstWhere((t) => t.id == tableId);

      // Must be preserved as occupied
      expect(table.status, TableStatus.occupied);
      expect(table.activeOrderId, orderId);
    });
  });
}
