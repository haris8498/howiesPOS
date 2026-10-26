# Fix Handoff: SYNC-003 - Offline Table Order Updates Discard Payment Records

> **Agent:** `sync003-table-update-payments`  
> **Target Branch:** `fix/sync003-table-update-payments`  
> **Status:** COMPLETED & VERIFIED  
> **Issue ID:** `SYNC-003` (MNY-01, CFL-04)  
> **Date:** October 26, 2026  

---

## 1. Root Cause

In `backend/src/sync/handlers/order.handler.ts:265-279`, `OrderHandler.handleUpdate()` handled order `UPDATE` mutations by executing `tx.order.update()` targeting only `status`, `payment_status`, `is_paid`, `is_held`, and `rejection_reason`.

When a dine-in table order was placed as unpaid (`payment_status: 'UNPAID', is_paid: false`) and later settled offline (adding line items, applying discounts/taxes, and recording cash/card tenders), the client pushed an `UPDATE` mutation with the full payload. However:
1. `payload.payments` was completely ignored, and no records were written to `order_payments`.
2. `payload.discounts`, `payload.taxes`, `payload.items`, `subtotal`, and `grand_total` were never persisted or recalculated.
3. Server-side validation was missing, allowing underpaid or unbacked orders to be marked `is_paid = true`.
4. Idempotent upserting was absent, meaning replays or retries lacked payment deduplication by client ID.

As a result, PostgreSQL canonical records displayed a paid order with zero payment records and $0.00 in the ledger, destroying accounting reconciliation.

---

## 2. Change Summary

1. **Extracted Shared Calculation & Mapping Helpers (`order.handler.ts`):**
   - `round(val)`: Standardized 2-decimal arithmetic.
   - `mapItems(items)`: Canonical line-item mapper shared between `handleInsert` and `handleUpdate`.
   - `mapPayments(payments)`: Canonical tender mapper shared between `handleInsert` and `handleUpdate`.
   - `extractSubtotal(...)`: Recomputes subtotal from active (un-cancelled) items or falls back to existing order.
   - `extractDiscount(...)`: Parses absolute amounts, percentage discounts, or discount object arrays with bidirectional consistency and subtotal bounding.
   - `extractTax(...)`: Parses standard tax amounts, dine-in tax, or tax arrays.
   - `extractDeliveryFee(...)`: Handles online delivery fees while ensuring dine-in defaults to 0.
   - `computeGrandTotal(...)`: Authoritative recomputation of `subtotal - discount + tax + deliveryFee`.
   - `toIsoString(val)`: Safe ISO date formatting for Date objects, strings, or numbers.

2. **Server-Side Validation & Payment Reconciliation in `handleUpdate`:**
   - Authoritatively recomputes totals.
   - Validates that `sum(payments) >= orderTotal` whenever `is_paid = true`, `payment_status = 'PAID'`, or `status = 'completed'` is requested.
   - If there is an underpayment mismatch, `handleUpdate` does NOT set `is_paid = true` or `completed`; it immediately returns a `CONFLICT` status with detailed diagnostic mismatch figures so the discrepancy remains visible in cashier conflict queues rather than silently succeeding.

3. **Idempotent Payment Upserts by Client-Generated ID:**
   - Upserts each incoming payment into `tx.orderPayment` using `where: { id: paymentId }` (using client UUID v7 or deterministic index fallback).
   - Replaying the same mutation updates existing payments in-place without duplicating payment rows or double-counting revenue.

4. **Line-Item Reconciliation in `handleUpdate`:**
   - When updated line items (`payload.items`) are sent, updates existing items in-place (preserving audit timestamps), creates newly added items, and removes active items that were removed while preserving cancelled items for audit strikethrough.

5. **Preserved Status-Only Updates & Online Invariants:**
   - For status-only patches carrying no payments or financial fields (e.g., `status = 'preparing'`), existing status-update behavior is strictly preserved without touching ledger rows or overwriting stored financials.
   - No stock or inventory double deductions are performed on settle or replay, adhering to the online settle invariant.

---

## 3. Files Changed

- `backend/src/sync/handlers/order.handler.ts` (Core fix in `OrderHandler.handleUpdate` and shared helpers)
- `backend/src/sync/handlers/order.handler.spec.ts` (Comprehensive unit test suite for all SYNC-003 acceptance requirements)
- `backend/test/sync-order-update-payment.e2e-spec.ts` (Automated integration test for Test T-03)

