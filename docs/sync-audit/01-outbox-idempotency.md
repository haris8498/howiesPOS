# 01 - Outbox and Idempotency Audit: Hungry Howie's POS

> **Audit Role:** Outbox and Idempotency Auditor (`.agents/outbox-idempotency-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop + NestJS / Prisma / PostgreSQL Backend)  
> **Reference Specification:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`  
> **Architecture Baseline:** `docs/sync-audit/00-architecture-map.md`  
> **Output Finding Prefix:** `OBX`  
> **Date:** October 26, 2026  
> **Status:** Completed Authoritative Audit  

---

## Executive Summary

This audit evaluates the reliability, transactional integrity, mutation ordering, retry mechanics, poison message isolation, and idempotency guarantees across the offline synchronization subsystem in Hungry Howie's POS. Every claim and vulnerability documented herein is substantiated by exact source code citations (`file:line`).

### High-Level Verdict
The synchronization engine demonstrates robust core design patterns in several foundational areas:
- **Order Creation Durability:** Client order checkout (`OrdersDao.saveOrderAtomic`) encapsulates order header, line items, payments, outbox mutation, and print job into **one atomic ACID SQLite transaction** in WAL mode (`orders_dao.dart:23-43`).
- **Immutable Birth Identity:** Primary keys for orders, items, payments, and shifts are generated client-side using **RFC 9562 UUID v7** identifiers (`drift_offline_first_order_repository.dart:81`), preventing identity mapping collisions.
- **Server Idempotency Infrastructure:** The NestJS backend provides an dedicated `IdempotencyInterceptor` (`idempotency.interceptor.ts:71-205`) backed by a PostgreSQL database table (`processed_operations`), coupled with primary key duplicate detection (`order.handler.ts:68`, `sync-push.service.ts:259`).

However, **critical failure modes exist** that can cause **lost orders, permanently stalled sync queues, false-positive fatal quarantines, out-of-order data corruption, and financial misallocation**:
1. **Out-of-Order Entity Replay (OBX-03):** If an order `INSERT` fails retryably and enters backoff, `getPushBatch()` skips the backoff entry but picks up subsequent `UPDATE` mutations for the same order. The server rejects the premature update as `FAILED_FATAL` ("Order not found"), permanently quarantining the update.
2. **Batch Poisoning on HTTP 4xx (OBX-04):** If a single malformed mutation causes the server to return HTTP 400 (e.g. class-validator payload failure), `SyncBackgroundWorker._handleFatalBatch` marks **all 25 mutations** in that batch as `FAILED_FATAL`, killing up to 24 innocent transactions.
3. **Premature Fatal Error Quarantine (OBX-05):** In `SyncPushService.pushMutations`, any unexpected exception thrown during database execution (e.g., query timeout, connection pool exhaustion) defaults to `status: 'FAILED_FATAL'` instead of retryable, causing transient server glitches to permanently quarantine offline orders.
4. **Startup Zombie Task Trap (OBX-02):** If an app crash occurs and the cashier restarts the POS in under 60 seconds (standard operational behavior), `recoverOrphanedOutboxTasks` skips the in-flight rows because `sentAt` is not older than 60s. Because the task is never checked periodically, the rows remain stuck `IN_FLIGHT` indefinitely for that entire session.
5. **Silent Shift Unlinking & Revenue Hijacking (OBX-07):** In `OrdersService.createOrderInTx`, if an offline order is pushed before its shift open record exists in PostgreSQL, the server silently nullifies `shift_id` and reattaches the order to **any other active shift** found on the server, corrupting cash drawer reconciliation.
6. **Non-Atomic Secondary Business Writes (OBX-01):** Order status updates (`updateOrderStatus`) and cancellations execute Drift updates and outbox insertions sequentially outside of a transaction. An app kill between statements leaves a local state change that will never sync.
7. **Unindexed Table Drain Bottleneck (OBX-09):** `SyncOutbox` has zero database indexes on `(status, dependency_order, created_at)`. Processing 5,000 backlogged rows requires 200 unindexed full table scans while loading thousands of full JSON payloads on the main UI thread.

---

## 1. Checklist Deep Dive

### 1. Atomicity
*Question: Is the local business write and the outbox insert in ONE Drift transaction? Can an order exist locally without an outbox row, or the reverse?*

- **Order Checkout (`saveOrder`):** Fully atomic. In [`drift_offline_first_order_repository.dart:69-244`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L69-L244), `_db.transaction()` invokes `OrdersDao.saveOrderAtomic()`, which inserts `local_orders`, `local_order_items`, `local_order_payments`, `sync_outbox`, and `offline_print_jobs` in a single SQLite transaction. If any insert throws or the app crashes, the entire transaction rolls back cleanly.
- **Shift Open & Close:** Fully atomic. In [`drift_offline_first_shift_repository.dart:67-120`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L67-L120) and [`lines 137-281`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L137-L281), `openShift` and `closeShift` encapsulate both the `local_daily_calculations` DAO insert/update and the `sync_outbox` insert inside `_db.transaction()`.
- **CRITICAL ATOMICITY GAPS (OBX-01):**
  - **`updateOrderStatus`:** In [`drift_offline_first_order_repository.dart:407-434`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L407-L434), line 408 updates `local_orders` row. Line 418 inserts `syncOutbox`. There is **no wrapping transaction**. If the app crashes between lines 414 and 418, the local order reflects the new status, but no outbox mutation is ever queued. The server never receives the status change.
  - **`deleteHeldOrder`:** In [`drift_offline_first_order_repository.dart:442-466`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L442-L466), line 443 marks `local_orders.isDeleted = true`. Line 452 inserts `syncOutbox`. There is **no transaction**. A process kill between lines 449 and 452 produces an orphaned local deletion.
  - **`updateTableStatus` & `updateTableBillAndStatus`:** In [`table_repository.dart:211-236, 274-295`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L211-L236), local table updates and outbox inserts execute without a transaction.

---

### 2. Ordering
*Question: Are dependent operations (create order -> add items -> payment -> close) replayed in order? Per-entity ordering vs global FIFO. Can a payment sync before its order?*

- **Order Items & Payments:** In Hungry Howie's POS, order items and payments are **not** separate outbox operations. They are serialized directly into the single order creation payload via `OrderModel.toCreateOrderDto()` ([`drift_offline_first_order_repository.dart:202-217`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L202-L217)). Thus, payments and items cannot sync before the initial order.
- **Topological Sorting Across Entities:** The system uses 7 dependency levels (Level 0: Shift Open, Level 1: Customer/Table, Level 2: Order Header/Update, Level 3: Table Status, Level 5: Shift Close). Batch selection enforces `ORDER BY dependency_order ASC, created_at ASC` ([`outbox_dao.dart:29-32`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/outbox_dao.dart#L29-L32)).
- **CRITICAL ORDERING DEFECT (OBX-03): Global FIFO Without Per-Entity Dependency:**
  - Both Order `INSERT` and Order `UPDATE` have `dependencyOrder = 2`.
  - When an Order `INSERT` fails due to a network timeout, `_handleNetworkFailure` marks it `FAILED_RETRYABLE` with `nextRetryAt = now + 4s`.
  - In the subsequent sync cycle 1 second later, `outboxDao.getPushBatch` runs:
    ```sql
    WHERE status = 'PENDING' OR (status = 'FAILED_RETRYABLE' AND nextRetryAt <= now)
    ```
  - The `INSERT` is excluded because `nextRetryAt > now`.
  - The subsequent `UPDATE` for that same order is still `PENDING`, so it is **included in the push batch**!
  - The client pushes `UPDATE` for `order_1` before `INSERT` has succeeded.
  - The backend (`order.handler.ts:231-240`) searches for `order_1`, finds nothing, and returns `status: 'FAILED_FATAL'` ("Order not found for update").
  - The client marks the update as fatally failed and quarantines it. The order status update is permanently lost.

---

### 3. Dependency Failure
*Question: If the "create order" item fails permanently, what happens to its child items and payment? Orphans? Infinite retry?*

- **Child Items & Payments:** Because items and payments are contained within the `order` JSON payload, if the `INSERT order` mutation fails fatally, all items and payments fail together atomically within that transaction.
- **CRITICAL INFINITE RETRY DEFECT (OBX-06): Unsynced Dependency Deadlock:**
  - In [`drift_offline_first_shift_repository.dart:221-231`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L221-L231), `closeShift` sets `dependsOnOperationId` to the last pending mutation in `sync_outbox`.
  - If that referenced mutation fails permanently with `FAILED_FATAL` or `CONFLICT`:
  - On the backend, `SyncPushService.pushMutations` ([`sync-push.service.ts:100-126`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L100-L126)) and `ShiftHandler.handleUpdate` ([`shift.handler.ts:259-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L259-L279)) check:
    ```typescript
    if (!dep || dep.status !== 'COMPLETED') {
      return { status: 'FAILED_RETRYABLE', error_message: 'Unsynced dependency...' };
    }
    ```
  - Because the parent mutation failed permanently, it will **never** achieve status `COMPLETED`.
  - The server continuously returns `FAILED_RETRYABLE` for the dependent shift close.
  - The client receives `FAILED_RETRYABLE`, increments `retryCount`, backs off, and **retries indefinitely forever**.
  - There is zero dependency cascade failure logic on client or server. The dependent mutation is deadlocked in an infinite retry loop, causing repeated circuit breaker trips.

---

### 4. Retry and Backoff
*Question: Max attempts, jitter, status transitions (pending/in-flight/failed/dead). Can an item get stuck `in-flight` forever after an app kill?*

- **Formula & Jitter:** Exponential backoff with uniform jitter is implemented in [`sync_background_worker.dart:690-695`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L690-L695):
  $$\text{baseDelay} = \min(300.0, 2.0 \times 2^{\text{retryCount}})$$
  $$\text{jitter} = 0.75 + 0.5 \times \text{random}() \quad [0.75..1.25]$$
  $$\text{delaySeconds} = \text{baseDelay} \times \text{jitter}$$
- **Max Retries:** Unlimited per Developer Directive Q7.3. The worker does not drop failed retryable entries after a maximum retry threshold.
- **Circuit Breaker:** Increments `consecutiveTimeouts`. At 5 timeouts, trips breaker and pauses synchronization for 30 seconds (`sync_background_worker.dart:698-746`).
- **CRITICAL IN-FLIGHT REAPING TRAP (OBX-02):**
  - Spec §15.3 calls for zombie task reaping.
  - In [`sync_background_worker.dart:210, 291-296`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L210), `recoverOrphanedOutboxTasks(olderThan: Duration(seconds: 60))` is executed **only once** inside `start()`.
  - If the app crashes while a batch is `IN_FLIGHT`, and the cashier re-opens the app 10 seconds later:
    - `sentAt` is 10 seconds old.
    - `cutoff = now - 60s`.
    - `sentAt < cutoff` evaluates to **FALSE**.
    - 0 rows are updated back to `PENDING`.
  - `recoverOrphanedOutboxTasks` is **never called in any periodic timer** while the app runs.
  - `outboxDao.getPushBatch()` only selects `PENDING` and due `FAILED_RETRYABLE`. It completely ignores `IN_FLIGHT`.
  - As a result, those rows remain stuck in `IN_FLIGHT` **indefinitely** for the entire runtime of the application!
  - `sync_health_provider.dart:120` detects `sentAt > 2 min` and turns the health indicator RED, but the system has no background recovery mechanism.

---

### 5. Poison Messages
*Question: Does one permanently failing row block the queue?*

- **Individual Item Isolation (HTTP 200 Path):** If the server ingests a batch and returns HTTP 200 containing a specific mutation with `status: 'FAILED_FATAL'`, that single mutation is updated to `FAILED_FATAL` in `sync_outbox` and quarantined into `sync_conflicts` ([`sync_background_worker.dart:630-650`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L630-L650)). It does not block subsequent entries in future batches.
- **CRITICAL BATCH POISONING DEFECT (OBX-04):**
  - If a mutation contains malformed payload data that violates NestJS class-validator rules (`SyncPushDto` / `SyncMutationDto` in [`backend/src/sync/dto/sync-push.dto.ts:13-64`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L13-L64)), NestJS rejects the entire HTTP request with **HTTP 400 Bad Request**.
  - On the client side in [`sync_background_worker.dart:478-482`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L478-L482):
    ```dart
    if (response.statusCode >= 400 && response.statusCode < 500) {
      await _handleFatalBatch(batch, 'Client error (HTTP ${response.statusCode}): ${response.body}');
      return true;
    }
    ```
  - `_handleFatalBatch` loops through **every entry in the 25-item batch** and marks all 25 rows as `FAILED_FATAL` ([`lines 782-799`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L782-L799))!
  - One invalid mutation permanently quarantines and kills up to 24 valid orders, payments, and shifts in the same batch.
- **CRITICAL TRANSIENT ERROR POISONING DEFECT (OBX-05):**
  - In [`backend/src/sync/sync-push.service.ts:283-296`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L283-L296), when `prisma.$transaction()` throws an error that is not a unique constraint or conflict exception (e.g. transient database timeout, connection blip, deadlock), line 292 sets:
    ```typescript
    status: isConflict ? 'CONFLICT' : 'FAILED_FATAL'
    ```
  - It classifies non-conflict errors as `FAILED_FATAL`!
  - The client receives `FAILED_FATAL` in the per-item result, marks the order fatal, and quarantines it. A transient server glitch results in permanent order abandonment.

---

### 6. Idempotency Keys
*Question: Client-generated UUIDs on every sync request? Does the server enforce them with a DB unique constraint (not just app-level check)?*

- **Client UUID Generation:** Verified. All entities generate RFC 9562 UUID v7 identifiers at birth:
  - Orders: [`drift_offline_first_order_repository.dart:81-83`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L81-L83)
  - Order Items: [`drift_offline_first_order_repository.dart:134-136`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L134-L136)
  - Payments: [`drift_offline_first_order_repository.dart:161-164`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L161-L164)
  - Shifts: [`drift_offline_first_shift_repository.dart:68`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L68)
  - Outbox Mutations: [`drift_offline_first_order_repository.dart:201`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L201)
  - Push Batches: [`sync_background_worker.dart:420`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L420)
- **Database Unique Constraints:** Verified in PostgreSQL Prisma schema:
  - `ProcessedOperation`: `operation_id String @id @db.VarChar(36)` ([`schema.prisma:651`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L651))
  - `Order`: `id String @id @db.VarChar(36)` and `order_number String @unique` ([`schema.prisma:281-282`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L281-L282))
  - `OrderItem`: `id String @id @db.VarChar(36)` ([`schema.prisma:376`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L376))
  - `OrderPayment`: `id String @id @db.VarChar(36)` ([`schema.prisma:418`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L418))
  - `DailyCalculation`: `id String @id @db.VarChar(36)` ([`schema.prisma:507`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L507))
- **NON-TRANSACTIONAL IDEMPOTENCY RECORDING (OBX-11):**
  - In [`sync-push.service.ts:154-208`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L154-L208), the business mutation commits via `await this.prisma.$transaction(...)`.
  - However, the call to `await this.prisma.processedOperation.upsert(...)` occurs **outside the transaction on line 190**.
  - If the server process crashes or restarts between lines 156 and 190, the business entity is persisted, but the idempotency ledger record is never created.

---

### 7. Lost Response
*Question: Server commits, response lost, client retries. Duplicate order/payment/receipt?*

- **Order & Payment Deduplication:** Guaranteed.
  - If client retries with the same `batch_id`, the `IdempotencyInterceptor` ([`idempotency.interceptor.ts:104-121`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L104-L121)) returns the cached HTTP 200 payload directly from `processed_operations`. Zero business logic executes.
  - If client retries with a new `batch_id`, `SyncPushService:81-97` checks `operation_id` in `processed_operations`, returning `status: 'DUPLICATE'`.
  - If `processed_operations` record is absent, `OrderHandler.handleInsert` ([`order.handler.ts:68-91`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L68-L91)) executes `tx.order.findUnique({ where: { id: orderId } })`. It finds the existing order by UUID v7 and returns `status: 'DUPLICATE'`.
  - Prisma unique constraint on `Order.id` (`P2002`) also catches concurrent inserts ([`sync-push.service.ts:259-277`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L259-L277)) and returns `DUPLICATE`.
- **Kitchen Ticket Emission:** Protected. In [`sync-push.service.ts:217`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L217), `kitchenGateway.emitOrderCreated` is guarded by `if (result.status === 'SYNCED')`. Duplicate responses (`status === 'DUPLICATE'`) **never emit kitchen tickets**.
- **Receipt Printing:** Decoupled. Physical receipts are spooled locally via `OfflinePrintJobs` table at order creation time (`orders_dao.dart:39-41`). Printing does not depend on sync acknowledgment.

---

### 8. Batching
*Question: Partial success handling, per-item result contract, how client marks individual rows.*

- **Batch Size:** Sliced to 25 mutations per HTTP request (`batchSize = 25` in [`sync_background_worker.dart:174`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L174)).
- **Result Contract:** Server returns `{ success: true, batch_id, processed_count, results: [ SyncMutationResult ] }`. Each result contains `operation_id`, `entity_id`, `status` (`SYNCED` | `DUPLICATE` | `CONFLICT` | `FAILED_FATAL` | `FAILED_RETRYABLE`), `server_version`, `server_timestamp`, `error_message`, and `conflict_details`.
- **Client Processing:** In [`sync_background_worker.dart:489-660`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L489-L660), client wraps the entire batch response handling in a single atomic Drift transaction:
  - `SYNCED` / `DUPLICATE`: Marks outbox entry `SYNCED` and stamps local entity table.
  - `CONFLICT`: Evaluates auto-resolution (Hospitality Operational Priority) or rebases order base version (up to 3 times); otherwise marks `CONFLICT` and writes to `sync_conflicts`.
  - `FAILED_FATAL`: Marks outbox `FAILED_FATAL` and quarantines to `sync_conflicts`.
  - `FAILED_RETRYABLE`: Increments `retryCount` and computes jittered backoff.
- **Defect in Missing Envelopes:** If an item is missing from the server `results` array, line 498 marks it `FAILED_RETRYABLE` with exponential backoff.

---

### 9. Outbox Hygiene
*Question: Cleanup/retention of synced rows, growth of the table, performance with 5,000+ rows.*

- **Retention Pruning:** Implemented in [`retention_dao.dart:41-69`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/retention_dao.dart#L41-L69). Purges `local_orders` (`syncStatus = 'synced'`), `sync_outbox` (`status = 'SYNCED'`), and `offline_print_jobs` (`status = 'PRINTED'`) older than 30 days. Cascade foreign keys cleanly delete order items and payments.
- **Unsynced / Quarantined Entries:** Quarantined rows (`FAILED_FATAL`, `CONFLICT`) are **never pruned automatically** by the retention job (`retention_dao.dart:40`). They accumulate permanently unless cleared via cashier sync center (`clearFailedEntries`).
- **CRITICAL SCALE BOTTLENECK (OBX-09): Missing Outbox Indexes:**
  - `SyncOutbox` table definition in [`sync_outbox_table.dart:20-39`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/sync_outbox_table.dart#L20-L39) declares only a single unique constraint on `operationId`.
  - There are **no indexes** on `status`, `dependency_order`, `created_at`, or `next_retry_at`.
  - Slicing 5,000 pending mutations across 200 batches forces SQLite to execute 200 full table scans and memory sorts over large JSON payloads on an encrypted SQLCipher database.
  - Furthermore, `watchActiveOutboxEntries()` in [`outbox_dao.dart:166-176`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/outbox_dao.dart#L166-L176) streams all active rows with full JSON payloads into Dart heap memory on every mutation update, causing main UI thread freezing.

---

### 10. Schema Change Mid-Queue
*Question: Drift migration or API change while rows pending. Payload versioning?*

- **Drift Migration:** `schemaVersion` is hardcoded to `1` in [`app_database.dart:69`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/app_database.dart#L69). The `onUpgrade` handler is an empty scaffold.
- **Payload Versioning (OBX-12):** There is **no payload schema version column** in `SyncOutbox`. The `baseVersion` column stores the OCC entity version token, not the serialization schema version.
- **API Contract Change Risk:** If a cloud deployment introduces new mandatory fields or alters DTO structures while terminal outboxes hold pending mutations, incoming push payloads will fail NestJS validation. As shown in OBX-04, this results in HTTP 400 Bad Request, causing the client to fatally quarantine the entire batch of pending mutations.

---

### 11. Replay Safety
*Question: Can a replayed (old) payload overwrite newer server data?*

- **Order Updates:** Safe under OCC. In [`order.handler.ts:243-263`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L243-L263), `handleUpdate` checks `currentVersion > mutation.base_version`. If the server has a newer version, it returns `status: 'CONFLICT'`. *Caveat:* If `base_version` is omitted, OCC is skipped.
- **Order Inserts:** Safe. In [`order.handler.ts:68-91`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L68-L91), if the order UUID already exists, it immediately returns `status: 'DUPLICATE'` without overwriting server state.
- **Dining Tables:** Safe. In [`table.handler.ts:233-260`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/table.handler.ts#L233-L260), table mutations enforce OCC checks and Hospitality Operational Priority (§10.2). If a client attempts to clear a table that currently holds an active order on the server, the server rejects the wipe with `CONFLICT (auto_resolvable: true)`.
- **Shift Operations:** Safe. In [`shift.handler.ts:311-328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L311-L328), closed shifts reject updates with `DUPLICATE`.

---

## 2. Scenarios to Trace Step-by-Step

### Scenario 1: Kill App Between Drift Write and Outbox Insert
- **Order Checkout (`saveOrder`):** **PASS**.
  1. Cashier completes checkout.
  2. `saveOrderAtomic` begins SQLite transaction (`orders_dao.dart:30`).
  3. Writes `local_orders`, `local_order_items`, `local_order_payments`, `sync_outbox`, and `offline_print_jobs`.
  4. App killed before commit: SQLite WAL rolls back 100%. Zero orphaned rows.
  5. App killed after commit: Outbox row exists durably. Sync worker pushes it on boot.
- **Order Status Update (`updateOrderStatus`):** **FAIL** (See OBX-01).
  1. Cashier cancels or completes an order (`drift_offline_first_order_repository.dart:408`).
  2. Local SQLite table is updated.
  3. Process is terminated before line 418.
  4. App restarts. Local order remains in updated status, but outbox row was never inserted. Desync is permanent.

### Scenario 2: Kill App While a Row Is In-Flight
- **Restart After > 60 Seconds:** **PASS**.
  1. Row is marked `IN_FLIGHT` with `sentAt = T0` (`outbox_dao.dart:41`).
  2. App is killed while HTTP request is travelling over network.
  3. App is launched 75 seconds later.
  4. `SyncBackgroundWorker.start()` invokes `recoverOrphanedOutboxTasks(olderThan: 60s)` (`sync_background_worker.dart:210`).
  5. `sentAt < (now - 60s)` is true. Row status reverts to `PENDING`. Drained normally.
- **Restart in < 60 Seconds:** **FAIL** (See OBX-02).
  1. Row is marked `IN_FLIGHT` with `sentAt = T0`.
  2. App crashes. Cashier immediately clicks POS desktop icon 10 seconds later.
  3. `start()` runs `recoverOrphanedOutboxTasks`. Because `sentAt` is only 10s old, 0 rows are updated.
  4. Method is never invoked again while app runs.
  5. Row is stuck in `IN_FLIGHT` indefinitely for that entire session. Health indicator turns red after 2 minutes.

### Scenario 3: Same Request Sent Twice 50 ms Apart
- **Case A: Identical `batch_id` (Double Tap / Duplicate Network Trigger):** **PASS**.
  1. Request 1 arrives at NestJS with `X-Idempotency-Key: b-1`.
  2. `IdempotencyInterceptor` (`idempotency.interceptor.ts:154`) creates `processed_operations` row with `status: 'PROCESSING'`.
  3. Request 2 arrives 50ms later with same `b-1`.
  4. `IdempotencyInterceptor:148` detects in-flight row and calls `handleConcurrentInFlight`.
  5. Request 2 polls every 50ms awaiting Request 1 completion.
  6. Request 1 commits and marks ledger `COMPLETED`.
  7. Request 2 returns cached response payload. Zero duplicate database inserts.
- **Case B: Differing `batch_id` (Same Mutation UUIDs):** **PASS**.
  1. Request 1 commits order with `id: ord-123`.
  2. Request 2 arrives with new batch ID containing `ord-123`.
  3. Interceptor passes. `SyncPushService:81` finds `operation_id` in `processed_operations` or `OrderHandler:68` finds order by primary key.
  4. Server returns `status: 'DUPLICATE'`.
  5. Line 217 skips kitchen ticket emission. Zero duplicate KOTs, zero duplicate orders.

### Scenario 4: 20-Item Batch Where Item 7 Returns 500, Item 8 Returns 409
- **Trace:** **FAIL** (See OBX-04, OBX-05).
  1. Batch of 20 items is transmitted to `POST /api/sync/push`.
  2. Items 1..6 process successfully in isolated transactions and return `status: 'SYNCED'`.
  3. Item 7 encounters an unexpected database timeout in `prisma.$transaction`.
  4. In `sync-push.service.ts:292`, the catch block maps the unexpected database error to `status: 'FAILED_FATAL'`.
  5. Item 8 has an OCC version conflict. Handled via domain handler; returns `status: 'CONFLICT'`.
  6. Items 9..20 process and return `status: 'SYNCED'`.
  7. Backend responds with HTTP 200 containing the 20 per-item results.
  8. Client processes response in Drift transaction:
     - Items 1..6: Marked `SYNCED`.
     - Item 7: Marked `FAILED_FATAL` and permanently quarantined to `sync_conflicts` without retry! (FAIL: Transient error was not retried).
     - Item 8: Auto-rebases OCC version or quarantines to `sync_conflicts`.
     - Items 9..20: Marked `SYNCED`.
  9. *Variant:* If Item 7 triggers an HTTP 400 validation error, `_handleFatalBatch` runs, killing all 20 items in the batch!

### Scenario 5: 5,000 Pending Rows After Multi-Day Outage
- **Trace:** **FAIL** (See OBX-07, OBX-09).
  1. Terminal reconnects with 5,000 pending mutations in `sync_outbox`.
  2. Worker queries batch of 25. Because `sync_outbox` lacks an index on `(status, dependency_order, created_at)`, SQLite executes a full table scan and filesort across 5,000 rows.
  3. Worker marks 25 items `IN_FLIGHT`. Drift reactive query `watchActiveOutboxEntries()` triggers, loading thousands of full JSON payloads into Dart memory, freezing the UI thread.
  4. Worker transmits HTTP POST. Repeats this cycle 200 consecutive times.
  5. *Data Corruption Branch:* If the shift open mutation (Level 0) was delayed in retry backoff, the pending orders in the queue are ingested first.
  6. In `orders.service.ts:329-348`, the backend sees that the order's `shift_id` does not exist in PostgreSQL. It nullifies `shift_id` and attaches the order to another active shift on the server.
  7. Alice's offline shift revenue is credited to Bob's drawer on the server. Alice's drawer shows unexplained shortage upon closing.

---

### Scenario PASS/FAIL Summary Matrix

| Scenario | Result | Failure Mechanism & Behavioral Consequence |
|---|---|---|
| **1. Kill app between Drift write & outbox insert** | **FAIL** | Order creation passes atomically (`saveOrderAtomic`). However, `updateOrderStatus` and `deleteHeldOrder` update local SQLite outside of a transaction before inserting outbox row, causing permanent state loss on process kill. |
| **2. Kill app while a row is in-flight** | **FAIL** | If app restarts within 60 seconds (standard cashier behavior), `recoverOrphanedOutboxTasks` skips the row. Because no periodic recovery runs, the row is stuck `IN_FLIGHT` indefinitely for that entire session. |
| **3. Same request sent twice 50ms apart** | **PASS** | Double-taps with same batch ID are collapsed by `IdempotencyInterceptor`. Concurrent mutations with different batch IDs are caught by PostgreSQL primary key unique constraints and resolved as `DUPLICATE`. |
| **4. 20-item batch (Item 7 = 500, Item 8 = 409)** | **FAIL** | `SyncPushService` maps unexpected database exceptions to `FAILED_FATAL` instead of `FAILED_RETRYABLE`. Client permanently quarantines valid orders. If an item causes HTTP 400, all 20 items are killed. |
| **5. 5,000 pending rows after multi-day outage** | **FAIL** | 200 unindexed full table scans freeze main UI thread. Reordering orders before shift open causes the server to silently reassign offline orders to incorrect active shifts. |

---

## 3. Audit Findings

### OBX-01: Non-Atomic Local Write and Outbox Insert in Order Updates and Deletions
- Severity: High
- Evidence: [`drift_offline_first_order_repository.dart:407-434`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L407-L434), [`lines 442-466`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L442-L466), [`table_repository.dart:211-236`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L211-L236)
- Failure sequence:
  1. Cashier updates order status (e.g. cancels order or marks preparing) via `updateOrderStatus`.
  2. Line 408 writes `LocalOrdersCompanion` to SQLite (`local_orders`).
  3. Operating system terminates process, power drops, or app crashes before line 418 executes.
  4. Local SQLite holds the updated order status, but `sync_outbox` has no record of the mutation.
  5. The change is never transmitted to the server or kitchen display.
- Impact: Lost order status / permanent desync between local POS and cloud.
- Recommended fix: Wrap `updateOrderStatus` and `deleteHeldOrder` in `_db.transaction(() async { ... })` so table update and outbox insertion commit atomically.
- Effort: S
- Status: CONFIRMED

---

### OBX-02: Zombie Task Recovery Window Leaves Rows Stuck in `IN_FLIGHT` Indefinitely
- Severity: High
- Evidence: [`sync_background_worker.dart:210, 291-296`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L210), [`sync_health_provider.dart:120`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_health_provider.dart#L120)
- Failure sequence:
  1. Outbox worker transitions batch to `IN_FLIGHT` with `sentAt = DateTime.now()`.
  2. Application process terminates unexpectedly during HTTP transmission.
  3. Cashier re-opens POS app within 15 seconds.
  4. Worker `start()` invokes `recoverOrphanedOutboxTasks(olderThan: Duration(seconds: 60))`.
  5. Because `sentAt` was only 15 seconds ago, `t.sentAt.isSmallerThan(cutoff)` evaluates to false. 0 rows are reset.
  6. `recoverOrphanedOutboxTasks` is never called again while the application runs.
  7. `getPushBatch()` ignores `IN_FLIGHT` rows; mutations remain stuck in-flight for the rest of the day.
- Impact: Stuck queue / unsynced orders / permanent red health indicator.
- Recommended fix: Add periodic execution of `recoverOrphanedOutboxTasks(olderThan: Duration(seconds: 60))` inside the 30-second poll timer, and on app startup reset **all** `IN_FLIGHT` tasks regardless of timestamp.
- Effort: S
- Status: CONFIRMED

---

### OBX-03: Out-of-Order Execution When Entity INSERT Enters Retry Backoff While UPDATE Remains Pending
- Severity: Critical
- Evidence: [`drift_offline_first_order_repository.dart:328-341`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L328-L341), [`outbox_dao.dart:22-34`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/outbox_dao.dart#L22-L34), [`order.handler.ts:231-240`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L231-L240)
- Failure sequence:
  1. Cashier creates order `ord-1` (Operation 1: `INSERT`, Level 2, `status: PENDING`).
  2. Cashier edits order `ord-1` (Operation 2: `UPDATE`, Level 2, `status: PENDING`, `dependsOnOperationId: null`).
  3. Operation 1 is transmitted; network drops. Worker marks Operation 1 `FAILED_RETRYABLE` with `nextRetryAt = now + 4s`.
  4. 1 second later, worker queries `outboxDao.getPushBatch()`.
  5. Operation 1 is skipped because `nextRetryAt > now`.
  6. Operation 2 is still `PENDING`, so it is returned and pushed to `/api/sync/push`.
  7. Server `OrderHandler.handleUpdate` searches for `ord-1` in PostgreSQL. Order does not exist yet.
  8. Line 235 returns `status: 'FAILED_FATAL'` ("Order not found for update").
  9. Client marks Operation 2 `FAILED_FATAL` and permanently dumps it into `sync_conflicts`.
  10. When Operation 1 retries and creates the order, the subsequent update has been permanently lost.
- Impact: Lost order updates / corrupted order state in database.
- Recommended fix: In `updateOrder` and `updateOrderStatus`, set `dependsOnOperationId` to the preceding operation for that entity, or enforce per-entity FIFO queueing in `getPushBatch()` so no mutation for an entity can push if an earlier mutation for that entity is in retry backoff.
- Effort: M
- Status: CONFIRMED

---

### OBX-04: HTTP 4xx Client Validation Error Fatally Quarantines Entire 25-Mutation Batch
- Severity: Critical
- Evidence: [`sync_background_worker.dart:478-482, 782-799`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L478-L482), [`sync-push.dto.ts:13-64`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/dto/sync-push.dto.ts#L13-L64)
- Failure sequence:
  1. A batch of 25 mutations is assembled, containing 24 valid orders and 1 order with an invalid or unexpected field.
  2. NestJS `ValidationPipe` validates `SyncPushDto` and rejects the entire request with `HTTP 400 Bad Request`.
  3. In `sync_background_worker.dart:478`, the client receives status 400 and calls `_handleFatalBatch(batch)`.
  4. Lines 782-799 iterate through **all 25 mutations** in the batch, marking every single one as `FAILED_FATAL` and writing all of them into `sync_conflicts`.
  5. 24 completely valid orders are permanently abandoned and never sent again.
- Impact: Mass loss of valid orders / lost revenue.
- Recommended fix: Never mark an entire batch fatal on HTTP 4xx. Split the batch into single-item push requests to isolate the single failing mutation, or mark items `FAILED_RETRYABLE` for supervisor inspection.
- Effort: M
- Status: CONFIRMED

---

### OBX-05: Transient Server Database Errors Classified as `FAILED_FATAL` Instead of `FAILED_RETRYABLE`
- Severity: High
- Evidence: [`backend/src/sync/sync-push.service.ts:283-296`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L283-L296)
- Failure sequence:
  1. Offline mutations batch is processed on backend.
  2. In `sync-push.service.ts:154`, `this.prisma.$transaction` executes `handler.handle()`.
  3. PostgreSQL encounters a transient connection timeout, statement deadlock, or pool exhaustion.
  4. The catch block on line 283 catches the error. `isConflict` evaluates to false.
  5. Line 292 sets `status: 'FAILED_FATAL'`.
  6. Response returns HTTP 200 with result `status: 'FAILED_FATAL'`.
  7. Client marks the mutation as `FAILED_FATAL` and moves it to quarantine. Mutation is never retried.
- Impact: Lost orders caused by transient server blips.
- Recommended fix: In `sync-push.service.ts:292`, classify unknown database exceptions and connection errors as `FAILED_RETRYABLE`, reserving `FAILED_FATAL` strictly for explicit unresolvable validation errors.
- Effort: S
- Status: CONFIRMED

---

### OBX-06: Missing Dependency Failure Cascade Causes Infinite Retry Loops
- Severity: High
- Evidence: [`backend/src/sync/sync-push.service.ts:100-126`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L100-L126), [`drift_offline_first_shift_repository.dart:221-231`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L221-L231)
- Failure sequence:
  1. Cashier opens shift (Op 1) and later closes shift (Op 2, with `dependsOnOperationId: Op 1`).
  2. Op 1 encounters a fatal error or supervisor rejection and is marked `FAILED_FATAL`.
  3. Op 2 is sent to the server.
  4. Server checks `depends_on_operation_id` (`sync-push.service.ts:106`). Op 1 is not in `processedOperation` as `COMPLETED`.
  5. Server returns `status: 'FAILED_RETRYABLE'` ("Unsynced dependency... has not completed yet").
  6. Client schedules retry. Op 2 retries indefinitely every 5 minutes forever.
- Impact: Infinite retry loop / circuit breaker cycling / unable to close shift on server.
- Recommended fix: When a mutation is marked `FAILED_FATAL` or `CONFLICT`, cascade-fail all dependent mutations in `sync_outbox` where `dependsOnOperationId == failedOpId`.
- Effort: M
- Status: CONFIRMED

---

### OBX-07: Unlinked Shift Session Silent Reassignment to Other Active Shifts
- Severity: Critical
- Evidence: [`backend/src/orders/orders.service.ts:321-349`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L321-L349)
- Failure sequence:
  1. Cashier Alice operates POS-P1 offline under local shift `shift-A`.
  2. Terminal reconnects. Due to lack of `dependsOnOperationId` between orders and shift open, orders are transmitted while `shift-A` open is in retry backoff.
  3. Backend `OrdersService.createOrderInTx` executes lines 329-331:
     `shiftExists` is false. Line 331 sets `activeShiftId = null`.
  4. Lines 340-346 execute:
     `activeShift = await tx.dailyCalculation.findFirst({ where: { status: 'ACTIVE' } })`.
  5. The backend finds cashier Bob's active shift `shift-B` and reassigns Alice's order to `shift-B`!
  6. Alice's offline orders are permanently linked to Bob's shift in PostgreSQL.
  7. Alice closes her shift; her cloud Z-report shows zero sales (severe cash shortage variance). Bob's drawer shows unexpected revenue.
- Impact: Money / financial discrepancy / broken cash drawer reconciliation.
- Recommended fix: Never reassign an offline order's `shift_id` to an arbitrary active shift. If `shift_id` is specified but missing, return `FAILED_RETRYABLE` so the order waits for its shift open mutation to commit.
- Effort: S
- Status: CONFIRMED

---

### OBX-08: Dual-Write Anti-Pattern in Takeaway, Delivery, and Table Repositories
- Severity: High
- Evidence: [`takeaway_repository.dart:365-388`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L365-L388), [`delivery_repository.dart:365-392`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L365-L392), [`table_repository.dart:251-257`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L251-L257)
- Failure sequence:
  1. Cashier creates or updates a takeaway order while online.
  2. Order is saved to Drift and queued in `sync_outbox`.
  3. In parallel, `takeaway_repository` issues direct HTTP `_ordersApiService.createOrder()`.
  4. Background worker simultaneously picks up the outbox entry and issues `POST /api/sync/push`.
  5. Both requests hit NestJS simultaneously.
  6. Direct REST succeeds and updates the server version to 2.
  7. Outbox push arrives with `base_version = 1`, resulting in an artificial OCC `CONFLICT`.
  8. In takeaway creation, line 386 deletes the outbox entry after HTTP success, racing with the in-flight background worker.
- Impact: Race conditions / artificial OCC conflicts / duplicate network traffic.
- Recommended fix: Remove direct HTTP calls from domain feature repositories when `offlineFirstEnabled` is true. Funnel all writes exclusively through Drift and `SyncBackgroundWorker`.
- Effort: M
- Status: CONFIRMED

---

### OBX-09: Missing Database Indexes on `SyncOutbox` Causes UI Freezes During Large Queue Drains
- Severity: Medium
- Evidence: [`frontend/lib/core/database/tables/sync_outbox_table.dart:20-39`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/sync_outbox_table.dart#L20-L39), [`outbox_dao.dart:22-34, 166-176`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/outbox_dao.dart#L22-L34)
- Failure sequence:
  1. Terminal reconnects after a 3-day outage with 5,000 pending mutations.
  2. Worker queries batches of 25 using `getPushBatch()`:
     `WHERE status = 'PENDING' ... ORDER BY dependency_order ASC, created_at ASC`.
  3. Because `SyncOutbox` has no index on `(status, dependency_order, created_at)`, SQLite must perform 200 full table scans and memory sorts over encrypted pages.
  4. On each of the 200 batch updates, `watchActiveOutboxEntries()` triggers, querying all 5,000 active entries with full JSON payloads into Dart memory.
  5. Main UI thread encounters severe jank, garbage collection pauses, and temporary lockups.
- Impact: Severe UI freezing / degraded performance.
- Recommended fix: Add composite index `TableIndex('idx_outbox_push', 'status, dependency_order, created_at, next_retry_at')` in `SyncOutbox` table definition. Refactor `watchActiveOutboxEntries()` to select only lightweight status columns without full payload JSON blobs.
- Effort: S
- Status: CONFIRMED

---

### OBX-10: Server Order Number Suffix Reassignment Never Synchronized Back to Client
- Severity: Medium
- Evidence: [`backend/src/orders/orders.service.ts:306-314`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L306-L314), [`order.handler.ts:206-212`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L206-L212), [`sync_background_worker.dart:516-526`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L516-L526)
- Failure sequence:
  1. Terminal P1 creates an order offline with receipt number `P1-101`.
  2. Upon sync, backend detects that `P1-101` already exists in PostgreSQL and renames the order to `P1-101-1`.
  3. `OrderHandler` returns `SyncMutationResult` containing only `server_version` and `server_timestamp`.
  4. Client marks order synced locally; order number in `LocalOrders` remains `P1-101`.
  5. Customer receipt reads `P1-101`, but cloud admin portal displays `P1-101-1`.
- Impact: Customer support confusion / receipt audit desynchronization.
- Recommended fix: Return `reassigned_order_number` in `SyncMutationResult` and update `local_orders.orderNumber` when processing push results in `SyncBackgroundWorker`.
- Effort: S
- Status: CONFIRMED

---

### OBX-11: Non-Transactional Idempotency Ledger Recording on Server
- Severity: Medium
- Evidence: [`backend/src/sync/sync-push.service.ts:154, 183-208`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/sync-push.service.ts#L154)
- Failure sequence:
  1. Server executes entity handler inside `prisma.$transaction` (line 154).
  2. Transaction commits order to PostgreSQL database.
  3. Before line 190 (`prisma.processedOperation.upsert`), the server crashes or worker thread dies.
  4. The business order is committed, but `processed_operations` has no record of the mutation.
  5. Client retries the batch; idempotency interceptor cache misses.
- Impact: Fragile idempotency boundary / reliance on entity-level unique constraint fallbacks.
- Recommended fix: Move `processedOperation.upsert` inside the same `prisma.$transaction(async (tx) => { ... })` block as the entity mutation.
- Effort: S
- Status: CONFIRMED

---

### OBX-12: Missing Schema and Payload Versioning in `SyncOutbox`
- Severity: Medium
- Evidence: [`frontend/lib/core/database/tables/sync_outbox_table.dart:20-39`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/sync_outbox_table.dart#L20-L39), [`app_database.dart:69-78`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/app_database.dart#L69-L78)
- Failure sequence:
  1. Outbox contains pending order mutations serialized with schema version 1.
  2. Application auto-updates or backend introduces a breaking schema change to `CreateOrderDto`.
  3. Pending mutations are sent to the server.
  4. Server fails to deserialize or rejects payload via validation pipe.
  5. The mutations are marked `FAILED_FATAL`, losing the orders.
- Impact: Lost orders during software updates while offline.
- Recommended fix: Add `IntColumn get payloadSchemaVersion => integer().withDefault(const Constant(1))()` to `SyncOutbox` and maintain backward-compatible payload migration transformers.
- Effort: M
- Status: CONFIRMED

---

## 4. Recommended System Invariants

To achieve complete zero-loss offline synchronization, the system must strictly guarantee the following invariants:

1. **Strict Local Atomicity Invariant:**
   Every local state mutation (`LocalOrders`, `LocalOrderItems`, `LocalRestaurantTables`, `LocalDailyCalculations`) and its corresponding `SyncOutbox` mutation must be committed within the **same atomic SQLite transaction**. Zero business writes may occur outside of a transaction.
2. **Per-Entity Serialization Invariant:**
   Mutations targeting the same entity (`entityType + entityId`) must execute in strict FIFO order. If a mutation for an entity enters retry backoff, **all subsequent mutations for that entity must pause** and never be transmitted out of order.
3. **No Batch Poisoning Invariant:**
   A failure in one mutation must never contaminate or fail other mutations in the same batch. HTTP 4xx responses must trigger single-mutation retry isolation rather than mass batch quarantine.
4. **Permanent Zombie Task Recovery Invariant:**
   The background sync worker must periodically sweep `IN_FLIGHT` rows older than 60 seconds and reset them to `PENDING`. On application startup, **all** `IN_FLIGHT` rows must be reset to `PENDING` immediately without waiting for a 60-second cutoff.
5. **Deterministic Shift Association Invariant:**
   An offline order must **never** be reassigned to a different active shift on the server. If an order references a shift that has not yet synced, the order must return `FAILED_RETRYABLE` and await the shift open mutation.
6. **Single Source of Write Truth Invariant:**
   When `offlineFirstEnabled` is true, domain repositories must **never** attempt direct REST calls. All mutations must write exclusively to local Drift tables and allow `SyncBackgroundWorker` to manage delivery.
7. **Transactional Server Idempotency Invariant:**
   Business persistence and idempotency ledger recording (`processed_operations`) must commit inside the **exact same database transaction**.
8. **Indexed Outbox Drain Invariant:**
   `SyncOutbox` must maintain a covering index on `(status, dependency_order, created_at, next_retry_at)` to guarantee constant-time batch selection at 5,000+ row scales.
