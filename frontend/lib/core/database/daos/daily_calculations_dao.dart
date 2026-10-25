import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/local_daily_calculations_table.dart';

part 'daily_calculations_dao.g.dart';

@DriftAccessor(tables: [LocalDailyCalculations])
class DailyCalculationsDao extends DatabaseAccessor<AppDatabase> with _$DailyCalculationsDaoMixin {
  DailyCalculationsDao(super.db);

  Future<int> insertCalculation(LocalDailyCalculationsCompanion entry) {
    return into(localDailyCalculations).insert(entry);
  }

  Future<LocalDailyCalculation?> getCalculationById(String id) {
    return (select(localDailyCalculations)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<LocalDailyCalculation?> getActiveCalculation(String cashierId) {
    return (select(localDailyCalculations)
      ..where((t) => t.cashierId.equals(cashierId) & t.status.equals(DailyCalculationStatus.active))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1))
      .getSingleOrNull();
  }

  /// Check if ANY active shift exists store-wide
  Future<LocalDailyCalculation?> getAnyActiveCalculation() {
    return (select(localDailyCalculations)
      ..where((t) => t.status.equals(DailyCalculationStatus.active))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1))
      .getSingleOrNull();
  }

  Stream<LocalDailyCalculation?> watchActiveCalculation(String cashierId) {
    return (select(localDailyCalculations)
      ..where((t) => t.cashierId.equals(cashierId) & t.status.equals(DailyCalculationStatus.active))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1))
      .watchSingleOrNull();
  }

  /// Closes an active shift offline with recorded cash variance per Spec §5.2 and §21.2.
  Future<int> closeShiftOffline({
    required String id,
    required double actualCashCounted,
    required double cashVariance,
    double? expectedCashDrawer,
    String? closingNotes,
    DateTime? submittedAt,
  }) {
    return (update(localDailyCalculations)..where((t) => t.id.equals(id))).write(
      LocalDailyCalculationsCompanion(
        status: const Value(DailyCalculationStatus.offlineClosed),
        actualCashCounted: Value(actualCashCounted),
        expectedCashDrawer: expectedCashDrawer != null ? Value(expectedCashDrawer) : const Value.absent(),
        cashVariance: Value(cashVariance),
        closingNotes: Value(closingNotes),
        submittedAt: Value(submittedAt ?? DateTime.now()),
        syncStatus: const Value('pending_update'),
      ),
    );
  }

  Future<int> markCalculationSynced(String id, int serverVersion) {
    return (update(localDailyCalculations)..where((t) => t.id.equals(id))).write(
      LocalDailyCalculationsCompanion(
        syncStatus: const Value('synced'),
        serverVersion: Value(serverVersion),
      ),
    );
  }
  Future<int> markShiftClosed(String id, {DateTime? closedAt, String? closingNotes}) {
    return (update(localDailyCalculations)..where((t) => t.id.equals(id))).write(
      LocalDailyCalculationsCompanion(
        status: const Value(DailyCalculationStatus.closed),
        submittedAt: Value(closedAt ?? DateTime.now()),
        closingNotes: Value(closingNotes),
        syncStatus: const Value('synced'),
      ),
    );
  }
}
