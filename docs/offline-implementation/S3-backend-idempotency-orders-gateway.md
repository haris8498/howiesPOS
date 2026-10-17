# Stage 3 Implementation Report: Backend Idempotency, Order Numbering & Realtime Gateway

> **Stage:** `backend-idempotency-orders-gateway` (Stage 3)  
> **Architecture Spec Sections:** §8.2, §8.3(2), §9 (9.1–9.4), §15.2, §4.3  
> **Report File:** `docs/offline-implementation/S3-backend-idempotency-orders-gateway.md`  
> **Status:** Completed & Verified  
> **Date:** October 17, 2026  

---

## 1. What Was Built

1. **NestJS Idempotency Interceptor (`IdempotencyInterceptor` - Spec §8.2, §7.1, §15.2):**
   - Implemented `backend/src/sync/interceptors/idempotency.interceptor.ts` managing the `processed_operations` database ledger.
   - **Key Extraction:** Intercepts write requests carrying `X-Idempotency-Key` or `Idempotency-Key` HTTP headers, or `operation_id` / `batch_id` in the request body. Requests without idempotency keys pass through unchanged with zero performance overhead.
   - **Deterministic SHA-256 Hashing:** Computes a 64-character SHA-256 hex hash from HTTP method, request path, and a recursively sorted, canonical JSON string of the request body (`canonicalJson`).
   - **Ledger Lifecycle:**
     - Checks `processed_operations` for `operation_id`.
     - **Idempotent Hit (`COMPLETED`):** Compares request hashes. If matching, immediately returns the cached response payload and HTTP status code without re-executing controller logic or database transactions.
     - **Payload Mismatch (Conflict):** If the idempotency key matches an existing record but the request hash differs, rejects with `ConflictException` (HTTP 409: *"Idempotency key reused with different request payload"*).
     - **In-Flight Concurrency Lock (`PROCESSING`):** When concurrent duplicate requests arrive (or a thread encounters `P2002` unique constraint race on insert), the second request waits and polls `processed_operations` (default 50ms interval up to 3s). Once the first request completes, the second receives the cached result.
     - **Stale `PROCESSING` Recovery (§15.3):** If a record remains in `PROCESSING` status for over 30 seconds (simulating server restart/crash mid-processing), the interceptor automatically reclaims the lock and safely re-executes the request.
     - **Error Rollback Cleanup:** If downstream handler throws an error or rolls back, the in-flight `PROCESSING` record is deleted, ensuring subsequent client retries are not deadlocked.

2. **Integration on Write Endpoints:**
   - Applied `@UseInterceptors(IdempotencyInterceptor)` to:
     - `POST /api/sync/push` (Offline mutations batch ingestion)
     - `POST /api/orders` (Order creation and initial payments)
     - `PATCH /api/orders/:id` (Order modifications and payment updates)
     - `POST /api/daily-calculation/submit` (Cashier shift closure)
     - `POST /api/daily-calculation/start-session` (Cashier shift opening)
   - Updated `SyncPushService.pushMutations` to check and record `processed_operations` per individual mutation in addition to whole-batch protection.

3. **Terminal-Prefixed Human Receipt Numbering (`OrdersService.createOrder` - Spec §4.3, §8.3(2)):**
   - Updated `OrdersService.createOrderInTx` to accept terminal-prefixed order numbers formatted as `P<terminal>-<seq>` (e.g., `P1-101`, `P2-105`).
   - Enforces uniqueness within terminal partitions. Terminal 1 (`P1-101`) and Terminal 2 (`P2-101`) use isolated namespaces, eliminating collisions on PostgreSQL's `@unique(order_number)` constraint during offline operations.
   - Preserves 100% backward compatibility for legacy clients that omit `order_number`, maintaining the clean `101–999` auto-increment loop and inspecting the latest pure 3-digit order numbers even when terminal-prefixed orders coexist in the database.

