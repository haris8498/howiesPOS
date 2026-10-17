import 'package:drift/drift.dart';

/// Terminal sequence counters per Architecture Spec §5.4.1.
/// Used for deterministic human-readable order numbers (e.g., P1-101).
@DataClassName('TerminalSequence')
class TerminalSequences extends Table {
  TextColumn get sequenceKey => text().withLength(min: 1, max: 30)(); // 'ORDER_NUMBER'
  TextColumn get businessDate => text().withLength(min: 8, max: 10)(); // '2026-10-17'
  IntColumn get currentValue => integer()();

  @override
  Set<Column> get primaryKey => {sequenceKey};
}
