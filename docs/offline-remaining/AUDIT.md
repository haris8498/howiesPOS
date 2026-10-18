# Offline-First Pipeline Audit Report (Wave 1: sync-audit)

> **Document Reference:** `docs/offline-remaining/AUDIT.md`  
> **Agent:** `sync-audit` (Wave 1)  
> **Status:** Completed  
> **Date:** October 18, 2026  

---

## 1. Direct HTTP/API Calls Map (Bypassing Offline Repository)

| File : Line | API Instance / Method | HTTP Verb & Endpoint | Type (READ/WRITE) | Triggering Flow / Screen | Offline Remediation Needed |
|---|---|---|---|---|---|
| `frontend/lib/features/tables/tables_screen.dart:3737` | `ordersApi.createOrder(orderDto)` | `POST /api/orders` | **WRITE** | Tables Screen: Creating a new dine-in order | Route through `orderRepositoryProvider` (Drift atomic transaction) |
| `frontend/lib/features/tables/tables_screen.dart:3711` | `ordersApi.updateOrder(orderId, dto)` | `PATCH /api/orders/:id` | **WRITE** | Tables Screen: Adding items to active dine-in table | Route through `orderRepositoryProvider.updateOrder` |
| `frontend/lib/features/tables/tables_screen.dart:5039` | `ordersApi.updateOrder(orderId, dto)` | `PATCH /api/orders/:id` | **WRITE** | Tables Screen: Completing table payment | Route through `orderRepositoryProvider.updateOrder` |
| `frontend/lib/features/tables/tables_screen.dart:5650` | `ordersApi.updateOrder(orderId, dto)` | `PATCH /api/orders/:id` | **WRITE** | Tables Screen: Split bill completion | Route through `orderRepositoryProvider.updateOrder` |
| `frontend/lib/features/tables/tables_screen.dart:2067` | `ordersApi.updateOrder(orderId, dto)` | `PATCH /api/orders/:id` | **WRITE** | Tables Screen: Cancelling table order | Route through `orderRepositoryProvider.cancelOrder` |
| `frontend/lib/features/tables/tables_screen.dart:6318` | `ordersApi.cancelOrderItem(orderId, itemId)` | `DELETE /api/orders/:id/items/:itemId` | **WRITE** | Tables Screen: Voiding single order item | Enqueue outbox op or update order |
| `frontend/lib/features/tables/tables_screen.dart:3119` | `ordersApi.getOrderById(orderId)` | `GET /api/orders/:id` | **READ** | Tables Screen: Viewing active table bill | Query `orderRepositoryProvider.getOrderById` (local Drift) |
| `frontend/lib/features/tables/tables_screen.dart:3004-3006` | `menuApi.listCategories/Items/Deals()` | `GET /api/menu/...` | **READ** | Tables Screen: Menu dialog for table ordering | Fall back to `CatalogDao` local tables if offline |
| `frontend/lib/data/table_repository.dart:56` | `tablesApi.listTables()` | `GET /api/tables` | **READ** | TableNotifier: Initial & refreshed tables load | Fall back to `CatalogDao.getAllTables()` if offline |
| `frontend/lib/data/table_repository.dart:62` | `tablesApi.listZones()` | `GET /api/tables/zones` | **READ** | TableNotifier: Floor zones list | Fall back to `CatalogDao.getAllFloorZones()` |
| `frontend/lib/data/table_repository.dart:85, 114` | `tablesApi.updateTableStatus(...)` | `PATCH /api/tables/:id/status` | **WRITE** | TableNotifier: Occupied/Available status transition | Update Drift `LocalRestaurantTables` + enqueue outbox `table_status` |
| `frontend/lib/data/table_repository.dart:161` | `tablesApi.releaseTable(id)` | `POST /api/tables/:id/release` | **WRITE** | TableNotifier: Free table | Update Drift `LocalRestaurantTables` + enqueue outbox `table_status` |
| `frontend/lib/data/table_repository.dart:182` | `tablesApi.transferTable(...)` | `POST /api/tables/transfer` | **WRITE** | TableNotifier: Table transfer | Update local tables + enqueue outbox |
| `frontend/lib/data/sync_repository.dart:60, 114` | `_syncApiService.getSyncOverview(...)` | `GET /api/sync/overview` | **READ** | DataSyncScreen: Sync metrics & orders table | Query local Drift `SyncOutbox` + `LocalOrders` |
| `frontend/lib/data/sync_repository.dart:96, 121` | `_syncApiService.syncSingle/BatchOrders(...)` | `POST /api/sync/...` | **WRITE** | DataSyncScreen: Trigger manual re-sync | Trigger `SyncBackgroundWorker.triggerPushNow()` |
| `frontend/lib/data/takeaway_repository.dart:56` | `ordersApi.listOrders(orderType: takeaway)` | `GET /api/orders?type=takeaway` | **READ** | TakeawayScreen: List orders | Stream from `DriftOfflineFirstOrderRepository` |
| `frontend/lib/features/delivery/delivery_screen.dart:4939` | `ordersApi.getOrderById(orderId)` | `GET /api/orders/:id` | **READ** | DeliveryScreen: Order details | Read from local order repo |

