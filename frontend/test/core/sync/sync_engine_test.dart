import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late List<Map<String, dynamic>> receivedPushBatches;

  // Custom handler to simulate various server scenarios
  late Future<void> Function(HttpRequest request) requestHandler;

  setUp(() async {
    // Enable real HTTP requests for loopback server in Flutter test environment
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});

    // 1. In-memory SQLite Drift database
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    // 2. Ephemeral loopback HTTP server
    fakeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${fakeServer.port}';
    receivedPushBatches = [];

    // Default request handler
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
    connectivityNotifier.dispose();
    await fakeServer.close(force: true);
    await db.close();
  });

  SyncBackgroundWorker createWorker({
    Duration circuitBreakerPauseDuration = const Duration(milliseconds: 100),
    Duration pollInterval = const Duration(seconds: 30),
    Duration zombieTimeout = const Duration(seconds: 60),
  }) {
    return SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
      syncUrlOverride: serverUrl,
      circuitBreakerPauseDuration: circuitBreakerPauseDuration,
      pollInterval: pollInterval,
      zombieTimeout: zombieTimeout,
    );
  }

  group('SyncBackgroundWorker Core Tests', () {
    test('1. Ordering: mutations are pushed strictly sorted by dependency_order then created_at', () async {
      final worker = createWorker();

      // Enqueue 3 mutations with disordered dependency_order
      // Level 2 (Order Header)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000002'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000022'),
          operationType: const Value('INSERT'),
          dependencyOrder: const Value(2),
          payload: const Value('{"order_number": "P1-102"}'),
          createdAt: Value(DateTime.now().add(const Duration(seconds: 1))),
        ),
      );

      // Level 0 (Shift Session)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000000'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('shift'),
          entityId: const Value('019283a0-0000-7000-8000-000000000020'),
          operationType: const Value('INSERT'),
          dependencyOrder: const Value(0),
          payload: const Value('{"cashier_id": "c-1"}'),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Level 3 (Line Items)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000003'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order_item'),
          entityId: const Value('019283a0-0000-7000-8000-000000000023'),
          operationType: const Value('INSERT'),
          dependencyOrder: const Value(3),
          payload: const Value('{"item_name": "Pizza"}'),
          createdAt: Value(DateTime.now().add(const Duration(seconds: 2))),
        ),
      );

      await worker.triggerPush();

      expect(receivedPushBatches.length, 1);
      final pushedMutations = receivedPushBatches.first['mutations'] as List;
      expect(pushedMutations.length, 3);

      // Verify strict dependency ordering: Level 0 -> Level 2 -> Level 3
      expect(pushedMutations[0]['entity_type'], 'shift');
      expect(pushedMutations[0]['dependency_order'], 0);
      expect(pushedMutations[1]['entity_type'], 'order');
      expect(pushedMutations[1]['dependency_order'], 2);
      expect(pushedMutations[2]['entity_type'], 'order_item');
      expect(pushedMutations[2]['dependency_order'], 3);

      // Verify all outbox entries were updated to SYNCED
      final entries = await db.outboxDao.getAllEntries();
      for (final e in entries) {
        expect(e.status, SyncOutboxStatus.synced);
        expect(e.ackedAt, isNotNull);
      }

      worker.dispose();
    });

    test('2. Retry & Backoff: HTTP 500 increments retryCount and computes jittered nextRetryAt', () async {
      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          req.response.statusCode = 500;
          req.response.write('Internal Server Error');
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker();

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000010'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000011'),
          operationType: const Value('INSERT'),
          dependencyOrder: const Value(1),
          payload: const Value('{"order_number": "P1-110"}'),
        ),
      );

      final before = DateTime.now();
      await worker.triggerPush();

      final entry = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000010');
      expect(entry, isNotNull);
      expect(entry!.status, SyncOutboxStatus.failedRetryable);
      expect(entry.retryCount, 1);
      expect(entry.nextRetryAt, isNotNull);

      // Spec §6.4 formula: min(300, 2.0 * 2^0) * [0.75, 1.25] = 1.5s to 2.5s delay
      // Account for Drift SQLite integer-second resolution truncation on DateTimeColumn
      final delaySeconds = entry.nextRetryAt!.difference(before).inSeconds;
      expect(delaySeconds >= 1, isTrue);
      expect(delaySeconds <= 4, isTrue);

      // getPushBatch() must exclude this non-due item right now
      final dueNow = await db.outboxDao.getPushBatch(now: DateTime.now());
      expect(dueNow.isEmpty, isTrue);

      // getPushBatch() must include it once simulated clock passes nextRetryAt
      final dueFuture = await db.outboxDao.getPushBatch(now: DateTime.now().add(const Duration(seconds: 5)));
      expect(dueFuture.length, 1);

      worker.dispose();
    });

    test('3. Circuit Breaker: 5 consecutive failures pause queue, reset on health probe', () async {
      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          req.response.statusCode = 503;
          req.response.write('Service Unavailable');
          await req.response.close();
          return;
        }
        if (req.uri.path == '/health') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({'success': true, 'status': 'ok'}));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker(
        circuitBreakerPauseDuration: const Duration(milliseconds: 150),
      );

      // Enqueue one mutation
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000020'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000021'),
          operationType: const Value('INSERT'),
          dependencyOrder: const Value(1),
          payload: const Value('{"order_number": "P1-120"}'),
        ),
      );

      // Simulate 5 consecutive push attempts
      for (int i = 0; i < 5; i++) {
        // Force status back to PENDING so getPushBatch will pick it for the test
        await (db.update(db.syncOutbox)..where((t) => t.id.equals(1))).write(
          const SyncOutboxCompanion(status: Value(SyncOutboxStatus.pending)),
        );
        await worker.triggerPush();
      }

      // Circuit breaker should be tripped
      expect(worker.state.consecutiveTimeouts, 5);
      expect(worker.state.isCircuitBreakerTripped, isTrue);
      expect(worker.state.status, SyncWorkerStatus.circuitBreakerTripped);

      // Further pushes are blocked while breaker is tripped
      await worker.triggerPush();
      expect(worker.state.isCircuitBreakerTripped, isTrue);

      // Wait for pause duration (150ms) to trigger automated probeHealth()
      await Future.delayed(const Duration(milliseconds: 250));

      // Circuit breaker should have reset upon probe success
      expect(worker.state.isCircuitBreakerTripped, isFalse);
      expect(worker.state.consecutiveTimeouts, 0);

      worker.dispose();
    });

    test('4. Startup Crash Recovery: Zombie tasks left IN_FLIGHT older than 60s reset to PENDING', () async {
      final worker = createWorker();

      final now = DateTime.now();

      // Zombie task: left IN_FLIGHT 90 seconds ago
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000031'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000041'),
          operationType: const Value('INSERT'),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(now.subtract(const Duration(seconds: 90))),
          payload: const Value('{}'),
        ),
      );

      // Recent task: left IN_FLIGHT 10 seconds ago (active transmission, not a zombie)
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000032'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000042'),
          operationType: const Value('INSERT'),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(now.subtract(const Duration(seconds: 10))),
          payload: const Value('{}'),
        ),
      );

      final recovered = await worker.recoverOrphanedOutboxTasks(olderThan: const Duration(seconds: 60));
      expect(recovered, 1);

      final task31 = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000031');
      expect(task31!.status, SyncOutboxStatus.pending);

      final task32 = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000032');
      expect(task32!.status, SyncOutboxStatus.inFlight);

      worker.dispose();
    });

    test('5. Poison-Pill Isolation: Fatal mutation is quarantined to sync_conflicts without blocking batch', () async {
      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'batch_id': 'batch-poison',
            'processed_count': 2,
            'results': [
              {
                'operation_id': '019283a0-0000-7000-8000-000000000051',
                'entity_id': '019283a0-0000-7000-8000-000000000061',
                'status': 'SYNCED',
                'server_version': 2,
                'server_timestamp': DateTime.now().toIso8601String(),
              },
              {
                'operation_id': '019283a0-0000-7000-8000-000000000052',
                'entity_id': '019283a0-0000-7000-8000-000000000062',
                'status': 'FAILED_FATAL',
                'error_message': 'Constraint violation: invalid SKU code',
                'server_version': 1,
                'server_timestamp': DateTime.now().toIso8601String(),
              },
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker();

      // Mutation 1: Valid order
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000051'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000061'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number": "P1-201"}'),
        ),
      );

      // Mutation 2: Poison pill
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000052'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000062'),
          operationType: const Value('INSERT'),
          payload: const Value('{"bad": "data"}'),
        ),
      );

      await worker.triggerPush();

      // Valid mutation should be SYNCED
      final validEntry = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000051');
      expect(validEntry!.status, SyncOutboxStatus.synced);

      // Poison pill should be FAILED_FATAL
      final poisonEntry = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000052');
      expect(poisonEntry!.status, SyncOutboxStatus.failedFatal);
      expect(poisonEntry.lastError, contains('invalid SKU code'));

      // Check quarantine table sync_conflicts
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.length, 1);
      expect(conflicts.first.operationId, '019283a0-0000-7000-8000-000000000052');
      expect(conflicts.first.conflictType, ConflictType.fatalError);

      worker.dispose();
    });

    test('6. 401 Pause / Resume: HTTP 401 transitions outbox to AUTH_PAUSED; resumeAuthPaused restores queue', () async {
      int requestCount = 0;

      requestHandler = (req) async {
        if (req.uri.path == '/sync/push') {
          requestCount++;
          if (requestCount == 1) {
            // First attempt: Token expired
            req.response.statusCode = 401;
            req.response.write('Unauthorized: token expired');
            await req.response.close();
            return;
          } else {
            // Subsequent attempt after token refresh: Success
            req.response.statusCode = 200;
            req.response.headers.contentType = ContentType.json;
            req.response.write(jsonEncode({
              'success': true,
              'batch_id': 'b-reauth',
              'processed_count': 1,
              'results': [
                {
                  'operation_id': '019283a0-0000-7000-8000-000000000071',
                  'entity_id': '019283a0-0000-7000-8000-000000000081',
                  'status': 'SYNCED',
                  'server_version': 1,
                  'server_timestamp': DateTime.now().toIso8601String(),
                }
              ]
            }));
            await req.response.close();
            return;
          }
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      final worker = createWorker();

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0000-7000-8000-000000000071'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0000-7000-8000-000000000081'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number": "P1-300"}'),
        ),
      );

      // 1. First push attempt triggers 401
      await worker.triggerPush();

      expect(worker.state.isAuthPaused, isTrue);
      expect(worker.state.status, SyncWorkerStatus.authPaused);

      final entry = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000071');
      expect(entry!.status, SyncOutboxStatus.authPaused);

      // Verify zero entries quarantined to sync_conflicts (Approved Deviation #3)
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.isEmpty, isTrue);

      // Triggering push while paused does nothing
      await worker.triggerPush();
      expect(requestCount, 1);

      // 2. Resume auth paused (simulates cashier re-login or token renewal)
      await worker.resumeAuthPaused();

      expect(worker.state.isAuthPaused, isFalse);
      expect(requestCount, 2);

      final syncedEntry = await db.outboxDao.getEntryByOperationId('019283a0-0000-7000-8000-000000000071');
      expect(syncedEntry!.status, SyncOutboxStatus.synced);

      worker.dispose();
    });

    test('7. Stale-Version Ignore & Duplicate Pull: incoming delta with version <= local is ignored', () async {
      final worker = createWorker();

      // Seed local table with Table 4 at version 5
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value('table-4'),
          tableNumber: Value('4'),
          name: Value('Booth 4'),
          status: Value('available'),
          version: Value(5),
        ),
      ]);

      // Seed global pull cursor to 10
      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 10);

      // Setup fake server for /sync/pull
      requestHandler = (req) async {
        if (req.uri.path == '/sync/pull') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 12,
            'next_cursor': 12,
            'has_more': false,
            'changes': [
              // Stale change: version 4 (should be ignored)
              {
                'sequence': 11,
                'entity_type': 'restaurant_table',
                'entity_id': 'table-4',
                'operation': 'UPDATE',
                'record_version': 4,
                'is_deleted': false,
                'payload': {'name': 'STALE NAME V4', 'status': 'occupied'},
              },
              // Duplicate change: version 5 (equal, should be ignored)
              {
                'sequence': 12,
                'entity_type': 'restaurant_table',
                'entity_id': 'table-4',
                'operation': 'UPDATE',
                'record_version': 5,
                'is_deleted': false,
                'payload': {'name': 'DUPLICATE NAME V5', 'status': 'occupied'},
              },
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      await worker.triggerPull();

      // Table 4 should remain untouched at version 5 with original name
      var table = await db.catalogDao.getTableById('table-4');
      expect(table!.name, 'Booth 4');
      expect(table.version, 5);

      // Now simulate a newer change: version 6
      requestHandler = (req) async {
        if (req.uri.path == '/sync/pull') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 13,
            'next_cursor': 13,
            'has_more': false,
            'changes': [
              {
                'sequence': 13,
                'entity_type': 'restaurant_table',
                'entity_id': 'table-4',
                'operation': 'UPDATE',
                'record_version': 6,
                'is_deleted': false,
                'payload': {'name': 'NEW NAME V6', 'status': 'available'},
              },
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      await worker.triggerPull();

      table = await db.catalogDao.getTableById('table-4');
      expect(table!.name, 'NEW NAME V6');
      expect(table.version, 6);

      // Verify cursor moved to 13
      final cursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      expect(cursor, 13);

      worker.dispose();
    });

    test('8. Hospitality Operational Priority: Seated walk-in guest on POS wins over remote reservation (§10.2)', () async {
      final worker = createWorker();

      // Seed local Table 2 with active walk-in guests seated by cashier
      await db.catalogDao.upsertRestaurantTables([
        const LocalRestaurantTablesCompanion(
          id: Value('table-2'),
          tableNumber: Value('2'),
          name: Value('Window Table 2'),
          status: Value('occupied'),
          activeOrderId: Value('019283a0-ord-walkin'),
          version: Value(1),
        ),
      ]);

      await db.syncCursorsDao.setCursor('GLOBAL_PULL_CURSOR', 50);

      // Cloud sends delta attempting to mark Table 2 as 'reserved' or 'available'
      requestHandler = (req) async {
        if (req.uri.path == '/sync/pull') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'success': true,
            'cursor': 51,
            'next_cursor': 51,
            'has_more': false,
            'changes': [
              {
                'sequence': 51,
                'entity_type': 'restaurant_table',
                'entity_id': 'table-2',
                'operation': 'UPDATE',
                'record_version': 2,
                'is_deleted': false,
                'payload': {
                  'status': 'reserved',
                  'active_order_id': null,
                },
              },
            ],
          }));
          await req.response.close();
          return;
        }
        req.response.statusCode = 404;
        await req.response.close();
      };

      await worker.triggerPull();

      // Hospitality Priority: Table 2 remains OCCUPIED with active walk-in order
      final table = await db.catalogDao.getTableById('table-2');
      expect(table!.status, 'occupied');
      expect(table.activeOrderId, '019283a0-ord-walkin');
      expect(table.version, 2);

      worker.dispose();
    });

    test('9. Cold-Start Bootstrap: Hydrates catalog tables when cursor is 0 (§8.1.3)', () async {
      requestHandler = (req) async {
        if (req.uri.path == '/sync/bootstrap') {
          req.response.statusCode = 200;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode({
            'max_global_sequence': 48200,
            'server_timestamp': DateTime.now().toIso8601String(),
            'store_settings': [
              {
                'id': 'store-1',
                'chain_name': 'Hungry Howies',
                'branch_code': 'HH-MAIN',
                'branch_name': 'Downtown Branch',
                'store_phone': '+1-800-HOWIES',
                'tax_percentage': 5.0,
              }
            ],
            'categories': [
              {'id': 'cat-1', 'name': 'Pizzas', 'display_order': 1, 'is_active': true},
              {'id': 'cat-2', 'name': 'Beverages', 'display_order': 2, 'is_active': true},
            ],
            'menu_items': [
              {
                'id': 'item-101',
                'category_id': 'cat-1',
                'name': 'Howie Special Pizza',
                'base_price': 15.99,
                'is_available': true,
              }
            ],
            'tables': [
              {
                'id': 'table-10',
                'table_number': '10',
                'name': 'Patio 10',
                'capacity': 6,
                'status': 'available',
                'version': 1,
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

      // Verify cursor is 0
      final beforeCursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      expect(beforeCursor, 0);

      final success = await worker.bootstrapInitialData();
      expect(success, isTrue);

      // Verify catalog tables hydrated
      final categories = await db.catalogDao.getAllCategories();
      expect(categories.length, 2);
      expect(categories[0].name, 'Pizzas');

      final items = await db.catalogDao.getAllMenuItems();
      expect(items.length, 1);
      expect(items.first.name, 'Howie Special Pizza');

      final tables = await db.catalogDao.getAllTables();
      expect(tables.length, 1);
      expect(tables.first.name, 'Patio 10');

      final settings = await db.catalogDao.getStoreSettings();
      expect(settings!.branchCode, 'HH-MAIN');

      // Verify cursor seeded to 48200
      final afterCursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      expect(afterCursor, 48200);

      worker.dispose();
    });

    test('10. ConnectivityNotifier: probes /api/health and updates online/offline state', () async {
      final notifier = ConnectivityNotifier(
        healthEndpointOverride: '$serverUrl/health',
      );

      // Probe healthy server
      final isHealthy = await notifier.probeHealth();
      expect(isHealthy, isTrue);
      expect(notifier.isOnline, isTrue);
      expect(notifier.currentState.latencyMs, isNotNull);
      expect(notifier.currentState.consecutiveFailures, 0);

      // Simulate server failure
      requestHandler = (req) async {
        req.response.statusCode = 503;
        await req.response.close();
      };

      final isHealthyAfterFailure = await notifier.probeHealth();
      expect(isHealthyAfterFailure, isFalse);
      expect(notifier.isOnline, isFalse);
      expect(notifier.currentState.consecutiveFailures, 1);

      notifier.dispose();
    });

    test('11. Riverpod Providers: exposes sync status, pending count, and indicator view model', () async {
      final testConnectivity = ConnectivityNotifier(
        healthEndpointOverride: '$serverUrl/health',
      );
      testConnectivity.setOnlineManually();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          connectivityNotifierProvider.overrideWith((ref) => testConnectivity),
          syncBackgroundWorkerProvider.overrideWith((ref) {
            return SyncBackgroundWorker(
              db: db,
              connectivityNotifier: testConnectivity,
              syncUrlOverride: serverUrl,
            );
          }),
        ],
      );

      // Read providers
      final worker = container.read(syncBackgroundWorkerProvider);
      final syncState = container.read(syncStateProvider);
      final indicator = container.read(syncIndicatorProvider);

      expect(worker, isNotNull);
      expect(syncState.isIdle, isTrue);
      expect(indicator.state, SyncIndicatorState.allSynced);
      expect(indicator.label, 'All Synced');

      container.dispose();
    });
  });
}
