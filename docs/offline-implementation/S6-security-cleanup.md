# Stage 6 Implementation Report: Security Hardening, DPAPI Token Storage & Pruning

> **Document Reference:** `docs/offline-implementation/S6-security-cleanup.md`  
> **Agent:** `security-cleanup (Stage 6)`  
> **Architecture Spec Reference:** §8.3(1), §16 (16.2, 16.3), §18 Phase 7, §3.3, Risk #9  
> **Branch:** `offline/main`  
> **Date:** October 18, 2026  

---

## 1. Executive Summary

Stage 6 completes the production security hardening, at-rest credential encryption, automated SQLite database retention pruning, and legacy dead-code audit for the offline-first Hungry Howie's POS platform.

Key deliverables achieved:
1. **Purged Development Auth Backdoor (`JwtAuthGuard`):** Removed the hardcoded `'Noman'` development fallback user (`4cec453b-0ce2-4f0a-a335-d014883bb0a8`) from [`backend/src/common/guards/jwt-auth.guard.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/common/guards/jwt-auth.guard.ts). Unauthenticated requests without a valid signed JWT now strictly throw `UnauthorizedException('Authentication required')` (HTTP 401). Verified that no backend tests or runtime scripts relied on the bypass; seeded DB user `'Noman'` remains for standard password login via `/api/auth/login`.
2. **DPAPI At-Rest Session & Token Encryption (`TokenStorage`):** Upgraded [`frontend/lib/core/security/token_storage.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/security/token_storage.dart) with Windows user-scope DPAPI (`CryptProtectData` / `CryptUnprotectData` via `WindowsDpapi`). All JWT tokens and user session attributes are stored encrypted at rest.
3. **Transparent First-Run Plaintext Migration:** Existing legacy plaintext keys (`auth_jwt_token`, `auth_user_id`, `auth_user_name`, `auth_user_email`, `auth_user_role`, `auth_user_is_default`) in `SharedPreferences` are transparently detected on first run, encrypted into DPAPI ciphertext (`enc_dpapi_*`), and permanently purged from disk (`prefs.remove(...)`).
4. **Resilience & `AUTH_PAUSED` Lifecycle Parity:** Preserved the fast in-memory token cache (`TokenStorage.cachedToken`) and public API signatures. When the cashier re-authenticates following an HTTP 401 `AUTH_PAUSED` trigger, `saveUserSession` updates RAM and disk immediately, allowing `SyncBackgroundWorker.resumeAuthPaused()` to seamlessly drain the outbox queue without restart.
5. **30-Day Retention Pruning Job:** Enabled automated 30-day retention pruning in [`frontend/lib/core/sync/sync_background_worker.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/sync/sync_background_worker.dart) executed on worker startup and on a 24-hour periodic cadence. Purges `local_orders` with `sync_status = 'synced'`, `sync_outbox` entries with `status = 'SYNCED'`, and `offline_print_jobs` with `status = 'PRINTED'` older than 30 days. Crucially enforces the invariant: pending, retryable, conflict, and fatal error records are **never** pruned.
6. **Legacy Code Cleanup Audit:** Audited legacy seams. Kept the fallback online path [`ApiOrderRepository`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/repositories/api_order_repository.dart) 100% intact when `FeatureFlags.offlineFirstEnabled == false`. Preserved legacy endpoints in [`backend/src/sync/sync.service.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/sync/sync.service.ts) utilized by portal management controllers.

---

## 2. Files Created & Modified

### Files Created:
| File Path | Description |
|---|---|
| [`backend/src/common/guards/jwt-auth.guard.spec.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/common/guards/jwt-auth.guard.spec.ts) | Unit test suite (4 tests) verifying `JwtAuthGuard` throws `UnauthorizedException` when unauthenticated and never returns fallback user `'Noman'`. |
| [`frontend/test/core/security/token_storage_test.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/test/core/security/token_storage_test.dart) | Unit test suite (5 tests) verifying DPAPI encryption, transparent legacy plaintext migration, plaintext key deletion, and `AUTH_PAUSED` resumption. |
| [`frontend/test/core/sync/retention_prune_job_test.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/test/core/sync/retention_prune_job_test.dart) | Unit test suite (2 tests) verifying 30-day pruning of synced orders/outbox/print jobs while strictly preserving pending, conflict, and failed rows. |
| [`docs/offline-implementation/S6-security-cleanup.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-implementation/S6-security-cleanup.md) | This Stage 6 implementation and verification report. |

