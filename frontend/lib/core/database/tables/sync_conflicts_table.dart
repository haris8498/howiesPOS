import 'package:drift/drift.dart';

/// Conflict resolution status
class ConflictResolutionStatus {
  ConflictResolutionStatus._();

  static const String pending = 'PENDING';
  static const String autoResolved = 'AUTO_RESOLVED';
  static const String supervisorAcknowledged = 'SUPERVISOR_ACKNOWLEDGED';
}

/// Conflict types
class ConflictType {
  ConflictType._();

  static const String occMismatch = 'OCC_MISMATCH';
  static const String invariantViolation = 'INVARIANT_VIOLATION';
  static const String fatalError = 'FATAL_ERROR';
  static const String tableCollision = 'TABLE_COLLISION';
}

/// Sync conflicts quarantine registry per Spec §3.3 (Tier 5) and §20 (Risk #6)
@DataClassName('SyncConflict')
class SyncConflicts extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)(); // UUID v7
  TextColumn get operationId => text().withLength(min: 36, max: 36)();
  TextColumn get entityType => text().withLength(min: 1, max: 50)();
  TextColumn get entityId => text().withLength(min: 36, max: 36)();
  TextColumn get conflictType => text()(); // e.g. 'OCC_MISMATCH', 'FATAL_ERROR'
  TextColumn get resolutionStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get payload => text()();
  TextColumn get serverState => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
