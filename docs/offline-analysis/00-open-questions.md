# Open Questions for the Developer (Wave 1 Synthesis)

This document aggregates and deduplicates all questions identified across the 10 Wave 1 analysis reports ([`01`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-analysis/01-flutter-architecture.md) through [`10`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-analysis/10-performance.md)). These questions represent domain, operational, hardware, and business policy decisions that cannot be resolved from codebase inspection alone.

---

## 1. Store Network Topology & Multi-Terminal Architecture
*Source reports: `01-flutter-architecture`, `02-screens-flows`, `05-realtime-multiuser`, `06-offline-operations`, `08-security`*

- **Q1.1: Multi-Terminal Offline Topology**  
  In a store with multiple devices (e.g., 2 Cashier POS terminals, 1 KDS kitchen monitor, 1 Manager laptop), when the broadband internet connection goes down:
  - **Option A (Isolated Silos):** Each terminal operates in complete isolation, saving data to its own local Drift/SQLite database and syncing directly to Cloud PostgreSQL once WAN internet returns. (No LAN communication between terminals during outages; KDS relies on physical printed paper tickets).
  - **Option B (Local LAN Hub / Master Node):** Terminals discover each other on the local Wi-Fi/LAN (e.g., via mDNS or static IP). One designated primary Windows POS acts as a local sync/WebSocket broker so cashier orders appear on the kitchen KDS in real-time even during total WAN internet outages.
- **Q1.2: Kitchen Display System (KDS) Target Hardware**  
  Is the KDS terminal deployed on Windows hardware (running the same Flutter desktop app as POS), or on an Android tablet / iPad?  
  *(Context: Determines whether KDS can run a full local Drift/SQLite database and background sync workers or must remain a lightweight socket listener).*

---

## 2. Order & Receipt Numbering Sequence
*Source reports: `01-flutter-architecture`, `02-screens-flows`, `03-database-schema`, `04-backend-api`, `06-offline-operations`, `07-concurrency-conflicts`*

