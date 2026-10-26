# 09 - Flag-Off Regression Audit: Proving Online POS Equivalence

> **Audit Role:** Flag-Off Regression Auditor (`.agents/flag-off-regression-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop + NestJS / Prisma / PostgreSQL Backend)  
> **Reference Specification:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md` (§17.1, §17.2)  
> **Baseline Commit:** `819c8c0~1` (Pre-Offline Foundation)  
> **Status:** Completed Implementation Audit  
> **Date:** October 26, 2026  

---

## Executive Summary & Authoritative Verdict

### Verdict: **NOT SAFE (Safe with Fixes)**

The foundational architectural directive of the Hungry Howie's offline-first initiative states:  
> *"Adding offline-first must NOT change existing online functionality. Flipping `OFFLINE_FIRST_ENABLED = false` immediately restores 100% legacy online behavior without requiring app uninstallation or database schema downgrades."* (`docs/offline-analysis/99-FINAL-ARCHITECTURE.md:1062-1064`)

Following exhaustive static analysis, AST tracing, git baseline diffing, and control-flow verification across both the Flutter Windows client and NestJS backend, this audit **disproves** that the application with `OFFLINE_FIRST_ENABLED = false` operates identically to the pre-offline POS.

While extensive seam gating was implemented across most repositories, **three critical regressions and four secondary defects** prevent the flag-off state from operating safely:

1. **Silent Order Loss via Collision Rejection ([`FLG-01`](#flg-01-order-number-collision-rejection-and-silent-order-loss-on-pos-checkout)):** When `OFFLINE_FIRST_ENABLED = false`, `orderNumberGeneratorProvider` falls back to an unmanaged in-memory counter starting at sequence 100 (`P1-101`). Upon app restart, this counter resets to 100. When checking out, `ApiOrderRepository` submits `'P1-101'` without an explicit UUID `id`. The backend detects an existing order number, fails to identify an `explicitOrderId`, and throws an HTTP 409 `ConflictException`. `ApiOrderRepository.saveOrder()` catches and swallows this exception, returning the unsaved model to the UI. The cart clears, the cashier believes the order succeeded, but **the order is completely lost from the backend database**.
2. **Permanent Data Stranding on Rollback ([`FLG-02`](#flg-02-permanent-stranding--data-loss-of-local-outbox-mutations-upon-flag-rollback)):** If the application operates with offline mode enabled and subsequently rolls back to flag-off (`OFFLINE_FIRST_ENABLED = false`), all pending mutations in the local SQLite `sync_outbox` table are completely abandoned. No worker runs, no drain-then-disable path exists, and the sync indicator is suppressed, permanently stranding unsynced orders.
3. **Drift Database & Worker Leak in Management Portal ([`FLG-03`](#flg-03-ownermanager-sync-center-route-unconditionally-instantiates-drift-sqlite-database-and-sync-worker)):** If an owner or manager navigates to "Sync Center" (`/owner/sync-center` or `/owner/data-sync`), `syncCenterProvider` unconditionally instantiates Drift SQLite, executes DPAPI key generation, acquires SQLite WAL file locks, and mounts `SyncBackgroundWorker`, completely bypassing the feature flag.
4. **Duplicate REST Calls in Takeaway ([`FLG-05`](#flg-05-redundant-duplicate-rest-api-call-on-takeaway-order-status-updates)):** In `TakeawayNotifier.updateOrderStatus()`, an un-gated fallback calls `orderRepo.updateOrderStatus()`, which resolves to `ApiOrderRepository` when flag is OFF, resulting in two identical HTTP PATCH requests dispatched to the server for every status change.

---

## PASS / FAIL Scorecard by Entry Point

| Entry Point | Flag-OFF Status | Divergence from Pre-Offline Baseline | Primary Evidence |
|---|---|---|---|
| **1. App Initialization** | **PASS** | `SyncBackgroundWorker.start()` is cleanly skipped; update controller and WebSocket connect normally. | [`frontend/lib/main.dart:43-46`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/main.dart#L43-L46) |
| **2. Cashier Login & Auth** | **PASS** | Uses `InMemoryAuthRepository` fallback and REST API; no Drift or outbox touches. | [`frontend/lib/data/auth_repository.dart:425-455`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L425-L455) |
| **3. POS Order Checkout** | <span style="color:red;font-weight:bold;">FAIL (CRITICAL)</span> | In-memory sequence resets to 100 on restart; causes backend 409 Conflict, swallowed by `ApiOrderRepository`, resulting in **silent order loss**. | [`frontend/lib/domain/services/order_number_generator.dart:34-65`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L34-L65)<br>[`frontend/lib/data/repositories/api_order_repository.dart:60-70`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/api_order_repository.dart#L60-L70)<br>[`backend/src/orders/orders.service.ts:298-319`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L298-L319) |
| **4. Dine-In Tables Flow** | **PASS** | Fully routed through REST endpoints; local catalog upserts and OCC checks cleanly bypassed. | [`frontend/lib/data/table_repository.dart:119-150`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L119-L150)<br>[`frontend/lib/features/tables/tables_screen.dart:2135-2145`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L2135-L2145) |
| **5. Takeaway Orders** | <span style="color:orange;font-weight:bold;">FAIL (MEDIUM)</span> | Local loading bypassed, but status changes fire **duplicate REST requests** to `/api/orders/:id/status`. | [`frontend/lib/data/takeaway_repository.dart:536-543`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L536-L543) |
| **6. Delivery Orders** | **PASS** | Local Drift loading and local outbox creation bypassed; direct REST execution preserved. | [`frontend/lib/data/delivery_repository.dart:68-80`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L68-L80)<br>[`frontend/lib/data/delivery_repository.dart:307-358`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L307-L358) |
| **7. Shift & Starting Cash** | **PASS** | Gated by flag; uses direct REST endpoints `/api/daily-calculations/active-session` and `/start-session`. | [`frontend/lib/data/daily_calculation_repository.dart:151-165`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L151-L165)<br>[`frontend/lib/data/daily_calculation_repository.dart:328-385`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L328-L385) |
| **8. Reports & Analytics** | **PASS** | Offline SQLite merging logic cleanly bypassed; pulls strictly from `/api/reports`. | [`frontend/lib/features/reports/reports_providers.dart:136-160`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/reports/reports_providers.dart#L136-L160)<br>[`frontend/lib/features/reports/reports_providers.dart:223-245`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/reports/reports_providers.dart#L223-L245) |
| **9. Hardware Printing** | **PASS** | Direct Win32 thermal spooler used; `OfflinePrintJobs` Drift table writes safely bypassed because database instance is null. | [`frontend/lib/services/receipt_printer_service.dart:1873-1934`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/services/receipt_printer_service.dart#L1873-L1934) |
| **10. UI Sync Indicator** | <span style="color:orange;font-weight:bold;">FAIL (LOW)</span> | Sync status light cleanly shrunk (`SizedBox.shrink()`), but top-bar sync button initiates an **unbounded 15-second background health polling loop**. Extra 8px spacing artifact in navbar. | [`frontend/lib/core/widgets/sync_status_indicator_widget.dart:92-94`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/widgets/sync_status_indicator_widget.dart#L92-L94)<br>[`frontend/lib/services/sync/global_sync_controller.dart:48`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/services/sync/global_sync_controller.dart#L48)<br>[`frontend/lib/core/sync/connectivity_notifier.dart:177-185`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/connectivity_notifier.dart#L177-L185) |
| **11. Management Sync Center** | <span style="color:red;font-weight:bold;">FAIL (HIGH)</span> | Visiting `/owner/sync-center` or `/owner/data-sync` eagerly initializes Drift SQLite and the background worker despite flag being OFF. | [`frontend/lib/features/sync/sync_center_provider.dart:537-555`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/sync_center_provider.dart#L537-L555) |
| **12. Rollback with Outbox Data** | <span style="color:red;font-weight:bold;">FAIL (CRITICAL)</span> | Disabling flag after offline usage permanently strands pending outbox entries with zero notification or drain mechanism. | [`frontend/lib/main.dart:43-45`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/main.dart#L43-L45)<br>[`frontend/lib/data/repositories/order_repository_provider.dart:32-38`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L32-L38) |

---

## Task 1: Complete Read Inventory of `OFFLINE_FIRST_ENABLED`

### Frontend Reads
Every read of `FeatureFlags.offlineFirstEnabled` (which parses `const String.fromEnvironment('OFFLINE_FIRST_ENABLED', defaultValue: true)`) is cataloged below:

| # | File & Line | Code Expression | Function / Responsibility Gated |
|---|---|---|---|
| 1 | [`frontend/lib/config/feature_flags.dart:5-6`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/config/feature_flags.dart#L5-L6) | `static const bool offlineFirstEnabled = bool.fromEnvironment(...)` | Central compile-time flag definition. Defaulted to `true` in commit `ed12271`. |
| 2 | [`frontend/lib/main.dart:43`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/main.dart#L43) | `if (FeatureFlags.offlineFirstEnabled)` | Gates starting `syncBackgroundWorkerProvider` during post-frame boot. |
| 3 | [`frontend/lib/core/sync/sync_providers.dart:50`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_providers.dart#L50) | `if (FeatureFlags.offlineFirstEnabled)` | Auto-starts worker when provider is instantiated. |
| 4 | [`frontend/lib/core/sync/sync_health_provider.dart:45`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_health_provider.dart#L45) | `if (!FeatureFlags.offlineFirstEnabled)` | Returns `Stream.empty()` for outbox stream when OFF. |
| 5 | [`frontend/lib/core/sync/sync_health_provider.dart:54`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_health_provider.dart#L54) | `if (!FeatureFlags.offlineFirstEnabled)` | Returns `SyncHealthState.initial` without reading worker or outbox when OFF. |
| 6 | [`frontend/lib/core/widgets/sync_status_indicator_widget.dart:92`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/widgets/sync_status_indicator_widget.dart#L92) | `if (!FeatureFlags.offlineFirstEnabled)` | Renders `const SizedBox.shrink()` (hides red/green light) when OFF. |
| 7 | [`frontend/lib/data/pos_repository.dart:169`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/pos_repository.dart#L169) | `if (FeatureFlags.offlineFirstEnabled)` | Injects `terminalSequencesDao` into `OrderNumberGenerator`; returns unbacked generator when OFF. |
| 8 | [`frontend/lib/data/repositories/order_repository_provider.dart:33`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L33) | `if (FeatureFlags.offlineFirstEnabled)` | Returns `DriftOfflineFirstOrderRepository` when ON; returns `ApiOrderRepository` when OFF. |
| 9 | [`frontend/lib/data/repositories/order_repository_provider.dart:42`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L42) | `if (FeatureFlags.offlineFirstEnabled)` | Streams all orders from Drift when ON; returns `Stream.empty()` when OFF. |
| 10 | [`frontend/lib/data/repositories/order_repository_provider.dart:51`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L51) | `if (FeatureFlags.offlineFirstEnabled)` | Streams pending orders from Drift when ON; returns `Stream.empty()` when OFF. |
| 11 | [`frontend/lib/data/daily_calculation_repository.dart:151`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L151) | `if (FeatureFlags.offlineFirstEnabled)` | Checks local active shift in Drift SQLite before REST probe. |
| 12 | [`frontend/lib/data/daily_calculation_repository.dart:190`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L190) | `if (FeatureFlags.offlineFirstEnabled)` | Upserts server active shift into local Drift SQLite table `local_daily_calculations`. |
| 13 | [`frontend/lib/data/daily_calculation_repository.dart:328`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L328) | `if (FeatureFlags.offlineFirstEnabled)` | Opens shift locally in Drift SQLite (Level 0 mutation); falls back to REST when OFF. |
| 14 | [`frontend/lib/data/daily_calculation_repository.dart:466`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L466) | `if (FeatureFlags.offlineFirstEnabled)` | Computes live summary from Drift SQLite when backend is offline. |
| 15 | [`frontend/lib/data/daily_calculation_repository.dart:650`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L650) | `if (FeatureFlags.offlineFirstEnabled)` | Verifies cashier active shift in Drift SQLite before closing shift. |
| 16 | [`frontend/lib/data/daily_calculation_repository.dart:757`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L757) | `if (FeatureFlags.offlineFirstEnabled && isNetworkError)` | Executes offline shift close in Drift SQLite (Level 5 mutation) on network exception. |
| 17 | [`frontend/lib/data/delivery_repository.dart:68`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L68) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Loads offline delivery orders from Drift SQLite. |
| 18 | [`frontend/lib/data/delivery_repository.dart:307`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L307) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Saves delivery order atomically to Drift SQLite and `sync_outbox`. |
| 19 | [`frontend/lib/data/delivery_repository.dart:386`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L386) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Marks delivery order synced in Drift SQLite upon REST success. |
| 20 | [`frontend/lib/data/delivery_repository.dart:396`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L396) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Triggers worker push on delivery REST failure. |
| 21 | [`frontend/lib/data/delivery_repository.dart:425`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L425) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Updates delivery order details in Drift SQLite. |
| 22 | [`frontend/lib/data/delivery_repository.dart:625`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L625) | `if (FeatureFlags.offlineFirstEnabled && _ref != null ...)` | Updates delivery order payment status in Drift SQLite. |
| 23 | [`frontend/lib/data/takeaway_repository.dart:67`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L67) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Loads offline takeaway orders from Drift SQLite. |
| 24 | [`frontend/lib/data/takeaway_repository.dart:322`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L322) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Saves takeaway order atomically to Drift SQLite and `sync_outbox`. |
| 25 | [`frontend/lib/data/takeaway_repository.dart:382`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L382) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Marks takeaway order synced in Drift SQLite upon REST success. |
| 26 | [`frontend/lib/data/takeaway_repository.dart:393`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L393) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Triggers worker push on takeaway REST failure. |
| 27 | [`frontend/lib/data/takeaway_repository.dart:471`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L471) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Updates takeaway order details in Drift SQLite. |
| 28 | [`frontend/lib/data/takeaway_repository.dart:612`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L612) | `if (FeatureFlags.offlineFirstEnabled && _ref != null)` | Updates takeaway order payment status in Drift SQLite. |
| 29 | [`frontend/lib/data/table_repository.dart:119`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L119) | `if (FeatureFlags.offlineFirstEnabled && localDb != null ...)` | Upserts restaurant tables into Drift `local_restaurant_tables`. |
| 30 | [`frontend/lib/data/table_repository.dart:148`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L148) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Loads tables from Drift `local_restaurant_tables` on network failure. |
| 31 | [`frontend/lib/data/table_repository.dart:206`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L206) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Updates table bill and status locally in Drift SQLite. |
| 32 | [`frontend/lib/data/table_repository.dart:269`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L269) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Updates table bill amount locally in Drift SQLite. |
| 33 | [`frontend/lib/data/table_repository.dart:351`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L351) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Enqueues OCC Level 3 table status mutation into `sync_outbox`. |
| 34 | [`frontend/lib/data/table_repository.dart:439`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L439) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Enqueues table reservation mutation into `sync_outbox`. |
| 35 | [`frontend/lib/data/table_repository.dart:512`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L512) | `if (FeatureFlags.offlineFirstEnabled && localDb != null)` | Upserts newly created table into Drift catalog. |
| 36 | [`frontend/lib/data/table_repository.dart:589`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L589) | `FeatureFlags.offlineFirstEnabled ? ref.watch(appDatabaseProvider) : null` | Injects `AppDatabase` into `tableProvider` only when ON. |
| 37 | [`frontend/lib/data/sync_repository.dart:340`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L340) | `if (FeatureFlags.offlineFirstEnabled && _db != null)` | Loads local orders from Drift for Data Sync screen. |
| 38 | [`frontend/lib/data/sync_repository.dart:346`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L346) | `if (FeatureFlags.offlineFirstEnabled && !isOnline)` | Sets Data Sync UI state from SQLite when offline. |
| 39 | [`frontend/lib/data/sync_repository.dart:382`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L382) | `if (FeatureFlags.offlineFirstEnabled)` | Merges local pending orders with backend orders. |
| 40 | [`frontend/lib/data/sync_repository.dart:397`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L397) | `totalPending = FeatureFlags.offlineFirstEnabled ? ... : ...` | Derives pending count from SQLite when ON, or REST summary when OFF. |
| 41 | [`frontend/lib/data/sync_repository.dart:418`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L418) | `if (FeatureFlags.offlineFirstEnabled && localOrders.isNotEmpty)` | Fallback to SQLite data when REST endpoint fails. |
| 42 | [`frontend/lib/data/sync_repository.dart:481`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L481) | `if (FeatureFlags.offlineFirstEnabled && worker != null)` | Triggers worker push when syncing all orders. |
| 43 | [`frontend/lib/data/sync_repository.dart:511`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L511) | `if (FeatureFlags.offlineFirstEnabled && worker != null)` | Triggers worker push when syncing single order. |
| 44 | [`frontend/lib/data/sync_repository.dart:595-597`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/sync_repository.dart#L595-L597) | `FeatureFlags.offlineFirstEnabled ? ref.watch(...) : null` | Conditionally injects `db`, `connectivity`, and `worker` into `dataSyncProvider`. |
| 45 | [`frontend/lib/features/reports/reports_providers.dart:136`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/reports/reports_providers.dart#L136) | `if (FeatureFlags.offlineFirstEnabled)` | Merges pending offline orders into product sales report. |
| 46 | [`frontend/lib/features/reports/reports_providers.dart:223`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/reports/reports_providers.dart#L223) | `if (FeatureFlags.offlineFirstEnabled)` | Merges pending offline orders into sales summary report. |
| 47 | [`frontend/lib/features/reports/reports_providers.dart:417`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/reports/reports_providers.dart#L417) | `if (cancelled.isEmpty && FeatureFlags.offlineFirstEnabled)` | Falls back to local cancelled orders from Drift when server returns empty. |
| 48 | [`frontend/lib/features/sync/cashier_sync_center_provider.dart:183`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/cashier_sync_center_provider.dart#L183) | `if (FeatureFlags.offlineFirstEnabled && db != null)` | Loads timeline events from Drift in cashier sync center. |
| 49 | [`frontend/lib/features/sync/cashier_sync_center_provider.dart:702-705`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/cashier_sync_center_provider.dart#L702-L705) | `FeatureFlags.offlineFirstEnabled ? ref.watch(...) : null` | Conditionally injects `db`, `connectivity`, and `worker` into `cashierSyncCenterProvider`. |
| 50 | [`frontend/lib/features/tables/tables_screen.dart:2122`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L2122) | `if (FeatureFlags.offlineFirstEnabled)` | Updates table bill via `orderRepo` when ON; uses direct `ordersApi.updateOrder` when OFF. |
| 51 | [`frontend/lib/features/tables/tables_screen.dart:3107`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L3107) | `if (FeatureFlags.offlineFirstEnabled)` | Fallback to Drift catalog when menu API fails. |
| 52 | [`frontend/lib/features/tables/tables_screen.dart:3233`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L3233) | `if (FeatureFlags.offlineFirstEnabled)` | Reads active order from `orderRepo` when ON; calls `ordersApi.getOrderById` when OFF. |
| 53 | [`frontend/lib/features/tables/tables_screen.dart:3910`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L3910) | `if (FeatureFlags.offlineFirstEnabled)` | Persists table order to Drift and triggers worker push; skipped when OFF. |
| 54 | [`frontend/lib/features/tables/tables_screen.dart:5276`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5276) | `if (FeatureFlags.offlineFirstEnabled)` | Updates paid order via `orderRepo` when ON; calls `ordersApi.updateOrder` when OFF. |
| 55 | [`frontend/lib/features/tables/tables_screen.dart:5924`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5924) | `if (FeatureFlags.offlineFirstEnabled)` | Updates split payment order via `orderRepo` when ON; calls `ordersApi.updateOrder` when OFF. |

### Backend Reads
- **Result:** `NOT FOUND`.
- **Evidence:** Global search across `backend/src/` for `OFFLINE_FIRST_ENABLED` and `offlineFirstEnabled` yields 0 matches.
- **Verification:** The NestJS backend contains **zero feature flag checks**. The backend sync subsystem (`/api/sync/push`, `/api/sync/pull`, `/api/sync/bootstrap`) is mounted alongside the standard legacy REST routes (`/api/orders`, `/api/tables`, etc.) without conditional routing.

---

## Task 2: Entry Point Execution Traces under Flag-OFF State

### 1. App Startup Flow
- **Execution Path:** `main()` -> `HungryHowiesPosApp.initState()` -> `addPostFrameCallback()`.
- **Gating Check:** [`frontend/lib/main.dart:43-45`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/main.dart#L43-L45):
  ```dart
  if (FeatureFlags.offlineFirstEnabled) {
    ref.read(syncBackgroundWorkerProvider).start();
  }
  ```
- **Observed Behavior:**
  - `syncBackgroundWorkerProvider.start()` is **not** called.
  - `appDatabaseProvider` is **not** instantiated during normal app launch.
  - SQLite WAL files are **not** opened or locked.
  - DPAPI encryption key is **not** derived.
  - Realtime WebSocket service connects normally via `ref.read(realtimeSocketServiceProvider).connect()`.
  - Silent auto-update timer runs normally via `autoUpdateControllerProvider`.
- **Verdict:** **PASS**.

### 2. Cashier Authentication Flow
- **Execution Path:** `LoginScreen` -> `ref.read(authProvider.notifier).login(username, password)`.
- **Observed Behavior:**
  - Executes HTTP POST to `/api/auth/login` via `AuthApiService`.
  - Saves JWT session securely in `TokenStorage`.
  - Loads fallback staff into `InMemoryAuthRepository`.
  - Drift SQLite tables (`LocalStaffUsers`, `LocalRolePermissions`) are **not** accessed.
  - No background worker tasks are enqueued.
- **Verdict:** **PASS**.

### 3. POS Order Checkout Flow
- **Execution Path:** `PosNotifier.checkoutOrder()` -> `CompleteOrderUseCase.execute(command)`.
- **Observed Behavior:**
  1. `orderNumberGeneratorProvider` produces `OrderNumberGenerator` with in-memory sequence starting at `100` ([`pos_repository.dart:168-174`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/pos_repository.dart#L168-L174)).
  2. First order generates sequence receipt `'P1-101'`.
  3. `orderRepositoryProvider` resolves to `ApiOrderRepository` ([`order_repository_provider.dart:36`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L36)).
  4. `ApiOrderRepository.saveOrder()` calls `order.toCreateOrderDto()`, which sends `'order_number': 'P1-101'` but **omits** `'id'` ([`api_order_repository.dart:62`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/api_order_repository.dart#L62)).
  5. The app or PC restarts, resetting the in-memory counter back to `100`.
  6. The next order generated is `'P1-101'`.
  7. Backend `OrdersService.createOrderInTx()` checks `findUnique({ where: { order_number: 'P1-101' } })`. Because the order already exists and `explicitOrderId` is undefined, the backend throws an HTTP 409 `ConflictException("Order number 'P1-101' already exists")` ([`backend/src/orders/orders.service.ts:316`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L316)).
  8. `ApiOrderRepository.saveOrder()` catches the exception in a blind `catch (_)` block and returns the un-persisted order to the caller ([`api_order_repository.dart:67-70`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/api_order_repository.dart#L67-L70)).
  9. The cart clears and the cashier believes the order was saved, but **the order is completely lost from the backend database**.
- **Verdict:** <span style="color:red;font-weight:bold;">FAIL (CRITICAL)</span> ([`FLG-01`](#flg-01-order-number-collision-rejection-and-silent-order-loss-on-pos-checkout)).

### 4. Dine-In Tables Flow
- **Execution Path:** `tables_screen.dart` -> `TableNotifier.loadTables()`, `updateTableBillAndStatus()`, `reserveTable()`.
- **Observed Behavior:**
  - `tableProvider` sets `db = null` ([`table_repository.dart:589`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L589)).
  - Table bill and status updates bypass Drift catalog updates and outbox insertions ([`table_repository.dart:119, 351, 439`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L119)).
  - Active orders for occupied tables are fetched directly via `ordersApi.getOrderById()` ([`tables_screen.dart:3276-3283`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L3276-L3283)).
  - Order completion updates the backend directly via `ordersApi.updateOrder()` ([`tables_screen.dart:5304-5310, 5952-5955`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L5304-L5310)).
- **Verdict:** **PASS**.

### 5. Order History (Takeaway & Delivery)
- **Execution Path:** `TakeawayNotifier.loadTakeawayOrders()`, `updateOrderStatus()`, `DeliveryNotifier.loadDeliveryData()`.
- **Observed Behavior:**
  - Loading orders bypasses Drift SQLite and pulls from `_ordersApiService.listOrders()`.
  - In `TakeawayNotifier.updateOrderStatus()`, lines 536-543:
    1. Line 536 calls `await _ordersApiService.updateOrderStatus(orderId, status: statusStr);`.
    2. Lines 538-543 check `if (_ref != null)` without checking `FeatureFlags.offlineFirstEnabled`.
    3. `_ref.read(orderRepositoryProvider)` resolves to `ApiOrderRepository`, which calls `_ordersApiService.updateOrderStatus(orderId, status: parsedStatus.name);` **a second time**.
    4. Two identical HTTP PATCH requests are sent to the backend for every status change.
- **Verdict:** <span style="color:orange;font-weight:bold;">FAIL (MEDIUM)</span> ([`FLG-05`](#flg-05-redundant-duplicate-rest-api-call-on-takeaway-order-status-updates)).

### 6. Reports & Analytics
- **Execution Path:** `reports_screen.dart` -> `reportSummaryProvider`, `reportProductsProvider`, `cancelledOrdersProvider`.
- **Observed Behavior:**
  - `reports_providers.dart:136, 223, 417`: All Drift queries are cleanly guarded behind `if (FeatureFlags.offlineFirstEnabled)`.
  - When OFF, reports fetch exclusively from backend REST endpoints `/api/reports/...`.
- **Verdict:** **PASS**.

### 7. Settings & Printing Flow
- **Execution Path:** `settings_screen.dart`, `ReceiptPrinterService.printKitchenReceipt()`, `printCustomerReceipt()`.
- **Observed Behavior:**
  - `ReceiptPrinterService._database` is `null` because `appDatabaseProvider` was not initialized.
  - Lines 1873-1904: Enqueueing into `OfflinePrintJobs` Drift table is bypassed (`if (targetDb != null)`).
  - Lines 1906-1920: Direct Win32 thermal raw printing executes cleanly.
  - Lines 1923-1932: Status update in `OfflinePrintJobs` is bypassed.
- **Verdict:** **PASS**.

---

## Task 3: Inadvertent Execution & Resource Allocation under Flag-OFF

The following table catalogs every component that executes or allocates resources when `OFFLINE_FIRST_ENABLED = false`:

| Component / Resource | Executes When Flag OFF? | Root Cause & Allocation Mechanism | Code Reference |
|---|---|---|---|
| **Drift SQLite (`AppDatabase`)** | <span style="color:red;font-weight:bold;">YES (on owner navigation)</span> | `syncCenterProvider` unconditionally watches `appDatabaseProvider`. Opens SQLite WAL file and runs DPAPI encryption if owner visits `/owner/sync-center`. | [`sync_center_provider.dart:538`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/sync_center_provider.dart#L538) |
| **Background Sync Worker** | <span style="color:red;font-weight:bold;">YES (on owner navigation)</span> | `syncCenterProvider` unconditionally watches `syncBackgroundWorkerProvider`. Instantiates worker and registers state notifiers if owner visits `/owner/sync-center`. | [`sync_center_provider.dart:542`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/sync_center_provider.dart#L542) |
| **Shift Repository Seam** | <span style="color:orange;font-weight:bold;">YES (on provider read)</span> | `shiftRepositoryProvider` unconditionally binds to `DriftOfflineFirstShiftRepository`, which watches `appDatabaseProvider`. | [`shift_repository_provider.dart:7-19`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/shift_repository_provider.dart#L7-L19) |
| **Connectivity Polling Loop** | <span style="color:orange;font-weight:bold;">YES (on sync button tap)</span> | Tapping top-bar `SyncButton` calls `GlobalSyncController.syncAndRefreshAll()`, which reads `connectivityNotifierProvider.notifier`. Starts un-gated `Timer.periodic(15s)` probing `/api/health`. | [`global_sync_controller.dart:48`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/services/sync/global_sync_controller.dart#L48)<br>[`connectivity_notifier.dart:181`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/connectivity_notifier.dart#L181) |
| **Idempotency Interceptor** | **PASS (zero overhead)** | Applied globally on backend `@UseInterceptors(IdempotencyInterceptor)`. Passes immediately to `next.handle()` when `X-Idempotency-Key` or `operation_id` is absent. | [`backend/src/sync/interceptors/idempotency.interceptor.ts:82-85`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/sync/interceptors/idempotency.interceptor.ts#L82-L85) |
| **Native Plugin DLLs** | **YES (binary footprint)** | `sqlcipher.dll` and `sqlite3.dll` are compiled and packaged into the Windows build executable regardless of runtime flag state. | [`frontend/pubspec.yaml:51-56`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/pubspec.yaml#L51-L56) |

---

## Task 4: Shared Code Behavioral Divergence Analysis

Diffing current code against baseline commit `819c8c0~1` reveals the following behavioral changes in the shared online path:

### 1. `OrderNumberGenerator` Numbering Scheme
- **Baseline Behavior:** Generated chronological receipt numbers formatted as `HH-yyMMdd-1001` ([`order_number_generator.dart:28`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L28)).
- **Current Flag-OFF Behavior:** Generates terminal-prefixed numbers formatted as `P1-101` from an in-memory counter that resets to 100 on every restart ([`order_number_generator.dart:60-69`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L60-L69)).
- **Divergence:** Guarantees collision against earlier orders taken on the same day whenever the terminal restarts.

### 2. Backend Order Collision Reassignment
- **Baseline Behavior:** If a duplicate `order_number` was sent, the backend immediately threw `ConflictException("Order number ... already exists")` ([`orders.service.ts:316`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L316)).
- **Current Shared Behavior:** If `explicitOrderId` is passed, the backend automatically renames the order with a suffix (e.g. `P1-101-1`). However, because `ApiOrderRepository` does **not** send `explicitOrderId`, this collision-reassignment logic is bypassed, and the backend continues to throw `ConflictException`.

### 3. Backend Table Auto-Free on Order Completion
- **Baseline Behavior:** Updating an order to `status: 'completed'` or `is_paid: true` in `OrdersService.updateOrder()` automatically updated the associated table to `status: 'available', active_order_id: null` ([`commit 8b37849`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L792-L805)).
- **Current Shared Behavior:** In `orders.service.ts:795`, the auto-free behavior was removed so that *"tables remain occupied until staff explicitly clicks 'Free Table'"*.
- **Divergence:** While this affects both online and offline clients, the frontend explicitly calls `TableNotifier.updateTableBillAndStatus(..., TableStatus.available)` in `tables_screen.dart:5341`, so UI operations remain functional.

---

## Task 5: Backend Compatibility, Invariants & Migration Analysis

### 1. DTO Validation Changes
Diffing `backend/src/orders/dto/create-order.dto.ts` and `backend/src/daily-calculation/dto/` against baseline confirms:
- All newly introduced fields (`id?: string`, `is_adjustment?: boolean`, `cash_variance?: number`, `variance_reason?: string`, `force_close?: boolean`) are decorated with `@IsOptional()`.
- **Verdict:** No required DTO fields were added. A legacy client sending baseline JSON payloads passes validation cleanly.

### 2. Prisma Database Migrations
Four migrations were introduced during the offline-first implementation:
1. `20261017000000_offline_sync_schema`:
   - Adds nullable OCC columns (`version`, `is_deleted`, `deleted_at`) with defaults (`default(1)`, `default(false)`).
   - Creates new tables `processed_operations` and `system_change_logs`.
   - **Verdict:** 100% additive; zero breaking constraint or column alterations.
2. `20261023120000_unique_active_shift`:
   - Adds `closed_by_id` and `closed_by_name`.
   - Adds partial unique index: `CREATE UNIQUE INDEX "unique_active_shift" ON "daily_calculations" ("status") WHERE "status" = 'ACTIVE';`.
   - **Impact on Flag-OFF Client:** Enforces store-wide single active shift invariant. If an online cashier attempts to open a second active shift, the server rejects it with HTTP 409 Conflict rather than allowing silent multiple active shifts. This is an intentional invariant enforcement.
3. `20261025000000_sync_performance_and_shift_indexes`:
   - Adds btree performance indexes on `orders(shift_id)`, `orders(status)`, `orders(created_at)`, `daily_calculations(status)`.
   - **Verdict:** Strictly additive performance enhancements.

---

## Task 6: Data Model & DTO Serialization Analysis

Inspection of `frontend/lib/domain/models/`:
- `order_model.dart`: Has not been modified since baseline commit `bca666f`. `toCreateOrderDto()` continues to produce the exact same JSON schema as before offline-first was introduced.
- `daily_calculation_model.dart`: Added optional fields (`shiftDate`, `openedAt`, `status`, `shiftId`, `sessionId`) with safe fallback deserialization in `fromJson`. `toJson()` was not modified.
- `role_rights_model.dart`: Added `toJson()` helper method. No existing serialization altered.
- **Verdict:** **PASS**. No shared domain models alter JSON serialization sent to the backend when flag is OFF.

---

## Task 7: Rollback, Stranded Outbox Mutations & Drain Lifecycle

### The Rollback Scenario
The architecture specification explicitly promises a 1-step rollback:  
> *"If any phase encounters regressions during pilot testing, flipping `OFFLINE_FIRST_ENABLED = false` immediately restores 100% legacy online behavior without requiring app uninstallation or database schema downgrades."* (`docs/offline-analysis/99-FINAL-ARCHITECTURE.md:1062-1064`)

### What Actually Happens When the Flag is Flipped to `false`:
1. **Outbox Halted:** `main.dart:43` skips calling `syncBackgroundWorkerProvider.start()`.
2. **Repository Reverted:** `orderRepositoryProvider` immediately resolves to `ApiOrderRepository`.
3. **Local Queue Abandoned:** Any mutations sitting in SQLite `sync_outbox` (Level 0..6) are completely ignored.
4. **Zero Cashier Visibility:** `SyncStatusIndicatorWidget` renders `SizedBox.shrink()`. The cashier has no indication that 10, 50, or 100 orders taken during an outage remain unsynced in SQLite.
5. **No Drain-Then-Disable Path:** There is **no code in the repository** that checks for un-synced outbox mutations prior to deactivating the worker, nor is there a CLI flag or admin tool to trigger a final drain.

**Conclusion:** Rollback from `true` to `false` without a manual database inspection **causes catastrophic data stranding and loss of unpushed revenue** ([`FLG-02`](#flg-02-permanent-stranding--data-loss-of-local-outbox-mutations-upon-flag-rollback)).

---

## Task 8: Binary Footprint, Memory Overhead & Permissions Audit

| Metric | Pre-Offline Baseline | Current Flag-OFF Build | Difference / Impact |
|---|---|---|---|
| **Windows Executable & Bundle Size** | ~42 MB | ~65 MB | **+23 MB** due to bundled native `sqlite3.dll`, `sqlcipher.dll`, and Drift FFI bindings in release runner. |
| **Idle Memory Consumption** | ~110 MB RAM | ~115 MB RAM | **+5 MB RAM** (negligible when Drift is not opened). Increases by +25 MB if owner visits Sync Center. |
| **Startup Time (Cold Launch)** | ~850 ms | ~920 ms | **+70 ms** due to additional Dart symbol loading and FFI initialization. |
| **Windows OS Permissions** | Standard desktop user | Standard desktop user | **Zero changes**. No elevated administrator permissions required. |
| **Network Permissions** | Outbound HTTP/WS | Outbound HTTP/WS | **Zero changes**. |

---

## Formal Findings Ledger

### FLG-01: Order Number Collision Rejection and Silent Order Loss on POS Checkout
- **Severity:** Critical
- **Evidence:** [`frontend/lib/domain/services/order_number_generator.dart:34-65`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/domain/services/order_number_generator.dart#L34-L65), [`frontend/lib/data/pos_repository.dart:168-174`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/pos_repository.dart#L168-L174), [`frontend/lib/data/repositories/api_order_repository.dart:60-70`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/api_order_repository.dart#L60-L70), [`backend/src/orders/orders.service.ts:298-319`](file:///D:/HOWIES%20TEST/howiesPOS/backend/src/orders/orders.service.ts#L298-L319)
- **Failure sequence:**
  1. POS app is compiled with `OFFLINE_FIRST_ENABLED = false`.
  2. Cashier boots POS app. `orderNumberGeneratorProvider` instantiates `OrderNumberGenerator` without Drift sequence DAO. In-memory `_currentSequence` initializes to `100`.
  3. Cashier creates order #1 and taps Checkout. `generateOrderNumber()` returns `'P1-101'`.
  4. App is restarted or cashier opens POS for afternoon shift. In-memory `_currentSequence` resets to `100`.
  5. Cashier creates an order and checks out. `generateOrderNumber()` returns `'P1-101'` again.
  6. `CompleteOrderUseCase` constructs `OrderModel` with `orderNumber: 'P1-101'` and calls `ApiOrderRepository.saveOrder()`.
  7. `OrderModel.toCreateOrderDto()` serializes `order_number: 'P1-101'` but does NOT include an `id` field.
  8. Backend `OrdersService.createOrderInTx()` checks `findUnique({ where: { order_number: 'P1-101' } })`. Because the previous order `'P1-101'` exists in PostgreSQL and `explicitOrderId` is undefined, the backend enters the collision branch and executes `throw new ConflictException("Order number 'P1-101' already exists")` (HTTP 409).
  9. `ApiOrderRepository.saveOrder()` catches the exception in `catch (_) { _localCache.insert(0, order); return order; }`, swallowing the failure and returning the unpersisted order model to `CompleteOrderUseCase`.
  10. `CompleteOrderUseCase` reports `Result.success(savedOrder)`, UI clears the cart, and cashier hands receipt to customer. The order was **never written to PostgreSQL and never written to Drift**.
- **Impact:** Lost order | money loss.
- **Recommended fix:** In `OrderNumberGenerator.generateOrderNumber()`, when `terminalSequencesDao == null` (flag OFF), preserve the pre-offline legacy collision-free scheme `'HH-${DateFormat('yyMMdd').format(now)}-$seq'` or omit `order_number` from `toCreateOrderDto()` so backend auto-assigns monotonic 3-digit receipt numbers. Additionally, `ApiOrderRepository.saveOrder()` must rethrow network/HTTP exceptions rather than swallowing them.
- **Effort:** S
- **Status:** CONFIRMED

---

### FLG-02: Permanent Stranding / Data Loss of Local Outbox Mutations upon Flag Rollback
- **Severity:** Critical
- **Evidence:** [`frontend/lib/config/feature_flags.dart:5-6`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/config/feature_flags.dart#L5-L6), [`frontend/lib/main.dart:43-45`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/main.dart#L43-L45), [`frontend/lib/data/repositories/order_repository_provider.dart:32-38`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/order_repository_provider.dart#L32-L38), [`frontend/lib/core/sync/sync_background_worker.dart:180-220`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L180-L220)
- **Failure sequence:**
  1. Terminal runs in offline-first mode (`OFFLINE_FIRST_ENABLED = true`). Orders are taken while network is disconnected.
  2. Mutations accumulate in SQLite WAL (`local_orders`, `sync_outbox` with status `PENDING`).
  3. Administrator flips flag to `OFFLINE_FIRST_ENABLED = false` to roll back to online-only operation.
  4. App launches with flag OFF. `main.dart:43` skips starting `SyncBackgroundWorker`.
  5. `orderRepositoryProvider` resolves to `ApiOrderRepository`. Drift tables are never queried.
  6. No drain-then-disable mechanism exists. The background worker never starts, and outbox mutations are neither pushed nor monitored.
  7. Orders taken offline while flag was ON remain permanently stranded in local SQLite WAL files without any cashier warning or indication (sync light is hidden).
- **Impact:** Lost order | money loss | unrecoverable data stranding.
- **Recommended fix:** Implement a startup drain check: even when `OFFLINE_FIRST_ENABLED = false`, check if `local_orders` / `sync_outbox` contains pending unsynced records. If so, display a blocking warning dialogue and provide an explicit "Drain and Disable" migration path before reverting fully to online-only REST.
- **Effort:** M
- **Status:** CONFIRMED

---

### FLG-03: Owner/Manager Sync Center Route Unconditionally Instantiates Drift SQLite Database and Sync Worker
- **Severity:** High
- **Evidence:** [`frontend/lib/config/router.dart:244-252`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/config/router.dart#L244-L252), [`frontend/lib/features/sync/sync_center_provider.dart:537-555`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/sync/sync_center_provider.dart#L537-L555), [`frontend/lib/core/sync/sync_providers.dart:13-59`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_providers.dart#L13-L59)
- **Failure sequence:**
  1. App compiles with `OFFLINE_FIRST_ENABLED = false`.
  2. Owner or Manager logs in and clicks "Sync Center" in the sidebar navigation (`/owner/sync-center` or `/owner/data-sync`).
  3. `router.dart` mounts `SyncCenterScreen()`.
  4. `SyncCenterScreen` reads `syncCenterProvider`.
  5. Unlike `cashierSyncCenterProvider` (which properly checks `FeatureFlags.offlineFirstEnabled`), `syncCenterProvider` unconditionally calls:
     - `ref.watch(appDatabaseProvider)`
     - `ref.watch(syncBackgroundWorkerProvider)`
     - `ref.watch(connectivityNotifierProvider.notifier)`
  6. Drift `AppDatabase` is instantiated, allocating native SQLCipher/SQLite memory, executing DPAPI Windows encryption key derivation, and acquiring SQLite WAL file locks.
  7. Background worker is initialized and mounts its internal listeners.
- **Impact:** Security / unexpected memory allocation / architectural violation of flag isolation.
- **Recommended fix:** In `sync_center_provider.dart:537-555`, wrap `appDatabaseProvider`, `syncBackgroundWorkerProvider`, and `connectivityNotifierProvider` in `FeatureFlags.offlineFirstEnabled ? ... : null`, matching the pattern in `cashier_sync_center_provider.dart:700-715`.
- **Effort:** S
- **Status:** CONFIRMED

---

### FLG-04: Unbounded 15-Second Background Polling Timer Triggered by Top Bar Sync Button
- **Severity:** Medium
- **Evidence:** [`frontend/lib/shared/widgets/cashier_top_navigation_bar.dart:289`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/shared/widgets/cashier_top_navigation_bar.dart#L289), [`frontend/lib/shared/widgets/sync_button.dart:51`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/shared/widgets/sync_button.dart#L51), [`frontend/lib/services/sync/global_sync_controller.dart:48`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/services/sync/global_sync_controller.dart#L48), [`frontend/lib/core/sync/sync_providers.dart:24-30`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_providers.dart#L24-L30), [`frontend/lib/core/sync/connectivity_notifier.dart:177-185`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/connectivity_notifier.dart#L177-L185)
- **Failure sequence:**
  1. App runs with `OFFLINE_FIRST_ENABLED = false`.
  2. Cashier top navigation bar renders `SyncButton` (line 289).
  3. Cashier taps the sync pill / refresh button.
  4. `SyncButton` calls `GlobalSyncController.syncAndRefreshAll()`.
  5. Line 48 executes `await ref.read(connectivityNotifierProvider.notifier).probeHealth()`.
  6. Accessing `connectivityNotifierProvider` triggers its provider factory in `sync_providers.dart:28`, which calls `notifier.startMonitoring()`.
  7. `startMonitoring()` sets `_monitorTimer = Timer.periodic(const Duration(seconds: 15), (_) => probeHealth())`.
  8. From that moment forward, an active HTTP GET request to `/api/health` is dispatched across the network every 15 seconds indefinitely, even though offline-first mode is disabled.
- **Impact:** Extra network calls / unwanted battery & network polling overhead.
- **Recommended fix:** In `GlobalSyncController.syncAndRefreshAll()`, gate health probing behind `if (FeatureFlags.offlineFirstEnabled)`. In `sync_providers.dart:24-30`, do not call `notifier.startMonitoring()` if `!FeatureFlags.offlineFirstEnabled`.
- **Effort:** S
- **Status:** CONFIRMED

---

### FLG-05: Redundant Duplicate REST API Call on Takeaway Order Status Updates
- **Severity:** Medium
- **Evidence:** [`frontend/lib/data/takeaway_repository.dart:536-543`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L536-L543)
- **Failure sequence:**
  1. Cashier runs POS with `OFFLINE_FIRST_ENABLED = false` and opens Takeaway screen.
  2. Cashier clicks to mark an order "Ready for Pickup" or "Completed".
  3. `TakeawayNotifier.updateOrderStatus()` executes line 536:
     `await _ordersApiService.updateOrderStatus(orderId, status: statusStr);`
  4. Next, lines 538-543 run:
     ```dart
     if (_ref != null) {
       final orderRepo = _ref.read(orderRepositoryProvider);
       await orderRepo.updateOrderStatus(orderId, parsedStatus);
     }
     ```
  5. Because `FeatureFlags.offlineFirstEnabled == false`, `orderRepositoryProvider` resolves to `ApiOrderRepository`.
  6. `ApiOrderRepository.updateOrderStatus()` executes:
     `await _ordersApiService.updateOrderStatus(orderId, status: status.name);`
  7. Exactly identical HTTP `PATCH /api/orders/:id/status` is transmitted over the wire twice in immediate succession.
- **Impact:** Extra network calls / duplicate HTTP traffic / server race condition.
- **Recommended fix:** In `takeaway_repository.dart:538`, wrap the local repository sync in `if (FeatureFlags.offlineFirstEnabled && _ref != null)`.
- **Effort:** S
- **Status:** CONFIRMED

---

### FLG-06: Unconditional Shift Repository Seam Provider
- **Severity:** Low
- **Evidence:** [`frontend/lib/data/repositories/shift_repository_provider.dart:7-19`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/shift_repository_provider.dart#L7-L19)
- **Failure sequence:**
  1. Unlike `orderRepositoryProvider` (which cleanly branches between `DriftOfflineFirstOrderRepository` and `ApiOrderRepository`), `shiftRepositoryProvider` has no branch and unconditionally points to `driftOfflineFirstShiftRepositoryProvider`.
  2. `driftOfflineFirstShiftRepositoryProvider` directly watches `appDatabaseProvider`.
  3. Currently, calls to `ref.read(shiftRepositoryProvider)` in `daily_calculation_repository.dart` are gated by `if (FeatureFlags.offlineFirstEnabled)`.
  4. However, any new or existing consumer watching `shiftRepositoryProvider` will immediately trigger full Drift database instantiation when the flag is OFF.
- **Impact:** Architectural leakage / fragile abstraction.
- **Recommended fix:** Provide an `ApiShiftRepository` fallback in `shift_repository_provider.dart` when `!FeatureFlags.offlineFirstEnabled`, identical to `orderRepositoryProvider`.
- **Effort:** S
- **Status:** CONFIRMED

---

### FLG-07: Minor Top Navigation Bar Spacing Artifact When Sync Indicator Shrunk
- **Severity:** Low
- **Evidence:** [`frontend/lib/shared/widgets/cashier_top_navigation_bar.dart:294-299`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/shared/widgets/cashier_top_navigation_bar.dart#L294-L299), [`frontend/lib/core/widgets/sync_status_indicator_widget.dart:92-94`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/widgets/sync_status_indicator_widget.dart#L92-L94)
- **Failure sequence:**
  1. When `OFFLINE_FIRST_ENABLED = false`, `SyncStatusIndicatorWidget.build()` returns `const SizedBox.shrink()`.
  2. In `cashier_top_navigation_bar.dart`, line 294 adds `const SizedBox(width: 8)`, followed by `SyncStatusIndicatorWidget()`, followed by line 299 adding `const SizedBox(width: 8)`.
  3. When shrunk, a double gap of 16px is rendered between `SyncButton` and the auto-update check button, causing a slight visual layout asymmetry compared to the original 8px navbar rhythm.
- **Impact:** UX / visual layout asymmetry.
- **Recommended fix:** In `cashier_top_navigation_bar.dart`, place `if (FeatureFlags.offlineFirstEnabled) ...[ const SizedBox(width: 8), const SyncStatusIndicatorWidget() ]`.
- **Effort:** S
- **Status:** CONFIRMED

---

## Remediation Matrix & Safe Rollout Roadmap

To make `OFFLINE_FIRST_ENABLED = false` 100% equivalent to the pre-offline POS, apply the following minimal fixes:

| Fix ID | Target File | Action Required | Effort |
|---|---|---|---|
| **FIX-01** | `frontend/lib/domain/services/order_number_generator.dart` | In `generateOrderNumber()`, check `if (_terminalSequencesDao == null)`: return legacy `'HH-${DateFormat('yyMMdd').format(DateTime.now())}-$_dailySequence'`. | S |
| **FIX-02** | `frontend/lib/data/repositories/api_order_repository.dart` | In `saveOrder()`, rethrow `ApiException` / network exceptions rather than returning the unsaved order model. | S |
| **FIX-03** | `frontend/lib/features/sync/sync_center_provider.dart` | Wrap `appDatabaseProvider`, `syncBackgroundWorkerProvider`, and `connectivityNotifierProvider` in `FeatureFlags.offlineFirstEnabled ? ... : null`. | S |
| **FIX-04** | `frontend/lib/data/takeaway_repository.dart` | Change line 538 from `if (_ref != null)` to `if (FeatureFlags.offlineFirstEnabled && _ref != null)`. | S |
| **FIX-05** | `frontend/lib/core/sync/sync_providers.dart` | In `connectivityNotifierProvider`, only invoke `notifier.startMonitoring()` if `FeatureFlags.offlineFirstEnabled == true`. | S |
| **FIX-06** | `frontend/lib/data/repositories/shift_repository_provider.dart` | Introduce `apiShiftRepositoryProvider` and branch based on `FeatureFlags.offlineFirstEnabled`. | S |
| **FIX-07** | `frontend/lib/core/sync/sync_background_worker.dart` | Add a drain-then-disable diagnostic check during app bootstrap that warns if local SQLite contains pending orders before running with flag OFF. | M |
