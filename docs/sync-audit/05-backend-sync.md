# 05 - Backend Synchronization Audit: NestJS / Prisma / PostgreSQL

> **Audit Role:** Backend Sync Auditor (`.agents/backend-sync-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS Backend (`backend/src/sync`, `backend/src/orders`, `backend/src/daily-calculation`, `backend/src/tables`, `backend/prisma`)  
> **Reference Specifications:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/00-architecture-map.md`  
> **Finding Prefix:** `BCK`  
> **Status:** Final Implementation Audit  
> **Date:** October 26, 2026  

---

## Executive Summary

This audit assesses the server-side offline synchronization engine implemented in the NestJS, Prisma, and PostgreSQL backend. The audit models the system under adverse network conditions—simulating duplicated, out-of-order, stale, concurrently conflicting, and maliciously crafted payloads sent by reconnecting client devices.

The backend implementation achieves several architectural milestones outlined in `99-FINAL-ARCHITECTURE.md`, including RFC 9562 UUID v7 primary key preservation, dependency-ordered mutation processing (Levels 0–5), and an HTTP-level idempotency interceptor backed by `processed_operations`.

However, the server side exhibits **severe operational vulnerabilities and data-loss failure modes**:
1. **Silent Order Annihilation on Unique Constraint Collisions (BCK-01):** Any `P2002` error on `INSERT`—including collisions on `order_number`, takeaway `token_number`, or dining table unique constraints—is unconditionally treated by `SyncPushService` as a primary key duplicate (`isDuplicatePrimaryKey`). The transaction rolls back, but the server returns `status: 'DUPLICATE'`. The client marks the order as successfully synced locally and deletes it from the outbox, **permanently losing the customer order from PostgreSQL**.
2. **Zero Price and Total Validation (BCK-02):** The server completely trusts client-provided `unit_price`, `subtotal`, `grand_total`, `discount_amount`, and `tax_amount`. It does not recalculate totals against menu database records or store tax policies, enabling trivial financial manipulation or accidental corruption.
3. **Destruction of Historical Timestamps (BCK-03):** The server strips or ignores client order timestamps and assigns PostgreSQL `created_at = NOW()`. Syncing after an offline shift stamps all afternoon orders at the evening reconnect time, falsifying hourly sales distribution, distorting end-of-day Z-reports, and corrupting shift revenue calculations.
4. **Time-of-Check to Time-of-Use (TOCTOU) Concurrency Vulnerability (BCK-04):** Optimistic Concurrency Control (OCC) version checking is evaluated in Node.js heap memory rather than atomically within the SQL `UPDATE` statement. Concurrent updates under default PostgreSQL `ReadCommitted` isolation silently overwrite each other.
5. **Indiscriminate Shift Order Adoption and Order Cancellation (BCK-05):** Closing a shift queries all orders with `shift_id: null` within the shift's elapsed time window, forcibly attaches them to the closing shift, and automatically cancels any unpaid orders—destroying active dining or preparation orders created by other terminals or online dispatch.
6. **Multi-Register Store Lockout (BCK-06):** A PostgreSQL partial unique index (`unique_active_shift`) physically restricts the entire database to at most one active shift across all terminals, preventing multi-register stores from operating independent cash drawers.

---

## 1. Sync & Offline Endpoint Inventory

The following table summarizes every endpoint involved in offline synchronization, direct order placement, shift management, and table operations.

| Route | HTTP Method | Guard(s) | Idempotent? | Transactional? | Validates Totals? | Contract Summary & DTO |
|---|---|---|---|---|---|---|
| `/api/sync/push` | `POST` | `JwtAuthGuard` | **Yes** (via `IdempotencyInterceptor` & `SyncPushService`) | **Yes** (Per-mutation `prisma.$transaction`) | **No** (Accepts client grand total verbatim) | [`SyncPushDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L51-L64) with array of [`SyncMutationDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L13-L49). Returns batch results with per-mutation statuses. |
| `/api/sync/pull` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** (Single `findMany` query) | N/A | [`SyncPullDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-pull.dto.ts#L4-L22). Streams changes from `system_change_logs` where `global_sequence > cursor`. |
| `/api/sync/bootstrap` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** (Parallel `findMany` queries) | N/A | Query `raw?: string`. Returns full catalog, store settings, staff users, tables, and active shift snapshot (gzipped by default). |
| `/api/sync/overview` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Query `sync_status`, `order_type`, `search`. Legacy overview of cloud orders. |
| `/api/sync/order/:id` | `POST` | `JwtAuthGuard` | **No** (Flips boolean flag) | **No** | N/A | Single order sync status toggle. Updates `is_synced = true`. |
| `/api/sync/batch` | `POST` | `JwtAuthGuard` | **No** (Loop without transaction) | **No** (Iterative `prisma.order.update`) | N/A | [`BatchSyncOrdersDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-order.dto.ts#L3-L11). Legacy batch order flag flipper. |
| `/api/sync/toggle/:id` | `POST` | `JwtAuthGuard` | **No** | **No** | N/A | [`ToggleSyncStatusDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-order.dto.ts#L23-L27). Toggles `sync_status` column. |
| `/api/sync/log` | `POST` | `JwtAuthGuard` | **No** | **No** | N/A | [`CreateSyncLogDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-order.dto.ts#L29-L70). Appends row into legacy `data_sync_logs`. |
| `/api/sync/logs` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Reads latest 50 entries from legacy `data_sync_logs`. |
| `/api/sync/modules` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Static module sync health overview. |
| `/api/sync/history` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Paginated history from `data_sync_logs`. |
| `/api/sync/conflicts` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Returns pending conflict records. |
| `/api/sync/cashier-shifts` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Returns cashier's historical shifts. |
| `/api/sync/cashier-shift/:shiftId` | `GET` | `JwtAuthGuard` | **Yes** (Read-only) | **No** | N/A | Returns shift-first reconciliation metrics for cashier. |
| `/api/orders` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **Yes** (via `IdempotencyInterceptor`) | **Yes** (`prisma.$transaction`) | **No** (Client subtotal & grand total trusted) | [`CreateOrderDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/create-order.dto.ts#L83-L246). Cloud REST order creation path. |
| `/api/orders/:id` | `PATCH` | `JwtAuthGuard`, `PermissionsGuard` | **Yes** (via `IdempotencyInterceptor`) | **No** | **No** | [`UpdateOrderDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/update-order.dto.ts). Incremental order modification. |
| `/api/orders/:id/status` | `PATCH` | `JwtAuthGuard`, `PermissionsGuard` | **No** | **No** | N/A | [`UpdateOrderStatusDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/update-order-status.dto.ts). Status state transition. |
| `/api/orders/:id/cancel-item` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **No** | **Yes** (`tx.orderItem.update` + `tx.order.update`) | **Partial** (Recomputes grand total after line cancel) | Cancels single item on active order. |
| `/api/daily-calculation/start-session` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **Yes** (via `IdempotencyInterceptor`) | **No** | N/A | [`StartSessionDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/daily-calculation/dto/start-session.dto.ts). Opens or adjusts store cashier shift. |
| `/api/daily-calculation/submit` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **Yes** (via `IdempotencyInterceptor`) | **Yes** (`prisma.$transaction`) | **No** (Accepts reported variance) | [`SubmitDailyCalculationDto`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/daily-calculation/dto/submit-daily-calculation.dto.ts). Closes active shift session. |
| `/api/tables/:id/status` | `PATCH` | `JwtAuthGuard`, `PermissionsGuard` | **No** | **No** | N/A | Updates dining table status (`available`, `occupied`, `reserved`). |
| `/api/tables/:id/release` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **No** | **No** | N/A | Clears table occupancy and unlinks active order. |
| `/api/tables/transfer` | `POST` | `JwtAuthGuard`, `PermissionsGuard` | **No** | **Yes** (`prisma.$transaction`) | N/A | Transfers active order from one dining table to another. |

---

## 2. In-Depth Architectural Evaluation

### 2.1 Transactions & Isolation Semantics
- **Boundary Scope:** `SyncPushService.pushMutations()` ([`backend/src/sync/sync-push.service.ts:154`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L154)) wraps each mutation in an isolated `prisma.$transaction(async (tx) => handler.handle(tx, mutation, context))`.
- **Isolation Level:** Transactions run under the PostgreSQL default **`Read Committed`** isolation level. The code never specifies `isolationLevel: Prisma.TransactionIsolationLevel.Serializable` or `RepeatableRead`.
- **Partial Batch Writes:** If mutation 1 and 2 succeed, but mutation 3 fails, mutations 1 and 2 **remain committed**. This prevents a single malformed payload from poisoning the entire outbox batch.
- **Transaction Leak:** The recording of the idempotency token in `processed_operations` ([`sync-push.service.ts:183-208`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L183-L208)) occurs **after** the transaction commits. If the server crashes or worker terminates immediately following `tx` commit, the business data exists in the database, but the idempotency ledger does not record it. On reconnection, the client retries the mutation, causing an OCC conflict or duplicate processing.

### 2.2 DB Idempotency & Prisma Upsert Hazards
- **Idempotency Ledger:** Backed by `processed_operations` ([`backend/prisma/schema.prisma:650-665`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L650-L665)) with primary key `operation_id VARCHAR(36)`.
- **HTTP Interception:** `IdempotencyInterceptor` ([`backend/src/sync/interceptors/idempotency.interceptor.ts:71-150`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L71-L150)) checks for existing operations. If `COMPLETED`, it verifies `request_hash` (SHA-256) and returns the cached response.
- **In-Flight Lock:** If status is `PROCESSING` and `< 30s` old, it polls for completion up to 3 seconds ([`idempotency.interceptor.ts:240-254`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L240-L254)).
- **Fatal P2002 Bug:** When an `INSERT` fails due to a database unique constraint, `SyncPushService:259` catches `err.code === 'P2002'` and assumes it is a duplicate primary key. If the collision was on `order_number` or `token_number`, the transaction is rolled back, but the server replies `status: 'DUPLICATE'`, causing **silent order loss** (see [BCK-01](#bck-01-critical---false-positive-duplicate-recognition-on-unique-constraint-collisions-causes-permanent-silent-order-loss)).

### 2.3 Concurrency & Lock Contention
- **Row Locking:** No explicit row-level locking (`SELECT ... FOR UPDATE`) is used anywhere in the sync push handlers.
- **Check-Then-Act Race:** In `OrderHandler.handleUpdate`, `TableHandler.handleUpdate`, and `ShiftHandler.handleUpdate`, the handler performs a `findUnique` query, checks `currentVersion > mutation.base_version` in JavaScript, and then executes `update({ where: { id } })`. Under `Read Committed` isolation, two concurrent updates for the same entity will both pass the version check, resulting in a lost update (see [BCK-04](#bck-04-high---check-then-act-race-condition-in-optimistic-concurrency-control-occ-for-orders-tables-and-shifts)).

### 2.4 Data Validation & Financial Integrity
- **Item Prices:** `OrdersService.createOrderInTx()` ([`backend/src/orders/orders.service.ts:211-224`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L211-L224)) queries `tx.menuItem.findUnique` solely to verify the existence of the foreign key. It **never compares or validates** `item.unit_price` against `menuItem.base_price` or size multipliers.
- **Totals:** If `dto.subtotal` or `dto.grand_total` are provided by the client, the server assigns them directly ([`orders.service.ts:230, 259`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L230)).
- **Taxes:** The server accepts `dto.tax_amount` directly without recomputing from `StoreSetting.tax_percentage`.
- **Payments:** The server does not check whether `sum(payments.amount) == grand_total`. An order with `grand_total: 5000` can be submitted with `is_paid: true` and a payment record of `amount: 1.00`.

### 2.5 Batch Contract & Error Semantics
- **Status Envelope:** `POST /api/sync/push` always responds with HTTP 200 OK once the batch JSON is validated, returning an array of `results`.
- **Per-Item Status Codes:** `SYNCED`, `DUPLICATE`, `CONFLICT`, `FAILED_RETRYABLE`, `FAILED_FATAL`.
- **Defects:**
  1. The server maps unexpected database exceptions (e.g. transient query timeouts, lock contention) to `FAILED_FATAL` ([`sync-push.service.ts:292`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L292)), causing the client to permanently quarantine the order rather than retrying.
  2. Machine-readable error codes are inconsistent: `shift.handler.ts:187` returns `conflict_details.code`, `table.handler.ts:117` returns `conflict_details.conflict_code`, and `order.handler.ts:257` provides only a text message.
  3. Suffix-reassigned order numbers (`P1-101-1`) are not returned in the result payload.

### 2.6 Delta Pull Feed & Ordering Stability
- **Cursor Mechanism:** Ordered by monotonic `global_sequence > cursor` ASC ([`backend/src/sync/sync-pull.service.ts:48-52`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L48-L52)).
- **Sequence Race Condition:** PostgreSQL sequences generate values before transaction commit. A long transaction allocated sequence 100 committing after a fast transaction allocated sequence 101 will result in sequence 100 being skipped permanently by clients that polled while sequence 101 was active.
- **One-Way Replication:** `ChangeLogService.record()` is only invoked within sync push handlers. Direct cloud changes (menu updates, price changes, web portal edits) never write to `system_change_logs`.
- **Missing Echo Suppression Identity:** `SystemChangeLog` does not record `origin_device_id` ([`backend/prisma/schema.prisma:668-681`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L668-L681)), defeating client-side echo filtering.

### 2.7 Timestamps & Financial Reporting
- **Order Creation Time:** `CreateOrderDto` has no `created_at` field ([`backend/src/orders/dto/create-order.dto.ts:83-246`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/create-order.dto.ts#L83-L246)). `tx.order.create()` defaults to PostgreSQL `now()` ([`backend/src/orders/orders.service.ts:354`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L354)). All orders synced after being offline receive the sync timestamp instead of the actual order completion timestamp.
- **Report Distortion:** All sales reports ([`backend/src/reports/reports.service.ts:167, 457, 622`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/reports/reports.service.ts#L167)) filter by `order.created_at`. If offline orders are pushed after midnight, yesterday's sales are permanently credited to today's date.

### 2.8 Multi-Tenant & Branch Isolation
- **Tenant Scope:** The database models `Order`, `DailyCalculation`, `RestaurantTable`, and `ProcessedOperation` contain no `branch_id` or `tenant_id` foreign keys.
- **Store Settings:** `StoreSetting` ([`backend/prisma/schema.prisma:13-22`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L13-L22)) is a single global record.
- **Data Leakage Risk:** The backend functions strictly as a single-store database. Deploying multiple physical store locations against a shared database instance without schema partitioning will cause complete data crossover across branches.

### 2.9 Authentication & Device Identity
- **Guard Coverage:** `SyncController` is protected by `JwtAuthGuard` ([`backend/src/sync/sync.controller.ts:30`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync.controller.ts#L30)).
- **Deactivated Staff Vulnerability:** `JwtStrategy.validate()` ([`backend/src/auth/strategies/jwt.strategy.ts:26-34`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L34)) does not query `is_active`. Deactivated or terminated staff retain full API access until token expiration.
- **Device Identity:** No device registration, device certificate, or per-device token revocation exists.
- **Token Expiry Stall:** Tokens expire after 24 hours (`JWT_EXPIRES_IN: '1d'`) ([`backend/src/auth/auth.module.ts:23`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/auth.module.ts#L23)). Without a refresh token mechanism, terminals offline for > 24 hours halt sync in `AUTH_PAUSED`.

### 2.10 Load, Throttling & Connection Limits
- **Payload Limits:** `main.ts:31` sets `express.json({ limit: '10mb' })`.
- **Unbounded Batches:** `SyncPushDto.mutations` ([`backend/src/sync/dto/sync-push.dto.ts:60`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L60)) lacks an `@ArrayMaxSize()` decorator.
- **Rate Limiting:** NestJS `ThrottlerModule` is not installed or configured. Reconnecting multiple terminals simultaneously creates connection pool starvation on Prisma and PostgreSQL.
- **CORS Misconfiguration:** `main.ts:65` omits `X-Idempotency-Key` and `X-Device-Id` from `allowedHeaders`.

---

## 3. Findings Matrix

| Finding ID | Severity | Category | Title | Impact | Effort |
|---|---|---|---|---|---|
| **BCK-01** | **Critical** | Data Loss | False-Positive Duplicate on Unique Collisions Silently Drops Orders | Lost Orders / Lost Revenue | M |
| **BCK-02** | **Critical** | Validation | Server Trusts Client Unit Prices, Subtotals, and Grand Totals | Money / Pricing Fraud | M |
| **BCK-03** | **Critical** | Accounting | Order `created_at` Client Timestamp Stripped; Replaced by Server `NOW()` | Falsified Reports / Shift Accounting | S |
| **BCK-04** | **High** | Concurrency | Check-Then-Act Race Condition in Optimistic Concurrency Control | Lost Updates / State Overwrite | M |
| **BCK-05** | **High** | Data Integrity | Shift Close Adopts and Cancels Unrelated Unpaid Orders Across Time Window | Lost Orders / Forced Cancellations | M |
| **BCK-06** | **High** | Concurrency | Store-Wide Unique Active Shift Index Blocks Multi-Register Operations | Store Operations Blocked | M |
| **BCK-07** | **High** | Consistency | Reassigned Order Numbers from Collision Suffixing Never Returned to Client | Desynchronized Receipts & Audit | S |
| **BCK-08** | **High** | Security | Deactivated Staff Users Retain Valid JWT Access Due to Missing `is_active` | Unauthorized Access / Security Breach | S |
| **BCK-09** | **Medium** | Replication | Delta Pull Feed Misses Non-Push Cloud Modifications & Sequence Gaps | Stale Client Catalog / Missed Deltas | L |
| **BCK-10** | **Medium** | Replication | Change Log Omits `origin_device_id`, Defeating Client Echo Suppression | Redundant DB Churn / Processing Waste | S |
| **BCK-11** | **Medium** | Availability | Unbounded Push Batch Size & Zero Rate Limiting Exposes Connection Pool | Server Denial of Service / Timeouts | M |
| **BCK-12** | **Medium** | Networking | CORS Configuration Omits Sync Idempotency and Device Headers | Web POS Clients Blocked from Syncing | S |
| **BCK-13** | **Medium** | Performance | Missing Database Indexes on Foreign Keys and Composite Shift Lookups | Query Degradation / Database Locks | S |
| **BCK-14** | **Low** | Observability | Absence of Request Correlation IDs and Server-Side Dead-Letter Storage | Impaired Production Troubleshooting | M |
| **BCK-15** | **Low** | Architecture | Dual Disconnected Synchronization Log Ledgers in Database Schema | Fragmented Audit Trail | S |

---

## 4. Detailed Audit Findings

### BCK-01: False-Positive Duplicate Recognition on Unique Constraint Collisions Causes Permanent Silent Order Loss
- Severity: Critical
- Evidence: [`backend/src/sync/sync-push.service.ts:259-277`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L259-L277)
- Failure sequence:
  1. Terminal P1 operates offline and creates a takeaway order with token `TK-501` and client UUID `ord-111`.
  2. While P1 is offline, Terminal P2 or cloud creates an order which already consumed token `TK-501` or receipt number `P1-101`.
  3. Terminal P1 reconnects and pushes `ord-111` inside `POST /api/sync/push`.
  4. In `OrdersService.createOrderInTx()`, Prisma attempts `tx.takeawayOrderDetail.create()`, which throws PostgreSQL error `P2002` (Unique constraint failed on `token_number`).
  5. The error bubbles to `SyncPushService:258`. Line 259 checks:
     ```typescript
     const isDuplicatePrimaryKey =
       (err?.code === 'P2002' ||
         (err.message && err.message.includes('Unique constraint failed'))) &&
       mutation.operation_type === 'INSERT';
     ```
  6. Line 269 pushes `{ status: 'DUPLICATE' }` and adds `mutation.operation_id` to `completedInBatch`.
  7. The transaction for `ord-111` is rolled back completely in PostgreSQL.
  8. Terminal P1 receives `status: 'DUPLICATE'`, marks the order as successfully synced in SQLite, and purges it from the outbox.
  9. **Result:** The order does not exist in PostgreSQL. The customer paid, but the kitchen never receives the ticket and management has no record of the sale.
- Impact: Lost order, lost revenue.
- Recommended fix: Inspect `err.meta.target` on Prisma `P2002` exceptions. Only treat the mutation as `DUPLICATE` if the violated unique field is strictly the primary key `id`. For collisions on `order_number` or `token_number`, auto-suffix the colliding field within the transaction or return `CONFLICT`.
- Effort: M
- Status: CONFIRMED

---

### BCK-02: Server Blindly Trusts Client Unit Prices, Subtotals, and Grand Totals Without Menu Recomputation
- Severity: Critical
- Evidence: [`backend/src/orders/orders.service.ts:211-262`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L211-L262), [`backend/src/sync/handlers/order.handler.ts:100-151`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L100-L151)
- Failure sequence:
  1. A malicious user or modified client device submits an offline order payload via `POST /api/sync/push`.
  2. The payload contains 5 large gourmet pizzas (`menu_item_id` valid), but sets `unit_price: 1.00`, `subtotal: 5.00`, and `grand_total: 5.00`.
  3. `OrderHandler.handleInsert()` maps client prices directly into `CreateOrderDto`.
  4. `OrdersService.createOrderInTx()` queries `tx.menuItem.findUnique()` at line 216, but only checks if the item exists; it never compares `unit_price` against `menuItem.base_price`.
  5. At line 230: `const subtotal = dto.subtotal !== undefined ? this.round(dto.subtotal) : calculatedSubtotal;`. The server accepts the client's `subtotal: 5.00`.
  6. At line 259: `const grandTotal = dto.grand_total !== undefined ? this.round(dto.grand_total) : ...`. The server accepts `grand_total: 5.00`.
  7. At line 448: `orderItem.createMany` persists `unit_price: 1.00` and `total_price: 5.00`.
- Impact: Lost money, pricing fraud, inventory deduction without proper revenue.
- Recommended fix: Recompute `subtotal`, discounts, taxes, and `grand_total` server-side from `MenuItem.base_price`, size variations, and `StoreSetting.tax_percentage`. Reject mutations or flag supervisor audit when client-sent prices deviate beyond rounding tolerance ($> \pm 0.05$).
- Effort: M
- Status: CONFIRMED

---

### BCK-03: Order `created_at` Client Timestamp Stripped; Replaced by Server `NOW()`
- Severity: Critical
- Evidence: [`backend/src/orders/orders.service.ts:354-374`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L354-L374), [`backend/src/orders/dto/create-order.dto.ts:83-246`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/create-order.dto.ts#L83-L246), [`backend/src/sync/handlers/order.handler.ts:94-167`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L94-L167)
- Failure sequence:
  1. A store loses internet connectivity from 12:00 PM to 4:00 PM (lunch rush).
  2. Cashiers process and complete 80 orders locally with valid client timestamps (`2026-10-26T12:15:00Z`, etc.).
  3. Internet is restored at 7:00 PM. Background sync worker pushes the 80 orders.
  4. `OrderHandler.handleInsert()` maps the payload to `CreateOrderDto`. `CreateOrderDto` has no `created_at` property; NestJS `ValidationPipe` whitelist strips it if passed.
  5. `OrdersService.createOrderInTx()` calls `tx.order.create()` without passing `created_at`.
  6. PostgreSQL `@default(now())` populates `created_at` as `2026-10-26T19:00:00Z` for all 80 lunch orders.
  7. Management executes the Lunch Sales Report (12:00 PM – 4:00 PM): the report returns **PKR 0.00**.
  8. The Evening Sales Report (7:00 PM – 8:00 PM) reflects an unnatural surge containing 80 lunch pizzas.
  9. If reconnection occurs the following morning, Friday's sales are credited to Saturday's revenue.
- Impact: Falsified financial reports, corrupt sales tax reporting, inaccurate shift balancing.
- Recommended fix: Add `created_at?: string` to `CreateOrderDto`, map `payload.created_at` in `OrderHandler.handleInsert()`, and pass `created_at: dto.created_at ? new Date(dto.created_at) : new Date()` to `tx.order.create()` and `tx.orderPayment.createMany()`.
- Effort: S
- Status: CONFIRMED

---

### BCK-04: Check-Then-Act Race Condition in Optimistic Concurrency Control (OCC) for Orders, Tables, and Shifts
- Severity: High
- Evidence: [`backend/src/sync/handlers/order.handler.ts:243-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L243-L279), [`backend/src/sync/handlers/table.handler.ts:235-314`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/table.handler.ts#L235-L314), [`backend/src/sync/handlers/shift.handler.ts:331-470`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L331-L470)
- Failure sequence:
  1. An order exists in PostgreSQL at `version: 1`.
  2. Device A and Device B both submit updates (`operation_type: 'UPDATE'`) with `base_version: 1` almost simultaneously.
  3. Device A transaction begins: `tx.order.findUnique` reads `version: 1`. Condition `currentVersion > mutation.base_version` (1 > 1) is `false`.
  4. Device B transaction begins concurrently: `tx.order.findUnique` also reads `version: 1`. Check passes.
  5. Device A executes `tx.order.update({ where: { id }, data: { status: 'accepted', version: { increment: 1 } } })` and commits (`version: 2`).
  6. Device B executes `tx.order.update({ where: { id }, data: { status: 'cancelled', version: { increment: 1 } } })`. Because the `WHERE` clause only filters by `id`, it succeeds and commits (`version: 3`).
  7. Neither transaction detected a conflict, and Device B silently overwrote Device A's update.
- Impact: Lost updates, state overwrite, broken OCC guarantee.
- Recommended fix: Enforce atomic conditional updates using Prisma or raw SQL:
  ```typescript
  const count = await tx.order.updateMany({
    where: { id: orderId, version: mutation.base_version },
    data: { ...updateData, version: { increment: 1 } }
  });
  if (count.count === 0) throw new ConflictException('OCC Version Conflict');
  ```
- Effort: M
- Status: CONFIRMED

---

### BCK-05: Shift Close Adopts and Cancels Unrelated Unpaid Orders Across Time Window
- Severity: High
- Evidence: [`backend/src/sync/handlers/shift.handler.ts:351-386`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L351-L386)
- Failure sequence:
  1. Cashier A opens Shift 1 at 8:00 AM on Register 1.
  2. Cashier B opens a dining session on Table 4 at 1:30 PM with an order marked `is_paid: false`.
  3. Online orders arrive from the mobile app without an assigned `shift_id` (`shift_id: null`).
  4. Cashier A closes Shift 1 at 2:00 PM.
  5. In `ShiftHandler.handleUpdate()`:
     - Lines 352-368 execute `tx.order.updateMany` where `shift_id: null` and `created_at >= existing.created_at`, stamping Cashier A's `shift_id` on all online orders and dining orders.
     - Lines 380-386 execute:
       ```typescript
       await tx.order.updateMany({
         where: {
           shift_id: existing.id,
           status: { notIn: ['completed', 'cancelled', 'rejected'] },
           is_paid: false,
         },
         data: { status: 'cancelled' },
       });
       ```
  6. Dining Table 4's active order—which was still dining—is abruptly set to `status: 'cancelled'`.
- Impact: Lost orders, unauthorized cancellation of active dining and kitchen orders.
- Recommended fix: Never adopt unassigned orders by timestamp range during shift close. Restrict shift close reconciliation strictly to orders explicitly tagged with that `shift_id`. Never auto-cancel unpaid orders; instead, return a conflict or unassign them from the closing shift.
- Effort: M
- Status: CONFIRMED

---

### BCK-06: Store-Wide Unique Active Shift Index Blocks Multi-Register Operations
- Severity: High
- Evidence: [`backend/prisma/migrations/20261023120000_unique_active_shift/migration.sql:16-17`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/migrations/20261023120000_unique_active_shift/migration.sql#L16-L17), [`backend/src/sync/handlers/shift.handler.ts:131-192`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L131-L192), [`backend/src/daily-calculation/daily-calculation.service.ts:113-145`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/daily-calculation/daily-calculation.service.ts#L113-L145)
- Failure sequence:
  1. A store has two physical POS terminals (Register 1 and Register 2).
  2. Cashier 1 on Register 1 opens an active shift. PostgreSQL inserts row with `status = 'ACTIVE'`.
  3. Cashier 2 on Register 2 attempts to open their cashier shift.
  4. In `ShiftHandler.handleInsert()` line 133: `tx.dailyCalculation.findFirst({ where: { status: 'ACTIVE' } })` finds Register 1's shift.
  5. The handler rejects Register 2's shift with `status: 'CONFLICT', conflict_details: { code: 'ACTIVE_SHIFT_EXISTS' }` and forces Register 2's shift into `OFFLINE_CLOSED`.
  6. Even if the service logic were bypassed, PostgreSQL migration `20261023120000_unique_active_shift` enforces:
     `CREATE UNIQUE INDEX "unique_active_shift" ON "daily_calculations" ("status") WHERE "status" = 'ACTIVE';`
  7. Register 2 throws a unique constraint violation.
- Impact: Store operations blocked; multiple registers cannot operate independent shifts.
- Recommended fix: Add `device_id VARCHAR(50)` to `daily_calculations` and change the unique constraint to `CREATE UNIQUE INDEX unique_active_shift_per_device ON daily_calculations (device_id, status) WHERE status = 'ACTIVE';`.
- Effort: M
- Status: CONFIRMED

---

### BCK-07: Reassigned Order Numbers from Collision Suffixing Never Returned to Client
- Severity: High
- Evidence: [`backend/src/orders/orders.service.ts:305-315`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L305-L315), [`backend/src/sync/handlers/order.handler.ts:206-212`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L206-L212)
- Failure sequence:
  1. Terminal P1 operates offline and assigns order number `P1-101`.
  2. Due to terminal sequence reset or previous collision, `P1-101` already exists in PostgreSQL.
  3. When P1 pushes the order, `OrdersService.createOrderInTx()` detects the collision and suffixes the order number to `P1-101-1`.
  4. In `OrderHandler.handleInsert()` lines 206-212:
     ```typescript
     return {
       operation_id: mutation.operation_id,
       entity_id: createdOrder.id,
       status: 'SYNCED',
       server_version: version,
       server_timestamp: updatedAt.toISOString(),
     };
     ```
  5. The result contains no field indicating the order number was changed.
  6. Terminal P1 marks the order synced. SQLite retains `P1-101`.
  7. When the customer calls regarding order `P1-101`, the cloud portal cannot find it because it is stored as `P1-101-1`.
- Impact: Customer support confusion, order tracking mismatches.
- Recommended fix: Extend `SyncMutationResult` to include `reassigned_order_number?: string` and update client `LocalOrders` on push acknowledgment.
- Effort: S
- Status: CONFIRMED

---

### BCK-08: Deactivated Staff Users Retain Valid JWT Access Due to Missing `is_active` Check
- Severity: High
- Evidence: [`backend/src/auth/strategies/jwt.strategy.ts:25-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L25-L41)
- Failure sequence:
  1. An employee is terminated. An administrator sets `is_active = false` on their record in `staff_users`.
  2. The terminated employee still possesses their active JWT token issued earlier that day.
  3. The employee sends a request to `POST /api/sync/push` or `GET /api/sync/pull`.
  4. `JwtStrategy.validate()` executes:
     ```typescript
     const user = await this.prisma.staffUser.findUnique({
       where: { id: payload.sub },
       select: { id: true, username: true, role: true, is_default: true },
     });
     ```
  5. Because `is_active` is neither selected nor checked, the strategy returns `user` as valid.
  6. The terminated employee continues reading and writing sync mutations for up to 24 hours.
- Impact: Security breach, unauthorized data push/pull by revoked employees.
- Recommended fix: Select `is_active: true` in `JwtStrategy.validate()` and throw `UnauthorizedException('User account is deactivated')` if `user.is_active === false`.
- Effort: S
- Status: CONFIRMED

---

### BCK-09: Delta Pull Feed Misses Non-Push Cloud Modifications & Sequence Gaps
- Severity: Medium
- Evidence: [`backend/src/sync/change-log.service.ts:15-41`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/change-log.service.ts#L15-L41), [`backend/src/sync/sync-pull.service.ts:48-52`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-pull.service.ts#L48-L52)
- Failure sequence:
  1. A store manager updates pizza prices and marks an ingredient out-of-stock via the Web Admin Portal (`/api/menu/items/:id`).
  2. `MenuItemsService` updates PostgreSQL directly via Prisma.
  3. No call to `ChangeLogService.record()` is executed.
  4. A POS terminal polls `GET /api/sync/pull?cursor=500`.
  5. The server queries `system_change_logs.findMany({ where: { global_sequence: { gt: 500 } } })`.
  6. The server returns 0 changes.
  7. The POS terminal continues selling the item at obsolete prices indefinitely until an application reinstall forces bootstrap.
- Impact: Stale client catalog, pricing discrepancies, selling out-of-stock items.
- Recommended fix: Implement database triggers on PostgreSQL tables (`menu_items`, `restaurant_tables`, `staff_users`, `store_settings`) or Prisma client extension middleware to auto-insert into `system_change_logs` on all mutations regardless of caller.
- Effort: L
- Status: CONFIRMED

---

### BCK-10: Change Log Omits `origin_device_id`, Defeating Client Echo Suppression
- Severity: Medium
- Evidence: [`backend/src/sync/handlers/order.handler.ts:181-204`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L181-L204), [`backend/src/sync/handlers/shift.handler.ts:219-237`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L219-L237), [`backend/src/sync/handlers/table.handler.ts:151-172`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/table.handler.ts#L151-L172), [`backend/prisma/schema.prisma:668-681`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L668-L681)
- Failure sequence:
  1. Terminal P1 pushes an order mutation via `POST /api/sync/push`.
  2. `OrderHandler` records a change log entry in `system_change_logs`. Neither `device_id` nor `origin_device_id` is included in the payload.
  3. Terminal P1 executes periodic delta pull (`GET /api/sync/pull`).
  4. Terminal P1 receives the change log for the order it just created.
  5. In `SyncBackgroundWorker._applyPullChange()`, echo suppression check `payload['origin_device_id'] == deviceId` fails because the field is undefined.
  6. Terminal P1 is forced to re-query local SQLite, run OCC checks, and re-persist its own order.
- Impact: Redundant local processing, unnecessary SQLite write cycles and lock contention on Windows desktop client.
- Recommended fix: Add `origin_device_id` to `system_change_logs` schema and inject `context.deviceId` inside `ChangeLogService.record()`.
- Effort: S
- Status: CONFIRMED

---

### BCK-11: Unbounded Push Batch Size & Zero Rate Limiting Exposes Connection Pool
- Severity: Medium
- Evidence: [`backend/src/sync/dto/sync-push.dto.ts:60-63`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L60-L63), [`backend/src/main.ts:31-47`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L31-L47), [`backend/src/app.module.ts:28-58`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/app.module.ts#L28-L58)
- Failure sequence:
  1. Following a multi-hour network outage, 5 terminals reconnect simultaneously.
  2. Each terminal pushes an unconstrained batch of mutations to `POST /api/sync/push`.
  3. `SyncPushService` processes each mutation in a dedicated `$transaction`.
  4. Prisma connection pool (default ~10 connections) is saturated immediately.
  5. Reconnecting clients encounter database connection timeouts (`Timed out fetching a new connection from the connection pool`), triggering HTTP 500/504 errors.
  6. Clients trip their local circuit breakers, pausing synchronization for 30 seconds.
- Impact: Server denial of service on reconnect, sync engine stall.
- Recommended fix: Add `@ArrayMaxSize(50)` to `SyncPushDto.mutations`, configure NestJS `ThrottlerModule` with rate limits on `/api/sync/*`, and increase Prisma connection pool size.
- Effort: M
- Status: CONFIRMED

---

### BCK-12: CORS Configuration Omits Sync Idempotency and Device Headers
- Severity: Medium
- Evidence: [`backend/src/main.ts:61-66`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L61-L66)
- Failure sequence:
  1. A cashier operates Hungry Howie's POS via a web browser or Electron cross-origin client.
  2. The browser initiates a push request with header `X-Idempotency-Key: <uuid>` or `X-Device-Id: POS-P1`.
  3. The browser sends an HTTP `OPTIONS` preflight request.
  4. In `main.ts:65`:
     ```typescript
     allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With']
     ```
  5. The CORS preflight is rejected because `X-Idempotency-Key` and `X-Device-Id` are not in `allowedHeaders`.
  6. The sync push request fails before reaching `SyncController`.
- Impact: Web-based POS clients blocked from syncing.
- Recommended fix: Include `X-Idempotency-Key`, `Idempotency-Key`, and `X-Device-Id` in `allowedHeaders`.
- Effort: S
- Status: CONFIRMED

---

### BCK-13: Missing Database Indexes on Foreign Keys and Composite Shift Lookups
- Severity: Medium
- Evidence: [`backend/prisma/schema.prisma:401-447`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L401-L447), [`backend/src/sync/handlers/shift.handler.ts:370-397`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L370-L397)
- Failure sequence:
  1. PostgreSQL does not automatically create indexes on foreign key columns.
  2. Models `OrderItem` and `OrderPayment` have no indexes on `order_id`.
  3. When an order is deleted, updated, or queried with `include: { order_items: true, payments: true }`, PostgreSQL performs a sequential scan over `order_items` and `order_payments`.
  4. In `shift.handler.ts:371, 380, 390`, queries filter on `shift_id` and `status`. Only a single-column index on `shift_id` exists, requiring bitmap heap scans.
  5. `SystemChangeLog` defines `@@index([global_sequence])`, which is redundant because `global_sequence` is already the primary key index.
- Impact: Query degradation and lock contention as order volume increases.
- Recommended fix: Add missing foreign key indexes and composite indexes as detailed in [Section 5](#5-database-constraints--indexes-gap-analysis).
- Effort: S
- Status: CONFIRMED

---

### BCK-14: Absence of Request Correlation IDs and Server-Side Dead-Letter Storage
- Severity: Low
- Evidence: [`backend/src/sync/sync-push.service.ts:279-297`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L279-L297), [`backend/src/sync/interceptors/idempotency.interceptor.ts:1-282`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L1-L282)
- Failure sequence:
  1. A mutation fails with `FAILED_FATAL` on the backend.
  2. The failure details are logged to standard output via `this.logger.error`.
  3. No row is recorded in `processed_operations` or any dead-letter table.
  4. The client receives the failure in HTTP response, but if the client terminal crashes before persisting the conflict, all evidence of the fatal failure payload is lost from durable storage.
  5. No `X-Correlation-Id` is passed or logged across HTTP requests.
- Impact: Impaired production troubleshooting, support cannot trace a specific mutation from client outbox to backend logs.
- Recommended fix: Implement a NestJS correlation ID middleware and persist `FAILED_FATAL` mutations into a PostgreSQL `sync_dead_letter` table.
- Effort: M
- Status: CONFIRMED

---

### BCK-15: Dual Disconnected Synchronization Log Ledgers in Database Schema
- Severity: Low
- Evidence: [`backend/prisma/schema.prisma:627-643`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L627-L643), [`backend/prisma/schema.prisma:650-681`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L650-L681), [`backend/src/sync/sync.controller.ts:123-133`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync.controller.ts#L123-L133)
- Failure sequence:
  1. The schema defines `DataSyncLog` (`data_sync_logs`), populated by legacy endpoints `/api/sync/log`.
  2. The offline sync engine uses `ProcessedOperation` (`processed_operations`) and `SystemChangeLog` (`system_change_logs`).
  3. The legacy sync history screen (`/api/sync/history`) queries `data_sync_logs`, showing zero entries for offline mutations ingested through `POST /api/sync/push`.
- Impact: Fragmented audit trail, developer confusion.
- Recommended fix: Deprecate `data_sync_logs` and point all sync history reporting endpoints to `system_change_logs` and `processed_operations`.
- Effort: S
- Status: CONFIRMED

---

## 5. Database Constraints & Indexes Gap Analysis

The following constraints and indexes are currently missing from `backend/prisma/schema.prisma` and must be applied via a Prisma migration:

### 5.1 Missing Index & Constraint Inventory

| Model | Target Column(s) | Type | Purpose / Justification |
|---|---|---|---|
| `OrderItem` | `[order_id]` | `INDEX` | Eliminates sequential scan when fetching order items or cascading deletes. |
| `OrderItem` | `[menu_item_id]` | `INDEX` | Accelerates foreign key joins and catalog usage queries. |
| `OrderPayment` | `[order_id]` | `INDEX` | Eliminates sequential scan during order lookup and shift financial calculations. |
| `OrderPayment` | `[payment_method]` | `INDEX` | Speeds up shift payment aggregation by tender method (`cash`, `card`, `online`). |
| `DineInOrderDetail` | `[table_id]` | `INDEX` | Accelerates dining table occupancy queries in `TableHandler`. |
| `OnlineOrderDetail` | `[customer_id]` | `INDEX` | Speeds up customer order history queries. |
| `TakeawayOrderDetail` | `[customer_id]` | `INDEX` | Speeds up customer takeaway lookup. |
| `Order` | `[shift_id, status]` | `COMPOSITE INDEX` | Optimizes `ShiftHandler` queries fetching non-completed orders for shift reconciliation. |
| `Order` | `[created_at, status]` | `COMPOSITE INDEX` | Accelerates live sales summaries and end-of-day Z-reports. |
| `Order` | `[updated_at]` | `INDEX` | Speeds up incremental delta queries for orders. |
| `DailyCalculation` | `[device_id, status]` | `PARTIAL UNIQUE INDEX` | Replaces single store-wide `unique_active_shift` to permit concurrent multi-register shifts. |
| `ProcessedOperation` | `[status, created_at]` | `COMPOSITE INDEX` | Optimizes cleanup of stale `PROCESSING` locks older than 30 seconds. |
| `SystemChangeLog` | `[created_at]` | `INDEX` | Supports automated retention pruning for change log entries older than 30 days. |
| `SystemChangeLog` | `[global_sequence]` | `REMOVE INDEX` | Redundant index; already indexed by primary key `system_change_logs_pkey`. |

### 5.2 Prisma Schema Remediation Snippet

```prisma
// ── OrderItem additions ───────────────────────────────────────
model OrderItem {
  // ... existing fields ...

  @@index([order_id])
  @@index([menu_item_id])
  @@map("order_items")
}

// ── OrderPayment additions ────────────────────────────────────
model OrderPayment {
  // ... existing fields ...

  @@index([order_id])
  @@index([payment_method])
  @@map("order_payments")
}

// ── DineInOrderDetail additions ───────────────────────────────
model DineInOrderDetail {
  // ... existing fields ...

  @@index([table_id])
  @@map("dine_in_order_details")
}

// ── Order additions ───────────────────────────────────────────
model Order {
  // ... existing fields ...

  @@index([shift_id, status])
  @@index([created_at, status])
  @@index([updated_at])
  @@map("orders")
}

// ── DailyCalculation additions ────────────────────────────────
model DailyCalculation {
  id             String    @id @default(uuid()) @db.VarChar(36)
  device_id      String    @default("POS-P1") @map("device_id") @db.VarChar(50)
  // ... existing fields ...

  @@index([device_id, status])
  @@map("daily_calculations")
}

// ── ProcessedOperation additions ──────────────────────────────
model ProcessedOperation {
  // ... existing fields ...

  @@index([status, created_at])
  @@map("processed_operations")
}

// ── SystemChangeLog remediation ───────────────────────────────
model SystemChangeLog {
  global_sequence  BigInt    @id @default(autoincrement())
  origin_device_id String?   @map("origin_device_id") @db.VarChar(50)
  // ... existing fields ...

  // REMOVE: @@index([global_sequence])  <-- Redundant with PK
  @@index([created_at])
  @@index([entity_type, entity_id])
  @@map("system_change_logs")
}
```

---

## 6. Verification & Audit Trail

| Verification Item | Command / Code Location | Result |
|---|---|---|
| Handlers Registry | [`backend/src/sync/handlers/handler-registry.service.ts:1-46`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/handler-registry.service.ts#L1-L46) | CONFIRMED: Registers `order`, `shift`, `table`, and `restaurant_table`. |
| P2002 False Duplicate | [`backend/src/sync/sync-push.service.ts:259-277`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L259-L277) | CONFIRMED: Catches any P2002 on INSERT as `DUPLICATE`. |
| Order Timestamp Stripping | [`backend/src/orders/dto/create-order.dto.ts:83-246`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/dto/create-order.dto.ts#L83-L246) | CONFIRMED: `CreateOrderDto` has no `created_at` property. |
| Inactive Staff JWT Validation | [`backend/src/auth/strategies/jwt.strategy.ts:26-34`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/auth/strategies/jwt.strategy.ts#L26-L34) | CONFIRMED: `is_active` omitted from query select. |
| Unique Active Shift Index | [`backend/prisma/migrations/20261023120000_unique_active_shift/migration.sql:16`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/migrations/20261023120000_unique_active_shift/migration.sql#L16) | CONFIRMED: Partial unique index blocks > 1 active shift store-wide. |
| CORS Header Exclusion | [`backend/src/main.ts:65`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/main.ts#L65) | CONFIRMED: `X-Idempotency-Key` missing from CORS allowed headers. |
| Change Log Exclusion | [`backend/src/sync/change-log.service.ts:15`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/change-log.service.ts#L15) | CONFIRMED: Only called inside `order.handler.ts`, `shift.handler.ts`, `table.handler.ts`. |