---

## 2. Write Endpoints Seen in Backend-Down Log & Classification

| HTTP Endpoint | Invoked From | Operation Type | Payload Summary | Offline Classification |
|---|---|---|---|---|
| `POST /api/orders` | `tables_screen.dart:3737` | `INSERT` | Dine-in order items, table_id, subtotal, guest_count | **Critical Write**: Must generate UUID v7, insert to `LocalOrders` & `LocalOrderItems`, and queue `INSERT` in `SyncOutbox`. |
| `PATCH /api/orders/:id` | `tables_screen.dart:3711, 5039` | `UPDATE` | Items payload, status='completed', payment details | **Critical Write**: Must update local order in Drift, insert `LocalOrderPayments`, and queue `UPDATE` in `SyncOutbox`. |
| `PATCH /api/tables/:id/status` | `table_repository.dart:114` | `UPDATE` | status, currentBillAmount, activeOrderId | **Critical Write**: Must update `LocalRestaurantTables` version/status in Drift, and queue `UPDATE` (entity_type: `'table'`) in `SyncOutbox`. |
| `GET /api/sync/overview` | `data_sync_screen.dart:23` | `QUERY` | sync_status, order_type filters | **Read / View-Model**: Must read local outbox and local orders instead of crashing on `SocketException`. |

---

## 3. Provider & Component Mounting Status

| Component / Provider | Definition Location | Read / Mounted By | Status |
|---|---|---|---|
| `orderRepositoryProvider` | `frontend/lib/data/repositories/order_repository_provider.dart:32` | `pos_repository.dart` (`posProvider`, `completeOrderUseCaseProvider`) | **Partially Wired** (Wired to POS screen; NOT wired to Tables, Takeaway, or Delivery screens) |
| `syncBackgroundWorkerProvider` | `frontend/lib/core/sync/sync_providers.dart:36` | `syncStateProvider` (`sync_providers.dart:64`) | **NEVER STARTED** (Lazy Riverpod provider; unread by `main.dart` or any widget; `worker.start()` never executes) |
| `connectivityNotifierProvider` | `frontend/lib/core/sync/sync_providers.dart:24` | `syncBackgroundWorkerProvider` | **NEVER STARTED** (Tied to worker provider lifecycle) |
| `SyncStatusIndicatorWidget` | `frontend/lib/core/widgets/sync_status_indicator_widget.dart:18` | **NONE** | **UNMOUNTED** (Never rendered in any screen or app bar) |

---

## 4. Drift Schema & DAOs Readiness Check

| Capability | Local Drift Table | DAO Method Available | Backend Handler Support | Status |
|---|---|---|---|---|
| Tables Cache | `LocalRestaurantTables` (`catalog_tables.dart:78`) | `CatalogDao.getAllTables()`, `getTableById(id)`, `upsertRestaurantTables(entries)` | `TableHandler` (`backend/src/sync/handlers/table.handler.ts`) handles entity `'table'` & `'restaurant_table'` with OCC | **Schema Ready**; Needs wiring in `table_repository.dart` |
| Table Outbox Ops | `SyncOutbox` (`sync_outbox_table.dart:20`) | `OutboxDao.insertEntry(...)` | `TableHandler.handleUpdate(...)` supports `status`, `current_bill_amount`, `active_order_id`, and table conflict policy | **Supported**; Use `entityType: 'table'`, `operationType: 'UPDATE'` |
| Menu & Deals Cache | `LocalMenuCategories`, `LocalMenuItems`, `LocalMenuItemSizes`, `LocalMenuItemOptions`, `LocalDeals` | `CatalogDao.getAllCategories()`, `getAllMenuItems()`, `getAllDeals()`, upserts | Populated during `/api/sync/bootstrap` by `SyncBackgroundWorker` | **Schema Ready**; Populated once worker boots |
| Outbox Status & Queries | `SyncOutbox` | `OutboxDao.watchPendingCount()`, `watchPendingEntries()` | Push sync endpoint `/api/sync/push` | **Schema Ready** |

---

## 5. Provider Mutation in Lifecycle Methods Audit

