# D-06 Fix Report: Credential Storage & Password Hashing Upgrade

**Item ID:** D-06 (Wave 1)  
**Branch:** `fix/D-06`  
**Mapped Findings:** `SEC-05` (Staff password hashing & API sanitization), `SEC-07` (Windows DPAPI credential cache encryption), `SEC-11` (Argon2id password verification, exponential lockout & expiry)  
**Date:** October 27, 2026  
**Status:** Completed & Verified  

---

## 1. What Changed

### 1.1 Backend (NestJS + Prisma + PostgreSQL)
1. **Argon2id Password Service (`PasswordService`)**:
   - Implemented `PasswordService` with `hash()`, `verify()`, `needsRehash()`, and `wrapLegacyHash()`.
   - Uses OWASP-recommended parameters: Argon2id with `m=19456 KiB` (19 MiB), `t=2`, `p=1`, overridable via environment variables (`ARGON2_MEMORY_COST`, `ARGON2_TIME_COST`, `ARGON2_PARALLELISM`).
   - Produces standard PHC strings (`$argon2id$v=19$m=19456,t=2,p=1$...`).
2. **Seamless Upgrade & Verification**:
   - `verify()` detects the hash format dynamically from its prefix:
     - `$argon2id$`: Verified with native Argon2id.
     - `argon2id-wrap$`: Verified by unwrapping and checking the inner Argon2id against the legacy candidate SHA-256 hex.
     - Legacy 64-char SHA-256 hex: Verified in constant-time using `crypto.timingSafeEqual` with dummy comparison fallback.
   - Upon successful legacy login in `AuthService.login()`, the user's password is transparently re-hashed to Argon2id and persisted to PostgreSQL, and `plain_password` is permanently set to `null`.
3. **Route All Password/PIN Paths Through `PasswordService`**:
   - Updated `UsersService` (`createUser`, `updateUser`, `updatePassword`) and `StaffService` (`createStaff`) to route all hashing through `PasswordService`.
   - Seed script (`prisma/seed.ts`) updated to use Argon2id with OWASP parameters and nullify `plain_password`.
4. **Credential Sanitization in API & Sync Payloads**:
   - Sanitized all user selectors in `UsersService` (`listUsers`, `getUserById`, `createUser`, `updateUser`), `AuthService` (`login`), and `SyncPullService` (`getBootstrapData`).
   - Verified that `password_hash`, `plain_password`, and `password` are never leaked in any REST response or sync bootstrap payload.
5. **Bulk Upgrade Migration Script**:
   - Added `scripts/wrap-legacy-hashes.ts` to wrap legacy un-slowed hashes as `argon2id-wrap$` + `argon2id(legacyHashHex)` without requiring user plaintext.
   - Idempotent and runs in dry-run mode by default; applies changes only when passed `--execute` or `--apply`.

### 1.2 Frontend (Flutter + Riverpod + Drift)
1. **Local Verifier Derivation (`LocalCredentialVerifier`)**:
   - Derives local verifiers using Argon2id via `package:cryptography` with a per-user 128-bit cryptographically secure random salt.
   - Benchmarked at ~1.06s on local hardware, meeting OWASP memory-hardness requirements.
   - Also supports PBKDF2-HMAC-SHA256 (>= 600,000 iterations per OWASP).
   - Implemented constant-time byte array comparison (`constantTimeEquals`) to eliminate side-channel timing discrepancies.
2. **Windows DPAPI Protection (`OfflineCredentialStore`)**:
   - Offline credentials are encrypted at-rest using Win32 `CryptProtectData` (user scope, `_cryptprotectUiForbidden`) via Dart FFI (`WindowsDpapi`).
   - Stores only `{userId, username, role, saltHex, verifierHex, params, lastOnlineLoginAt, isPin}`.
   - Raw SHA-256 password hashes, server password hashes, and plaintext passwords are never stored to disk.
3. **Legacy Cache Purge & Migration**:
   - On the first successful online login, `OfflineCredentialStore.purgeLegacyCache()` automatically deletes all old legacy SharedPreferences entries (`auth_pwd_hash_*`, `auth_salt_*`, `auth_custom_staff_users_v1`, `auth_deleted_staff_users_v1`).
4. **Offline Login Hardening (`OfflineAuthService`)**:
   - **Cache Expiry**: Default 14 days since last successful online login (`maxOfflineDuration`). Rejects stale logins with clear instructions to reconnect to the internet.
   - **Exponential Lockout**: After 5 consecutive failed attempts, locks terminal offline access for 30 seconds, doubling on subsequent failures (60s, 120s, capped at 24h).
   - **Admin Revoke**: `revokeUser(userId)` removes specific user offline access; `revokeAll()` purges all cached credentials.
5. **Supervisor Verification Reusable by D-03**:
   - Exposed `OfflineAuthService.verifyManagerCredential(managerIdOrUsername, credentialOrPin)`.
   - Validates that the user holds the `manager` or `owner` role, verifies PIN/password using constant-time comparison, and applies lockout protection.

---

## 2. Files Touched

