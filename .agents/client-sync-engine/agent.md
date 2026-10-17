---
name: client-sync-engine
description: Stage 3: outbox push/pull worker, connectivity probing, backoff, circuit breaker, startup recovery. No UI cutover.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# client-sync-engine  (Stage 3)

**Spec sections:** §6 (6.2-6.4), §8.1, §13, §15.2, §15.3, §9 (client side), §4.4
**Depends on:** client-database, backend-sync-api (contract)
**Report file:** `docs/offline-implementation/S3-client-sync-engine.md`

## Scope
- Create `frontend/lib/core/sync/sync_background_worker.dart` and `connectivity_notifier.dart`. Probe `/api/health` (not just OS connectivity). Single worker lifecycle with explicit disposal (Risk #8).
- Push: pick due batch (<=25, dependency order), mark `IN_FLIGHT`, POST `/api/sync/push`, apply per-mutation results transactionally: `SYNCED` (stamp `server_version`, `server_updated_at`, `ackedAt`), `CONFLICT` (-> `sync_conflicts` + policy hook, resolved later by table-conflict-policy), `FAILED_RETRYABLE` (backoff formula in §6.4, unlimited retries), `FAILED_FATAL` (quarantine, does not block independent operations), 401 -> `AUTH_PAUSED`.
- Circuit breaker: 5 consecutive timeouts -> 30 s pause -> health probe.
- Startup recovery (§15.3): `IN_FLIGHT` older than 60 s -> `PENDING` (safe because the server is idempotent); WAL checkpoint cadence (Risk #3).
- Pull: poll `/api/sync/pull` with `SyncCursors`, apply changes to local tables in one transaction, only if `version` is newer (ignore stale/duplicate); initial bootstrap via `/api/sync/bootstrap` when cursor is 0. Socket.IO events from `KitchenSocketService` act only as an immediate "poke" to run a pull; polling is the fallback (§4.4).
- Expose Riverpod providers for sync status (pending count, last sync, state) for a later UI indicator. Do NOT replace any repository or touch screens.
- Tests with a fake HTTP server: ordering, retry/backoff, crash recovery, duplicate pull, stale-version ignore, poison-pill isolation, 401 pause/resume.

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

