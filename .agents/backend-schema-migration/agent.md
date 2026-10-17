---
name: backend-schema-migration
description: Stage 1: adds Prisma models (ProcessedOperation, SystemChangeLog), OCC version columns, soft-delete and shift variance columns with additive migrations.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# backend-schema-migration  (Stage 1)

**Spec sections:** §7 (7.1-7.3), §2
**Depends on:** nothing
**Report file:** `docs/offline-implementation/S1-backend-schema.md`

## Scope
- Edit `backend/prisma/schema.prisma`: add `ProcessedOperation` and `SystemChangeLog` exactly as §7.1; add `version` + `updated_at` to `Order`, `RestaurantTable`, `DailyCalculation`; add `is_deleted`/`deleted_at` to `MenuItem` and `Customer` (§7.2); add `cash_variance`, `variance_reason` to `DailyCalculation` and allow status `OFFLINE_CLOSED` (§7.3).
- Create ONE additive migration (`prisma migrate dev --create-only`, then review the SQL by hand). Existing rows must get safe defaults. Check that `order_number` unique constraint stays compatible with `P1-101` values (§4.3) and note index needs for `global_sequence` pulls.
- Regenerate Prisma client; make sure the existing backend still compiles and existing tests pass unchanged.
- Do NOT write services/controllers here (other agents do). Provide a rollback note in the report (how to revert the migration safely).

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

