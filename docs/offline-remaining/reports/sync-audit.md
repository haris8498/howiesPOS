# Agent Report: sync-audit (Wave 1)

> **Agent:** `sync-audit`  
> **Wave:** Wave 1  
> **Date:** October 18, 2026  
> **Status:** COMPLETED  
> **Blockers:** NONE  
> **Requests for other agents:** NONE  

---

## 1. Summary of Changes
- Read-only reconnaissance audit completed.
- Zero source code changes made.
- Produced comprehensive reconnaissance specification at [`docs/offline-remaining/AUDIT.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-remaining/AUDIT.md).

## 2. Findings & Verification
1. **Direct HTTP Bypass in `tables_screen.dart`:**
   - Dine-in order creation (`tables_screen.dart:3737`) directly calls `ordersApi.createOrder()` over HTTP.
   - Adding items and completing payments (`tables_screen.dart:3711`, `5039`, `5650`) directly calls `ordersApi.updateOrder()`.
   - When offline, these throw `ClientException with SocketException`, swallowing the error in `try/catch` and leaving `effectiveOrderId = null`. No row is written to Drift `local_orders` or `sync_outbox`.
2. **`DataSyncScreen` Failure Offline:**
   - `data_sync_screen.dart` calls `_syncApiService.getSyncOverview()` over HTTP (`/api/sync/overview`).
   - When offline, it throws `SocketException` instead of reading local rows from Drift `sync_outbox` and `local_orders`.
3. **`SyncBackgroundWorker` Idle at Startup:**
   - `syncBackgroundWorkerProvider` is a lazy Riverpod provider. Because nothing reads it on launch, `worker.start()` never executes.
4. **`SyncStatusIndicatorWidget` Unmounted:**
   - `SyncStatusIndicatorWidget` is defined in `frontend/lib/core/widgets/sync_status_indicator_widget.dart` but is unmounted across all navigation bars.
5. **Drift Schema & Backend Handlers:**
   - Local tables (`LocalRestaurantTables`, `LocalMenuCategories`, `LocalMenuItems`, `LocalDeals`, `LocalFloorZones`) and DAOs already exist in Drift.
   - Backend `TableHandler` (`backend/src/sync/handlers/table.handler.ts`) already handles `entityType: 'table'` and `'restaurant_table'` with OCC and operational priority.
6. **Riverpod Lifecycle Guard:**
   - Synchronous mutation in `_PortalShellWrapperState.didUpdateWidget` has been resolved with `WidgetsBinding.instance.addPostFrameCallback`. Other screens already use post-frame deferral.

## 3. Open Risks
- None. Wave 2 agents have strictly non-overlapping file ownership as documented in Section 7 of [`AUDIT.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-remaining/AUDIT.md).

## 4. Requests for Other Agents
- **`worker-bootstrap` (Wave 2):** Eagerly start `syncBackgroundWorkerProvider` in `HungryHowiesPosApp` post-frame in `initState`, gated by `FeatureFlags.offlineFirstEnabled`.
- **`tables-offline-wiring` (Wave 2):** Replace direct `ordersApi` calls in `tables_screen.dart` with `ref.read(orderRepositoryProvider)` and update `table_repository.dart` to sync through Drift and outbox.
- **`datasync-local-screen` (Wave 2):** Update `sync_repository.dart` to read pending/synced outbox rows from Drift SQLite instead of crashing when HTTP fails.
- **`riverpod-lifecycle-guard` (Wave 2):** Verify `router.dart` and perform full sweep across `lib/` to confirm no remaining synchronous provider mutations in lifecycle methods.
