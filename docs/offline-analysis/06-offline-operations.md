# Offline Operations Matrix & Per-Operation Analysis

**Document:** `docs/offline-analysis/06-offline-operations.md`  
**Phase:** Phase 6 — Offline Operations Analysis (Wave 1)  
**Target System:** Hungry Howie's POS (Flutter Windows Desktop + NestJS / Prisma / PostgreSQL Backend)  
**Status:** Complete  

---

## 1. Executive Summary & Architecture Principles

The offline-first architecture for the Hungry Howie's Point of Sale (POS) system must guarantee that retail store transactions can proceed uninterrupted during wide-area network (WAN) outages, local broadband failures, and backend server maintenance windows. In a high-volume fast-casual pizzeria environment, halting cashier order intake, dining table turns, or cash receipt printing due to network loss directly causes immediate revenue loss and customer dissatisfaction.

### Core Architectural Principles
1. **Server as Single Source of Truth:** Cloud PostgreSQL remains the authoritative ledger for finalized financial data, official consecutive tax receipts, system-wide inventory valuations, and role permissions.
2. **Local Operational Store:** The Flutter Windows client relies on a local relational operational database (Drift / SQLite) that mirrors necessary active operational tables (Menu Catalog, Active Shift, Tables, Active Orders, Local Stock, Customer Cache).
3. **Outbox Synchronization Queue:** All offline state mutations are staged as immutable events in an Outbox Queue (`sync_outbox`) with cryptographic UUIDs and idempotency keys, guaranteeing exactly-once processing on the server.
4. **WebSocket for Realtime Invalidation Only:** WebSockets provide optimistic low-latency push notifications (e.g. order ready, table occupied). WebSockets are never relied upon as a guarantee of transactional consistency.
5. **Data Integrity over Convenience:** Operations involving irreversible financial debits (e.g. online card payment gateway capture, salary disbursals, uncontrolled high-value refunds) or security authorization (role escalation, user account creation) must be strictly **BLOCKED** or gated while offline.
6. **Feature Flag Boundary:** The entire offline operational engine is encapsulated behind `OFFLINE_FIRST_ENABLED`. When disabled, the POS strictly executes existing REST API calls without behavioral divergence.

---

## 2. Operational State Lifecycle

To eliminate ambiguity across UI components, repositories, and background sync workers, all entity models adhere to a 5-state lifecycle model:

```
[Local State] ──(User Action)──> [Pending State (Outbox Queued)]
                                           │
                              ┌────────────┴────────────┐
                     (Sync Success)                (Conflict/Rejected)
                              ▼                         ▼
                        [Synced State]           [Conflict State]
                              │                         │
                     (Server Update WS)        (Supervisor Intervention)
                              ▼                         ▼
                        [Server State]          [Resolved / Overridden]
```

* **Local State (`local`):** Temporary, uncommitted UI state (e.g., items currently sitting in the POS shopping cart before the cashier clicks "Complete Order" or "Hold Order" in `frontend/lib/data/pos_repository.dart:305-356`).
* **Pending State (`pending`):** Locally committed transaction written to SQLite tables and registered in the `sync_outbox` table with `sync_status = 'pending'`, awaiting cloud synchronization (`backend/src/sync/sync.service.ts:43-48`).
* **Synced State (`synced`):** Successfully transmitted to and acknowledged by NestJS/PostgreSQL backend (`backend/src/sync/sync.service.ts:200-206`). The client records `synced_at` timestamp and server-assigned canonical IDs where applicable.
* **Server State (`server_authoritative`):** Read-only snapshot of database state fetched from the cloud server (e.g., store tax rates, global catalog prices, employee hourly rates).
* **Conflict State (`conflict`):** A queued write was rejected by the server due to concurrency collision, state divergence, or rule violation (e.g., table occupied by another terminal, duplicate phone number conflict, closed shift). Requires automated domain merging or supervisor resolution.

---

## 3. Master Offline Operations Matrix

The following operational matrix evaluates every store operation found across the Flutter frontend and NestJS backend.

