# Stage 3 Implementation Report: Client Synchronization Engine

> **Stage:** `client-sync-engine` (Stage 3)  
> **Architecture Spec Sections:** §6 (6.2-6.4), §8.1, §13, §15.2, §15.3, §9 (client side), §4.4  
> **Report File:** `docs/offline-implementation/S3-client-sync-engine.md`  
> **Status:** Completed & Verified  
> **Date:** October 17, 2026  
> **Branch:** `offline/main`  
> **Depends On:** `client-database` (Stage 2), `backend-sync-api` (Stage 2)

---

## 1. What Was Built

1. **Active Connectivity Notifier (`ConnectivityNotifier` - Spec §6.4 & §13):**
   - Implemented `frontend/lib/core/sync/connectivity_notifier.dart` as a Riverpod `StateNotifier<ConnectivityState>`.
   - Actively probes the `/api/health` HTTP endpoint rather than relying solely on OS network interfaces.
   - Transitions between `online`, `offline`, and `probing` states, capturing latency (ms), consecutive failures, and error details.
   - Provides background periodic probing with explicit lifecycle disposal.

2. **Push Pipeline with Batching & Dependency Ordering (§6.1-§6.3, §8.1.1):**
   - Implemented `SyncBackgroundWorker.triggerPush()` and `_processPushBatch()`.
   - Queries batches from `sync_outbox` limited to $\le 25$ mutations, sorted strictly by `dependency_order ASC, created_at ASC`.
   - Applies Tier 3 Anti-Duplicate defense (§15.2) by locking records to `IN_FLIGHT` with `sentAt` timestamp before network transmission.
   - Emits `POST /api/sync/push` envelope with `device_id`, `batch_id` (UUID v7), and header `X-Idempotency-Key`.
   - Transactionally applies per-mutation server results:
     - `SYNCED` / `DUPLICATE`: marks outbox row `SYNCED` with server ACK timestamp and updates `local_orders` to `synced` with `server_version` and `server_updated_at`.
     - `CONFLICT`: marks outbox row `CONFLICT`, inserts quarantine record into `sync_conflicts` with `ConflictType.occMismatch`, and updates `local_orders.sync_status = 'conflict'`.
     - `FAILED_FATAL`: isolates poison pills by updating outbox to `FAILED_FATAL` and logging to `sync_conflicts` with `ConflictType.fatalError`. Does NOT abort or poison independent operations.
     - `FAILED_RETRYABLE`: recalculates next attempt using exponential backoff with jitter.

3. **Exponential Backoff with Jitter & Circuit Breaker (§6.4):**
   - Implemented exact formula:
     $$T_{\text{delay}} = \min(300, 2.0 \times 2^{\text{retry\_count}}) \times (0.75 + 0.5 \times \text{random}())$$
   - Supports unlimited retries for indefinite offline operation (Directive Q7.3).
   - Circuit Breaker: Tracks consecutive socket/network failures. Upon 5 consecutive failures, trips circuit breaker, pauses outbox processing for 30 seconds (configurable in tests), probes `/api/health`, and automatically resumes upon recovery.

