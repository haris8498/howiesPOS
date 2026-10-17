import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sync_cursors_table.dart';

part 'sync_cursors_dao.g.dart';

@DriftAccessor(tables: [SyncCursors])
class SyncCursorsDao extends DatabaseAccessor<AppDatabase> with _$SyncCursorsDaoMixin {
  SyncCursorsDao(super.db);

  /// Retrieves the sync cursor record for the given [feedKey].
  Future<SyncCursor?> getCursor(String feedKey) {
    return (select(syncCursors)..where((t) => t.feedKey.equals(feedKey))).getSingleOrNull();
  }

  /// Retrieves the last successfully pulled sequence number for [feedKey], returning 0 if not yet synced.
  Future<int> getLastPulledSequence(String feedKey) async {
    final cursor = await getCursor(feedKey);
    return cursor?.lastPulledSequence ?? 0;
  }

  /// Sets or updates the cursor position for [feedKey].
  Future<void> setCursor(
    String feedKey,
    int lastPulledSequence, {
    DateTime? lastSyncAttempt,
    DateTime? lastSuccessfulSync,
  }) {
    return into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion(
        feedKey: Value(feedKey),
        lastPulledSequence: Value(lastPulledSequence),
        lastSyncAttempt: Value(lastSyncAttempt),
        lastSuccessfulSync: Value(lastSuccessfulSync),
      ),
    );
  }
}
