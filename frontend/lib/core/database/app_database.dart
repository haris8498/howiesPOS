import 'package:drift/drift.dart';
import 'encrypted_connection.dart';

// Tables
import 'tables/local_orders_tables.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/terminal_sequences_table.dart';
import 'tables/offline_print_jobs_table.dart';
import 'tables/sync_cursors_table.dart';
import 'tables/sync_conflicts_table.dart';
import 'tables/local_daily_calculations_table.dart';
import 'tables/catalog_tables.dart';

// DAOs
import 'daos/orders_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/catalog_dao.dart';
import 'daos/sync_cursors_dao.dart';
import 'daos/daily_calculations_dao.dart';
import 'daos/terminal_sequences_dao.dart';
import 'daos/print_jobs_dao.dart';
import 'daos/retention_dao.dart';

part 'app_database.g.dart';

/// Central Drift Database for Hungry Howie's POS.
///
/// Encrypted using SQLCipher AES-256 with Windows DPAPI derived key.
/// Configured with Spec §5.1 SQLite pragmas (WAL mode, synchronous NORMAL,
/// busy_timeout 5000ms, foreign_keys ON).
@DriftDatabase(
  tables: [
    LocalOrders,
    LocalOrderItems,
    LocalOrderPayments,
    SyncOutbox,
    TerminalSequences,
    OfflinePrintJobs,
    SyncCursors,
    SyncConflicts,
    LocalDailyCalculations,
    LocalMenuCategories,
    LocalMenuItems,
    LocalMenuItemSizes,
    LocalMenuItemOptions,
    LocalDeals,
    LocalDealComponents,
    LocalRestaurantTables,
    LocalFloorZones,
    LocalStaffUsers,
    LocalRolePermissions,
    LocalStoreSettings,
  ],
  daos: [
    OrdersDao,
    OutboxDao,
    CatalogDao,
    SyncCursorsDao,
    DailyCalculationsDao,
    TerminalSequencesDao,
    PrintJobsDao,
    RetentionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openEncryptedConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Schema Version 1 Baseline. Scaffold for future versioned migrations.
        },
        beforeOpen: (OpeningDetails details) async {
          // Guarantee foreign key constraints are enforced
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  /// Convenience retention pruning method (30-day synced) per Directive Q9.2.
  Future<RetentionPruneResult> pruneSyncedDataOlderThan({
    Duration olderThan = const Duration(days: 30),
    DateTime? referenceDate,
  }) {
    return retentionDao.pruneSyncedDataOlderThan(
      olderThan: olderThan,
      referenceDate: referenceDate,
    );
  }
}
