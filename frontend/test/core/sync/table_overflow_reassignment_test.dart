import 'dart:convert';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/table_reassignment_provider.dart';
import 'package:hungry_howies_pos/domain/models/restaurant_table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('SYNC-011 / TBL-02: Concurrent Offline Seating & Virtual Overflow Tables', () {
    late AppDatabase db;
    late ConnectivityNotifier connectivityNotifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      connectivityNotifier = ConnectivityNotifier(
        apiClient: ApiClient(baseUrl: 'http://localhost:3000'),
        probeTimeout: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      connectivityNotifier.dispose();
      await db.close();
    });

    test('Drift database schema version is 3 with overflow columns in LocalRestaurantTables', () async {
      expect(db.schemaVersion, 3);

      // Verify inserting and reading an overflow table in Drift
      await db.into(db.localRestaurantTables).insert(
        const LocalRestaurantTablesCompanion(
          id: Value('tbl-4-B'),
          tableNumber: Value('4-B'),
          name: Value('Table 4-B'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value('ord-collision-2'),
          isOverflow: Value(true),
          parentTableId: Value('tbl-4'),
          overflowSuffix: Value('B'),
        ),
      );

      final row = await (db.select(db.localRestaurantTables)..where((t) => t.id.equals('tbl-4-B'))).getSingle();
      expect(row.tableNumber, '4-B');
      expect(row.isOverflow, true);
      expect(row.parentTableId, 'tbl-4');
      expect(row.overflowSuffix, 'B');
      expect(row.status, 'occupied');
      expect(row.activeOrderId, 'ord-collision-2');
    });

    test('RestaurantTable domain model correctly serializes and deserializes overflow fields', () {
      final json = {
        'id': 'tbl-4-B',
        'table_number': '4-B',
        'name': 'Table 4-B',
        'capacity': 4,
        'status': 'occupied',
        'active_order_id': 'ord-test-1',
        'section': 'Hall',
        'is_overflow': true,
        'parent_table_id': 'tbl-4',
        'overflow_suffix': 'B',
      };

      final table = RestaurantTable.fromBackendJson(json);
      expect(table.id, 'tbl-4-B');
      expect(table.tableNumber, '4-B');
      expect(table.isOverflow, true);
      expect(table.parentTableId, 'tbl-4');
      expect(table.overflowSuffix, 'B');

      final serialized = table.toJson();
      expect(serialized['is_overflow'], true);
      expect(serialized['parent_table_id'], 'tbl-4');
      expect(serialized['overflow_suffix'], 'B');
    });

    test('SyncWorker creates overflow table 4-B and emits notification upon push ACK tableReassigned', () async {
      final orderId = uuid.v7();
      final opId = uuid.v7();
      const parentTableId = 'tbl-4';
      const overflowTableId = 'tbl-4-B';

      // 1. Seed base table (Table 4) in Drift
      await db.into(db.localRestaurantTables).insert(
        const LocalRestaurantTablesCompanion(
          id: Value(parentTableId),
          tableNumber: Value('4'),
          name: Value('Table 4'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value('initial-order'),
          isOverflow: Value(false),
          zoneId: Value('zone-1'),
        ),
      );

      // 2. Seed outbox mutation for order
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-02'),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('INSERT'),
          payload: Value(jsonEncode({
            'id': orderId,
            'table_id': parentTableId,
            'grand_total': 2000,
          })),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // 3. Mock server ACK with tableReassigned array
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/sync/push')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'batch_id': 'b-test-1',
              'processed_count': 1,
              'results': [
                {
                  'operation_id': opId,
                  'entity_id': orderId,
                  'status': 'APPLIED',
                  'server_version': 1,
                  'server_timestamp': DateTime.now().toIso8601String(),
                  'table_reassigned': {
                    'orderId': orderId,
                    'fromTableId': parentTableId,
                    'toTableId': overflowTableId,
                    'toLabel': '4-B',
                  },
                },
              ],
              'tableReassigned': [
                {
                  'orderId': orderId,
                  'fromTableId': parentTableId,
                  'toTableId': overflowTableId,
                  'toLabel': '4-B',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockClient,
      );

      final worker = SyncBackgroundWorker(
        db: db,
        apiClient: apiClient,
        httpClient: mockClient,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
      );

      TableReassignmentNotification? capturedNotif;
      final sub = TableReassignmentEventBus.stream.listen((notif) {
        capturedNotif = notif;
      });

      // 4. Trigger push drainage
      await worker.triggerPush();

      // 5. Verify overflow table was created in Drift
      final overflowRow = await (db.select(db.localRestaurantTables)
            ..where((t) => t.id.equals(overflowTableId)))
          .getSingleOrNull();

      expect(overflowRow, isNotNull);
      expect(overflowRow!.tableNumber, '4-B');
      expect(overflowRow.isOverflow, true);
      expect(overflowRow.parentTableId, parentTableId);
      expect(overflowRow.overflowSuffix, 'B');
      expect(overflowRow.status, 'occupied');
      expect(overflowRow.activeOrderId, orderId);
      expect(overflowRow.zoneId, 'zone-1');

      // 6. Verify notification event was emitted
      expect(capturedNotif, isNotNull);
      expect(capturedNotif!.orderId, orderId);
      expect(capturedNotif!.fromTableId, parentTableId);
      expect(capturedNotif!.toTableId, overflowTableId);
      expect(capturedNotif!.toLabel, '4-B');
      expect(capturedNotif!.message, 'Table 4 had two parties, one moved to 4-B');

      await sub.cancel();
      worker.dispose();
    });

    test('UI Floor Plan sorting orders overflow table 4-B immediately after Table 4', () {
      final tables = [
        const RestaurantTable(id: 'tbl-5', tableNumber: '5', name: 'Table 5', capacity: 4, status: TableStatus.available, section: 'Hall'),
        const RestaurantTable(id: 'tbl-4-B', tableNumber: '4-B', name: 'Table 4-B', capacity: 4, status: TableStatus.occupied, section: 'Hall', isOverflow: true, parentTableId: 'tbl-4'),
        const RestaurantTable(id: 'tbl-4', tableNumber: '4', name: 'Table 4', capacity: 4, status: TableStatus.occupied, section: 'Hall'),
        const RestaurantTable(id: 'tbl-1', tableNumber: '1', name: 'Table 1', capacity: 4, status: TableStatus.available, section: 'Hall'),
      ];

      // Sort using D-01 logic
      final sorted = List<RestaurantTable>.from(tables)..sort((a, b) {
        final aBase = a.isOverflow && a.parentTableId != null
            ? (tables.where((t) => t.id == a.parentTableId).firstOrNull?.tableNumber ?? a.tableNumber.split('-').first)
            : a.tableNumber.split('-').first;
        final bBase = b.isOverflow && b.parentTableId != null
            ? (tables.where((t) => t.id == b.parentTableId).firstOrNull?.tableNumber ?? b.tableNumber.split('-').first)
            : b.tableNumber.split('-').first;

        if (aBase != bBase) {
          final aNum = int.tryParse(aBase);
          final bNum = int.tryParse(bBase);
          if (aNum != null && bNum != null) return aNum.compareTo(bNum);
          return aBase.compareTo(bBase);
        }

        if (!a.isOverflow && b.isOverflow) return -1;
        if (a.isOverflow && !b.isOverflow) return 1;
        return a.tableNumber.compareTo(b.tableNumber);
      });

      expect(sorted.map((t) => t.tableNumber).toList(), ['1', '4', '4-B', '5']);
    });

    test('UI Floor Plan auto-hides empty / closed overflow tables', () {
      final tables = [
        // Parent table 4 occupied
        const RestaurantTable(id: 'tbl-4', tableNumber: '4', name: 'Table 4', capacity: 4, status: TableStatus.occupied, section: 'Hall', activeOrderId: 'ord-1', currentBillAmount: 1500),
        // Active overflow table 4-B occupied -> SHOULD SHOW
        const RestaurantTable(id: 'tbl-4-B', tableNumber: '4-B', name: 'Table 4-B', capacity: 4, status: TableStatus.occupied, section: 'Hall', isOverflow: true, parentTableId: 'tbl-4', activeOrderId: 'ord-2', currentBillAmount: 2000),
        // Closed overflow table 4-C available / no order -> SHOULD HIDE
        const RestaurantTable(id: 'tbl-4-C', tableNumber: '4-C', name: 'Table 4-C', capacity: 4, status: TableStatus.available, section: 'Hall', isOverflow: true, parentTableId: 'tbl-4', activeOrderId: null, currentBillAmount: 0),
      ];

      final filtered = tables.where((t) {
        if (t.isOverflow) {
          final hasActiveOrder = t.status == TableStatus.occupied || (t.activeOrderId != null && t.currentBillAmount > 0);
          if (!hasActiveOrder) return false;
        }
        return true;
      }).toList();

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.tableNumber).toList(), ['4', '4-B']);
      expect(filtered.any((t) => t.tableNumber == '4-C'), isFalse);
    });
  });
}