### Files Modified:
| File Path | Changes Made |
|---|---|
| [`backend/src/common/guards/jwt-auth.guard.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/common/guards/jwt-auth.guard.ts) | Removed hardcoded fallback user `'Noman'` and default UUID; throws `UnauthorizedException` when JWT is missing or invalid. |
| [`backend/src/tables/tables.controller.spec.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/tables/tables.controller.spec.ts) | Added `version` and `updated_at` properties to `mockTable` fixture to match regenerated Prisma client typing. |
| [`frontend/lib/core/security/token_storage.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/security/token_storage.dart) | Wrapped session and token persistence in Windows DPAPI (`WindowsDpapi.protectString`); added transparent first-run migration from plaintext `SharedPreferences` with immediate plaintext deletion. |
| [`frontend/lib/core/sync/sync_background_worker.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/sync/sync_background_worker.dart) | Added `retentionPeriod`, `retentionPruneInterval`, startup pruning trigger, periodic pruning cadence check, and `pruneOldSyncedData()` method. |

---

## 3. Scope Implementation Details

### 3.1 Purge Development Auth Fallback (`backend/src/common/guards/jwt-auth.guard.ts`)
- **Previous Vulnerability:** Lines 10-17 returned a mock owner user payload (`username: 'Noman'`, `role: 'owner'`) whenever an unauthenticated HTTP request was received without a JWT token.
- **Hardening:**
  ```typescript
  @Injectable()
  export class JwtAuthGuard extends AuthGuard('jwt') {
    handleRequest<TUser = unknown>(err: unknown, user: TUser): TUser {
      if (err || !user) {
        throw err || new UnauthorizedException('Authentication required: valid JWT token is missing or expired');
      }
      return user;
    }
  }
  ```
- **Repo Grep Audit:**
  - Audited all usages of `'Noman'` and `4cec453b-0ce2-4f0a-a335-d014883bb0a8`.
  - The fallback UUID existed only in `jwt-auth.guard.ts`.
  - `backend/prisma/seed.ts` seeds a persistent database user with username `'Noman'` and Argon2 password hash for development/demo logins. This is valid database data and was not touched.
  - Controller unit tests (`*.controller.spec.ts`) mock auth via `.overrideGuard(JwtAuthGuard).useValue({ canActivate: () => true })` and were unaffected.
  - Public endpoints (`/api/health`) do not use `JwtAuthGuard` and continue operating without authentication.

### 3.2 DPAPI At-Rest Encryption & Migration (`frontend/lib/core/security/token_storage.dart`)
- **Encryption Scheme:**
  - On Windows (`Platform.isWindows`), calls `WindowsDpapi.protectString(value)` which invokes Win32 `CryptProtectData` in `Crypt32.dll`.
  - Stored values in `SharedPreferences` use keys prefixed with `enc_dpapi_` (`enc_dpapi_jwt_token`, `enc_dpapi_user_id`, etc.) containing base64 DPAPI ciphertext.
  - In-memory cache `_cachedToken` is retained so synchronous API calls and outbox sync pipelines avoid repetitive FFI overhead.
- **Transparent Migration Algorithm:**
  1. On first run after upgrading, `getToken()` or `getUserSession()` checks for the existence of legacy plaintext keys (`auth_jwt_token`, `auth_user_id`, etc.).
  2. If found, reads the plaintext strings and encrypts each through `WindowsDpapi.protectString()`.
  3. Writes the resulting ciphertext blobs to `enc_dpapi_*` keys in `SharedPreferences`.
  4. Calls `_deleteLegacyPlaintextKeys(prefs)` to immediately delete the plaintext keys from disk.
  5. Subsequent invocations read directly from `enc_dpapi_*` and decrypt via `WindowsDpapi.unprotectString()`.
- **`AUTH_PAUSED` Lifecycle Resumption:**
  - When the sync worker encounters HTTP 401, mutations transition to `AUTH_PAUSED` status.
  - When the cashier logs back in, `AuthApiService.login()` calls `TokenStorage.saveUserSession(...)`.
  - `TokenStorage` updates `_cachedToken` synchronously in RAM and writes encrypted tokens to disk.
  - `SyncBackgroundWorker.resumeAuthPaused()` retrieves the fresh token via `await TokenStorage.getToken()` and flushes the queued mutations to `/api/sync/push` with HTTP 200 OK.

### 3.3 30-Day Retention Pruning Job (`frontend/lib/core/sync/sync_background_worker.dart`)
- **Pruning Invariants (Directive Q9.2 & Spec §3.3):**
  - **Orders:** `local_orders` where `sync_status = 'synced'` and `createdAt <= (now - 30 days)` are deleted. Foreign key cascading automatically purges associated `local_order_items` and `local_order_payments`.
  - **Outbox:** `sync_outbox` entries where `status = 'SYNCED'` and `createdAt <= (now - 30 days)` are deleted.
  - **Print Jobs:** `offline_print_jobs` where `status = 'PRINTED'` and `createdAt <= (now - 30 days)` are deleted.
  - **Protected Entities (NEVER Pruned):** Any row with `sync_status = 'pending_insert'`, `'pending_update'`, outbox status `'PENDING'`, `'IN_FLIGHT'`, `'AUTH_PAUSED'`, `'FAILED_RETRYABLE'`, `'FAILED_FATAL'`, `'CONFLICT'`, or print jobs in `'QUEUED'` / `'FAILED'` state are strictly protected regardless of age.
