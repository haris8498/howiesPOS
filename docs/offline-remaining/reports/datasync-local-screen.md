# Agent Report: datasync-local-screen

## Summary
Updated `DataSyncScreen` and `DataSyncNotifier` to show local truth first from Drift SQLite (`local_orders` and `sync_outbox`) when offline, preventing crashes, connection error spam, and empty ledger screens when the NestJS backend is stopped.

## Files Touched
- [`frontend/lib/data/sync_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/sync_repository.dart)
  - Added `bool isOffline` to `DataSyncState`.
  - Injected `AppDatabase? db`, `ConnectivityNotifier? connectivity`, and `SyncBackgroundWorker? worker` into `DataSyncNotifier` and `dataSyncProvider`.
  - Implemented `_loadLocalOrders()` querying `local_orders`, `local_order_items`, and `sync_outbox` to construct `DataSyncOrder` and summary metrics offline.
  - Implemented `_filterOrders()` preserving filter semantics (`all`, `synced`, `pending`, `failed`, and order types `dineIn`, `takeaway`, `delivery`).
  - Added short-circuit in `loadData()` when connectivity monitor reports offline, avoiding redundant failing HTTP requests.
  - Handled network errors / `SocketException` gracefully by returning local data with `isOffline = true` instead of throwing unhandled exceptions.
  - Updated `syncSingleOrder` and `syncAllPending` to trigger `_worker.triggerPush()` when offline-first is enabled, resetting failed outbox items to `pending` on retry.
- [`frontend/lib/features/sync/data_sync_screen.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/features/sync/data_sync_screen.dart)
  - Added amber banner: *"Offline — Showing local SQLite data. Changes will sync automatically when connection restores."* with a "Check Connection" retry button when `syncState.isOffline`.
  - Updated header status badge to show *"Offline - Local Mode"* (amber) when offline, or *"Cloud Sync Active"* (green) when online.
  - Added per-row red sync retry button for pending/failed outbox orders to immediately trigger push synchronization.

## Verification
- Ran `dart analyze lib/features/sync/data_sync_screen.dart lib/data/sync_repository.dart`: **0 issues found**.
- Verified all new paths are gated behind `FeatureFlags.offlineFirstEnabled`; legacy HTTP logic remains intact when flag is false.

## Open Risks
- None.

## Requests for Other Agents
- `sync-status-light`: Can reflect whether sync is active, offline, or experiencing errors.