### Backend
- `backend/prisma/seed.ts`
- `backend/src/auth/auth.module.ts`
- `backend/src/auth/auth.service.ts`
- `backend/src/auth/auth.service.spec.ts`
- `backend/src/auth/password.service.ts` *(new)*
- `backend/src/auth/password.service.spec.ts` *(new)*
- `backend/src/auth/legacy-upgrade.spec.ts` *(new)*
- `backend/src/auth/credential-sanitization.spec.ts` *(new)*
- `backend/src/auth/wrap-legacy-hashes.spec.ts` *(new)*
- `backend/scripts/wrap-legacy-hashes.ts` *(new)*
- `backend/src/staff/staff.module.ts`
- `backend/src/staff/staff.service.ts`
- `backend/src/staff/staff.service.spec.ts`
- `backend/src/users/users.module.ts`
- `backend/src/users/users.service.ts`
- `backend/src/users/users.service.spec.ts`

### Frontend
- `frontend/pubspec.yaml`
- `frontend/pubspec.lock`
- `frontend/lib/core/security/local_credential_verifier.dart` *(new)*
- `frontend/lib/core/security/offline_credential_store.dart` *(new)*
- `frontend/lib/core/security/offline_auth_service.dart` *(new)*
- `frontend/lib/data/auth_repository.dart`
- `frontend/test/core/security/local_credential_verifier_test.dart` *(new)*
- `frontend/test/core/security/offline_credential_store_test.dart` *(new)*
- `frontend/test/core/security/offline_auth_service_test.dart` *(new)*

### Documentation & Tracking
- `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` (appended §11.4)
- `docs/sync-audit/fixes/leftovers-backlog.md` (updated SEC-05, SEC-07, SEC-11, D-06)
- `docs/fixes/D-06-report.md` *(this document)*

---

## 3. Database & Migrations
- **No `schema.prisma` change** was made. The `StaffUser.password_hash` column is string-based and format-agnostic, supporting prefix detection (`$argon2id$`, `argon2id-wrap$`, legacy hex).
- Added `scripts/wrap-legacy-hashes.ts` for safe, idempotent, non-destructive bulk migration.
- `npx prisma validate`: Output `The schema at prisma\schema.prisma is valid 🚀`.

---

## 4. Test Results

### 4.1 Backend
- **Command:** `npm test`
- **Result:** **63 passed, 63 total suites (435 passed, 435 total tests)**
- **Key Test Suites Added:**
  - `src/auth/password.service.spec.ts` (Argon2id hashing, legacy SHA-256 timingSafeEqual, wrapped legacy hashes, needsRehash checks)
  - `src/auth/legacy-upgrade.spec.ts` (Transparent rehash from SHA-256 to Argon2id and nulling plain_password on login)
  - `src/auth/credential-sanitization.spec.ts` (Verification that password_hash/plain_password are never exposed in user API or sync bootstrap payloads)
  - `src/auth/wrap-legacy-hashes.spec.ts` (Idempotency and safety of bulk hash wrapping script)
- **Build:** `nest build` passed with exit code 0.
- **Lint:** ESLint ran clean with zero warnings on all touched auth and user service files.

### 4.2 Frontend
- **Command:** `flutter test`
- **Result:** **All 226 tests passed (0 failures)**
- **Key Test Suites Added:**
  - `test/core/security/local_credential_verifier_test.dart` (Argon2id derivation, PBKDF2 derivation, constant-time compare, random salts)
  - `test/core/security/offline_credential_store_test.dart` (DPAPI persistence, user lookups, revocation, cache wipe, legacy cache purge)
  - `test/core/security/offline_auth_service_test.dart` (Offline login verification, 5-failure exponential lockout, 14-day cache expiry, verifyManagerCredential)

---

## 5. Residual Risks
1. **Initial Online Login Prerequisite**: Users with only an un-migrated legacy client cache must log in online once to derive and cache their Argon2id verifier in the DPAPI store. Attempting offline login without an initial online login will guide the user to connect to the network.

---

## 6. Manual Verification Steps
1. **Legacy Password Upgrade**:
   - Seed database or insert user with legacy SHA-256 hash.
   - Perform POST `/api/auth/login` with user credentials.
   - Inspect database: verify `password_hash` now begins with `$argon2id$` and `plain_password` is `NULL`.
2. **Credential Sanitization**:
   - Call GET `/api/users` and GET `/api/sync/bootstrap`.
   - Verify `password_hash` and `plain_password` fields are absent from response bodies.
3. **DPAPI Offline Caching**:
   - Log in via the Flutter desktop app while online.
   - Inspect SharedPreferences: observe key `enc_dpapi_offline_credentials_v2` contains base64 DPAPI ciphertext; observe no `auth_pwd_hash_*` keys exist.
4. **Brute-Force Lockout**:
   - Disconnect network.
   - Enter invalid password 5 consecutive times.
   - Observe terminal locked status and lockout timer preventing subsequent attempts.
5. **Manager Approval Interface**:
   - Invoke `OfflineAuthService.verifyManagerCredential()` with manager credentials -> returns success.
   - Invoke with cashier credentials -> returns unauthorized role.

---

## 7. Handoff to Other Agents
- **D-03 (Offline Manager Approval)**: `OfflineAuthService.verifyManagerCredential(managerId/pin)` is exported and registered in Riverpod via `offlineAuthServiceProvider`. D-03 can inject it to validate supervisor overrides (voids, discounts, shift rollovers) offline without any modifications.
