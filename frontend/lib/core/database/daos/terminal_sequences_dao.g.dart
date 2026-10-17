// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminal_sequences_dao.dart';

// ignore_for_file: type=lint
mixin _$TerminalSequencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $TerminalSequencesTable get terminalSequences =>
      attachedDatabase.terminalSequences;
  TerminalSequencesDaoManager get managers => TerminalSequencesDaoManager(this);
}

class TerminalSequencesDaoManager {
  final _$TerminalSequencesDaoMixin _db;
  TerminalSequencesDaoManager(this._db);
  $$TerminalSequencesTableTableManager get terminalSequences =>
      $$TerminalSequencesTableTableManager(
        _db.attachedDatabase,
        _db.terminalSequences,
      );
}
