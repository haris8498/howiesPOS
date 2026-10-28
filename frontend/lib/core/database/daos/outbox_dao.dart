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
    final entryWithVersion = entry.schemaVersion.present
        ? entry
        : entry.copyWith(schemaVersion: const Value(kCurrentOutboxPayloadVersion));
    return into(syncOutbox).insert(entryWithVersion);
  }

  /// Checks whether any ancestor mutation in the dependency chain ended in FAILED_FATAL or QUARANTINED.
  Future<bool> hasFatalAncestor(SyncOutboxEntry entry, {Set<String>? visited}) async {
    final visitedOpIds = visited ?? <String>{};
    if (visitedOpIds.contains(entry.operationId)) {
      return false; // Break dependency cycles
    }
    visitedOpIds.add(entry.operationId);

    // 1. Check explicit dependency field (dependsOnOperationId)
    if (entry.dependsOnOperationId != null) {
      final parent = await getEntryByOperationId(entry.dependsOnOperationId!);
      if (parent != null) {
        if (parent.status == SyncOutboxStatus.failedFatal ||
            parent.status == statusQuarantined ||
            parent.status == statusDeadLetter) {
          return true;
        }
        // Transitively check grandparent
        if (await hasFatalAncestor(parent, visited: visitedOpIds)) {
          return true;
        }
      }
    }

    // 2. Check same entity aggregate (earlier mutation on the same entity that failed fatally)
    final fatalEntitySibling = await (select(syncOutbox)
          ..where((t) =>
              t.entityType.equals(entry.entityType) &
              t.entityId.equals(entry.entityId) &
              t.id.isSmallerThanValue(entry.id) &
              (t.status.equals(SyncOutboxStatus.failedFatal) |
                  t.status.equals(statusQuarantined) |
                  t.status.equals(statusDeadLetter)))
          ..limit(1))
        .getSingleOrNull();

    if (fatalEntitySibling != null) {
      return true;
    }

    return false;
  }

  /// Cascades a fatal failure from an ancestor mutation to all its dependent children.
  /// Quarantines dependent children with status FAILED_FATAL and reason PARENT_FAILED_FATAL.
  Future<int> cascadeFatalChildren(
    String parentOperationId, {
    String reason = 'PARENT_FAILED_FATAL',
    Set<String>? visitedOperationIds,
  }) async {
    final visited = visitedOperationIds ?? <String>{};
    if (visited.contains(parentOperationId)) {
      return 0;
    }
    visited.add(parentOperationId);

    final parent = await getEntryByOperationId(parentOperationId);
    if (parent == null) return 0;

    const terminalStatuses = [
      SyncOutboxStatus.synced,
      SyncOutboxStatus.failedFatal,
      statusQuarantined,
      statusDeadLetter,
    ];

    // Find direct dependent children:
    // (a) Dependent via dependsOnOperationId
    // (b) Dependent via same entity aggregate (subsequent un-synced operations for same entity)
    final directChildren = await (select(syncOutbox)
          ..where((t) =>
              (t.dependsOnOperationId.equals(parentOperationId) |
                  (t.entityType.equals(parent.entityType) &
                      t.entityId.equals(parent.entityId) &
                      t.id.isBiggerThanValue(parent.id))) &
              t.status.isNotIn(terminalStatuses)))
        .get();

    if (directChildren.isEmpty) {
      return 0;
    }

    int cascadedCount = 0;
    for (final child in directChildren) {
      final conflictDetailsJson = jsonEncode({
        'reason': reason,
        'parentOperationId': parentOperationId,
        'parentEntityType': parent.entityType,
        'parentEntityId': parent.entityId,
      });

      final updated = await (update(syncOutbox)..where((t) => t.id.equals(child.id))).write(
        SyncOutboxCompanion(
          status: const Value(SyncOutboxStatus.failedFatal),
          lastError: Value('PARENT_FAILED_FATAL: Dependency $parentOperationId failed fatally'),
          conflictDetails: Value(conflictDetailsJson),
          retryCount: const Value(99),
        ),
      );

      if (updated > 0) {
        cascadedCount += updated;

        try {
          await db.into(db.syncConflicts).insert(
                SyncConflictsCompanion(
                  id: Value(const Uuid().v7()),
                  operationId: Value(child.operationId),
                  entityType: Value(child.entityType),
                  entityId: Value(child.entityId),
                  conflictType: const Value(ConflictType.fatalError),
                  resolutionStatus: const Value(ConflictResolutionStatus.pending),
                  errorMessage: Value('PARENT_FAILED_FATAL: Dependency $parentOperationId failed fatally'),
                  payload: Value(child.payload),
                  createdAt: Value(DateTime.now()),
                ),
              );
        } catch (_) {}

        // Transitively cascade to children of this child
        cascadedCount += await cascadeFatalChildren(
          child.operationId,
          reason: reason,
          visitedOperationIds: visited,
        );
      }
    }

    return cascadedCount;
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

    final candidates = await query.get();
    final result = <SyncOutboxEntry>[];
    for (final candidate in candidates) {
      if (candidate.dependsOnOperationId != null &&
          await hasFatalAncestor(candidate)) {
        await markFailedFatal(
          candidate.id,
          error: 'PARENT_FAILED_FATAL: Ancestor operation failed fatally',
          conflictDetails: jsonEncode({
            'reason': 'PARENT_FAILED_FATAL',
            'dependsOnOperationId': candidate.dependsOnOperationId,
          }),
        );
        continue;
      }

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
  }) async {
    final entry = await (select(syncOutbox)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (entry == null) return 0;

    // Never overwrite an already fatal or quarantined entry back to retryable
    if (entry.status == SyncOutboxStatus.failedFatal ||
        entry.status == statusQuarantined ||
        entry.status == statusDeadLetter) {
      return 0;
    }

    // Never mark retryable if an ancestor ended in FAILED_FATAL
    if (await hasFatalAncestor(entry)) {
      return await markFailedFatal(
        id,
        error: 'PARENT_FAILED_FATAL: Ancestor operation failed fatally',
        conflictDetails: jsonEncode({
          'reason': 'PARENT_FAILED_FATAL',
          'dependsOnOperationId': entry.dependsOnOperationId,
        }),
      );
    }

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
  /// Deviation #3 / #18: Marks all pending and retryable entries as AUTH_PAUSED when re-login is required.
  Future<int> markAllPendingAuthPaused({required String error}) {
    return (update(syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.pending) |
              t.status.equals(SyncOutboxStatus.failedRetryable)))
        .write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.authPaused),
        lastError: Value(error),
      ),
    );
  }

  Future<int> resumeAuthPaused() {
    return (update(syncOutbox)..where((t) => t.status.equals(SyncOutboxStatus.authPaused))).write(
      const SyncOutboxCompanion(
        status: Value(SyncOutboxStatus.pending),
      ),
    );
  }

  Future<int> markFailedFatal(int id, {required String error, String? conflictDetails}) async {
    final entry = await (select(syncOutbox)..where((t) => t.id.equals(id))).getSingleOrNull();

    final count = await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.failedFatal),
        lastError: Value(error),
        conflictDetails: Value(conflictDetails),
      ),
    );

    if (entry != null) {
      await cascadeFatalChildren(entry.operationId, reason: 'PARENT_FAILED_FATAL');
    }

    return count;
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
      'details': details,
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
    final entry = await (select(syncOutbox)..where((t) => t.id.equals(id))).getSingleOrNull();

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

      if (entry != null) {
        await cascadeFatalChildren(entry.operationId, reason: 'PARENT_FAILED_FATAL');
      }
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

  /// Non-terminal outbox queue states (D-04 / SYNC-027).
  static const List<String> nonTerminalStatuses = [
    SyncOutboxStatus.pending,
    SyncOutboxStatus.failedRetryable,
    SyncOutboxStatus.inFlight,
    SyncOutboxStatus.authPaused,
  ];

  /// Counts non-terminal outbox rows (pending, failed-retryable, in-flight, auth-paused).
  Future<int> getNonTerminalCount() async {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.status.isIn(nonTerminalStatuses));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Counts pending and retryable order mutations in outbox (excluding quarantined, fatal, and conflict) (MNY-06).
  Future<int> getPendingOrderCount() async {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.entityType.equals('order') &
          syncOutbox.status.isIn(nonTerminalStatuses));
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Reactive stream of pending and retryable order mutations count (MNY-06).
  Stream<int> watchPendingOrderCount() {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.entityType.equals('order') &
          syncOutbox.status.isIn(nonTerminalStatuses));
    return query.map((row) => row.read(countExpr) ?? 0).watchSingle();
  }

  /// Reactive stream of non-terminal outbox rows count.
  Stream<int> watchNonTerminalCount() {
    final countExpr = syncOutbox.id.count();
    final query = selectOnly(syncOutbox)
      ..addColumns([countExpr])
      ..where(syncOutbox.status.isIn(nonTerminalStatuses));
    return query.map((row) => row.read(countExpr) ?? 0).watchSingle();
  }

  /// Retrieves non-terminal outbox rows ordered by dependency and creation date.
  Future<List<SyncOutboxEntry>> getNonTerminalEntries() {
    return (select(syncOutbox)
          ..where((t) => t.status.isIn(nonTerminalStatuses))
          ..orderBy([
            (t) => OrderingTerm.asc(t.dependencyOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  /// Retrieves permanently failed outbox entries (4xx business errors, FAILED_FATAL, CONFLICT, QUARANTINED, DEAD_LETTER).
  Future<List<SyncOutboxEntry>> getPermanentlyFailedEntries() {
    return (select(syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.failedFatal) |
              t.status.equals(SyncOutboxStatus.conflict) |
              t.status.equals(statusQuarantined) |
              t.status.equals(statusDeadLetter))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Reactive stream of permanently failed outbox entries.
  Stream<List<SyncOutboxEntry>> watchPermanentlyFailedEntries() {
    return (select(syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.failedFatal) |
              t.status.equals(SyncOutboxStatus.conflict) |
              t.status.equals(statusQuarantined) |
              t.status.equals(statusDeadLetter))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Serializes all pending/non-terminal and failed outbox entries to diagnostic JSON (D-04).
  /// Every pending and failed row is included with its metadata and payload.
  Future<String> exportOutboxBackupJson() async {
    final nonTerminal = await getNonTerminalEntries();
    final failed = await getPermanentlyFailedEntries();
    final allToExport = [...nonTerminal, ...failed];

    final list = allToExport.map((e) {
      dynamic parsedPayload;
      try {
        parsedPayload = jsonDecode(e.payload);
      } catch (_) {
        parsedPayload = e.payload;
      }

      return {
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
        'sentAt': e.sentAt?.toIso8601String(),
        'ackedAt': e.ackedAt?.toIso8601String(),
        'lastError': e.lastError,
        'conflictDetails': e.conflictDetails,
        'payload': parsedPayload,
      };
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'pendingCount': nonTerminal.length,
      'failedCount': failed.length,
      'totalExported': list.length,
      'entries': list,
    });
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
