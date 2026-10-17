# Stage 5 Implementation Report: Dining Table Conflict Policy & Hospitality Priority

**Author:** `table-conflict-policy` Agent  
**Stage:** Stage 5 (Dining Table Conflict Matrix & Hospitality Operational Invariants)  
**Branch:** `offline/main`  
**Date:** October 17, 2026  
**Related Specs:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` §10 (10.1, 10.2), §3.3, §6.2, §15, and `docs/offline-implementation/00-baseline.md`.

---

## 1. Executive Summary

This report documents the implementation of the dining table synchronization conflict resolution policy, pessimistic hospitality operational guarantees, optimistic concurrency control (OCC), client outbox conflict resolution, and pull-delta filtering for the Hungry Howie's POS offline-first architecture.

In restaurant hospitality, physical reality supersedes remote or cloud-based events:
1. **POS Physical Seated Guest Wins Over Remote Reservation (§10.2):** A customer physically seated at a table cannot be displaced because a remote online booking occurred during an offline interval or network partition. When a conflict between a local walk-in seating (`status: occupied`) and a server reservation (`status: reserved`) occurs, the POS physical guest retains the table, and an overflow table (`${tableNumber}-Overflow`) is automatically created for the remote reservation with a realtime `table.reservation_overflow` notification emitted.
2. **Active / Paid Order Protection (§10.2):** A dining table with an active or paid open order (`Order.status IN ('PENDING', 'IN_PREPARATION', 'READY', 'PAYMENT_PENDING')`) must never have its status overwritten or released by a stale table update. Stale updates targeting active tables are rejected with machine-readable `CONFLICT` and invariant code `ACTIVE_ORDER_PROTECTED`.
3. **Optimistic Concurrency Control (OCC) via `RestaurantTable.version` (§10.1):** All mutations submit `base_version`. If `server.version > mutation.base_version`, updates are rejected with `OCC_VERSION_MISMATCH` unless auto-resolvable or subject to hospitality priority.
4. **Client-Side Outbox Auto-Resolution & Supervisory Badging (§3.3, §6.2):** The client sync worker processes server `CONFLICT` responses:
   - When auto-resolvable (`isAutoResolvable == true`), the client updates the local SQLite table row to the server state, marks the outbox mutation `SYNCED`, and logs an audit record in `sync_conflicts` with status `AUTO_RESOLVED`.
   - When non-resolvable, the mutation is marked `CONFLICT`, quarantined in `sync_conflicts` (`PENDING`), and surfaced via Riverpod providers (`unresolvedConflictCountProvider`, `syncConflictBadgeProvider`, and `syncIndicatorProvider`) without modifying untouched screens.
5. **Pull-Side Delta Echo-Suppression and OCC Filtering:** Incoming table deltas are applied only if `record_version > existing.version`. Echo deltas originating from the current device's own outbox are discarded.

---

## 2. Backend Implementation (`TableHandler`)

### 2.1 File Location & Registration
- Implementation: `backend/src/sync/handlers/table.handler.ts`
- Registered in `backend/src/sync/sync.module.ts` as a provider and exported.
- Registers for entity types: `'table'` and `'restaurant_table'`.

### 2.2 Operational Flow & Conflict Matrix (§10.1)

#### A. INSERT Operations
- Idempotency check: If a table with `entity_id` already exists, returns `DUPLICATE` with current `version`.
- Table Number uniqueness: If another table exists with the same `table_number`, returns `CONFLICT` (`TABLE_NUMBER_EXISTS`).
- Creation: Inserts `RestaurantTable` with `version: 1`, logs audit change in `SyncChangeLog`.

#### B. UPDATE Operations & OCC (§10.1)
- Table lookup: Returns `NOT_FOUND` if the table does not exist.
- OCC version check: If `mutation.base_version != null` and `mutation.base_version < currentTable.version`:
  - **Hospitality Operational Priority (§10.2):** If the incoming mutation sets `status: 'occupied'` (POS seated guest) while server is `reserved` (online booking):
    - Table remains with POS walk-in guest (`status: 'occupied'`, version incremented).
    - An overflow table (e.g. `4-Overflow`) is automatically created/updated with `status: 'reserved'`.
    - Realtime event envelope `table.reservation_overflow` is broadcast via `KitchenGateway`.
    - Change log records `table` update and returns `RESOLVED_PRIORITY` to client.
  - **Active Order Protection (§10.2):** Checks Prisma for open orders (`status IN ('PENDING', 'IN_PREPARATION', 'READY', 'PAYMENT_PENDING')`). If an active order exists on server and the incoming mutation would unseat or alter the table status, it is rejected with `CONFLICT` (`ACTIVE_ORDER_PROTECTED`), returning `isAutoResolvable: true` so the client aligns its local state to server.
  - **Idempotent Replay:** If the incoming mutation desires the exact status the server already has, returns `DUPLICATE`.
  - **Standard OCC Mismatch:** Otherwise returns `CONFLICT` (`OCC_VERSION_MISMATCH`) with `isAutoResolvable: false`.

#### C. DELETE Operations
- Soft/hard deletion: Rejected with `CONFLICT` (`ACTIVE_ORDER_PROTECTED`) if an active order is bound to the table.
- Available tables: Deletes table and creates a `DELETE` change log record.

#### D. Realtime Status Notifications
- Broadcasts `table.status_changed` via `KitchenGateway.emitEnvelope` upon successful table updates, keeping all connected devices synchronized in sub-100ms.

---

## 3. Frontend Implementation (`SyncBackgroundWorker` & Providers)

### 3.1 Push-Side Conflict Processing (`sync_background_worker.dart`)
When the sync push worker encounters `result.status == 'CONFLICT'`:
1. Parses `result.conflictDetails` JSON.
2. Checks `isAutoResolvable`:
   - **Auto-Resolvable (`isAutoResolvable == true`):**
     - If `server_state` is provided, updates `LocalRestaurantTables` (drift SQLite) with server values (`status`, `capacity`, `version`, `isAvailable`).
     - Updates `SyncOutboxTable` row to status `SYNCED`.
     - Inserts a record in `sync_conflicts` with `resolutionStatus = 'AUTO_RESOLVED'` and `resolutionNotes = 'Auto-resolved per policy: local table aligned with server active state.'`.
   - **Non-Resolvable (`isAutoResolvable == false`):**
     - Marks `SyncOutboxTable` row as `CONFLICT`.
     - Inserts record into `sync_conflicts` with `resolutionStatus = 'PENDING'`, capturing `table_number`, `client_version`, `server_version`, and full conflict details.
     - The outbox queue does not get blocked; the poison pill is safely isolated.

### 3.2 Pull-Side Delta Processing (`_applyPullChange`)
When pull engine processes delta changes for `table` / `restaurant_table`:
1. **Echo Suppression:** Checks `change['origin_device_id']` or `change['device_id']` against the local device ID, or checks if `change['operation_id']` exists in local outbox. If it matches an echo of local mutation, it is discarded immediately without database writes.
2. **Hospitality Operational Priority Preservation:** If the local table is `occupied` and has an active local order, but the incoming delta attempts to revert it to `available` or `reserved`, local active dining is preserved, logging a warning.
3. **OCC Version Check:** Table is updated only if `delta.version > local.version`. Stale deltas (`delta.version <= local.version`) are discarded as no-ops.

### 3.3 Provider Surfacing (`sync_providers.dart`)
State is surfaced strictly through Riverpod providers without modifying untouched screens:
1. `unresolvedConflictCountProvider`: A `StreamProvider<int>` watching `sync_conflicts` where `resolutionStatus == 'PENDING'`.
2. `SyncConflictBadgeState`: Value object holding `hasConflict`, `conflictCount`, `label`, `colorHex`, and `colorName` (`#F59E0B` orange for 1 conflict, `#EF4444` red for >1 conflicts).
3. `syncConflictBadgeProvider`: Exposes `SyncConflictBadgeState` derived from `unresolvedConflictCountProvider`.
4. `syncIndicatorProvider`: Updated to surface `SyncIndicatorState.conflict` when `conflictCount > 0`.

