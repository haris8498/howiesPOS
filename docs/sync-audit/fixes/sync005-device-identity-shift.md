# Fix Handoff: SYNC-005 Hardcoded Device Identity & Single-Shift DB Constraint

> **Agent:** `sync005-device-identity-shift`  
> **Status:** COMPLETED  
> **Date:** October 26, 2026  
> **Branch:** `fix/sync005-device-identity-shift`  

---

## 1. Root Cause

1. **Client Identity & Echo Suppression Bug:**  
   Every client installation hardcoded `deviceId: 'POS-P1'` and `terminalId: '1'` in `SyncBackgroundWorker` constructor default parameters and repository providers. During delta pull replication (`SyncBackgroundWorker._applyPullChange`), the engine evaluated:
   ```dart
   final changeDeviceId = payload['origin_device_id'] ?? payload['device_id'];
   if (changeDeviceId != null && changeDeviceId.toString() == deviceId) {
     return; // Ignore echo of own writes
   }
   ```
   Because both Tablet A and Tablet B reported as `POS-P1`, any changes made by Tablet A (such as seating guests at dining tables) were discarded on Tablet B as its own "echo", causing state desynchronization.

2. **Database Single-Shift Constraint:**  
   PostgreSQL migration `20261023120000_unique_active_shift` enforced:
   ```sql
   CREATE UNIQUE INDEX "unique_active_shift" ON "daily_calculations" ("status") WHERE "status" = 'ACTIVE';
   ```
   This prevented more than one active register shift across the entire store. When Tablet B reconnected and pushed an active shift, `ShiftHandler` detected the existing active shift and forcibly downgraded Tablet B's shift to `OFFLINE_CLOSED` with `CONFLICT (ACTIVE_SHIFT_EXISTS)`, subsequently dropping counted cash and closing reconciliation.

---

## 2. Change Summary

1. **Persistent Device Identity Service (`device_identity.dart`):**
   - Created `DeviceIdentityService` and `deviceIdentityProvider` in `frontend/lib/core/sync/device_identity.dart`.
   - On first launch, generates a persistent RFC 9562 UUID v4 hardware device identifier.
   - Encrypts identity tokens at rest using Windows DPAPI (`WindowsDpapi.protectString`) stored in `SharedPreferences`, completely separated from SQLite/Drift databases (surviving database resets or restores).
   - Allows configuration and persistence of human-assigned `terminalId` (default: `'1'`), `terminalName` (default: `'Register 1'`), and `restaurantId` (default: `'default'`).
   - Exposes static and Riverpod reactive accessors (`deviceIdentityProvider`, `currentDeviceIdProvider`, `currentTerminalIdProvider`).

2. **Dynamic Sync Worker Identity:**
   - Modified `SyncBackgroundWorker` constructor in `frontend/lib/core/sync/sync_background_worker.dart`:
     Replaced `this.deviceId = 'POS-P1'` literal with dynamic initialization defaulting to `DeviceIdentityService.currentDeviceId`.
   - Preserved all other logic in `sync_background_worker.dart` for subsequent work by `sync004`.
   - Echo suppression now compares incoming delta `origin_device_id` against the unique device UUID. Changes from other physical registers are accepted and applied.

3. **Database Migration (`20261026100000_terminal_scoped_active_shift_and_devices`):**
   - Dropped the store-wide `unique_active_shift` partial unique index.
   - Added `restaurant_id` (`VARCHAR(50) NOT NULL DEFAULT 'default'`) and `terminal_id` (`VARCHAR(50) NOT NULL DEFAULT '1'`) to `daily_calculations`.
   - Safely backfilled legacy shift rows with default values.
   - Added deduplication logic before index creation to safely close older duplicate active shifts per terminal on existing databases.
   - Created scoped partial unique index:
     ```sql
     CREATE UNIQUE INDEX "unique_active_shift_per_terminal"
     ON "daily_calculations" ("restaurant_id", "terminal_id")
     WHERE "status" = 'ACTIVE';
     ```
   - Created `devices` table for POS hardware registration and management (`device_id`, `restaurant_id`, `terminal_id`, `terminal_name`, `is_blocked`, `last_seen_at`).
   - Included full down/rollback instructions in migration SQL comments.

