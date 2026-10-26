# 08 - Security, Authentication, and Data Protection Audit

> **Audit Role:** Security and Auth Auditor (`.agents/security-auth-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop Client + NestJS / Prisma / PostgreSQL Backend)  
> **Reference Specification:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`  
> **Status:** Completed Security Audit  
> **Date:** October 26, 2026  
> **Finding Prefix:** `SEC`  

---

## Executive Summary

This audit evaluates the authentication, authorization, token lifecycle, local data-at-rest protection, device identity, tamper resistance, and tenant isolation of Hungry Howie's POS under extended offline operations and hostile sync conditions.

While the architecture specification (`99-FINAL-ARCHITECTURE.md`) mandated transparent SQLCipher page encryption via Windows DPAPI, zero plaintext credential backdoors, and server-authoritative reconciliation, **critical security vulnerabilities and architectural gaps exist in the implemented code**:

1. **Blind Server Financial Acceptance (SEC-01):** When ingesting offline orders via `POST /api/sync/push`, `OrdersService.createOrderInTx` blindly accepts `unit_price`, `subtotal`, `grand_total`, `discount_amount`, and payments directly from the client JSON envelope without recomputing against the catalog or enforcing discount permissions. An attacker or cashier editing local SQLite tables can order items for $0.01 or apply 100% unauthorized discounts.
2. **Deactivated Staff Bypass (SEC-02):** Backend `JwtStrategy.validate()` looks up the staff user by ID but **fails to check `is_active`**. A fired and deactivated cashier's active JWT remains 100% valid on all protected cloud endpoints until expiration. Furthermore, offline deactivations never replicate to clients because `users.service.ts` updates Prisma without creating change logs.
3. **Hardcoded Credential Backdoor in Re-Authentication (SEC-03):** When a JWT expires, `SyncBackgroundWorker.trySilentReauth()` attempts to guess the user's password using the hardcoded pattern `'${username}123'` or `'Noman123'`, transmitting plaintext credentials over HTTP.
4. **Indefinite Queue Lockup (SEC-04):** When silent re-auth fails, mutations are marked `AUTH_PAUSED`. `outboxDao.getPushBatch` permanently excludes `AUTH_PAUSED` items, and `AuthNotifier.login()` never triggers `resumeAuthPaused()`, stranding unsynced orders in SQLite indefinitely.
5. **Plaintext Password Storage (SEC-05 & SEC-07):** The backend stores and returns plaintext passwords in `staff_users.plain_password` in PostgreSQL and REST responses. Concurrently, the Flutter client's `InMemoryAuthRepository` writes custom staff usernames, salts, and password hashes into unencrypted `SharedPreferences` as pipe-delimited plaintext strings.
6. **Zero Device Identity (SEC-08):** There is no device registration table, device authentication credential, revocation list, or remote wipe capability. `device_id` is an unverified string defaulting to `'POS-P1'`.

---

## Threat Modeling Table

| Threat | Entry Point | Current Mitigation | Vulnerability / Gap | Recommended Fix |
|---|---|---|---|---|
| **Price & Discount Tampering** | Client local SQLite (`local_orders`, `sync_outbox`) or crafted `POST /api/sync/push` | Client-side UI discount validations | Backend `OrderHandler` & `OrdersService.createOrderInTx` accept client totals without verification | Recompute subtotal, taxes, and grand totals on server; validate item prices against catalog; enforce server-side discount RBAC |
| **Fired Cashier Action Execution** | Reconnection of tablet with pending orders created by deactivated cashier | `AuthService.login` checks `is_active === false` | `JwtStrategy.validate` ignores `is_active`; unexpired tokens continue working; offline tablet never receives deactivation event | Check `is_active` in `JwtStrategy`; record user deactivations in `system_change_logs`; flag offline orders from deactivated users for supervisory review |
| **Silent Re-Auth Credential Harvest** | Network sniffing / MITM or memory inspection during `trySilentReauth()` | None | Client constructs password as `'${username}123'` or `'Noman123'` and issues HTTP POST | Replace password guessing with standard OAuth2 / JWT refresh token exchange stored in DPAPI |
| **Outbox Queue Stranding** | HTTP 401 response from sync push endpoint | Outbox marked `AUTH_PAUSED` | `outboxDao.getPushBatch` permanently ignores `AUTH_PAUSED`; UI login never resumes paused entries | Invoke `syncBackgroundWorker.resumeAuthPaused()` upon successful UI login; add auto-retry for auth errors |
| **Plaintext Credential Disclosure (Backend)** | Direct DB access, SQL injection, or `GET /api/users` | Passwords hashed with Argon2 in `password_hash` | Dual-stored in plaintext in `plain_password` column and returned in user DTOs | Drop `plain_password` column from Prisma schema and purge from all service DTOs |
| **Plaintext Credential Disclosure (Client)** | Local Windows user filesystem inspection (`%APPDATA%`) | DPAPI token storage used for session JWTs | `InMemoryAuthRepository` writes staff credentials in plaintext to `SharedPreferences` | Migrate staff fallback repository to encrypted SQLite or DPAPI storage |
| **Sync Denial of Service (DoS)** | `POST /api/sync/push` payload | Express 10MB body limit | `SyncPushDto` has `payload: any` and no `@ArrayMaxSize()` on mutations array; O(N^2) dependency graph sort | Impose `@ArrayMaxSize(50)`, strictly validate payload schemas with `@ValidateNested`, limit topological sort depth |
| **Stolen Terminal Data Extraction** | Physical theft of tablet / laptop | Windows user-scope DPAPI encryption on `db.key` | User-scope DPAPI decryptable by any process running under the POS Windows login; non-Windows platforms 100% unencrypted | Enforce machine-scope DPAPI with secondary application entropy or TPM-backed enclave; encrypt across all target OSs |
| **Cross-Tenant Data Snooping** | `GET /api/sync/pull`, `GET /api/sync/bootstrap`, WebSockets | JWT authentication | Single flat schema; no `store_id` filter in pull queries or WebSocket rooms | Scope change log and bootstrap queries by `store_id`; partition WebSocket channels by authenticated store |
| **Attribution Repudiation** | Account sharing or terminal handoff | Shift opening/closing tracked | `Order` and `LocalOrders` tables lack author / cashier foreign keys; push uses whoever is currently logged in | Add immutable `cashier_id` and cryptographic signature to each `LocalOrder` and mutation envelope |

---

## Technical Audit Checklist

### 1. Offline Login
- **Implementation:** [`frontend/lib/data/auth_repository.dart:471-531`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L471-L531), [`frontend/lib/data/repositories/in_memory_auth_repository.dart:172-245`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/in_memory_auth_repository.dart#L172-L245), [`frontend/lib/core/security/password_hasher.dart:10-24`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/password_hasher.dart#L10-L24).
- **Offline Authentication Mechanism:** When the network is unreachable, `AuthNotifier.login()` catches network exceptions and invokes `_loginFallback()`. It delegates to `InMemoryAuthRepository.verifyUserCredentials()`, which matches against credentials cached in Windows `SharedPreferences`.
- **Hash Strength & Salt:** `PasswordHasher.hashPassword()` executes a **single round of SHA-256** with a static hardcoded pepper (`'hungry_howies_pos_pepper_2026'`). There is zero work factor (no PBKDF2 iterations, no Argon2, no bcrypt).
- **Plaintext Bypass:** `InMemoryAuthRepository:239-242` checks `if (cred.plainPassword != null && cred.plainPassword == input)` before verifying hashes.
- **Brute-Force & Lockout:** In [`frontend/lib/features/auth/login_screen.dart:30-52`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/auth/login_screen.dart#L30-L52), there is **zero attempt counting, zero progressive delay, and zero lockout mechanism**. An attacker with access to the keyboard can execute dictionary attacks at processor speed.
- **Synthetic Token:** Upon offline login, line 505 generates a fake session token: `'local_offline_token_${cred.username}'`.

### 2. Token Lifecycle
- **Token Duration:** Access tokens are issued with a 24-hour expiration (`expiresIn: '1d'`) in [`backend/src/auth/auth.module.ts:23`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.module.ts#L23).
- **Refresh Endpoint:** **NOT FOUND**. The backend provides no `/api/auth/refresh` endpoint in [`backend/src/auth/auth.controller.ts`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.controller.ts).
- **Offline Expiry Behavior:** If a device is offline for > 24 hours, its token expires. On reconnect, the first push returns HTTP 401 (`jwt-auth.guard.ts:8`).
- **Silent Re-Authentication:** Caught by `SyncBackgroundWorker._handleAuthPaused()` in [`sync_background_worker.dart:752`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L752), which calls `trySilentReauth()` in [`sync_background_worker.dart:1342`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1342). This function attempts to log in using the username and a guessed password (`username == 'noman' ? 'Noman123' : '${username}123'`). If the user changed their password, silent reauth fails.
- **Queue Stranding on 401:** If re-auth fails, mutations are marked `AUTH_PAUSED`. `outboxDao.getPushBatch()` exclusively queries `PENDING` and `FAILED_RETRYABLE`. The worker never picks them up again.
- **Whole-Batch Drop on 4xx/403:** In [`sync_background_worker.dart:478-482`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L478-L482), any HTTP 4xx response (including 403 Forbidden) triggers `_handleFatalBatch()`, marking all 25 mutations in the batch as `FAILED_FATAL` and moving them to `sync_conflicts`. They are never synced.

### 3. Role and Permission Drift
- **Backend Role Check in JWT Strategy:** In [`backend/src/auth/strategies/jwt.strategy.ts:26-38`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L38), `validate(payload)` queries `prisma.staffUser.findUnique({ where: { id: payload.sub } })`. It validates user existence, **but does not check `is_active`**. If an employee is marked `is_active = false` (or deleted via `users.service.ts:326`), their unexpired JWT continues to pass authentication.
- **Sync Controller Authorization:** `SyncController` in [`backend/src/sync/sync.controller.ts:29-46`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync.controller.ts#L29-L46) applies `@UseGuards(JwtAuthGuard)` but **no `RolesGuard`**. Any user role (cashier, rider, waiter) can trigger sync pushes and delta pulls.
- **Mutation Creator Validation:** In [`backend/src/sync/sync-push.service.ts:128-156`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L128-L156), the sync push service does not pass the authenticated user into entity handlers. Mutations are executed without verifying who authored the mutation offline.
- **Pull Stream Blindness:** User deactivations and permission changes executed in `users.service.ts` do not call `ChangeLogService.record()`. An offline client will never receive notification that a user has been deactivated upon polling `GET /api/sync/pull`.

### 4. Device Identity
- **Client Configuration:** In [`frontend/lib/core/sync/sync_background_worker.dart:173`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L173) and [`frontend/lib/data/table_repository.dart:222`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L222), `deviceId` is hardcoded to `'POS-P1'`.
- **Device Registration & Credentials:** **NOT FOUND**. There is no device registration schema, no per-device X.509 certificate, and no device secret key.
- **Device Revocation & Wipe:** **NOT FOUND**. If a tablet is stolen, administrators have no mechanism to revoke the device ID or remotely wipe the local SQLite database.

### 5. Same-Account Concurrency & Attribution
- **Order Attribution Schema:** In [`frontend/lib/core/database/tables/local_orders_tables.dart:6-34`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/local_orders_tables.dart#L6-L34) and [`backend/prisma/schema.prisma:280-310`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L280-L310), the `Order` table contains **no `cashier_id`, `user_id`, or `created_by` field**.
- **Shift Concurrency:** Orders reference `shift_id`, but multiple cashiers sharing an account or POS terminal cannot be distinguished.
- **Repudiation Risk:** If unauthorized discounts or fraudulent transactions are entered offline, the system cannot attribute them to a specific person.

### 6. Local Data at Rest
- **SQLite Page Encryption (Windows):** Implemented in [`frontend/lib/core/database/encrypted_connection.dart:44-55`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/encrypted_connection.dart#L44-L55) using `PRAGMA key = "x'<hex>'";` with `cipher_page_size = 4096` and `kdf_iter = 64000`.
- **Master Key Protection:** In [`frontend/lib/core/security/windows_dpapi.dart:254-289`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/windows_dpapi.dart#L254-L289), the master key is protected with Windows user-scope DPAPI (`CryptProtectData`) and stored at `%LOCALAPPDATA%\HungryHowies\db.key`.
- **Session Token Encryption:** [`frontend/lib/core/security/token_storage.dart:42-52`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/token_storage.dart#L42-L52) wraps JWTs in DPAPI before storing them in `SharedPreferences`.
- **Non-Windows Vulnerability:** On non-Windows platforms (Android/iOS/Linux), `WindowsDpapi` throws `UnsupportedError` ([`windows_dpapi.dart:95-97`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/windows_dpapi.dart#L95-L97)). `encrypted_connection.dart:97-100` falls back to `keyHex = null`, opening SQLite in **100% UNENCRYPTED PLAINTEXT**.
- **Plaintext Credentials in SharedPreferences:** In [`frontend/lib/data/repositories/in_memory_auth_repository.dart:163`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/in_memory_auth_repository.dart#L163), cached staff users, salts, and password hashes are saved in unencrypted `SharedPreferences` keys (`auth_custom_staff_users_v1`, `auth_pwd_hash_*`, `auth_salt_*`).
- **Cached Sensitive Data:** Local SQLite tables store customer full names, phone numbers, and delivery addresses in `local_orders`, card payment metadata (`cardLastFour`, `transactionReference`, `bankName`) in `local_order_payments`, and raw customer receipts in `offline_print_jobs`.

### 7. Tamper Resistance
- **Server Validation of Prices:** In [`backend/src/orders/orders.service.ts:211-224`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L211-L224), `createOrderInTx` verifies that `menu_item_id` exists in the database, but **never checks whether `item.unit_price` matches `menuItem.base_price`**.
- **Server Validation of Totals:** In [`orders.service.ts:230`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L230):
  `const subtotal = dto.subtotal !== undefined ? this.round(dto.subtotal) : calculatedSubtotal;`
  And line 258:
  `const grandTotal = dto.grand_total !== undefined ? this.round(dto.grand_total) : ...;`
  If client sends manipulated `subtotal` or `grand_total`, the server writes it directly to PostgreSQL.
- **Discount Authorization:** The server enforces no role or percentage ceiling on `discount_amount` or `discount_percentage` ([`orders.service.ts:244-256`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L244-L256)).
- **Payment Verification:** Client-provided payments are inserted directly via `tx.orderPayment.createMany()` ([`orders.service.ts:468`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L468)) without cross-checking against gateway authorizations.

### 8. Sync Endpoint Abuse
- **Missing Payload Schema Validation:** In [`backend/src/sync/dto/sync-push.dto.ts:47-48`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L47-L48), `payload` is declared as:
  ```typescript
  @IsNotEmpty({ message: 'payload is required' })
  payload!: any;
  ```
  Because `payload` is typed as `any`, NestJS's global `ValidationPipe` (`whitelist: true, forbidNonWhitelisted: true` in [`main.ts:40-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L40-L41)) performs zero property filtering or schema validation on payload data.
- **Unbounded Push Batch DoS:** `SyncPushDto.mutations` (`sync-push.dto.ts:60-63`) has no `@ArrayMaxSize()` decorator. Express accepts payloads up to 10MB ([`main.ts:31`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L31)). An attacker can transmit thousands of mutations in a single batch, forcing O(N^2) topological sorting in `SyncPushService.pushMutations` ([`sync-push.service.ts:44-51`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L44-L51)), saturating Prisma connection pools and exhausting server CPU.
- **Replay Attacks:** The `IdempotencyInterceptor` (`idempotency.interceptor.ts:77-80`) indexes on `X-Idempotency-Key` or `operation_id`. If an attacker submits an old payload with a freshly generated UUID v7 `operation_id`, the idempotency check passes and the duplicate transaction is processed.

### 9. Tenant and Branch Isolation
- **Single-Tenant Database Topology:** `StoreSetting` is a singleton table in [`backend/prisma/schema.prisma:11-22`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L11-L22). Database models (`Order`, `OrderItem`, `DailyCalculation`, `RestaurantTable`) contain **no `store_id`, `branch_id`, or `tenant_id` column**.
- **Pull Stream Leakage:** `SyncPullService.pullChanges()` in [`backend/src/sync/sync-pull.service.ts:48-52`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L48-L52) queries `systemChangeLog.findMany()` with no store scoping. Any client can pull all operational events across the deployment.
- **Bootstrap Dump:** `SyncPullService.getBootstrapData()` ([`sync-pull.service.ts:103-125`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L103-L125)) exports the entire database without tenant isolation.
- **WebSocket Room Bleed:** In [`backend/src/realtime/realtime.gateway.ts:110-112`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/realtime/realtime.gateway.ts#L110-L112), every connected socket joins global `'pos'` and `'kitchen'` rooms regardless of store ID. Furthermore, lines 161-166 allow any client to call `join_store` with any arbitrary `storeId` with zero permission checks.

### 10. Logging
- **Database PII Storage:** In [`backend/prisma/schema.prisma:640`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L640), `data_sync_logs.payload_json` stores complete raw JSON payloads including customer names, phone numbers, delivery addresses, and card last four digits.
- **Client Conflict Ledger:** Drift's `sync_conflicts` table (`sync_conflicts_table.dart:18-20`) stores unredacted mutation payloads and raw backend exception strings.
- **Stack Trace Exposure:** `SyncBackgroundWorker._handleFatalBatch()` ([`sync_background_worker.dart:480`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L480)) captures HTTP error bodies verbatim and writes them into SQLite `sync_outbox.last_error`.

### 11. Logout Behavior
- **Local Database Persistence:** `AuthNotifier.logout()` in [`frontend/lib/data/auth_repository.dart:533-546`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L533-L546) only clears `TokenStorage.clearSession()`. It **does not clear Drift tables** (`local_orders`, `local_order_items`, `local_daily_calculations`, `sync_outbox`).
- **Missing Backend Endpoint:** Line 535 calls `_authApiService.logout()`. The backend has no `POST /api/auth/logout` endpoint in [`backend/src/auth/auth.controller.ts`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.controller.ts), throwing an unhandled 404 and skipping graceful server session termination.
- **Unsynced Outbox Warning:** In [`frontend/lib/shared/widgets/navigation_sidebar.dart:1011-1076`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/shared/widgets/navigation_sidebar.dart#L1011-L1076), `_confirmLogout()` contains no checks for pending unsynced outbox entries or active shifts. A cashier can log out with 50 unsynced orders, leaving them in the local database.

---

## Step-by-Step Scenario Traces

### Scenario 1: Cashier fired and deactivated while tablet offline with 20 pending orders
1. **Cloud Deactivation:** Store manager logs into cloud management portal and deletes cashier account. `UsersService.deleteUser()` in [`backend/src/users/users.service.ts:323-328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/users/users.service.ts#L323-L328) executes `tx.staffUser.update({ data: { is_active: false } })`.
2. **Missing Delta Log:** `deleteUser()` does not call `ChangeLogService.record()`. No entry is written to `system_change_logs`.
3. **Offline Sales:** Cashier tablet remains offline. Offline sales proceed normally; cashier completes 20 orders, which are saved to SQLite `local_orders` and `sync_outbox`.
4. **Reconnection:** Tablet reconnects to network. `SyncBackgroundWorker.triggerPush()` queries 20 outbox rows and prepares batch.
5. **Token Verification:** Batch is sent via `POST /api/sync/push` with the cashier's existing JWT. In [`backend/src/auth/strategies/jwt.strategy.ts:26-38`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L38), `JwtStrategy.validate()` queries `staffUser.findUnique({ where: { id: payload.sub } })`. It verifies the record exists, **but does not check `user.is_active`**.
6. **Execution:** The request succeeds. `SyncPushService` processes all 20 orders via `OrderHandler.handleInsert()`.
7. **Outcome:** All 20 orders created by the fired cashier are permanently committed to PostgreSQL and broadcast to kitchen displays without warning or supervisor verification.

### Scenario 2: Tablet stolen; attacker keeps it offline and reads local DB
1. **Physical Access:** Attacker obtains physical possession of POS tablet and keeps it offline.
2. **Windows Key Extraction:** The attacker powers on the machine and logs into Windows (or accesses the terminal in auto-login kiosk mode). The attacker launches PowerShell and executes a script invoking `CryptUnprotectData` via FFI on `%LOCALAPPDATA%\HungryHowies\db.key` ([`windows_dpapi.dart:258-264`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/windows_dpapi.dart#L258-L264)). Because DPAPI user-scope keys can be decrypted by any process in the same user session, the 32-byte AES-256 master key is exposed in plaintext.
3. **Database Decryption:** Attacker opens `%LOCALAPPDATA%\HungryHowies\hungry_howies_pos.db` in SQLite CLI using `PRAGMA key = "x'<extracted_hex>'";`.
4. **Data Harvest:** Attacker extracts:
   - Full customer directory: names, phone numbers, and addresses from `local_orders`.
   - Payment logs: card last four digits, transaction references, and tendered amounts from `local_order_payments`.
   - Cash register balances: opening float, cash counts, and variances from `local_daily_calculations`.
   - Unencrypted credentials: staff usernames, salts, and SHA-256 hashes from Windows `SharedPreferences` (`auth_custom_staff_users_v1`).
5. **Outcome:** Total confidentiality breach of customer PII, staff credentials, and financial metrics.

### Scenario 3: Malicious client replays old outbox payload with altered totals
1. **Payload Modification:** Rogue client captures an outbox payload for a $120.00 order. Attacker modifies the JSON:
   - `subtotal`: changed to `1.00`.
   - `grand_total`: changed to `1.00`.
   - `items[0].unit_price`: changed to `0.10`.
   - `payments[0].amount`: changed to `1.00`.
   - `operation_id`: generated as a new UUID v7.
2. **Push Submission:** Attacker submits `POST /api/sync/push` with the tampered payload.
3. **Idempotency Bypass:** In [`idempotency.interceptor.ts:100`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L100), the server checks `processed_operations` for the new `operation_id`. Since it is unique, the interceptor passes through.
4. **Order Handling:** In [`backend/src/sync/handlers/order.handler.ts:94-116`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L94-L116), `handleInsert()` passes the client's `subtotal`, `grand_total`, and `unit_price` directly into `CreateOrderDto`.
5. **Server Persistence:** `OrdersService.createOrderInTx()` ([`orders.service.ts:230, 258`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L230)) accepts `dto.subtotal` and `dto.grand_total` verbatim without recalculating. Line 468 inserts a payment of $1.00.
6. **Kitchen Notification:** `KitchenGateway.emitOrderCreated()` sends the order to kitchen screens.
7. **Outcome:** Kitchen prepares a $120 meal recorded in the sales ledger as $1.00, causing immediate financial loss.

### Scenario 4: Staff A logs out, staff B logs in on same offline device; identity of pending items
1. **Pending Mutations:** Staff A operates offline and completes 10 orders. The orders are saved to `local_orders` and queued in `sync_outbox` with `shift_id` from Staff A's shift.
2. **Logout:** Staff A taps "Log Out" in `navigation_sidebar.dart:1070`. `AuthNotifier.logout()` clears `TokenStorage.clearSession()`. The SQLite database and `sync_outbox` entries remain untouched.
3. **Login:** Staff B logs in on the same offline tablet. `_loginFallback()` writes Staff B's user details into `TokenStorage`.
4. **Reconnection & Push:** Tablet reconnects to the network. `SyncBackgroundWorker.triggerPush()` wakes up and builds HTTP request headers using [`sync_background_worker.dart:1381`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1381), retrieving Staff B's credentials from `TokenStorage`.
5. **Server Ingestion:** `POST /api/sync/push` is submitted with Staff B's JWT token.
6. **Ledger Discrepancy:**
   - In PostgreSQL `orders`, the 10 orders are linked to Staff A's `shift_id`.
   - In `processed_operations` and HTTP access logs, the push mutation batch is authenticated and stamped under Staff B's user ID.
   - If cash shortages or discrepancies occur on those orders, audit logs attribute the sync submission to Staff B while the register shift belongs to Staff A.
7. **Outcome:** Severed audit trail; inability to hold staff legally accountable for cash variances.

---

## Detailed Findings

### SEC-01: Client-Supplied Financial Totals and Pricing Blindly Trusted by Server
- Severity: Critical
- Evidence: [`backend/src/sync/handlers/order.handler.ts:94-167`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L94-L167), [`backend/src/orders/orders.service.ts:227-261`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L227-L261)
- Failure sequence:
  1. Cashier terminal operates offline or attacker tampers with outbox queue.
  2. Client sets `item.unit_price = 0.01`, `subtotal = 0.01`, and `grand_total = 0.01`.
  3. `OrderHandler.handleInsert()` maps client fields directly into `CreateOrderDto`.
  4. `OrdersService.createOrderInTx()` checks `if (dto.subtotal !== undefined)` and uses client subtotal without validating against `menuItem.base_price`.
  5. Line 258 uses `dto.grand_total` directly without recomputing taxes or item line sums.
  6. Order commits to PostgreSQL and emits to kitchen displays.
- Impact: Money loss; cashiers or attackers can purchase items for arbitrary prices.
- Recommended fix: Make the server authoritative for pricing. Look up each `menu_item_id` in the database, calculate line item sums, compute store tax rate, apply only authorized discounts, and reject orders whose client totals differ by more than rounding tolerance (0.05).
- Effort: M
- Status: CONFIRMED

### SEC-02: Deactivated / Fired Staff Accounts Accepted by Backend JWT Strategy
- Severity: Critical
- Evidence: [`backend/src/auth/strategies/jwt.strategy.ts:26-38`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L38), [`backend/src/users/users.service.ts:323-328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/users/users.service.ts#L323-L328)
- Failure sequence:
  1. Store manager deactivates employee via `DELETE /api/users/:id`, setting `is_active = false`.
  2. Employee's tablet remains in possession with an unexpired JWT (up to 24-hour lifetime).
  3. Employee submits sync push or REST calls.
  4. `JwtStrategy.validate()` queries `staffUser.findUnique({ where: { id: payload.sub } })` and returns the user without checking `is_active`.
  5. `JwtAuthGuard` accepts the request.
- Impact: Security breach; deactivated or rogue employees can access cloud endpoints, push transactions, and read store data until token expiration.
- Recommended fix: In `JwtStrategy.validate()`, check `if (!user || user.is_active === false) throw new UnauthorizedException('User account is deactivated');`.
- Effort: S
- Status: CONFIRMED

### SEC-03: Hardcoded Password Guessing in Silent Re-Authentication Pipeline
- Severity: High
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:1355-1360`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1355-L1360)
- Failure sequence:
  1. Tablet token expires while syncing.
  2. Background worker catches 401 and calls `trySilentReauth()`.
  3. Worker constructs password as `username.toLowerCase() == 'noman' ? 'Noman123' : '${username}123'`.
  4. Worker issues plaintext HTTP POST to `/api/auth/login`.
  5. Fails if user has a custom password, and exposes hardcoded password structure.
- Impact: Security vulnerability (credential guessing backdoor) and sync stall.
- Recommended fix: Remove hardcoded password logic. Implement standard OAuth2 / JWT refresh tokens encrypted in DPAPI storage.
- Effort: M
- Status: CONFIRMED

### SEC-04: Permanent Outbox Queue Freeze on Authentication Expiry
- Severity: High
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:752-769`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L752-L769), [`frontend/lib/core/database/daos/outbox_dao.dart:20-35`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/outbox_dao.dart#L20-L35), [`frontend/lib/data/auth_repository.dart:420-435`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L420-L435)
- Failure sequence:
  1. Sync worker receives HTTP 401 during push transmission.
  2. `trySilentReauth()` fails; worker calls `markAuthPaused()` on all batch entries.
  3. Mutations transition to status `AUTH_PAUSED`.
  4. `outboxDao.getPushBatch()` explicitly filters out `AUTH_PAUSED`.
  5. User re-authenticates successfully via `LoginScreen` and `AuthNotifier.login()`.
  6. `AuthNotifier.login()` never calls `worker.resumeAuthPaused()`.
  7. Mutations remain in `AUTH_PAUSED` indefinitely and are never pushed.
- Impact: Lost orders / revenue loss; offline sales never synchronize to the cloud.
- Recommended fix: In `AuthNotifier.login()`, add `ref.read(syncBackgroundWorkerProvider).resumeAuthPaused()` upon successful login, and reset `AUTH_PAUSED` entries on app restart.
- Effort: S
- Status: CONFIRMED

### SEC-05: Plaintext Staff Passwords Stored in PostgreSQL and Exposed via REST API
- Severity: High
- Evidence: [`backend/prisma/schema.prisma:32`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L32), [`backend/src/users/users.service.ts:102, 199, 272`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/users/users.service.ts#L102)
- Failure sequence:
  1. Administrator creates or updates user via `UsersService.createUser()` or `updatePassword()`.
  2. Password is saved in `plain_password` column in PostgreSQL alongside `password_hash`.
  3. `users.service.ts` includes `plain_password: true` in queries and returns plaintext passwords in REST responses.
- Impact: Severe credential compromise; database dumps and network sniffers expose all employee passwords.
- Recommended fix: Remove `plain_password` column from `schema.prisma`, delete all references in `users.service.ts`, and rely exclusively on `password_hash` with Argon2.
- Effort: S
- Status: CONFIRMED

### SEC-06: Unvalidated Mutation Payload and Unbounded Push Batch DoS
- Severity: High
- Evidence: [`backend/src/sync/dto/sync-push.dto.ts:47-48, 60-63`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L47-L48), [`backend/src/main.ts:31, 38-47`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L31)
- Failure sequence:
  1. Client sends `POST /api/sync/push` with 5,000 mutations in `mutations` array and arbitrary properties inside `payload: any`.
  2. Global `ValidationPipe` ignores `payload` contents because no class schema exists.
  3. `SyncPushService.pushMutations()` runs recursive `isAncestorOf` sorting across 5,000 items (O(N^2)).
  4. Server experiences CPU exhaustion, blocking all REST and sync traffic.
- Impact: Denial of Service and potential payload injection.
- Recommended fix: Add `@ArrayMaxSize(50)` on `mutations`, define polymorphic DTO classes for each entity payload with `@ValidateNested()`, and enforce schema validation.
- Effort: M
- Status: CONFIRMED

### SEC-07: Plaintext Storage of Cached Staff Credentials in Client SharedPreferences
- Severity: High
- Evidence: [`frontend/lib/data/repositories/in_memory_auth_repository.dart:80-169`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/in_memory_auth_repository.dart#L80-L169)
- Failure sequence:
  1. Staff members log into POS client.
  2. `_saveCustomUsers()` serializes credentials into pipe-delimited strings (`username||role||email||salt||hash`).
  3. Writes array to unencrypted `SharedPreferences` key `auth_custom_staff_users_v1`.
  4. Attacker inspects local AppData or registry to harvest salts and hashes.
- Impact: Credential theft and offline dictionary cracking.
- Recommended fix: Persist staff users exclusively in SQLCipher-encrypted Drift table `LocalStaffUsers` and remove `in_memory_auth_repository.dart` SharedPreferences storage.
- Effort: M
- Status: CONFIRMED

### SEC-08: Complete Absence of Device Identity, Authentication, and Revocation
- Severity: High
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:173`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L173), [`backend/prisma/schema.prisma:652`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L652)
- Failure sequence:
  1. Client provides arbitrary `device_id` string in `SyncPushDto` (defaults to `'POS-P1'`).
  2. Backend accepts and records string without verifying device identity.
  3. A tablet is stolen or an unauthorized laptop connects to the store network.
  4. Administrators cannot revoke the compromised device because no device authorization entity exists.
- Impact: Unauthorized terminal access; inability to isolate stolen POS hardware.
- Recommended fix: Introduce `devices` table with device UUID, pre-shared public key / mutual TLS enrollment, active status, and remote wipe flag. Reject sync from unapproved devices.
- Effort: L
- Status: CONFIRMED

### SEC-09: Lack of Individual Staff Attribution on Orders and Shift Cross-Contamination
- Severity: Medium
- Evidence: [`frontend/lib/core/database/tables/local_orders_tables.dart:6-34`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/local_orders_tables.dart#L6-L34), [`backend/prisma/schema.prisma:280-310`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L280-L310), [`frontend/lib/data/auth_repository.dart:533-546`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L533-L546)
- Failure sequence:
  1. Cashier A creates 10 orders offline.
  2. Cashier A logs out without syncing.
  3. Cashier B logs in on the same offline tablet.
  4. Tablet reconnects; outbox pushes Cashier A's orders using Cashier B's JWT token.
  5. In PostgreSQL, `Order` contains no author field; audit trails attribute push to Cashier B.
- Impact: Repudiation; inability to trace fraud, shrinkage, or voided items to individual cashiers.
- Recommended fix: Add immutable `cashier_id` and `cashier_name` to `LocalOrders` and `Order` tables, populated at order creation time.
- Effort: S
- Status: CONFIRMED

### SEC-10: Total Absence of Tenant and Branch Isolation in Sync Stream & Realtime WebSockets
- Severity: High
- Evidence: [`backend/src/sync/sync-pull.service.ts:48-52, 103-125`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L48-L52), [`backend/src/realtime/realtime.gateway.ts:110-166`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/realtime/realtime.gateway.ts#L110-L166)
- Failure sequence:
  1. Terminal connects to `GET /api/sync/pull` or WebSocket gateway.
  2. `SyncPullService.pullChanges()` executes `systemChangeLog.findMany()` with no branch/store filter.
  3. Client receives change logs for all stores.
  4. Socket clients join global `'pos'` and `'kitchen'` rooms or call `join_store` without authorization.
- Impact: Multi-store data leakage; cross-store ticket broadcasting.
- Recommended fix: Add `store_id` foreign key to `system_change_logs`, filter delta pull streams by JWT `store_id`, and restrict WebSocket room subscription to the authenticated store.
- Effort: M
- Status: CONFIRMED

### SEC-11: Single-Round SHA-256 Hashing with Zero Offline Rate Limiting or Lockout
- Severity: Medium
- Evidence: [`frontend/lib/core/security/password_hasher.dart:10-24`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/password_hasher.dart#L10-L24), [`frontend/lib/features/auth/login_screen.dart:30-52`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/auth/login_screen.dart#L30-L52)
- Failure sequence:
  1. Attacker accesses offline POS login screen.
  2. Attacker runs automated script entering candidate passwords.
  3. Client executes single-round SHA-256 verification in microseconds with zero delay or lockout.
  4. 4-digit or 6-digit staff PINs are brute-forced in seconds.
- Impact: Offline authentication bypass.
- Recommended fix: Upgrade `PasswordHasher` to PBKDF2-HMAC-SHA256 (min 100,000 iterations) or Argon2id; enforce 5-attempt limit with 5-minute lockout on offline login.
- Effort: S
- Status: CONFIRMED

### SEC-12: Total Loss of Encryption at Rest on Non-Windows Platforms
- Severity: High
- Evidence: [`frontend/lib/core/security/windows_dpapi.dart:95-97`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/windows_dpapi.dart#L95-L97), [`frontend/lib/core/security/token_storage.dart:42-52`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/security/token_storage.dart#L42-L52), [`frontend/lib/core/database/encrypted_connection.dart:97-100`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/encrypted_connection.dart#L97-L100)
- Failure sequence:
  1. POS application is deployed on Android tablet, Linux terminal, or macOS.
  2. `WindowsDpapi` fails initialization (`Platform.isWindows == false`).
  3. `TokenStorage` reverts to plaintext `SharedPreferences`.
  4. `encrypted_connection.dart` sets `keyHex = null`, disabling SQLite encryption pragmas.
  5. Database is created and stored in plaintext.
- Impact: Complete loss of data-at-rest confidentiality on mobile/tablet deployments.
- Recommended fix: Integrate `flutter_secure_storage` (Android Keystore / iOS Keychain) for cross-platform master key derivation.
- Effort: M
- Status: CONFIRMED

### SEC-13: Whole-Batch Fatal Poisoning on HTTP 4xx Client Errors
- Severity: High
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:478-482, 782-799`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L478-L482)
- Failure sequence:
  1. Outbox contains 25 mutations; 1 mutation has an invalid field triggering HTTP 400 or permission error triggering HTTP 403.
  2. Server responds with HTTP 400/403.
  3. Client executes `_handleFatalBatch(batch)`.
  4. All 25 mutations in the batch are marked `FAILED_FATAL` and quarantined into `sync_conflicts`.
  5. 24 valid orders are permanently prevented from syncing.
- Impact: Lost orders / revenue loss due to collateral batch poisoning.
- Recommended fix: Unpack batches into individual mutation requests when a batch-level 4xx is encountered, isolating the poisoned mutation while syncing the remaining 24.
- Effort: M
- Status: CONFIRMED

### SEC-14: Customer PII and Financial Metadata Stored in Plaintext Data Sync Logs
- Severity: Low
- Evidence: [`backend/prisma/schema.prisma:640`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L640), [`backend/src/sync/handlers/order.handler.ts:181`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L181)
- Failure sequence:
  1. Offline orders sync to backend.
  2. Raw payloads containing customer telephone numbers, delivery addresses, notes, and card references are saved in `data_sync_logs.payload_json`.
  3. Support staff with log access inspect customer PII and card last-four digits.
- Impact: PII privacy violation and regulatory non-compliance.
- Recommended fix: Mask telephone numbers and redact customer delivery addresses and card references prior to writing sync log payloads.
- Effort: S
- Status: CONFIRMED

### SEC-15: Non-Existent Backend Logout Endpoint Causing Failed Session Termination
- Severity: Medium
- Evidence: [`frontend/lib/data/auth_repository.dart:535`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L535), [`backend/src/auth/auth.controller.ts:1-34`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.controller.ts#L1-L34)
- Failure sequence:
  1. Cashier taps "Log Out" in UI.
  2. `AuthNotifier.logout()` invokes `_authApiService.logout()`.
  3. `AuthApiService` sends `POST /api/auth/logout`.
  4. Backend returns HTTP 404 Not Found because no logout route is implemented in NestJS `AuthController`.
  5. Catch block executes local `clearSession()`, but JWT token is never invalidated on the server or added to a revoked token blacklist.
- Impact: Zombie session persistence; intercepted token remains usable until natural expiration.
- Recommended fix: Implement `POST /api/auth/logout` endpoint in NestJS backed by Redis JWT blacklist or token revocation ledger.
- Effort: S
- Status: CONFIRMED
