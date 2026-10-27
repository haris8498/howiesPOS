import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';

void main() {
  group('Drift Schema Version & Migration Scaffold Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Schema version is 3 and all 20 tables are initialized with D-05 ledger columns', () async {
      expect(db.schemaVersion, equals(3));

      // Execute query to ensure database opens and schema migration runs
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      ).get();

      final tableNames = tables.map((row) => row.read<String>('name')).toSet();

      // Verify all Spec §5 tables are created
      final expectedTables = {
        'local_orders',
        'local_order_items',
        'local_order_payments',
        'sync_outbox',
        'terminal_sequences',
        'offline_print_jobs',
        'sync_cursors',
        'sync_conflicts',
        'local_daily_calculations',
        'local_menu_categories',
        'local_menu_items',
        'local_menu_item_sizes',
        'local_menu_item_options',
        'local_deals',
        'local_deal_components',
        'local_restaurant_tables',
        'local_floor_zones',
        'local_staff_users',
        'local_role_permissions',
        'local_store_settings',
      };

      for (final expected in expectedTables) {
        expect(tableNames.contains(expected), isTrue,
            reason: 'Expected table $expected to exist in SQLite schema');
      }

      final tableColumns = await db.customSelect("PRAGMA table_info('local_restaurant_tables');").get();
      final columnNames = tableColumns.map((row) => row.read<String>('name')).toSet();
      expect(columnNames.contains('is_deleted'), isTrue,
          reason: 'Expected is_deleted column to exist on local_restaurant_tables');

      // Verify D-05 (SYNC-032) ledger columns on local_order_items
      final orderItemColumns = await db.customSelect("PRAGMA table_info('local_order_items');").get();
      final itemColNames = orderItemColumns.map((row) => row.read<String>('name')).toSet();
      expect(itemColNames.contains('voided_at'), isTrue);
      expect(itemColNames.contains('voided_by'), isTrue);
      expect(itemColNames.contains('supersedes_item_id'), isTrue);
      expect(itemColNames.contains('created_by_device_id'), isTrue);
      expect(itemColNames.contains('client_created_at'), isTrue);
    });

    test('beforeOpen enforces foreign keys PRAGMA', () async {
      final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      final foreignKeysEnabled = result.data.values.first;
      expect(foreignKeysEnabled, equals(1));
    });
  });
}