4. **Terminal-Scoped Shift Services:**
   - `ShiftHandler` (`backend/src/sync/handlers/shift.handler.ts`):
     - Active shift uniqueness guard now checks `{ restaurant_id, terminal_id, status: 'ACTIVE' }`.
     - Allows concurrent active shifts across distinct registers.
     - Opening a second active shift on the SAME terminal returns `CONFLICT` (`ACTIVE_SHIFT_EXISTS`) with clear message: `Cannot open active shift: Terminal '${terminalId}' already has active shift '${activeShift.id}'. Preserved offline shift as OFFLINE_CLOSED.`
     - Preserves backward compatibility for legacy clients sending `'POS-P1'`, defaulting to terminal 1 and logging a warning.
   - `DailyCalculationService` (`backend/src/daily-calculation/daily-calculation.service.ts`):
     - `startSession` and `getActiveSession` accept and enforce `terminal_id` and `restaurant_id`.
     - Attempting to open a second active shift on the same terminal returns HTTP 409 Conflict with clear message: `An active shift already exists on terminal ${terminalId}. Close the current shift before opening a new shift.`

5. **Device Registration & Validation Guard:**
   - Added endpoint `POST /api/sync/device/register` (and alias `/api/sync/register-device`) in `SyncController`.
   - In `SyncPushService.pushMutations()`:
     - When `DEVICE_VALIDATION_ENABLED=true`: rejects unregistered non-legacy devices and blocked devices with HTTP 403 Forbidden.
     - When flag is OFF (default): automatically upserts device records and updates `last_seen_at` without rejecting pushes.
     - Legacy clients sending `'POS-P1'` are always permitted.

---

## 3. Files Changed

### Frontend
- **NEW:** `frontend/lib/core/sync/device_identity.dart` - Secure device identity manager and Riverpod providers.
- `frontend/lib/core/sync/sync_background_worker.dart` - Replaced `deviceId` literal with `DeviceIdentityService.currentDeviceId`.
- **NEW:** `frontend/test/core/sync/device_identity_test.dart` - Test suite for UUID generation, persistence across restarts, and echo suppression.

### Backend
- `backend/prisma/schema.prisma` - Added `restaurant_id`, `terminal_id` to `DailyCalculation` and added `Device` model.
- **NEW:** `backend/prisma/migrations/20261026100000_terminal_scoped_active_shift_and_devices/migration.sql` - Drop single active shift index, add scoped unique index, create `devices` table.
- `backend/src/daily-calculation/daily-calculation.service.ts` - Terminal-scoped active shift checks.
- `backend/src/daily-calculation/dto/start-session.dto.ts` - Added `terminal_id` and `restaurant_id` properties.
- `backend/src/daily-calculation/daily-calculation.controller.ts` - Passed `terminal_id` query parameter to active session getter.
- `backend/src/sync/dto/sync-push.dto.ts` - Added optional `restaurant_id`.
- `backend/src/sync/sync.controller.ts` - Added `POST /api/sync/device/register` endpoint.
- `backend/src/sync/sync-push.service.ts` - Added device registration, validation gating, and `last_seen_at` tracking.
- `backend/src/sync/handlers/shift.handler.ts` - Terminal-scoped active shift enforcement and legacy client handling.
- `backend/src/sync/offline-schema.spec.ts` - Added schema and migration assertions.
- **NEW:** `backend/src/sync/sync005-multi-terminal-shift.spec.ts` - Integration tests for multi-terminal concurrency and device registration.

---

## 4. Tests Added & Results