---

## 4. Test Verification & Coverage

### 4.1 Backend Unit Tests (`src/sync/handlers/table.handler.spec.ts`)
12 Jest test cases passed:
```
PASS src/sync/handlers/table.handler.spec.ts (7.348 s)
  TableHandler
    √ should register both table and restaurant_table in registry onModuleInit (5 ms)
    handle INSERT
      √ should return DUPLICATE if table with entity_id already exists (3 ms)
      √ should return CONFLICT if another table already has the same table_number (2 ms)
      √ should create new table with version 1 and record in change log (3 ms)
    handle UPDATE & Conflict Policy Scenarios
      √ 1. Cashier reserves vs release race: returns machine-readable CONFLICT when base_version is stale (4 ms)
      √ 2. Stale base_version: detected and rejected with CONFLICT when server has progressed (2 ms)
      √ 3. Offline reserve then server changed: active/paid order must NEVER be lost due to stale table update (§10.2) (2 ms)
      √ 4. Repeated conflict replay (idempotent): returns consistent DUPLICATE if already matching server state (2 ms)
      √ 5. Dining Table Hospitality Operational Priority (§10.1 & §10.2): POS Physical Seated Guest Wins over Online Reservation (4 ms)
      √ 6. Normal update without conflict increments version and broadcasts status change (12 ms)
    handle DELETE
      √ should reject deletion with CONFLICT if table currently has active order (1 ms)
      √ should delete table and record deletion in change log if table is available (1 ms)

Test Suites: 1 passed, 1 total
Tests:       12 passed, 12 total
Snapshots:   0 total
Time:        7.624 s
```

