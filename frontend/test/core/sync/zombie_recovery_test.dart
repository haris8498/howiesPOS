import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('SYNC-025: Zombie Task Recovery Tests', () {
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

    test('worker.start() unconditionally resets all IN_FLIGHT tasks to PENDING', () async {
      final opId = uuid.v7();
      // Insert in-flight task with fresh sentAt (just now)
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(opId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(DateTime.now()),
        ),
      );

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
      );

      await worker.start();
      worker.stop();

      final row = await (db.select(db.syncOutbox)..where((t) => t.operationId.equals(opId))).getSingle();
      expect(row.status, equals(SyncOutboxStatus.pending));
    });

    test('recoverOrphanedOutboxTasks recovers expired tasks and preserves fresh tasks', () async {
      final oldOpId = uuid.v7();
      final freshOpId = uuid.v7();

      // Old in-flight task (sent 5 minutes ago)
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(oldOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(1),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(DateTime.now().subtract(const Duration(minutes: 5))),
        ),
      );

      // Fresh in-flight task (sent 5 seconds ago)
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(freshOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.inFlight),
          sentAt: Value(DateTime.now().subtract(const Duration(seconds: 5))),
        ),
      );

      final worker = SyncBackgroundWorker(
        db: db,
        connectivityNotifier: connectivityNotifier,
        syncUrlOverride: 'http://localhost:3000/api',
      );

      final recovered = await worker.recoverOrphanedOutboxTasks(olderThan: const Duration(minutes: 2));
      expect(recovered, equals(1));

      final oldRow = await (db.select(db.syncOutbox)..where((t) => t.operationId.equals(oldOpId))).getSingle();
      final freshRow = await (db.select(db.syncOutbox)..where((t) => t.operationId.equals(freshOpId))).getSingle();

      expect(oldRow.status, equals(SyncOutboxStatus.pending));
      expect(freshRow.status, equals(SyncOutboxStatus.inFlight));
    });
  });
}
