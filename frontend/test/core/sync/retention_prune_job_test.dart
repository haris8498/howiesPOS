import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/offline_print_jobs_table.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SyncBackgroundWorker worker;
  late ConnectivityNotifier connectivityNotifier;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    connectivityNotifier = ConnectivityNotifier();
    worker = SyncBackgroundWorker(
      db: db,
      connectivityNotifier: connectivityNotifier,
    );
  });


  tearDown(() async {
    worker.dispose();
    connectivityNotifier.dispose();
    await db.close();
  });

  group('30-Day Retention Pruning Job Tests (§3.3, §18 Phase 7, Directive Q9.2)', () {
    test('1. Prunes SYNCED orders, outbox entries, and print jobs older than 30 days', () async {
      final now = DateTime.now();
      final fortyDaysAgo = now.subtract(const Duration(days: 40));
      const uuid = Uuid();

      // 1. Synced order from 40 days ago -> SHOULD BE PRUNED
      await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: drift.Value(uuid.v7()),
              orderNumber: const drift.Value('P1-101'),
              deviceId: const drift.Value('POS-P1'),
              orderType: const drift.Value('dineIn'),
              status: const drift.Value('completed'),
              syncStatus: const drift.Value('synced'),
              subtotal: const drift.Value(20.0),
              taxAmount: const drift.Value(2.0),
              grandTotal: const drift.Value(22.0),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 2. Synced outbox mutation from 40 days ago -> SHOULD BE PRUNED
      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion(
              operationId: drift.Value(uuid.v7()),
              deviceId: const drift.Value('POS-P1'),
              entityType: const drift.Value('order'),
              entityId: drift.Value(uuid.v7()),
              operationType: const drift.Value('INSERT'),
              payload: const drift.Value('{}'),
              status: const drift.Value(SyncOutboxStatus.synced),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 3. Printed receipt from 40 days ago -> SHOULD BE PRUNED
      await db.into(db.offlinePrintJobs).insert(
            OfflinePrintJobsCompanion(
              orderId: drift.Value(uuid.v7()),
              jobType: const drift.Value(PrintJobType.customerReceipt),
              printerTarget: const drift.Value('WIN_DEFAULT'),
              rawEscPosData: drift.Value(Uint8List.fromList([0x1B, 0x40])),
              status: const drift.Value(PrintJobStatus.printed),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 4. Pending order from 40 days ago (e.g. prolonged offline) -> MUST NEVER BE PRUNED
      final pendingOrderId = uuid.v7();
      await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: drift.Value(pendingOrderId),
              orderNumber: const drift.Value('P1-102'),
              deviceId: const drift.Value('POS-P1'),
              orderType: const drift.Value('dineIn'),
              status: const drift.Value('completed'),
              syncStatus: const drift.Value('pending_insert'),
              subtotal: const drift.Value(30.0),
              taxAmount: const drift.Value(3.0),
              grandTotal: const drift.Value(33.0),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 5. Pending, Conflict, and Fatal Outbox entries from 40 days ago -> MUST NEVER BE PRUNED
      final pendingOutboxOpId = uuid.v7();
      final conflictOutboxOpId = uuid.v7();
      final fatalOutboxOpId = uuid.v7();

      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion(
              operationId: drift.Value(pendingOutboxOpId),
              deviceId: const drift.Value('POS-P1'),
              entityType: const drift.Value('order'),
              entityId: drift.Value(pendingOrderId),
              operationType: const drift.Value('INSERT'),
              payload: const drift.Value('{}'),
              status: const drift.Value(SyncOutboxStatus.pending),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion(
              operationId: drift.Value(conflictOutboxOpId),
              deviceId: const drift.Value('POS-P1'),
              entityType: const drift.Value('table'),
              entityId: drift.Value(uuid.v7()),
              operationType: const drift.Value('UPDATE'),
              payload: const drift.Value('{}'),
              status: const drift.Value(SyncOutboxStatus.conflict),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion(
              operationId: drift.Value(fatalOutboxOpId),
              deviceId: const drift.Value('POS-P1'),
              entityType: const drift.Value('order'),
              entityId: drift.Value(uuid.v7()),
              operationType: const drift.Value('INSERT'),
              payload: const drift.Value('{}'),
              status: const drift.Value(SyncOutboxStatus.failedFatal),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 6. Queued and Failed print jobs from 40 days ago -> MUST NEVER BE PRUNED
      await db.into(db.offlinePrintJobs).insert(
            OfflinePrintJobsCompanion(
              orderId: drift.Value(pendingOrderId),
              jobType: const drift.Value(PrintJobType.customerReceipt),
              printerTarget: const drift.Value('WIN_DEFAULT'),
              rawEscPosData: drift.Value(Uint8List.fromList([0x1B, 0x40])),
              status: const drift.Value(PrintJobStatus.queued),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      await db.into(db.offlinePrintJobs).insert(
            OfflinePrintJobsCompanion(
              orderId: drift.Value(pendingOrderId),
              jobType: const drift.Value(PrintJobType.kitchenTicket),
              printerTarget: const drift.Value('WIN_DEFAULT'),
              rawEscPosData: drift.Value(Uint8List.fromList([0x1B, 0x40])),
              status: const drift.Value(PrintJobStatus.failed),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      // 7. Recent 5-day-old SYNCED data -> MUST BE PRESERVED (within 30 days)
      final recentFiveDays = now.subtract(const Duration(days: 5));
      final recentOrderId = uuid.v7();

      await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: drift.Value(recentOrderId),
              orderNumber: const drift.Value('P1-103'),
              deviceId: const drift.Value('POS-P1'),
              orderType: const drift.Value('takeAway'),
              status: const drift.Value('completed'),
              syncStatus: const drift.Value('synced'),
              subtotal: const drift.Value(15.0),
              taxAmount: const drift.Value(1.5),
              grandTotal: const drift.Value(16.5),
              createdAt: drift.Value(recentFiveDays),
            ),
          );

      await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion(
              operationId: drift.Value(uuid.v7()),
              deviceId: const drift.Value('POS-P1'),
              entityType: const drift.Value('order'),
              entityId: drift.Value(recentOrderId),
              operationType: const drift.Value('INSERT'),
              payload: const drift.Value('{}'),
              status: const drift.Value(SyncOutboxStatus.synced),
              createdAt: drift.Value(recentFiveDays),
            ),
          );

      await db.into(db.offlinePrintJobs).insert(
            OfflinePrintJobsCompanion(
              orderId: drift.Value(recentOrderId),
              jobType: const drift.Value(PrintJobType.customerReceipt),
              printerTarget: const drift.Value('WIN_DEFAULT'),
              rawEscPosData: drift.Value(Uint8List.fromList([0x1B, 0x40])),
              status: const drift.Value(PrintJobStatus.printed),
              createdAt: drift.Value(recentFiveDays),
            ),
          );

      // Execute Pruning via SyncBackgroundWorker
      final pruneResult = await worker.pruneOldSyncedData(
        olderThan: const Duration(days: 30),
        referenceDate: now,
      );

      // Verify exact pruned counts: exactly 1 order, 1 outbox, 1 print job pruned
      expect(pruneResult.ordersDeleted, equals(1));
      expect(pruneResult.outboxDeleted, equals(1));
      expect(pruneResult.printJobsDeleted, equals(1));
      expect(pruneResult.totalDeleted, equals(3));

      // Verify pending order remains
      final remainingOrders = await db.select(db.localOrders).get();
      expect(remainingOrders.length, equals(2));
      expect(remainingOrders.any((o) => o.id == pendingOrderId), isTrue);
      expect(remainingOrders.any((o) => o.id == recentOrderId), isTrue);

      // Verify non-synced and recent outbox entries remain
      final remainingOutbox = await db.select(db.syncOutbox).get();
      expect(remainingOutbox.length, equals(4)); // 1 pending, 1 conflict, 1 fatal, 1 recent synced
      expect(remainingOutbox.any((o) => o.operationId == pendingOutboxOpId), isTrue);
      expect(remainingOutbox.any((o) => o.operationId == conflictOutboxOpId), isTrue);
      expect(remainingOutbox.any((o) => o.operationId == fatalOutboxOpId), isTrue);

      // Verify queued/failed and recent print jobs remain
      final remainingPrintJobs = await db.select(db.offlinePrintJobs).get();
      expect(remainingPrintJobs.length, equals(3)); // 1 queued, 1 failed, 1 recent printed
      expect(remainingPrintJobs.any((p) => p.status == PrintJobStatus.queued), isTrue);
      expect(remainingPrintJobs.any((p) => p.status == PrintJobStatus.failed), isTrue);
    });

    test('2. Pruning on worker start runs automatically', () async {
      final now = DateTime.now();
      final fortyDaysAgo = now.subtract(const Duration(days: 40));
      const uuid = Uuid();

      await db.into(db.localOrders).insert(
            LocalOrdersCompanion(
              id: drift.Value(uuid.v7()),
              orderNumber: const drift.Value('P1-999'),
              deviceId: const drift.Value('POS-P1'),
              orderType: const drift.Value('dineIn'),
              status: const drift.Value('completed'),
              syncStatus: const drift.Value('synced'),
              subtotal: const drift.Value(10.0),
              taxAmount: const drift.Value(1.0),
              grandTotal: const drift.Value(11.0),
              createdAt: drift.Value(fortyDaysAgo),
            ),
          );

      expect((await db.select(db.localOrders).get()).length, equals(1));

      // Starting worker triggers automatic startup pruning
      await worker.start();

      final ordersAfterStart = await db.select(db.localOrders).get();
      expect(ordersAfterStart, isEmpty);
    });
  });
}
