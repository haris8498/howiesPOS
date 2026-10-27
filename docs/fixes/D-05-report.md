# Remediation Report: D-05 (SYNC-032) Append-Only Order Line-Item Ledger

- **Task ID:** D-05 / SYNC-032 (Wave 2)
- **Branch:** `fix/D-05`
- **Worktree:** `D:\HOWIES TEST\wt-d05`
- **Date:** 2026-10-27
- **Status:** **COMPLETE & VERIFIED**

---

## 1. Executive Summary

Task **D-05** resolves **SYNC-032** (Audit Scenario B.1): concurrent multi-terminal line-item loss during order edits.

Previously, both the backend REST `updateOrder` endpoint (`orders.service.ts`) and the frontend Drift SQLite repository (`drift_offline_first_order_repository.dart`) performed destructive deletion of existing line items:
- The backend iterated existing line items and invoked `tx.orderItem.delete()` on any line item missing from the update payload.
- The frontend SQLite repository invoked `db.delete(db.localOrderItems).where((t) => t.orderId.equals(order.id))` prior to re-inserting items.

When two terminals or waiters simultaneously modified an open table order or counter order (e.g., Terminal 1 adding a beverage while Terminal 2 added a pizza), the subsequent update would delete the line item added by the first terminal.

Under D-05, order line items operate as an **append-only ledger** keyed by client-generated **RFC 9562 UUID v7** identifiers:
1. **Additive Schema:** Added `voided_at`, `voided_by`, `supersedes_item_id`, `created_by_device_id`, and `client_created_at` to `OrderItem` (PostgreSQL) and `LocalOrderItems` (Drift SQLite).
2. **Non-Destructive Diffs:** Order updates diff incoming items against existing items. Unmentioned items are **never deleted**. Modifying an item (e.g. quantity or size) voids the old item and inserts a superseding item referencing `supersedes_item_id`.
3. **Explicit Item Endpoints & Operations:** Introduced `POST /orders/:id/items` (`ITEM_ADD`) and `POST /orders/:id/items/:itemId/void` (`ITEM_VOID`) on REST and in sync outbox push/pull payloads.
4. **Commutative Merge with Void-Always-Wins:** The sync engine merges incoming line items via set-union by ID. If an item is voided either locally or remotely, **void always wins**; an un-voided live copy can never revive a voided item regardless of packet arrival order.

---

## 2. Schema Changes & Migration

### 2.1 Backend PostgreSQL Migration

Created migration `20261027150000_order_line_item_ledger`:
- **Timestamp:** `20261027150000` (strictly sequenced prior to concurrent task D-01 at `20261027160000`).
- **Target Table:** `order_items` only. (`RestaurantTable` and other models remained untouched per boundary rules).
- **Columns Added:**
  - `voided_at TIMESTAMP(3)`
  - `voided_by TEXT`
  - `supersedes_item_id TEXT` (self-referencing index)
  - `created_by_device_id TEXT`
  - `client_created_at TIMESTAMP(3)`
- **Backfill:** Existing cancelled items backfilled `voided_at = COALESCE(cancelled_at, NOW())`.
- **Indexes:**
  - `idx_order_items_order_id` on `order_id`
  - `idx_order_items_supersedes` on `supersedes_item_id`
  - `idx_order_items_voided_at` on `voided_at`

### 2.2 Frontend Drift SQLite Migration

- **Schema Version:** Incremented from 2 to 3 in `AppDatabase`.
- **Migration Strategy:**
  ```dart
  if (from < 3) {
    await m.addColumn(localOrderItems, localOrderItems.voidedAt);
    await m.addColumn(localOrderItems, localOrderItems.voidedBy);
    await m.addColumn(localOrderItems, localOrderItems.supersedesItemId);
    await m.addColumn(localOrderItems, localOrderItems.createdByDeviceId);
    await m.addColumn(localOrderItems, localOrderItems.clientCreatedAt);
  }
  ```
- Drift code regenerated via `dart run build_runner build`.

---

## 3. Implementation Details

### 3.1 Backend Architecture

- **`backend/src/orders/dto/create-order.dto.ts` & `update-order.dto.ts`:**
  - Added ledger metadata fields (`voided_at`, `voided_by`, `supersedes_item_id`, `created_by_device_id`, `client_created_at`).
  - Added `fullReplace?: boolean` / `full_replace?: boolean` to `UpdateOrderDto` for explicit administrative resets.
- **`backend/src/orders/dto/append-order-items.dto.ts`:**
  - DTO for appending items to an existing order.
- **`backend/src/orders/dto/void-order-item.dto.ts`:**
  - DTO for voiding an existing order line item with audit reason and author.
- **`backend/src/orders/orders.service.ts`:**
  - `getActiveItems(orderId, tx)`: Filters out items where `voidedAt != null` or `is_cancelled == true`.
  - `appendOrderItems(orderId, items, deviceId, tx)`: Appends UUID v7 line items and updates order subtotal/grandTotal.
  - `voidOrderItem(orderId, itemId, voidedBy, reason, tx)`: Sets `voidedAt`, `voidedBy`, and `cancelReason`.
  - `updateOrder`: Compares incoming items to database items. If an item changed, voids the old item and inserts a superseding item. Preserves unmentioned items unless `fullReplace: true`.
