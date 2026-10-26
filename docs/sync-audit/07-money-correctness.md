# 07 - Money Correctness Audit: Financial Invariants, Totals, Payments, Shifts, and Cash Reconciliation

> **Audit Role:** Money Correctness Auditor (`.agents/money-correctness-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop + NestJS / Prisma / PostgreSQL Backend)  
> **Reference Specification:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`  
> **Status:** Completed Authoritative Audit Baseline  
> **Date:** October 26, 2026  

---

## Executive Summary

This report delivers the authoritative money correctness audit for the Hungry Howie's POS platform. It assesses financial calculations, tax computation, discount distribution, multi-tender payment processing, stock deductions, shift drawer reconciliations, and reporting under offline, hybrid, and concurrent operational conditions.

Every claim and failure mechanism documented herein is cited with verified `file:line` locations from the active codebase.

### Key Audit Findings Overview

1. **`MNY-01` (Critical): Offline Order Update Mutation Completely Drops Payments:** In `backend/src/sync/handlers/order.handler.ts:265-279`, `OrderHandler.handleUpdate()` handles order `UPDATE` mutations by only updating `status`, `payment_status`, `is_paid`, `is_held`, and `rejection_reason`. It completely omits `payload.payments`, `discount_amount`, `tax_amount`, and `grand_total`. When an offline dining order is settled and paid, the payment ledger entries are permanently discarded by the server.
2. **`MNY-02` (Critical): Zero Tender Amount Validation in Bill Settlement:** In `frontend/lib/features/tables/tables_screen.dart:5830-5950`, `_PaymentTenderDialog._completePayment()` performs zero validation to ensure `_totalPayment >= widget.billAmount`. A cashier can enter PKR 10 on a PKR 5,000 bill and tap "SAVE", which marks the order `completed`, `isPaid = true`, and releases the table.
3. **`MNY-03` (High): Split-Payment Change Calculation Overstates Cash Ledger:** In `frontend/lib/features/tables/tables_screen.dart:5840-5848`, when cash is tendered with overpayment in a multi-tender split (e.g. PKR 1,000 cash + PKR 1,500 card on a PKR 2,000 bill), `change_returned` is not deducted from `cash.amount`. The payment ledger records PKR 2,500 in total tenders for a PKR 2,000 sale, distorting cash drawer expected totals and creating false shift shortages.
4. **`MNY-04` (High): Unpaid Orders Counted as Cash Sales in Shifts:** In `backend/src/daily-calculation/daily-calculation.service.ts:320-326` and `backend/src/sync/handlers/shift.handler.ts:434-439`, if an order has no payment records or partial payments, the server assumes the balance was paid in cash (`totalCashSales += (gTotal - orderPaidSum)`), artificially inflating cash drawer requirements for orders that are unpaid or in-kitchen.
5. **`MNY-05` (High): Server Overwrites Transaction Timestamp with Ingestion Time:** In `backend/src/orders/orders.service.ts:354-374` and `backend/src/sync/handlers/order.handler.ts:94-167`, `createOrderInTx` fails to pass `created_at` from the client's payload. PostgreSQL defaults `created_at` to server `now()`. Offline orders paid on Monday night and synced Tuesday morning are accounted as Tuesday morning revenue, corrupting daily accounting and tax periods.
6. **`MNY-06` (High): Late-Arriving Multi-Device Orders Orphaned from Closed Shift:** In `backend/src/sync/handlers/shift.handler.ts:311-328` and `backend/src/sync/handlers/order.handler.ts:170-205`, when Shift 1 is closed by Device A, its financial totals are frozen in `daily_calculations`. When Device B syncs 10 orders from Shift 1 later, `OrderHandler` attaches the orders to `shift_id = Shift 1`, but never updates the closed `daily_calculations` sales totals, creating a permanent ledger divergence where `SUM(orders.grand_total) != daily_calculations.total_gross_sales`.
7. **`MNY-07` (Medium): Unsynced Orders Adopted by Current Server Active Shift:** In `backend/src/orders/orders.service.ts:328-351`, if an order's `shift_id` does not exist on PostgreSQL at the time of push, the server attaches the order to whatever shift is currently `ACTIVE` on PostgreSQL, attributing sales to the wrong cashier and register session.
8. **`MNY-08` (High): Blind Trust of Client Pricing and Grand Totals:** In `backend/src/orders/orders.service.ts:227-262`, the server defaults `subtotal`, `grand_total`, `tax_amount`, and `discount_amount` directly from `dto` without verifying item catalog prices or recalculating arithmetic invariants.
9. **`MNY-09` (High): Order Completion Decoupled from Stock Deduction:** In `frontend/lib/application/orders/complete_order_usecase.dart:188-198` and `frontend/lib/data/repositories/api_inventory_repository.dart:118-124`, stock deductions are made via non-transactional REST calls that are swallowed on failure (`catch (_) {}`). Offline orders never deduct inventory either locally or on the server.
10. **`MNY-10` (High): Paid Orders Can Be Mutated and Deleted Without Guard:** In `frontend/lib/data/repositories/drift_offline_first_order_repository.dart:251-267, 442-467` and `backend/src/sync/handlers/order.handler.ts:328-335`, `updateOrder` and `handleDelete` permit mutating and cancelling paid orders without checking `is_paid`, permitting cash leaks and untracked cancellations.
11. **`MNY-11` (Medium): IEEE 754 Float Precision in Drift vs Decimal in Prisma:** In `frontend/lib/core/database/tables/local_orders_tables.dart:12-16` and `frontend/lib/domain/services/pricing_engine.dart:95-141`, client uses unrounded 64-bit IEEE 754 `double` math stored as Drift `RealColumn`, resulting in penny rounding discrepancies against PostgreSQL `Decimal(10, 2)`.
12. **`MNY-12` (High): Premature Order Auto-Cancellation on Shift Close:** In `backend/src/sync/handlers/shift.handler.ts:379-386`, shift closure automatically sets all unpaid orders to `cancelled`, destroying active table dining sessions and in-transit Cash-On-Delivery orders.

---

## Money Flow Diagram: Offline Cash Sale from Tap to Server Ledger

```mermaid
sequenceDiagram
    autonumber
    actor Cashier
    participant UI as Tables / POS Screen
    participant PE as PricingEngine (Domain)
    participant Repo as DriftOrderRepository
    participant Drift as Local SQLite WAL (Encrypted)
    participant Outbox as SyncOutbox (Drift)
    participant Spooler as OfflinePrintJobs (Drift)
    participant Worker as SyncBackgroundWorker
    participant Server as NestJS SyncPushService
    participant Handler as OrderHandler & OrdersService
    participant PG as PostgreSQL (Prisma $transaction)

    Note over Cashier,UI: Store Broadband Disconnected (Offline)
    Cashier->>UI: Select Items + Add Toppings + Apply 10% Discount
    Cashier->>UI: Tap "Complete Order & Pay Cash" (PKR 2,500 tendered)
    
    UI->>PE: calculateOrderTotals(items, discountPercentage: 10.0)
    PE-->>UI: PriceBreakdown(subtotal: 2000, discount: 200, tax: 180, grandTotal: 1980)

    rect rgb(235, 245, 255)
        note over UI,Drift: ONE Atomic SQLite ACID Transaction (< 5ms)
        UI->>Repo: saveOrder(order, payments: [Cash 1980, Tendered 2500, Change 520])
        Repo->>Drift: terminalSequencesDao.getNextSequence() -> P1-105
        Repo->>Drift: INSERT INTO local_orders (UUIDv7, 'P1-105', grandTotal: 1980, syncStatus: 'pending_insert')
        Repo->>Drift: INSERT INTO local_order_items (2 rows, unit_price, subtotal)
        Repo->>Drift: INSERT INTO local_order_payments (1 row, method: 'cash', amount: 1980, change: 520)
        Repo->>Outbox: INSERT INTO sync_outbox (op_id: UUIDv7, dep_order: 2, status: 'PENDING')
        Repo->>Spooler: INSERT INTO offline_print_jobs (ESC/POS raw bytes, status: 'QUEUED')
        Drift-->>Repo: Transaction Committed to WAL
    end

    par Instant Hardware & UI Feedback
        Repo-->>UI: finalOrder ('P1-105')
        UI-->>Cashier: UI ready in < 5ms; Drawer Kicks; Receipt Prints
    and Sync Worker Probing
        Worker->>Worker: probe /api/health -> SocketException
        Worker->>Outbox: Mark FAILED_RETRYABLE with exponential backoff
    end

    Note over Worker,Server: Broadband Restored 2 Hours Later
    Worker->>Worker: probe /api/health -> HTTP 200 OK
    Worker->>Outbox: getPushBatch(limit: 25) -> op_id: UUIDv7
    Worker->>Outbox: markInFlight([op_id])
    Worker->>Server: POST /api/sync/push { batch_id, mutations: [Order INSERT] }

    rect rgb(240, 255, 240)
        note over Server,PG: Isolated Prisma $transaction
        Server->>Handler: handleInsert(mutation)
        Handler->>PG: tx.order.findUnique(UUIDv7) -> null (not duplicate)
        Handler->>Handler: OrdersService.createOrderInTx()
        Handler->>PG: tx.order.create (UUIDv7, order_number: 'P1-105', grand_total: 1980.00)
        Handler->>PG: tx.orderItem.createMany (client item UUIDs preserved)
        Handler->>PG: tx.orderPayment.createMany (client payment UUIDs preserved)
        Handler->>PG: tx.processedOperation.upsert (COMPLETED)
        Handler->>PG: tx.systemChangeLog.create (INSERT, global_sequence: autoincrement)
        PG-->>Handler: Committed
    end

    Server-->>Worker: HTTP 200 OK { results: [{ op_id, status: 'SYNCED', server_version: 1 }] }
    Worker->>Outbox: markSynced(op_id)
    Worker->>Drift: markOrderSynced(orderId, version: 1)
    Worker->>UI: Sync indicator turns SOLID GREEN
```

---

## 10 Core Financial Invariants That Must Always Hold

| # | Invariant Rule | Mathematical / Logical Expression | System Enforcement Point | Current Code Status |
|---|---|---|---|---|
| **INV-1** | **Order Total Equation** | $\text{grand\_total} = \text{subtotal} - \text{discount\_amount} + \text{tax\_amount} + \text{service\_charge} + \text{delivery\_fee} \pm 0.01$ | Server `OrdersService.createOrderInTx` & Client `PricingEngine` | **VIOLATED:** Server trusts client `dto.grand_total` without validating arithmetic equality ([`orders.service.ts:258-261`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L258-L261)). |
| **INV-2** | **Item-Subtotal Integrity** | $\text{subtotal} = \sum_{i \in \text{activeItems}} (\text{quantity}_i \times \text{unit\_price}_i)$ | Server `OrdersService.createOrderInTx` & Client `PricingEngine` | **VIOLATED:** Server trusts client `dto.subtotal` without verifying against item sum ([`orders.service.ts:230`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L230)). |
| **INV-3** | **Order Settlement Parity** | If $\text{status} \in \{\text{'completed'}, \text{'PAID'}\}$, then $\sum \text{payment.amount} \ge \text{grand\_total}$ | Client UI checkout & Server order completion | **VIOLATED:** Client permits closing table with zero or partial payment ([`tables_screen.dart:5830-5950`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5830-L5950)). |
| **INV-4** | **Cash Tender Equation** | $\text{amount} = \min(\text{tendered}, \text{due})$ and $\text{change\_returned} = \max(0, \text{tendered} - \text{due})$ | Client checkout tender calculation | **VIOLATED:** Cash tender overpayment in split payments fails to deduct change from cash amount ([`tables_screen.dart:5843`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5843)). |
| **INV-5** | **Paid Order Immutability** | If $\text{is\_paid} = \text{true}$, then $\Delta(\text{items}) = 0$, $\Delta(\text{totals}) = 0$, $\Delta(\text{payments}) = 0$. Modifications require separate refund/adjustment records. | Client `DriftOrderRepository` & Server `OrderHandler` | **VIOLATED:** Client `updateOrder` and `deleteHeldOrder` mutate and delete paid orders ([`drift_offline_first_order_repository.dart:251`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L251)). Server `handleDelete` cancels paid orders ([`order.handler.ts:328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L328)). |
| **INV-6** | **Shift Cash Equation** | $\text{expected\_cash} = \text{starting\_cash} + \text{cash\_sales} - \text{skimming} - \text{expenses}$ and $\text{variance} = \text{counted} - \text{expected}$ | Server `DailyCalculationService` & Client `DailyCalculationRepository` | **VIOLATED:** Server includes unpaid orders in `cash_sales` ([`daily-calculation.service.ts:323-326`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/daily-calculation/daily-calculation.service.ts#L323-L326)). |
| **INV-7** | **Shift-Order Associative Closure** | $\text{daily\_calculations.total\_gross\_sales} = \sum_{o \in \text{shiftOrders}} o.\text{grand\_total}$ | Server `ShiftHandler` & `OrderHandler` | **VIOLATED:** Orders synced after shift closure attach to `shift_id` but never recalculate closed shift totals ([`order.handler.ts:170-205`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L170-L205)). |
| **INV-8** | **Catalog Historical Price Snapshot** | Order line items must permanently preserve unit prices quoted at the moment of sale; catalog price updates must never retroactively alter historical orders. | Server `OrderHandler` & `MenuItemsService` | **PARTIALLY COMPLIANT:** Line items preserve quoted unit prices ([`order.handler.ts:138`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L138)), but price discrepancies are unflagged. |
| **INV-9** | **Monetary Precision Preservation** | Money must be stored and computed in integer minor units (paisa/cents) or fixed-point decimal arithmetic, never in floating point. | Drift schema & Prisma schema | **VIOLATED:** Drift uses IEEE 754 float64 `RealColumn` ([`local_orders_tables.dart:12`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/local_orders_tables.dart#L12)). Dart uses unrounded `double` math ([`pricing_engine.dart:95`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/pricing_engine.dart#L95)). |
| **INV-10** | **Transaction Timestamp Immutability** | Canonical accounting timestamp is the device's transaction time, not the network sync arrival time. | Client outbox payload & Server ingestion | **VIOLATED:** Server omits payload `created_at` in `createOrderInTx`, defaulting to server `now()` ([`orders.service.ts:354`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L354)). |

---

## Detailed Checklist Analysis

### 1. Totals: Computation, Rounding, and Validation
- **Client Computation:** Subtotal, discount, tax, service charge, and grand total are calculated in `PricingEngine.calculateOrderTotals()` ([`frontend/lib/domain/services/pricing_engine.dart:87-142`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/pricing_engine.dart#L87-L142)).
  - Calculations use unrounded IEEE 754 64-bit Dart `double` floating-point math.
  - Subtotal: $\sum (\text{item.basePrice} + \text{sizeAdjustment} + \text{toppings} \times 1.50) \times \text{quantity}$. Size modifiers (`Regular: 0.0, Medium: 2.0, Large: 5.0, Extra Large: 8.0`) and topping prices ($1.50) are hardcoded in Dart (`pricing_engine.dart:18-27`).
  - Discount: Calculated as `subtotal * (discountPercentage / 100)` or `discountAmount`. Unrounded.
  - Tax: Only applied to dine-in orders (`isDineIn ? taxableSubtotal * (taxRate / 100) : 0.0`). Takeaway and delivery orders receive zero tax (`pricing_engine.dart:119`).
- **Server Computation:** In `OrdersService.createOrderInTx()` ([`backend/src/orders/orders.service.ts:227-262`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L227-L262)):
  - Rounding helper: `Math.round((val + Number.EPSILON) * 100) / 100` (`orders.service.ts:48-50`).
  - Subtotal: `dto.subtotal !== undefined ? this.round(dto.subtotal) : calculatedSubtotal` (`orders.service.ts:230`).
  - Grand Total: `dto.grand_total !== undefined ? this.round(dto.grand_total) : this.round(subtotal - discountAmountRaw + taxAmountRaw + deliveryFeeRaw)` (`orders.service.ts:258-261`).
- **Audit Verdict:** The server **does not validate or recompute totals**. It trusts whatever numbers the client transmits in `dto.subtotal` and `dto.grand_total`. Rounding implementations differ: Dart performs no intermediate rounding; JavaScript uses float rounding with `Number.EPSILON`.

### 2. Prices Offline: Stale Prices, Disabled Items, Changed Taxes
- **Behavior:** When an item's price is updated, disabled (`is_available: false`), or deleted (`is_deleted: true`) in PostgreSQL, the server does not publish rows to `system_change_logs` (Defect ARCH-02).
- **Server Sync Policy:** In `OrdersService.createOrderInTx()` ([`orders.service.ts:211-224`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L211-L224)):
  - The server verifies that `menu_item_id` exists in the database.
  - It does **not** check `menuItem.is_available` or `menuItem.is_deleted`.
  - It does **not** check `item.unit_price` against current catalog pricing.
  - It does **not** reject or flag the mutation.
- **Audit Verdict:** Outdated prices and discontinued items are accepted silently by the server without warnings, supervisor notifications, or discrepancy flags.

### 3. Payments Offline: Methods, Card Processing, Splits, Partials, and Change
- **Allowed Methods:** All methods (`cash`, `card`, `bankTransfer`, `easypaisa`, `jazzcash`) are accepted offline in `tables_screen.dart:5833-5897`.
- **Card / Electronic Payments:** There is zero hardware terminal or online payment gateway integration in the code. "Card" and "Bank Transfer" are manual text recordings (cashier swipes external countertop PDQ terminal and inputs the amount). As a result, card payments cannot fail with network gateway errors, but require manual batch settlement.
- **Split Payments:** Supported on dine-in settlement via `_PaymentTenderDialog` ([`tables_screen.dart:5739-6000`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5739-L6000)). However, `CompleteOrderUseCase` (used by takeaway/delivery) hardcodes a single payment record equal to `grandTotal` ([`complete_order_usecase.dart:163-172`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/application/orders/complete_order_usecase.dart#L163-L172)).
- **Partial Payments & Overpayment:** Overpayment change due is calculated as `_totalPayment - widget.billAmount` ([`tables_screen.dart:5827`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5827)). In multi-tender splits, change is not deducted from the cash ledger amount (`MNY-03`). Furthermore, underpayment is unblocked: a cashier can complete an order with zero tender (`MNY-02`).

### 4. Payment/Order Consistency
- **Initial Placement:** In `DriftOfflineFirstOrderRepository.saveOrder()` and `OrdersService.createOrderInTx()`, order header, items, and payments are written in a single atomic database transaction (`orders_dao.dart:23-43`, `orders.service.ts:354-485`).
- **Post-Placement Settlement:** When an order created as `UNPAID` is settled later, the client enqueues an `UPDATE` mutation. `OrderHandler.handleUpdate()` ([`order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279)) discards `payload.payments`. The order is marked `PAID` in PostgreSQL, but `order_payments` contains zero payment records (`MNY-01`).

### 5. Refunds, Voids, Discounts, and Tips
- **Refunds:** **NOT FOUND**. There are zero refund endpoints, services, or database models on the backend. Spec Directive Q6.1 explicitly disabled offline refunds, but no online refund subsystem exists either.
- **Item Cancellations:** Handled online via `POST /api/orders/:id/items/:itemId/cancel` ([`orders.service.ts:980-1120`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L980-L1120)). Cancelling an item recalculates subtotal and tax, but does **not** create a refund payment record in `order_payments` or adjust cash drawer expectations. Offline item cancellation does not exist (direct REST call only).
- **Discounts:** Discounts can be applied offline as percentages or absolute amounts. However, because `OrderHandler.handleUpdate()` drops `discount_amount`, discounts applied during bill settlement never sync to PostgreSQL (`MNY-01`).
- **Tips:** **NOT FOUND**. Tips are not tracked in `OrderPayment` or `LocalOrderPayments`.

### 6. Stock / Inventory Correctness
- **Decoupled Architecture:** Spec Directive Q4.1 mandates: *"Inventory remains independent from orders. Placing/completing an order does NOT deduct raw materials. Zero inventory concurrency conflicts exist during offline sales."*
- **Implementation Reality:** `CompleteOrderUseCase:189-198` directly violates Directive Q4.1 by invoking `stockDeductionEngine.calculateTotalIngredientRequirements()` and calling `ApiInventoryRepository.deductStockByItemName()`.
- **Offline & Sync Behavior:** When offline, `ApiInventoryRepository` catches `SocketException` and silently swallows it (`MNY-09`). When the order syncs, neither `SyncPushService` nor `OrderHandler` deducts inventory. Thus, online orders deduct stock while offline orders never deduct stock, causing physical ingredient counts to diverge from the database.

### 7. Shift and Cash Drawer Management
- **Shift Lifecycle:** Shift open is Level 0 (`dependency_order: 0`); shift close is Level 5 (`dependency_order: 5`) ([`drift_offline_first_shift_repository.dart:112, 243`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_shift_repository.dart#L112)).
- **Unsynced Orders at Shift Close:**
  - Client check: `drift_offline_first_shift_repository.dart:151-195` blocks closing a shift if local orders remain in pending status (`status.isNotIn(['completed', 'cancelled', 'rejected'])`). If `forceClose = true`, it resolves paid orders to `completed` and unpaid orders to `cancelled`.
  - Server calculation: `DailyCalculationService` and `ShiftHandler` calculate `total_cash_sales` by adding `gTotal` for any order without payment records (`MNY-04`).
  - Cash Variance: Calculated as `actualCashCounted - expectedCashDrawer` and accepted without blocking thresholds per Spec §21 Decision 2.

### 8. Day Close and Reporting
- **Timestamp Desynchronization:** Client writes local `createdAt` (`DateTime.now()`). Server omits `created_at` in `createOrderInTx` (`orders.service.ts:354-374`), defaulting to PostgreSQL `now()` at the moment of synchronization (`MNY-05`).
- **Late-Arriving Orders:** When orders sync after a shift has closed, `daily_calculations` is not recalculated. The Z-report totals frozen in `daily_calculations` permanently diverge from `SELECT SUM(grand_total) FROM orders WHERE shift_id = X` (`MNY-06`).
- **Reports Provider:** `reports_providers.dart:222-335` implements a dual-source hybrid: it queries Drift `localOrders` and merges pending offline orders with remote report data, mitigating client UI discrepancies while the device remains connected to its local database.

### 9. Currency and Precision Storage
- **Drift (Client):** `RealColumn` (SQLite REAL, 64-bit IEEE 754 float) across `local_orders`, `local_order_items`, `local_order_payments`, and `local_daily_calculations` (`local_orders_tables.dart:12-16`).
- **Prisma (Server):** `Decimal(10, 2)` for orders and payments; `Decimal(12, 2)` for shift sales and cash amounts (`schema.prisma:286-290, 557-585`).
- **Precision Hazard:** Dart does not utilize decimal fixed-point libraries or integer minor units (paisa). Floating point arithmetic produces representation errors (e.g. `0.1 + 0.2 = 0.30000000000000004`), which can cause OCC version and balance validation checks to fail (`MNY-11`).

### 10. Audit Trail and Tamper Evidence
- **Client Immutability:** `DriftOfflineFirstOrderRepository.updateOrder()` ([`drift_offline_first_order_repository.dart:251-340`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L251-L340)) lacks guards preventing edits to paid orders. `deleteHeldOrder` sets `isDeleted = true` and enqueues a `DELETE` mutation.
- **Server Cancellation Guard:** In `OrderHandler.handleDelete()` ([`order.handler.ts:328-335`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L328-L335)), an incoming `DELETE` mutation sets `status = 'cancelled'` on the order regardless of whether `is_paid` is true, wiping the transaction from revenue calculations (`MNY-10`).

---

## Scenario Traces

### Scenario 1: Cash order paid offline, app killed, reopened online 2 hours later
1. **Offline Order Placement:**
   - Cashier enters items, taps "Complete Order & Pay Cash".
   - `CompleteOrderUseCase.execute()` generates UUID v7 order ID, receipt number `P1-101`, and constructs `OrderModel` with `isPaid: true, paymentStatus: 'COMPLETED'`.
   - `DriftOfflineFirstOrderRepository.saveOrder()` commits atomic ACID transaction into Drift SQLite WAL:
     - `local_orders` row (`syncStatus = 'pending_insert'`).
     - `local_order_items` rows (`syncStatus = 'pending_insert'`).
     - `local_order_payments` row (`syncStatus = 'pending_insert'`).
     - `sync_outbox` row (`operation_id = UUID v7`, `dependency_order = 2`, `status = 'PENDING'`).
     - `offline_print_jobs` row (`status = 'QUEUED'`).
   - Thermal receipt prints, cash drawer kicks, customer receives goods.
2. **Crash / Kill:**
   - App process is killed. Data is durable in SQLite WAL on disk.
3. **Reopening 2 Hours Later:**
   - App launches. SQLCipher unlocks with DPAPI key.
   - `SyncBackgroundWorker` initializes; `watchPendingCount()` detects pending mutation.
   - `ConnectivityNotifier.probeHealth()` succeeds; worker invokes `triggerPush()`.
   - Outbox entry transitioned to `IN_FLIGHT` and sent via `POST /api/sync/push`.
4. **Server Persistence:**
   - `SyncPushService` resolves `OrderHandler.handleInsert()`.
   - `OrdersService.createOrderInTx()` commits order, items, and payments to PostgreSQL inside `prisma.$transaction()`.
   - **Defect (`MNY-05`):** `created_at` on the order and payments is stamped with server `now()` (2 hours late), shifting financial attribution to the reconnection hour instead of the transaction hour.
5. **Reconciliation:**
   - Server returns HTTP 200 `SYNCED`. Worker marks outbox and local order `SYNCED`.

### Scenario 2: Same order paid on two devices
1. **Setup:** Dine-in Table 4 has active order `ord-100` ($50.00 bill) present on both Terminal A and Terminal B.
2. **Concurrent Settlement:**
   - At 1:00 PM, Guest at Table 4 pays $50 Cash at Terminal A. Terminal A calls `orderRepo.updateOrder()`, enqueues outbox mutation `op-A` (base_version: 1).
   - At 1:01 PM, another member of the party pays $50 Card at Terminal B. Terminal B calls `orderRepo.updateOrder()`, enqueues outbox mutation `op-B` (base_version: 1).
   - Both terminals took payment (customer double-billed: $50 cash + $50 card).
3. **Sync Push Sequence:**
   - Terminal A pushes `op-A`. Server `OrderHandler.handleUpdate()` updates order status to `completed`, `is_paid = true`, increments `version` to 2. Due to `MNY-01`, Terminal A's payment record is discarded.
   - Terminal B pushes `op-B` (base_version: 1). Server detects OCC conflict (`currentVersion 2 > base_version 1`) and returns HTTP 409 `CONFLICT`.
4. **Client Rebase:**
   - Terminal B auto-rebases base_version to 2 and retries.
   - On retry, server executes `handleUpdate()`, updating `version` to 3. Terminal B's payment record is also discarded (`MNY-01`).
5. **Outcome:**
   - Order reflects $50 total revenue.
   - $50 cash is physically in Drawer A; $50 card was processed in Terminal B's card terminal.
   - Zero payment records exist in PostgreSQL `order_payments`. Neither terminal's shift reconciliation accurately reflects the double payment.

### Scenario 3: Price changed on server while device offline 1 day, then order synced
1. **Server Edit:**
   - Terminal P1 is offline.
   - Store manager changes "Pepperoni Pizza" price from $15.00 to $18.00 in the cloud web portal and disables "Garlic Knots" (`is_available = false`).
   - PostgreSQL updates `menu_items`. No change log row is written (`ARCH-02`).
2. **Offline Sale on Terminal P1:**
   - Cashier sells "Pepperoni Pizza" at $15.00 and "Garlic Knots" at $5.00 (Total: $20.00).
   - Cashier collects $20.00 cash; customer receipt prints $20.00.
3. **Reconnection Sync:**
   - Terminal P1 pushes order mutation to `POST /api/sync/push`.
4. **Server Ingestion:**
   - `OrderHandler.handleInsert()` delegates to `OrdersService.createOrderInTx()`.
   - Lines 211-224: `sanitizedItems` checks `menuItem.findUnique()`. The items exist.
   - Server does not check `is_available` or compare `unit_price` against the updated $18.00 catalog price.
   - Server commits the order at the quoted $20.00 price.
5. **Outcome:**
   - While honoring the quoted customer price satisfies Spec §10.1, the server provides zero supervisory warning or audit record that the order contained stale prices or disabled items (`MNY-08`).
   - Terminal P1 continues selling at $15.00 indefinitely until application reboot forces cold bootstrap.

### Scenario 4: Shift closed on device A while device B has 10 unsynced paid orders from same shift
1. **Setup:**
   - Shift `shift-777` is opened with starting cash PKR 10,000.
   - Device A takes 20 cash orders (PKR 40,000).
   - Device B takes 10 cash orders (PKR 20,000) under `shift-777`.
2. **Device A Closes Shift:**
   - Cashier A counts Drawer A (PKR 50,000), closes shift on Device A, and pushes mutation `op-shift-close` to server.
   - Server `ShiftHandler.handleUpdate()` queries orders for `shift-777`. Only Device A's 20 orders have synced.
   - Server freezes `shift-777`: `total_gross_sales = 40,000`, `total_cash_sales = 40,000`, `expected_cash_in_hand = 50,000`, `cash_variance = 0.00`, `status = 'CLOSED'`.
3. **Device B Syncs Late:**
   - Device B connects 1 hour later and pushes its 10 orders (PKR 20,000).
   - Server `OrderHandler.handleInsert()` commits the 10 orders with `shift_id = 'shift-777'`.
   - `OrderHandler` never updates `daily_calculations`.
   - Device B pushes its shift close mutation. Server `ShiftHandler.handleUpdate()` sees `existing.status === 'CLOSED'` and returns `DUPLICATE`, discarding Device B's cash count.
4. **Outcome:**
   - PostgreSQL `daily_calculations` reports PKR 40,000 gross sales and PKR 50,000 expected cash.
   - PostgreSQL `orders` table contains 30 orders for `shift-777` totaling PKR 60,000.
   - `daily_calculations.total_gross_sales` deviates from `SUM(orders.grand_total)` by PKR 20,000 permanently (`MNY-06`).

### Scenario 5: Retry of payment request after lost response
1. **Transmission & Execution:**
   - Client sends mutation `op-101` in batch `b-1` with header `X-Idempotency-Key: b-1`.
   - Server `IdempotencyInterceptor` passes request; `SyncPushService` processes `op-101`.
   - `OrderHandler.handleInsert()` commits order and payment into PostgreSQL.
   - `SyncPushService` inserts `processedOperation(operation_id: 'op-101', status: 'COMPLETED')` with cached response payload.
   - Database transaction commits.
2. **Response Lost:**
   - Network interface drops before HTTP 200 reaches client. Client times out (15s) and marks outbox entry `FAILED_RETRYABLE`.
3. **Client Retry:**
   - Jitter backoff elapses. Worker re-sends `op-101` in batch `b-2`.
4. **Server Replay Interception:**
   - `SyncPushService` checks `processedOperation.findUnique({ where: { operation_id: 'op-101' } })`.
   - Record found with status `COMPLETED`.
   - Immediately returns cached payload: `{ operation_id: 'op-101', entity_id: 'ord-101', status: 'SYNCED', server_version: 1 }`.
   - Business logic is skipped. No duplicate order or payment is created.
5. **Outcome:**
   - Client marks entry `SYNCED`. Clean, lossless recovery via the idempotency ledger.

---

## Detailed Findings Ledger (Prefix: `MNY`)

### MNY-01: Order Update Sync Drops Payments and Financial Totals
- Severity: Critical
- Evidence: [`backend/src/sync/handlers/order.handler.ts:265-279`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L265-L279), [`frontend/lib/data/repositories/drift_offline_first_order_repository.dart:297-321`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L297-L321)
- Failure sequence:
  1. A dine-in table order is created and synced while online or offline as `payment_status: 'UNPAID'`.
  2. Customer finishes dining and settles the bill. Cashier applies a 10% discount, adds tax, and accepts payment (Cash or Card).
  3. `DriftOfflineFirstOrderRepository.updateOrder()` updates SQLite and enqueues an outbox `UPDATE` mutation containing the payments array, discount amount, tax amount, and grand total.
  4. Background sync worker pushes the `UPDATE` mutation to `POST /api/sync/push`.
  5. `OrderHandler.handleUpdate()` executes `tx.order.update()` updating only `status`, `payment_status`, `is_paid`, `is_held`, and `rejection_reason`.
  6. The `payload.payments` array is completely ignored and never written to `tx.orderPayment`.
  7. `discount_amount`, `tax_amount`, `subtotal`, and `grand_total` are also omitted from the update payload.
- Impact: Payments taken offline for dine-in tables are completely dropped on the server. The order is marked paid in cloud reports, but `order_payments` contains zero records. Shift cash calculations fallback to unitemized cash estimations.
- Recommended fix: In `OrderHandler.handleUpdate()`, delegate to `OrdersService.updateOrder()` or explicitly execute payment ledger updates (`tx.orderPayment.deleteMany` followed by `tx.orderPayment.createMany`) and persist `discount_amount`, `tax_amount`, and `grand_total`.
- Effort: M
- Status: CONFIRMED

---

### MNY-02: Underpayment Allowed in Dine-In Tender Settlement (Zero Payment Validation)
- Severity: Critical
- Evidence: [`frontend/lib/features/tables/tables_screen.dart:5817-5848, 5922-5950`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5817-L5848)
- Failure sequence:
  1. A customer bill totals PKR 5,000 on Table 3.
  2. Cashier opens `_PaymentTenderDialog` and enters PKR 500 in the cash tender input field.
  3. `_totalPayment` calculates as 500.0, and `_change` calculates as -4500.0.
  4. Cashier taps the "SAVE" or "PRINT & FINISH" button.
  5. `_completePayment` executes with zero check verifying `_totalPayment >= widget.billAmount`.
  6. Line 5940 executes `existing.copyWith(status: OrderStatus.completed, paymentStatus: 'PAID', isPaid: true)`.
  7. Table is freed to `available`, and the order is marked fully paid with PKR 4,500 uncollected.
- Impact: Direct lost revenue. Orders can be closed and marked fully paid with partial or zero payment.
- Recommended fix: In `_PaymentTenderDialog`, add a strict guard before `_completePayment`: if `_totalPayment < widget.billAmount`, abort execution and display an error toast (`"Total tendered (PKR X) is less than bill amount (PKR Y)"`).
- Effort: S
- Status: CONFIRMED

---

### MNY-03: Cash Tender Change Calculation Corrupts Split Payments & Drawer Totals
- Severity: High
- Evidence: [`frontend/lib/features/tables/tables_screen.dart:5840-5848`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5840-L5848)
- Failure sequence:
  1. Customer bill is PKR 2,000.
  2. Customer splits payment: pays PKR 1,500 via Card and hands the cashier a PKR 1,000 cash note (Total tendered: PKR 2,500; change due: PKR 500).
  3. In `_completePayment`, lines 5840-5848:
     ```dart
     if (cash > 0) {
       paymentsList.add({
         'payment_method': 'cash',
         'amount': cash > widget.billAmount ? widget.billAmount : cash, // Evaluates to 1000
         'tendered_amount': cash, // 1000
         'change_returned': _change > 0 ? _change : 0.0, // 500
       });
     }
     ```
  4. Card payment is added with amount PKR 1,500.
  5. The payment ledger records Cash amount: PKR 1,000 and Card amount: PKR 1,500, summing to PKR 2,500 for a PKR 2,000 order.
  6. Shift cash reconciliation sums `payment.amount` where method is cash (PKR 1,000), expecting PKR 1,000 in the drawer when only PKR 500 net cash was retained.
- Impact: Distorted payment ledger records, false cash drawer shortages during end-of-shift reconciliation.
- Recommended fix: Calculate the net cash revenue as `cash - changeReturned` (or `billAmount - otherTenders`) before setting `payment.amount`.
- Effort: S
- Status: CONFIRMED

---

### MNY-04: Unpaid Orders Automatically Added to Shift Cash Sales on Server
- Severity: High
- Evidence: [`backend/src/daily-calculation/daily-calculation.service.ts:320-326`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/daily-calculation/daily-calculation.service.ts#L320-L326), [`backend/src/sync/handlers/shift.handler.ts:434-439`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L434-L439)
- Failure sequence:
  1. Cashier opens a shift. Several orders are placed during the shift (dine-in tables dining, or online deliveries pending dispatch).
  2. In `DailyCalculationService.getLiveSummary()` and `ShiftHandler.handleUpdate()`, orders are queried with `status: { notIn: ['cancelled', 'rejected'] }`. Unpaid and in-progress orders are included.
  3. Lines 323-326 execute:
     ```typescript
     } else {
       // Default unitemized tender is Cash
       totalCashSales += gTotal;
     }
     ```
  4. If an order has no payment records (e.g. unpaid dine-in bill), its full `grand_total` is added to `total_cash_sales`.
  5. If an order was partially paid by card, lines 320-322 add the remaining unpaid balance to `total_cash_sales`.
  6. Expected cash drawer requires the cashier to deposit cash for orders that haven't been paid.
- Impact: Cashier shift closure calculates massive false cash shortages for unpaid or in-progress orders.
- Recommended fix: Only include orders where `is_paid = true` or `payment_status = 'PAID'` when computing cash sales, or only sum payment records whose `payment_status = 'COMPLETED'`.
- Effort: S
- Status: CONFIRMED

---

### MNY-05: Server Replaces Client Order Timestamps with Server Ingestion Time
- Severity: High
- Evidence: [`backend/src/orders/orders.service.ts:354-374`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L354-L374), [`backend/src/sync/handlers/order.handler.ts:94-167`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L94-L167), [`backend/prisma/schema.prisma:307`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L307)
- Failure sequence:
  1. A register operates offline on Monday evening from 8:00 PM to 11:30 PM, taking PKR 80,000 in sales.
  2. Register powers off for the night.
  3. Register boots up Tuesday morning at 9:00 AM and reconnects to the network.
  4. Background worker pushes the offline orders to `POST /api/sync/push`.
  5. `OrderHandler.handleInsert()` maps the payload to `createDto`. It omits `created_at`.
  6. In `OrdersService.createOrderInTx()`, `tx.order.create()` and `tx.orderPayment.createMany()` do not supply `created_at`.
  7. PostgreSQL defaults `created_at` to server execution timestamp (Tuesday 9:01 AM).
  8. Monday's sales reports show zero revenue; Tuesday's sales reports show PKR 80,000 inflated revenue.
- Impact: Distorted sales reports, invalid tax period reporting, corrupted hourly business analytics.
- Recommended fix: Include `created_at` in `CreateOrderDto`, map `payload.created_at` in `OrderHandler`, and pass `created_at: dto.created_at ? new Date(dto.created_at) : undefined` into `tx.order.create` and `tx.orderPayment.createMany`.
- Effort: S
- Status: CONFIRMED

---

### MNY-06: Late-Arriving Offline Orders from Multi-Device Shift Orphaned from Closed Shift Record
- Severity: High
- Evidence: [`backend/src/sync/handlers/shift.handler.ts:311-328`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L311-L328), [`backend/src/sync/handlers/order.handler.ts:170-205`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L170-L205)
- Failure sequence:
  1. Terminal A and Terminal B both take orders under active shift session `shift-01`.
  2. Internet connection drops. Terminal B takes 10 cash orders ($500).
  3. Terminal A finishes shift and reconnects first. Cashier A counts Drawer A and submits shift close.
  4. Server `ShiftHandler.handleUpdate()` calculates totals based only on Terminal A's orders, writes `total_gross_sales`, and sets `status = 'CLOSED'`.
  5. Terminal B reconnects 2 hours later and pushes its 10 orders.
  6. `OrderHandler.handleInsert()` creates the orders and links them to `shift_id = 'shift-01'`.
  7. `OrderHandler` never updates `daily_calculations`.
  8. When Terminal B attempts to push its shift close mutation, `ShiftHandler` returns `DUPLICATE` because the shift is already closed.
- Impact: Terminal B's $500 in sales is permanently missing from `daily_calculations`. `SUM(orders.grand_total)` exceeds `daily_calculations.total_gross_sales` by $500, corrupting Z-reports.
- Recommended fix: When `OrderHandler.handleInsert()` ingests an order whose `shift_id` belongs to a shift with `status IN ('CLOSED', 'OFFLINE_CLOSED')`, re-aggregate the shift's financial totals and update `daily_calculations` with a flag (`late_orders_reconciled: true`).
- Effort: M
- Status: CONFIRMED

---

### MNY-07: Unsynced Order Assigned to Arbitrary Server Active Shift Upon Push
- Severity: Medium
- Evidence: [`backend/src/orders/orders.service.ts:328-351`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L328-L351)
- Failure sequence:
  1. An order is created offline during a shift session whose open mutation was delayed or not yet synced to PostgreSQL.
  2. When the order syncs, `createOrderInTx` attempts `tx.dailyCalculation.findUnique({ where: { id: activeShiftId } })`.
  3. The query returns `null` because the shift record does not exist on PostgreSQL yet.
  4. Line 330 logs a warning and resets `activeShiftId = null`.
  5. Lines 338-351 execute fallback logic: `tx.dailyCalculation.findFirst({ where: { status: 'ACTIVE' } })`.
  6. The server assigns the order to whatever shift is currently active on the server at that moment.
- Impact: Orders are attributed to the wrong shift, wrong cashier, and wrong business date.
- Recommended fix: If `dto.shift_id` is supplied, retain the foreign key reference even if the shift record has not synced yet, relying on dependency order (`dependency_order: 0` before `2`) or create a placeholder shift row.
- Effort: S
- Status: CONFIRMED

---

### MNY-08: Zero Server Verification of Prices, Taxes, and Totals (Blind Trust of Client)
- Severity: High
- Evidence: [`backend/src/orders/orders.service.ts:227-262`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L227-L262)
- Failure sequence:
  1. Client sends order mutation payload with `subtotal`, `grand_total`, `tax_amount`, and `discount_amount`.
  2. Server assigns: `subtotal = dto.subtotal !== undefined ? this.round(dto.subtotal) : calculatedSubtotal`.
  3. Server assigns: `grandTotal = dto.grand_total !== undefined ? this.round(dto.grand_total) : ...`.
  4. The server never validates that `item.unit_price` matches `MenuItem.base_price` or size modifiers.
  5. The server never checks if $\text{grand\_total} == \text{subtotal} - \text{discount} + \text{tax} + \text{deliveryFee}$.
  6. A client bug, floating point error, or tampered payload can set `grand_total: 1.00` on a $100 order, and the server commits it without verification.
- Impact: Financial leakage, silent calculation errors, vulnerability to client-side manipulation.
- Recommended fix: Implement server-side recomputation in `OrdersService.createOrderInTx()`. If client totals deviate from server recalculations by more than a configurable rounding threshold (e.g. > $0.05), reject or flag the transaction for supervisor audit.
- Effort: M
- Status: CONFIRMED

---

### MNY-09: Complete Order Execution Decoupled from Inventory Deduction (Ghost Inventory)
- Severity: High
- Evidence: [`frontend/lib/application/orders/complete_order_usecase.dart:188-198`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/application/orders/complete_order_usecase.dart#L188-L198), [`frontend/lib/data/repositories/api_inventory_repository.dart:118-124`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/api_inventory_repository.dart#L118-L124)
- Failure sequence:
  1. Cashier completes an order in POS checkout.
  2. `CompleteOrderUseCase.execute()` invokes `inventoryRepository.deductStockByItemName()`.
  3. `ApiInventoryRepository` issues direct HTTP calls to `/api/inventory/stock-out`.
  4. If offline, the network call throws `SocketException`. Line 124 catches and silently swallows the error (`catch (_) {}`).
  5. No local Drift inventory table exists; no outbox mutation is created.
  6. When the order syncs to the server, `OrderHandler` does not touch inventory.
  7. Physical ingredients are consumed, but cloud stock records are never decremented.
- Impact: Inventory records in PostgreSQL remain untouched for all offline orders, creating ghost inventory and invalid stock valuation.
- Recommended fix: Enforce Developer Directive Q4.1: completely decouple inventory deductions from the order completion path, or record inventory deductions in the same outbox transaction.
- Effort: M
- Status: CONFIRMED

---

### MNY-10: Paid Orders Mutated and Deleted Without Audit Trail or Guard
- Severity: High
- Evidence: [`frontend/lib/data/repositories/drift_offline_first_order_repository.dart:251-267, 442-467`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L251-L267), [`backend/src/sync/handlers/order.handler.ts:328-335`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/order.handler.ts#L328-L335)
- Failure sequence:
  1. An order is completed and paid in cash.
  2. `DriftOfflineFirstOrderRepository.updateOrder()` allows any caller to overwrite items, subtotal, discount, and grand total without checking `isPaid`.
  3. `deleteHeldOrder()` marks the order `isDeleted = true` and queues a `DELETE` mutation.
  4. Server `OrderHandler.handleDelete()` receives the `DELETE` mutation and sets `status = 'cancelled'`.
  5. Line 328 does not check `existing.is_paid`.
  6. The paid order is cancelled, removing it from sales reports and daily calculations, while cash remains in the drawer unaccounted for.
- Impact: Cash theft vulnerability, loss of transaction immutability, broken audit trail.
- Recommended fix: In both `DriftOfflineFirstOrderRepository` and server `OrderHandler`, reject updates and deletions if `order.is_paid == true` or `order.status == 'completed'`. Enforce that paid orders can only be modified via explicit supervisory void/refund records.
- Effort: S
- Status: CONFIRMED

---

### MNY-11: IEEE 754 Float Precision in Drift vs Decimal in Prisma
- Severity: Medium
- Evidence: [`frontend/lib/core/database/tables/local_orders_tables.dart:12-16`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/local_orders_tables.dart#L12-L16), [`backend/prisma/schema.prisma:286-290`](file:///D:/HOWIES%20TEST/howiesPOS/backend/prisma/schema.prisma#L286-L290), [`frontend/lib/domain/services/pricing_engine.dart:95-141`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/pricing_engine.dart#L95-L141)
- Failure sequence:
  1. Drift stores monetary amounts using `RealColumn` (SQLite REAL, IEEE 754 64-bit float).
  2. Dart `PricingEngine` accumulates totals using double-precision floating-point arithmetic without scaling to integer minor units.
  3. Calculations like `19.99 * 0.15` yield `2.9985`, which when subtracted and added yields fractional floating-point representations.
  4. When pushed via JSON, the numbers are parsed into JavaScript numbers and stored into PostgreSQL `Decimal(10, 2)`.
  5. Floating-point epsilon discrepancies cause balance validation checks (`totalPaid >= grandTotal`) to fail or produce 1-cent rounding variances between client and server.
- Impact: Penny reconciliation variances, rounding errors in reports.
- Recommended fix: Store currency in integer minor units (cents / paisa) across Drift tables, or round all arithmetic in `PricingEngine` using fixed two-decimal scaling (`(val * 100).round() / 100`).
- Effort: M
- Status: CONFIRMED

---

### MNY-12: Premature Order Auto-Cancellation on Shift Close
- Severity: High
- Evidence: [`backend/src/sync/handlers/shift.handler.ts:379-386`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/handlers/shift.handler.ts#L379-L386)
- Failure sequence:
  1. Cashier closes shift on register terminal via `shift.handler.ts:handleUpdate()`.
  2. Lines 379-386 execute:
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
  3. Any order associated with this shift that has `is_paid: false` is automatically updated to `status = 'cancelled'`.
  4. Dine-in tables with active seated guests who have not paid their bill yet, or online delivery orders out for Cash-On-Delivery, are cancelled in the database.
  5. When the guest later pays or the delivery rider returns with cash, the order has already been marked `cancelled`.
- Impact: Active orders cancelled prematurely; collected cash cannot be reconciled against cancelled orders.
- Recommended fix: Do not auto-cancel unpaid orders during shift close. Instead, disassociate active dining orders from the closing shift and roll them over to the next active shift (`shift_id = null` or next shift).
- Effort: S
- Status: CONFIRMED

---

## Conclusion & Audit Recommendations Matrix

| Finding ID | Vulnerability | Severity | Target Remediation Layer | Remediation Summary |
|---|---|---|---|---|
| **`MNY-01`** | Payment Drop on Order UPDATE | **Critical** | Backend: `order.handler.ts` | Process `payload.payments` and update totals inside `handleUpdate()`. |
| **`MNY-02`** | Underpayment Settlement | **Critical** | Frontend: `tables_screen.dart` | Guard `_completePayment` against `_totalPayment < billAmount`. |
| **`MNY-03`** | Cash Overpayment in Splits | **High** | Frontend: `tables_screen.dart` | Subtract `change_returned` from cash `payment.amount`. |
| **`MNY-04`** | Unpaid Orders in Cash Sales | **High** | Backend: `daily-calculation.service.ts` | Only sum payment records where status is `COMPLETED`. |
| **`MNY-05`** | Server Overwriting Timestamp | **High** | Backend: `order.handler.ts` | Pass client `created_at` into `tx.order.create` and `tx.orderPayment.createMany`. |
| **`MNY-06`** | Multi-Device Late Orders | **High** | Backend: `order.handler.ts` | Recalculate closed shift totals when late orders arrive. |
| **`MNY-07`** | Active Shift Theft | **Medium** | Backend: `orders.service.ts` | Do not reassign `shift_id` to arbitrary active shift if ID was provided. |
| **`MNY-08`** | Unverified Client Totals | **High** | Backend: `orders.service.ts` | Recompute line totals and validate `grand_total` invariant on server. |
| **`MNY-09`** | Decoupled Inventory Deduction | **High** | Frontend / Backend | Comply with Directive Q4.1 or include deductions in outbox transaction. |
| **`MNY-10`** | Paid Order Mutation / Deletion | **High** | Client / Backend | Reject mutations/deletions on paid orders (`is_paid == true`). |
| **`MNY-11`** | Floating-Point Precision | **Medium** | Drift / Dart Domain | Round all intermediate calculations in `PricingEngine` to 2 decimals. |
| **`MNY-12`** | Shift Auto-Cancellation | **High** | Backend: `shift.handler.ts` | Rollover unpaid orders to next shift instead of setting to `cancelled`. |
