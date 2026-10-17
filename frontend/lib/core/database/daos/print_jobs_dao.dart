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

  Future<OfflinePrintJob?> getJobById(int id) {
    return (select(offlinePrintJobs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> markJobStatus(int id, String status, {int? retryCount}) {
    return (update(offlinePrintJobs)..where((t) => t.id.equals(id))).write(
      OfflinePrintJobsCompanion(
        status: Value(status),
        retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
      ),
    );
  }
}
