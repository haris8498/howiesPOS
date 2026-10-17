import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/terminal_sequences_table.dart';

part 'terminal_sequences_dao.g.dart';

@DriftAccessor(tables: [TerminalSequences])
class TerminalSequencesDao extends DatabaseAccessor<AppDatabase> with _$TerminalSequencesDaoMixin {
  TerminalSequencesDao(super.db);

  /// Atomically increments the terminal sequence counter for [sequenceKey]
  /// on the given [businessDate] (e.g. '2026-10-17') per Spec §4.3.
  /// If the date has rolled over, resets the counter to [start] (default 101).
  /// If the sequence exceeds [max] (default 999), cycles back to [start].
  Future<int> getNextSequence(
    String sequenceKey,
    String businessDate, {
    int start = 101,
    int max = 999,
  }) {
    return transaction(() async {
      final existing = await (select(terminalSequences)..where((t) => t.sequenceKey.equals(sequenceKey)))
          .getSingleOrNull();

      int nextValue;
      if (existing == null || existing.businessDate != businessDate) {
        nextValue = start;
      } else {
        nextValue = existing.currentValue + 1;
        if (nextValue > max) {
          nextValue = start;
        }
      }

      await into(terminalSequences).insertOnConflictUpdate(
        TerminalSequencesCompanion(
          sequenceKey: Value(sequenceKey),
          businessDate: Value(businessDate),
          currentValue: Value(nextValue),
        ),
      );

      return nextValue;
    });
  }

  Future<TerminalSequence?> getSequenceRecord(String sequenceKey) {
    return (select(terminalSequences)..where((t) => t.sequenceKey.equals(sequenceKey))).getSingleOrNull();
  }

  Future<void> setSequence(String sequenceKey, String businessDate, int value) {
    return into(terminalSequences).insertOnConflictUpdate(
      TerminalSequencesCompanion(
        sequenceKey: Value(sequenceKey),
        businessDate: Value(businessDate),
        currentValue: Value(value),
      ),
    );
  }
}
