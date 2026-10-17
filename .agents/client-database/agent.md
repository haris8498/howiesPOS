---
name: client-database
description: Stage 2: creates the Drift app database, all local tables, DAOs and migrations on top of the encrypted connection.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# client-database  (Stage 2)

**Spec sections:** §5 (5.2, 5.3, 5.4), §6.1, §3.3, §4.2
**Depends on:** client-foundation
**Report file:** `docs/offline-implementation/S2-client-database.md`

## Scope
- Create `frontend/lib/core/database/app_database.dart` (uses the encrypted opener from client-foundation), plus `tables/local_orders_tables.dart`, `tables/sync_outbox_table.dart`, `tables/terminal_sequences_table.dart`, `tables/offline_print_jobs_table.dart`, and tables for the catalog/reference data (§5.3), `SyncCursors`, `sync_conflicts`, `local_daily_calculations` (needed by shifts, §21.2). Follow §5.2 column lists exactly (sync_status, server_version, server_updated_at, UUID v7 ids).
- `SyncOutbox` exactly as §6.1 (add an `AUTH_PAUSED` status value; see deviation #3).
- DAOs: orders (atomic "save order + items + payment + outbox row + print job placeholder" in one Drift transaction), outbox queries (`ORDER BY dependency_order, created_at LIMIT 25`, only `PENDING`/due `FAILED_RETRYABLE`), catalog upsert, cursor get/set, retention pruning query (30-day synced) as a method only.
- Schema version 1 + migration test scaffold. Generated code via build_runner.
- Tests with an in-memory/NativeDatabase: atomicity (rollback leaves zero rows), unique `operation_id`, FK behaviour, outbox ordering.
- Do not wire the database into the app yet; no UI or provider changes.

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

