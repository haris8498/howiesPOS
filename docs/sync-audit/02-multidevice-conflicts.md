# 02 - Multi-Device and Same-Account Conflict Audit: Hungry Howie's POS

> **Audit Role:** Multi-Device and Same-Account Conflict Auditor (`.agents/multidevice-conflict-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop + NestJS / Prisma / PostgreSQL Backend)  
> **Reference Specifications:** `docs/sync-audit/00-architecture-map.md`, `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`  
> **Date:** October 26, 2026  
> **Status:** Completed Audit Baseline  

---

## Executive Summary

This report delivers an exhaustive, evidence-backed conflict audit of the Hungry Howie's POS offline synchronization architecture. We examine the exact failure modes when:
1. Two cashiers or tablets log into the **same cashier account simultaneously**.
2. Two devices edit the **same business data (orders, dining tables, cash drawers)** concurrently across online and offline states.
3. Numbering sequences (receipts, takeaway tokens, invoices) collide across offline nodes.
4. Concurrency versions (OCC tokens, pull streams, delta change-feeds) collide or overwrite local work.

Every claim in this report cites verified source code (`file:line`). Where code paths could not be conclusively proven via static tracing, they are explicitly tagged **`UNVERIFIED`**.

### Critical Audit Verdict: HIGH RISK
The current implementation suffers from architectural vulnerabilities that cause **silent data corruption, lost revenue, and rogue session survivability**:
- **Hardcoded Device Identity:** Every client terminal is hardcoded as `terminalId: '1'` and `deviceId: 'POS-P1'` ([`order_repository_provider.dart:22-23`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L22-L23), [`shift_repository_provider.dart:12`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/shift_repository_provider.dart#L12)). The server and background worker cannot distinguish Tablet A from Tablet B.
- **False-Positive Echo Suppression:** Because Tablet A and Tablet B share the identical hardcoded `deviceId`, table updates pushed by Tablet A are **silently discarded** by Tablet B as its own "echo" ([`sync_background_worker.dart:1137-1140`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1137-L1140)).
- **Resurrection of Paid Orders:** An offline terminal pushing an order update resurrects paid, completed orders back to `UNPAID` and `accepted` because `OrderHandler.handleUpdate` neglects to verify whether the order is already settled ([`order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279)).
- **Item-Level Updates Dropped on Sync Push:** `OrderHandler.handleUpdate` on the backend only updates 5 header fields (`status`, `payment_status`, `is_paid`, `is_held`, `rejection_reason`). Any line-item additions, quantity edits, or cancellations pushed via the offline outbox are **silently ignored** by the server while returning `SYNCED` ([`order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279)).
- **Blind Delta Pull:** `_applyPullChange` in `SyncBackgroundWorker` contains no branch to insert newly created orders (`existingOrder == null` is ignored) ([`sync_background_worker.dart:1234-1256`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1234-L1256)). Orders created on Tablet A are completely invisible to Tablet B.
- **Deactivated Accounts Retain 24-Hour Write Access:** `JwtStrategy.validate` does not check `user.is_active` ([`jwt.strategy.ts:26-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L41)). A terminated cashier with an unexpired JWT can push arbitrary transactions for up to 24 hours.

---

## 1. Table of Scenarios

| Scenario Code | Scenario Description | Audit Verdict | Observed Code Behavior & Failure Mechanism |
|---|---|---|---|
| **A.1** | Both tablets log in to same cashier account at once | **PARTIAL** | Stateless JWT permits concurrent logins. No server session tracking, no token invalidation. However, multi-terminal concurrency creates drawer and outbox collisions downstream. |
| **A.2** | Device ID on outbox rows and server records | **FAIL** | All terminals hardcode `deviceId: 'POS-P1'`. Server cannot tell tablets apart. Audit trail completely compromised. False echo suppression triggers. |
| **A.3** | Two devices share one shift / cash drawer session | **FAIL** | Shift open rejects second offline shift with `ACTIVE_SHIFT_EXISTS`, forcing it into `OFFLINE_CLOSED`. When closing, server aggregates all cash storewide, creating massive false drawer shortages. Closes auto-cancel unpaid orders. |
| **A.4** | Account deactivated / PIN changed / role changed offline | **FAIL** | `JwtStrategy.validate` omits `is_active` check; existing tokens sync for up to 24 hours. Role changes ignored by `/sync/push` (no permission guard). Pauses on token expiry. |
| **A.5** | Logout on Device A — effect on Device B | **PARTIAL** | Logout is client-local (`TokenStorage.clearSession()`). Device B is unaffected. However, Device A silently resurrects session if pending outbox entries trigger `trySilentReauth`. |
| **B.1** | Same order edited on two devices (both online) | **FAIL** | Direct REST `orders.service.ts` uses whole-order LWW. Second write deletes items not present in its payload (`tx.orderItem.delete`). No item-level merge exists. |
| **B.2** | Same order edited on two devices (both offline, then reconnect) | **FAIL** | Device A syncs; Device B gets OCC `CONFLICT`. When Device B rebases, `OrderHandler.handleUpdate` drops all line-item changes on the server while acknowledging `SYNCED`. |
| **B.3** | Same order edited: one online, one offline | **FAIL** | Direct REST updates on server fail to increment `version`. When offline device reconnects, server OCC check (`1 > 1`) passes, silently overwriting server state. |
| **B.4** | Device A pays/closes order; Device B (offline) adds items and reconnects | **FAIL** | `OrderHandler.handleUpdate` does not check if order is paid/closed. Reverts order to `UNPAID` and `accepted`. Overwrites payment status in database. |
| **B.5** | Device A voids item; Device B increases its quantity | **FAIL** | Voiding is direct REST (`cancelOrderItem`). Server marks item cancelled, does not increment order version. Device B's stale update modifies quantity of a cancelled item; subtotal excludes it while client UI counts it. |
| **C.1** | Two offline devices issuing receipt/order/token numbers | **FAIL** | Both devices hardcode `terminalId: '1'` and start at `101`. Both issue identical `P1-101` and `TK-101`. Server suffixes cloud order to `P1-101-1`, but never returns suffix to client. |
| **C.2** | Gaps in numbering (tax / legal relevance) | **FAIL** | `getNextSequence` increments locally. Unsynced orders, dual-write races, or fatal conflicts leave permanent holes in server invoice sequences with no gap audit ledger. |
| **C.3** | Numbering assignment and DB uniqueness | **PASS / PARTIAL** | Local numbering via `TerminalSequencesDao`. PostgreSQL enforces `@unique` on `order_number` and `token_number`. Server prevents DB crash via suffixing, but desyncs client receipts. |
| **D.1** | Mutable entities carry `version` / OCC check on write | **PARTIAL** | `version` exists on `Order`, `RestaurantTable`, `DailyCalculation`. Checked in push handlers. BUT ignored/bypassed in all direct REST endpoints (`orders.service.ts`). |
| **D.2** | Last-write-wins (LWW) anywhere dangerous | **FAIL** | Whole-order LWW in `orders.service.ts:632` deletes concurrent line items. `OrderHandler.handleUpdate` overwrites payment status. Table status clobbers seated guests. |
| **D.3** | Pull overwriting unsynced local edits | **FAIL** | `_applyPullChange` updates local orders and sets `syncStatus = 'synced'` unconditionally, wiping out `pending_update` status before local mutations push. |
| **D.4** | Soft-deleted / voided records resurrecting after pull | **PARTIAL** | Deleted tables and menu items delete from SQLite. However, cancelled items are never pulled (no order item delta handler), and stale order pushes resurrect cancelled quantities. |

