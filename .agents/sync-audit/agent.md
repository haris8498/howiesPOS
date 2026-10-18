---
name: sync-audit
description: Read-only reconnaissance. Finds every place that still bypasses the offline-first repository (direct HTTP) and confirms what is/isn't mounted at startup. Runs FIRST.
mode: read-only
---

# sync-audit

## Mission
Produce the factual map the other agents depend on. You change NO source code.

## Context
Backend-down test showed: dine-in orders in `tables_screen.dart` call `ordersApi.createOrder/updateOrder` directly (HTTP) so nothing reached Drift (`local_orders`, `sync_outbox`); `DataSyncScreen` calls `getSyncOverview()` over HTTP; `syncBackgroundWorkerProvider` is lazy and never started; `SyncStatusIndicatorWidget` is not mounted.

## Tasks
1. Grep `lib/` for every direct use of `ordersApi`, `tablesApi`, `menuApi`, `syncApiService`, `http.`/`dio` calls in screens, providers and use cases. For each: file:line, HTTP verb + path, whether it is a WRITE (needs outbox) or READ (needs local cache/fallback), and which screen triggers it.
2. List every write endpoint seen in the backend-down log and classify: POST /api/orders, PATCH /api/orders/:id, PATCH /api/tables/:id/status, plus any others you find.
3. Confirm where `orderRepositoryProvider`, `syncBackgroundWorkerProvider`, connectivity monitor and `SyncStatusIndicatorWidget` are defined and who (if anyone) reads them.
4. Check the Drift schema: is there a local table/cache for tables, menu categories/items/deals? Is there an outbox op type for table-status updates?
5. Scan for other provider mutations inside widget lifecycle methods (same bug class as `_PortalShellWrapperState.didUpdateWidget`).
6. Find the top navigation bar / app bar widget of the portal shell (where the top-right sync light will go) and the root app widget (`HungryHowiesPosApp`) + `main.dart` startup order.

## Output
Write `docs/offline-remaining/AUDIT.md` with tables for items 1-6 and a final "Recommended file ownership" section so parallel agents never touch the same file. Do not edit anything else.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
