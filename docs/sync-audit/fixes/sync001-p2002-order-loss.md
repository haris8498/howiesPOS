# Handoff Note: sync001-p2002-order-loss

## Issue
**SYNC-001:** Silent Order Annihilation on Server via P2002 Unique Constraint False Duplicate Return.

## Root Cause
When an offline device reconnected and pushed an order whose human-readable `order_number` (e.g. `P1-101`) or takeaway `token_number` collided with an existing record, PostgreSQL / Prisma threw unique constraint error `P2002`. The catch block in `sync-push.service.ts` assumed *any* `P2002` on an `INSERT` was a primary key duplicate, rolling back the transaction while returning HTTP 200 with `status: 'DUPLICATE'`. The client then purged the unsynced order from its local outbox, resulting in complete, silent order loss.

## Changes Made
1. **Schema & Migration:**
   - Added nullable `client_order_number VARCHAR(30)` to `Order` in `backend/prisma/schema.prisma`.
   - Created additive migration `20261026010000_add_client_order_number`.
2. **Orders Service (`backend/src/orders/orders.service.ts`):**
   - Retained original human receipt number in `client_order_number`.
   - When a collision occurs on `order_number`, reassigns unique candidate with suffix (e.g. `P1-101-1`), enforcing VARCHAR(30) length bounds.
   - For takeaway orders, resolves `token_number` collision with a bounded suffix loop, enforcing VARCHAR(20) length bounds.
   - Online behavior (when `explicitOrderId` is absent) strictly preserves throwing `ConflictException`.
3. **Order Handler (`backend/src/sync/handlers/order.handler.ts`):**
   - Propagated `client_order_number` from payload into `createDto`.
   - If server reassigns the order number or takeaway token number upon collision, returns `status: 'APPLIED'`, final `order_number`, `token_number`, and `client_order_number`.
4. **Sync Push Service (`backend/src/sync/sync-push.service.ts`):**
   - Added precise `isPkCollision` target check inspecting `err?.meta?.target` (strictly matching `id`, `_pkey`, `primary` - preventing false matches on `shift_id`, `table_id`, etc.).
   - Only treats `P2002` as `DUPLICATE` if target is primary key AND the entity row is verified to actually exist in PostgreSQL.
   - For `order_number` or `token_number` collision races, retries the transaction in a bounded loop (up to 5 attempts) with reassigned identifier (respecting column length limits) and returns `status: 'APPLIED'`.
   - For unknown `P2002` targets, logs structured warning with `deviceId`, `mutationId`, `entityId`, `target`, and returns `status: 'FAILED_RETRYABLE'` to keep entry safe in client outbox.
   - Extended `SyncResultStatus` to support additive `'APPLIED'`.
   - Extended `SyncMutationResult` with `token_number?: string;`.

## Files Changed
- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/20261026010000_add_client_order_number/migration.sql`
- `backend/src/orders/dto/create-order.dto.ts`
- `backend/src/orders/orders.service.ts`
- `backend/src/sync/handlers/sync-entity.handler.ts`
- `backend/src/sync/handlers/order.handler.ts`
- `backend/src/sync/sync-push.service.ts`
- `backend/src/sync/sync-001-p2002.spec.ts`

## Tests Added
- `backend/src/sync/sync-001-p2002.spec.ts`:
  1. Same mutation pushed twice -> DUPLICATE, one row.
  2. Two devices push different orders with the same `order_number` -> both persisted, distinct final numbers, nothing lost (`status: 'APPLIED'`).
  3. Same collision for takeaway token -> both persisted, distinct final tokens, nothing lost (`status: 'APPLIED'`).
  4. Unknown P2002 target -> not acknowledged as success or DUPLICATE (`status: 'FAILED_RETRYABLE'`).
  5. Concurrent pushes (`Promise.all`) do not lose orders.

## Manual Verification
Push two separate order payloads with the same `order_number` (e.g. `P1-101`) to `POST /api/sync/push`. Verify that both orders exist in the database, with the second receiving `order_number: 'P1-101-1'` and `client_order_number: 'P1-101'`. Repeat for takeaway orders with identical `token_number` (e.g. `TK-101`).

## Residual Risks
None. Client code in subsequent waves should recognize `status: 'APPLIED'` to update the local receipt number.
