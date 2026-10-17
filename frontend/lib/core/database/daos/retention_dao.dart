import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/local_orders_tables.dart';
import '../tables/sync_outbox_table.dart';
import '../tables/offline_print_jobs_table.dart';

part 'retention_dao.g.dart';

/// Summary report of purged local records during retention pruning.
class RetentionPruneResult {
  final int ordersDeleted;
  final int outboxDeleted;
  final int printJobsDeleted;

  const RetentionPruneResult({
    required this.ordersDeleted,
    required this.outboxDeleted,
    required this.printJobsDeleted,
  });

  int get totalDeleted => ordersDeleted + outboxDeleted + printJobsDeleted;

  @override
  String toString() =>
      'RetentionPruneResult(orders: $ordersDeleted, outbox: $outboxDeleted, printJobs: $printJobsDeleted)';
}

@DriftAccessor(tables: [LocalOrders, SyncOutbox, OfflinePrintJobs])
class RetentionDao extends DatabaseAccessor<AppDatabase> with _$RetentionDaoMixin {
  RetentionDao(super.db);

  /// 30-day synced retention pruning method per Directive Q9.2 and Spec §3.3 / §18.
  ///
  /// Prunes:
  /// 1. `local_orders` with syncStatus = 'synced' older than [olderThan] (default 30 days).
  ///    FK cascade deletes associated `local_order_items` and `local_order_payments`.
  /// 2. `sync_outbox` entries with status = 'SYNCED' older than [olderThan].
  /// 3. `offline_print_jobs` with status = 'PRINTED' older than [olderThan].
  ///
  /// Unsynced / pending orders, retryable mutations, and queued print jobs are never touched.
  Future<RetentionPruneResult> pruneSyncedDataOlderThan({
    Duration olderThan = const Duration(days: 30),
    DateTime? referenceDate,
  }) {
    final cutoff = (referenceDate ?? DateTime.now()).subtract(olderThan);

    return transaction(() async {
      final ordersCount = await (delete(localOrders)..where((t) =>
        t.syncStatus.equals('synced') &
        t.createdAt.isSmallerOrEqualValue(cutoff)
      )).go();

      final outboxCount = await (delete(syncOutbox)..where((t) =>
        t.status.equals(SyncOutboxStatus.synced) &
        t.createdAt.isSmallerOrEqualValue(cutoff)
      )).go();

      final printJobsCount = await (delete(offlinePrintJobs)..where((t) =>
        t.status.equals(PrintJobStatus.printed) &
        t.createdAt.isSmallerOrEqualValue(cutoff)
      )).go();

      return RetentionPruneResult(
        ordersDeleted: ordersCount,
        outboxDeleted: outboxCount,
        printJobsDeleted: printJobsCount,
      );
    });
  }
}
