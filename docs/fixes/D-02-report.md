# Fix Report: D-02 Dining Table Soft-Delete & Offline Order Preservation

- **Agent:** `d02-table-soft-delete`
- **Branch:** `fix/D-02`
- **Worktree:** `D:\HOWIES TEST\wt-d02`
- **Mapped Issues:** `SYNC-012`, `TBL-12`
- **Target Subsystem:** Backend (Prisma / NestJS / Sync Push & Pull / Tables Service) & Frontend (Flutter / Drift SQLite / Table Repository / Tables Screen)
- **Date:** October 27, 2026

---

## 1. Executive Summary

Prior to this fix, when an administrator deleted a dining table via the cloud management portal while an offline POS terminal was concurrently creating or updating orders for that table:
1. Hard-deleting the table row in PostgreSQL violated foreign key constraints on `dine_in_order_details.table_id`.
2. Sync push ingestion failed catastrophically with database foreign key errors, classifying the client's outbox mutations as `FAILED_FATAL`.
3. Customer orders, line items, and revenue were permanently destroyed.
4. Furthermore, hard deletion broke historical reporting and prevented table number reuse without complex workarounds.

**Resolution:**
We implemented **End-to-End Soft-Deletion (Decision D-02: Option 1)**:
- Replaced hard-deletion with soft-deletion (`is_deleted: true`, `deleted_at: now()`, `deleted_by: userId`) across PostgreSQL and Drift SQLite.
- Replaced the global unique constraint on `table_number` with a PostgreSQL partial unique index (`WHERE is_deleted = false`) allowing table numbers to be recycled after deletion.
- Enhanced table deletion to record tombstones in the sync change log and report existing open orders in the delete response without blocking the administrator.
- Added a role-guarded `POST /tables/:id/restore` endpoint with collision detection.
- Updated `OrderHandler` in sync push to detect soft-deleted tables, accept offline orders with full data fidelity, retain the original `table_id`, and surface a non-fatal `TABLE_DELETED` warning ACK.
- Bumped Flutter Drift database schema to version 2 with a safe additive migration for `is_deleted`.
- Implemented state-aware tombstone application in Flutter: deleted tables with local open orders remain visible on the POS floor plan tagged with a distinct `REMOVED` badge until final payment and settlement, after which they are removed from the grid.

---

## 2. Handoff & Schema Specification for Agent D-01

> [!IMPORTANT]
> **Attention Agent D-01 (`d01-table-seating-overflow`):**
> As authorized by the Wave 1 plan, `schema.prisma` was updated on branch `fix/D-02`. You can build directly upon these exact columns in `RestaurantTable`:

### Prisma Model (`backend/prisma/schema.prisma`):
```prisma
model RestaurantTable {
  id           String        @id @default(uuid())
  table_number String
  name         String?
  capacity     Int           @default(4)
  is_active    Boolean       @default(true)
  is_deleted   Boolean       @default(false)
  deleted_at   DateTime?
  deleted_by   String?
  shape        TableShape    @default(SQUARE)
  pos_x        Float         @default(0)
  pos_y        Float         @default(0)
  status       TableStatus   @default(AVAILABLE)
  zone_id      String?
  zone         TableZone?    @relation(fields: [zone_id], references: [id], onDelete: SetNull)
  current_bill Float         @default(0)
  created_at   DateTime      @default(now())
  updated_at   DateTime      @updatedAt

  dine_in_orders DineInOrderDetail[]

  @@index([zone_id])
  @@index([is_active])
  @@index([is_deleted])
  @@map("restaurant_tables")
}
```

### PostgreSQL Index Details:
- The global unique constraint `@unique(table_number)` was removed from `RestaurantTable` in Prisma schema.
- Uniqueness for active tables is enforced via raw PostgreSQL partial unique index:
  ```sql
  CREATE UNIQUE INDEX "restaurant_tables_table_number_active_key"
  ON "restaurant_tables"("table_number")
  WHERE "is_deleted" = false;
  ```
