# D-03 Fix Report: Server Pricing Authority & Manager Discount Control

**Item ID:** D-03 (Wave 2)  
**Branch:** `fix/D-03`  
**Mapped Findings:** `SYNC-016` (Server pricing authority & client price tampering rejection), `BCK-02` (Discount approval workflow / supervisor credentials), `MNY-08` (Audit trail for discounts and price overrides)  
**Date:** October 28, 2026  
**Status:** Completed & Verified  

---

## 1. Executive Summary

Decision D-03 resolves critical sync vulnerabilities where clients could submit arbitrary prices or unapproved discounts without server recomputation or supervisor audit. Under the offline-first POS architecture, local POS terminals may operate disconnected, but the server remains the ultimate authority for pricing, tax, and discount verification.

This remediation establishes:
1. **Server Pricing Authority (`SYNC-016`)**: The server strictly recalculates catalog item base prices, size variants, crust modifications, and extra toppings for every incoming order. Discrepancies exceeding a configurable rounding tolerance (1.00 PKR) are flagged as `PRICE_MISMATCH`, adjusted to authoritative server totals, and logged in `pricing_audits`.
2. **Offline-First Manager Discount Control (`BCK-02`)**:
   - Cashiers cannot apply order discounts without explicit manager credential verification.
   - When offline, manager approval is verified locally using `OfflineAuthService.verifyManagerCredential` (leveraging Argon2id / DPAPI encrypted offline credentials established in D-06).
   - Approval metadata (`{managerId, deviceId, approvedAt, reason}`) is attached to order outbox mutation payloads and API requests.
   - Online REST orders with unapproved discounts are rejected with HTTP 403 Forbidden.
   - Offline sync orders (Rule 5 compliance: the customer has already received food) are preserved, but the discount is revoked to 0.00, server grand total is set to full price, `pricing_status` is marked `UNAUTHORIZED_DISCOUNT`, and an audit record is created in `pricing_audits`.
3. **Audit Trail (`MNY-08`)**: All approved discounts create immutable rows in `discount_audits`, capturing the approving manager, reason, device ID, original subtotal, and discount amount.
4. **Cashier UI Reconciliation & Notifications**:
   - The Flutter frontend prompts the `ManagerApprovalDialog` in Takeaway and Table/Dine-In pre-bills whenever discounts are applied.
   - During sync push acknowledgement, the local client processes server pricing adjustments and notifies cashiers via non-blocking warning banners driven by `PricingReconciliationEventBus` and `PricingReconciliationNotifier`.

---

## 2. Detailed Technical Changes

### 2.1 Backend (NestJS + Prisma + PostgreSQL)

1. **Database Schema Enhancements (`prisma/schema.prisma`)**:
   - **`Order` Model**: Added `pricing_status` (`VERIFIED`, `PRICE_MISMATCH`, `UNAUTHORIZED_DISCOUNT`), `server_grand_total` (`Decimal(10,2)`), `approved_by_manager_id` (`String?`), and `discount_reason` (`String?`).
   - **`PricingAudit` Model (`pricing_audits`)**: Records every pricing recomputation mismatch, capturing `order_id`, `client_total`, `server_total`, `discrepancy`, `item_mismatches` (JSON), and `resolved_at`.
   - **`DiscountAudit` Model (`discount_audits`)**: Records immutable audit trails for discounts, capturing `order_id`, `manager_id`, `device_id`, `discount_type`, `discount_value`, `subtotal_before_discount`, `discount_amount`, `reason`, and `approved_at`.
2. **Additive Zero-Downtime Migration**:
   - Created `prisma/migrations/20261027170000_server_pricing_authority/migration.sql`.
   - Schema alterations use safe defaults (`DEFAULT 'VERIFIED'`) and backfills existing orders (`server_grand_total = grand_total`) to prevent data inconsistency or downtime.
3. **`PricingService` (`src/pricing/pricing.service.ts`)**:
   - Independent NestJS service computing item-level catalog prices:
     - Base item prices queried from `MenuItem`.
     - Size variant price additions queried from `SizeVariant`.
     - Crust price additions queried from `Crust`.
     - Extra topping additions queried from `Topping`.
   - Uses fixed-point `Prisma.Decimal` arithmetic across all intermediate and final calculations to prevent floating-point rounding errors.
   - Evaluates client vs. server totals against `PRICING_ROUNDING_TOLERANCE` (default: 1.00 PKR).
   - Validates manager permissions (`manager`, `admin`, `owner`, `superadmin`) against the `StaffUser` database table.
   - Emits structured audit logs to `pricing_audits` and `discount_audits`.
