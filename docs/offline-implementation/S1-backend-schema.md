# Stage 1 Implementation Report: Backend Schema & Additive Migration

> **Phase:** Stage 1 — Backend Schema Migration  
> **Author:** `backend-schema-migration`  
> **Spec References:** [`docs/offline-analysis/99-FINAL-ARCHITECTURE.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-analysis/99-FINAL-ARCHITECTURE.md) §7 (7.1–7.3), §2, §4.3  
> **Baseline:** [`docs/offline-implementation/00-baseline.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-implementation/00-baseline.md)  
> **Date:** October 17, 2026  

---

## 1. What Was Built

The backend data schema has been upgraded to support offline idempotency tracking, monotonic change-feed streaming for delta sync, optimistic concurrency control (OCC), soft deletion for catalog integrity, and offline shift reconciliation with cash variance recording.

### 1.1 Idempotency Ledger (`ProcessedOperation`)
- Added `ProcessedOperation` model in [`backend/prisma/schema.prisma`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/prisma/schema.prisma) mapped to `processed_operations`.
- Primary key: `operation_id VARCHAR(36)` (UUID v7).
- Fields: `device_id`, `entity_type`, `entity_id`, `request_hash`, `status` (default `'PROCESSING'`), `response_payload` (nullable JSON), `http_status` (default `200`), `created_at` (default `now()`), `completed_at` (nullable timestamp).
- Indexes:
  - `@@index([device_id, created_at])` for terminal session pruning and audit queries.
  - `@@index([entity_type, entity_id])` for looking up mutation history for a specific entity.

### 1.2 Monotonic Replication Stream (`SystemChangeLog`)
- Added `SystemChangeLog` model in [`backend/prisma/schema.prisma`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/prisma/schema.prisma) mapped to `system_change_logs`.
- Primary key: `global_sequence BigInt @id @default(autoincrement())` (`BIGSERIAL`).
- Fields: `entity_type`, `entity_id`, `operation` (`'INSERT'`, `'UPDATE'`, `'DELETE'`), `record_version` (default 1), `is_deleted` (default `false`), `payload` (JSON), `created_at` (default `now()`).
- Indexes:
  - `@@index([global_sequence])` for high-throughput delta stream pulling (`WHERE global_sequence > cursor ORDER BY global_sequence ASC LIMIT N`).
  - `@@index([entity_type, entity_id])` for change-history lookups by entity.

### 1.3 Optimistic Concurrency Control (OCC) & Timestamps
Added concurrency tokens and auto-updating timestamps to active operational models:
- **`Order`**: Added `version Int @default(1)` and `updated_at DateTime @default(now()) @updatedAt`.
- **`RestaurantTable`**: Added `version Int @default(1)` and `updated_at DateTime @default(now()) @updatedAt`.
- **`DailyCalculation`**: Added `version Int @default(1)` and `updated_at DateTime @default(now()) @updatedAt`.

### 1.4 Soft Deletion Columns
Added soft-delete metadata to prevent cascading foreign-key failures during sync replication:
- **`MenuItem`**: Added `is_deleted Boolean @default(false)` and `deleted_at DateTime?`.
- **`Customer`**: Added `is_deleted Boolean @default(false)` and `deleted_at DateTime?`.

### 1.5 Shift Closure & Cash Variance Support
- **`DailyCalculation`**:
  - Added `cash_variance Decimal(10, 2) @default(0.00)` to capture drawer discrepancies.
  - Added `variance_reason String? @db.VarChar(255)` for cashier audit notes.
  - Verified and documented `status String @default("ACTIVE") @db.VarChar(20)` accommodates the `'OFFLINE_CLOSED'` status string (14 chars <= 20 chars).

### 1.6 Constraint & Index Compatibility Analysis
- **Receipt Number Partitioning (`order_number`):**  
  `Order.order_number` retains its `@unique @db.VarChar(30)` constraint. With terminal-prefixed order sequencing (e.g., `P1-101`, `P2-101` per §4.3), each physical terminal increments counters within its distinct namespace. Unique collisions across terminals are completely eliminated.
- **Global Sequence Delta Pulls:**  
  `SystemChangeLog.global_sequence` is defined as a 64-bit integer (`BigInt`) primary key with an explicit B-tree index. This enables fast sequential scans for cursor-based client polling (`WHERE global_sequence > cursor ORDER BY global_sequence ASC LIMIT 100`).

---

## 2. Files Created and Modified

| Action | File Path | Description |
|---|---|---|
| **Modified** | [`backend/prisma/schema.prisma`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/prisma/schema.prisma) | Added `ProcessedOperation`, `SystemChangeLog`, OCC columns, soft-delete columns, and shift variance fields. |
| **Created** | [`backend/prisma/migrations/20261017000000_offline_sync_schema/migration.sql`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/prisma/migrations/20261017000000_offline_sync_schema/migration.sql) | Purely additive PostgreSQL migration script generated and validated with safe defaults. |
| **Created** | [`backend/src/sync/offline-schema.spec.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/sync/offline-schema.spec.ts) | 9 unit tests verifying schema metadata, DMMF structure, and migration SQL integrity. |
| **Created** | [`docs/offline-implementation/S1-backend-schema.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-implementation/S1-backend-schema.md) | Stage 1 summary and verification report. |

