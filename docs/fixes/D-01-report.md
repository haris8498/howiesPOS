# Remediation Report: Decision D-01 — Concurrent Offline Seating & Virtual Overflow Tables

> **Task ID:** D-01  
> **Related Findings:** `SYNC-011`, `SYNC-030`, `TBL-02`, `TBL-10`  
> **Assigned Branch:** `fix/D-01`  
> **Working Directory:** `D:\HOWIES TEST\wt-d01`  
> **Date:** October 27, 2026  
> **Status:** **COMPLETED** (Ready for Review & Merge)

---

## 1. Executive Summary

In a multi-terminal offline POS environment, two separate cashiers can concurrently seat walk-in dining parties at the same physical table (e.g., Table 4) while disconnected from the cloud. Under the pre-remediation engine:
1. The first device to sync claimed Table 4.
2. When the second device synced, the table handler detected that Table 4 already had an active order and rejected the occupancy mutation with `ACTIVE_ORDER_PROTECTED` or `CONFLICT`.
3. Consequently, the second dining party's order was either orphaned from the floor plan or lost visibility, preventing waiters and cashiers from adding items, viewing bill totals, and collecting payment.

Under **Decision D-01**, we designed and implemented a **Virtual Overflow Table** architecture (`4-B`, `4-C`, ...):
- **Deterministic Priority:** The party with the earlier seating timestamp (`seated_at` / `created_at`) keeps the primary table. Deterministic tie-breaking is enforced by UUID comparison.
- **Virtual Overflow Creation:** The colliding loser party is automatically assigned to a virtual overflow table (e.g., Table 4-B) under the same section and floor zone.
- **Slot Re-use:** If an earlier overflow table (such as 4-B) has already paid and completed, subsequent collisions reuse that free overflow slot before creating new suffixes (`4-C`).
- **Push ACK Reassignment:** The backend server returns a structured `tableReassigned` envelope in the push ACK response.
- **Client Auto-Linking & UI Floor Plan:** The Flutter POS client receives the reassignment in `SyncBackgroundWorker`, updates local Drift SQLite tables, links the order to the overflow table, renders an `OVERFLOW` badge with distinct purple styling (`#7C3AED`), sorts overflow tables immediately adjacent to their parent table in the visual floor plan grid, auto-hides closed/empty overflow tables, and displays a non-blocking floating notification banner.

---

## 2. Root Cause Analysis

Prior to remediation, `order.handler.ts` and `table.handler.ts` lacked coordination during concurrent offline dining seatings:
1. **Uncoordinated Order Insertion:** When an order was created with `table_id`, it was inserted without verifying whether another transaction had claimed the table or whether an active dining order was already seated.
2. **Table UPDATE Rejection:** Subsequent table status update mutations targeting the table returned `ACTIVE_ORDER_PROTECTED` because the table's `active_order_id` pointed to the first synced order.
3. **No Reassignment Channel:** The sync push response protocol only acknowledged individual mutation statuses (`SYNCED`, `DUPLICATE`, `CONFLICT`) without any mechanism to inform client terminals that their order had been safely re-homed to an overflow table.
4. **Prisma Schema Limitations:** `RestaurantTable` lacked parent-child relationship tracking, preventing the server and client from knowing which base table an overflow table belonged to.

---

## 3. Architecture & Implementation Details