| File : Line | Lifecycle Method | Provider Mutated | Nature of Mutation | Fixed / Action |
|---|---|---|---|---|
| `frontend/lib/config/router.dart:221` | `didUpdateWidget` | `roleRightsProvider` | Synchronous `loadPermissions()` setting `state = state.copyWith(isLoading: true)` | **FIXED** (Wrapped in `WidgetsBinding.instance.addPostFrameCallback` with `mounted` check) |
| `frontend/lib/config/router.dart:213` | `initState` | `roleRightsProvider` | Post-frame callback `ref.read(...).loadPermissions()` | Safe (already deferred via `addPostFrameCallback`) |
| `frontend/lib/features/rights/rights_screen.dart:20` | `initState` | `roleRightsProvider` | Post-frame callback `ref.read(...).loadPermissions()` | Safe (already deferred via `addPostFrameCallback`) |
| `frontend/lib/features/sync/data_sync_screen.dart:23` | `initState` | `dataSyncProvider` | Post-frame callback `ref.read(...).loadData()` | Safe (already deferred via `addPostFrameCallback`) |
| `frontend/lib/features/tables/tables_screen.dart:34` | `initState` | `tableProvider` | Post-frame callback `ref.read(...).loadTables()` | Safe (already deferred via `addPostFrameCallback`) |
| `frontend/lib/features/stock/stock_screen.dart:26` | `initState` | `inventoryProvider` | Post-frame callback `ref.read(...).loadInventoryData()` | Safe (already deferred via `addPostFrameCallback`) |

---

## 6. Shell Navigation Bar & App Startup Audit

### 6.1 App Startup (`main.dart` & Root Widget)
- **File:** [`frontend/lib/main.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/main.dart)
- **Structure:**
  - `main()` -> `runApp(ProviderScope(child: HungryHowiesPosApp()))`
  - `HungryHowiesPosApp` is a `ConsumerWidget`.
  - Currently watches `appRouterProvider` and `themeProvider`.
  - **Remediation for `worker-bootstrap`:** Convert `HungryHowiesPosApp` to a `ConsumerStatefulWidget`, and in `initState()` schedule `ref.read(syncBackgroundWorkerProvider).start()` inside `WidgetsBinding.instance.addPostFrameCallback`.

### 6.2 Top Navigation Bar (Mount Location for Sync Light)
- **Portal Shell:** Defined in `frontend/lib/config/router.dart:251-267` (`_PortalShellWrapper`):
  - Cashier shell renders: `CashierTopNavigationBar(currentRoute: widget.currentRoute)`
  - Manager/Admin shell renders: `NavigationSidebar(currentRoute: widget.currentRoute)`
- **Top-Right Slot in Cashier Shell:** [`frontend/lib/shared/widgets/cashier_top_navigation_bar.dart:295-306`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/shared/widgets/cashier_top_navigation_bar.dart#L295-L306):
  - Already contains `SyncButton(variant: SyncButtonVariant.cashierTopBar)` and `_buildNetworkStatusBadge(context, ref)`.
  - The sync indicator / status light (`SyncStatusIndicatorWidget`) belongs directly between `SyncButton` and `_buildNetworkStatusBadge`.
- **Admin/Manager Shell:** Inside `NavigationSidebar` footer or top header, adjacent to the existing `NETWORK STATUS` badge.

---

## 7. Recommended File Ownership Matrix for Parallel Waves

To guarantee parallel agents never edit the same files or create merge conflicts, file ownership is strictly partitioned as follows:

| Agent Name | Wave | Owned Files (Exclusive Write Access) | Read-Only Dependencies |
|---|---|---|---|
| **`worker-bootstrap`** | Wave 2 | `frontend/lib/main.dart`, `frontend/lib/core/sync/sync_background_worker.dart`, `frontend/lib/core/sync/sync_providers.dart` | `AUDIT.md`, `app_database.dart` |
| **`tables-offline-wiring`** | Wave 2 | `frontend/lib/features/tables/tables_screen.dart`, `frontend/lib/data/table_repository.dart`, `frontend/lib/data/repositories/drift_offline_first_order_repository.dart` | `AUDIT.md`, `order_repository_provider.dart`, `catalog_dao.dart` |
| **`datasync-local-screen`** | Wave 2 | `frontend/lib/features/sync/data_sync_screen.dart`, `frontend/lib/data/sync_repository.dart` | `AUDIT.md`, `outbox_dao.dart`, `orders_dao.dart` |
| **`riverpod-lifecycle-guard`** | Wave 2 | `frontend/lib/config/router.dart` (lifecycle deferral guard only) | `AUDIT.md` |
| **`sync-status-light`** | Wave 3 | `frontend/lib/core/widgets/sync_status_indicator_widget.dart`, `frontend/lib/shared/widgets/cashier_top_navigation_bar.dart` | `sync_providers.dart`, `worker-bootstrap` exports |
| **`integration-qa`** | Wave 4 | `docs/offline-remaining/QA.md` (verify & test only) | Full repository |