- **`backend/src/orders/orders.controller.ts`:**
  - Added `PUT /api/orders/:id`
  - Added `POST /api/orders/:id/items`
  - Added `POST /api/orders/:id/items/:itemId/void`
- **`backend/src/sync/handlers/order.handler.ts`:**
  - Registered `order_item` entity alias.
  - Added `ITEM_ADD` and `ITEM_VOID` sync handlers.
  - In `handleUpdate`, implements set-union merge by ID. Creates tombstone rows if `ITEM_VOID` arrives out of order before `ITEM_ADD`, ensuring commutativity.

### 3.2 Frontend Architecture

- **`frontend/lib/domain/models/order_model.dart`:**
  - Updated `OrderItem` with `voidedAt`, `voidedBy`, `supersedesItemId`, `createdByDeviceId`, `clientCreatedAt`.
  - Updated `copyWith`, `toCreateItemDto()`, and `fromBackendJson()` with fallback handling for legacy cancellation columns.
- **`frontend/lib/domain/repositories/order_repository.dart`:**
  - Added contract methods: `addOrderItem(orderId, item)` and `voidOrderItem(orderId, itemId, {voidedBy, reason})`.
- **`frontend/lib/data/repositories/drift_offline_first_order_repository.dart`:**
  - `saveOrder`: Sets `createdByDeviceId: _deviceId` and `clientCreatedAt: DateTime.now()`.
  - `updateOrder`: Replaced destructive `delete` with append-only ledger diff.
  - Implemented atomic `addOrderItem` and `voidOrderItem` enqueuing `ITEM_ADD` and `ITEM_VOID` mutations in `sync_outbox`.
  - Updated `_mapToOrderModel` to map ledger fields.
- **`frontend/lib/data/repositories/api_order_repository.dart` & `in_memory_order_repository.dart`:**
  - Implemented `addOrderItem` and `voidOrderItem` for online-only (`OFFLINE_FIRST_ENABLED=false`) and mock repository implementations.
- **`frontend/lib/core/sync/sync_background_worker.dart`:**
  - In `_applyPullChange`, merged incoming items in `order` and `order_item` deltas using set-union by ID where **void always wins over live copy**.

---

## 4. Verification & Test Results

### 4.1 Backend Test Verification
- **Unit & Integration Tests:**
  - `backend/src/orders/orders-ledger.spec.ts`: 7/7 tests passed (Append-only merging, non-deletion of unmentioned items, `fullReplace` flag, superseding modified items, `appendOrderItems`, `voidOrderItem`, and out-of-order commutativity).
  - `backend/src/orders/orders.controller.spec.ts`: 8/8 tests passed.
  - `backend/src/orders/orders.service.spec.ts`: 17/17 tests passed.
  - `backend/src/sync/handlers/order.handler.spec.ts`: 17/17 tests passed.
- **Full Backend Suite:**
  - **65 passed, 65 total suites (456 passed, 456 total tests)**
  - Ran cleanly in 35.056 s.
- **Build Verification:**
  - `npm run build` executed with exit code 0 and 0 errors.

### 4.2 Frontend Test Verification
- **Unit & Integration Tests:**
  - `frontend/test/data/repositories/order_line_item_ledger_test.dart`: 5/5 tests passed (`saveOrder` ledger columns, `updateOrder` diff-to-ledger, `addOrderItem` with outbox enqueue, `voidOrderItem` with outbox enqueue, `SyncBackgroundWorker` pull merge with void-always-wins commutativity).
  - `frontend/test/core/database/schema_migration_test.dart`: 2/2 tests passed (schema version 3, all 20 tables + ledger columns verified).
  - `frontend/test/data/repositories/drift_offline_first_order_repository_test.dart`: 12/12 tests passed.
  - `frontend/test/data/`: All 32 tests passed.
- **Full Frontend Suite:**
  - **249 passed, 249 total tests**
  - Ran cleanly in 52 s with 0 failures.
- **Static Analysis:**
  - `flutter analyze` on modified files reported: **"No issues found! (ran in 5.0s)"** (0 errors, 0 warnings).

---

## 5. Backward Compatibility & Boundaries

1. **Online Mode (`OFFLINE_FIRST_ENABLED=false`):**
   - REST endpoints accept both new ledger fields and legacy payloads without error.
   - `ApiOrderRepository` translates `addOrderItem` and `voidOrderItem` calls directly to REST HTTP calls.
2. **Strict Boundary Compliance:**
   - No modifications made to `DiningTable`, `RestaurantTable`, `Zone`, or any table management model in `schema.prisma` or Drift.
   - Migration strictly timestamped `20261027150000`, ordering ahead of concurrent task D-01 (`20261027160000`).
   - Pricing calculations left to D-03 per specification.