4. **Authentication Pause & Resume (Approved Deviation #3):**
   - HTTP 401 Unauthorized during sync is treated as `AUTH_PAUSED` rather than `FAILED_FATAL`.
   - Batches encountering 401 are marked `AUTH_PAUSED`, halting the push loop without quarantining valid transactions.
   - `resumeAuthPaused()` seamlessly transitions paused mutations back to `PENDING` upon cashier re-authentication or token refresh.

5. **Startup Zombie Recovery & WAL Maintenance (§15.3, Risk #3):**
   - Implemented `recoverOrphanedOutboxTasks(olderThan: 60s)`: Automatically resets mutations stuck in `IN_FLIGHT` older than 60 seconds back to `PENDING` on startup. Safe because backend processing is strictly idempotent.
   - Periodic SQLite WAL checkpointing via `PRAGMA wal_checkpoint(PASSIVE)` every 1,000 processed mutations to prevent unbounded WAL file growth.

6. **Pull Replication Pipeline & Bootstrap (§8.1.2, §8.1.3, §10.2):**
   - Cursor tracking against `sync_cursors` table for `GLOBAL_PULL_CURSOR`.
   - **Cold-Start Bootstrap:** When cursor is 0, calls `GET /api/sync/bootstrap?raw=true` (with gzip decompression support), hydrates store settings, role permissions, staff users, menu catalog, floor zones, and tables, and seeds cursor to `max_global_sequence`.
   - **Incremental Delta Pull:** Polls `GET /api/sync/pull?cursor=seq&limit=100`.
   - **Stale / Duplicate Ignore:** Compares incoming `record_version` against local record version; strictly ignores changes where local version $\ge$ incoming version.
   - **Hospitality Operational Priority (§10.2):** Preserves local cashier table occupancy if physical walk-in guests were seated offline, preventing remote cloud overwrites.
   - **Real-Time WebSocket Poking (§4.4, §9.1):** Wires Socket.IO events (`*`) from `KitchenSocketService` as lightweight invalidation "pokes" to trigger pull immediately, with periodic polling as fallback.

7. **Riverpod Providers for UI Status (Additive, Untouched Repositories):**
   - Created `frontend/lib/core/sync/sync_providers.dart`:
     - `appDatabaseProvider` (root database provider)
     - `connectivityNotifierProvider` (active health probe)
     - `syncBackgroundWorkerProvider` (single worker lifecycle with explicit disposal)
     - `syncStateProvider` (real-time worker state)
     - `pendingOutboxCountProvider` (stream of outbox pending count)
     - `syncIndicatorProvider` (computed UI indicator state: `allSynced`, `pendingOffline`, `syncing`, `authPaused`, `circuitBreaker`, `conflict`)
   - Left all existing UI screens and active repositories completely untouched.

---

## 2. Files Created & Modified

### Created Files:
- `frontend/lib/core/sync/connectivity_notifier.dart` — Health probe monitor and connectivity state notifier.
- `frontend/lib/core/sync/sync_background_worker.dart` — Push/pull sync worker, backoff jitter, circuit breaker, zombie recovery.
- `frontend/lib/core/sync/sync_providers.dart` — Riverpod providers for sync status, background worker, and UI indicator.
- `frontend/test/core/sync/sync_engine_test.dart` — Unit test suite with real in-process loopback HTTP server.
- `docs/offline-implementation/S3-client-sync-engine.md` — Stage 3 implementation report.

### Files Modified:
- None. All additions are completely additive and modular.

---

## 3. Test Suites Added & Verification Results

### New Test Suite: `frontend/test/core/sync/sync_engine_test.dart`
All 11 unit tests passed cleanly against an ephemeral loopback `HttpServer`:
1. `1. Ordering: mutations are pushed strictly sorted by dependency_order then created_at` — Passed.
2. `2. Retry & Backoff: HTTP 500 increments retryCount and computes jittered nextRetryAt` — Passed.
3. `3. Circuit Breaker: 5 consecutive failures pause queue, reset on health probe` — Passed.
4. `4. Startup Crash Recovery: Zombie tasks left IN_FLIGHT older than 60s reset to PENDING` — Passed.
5. `5. Poison-Pill Isolation: Fatal mutation is quarantined to sync_conflicts without blocking batch` — Passed.
6. `6. 401 Pause / Resume: HTTP 401 transitions outbox to AUTH_PAUSED; resumeAuthPaused restores queue` — Passed.
7. `7. Stale-Version Ignore & Duplicate Pull: incoming delta with version <= local is ignored` — Passed.
8. `8. Hospitality Operational Priority: Seated walk-in guest on POS wins over remote reservation (§10.2)` — Passed.
9. `9. Cold-Start Bootstrap: Hydrates catalog tables when cursor is 0 (§8.1.3)` — Passed.
10. `10. ConnectivityNotifier: probes /api/health and updates online/offline state` — Passed.
11. `11. Riverpod Providers: exposes sync status, pending count, and indicator view model` — Passed.

### Full Frontend Test Run (`flutter test`):
- **Total Test Suites:** 10 test suites passed.
- **Total Unit & Domain Tests:** 51 of 51 tests passed (0 failed, 0 skipped).
  - Baseline: 15 passed
  - Stage 1: +13 passed (total 28)
  - Stage 2: +12 passed (total 40)
  - Stage 3: +11 passed (total 51)

### Static Analysis (`dart analyze`):
- `dart analyze lib/core/sync`: 0 errors, 0 warnings, 0 info hints.
- `dart analyze`: 0 errors. (Pre-existing baseline warnings in `test_mapping.dart` and `test/core/database/schema_migration_test.dart` unchanged).

---

## 4. Commands Run

```powershell
# Analyze sync directory
dart analyze lib/core/sync

# Run sync engine unit tests
flutter test test/core/sync/sync_engine_test.dart

# Run all frontend tests
flutter test

# Verify git status
git status
```

---

## 5. Deviations & Blockers

- **Approved Deviations Applied:**
  - `FeatureFlags.offlineFirstEnabled` defaults to `false`. Background worker only starts automatically when flag is flipped or when explicitly started.
  - HTTP 401 during push pauses the queue as `AUTH_PAUSED` rather than failing fatally or quarantining to conflicts. `resumeAuthPaused()` seamlessly transitions them back to `PENDING` without data loss.
- **Blockers:** None.

---

## 6. How to Verify Manually

1. **Run Sync Engine Tests:**
   ```powershell
   cd frontend
   flutter test test/core/sync/sync_engine_test.dart
   ```
   All 11 tests will pass cleanly with zero network mocks (using local loopback server).

2. **Run Full Test Suite:**
   ```powershell
   cd frontend
   flutter test
   ```
   All 51 frontend tests will pass with code 0.

3. **Verify Riverpod Providers Availability:**
   Inspect `frontend/lib/core/sync/sync_providers.dart` to confirm that `syncStateProvider`, `connectivityNotifierProvider`, and `syncIndicatorProvider` are available for Stage 4+ repository and UI integration.
