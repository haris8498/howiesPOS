import 'package:drift/drift.dart';

/// Sync cursors table for delta change-feed tracking per Spec §5.4.2
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  TextColumn get feedKey => text()(); // e.g. 'GLOBAL_PULL_CURSOR'
  IntColumn get lastPulledSequence => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncAttempt => dateTime().nullable()();
  DateTimeColumn get lastSuccessfulSync => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {feedKey};
}