- **Q2.1: Multi-Terminal Order Number Formatting**  
  The backend currently enforces a unique constraint on sequential 3-digit order numbers (`101`–`999`) reset daily ([`orders.service.ts:230-260`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/orders/orders.service.ts#L230-L260)). When multiple terminals operate offline simultaneously, sequential numbers will collide upon cloud reconnection.
  - Is a terminal-prefixed order number acceptable on printed customer receipts and kitchen KOT tickets (e.g. `T1-101`, `T2-101`, or `POS1-0101`)?
  - Or does tax/store policy mandate a strictly unified 3-digit sequence across the entire store?

---

## 3. Table Concurrency & Dine-In Conflict Policy
*Source reports: `02-screens-flows`, `03-database-schema`, `04-backend-api`, `05-realtime-multiuser`, `07-concurrency-conflicts`*

- **Q3.1: Table Seating / Reservation Conflicts**  
  If two terminals perform conflicting table operations while disconnected (e.g., Terminal A seats guests at Table 4 while offline, and Terminal B seats a different party at Table 4 while offline; OR Terminal A reserves Table 1 while Terminal B seats a walk-in at Table 1):
  - **Option A (Merge Tab):** Merge all order items under Table 4 into a single combined order.
  - **Option B (Virtual Overflow Table):** The first reconnected order retains Table 4; the second order is automatically assigned an overflow identifier (e.g. `Table 4-B`) with an urgent manager notification to re-seat.
  - **Option C (Hospitality Priority):** Physical seated guest always supersedes a reservation; the reservation is flagged for manual reassignment.

---

## 4. Inventory Depletion & Negative Stock Policy
*Source reports: `03-database-schema`, `06-offline-operations`, `07-concurrency-conflicts`, `10-performance`*

- **Q4.1: Recipe/BOM Auto-Depletion**  
  Currently, placing an order does not automatically deduct raw material ingredients. Should raw ingredients (`InventoryItem`) be deducted automatically via recipes/BOM upon order placement/sync, or will inventory remain an independent, manually counted stock-in/stock-out ledger?
- **Q4.2: Negative Stock Acceptance on Reconnection**  
  The backend currently throws HTTP 400 if an inventory deduction exceeds available stock (`inventory.service.ts:285`). In an offline scenario where multiple terminals sell items before syncing:
  - Can the sync engine allow inventory counts to go negative (deficit tracking) so that verified customer sales are **never rejected**, accompanied by a manager stock discrepancy alert?

---

## 5. Shift Management, Cash Drawer & End-of-Day Float
*Source reports: `01-flutter-architecture`, `02-screens-flows`, `04-backend-api`, `05-realtime-multiuser`, `07-concurrency-conflicts`*

- **Q5.1: Cash Drawer Sharing vs. Per-Terminal Floats**  
  Do multiple cashiers share a single physical cash drawer (`daily_calculations`), or does each POS register maintain an independent opening float, cash skimming, and closing balance?
- **Q5.2: Offline Shift Closure**  
  If a shift ends during an extended internet outage, should the cashier be permitted to finalize an "End of Shift" cash count and close the register offline, generating a local closing receipt, with the closed shift syncing upstream once online?
- **Q5.3: Cash Variance Handling**  
  When an offline shift is submitted with a cash discrepancy (overage/shortage), should the server permit supervisory variance approval rather than rejecting the submission via hard balance checks?

---

## 6. Refunds & Cancellation Workflows
*Source reports: `04-backend-api`, `06-offline-operations`, `07-concurrency-conflicts`*

- **Q6.1: Refund Accounting Model**  
  No refund model or endpoint currently exists in the codebase (`backend/src/orders` or `backend/prisma/schema.prisma`), and paid orders are strictly immutable (`orders.service.ts:480, 892`).
  - Does the business plan to introduce a formal ledgered refund transaction (credit note / refund record) in the POS, or are refunds handled strictly via manual cash payout outside the system?
  - Should refunds be strictly **blocked** while offline?

---

## 7. Security, Auth & Risk Safeguards
*Source reports: `04-backend-api`, `08-security`*

- **Q7.1: Production Auth Bypass Deprecation**  
  `JwtAuthGuard` ([`backend/src/common/guards/jwt-auth.guard.ts:11-17`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/backend/src/common/guards/jwt-auth.guard.ts#L11-L17)) currently authenticates any unauthenticated request as user `'Noman'` (owner). Can this fallback be removed in production so that cloud endpoints enforce valid JWT signatures?
- **Q7.2: Offline Manager Overrides**  
  When a restricted operation (e.g., voiding an active kitchen order, applying a >15% discount) occurs offline, should authorization require a local manager PIN hash check, or a mobile-generated TOTP?
- **Q7.3: Offline Financial Risk Limits**  
  What is the acceptable maximum offline duration (e.g., 8 hours, 24 hours) and cumulative offline transaction value (e.g., PKR 100,000 / $5,000) before the terminal requires reconnection to continue ringing sales?
- **Q7.4: Hardware TPM Availability**  
  Are the Windows POS machines equipped with TPM 2.0 chips for hardware-bound DPAPI key encryption of the local SQLite database, or should DPAPI user-scope encryption be used without TPM dependency?

---

## 8. Thermal Printing & Hardware Redundancy
*Source reports: `01-flutter-architecture`, `02-screens-flows`, `08-security`, `09-printing`*

- **Q8.1: Printer Interface Topology**  
  In production, are thermal printers connected via **USB** to a specific Windows PC, or are they **Network (Ethernet/Wi-Fi)** printers with static IP addresses on port 9100?
- **Q8.2: Print Queue & Hardware Errors**  
  If a thermal printer runs out of paper or disconnects during offline checkout, should print jobs be stored in a durable SQLite `print_jobs` table for automatic/manual retry once paper is replaced?
- **Q8.3: Online / Delivery Order Auto-Print**  
  When an online or delivery order arrives, should kitchen KOT tickets print automatically, or is manual cashier review and acceptance strictly required before printing?
- **Q8.4: Dual Ticket Configuration**  
  Does store policy require dual KOT printing ("Kitchen Receipt" + "Food Picker - Dine In") in all locations, or should it be configurable per branch?

---

## 9. Catalog Management & Local Data Retention
*Source reports: `01-flutter-architecture`, `03-database-schema`, `10-performance`*

- **Q9.1: Menu Edits Offline Policy**  
  Should menu and catalog updates (adding items, changing prices, modifying categories) be strictly disabled while offline, limiting offline capabilities exclusively to operational order billing and table service?
- **Q9.2: Local Database Retention & Pruning**  
  Can closed orders older than 30 days be pruned from local POS terminals to keep SQLite database sizes small (~25–38 MB), reserving historical reporting (>30 days) for the cloud portal?
- **Q9.3: Customer Phonebook Bootstrap Scope**  
  When seeding the local customer database for offline caller-ID/CRM lookup, should the terminal download the full customer directory or only active/frequent customers (e.g. top 1,000)?


---

# Developer Answers & Architectural Directives (Wave 1 Sign-Off)

*Recorded: 2026-10-17*

| Question ID | Developer Directive / Answer | Architectural Impact |
|---|---|---|
| **Q1.1** | **Option A — Isolated local databases with cloud synchronization.** No KDS or kitchen terminal. Kitchen uses a physical printer connected directly to the cashier PC. | Simplifies Wave 2 design: no LAN peer-to-peer sync or local master required. Each POS terminal is an autonomous island syncing directly with Cloud PostgreSQL. |
| **Q1.2** | **N/A — No KDS.** Kitchen only receives printed order slips directly from the cashier PC. | No KDS sync or real-time tablet protocol needed. All kitchen communication is mediated via local thermal printer spooling. |
| **Q2.1** | **Terminal-prefixed order numbers are acceptable** (e.g., `P1-101`, `P2-101`). Internal database uses unique UUID for every order; prefixed numbers are used on customer receipts and kitchen tickets. | Zero order number collision during offline mode across terminals. Schema maintains unique UUIDs internally and partitions receipt numbers with `terminal_id`. |
| **Q3.1** | **Not applicable.** Current system is designed for a single physical POS/cashier terminal. Table seating conflicts between multiple terminals do not apply. Local DB maintains table state; sync keeps cashier POS and owner account up to date. | Table state is strictly local-authoritative on the POS while offline; owner portal reflects state once synced. No multi-terminal conflict arbitration needed. |
| **Q4.1** | **Inventory remains independent from orders.** Placing/completing an order only stores order history. NO automatic ingredient or stock deduction based on recipe/BOM. Inventory managed separately via manual stock entries, adjustments, purchases, waste, counts. | Eliminates high-volume stock mutation deltas during offline order creation. Zero inventory collision during offline sales. |
| **Q5.1** | **Single cashier and single physical cash drawer.** Register maintains a single opening float, cash transactions, skimming, and closing balance. Multi-register drawer sharing is not required. | Shift ledger is purely local to the terminal during the shift. |
| **Q5.2** | **Yes — Cashier can close shift offline.** End-of-Day cash count and shift close are stored locally in SQLite and synchronized upstream when connection is restored. | Shift state machine must support `OFFLINE_CLOSED` status in local SQLite. |
| **Q5.3** | **Yes — Cashier can close shift with variance.** System records variance (overage/shortage) locally as part of the closing record. Synchronizes to server for review upon reconnection. No offline supervisor approval workflow required. | Remove strict server-side zero-variance blocking on shift sync; accept local variance record. |
| **Q6.1** | **Formal refund workflow not required.** Cash recorded only when order is approved/completed after dining. Unapproved cancellations create no cash record. Paid orders remain immutable. Refunds not required offline. | No refund queue, reversal transactions, or offline cash payout ledger needed. |
| **Q7.1** | **Yes — Remove legacy hardcoded fallback user ('Noman') from production.** Cloud deployments must strictly enforce valid JWT authentication and role validation. | Clean security boundary; eliminate auth bypass in target architecture. |
| **Q7.2** | **Sensitive operations (large discounts, voids, privileged actions) are NOT permitted offline.** Require active server connection. No offline manager PIN or TOTP needed. | Flutter UI will disable/grey out privileged overrides when `OFFLINE_FIRST_ENABLED` detects no WAN connection. |
| **Q7.3** | **Support indefinite offline operation.** No maximum duration, no cumulative transaction-value cap. Continue normal sales and store data locally until sync. | Outbox and local DB must be designed for unbound offline duration with robust SQLite durability (WAL mode). |
| **Q7.4** | **Standard Windows user-scope DPAPI encryption.** TPM 2.0 hardware binding not required. | Encryption key for SQLCipher/Drift derived via `CryptProtectData` (DPAPI) without requiring TPM chip. |
| **Q9.1** | **Menu/catalog changes strictly disabled while offline.** Offline mode is limited to normal POS sales and approved operational functions. Pricing/products require server connection. | Menu table is strictly read-only/pull-only on POS local DB. No outbox mutations for catalog. |
| **Q9.2** | **Closed orders older than 30 days automatically pruned from local SQLite.** Historical reporting (>30 days) remains on cloud/server. Only local copies removed. | Implement local rolling 30-day retention pruning job in Drift. |
| **Q9.3** | **Complete customer database NOT stored locally.** CRM data remains on server. Offline CRM functionality not required. | No bulk customer sync needed on bootstrap. POS can record phone/name locally on order if entered. |
| **Q8.2** | **ORDER SAVING ≠ PRINTING.** Order is committed to local Drift SQLite and sync outbox first. Thermal printer failure (jam, out of paper, disconnect) never blocks or rolls back orders. Simple warning displayed to cashier; print job retained in `OfflinePrintJobs` for manual tap-to-retry. | Eliminates printer blocking hazards and complex spooler daemons. |
| **Q5.3B** | **No automatic cash variance alert thresholds.** Shift records expected cash, actual counted cash, and variance. Stored locally offline and synced to server for owner review. No automated SMS/email alerts or threshold rules. | Keeps shift closing simple and reliable without complex notification infrastructure. |
| **Q-Audit** | **No emergency local audit export.** No USB CSV/PDF export workflow is required. System relies on local SQLite storage, automatic PostgreSQL sync upon reconnection, and existing server-side reporting. | Avoids unnecessary export features and security attack surfaces. |
