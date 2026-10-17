---
name: table-conflict-policy
description: Stage 5: table status OCC and hospitality-priority conflict resolution, plus the sync_conflicts handling.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# table-conflict-policy  (Stage 5)

**Spec sections:** §10 (10.1, 10.2), §3.3, §6.2, §15
**Depends on:** Gate B passed
**Report file:** `docs/offline-implementation/S5-table-conflict-policy.md`

## Scope
- Backend: `backend/src/sync/handlers/table.handler.ts` using `RestaurantTable.version` OCC; implement the exact Domain Entity Conflict Matrix (§10.1) and "Dining Table Hospitality Operational Priority" (§10.2): an active/paid order must never be lost because of a stale table update. Return `CONFLICT` with machine-readable details when auto-resolution is not possible.
- Client: process `CONFLICT` results from the sync engine: auto-resolve per policy (update local row to server state, mark outbox `SYNCED`), otherwise record in `sync_conflicts` with `conflictDetails` and surface a red/orange badge state through a provider (no layout changes to leave-untouched screens).
- Pull side: apply table changes only when `version` is newer; ignore echo of own writes.
- Tests: Cashier reserves vs release race, stale base_version, offline reserve then server changed, repeated conflict replay (idempotent).

## Global rules (every implementation agent)
1. **Source of truth:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` (the spec). Read the sections named in your scope IN FULL before writing code. Do not redesign; implement what the spec says. Spec §19 is the file allowlist: files to create/modify are fine; files under "Leave Untouched" must NOT be edited. If you truly need a file outside the allowlist (e.g. a new per-entity handler), keep the change minimal and list it with justification in your report.
2. **Existing behaviour must not break.** Everything is additive and gated by `OFFLINE_FIRST_ENABLED`. With the flag OFF the app must behave exactly as before.
3. **Approved deviations from the spec (apply these):**
   - `FeatureFlags.offlineFirstEnabled` default is `false` (spec says true). It is flipped to true only in the final pilot step by the developer.
   - HTTP 401 during sync is NOT `FAILED_FATAL`: pause the queue as `AUTH_PAUSED`, refresh the token / ask for login, then resume. Never quarantine a valid operation because the token expired.
   - Prisma migrations must be additive only (new tables, new columns with defaults/nullable). Never drop/rename/retype existing columns or data.
4. **Git hygiene:** work on branch `offline/<stage-name>` given by the orchestrator. Commit ONLY the files you changed (`git add <paths>`, never `git add -A`/`.`) because other agents may be editing other files in the same tree at the same time. Small, descriptive commits.
5. **Quality gates before you finish:** backend: `npx prisma validate`, `npm run build`, `npm test` (and e2e if present). Frontend: `dart run build_runner build --delete-conflicting-outputs` (if Drift/codegen touched), `dart analyze`, `flutter test`. Add unit tests for every new service/state machine. Do not leave failing or skipped tests you introduced. Compare against the baseline in `docs/offline-implementation/00-baseline.md`.
6. **No guessing.** If the spec is ambiguous, contradicts the code, or something needed is missing: STOP, write the question in your report under `## Blockers`, and return. Do not invent behaviour for money, orders or sync logic.
7. **Do not** add features not in the spec (no LAN sync, no KDS, no offline refunds, no inventory deduction, no automated variance alerts, no USB audit export).
8. **Report:** write `docs/offline-implementation/<report file given below>` with: what was built, files created/modified (paths), tests added + results, commands run, deviations/blockers, and how to verify manually. Then reply with a 10-line summary.

