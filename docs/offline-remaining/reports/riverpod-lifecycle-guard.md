# Agent Report: riverpod-lifecycle-guard

## Summary
Audited and resolved Riverpod lifecycle crashes ("Tried to modify a provider while the widget tree was building"). Verified that `_PortalShellWrapperState` (`frontend/lib/config/router.dart`) defers calls in both `initState` and `didUpdateWidget`, and swept `frontend/lib` for similar lifecycle hazards.

## Files Touched
- [`frontend/lib/config/router.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/config/router.dart#L210-L226)
  - `initState`: Deferred `_checkStartingCashGate()` and `roleRightsProvider.notifier.loadPermissions()` via `WidgetsBinding.instance.addPostFrameCallback` with `if (mounted)` guard.
  - `didUpdateWidget`: Deferred `roleRightsProvider.notifier.loadPermissions()` via `WidgetsBinding.instance.addPostFrameCallback` with `if (mounted)` guard on route changes.
- [`frontend/lib/data/role_rights_repository.dart`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/frontend/lib/data/role_rights_repository.dart#L179-L181)
  - `loadPermissions`: Added early return `if (!mounted || state.isLoading) return;` to avoid race conditions or redundant state mutations when rapidly navigating routes.
- [`docs/offline-remaining/lifecycle-grep.md`](file:///D:/HowiePOSUPdated/Hbackend-Hfrontend-main/docs/offline-remaining/lifecycle-grep.md)
  - Documented PowerShell commands and automated Dart scripts for repeatable auditing.

## Verification
- Codebase sweep across all `initState`, `didUpdateWidget`, `didChangeDependencies`, `dispose`, and `build` methods confirmed no other direct synchronous provider mutations exist.
- Ran `dart analyze lib/config/router.dart lib/data/role_rights_repository.dart`: **0 issues**.

## Open Risks
- None.

## Requests for Other Agents
- None.