```mermaid
sequenceDiagram
    autonumber
    participant D1 as POS Terminal 1 (Offline)
    participant D2 as POS Terminal 2 (Offline)
    participant BE as Backend Push Engine
    participant DB as PostgreSQL Database

    Note over D1,D2: Both terminals offline. Seated parties at Table 4.
    D1->>D1: Seats Order 1 on Table 4 (12:00:00Z)
    D2->>D2: Seats Order 2 on Table 4 (12:05:00Z)

    Note over D1,BE: Terminal 1 reconnects & syncs first
    D1->>BE: Push Order 1 (table_id: tbl-4, seated: 12:00Z)
    BE->>DB: Lock tbl-4 FOR UPDATE
    BE->>DB: Table free -> Assign Order 1 to Table 4
    BE-->>D1: ACK SYNCED

    Note over D2,BE: Terminal 2 reconnects & syncs later
    D2->>BE: Push Order 2 (table_id: tbl-4, seated: 12:05Z)
    BE->>DB: Lock tbl-4 FOR UPDATE
    BE->>BE: Collision detected! Order 1 (12:00Z) vs Order 2 (12:05Z)
    BE->>BE: Order 1 was earlier -> Order 1 keeps Table 4. Order 2 LOSES.
    BE->>DB: Create/reuse overflow Table 4-B (parent_table_id: tbl-4)
    BE->>DB: Assign Order 2 to Table 4-B
    BE-->>D2: ACK APPLIED + tableReassigned: [{ orderId: ord-2, fromTableId: tbl-4, toTableId: tbl-4-B, toLabel: '4-B' }]

    Note over D2: Terminal 2 receives tableReassigned in Push ACK
    D2->>D2: Drift: Clear tbl-4 activeOrderId; upsert tbl-4-B (isOverflow: true)
    D2->>D2: UI Floor Plan: Renders Table 4-B right next to Table 4 with purple OVERFLOW badge
    D2->>D2: Displays notification: "Table 4 had two parties, one moved to 4-B"
```

### 3.1 Backend Changes

#### A. Prisma Schema Migration (`backend/prisma/schema.prisma`)
Strictly respecting our single-model scope boundary, only `RestaurantTable` was modified:
```prisma
model RestaurantTable {
  id                     String            @id @default(uuid()) @db.VarChar(36)
  table_number           String            @unique @db.VarChar(50)
  name                   String            @db.VarChar(100)
  capacity               Int               @default(4)
  section                String            @default("Main Hall") @db.VarChar(50)
  zone_id                String?           @map("zone_id") @db.VarChar(36)
  status                 String            @default("available") @db.VarChar(20)
  current_customer_count Int               @default(0) @map("current_customer_count")
  current_bill_amount    Decimal           @default(0.0) @map("current_bill_amount") @db.Decimal(10, 2)
  active_order_id        String?           @map("active_order_id") @db.VarChar(36)
  occupied_since         DateTime?         @map("occupied_since") @db.Timestamp()
  reserved_customer_name String?           @map("reserved_customer_name") @db.VarChar(100)
  reservation_time       DateTime?         @map("reservation_time") @db.Timestamp()
  is_deleted             Boolean           @default(false) @map("is_deleted")
  deleted_at             DateTime?         @map("deleted_at") @db.Timestamp()
  deleted_by             String?           @map("deleted_by") @db.VarChar(100)
  is_overflow            Boolean           @default(false) @map("is_overflow")
  parent_table_id        String?           @map("parent_table_id") @db.VarChar(36)
  overflow_suffix        String?           @map("overflow_suffix") @db.VarChar(10)
  version                Int               @default(1) @map("version")
  updated_at             DateTime          @default(now()) @updatedAt @map("updated_at") @db.Timestamp()

  // Relationships
  zone                   FloorZone?        @relation(fields: [zone_id], references: [id], onDelete: SetNull)
  dine_in_orders         DineInOrderDetail[]
  parent_table           RestaurantTable?  @relation("TableOverflow", fields: [parent_table_id], references: [id], onDelete: SetNull)
  overflow_tables        RestaurantTable[] @relation("TableOverflow")

  @@index([zone_id])
  @@index([is_deleted])
  @@index([parent_table_id])
  @@index([is_overflow])
  @@map("restaurant_tables")
}
```
- Migration SQL generated at: `backend/prisma/migrations/20261027160000_table_seating_overflow/migration.sql`.
- Migration timestamp sequenced strictly after D-05 (`20261027150000_...`).

