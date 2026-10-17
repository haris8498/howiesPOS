---
name: security-cleanup
description: Stage 6: removes dev auth fallback, encrypts stored sessions via DPAPI, enables 30-day pruning, removes legacy dead code safely.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# security-cleanup  (Stage 6)

**Spec sections:** §8.3(1), §16 (16.2, 16.3), §18 Phase 7, §3.3, Risks 9
**Depends on:** Gate C passed
**Report file:** `docs/offline-implementation/S6-security-cleanup.md`

## Scope
- `backend/src/common/guards/jwt-auth.guard.ts`: remove the development fallback user `Noman`; throw `UnauthorizedException` without a valid JWT. First grep the whole repo (frontend, tests, scripts, seed) for anything relying on it and report/fix those callers.
- `frontend/lib/core/security/token_storage.dart`: encrypt stored session/tokens with DPAPI (migrate existing plaintext SharedPreferences values transparently on first run, then delete the plaintext). Keep login/refresh behaviour identical, including how the sync engine resumes from `AUTH_PAUSED`.
- Enable the 30-day retention pruning job for SYNCED orders/outbox/print jobs (never prune pending/conflict/failed rows).
- Legacy cleanup: only remove code proven dead (the in-memory `_localCache` fallback when the flag is ON path). Leave the legacy `ApiOrderRepository` path intact for flag OFF. Do not delete the old `sync.service.ts` unless nothing references it and the verifier agrees.

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

