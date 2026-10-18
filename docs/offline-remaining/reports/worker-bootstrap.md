# Agent Report: worker-bootstrap

## Summary
Bootstrapped `SyncBackgroundWorker` at application startup so that queued outbox mutations are drained automatically when online without requiring manual navigation or explicit user sync actions.

## Files Touched
- [`frontend/lib/main.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/main.dart#L19-L37)
  - Converted `HungryHowiesPosApp` from a `StatelessWidget` to a `ConsumerStatefulWidget`.
  - Added post-frame callback in `initState` guarded by `mounted` and `FeatureFlags.offlineFirstEnabled` to trigger `ref.read(syncBackgroundWorkerProvider).start()`.
- [`frontend/lib/core/sync/sync_background_worker.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/core/sync/sync_background_worker.dart#L186-L190)
  - Added public read-only getters for sync status light / UI consumers:
    - `bool get isRunning => _isRunning && !_isDisposed;`
    - `bool get isDraining => _isPushing || _isPulling;`
    - `DateTime? get lastSuccessAt => state.lastSuccessfulPush ?? state.lastSuccessfulPull;`
    - `String? get lastError => state.lastError;`
  - Verified `start()` idempotency (guards on `_isRunning || _isDisposed`).
  - Verified `ref.onDispose` cleanly calls `worker.dispose()`.
  - Verified connectivity notifier listener calls `reconnect()` immediately when flipping from offline to online.
  - Verified all periodic ticks and triggers wrap network operations in try/catch and update `stateNotifier` without crashing the loop.

## Verification
- Ran `dart analyze lib/main.dart lib/core/sync/sync_background_worker.dart`: **0 issues**.
- Checked Riverpod lifecycle safety: provider mutation deferred to post-frame callback, avoiding any `build`/`initState` synchronous state modification.

## Open Risks
- None identified.

## Requests for Other Agents
- `sync-status-light`: Can consume `ref.watch(syncBackgroundWorkerProvider)` and its getters `isRunning`, `isDraining`, `lastSuccessAt`, `lastError`.