---

## 2. Detailed Scenario Tracing

### Scenario A: Same Cashier Account on Two Tablets

#### A.1 Concurrent Logins & Session Invalidation
- **Code Trace:**
  - Login is handled by `AuthService.login()` in [`backend/src/auth/auth.service.ts:17-62`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.service.ts#L17-L62).
  - The server validates credentials via `argon2.verify()` and generates a stateless JWT:
    ```typescript
    // backend/src/auth/auth.service.ts:51
    const accessToken = this.jwtService.sign(payload);
    ```
  - The JWT expiration is configured in `AuthModule` as `JWT_EXPIRES_IN || '1d'` (24 hours) ([`backend/src/auth/auth.module.ts:23`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.module.ts#L23)).
  - **Prisma Schema Inspection:** The backend database contains no `Session`, `DeviceSession`, or `ActiveToken` table ([`backend/prisma/schema.prisma:28-43`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L28-L43)).
  - There are no refresh tokens implemented anywhere in the backend codebase (`NOT FOUND`).
  - There is no token blacklist or revocation list (`NOT FOUND`).
- **Outcome:** Both tablets can log in simultaneously using the exact same cashier username and password. Neither token invalidates the other. Both devices operate concurrently until their 24-hour JWT tokens expire.

#### A.2 Device ID & Terminal Identification
- **Code Trace:**
  - In `order_repository_provider.dart:20-24`, the order repository is initialized:
    ```dart
    // frontend/lib/data/repositories/order_repository_provider.dart:20-24
    return DriftOfflineFirstOrderRepository(
      db: db,
      terminalId: '1',
      deviceId: 'POS-P1',
    );
    ```
  - In `shift_repository_provider.dart:10-13`:
    ```dart
    // frontend/lib/data/repositories/shift_repository_provider.dart:10-13
    return DriftOfflineFirstShiftRepository(
      db: db,
      deviceId: 'POS-P1',
    );
    ```
  - In `sync_background_worker.dart:173`:
    ```dart
    // frontend/lib/core/sync/sync_background_worker.dart:173
    this.deviceId = 'POS-P1',
    ```
  - In `table_repository.dart:222, 285, 368, 455`, `deviceId` is hardcoded as `const Value('POS-P1')`.
  - There is no settings screen, config file, or environment variable allowing an operator to change `terminalId` or `deviceId` on a specific tablet.
  - In `backend/src/orders/orders.service.ts:356-380`, `device_id` is **not even mapped** into `tx.order.create`. The Prisma model defaults to `'POS-LOCAL-01'` ([`schema.prisma:304`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L304)).
  - In `backend/prisma/schema.prisma:549-604`, the `DailyCalculation` table does not possess a `device_id` column at all.
  - **Echo Suppression Defect:** In `sync_background_worker.dart:1137-1140`:
    ```dart
    final changeDeviceId = payload['origin_device_id'] ?? payload['device_id'];
    if (changeDeviceId != null && changeDeviceId.toString() == deviceId) {
      return; // Ignore echo of own writes
    }
    ```
- **Outcome:** Because Tablet A and Tablet B both identify as `POS-P1`, the backend audit trail cannot distinguish which tablet or physical operator submitted a transaction. Even worse, when Tablet A pushes an update for a restaurant table, Tablet B pulls the delta, inspects `payload['device_id'] == 'POS-P1'`, and **discards Tablet A's table update as its own write**.

#### A.3 Shared Shift & Cash Drawer Concurrency
- **Code Trace:**
  - Cashier shift open/close is governed by `DriftOfflineFirstShiftRepository` ([`drift_offline_first_shift_repository.dart:37-120`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L37-L120)) and `ShiftHandler` ([`shift.handler.ts:48-350`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L48-L350)).
  - **Case 1: Both devices offline.**
    1. Tablet A opens shift: generates UUID v7 `shift_id_A`, enqueues outbox Level 0.
    2. Tablet B opens shift: generates UUID v7 `shift_id_B`, enqueues outbox Level 0.
    3. Both tablets take orders offline against their respective shift IDs.
    4. Tablet A reconnects and pushes: `ShiftHandler.handleInsert` checks `activeShift = findFirst({ status: 'ACTIVE' })` ([`shift.handler.ts:133`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L133)). None exists. `shift_id_A` is created with status `ACTIVE`.
    5. Tablet B reconnects and pushes: `ShiftHandler.handleInsert` finds `shift_id_A` is already `ACTIVE`. It forces `shift_id_B` into status `OFFLINE_CLOSED` and returns HTTP 200 with `status: 'CONFLICT'` (`ACTIVE_SHIFT_EXISTS`) ([`shift.handler.ts:148-191`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L148-L191)).
    6. Tablet B's outbox worker marks the shift mutation as `CONFLICT` and quarantines it in `sync_conflicts` ([`sync_background_worker.dart:624-640`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L624-L640)). The top status indicator turns **RED**.
    7. When Tablet B subsequently attempts to close its shift (`closeShift`), `ShiftHandler.handleUpdate` inspects lines 312-328:
       ```typescript
       // backend/src/sync/handlers/shift.handler.ts:312-316
       if (existing.status === 'OFFLINE_CLOSED' || existing.status === 'CLOSED') {
         return { status: 'DUPLICATE', ... };
       }
       ```
       The server returns `DUPLICATE` and **completely drops Tablet B's counted cash, cash variance, and closing notes**. Tablet B's cash drawer balance is lost from the database.
  - **Case 2: Both devices online, sharing one shift (`shift_id_A`).**
    1. Tablet A and Tablet B both submit cash orders associated with `shift_id_A`.
    2. Cashier A closes the shift on Tablet A, counting the physical cash inside Tablet A's drawer (e.g. PKR 10,000).
    3. Server `ShiftHandler.handleUpdate` runs lines 389-446:
       ```typescript
       // backend/src/sync/handlers/shift.handler.ts:442-446
       const startingCashNum = Number(existing.starting_cash || 0);
       const expectedCash = startingCashNum + totalCashSales; // Sum of ALL orders storewide!
       const finalVariance = actualCash - expectedCash;
       ```
       The server expects cash for orders placed across **both** Tablet A and Tablet B (e.g. PKR 25,000).
       Cashier A's shift close is stamped with a **spurious cash shortage of PKR 15,000**.
    4. Auto-cancel side effect: Lines 379-386 in `shift.handler.ts`:
       ```typescript
       // backend/src/sync/handlers/shift.handler.ts:380-386
       await tx.order.updateMany({
         where: { shift_id: existing.id, status: { notIn: ['completed', 'cancelled'] }, is_paid: false },
         data: { status: 'cancelled' },
       });
       ```
       Any unpaid order currently in progress on Tablet B is **automatically cancelled on the server**.
- **Outcome:** Catastrophic failure. Offline multi-device shifts are rejected and quarantined, losing counted cash balances; online multi-device shifts corrupt cash variance reporting and auto-cancel concurrent active orders.

#### A.4 Deactivation, Password Change, or Role Change While Offline
- **Code Trace:**
  - **Account Deactivation:** Admin sets `StaffUser.is_active = false` via web management portal.
    - Tablet B is offline with 15 pending orders in `sync_outbox`.
    - Tablet B reconnects. Worker attaches existing JWT bearer token from `TokenStorage`.
    - Token hits `JwtAuthGuard` -> `JwtStrategy.validate(payload)` in [`jwt.strategy.ts:25-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L25-L41):
      ```typescript
      // backend/src/auth/strategies/jwt.strategy.ts:26-38
      const user = await this.prisma.staffUser.findUnique({
        where: { id: payload.sub },
        select: { id: true, username: true, role: true, is_default: true },
      });
      if (!user) {
        throw new UnauthorizedException('User no longer exists or session is invalid');
      }
      return user;
      ```
      **`JwtStrategy` never checks `is_active`!**
    - The deactivated user's push request returns HTTP 200 `SYNCED`.
    - Queued data commits into PostgreSQL despite the cashier having been terminated.
  - **Token Expiry After Deactivation (> 24 hours):**
    - If the token expired while offline, `POST /sync/push` fails with HTTP 401.
    - Worker calls `trySilentReauth()` in [`sync_background_worker.dart:1342-1373`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1342-L1373).
    - `trySilentReauth()` sends `POST /api/auth/login`.
    - `AuthService.login()` explicitly checks `if (user.is_active === false)` ([`auth.service.ts:33`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.service.ts#L33)) and throws `UnauthorizedException`.
    - Worker enters `isAuthPaused = true`, marking outbox entries `AUTH_PAUSED`. Data remains durable in SQLite.
  - **Role Change While Offline:**
    - Admin downgrades user from `'cashier'` to `'rider'`.
    - Tablet B reconnects and calls `POST /sync/push`.
    - `SyncController` has `@UseGuards(JwtAuthGuard)` ([`sync.controller.ts:30`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync.controller.ts#L30)), but **no RBAC guard** (`@UseGuards(PermissionsGuard)` is NOT present).
    - The push succeeds without restriction.
- **Outcome:** Severe security gap. Deactivated cashier accounts can continue committing offline orders to the cloud database for up to 24 hours after deactivation due to missing `is_active` validation in Passport JWT strategy.

#### A.5 Logout on Device A — Effect on Device B
- **Code Trace:**
  - Cashier taps "Logout" on Device A (`NavigationSidebar._confirmLogout()` -> `authProvider.notifier.logout()`).
  - In `frontend/lib/services/api/auth_api_service.dart:54-56`:
    ```dart
    // frontend/lib/services/api/auth_api_service.dart:54-56
    Future<void> logout() async {
      await TokenStorage.clearSession();
    }
    ```
  - The client makes **zero HTTP network requests** to the server.
  - In `auth_repository.dart:539`, `RealtimeSocketService.instance.disconnect()` closes the local WebSocket.
  - On Device B: Device B's `TokenStorage` retains its token; Device B's Socket.IO remains connected; Device B experiences zero operational impact.
  - On Device A: If Device A has pending outbox records, `SyncBackgroundWorker._buildHeaders()` executes lines 1381-1387:
    ```dart
    var token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      final newToken = await trySilentReauth();
      if (newToken != null) token = newToken;
    }
    ```
    `trySilentReauth()` looks up the active shift cashier name in `local_daily_calculations` and executes silent login using password `'${username}123'` ([`sync_background_worker.dart:1355`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1355)).
- **Outcome:** Device B is unaffected. However, Device A contains an auth bypass backdoor that automatically logs back in and generates a fresh token if an unsynced shift exists in the local database.

---

### Scenario B: Same Order Edited on Two Devices

#### B.1 Both Online Concurrently
- **Code Trace:**
  - In `frontend/lib/features/tables/tables_screen.dart:3880-3904`, dining table order modification issues direct HTTP REST `ordersApi.updateOrder(activeOrderId, payload)` before writing to Drift.
  - On backend, `OrdersService.updateOrder()` in [`orders.service.ts:537-646`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L537-L646):
    - Reads `existing.order_items`.
    - Iterates incoming items: updates matched items and inserts new items.
    - **Clobbering Step (Lines 632-636):**
      ```typescript
      // backend/src/orders/orders.service.ts:632-636
      for (const existingItem of existingItems) {
        if (!incomingItemIds.has(existingItem.id) && !existingItem.is_cancelled) {
          await tx.orderItem.delete({ where: { id: existingItem.id } });
        }
      }
      ```
  - Device A adds "Pepperoni Pizza" and posts. Server commits.
  - Device B (having loaded the table cart earlier) adds "Garlic Bread" and posts.
  - Device B's payload does not contain the `id` of "Pepperoni Pizza" added by Device A.
  - The server executes `tx.orderItem.delete` on Device A's "Pepperoni Pizza".
- **Outcome:** Pure whole-order Last-Write-Wins (LWW). Concurrent line-item additions on online devices clobber and delete each other. Kitchen tickets will have missing items; bills will be truncated.

#### B.2 Both Offline, Then Reconnect
- **Code Trace:**
  - Device A and Device B both have Order #101 cached locally with `serverVersion = 1`.
  - Offline: Device A adds Item A. Drift updates `local_orders` and enqueues outbox `UPDATE` with `baseVersion: 1` ([`drift_offline_first_order_repository.dart:335`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L335)).
  - Offline: Device B adds Item B. Drift updates `local_orders` and enqueues outbox `UPDATE` with `baseVersion: 1`.
  - Reconnect: Device A pushes first.
    - `OrderHandler.handleUpdate()` verifies `currentVersion (1) > mutation.base_version (1)` is false.
    - Increments version: `version: 2`. Returns `SYNCED`.
  - Reconnect: Device B pushes second.
    - `OrderHandler.handleUpdate()` verifies lines 244-262:
      ```typescript
      // backend/src/sync/handlers/order.handler.ts:246-247
      if (mutation.base_version !== undefined && currentVersion > mutation.base_version) {
        return { status: 'CONFLICT', ... };
      }
      ```
      `currentVersion (2) > mutation.base_version (1)` is **TRUE**.
    - Server returns HTTP 200 with `status: 'CONFLICT'`.
  - Device B Client Reaction:
    - In `sync_background_worker.dart:575-585`, worker attempts automatic rebasing:
      ```dart
      // Auto-rebase base_version up to 3 times
      if (rebaseCount < 3) {
        await db.outboxDao.rebaseMutationVersion(entry.id, serverVersion);
        continue;
      }
      ```
    - Device B updates `baseVersion` to 2 and retries push!
    - **The Fatal Trap in `OrderHandler.handleUpdate` (Lines 265-279):**
      ```typescript
      // backend/src/sync/handlers/order.handler.ts:265-279
      const updated = await tx.order.update({
        where: { id: orderId },
        data: {
          ...(payload.status ? { status: payload.status } : {}),
          ...(payload.payment_status ? { payment_status: payload.payment_status } : {}),
          ...(payload.is_paid !== undefined ? { is_paid: payload.is_paid } : {}),
          ...(payload.is_held !== undefined ? { is_held: payload.is_held } : {}),
          ...(payload.rejection_reason ? { rejection_reason: payload.rejection_reason } : {}),
          version: { increment: 1 },
        } as any,
      });
      ```
      **`OrderHandler.handleUpdate` completely ignores `payload.items`, `payload.subtotal`, and `payload.grand_total`!**
    - The server returns `SYNCED`.
- **Outcome:** When Device B rebases and syncs, the backend acknowledges `SYNCED`, but **drops all items added by Device B**. Device B's local database believes Item B was synchronized, but Item B does not exist in PostgreSQL.

#### B.3 One Online, One Offline
- **Code Trace:**
  - Device A (online) modifies Order #101 via REST `OrdersController.updateOrder` -> `OrdersService.updateOrder`.
  - In `backend/src/orders/orders.service.ts:710-738`:
    ```typescript
    await tx.order.update({
      where: { id },
      data: {
        order_type: orderType,
        status: dto.status ?? existing.status,
        subtotal,
        discount_amount: discountAmount,
        grand_total: grandTotal,
        // NOTICE: version IS NOT INCREMENTED!
      },
    });
    ```
    `OrdersService.updateOrder` **never increments `version`**!
  - In addition, `OrdersService.updateOrder` **never calls `ChangeLogService.record()`**.
  - PostgreSQL retains `Order.version = 1`.
  - Device B (offline) modifies Order #101 with `baseVersion: 1`.
  - Device B reconnects and calls `POST /sync/push`.
  - Server `OrderHandler.handleUpdate` evaluates OCC:
    `currentVersion (1) > mutation.base_version (1)` -> **FALSE**!
  - OCC collision detection completely fails because online edits never bump the version token.
- **Outcome:** The offline device's push is accepted as a valid update despite conflicting with intermediate online edits. The server change log is missing, leaving all other nodes blind to the changes.

#### B.4 Device A Pays/Closes Order; Device B (Offline) Adds Items and Reconnects
- **Code Trace:**
  - Device A pays and closes Order #101 via POS checkout or `OrdersService.updateOrderStatus(id, 'completed')`.
  - In PostgreSQL: `Order.is_paid = true`, `Order.status = 'completed'`, `Order.version = 1`.
  - Device B (offline) was editing Order #101: added drinks, local `status = 'accepted'`, local `is_paid = false`.
  - Device B reconnects and pushes `UPDATE` mutation to `POST /sync/push`.
  - `OrderHandler.handleUpdate()` in `backend/src/sync/handlers/order.handler.ts:243-279`:
    - Checks OCC: `currentVersion (1) > mutation.base_version (1)` is false.
    - **No settlement guard:** Unlike `OrdersService.updateOrder:549`, `OrderHandler.handleUpdate` contains **no check** for `existing.is_paid` or `existing.status === 'completed'`.
    - Executes lines 265-279:
      ```typescript
      const updated = await tx.order.update({
        where: { id: orderId },
        data: {
          ...(payload.status ? { status: payload.status } : {}), // Sets 'accepted'
          ...(payload.payment_status ? { payment_status: payload.payment_status } : {}), // Sets 'UNPAID'
          ...(payload.is_paid !== undefined ? { is_paid: payload.is_paid } : {}), // Sets false!
          version: { increment: 1 },
        },
      });
      ```
- **Outcome:** **RESURRECTION OF PAID ORDER.** The cloud database's completed, paid transaction is reverted back to `accepted`, `payment_status: 'UNPAID'`, and `is_paid: false`. The customer's payment is effectively wiped from the order header in PostgreSQL.

#### B.5 Device A Voids Item; Device B (Stale) Increases Its Quantity
- **Code Trace:**
  - Device A voids item via `tables_screen.dart:6630` calling direct REST `ordersApi.cancelOrderItem()`.
  - `OrdersService.cancelOrderItem()` ([`orders.service.ts:1045-1054`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L1045-L1054)) sets `OrderItem.is_cancelled = true`.
  - Device B has stale state (item active with qty 1).
  - Cashier B taps `+` to increase qty to 2.
  - If Device B submits via REST `updateOrder`:
    - `orders.service.ts:588-600` updates `OrderItem.quantity = 2`, but preserves `is_cancelled = true`.
    - In lines 640-645, `activeItems = allCurrentItems.filter(i => !i.is_cancelled)`.
    - Because `is_cancelled` is true, the item is completely excluded from subtotal!
    - Device B's UI displays 2 pizzas with PKR 2,000 total; server displays 0 pizzas with PKR 0 subtotal.
  - If Device B submits via Sync Outbox:
    - As proven in B.2, `OrderHandler.handleUpdate` drops all item modifications.
- **Outcome:** Complete desynchronization between client UI totals and cloud order totals.

---

### Scenario C: Numbering

#### C.1 Multi-Device Offline Sequence Collisions
- **Code Trace:**
  - Sequential human numbers are generated by `TerminalSequencesDao.getNextSequence()` in [`terminal_sequences_dao.dart:15-45`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/terminal_sequences_dao.dart#L15-L45).
  - When date changes or table initializes, counter resets to 101.
  - Receipt number format is assembled by `OrderNumberGenerator.formatReceiptNumber(terminalId, seq)` in [`order_number_generator.dart:68`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L68): `'P' + terminalId + '-' + seq`.
  - `terminalId` is hardcoded as `'1'` on all installations ([`order_repository_provider.dart:22`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L22)).
  - Both Tablet A and Tablet B generate `P1-101`, `P1-102`, `P1-103`.
  - Takeaway tokens are generated as `TK-$counter` where counter is sequence modulo 1000 ([`order_number_generator.dart:95`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L95)). Both generate `TK-101`.
  - When Tablet B syncs `P1-101` and `TK-101`:
    - Server `OrdersService.createOrderInTx` detects collision on `order_number`:
      ```typescript
      // backend/src/orders/orders.service.ts:306-314
      let suffix = 1;
      let candidate = `${orderNumber}-${suffix}`;
      while (await tx.order.findUnique({ where: { order_number: candidate } })) {
        suffix++;
        candidate = `${orderNumber}-${suffix}`;
      }
      orderNumber = candidate; // Becomes P1-101-1
      ```
    - Server detects collision on `token_number` ([`orders.service.ts:408-410`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L408-L410)) and appends timestamp suffix: `TK-101-5821`.
    - **Client Desynchronization:** `OrderHandler.handleInsert` returns `SyncMutationResult` ([`order.handler.ts:206-212`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L206-L212)). It returns **only** `server_version` and `server_timestamp`.
    - The client's local Drift table retains `orderNumber = 'P1-101'`.
- **Outcome:** The customer's printed paper receipt says `P1-101`, the kitchen display token says `TK-101`, but the cloud PostgreSQL record says `P1-101-1` and `TK-101-5821`. Lookups by receipt number fail on cloud management tools.

#### C.2 Gaps in Numbering & Tax Relevance
- **Code Trace:**
  - `TerminalSequencesDao.getNextSequence()` is executed inside the atomic Drift order creation transaction ([`orders_dao.dart:23`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/orders_dao.dart#L23)).
  - If a transaction is created locally as `P1-105`:
    - If the outbox entry encounters a fatal schema error or is quarantined as `FAILED_FATAL`, it is moved to `sync_conflicts`.
    - In `takeaway_repository.dart:385`, dual-write attempts to delete outbox rows directly.
    - If local database corruption or Windows reinstall occurs, sequence 105 never reaches PostgreSQL.
  - In PostgreSQL, the order sequence shows `P1-104` followed by `P1-106`.
  - The server schema possesses no sequence gap detection table or missing invoice audit log.
- **Outcome:** In Pakistan (PRA / FBR sales tax compliance), consecutive unbroken invoice sequences are legally mandated. Gaps in synced sequential receipts trigger regulatory non-compliance during tax audits.

#### C.3 Assignment Authority & DB Uniqueness
- **Code Trace:**
  - Assignment occurs **on the client** at order birth.
  - Prisma Schema enforces:
    - `Order.order_number`: `@unique @map("order_number") @db.VarChar(30)` ([`schema.prisma:282`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L282)).
    - `TakeawayOrderDetail.token_number`: `@unique @map("token_number") @db.VarChar(20)` ([`schema.prisma:360`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L360)).
- **Outcome:** PASS on database integrity (unique constraints prevent database crashes via automated suffixing). FAIL on client synchronicity (suffix not propagated back to SQLite).

---

### Scenario D: Versioning

#### D.1 Concurrency Tokens & OCC Verification
- **Code Trace:**
  - Models with `version Int @default(1)`: `Order` ([`schema.prisma:308`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L308)), `RestaurantTable` ([`schema.prisma:156`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L156)), `DailyCalculation` ([`schema.prisma:591`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L591)).
  - Models **LACKING** `version`: `OrderItem` ([`schema.prisma:401-423`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L401-L423)), `OrderPayment` ([`schema.prisma:428-447`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L428-L447)).
  - OCC checks are enforced in:
    - `OrderHandler.handleUpdate` ([`order.handler.ts:246`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L246)).
    - `TableHandler.handleUpdate` ([`table.handler.ts:85`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/table.handler.ts#L85)).
    - `ShiftHandler.handleUpdate` ([`shift.handler.ts:332`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L332)).
  - **OCC Bypass in REST Services:** `OrdersService.updateOrder` ([`orders.service.ts:710`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L710)) and `OrdersService.cancelOrderItem` ([`orders.service.ts:1098`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L1098)) do **not** increment or inspect `version`.
- **Outcome:** Partial implementation. Concurrency tokens exist on headers but not on child items. Direct REST API calls bypass versioning entirely, causing OCC false-negatives during offline push.

#### D.2 Dangerous Last-Write-Wins
- **Code Trace:**
  - Line items in `OrdersService.updateOrder:632-636`: Deletes non-included items with no concurrency check.
  - Payment status in `OrderHandler.handleUpdate:265-279`: Overwrites `is_paid` and `payment_status`.
  - Restaurant tables in `TableHandler.handleUpdate`: If version matches, overwrites `current_bill_amount`, `guest_count`, and table notes.
- **Outcome:** Dangerous LWW exists on line items and payment statuses, directly threatening financial reconciliation.

#### D.3 Pull Overwriting Unsynced Local Edits
- **Code Trace:**
  - In `sync_background_worker.dart:1234-1256`:
    ```dart
    case 'order':
      final existingOrder = await db.ordersDao.getOrderById(entityId);
      if (existingOrder != null && existingOrder.serverVersion >= recordVersion) {
        return; // Ignore stale or duplicate
      }
      if (isDeleted) {
        await db.ordersDao.deleteOrder(entityId);
      } else if (existingOrder != null) {
        await (db.update(db.localOrders)..where((t) => t.id.equals(entityId))).write(
          LocalOrdersCompanion(
            status: Value(payload['status']?.toString() ?? existingOrder.status),
            paymentStatus: Value(payload['payment_status']?.toString() ?? existingOrder.paymentStatus),
            isPaid: Value(payload['is_paid'] == true || existingOrder.isPaid),
            serverVersion: Value(recordVersion),
            syncStatus: const Value('synced'), // BUG: Overwrites pending_update!
          ),
        );
      }
    ```
  - If a cashier made offline changes on Tablet B (`syncStatus = 'pending_update'`), and a delta pull arrives from the server, line 1253 writes `syncStatus = 'synced'`.
  - The local database marks the order as synced before its local outbox mutation has even been transmitted.
  - In addition, if `existingOrder == null` (an order created by another terminal), there is **no else block**. The newly created order is ignored and never saved to Drift.
- **Outcome:** CRITICAL. Local pending changes have their status prematurely flipped to `synced`, and remote orders created on other devices are completely ignored during delta pull.

#### D.4 Soft-Deleted / Voided Records Resurrecting After Pull
- **Code Trace:**
  - Tables: If `is_deleted == true`, `_applyPullChange` calls Drift `delete(localRestaurantTables)`.
  - Menu Items: If `isDeleted == true`, deleted from `localMenuItems`.
  - Orders: If `isDeleted == true`, `deleteOrder(entityId)` removes the order.
  - Order Items: There is **no pull handler** for `order_item` in `_applyPullChange`. Item deletions or voids on the server never sync down to other tablets via delta pull.
- **Outcome:** Deleted tables and catalog rows behave properly, but voided line items cannot sync down via delta pull, causing ghost items to linger on other terminals.

---

## 3. Conflict Policy Matrix

| Domain Entity | Current Strategy As Implemented | Recommended Strategy | Rationale & Code Target |
|---|---|---|---|
| **Orders (Headers)** | Optimistic Concurrency Control (OCC) in push; Last-Write-Wins (LWW) in REST. | **OCC on all write paths + Closed Order Immutability.** | Paid or completed orders must reject all updates with HTTP 409 Conflict. All REST routes must bump `version` ([`orders.service.ts:710`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L710)). |
| **Order Line Items** | Whole-order replace with blind child deletion ([`orders.service.ts:634`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L634)). Ignored in sync push. | **CRDT / Append-Only Item Ledger with UUID v7.** | Never delete rows. Modifying an item creates a delta operation (add, cancel, qty delta). Merges items by UUID v7. |
| **Order Payments** | Atomic append on insert; overwritten on update ([`order.handler.ts:272`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L272)). | **Strict Append-Only Immutable Ledger.** | Payments are immutable financial transactions. Once written, payments can only be offset by an explicit refund record ([`schema.prisma:428`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L428)). |
| **Restaurant Tables** | Hospitality Priority (§10.2) in pull; OCC in push handler. | **Hospitality Priority + Device-Aware Echo Suppression.** | Physical seated guest wins over cloud reservation. Echo suppression must check actual distinct device IDs, not hardcoded strings ([`sync_background_worker.dart:1137`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1137)). |
| **Cashier Shifts** | Store-wide single active shift check. Rejects second shift with `CONFLICT`. | **Register-Scoped Shifts (Terminal + Cashier).** | A shift represents a physical cash drawer. Each physical terminal must own its own shift session ([`schema.prisma:549`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L549), [`shift.handler.ts:133`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L133)). |
| **Receipt Numbering** | Suffixing on server collision (`P1-101-1`). Silent desync on client. | **Partitioned Sequences per Registered Terminal (`P1-`, `P2-`).** | Distinct terminal prefixes eliminate collisions. Server must return reassigned order numbers in `SyncMutationResult` ([`order.handler.ts:206`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L206)). |
| **Takeaway Tokens** | Random sequence modulo 1000 + timestamp suffix on collision. | **Terminal-Partitioned Tokens (`T1-101`, `T2-101`).** | Prevents unique constraint collisions in `takeaway_order_details.token_number` ([`orders.service.ts:405`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L405)). |
| **Menu / Pricing** | Pull-only catalog. Sales honor quoted bill pricing. | **Quoted Price Snapshot (Retain Current Policy).** | Customer pays quoted bill price at order time. Catalog updates independently ([`drift_offline_first_order_repository.dart:133`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L133)). |

---

## 4. Audit Findings

### CFL-01: Hardcoded Device ID and Terminal ID Eliminates Multi-Device Differentiation
- Severity: Critical
- Evidence: [`order_repository_provider.dart:22-23`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L22-L23), [`shift_repository_provider.dart:12`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/shift_repository_provider.dart#L12), [`sync_background_worker.dart:173`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L173), [`table_repository.dart:222`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L222)
- Failure sequence:
  1. Two tablets are deployed in the same restaurant.
  2. Both tablets execute compiled Dart code containing `terminalId: '1'` and `deviceId: 'POS-P1'`.
  3. Both devices emit identical `device_id` values on sync outbox rows and push requests.
  4. The NestJS server cannot distinguish which tablet or physical register performed an action.
- Impact: Security and audit trail destroyed; false echo suppression; sequence collisions.
- Recommended fix: Store a unique machine identifier (e.g. Windows MachineGuid or configured terminal number) in local encrypted storage and inject dynamically into providers.
- Effort: M
- Status: CONFIRMED

---

### CFL-02: False-Positive Echo Suppression Drops Remote Table Updates
- Severity: High
- Evidence: [`sync_background_worker.dart:1137-1140`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1137-L1140)
- Failure sequence:
  1. Cashier on Tablet A updates Table 4 to `occupied`.
  2. Tablet A pushes change to server with `device_id = 'POS-P1'`.
  3. Server logs change to `system_change_logs`.
  4. Tablet B executes delta pull (`GET /api/sync/pull`).
  5. Tablet B inspects `payload['device_id']` (`'POS-P1'`).
  6. Tablet B compares with its own `deviceId` (`'POS-P1'`).
  7. Tablet B exits early: `return; // Ignore echo of own writes`.
  8. Table 4 remains marked `available` on Tablet B.
- Impact: Wrong table state; double-seating of guests; floor layout desynchronization.
- Recommended fix: Ensure each device has a unique `deviceId`, and check both `deviceId` and `operationId` before suppressing changes.
- Effort: S
- Status: CONFIRMED

---

### CFL-03: Offline Reconnect Reverts Completed/Paid Orders to UNPAID
- Severity: Critical
- Evidence: [`order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279), [`orders.service.ts:710-738`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L710-L738)
- Failure sequence:
  1. Tablet A pays and completes Order #101 online (`status: 'completed', is_paid: true`).
  2. Because REST calls bypass version incrementing, PostgreSQL retains `Order.version = 1`.
  3. Tablet B (which had stale state while offline) modified Order #101 (`status: 'accepted', is_paid: false`).
  4. Tablet B reconnects and calls `POST /sync/push` with `base_version = 1`.
  5. Server `OrderHandler.handleUpdate` evaluates OCC: `currentVersion (1) > mutation.base_version (1)` is false.
  6. `OrderHandler` updates PostgreSQL with Tablet B's payload, setting `is_paid = false` and `status = 'accepted'`.
- Impact: Money / Lost payment; financial records corrupted; closed transactions resurrected.
- Recommended fix: Add guard in `OrderHandler.handleUpdate` rejecting updates if `existing.is_paid == true` or `existing.status == 'completed'`. Increment `version` on all REST order writes.
- Effort: S
- Status: CONFIRMED

---

### CFL-04: Order Item Updates Completely Discarded in Push Handler
- Severity: Critical
- Evidence: [`order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279), [`drift_offline_first_order_repository.dart:268-294`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L268-L294)
- Failure sequence:
  1. Cashier edits an existing order offline (adds an extra pizza, updates drink size).
  2. `drift_offline_first_order_repository.dart:updateOrder` saves new items to `local_order_items` and enqueues outbox `UPDATE`.
  3. Background worker pushes `UPDATE` mutation to `/api/sync/push`.
  4. `OrderHandler.handleUpdate` receives payload containing `items`.
  5. `OrderHandler.handleUpdate` executes `tx.order.update` targeting ONLY `status`, `payment_status`, `is_paid`, `is_held`, `rejection_reason`.
  6. Line items are never touched in PostgreSQL.
  7. Server returns `SYNCED`. Client marks outbox entry synced.
- Impact: Lost order items; customer billed for items not on kitchen ticket; financial mismatch between client and server.
- Recommended fix: Implement item upsert and reconciliation logic inside `OrderHandler.handleUpdate`.
- Effort: M
- Status: CONFIRMED

---

### CFL-05: Delta Pull Stream Completely Ignores New Orders
- Severity: Critical
- Evidence: [`sync_background_worker.dart:1234-1256`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1234-L1256)
- Failure sequence:
  1. Tablet A creates a new dine-in or takeaway order.
  2. Tablet A syncs order to backend; backend records `INSERT` in `system_change_logs`.
  3. Tablet B executes delta pull `GET /api/sync/pull`.
  4. Worker processes change: `existingOrder = await db.ordersDao.getOrderById(entityId)`.
  5. Because Tablet B never had this order, `existingOrder` is `null`.
  6. Code has `else if (existingOrder != null) { ... }`, with **no else block**.
  7. The new order is completely ignored.
- Impact: Multi-device visibility broken. Tablet B cannot see or manage orders created on Tablet A.
- Recommended fix: Implement `else` block in `_applyPullChange` for `order` to insert new order header, items, and payments into Drift.
- Effort: M
- Status: CONFIRMED

---

### CFL-06: Delta Pull Stream Unconditionally Overwrites Unsynced Local Order Edits
- Severity: High
- Evidence: [`sync_background_worker.dart:1246-1255`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1246-L1255)
- Failure sequence:
  1. Cashier edits Order #101 on Tablet B while offline (`syncStatus = 'pending_update'`).
  2. Tablet B connects to Wi-Fi. Delta pull executes before outbox push drains.
  3. Change arrives for Order #101 with `recordVersion > existingOrder.serverVersion`.
  4. `_applyPullChange` executes:
     `LocalOrdersCompanion(..., syncStatus: const Value('synced'))`.
  5. Local pending edits in SQLite are overwritten and marked `synced`.
- Impact: Cashier's pending edits wiped out; premature synchronization flag.
- Recommended fix: Check `existingOrder.syncStatus == 'pending_update'` or outbox pending count before overwriting local orders during pull.
- Effort: S
- Status: CONFIRMED

---

### CFL-07: REST Order Updates Bypass Version Token and Change-Feed Replication
- Severity: High
- Evidence: [`orders.service.ts:710-738`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L710-L738), [`orders.service.ts:1098-1110`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L1098-L1110)
- Failure sequence:
  1. An order is modified via web portal or direct REST API (`updateOrder` or `cancelOrderItem`).
  2. `tx.order.update` modifies order data but does not increment `version`.
  3. `ChangeLogService.record()` is not called.
  4. Offline tablets never receive the update via `GET /api/sync/pull`.
  5. If an offline tablet later pushes an update, OCC check fails to detect conflict because `version` remained 1.
- Impact: OCC collision failure; pull stream blindness.
- Recommended fix: Use Prisma middleware or update service methods to unconditionally increment `version` and append rows to `system_change_logs`.
- Effort: M
- Status: CONFIRMED

---

### CFL-08: Order Number and Takeaway Token Collisions Suffix Desynchronization
- Severity: High
- Evidence: [`orders.service.ts:306-314`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L306-L314), [`orders.service.ts:405-410`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L405-L410), [`order.handler.ts:206-212`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L206-L212)
- Failure sequence:
  1. Tablet A and Tablet B both issue receipt `P1-101` and token `TK-101` offline.
  2. Tablet A syncs first.
  3. Tablet B syncs second. Server renames Tablet B's order to `P1-101-1` and token to `TK-101-9921`.
  4. Server `SyncMutationResult` omits the reassigned order and token numbers.
  5. Customer paper receipt reads `P1-101` / `TK-101`; cloud database reads `P1-101-1` / `TK-101-9921`.
- Impact: Customer receipt mismatch; order tracking confusion at dispatch counter.
- Recommended fix: Include `reassigned_order_number` and `reassigned_token_number` in `SyncMutationResult` and update local SQLite rows upon sync ACK.
- Effort: S
- Status: CONFIRMED

---

### CFL-09: Multi-Device Shift Conflict Rejection and Cash Count Deletion
- Severity: Critical
- Evidence: [`shift.handler.ts:133-191`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L133-L191), [`shift.handler.ts:312-328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L312-L328)
- Failure sequence:
  1. Two tablets operate offline, each opening a shift with starting cash PKR 5,000.
  2. Tablet A reconnects; shift is accepted as `ACTIVE`.
  3. Tablet B reconnects; `shift.handler.ts` detects active shift, forces Tablet B's shift to `OFFLINE_CLOSED`, and returns `CONFLICT` (`ACTIVE_SHIFT_EXISTS`).
  4. Tablet B's outbox marks the mutation `CONFLICT` (quarantined). Status turns RED.
  5. When Tablet B tries to close its shift, `shift.handler.ts` sees status `OFFLINE_CLOSED`, returns `DUPLICATE`, and **drops Tablet B's cash count and variance**.
- Impact: Money / Lost cash audit; cashier shift reports corrupted.
- Recommended fix: Allow multiple active shifts if scoped to distinct registers/terminals.
- Effort: M
- Status: CONFIRMED

---

### CFL-10: Shift Close Store-Wide Aggregation Creates Spurious Cash Drawer Shortage
- Severity: High
- Evidence: [`shift.handler.ts:389-446`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L389-L446)
- Failure sequence:
  1. Tablet A and Tablet B are online and share `shift_id_1`.
  2. Cashier A placed PKR 10,000 in cash orders on Tablet A.
  3. Cashier B placed PKR 15,000 in cash orders on Tablet B.
  4. Cashier A closes the shift, entering counted cash PKR 10,000.
  5. Server aggregates ALL orders for `shift_id_1` (PKR 25,000 total cash sales).
  6. Server computes `expectedCash = 5000 + 25000 = 30000`.
  7. Server records a false cash shortage of PKR 15,000 against Cashier A.
- Impact: Money / Unjust cashier disciplinary action; audit trail chaos.
- Recommended fix: Scope cash drawer reconciliation strictly to orders originating from the specific terminal register.
- Effort: M
- Status: CONFIRMED

---

### CFL-11: Shift Close Automatically Cancels All Open Unpaid Orders Store-Wide
- Severity: Critical
- Evidence: [`shift.handler.ts:379-386`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L379-L386)
- Failure sequence:
  1. Tablet A closes its shift at 3:00 PM (end of lunch shift).
  2. Table 5 is currently occupied with a dining party whose bill has not yet been paid (`is_paid: false`).
  3. `shift.handler.ts` runs lines 379-386:
     ```typescript
     await tx.order.updateMany({
       where: { shift_id: existing.id, status: { notIn: ['completed', 'cancelled'] }, is_paid: false },
       data: { status: 'cancelled' },
     });
     ```
  4. Table 5's active order is automatically cancelled in PostgreSQL.
- Impact: Lost orders; seated dining guests have their open checks cancelled.
- Recommended fix: Reassign active un-settled orders to the incoming shift session or overflow ledger rather than cancelling them.
- Effort: S
- Status: CONFIRMED

---

### CFL-12: Deactivated User Existing JWT Continues Valid for 24 Hours in Sync Strategy
- Severity: High
- Evidence: [`jwt.strategy.ts:26-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L41), [`sync.controller.ts:30`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync.controller.ts#L30)
- Failure sequence:
  1. Cashier is terminated and marked `is_active = false` by store manager.
  2. Cashier takes tablet or uses existing local installation with valid JWT (issued < 24h ago).
  3. Cashier pushes arbitrary or fraudulent mutations to `POST /api/sync/push`.
  4. `JwtStrategy.validate` queries user, checks `if (!user)`, but completely ignores `is_active`.
  5. The unauthorized mutations are committed.
- Impact: Security vulnerability; terminated staff can alter records.
- Recommended fix: Add `if (!user.is_active) throw new UnauthorizedException('User account has been deactivated');` in `JwtStrategy.validate`.
- Effort: S
- Status: CONFIRMED

---

### CFL-13: Silent Re-Authentication Door Bypasses Cashier Logout on Outbox Push
- Severity: Medium
- Evidence: [`sync_background_worker.dart:1342-1373`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1342-L1373), [`auth_repository.dart:533-546`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L533-L546)
- Failure sequence:
  1. Cashier logs out on Tablet A (`TokenStorage.clearSession()`).
  2. Pending outbox records exist in SQLite.
  3. Worker executes `_buildHeaders()`. Token is null.
  4. Worker calls `trySilentReauth()`, extracts cashier username from active shift in SQLite, guesses password `${username}123`, and logs in.
  5. Session is silently re-established without cashier knowledge.
- Impact: Security / Session unpredictability.
- Recommended fix: Require explicit re-authentication when tokens are cleared on logout; never guess passwords.
- Effort: S
- Status: CONFIRMED

---

### CFL-14: Item Cancellation is REST-Only and Drops Strikethrough Audit Offline
- Severity: Medium
- Evidence: [`tables_screen.dart:6624-6638`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L6624-L6638)
- Failure sequence:
  1. Tablet A loses internet connectivity.
  2. Cashier attempts to cancel a pizza item from an active dine-in table.
  3. `_handleConfirmCancel` executes `ordersApi.cancelOrderItem()`.
  4. Throws unhandled `SocketException`.
  5. UI shows snackbar: *"Failed to cancel item: SocketException"*.
  6. Item cancellation cannot be performed offline.
- Impact: UX / Offline capability failure; cashier cannot void items when broadband is down.
- Recommended fix: Route item cancellation through `orderRepository.updateOrder()` in Drift with an outbox mutation.
- Effort: M
- Status: CONFIRMED

---

### CFL-15: Cold Bootstrap Ignores Active Orders, Leaving Fresh Terminals Blind
- Severity: High
- Evidence: [`sync_background_worker.dart:921-1111`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L921-L1111), [`sync-pull.service.ts:131-136`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L131-L136)
- Failure sequence:
  1. Store has 10 active dining tables with open orders.
  2. A new tablet (Tablet C) is booted up and executes cold bootstrap (`GET /api/sync/bootstrap?raw=true`).
  3. Server returns `active_orders` in the JSON response payload ([`sync-pull.service.ts:131`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L131)).
  4. Client `_applyBootstrapData` parses settings, categories, items, and tables, but **omits `active_orders`**.
  5. Tablet C's local database contains zero orders.
  6. Cashier on Tablet C taps Table 1: app treats it as a brand new order because local active order is missing.
- Impact: Multi-device visibility broken on fresh terminal starts; duplicate orders created.
- Recommended fix: Ingest `data['active_orders']` into `local_orders`, `local_order_items`, and `local_order_payments` inside `_applyBootstrapData`.
- Effort: M
- Status: CONFIRMED

---

## 5. Recommended Conflict Rules

To achieve a production-ready, multi-device, offline-first restaurant POS, the following 5 conflict rules must be adopted:

### Rule 1: Closed and Paid Orders Are Strictly Immutable
Once an order has `is_paid == true` or `status == 'completed'`, the server must reject all subsequent mutation payloads with HTTP 409 Conflict. An offline terminal attempting to push modifications to a closed order must have its mutation quarantined with a human-readable prompt to supervisor: *"Order was already paid and closed on Terminal 1. Items cannot be added."*

### Rule 2: Item-Level CRDT / Delta Merge Over Whole-Order LWW
Whole-order Last-Write-Wins must be abolished. The server must never delete `order_items` simply because they are missing from an incoming array. Line items must be treated as independent, immutable ledger entries identified by RFC 9562 UUID v7:
- Adding an item inserts a new UUID v7 row.
- Cancelling an item sets `is_cancelled = true` on that UUID v7 row.
- Changing quantity stores a signed delta quantity.

### Rule 3: Register-Scoped Cash Drawer Sessions
A shift represents a physical cash drawer. Each physical terminal must own its own shift session (`terminal_id + cashier_id`). The server must allow multiple active shifts across different terminals simultaneously. Expected cash calculations must strictly sum orders placed on that specific terminal.

### Rule 4: Partitioned Numbering Sequences per Physical Terminal
Every deployed tablet must be assigned a unique terminal index (`P1`, `P2`, `P3`, etc.).
- Terminal 1 issues `P1-101..999` and `TK1-101..999`.
- Terminal 2 issues `P2-101..999` and `TK2-101..999`.
Distinct sequence namespaces eliminate collisions by design. When server-side re-numbering does occur, `SyncMutationResult` must return the reassigned identifier, and Drift must update the local SQLite row immediately.

### Rule 5: Strict Active Check on JWT Strategy & Complete Pull Handlers
`JwtStrategy.validate` must verify `user.is_active === true` on every request. `SyncBackgroundWorker._applyPullChange` must implement full insertion logic for `order`, `order_item`, and `order_payment` to allow orders created on Terminal A to replicate down to Terminal B.
