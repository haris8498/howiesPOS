// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_cursors_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncCursorsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncCursorsTable get syncCursors => attachedDatabase.syncCursors;
  SyncCursorsDaoManager get managers => SyncCursorsDaoManager(this);
}

class SyncCursorsDaoManager {
  final _$SyncCursorsDaoMixin _db;
  SyncCursorsDaoManager(this._db);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db.attachedDatabase, _db.syncCursors);
}
