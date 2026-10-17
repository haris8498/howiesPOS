import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Inserts a new mutation into the outbox queue.
  Future<int> insertEntry(SyncOutboxCompanion entry) {
    return into(syncOutbox).insert(entry);
  }

  /// Queries batch of entries ready for push transmission per Spec §6.1, §6.3:
  /// - Only 'PENDING' or due 'FAILED_RETRYABLE' (next_retry_at IS NULL or <= now).
  /// - Excludes 'AUTH_PAUSED' (Deviation #3), 'IN_FLIGHT', 'SYNCED', 'FAILED_FATAL', 'CONFLICT'.
  /// - Strictly ordered by `dependency_order ASC, created_at ASC LIMIT 25`.
  Future<List<SyncOutboxEntry>> getPushBatch({int limit = 25, DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    return (select(syncOutbox)
      ..where((t) {
        final isPending = t.status.equals(SyncOutboxStatus.pending);
        final isDueRetryable = t.status.equals(SyncOutboxStatus.failedRetryable) &
            (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerOrEqualValue(effectiveNow));
        return isPending | isDueRetryable;
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.dependencyOrder),
        (t) => OrderingTerm.asc(t.createdAt),
      ])
      ..limit(limit))
      .get();
  }

  Future<SyncOutboxEntry?> getEntryByOperationId(String operationId) {
    return (select(syncOutbox)..where((t) => t.operationId.equals(operationId))).getSingleOrNull();
  }

  Future<int> markInFlight(List<int> ids, DateTime sentAt) {
    return (update(syncOutbox)..where((t) => t.id.isIn(ids))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.inFlight),
        sentAt: Value(sentAt),
      ),
    );
  }

  Future<int> markSynced(int id, DateTime ackedAt) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.synced),
        ackedAt: Value(ackedAt),
      ),
    );
  }

  Future<int> markFailedRetryable(
    int id, {
    required String error,
    required int retryCount,
    required DateTime nextRetryAt,
  }) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.failedRetryable),
        lastError: Value(error),
        retryCount: Value(retryCount),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }

  /// Approved Deviation #3: HTTP 401 pauses outbox with AUTH_PAUSED status.
  Future<int> markAuthPaused(int id, {required String error}) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.authPaused),
        lastError: Value(error),
      ),
    );
  }

  /// Resumes all AUTH_PAUSED entries back to PENDING after successful authentication.
  Future<int> resumeAuthPaused() {
    return (update(syncOutbox)..where((t) => t.status.equals(SyncOutboxStatus.authPaused))).write(
      const SyncOutboxCompanion(
        status: Value(SyncOutboxStatus.pending),
      ),
    );
  }

  Future<int> markFailedFatal(int id, {required String error, String? conflictDetails}) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.failedFatal),
        lastError: Value(error),
        conflictDetails: Value(conflictDetails),
      ),
    );
  }

  Future<int> markConflict(int id, {required String conflictDetails}) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.conflict),
        conflictDetails: Value(conflictDetails),
      ),
    );
  }

  Stream<int> watchPendingCount() {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.status.equals(SyncOutboxStatus.pending) |
          syncOutbox.status.equals(SyncOutboxStatus.failedRetryable));
    return query.map((row) => row.read(countExpr) ?? 0).watchSingle();
  }

  Future<List<SyncOutboxEntry>> getAllEntries() {
    return (select(syncOutbox)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }
}
