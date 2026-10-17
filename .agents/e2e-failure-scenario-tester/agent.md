---
name: e2e-failure-scenario-tester
description: Stage 7: automated tests for the 15 failure scenarios and multi-device flow against the real implementation.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# e2e-failure-scenario-tester  (Stage 7)

**Spec sections:** §15 (15.1-15.4), §11-§14, §20
**Depends on:** Gate C and security-cleanup
**Report file:** `docs/offline-implementation/S7-e2e-tests.md`

## Scope
- Implement automated tests (backend e2e with supertest + test DB; client integration tests with Drift in-memory + fake/real local backend) for all 15 scenarios in §15.1: normal, sudden loss, very slow, return after 30 min, loss during checkout, request reaches server but response lost, two devices same table, cashier offline/owner online (and reverse), both offline, server down, crash during sync, power loss, same op retried 5 times.
- Assert invariants: exactly one server order per `operation_id`; no orphan rows after crash; outbox converges to SYNCED; pull converges owner view; WebSocket events are only pokes (kill the socket, polling still converges); printer failure never loses an order.
- Add a load smoke test: 8-hour outage worth of orders (use the sizing from the performance report) syncs in bounded time and memory.
- Do not change production code to make tests pass unless it is a real bug: list each bug found in the report and fix it minimally in the owning area (tell the orchestrator).

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

