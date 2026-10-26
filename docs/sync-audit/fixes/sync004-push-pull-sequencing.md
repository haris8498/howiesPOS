# SYNC-004 Fix: Push-Pull Sequencing, Single-Flight Mutex, and State-Aware Reconciliations

## Root Cause
Prior to this fix, push synchronization (`triggerPush`) and delta pull replication (`triggerPull`) lacked mutual exclusion and strict sequencing:
1. **Unsynchronized Parallel Execution:** On reconnection (`reconnect()`) or periodic ticks (`_onPeriodicTick()`), `triggerPush()` and `triggerPull()` ran uncoordinated in parallel or push failures did not pause the delta pull stream.
2. **Version-Only Delta Application:** Pull deltas were applied blindly using version checks (`recordVersion > localVersion`). A stale server delta with a higher sequence number returning `status: 'ACTIVE'` and `actual_cash_counted: null` would overwrite locally closed shifts (`OFFLINE_CLOSED`), wiping out counted drawer cash and calculated cash variance. Similarly, tables freed locally (`status: 'available'`) would be snapped back to `occupied` if an incoming delta reported an earlier occupied state.
3. **No In-Flight Outbox Guard on Delta Application:** Pull deltas were applied even for entities that currently had pending or in-flight outbox mutations waiting to be synced to the server.
4. **Non-Transactional Batch Cursor Advancement:** If a batch of pull changes failed mid-batch, the pull cursor would either advance or leave state partially applied.

## Change Summary
1. **Single-Flight Sync Cycle with Coalescing Mutex:**
   - Implemented `triggerSyncCycle({bool force = false})` in `SyncBackgroundWorker`.
   - Uses an internal mutex (`_isCycleRunning`, `_queuedCycle`, `_queuedForcePush`, `_activeCycleCompleter`, `_queuedCycleCompleter`).
   - Strictly enforces the execution order: **PUSH (drain outbox) -> PULL (apply deltas)**.
   - Any overlapping triggers (periodic timer, connectivity change, socket poke, manual calls to `triggerPush`/`triggerPull`) are coalesced into a single queued run rather than running concurrently.
2. **Push Failure Pause (§5):**
   - If push encounters a network error, HTTP 401 (auth pause), or HTTP 5xx error, delta pull is skipped/paused for the current cycle and resumes on the next cycle once connectivity/auth is restored.
3. **Pending Outbox Guard on Delta Application (§2):**
   - Added `_hasPendingOutbox(entityId)` to check for uncommitted mutations in `sync_outbox` (`PENDING`, `IN_FLIGHT`, `FAILED_RETRYABLE`, `AUTH_PAUSED`).
   - If an entity has pending local mutations, incoming pull deltas for that entity are skipped (`PullApplyResult.skippedPending`) and the pull cursor does not advance past that change, guaranteeing re-pull once push drains.
4. **State-Aware Delta Application for Shifts and Tables (§3):**
   - **Shifts:** Shift closure (`CLOSED` or `OFFLINE_CLOSED`) is terminal. A local closed shift never reverts to `ACTIVE` from a stale server delta. Merges and preserves locally counted cash (`actualCashCounted`), `cashVariance`, and `closingNotes`.
   - **Tables:** Respects pending local release/occupy mutations and physical seating occupancy (Hospitality Operational Priority §10.2). Last-writer-wins applies only when no local pending change exists.
   - **Bootstrap Protection:** `_applyBootstrapData` preserves locally closed shifts if an `active_shift` is returned during cold-start bootstrap.
5. **Transactional Batch Pull & Cursor Advancement (§4):**
   - All changes in a pull batch are executed within a single Drift `db.transaction`.
   - The cursor is updated inside the transaction only up to the last applied sequence before any skipped-for-pending change (or `next_cursor` if all applied).
   - If a batch transaction throws an error, Drift rolls back the entire batch and the cursor does not advance.
6. **Per-Cycle Logging (§6):**
   - Added structured debug log output per sync cycle:
     `[SyncWorker] Cycle finished: pushed=$pushedCount, pulled=$pulledCount, skipped_for_pending=$skippedForPendingCount`.

## Files Changed
- `frontend/lib/core/sync/sync_background_worker.dart`:
  - Added `SyncCycleResult`, `PullApplyResult`, `PushBatchDrainResult`, `PullStreamResult`.
  - Added single-flight mutex and coalescing cycle queue in `triggerSyncCycle()`.
  - Routed `triggerPush()`, `triggerPull()`, `reconnect()`, `_onPeriodicTick()`, and socket pokes through `triggerSyncCycle()`.
  - Added `_hasPendingOutbox(entityId)` guard.
  - Implemented transactional batch pull and cursor advancement in `_pullDeltas()`.
  - Implemented state-aware terminal closure and cash merging for shifts and tables in `_applyPullChange()`.
  - Protected locally closed shifts in `_applyBootstrapData()`.
- `frontend/test/core/sync/push_pull_sequencing_test.dart`:
  - New test file covering concurrent trigger serialization, stale delta closure/table protection, pending outbox delta skipping, batch transaction rollback on failure, and pull pause on push errors.
- `frontend/test/core/sync/pull_overwrite_test.dart`:
  - New test file covering Test T-04 (delta pull overwrite of local shift closure and terminal closure guard).

## Tests Added & Verified
- `test/core/sync/push_pull_sequencing_test.dart`:
  - `1. Concurrent trigger calls produce serial execution` (PASSED)
  - `2. Stale delta cannot reopen a closed shift or re-occupy a freed table` (PASSED)
  - `3. Delta for an entity with pending outbox is skipped, then applied after push drains` (PASSED)
  - `4. Cursor does not advance when batch transaction fails` (PASSED)
  - `5. Pull pauses if push fails with network or auth error` (PASSED)
- `test/core/sync/pull_overwrite_test.dart`:
  - `Offline shift closure and counted cash are preserved when delta pull arrives with ACTIVE status` (PASSED)
  - `Locally CLOSED shift is terminal and cannot revert to ACTIVE from stale delta` (PASSED)
- Existing tests:
  - `test/core/sync/sync_engine_test.dart` (11/11 PASSED)
  - `test/integration/failure_scenarios_e2e_test.dart` (16/16 PASSED)
  - Full Flutter suite (`flutter test`): 175/175 tests PASSED (100% green)

## How to Verify Manually
1. Open POS and create an active shift on Terminal 1.
2. Disconnect network / disable Wi-Fi.
3. Close the shift offline by entering counted cash (e.g. PKR 15,000 with a variance). Verify shift status shows `OFFLINE_CLOSED`.
4. Free a dining table (e.g. Table 4).
5. Reconnect network.
6. Verify via terminal logs that:
   - Push executes first and drains outbox mutations before pull delta fetch.
   - Console logs `[SyncWorker] Cycle finished: pushed=X, pulled=Y, skipped_for_pending=Z`.
   - The shift status remains closed and drawer cash count of PKR 15,000 is intact.
   - Table 4 remains available and does not snap back to occupied.

## Residual Risks
- **Long Outbox Queues Under Low Bandwidth:** When a POS reconnects after a very long outage with hundreds of mutations, delta pulls are deferred until all outbox batches drain. This is by design to maintain Push-Then-Pull correctness and prevent stale server deltas from clobbering unpushed local edits.
- **Persistent Outbox Poison Pills:** If a mutation encounters a fatal client error (HTTP 4xx), it is isolated to `sync_conflicts` as `failedFatal` so it does not block the queue or prevent pull execution.
