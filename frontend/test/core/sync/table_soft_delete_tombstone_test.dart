import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/domain/models/restaurant_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HttpServer fakeServer;
  late String serverUrl;
  late ConnectivityNotifier connectivityNotifier;

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

    fakeServer.listen((req) async {
      req.response.statusCode = 404;
      await req.response.close();
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
      deviceId: 'POS-TEST-01',
    );
  }

  group('SYNC-012 / TBL-12: Soft-Delete Dining Tables Tombstone Apply Tests', () {
    test('1. Tombstone apply WITHOUT local open order: marks table is_deleted=true and excludes from active grid', () async {
      final worker = createWorker();
      const tableId = 'tbl-empty-001';

      // Seed available table in local Drift database
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: Value('T-10'),
          name: Value('Table 10'),
          capacity: Value(4),
          status: Value('available'),
          activeOrderId: Value(null),
          version: Value(1),
          isDeleted: Value(false),
        ),
      ]);

      final initialTable = await db.catalogDao.getTableById(tableId);
      expect(initialTable, isNotNull);
      expect(initialTable!.isDeleted, isFalse);

      // Verify getAllTables() returns it before deletion
      final activeBefore = await db.catalogDao.getAllTables();
      expect(activeBefore.any((t) => t.id == tableId), isTrue);

      // Delta pull change: tombstone for Table 10 (deleted on server)
      final tombstoneChange = {
        'sequence': 101,
        'entity_type': 'restaurant_table',
        'entity_id': tableId,
        'operation': 'DELETE',
        'record_version': 2,
        'is_deleted': true,
        'payload': {
          'id': tableId,
          'table_number': 'T-10',
          'name': 'Table 10',
          'is_deleted': true,
          'version': 2,
        },
        'created_at': DateTime.now().toIso8601String(),
      };

      // Apply pull delta
      final applyResult = await worker.applyPullChange(tombstoneChange);
      expect(applyResult, PullApplyResult.applied);

      // Verify Drift database record has is_deleted = true
      final updatedTable = await db.catalogDao.getTableById(tableId);
      expect(updatedTable, isNotNull);
      expect(updatedTable!.isDeleted, isTrue);

      // Default getAllTables() excludes soft-deleted table
      final activeAfter = await db.catalogDao.getAllTables();
      expect(activeAfter.any((t) => t.id == tableId), isFalse);

      // getAllTables(includeDeleted: true) preserves record
      final allWithDeleted = await db.catalogDao.getAllTables(includeDeleted: true);
      expect(allWithDeleted.any((t) => t.id == tableId), isTrue);

      // Grid filter logic: soft-deleted table with no open order is hidden from grid
      final restaurantTable = RestaurantTable(
        id: updatedTable.id,
        tableNumber: updatedTable.tableNumber,
        name: updatedTable.name,
        capacity: updatedTable.capacity,
        status: TableStatus.available,
        section: 'Hall',
        isDeleted: updatedTable.isDeleted,
      );

      final hasOpenOrder = restaurantTable.status == TableStatus.occupied ||
          (restaurantTable.activeOrderId != null && restaurantTable.currentBillAmount > 0);
      final isVisibleOnGrid = !restaurantTable.isDeleted || hasOpenOrder;
      expect(isVisibleOnGrid, isFalse, reason: 'Deleted table without open order must be hidden from grid');

      worker.dispose();
    });

    test('2. Tombstone apply WITH local open order: keeps table visible with REMOVED badge until settled', () async {
      final worker = createWorker();
      const tableId = 'tbl-occupied-002';
      const orderId = '019283a0-0000-7000-8000-000000000099';

      // 1. Seed local open order in Drift (taken while offline)
      await db.into(db.localOrders).insert(
        LocalOrdersCompanion(
          id: const Value(orderId),
          orderNumber: const Value('P1-105'),
          orderType: const Value('dineIn'),
          status: const Value('inProgress'),
          subtotal: const Value(2500.0),
          grandTotal: const Value(2500.0),
          isPaid: const Value(false),
          deviceId: const Value('POS-TEST-01'),
          syncStatus: const Value('pending_insert'),
        ),
      );

      // 2. Table has active local order
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: Value('T-05'),
          name: Value('Table 5'),
          capacity: Value(4),
          status: Value('occupied'),
          activeOrderId: Value(orderId),
          version: Value(1),
          isDeleted: Value(false),
        ),
      ]);

      // 3. Backend deletes table while client was offline; client reconnects and pulls tombstone
      final tombstoneChange = {
        'sequence': 202,
        'entity_type': 'restaurant_table',
        'entity_id': tableId,
        'operation': 'DELETE',
        'record_version': 2,
        'is_deleted': true,
        'payload': {
          'id': tableId,
          'table_number': 'T-05',
          'name': 'Table 5',
          'is_deleted': true,
          'version': 2,
        },
        'created_at': DateTime.now().toIso8601String(),
      };

      final applyResult = await worker.applyPullChange(tombstoneChange);
      expect(applyResult, PullApplyResult.applied);

      // 4. Verify table retains is_deleted=true AND remains occupied with activeOrderId preserved
      final driftTable = await db.catalogDao.getTableById(tableId);
      expect(driftTable, isNotNull);
      expect(driftTable!.isDeleted, isTrue, reason: 'Tombstone flag must be saved');
      expect(driftTable.status, equals('occupied'), reason: 'Occupancy must be preserved while local order is open');
      expect(driftTable.activeOrderId, equals(orderId), reason: 'activeOrderId must remain linked');

      // 5. Verify Grid Visibility & Badge Requirement
      final restaurantTable = RestaurantTable(
        id: driftTable.id,
        tableNumber: driftTable.tableNumber,
        name: driftTable.name,
        capacity: driftTable.capacity,
        status: TableStatus.occupied,
        activeOrderId: driftTable.activeOrderId,
        currentBillAmount: 2500.0,
        section: 'Hall',
        isDeleted: driftTable.isDeleted,
      );

      final hasOpenOrder = restaurantTable.status == TableStatus.occupied ||
          (restaurantTable.activeOrderId != null && restaurantTable.currentBillAmount > 0);
      final isVisibleOnGrid = !restaurantTable.isDeleted || hasOpenOrder;
      expect(isVisibleOnGrid, isTrue, reason: 'Soft-deleted table with open order MUST stay visible on grid');
      expect(restaurantTable.isDeleted, isTrue, reason: 'Table must have isDeleted true to display REMOVED badge');

      // 6. When the order is completed/paid, table is freed
      await (db.update(db.localRestaurantTables)..where((t) => t.id.equals(tableId))).write(
        const LocalRestaurantTablesCompanion(
          status: Value('available'),
          activeOrderId: Value(null),
        ),
      );

      final freedTable = await db.catalogDao.getTableById(tableId);
      expect(freedTable!.status, 'available');
      expect(freedTable.activeOrderId, isNull);

      final freedRestaurantTable = restaurantTable.copyWith(
        status: TableStatus.available,
        activeOrderId: null,
        currentBillAmount: 0.0,
      );

      final hasOpenOrderAfterPaid = freedRestaurantTable.status == TableStatus.occupied ||
          (freedRestaurantTable.activeOrderId != null && freedRestaurantTable.currentBillAmount > 0);
      final isVisibleAfterPaid = !freedRestaurantTable.isDeleted || hasOpenOrderAfterPaid;
      expect(isVisibleAfterPaid, isFalse, reason: 'Table must disappear from grid once open order is settled');

      worker.dispose();
    });
  });
}
