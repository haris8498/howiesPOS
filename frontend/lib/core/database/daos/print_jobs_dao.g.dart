// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_jobs_dao.dart';

// ignore_for_file: type=lint
mixin _$PrintJobsDaoMixin on DatabaseAccessor<AppDatabase> {
  $OfflinePrintJobsTable get offlinePrintJobs =>
      attachedDatabase.offlinePrintJobs;
  PrintJobsDaoManager get managers => PrintJobsDaoManager(this);
}

class PrintJobsDaoManager {
  final _$PrintJobsDaoMixin _db;
  PrintJobsDaoManager(this._db);
  $$OfflinePrintJobsTableTableManager get offlinePrintJobs =>
      $$OfflinePrintJobsTableTableManager(
        _db.attachedDatabase,
        _db.offlinePrintJobs,
      );
}