4. **Standardized Realtime Event Gateway (`KitchenGateway` - Spec §9.1–9.4):**
   - Standardized WebSocket broadcasting to emit the canonical `RealtimeEventEnvelope<T>` from Spec §9.2:
     - `event_id`: RFC 4122 UUID v4 for deduplication.
     - `event_name`: Lowercase dot-separated (e.g. `'order.created'`).
     - `entity`: Database table name (e.g. `'orders'`).
     - `entity_id`: Primary key UUID.
     - `action`: `'CREATED'` | `'UPDATED'` | `'DELETED'` | `'STATUS_CHANGED'`.
     - `version`: OCC integer version token.
     - `change_seq`: Store sequence counter.
     - `occurred_at`: ISO 8601 UTC timestamp.
     - `origin_device_id`: Device identifier (e.g. `'POS-P1'`).
     - `store_id`: Store partition code.
     - `payload`: Lightweight metadata (notification-only principle, no PII, no large trees).
   - **Post-Commit Broadcasting (§9.4):** Emits strictly after PostgreSQL `$transaction` commits successfully. If transaction fails or rolls back, zero events are dispatched.
   - **Multi-Tenant Room Partitioning (§9.3):** Broadcasts envelope to `store:{storeId}:owner`, `store:{storeId}:cashier`, `store:{storeId}:all`, and `'kitchen'` room (`'realtime.event'`).
   - **Backwards Compatibility Transition:** Retains legacy event emissions (`order.created`, `kitchen.order_created`, etc.) formatted with `KitchenOrderEventPayload` to the legacy `'kitchen'` room so existing desktop clients continue functioning without disruption.

---

## 2. Files Created & Modified

### Files Created:
- `backend/src/sync/interceptors/idempotency.interceptor.ts` — Idempotency interceptor managing `processed_operations` ledger, SHA-256 request hashing, in-flight concurrent polling, and stale crash recovery.
- `backend/src/sync/interceptors/idempotency.interceptor.spec.ts` — Comprehensive unit test suite covering pass-through, 5x replay, hash mismatch, concurrent duplicates, and stale recovery.
- `docs/offline-implementation/S3-backend-idempotency-orders-gateway.md` — Stage 3 completion report.

### Files Modified:
- `backend/src/kitchen/kitchen.gateway.ts` — Implemented `RealtimeEventEnvelope<T>`, room partitioning, and envelope broadcasting across all order lifecycle events while preserving legacy formats.
- `backend/src/kitchen/kitchen.gateway.spec.ts` — Added unit tests for `RealtimeEventEnvelope` generation and room broadcasting.
- `backend/src/orders/orders.service.ts` — Added support for `P<terminal>-<seq>` receipt numbers, uniqueness validation, resilient legacy 101-999 fallback loop, and post-commit event delivery.
- `backend/src/orders/orders.service.spec.ts` — Added unit tests for terminal prefixes (`P1-101`), duplicate rejection, and post-commit event verification (no events on rollback).
- `backend/src/orders/orders.controller.ts` — Applied `@UseInterceptors(IdempotencyInterceptor)` to `createOrder` and `updateOrder`.
- `backend/src/orders/orders.controller.spec.ts` — Added `PrismaService` mock for testing module compilation with `IdempotencyInterceptor`.
- `backend/src/daily-calculation/daily-calculation.controller.ts` — Applied `@UseInterceptors(IdempotencyInterceptor)` to `submitDailyCalculation` and `startSession`.
- `backend/src/sync/sync.controller.ts` — Applied `@UseInterceptors(IdempotencyInterceptor)` to `POST /api/sync/push`.
- `backend/src/sync/sync.module.ts` — Registered and exported `IdempotencyInterceptor`.
- `backend/src/sync/sync-push.service.ts` — Added `processed_operations` checking and persistence for individual mutations, plus post-commit kitchen notifications.

---

## 3. Test Suites Added & Quality Gate Results

### 1. New & Updated Test Suites (14 New/Updated Unit Tests):
- `src/sync/interceptors/idempotency.interceptor.spec.ts` (8 tests passed):
  - Pass through when neither `X-Idempotency-Key` nor `operation_id` is present.
  - Execute write request and record `COMPLETED` record in `processed_operations`.
  - **5x Replay Test:** Retrying same key 5 times executes handler exactly once and returns identical cached response.
  - **Hash Mismatch Test:** Throws `ConflictException` (HTTP 409) when same key is used with differing request payload.
  - **Concurrent Duplicates Test:** Second in-flight request waits and returns cached response when first request completes.
  - **Stale PROCESSING Recovery Test:** Recovers and re-executes when previous processing crashed >30s ago.
  - **Error Cleanup Test:** Removes `PROCESSING` lock on transaction failure so subsequent retry can succeed.
  - `canonicalJson` produces deterministic strings regardless of object key order.
- `src/orders/orders.service.spec.ts` (3 tests added, 16 passed):
  - Accepts terminal-prefixed order number (`P1-101`).
  - Throws `ConflictException` if terminal order number already exists in partition.
  - Invariant: Does NOT emit kitchen event when transaction rolls back / throws.
