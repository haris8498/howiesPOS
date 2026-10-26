import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/daos/outbox_dao.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_conflicts_table.dart';
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

  group('OutboxDao Safe Sync Tests (SYNC-002)', () {
    test('Retry resets FAILED -> PENDING and leaves SYNCED untouched', () async {
      final now = DateTime.now();

      // Seed entries with various statuses
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0001-7000-8000-000000000001'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0001-7000-8000-000000000011'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-101"}'),
          status: const Value(SyncOutboxStatus.conflict),
          retryCount: const Value(3),
        ),
      );

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0002-7000-8000-000000000002'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0002-7000-8000-000000000012'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-102"}'),
          status: const Value(SyncOutboxStatus.failedFatal),
          retryCount: const Value(2),
        ),
      );

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0003-7000-8000-000000000003'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0003-7000-8000-000000000013'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-103"}'),
          status: const Value(SyncOutboxStatus.failedRetryable),
          retryCount: const Value(2),
          nextRetryAt: Value(now.add(const Duration(minutes: 10))),
        ),
      );

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0004-7000-8000-000000000004'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0004-7000-8000-000000000014'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-104"}'),
          status: const Value(OutboxDao.statusQuarantined),
          retryCount: const Value(99),
        ),
      );

      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0005-7000-8000-000000000005'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0005-7000-8000-000000000015'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-105"}'),
          status: const Value(SyncOutboxStatus.pending),
          retryCount: const Value(5), // Stuck with retryCount >= 5
        ),
      );

      // Existing SYNCED entry (must remain untouched!)
      final ackedTime = DateTime.fromMillisecondsSinceEpoch(
        (now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000) * 1000,
      );
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0006-7000-8000-000000000006'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0006-7000-8000-000000000016'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-106"}'),
          status: const Value(SyncOutboxStatus.synced),
          ackedAt: Value(ackedTime),
        ),
      );

      // Run resetFailedEntries
      final resetCount = await db.outboxDao.resetFailedEntries(
        userId: 'mgr-42',
        userName: 'Store Manager',
        reason: 'Retry all failed orders',
      );

      expect(resetCount, equals(5));

      // Verify all failed/conflict/quarantined entries are now PENDING with retryCount=0 and nextRetryAt=null
      final conflictEntry = await db.outboxDao.getEntryByOperationId('019283a0-0001-7000-8000-000000000001');
      expect(conflictEntry!.status, equals(SyncOutboxStatus.pending));
      expect(conflictEntry.retryCount, equals(0));
      expect(conflictEntry.nextRetryAt, isNull);

      final fatalEntry = await db.outboxDao.getEntryByOperationId('019283a0-0002-7000-8000-000000000002');
      expect(fatalEntry!.status, equals(SyncOutboxStatus.pending));
      expect(fatalEntry.retryCount, equals(0));
      expect(fatalEntry.nextRetryAt, isNull);

      final retryableEntry = await db.outboxDao.getEntryByOperationId('019283a0-0003-7000-8000-000000000003');
      expect(retryableEntry!.status, equals(SyncOutboxStatus.pending));
      expect(retryableEntry.retryCount, equals(0));
      expect(retryableEntry.nextRetryAt, isNull);

      final quarantinedEntry = await db.outboxDao.getEntryByOperationId('019283a0-0004-7000-8000-000000000004');
      expect(quarantinedEntry!.status, equals(SyncOutboxStatus.pending));
      expect(quarantinedEntry.retryCount, equals(0));
      expect(quarantinedEntry.nextRetryAt, isNull);

      final stuckEntry = await db.outboxDao.getEntryByOperationId('019283a0-0005-7000-8000-000000000005');
      expect(stuckEntry!.status, equals(SyncOutboxStatus.pending));
      expect(stuckEntry.retryCount, equals(0));
      expect(stuckEntry.nextRetryAt, isNull);

      // SYNCED entry must remain SYNCED and ackedAt unchanged
      final syncedEntry = await db.outboxDao.getEntryByOperationId('019283a0-0006-7000-8000-000000000006');
      expect(syncedEntry!.status, equals(SyncOutboxStatus.synced));
      expect(syncedEntry.ackedAt, equals(ackedTime));
    });

    test('No DAO method can mark an unacknowledged entry SYNCED', () async {
      // Seed unacknowledged entries
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0007-7000-8000-000000000007'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0007-7000-8000-000000000017'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-107"}'),
          status: const Value(SyncOutboxStatus.failedFatal),
          retryCount: const Value(5),
        ),
      );

      // Call legacy clearFailedEntries()
      await db.outboxDao.clearFailedEntries();

      // Guard assertion: status is PENDING, NOT SYNCED!
      final entry = await db.outboxDao.getEntryByOperationId('019283a0-0007-7000-8000-000000000007');
      expect(entry!.status, isNot(equals(SyncOutboxStatus.synced)));
      expect(entry.status, equals(SyncOutboxStatus.pending));
      expect(entry.ackedAt, isNull);
    });

    test('Audit row written for any state change by a user action', () async {
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0008-7000-8000-000000000008'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0008-7000-8000-000000000018'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-108"}'),
          status: const Value(SyncOutboxStatus.failedFatal),
        ),
      );

      // 1. Reset all failed
      await db.outboxDao.resetFailedEntries(
        userId: 'user-001',
        userName: 'Alice Cashier',
        reason: 'Manual retry by Alice',
      );

      var auditLogs = await db.outboxDao.getAuditLogs();
      expect(auditLogs, isNotEmpty);
      final firstLog = auditLogs.first;
      expect(firstLog.entityType, equals('audit_log'));
      expect(firstLog.conflictType, equals('USER_ACTION'));
      expect(firstLog.resolutionStatus, equals(ConflictResolutionStatus.supervisorAcknowledged));

      final decodedPayload = jsonDecode(firstLog.payload) as Map<String, dynamic>;
      expect(decodedPayload['action'], equals('RETRY_FAILED_ENTRIES'));
      expect(decodedPayload['userId'], equals('user-001'));
      expect(decodedPayload['userName'], equals('Alice Cashier'));

      // 2. Quarantine an entry
      final entry = await db.outboxDao.getEntryByOperationId('019283a0-0008-7000-8000-000000000008');
      await db.outboxDao.markQuarantined(
        entry!.id,
        reason: 'Permanent 422 Unprocessable Entity',
        userId: 'mgr-002',
        userName: 'Bob Manager',
      );

      auditLogs = await db.outboxDao.getAuditLogs();
      final quarantineLog = auditLogs.firstWhere(
        (l) => l.errorMessage?.contains('QUARANTINE_MUTATION') ?? false,
      );
      final quarantinePayload = jsonDecode(quarantineLog.payload) as Map<String, dynamic>;
      expect(quarantinePayload['action'], equals('QUARANTINE_MUTATION'));
      expect(quarantinePayload['userId'], equals('mgr-002'));
      expect(quarantinePayload['userName'], equals('Bob Manager'));

      // 3. Single entry reset
      await db.outboxDao.resetSingleEntry(
        entry.id,
        userId: 'mgr-002',
        userName: 'Bob Manager',
      );

      auditLogs = await db.outboxDao.getAuditLogs();
      final singleResetLog = auditLogs.firstWhere(
        (l) => l.errorMessage?.contains('RETRY_SINGLE_ENTRY') ?? false,
      );
      final singleResetPayload = jsonDecode(singleResetLog.payload) as Map<String, dynamic>;
      expect(singleResetPayload['action'], equals('RETRY_SINGLE_ENTRY'));
      expect(singleResetPayload['userId'], equals('mgr-002'));
    });

    test('Quarantine retains entry without deletion and exports diagnostic JSON', () async {
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0009-7000-8000-000000000009'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0009-7000-8000-000000000019'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-109","amount":45.50}'),
          status: const Value(SyncOutboxStatus.pending),
        ),
      );

      final entry = await db.outboxDao.getEntryByOperationId('019283a0-0009-7000-8000-000000000009');
      await db.outboxDao.markQuarantined(
        entry!.id,
        reason: 'Non-retryable 400 bad payload schema',
        conflictDetails: '{"field":"amount","error":"out of range"}',
      );

      // Verify entry exists and is NOT deleted
      final retrieved = await db.outboxDao.getEntryByOperationId('019283a0-0009-7000-8000-000000000009');
      expect(retrieved, isNotNull);
      expect(retrieved!.status, equals(OutboxDao.statusQuarantined));
      expect(retrieved.lastError, equals('Non-retryable 400 bad payload schema'));

      // Verify export JSON
      final exportJson = await db.outboxDao.exportQuarantinedJson();
      expect(exportJson, contains('019283a0-0009-7000-8000-000000000009'));
      expect(exportJson, contains('Non-retryable 400 bad payload schema'));
      expect(exportJson, contains('P1-109'));
    });
  });
}