#### B. Order Handler Conflict Resolution (`backend/src/sync/handlers/order.handler.ts`)
1. **Row-level Lock:** Inside the per-mutation database transaction, executes `SELECT ... FOR UPDATE` via `tx.$queryRaw` (falling back to `findFirst`) on the target table.
2. **Deterministic Seating Comparison:**
   - Extracts seating timestamp from `payload.seated_at || payload.seatedAt || payload.dine_in_detail?.seated_at || payload.occupied_since || payload.created_at || mutation.created_at`.
   - If incoming order has earlier timestamp: incoming order wins Table 4; existing order is displaced to Table 4-B.
   - If existing order has earlier timestamp: existing order keeps Table 4; incoming order is assigned to Table 4-B.
   - Ties broken deterministically by smaller UUID string comparison (`orderId.localeCompare(activeHoldingOrder.id) < 0`).
3. **Overflow Slot Re-use:** `getOrCreateOverflowTable()` queries existing overflow tables with `parent_table_id`. If an existing overflow table is free (`status != 'occupied'` and no active unpaid order), it reuses that table before incrementing suffix (`B`, `C`, `D`, ...).
4. **Idempotent Replay Handling:** If a client replays an order mutation whose order is already in the database and was reassigned to an overflow table, returns `DUPLICATE` with `table_reassigned` envelope populated.

#### C. Table Handler Update Redirection (`backend/src/sync/handlers/table.handler.ts`)
- When a client sends a subsequent `table` `UPDATE` mutation with `active_order_id`, the handler checks if that order was reassigned to a virtual overflow table.
- If reassigned, the mutation is automatically redirected to the overflow table, updating its status and bill amount without raising `ACTIVE_ORDER_PROTECTED` conflicts.

#### D. Sync Push ACK Aggregation (`backend/src/sync/sync-push.service.ts`)
- `SyncPushService.pushMutations()` aggregates all `table_reassigned` and `tableReassigned` events across the batch and surfaces `tableReassigned: [...]` in the root push ACK response.

---

### 3.2 Frontend (Flutter) Changes

#### A. Drift SQLite Schema Migration (`v2 -> v3`)
- `frontend/lib/core/database/tables/catalog_tables.dart`: Added `isOverflow`, `parentTableId`, `overflowSuffix` to `LocalRestaurantTables`.
- `frontend/lib/core/database/app_database.dart`: Bumped `schemaVersion` to `3`. In `onUpgrade`:
  ```dart
  if (from < 3) {
    await m.addColumn(localRestaurantTables, localRestaurantTables.isOverflow);
    await m.addColumn(localRestaurantTables, localRestaurantTables.parentTableId);
    await m.addColumn(localRestaurantTables, localRestaurantTables.overflowSuffix);
  }
  ```
- Regenerated Drift bindings with `build_runner`.

#### B. Domain Model & Repository
- `frontend/lib/domain/models/restaurant_table.dart`: Added `isOverflow`, `parentTableId`, `overflowSuffix`, constructor defaults, `copyWith`, `fromBackendJson`, and `toJson`.
- `frontend/lib/data/table_repository.dart`: Mapped overflow columns in `loadTables` (both network response and Drift DB fallback cache) and companion upserts.

#### C. Push ACK Reassignment Handling (`frontend/lib/core/sync/sync_background_worker.dart`)
- Inspects `decoded['tableReassigned']` and `result['table_reassigned']`.
- Deduplicates reassignment keys (`orderId:toTableId`).
- Clears the old table reference if held by the reassigned order.
- Upserts the virtual overflow table into Drift with status `occupied` and `activeOrderId`.
- Broadcasts `TableReassignmentNotification` over `TableReassignmentEventBus`.

#### D. Floor Plan UI Updates (`frontend/lib/features/tables/tables_screen.dart`)
1. **Auto-Hiding:** Overflow tables auto-hide when closed or empty (`isOverflow == true && status != occupied && activeOrderId == null`).
2. **Adjacent Sorting:** In `filteredTables`, overflow tables sort immediately after their parent table (`Table 4` -> `Table 4-B` -> `Table 4-C` -> `Table 5`).
3. **Distinct Styling & Badge:** Displays an `OVERFLOW` badge and purple border (`#7C3AED`) on overflow table cards.
4. **Floating Notification Banner:** Subscribes to `tableReassignmentNotificationProvider` and displays a floating, dismissible banner alerting cashiers: *"Table 4 had two parties, one moved to 4-B"*.

