---
name: backend-sync-api
description: Stage 2: builds /api/sync push, pull, bootstrap, the change-log recorder and a per-entity handler registry.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# backend-sync-api  (Stage 2)

**Spec sections:** §8.1, §7.1, §9.4 (change-log hook), §10, §6.3
**Depends on:** backend-schema-migration
**Report file:** `docs/offline-implementation/S2-backend-sync-api.md`

## Scope
- Create `backend/src/sync/sync.controller.ts`, `sync-push.service.ts`, `sync-pull.service.ts`, `change-log.service.ts`; register in the sync module (keep the old `sync.service.ts` working; do not remove it).
- `POST /api/sync/push`: batch envelope exactly as §8.1. Process mutations in `dependency_order` then created order. Each mutation is its own DB transaction; per-mutation result (`SYNCED | CONFLICT | FAILED_FATAL | DUPLICATE`) with `server_version`/`server_timestamp`. One bad mutation must not poison the batch.
- Introduce a **per-entity handler registry** (`backend/src/sync/handlers/<entity>.handler.ts` + interface) so later stages (shift, table) add handlers without editing the same file. Implement the `order` (+items/payments/customer snapshot as in the spec) handler here by calling existing OrdersService logic where possible — preserve existing business rules/totals validation.
- `ChangeLogService.record(tx, entity, id, op, version, payload)` writes `system_change_logs` INSIDE the same transaction as the business write.
- `GET /api/sync/pull?cursor&device_id&limit`: ordered by `global_sequence > cursor`, returns `next_cursor` and `has_more`. `GET /api/sync/bootstrap`: gzipped catalog snapshot (§8.1.3) plus current max `global_sequence`.
- JWT-guard all endpoints, validate DTOs, add unit tests (ordering, partial failure, pull paging, bootstrap cursor).
- Leave the idempotency ledger wiring for the next agent but design the handler so it receives `operation_id`.

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

