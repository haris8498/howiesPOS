---
name: client-order-repository-seam
description: Stage 4: IOrderRepository seam, DriftOfflineFirstOrderRepository, UUID v7 and P<terminal>-seq numbering, flag-gated provider.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# client-order-repository-seam  (Stage 4)

**Spec sections:** §17.2, §4.2, §4.3, §11, §12, §3.3, §21.1
**Depends on:** Gate A passed (stages 1-3)
**Report file:** `docs/offline-implementation/S4-client-order-seam.md`

## Scope
- Introduce `IOrderRepository` (derive its surface from the existing `ApiOrderRepository` so the legacy class implements it unchanged). Create `frontend/lib/data/repositories/order_repository_provider.dart` and `drift_offline_first_order_repository.dart` per §17.2.
- Drift repository: save order = ONE Drift transaction writing order + items + payment + outbox rows (UUID v7 ids, correct `dependency_order`) + a print job row; the UI returns as soon as the local commit succeeds (order saving never waits on network or printer). Reads come from Drift streams (watch) so UI updates reactively.
- `order_number_generator.dart`: output UUID v7 id and `P<terminal>-<seq>` receipt number from `TerminalSequences` (101..999, daily reset, atomic increment inside the order transaction).
- `pos_repository.dart`: bind to `IOrderRepository` only; keep public behaviour/signatures so `pos_screen.dart` and other UI stay untouched.
- With the flag OFF the provider returns `ApiOrderRepository` and behaviour (including its current error handling) is identical. Add tests for both flag states.
- Pending/synced status: expose via the providers from the sync engine; if an indicator widget is needed, create it as a NEW small widget and tell the orchestrator where it should be mounted rather than editing leave-untouched screens.
- Duplicate-submit protection: UI debounce / in-memory lock + local UUID (tiers 1-3 of §15.2). Manual test script in the report: place order with network off, restart app, reconnect, verify single server order.

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