| Operation | Must work offline? | WHY | Local storage needed | Sync priority | Conflict risk | Needs server approval? |
|---|---|---|---|---|---|---|
| **Create Order (Dine-In)** | YES | Pizzeria cannot stop seating and taking food orders when internet drops (`backend/src/orders/orders.service.ts:348-370`). | `orders`, `order_items`, `dine_in_order_details`, `restaurant_tables`, `sync_outbox` | High (P1) | Low-Med (UUID primary key; table collision if multi-terminal) | NO (Immediate local commitment) |
| **Create Order (Takeaway)** | YES | Walk-in counter customers must receive sequential tokens and receipts immediately (`backend/src/orders/orders.service.ts:326-347`). | `orders`, `order_items`, `takeaway_order_details`, `sync_outbox` | High (P1) | Low (Client-scoped token prefix e.g. `TK-A101`) | NO |
| **Create Order (Delivery / Online Direct)** | YES (Phone/In-Store Take) | Phone orders taken by cashier during outage must be captured and sent to kitchen (`backend/src/orders/orders.service.ts:302-325`). | `orders`, `order_items`, `online_order_details`, `delivery_dispatches`, `sync_outbox` | High (P1) | Low | NO |
| **Update Order (Draft / Dine-In)** | YES | Guests add drinks/sides, modify crust/sizes, or alter guest count before settlement (`backend/src/orders/orders.service.ts:468-577`). | `orders`, `order_items`, `dine_in_order_details`, `sync_outbox` | High (P1) | Med-High (Concurrent terminal edits) | NO for open orders; BLOCKED for paid orders (`orders.service.ts:480`) |
| **Cancel Order** | YES (Restricted) | Customers walk out or cancel before prep; cashier must free table and void order (`backend/src/orders/orders.service.ts:819-845`). | `orders`, `order_items`, `restaurant_tables`, `sync_outbox` | High (P1) | Medium (Server already marked completed) | NO for unpaid; BLOCKED for settled/paid orders (`orders.service.ts:892`) |
| **Add Item to Order** | YES | Incremental item additions during active dining session (`backend/src/orders/orders.service.ts:538-559`). | `order_items`, `orders` (recalculated totals), `sync_outbox` | High (P1) | Medium (Append-only item IDs prevent overwrite) | NO |
| **Remove / Cancel Item from Order** | YES (Supervisor PIN) | Food item ordered by mistake or kitchen ran out; strikethrough audit required (`backend/src/orders/orders.service.ts:908-987`). | `order_items` (`is_cancelled=1, cancel_reason`), `orders`, `sync_outbox` | High (P1) | Medium | NO (Local supervisor PIN authorization required) |
| **Reserve Table** | YES | Walk-ins or phone calls requesting table holds must be recorded locally (`backend/src/tables/tables.service.ts:523-559`). | `restaurant_tables` (`status='reserved', reserved_customer_name`), `sync_outbox` | Medium (P2) | High (Another terminal seats party at same table) | NO (Operational priority; Seated party wins) |
| **Release Table** | YES | Table cleared after guests leave must be marked available for new guests (`backend/src/tables/tables.service.ts:397-415`). | `restaurant_tables` (`status='available', current_bill=0`), `sync_outbox` | High (P1) | Low-Med | NO |
| **Move / Transfer Table** | YES | Guests request relocation (e.g. Table 2 to Table 5) (`backend/src/tables/tables.service.ts:417-521`). | `restaurant_tables` (source & dest), `dine_in_order_details`, `sync_outbox` | High (P1) | High (Target table occupied on another terminal) | NO (Fails gracefully to conflict queue if target occupied) |
| **Merge Tables** | CONDITIONAL / NOT FOUND in code | Pizzeria groups combining tables; not implemented in existing backend (`backend/src/tables/tables.service.ts`). | N/A (Feature not implemented in backend) | N/A | High | NOT FOUND in codebase |
| **Payment: Cash** | YES | Primary physical payment mode; store operations cannot stop cash collection (`backend/src/orders/orders.service.ts:405-417`). | `order_payments`, `orders` (`is_paid=true, payment_status='PAID'`), `sync_outbox` | Highest (P0) | Low (Idempotent order UUID linkage) | NO |
| **Payment: Offline Card (External PDQ)** | YES | Standalone EMV swipe/chip machine prints paper approval slip; POS records auth code & last 4 (`backend/prisma/schema.prisma:424-426`). | `order_payments` (`card_last_four, transaction_reference`), `orders`, `sync_outbox` | Highest (P0) | Low | NO |
| **Payment: Integrated Cloud Gateway** | BLOCKED | Direct REST payment capture via cloud gateway cannot execute without internet. | N/A | N/A | High | YES (Network connection strictly required) |
| **Refund** | BLOCKED (or strictly capped) | Uncontrolled cash/card refunds offline risk double refund fraud (`backend/src/orders/orders.service.ts:892-897`). | Local audit log only if emergency override allowed | Highest (P0) | Critical (Chargeback & financial loss) | YES (Server approval & manager credential mandatory) |
| **Inventory Deduction (Auto Recipe)** | YES (Local Decr.) | POS must not block sale if local stock counter drops below 0 (`frontend/lib/application/orders/complete_order_usecase.dart:176-186`). | `inventory_items` (`current_stock, used_stock`), `stock_movements`, `sync_outbox` | Medium (P2) | High (Multi-terminal concurrent deductions) | NO (Syncs as delta decrement: `stock = stock - N`) |
| **Inventory Adjustment (Wastage / Drop)** | YES (Supervisor PIN) | Kitchen drops pizza or discovers spoiled dough; must record wastage immediately (`backend/src/inventory/inventory.service.ts:271-334`). | `stock_movements` (`movement_type='wastage'`), `inventory_items`, `sync_outbox` | Medium (P2) | Low-Med | NO (Local supervisor approval) |
| **Inventory Restock (Stock-In)** | LIMITED / BLOCKED | Warehouse bulk inward deliveries must be verified against server supplier invoices (`backend/src/inventory/inventory.service.ts:214-269`). | `inventory_items`, `stock_movements`, `sync_outbox` | Low (P3) | High (Overwriting server PO purchase orders) | YES (Manager role; deferred until online unless emergency) |
| **Product 86ing (Toggle Availability)** | YES | Kitchen runs out of mushrooms/cheese; cashiers must immediately disable item on UI (`backend/src/menu/items/items.service.ts:248-268`). | `menu_items` (`is_available` boolean), `sync_outbox` | High (P1) | Low (Last-Write-Wins boolean) | NO |
| **Product Catalog CRUD (Add/Edit Price)** | BLOCKED | Editing menu item base price or creating deals offline creates catalog divergence (`backend/src/menu/items/items.service.ts:107-246`). | N/A | Low (P3) | Extreme (Price discrepancies across terminals) | YES (Cloud server is sole authority for menu & prices) |
| **Customer Creation & Update** | YES | Cashier taking phone/delivery order must create customer record locally (`backend/src/customers/customers.service.ts:54-79`). | `customers` (UUID, full_name, phone, address), `sync_outbox` | High (P1) | High (Unique phone collision `customers.service.ts:59`) | NO (Server upserts by phone during sync) |
| **Shift Open (Start Session / Float)** | YES | Morning shift must open cash drawer and register starting change float (`backend/src/daily-calculation/daily-calculation.service.ts:77-161`). | `daily_calculations` (`status='ACTIVE'`, starting_cash float), `sync_outbox` | High (P1) | Medium (Multiple terminals opening shift) | NO (Terminal-scoped shift session) |
| **Shift Close (Submit & Table Reset)** | CONDITIONAL (Draft Close) | Cashier must count drawer and go home; but server closing triggers storewide reset (`backend/src/daily-calculation/daily-calculation.service.ts:331-610`). | `daily_calculations` (`status='PENDING_CLOSURE'`, cash count), `daily_expense_items`, `sync_outbox` | Highest (P0) | Critical (Unsynced orders cause validation failure `line 424`) | YES (Server verifies all shift orders synced before closing) |
| **Shift Petty Expense (Cash Skimming)** | YES | Cashier takes cash from register for emergency store supplies (`backend/src/daily-calculation/daily-calculation.service.ts:37-52`). | `daily_expense_items`, `expenses`, `sync_outbox` | High (P1) | Low (Drawer cash balance requirement) | NO |
| **Delivery Rider Assign & Dispatch** | YES | Local delivery orders dispatched to clocked-in riders (`backend/src/delivery/dispatches/dispatches.service.ts:182-260`). | `delivery_dispatches` (`rider_id, dispatch_status='outForDelivery'`), `delivery_riders`, `sync_outbox` | High (P1) | Medium (Rider delivery capacity counter) | NO |
| **Kitchen Ticket Dispatch (KDS)** | YES (Local LAN) | Cook in kitchen must see pizza on KDS screen even if WAN cloud is disconnected (`backend/src/kitchen/kitchen.service.ts:141-201`). | Local KDS WebSocket or LAN SQLite replicate | Highest (P0) | Low | NO |
| **Receipt Printing (ESC/POS)** | YES (Local Hardware) | Customer paper receipt and kitchen prep slips print directly via USB/Spooler (`backend/src/printer/printer.service.ts:20-64`). | Direct Windows Print Spooler / Raw ESC/POS bytecode | Highest (P0) | None | NO |
| **Staff User Creation / Password Reset** | BLOCKED | Security risk; password hashing and credential storage must be centralized (`backend/src/users/users.service.ts:83-100`). | N/A | Low (P3) | Extreme | YES (Cloud Admin authority required) |
| **Role & Permissions Modification** | BLOCKED | Changing role permissions offline allows unauthorized privilege escalation (`backend/src/permissions/permissions.service.ts:120-220`). | N/A | Low (P3) | Extreme | YES (Cloud Admin authority required) |
| **Staff Salary Settlement / Disbursal** | BLOCKED | Disbursing payroll funds is a back-office financial transaction requiring online ledger (`backend/src/staff/staff.service.ts:200-260`). | N/A | Low (P3) | Critical | YES (Online Cloud Ledger required) |
| **Store Settings Update** | BLOCKED | Updating store tax rate, branch metadata, or legal info (`backend/src/settings/settings.service.ts:22-52`). | N/A | Low (P3) | High | YES (Cloud Admin authority required) |

