import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Push Failure Cascade Tests (#20)', () {
    test('(a) fatal parent quarantines children', () async {
      const parentOpId = '019283a0-0001-7000-8000-000000000001';
      const childOpId = '019283a0-0001-7000-8000-000000000002';
      const grandChildOpId = '019283a0-0001-7000-8000-000000000003';
      const unrelatedOpId = '019283a0-0001-7000-8000-000000000099';

      final parentId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(parentOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('order'),
          entityId: Value('019283a0-0001-7000-8000-000000000011'),
          operationType: Value('INSERT'),
          payload: Value('{"order_number":"P1-101"}'),
          dependencyOrder: Value(2),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      final childId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(childOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('order_item'),
          entityId: Value('019283a0-0001-7000-8000-000000000012'),
          operationType: Value('INSERT'),
          payload: Value('{"item_name":"Pepperoni Pizza"}'),
          dependsOnOperationId: Value(parentOpId),
          dependencyOrder: Value(3),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      final grandChildId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(grandChildOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('payment'),
          entityId: Value('019283a0-0001-7000-8000-000000000013'),
          operationType: Value('INSERT'),
          payload: Value('{"amount":25.50}'),
          dependsOnOperationId: Value(childOpId),
          dependencyOrder: Value(4),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(unrelatedOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('shift'),
          entityId: Value('019283a0-0001-7000-8000-000000000099'),
          operationType: Value('INSERT'),
          payload: Value('{"shift_number":1}'),
          dependencyOrder: Value(0),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      // 1. Mark parent mutation FAILED_FATAL
      await db.outboxDao.markFailedFatal(
        parentId,
        error: 'Validation error: invalid customer store configuration',
      );

      // 2. Verify parent is marked FAILED_FATAL
      final parent = await db.outboxDao.getEntryByOperationId(parentOpId);
      expect(parent, isNotNull);
      expect(parent!.status, equals(SyncOutboxStatus.failedFatal));
      expect(parent.lastError, equals('Validation error: invalid customer store configuration'));

      // 3. Verify direct child is automatically cascaded to FAILED_FATAL / quarantined
      final child = await db.outboxDao.getEntryByOperationId(childOpId);
      expect(child, isNotNull);
      expect(child!.status, equals(SyncOutboxStatus.failedFatal));
      expect(child.lastError, contains('PARENT_FAILED_FATAL'));
      expect(child.conflictDetails, contains('PARENT_FAILED_FATAL'));

      // 4. Verify transitively dependent grandchild is also cascaded to FAILED_FATAL
      final grandChild = await db.outboxDao.getEntryByOperationId(grandChildOpId);
      expect(grandChild, isNotNull);
      expect(grandChild!.status, equals(SyncOutboxStatus.failedFatal));
      expect(grandChild.lastError, contains('PARENT_FAILED_FATAL'));

      // 5. Verify unrelated mutation is untouched
      final unrelated = await db.outboxDao.getEntryByOperationId(unrelatedOpId);
      expect(unrelated, isNotNull);
      expect(unrelated!.status, equals(SyncOutboxStatus.pending));

      // 6. Verify getPushBatch excludes fatal parent and all quarantined children
      final batch = await db.outboxDao.getPushBatch();
      expect(batch.length, equals(1));
      expect(batch.first.operationId, equals(unrelatedOpId));

      // 7. Verify subsequent retry attempt on child does NOT demote it back to retryable
      await db.outboxDao.markFailedRetryable(
        childId,
        error: 'Server returned retryable dependency error',
        retryCount: 1,
        nextRetryAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      final childAfterRetry = await db.outboxDao.getEntryByOperationId(childOpId);
      expect(childAfterRetry!.status, equals(SyncOutboxStatus.failedFatal),
          reason: 'Quarantined child must not be reverted to FAILED_RETRYABLE');

      // 8. Verify permanently failed entries query includes parent and cascaded children
      final failedList = await db.outboxDao.getPermanentlyFailedEntries();
      final failedOpIds = failedList.map((e) => e.operationId).toSet();
      expect(failedOpIds.contains(parentOpId), isTrue);
      expect(failedOpIds.contains(childOpId), isTrue);
      expect(failedOpIds.contains(grandChildOpId), isTrue);
    });

    test('(b) retryable parent does NOT quarantine children', () async {
      const parentOpId = '019283a0-0002-7000-8000-000000000001';
      const childOpId = '019283a0-0002-7000-8000-000000000002';
      final now = DateTime.now();

      final parentId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(parentOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('order'),
          entityId: Value('019283a0-0002-7000-8000-000000000011'),
          operationType: Value('INSERT'),
          payload: Value('{"order_number":"P1-102"}'),
          dependencyOrder: Value(2),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      final childId = await db.outboxDao.insertEntry(
        const SyncOutboxCompanion(
          operationId: Value(childOpId),
          deviceId: Value('POS-P1'),
          entityType: Value('order_item'),
          entityId: Value('019283a0-0002-7000-8000-000000000012'),
          operationType: Value('INSERT'),
          payload: Value('{"item_name":"Cheese Pizza"}'),
          dependsOnOperationId: Value(parentOpId),
          dependencyOrder: Value(3),
          status: Value(SyncOutboxStatus.pending),
        ),
      );

      // 1. Mark parent mutation FAILED_RETRYABLE (transient network / server error)
      await db.outboxDao.markFailedRetryable(
        parentId,
        error: 'Network timeout: connection refused',
        retryCount: 1,
        nextRetryAt: now.add(const Duration(minutes: 5)),
      );

      // 2. Verify parent is FAILED_RETRYABLE
      final parent = await db.outboxDao.getEntryByOperationId(parentOpId);
      expect(parent, isNotNull);
      expect(parent!.status, equals(SyncOutboxStatus.failedRetryable));
      expect(parent.retryCount, equals(1));

      // 3. Verify child is NOT quarantined and remains PENDING
      final child = await db.outboxDao.getEntryByOperationId(childOpId);
      expect(child, isNotNull);
      expect(child!.status, equals(SyncOutboxStatus.pending),
          reason: 'Transient failure of parent must not quarantine dependent children');
      expect(child.lastError, isNull);

      // 4. Verify child is not in permanently failed entries
      final failedList = await db.outboxDao.getPermanentlyFailedEntries();
      expect(failedList.any((e) => e.operationId == childOpId), isFalse);

      // 5. Verify child can independently transition to FAILED_RETRYABLE on transient failure
      await db.outboxDao.markFailedRetryable(
        childId,
        error: 'Transient upstream dependency waiting',
        retryCount: 1,
        nextRetryAt: now.add(const Duration(seconds: 30)),
      );
      final childAfterRetry = await db.outboxDao.getEntryByOperationId(childOpId);
      expect(childAfterRetry!.status, equals(SyncOutboxStatus.failedRetryable),
          reason: 'Child must be retryable when parent is only temporarily retryable');
    });
  });
}
