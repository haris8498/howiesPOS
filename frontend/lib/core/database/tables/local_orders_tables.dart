import 'package:drift/drift.dart';

/// Replicated Operational Tables per Architecture Spec §5.2

@DataClassName('LocalOrder')
class LocalOrders extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)(); // UUID v7 PK
  TextColumn get orderNumber => text().withLength(min: 1, max: 30)(); // 'P1-101'
  TextColumn get orderType => text().withLength(min: 1, max: 30)(); // 'dineIn', 'takeaway', 'online'
  TextColumn get shiftId => text().withLength(min: 36, max: 36).nullable()();
  TextColumn get status => text().withLength(min: 1, max: 30).withDefault(const Constant('newOrder'))();
  RealColumn get subtotal => real()();
  RealColumn get discountPercentage => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real()();
  TextColumn get paymentStatus => text().withLength(min: 1, max: 20).withDefault(const Constant('UNPAID'))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  BoolColumn get isHeld => boolean().withDefault(const Constant(false))();
  BoolColumn get kitchenTicketSent => boolean().withDefault(const Constant(false))();
  TextColumn get rejectionReason => text().nullable()();
  TextColumn get deviceId => text().withLength(min: 1, max: 50)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync Metadata
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get clientUpdatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalOrderItem')
class LocalOrderItems extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)(); // UUID v7
  TextColumn get orderId => text().references(LocalOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get menuItemId => text().nullable()();
  TextColumn get itemName => text()();
  TextColumn get sizeName => text().nullable()();
  RealColumn get unitPrice => real()();
  IntColumn get quantity => integer()();
  RealColumn get subtotal => real()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCancelled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelReason => text().nullable()();

  // D-05 (SYNC-032) Order line-item ledger columns
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidedBy => text().nullable()();
  TextColumn get supersedesItemId => text().nullable()();
  TextColumn get createdByDeviceId => text().nullable()();
  DateTimeColumn get clientCreatedAt => dateTime().nullable()();

  // Sync Metadata
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalOrderPayment')
class LocalOrderPayments extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)(); // UUID v7
  TextColumn get orderId => text().references(LocalOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get paymentMethod => text()(); // 'cash', 'card', 'bankTransfer', 'split'
  RealColumn get amount => real()();
  RealColumn get tenderedAmount => real().nullable()();
  RealColumn get changeReturned => real().nullable()();
  TextColumn get transactionReference => text().nullable()();
  TextColumn get cardLastFour => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get paymentStatus => text().withDefault(const Constant('COMPLETED'))();
  TextColumn get receivedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Sync Metadata
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();

  @override
  Set<Column> get primaryKey => {id};
}