- This ensures active table numbers remain strictly unique, while soft-deleted table numbers can be reassigned freely.

### Drift SQLite Table (`frontend/lib/core/database/tables/catalog_tables.dart`):
```dart
class LocalRestaurantTables extends Table {
  // ... existing fields ...
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  // ...
}
```
- Schema version: `2` (in `frontend/lib/core/database/app_database.dart`).
- Migration step:
  ```dart
  if (from < 2) {
    await m.addColumn(localRestaurantTables, localRestaurantTables.isDeleted);
  }
  ```

---

## 3. Files Touched & Detailed Changes

### Backend:
1. [`backend/prisma/schema.prisma`](file:///D:/HOWIES%20TEST/wt-d02/backend/prisma/schema.prisma):
   - Added `is_deleted`, `deleted_at`, `deleted_by` to `RestaurantTable`.
   - Removed `@unique` on `table_number` to allow partial indexing.
   - Added `@@index([is_deleted])`.
2. [`backend/prisma/migrations/20261027140000_soft_delete_dining_tables/migration.sql`](file:///D:/HOWIES%20TEST/wt-d02/backend/prisma/migrations/20261027140000_soft_delete_dining_tables/migration.sql):
   - Additive SQL: Adds columns with `DEFAULT false`, backfills existing rows, drops table-level unique constraint `restaurant_tables_table_number_key`, creates partial unique index `restaurant_tables_table_number_active_key`, and adds index on `is_deleted`.
3. [`backend/src/tables/tables.service.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/tables/tables.service.ts):
   - Excluded `is_deleted: true` from all read operations (`findAll`, `findOne`, `findByNumber`, `getDashboardStats`, `getFloorPlan`, `getZoneFloorPlan`).
   - `createTable`: Enforces unique active table numbers via `findFirst({ where: { table_number, is_deleted: false } })`.
   - `deleteTable`: Switched to soft-delete (`is_deleted: true, is_active: false, deleted_at: now, deleted_by: userId`). Records change log entry (`entity_name: 'restaurant_table', change_type: 'DELETE'`) for delta pull tombstone replication. Queries and returns any active/unpaid orders on the deleted table.
   - `deleteZone`: Soft-deletes all associated tables.
   - Added `restoreTable(idOrNumber)`: Re-activates soft-deleted table with collision check against active table numbers.
4. [`backend/src/tables/tables.controller.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/tables/tables.controller.ts):
   - Added `@Post(':id/restore')` endpoint restricted to `ADMIN` and `OWNER` roles.
5. [`backend/src/tables/tables.module.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/tables/tables.module.ts):
   - Imported `ChangeLogModule` to enable tombstone recording during table deletion.
6. [`backend/src/sync/sync-pull.service.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/sync/sync-pull.service.ts):
   - `getBootstrapData`: Filters `is_deleted: false` so soft-deleted tables are excluded from initial bootstrap catalog.
7. [`backend/src/sync/handlers/table.handler.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/sync/handlers/table.handler.ts):
   - Updated lookup query to check `is_deleted: false`.
8. [`backend/src/sync/handlers/sync-entity.handler.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/sync/handlers/sync-entity.handler.ts):
   - Added `warning_code?: string` and `warnings?: string[]` to `SyncMutationResult` contract.
9. [`backend/src/sync/handlers/order.handler.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/sync/handlers/order.handler.ts):
   - In both `handleInsert` and `handleUpdate`, when an order includes `dine_in_details.table_id`:
     - Checks if the table has `is_deleted: true`.
     - Preserves the original `table_id` and persists the order normally without throwing FK violation.
     - Sets `warning_code: 'TABLE_DELETED'` and `warnings: ['TABLE_DELETED']` in the mutation ACK.

### Frontend:
1. [`frontend/lib/core/database/tables/catalog_tables.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/core/database/tables/catalog_tables.dart):
   - Added `isDeleted` boolean column with default `false`.
2. [`frontend/lib/core/database/app_database.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/core/database/app_database.dart):
   - Bumped `schemaVersion => 2`.
   - Added migration step in `onUpgrade` using `m.addColumn(localRestaurantTables, localRestaurantTables.isDeleted)`.
3. [`frontend/lib/domain/models/restaurant_table.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/domain/models/restaurant_table.dart):
   - Added `isDeleted` field, `copyWith`, and `fromBackendJson` mapping.
4. [`frontend/lib/core/database/daos/catalog_dao.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/core/database/daos/catalog_dao.dart):
   - Updated `getAllTables({bool includeDeleted = false})` to filter `isDeleted = false` by default.
5. [`frontend/lib/core/sync/sync_background_worker.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/core/sync/sync_background_worker.dart):
   - Bootstrap mapping includes `isDeleted`.
   - Delta pull applies `restaurant_table` tombstones: checks if local table has an active order in SQLite (`activeOrderId != null` or via `ordersDao.getOrderById`). If an active order exists, keeps table row with `isDeleted: true, status: occupied`. If no active order, marks `isDeleted: true, status: available, activeOrderId: null`.
6. [`frontend/lib/data/table_repository.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/data/table_repository.dart):
   - Maps `isDeleted` in `LocalRestaurantTablesCompanion`.
   - In `loadTables`, persists local open orders even if backend reports the table as soft-deleted so cashier can continue billing and settlement.
7. [`frontend/lib/features/tables/tables_screen.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/lib/features/tables/tables_screen.dart):
   - Filters out `t.isDeleted` unless the table has a local open order (`status == TableStatus.occupied` or active bill amount $> 0$).
   - Displays a prominent red `REMOVED` badge on the table card and detail header so staff know the table was deleted in the backend while still allowing order completion.

### Documentation:
1. [`docs/sync-audit/fixes/leftovers-backlog.md`](file:///D:/HOWIES%20TEST/wt-d02/docs/sync-audit/fixes/leftovers-backlog.md):
   - Updated `SYNC-012` and Decision `D-02` status to `Implemented (recommendation adopted) (fix/D-02)`.
2. [`docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`](file:///D:/HOWIES%20TEST/wt-d02/docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md):
   - Appended `D-02` entry to Section 11.1 Remediation Summary table.
3. [`docs/fixes/D-02-report.md`](file:///D:/HOWIES%20TEST/wt-d02/docs/fixes/D-02-report.md):
   - This handoff report.

---

## 4. Test Suites Added & Verification Results

### Backend Tests:
- **New E2E Suite:** [`backend/src/sync/sync-012-table-soft-delete-e2e.spec.ts`](file:///D:/HOWIES%20TEST/wt-d02/backend/src/sync/sync-012-table-soft-delete-e2e.spec.ts)
  1. *Scenario 1: Partial-Unique Constraint Reuse* — Verified creating Table T-20, soft-deleting it, and creating a new Table T-20 succeeds without collision.
  2. *Scenario 2: Tombstone Replication in Delta Pull* — Verified soft deletion generates a change log tombstone with `isDeleted: true` in delta pull payloads.
  3. *Scenario 3: Bootstrap Pull Exclusion* — Verified bootstrap catalog pulls exclude soft-deleted tables.
  4. *Scenario 4: Offline Order Push Resilience & Non-Fatal Warning* — Verified offline order targeting a soft-deleted table is accepted (`status: 'APPLIED'`), foreign key is satisfied, and returns `warning_code: 'TABLE_DELETED'`.
  5. *Scenario 5: Admin Delete Warning on Active Orders* — Verified `deleteTable` returns open orders in response.
  6. *Scenario 6: Restore Table Endpoint* — Verified restoring a deleted table reactivates it, or fails with conflict if another active table took its number.
- **Updated Suites:**
  - `backend/src/tables/tables.service.spec.ts` (14/14 passed)
  - `backend/src/tables/tables.controller.spec.ts` (12/12 passed)
  - `backend/src/sync/offline-schema.spec.ts` (11/11 passed)
- **Total Backend Tests Run:** 43 tests passed across 4 suites.
- **Prisma Schema Validation:** `npx prisma validate` passed with 0 errors.
- **Backend Build:** `npm run build` compiled cleanly with 0 errors.

### Frontend Tests:
- **New Tombstone & Settlement Suite:** [`frontend/test/core/sync/table_soft_delete_tombstone_test.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/test/core/sync/table_soft_delete_tombstone_test.dart)
  1. *Scenario 1: Tombstone on Empty Table* — Verified table is marked `isDeleted: true` and disappears from active table queries.
  2. *Scenario 2: Tombstone on Occupied Table with Local Order* — Verified table preserves occupied status and `activeOrderId` so cashier can view and service guests.
  3. *Scenario 3: Settlement Clears Occupied Tombstone* — Verified settling the open order transitions the soft-deleted table to available, causing it to disappear from the active grid.
- **Updated Migration Suite:** [`frontend/test/core/database/schema_migration_test.dart`](file:///D:/HOWIES%20TEST/wt-d02/frontend/test/core/database/schema_migration_test.dart)
  - Verified schema migration to version 2 adds `is_deleted` column to `local_restaurant_tables` without data loss.
- **Existing Table Test Suites:**
  - `frontend/test/features/tables/payment_tender_settlement_test.dart` (passed)
  - `frontend/test/core/sync/table_conflict_policy_test.dart` (passed)
  - `frontend/test/core/sync/offline_table_transfer_test.dart` (passed)
- **Analyzer:** `flutter analyze` verified 0 errors across all modified frontend files.

---

## 5. Residual Risks & Operational Considerations

1. **Table Number Reuse Disambiguation:**
   - If Table 12 is soft-deleted and a new Table 12 is created while an offline device is still disconnected, an offline order from the old Table 12 will sync successfully to the old table ID (foreign key preserved).
   - In the cloud portal, reports will correctly link the order to the old table record rather than the new table record because orders reference `table_id` (UUID), not `table_number`.
2. **Floor Plan Grid Layout:**
   - When a table is soft-deleted with an open order, it remains displayed on the floor plan at its last known `(pos_x, pos_y)` coordinates with the `REMOVED` badge until checkout. Once paid, the cashier's table list refreshes and the table is omitted from rendering.
3. **Additive-Only Migrations:**
   - No tables or columns were dropped.
   - Default value for `is_deleted` is `false`, ensuring zero impact on existing running deployments or un-migrated client versions.
4. **Online Behavior Parity:**
   - With `OFFLINE_FIRST_ENABLED=false`, the NestJS API transparently serves only non-deleted tables. Deletions remain soft, ensuring historical data integrity is preserved across both offline and online modes.

---

## 6. Manual Verification Steps

1. **Table Creation & Deletion:**
   - Log in as Admin on web dashboard.
   - Create Table "T-99" with capacity 4.
   - Delete Table "T-99" -> Server soft-deletes row (`is_deleted = true`).
   - Create Table "T-99" again -> Verify partial unique index allows reuse of "T-99".
2. **Offline Order on Deleted Table:**
   - Disconnect POS terminal Wi-Fi.
   - Open floor plan -> Table "T-10" is visible.
   - Create a dine-in order for Table "T-10" with 2 pizzas and send to kitchen.
   - On admin dashboard, delete Table "T-10".
   - Reconnect POS terminal Wi-Fi.
   - Sync background worker triggers push -> order is accepted by backend with `warning_code: 'TABLE_DELETED'`.
   - Verify table remains on floor plan with red `REMOVED` badge.
   - Settle order with Cash tender -> Payment accepted, table status clears, table disappears from floor plan.
