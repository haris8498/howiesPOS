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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('SYNC-020: Server Order Number Suffix Reassignment Tests', () {
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

    test('reassigned_order_number with status APPLIED updates local orderNumber upon ACK', () async {
      final orderId = uuid.v7();
      final opId = uuid.v7();

      // Seed local order with initial orderNumber 'P1-101'
      await db.into(db.localOrders).insert(
        LocalOrdersCompanion(
          id: Value(orderId),
          orderNumber: const Value('P1-101'),
          orderType: const Value('takeaway'),
          subtotal: const Value(1000.0),
          grandTotal: const Value(1000.0),
          deviceId: const Value('POS-01'),
          syncStatus: const Value('pending_insert'),
        ),
      );

      // Seed outbox mutation
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(orderId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-101"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      // Mock server returning APPLIED with reassigned_order_number 'P1-101-1'
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.contains('/push')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'results': [
                {
                  'operation_id': opId,
                  'entity_id': orderId,
                  'status': 'APPLIED',
                  'server_version': 1,
                  'server_timestamp': DateTime.now().toIso8601String(),
                  'order_number': 'P1-101-1',
                  'reassigned_order_number': 'P1-101-1',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"ok"}', 200, headers: {'content-type': 'application/json'});
      });

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
        httpClient: mockHttpClient,
      );

      await worker.triggerPush();

      // Verify outbox entry is SYNCED
      final outboxRow = await (db.select(db.syncOutbox)..where((t) => t.id.equals(1))).getSingle();
      expect(outboxRow.status, SyncOutboxStatus.synced);

      // Verify local order was updated to 'P1-101-1' and syncStatus is 'synced'
      final localOrder = await db.ordersDao.getOrderById(orderId);
      expect(localOrder, isNotNull);
      expect(localOrder!.orderNumber, 'P1-101-1');
      expect(localOrder.syncStatus, 'synced');

      worker.stop();
      worker.dispose();
    });
  });
}