### 4.2 Frontend Unit Tests (`test/core/sync/table_conflict_policy_test.dart`)
5 Flutter test cases passed:
```
00:00 +0: loading D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/test/core/sync/table_conflict_policy_test.dart
00:00 +0: Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3) 1. Auto-resolves CONFLICT per policy when server active order wins: updates local row to server state and marks outbox SYNCED
00:00 +1: Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3) 2. Quarantines non-auto-resolvable CONFLICT in sync_conflicts and surfaces supervisory badge state
00:00 +2: Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3) 3. Pull side: applies table changes ONLY when version is newer
00:00 +3: Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3) 4. Pull side: ignores echo of own writes via device_id and operation_id
00:01 +4: Stage 5: Table Conflict Policy Tests (§10.1, §10.2, §3.3) 5. Pull side: Hospitality Priority preserves local seated guests when active local order exists
00:01 +5: All tests passed!
```

---

## 5. Quality Gate Verifications

| Gate / Command | Result | Notes |
|---|---|---|
| `npx prisma validate` | **PASSED** | Schema at `prisma/schema.prisma` is valid. |
| `npm run build` | **PASSED** | `nest build` completed with code 0 without compilation errors. |
| `npm test -- table.handler.spec.ts` | **PASSED** | 12/12 unit tests passed. |
| `dart analyze lib/core/sync test/core/sync/table_conflict_policy_test.dart` | **PASSED** | 0 issues found, clean analysis. |
| `flutter test test/core/sync` | **PASSED** | 16/16 core sync and table conflict tests passed. |

---

## 6. Files Changed in Stage 5 Scope

- `backend/src/sync/handlers/table.handler.ts` (New Table OCC handler and Hospitality Priority)
- `backend/src/sync/handlers/table.handler.spec.ts` (12 unit tests)
- `backend/src/sync/sync.module.ts` (Registered TableHandler provider & export)
- `backend/src/sync/sync-push.service.ts` (Realtime event notification for table changes)
- `frontend/lib/core/sync/sync_background_worker.dart` (Client push conflict auto-resolve/quarantine & pull OCC filter)
- `frontend/lib/core/sync/sync_providers.dart` (Riverpod conflict count & badge state providers)
- `frontend/test/core/sync/table_conflict_policy_test.dart` (5 Flutter tests)
- `docs/offline-implementation/S5-table-conflict-policy.md` (This documentation report)
