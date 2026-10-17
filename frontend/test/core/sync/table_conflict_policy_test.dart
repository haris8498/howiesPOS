import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_conflicts_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';

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

    requestHandler = (request) async {
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

  group('Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3)', () {
    test('1. Auto-resolves CONFLICT per policy when server active order wins: updates local row to server state and marks outbox SYNCED', () async {
      final tableId = const Uuid().v7();
      final opId = const Uuid().v7();

      // Setup initial local table in Drift (e.g. Cashier had marked it reserved offline)
      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('4'),
          name: const Value('Table 4'),
          capacity: const Value(4),
          status: const Value('reserved'),
          activeOrderId: const Value(null),
          version: const Value(1),
        ),
      ]);

      // Enqueue an outbox mutation for table update with 36-char UUIDs
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('table'),
          entityId: Value(tableId),
          operationType: const Value('UPDATE'),
          baseVersion: const Value(1),
          payload: const Value('{"status": "reserved", "reserved_customer_name": "Walk-in Offline"}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Server responds with CONFLICT (active order exists on server, auto_resolvable = true)
      requestHandler = (request) async {
        if (request.uri.path == '/sync/push') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'batch_id': 'b-1',
            'results': [
              {
                'operation_id': opId,
                'entity_id': tableId,
                'status': 'CONFLICT',
                'server_version': 3,
                'server_timestamp': '2026-10-17T15:00:00.000Z',
                'error_message': 'Active order on Table 4 cannot be lost due to stale table update',
                'conflict_details': {
                  'conflict_code': 'ACTIVE_ORDER_PROTECTED',
                  'auto_resolvable': true,
                  'policy_action': 'REVERT_TO_SERVER_STATE',
                  'server_state': {
                    'id': tableId,
                    'table_number': '4',
                    'name': 'Table 4',
                    'capacity': 4,
                    'status': 'occupied',
                    'active_order_id': 'ord-server-active',
                    'version': 3,
                  },
                },
              }
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: 'POS-P1',
        syncUrlOverride: serverUrl,
      );

      await worker.triggerPush();

      // Verify outbox entry is now marked SYNCED per policy!
      final outboxEntry = await db.outboxDao.getEntryByOperationId(opId);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.status, equals(SyncOutboxStatus.synced));

      // Verify local table row is updated to server state
      final localTable = await db.catalogDao.getTableById(tableId);
      expect(localTable, isNotNull);
      expect(localTable!.status, equals('occupied'));
      expect(localTable.activeOrderId, equals('ord-server-active'));
      expect(localTable.version, equals(3));

      // Verify audit record in sync_conflicts is marked AUTO_RESOLVED
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.length, equals(1));
      expect(conflicts.first.resolutionStatus, equals(ConflictResolutionStatus.autoResolved));
      expect(conflicts.first.conflictType, equals('ACTIVE_ORDER_PROTECTED'));

      worker.dispose();
    });

    test('2. Quarantines non-auto-resolvable CONFLICT in sync_conflicts and surfaces supervisory badge state', () async {
      final tableId = const Uuid().v7();
      final opId = const Uuid().v7();

      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('9'),
          name: const Value('Table 9'),
          capacity: const Value(4),
          status: const Value('available'),
          version: const Value(1),
        ),
      ]);

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('table'),
          entityId: Value(tableId),
          operationType: const Value('UPDATE'),
          baseVersion: const Value(1),
          payload: const Value('{"status": "reserved", "reserved_customer_name": "Terminal 1 Client"}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Server responds with non-resolvable OCC_MISMATCH conflict
      requestHandler = (request) async {
        if (request.uri.path == '/sync/push') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'batch_id': 'b-2',
            'results': [
              {
                'operation_id': opId,
                'entity_id': tableId,
                'status': 'CONFLICT',
                'server_version': 2,
                'server_timestamp': '2026-10-17T15:30:00.000Z',
                'error_message': 'OCC Version Conflict: Table 9 was modified on server',
                'conflict_details': {
                  'conflict_code': 'OCC_VERSION_MISMATCH',
                  'auto_resolvable': false,
                  'server_state': {
                    'id': tableId,
                    'table_number': '9',
                    'name': 'Table 9',
                    'status': 'reserved',
                    'reserved_customer_name': 'Terminal 2 Client',
                    'version': 2,
                  },
                },
              }
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: 'POS-P1',
        syncUrlOverride: serverUrl,
      );

      await worker.triggerPush();

      // Verify outbox entry is marked CONFLICT
      final outboxEntry = await db.outboxDao.getEntryByOperationId(opId);
      expect(outboxEntry, isNotNull);
      expect(outboxEntry!.status, equals(SyncOutboxStatus.conflict));

      // Verify quarantined in sync_conflicts with resolutionStatus = PENDING
      final conflicts = await (db.select(db.syncConflicts)..where((t) => t.operationId.equals(opId))).get();
      expect(conflicts.length, equals(1));
      expect(conflicts.first.resolutionStatus, equals(ConflictResolutionStatus.pending));
      expect(conflicts.first.conflictType, equals('OCC_VERSION_MISMATCH'));
      expect(conflicts.first.serverState, contains('Terminal 2 Client'));

      // Test Riverpod provider state reflection
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncBackgroundWorkerProvider.overrideWithValue(worker),
          connectivityNotifierProvider.overrideWith((ref) => connectivityNotifier),
        ],
      );

      // Verify unresolved conflict count
      final conflictCount = await container.read(unresolvedConflictCountProvider.future);
      expect(conflictCount, equals(1));

      // Verify supervisory badge provider surfaces badge
      final badge = container.read(syncConflictBadgeProvider);
      expect(badge.hasConflict, isTrue);
      expect(badge.conflictCount, equals(1));
      expect(badge.label, equals('1 Conflict Detected'));

      // Verify sync indicator view model surfaces conflict state
      final indicator = container.read(syncIndicatorProvider);
      expect(indicator.state, equals(SyncIndicatorState.conflict));
      expect(indicator.label, equals('1 Conflict Detected'));

      container.dispose();
      worker.dispose();
    });

    test('3. Pull side: applies table changes ONLY when version is newer', () async {
      final tableId = const Uuid().v7();

      // Local table starts at version 3
      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('OCC-1'),
          name: const Value('OCC Table'),
          capacity: const Value(4),
          status: const Value('occupied'),
          version: const Value(3),
        ),
      ]);

      // Set cursor sequence in Drift
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 10);

      // Server returns an older change (v2) which must be ignored
      requestHandler = (request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 12,
            'next_cursor': 12,
            'has_more': false,
            'changes': [
              {
                'sequence': 11,
                'entity_type': 'restaurant_table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 2, // Older! Should be ignored
                'payload': {
                  'status': 'available',
                  'table_number': 'OCC-1',
                  'name': 'OCC Table',
                  'version': 2,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: 'POS-P1',
        syncUrlOverride: serverUrl,
      );

      // Trigger pull for older version (2)
      await worker.triggerPull();

      var currentTable = await db.catalogDao.getTableById(tableId);
      expect(currentTable!.version, equals(3));
      expect(currentTable.status, equals('occupied')); // Untouched!

      // Now server sends newer version (4)
      requestHandler = (request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 15,
            'next_cursor': 15,
            'has_more': false,
            'changes': [
              {
                'sequence': 15,
                'entity_type': 'restaurant_table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 4, // Newer! Should be applied
                'payload': {
                  'status': 'available',
                  'table_number': 'OCC-1',
                  'name': 'OCC Table Updated',
                  'version': 4,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      await worker.triggerPull();

      currentTable = await db.catalogDao.getTableById(tableId);
      expect(currentTable!.version, equals(4));
      expect(currentTable.name, equals('OCC Table Updated'));

      worker.dispose();
    });

    test('4. Pull side: ignores echo of own writes via device_id and operation_id', () async {
      final tableId = const Uuid().v7();
      final ownOpId = const Uuid().v7();

      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('E-1'),
          name: const Value('Echo Table'),
          capacity: const Value(4),
          status: const Value('occupied'),
          version: const Value(1),
        ),
      ]);

      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 20);

      // Insert matching outbox entry for operation_id
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: Value(ownOpId),
          deviceId: const Value('POS-P1'),
          entityType: const Value('table'),
          entityId: Value(tableId),
          operationType: const Value('UPDATE'),
          baseVersion: const Value(1),
          payload: const Value('{}'),
          status: const Value(SyncOutboxStatus.synced),
        ),
      );

      // Server pull returns a change containing own deviceId and operationId
      requestHandler = (request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 25,
            'next_cursor': 25,
            'has_more': false,
            'changes': [
              {
                'sequence': 21,
                'entity_type': 'table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 5,
                'payload': {
                  'origin_device_id': 'POS-P1', // Own device!
                  'operation_id': ownOpId,
                  'name': 'SHOULD_NOT_BE_APPLIED',
                  'version': 5,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: 'POS-P1',
        syncUrlOverride: serverUrl,
      );

      await worker.triggerPull();

      final table = await db.catalogDao.getTableById(tableId);
      expect(table, isNotNull);
      expect(table!.name, equals('Echo Table')); // Not modified because echo was ignored!

      worker.dispose();
    });

    test('5. Pull side: Hospitality Priority preserves local seated guests when active local order exists', () async {
      final tableId = const Uuid().v7();

      // Local table is occupied with active local order
      await db.catalogDao.upsertRestaurantTables([
        LocalRestaurantTablesCompanion(
          id: Value(tableId),
          tableNumber: const Value('H-1'),
          name: const Value('Hospitality Table'),
          capacity: const Value(4),
          status: const Value('occupied'),
          activeOrderId: const Value('local-ord-1'),
          version: const Value(1),
        ),
      ]);

      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 30);

      // Server pull says table is now 'available' or 'reserved' at higher version
      requestHandler = (request) async {
        if (request.uri.path == '/sync/pull') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'cursor': 35,
            'next_cursor': 35,
            'has_more': false,
            'changes': [
              {
                'sequence': 31,
                'entity_type': 'restaurant_table',
                'entity_id': tableId,
                'operation': 'UPDATE',
                'record_version': 2,
                'payload': {
                  'origin_device_id': 'OTHER-POS',
                  'status': 'available', // Remote attempted to free the table!
                  'active_order_id': null,
                  'table_number': 'H-1',
                  'name': 'Hospitality Table',
                  'version': 2,
                },
              },
            ],
          }));
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      };

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        deviceId: 'POS-P1',
        syncUrlOverride: serverUrl,
      );

      await worker.triggerPull();

      // Physical seated guests cannot be evicted!
      final table = await db.catalogDao.getTableById(tableId);
      expect(table, isNotNull);
      expect(table!.status, equals('occupied'));
      expect(table.activeOrderId, equals('local-ord-1'));
      expect(table.version, equals(2));

      worker.dispose();
    });
  });
}
