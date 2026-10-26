import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SYNC-021: SyncOutbox Composite Indexes Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('indexes idx_sync_outbox_queue and idx_sync_outbox_entity exist on sync_outbox', () async {
      // Trigger database opening and beforeOpen callback
      final rows = await db.customSelect("PRAGMA index_list('sync_outbox');").get();
      final indexNames = rows.map((r) => r.read<String>('name')).toList();

      expect(indexNames, contains('idx_sync_outbox_queue'));
      expect(indexNames, contains('idx_sync_outbox_entity'));
    });
  });
}