---

## 3. Tests Added & Results

### 3.1 New Unit Test Suite
File: `backend/src/sync/offline-schema.spec.ts`
- Tests: 9 tests across 6 describe blocks:
  1. `ProcessedOperation` model definition, column types, and composite indexes.
  2. `SystemChangeLog` model definition, autoincrement sequence, and index.
  3. `Order`, `RestaurantTable`, `DailyCalculation` OCC `version` (default 1) and `updated_at`.
  4. `MenuItem` and `Customer` soft-delete `is_deleted` (default false) and `deleted_at`.
  5. `DailyCalculation` shift variance (`cash_variance`, `variance_reason`) and status support.
  6. Migration SQL script file presence and additive clause verification.
- **Result:** `PASS` (9/9 passed in 6.06s).

### 3.2 Full Backend Test Suite Comparison Against Baseline
- **Baseline (from `docs/offline-implementation/00-baseline.md`):**
  - Test Suites: 4 failed, 40 passed, 44 total
  - Tests: 4 failed, 292 passed, 296 total
- **Post-Stage 1 Execution:**
  - Test Suites: 4 failed, 41 passed, 45 total (+1 passed suite)
  - Tests: 4 failed, 301 passed, 305 total (+9 passed tests)
- **Known Pre-Existing Failures (Unchanged):**
  - `src/inventory/inventory.service.spec.ts` (duplicate SKU code)
  - `src/permissions/permissions.service.spec.ts` (role permission check)
  - `src/reports/reports.service.spec.ts` (executive summary metrics)
  - `src/users/users.service.spec.ts` (delete user mock method)
- **Regressions Introduced:** **0**.

---

## 4. Commands Executed

```powershell
# 1. Back up baseline schema and validate diff
npx prisma validate
npx prisma migrate diff --from-schema-datamodel prisma/schema.prisma.baseline --to-schema-datamodel prisma/schema.prisma --script

# 2. Regenerate Prisma Client
npx prisma generate

# 3. Application compilation
npm run build

# 4. Unit test suite execution
npx jest src/sync/offline-schema.spec.ts
npm test
```

---

## 5. Deviations & Blockers

- **Deviations:** None. All additions strictly follow §7.1–7.3 and §2. No controllers or services were written in this stage.
- **Blockers:** None.

---

## 6. How to Verify Manually

1. **Verify Schema Syntax & Integrity:**
   ```powershell
   cd backend
   npx prisma validate
   ```
   *Expected output:* `The schema at prisma\schema.prisma is valid 🚀`

2. **Verify TypeScript Compilation:**
   ```powershell
   cd backend
   npm run build
   ```
   *Expected output:* NestJS CLI completes build with exit code 0.

3. **Verify Stage 1 Unit Tests:**
   ```powershell
   cd backend
   npx jest src/sync/offline-schema.spec.ts
   ```
   *Expected output:* `9 passed, 9 total`.

4. **Verify Additive Nature of Migration:**
   Inspect `backend/prisma/migrations/20261017000000_offline_sync_schema/migration.sql`. Confirm there are NO `DROP TABLE`, `DROP COLUMN`, or `RENAME` statements. All new columns include `DEFAULT` values or are nullable.

---

## 7. Rollback Note

If this migration needs to be rolled back safely without data loss to existing systems:

### 7.1 Database Rollback SQL
```sql
-- 1. Drop replication and idempotency ledger tables
DROP TABLE IF EXISTS "system_change_logs" CASCADE;
DROP TABLE IF EXISTS "processed_operations" CASCADE;

-- 2. Drop additive columns from daily_calculations
ALTER TABLE "daily_calculations"
  DROP COLUMN IF EXISTS "variance_reason",
  DROP COLUMN IF EXISTS "cash_variance",
  DROP COLUMN IF EXISTS "version",
  DROP COLUMN IF EXISTS "updated_at";

-- 3. Drop additive columns from orders
ALTER TABLE "orders"
  DROP COLUMN IF EXISTS "version",
  DROP COLUMN IF EXISTS "updated_at";

-- 4. Drop additive columns from restaurant_tables
ALTER TABLE "restaurant_tables"
  DROP COLUMN IF EXISTS "version",
  DROP COLUMN IF EXISTS "updated_at";

-- 5. Drop soft-delete columns from menu_items
ALTER TABLE "menu_items"
  DROP COLUMN IF EXISTS "is_deleted",
  DROP COLUMN IF EXISTS "deleted_at";

-- 6. Drop soft-delete columns from customers
ALTER TABLE "customers"
  DROP COLUMN IF EXISTS "is_deleted",
  DROP COLUMN IF EXISTS "deleted_at";
```

### 7.2 Application Rollback Steps
1. Delete directory `backend/prisma/migrations/20261017000000_offline_sync_schema/`.
2. Delete `backend/src/sync/offline-schema.spec.ts`.
3. Revert `backend/prisma/schema.prisma` using `git restore backend/prisma/schema.prisma`.
4. Run `npx prisma generate` in `backend/` to regenerate client typings.
5. Run `npm run build` in `backend/` to verify clean build.
