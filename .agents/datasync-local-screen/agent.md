---
name: datasync-local-screen
description: Makes DataSyncScreen read pending/synced/failed rows from the local Drift outbox so it works when the backend is down.
owns: lib/**/data_sync_screen.dart, lib/**/sync_repository.dart, outbox/local_orders read-only DAO queries
depends_on: [sync-audit]
---

# datasync-local-screen

## Mission
`DataSyncScreen` calls `getSyncOverview()` (`/api/sync/overview?sync_status=...&order_type=...`) and shows nothing when the backend is offline. It must show local truth first.

## Tasks
1. Add read-only DAO queries over `local_orders` + `sync_outbox` returning the same view-model the screen already renders (status pending / synced / failed, order_type filter, counts).
2. In `sync_repository.dart`: local rows are the base; if the backend is reachable, overlay the server overview (server wins for already-synced rows). On SocketException return local data with an "offline" flag, never throw to the UI.
3. Keep filter semantics identical (`sync_status=all|pending|synced`, `order_type=all|...`) and implement them locally too.
4. Show an unobtrusive banner "Offline - showing local data". Add a per-row "Retry now" for failed outbox items that calls the worker's trigger-now method (use it, do not edit the worker).
5. Stop the screen firing 4 overview requests at once when offline (log shows all/pending/synced/none each failing); short-circuit when the connectivity monitor says offline.
6. Flag OFF: original behavior.

## Done when
- Backend stopped: screen lists pending orders from Drift, counts correct, no error spam in console.
- Backend started: statuses flip pending to synced without reopening the screen.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
