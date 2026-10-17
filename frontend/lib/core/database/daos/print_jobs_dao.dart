import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/offline_print_jobs_table.dart';

part 'print_jobs_dao.g.dart';

@DriftAccessor(tables: [OfflinePrintJobs])
class PrintJobsDao extends DatabaseAccessor<AppDatabase> with _$PrintJobsDaoMixin {
  PrintJobsDao(super.db);

  Future<int> insertJob(OfflinePrintJobsCompanion job) {
    return into(offlinePrintJobs).insert(job);
  }

  Future<List<OfflinePrintJob>> getQueuedJobs() {
    return (select(offlinePrintJobs)
      ..where((t) => t.status.equals(PrintJobStatus.queued))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();
  }

  Future<List<OfflinePrintJob>> getFailedJobs() {
    return (select(offlinePrintJobs)
      ..where((t) => t.status.equals(PrintJobStatus.failed))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
  }

  Future<OfflinePrintJob?> getJobById(int id) {
    return (select(offlinePrintJobs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<OfflinePrintJob?> getPrintedJobForOrder(String orderId, String jobType) async {
    final list = await (select(offlinePrintJobs)
      ..where((t) =>
          t.orderId.equals(orderId) &
          t.jobType.equals(jobType) &
          t.status.equals(PrintJobStatus.printed))
      ..limit(1))
      .get();
    return list.firstOrNull;
  }

  Future<List<OfflinePrintJob>> getJobsForOrder(String orderId) {
    return (select(offlinePrintJobs)
      ..where((t) => t.orderId.equals(orderId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
  }

  Future<OfflinePrintJob?> getQueuedJobForOrder(String orderId, String jobType) async {
    final list = await (select(offlinePrintJobs)
      ..where((t) =>
          t.orderId.equals(orderId) &
          t.jobType.equals(jobType) &
          t.status.equals(PrintJobStatus.queued))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1))
      .get();
    return list.firstOrNull;
  }

  Future<int> markJobStatus(int id, String status, {int? retryCount}) {
    return (update(offlinePrintJobs)..where((t) => t.id.equals(id))).write(
      OfflinePrintJobsCompanion(
        status: Value(status),
        retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
      ),
    );
  }

  Future<int> updateJobPayloadAndTarget(int id, Uint8List rawBytes, String printerTarget) {
    return (update(offlinePrintJobs)..where((t) => t.id.equals(id))).write(
      OfflinePrintJobsCompanion(
        rawEscPosData: Value(rawBytes),
        printerTarget: Value(printerTarget),
      ),
    );
  }

  Future<int> deleteJobsForOrder(String orderId) {
    return (delete(offlinePrintJobs)..where((t) => t.orderId.equals(orderId))).go();
  }
}