---

## 4. Deep-Dive Per-Operation Analysis

### 4.1 Create Order (Dine-In, Takeaway, Online/Delivery)
* **Code Paths:**
  * Backend: [`backend/src/orders/orders.service.ts:137-463`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L137-L463) (`createOrder`)
  * Backend Controller: [`backend/src/orders/orders.controller.ts:44-52`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.controller.ts#L44-L52)
  * Frontend Orchestration: [`frontend/lib/application/orders/complete_order_usecase.dart:66-193`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/application/orders/complete_order_usecase.dart#L66-L193)
  * Frontend Repository: [`frontend/lib/data/pos_repository.dart:486-561`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/pos_repository.dart#L486-L561)
* **Business Rules & Constraints in Code:**
  1. Sequential Order Number generation (`backend/src/orders/orders.service.ts:230-260`): The backend generates a 3-digit receipt sequence (101 to 999). If offline clients generate simple integer numbers, two disconnected terminals will collide (`ConflictException: Order number '105' already exists`, line 258).
  2. Active Shift Linkage (`backend/src/orders/orders.service.ts:262-277`): Backend attaches the order to `dailyCalculation` where `status = 'ACTIVE'`.
  3. Dine-In Table Occupation (`backend/src/orders/orders.service.ts:360-369`): Automatically sets `restaurantTable.status = 'occupied'`, `current_bill_amount = grandTotal`, and `active_order_id = createdOrder.id`.
  4. Takeaway Token generation (`backend/src/orders/orders.service.ts:327-336`): Unique token `TK-XXX`.
* **Local Storage Schema:**
  * `orders` table: `id` (UUIDv4 generated locally), `order_number` (formatted with device prefix e.g. `T1-105`), `order_type`, `status` (`newOrder`), `subtotal`, `tax_amount`, `grand_total`, `is_paid`, `shift_id`, `created_at`, `sync_status = 'pending'`, `device_id`.
  * `order_items` table: `id` (UUID), `order_id`, `menu_item_id`, `item_name`, `quantity`, `unit_price`, `total_price`, `selected_size`, `selected_crust`, `extra_toppings`.
  * `dine_in_order_details` / `takeaway_order_details` / `online_order_details`.
  * `sync_outbox` table: Enqueue `CREATE_ORDER` event payload with idempotency key `order_<uuid>`.
* **Sync Priority:** `HIGH (P1)`.
* **Conflict Vector & Resolution Strategy:**
  * Primary keys must use client-generated UUIDv4 to avoid ID collision.
  * Order numbers generated offline must be formatted as `<DevicePrefix>-<DailySeq>` (e.g. `W1-101`) to eliminate primary key / unique constraint collisions on `order_number` (`backend/src/orders/orders.service.ts:258`).
  * On sync, server preserves the local order ID and registers the transaction into `data_sync_logs` (`backend/src/orders/orders.service.ts:421-445`).

---

### 4.2 Update Order (Draft / Unpaid Dine-In Orders)
* **Code Paths:**
  * Backend: [`backend/src/orders/orders.service.ts:468-814`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L468-L814) (`updateOrder`)
  * Backend Immutability Guard: [`backend/src/orders/orders.service.ts:480-484`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L480-L484)
* **Business Rules & Constraints in Code:**
  1. Immutability: "completed or paid orders are immutable historical records. If existing.is_paid || existing.status === 'completed' || existing.status === 'cancelled', throws BadRequestException" (`lines 480-484`).
  2. Non-destructive item reconciliation (`lines 513-567`): Active items missing from incoming list are deleted; cancelled items are never deleted to preserve audit logs (`line 561`).
  3. Automatic table bill update (`lines 733-737`): Table bill amount is updated to match recalculated grand total.
* **Local Storage Schema:**
  * Update `orders` row locally with new totals and increment local `version` column.
  * Sync outbox: Enqueue `UPDATE_ORDER` with `order_id`, item diffs, and `base_version`.
* **Sync Priority:** `HIGH (P1)`.
* **Conflict Vector & Resolution Strategy:**
  * Conflict: If Terminal A updates items on Table 4 offline while Terminal B updates Table 4 online or offline.
  * Resolution: Optimistic concurrency control using `version` column. If incoming `base_version < server.version`, perform item-level CRDT union (append new items, take highest quantity per item, never un-cancel cancelled items).

---

### 4.3 Cancel Order
* **Code Paths:**
  * Backend: [`backend/src/orders/orders.service.ts:819-879`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L819-L879) (`updateOrderStatus`)
  * Backend Deletion Guard: [`backend/src/orders/orders.service.ts:892-897`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L892-L897)
* **Business Rules & Constraints in Code:**
  1. Deletion restriction (`line 892`): Paid and completed orders are permanent financial records and cannot be deleted. They may only have status set to `cancelled` via status update.
  2. Cascade item cancellation (`lines 826-835`): When order is cancelled, all constituent items are flagged `is_cancelled = true`, `cancelled_at = now()`, `cancel_reason = rejection_reason`.
* **Local Storage Schema:**
  * Set `orders.status = 'cancelled'`, `orders.rejection_reason = reason`.
  * Set `order_items.is_cancelled = 1` for all order items.
  * Release associated table: `restaurant_tables.status = 'available'`.
  * Enqueue `CANCEL_ORDER` in `sync_outbox`.
* **Sync Priority:** `HIGH (P1)`.
* **Conflict Vector & Resolution Strategy:**
  * If order was already paid or completed on server before client's cancel sync arrives, the server rejects the cancellation (`BadRequestException`). Client receives `CONFLICT_ORDER_ALREADY_PAID` and alerts cashier/supervisor.

---

### 4.4 Add Item / Remove Item
* **Code Paths:**
  * Backend Add: [`backend/src/orders/orders.service.ts:538-559`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L538-L559)
  * Backend Remove / Partial Cancel: [`backend/src/orders/orders.service.ts:908-1060`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L908-L1060) (`cancelOrderItem`)
* **Business Rules & Constraints in Code:**
  1. Partial Item Split (`backend/src/orders/orders.service.ts:943-976`): If cancelling 1 of 3 pizzas, existing item quantity is decremented to 2, and a new `order_items` record is created for quantity 1 with `is_cancelled: true`, `cancel_reason`, and `cancelled_by`.
  2. Financial recalculation (`lines 990-1043`): Subtotal, discount percentage, tax, and grand total are atomically recalculated. Table `current_bill_amount` is updated (`line 1047`).
* **Local Storage Schema:**
  * Local `order_items` table mirrors split audit logic.
  * Enqueue `CANCEL_ORDER_ITEM` or `ADD_ORDER_ITEM` with item UUIDs in `sync_outbox`.
* **Sync Priority:** `HIGH (P1)`.
* **Conflict Vector & Resolution Strategy:**
  * Items are identified by UUID rather than array index. Adding an item is always additive. Cancelling an item is idempotent (`backend/src/orders/orders.service.ts:932-938`).

---

### 4.5 Reserve Table, Release Table, Move Table
* **Code Paths:**
  * Reserve: [`backend/src/tables/tables.service.ts:523-559`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/tables/tables.service.ts#L523-L559) (`updateTableReservation`)
  * Release: [`backend/src/tables/tables.service.ts:397-415`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/tables/tables.service.ts#L397-L415) (`releaseTable`)
  * Move / Transfer: [`backend/src/tables/tables.service.ts:417-521`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/tables/tables.service.ts#L417-L521) (`transferTable`)
  * Delete Table Guard: [`backend/src/tables/tables.service.ts:576-580`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/tables/tables.service.ts#L576-L580) (cannot delete occupied table)
* **Business Rules & Constraints in Code:**
  1. Transfer Validation (`lines 433, 445`): Source table must be `occupied`, destination table must NOT be `occupied` (`ConflictException: Destination table is already occupied`).
  2. Reassignment (`lines 470-484`): Moves `dineInOrderDetail.table_id` to destination table and copies bill amount.
* **Local Storage Schema:**
  * Local table state updated in `restaurant_tables`. Outbox records `TRANSFER_TABLE` or `RELEASE_TABLE`.
* **Sync Priority:** `HIGH (P1)` for Release/Transfer; `MEDIUM (P2)` for Reservation.
* **Conflict Vector & Resolution Strategy:**
  * If destination table became occupied on the server while the client was offline, the transfer fails on sync.
  * Resolution: Server retains existing occupied session on destination table and moves the arriving order to a temporary "Unassigned Dine-In" state with a high-priority supervisor UI notification.

---

### 4.6 Merge Tables
* **Code Paths:**
  * Backend: `NOT FOUND`! Grepping `backend/src/tables` and the entire repository confirms no `mergeTable` or `merge_tables` endpoint or database column exists.
  * Frontend: `NOT FOUND`. Table view supports transfer and release, but no table bill consolidation UI exists.
* **Analysis & Recommendation:**
  * Since table merging does not exist in the code, it cannot be run offline. If introduced in the future, it must be treated as an atomic order consolidation: re-linking all active `order_items` from Table B to Table A's order ID and releasing Table B.

---

### 4.7 Payment (Cash, Split / Multi-Tender, External Card)
* **Code Paths:**
  * Backend Payment Creation: [`backend/src/orders/orders.service.ts:388-417`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L388-L417)
  * Backend Payment Update: [`backend/src/orders/orders.service.ts:772-805`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L772-L805)
  * Schema Model: [`backend/prisma/schema.prisma:417-436`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/prisma/schema.prisma#L417-L436) (`OrderPayment` model)
  * Frontend Use Case: [`frontend/lib/application/orders/complete_order_usecase.dart:150-161`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/application/orders/complete_order_usecase.dart#L150-L161)
* **Business Rules & Constraints in Code:**
  1. Multi-tender support (`schema.prisma:420`): Supports `'cash'`, `'card'`, `'bankTransfer'`, `'other'`.
  2. Audit tracking: Fields include `amount`, `tendered_amount`, `change_returned`, `transaction_reference`, `card_last_four`, `received_by`, `payment_status`.
* **Local Storage Schema:**
  * `order_payments` table with local UUID, amount, method, received_by, timestamp.
  * `orders.is_paid = 1`, `orders.payment_status = 'PAID'`.
  * Enqueue `RECORD_PAYMENT` in `sync_outbox`.
* **Sync Priority:** `HIGHEST (P0)` — Financial settlement.
* **Conflict Vector & Resolution Strategy:**
  * Low risk because payment is child of a specific order UUID. Payment ledger rows are append-only.

---

### 4.8 Refunds
* **Code Paths:**
  * Backend: `NOT FOUND`! There is no refund API controller or service method anywhere in `backend/src`.
  * Immutability Enforcement: [`backend/src/orders/orders.service.ts:480-484`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L480-L484) and [`backend/src/orders/orders.service.ts:892-897`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L892-L897) strictly prohibit modifying or deleting paid/completed orders.
* **Operational Boundary Justification:**
  * **MUST BE BLOCKED OFFLINE.**
  * In the absence of server validation, processing cash or card refunds offline creates severe fraud exposure (e.g. cashier issuing cash refunds while client is disconnected, or refunding transactions that are contested or already refunded). If a business decision demands offline refunds in the future, it must be strictly capped (e.g., maximum PKR 1,000 / $20) and require local Manager PIN override with physical receipt signed by customer.

---

### 4.9 Inventory Deduction & Stock Adjustments
* **Code Paths:**
  * Backend Stock Out / Sale Deduction: [`backend/src/inventory/inventory.service.ts:271-334`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/inventory/inventory.service.ts#L271-L334)
  * Backend Insufficient Stock Guard: [`backend/src/inventory/inventory.service.ts:283-288`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/inventory/inventory.service.ts#L283-L288)
  * Frontend Deduction Engine: [`frontend/lib/domain/services/stock_deduction_engine.dart:1-60`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/domain/services/stock_deduction_engine.dart#L1-L60)
  * Frontend Use Case Integration: [`frontend/lib/application/orders/complete_order_usecase.dart:176-186`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/application/orders/complete_order_usecase.dart#L176-L186)
* **Business Rules & Constraints in Code:**
  * Backend `stockOut` throws `BadRequestException` if `currentStockNum < dto.quantity` (`inventory.service.ts:285-288`).
* **Offline Conflict & Resolution Strategy:**
  * **Critical Architecture Requirement:** In a restaurant, food must continue to be sold even if computer inventory hits zero (kitchen might have raw dough or unlogged supplies). Offline POS must record the deduction in local SQLite and allow negative local stock.
  * When syncing offline order deductions to the server, deductions must be sent as **relative decrements** (`delta: -2.5 kg`) rather than absolute balances (`stock = 10`).
  * Backend must be adapted to accept sale deductions even if stock drops below zero, recording a `Stock Variance / Discrepancy Alert` for management rather than aborting the order synchronization.

---

### 4.10 Product Changes (Catalog Management vs. 86ing)
* **Code Paths:**
  * Item CRUD: [`backend/src/menu/items/items.service.ts:107-246`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/menu/items/items.service.ts#L107-L246)
  * Item 86ing (Availability): [`backend/src/menu/items/items.service.ts:248-268`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/menu/items/items.service.ts#L248-L268) (`updateAvailability`)
  * Frontend UI Toggle: [`frontend/lib/data/pos_repository.dart:394-404`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/pos_repository.dart#L394-L404)
* **Operational Boundary Justification:**
  * **86ing (Toggle Availability): MUST WORK OFFLINE.** Kitchen staff must be able to mark an item unavailable immediately so cashiers stop selling it. Synced using Last-Write-Wins.
  * **Catalog Configuration (Price edits, new menu items, deleting items): MUST BE BLOCKED OFFLINE.** Modifying prices or creating menu items offline leads to price inconsistency across terminals and breaking changes in historic receipts. Catalog configuration is an online-only back-office function.

---

### 4.11 Customer Creation & Update
* **Code Paths:**
  * Backend: [`backend/src/customers/customers.service.ts:54-100`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/customers/customers.service.ts#L54-L100)
  * Backend Phone Uniqueness Guard: [`backend/src/customers/customers.service.ts:59-63`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/customers/customers.service.ts#L59-L63)
* **Business Rules & Constraints in Code:**
  * `createCustomer` throws `ConflictException` if customer with `dto.phone` already exists.
* **Local Storage Schema:**
  * `customers` table in SQLite with local UUID, `full_name`, `phone`, `address`.
* **Sync Priority:** `HIGH (P1)`.
* **Conflict Vector & Resolution Strategy:**
  * If two terminals create the same customer offline with identical phone numbers, the server's unique constraint will reject the second insertion.
  * Resolution: Server sync handler must execute an **Upsert / Dedup strategy**: if phone exists, server merges the new address/name into the existing customer record and maps the offline order's `customer_id` to the existing customer ID.

---

### 4.12 Shift Open (Start Session) & Shift Close (Submit Daily Calculation)
* **Code Paths:**
  * Shift Open: [`backend/src/daily-calculation/daily-calculation.service.ts:77-161`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/daily-calculation/daily-calculation.service.ts#L77-L161) (`startSession`)
  * Shift Close: [`backend/src/daily-calculation/daily-calculation.service.ts:331-610`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/daily-calculation/daily-calculation.service.ts#L331-L610) (`submitDailyCalculation`)
  * Unresolved Orders Guard: [`backend/src/daily-calculation/daily-calculation.service.ts:338-367`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/daily-calculation/daily-calculation.service.ts#L338-L367)
  * Active Dispatches Guard: [`backend/src/daily-calculation/daily-calculation.service.ts:369-395`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/daily-calculation/daily-calculation.service.ts#L369-L395)
  * Arithmetic Balance Validations: [`backend/src/daily-calculation/daily-calculation.service.ts:412-437`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/daily-calculation/daily-calculation.service.ts#L412-L437)
* **Operational Boundary Justification:**
  * **Shift Open: MUST WORK OFFLINE.** Cashier counting float at start of day cannot be blocked by an outage. Generates local shift ID with opening cash float.
  * **Shift Close: RESTRICTED / DRAFT OFFLINE ONLY.**
    * Backend `submitDailyCalculation` executes strict validations: throws `BadRequestException` if any order in the shift is unpaid/unresolved (`line 363`) or if any delivery dispatch is in transit (`line 391`). Furthermore, it enforces exact cash balancing (`line 424`): `submittedAmount` must equal `live.total_cash_sales - totalExpenses`.
    * If Terminal A closes a shift offline while Terminal B has un-synced orders belonging to the same shift, the server's calculation will fail or close prematurely with partial data!
    * **Policy:** When offline, the POS allows the cashier to perform a "Local Drawer Close / Count" which locks the local register and records cash counted. The shift status is flagged `PENDING_SYNC_CLOSURE`. The server finalizes the shift closing calculation only after all pending orders from that shift are uploaded and reconciled.

---

## 5. Operations Blocked Offline & Justification

| Operation | Module & Code Path | Justification for Blocking Offline |
|---|---|---|
| **Role & Permission Changes** | [`backend/src/permissions/permissions.service.ts:120-220`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/permissions/permissions.service.ts#L120-L220) | Security compromise. Allowing offline permission overrides enables local privilege escalation (e.g. cashier granting themselves manager rights without server authorization). |
| **Staff User Creation & Password Alteration** | [`backend/src/users/users.service.ts:83-190`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/users/users.service.ts#L83-L190) | Centralized credential management. User account creation requires Argon2 hashing and enterprise identity synchronization. |
| **Staff Salary Settlement / Disbursal** | [`backend/src/staff/staff.service.ts:200-260`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/staff/staff.service.ts#L200-L260) | Financial ledger integrity. Salary disbursals impact corporate payroll ledgers and require live balance confirmation. |
| **Catalog Price Alterations & Menu Item Creation** | [`backend/src/menu/items/items.service.ts:107-246`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/menu/items/items.service.ts#L107-L246) | Catalog divergence. If terminals independently alter product prices offline, identical orders will have different financial charges across stations. |
| **Store Global Settings Configuration** | [`backend/src/settings/settings.service.ts:22-52`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/settings/settings.service.ts#L22-L52) | Modifying branch tax rates, chain metadata, or store identifiers must be authorized centrally. |
| **Direct Integrated Card Gateway Capture** | External Payment Gateway API | Direct payment gateway APIs require live internet to communicate with merchant acquirers. (External standalone PDQ machines are allowed). |

---

## 6. Hardware & Local Subsystems

### 6.1 Thermal Receipt & Kitchen Printing
* **Code Path:** [`backend/src/printer/printer.service.ts:20-64`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/printer/printer.service.ts#L20-L64), [`frontend/lib/services/printer_service.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/services/printer_service.dart)
* **Architecture Rule:** Printing is a **purely local hardware operation**. The POS Flutter desktop application sends ESC/POS raw bytecode directly to the Windows Spooler / USB thermal printer (`POS Receipt Printer` / `Kitchen Printer`). Printing must **NEVER** depend on an HTTP call to the cloud backend or an active internet connection.

### 6.2 Kitchen Display System (KDS) LAN Fallback
* **Code Path:** [`backend/src/kitchen/kitchen.service.ts:141-201`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/kitchen/kitchen.service.ts#L141-L201), [`backend/src/kitchen/kitchen.gateway.ts`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/kitchen/kitchen.gateway.ts)
* **Architecture Rule:** In an outage where the local router/LAN is active but the WAN/Internet is down, kitchen tickets must be dispatched across the local network to KDS screens using Local Network WebSockets (or local SQLite shared replication) rather than cloud Socket.IO.

---

## 7. Sync Priority Hierarchy

When network connectivity is restored, the Outbox Queue drains according to strict priority tiers to maintain referential integrity:

```
Tier 0 (P0 - Immediate Financial & Sync Control):
  1. OUTBOX_HANDSHAKE & Device Authentication
  2. PAYMENTS (Cash, External Card Settlement)
  3. FINAL SHIFT CLOSING (DRAWER AUDIT RECONCILIATION)

Tier 1 (P1 - Core Operational Transactions):
  4. CUSTOMER UPSERTS / DEDUPLICATIONS
  5. CREATE ORDER (Dine-In, Takeaway, Delivery)
  6. UPDATE ORDER & ITEM EDITS / CANCELLATIONS
  7. TABLE OCCUPATION / RELEASE / TRANSFER

Tier 2 (P2 - Secondary Operational Events):
  8. INVENTORY RECIPE AUTO-DEDUCTIONS (DELTAS)
  9. WASTAGE & STOCK-OUT LOGS
  10. PRODUCT 86ing (ITEM AVAILABILITY TOGGLES)
  11. TABLE RESERVATIONS
  12. DELIVERY DISPATCH ASSIGNMENTS & STATUS UPDATES

Tier 3 (P3 - Background Maintenance & Inbound Updates):
  13. DOWNSTREAM MENU CATALOG PULL
  14. STORE SETTINGS PULL
  15. REPORTING AGGREGATES SYNC
```

---

## 8. Questions for the Developer

1. **Table Merging Feature Intent:**  
   `merge tables` was requested in the analysis prompt, but no API route, Prisma schema relationship, or controller method exists in `backend/src/tables` or anywhere in the backend. Is table merging planned as a new feature for the offline-first milestone, or was it an optional conceptual scenario?
2. **Refund Implementation Status:**  
   No `refund` controller, service, or schema table exists in the codebase (`backend/src/orders` or `backend/prisma/schema.prisma`). Furthermore, `orders.service.ts:480` and `892` explicitly make paid orders immutable. Does the business plan to implement formal refund transactions, or is refund currently handled via manual cashier cash return?
3. **Multi-Terminal Master vs. Peer Architecture:**  
   In multi-terminal stores with 2-4 POS registers and a kitchen screen, will one terminal act as a Local Master server running a local SQLite/backend replica, or will each terminal operate purely as an independent peer syncing directly to the Cloud PostgreSQL backend?
4. **Order Number Collisions:**  
   `backend/src/orders/orders.service.ts:230-260` enforces a unique constraint on 3-digit order numbers (`101` to `999`). If multiple offline terminals generate sequential order numbers offline, they will collide upon reconnection. Is prepending a device identifier (e.g. `T1-101`, `T2-101`) acceptable for kitchen tickets and customer receipts?
5. **Inventory Negative Stock Policy:**  
   `backend/src/inventory/inventory.service.ts:285-288` throws `BadRequestException` if requested stock exceeds `current_stock`. Can the backend be updated during sync to accept negative stock adjustments from verified completed sales, logging a managerial variance alert instead of rejecting the order?
