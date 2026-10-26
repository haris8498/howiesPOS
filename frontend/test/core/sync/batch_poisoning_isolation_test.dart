import 'dart:convert';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('SYNC-018: Invariant #3 - No Batch Poisoning Isolation Tests', () {
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

    test('HTTP 400 on multi-item batch isolates the poison pill without failing valid mutations', () async {
      final validOpId = uuid.v7();
      final poisonOpId = uuid.v7();
      final validEntityId = uuid.v7();
      final poisonEntityId = uuid.v7();

      // Seed 2 mutations: 1 valid, 1 poison pill
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(validOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(validEntityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-101"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(poisonOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(poisonEntityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"malformed":true}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // Mock client that returns 400 if the request includes poisonOpId in a batch with other items,
      // returns 400 if poisonOpId is sent alone,
      // and returns 200 OK for validOpId alone.
      final mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final mutations = body['mutations'] as List<dynamic>;

        final hasPoison = mutations.any((m) => m['operation_id'] == poisonOpId);
        final hasValid = mutations.any((m) => m['operation_id'] == validOpId);

        if (hasPoison && mutations.length > 1) {
          // Entire batch fails with HTTP 400 Bad Request
          return http.Response(
            jsonEncode({'message': 'Validation failed: malformed field detected'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        } else if (hasPoison) {
          // Poison alone fails 400
          return http.Response(
            jsonEncode({'message': 'Validation failed: malformed field detected'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        } else if (hasValid) {
          // Valid alone succeeds 200 OK
          return http.Response(
            jsonEncode({
              'success': true,
              'results': [
                {
                  'operation_id': validOpId,
                  'entity_id': validEntityId,
                  'status': 'SYNCED',
                  'server_version': 1,
                  'server_timestamp': DateTime.now().toIso8601String(),
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        httpClient: mockHttpClient,
        syncUrlOverride: 'http://localhost:3000/api',
      );

      try {
        // Run push
        await worker.triggerPush(force: true);

        // Query outbox
        final validRow = await (db.select(db.syncOutbox)..where((t) => t.operationId.equals(validOpId))).getSingle();
        final poisonRow = await (db.select(db.syncOutbox)..where((t) => t.operationId.equals(poisonOpId))).getSingle();

        // Verify valid row is SYNCED
        expect(validRow.status, equals(SyncOutboxStatus.synced));

        // Verify poison row is FAILED_FATAL
        expect(poisonRow.status, equals(SyncOutboxStatus.failedFatal));

        // Verify only poison row was quarantined in sync_conflicts
        final conflicts = await db.select(db.syncConflicts).get();
        expect(conflicts.length, equals(1));
        expect(conflicts.first.operationId, equals(poisonOpId));
      } finally {
        worker.dispose();
      }
    });
  });
}
