# Stage 2: Client Database Implementation Report

> **Branch:** `offline/main`  
> **Stage:** `client-database` (Stage 2)  
> **Date:** October 17, 2026  
> **Architecture Spec:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` (§5.2, §5.3, §5.4, §6.1, §3.3, §4.2, §21.2)  
> **Baseline Reference:** `docs/offline-implementation/00-baseline.md`  
> **Depends On:** `client-foundation` (Stage 1)

---

## 1. Executive Summary

Stage 2 delivers the complete Drift SQLite client database architecture for Hungry Howie's POS, constructed directly on the AES-256 encrypted storage layer and Win32 DPAPI key provider established in Stage 1. 

All 20 relational tables, specialized Data Access Objects (DAOs), schema migration scaffold, and transactional guarantees required for full offline-first POS operations are in place without touching legacy production screens or active repositories.

Key capabilities implemented and verified:
1. **Central Database Root (`AppDatabase`):** Implemented `frontend/lib/core/database/app_database.dart` integrating all 20 tables and 8 DAOs with schema version 1, automatic table initialization, and PRAGMA foreign keys enforcement (`PRAGMA foreign_keys = ON;`). Default connection factory lazily initializes the SQLCipher connection using Windows user-scope DPAPI key derivation.
2. **Replicated Operational Tables (§5.2):** Created `local_orders`, `local_order_items`, and `local_order_payments` with UUID v7 primary keys, status flags, and sync metadata (`sync_status`, `server_version`, `client_updated_at`, `server_updated_at`, `is_deleted`). Foreign key cascades enforce that deleting an order completely purges associated items and payments.
3. **Sync Outbox Queue (§6.1 & Deviation #3):** Created `sync_outbox` table with unique constraint on `operation_id` (UUID v7), strict topological `dependency_order`, and support for `AUTH_PAUSED` state. Tested that HTTP 401 pauses outbox processing without prematurely quarantining mutations to conflict storage.
4. **Hardware Spooler & Sequencers (§5.4):** Created `offline_print_jobs` table for decoupled thermal printer queuing (`ORDER SAVING ≠ PRINTING`), `terminal_sequences` table cycling human-readable receipt numbers (`P1-101` through `P1-999`) with daily rollover, and `sync_cursors` for delta feed tracking.
5. **Replicated Catalog Tables (§5.3):** Built client mirror tables for all 11 catalog and reference entities (`LocalMenuCategories`, `LocalMenuItems`, `LocalMenuItemSizes`, `LocalMenuItemOptions`, `LocalDeals`, `LocalDealComponents`, `LocalRestaurantTables`, `LocalFloorZones`, `LocalStaffUsers`, `LocalRolePermissions`, `LocalStoreSettings`).
6. **Shift & Variance Tracking (§5.2, §21.2):** Implemented `local_daily_calculations` table and DAO capturing shift sessions, actual counted cash, and cash variance (overage/shortage) with `OFFLINE_CLOSED` support.
7. **Atomic Multi-Table Commit & Rollback (§11):** Implemented `OrdersDao.saveOrderAtomic` executing order header, items, payments, outbox mutation row, and thermal print job in a single ACID transaction. Tested that mid-transaction failure guarantees zero orphaned records.
8. **30-Day Retention Pruning (Directive Q9.2):** Implemented `pruneSyncedDataOlderThan()` in `RetentionDao` and `AppDatabase`, removing synced orders, acknowledged outbox entries, and printed spooler jobs older than 30 days while protecting pending or recent offline records.

---

## 2. Files Created and Modified

### Created Schema & Table Files
- `frontend/lib/core/database/tables/local_orders_tables.dart`: Operational tables `LocalOrders`, `LocalOrderItems`, `LocalOrderPayments` with UUID v7 and cascade rules.
- `frontend/lib/core/database/tables/sync_outbox_table.dart`: Outbox table `SyncOutbox` with unique `operationId`, retry parameters, dependency ordering, and `SyncOutboxStatus` including `AUTH_PAUSED`.
- `frontend/lib/core/database/tables/terminal_sequences_table.dart`: Terminal receipt sequence table `TerminalSequences` (`sequenceKey`, `businessDate`, `currentValue`).
- `frontend/lib/core/database/tables/offline_print_jobs_table.dart`: Spooler queue `OfflinePrintJobs` with raw ESC/POS blobs and `PrintJobStatus`.
- `frontend/lib/core/database/tables/sync_cursors_table.dart`: Cursor store `SyncCursors` (`feedKey`, `lastPulledSequence`).
- `frontend/lib/core/database/tables/sync_conflicts_table.dart`: Quarantine conflict registry `SyncConflicts` (`conflictType`, `resolutionStatus`).
- `frontend/lib/core/database/tables/local_daily_calculations_table.dart`: Shift drawer table `LocalDailyCalculations` with `cashVariance` and `OFFLINE_CLOSED` state.
- `frontend/lib/core/database/tables/catalog_tables.dart`: All 11 replicated reference tables (`LocalMenuCategories`, `LocalMenuItems`, `LocalMenuItemSizes`, `LocalMenuItemOptions`, `LocalDeals`, `LocalDealComponents`, `LocalRestaurantTables`, `LocalFloorZones`, `LocalStaffUsers`, `LocalRolePermissions`, `LocalStoreSettings`).

### Created DAOs & Root Database Files
- `frontend/lib/core/database/app_database.dart`: Central Drift root database configuring all tables, DAOs, schema version 1, and foreign keys PRAGMA.
- `frontend/lib/core/database/app_database.g.dart`: Generated Drift schema and table classes (via build_runner).
- `frontend/lib/core/database/daos/orders_dao.dart`: Orders DAO providing `saveOrderAtomic`, queries, and reactive watch streams.
- `frontend/lib/core/database/daos/orders_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/outbox_dao.dart`: Outbox DAO with `getPushBatch` (`ORDER BY dependency_order ASC, created_at ASC LIMIT 25`), retry transitions, and `AUTH_PAUSED` lifecycle.
- `frontend/lib/core/database/daos/outbox_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/catalog_dao.dart`: Catalog DAO with batch upsert (`insertAllOnConflictUpdate`) and query methods.
- `frontend/lib/core/database/daos/catalog_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/sync_cursors_dao.dart`: Cursors DAO for get/set of delta sequences.
- `frontend/lib/core/database/daos/sync_cursors_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/daily_calculations_dao.dart`: Shifts DAO with active session tracking and offline closure.
- `frontend/lib/core/database/daos/daily_calculations_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/terminal_sequences_dao.dart`: Sequencer DAO for `101`-`999` daily cycling.
- `frontend/lib/core/database/daos/terminal_sequences_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/print_jobs_dao.dart`: Print jobs spooler DAO.
- `frontend/lib/core/database/daos/print_jobs_dao.g.dart`: Generated DAO mixin.
- `frontend/lib/core/database/daos/retention_dao.dart`: 30-day retention pruning DAO for synced orders, outbox, and print jobs.
- `frontend/lib/core/database/daos/retention_dao.g.dart`: Generated DAO mixin.

### Created Test Suites
- `frontend/test/core/database/in_memory_database_test.dart`: In-memory SQLite verification covering atomicity, rollback, unique operation_id, foreign key cascades, outbox ordering, `AUTH_PAUSED`, catalog upsert, cursor tracking, 30-day pruning, sequence counters, and cash variance.
- `frontend/test/core/database/schema_migration_test.dart`: Verifies schema version 1, all 20 table initializations, and PRAGMA foreign keys.

---

## 3. Test Suites & Verification Results

### Test Execution Summary (`flutter test`)
- **Total Test Suites:** 9 passing suites.
- **Total Tests Passed:** 40 of 40 tests passed cleanly (0 failed, 0 skipped).
  - Baseline: 15 passed
  - Stage 1: +13 passed (total 28)
  - Stage 2: +12 passed (total 40)

### Detailed Stage 2 Unit Test Breakdown:
1. `Atomicity: saveOrderAtomic commits all records or rolls back completely`:
   - Verifies 1 order + 2 items + 1 payment + 1 outbox entry + 1 print job committed in a single transaction.
   - Proves that simulated mid-transaction failure rolls back completely leaving 0 rows across all affected tables.
2. `Unique Constraint: duplicate operation_id on SyncOutbox is rejected`:
   - Verifies SQLite unique index aborts duplicate operationId with `SqliteException` / `DriftWrappedException`.
3. `FK Behavior: cascade deletes child items and payments, rejects orphaned items`:
   - Proves inserting order item with nonexistent order ID fails constraint check.
   - Proves deleting parent order cascades and deletes all associated items and payments.
4. `Outbox Ordering & Status Filtering: ORDER BY dependency_order, created_at LIMIT 25`:
   - Proves mutations are sorted by `dependency_order ASC, created_at ASC`.
   - Proves only `PENDING` and due `FAILED_RETRYABLE` are returned; `AUTH_PAUSED`, non-due retryables, and `SYNCED` entries are strictly excluded.
5. `Approved Deviation #3: AUTH_PAUSED pauses queue and resumeAuthPaused restores to PENDING`:
   - Simulates HTTP 401 pause and subsequent resume on successful token renewal.
