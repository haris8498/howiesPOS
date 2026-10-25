import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/tables/local_daily_calculations_table.dart';
import '../../core/database/tables/sync_outbox_table.dart';
import '../../domain/repositories/shift_repository.dart';

/// Drift Offline-First Shift Repository per Architecture Spec §5.2, §6.3, §7.3, §8.3(3), §21 Decision 2.
///
/// Core Invariants:
/// 1. ACID Durability: Shift open/close writes `local_daily_calculations` + `sync_outbox` in ONE atomic transaction.
/// 2. Dependency Graph (§6.3):
///    - Level 0 (dependency_order: 0): Shift Session open (INSERT)
///    - Level 5 (dependency_order: 5): Shift Close (UPDATE)
/// 3. Cash Variance (§21 Decision 2):
///    - Records expected cash, counted cash, variance (shortage/overage).
///    - Blocks nothing based on variance size.
///    - No threshold alerts, no SMS/email, no supervisor PIN.
/// 4. Idempotency:
///    - Duplicate close calls for the same shift return cleanly without duplicate queue mutations.
class DriftOfflineFirstShiftRepository implements IShiftRepository {
  final AppDatabase _db;
  final String _deviceId;
  final Uuid _uuid;

  DriftOfflineFirstShiftRepository({
    required AppDatabase db,
    String deviceId = 'POS-P1',
    Uuid? uuid,
  })  : _db = db,
        _deviceId = deviceId,
        _uuid = uuid ?? const Uuid();

  @override
  Future<LocalDailyCalculation> openShift({
    required String cashierId,
    required String cashierName,
    required double startingCash,
    String? shiftName,
    String? shiftId,
  }) async {
    return await _db.transaction(() async {
      // 1. Check if shift already exists (idempotency)
      if (shiftId != null && shiftId.isNotEmpty) {
        final existing = await _db.dailyCalculationsDao.getCalculationById(shiftId);
        if (existing != null) {
          return existing;
        }
      }

      // Rule 1: Only ONE active shift at a time store-wide
      final activeShift = await _db.dailyCalculationsDao.getAnyActiveCalculation();
      if (activeShift != null) {
        throw StateError('You already have an active shift. Please close the current shift before opening a new one.');
      }

      final effectiveShiftId = (shiftId != null && shiftId.length == 36) ? shiftId : _uuid.v7();
      final now = DateTime.now();

      // 2. Insert into local_daily_calculations
      final shiftCompanion = LocalDailyCalculationsCompanion(
        id: Value(effectiveShiftId),
        cashierId: Value(cashierId),
        cashierName: Value(cashierName),
        startingCash: Value(startingCash),
        expectedCashDrawer: Value(startingCash),
        status: const Value(DailyCalculationStatus.active),
        createdAt: Value(now),
        syncStatus: const Value('pending_insert'),
        serverVersion: const Value(1),
      );
      await _db.dailyCalculationsDao.insertCalculation(shiftCompanion);

      // 3. Enqueue mutation into sync_outbox (Level 0: Shift Session per Spec §6.3)
      final operationId = _uuid.v7();
      final payload = {
        'id': effectiveShiftId,
        'shift_name': shiftName ?? 'Full Day',
        'cashier_id': cashierId,
        'cashier_name': cashierName,
        'starting_cash': startingCash,
        'opening_float': startingCash,
        'total_change_cash': startingCash,
        'status': DailyCalculationStatus.active,
        'created_at': now.toIso8601String(),
      };

      String? priorCloseOpId;
      final priorCloseOp = await (_db.select(_db.syncOutbox)
        ..where((t) =>
            t.entityType.equals('shift') &
            t.operationType.equals('UPDATE') &
            t.status.isIn([SyncOutboxStatus.pending, SyncOutboxStatus.failedRetryable]))
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(1))
        .getSingleOrNull();
      if (priorCloseOp != null) {
        priorCloseOpId = priorCloseOp.operationId;
      }

      final outboxCompanion = SyncOutboxCompanion(
        operationId: Value(operationId),
        deviceId: Value(_deviceId),
        entityType: const Value('shift'),
        entityId: Value(effectiveShiftId),
        operationType: const Value('INSERT'),
        baseVersion: const Value(1),
        payload: Value(jsonEncode(payload)),
        dependsOnOperationId: Value(priorCloseOpId),
        dependencyOrder: const Value(0), // Level 0: Shift Session (§6.3)
        status: const Value(SyncOutboxStatus.pending),
        retryCount: const Value(0),
        createdAt: Value(now),
      );
      await _db.outboxDao.insertEntry(outboxCompanion);

      return (await _db.dailyCalculationsDao.getCalculationById(effectiveShiftId))!;
    });
  }

