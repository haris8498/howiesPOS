import 'package:drift/drift.dart';

/// Print job statuses per Spec §5.4.3
class PrintJobStatus {
  PrintJobStatus._();

  static const String queued = 'QUEUED';
  static const String printed = 'PRINTED';
  static const String failed = 'FAILED';
}

/// Print job types per Spec §5.4.3
class PrintJobType {
  PrintJobType._();

  static const String customerReceipt = 'CUSTOMER_RECEIPT';
  static const String kitchenTicket = 'KITCHEN_TICKET';
  static const String shiftZReport = 'SHIFT_Z_REPORT';
}

/// Durable Hardware Print Spooler Queue per Architecture Spec §5.4.3
@DataClassName('OfflinePrintJob')
class OfflinePrintJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobType => text()(); // 'CUSTOMER_RECEIPT', 'KITCHEN_TICKET', 'SHIFT_Z_REPORT'
  TextColumn get orderId => text().nullable()();
  TextColumn get printerTarget => text()(); // 'USB001', 'COM1', 'WIN_DEFAULT'
  BlobColumn get rawEscPosData => blob()();
  TextColumn get status => text().withDefault(const Constant('QUEUED'))(); // 'QUEUED', 'PRINTED', 'FAILED'
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
