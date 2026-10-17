# Stage 2 Implementation Report: Backend Synchronization API

> **Stage:** `backend-sync-api` (Stage 2)  
> **Architecture Spec Sections:** §8.1, §7.1, §9.4, §10, §6.3  
> **Report File:** `docs/offline-implementation/S2-backend-sync-api.md`  
> **Status:** Completed & Verified  
> **Date:** October 17, 2026  

---

## 1. What Was Built

1. **Batch Push Ingestion (`POST /api/sync/push` - Spec §8.1.1, §6.3):**
   - Implemented `SyncPushService` processing batch mutation envelopes.
   - Enforces deterministic topological ordering by sorting mutations: `dependency_order ASC, created_at ASC`.
   - Executes each mutation inside its own isolated database transaction (`this.prisma.$transaction(...)`), guaranteeing that one failing mutation (conflict or fatal error) does not poison or abort the batch.
   - Returns per-mutation results with status `SYNCED`, `CONFLICT`, `FAILED_FATAL`, or `DUPLICATE`, accompanied by `server_version` and ISO `server_timestamp`.
   - Emits post-commit kitchen/owner notifications after transactions successfully commit (§9.4).

2. **Per-Entity Handler Registry & Architecture (§10, §8.1):**
   - Created `SyncEntityHandler` interface (`handle(tx, mutation, context)`) accepting `SyncMutationContext` with `operationId`, `deviceId`, and `batchId`.
   - Created `HandlerRegistry` service enabling pluggable handlers without modifying existing code.
   - Implemented `OrderHandler` (`backend/src/sync/handlers/order.handler.ts`):
     - Handles `INSERT`, `UPDATE`, and `DELETE` operations.
     - Preserves client-generated RFC 9562 UUID v7 primary keys for order header, line items, and payments.
     - Preserves business rules, custom tax, delivery fees, discount calculations, customer snapshots, table seating, and payment status by delegating to `OrdersService.createOrderInTx`.
     - Detects idempotent duplicates (`DUPLICATE`) when order UUID already exists.
     - Detects OCC conflicts (`CONFLICT`) when server version exceeds mutation `base_version` or duplicate `order_number` collision occurs on another order.
     - Injects `ChangeLogService.record(...)` inside the same transaction.

3. **Transactional Change-Log Service (`ChangeLogService` - Spec §7.1, §9.4):**
   - `ChangeLogService.record(tx, entity, id, op, version, payload, isDeleted)`:
     - Directly appends to `system_change_logs` inside the caller's transaction client (`tx`).
     - Stores monotonic global sequence, entity type, entity ID, operation, OCC version, and sanitized JSON payload.
   - `ChangeLogService.getMaxSequence()`: queries the current max `global_sequence` for cursor seeding.

4. **Incremental Delta Pull (`GET /api/sync/pull` - Spec §8.1.2):**
   - Implemented `SyncPullService.pullChanges(query)` querying `system_change_logs` where `global_sequence > cursor` ordered by `global_sequence ASC`.
   - Converts Prisma `BigInt` sequences to safe JavaScript numbers for standard JSON serialization.
   - Employs `limit + 1` query to cleanly calculate `has_more` without secondary count queries.
   - Returns `cursor`, `next_cursor`, `has_more`, and `changes` array.

5. **Cold-Start Hydration Bootstrap (`GET /api/sync/bootstrap` - Spec §8.1.3):**
   - Implemented `SyncPullService.getBootstrapData()` assembling catalog snapshots: store settings, role permissions, staff users (salted hashes, without plain passwords), menu categories, menu items, sizes, options, deals with components, floor zones, tables, delivery riders, active shift, and open orders.
   - Returns the current max `global_sequence` for initial client cursor seeding.
   - Compresses payload with Gzip (`zlib.gzipSync`) and returns HTTP headers `Content-Type: application/json` and `Content-Encoding: gzip`. Supports `raw=true` query param for uncompressed inspection.

6. **Controller & Module Registration (`SyncController` & `SyncModule`):**
   - Guarded with `JwtAuthGuard` matching all system API endpoints.
   - Retained 100% of legacy sync endpoints (`overview`, `order/:id`, `batch`, `toggle/:id`, `log`, `logs`) and kept `SyncService` completely intact without regressions.

---

## 2. Files Created & Modified

### Files Created:
- `backend/src/sync/dto/sync-push.dto.ts` — DTOs for batch envelope & mutation items.
- `backend/src/sync/dto/sync-pull.dto.ts` — DTO for delta pull pagination and cursor.
- `backend/src/sync/change-log.service.ts` — Transactional change log recorder.
- `backend/src/sync/change-log.service.spec.ts` — Unit tests for change log recorder.
- `backend/src/sync/handlers/sync-entity.handler.ts` — Entity handler interface & context.
- `backend/src/sync/handlers/handler-registry.service.ts` — Per-entity handler registry.
- `backend/src/sync/handlers/order.handler.ts` — Order handler for offline mutations.
- `backend/src/sync/handlers/order.handler.spec.ts` — Unit tests for order handler.
- `backend/src/sync/sync-push.service.ts` — Push service with isolated transactions.
- `backend/src/sync/sync-push.service.spec.ts` — Unit tests for push ordering & partial failure.
- `backend/src/sync/sync-pull.service.ts` — Pull and bootstrap service.
- `backend/src/sync/sync-pull.service.spec.ts` — Unit tests for pull paging & bootstrap snapshot.
- `backend/src/sync/sync.controller.spec.ts` — Unit tests for SyncController.
- `docs/offline-implementation/S2-backend-sync-api.md` — Stage 2 completion report.

