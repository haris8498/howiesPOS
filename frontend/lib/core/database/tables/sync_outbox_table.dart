import 'package:drift/drift.dart';

/// Standard Outbox queue states per Spec §6.2 and Approved Deviation #3.
class SyncOutboxStatus {
  SyncOutboxStatus._();

  static const String pending = 'PENDING';
  static const String inFlight = 'IN_FLIGHT';
  static const String synced = 'SYNCED';
  static const String failedRetryable = 'FAILED_RETRYABLE';
  static const String failedFatal = 'FAILED_FATAL';
  static const String conflict = 'CONFLICT';

  /// Approved Deviation #3: HTTP 401 Unauthorized pauses the queue without fatal quarantine.
  static const String authPaused = 'AUTH_PAUSED';
}

/// Outbox Queue Table Schema per Spec §6.1
@DataClassName('SyncOutboxEntry')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operationId => text().withLength(min: 36, max: 36).unique()(); // UUID v7
  TextColumn get deviceId => text().withLength(min: 1, max: 50)(); // 'POS-P1'
  TextColumn get entityType => text().withLength(min: 1, max: 50)(); // 'order', 'shift', etc.
  TextColumn get entityId => text().withLength(min: 36, max: 36)(); // Entity UUID
  TextColumn get operationType => text().withLength(min: 1, max: 20)(); // 'INSERT', 'UPDATE'
  IntColumn get baseVersion => integer().withDefault(const Constant(1))();
  TextColumn get payload => text()(); // Serialized JSON
  TextColumn get dependsOnOperationId => text().withLength(min: 36, max: 36).nullable()();
  IntColumn get dependencyOrder => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withLength(min: 1, max: 20).withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get ackedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get conflictDetails => text().nullable()();
}
