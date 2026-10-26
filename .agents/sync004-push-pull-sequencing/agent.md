---
name: sync004-push-pull-sequencing
description: Fixes SYNC-004 - concurrent push/pull lets stale server deltas overwrite local shift closures and table releases.
---

# Role
Flutter engineer (Drift, background worker). Fix SYNC-004. START ONLY AFTER `sync005-device-identity-shift` is done and merged, since both edit `sync_background_worker.dart`.

# Reports to read
`FINAL-SYNC-ENGINE-REPORT.md`, `02-multidevice-conflicts.md`, `03-table-conflicts.md`, `04-reconnect-recovery.md`, `06-flutter-lifecycle.md`

# Files you own
- `frontend/lib/core/sync/sync_background_worker.dart` (around lines 354-355 and 1159-1230)
- Drift DAOs for shifts/tables only where required for guards (coordinate via handoff note if outside sync/)

# Problem
Push and pull run concurrently without a lock. Incoming deltas with a higher server version overwrite locally closed shifts (OFFLINE_CLOSED reverts to ACTIVE, losing counted cash and variance) and revert freed tables to occupied.

# Required fix
1. Introduce a single-flight sync cycle: one mutex around a cycle that runs strictly in order PUSH (drain outbox) -> PULL (apply deltas). Overlapping triggers (timer, connectivity change, manual) are coalesced into one queued run, never run in parallel.
2. Do not apply a pull delta for an entity that still has pending/in-flight outbox entries (per entity id); skip and re-pull later.
3. Make delta application state-aware, not version-only:
   - Shifts: a locally CLOSED/OFFLINE_CLOSED shift must never revert to ACTIVE from a stale delta. Closure is terminal; merge counted cash and variance from local.
   - Tables: apply by (updated_at / server version) AND respect pending local release/occupy mutations; last-writer-wins only when no local pending change exists.
4. Apply each pull batch inside one Drift transaction; advance the pull cursor only after the batch commits.
5. Pull must pause if push fails with auth/network errors; resume on next cycle.
6. Add a short log line per cycle (counts pushed/pulled/skipped-for-pending).

# Tests (must exist)
- Concurrent trigger calls produce serial execution (fake timers/completers).
- Stale delta cannot reopen a closed shift or re-occupy a freed table.
- Delta for an entity with pending outbox is skipped, then applied after push drains.
- Cursor does not advance when batch transaction fails.

# Acceptance
Race scenarios from `02` and `03` reports no longer reproduce.

## Ground rules (apply to every agent)
- Read `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` and the specific report(s) listed below BEFORE editing anything. Re-verify the cited file:line evidence in the current code; line numbers may have drifted.
- Stack: Flutter (Riverpod, go_router, Drift/SQLite outbox) frontend; NestJS + Prisma + PostgreSQL backend. Feature flag `OFFLINE_FIRST_ENABLED`.
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.

