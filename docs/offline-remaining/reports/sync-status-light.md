# Agent Report: sync-status-light

## Summary
Added the two-color sync status indicator light (`SyncStatusIndicatorWidget`) in the top navigation bar (`CashierTopNavigationBar`), backed by a debounced reactive health stream (`syncHealthProvider`) combining network connectivity, worker operational state, and Drift SQLite outbox mutations.

## Semantics & Policy (Strict 2-Color Rule)
- **GREEN (Healthy):** Backend reachable/online, worker running, outbox empty or actively draining without failures. Gently pulses ambient glow while actively draining.
- **RED (Not syncing):** Backend unreachable/offline, OR worker stopped, OR any outbox item failed (fatal/conflict/retries >= 5), OR any item pending over 2 minutes while online.
- **Tooltips & Semantics:** Covers accessibility without relying on color alone ("Synced", "Syncing - 3 pending", "Offline - 2 saved locally", "Sync error - 1 failed", "Sync stuck - oldest item > 2 min").
- **Disabled Flag:** When `FeatureFlags.offlineFirstEnabled` is false, renders `SizedBox.shrink()` (never a misleading green).
- **Navigation:** Tapping the indicator navigates directly to `/sync` (Data Sync Ledger).

## Files Touched
- [`frontend/lib/core/database/daos/outbox_dao.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/database/daos/outbox_dao.dart#L104-L113)
  - Added `watchActiveOutboxEntries()` stream query on `sync_outbox` for non-terminal items.
- [`frontend/lib/core/sync/sync_health_provider.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/sync/sync_health_provider.dart)
  - Created `rawSyncHealthProvider` computing health state based on connectivity, worker getters, and active outbox entries.
  - Created `syncHealthProvider` with ~800 ms debounce to prevent flicker during flaky network transitions while immediately publishing initial state.
- [`frontend/lib/core/widgets/sync_status_indicator_widget.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/widgets/sync_status_indicator_widget.dart)
  - Restyled to a 14px dot with ambient glow and optional pending count badge.
  - Wired pulsing glow animation when draining.
  - Added accessibility tooltip and semantics.
  - Gated with `FeatureFlags.offlineFirstEnabled`.
- [`frontend/lib/shared/widgets/cashier_top_navigation_bar.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/shared/widgets/cashier_top_navigation_bar.dart#L305-L308)
  - Mounted `const SyncStatusIndicatorWidget()` in the top-right slot beside `SyncButton`.
- [`frontend/test/core/widgets/sync_status_indicator_widget_test.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/test/core/widgets/sync_status_indicator_widget_test.dart)
  - Added widget test suite covering:
    - Green idle state ("Synced")
    - Green pulsing state with pending badge ("Syncing - 3 pending")
    - Red offline state ("Offline - 2 saved locally")
    - Red failed state ("Sync error - 1 failed")

## Verification
- Widget tests: `flutter test test/core/widgets/sync_status_indicator_widget_test.dart` -> **4/4 passed (100%)**.
- Static analysis: `dart analyze lib/core/sync/sync_health_provider.dart lib/core/widgets/sync_status_indicator_widget.dart lib/core/database/daos/outbox_dao.dart lib/shared/widgets/cashier_top_navigation_bar.dart test/core/widgets/sync_status_indicator_widget_test.dart` -> **0 issues**.
- Riverpod lifecycle: No provider mutation in widget lifecycle methods; purely watched streams and providers.

## Open Risks
- None identified.

## Requests for Other Agents
- `integration-qa`: Ready for Wave 4 end-to-end integration QA.