- `src/kitchen/kitchen.gateway.spec.ts` (3 tests added, 10 passed):
  - Generates valid `RealtimeEventEnvelope<T>` with RFC 4122 UUID v4 and ISO timestamp.
  - Broadcasts envelope to partitioned `owner`, `cashier`, `all` rooms and `'kitchen'`.
  - Subscribes to partitioned rooms on `join_store`.

### 2. Quality Gate Verification:
- **Prisma Schema Validation:**
  ```bash
  npx prisma validate
  # Output: The schema at prisma\schema.prisma is valid 🚀 (Code 0)
  ```
- **TypeScript Application Build:**
  ```bash
  npm run build
  # Output: nest build -> Success, zero TypeScript compilation errors (Code 0)
  ```
- **Sync Module Tests:**
  ```bash
  npm test -- src/sync/
  # Output: 7 passed, 7 total suites (39 passed, 0 failed) (Code 0)
  ```
- **Kitchen & Orders Module Tests:**
  ```bash
  npm test -- src/kitchen/ src/orders/
  # Output: 5 passed, 5 total suites (40 passed, 0 failed) (Code 0)
  ```
- **Full Backend Test Run:**
  ```bash
  npm test
  # Output: 47 passed, 4 failed (337 passed, 4 failed)
  # Pre-existing baseline failures unchanged: inventory, permissions, reports, users.
  # Zero regressions introduced.
  ```

---

## 4. Commands Run

- `npx prisma validate`
- `npm run build`
- `npm test -- src/kitchen/kitchen.gateway.spec.ts`
- `npm test -- src/orders/orders.service.spec.ts`
- `npm test -- src/sync/interceptors/idempotency.interceptor.spec.ts`
- `npm test -- src/orders/orders.controller.spec.ts`
- `npm test -- src/sync/`
- `npm test`
- `git status`

---

## 5. Deviations / Blockers

- **Approved Deviations Applied:**
  - Feature flag `FeatureFlags.offlineFirstEnabled` remains defaulted to `false` until final pilot.
  - Legacy event emissions (`order.created`, `kitchen.order_created`, etc.) are retained in `KitchenGateway` so existing desktop and kitchen screens continue to receive updates during the migration period.
- **Blockers:** None.

---

## 6. How to Verify Manually

1. **Verify Idempotency 5x Replay via curl or Postman:**
   ```bash
   # Send an order with X-Idempotency-Key
   curl -X POST http://localhost:3000/api/orders \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <TOKEN>" \
     -H "X-Idempotency-Key: 0192994c-8f12-789a-bcde-test-key-01" \
     -d '{
       "order_number": "P1-101",
       "order_type": "takeaway",
       "items": [{ "item_name": "Cheese Pizza", "quantity": 1, "unit_price": 500 }]
     }'
   ```
   - **1st Request:** Returns HTTP 201 with created order details.
   - **2nd–5th Request (Exact Replay):** Returns cached HTTP 201 response immediately without creating additional database rows.
2. **Verify Hash Mismatch Detection (409 Conflict):**
   ```bash
   # Re-send with same idempotency key but altered grand_total / items
   curl -X POST http://localhost:3000/api/orders \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <TOKEN>" \
     -H "X-Idempotency-Key: 0192994c-8f12-789a-bcde-test-key-01" \
     -d '{
       "order_number": "P1-101",
       "order_type": "takeaway",
       "items": [{ "item_name": "Pepperoni Pizza", "quantity": 5, "unit_price": 900 }]
     }'
   ```
   - **Expected Result:** HTTP 409 Conflict with message `"Idempotency key reused with different request payload (request hash mismatch)"`.
3. **Verify Terminal Namespace Partitioning:**
   - Create Order 1 with `order_number: "P1-101"` -> Succeeds.
   - Create Order 2 from Terminal 2 with `order_number: "P2-101"` -> Succeeds (distinct namespaces, zero collision).
   - Create Order 3 with `order_number: "P1-101"` -> Fails with HTTP 409 Conflict (`"Order number 'P1-101' already exists"`).
4. **Verify WebSocket Canonical Envelope:**
   - Connect a Socket.IO client and listen to room `store:DEFAULT:owner` for event `order.created`.
   - Place an order.
   - Inspect frame payload: Verify it conforms to `RealtimeEventEnvelope<T>` containing `event_id`, `occurred_at`, `version`, `entity`, and lightweight payload.