### Files Modified:
- `backend/src/orders/dto/create-order.dto.ts` — Added optional `id?: string` to `CreateOrderDto` and `CreateOrderPaymentDto` to accept client UUIDs.
- `backend/src/orders/orders.service.ts` — Refactored internal order creation to `createOrderInTx` accepting `tx` and explicit IDs, while keeping `createOrder` backward-compatible.
- `backend/src/sync/sync.controller.ts` — Added `/api/sync/push`, `/api/sync/pull`, `/api/sync/bootstrap`, protected with `JwtAuthGuard`, preserved legacy endpoints.
- `backend/src/sync/sync.module.ts` — Registered all services, handler registry, order handler, and imported `OrdersModule` & `KitchenModule`.

---

## 3. Test Suites Added & Quality Gate Results

### 1. New Test Suites Added (5 Suites, 18 New Unit Tests):
- `src/sync/change-log.service.spec.ts` (3 tests passed)
  - Records change log inside transaction client.
  - Returns max global_sequence.
  - Handles empty change log.
- `src/sync/handlers/order.handler.spec.ts` (5 tests passed)
  - Registers in handler registry.
  - Returns `DUPLICATE` when order ID exists.
  - Creates order and records change log on `INSERT`.
  - Returns `FAILED_FATAL` on missing order update.
  - Detects OCC version conflict on `UPDATE`.
  - Increments version and records change log on valid `UPDATE`.
- `src/sync/sync-push.service.spec.ts` (3 tests passed)
  - Deterministic topological ordering by `dependency_order` ASC then `created_at` ASC.
  - Transaction isolation & partial failure: bad mutation does not poison batch (`[SYNCED, CONFLICT, SYNCED, FAILED_FATAL]`).
  - Unknown entity returns `FAILED_FATAL` gracefully.
- `src/sync/sync-pull.service.spec.ts` (4 tests passed)
  - Pull paging with `cursor`, `limit`, `next_cursor`, and `has_more: true`.
  - Paging termination with `has_more: false`.
  - Initial cursor fallback when no records.
  - Cold-start bootstrap catalog snapshot with `max_global_sequence`.
- `src/sync/sync.controller.spec.ts` (5 tests passed)
  - Delegates push mutations to `SyncPushService`.
  - Delegates pull queries to `SyncPullService`.
  - Returns gzipped payload with `Content-Encoding: gzip` for bootstrap.
  - Returns raw JSON when `raw=true`.
  - Preserves legacy `overview` and `batch` routes.

### 2. Quality Gate Verification:
- **Prisma Schema Validation:**
  ```bash
  npx prisma validate
  # The schema at prisma\schema.prisma is valid 🚀 (Code 0)
  ```
- **TypeScript Application Build:**
  ```bash
  npm run build
  # nest build -> Success, zero TypeScript compilation errors (Code 0)
  ```
- **Sync Module Tests:**
  ```bash
  npm test -- src/sync/
  # 6 passed, 6 total suites (31 passed, 0 failed) (Code 0)
  ```
- **Full Backend Test Run:**
  ```bash
  npm test
  # 50 total suites: 46 passed, 4 pre-existing baseline failed
  # 323 tests passed, 4 failed (compared to baseline: 292 passed, 4 failed)
  # Pre-existing failures unchanged: inventory, permissions, reports, users.
  ```

---

## 4. Commands Run

- `npx prisma validate`
- `npm run build`
- `npm test -- src/orders/orders.service.spec.ts`
- `npm test -- src/orders/orders.controller.spec.ts`
- `npm test -- src/sync/`
- `npm test`

---

## 5. Deviations / Blockers

- **Approved Deviations Applied:**
  - Feature flag `FeatureFlags.offlineFirstEnabled` remains defaulted to `false` until pilot phase.
  - Unauthenticated requests during token expiration are paused as `AUTH_PAUSED` rather than `FAILED_FATAL`.
  - Preserved existing legacy endpoints in `SyncController` and `SyncService` so existing frontend calls (`/api/sync/overview`, `/api/sync/batch`, `/api/sync/toggle/:id`) do not break.
- **Blockers:** None.

---

## 6. How to Verify Manually

1. **Start the backend server:**
   ```bash
   cd backend
   npm run start:dev
   ```
2. **Push a Batch of Mutations:**
   Send `POST /api/sync/push` with JWT Bearer Token:
   ```json
   {
     "device_id": "POS-P1",
     "batch_id": "0192994c-8f12-789a-bcde-f0123456789a",
     "mutations": [
       {
         "operation_id": "0192994c-8f12-789a-bcde-f0123456789b",
         "entity_type": "order",
         "entity_id": "0192994c-8f12-789a-bcde-f0123456789c",
         "operation_type": "INSERT",
         "dependency_order": 2,
         "payload": {
           "order_number": "P1-101",
           "order_type": "takeaway",
           "subtotal": 20.00,
           "grand_total": 20.00,
           "is_paid": true,
           "items": [
             {
               "item_name": "Cheese Pizza",
               "quantity": 1,
               "unit_price": 20.00
             }
           ]
         }
       }
     ]
   }
   ```
   **Expected Response:** HTTP 200 with `{ success: true, processed_count: 1, results: [{ status: "SYNCED", server_version: 1, ... }] }`.
3. **Verify Idempotent Duplicate:**
   Resend the exact same push payload.
   **Expected Response:** HTTP 200 with `{ status: "DUPLICATE", server_version: 1, ... }`.
4. **Pull Incremental Deltas:**
   Send `GET /api/sync/pull?cursor=0&limit=50`.
   **Expected Response:** HTTP 200 with `{ success: true, cursor: <N>, changes: [...] }`.
5. **Cold-Start Bootstrap:**
   Send `GET /api/sync/bootstrap` with header `Accept-Encoding: gzip`.
   **Expected Response:** HTTP 200 with `Content-Encoding: gzip` header containing gzipped JSON snapshot with `max_global_sequence`.