4. **Order Service & Sync Handlers (`src/orders/`, `src/sync/`)**:
   - Updated `CreateOrderDto` and `UpdateOrderDto` with `managerApproval` DTO (`managerId`, `deviceId`, `approvedAt`, `reason`) and `approvedByManagerId`.
   - Updated `OrdersService.create()`:
     - Recomputes pricing and sets `server_grand_total`.
     - Throws `ForbiddenException` if a discount is applied without verified manager credentials.
   - Updated `OrderSyncHandler` (`src/sync/handlers/order.handler.ts`):
     - Executes `PricingService.recalculateOrder()` for sync creations and updates.
     - Implements Rule 5 offline discount handling: retains order, nullifies discount, records `UNAUTHORIZED_DISCOUNT`, sets authoritative total.
     - Returns server-authoritative `pricing_status`, `grand_total`, `server_grand_total`, and `warning_code` in push ACK responses for downstream client reconciliation.

### 2.2 Frontend (Flutter + Riverpod + Drift)

1. **Manager Approval Dialog (`lib/shared/widgets/manager_approval_dialog.dart`)**:
   - Modal dialog prompting manager username/ID, PIN/password, and discount reason.
   - Integrates with D-06's `OfflineAuthService.verifyManagerCredential` for zero-latency, cryptographically secure offline credential checking against Windows DPAPI-protected Argon2id verifiers.
   - Returns structured `ManagerApprovalResult` containing `{managerId, managerName, reason, timestamp}`.
2. **Takeaway Flow (`lib/features/takeaway/takeaway_screen.dart`)**:
   - Intercepts discount preset buttons (5%, 10%, 15%, 20%, 50%, 100%) and custom discount modal.
   - Prompts `ManagerApprovalDialog` prior to applying discount.
   - Intercepts pre-bill generation: if an unapproved discount exists on the draft order, prompts for manager approval before finalizing or saving.
   - Displays non-blocking amber warning banners when server pricing reconciliation notifications are received.
3. **Table/Dine-In Flow (`lib/features/tables/tables_screen.dart`)**:
   - Intercepts discount selections in `_CustomerPreBillDialog`.
   - Requires manager approval before pre-bill discount application and before saving/printing pre-bills.
   - Forwards manager approval metadata through order persistence and API synchronization.
   - Integrates table-level pricing reconciliation banners with dismiss actions.
4. **Takeaway Repository & Order Persistence (`lib/data/takeaway_repository.dart`)**:
   - Updated `addOrder`, `updateTakeawayOrder`, and `updateOrderDiscount` to accept `managerApproval` and `approvedByManagerId`.
   - Persists manager approval metadata into local Drift SQLite `OrderModel`.
   - Serializes manager approval metadata into outbox mutation payloads.
5. **Reconciliation Provider & Event Bus (`lib/core/sync/pricing_reconciliation_provider.dart`)**:
   - Exposes `PricingReconciliationEventBus` for decoupled event passing.
   - Exposes `pricingReconciliationProvider` (Riverpod `StateNotifier`) tracking active reconciliation notifications.
   - Provides `addNotification()` and `dismissNotification()` methods.
6. **Sync Worker Integration (`lib/core/sync/sync_background_worker.dart`)**:
   - Updated push ACK processor:
     - Inspects server responses for `pricing_status == 'PRICE_MISMATCH'` or `pricing_status == 'UNAUTHORIZED_DISCOUNT'`.
     - Updates local Drift order record with authoritative `server_grand_total` and status.
     - Emits `PricingReconciliationNotification` via `PricingReconciliationEventBus` to immediately alert the cashier.

---

## 3. Files Touched

