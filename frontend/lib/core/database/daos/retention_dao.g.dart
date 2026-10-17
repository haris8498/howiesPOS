// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retention_dao.dart';

// ignore_for_file: type=lint
mixin _$RetentionDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalOrdersTable get localOrders => attachedDatabase.localOrders;
  $SyncOutboxTable get syncOutbox => attachedDatabase.syncOutbox;
  $OfflinePrintJobsTable get offlinePrintJobs =>
      attachedDatabase.offlinePrintJobs;
  RetentionDaoManager get managers => RetentionDaoManager(this);
}

class RetentionDaoManager {
  final _$RetentionDaoMixin _db;
  RetentionDaoManager(this._db);
  $$LocalOrdersTableTableManager get localOrders =>
      $$LocalOrdersTableTableManager(_db.attachedDatabase, _db.localOrders);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db.attachedDatabase, _db.syncOutbox);
  $$OfflinePrintJobsTableTableManager get offlinePrintJobs =>
      $$OfflinePrintJobsTableTableManager(
        _db.attachedDatabase,
        _db.offlinePrintJobs,
      );
}
