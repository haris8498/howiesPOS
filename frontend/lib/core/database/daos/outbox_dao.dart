import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/sync_conflicts_table.dart';
import '../tables/sync_outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  static const String statusQuarantined = 'QUARANTINED';
  static const String statusDeadLetter = 'DEAD_LETTER';

  /// Inserts a new mutation into the outbox queue.
  Future<int> insertEntry(SyncOutboxCompanion entry) {
    return into(syncOutbox).insert(entry);
  }

  /// Queries batch of entries ready for push transmission per Spec §6.1, §6.3:
  /// - Only 'PENDING' or due 'FAILED_RETRYABLE' (next_retry_at IS NULL or <= now).
  /// - Excludes 'AUTH_PAUSED' (Deviation #3), 'IN_FLIGHT', 'SYNCED', 'FAILED_FATAL', 'CONFLICT'.
  /// - Strictly ordered by `dependency_order ASC, created_at ASC LIMIT 25`.
  Future<List<SyncOutboxEntry>> getPushBatch({int limit = 25, DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();

    // OBX-03: Block later mutations if an earlier mutation for the same entity is in retry backoff, in-flight, or auth-paused
    final blockedEntityRows = await (selectOnly(syncOutbox, distinct: true)
          ..addColumns([syncOutbox.entityType, syncOutbox.entityId])
          ..where(
            (syncOutbox.status.equals(SyncOutboxStatus.failedRetryable) &
                syncOutbox.nextRetryAt.isBiggerThanValue(effectiveNow)) |
            syncOutbox.status.equals(SyncOutboxStatus.inFlight) |
            syncOutbox.status.equals(SyncOutboxStatus.authPaused),
          ))
        .get();

    final blockedKeys = blockedEntityRows.map((r) {
      final type = r.read(syncOutbox.entityType) ?? '';
      final id = r.read(syncOutbox.entityId) ?? '';
      return '$type:$id';
    }).toSet();

    final query = select(syncOutbox)
      ..where((t) {
        final isPending = t.status.equals(SyncOutboxStatus.pending);
        final isDueRetryable = t.status.equals(SyncOutboxStatus.failedRetryable) &
            (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerOrEqualValue(effectiveNow));
        return isPending | isDueRetryable;
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.dependencyOrder),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);

    if (blockedKeys.isEmpty) {
      return (query..limit(limit)).get();
    }

    final candidates = await query.get();
    final result = <SyncOutboxEntry>[];
    for (final candidate in candidates) {
      final key = '${candidate.entityType}:${candidate.entityId}';
      if (!blockedKeys.contains(key)) {
        result.add(candidate);
        if (result.length >= limit) break;
      }
    }
    return result;
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

  /// Records an immutable audit log entry in [SyncConflicts] for state changes initiated by user actions (SYNC-002).
  Future<void> recordAuditLog({
    required String action,
    required String userId,
    required String userName,
    required List<int> entryIds,
    String? details,
  }) async {
    final payloadJson = jsonEncode({
      'action': action,
      'userId': userId,
      'userName': userName,
      'entryIds': entryIds,
      'timestamp': DateTime.now().toIso8601String(),
      if (details != null) 'details': details,
    });

    await db.into(db.syncConflicts).insert(
      SyncConflictsCompanion(
        id: Value(const Uuid().v7()),
        operationId: Value(const Uuid().v7()),
        entityType: const Value('audit_log'),
        entityId: Value(const Uuid().v7()),
        conflictType: const Value('USER_ACTION'),
        resolutionStatus: const Value(ConflictResolutionStatus.supervisorAcknowledged),
        errorMessage: Value('State change by user: $action ($userName)'),
        payload: Value(payloadJson),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Queries all audit log entries written for user state changes.
  Future<List<SyncConflict>> getAuditLogs() {
    return (db.select(db.syncConflicts)
          ..where((t) => t.entityType.equals('audit_log'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Resets a single entry back to PENDING for immediate retry.
  Future<int> resetSingleEntry(
    int id, {
    String userId = 'system',
    String userName = 'System',
  }) async {
    final count = await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      const SyncOutboxCompanion(
        status: Value(SyncOutboxStatus.pending),
        retryCount: Value(0),
        nextRetryAt: Value(null),
      ),
    );

    if (count > 0) {
      await recordAuditLog(
        action: 'RETRY_SINGLE_ENTRY',
        userId: userId,
        userName: userName,
        entryIds: [id],
      );
    }

    return count;
  }

  /// Resets failed, conflict, and quarantined entries back to PENDING for retry (SYNC-002).
  ///
  /// Resets attempt count to 0 and nextRetryAt to null so the sync worker resends them immediately.
  /// Never marks entries SYNCED. Leaves existing SYNCED entries completely untouched.
  /// Records an audit log entry for the state change.
  Future<int> resetFailedEntries({
    String userId = 'system',
    String userName = 'System',
    String reason = 'User triggered retry failed',
  }) async {
    final targets = await (select(syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.conflict) |
              t.status.equals(SyncOutboxStatus.failedFatal) |
              t.status.equals(SyncOutboxStatus.failedRetryable) |
              t.status.equals(statusQuarantined) |
              t.status.equals(statusDeadLetter) |
              t.retryCount.isBiggerOrEqualValue(5)))
        .get();

    if (targets.isEmpty) {
      return 0;
    }

    final targetIds = targets.map((e) => e.id).toList();
    final count = await (update(syncOutbox)
          ..where((t) => t.id.isIn(targetIds)))
        .write(const SyncOutboxCompanion(
          status: Value(SyncOutboxStatus.pending),
          retryCount: Value(0),
          nextRetryAt: Value(null),
        ));

    await recordAuditLog(
      action: 'RETRY_FAILED_ENTRIES',
      userId: userId,
      userName: userName,
      entryIds: targetIds,
      details: jsonEncode({
        'reason': reason,
        'count': count,
        'operationIds': targets.map((e) => e.operationId).toList(),
      }),
    );

    return count;
  }

  /// Deprecated: Unacknowledged entries must NEVER be marked SYNCED locally without confirmed server acknowledgement (SYNC-002).
  ///
  /// Previously marked failed and pending entries as SYNCED without transmitting them, erasing orders.
  /// Calls to this method are safely redirected to [resetFailedEntries] so entries are retried instead of erased.
  @Deprecated('Use resetFailedEntries() instead. Marking unsent outbox entries SYNCED locally is prohibited.')
  Future<int> clearFailedEntries() {
    return resetFailedEntries(reason: 'Legacy clearFailedEntries redirected to resetFailedEntries');
  }

  /// Moves a permanently rejected entry to QUARANTINED status (SYNC-002 / Spec §6.2).
  /// Retained in database and exportable for support inspection. Never deleted.
  Future<int> markQuarantined(
    int id, {
    required String reason,
    String? conflictDetails,
    String userId = 'system',
    String userName = 'System',
  }) async {
    final count = await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(statusQuarantined),
        lastError: Value(reason),
        conflictDetails: Value(conflictDetails),
        retryCount: const Value(99),
      ),
    );

    if (count > 0) {
      await recordAuditLog(
        action: 'QUARANTINE_MUTATION',
        userId: userId,
        userName: userName,
        entryIds: [id],
        details: reason,
      );
    }

    return count;
  }

  /// Alias for dead-letter status per Spec §6.2.
  Future<int> markDeadLetter(
    int id, {
    required String reason,
    String? conflictDetails,
    String userId = 'system',
    String userName = 'System',
  }) {
    return markQuarantined(
      id,
      reason: reason,
      conflictDetails: conflictDetails,
      userId: userId,
      userName: userName,
    );
  }

  /// Retrieves all quarantined, dead-letter, conflict, or failed outbox entries.
  Future<List<SyncOutboxEntry>> getQuarantinedOrFailedEntries() {
    return (select(syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.conflict) |
              t.status.equals(SyncOutboxStatus.failedFatal) |
              t.status.equals(SyncOutboxStatus.failedRetryable) |
              t.status.equals(statusQuarantined) |
              t.status.equals(statusDeadLetter) |
              t.retryCount.isBiggerOrEqualValue(5))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Serializes quarantined and failed mutations to a diagnostic JSON string for support reporting.
  Future<String> exportQuarantinedJson() async {
    final entries = await getQuarantinedOrFailedEntries();
    final list = entries.map((e) => {
      'id': e.id,
      'operationId': e.operationId,
      'deviceId': e.deviceId,
      'entityType': e.entityType,
      'entityId': e.entityId,
      'operationType': e.operationType,
      'baseVersion': e.baseVersion,
      'status': e.status,
      'retryCount': e.retryCount,
      'createdAt': e.createdAt.toIso8601String(),
      'lastError': e.lastError,
      'conflictDetails': e.conflictDetails,
      'payload': e.payload,
    }).toList();

    return jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'quarantinedCount': list.length,
      'entries': list,
    });
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

  Stream<List<SyncOutboxEntry>> watchActiveOutboxEntries() {
    return (select(syncOutbox)
      ..where((t) =>
          t.status.equals(SyncOutboxStatus.pending) |
          t.status.equals(SyncOutboxStatus.inFlight) |
          t.status.equals(SyncOutboxStatus.failedRetryable) |
          t.status.equals(SyncOutboxStatus.failedFatal) |
          t.status.equals(SyncOutboxStatus.conflict) |
          t.status.equals(SyncOutboxStatus.authPaused) |
          t.status.equals(statusQuarantined) |
          t.status.equals(statusDeadLetter))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();
  }
}
