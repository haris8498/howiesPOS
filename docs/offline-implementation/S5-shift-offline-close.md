# Stage 5 Implementation Report: Offline Shift Close & Cash Variance Handling

**Author:** `shift-offline-close` Agent  
**Stage:** Stage 5 (Shift Offline Open/Close, Cash Variance Capture, Sync Handler, & Dependency Ordering)  
**Branch:** `offline/main`  
**Date:** October 17, 2026  
**Related Specs:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` §21 (Decision 2), §7.3, §8.3(3), §5.2 (`local_daily_calculations`), §6.3, §10.1, and `docs/offline-implementation/00-baseline.md`.

---

## 1. Executive Summary

This report documents the implementation of the offline shift lifecycle (opening, active drawer management, and shift closure), cash variance recording, idempotent synchronization, and topological dependency enforcement for the Hungry Howie's POS offline-first architecture.

### Key Architectural Invariants & Decisions:
1. **Spec §21 (Decision 2) — Cash Variance Philosophy:**
   - **Zero Operational Blocking:** The cashier can close the shift with *any* variance (shortage or excess). No threshold checks block shift close, no supervisor PIN is demanded on the POS terminal, and no outbound SMS/email alerts are triggered.
   - **Audit Durability:** Expected cash, counted cash, variance (`counted - expected`), and optional cashier explanations are captured faithfully. The server stores all variance data alongside the shift with `status: 'OFFLINE_CLOSED'`.
   - **Cloud Review:** Restaurant owners and managers review all variances, notes, and audit logs via the cloud management dashboard.
2. **Atomic Client Persistence (§5.2, §8.3(3)):**
   - Both shift open and shift close operations execute within a single atomic SQLite transaction writing to `local_daily_calculations` and `sync_outbox` simultaneously. An offline shift is immediately marked `OFFLINE_CLOSED` locally and can never be left in an ambiguous or orphaned state.
3. **Deterministic Topological Dependency Ordering (§6.3):**
   - Shift Open: **Level 0** (base prerequisite for all transactional operations within the shift).
   - Orders & Payments: **Level 2** (dependent on shift open).
   - Shift Close: **Level 5** (closure level; guarantees that all orders and payments created during the shift session are committed and synced prior to closing the shift).
4. **Idempotency & Optimistic Concurrency Control (OCC) (§7.1, §8.2, §10.1):**
   - Shift mutations carry deterministic UUID v7 `operation_id` and `base_version`.
   - Replays of shift opens or closes return `DUPLICATE` without throwing errors or duplicating database records.
   - Concurrency conflicts return `CONFLICT` with the latest server state, preventing silent data overwrites.

---

## 2. Backend Implementation

### 2.1 Schema & DTO Updates
- **File:** `backend/src/daily-calculation/dto/submit-daily-calculation.dto.ts`
  - Added optional fields: `id`, `shift_id`, `cash_variance`, `variance_reason`, `status`, `actual_cash_counted`, `expected_cash_drawer`.
- **File:** `backend/src/sync/dto/sync-push.dto.ts`
  - Added `depends_on_operation_id?: string` to `SyncMutationDto` to support DAG dependency ordering.
- **File:** `backend/src/sync/handlers/sync-entity.handler.ts`
  - Extended `SyncResultStatus` type union with `'FAILED_RETRYABLE'` for DAG dependency deferrals.

### 2.2 Removal of Hard Variance Blocking in `DailyCalculationService`
- **File:** `backend/src/daily-calculation/daily-calculation.service.ts`
  - **Removed Validation 2:** Hard variance block `BadRequestException('Actual cash counted does not match expected amount.')` removed per §8.3.3 and §21 Decision 2.
  - **Removed Validation 3:** Discrepancy block `BadRequestException('Discrepancy detected in daily calculation.')` removed.
  - **Relaxed Validation 1:** Expenses vs Skimming discrepancy check is skipped for offline closes (`status === 'OFFLINE_CLOSED'`) to ensure offline shifts sync safely.
  - **Field Persistence:** Persists `cash_variance`, `variance_reason`, `status` (`OFFLINE_CLOSED` or `SUBMITTED`), and increments `version` for supervisory audit trails.

### 2.3 Sync Shift Handler (`ShiftHandler`)
- **File:** `backend/src/sync/handlers/shift.handler.ts`
  - Registered in `backend/src/sync/sync.module.ts` and `HandlerRegistry` for `entity_type: 'shift'`.
  - **`handleInsert` (Shift Open — Level 0):**
    - Idempotency check: Returns `DUPLICATE` if shift ID already exists.
    - Creates `DailyCalculation` record with starting cash, cashier attribution, and initial version `1`.
    - Emits change log entry to `ChangeLogService`.
  - **`handleUpdate` (Shift Close — Level 5):**
    - **Dependency Check:** Inspects `depends_on_operation_id` if provided against `processed_operations`. Returns `FAILED_RETRYABLE` if dependent operations are uncommitted.
    - **Fatal Validation:** Returns `FAILED_FATAL` if the targeted shift does not exist.
    - **Idempotency Check:** If shift is already closed (`OFFLINE_CLOSED` or `CLOSED`), returns `DUPLICATE` with existing server state.
    - **OCC Concurrency Check:** If `server.version > mutation.base_version`, returns `CONFLICT` with the current server record.
    - **Atomic Closure:** Updates status to `OFFLINE_CLOSED`, stores `cash_variance`, `variance_reason`, `closed_at`, links shift orders, increments `version`, and logs audit trail.

---

## 3. Client Implementation (Flutter / Drift)

### 3.1 Domain & Repository Seams
- **File:** `frontend/lib/domain/repositories/shift_repository.dart`
  - Defines `IShiftRepository` interface with `openShift()`, `closeShift()`, `getActiveShift()`, `watchActiveShift()`, and `getShiftById()`.
- **File:** `frontend/lib/data/repositories/drift_offline_first_shift_repository.dart`
  - Concrete implementation executing offline shift actions.
  - **`openShift()`:**
    - Generates UUID v7 operation ID.
    - Atomically writes `local_daily_calculations` (status: `OPEN`) and `sync_outbox` (Level 0) in one SQLite transaction.
  - **`closeShift()`:**
    - Computes `cashVariance = actualCashCounted - expectedCashDrawer`.
    - Atomically writes `local_daily_calculations` (status: `OFFLINE_CLOSED`, cash variance, closing time) and `sync_outbox` (Level 5, `depends_on_operation_id` linking) in one SQLite transaction.
    - Handles idempotency: subsequent close calls for an already closed shift return cleanly.
- **File:** `frontend/lib/data/repositories/shift_repository_provider.dart`
  - Provides Riverpod accessors: `driftOfflineFirstShiftRepositoryProvider` and `shiftRepositoryProvider`.

### 3.2 Database DAO & Background Sync Worker
- **File:** `frontend/lib/core/database/daos/daily_calculations_dao.dart`
  - Added `expectedCashDrawer` parameter to `closeShiftOffline()`.
- **File:** `frontend/lib/core/sync/sync_background_worker.dart`
  - Maps `depends_on_operation_id` into push payload batches.
  - When sync succeeds for `entityType == 'shift'`, calls `db.dailyCalculationsDao.markCalculationSynced(entry.entityId, serverVersion)`.

### 3.3 UI Integration & Feature Flag Bridge
- **File:** `frontend/lib/data/daily_calculation_repository.dart`
  - Updated `checkActiveSession()`, `startSession()`, and `submitDailyCalculation()`.
  - When `FeatureFlags.offlineFirstEnabled == true`, shifts route directly through the offline-first repository, persisting locally and queueing sync outbox mutations.
  - Preserves REST fallback when feature flag is disabled.
- **File:** `frontend/lib/features/daily_calculation/daily_calculation_screen.dart`
  - Removed UI blockers (`_isCountedMatched` and `_isRevenueMatched`).
  - Displays non-blocking cash shortage or overage badge in the confirmation dialog.
  - Allows cashier to proceed with shift close under all financial conditions.

---

## 4. Quality Gates & Test Verification

### 4.1 Backend Verification
1. **Prisma Validation:**
   ```bash
   npx prisma validate
   # Output: The schema at prisma\schema.prisma is valid 🚀
   ```
2. **NestJS Build:**
   ```bash
   npm run build
   # Output: Built successfully with code 0
   ```
3. **Shift Handler Unit Tests (`src/sync/handlers/shift.handler.spec.ts`):**
   ```bash
   npx jest src/sync/handlers/shift.handler.spec.ts
   ```
   **Results (9/9 Passed):**
   - `√ should register itself in handler registry on module init`
   - `√ handle INSERT: should return DUPLICATE if shift ID already exists (idempotent open)`
   - `√ handle INSERT: should open shift with starting cash and record change log on new INSERT`
   - `√ handle UPDATE: Scenario 1: close offline then sync (stores cash_variance and OFFLINE_CLOSED status)`
   - `√ handle UPDATE: Scenario 2: two closes for same shift (idempotent close)`
   - `√ handle UPDATE: Scenario 3: close attempted with unsynced dependency (rejects with FAILED_RETRYABLE)`
   - `√ handle UPDATE: Scenario 4: OCC version conflict when server has been modified (server > base_version)`
   - `√ handle UPDATE: Scenario 5: returns FAILED_FATAL if shift record does not exist on UPDATE`
   - `√ Topological Ordering: Scenario 6: orders created offline before close all sync before the closure operation`

### 4.2 Frontend Verification
1. **Dart Analyzer:**
   ```bash
   dart analyze lib/domain/repositories/shift_repository.dart lib/data/repositories/drift_offline_first_shift_repository.dart lib/data/repositories/shift_repository_provider.dart lib/data/daily_calculation_repository.dart lib/core/database/daos/daily_calculations_dao.dart lib/features/daily_calculation/daily_calculation_screen.dart test/data/repositories/drift_offline_first_shift_repository_test.dart
   ```
   **Results:** 0 errors, 0 warnings.
2. **Flutter Unit Tests (`test/data/repositories/drift_offline_first_shift_repository_test.dart`):**
   ```bash
   flutter test test/data/repositories/drift_offline_first_shift_repository_test.dart
   ```
   **Results (6/6 Passed):**
   - `√ 1. Atomic Transaction: Shift open writes local_daily_calculations and sync_outbox (Level 0)`
   - `√ 2. Atomic Transaction: Shift close writes OFFLINE_CLOSED, variance, and outbox (Level 5)`
   - `√ 3. Decision 2: Blocks nothing based on variance size (handles both shortage and overage)`
   - `√ 4. Idempotency: Two closes for same shift return cleanly without duplicate outbox mutation`
   - `√ 5. Dependency Ordering (§6.3): Level 0 (open) < Level 2 (orders) < Level 5 (close)`
   - `√ 6. Queries: getActiveShift and watchActiveShift reflect shift status reactively`

---

## 5. Files Changed & Created

| File | Status | Description |
|---|---|---|
| `backend/src/daily-calculation/dto/submit-daily-calculation.dto.ts` | Modified | Added variance, expected cash, and status fields to DTO |
| `backend/src/daily-calculation/daily-calculation.service.ts` | Modified | Removed hard variance blocking, stores variance & OFFLINE_CLOSED |
| `backend/src/sync/dto/sync-push.dto.ts` | Modified | Added `depends_on_operation_id` to mutation DTO |
| `backend/src/sync/handlers/sync-entity.handler.ts` | Modified | Added `FAILED_RETRYABLE` to sync result status enum |
| `backend/src/sync/handlers/shift.handler.ts` | Created | Sync handler for shifts with Level 0 open, Level 5 close, OCC, and idempotency |
| `backend/src/sync/handlers/shift.handler.spec.ts` | Created | 9 comprehensive backend unit tests |
| `frontend/lib/domain/repositories/shift_repository.dart` | Created | `IShiftRepository` interface |
| `frontend/lib/data/repositories/drift_offline_first_shift_repository.dart` | Created | Drift offline-first shift repository implementation |
| `frontend/lib/data/repositories/shift_repository_provider.dart` | Created | Riverpod providers for shift repository |
| `frontend/lib/core/database/daos/daily_calculations_dao.dart` | Modified | Added `expectedCashDrawer` support to `closeShiftOffline` |
| `frontend/lib/data/daily_calculation_repository.dart` | Modified | Offline-first routing via `FeatureFlags.offlineFirstEnabled` |
| `frontend/lib/features/daily_calculation/daily_calculation_screen.dart` | Modified | Non-blocking variance modal with shortage/overage display |
| `frontend/test/data/repositories/drift_offline_first_shift_repository_test.dart` | Created | 6 comprehensive frontend unit tests |
| `docs/offline-implementation/S5-shift-offline-close.md` | Created | Full stage implementation report |

---

## 6. Manual Verification Walkthrough

1. **Offline Shift Open:**
   - Launch POS in airplane mode.
   - Enter starting drawer cash (e.g., $150.00).
   - Verify shift opens immediately; `local_daily_calculations` has status `OPEN`, and outbox has `dependency_order = 0`.
2. **Order Processing:**
   - Create and pay for cash orders during the shift.
   - Verify orders receive `dependency_order = 2`.
3. **Offline Shift Close with Variance:**
   - Count drawer cash with intentional variance (e.g., expected $245.50, counted $230.00 -> $15.50 shortage).
   - In Daily Calculation Screen, observe shortage displayed in yellow badge.
   - Click "Submit Calculation & Close Shift".
   - Shift closes immediately without blocking; `local_daily_calculations` has status `OFFLINE_CLOSED`, and outbox has `dependency_order = 5`.
4. **Online Sync:**
   - Reconnect network.
   - `SyncBackgroundWorker` pushes batch to `/api/sync/push`.
   - Operations process in topological order: Level 0 (Shift Open) -> Level 2 (Orders) -> Level 5 (Shift Close).
   - Shift in PostgreSQL database reflects `status: 'OFFLINE_CLOSED'`, `cash_variance: -15.50`.
