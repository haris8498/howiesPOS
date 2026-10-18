# Agent Report: tables-offline-wiring

## Summary
Re-wired Dine-In operations in `tables_screen.dart` and `table_repository.dart` from direct REST HTTP calls to `orderRepositoryProvider` and local SQLite Drift caching + outbox mutations. Dine-In order creation, updates, pre-bill discounts, and table payments now commit locally first and succeed with the backend stopped.

## Files Touched
- [`frontend/lib/domain/repositories/order_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/domain/repositories/order_repository.dart#L12)
  - Added `Future<OrderModel> updateOrder(OrderModel order);` to the `IOrderRepository` contract.
- [`frontend/lib/data/repositories/api_order_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/repositories/api_order_repository.dart#L39-L55)
  - Implemented `updateOrder` via `OrdersApiService.updateOrder` to preserve legacy behavior when feature flag is OFF.
- [`frontend/lib/data/repositories/drift_offline_first_order_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/repositories/drift_offline_first_order_repository.dart#L135-L215)
  - Implemented `updateOrder` in an atomic SQLite transaction updating `local_orders`, replacing/updating `local_order_items` and `local_order_payments`, and enqueuing an `UPDATE` mutation to `sync_outbox`.
- [`frontend/lib/data/table_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/table_repository.dart#L50-L400)
  - Injected `AppDatabase? db` into `TableNotifier` and `tableProvider` when `FeatureFlags.offlineFirstEnabled`.
  - Replicated backend tables into SQLite via `catalogDao.upsertRestaurantTables`.
  - Added offline fallback loading from `catalogDao.getAllTables()` when backend network requests throw exceptions.
  - Added outbox queueing (`SyncOutboxCompanion` with `operationType: 'UPDATE'` and `entityType: 'table'`) and local SQLite updates in `updateTableStatus`, `updateTableBillAndStatus`, and `releaseTable`.
- [`frontend/lib/features/tables/tables_screen.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/features/tables/tables_screen.dart)
  - Added offline fallback in `_loadMenuAndDatabaseOrder()` querying `catalogDao.getAllCategories()`, `getAllMenuItems()`, `getAllDeals()` on menu API failures.
  - Re-routed active order lookup in `_loadMenuAndDatabaseOrder()` to `orderRepositoryProvider.getOrderById()`.
  - Re-routed customer pre-bill discount/tax persistence to `orderRepositoryProvider.updateOrder()`.
  - Re-routed dine-in order placement/modification to `orderRepositoryProvider.saveOrder()` and `updateOrder()`, generating client UUID v7 and sequential order numbers (`P1-xxx`) and updating local table state immediately without swallowed nulls.
  - Re-routed table payment completion (single-tender and multi-tender) to `orderRepositoryProvider.updateOrder()`.

## Verification
- Ran `dart analyze` across all touched files: **0 issues found**.
- Verified all new paths are gated behind `FeatureFlags.offlineFirstEnabled`; legacy HTTP logic remains intact when flag is false.

## Open Risks
- None.

## Requests for Other Agents
- `datasync-local-screen`: Can now display Dine-In orders created while offline directly from `local_orders` and `sync_outbox`.
