import 'package:drift/drift.dart';

/// Shift status per Spec §5.2 and §21.2
class DailyCalculationStatus {
  DailyCalculationStatus._();

  static const String active = 'ACTIVE';
  static const String offlineClosed = 'OFFLINE_CLOSED';
  static const String closed = 'CLOSED';
}

/// Local Daily Calculations (Shift Sessions & Cash Drawer) per Spec §5.2 and §21.2
@DataClassName('LocalDailyCalculation')
class LocalDailyCalculations extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)(); // UUID v7
  TextColumn get cashierId => text()();
  TextColumn get cashierName => text()();
  RealColumn get startingCash => real()();
  RealColumn get expectedCashDrawer => real().withDefault(const Constant(0.0))();
  RealColumn get actualCashCounted => real().nullable()();
  RealColumn get cashVariance => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))(); // 'ACTIVE', 'OFFLINE_CLOSED', 'CLOSED'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  TextColumn get closingNotes => text().nullable()();

  // Sync Metadata
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
