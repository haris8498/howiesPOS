# 06 - Flutter Lifecycle & Client-Side Architecture Audit

> **Audit Role:** Flutter Lifecycle Auditor (`.agents/flutter-lifecycle-auditor/agent.md`)  
> **Target System:** Hungry Howie's POS (Flutter Windows Desktop + Drift / SQLite + Riverpod)  
> **Reference Specification:** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`  
> **Architecture Map:** `docs/sync-audit/00-architecture-map.md`  
> **Status:** Completed Authoritative Audit Baseline  
> **Date:** October 26, 2026  

---

## Executive Summary

This audit assesses the client-side lifecycle, Drift SQLite integrity, Riverpod state management, and UI truthfulness of the Hungry Howie's POS Flutter application. Every finding in this document has been verified against the production Flutter source code and is supported by exact `file:line` citations.

The offline-first client architecture uses Drift (SQLite with SQLCipher AES-256 via Windows user-scope DPAPI) and an outbox queue managed by `SyncBackgroundWorker`. However, severe lifecycle and architectural defects undermine system integrity:

1. **Authentication Pause Deadlock (`FLT-01`):** Logging out or experiencing token expiration transitions the outbox queue into `AUTH_PAUSED`. The periodic polling timer explicitly skips both push and pull when `isAuthPaused == true`. When a cashier subsequently logs in with valid credentials, `auth_repository.dart` never informs `SyncBackgroundWorker` or calls `resumeAuthPaused()`, permanently stalling offline synchronization until an application restart or manual force sync.
2. **Dual-Write Anti-Pattern & Bypassed Outbox (`FLT-02`, `FLT-03`):** Takeaway, Delivery, and Dine-In screens attempt direct HTTP REST calls in parallel with or prior to local Drift outbox queueing. In Takeaway and Delivery, direct HTTP success triggers manual deletion of the outbox entry while the background worker is actively processing it, causing race conditions and duplicate backend orders.
3. **Stale UI via In-Memory Notifier Caches (`FLT-04`):** Feature notifiers (`TakeawayNotifier`, `DeliveryNotifier`, `TableNotifier`) maintain state in detached in-memory Dart lists loaded via one-shot `.get()` queries. Because `SyncBackgroundWorker` lacks Riverpod `Ref` access and notifiers do not subscribe to Drift reactive streams, remote updates pulled from the cloud or local outbox completions never refresh the UI.
4. **Hardcoded Silent Re-Authentication Backdoor (`FLT-05`):** When the JWT token expires, `SyncBackgroundWorker.trySilentReauth()` attempts to re-authenticate by guessing staff passwords using the hardcoded formula `'${username}123'` or `'Noman123'`. Any staff member with a non-default password causes silent re-auth to fail, causing an unrecoverable `AUTH_PAUSED` stall.
5. **Main-Thread UI Jank & Unindexed Full Table Scans (`FLT-06`, `FLT-07`, `FLT-08`):** SQLite connections run synchronously on the main UI isolate (`inBackground = false`). Drift tables lack indexes on foreign keys (`orderId`, `menuItemId`, `categoryId`) and query columns (`status`, `nextRetryAt`, `dependencyOrder`), causing $O(N \times M)$ full table scans during shift summary calculations and screen loads.

---

## Checklist Audit Findings

```
====================================================================================================
FINDINGS MATRIX: FLUTTER LIFECYCLE & INTEGRITY
====================================================================================================
ID      SEVERITY  TITLE                                                                 STATUS
----------------------------------------------------------------------------------------------------
FLT-01  Critical  Auth Pause Deadlock Halts Outbox Sync After User Re-Login             CONFIRMED
FLT-02  High      Dual-Write Race & Outbox Deletion in Takeaway and Delivery Flows      CONFIRMED
FLT-03  High      Dine-In Tables Screen Dual-Write Calls REST Prior to Local Outbox     CONFIRMED
FLT-04  High      Stale UI: Feature Notifiers Lack Reactive Drift Stream Subscriptions  CONFIRMED
FLT-05  High      Hardcoded Password Formula in Silent Re-Auth Causes Worker Stall      CONFIRMED
FLT-06  High      Main-Thread UI Blocking from Synchronous SQLite and Bulk Hydration    CONFIRMED
FLT-07  Medium    Unindexed Foreign Keys and Outbox Columns Force Full Table Scans      CONFIRMED
FLT-08  High      Unbounded In-Memory Load of All Database Payments in Shift Summary    CONFIRMED
FLT-09  Medium    Re-Entrant Cold Bootstrap Causes Duplicate Snapshot Ingestion         CONFIRMED
FLT-10  High      Device Midnight Rollover Resets Receipt Numbering Mid-Shift           CONFIRMED
FLT-11  Medium    Unhandled Startup Exception Permanently Aborts Polling Timer          CONFIRMED
FLT-12  Low       Sync Health Provider Stuck-Item Check Fails to Recompute Timely       CONFIRMED
FLT-13  Low       Lack of Windows Background Daemon Limits Sync to Foreground Window    CONFIRMED
FLT-14  Low       Failed Hardware Print Spooler Jobs Lack Automated Background Retry    CONFIRMED
FLT-15  Medium    Empty Migration Scaffold Threatens DB Integrity on Version Bump       CONFIRMED
====================================================================================================
```

---

### FLT-01: Auth Pause Deadlock Halts Outbox Sync After User Re-Login
- Severity: Critical
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:352-356`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L352-L356), [`frontend/lib/core/sync/sync_background_worker.dart:760-769`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L760-L769), [`frontend/lib/data/auth_repository.dart:420-435`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L420-L435), [`frontend/lib/data/auth_repository.dart:533-546`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L533-L546)
- Failure sequence:
  1. Cashier session token expires, or a user logs out via `authRepository.logout()`.
  2. The background worker attempts an outbox push or periodic pull. Without a valid token or upon receiving HTTP 401, `trySilentReauth()` fails.
  3. `_handleAuthPaused()` marks the batch as `status = 'AUTH_PAUSED'` and sets `stateNotifier.updateState(state.copyWith(isAuthPaused: true))`.
  4. In `_onPeriodicTick()` ([`line 353`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L353)), the periodic timer checks `if (!state.isAuthPaused && !state.isCircuitBreakerTripped)`. Because `isAuthPaused == true`, periodic push and pull are completely skipped.
  5. The outbox stream listener ([`line 216`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L216)) also checks `!state.isAuthPaused`, ignoring any new local orders saved to Drift.
  6. Cashier logs in with valid credentials via `authRepository.login()` ([`auth_repository.dart:420`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/auth_repository.dart#L420)).
  7. Neither `login()` nor `_loginFallback()` informs `SyncBackgroundWorker` or calls `resumeAuthPaused()`.
  8. The sync worker remains permanently frozen in `AUTH_PAUSED` state. Unsynced orders accumulate in SQLite indefinitely until the entire app is terminated and restarted.
- Impact: Complete halt of offline synchronization; revenue, orders, and shifts remain trapped on the terminal.
- Recommended fix: In `auth_repository.dart`, inject or call `ref.read(syncBackgroundWorkerProvider).resumeAuthPaused()` immediately upon successful login. In `sync_providers.dart`, have `syncBackgroundWorkerProvider` listen to `authProvider` state transitions.
- Effort: S
- Status: CONFIRMED

---

### FLT-02: Dual-Write Race & Outbox Deletion in Takeaway and Delivery Flows
- Severity: High
- Evidence: [`frontend/lib/data/takeaway_repository.dart:363-388`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L363-L388), [`frontend/lib/data/delivery_repository.dart:363-392`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L363-L392)
- Failure sequence:
  1. Cashier creates a takeaway or delivery order while the POS terminal is online.
  2. Order is saved to local Drift tables, which enqueues a mutation into `sync_outbox`.
  3. Drift reactive watcher immediately notifies `SyncBackgroundWorker`, which invokes `getPushBatch()` and marks the outbox entry `IN_FLIGHT`.
  4. Concurrently, `takeaway_repository.dart:365` executes direct HTTP `_ordersApiService.createOrder(...)`.
  5. Both HTTP requests hit the NestJS backend nearly simultaneously.
  6. The direct HTTP call finishes first and executes `delete(db.syncOutbox)..where((t) => t.entityId.equals(orderId))`.
  7. The background worker's HTTP call finishes and attempts `markSynced()` on a row that was just deleted, or the backend returns an error/duplicate.
- Impact: Duplicate backend orders, race conditions mutating the outbox while in flight, erratic sync status.
- Recommended fix: Enforce Developer Directive Q1.1: remove direct REST calls in `takeaway_repository.dart` and `delivery_repository.dart` when `offlineFirstEnabled` is true; route all order mutations exclusively through Drift and `SyncBackgroundWorker`.
- Effort: M
- Status: CONFIRMED

---

### FLT-03: Dine-In Tables Screen Dual-Write Calls REST Prior to Local Outbox
- Severity: High
- Evidence: [`frontend/lib/features/tables/tables_screen.dart:3895-3945`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/features/tables/tables_screen.dart#L3895-L3945)
- Failure sequence:
  1. Cashier adds order items to a dine-in table in `TablesScreen` while online.
  2. Line 3900 directly executes HTTP REST `ordersApi.createOrder(orderDto)`.
  3. Server creates the order and returns the server order ID and order number.
  4. Immediately afterwards (line 3910), `TablesScreen` checks `if (FeatureFlags.offlineFirstEnabled)` and executes `orderRepo.saveOrder(finalOrder)`.
  5. `orderRepo.saveOrder()` saves the order to Drift SQLite and enqueues a `SyncOutbox` row with `dependency_order = 2`.
  6. `SyncBackgroundWorker` pushes the mutation to `POST /api/sync/push`.
  7. Backend `order.handler.ts` attempts to insert the order that was ALREADY created in step 2, generating a duplicate warning, conflict, or OCC version collision.
- Impact: Dual write anti-pattern; duplicate database load; table orders duplicated or trapped in conflict quarantine.
- Recommended fix: In `tables_screen.dart`, route dine-in order submission strictly through `orderRepositoryProvider.saveOrder()` without preceding REST calls when `offlineFirstEnabled` is true.
- Effort: M
- Status: CONFIRMED

---

### FLT-04: Stale UI: Feature Notifiers Lack Reactive Drift Stream Subscriptions
- Severity: High
- Evidence: [`frontend/lib/data/takeaway_repository.dart:60-74`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/takeaway_repository.dart#L60-L74), [`frontend/lib/data/delivery_repository.dart:61-75`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/delivery_repository.dart#L61-L75), [`frontend/lib/data/table_repository.dart:61-125`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/table_repository.dart#L61-L125), [`frontend/lib/core/sync/sync_background_worker.dart:140-155`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L140-L155)
- Failure sequence:
  1. Background worker pulls changes via delta pull (`GET /api/sync/pull`) or updates `LocalOrders` after an outbox push completes.
  2. Drift SQLite tables (`local_orders`, `local_restaurant_tables`, `catalog_tables`) are updated on disk.
  3. `SyncBackgroundWorker` does not hold a Riverpod `Ref` and cannot invalidate presentation providers.
  4. `TakeawayNotifier`, `DeliveryNotifier`, and `TableNotifier` hold UI state in private in-memory Dart lists loaded once at construction via `.get()`.
  5. None of these notifiers subscribe to Drift reactive `watch()` queries.
  6. UI continues displaying stale orders and obsolete table occupancy statuses until the cashier manually closes and reopens the screen.
- Impact: Stale UI; cashiers unaware of order updates, cancellations, or seating changes made on other terminals.
- Recommended fix: Connect feature notifiers directly to Drift reactive watch streams (e.g., `watchAllOrders()`, `catalogDao.watchTables()`) or trigger state invalidation upon pull ingestion.
- Effort: L
- Status: CONFIRMED

---

### FLT-05: Hardcoded Password Formula in Silent Re-Auth Causes Worker Stall
- Severity: High
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:1342-1373`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L1342-L1373)
- Failure sequence:
  1. The POS authentication token expires while the background worker is operating.
  2. The worker receives an HTTP 401 response and invokes `trySilentReauth()`.
  3. Line 1355 derives the password using a hardcoded string template:
     `final password = username.toLowerCase() == 'noman' ? 'Noman123' : '${username}123';`
  4. If the active staff user has customized their password (e.g. via Password Management Screen), the guessed password fails backend validation.
  5. The exception is swallowed (line 1371), and `trySilentReauth()` returns `null`.
  6. The outbox enters `AUTH_PAUSED` state; background sync halts permanently.
- Impact: Silent sync stoppage whenever standard password security policies are followed; credentials guessability exposure.
- Recommended fix: Store a secure DPAPI-encrypted refresh token or session key in `TokenStorage` rather than hardcoding password derivation patterns.
- Effort: M
- Status: CONFIRMED

---

### FLT-06: Main-Thread UI Blocking from Synchronous SQLite and Bulk Hydration
- Severity: High
- Evidence: [`frontend/lib/core/database/encrypted_connection.dart:70-81, 93`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/encrypted_connection.dart#L70-L81), [`frontend/lib/core/sync/sync_background_worker.dart:921-1120`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L921-L1120)
- Failure sequence:
  1. App initializes or downloads a cold-start bootstrap snapshot (`/api/sync/bootstrap`) containing hundreds of menu items, sizes, options, deals, and tables.
  2. `openEncryptedConnection()` sets `bool inBackground = false` by default, instantiating `NativeDatabase(file)` rather than `NativeDatabase.createInBackground(file)`.
  3. `_applyBootstrapData` executes hundreds of inserts and SQLCipher AES-256 cryptographic computations synchronously on the Flutter main UI isolate.
  4. The main thread event loop is blocked for up to several seconds.
  5. Touch interactions drop frames, POS buttons freeze, and cashiers experience noticeable application stutter.
- Impact: UI jank and unresponsiveness during checkout or high-volume sync activity.
- Recommended fix: Set `inBackground: true` in `openEncryptedConnection()` or utilize Drift isolate channels to offload all database queries and encryption to a background worker isolate.
- Effort: M
- Status: CONFIRMED

---

### FLT-07: Unindexed Foreign Keys and Outbox Columns Force Full Table Scans
- Severity: Medium
- Evidence: [`frontend/lib/core/database/tables/local_orders_tables.dart:39, 62`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/local_orders_tables.dart#L39), [`frontend/lib/core/database/tables/sync_outbox_table.dart:24, 31, 33`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/sync_outbox_table.dart#L24), [`frontend/lib/core/database/tables/catalog_tables.dart:20, 34, 46, 69`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/catalog_tables.dart#L20)
- Failure sequence:
  1. Store operates over weeks; `local_orders`, `local_order_items`, and `sync_outbox` accumulate thousands of rows within the 30-day retention window.
  2. Drift does not automatically create indexes on foreign keys declared with `.references()`.
  3. `LocalOrderItems.orderId` and `LocalOrderPayments.orderId` have no indexes; querying items for an order (`ordersDao.getOrderItems(orderId)`) performs a full table scan.
  4. `TakeawayNotifier.loadTakeawayOrders()` runs `ordersDao.getOrderItems(lo.id)` inside a loop over all orders, causing $N$ consecutive full table scans on the main UI isolate.
  5. `SyncOutbox` lacks indexes on `(status, nextRetryAt, dependencyOrder, createdAt)`, forcing a full table scan and sort on every `getPushBatch()` poll.
- Impact: Progressive performance degradation, battery consumption, and UI jank as local database grows.
- Recommended fix: Add `@TableIndex` declarations in Drift table classes for foreign keys and filtering columns (`orderId`, `menuItemId`, `categoryId`, `status`, `dependencyOrder`, `entityId`).
- Effort: S
- Status: CONFIRMED

---

### FLT-08: Unbounded In-Memory Load of All Database Payments in Shift Summary
- Severity: High
- Evidence: [`frontend/lib/data/daily_calculation_repository.dart:495-496`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/daily_calculation_repository.dart#L495-L496)
- Failure sequence:
  1. Terminal is offline; cashier navigates to the Daily Calculation / Shift screen.
  2. `fetchLiveSummary()` catches the network exception and executes the local offline summary calculation (line 466).
  3. Line 495 executes: `final allPayments = await db.select(db.localOrderPayments).get();`.
  4. The code retrieves every single payment record in the entire database into memory, across all historical 30-day shifts.
  5. Line 496 performs in-memory filtering: `allPayments.where((p) => validOrderIds.contains(p.orderId)).toList()`.
  6. On a terminal with 5,000+ payment rows, this allocates thousands of ephemeral Dart objects, causing garbage collection spikes and risking Out-Of-Memory crashes on low-spec hardware.
- Impact: Memory bloat, GC UI stutter, potential out-of-memory crash.
- Recommended fix: Query payments using SQL `WHERE order_id IN (...)` or a SQL `JOIN` with `LocalOrders` inside `DailyCalculationsDao`.
- Effort: S
- Status: CONFIRMED

---

### FLT-09: Re-Entrant Cold Bootstrap Causes Duplicate Snapshot Ingestion
- Severity: Medium
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:240-244`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L240-L244), [`frontend/lib/core/sync/sync_background_worker.dart:815-819`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L815-L819), [`frontend/lib/core/sync/sync_background_worker.dart:882-920`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L882-L920)
- Failure sequence:
  1. Terminal launches with an unhydrated database (`GLOBAL_PULL_CURSOR == 0`) while online.
  2. `start()` initiates `await bootstrapInitialData()` (line 243).
  3. Before bootstrap completes and writes the cursor to disk, a connectivity change or incoming WebSocket poke triggers `triggerPull()`.
  4. Line 815 checks `getLastPulledSequence('GLOBAL_PULL_CURSOR')`, which is still 0.
  5. `triggerPull()` invokes `bootstrapInitialData()` a second time concurrently.
  6. Two simultaneous bootstrap routines download the snapshot and execute overlapping bulk database writes. If snapshot entities lack explicit IDs, new UUIDs are generated, creating duplicate rows in `LocalRolePermissions` and `LocalStaffUsers`.
- Impact: Duplicate catalog records, database lock contention, wasted bandwidth.
- Recommended fix: Guard `bootstrapInitialData()` with a single-flight boolean flag `_isBootstrapping`.
- Effort: S
- Status: CONFIRMED

---

### FLT-10: Device Midnight Rollover Resets Receipt Numbering Mid-Shift
- Severity: High
- Evidence: [`frontend/lib/data/repositories/drift_offline_first_order_repository.dart:71-73`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L71-L73), [`frontend/lib/core/database/tables/terminal_sequences_table.dart:6-12`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/tables/terminal_sequences_table.dart#L6-L12)
- Failure sequence:
  1. Store runs a night shift spanning across midnight (e.g. 6:00 PM to 2:00 AM).
  2. Orders placed before midnight receive sequence numbers `P1-101`, `P1-102`, etc., keyed to `businessDate = '2026-10-25'`.
  3. At 00:00:01, device local time crosses to `2026-10-26`.
  4. Line 71 formats `todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now())`.
  5. `TerminalSequencesDao.getNextSequence('2026-10-26')` initializes a new sequence row and resets the sequence back to `101` (`P1-101`).
  6. Orders placed after midnight duplicate the receipt numbers printed earlier that same evening on the same shift.
- Impact: Receipt and KOT number collisions within the same operational work shift; staff and customer confusion.
- Recommended fix: Key terminal sequence numbers to the active shift start date (`activeShift.createdAt`) rather than `DateTime.now()`.
- Effort: S
- Status: CONFIRMED

---

### FLT-11: Unhandled Startup Exception Permanently Aborts Polling Timer
- Severity: Medium
- Evidence: [`frontend/lib/core/sync/sync_background_worker.dart:240-256`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L240-L256)
- Failure sequence:
  1. Cashier opens the POS; `main.dart` calls `syncBackgroundWorker.start()`.
  2. Line 207 sets `_isRunning = true`.
  3. Line 243 calls `await bootstrapInitialData()` without a surrounding `try/catch` block.
  4. If the network drops or JSON parsing throws an unhandled error, `start()` aborts execution.
  5. Lines 248-252 (`_periodicTimer = Timer.periodic(...)`) are never executed.
  6. The worker is left in an inconsistent state: `_isRunning == true`, but no polling timer exists. Automatic background sync never runs.
- Impact: Background sync silently dies on startup; outbox mutations remain pending.
- Recommended fix: Enclose startup bootstrap and recovery steps in isolated `try/catch` blocks so that timer instantiation is guaranteed.
- Effort: S
- Status: CONFIRMED

---

### FLT-12: Sync Health Provider Stuck-Item Check Fails to Recompute Timely
- Severity: Low
- Evidence: [`frontend/lib/core/sync/sync_health_provider.dart:77-80, 150-173`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_health_provider.dart#L77-L80)
- Failure sequence:
  1. A mutation enters `status = IN_FLIGHT` and is hung up on an unacknowledged HTTP connection.
  2. `rawSyncHealthProvider` evaluates at insertion ($t=0$); `now.difference(sentAt).inMinutes` is 0 (< 2 minutes), so health remains green.
  3. `rawSyncHealthProvider` is a standard `Provider`, not a timer. It only recomputes when watched providers emit.
  4. If no new orders are entered and connectivity does not change, `rawSyncHealthProvider` does not re-evaluate.
  5. Minutes pass; the outbox item remains stuck in-flight, but the UI indicator remains solid green until an unrelated database event triggers a re-evaluation.
- Impact: UI sync indicator shows green ("Healthy") while the sync queue is actually frozen.
- Recommended fix: Add a periodic 30-second timer inside `rawSyncHealthProvider` to periodically re-evaluate the 2-minute stuck-item condition.
- Effort: S
- Status: CONFIRMED

---

### FLT-13: Lack of Windows Background Daemon Limits Sync to Foreground Window
- Severity: Low
- Evidence: [`frontend/pubspec.yaml:30-59`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/pubspec.yaml#L30-L59), [`frontend/lib/core/sync/sync_background_worker.dart:248-252`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/sync/sync_background_worker.dart#L248-L252)
- Failure sequence:
  1. Cashier enters offline orders and closes the POS application window at end of day.
  2. Internet connectivity is restored later that night while the PC remains on.
  3. Because sync relies strictly on an in-app `Timer.periodic` without a Windows Background Service, Task Scheduler job, or system tray daemon, no sync occurs.
  4. Orders remain un-synced until staff relaunches the application window the following morning.
- Impact: Cloud sales reports delayed until the POS application is manually opened.
- Recommended fix: Advise operators to keep the POS window open until the sync indicator turns green, or package a lightweight Windows background synchronization service.
- Effort: M
- Status: CONFIRMED

---

### FLT-14: Failed Hardware Print Spooler Jobs Lack Automated Background Retry
- Severity: Low
- Evidence: [`frontend/lib/services/receipt_printer_service.dart:1872-1925, 2068-2085`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/services/receipt_printer_service.dart#L1872-L1925), [`frontend/lib/core/database/daos/print_jobs_dao.dart:1-85`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/daos/print_jobs_dao.dart#L1-L85)
- Failure sequence:
  1. An order is completed while the thermal printer is powered off or out of paper.
  2. `ReceiptPrinterService` catches the error and records the job in `offline_print_jobs` with `status = 'FAILED'`.
  3. A temporary SnackBar is displayed with a manual "Retry" button.
  4. If the cashier dismisses or misses the SnackBar, the print job remains in `offline_print_jobs` indefinitely.
  5. No background worker polls `offline_print_jobs` to automatically retry printing once the printer is restored.
- Impact: Unprinted receipts and kitchen tickets remain abandoned in the spooler table.
- Recommended fix: Introduce a periodic print spooler daemon in `ReceiptPrinterService` that checks printer readiness and automatically re-spools failed print jobs.
- Effort: M
- Status: CONFIRMED

---

### FLT-15: Empty Migration Scaffold Threatens DB Integrity on Version Bump
- Severity: Medium
- Evidence: [`frontend/lib/core/database/app_database.dart:69-78`](file:///D:/HOWIES%20TEST/howiesPOS/frontend/lib/core/database/app_database.dart#L69-L78)
- Failure sequence:
  1. A future app release updates Drift table schemas and increments `schemaVersion` from 1 to 2.
  2. `AppDatabase.migration.onUpgrade` is currently an empty no-op scaffold (`// Schema Version 1 Baseline`).
  3. When an updated client starts on a database containing pending outbox mutations, Drift performs no migration steps.
  4. Queries expecting new columns fail with `SqliteException: no such column`, crashing the app at launch and stranding unsynced outbox data.
- Impact: Application crash upon upgrade; inaccessible offline outbox mutations.
- Recommended fix: Implement explicit Drift step-by-step migration testing and add a pre-migration verification ensuring `sync_outbox` is empty or safely backed up before altering schemas.
- Effort: M
- Status: CONFIRMED

---

## Provider Map: Riverpod Data Sources & Screens

The following map catalogs all major Riverpod providers, their underlying data source (Online REST vs. Offline Drift), and the screens actively consuming them:

| Provider Name | Declared Type | Data Source (Online vs Offline) | Consuming Screens & Features | Data Source Verdict |
|---|---|---|---|---|
| `orderRepositoryProvider` | `Provider<IOrderRepository>` | **Dynamic Flag Seam:** `DriftOfflineFirstOrderRepository` (Offline Drift) when flag is ON; `ApiOrderRepository` (REST) when flag is OFF. | `pos_screen.dart`, `takeaway_screen.dart`, `delivery_screen.dart`, `tables_screen.dart` | **True Offline-First** |
| `tableProvider` | `StateNotifierProvider<TableNotifier, TableState>` | **Dual-Source Hybrid:** Calls REST `_tablesApiService.listTables()` when online; falls back to Drift `catalogDao.getAllTables()` when offline. Writes attempt REST first. | `tables_screen.dart`, `pos_screen.dart` | **Mixed / Dual-Write Anti-Pattern** |
| `takeawayProvider` | `StateNotifierProvider<TakeawayNotifier, TakeawayState>` | **Dual-Source Hybrid:** Initial state from Drift SQLite. Mutations save to Drift outbox, then execute direct REST `createOrder`, deleting outbox on success. | `takeaway_screen.dart` | **Mixed / Dual-Write Anti-Pattern** |
| `deliveryProvider` | `StateNotifierProvider<DeliveryNotifier, DeliveryState>` | **Dual-Source Hybrid:** Initial state from Drift SQLite. Mutations save to Drift outbox, then execute direct REST `createOrder`, deleting outbox on success. | `delivery_screen.dart` | **Mixed / Dual-Write Anti-Pattern** |
| `dailyCalculationProvider` | `StateNotifierProvider<DailyCalculationNotifier, DailyCalculationState>` | **Dual-Source Hybrid:** Shift open writes to Drift outbox. Shift summary attempts REST first, falls back to Drift. Shift close calls REST first, then enqueues to outbox. | `daily_calculation_screen.dart`, `daily_calculation_admin_screen.dart`, `starting_cash_dialog.dart` | **Mixed / Dual-Write Anti-Pattern** |
| `shiftRepositoryProvider` | `Provider<IShiftRepository>` | **Strictly Offline Drift:** Always returns `DriftOfflineFirstShiftRepository` backed by `local_daily_calculations` and `sync_outbox`. | `daily_calculation_repository.dart`, `cashier_sync_center_provider.dart` | **True Offline-First** |
| `syncBackgroundWorkerProvider` | `Provider<SyncBackgroundWorker>` | **Offline/Online Bridge:** Master sync engine managing outbox drain (`/api/sync/push`) and delta pull (`/api/sync/pull`). | `main.dart`, `data_sync_screen.dart`, `sync_center_screen.dart`, `sync_status_indicator_widget.dart` | **Sync Engine** |
| `connectivityNotifierProvider` | `StateNotifierProvider<ConnectivityNotifier, ConnectivityState>` | **Online HTTP Probe:** End-to-end probing of `GET /api/health` every 15 seconds. | `SyncBackgroundWorker`, `SyncStatusIndicatorWidget`, `cashier_top_navigation_bar.dart` | **Network Monitor** |
| `syncHealthProvider` | `StreamProvider<SyncHealthState>` | **Local Drift Stream:** Watches Drift active outbox mutations and combines with connectivity state; debounced at 800ms. | `sync_status_indicator_widget.dart`, `cashier_top_navigation_bar.dart` | **True Offline-First Indicator** |
| `reportSummaryProvider` | `FutureProvider<DailyLiveSummaryModel>` | **Dual-Source Hybrid:** Fetches cloud REST reports; if `offlineFirstEnabled`, merges pending un-synced orders from SQLite. | `reports_screen.dart` | **Dual-Source Hybrid** |
| `reportProductsProvider` | `FutureProvider<List<Map<String, dynamic>>>` | **Dual-Source Hybrid:** Fetches cloud product sales; merges offline orders and items from Drift SQLite. | `reports_screen.dart` | **Dual-Source Hybrid** |
| `posProvider` | `StateNotifierProvider<PosNotifier, PosState>` | **In-Memory & Domain:** Manages cart and active deal selection; order completion delegates to `CompleteOrderUseCase`. | `pos_screen.dart` | **True Offline-First Checkout** |
| `menuNotifierProvider` | `StateNotifierProvider<MenuNotifier, MenuState>` | **Online REST with Fallback:** Loads catalog from REST `/api/menu`; populated locally via bootstrap sync. | `pos_screen.dart`, `menu_screen.dart` | **Online-First / Pull Cache** |
| `kitchenProvider` | `StateNotifierProvider<KitchenNotifier, KitchenState>` | **Online Only:** Reads from REST `/api/kitchen/orders` and listens to Socket.IO. No Drift tables exist. | `kitchen_screen.dart` | **Online Only (Fails Offline)** |
| `inventoryProvider` | `StateNotifierProvider<InventoryNotifier, InventoryState>` | **Online Only:** Communicates exclusively with REST `/api/inventory`. No Drift tables exist. | `inventory_screen.dart`, `stock_screen.dart`, `stock_in_out_screen.dart` | **Online Only (Fails Offline)** |
| `authProvider` | `StateNotifierProvider<AuthNotifier, AuthState>` | **Hybrid:** Online REST auth with local PBKDF2/SHA-256 fallback in `InMemoryAuthRepository`. Session encrypted via Windows DPAPI. | `login_screen.dart`, `cashier_sidebar_footer.dart`, `navigation_sidebar.dart` | **Hybrid Auth** |
| `cashierSyncCenterProvider` | `StateNotifierProvider<CashierSyncCenterNotifier, CashierSyncCenterState>` | **Dual-Source Hybrid:** Merges Drift SQLite shifts/orders with cloud overview; provides manual retry trigger. | `cashier_sync_center_screen.dart`, `data_sync_screen.dart` | **Dual-Source Hybrid** |

---

## Lifecycle Events & Worker Action Matrix

The table below traces system lifecycle triggers and the concrete actions executed by `SyncBackgroundWorker`:

| Lifecycle Event | Event Source / Listener | Sync Background Worker Action | Failure Modes & Risks |
|---|---|---|---|
| **Cold Start** | `main.dart:43-45` via `ref.read(syncBackgroundWorkerProvider).start()` | 1. Sets `_isRunning = true`.<br>2. Reaps orphaned `IN_FLIGHT` tasks older than 60s back to `PENDING`.<br>3. Listens to `db.outboxDao.watchPendingCount()`.<br>4. Registers listener on `ConnectivityNotifier`.<br>5. Registers wildcard Socket.IO listener `socketService.on('*')`.<br>6. Checks `GLOBAL_PULL_CURSOR`; if 0 and online, runs `bootstrapInitialData()`.<br>7. Starts 30s `Timer.periodic`.<br>8. Runs 30-day retention pruning job. | If `bootstrapInitialData()` throws an unhandled network error, startup sequence aborts at line 243; periodic polling timer is never started (`FLT-11`). Re-entrant calls can cause duplicate snapshot hydration (`FLT-09`). |
| **Connectivity Restored** | `ConnectivityNotifier.addListener` transitions `isOnline` to `true` | Invokes `reconnect()`:<br>1. Resets `consecutiveTimeouts = 0` and `isCircuitBreakerTripped = false`.<br>2. Invokes `triggerPush()` to drain outbox mutations (Level 0 -> 5).<br>3. Invokes `triggerPull()` to fetch deltas from `GLOBAL_PULL_CURSOR`. | Push-then-pull ordering guarantees client mutations are committed on backend before pulling remote deltas. If worker is in `AUTH_PAUSED`, reconnect is ignored. |
| **Connectivity Lost** | `ConnectivityNotifier` detects `/api/health` timeout (5s) | Outbox push fails network transmission:<br>1. Catches network failure; increments `consecutiveTimeouts`.<br>2. Batch marked `FAILED_RETRYABLE` with exponential jitter backoff.<br>3. If `consecutiveTimeouts >= 5`, trips circuit breaker (30s pause).<br>4. UI status indicator immediately transitions to RED. | Durable in SQLite. No data is lost; orders remain safely queued. |
| **Local Outbox Write** | Drift stream `db.outboxDao.watchPendingCount()` fires | If `count > 0` and terminal is online and unpaused, immediately triggers `triggerPush()`. | Bypassed when `isAuthPaused` or circuit breaker is tripped. Can race with feature repository direct REST calls (`FLT-02`). |
| **Periodic Timer Tick** | `_periodicTimer` fires every 30 seconds | If unpaused and circuit breaker is untripped, executes `triggerPush()` then `triggerPull()`. Checks if 24 hours elapsed since last 30-day retention prune. | Timer suspended if Windows machine enters Modern Standby or sleep mode. |
| **Realtime Socket Poke** | Socket.IO wildcard event `*` received | Immediately triggers `triggerPull()` to fetch latest remote changes. | Notification-only principle strictly observed; no entity payloads ingested via WebSocket. Fails silently if offline. |
| **User Logout** | `authProvider.notifier.logout()` | Session token removed from `TokenStorage`. Realtime socket disconnected. Worker is **NOT** notified. | Worker continues running periodic timer. Outbox push gets HTTP 401, attempts silent re-auth with hardcoded password, fails, and enters `AUTH_PAUSED` deadlock (`FLT-01`, `FLT-05`). |
| **User Login** | `authProvider.notifier.login()` | New JWT saved to `TokenStorage`. Socket reconnects. Worker is **NOT** notified. | If outbox was previously in `AUTH_PAUSED`, login does not call `resumeAuthPaused()`. Outbox remains frozen indefinitely (`FLT-01`). |
| **Hot Restart / Rebuild** | Flutter Hot Restart / Riverpod provider disposal | `ref.onDispose` calls `worker.dispose()`: cancels timers, subscriptions, socket listeners, sets `_isDisposed = true`. New worker instantiated. | If an in-flight push request was pending during disposal, the new worker re-picks up mutations after 60s zombie timeout. Safe due to server idempotency. |
