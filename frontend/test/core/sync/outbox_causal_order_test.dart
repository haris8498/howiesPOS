import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uuid = Uuid();

  group('OBX-03: Outbox Causal Order & Retry Backoff Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('getPushBatch excludes pending UPDATE when earlier mutation is in retry backoff', () async {
      final entityId = uuid.v7();
      final insertOpId = uuid.v7();
      final updateOpId = uuid.v7();
      final otherOpId = uuid.v7();
      final now = DateTime.now();

      // 1. Earlier INSERT in retry backoff (nextRetryAt: 2 minutes from now)
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(insertOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-101"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.failedRetryable),
          nextRetryAt: Value(now.add(const Duration(minutes: 2))),
          createdAt: Value(now.subtract(const Duration(seconds: 30))),
        ),
      );

      // 2. Later UPDATE for same entity, currently PENDING
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(updateOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('UPDATE'),
          payload: const Value('{"status":"cancelled"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now),
        ),
      );

      // 3. Independent PENDING order for a different entity
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(otherOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(uuid.v7()),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-102"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now),
        ),
      );

      final batch = await db.outboxDao.getPushBatch(now: now);

      // Should contain the other order, but MUST NOT contain the UPDATE for the blocked entity
      expect(batch.any((e) => e.operationId == otherOpId), isTrue);
      expect(batch.any((e) => e.operationId == updateOpId), isFalse,
          reason: 'UPDATE must not be sent while earlier INSERT is in retry backoff');
      expect(batch.any((e) => e.operationId == insertOpId), isFalse,
          reason: 'INSERT is in future retry backoff');
    });

    test('getPushBatch includes both INSERT and UPDATE once retry backoff matures', () async {
      final entityId = uuid.v7();
      final insertOpId = uuid.v7();
      final updateOpId = uuid.v7();
      final now = DateTime.now();

      // Earlier INSERT whose retry backoff has matured (nextRetryAt was 10 seconds ago)
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(insertOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-101"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.failedRetryable),
          nextRetryAt: Value(now.subtract(const Duration(seconds: 10))),
          createdAt: Value(now.subtract(const Duration(seconds: 30))),
        ),
      );

      // Later UPDATE for same entity, currently PENDING
      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion(
          operationId: Value(updateOpId),
          deviceId: const Value('POS-01'),
          entityType: const Value('order'),
          entityId: Value(entityId),
          operationType: const Value('UPDATE'),
          payload: const Value('{"status":"cancelled"}'),
          dependencyOrder: const Value(2),
          status: const Value(SyncOutboxStatus.pending),
          createdAt: Value(now),
        ),
      );

      final batch = await db.outboxDao.getPushBatch(now: now);

      expect(batch.length, equals(2));
      // Causal order: INSERT first, then UPDATE
      expect(batch[0].operationId, equals(insertOpId));
      expect(batch[1].operationId, equals(updateOpId));
    });
  });
}
