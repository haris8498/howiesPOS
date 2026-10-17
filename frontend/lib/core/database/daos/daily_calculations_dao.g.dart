// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_calculations_dao.dart';

// ignore_for_file: type=lint
mixin _$DailyCalculationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalDailyCalculationsTable get localDailyCalculations =>
      attachedDatabase.localDailyCalculations;
  DailyCalculationsDaoManager get managers => DailyCalculationsDaoManager(this);
}

class DailyCalculationsDaoManager {
  final _$DailyCalculationsDaoMixin _db;
  DailyCalculationsDaoManager(this._db);
  $$LocalDailyCalculationsTableTableManager get localDailyCalculations =>
      $$LocalDailyCalculationsTableTableManager(
        _db.attachedDatabase,
        _db.localDailyCalculations,
      );
}