- **Execution Schedule:**
  - **Startup:** Invoked inside `SyncBackgroundWorker.start()`.
  - **Cadence:** Checked every `retentionPruneInterval` (24 hours) during periodic ticks in `_onPeriodicTick()`.

### 3.4 Legacy Code Cleanup Audit
- **In-Memory Volatile Cache:** `ApiOrderRepository` previously held an in-memory list `_localCache` which risked data loss on crash. When `FeatureFlags.offlineFirstEnabled == true`, the seam provider resolves to `DriftOfflineFirstOrderRepository`, which commits transactions to SQLite WAL and `sync_outbox`.
- **Legacy Online Seam Preservation:** `ApiOrderRepository` is left 100% intact when `FeatureFlags.offlineFirstEnabled == false`, guaranteeing zero regression if the feature flag is rolled back.
- **`sync.service.ts` Preservation:** Audited backend references to `backend/src/sync/sync.service.ts`. The legacy controller endpoints (`/api/sync/overview`, `/api/sync/order/:id`, `/api/sync/batch`, `/api/sync/log`, `/api/sync/logs`) directly reference `SyncService`. Therefore, `sync.service.ts` is verified active and preserved intact.

---

## 4. Verification & Quality Gates Results

### 4.1 Backend Verification:
1. **Prisma Schema Validation:**
   - Command: `npx prisma validate`
   - **Result:** Code 0 (Success). `The schema at prisma\schema.prisma is valid 🚀`.
2. **Application Build:**
   - Command: `npm run build` (`nest build`)
   - **Result:** Code 0 (Success). TypeScript compilation completed with zero errors.
3. **Unit & Service Tests:**
   - Command: `npm test` (`jest`)
   - **Result:** 50 passed, 4 failed (362 passed, 4 failed).
   - **New Guard Tests:** `src/common/guards/jwt-auth.guard.spec.ts` passed (4/4 tests passed).
   - **Baseline Parity:** The 4 failed tests exactly match the pre-existing failures recorded in [`00-baseline.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-implementation/00-baseline.md):
     1. `src/inventory/inventory.service.spec.ts` (duplicate SKU code conflict).
     2. `src/reports/reports.service.spec.ts` (executive summary metrics).
     3. `src/permissions/permissions.service.spec.ts` (role permission grant check).
     4. `src/users/users.service.spec.ts` (staffUser.update mock in deleteUser).
   - Zero test regressions introduced.

### 4.2 Frontend Verification:
1. **Static Analysis:**
   - Command: `dart analyze lib test`
   - **Result:** Code 0 (Success). **0 errors, 0 warnings**, 34 pre-existing info hints.
2. **Unit & Widget Tests:**
   - Command: `flutter test`
   - **Result:** Code 0 (Success). **99 of 99 tests passed**.
   - **New Tests:**
     - `test/core/security/token_storage_test.dart` (5 tests passed).
     - `test/core/sync/retention_prune_job_test.dart` (2 tests passed).

---

## 5. Manual Verification Test Script

### Scenario: DPAPI Session Encryption, Plaintext Migration & Retention Pruning

#### Prerequisites:
1. Hungry Howie's POS running on Windows Desktop with DPAPI support.
2. Local SQLite database initialized at `%LOCALAPPDATA%\HungryHowies\howies_pos.db`.

#### Step-by-Step Verification:
1. **Simulate Legacy Plaintext Session:**
   - Write plaintext strings to Windows registry / app preferences:
     `auth_jwt_token = "legacy_test_token_12345"`
     `auth_user_name = "Noman"`
     `auth_user_role = "owner"`
2. **Launch Application:**
   - Launch POS desktop application.
   - Observe automatic migration on startup.
3. **Inspect Stored SharedPreferences File:**
   - Open SharedPreferences XML/JSON file.
   - **Verify:** Keys `auth_jwt_token`, `auth_user_name`, `auth_user_role` no longer exist in plaintext.
   - **Verify:** Keys `enc_dpapi_jwt_token`, `enc_dpapi_user_name`, etc., exist and contain base64 DPAPI ciphertext.
4. **Verify Session Restoration:**
   - Check POS screen: Cashier profile shows user "Noman" with role "Owner".
   - REST API requests include `Authorization: Bearer legacy_test_token_12345` without user disruption.
5. **Simulate 35-Day-Old Database Rows:**
   - In SQLite DB, insert an order with `sync_status = 'synced'` and `createdAt = datetime('now', '-35 days')`.
   - Insert an order with `sync_status = 'pending_insert'` and `createdAt = datetime('now', '-35 days')`.
6. **Trigger Retention Pruning:**
   - Trigger worker startup or call `worker.pruneOldSyncedData()`.
   - **Verify:** 35-day-old `synced` order is deleted.
   - **Verify:** 35-day-old `pending_insert` order remains safely stored.