### Frontend Tests (`frontend/test/core/sync/device_identity_test.dart`)
1. **Device UUID Distinctness & Persistence:** Two devices generate distinct UUIDs on first launch and persist them across application restarts.
2. **Terminal Setup Persistence:** Admin terminal assignment (`terminalId: '3'`, `terminalName: 'Express Kiosk 3'`) persists outside SQLite across restarts while preserving underlying hardware device UUID.
3. **Multi-Device Echo Suppression:** Device A does NOT drop Device B's table changes as self-echo, but DOES drop its own writes when echoing back from server.
- **Result:** 3/3 passed (14/14 passed across all sync unit tests).

### Backend Tests (`backend/src/sync/sync005-multi-terminal-shift.spec.ts` & `offline-schema.spec.ts`)
1. **Multi-Terminal Concurrency:** Terminal 1 and Terminal 2 hold active shifts simultaneously via sync push without conflict.
2. **Same-Terminal Conflict Rejection:** Opening a second shift on Terminal 1 while one is already active returns `CONFLICT` (`ACTIVE_SHIFT_EXISTS`) and preserves the offline shift as `OFFLINE_CLOSED`.
3. **Online Concurrency:** `DailyCalculationService.startSession` allows concurrent active sessions on Terminal 1 and Terminal 2; blocks duplicate shift on same terminal with HTTP 409 Conflict.
4. **Legacy Compatibility:** Client sending `'POS-P1'` is accepted, treated as terminal 1, and logs a warning.
5. **Device Registration & Flag Gating:** Device registration endpoint upserts devices; rejects blocked devices; rejects unregistered devices only when `DEVICE_VALIDATION_ENABLED=true`.
6. **Migration Verification:** Migration drops `unique_active_shift`, backfills legacy data, and creates `unique_active_shift_per_terminal`.
- **Result:** 19/19 passed in sync test suites; 57/57 passed across entire backend test suite (389 tests passed).

---

## 5. How to Verify Manually

1. **Verify Distinct Device IDs on Multiple Terminals:**
   - Launch POS on Terminal 1 and inspect logs: confirm device ID is a UUID v4.
   - Launch POS on Terminal 2: confirm distinct UUID v4.
   - Reboot both terminals: confirm device IDs remain identical to first launch.
2. **Verify Concurrent Active Shifts:**
   - Terminal 1 starts a shift: status is `ACTIVE`.
   - Terminal 2 starts a shift: status is `ACTIVE`.
   - Run query in PostgreSQL:
     ```sql
     SELECT id, restaurant_id, terminal_id, status FROM daily_calculations WHERE status = 'ACTIVE';
     ```
     Confirm both rows exist simultaneously with status `ACTIVE`.
3. **Verify Same-Terminal Rejection:**
   - On Terminal 1, attempt to call `POST /api/daily-calculations/start-session` with `terminal_id: '1'`.
   - Confirm server returns HTTP 409 Conflict: `"An active shift already exists on terminal 1"`.
4. **Verify Echo Suppression:**
   - Seat guest at Table 3 on Terminal 1 while offline. Reconnect Terminal 1.
   - Pull changes on Terminal 2: Table 3 updates to `occupied` on Terminal 2 (not discarded as echo).

---

## 6. Residual Risks & Next Steps (Handoff to sync004)

- **Shift Cash Variance Allocation across Terminals:** In online-shared shift mode, order cash totals are aggregated by `shift_id`. Because each terminal now maintains its own active shift session, each register's counted cash balances strictly against the orders associated with its specific terminal shift.
- **Order Repository & Shift Repository Literals:** `order_repository_provider.dart` and `shift_repository_provider.dart` still default to `'1'` / `'POS-P1'`. To maintain strict boundaries within "Files you own", these providers can now read `ref.watch(currentDeviceIdProvider)` and `ref.watch(currentTerminalIdProvider)`.
- **Handoff to `sync004-push-pull-sequencing`:** `sync_background_worker.dart` has been updated with minimal literal changes only. `sync004` can now proceed to introduce the push-then-pull mutex and state-aware delta application around lines 354 and 1159.
