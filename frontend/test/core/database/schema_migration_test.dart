import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Drift Schema Version & Migration Scaffold Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Schema version is 4 and all 20 tables are initialized with D-05 ledger columns and schema_version', () async {
      expect(db.schemaVersion, equals(4));

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

      // Verify OBX-12 (GitHub #21) schema_version on sync_outbox
      final outboxColumns = await db.customSelect("PRAGMA table_info('sync_outbox');").get();
      final outboxColNames = outboxColumns.map((row) => row.read<String>('name')).toSet();
      expect(outboxColNames.contains('schema_version'), isTrue,
          reason: 'Expected schema_version column to exist on sync_outbox');
    });

    test('beforeOpen enforces foreign keys PRAGMA', () async {
      final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      final foreignKeysEnabled = result.data.values.first;
      expect(foreignKeysEnabled, equals(1));
    });

    test('Migration test 1: Seed in-memory DB at v3 with one outbox row, open with AppDatabase: row survives with schemaVersion 1', () async {
      final rawDb = sqlite.sqlite3.openInMemory();

      // Seed sync_outbox table at schema v3 (no schema_version column)
      rawDb.execute('''
        CREATE TABLE sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          operation_id TEXT NOT NULL UNIQUE,
          device_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          base_version INTEGER NOT NULL DEFAULT 1,
          payload TEXT NOT NULL,
          depends_on_operation_id TEXT,
          dependency_order INTEGER NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'PENDING',
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          sent_at INTEGER,
          acked_at INTEGER,
          last_error TEXT,
          conflict_details TEXT
        );
      ''');

      // Seed one outbox row
      rawDb.execute('''
        INSERT INTO sync_outbox (
          operation_id, device_id, entity_type, entity_id, operation_type, base_version, payload
        ) VALUES (
          '018f2f45-0000-7000-8000-000000000001', 'POS-P1', 'order', '018f2f45-0000-7000-8000-000000000002', 'INSERT', 1, '{"test":true}'
        );
      ''');

      // Set DB user_version to 3
      rawDb.execute('PRAGMA user_version = 3;');

      // Open with AppDatabase (schemaVersion 4)
      final upgradedDb = AppDatabase(NativeDatabase.opened(rawDb));
      addTearDown(upgradedDb.close);

      // Verify the outbox row survives and Drift assigned default schemaVersion 1
      final entries = await upgradedDb.outboxDao.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries.first.operationId, equals('018f2f45-0000-7000-8000-000000000001'));
      expect(entries.first.schemaVersion, equals(1));

      // Verify user_version was upgraded to 4
      final versionResult = await upgradedDb.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data.values.first, equals(4));
    });

    test('Migration test 2: Open a DB seeded at v1 or v2: migrates all the way to v4 without error', () async {
      // Test DB seeded at v1
      final rawDbV1 = sqlite.sqlite3.openInMemory();

      // Seed tables at v1 (before v2 is_deleted, before v3 ledger columns, before v4 schema_version)
      rawDbV1.execute('''
        CREATE TABLE local_restaurant_tables (
          id TEXT NOT NULL PRIMARY KEY,
          table_number TEXT NOT NULL,
          status TEXT NOT NULL,
          zone_id TEXT,
          server_updated_at INTEGER,
          capacity INTEGER NOT NULL DEFAULT 4,
          active_order_id TEXT,
          version INTEGER NOT NULL DEFAULT 1
        );
      ''');

      rawDbV1.execute('''
        CREATE TABLE local_order_items (
          id TEXT NOT NULL PRIMARY KEY,
          order_id TEXT NOT NULL,
          menu_item_id TEXT NOT NULL,
          item_name TEXT NOT NULL,
          size_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          item_total REAL NOT NULL,
          special_instructions TEXT
        );
      ''');

      rawDbV1.execute('''
        CREATE TABLE sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          operation_id TEXT NOT NULL UNIQUE,
          device_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          base_version INTEGER NOT NULL DEFAULT 1,
          payload TEXT NOT NULL,
          depends_on_operation_id TEXT,
          dependency_order INTEGER NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'PENDING',
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          sent_at INTEGER,
          acked_at INTEGER,
          last_error TEXT,
          conflict_details TEXT
        );
      ''');

      rawDbV1.execute('PRAGMA user_version = 1;');

      // Open with AppDatabase (triggers _migrateTo2, _migrateTo3, _migrateTo4)
      final upgradedDbV1 = AppDatabase(NativeDatabase.opened(rawDbV1));
      addTearDown(upgradedDbV1.close);

      // Verify PRAGMA user_version is 4
      final verResultV1 = await upgradedDbV1.customSelect('PRAGMA user_version;').getSingle();
      expect(verResultV1.data.values.first, equals(4));

      // Verify v2 column was added
      final tableCols = await upgradedDbV1.customSelect("PRAGMA table_info('local_restaurant_tables');").get();
      final tableColNames = tableCols.map((r) => r.read<String>('name')).toSet();
      expect(tableColNames.contains('is_deleted'), isTrue);

      // Verify v3 columns were added
      final itemCols = await upgradedDbV1.customSelect("PRAGMA table_info('local_order_items');").get();
      final itemColNames = itemCols.map((r) => r.read<String>('name')).toSet();
      expect(itemColNames.contains('voided_at'), isTrue);
      expect(itemColNames.contains('voided_by'), isTrue);
      expect(itemColNames.contains('supersedes_item_id'), isTrue);
      expect(itemColNames.contains('created_by_device_id'), isTrue);
      expect(itemColNames.contains('client_created_at'), isTrue);

      // Verify v4 column was added
      final outboxCols = await upgradedDbV1.customSelect("PRAGMA table_info('sync_outbox');").get();
      final outboxColNames = outboxCols.map((r) => r.read<String>('name')).toSet();
      expect(outboxColNames.contains('schema_version'), isTrue);

      // Verify newly enqueued mutation via DAO gets schemaVersion 1 stamped
      await upgradedDbV1.outboxDao.insertEntry(
        SyncOutboxCompanion.insert(
          operationId: '018f2f45-0000-7000-8000-000000000099',
          deviceId: 'POS-P1',
          entityType: 'order',
          entityId: '018f2f45-0000-7000-8000-000000000099',
          operationType: 'INSERT',
          payload: '{"test":true}',
        ),
      );
      final entry = await upgradedDbV1.outboxDao.getEntryByOperationId('018f2f45-0000-7000-8000-000000000099');
      expect(entry, isNotNull);
      expect(entry!.schemaVersion, equals(1));

      // Also verify DB seeded at v2 migrates to v4
      final rawDbV2 = sqlite.sqlite3.openInMemory();
      rawDbV2.execute('''
        CREATE TABLE local_order_items (
          id TEXT NOT NULL PRIMARY KEY,
          order_id TEXT NOT NULL,
          menu_item_id TEXT NOT NULL,
          item_name TEXT NOT NULL,
          size_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          item_total REAL NOT NULL,
          special_instructions TEXT
        );
      ''');
      rawDbV2.execute('''
        CREATE TABLE sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          operation_id TEXT NOT NULL UNIQUE,
          device_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          operation_type TEXT NOT NULL,
          base_version INTEGER NOT NULL DEFAULT 1,
          payload TEXT NOT NULL,
          depends_on_operation_id TEXT,
          dependency_order INTEGER NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'PENDING',
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          sent_at INTEGER,
          acked_at INTEGER,
          last_error TEXT,
          conflict_details TEXT
        );
      ''');
      rawDbV2.execute('PRAGMA user_version = 2;');

      final upgradedDbV2 = AppDatabase(NativeDatabase.opened(rawDbV2));
      addTearDown(upgradedDbV2.close);

      final verResultV2 = await upgradedDbV2.customSelect('PRAGMA user_version;').getSingle();
      expect(verResultV2.data.values.first, equals(4));

      final outboxColsV2 = await upgradedDbV2.customSelect("PRAGMA table_info('sync_outbox');").get();
      final outboxColNamesV2 = outboxColsV2.map((r) => r.read<String>('name')).toSet();
      expect(outboxColNamesV2.contains('schema_version'), isTrue);
    });
  });
}