6. `Catalog DAO: batch upsert and retrieval for categories, items, and settings`:
   - Verifies batch `insertAllOnConflictUpdate` and in-place updates.
7. `Sync Cursors: get and set sequence positions`:
   - Verifies default sequence 0, atomic upsert, and timestamp tracking.
8. `Retention Pruning: 30-day synced data pruned, pending/recent data preserved`:
   - Verifies 40-day-old synced orders, outbox entries, and print jobs are pruned.
   - Verifies 10-day-old synced orders are preserved.
   - Verifies 40-day-old unsynced pending orders are preserved.
9. `Terminal Sequences: cycles 101 to 999 and resets on new business date`:
   - Verifies counter increment, daily reset upon date rollover, and cycling when exceeding 999.
10. `Local Daily Calculations: active shift and offline closure with variance`:
    - Verifies active shift session tracking, actual counted cash, cash shortage recording (-50.0), and `OFFLINE_CLOSED` transition.
11. `Drift Schema Version & Migration Scaffold Tests`:
    - Verifies `schemaVersion == 1` and all 20 required tables exist in `sqlite_master`.
    - Verifies `PRAGMA foreign_keys = 1`.

### Code Generation (`dart run build_runner build`)
- Executed `dart run build_runner build --delete-conflicting-outputs`.
- Result: Code 0 (Success in 13s, 52 outputs written).

