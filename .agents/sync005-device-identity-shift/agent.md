---
name: sync005-device-identity-shift
description: Fixes SYNC-005 - hardcoded deviceId/terminalId and the one-active-shift-per-restaurant unique index.
---

# Role
Full-stack engineer (Flutter + Prisma migration). Fix SYNC-005: Hardcoded Device Identity and Single-Shift DB Constraint.

# Reports to read
`FINAL-SYNC-ENGINE-REPORT.md`, `02-multidevice-conflicts.md`, `08-security-auth.md`

# Files you own
- NEW: device identity service/provider in `frontend/lib/core/sync/` (e.g. `device_identity.dart`)
- `frontend/lib/core/sync/sync_background_worker.dart` ONLY the `deviceId` / `terminalId` literals (around lines 173 and 1137). Do not change anything else in that file (sync004 owns it next).
- NEW Prisma migration replacing the `unique_active_shift` partial unique index (migration.sql lines 16-17 reference) plus schema.prisma
- Backend device registration/validation, if needed

# Problem
Every terminal sends `deviceId: 'POS-P1'` and `terminalId: '1'`, so devices ignore each other's changes as self-echoes. The partial unique index `unique_active_shift` allows only one active shift in the whole restaurant, blocking multi-terminal use.

# Required fix
1. Generate a UUID device id on first launch, persist it in secure storage (not in the Drift DB that can be wiped on restore without the id), expose through a Riverpod provider. Terminal id/name is a human label chosen/assigned at setup, stored with the device id.
2. Replace hardcoded literals with the provider value. Echo filtering must compare against the real device id.
3. Backend: register devices (upsert by restaurant + device id), reject pushes from unregistered/blocked devices only when the flag is on, to keep flag-off behaviour unchanged.
4. Migration: drop `unique_active_shift`; create a new partial unique index scoped per terminal: unique (restaurant_id, terminal_id) WHERE status = 'ACTIVE' (add `terminal_id` to the shift table if missing, backfilling existing rows with the legacy value '1'). Write the migration to be safe on existing data and include a down/rollback note.
5. Update shift open/close services to use the terminal-scoped rule; opening a second shift on the SAME terminal still errors with a clear message.
6. Legacy clients still sending 'POS-P1' must keep working (treat as a legacy device, log a warning).

# Tests (must exist)
- Two devices get different ids and persist them across restarts.
- Device A does not drop device B's changes as self-echo.
- Two terminals can hold active shifts at once; a second active shift on the same terminal is rejected.
- Migration applies cleanly on a DB with existing shift rows.

# Acceptance
No hardcoded `POS-P1` / terminal '1' remains in sync code paths; two terminals operate concurrently.

## Ground rules (apply to every agent)
- Read `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` and the specific report(s) listed below BEFORE editing anything. Re-verify the cited file:line evidence in the current code; line numbers may have drifted.
- Stack: Flutter (Riverpod, go_router, Drift/SQLite outbox) frontend; NestJS + Prisma + PostgreSQL backend. Feature flag `OFFLINE_FIRST_ENABLED`.
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.