  @override
  Future<LocalDailyCalculation> closeShift({
    required String shiftId,
    required double actualCashCounted,
    required double expectedCashDrawer,
    double? cashSubmitted,
    double? cashSkimming,
    double? cashVariance,
    String? varianceReason,
    String? closingNotes,
    String? dependsOnOperationId,
    List<Map<String, dynamic>>? expenseItems,
    bool forceClose = false,
  }) async {
    return await _db.transaction(() async {
      final existing = await _db.dailyCalculationsDao.getCalculationById(shiftId);
      if (existing == null) {
        throw StateError('Shift $shiftId not found in local database');
      }

      // Idempotency check: Already closed offline
      if (existing.status == DailyCalculationStatus.offlineClosed ||
          existing.status == DailyCalculationStatus.closed) {
        return existing;
      }

      // Rule 2: Cannot close shift if pending orders exist
      final sessionStart = existing.createdAt;
      final pendingOrders = await (_db.select(_db.localOrders)
        ..where((t) =>
          (t.shiftId.equals(shiftId) |
            (t.shiftId.isNull() & t.createdAt.isBiggerOrEqualValue(sessionStart))) &
          t.status.isNotIn(['completed', 'cancelled', 'rejected'])))
        .get();
            if (pendingOrders.isNotEmpty) {
        if (forceClose) {
          for (final ord in pendingOrders) {
            final isPaid = ord.isPaid == true || ord.paymentStatus == 'paid';
            final resolvedStatus = isPaid ? 'completed' : 'cancelled';
            await (_db.update(_db.localOrders)..where((t) => t.id.equals(ord.id))).write(
              LocalOrdersCompanion(
                status: Value(resolvedStatus),
                shiftId: Value(shiftId),
              ),
            );
            final autoOpId = _uuid.v7();
            await _db.outboxDao.insertEntry(
              SyncOutboxCompanion(
                operationId: Value(autoOpId),
                deviceId: Value(_deviceId),
                entityType: const Value('order'),
                entityId: Value(ord.id),
                operationType: const Value('UPDATE'),
                baseVersion: Value(ord.serverVersion),
                payload: Value(jsonEncode({
                  'id': ord.id,
                  'status': resolvedStatus,
                  'shift_id': shiftId,
                })),
                dependencyOrder: const Value(2),
                status: const Value(SyncOutboxStatus.pending),
                retryCount: const Value(0),
                createdAt: Value(DateTime.now()),
              ),
            );
          }
        } else {
          throw StateError(
            'Cannot close this shift because there are ' + pendingOrders.length.toString() + ' pending orders. ' +
            'Please complete or resolve all pending orders before closing the shift.',
          );
        }
      }

      // Calculate cash variance (negative = shortage, positive = overage) per Spec §21 Decision 2
      final effectiveVariance = cashVariance ?? (actualCashCounted - expectedCashDrawer);
      final submittedAt = DateTime.now();

      // If pending INSERT mutation exists for this shift, mark it OFFLINE_CLOSED
      final shiftInsertEntry = await (_db.select(_db.syncOutbox)
        ..where((t) =>
            t.entityType.equals('shift') &
            t.entityId.equals(shiftId) &
            t.operationType.equals('INSERT') &
            t.status.equals(SyncOutboxStatus.pending)))
        .getSingleOrNull();
      if (shiftInsertEntry != null) {
        try {
          final decoded = jsonDecode(shiftInsertEntry.payload) as Map<String, dynamic>;
          decoded['status'] = DailyCalculationStatus.offlineClosed;
          await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(shiftInsertEntry.id))).write(
            SyncOutboxCompanion(
              payload: Value(jsonEncode(decoded)),
            ),
          );
        } catch (_) {}
      }

      String? effectiveDependsOn = dependsOnOperationId;
      if (effectiveDependsOn == null) {
        final lastOp = await (_db.select(_db.syncOutbox)
          ..where((t) => t.status.isIn([SyncOutboxStatus.pending, SyncOutboxStatus.failedRetryable]))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
          .getSingleOrNull();
        if (lastOp != null) {
          effectiveDependsOn = lastOp.operationId;
        }
      }

      // 1. Update local_daily_calculations table
      await _db.dailyCalculationsDao.closeShiftOffline(
        id: shiftId,
        actualCashCounted: actualCashCounted,
        expectedCashDrawer: expectedCashDrawer,
        cashVariance: effectiveVariance,
        closingNotes: closingNotes,
        submittedAt: submittedAt,
      );

      // 2. Enqueue mutation into sync_outbox (Level 5: Shift Close per Spec §6.3)
      final operationId = _uuid.v7();
      final payload = {
        'id': shiftId,
        'shift_id': shiftId,
        'cashier_id': existing.cashierId,
        'cashier_name': existing.cashierName,
        'starting_cash': existing.startingCash,
        'actual_cash_counted': actualCashCounted,
        'expected_cash_drawer': expectedCashDrawer,
        'cash_submitted': cashSubmitted ?? actualCashCounted,
        'cash_skimming': cashSkimming ?? 0.0,
        'cash_variance': effectiveVariance,
        'variance_amount': effectiveVariance,
        'variance_reason': varianceReason,
        'status': DailyCalculationStatus.offlineClosed,
        'closing_notes': closingNotes,
        'submitted_at': submittedAt.toIso8601String(),
        if (expenseItems != null) 'expense_items': expenseItems,
      };

      final outboxCompanion = SyncOutboxCompanion(
        operationId: Value(operationId),
        deviceId: Value(_deviceId),
        entityType: const Value('shift'),
        entityId: Value(shiftId),
        operationType: const Value('UPDATE'),
        baseVersion: Value(existing.serverVersion),
        payload: Value(jsonEncode(payload)),
        dependsOnOperationId: Value(effectiveDependsOn),
        dependencyOrder: const Value(5), // Level 5: Shift Close (§6.3)
        status: const Value(SyncOutboxStatus.pending),
        retryCount: const Value(0),
        createdAt: Value(submittedAt),
      );
      await _db.outboxDao.insertEntry(outboxCompanion);

      return (await _db.dailyCalculationsDao.getCalculationById(shiftId))!;
    });
  }

  @override
  Future<LocalDailyCalculation?> getActiveShift(String cashierId) async {
    if (cashierId.isNotEmpty) {
      final byCashier = await _db.dailyCalculationsDao.getActiveCalculation(cashierId);
      if (byCashier != null) return byCashier;
    }
    return await _db.dailyCalculationsDao.getAnyActiveCalculation();
  }

  @override
  Stream<LocalDailyCalculation?> watchActiveShift(String cashierId) {
    return _db.dailyCalculationsDao.watchActiveCalculation(cashierId);
  }

  @override
  Future<LocalDailyCalculation?> getShiftById(String shiftId) {
    return _db.dailyCalculationsDao.getCalculationById(shiftId);
  }

  @override
  Future<void> markShiftClosedLocally({
    required String shiftId,
    DateTime? closedAt,
    String? closingNotes,
  }) async {
    await _db.dailyCalculationsDao.markShiftClosed(
      shiftId,
      closedAt: closedAt,
      closingNotes: closingNotes,
    );
  }
}