### Static Analysis (`dart analyze`)
- Executed `dart analyze` on `frontend/`.
- Result: 0 errors.
- Pre-existing warnings/hints: 1 unused import warning in `test_mapping.dart` and 40 info hints (identical to baseline). Zero warnings or hints introduced.

---

## 4. Commands Run

```powershell
# Drift Code Generation
cd frontend
dart run build_runner build --delete-conflicting-outputs

# Static Analysis
dart analyze

# Unit Tests Execution
flutter test test/core/database/in_memory_database_test.dart test/core/database/schema_migration_test.dart
flutter test
```

---

## 5. Deviations & Blockers

- **Approved Deviation #3 Applied:** Implemented `SyncOutboxStatus.authPaused` (`'AUTH_PAUSED'`). On HTTP 401 Unauthorized, mutations remain in the queue in `AUTH_PAUSED` state rather than failing fatally or quarantining to conflicts. `resumeAuthPaused()` seamlessly transitions them back to `PENDING` once the cashier logs in or refreshes their token.
- **Blockers:** None.

---

## 6. How to Verify Manually

1. **Run Database Unit Tests:**
   ```powershell
   cd frontend
   flutter test test/core/database/in_memory_database_test.dart
   flutter test test/core/database/schema_migration_test.dart
   ```
   Both test suites will pass with 12 passing test cases.

2. **Run Full Test Suite:**
   ```powershell
   cd frontend
   flutter test
   ```
   All 40 unit and domain test cases across the frontend will pass cleanly.

3. **Verify Generated Files:**
   Confirm the presence of:
   - `frontend/lib/core/database/app_database.g.dart`
   - `frontend/lib/core/database/daos/*.g.dart`
