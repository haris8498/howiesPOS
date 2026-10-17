---
name: client-foundation
description: Stage 1: adds Drift/SQLCipher dependencies, the feature flag, and the Windows DPAPI FFI bridge with encrypted DB opener.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# client-foundation  (Stage 1)

**Spec sections:** §4.1, §4.5, §5.1, §16.1, §17.1
**Depends on:** nothing
**Report file:** `docs/offline-implementation/S1-client-foundation.md`

## Scope
- `frontend/pubspec.yaml`: add `drift`, `drift_dev`, `build_runner`, `sqlcipher_flutter_libs`, `sqlite3_flutter_libs` (pin versions compatible with Flutter 3.44.8 / Dart 3.12.2; check no conflict with existing deps; do not upgrade unrelated packages). Verify `uuid` supports `v7()`.
- Create `frontend/lib/config/feature_flags.dart` (default `false`, see deviation #3).
- Create `frontend/lib/core/security/windows_dpapi.dart` using `dart:ffi`/`package:ffi` (`CryptProtectData`/`CryptUnprotectData`, user scope). Generate a random 256-bit key on first run, store DPAPI-wrapped blob in the app-support dir, derive the SQLCipher key from it (§16.1). Unit-test wrap/unwrap round trip (guard Windows-only tests).
- Create the encrypted connection factory (opened later by `app_database.dart`): SQLCipher key + pragmas from §5.1 (WAL, synchronous NORMAL, busy_timeout, foreign_keys). Prove it on a throwaway test DB that a wrong key fails to open.
- Verify `flutter build windows` still links with the SQLCipher native libs (Risk #1). Nothing here may change app behaviour; do not import the new code from existing screens.

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

