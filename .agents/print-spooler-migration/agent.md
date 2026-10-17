---
name: print-spooler-migration
description: Stage 5: durable OfflinePrintJobs spooler; printing is decoupled from order saving with a simple Retry Print.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# print-spooler-migration  (Stage 5)

**Spec sections:** §15.4, §21 (decision 1), §5.4(3), §4 (printing refs), Risk #7, Risk #10
**Depends on:** client-database (Gate A)
**Report file:** `docs/offline-implementation/S5-print-spooler.md`

## Scope
- Modify `frontend/lib/services/receipt_printer_service.dart` to enqueue jobs in `OfflinePrintJobs` (kitchen ticket, customer receipt, shift Z-report) and print from the queue via the existing `NativeWin32Printer`. Do NOT rewrite the winspool/P-Invoke code.
- Invariant: **ORDER SAVING != PRINTING.** A printer failure (out of paper, disconnected) never fails/rolls back order, payment or outbox enqueue. Status QUEUED -> PRINTED/FAILED; show a simple non-blocking warning and a "Retry Print" action. No recovery daemons, no approval flows (decision 1).
- Prevent duplicate kitchen tickets (job id lock / PRINTED check, tier 5 of §15.2); reprints marked as copies; cancelled-item tickets only for items already printed.
- Printer status never gets synced to the server unless the spec says so.
- Tests with a fake printer: failure keeps job QUEUED/FAILED, retry prints once, app restart mid-print does not double print, order saved when the printer throws.

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