### Backend
- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/20261027170000_server_pricing_authority/migration.sql` *(new)*
- `backend/src/app.module.ts`
- `backend/src/pricing/pricing.service.ts` *(new)*
- `backend/src/pricing/pricing.module.ts` *(new)*
- `backend/src/pricing/pricing.service.spec.ts` *(new)*
- `backend/src/orders/dto/create-order.dto.ts`
- `backend/src/orders/dto/update-order.dto.ts`
- `backend/src/orders/orders.module.ts`
- `backend/src/orders/orders.service.ts`
- `backend/src/sync/handlers/order.handler.ts`
- `backend/src/sync/handlers/order.handler.spec.ts`
- `backend/src/sync/handlers/sync-entity.handler.ts`
- `backend/src/sync/sync-016-server-pricing-authority-e2e.spec.ts` *(new)*

### Frontend
- `frontend/lib/domain/models/order_model.dart`
- `frontend/lib/shared/widgets/manager_approval_dialog.dart` *(new)*
- `frontend/lib/core/sync/pricing_reconciliation_provider.dart` *(new)*
- `frontend/lib/core/sync/sync_background_worker.dart`
- `frontend/lib/data/takeaway_repository.dart`
- `frontend/lib/features/takeaway/takeaway_screen.dart`
- `frontend/lib/features/tables/tables_screen.dart`
- `frontend/test/core/pricing/server_pricing_authority_ui_test.dart` *(new)*

### Documentation & Audit Tracking
- `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` (appended §11.6, updated §11.1 table)
- `docs/sync-audit/fixes/leftovers-backlog.md` (marked D-03 Implemented)
- `docs/fixes/D-03-report.md` *(this document)*

---

## 4. Database Schema & Migration Verification

- **Schema Check**: `npx prisma validate` executed cleanly:
  ```text
  The schema at prisma\schema.prisma is valid
  ```
- **Additive Invariants**:
  - `pricing_status String @default("VERIFIED")` added to `orders`.
  - `server_grand_total Decimal @default(0.00)` added to `orders`.
  - `approved_by_manager_id String?` added to `orders`.
  - `discount_reason String?` added to `orders`.
  - `pricing_audits` and `discount_audits` tables created with non-destructive indexing.
  - Zero dropped tables, zero dropped columns, zero modified existing constraints.

---

## 5. Test Results

### 5.1 Backend Tests
- **Targeted Suite (SYNC-016 E2E)**:
  - Command: `npm test -- sync-016`
  - Result: **4 passed, 4 total (100% pass)**
    - Verifies catalog price recalculation on valid orders.
    - Verifies tampering detection: unauthorized price drop flagged as `PRICE_MISMATCH` and corrected.
    - Verifies offline unapproved discount: sale preserved, discount zeroed, flagged `UNAUTHORIZED_DISCOUNT`.
    - Verifies approved manager discount: valid role creates `discount_audits` record.
- **Full Backend Suite**:
  - Command: `npm test`
  - Result: **69 passed, 69 total suites; 480 passed, 480 total tests (100% pass, zero regressions)**

### 5.2 Frontend Tests
- **Flutter Analyzer**:
  - Command: `flutter analyze`
  - Result: **Zero errors** across all modified files (`takeaway_screen.dart`, `tables_screen.dart`, `takeaway_repository.dart`, `manager_approval_dialog.dart`, `pricing_reconciliation_provider.dart`, `sync_background_worker.dart`).
- **UI & Unit Test Suite**:
  - Command: `flutter test test/core/pricing/server_pricing_authority_ui_test.dart`
  - Result: **5 passed, 0 failures**
    - `OrderModel serialization preserves pricing reconciliation fields`
    - `TakeawayRepository attaches managerApproval and approvedByManagerId`
    - `PricingReconciliationNotifier manages notification lifecycle without duplicates`
    - `ManagerApprovalDialog validates manager credential and returns approval result`
    - `ManagerApprovalDialog rejects cashier or invalid credential`
- **Full Frontend Suite**:
  - Command: `flutter test`
  - Result: **All 259 tests passed (0 failures, zero regressions)**

---

## 6. Residual Risks & Edge Cases

1. **Sub-Rupee Rounding Variations**:
   - Fractional cent differences (e.g. 16% GST calculated on fractional item subtotal vs sum of rounded item GSTs) are absorbed by the configurable `PRICING_ROUNDING_TOLERANCE` (default 1.00 PKR).
2. **Offline Manager Provisioning**:
   - For a manager to approve discounts while a terminal is offline, the manager must have logged in online at least once on that terminal to populate the DPAPI Argon2id credential cache (per D-06). If a manager has never logged into that specific terminal, offline validation will reject the approval. This is an intentional security design to prevent brute-force forging.

---

## 7. Manual Verification Steps

1. **Takeaway Discount Manager Flow (Offline or Online)**:
   - Open Takeaway screen on POS terminal.
   - Add items to cart (e.g. 1 Pizza @ 1,500 PKR).
   - Click "Apply Discount" or select a preset (e.g. 10%).
   - Observe `ManagerApprovalDialog` pop up.
   - Enter cashier credentials: verify approval is rejected with "Unauthorized. Manager or Admin credentials required."
   - Enter manager credentials and reason ("Loyalty Customer"): verify discount is applied and badge displays approval.
2. **Price Tampering / Recomputation on Sync Push**:
   - Create an order locally and manually simulate client discrepancy in SQLite.
   - Trigger sync push to backend.
   - Inspect backend response: verify `warning_code: 'PRICE_MISMATCH'` and `server_grand_total` recalculated from catalog.
   - Observe POS frontend: prominent amber banner appears at top of screen:
     *"Pricing Reconciled (Order #...): Local: 1,200.00 PKR vs Server: 1,500.00 PKR (PRICE_MISMATCH)"* with a dismiss button.
3. **Database Audit Records**:
   - Query PostgreSQL: `SELECT * FROM discount_audits;` -> verify manager ID, reason, and original subtotal are recorded.
   - Query PostgreSQL: `SELECT * FROM pricing_audits;` -> verify item mismatches and discrepancy are recorded.
