// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_dao.dart';

// ignore_for_file: type=lint
mixin _$OrdersDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalOrdersTable get localOrders => attachedDatabase.localOrders;
  $LocalOrderItemsTable get localOrderItems => attachedDatabase.localOrderItems;
  $LocalOrderPaymentsTable get localOrderPayments =>
      attachedDatabase.localOrderPayments;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  $OfflinePrintJobsTable get offlinePrintJobs =>
      attachedDatabase.offlinePrintJobs;
  OrdersDaoManager get managers => OrdersDaoManager(this);
}

class OrdersDaoManager {
  final _$OrdersDaoMixin _db;
  OrdersDaoManager(this._db);
  $$LocalOrdersTableTableManager get localOrders =>
      $$LocalOrdersTableTableManager(_db.attachedDatabase, _db.localOrders);
  $$LocalOrderItemsTableTableManager get localOrderItems =>
      $$LocalOrderItemsTableTableManager(
        _db.attachedDatabase,
        _db.localOrderItems,
      );
  $$LocalOrderPaymentsTableTableManager get localOrderPayments =>
      $$LocalOrderPaymentsTableTableManager(
        _db.attachedDatabase,
        _db.localOrderPayments,
      );
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
  $$OfflinePrintJobsTableTableManager get offlinePrintJobs =>
      $$OfflinePrintJobsTableTableManager(
        _db.attachedDatabase,
        _db.offlinePrintJobs,
      );
}