---

## 4. Tests Added & Results

### Unit Tests (`backend/src/sync/handlers/order.handler.spec.ts`):
- `Offline settle of a dine-in table creates payment rows equal to payload`: Verified that settling an offline dine-in table order creates `order_payment` rows matching tender details and marks the order completed and paid.
- `Replay of the same update does not duplicate payments`: Verified that replaying the identical update mutation upserts in-place and leaves exactly 1 payment record with unchanged total.
- `Total mismatch is rejected/flagged, is_paid stays false`: Verified that underpayment attempts (e.g., 2,000 paid on 3,000 bill) return `CONFLICT`, leave `is_paid: false`, and do not mark the order completed.
- `Discounts and taxes persisted and ledger total equals order total`: Verified that discounts and taxes applied at settlement update base order columns (`subtotal`, `discount_amount`, `tax_amount`, `grand_total`) and ledger total matches order total.
- `Status-only update still works without overwriting payments or financial totals`: Verified that updating status to `preparing` preserves existing financial totals and leaves payments untouched.
- `Updated line items in dine-in order are persisted and subtotal recomputed`: Verified that adding extra items during table bill settlement persists new items and recomputes the subtotal.

### Integration / E2E Tests (`backend/test/sync-order-update-payment.e2e-spec.ts`):
- `T-03: Offline dine-in order UPDATE creates payment records in database`: Full NestJS + Prisma pipeline test sending `POST /api/sync/push`.
- `T-03b: Replay of the same UPDATE mutation does not duplicate payment rows`: Verifies idempotent replay through the push endpoint.
- `T-03c: Underpayment mismatch is rejected as CONFLICT and is_paid stays false`: Verifies conflict response code through the push endpoint.

### Execution Results:
```
backend unit tests:
Test Suites: 56 passed, 56 total
Tests:       385 passed, 385 total
Time:        40.826 s

backend e2e test (sync-order-update-payment.e2e-spec.ts):
Test Suites: 1 passed, 1 total
Tests:       3 passed, 3 total
Time:        8.305 s
```

---

## 5. How to Verify Manually

1. **Start backend and database**:
   ```bash
   cd backend && npm run start:dev
   ```
2. **Create an unpaid order**:
   Issue `POST /api/orders` (or push `INSERT` mutation) for a dine-in order with 1 pizza ($25.00), `is_paid: false`, `status: 'accepted'`.
3. **Simulate offline table settlement**:
   Issue `POST /api/sync/push` with mutation:
   ```json
   {
     "device_id": "POS-P1",
     "batch_id": "batch-settle-01",
     "mutations": [
       {
         "operation_id": "op-settle-manual-01",
         "entity_type": "order",
         "entity_id": "<order-id>",
         "operation_type": "UPDATE",
         "base_version": 1,
         "payload": {
           "status": "completed",
           "payment_status": "PAID",
           "is_paid": true,
           "discount_amount": 5.00,
           "grand_total": 20.00,
           "payments": [
             {
               "id": "pay-manual-01",
               "payment_method": "cash",
               "amount": 20.00,
               "tendered_amount": 25.00,
               "change_returned": 5.00
             }
           ]
         }
       }
     ]
   }
   ```
4. **Inspect database**:
   - Query `orders` table: `is_paid = true`, `status = 'completed'`, `discount_amount = 5.00`, `grand_total = 20.00`.
   - Query `order_payments` table: 1 row with `id = 'pay-manual-01'`, `amount = 20.00`, `change_returned = 5.00`.
   - Sum of `order_payments.amount` equals `orders.grand_total`.
5. **Re-send the same push payload**:
   Verify response is `DUPLICATE` or `SYNCED`, and `order_payments` still contains exactly 1 row (no duplicate payment).

---

## 6. Residual Risks

1. **Shift Totals Calculation Timing:**
   - In Hungry Howie's POS architecture, shift reconciliations (`DailyCalculation`) maintain cash drawer totals via `ShiftHandler` when shifts close. `OrderHandler` associates settled orders with `shift_id`, but does not directly mutate closed shift records to prevent racing closed shifts.
2. **Pre-existing Unsettled Orders:**
   - Historical orders created prior to this patch with `is_paid = true` and 0 payments will remain in database unless backfilled by a data migration.