---

## 4. Test Verification Matrix

### 4.1 Backend End-to-End Tests (`backend/src/sync/sync-011-table-overflow-e2e.spec.ts`)

| Test Scenario | Description | Result |
|---|---|---|
| **Test 1: 2-Way Collision (Device 1 first)** | Order 1 seated at 12:00:00Z on Table 4; Order 2 seated at 12:05:00Z on Table 4. Order 1 keeps Table 4; Order 2 reassigned to `4-B`. | **PASS** |
| **Test 2: Deterministic Seating Priority** | Order 2 (later) syncs first, but Order 1 (earlier) syncs second. Order 1 displaces Order 2 from Table 4; Order 2 moved to `4-B`. | **PASS** |
| **Test 3: 3-Way Collision** | Three concurrent offline seatings on Table 4 result in `Table 4`, `Table 4-B`, and `Table 4-C`. All orders intact. | **PASS** |
| **Test 4: Idempotent Replay** | Replaying sync push for reassigned Order 2 returns `DUPLICATE` with `tableReassigned: [{ toLabel: '4-B' }]` without creating duplicate tables. | **PASS** |
| **Test 5: Table Status Update Redirection** | Subsequent table update for Table 4 from loser device redirects to Table 4-B with `APPLIED` and no `ACTIVE_ORDER_PROTECTED` conflict. | **PASS** |
| **Test 6: Free Overflow Table Re-use** | When Table 4-B order completes and pays, subsequent collision on Table 4 reuses free Table 4-B instead of generating suffix `C`. | **PASS** |

### 4.2 Full Backend Regression Suite
- Ran `npm test` across all 65 test suites.
- **Results:** 65 passed, 65 total suites (450/450 tests passed).
- Ran `npm run build` (`nest build`): compilation succeeded with exit code 0.

### 4.3 Frontend Unit & Integration Tests (`frontend/test/core/sync/table_overflow_reassignment_test.dart`)

| Test Scenario | Description | Result |
|---|---|---|
| **Drift Schema v3 Verification** | Database schemaVersion is 3; `LocalRestaurantTables` stores and retrieves `isOverflow`, `parentTableId`, `overflowSuffix`. | **PASS** |
| **Domain Model Serialization** | `RestaurantTable.fromBackendJson` and `toJson` preserve overflow fields. | **PASS** |
| **SyncWorker Push ACK Processing** | Mock client returning `tableReassigned` causes SyncWorker to clear parent table, upsert `4-B` in SQLite, and emit `TableReassignmentNotification`. | **PASS** |
| **UI Floor Plan Sorting** | Table 4-B sorts immediately after Table 4 and before Table 5. | **PASS** |
| **UI Auto-Hiding** | Closed overflow tables are automatically hidden from the active grid. | **PASS** |

### 4.4 Full Flutter Sync Engine Regression Suite
- Ran `flutter test test/core/sync/`.
- **Results:** All 69 tests passed across 21 test suites.
- Ran `flutter analyze lib/features/tables/tables_screen.dart`: **No issues found (0 warnings, 0 errors)**.

---

## 5. Scope & Concurrency Isolation

- **Prisma Schema Scope:** Strictly limited to `RestaurantTable` model. No modifications to `OrderItem`, `Order`, or any other model.
- **Migration Sequencing:** Migration timestamp is `20261027160000_table_seating_overflow`, properly sequencing after D-05 (`20261027150000_...`).
- **Worktree Isolation:** All work was completed within assigned worktree `D:\HOWIES TEST\wt-d01` on branch `fix/D-01`.
- **Documentation Updated:** `docs/sync-audit/fixes/leftovers-backlog.md` and `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` updated with D-01 resolution status.
