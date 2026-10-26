---
name: sync002-clear-errors-purge
description: Fixes SYNC-002 - Data Sync screen button that marks unsent/failed outbox entries SYNCED and erases orders.
---

# Role
Flutter engineer (Riverpod, Drift). Fix SYNC-002: Cashier UI Button Permanently Purges Unsynced Orders.

# Reports to read
`FINAL-SYNC-ENGINE-REPORT.md`, `01-outbox-idempotency.md`, `06-flutter-lifecycle.md`, `08-security-auth.md`

# Files you own
- `frontend/lib/**/data_sync_screen.dart` (around lines 214-226)
- `frontend/lib/**/outbox_dao.dart` (around lines 140-151)
- related widget/DAO tests, and a new drift migration only if a schema change is unavoidable

# Problem
"Clear N Sync Errors" calls `clearFailedEntries()`, which sets `status = 'SYNCED'` for failed AND pending entries locally without sending them. A cashier can erase orders and drawer variance just to remove a red indicator.

# Required fix
1. Remove the behaviour of marking unsent entries as SYNCED. Never set SYNCED locally; only a confirmed server acknowledgement may do that.
2. Replace the button with "Retry failed" which resets FAILED entries to PENDING (attempt count reset, next-retry now) so the worker resends them.
3. If an entry is permanently rejected by the server (non-retryable), move it to a `QUARANTINED`/`DEAD_LETTER` status that is retained, visible, and exportable. Do not delete. Add a manager-only "Export / Report to support" action.
4. Any destructive/discard action (if kept at all) must require manager role + PIN, a confirmation dialog listing count and total monetary value affected, and write an audit-log row (who, when, entry ids, amounts) BEFORE changing state. Prefer not offering discard in this change.
5. DAO: rename or replace `clearFailedEntries` so the old unsafe semantics cannot be called by accident; add a unit test that guards it.
6. Status indicator must still turn green only when the outbox has zero PENDING/FAILED/QUARANTINED entries.

# Tests (must exist)
- Retry resets FAILED -> PENDING and leaves SYNCED untouched.
- No DAO method can mark an unacknowledged entry SYNCED.
- Widget test: button label/behaviour, role gating, confirmation (if any discard remains).
- Audit row written for any state change by a user action.

# Acceptance
There is no UI path that makes an unsent order disappear from the outbox.

## Ground rules (apply to every agent)
- Read `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` and the specific report(s) listed below BEFORE editing anything. Re-verify the cited file:line evidence in the current code; line numbers may have drifted.
- Stack: Flutter (Riverpod, go_router, Drift/SQLite outbox) frontend; NestJS + Prisma + PostgreSQL backend. Feature flag `OFFLINE_FIRST_ENABLED`.
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.

