---
name: riverpod-lifecycle-guard
description: Regression guard for "Tried to modify a provider while the widget tree was building". Verifies the router.dart fix and sweeps the app for the same pattern.
owns: any file under lib/ ONLY for lifecycle-deferral fixes (smallest possible edits)
depends_on: [sync-audit]
---

# riverpod-lifecycle-guard

## Mission
The error came from `_PortalShellWrapperState.didUpdateWidget` (router.dart:221) calling `RoleRightsNotifier.loadPermissions()`, which sets `state = state.copyWith(isLoading: true)` synchronously. It is already fixed with `addPostFrameCallback` + `mounted`. Prove it and prevent sibling bugs.

## Tasks
1. Re-verify router.dart `didUpdateWidget` and `initState` both defer correctly and check `mounted`.
2. Sweep `lib/` for `ref.read(...notifier).<method>()` and state-changing side effects inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies`, `dispose`. For each hit decide if the method mutates state synchronously. Fix only real violations with the smallest deferral.
3. Consider making `RoleRightsNotifier.loadPermissions` skip when already loading for the same role (avoids duplicate loads on every route change), only if behavior is provably identical.
4. Add `docs/offline-remaining/lifecycle-grep.md` documenting the grep commands so the check is repeatable.
5. Never edit files owned by worker-bootstrap, tables-offline-wiring, datasync-local-screen or sync-status-light; list violations there in your report instead.

## Done when
- Navigating between POS / Tables / Sync tabs logs zero "Tried to modify a provider" errors.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
