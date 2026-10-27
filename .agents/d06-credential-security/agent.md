---
name: d06-credential-security
description: Fixes D-06 (SEC-05/07/11): Argon2id server hashing with seamless upgrade, and DPAPI-protected offline credential cache. Wave 1.
---

# Agent: D-06 Credential Storage & Password Hashing

## Mission
Remove single-round SHA-256 password hashing on the server and unprotected credential caching on the client.

## Scope (may touch)
- Backend: auth module, a new `PasswordService`, user creation/reset/change-password paths, manager PIN hashing if present, seed scripts, a one-off migration script in `scripts/`. **No `schema.prisma` change** (hash format is detected from its prefix).
- Flutter: offline login/credential cache, secure storage wrapper, auth repository, lockout logic.

## Server tasks
1. Add `argon2` and a `PasswordService` with `hash()`, `verify()`, `needsRehash()`. Argon2id, defaults m=19456 KiB, t=2, p=1 (OWASP minimum), overridable via env. Output is the standard PHC string (`$argon2id$...`).
2. Route **every** place that creates or checks a password/PIN through `PasswordService` (grep for `sha256`, `createHash`, `crypto`).
3. Login verify: `$argon2id$` prefix → `argon2.verify`; otherwise legacy SHA-256 compared with `timingSafeEqual`. On successful legacy login, **transparently rehash to Argon2id** and save.
4. Optional bulk upgrade script (`scripts/wrap-legacy-hashes.ts`, idempotent, dry-run by default): wraps each legacy hash as `argon2id-wrap$` + argon2id(legacyHashHex) so all stored hashes become slow without plaintext; `verify` must understand this prefix and unwrap-upgrade on next login.
5. Never return password hashes in any API response or sync payload (add a test that scans DTOs/serializers).

## Client tasks
1. After a successful **online** login, derive a local verifier from the typed password (Argon2id via `cryptography`, or PBKDF2-HMAC-SHA256 ≥ 600k iterations if Argon2 is too slow on target hardware; benchmark and document) with a per-user random salt. Store only `{userId, salt, verifier, params, lastOnlineLoginAt}`.
2. Protect that blob with **Windows DPAPI** (`CryptProtectData`, user scope). First check which backend the installed `flutter_secure_storage` actually uses on Windows; if it is not DPAPI-backed, implement the wrapper with `win32`/FFI. Other platforms use Keystore/Keychain through `flutter_secure_storage`.
3. Remove any cached server hash/SHA-256 value and migrate old cache entries (delete them after the first successful online login; users with only an old cache must go online once).
4. Offline login hardening: lockout with exponential backoff after 5 failures, cache expiry (default 14 days since last online login, configurable), constant-time compare, wipe cache on explicit admin revoke.
5. Expose `OfflineAuthService.verifyManagerCredential(managerId/pin)` for D-03 to reuse (offline manager approval).

## Acceptance criteria
- New passwords are Argon2id; legacy user logs in once and is upgraded; wrong password rejected on both paths.
- Cached credential file/blob is unreadable without the Windows user context; no plaintext or raw SHA-256 on disk.
- Offline login works within the expiry window and is locked out after repeated failures.

## Tests to add
PasswordService unit tests (hash/verify/rehash/legacy/wrap), login e2e for legacy upgrade, Flutter tests for verifier derivation, lockout, expiry.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-06` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-06-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-06-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
