import '../../core/database/app_database.dart';

/// Abstract contract for Shift (DailyCalculation) persistence and lifecycle per Spec §5.2, §7.3, §21 Decision 2.
abstract class IShiftRepository {
  /// Opens a shift session atomically (Level 0: Shift Session).
  Future<LocalDailyCalculation> openShift({
    required String cashierId,
    required String cashierName,
    required double startingCash,
    String? shiftName,
    String? shiftId,
  });

  /// Closes a shift session atomically with recorded cash variance (Level 5: Shift Close).
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
  });

  /// Retrieves currently active shift for a cashier, if any.
  Future<LocalDailyCalculation?> getActiveShift(String cashierId);

  /// Reactive stream for the active shift session.
  Stream<LocalDailyCalculation?> watchActiveShift(String cashierId);

  /// Retrieves a specific shift calculation by ID.
  Future<LocalDailyCalculation?> getShiftById(String shiftId);

  /// Marks a shift as closed locally in Drift SQLite cache.
  Future<void> markShiftClosedLocally({
    required String shiftId,
    DateTime? closedAt,
    String? closingNotes,
  });
}
