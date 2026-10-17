---
name: backend-idempotency-orders-gateway
description: Stage 3: idempotency interceptor and ledger usage, terminal-prefixed order numbers, and standardized post-commit realtime envelope.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# backend-idempotency-orders-gateway  (Stage 3)

**Spec sections:** §8.2, §8.3(2), §9 (9.1-9.4), §15.2, §4.3
**Depends on:** backend-sync-api
**Report file:** `docs/offline-implementation/S3-backend-idempotency-orders-gateway.md`

## Scope
- Create `backend/src/sync/interceptors/idempotency.interceptor.ts` and apply it to `/api/sync/push` mutations and the existing write endpoints that must be retry-safe (orders create, payments, shift close) when `X-Idempotency-Key`/`operation_id` is present. Ledger lifecycle per §7.1/§8.2: insert `PROCESSING` (unique on operation_id) -> execute -> store `response_payload` + `COMPLETED`. Same key + same `request_hash` => return cached response; same key + different hash => 409. Handle concurrent duplicate while `PROCESSING` and crash mid-processing (stale PROCESSING recovery).
- `OrdersService.createOrder()`: accept `P<terminal>-<seq>` receipt numbers and uniqueness within terminal; keep legacy numeric behaviour for old clients (the existing 101-999 loop stays for requests without a terminal prefix).
- `kitchen.gateway.ts`: emit the `RealtimeEventEnvelope<T>` from §9.2 AFTER commit (§9.4), keep legacy event names emitted during transition (existing clients must keep working); stop emitting the duplicate only after confirming with the verifier. Events are notifications only.
- Tests: retry same key 5x creates exactly one order; concurrent duplicates; hash mismatch; event emitted only after commit (not on rollback).

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

