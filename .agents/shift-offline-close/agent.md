---
name: shift-offline-close
description: Stage 5: offline shift close with cash variance and OFFLINE_CLOSED status, local+server.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# shift-offline-close  (Stage 5)

**Spec sections:** §21 (decision 2), §7.3, §8.3(3), §5.2 (local_daily_calculations), §6.3, §10.1
**Depends on:** Gate B passed
**Report file:** `docs/offline-implementation/S5-shift-offline-close.md`

## Scope
- Backend: `daily-calculation.service.ts` accepts `cash_variance`, `variance_reason`, status `OFFLINE_CLOSED`; remove the hard variance block in `closeShift()` (§8.3.3). Add `backend/src/sync/handlers/shift.handler.ts` (registry from backend-sync-api) with idempotent close + OCC version; shift (level 0) and its closure (last level) ordering per §6.3.
- Client: offline shift open/close writes `local_daily_calculations` + outbox in one transaction; record expected cash, counted cash, variance (shortage/overage). Server stores it; owner reviews in the cloud dashboard.
- NO threshold alerts, no SMS/email, no supervisor-PIN flow (decision 2). Block nothing based on variance size.
- Edge cases to test: close offline then sync; two closes for same shift (idempotent); orders created offline before close all sync before the closure operation; close attempted with unsynced dependency.

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

