---
name: tables-offline-wiring
description: Moves Dine-In flow in tables_screen.dart off direct HTTP onto orderRepositoryProvider (Drift + outbox) so orders and table status work with the backend down.
owns: lib/**/tables_screen.dart, tables repository/API wrappers, Drift tables-cache table + DAO, order repository additions
depends_on: [sync-audit]
---

# tables-offline-wiring

## Mission
In the failing log, `POST /api/orders`, `PATCH /api/orders/101` and `PATCH /api/tables/<id>/status` all failed over HTTP from `tables_screen.dart` (~line 3737) and nothing was saved locally. Make Dine-In create / update / pay / table-status fully offline-capable.

## Tasks
1. Read `AUDIT.md` and the Stage 4 `DriftOfflineFirstOrderRepository` to reuse its patterns (atomic transaction: write `local_orders` + enqueue `sync_outbox` in ONE Drift transaction).
2. Replace direct `ordersApi.createOrder()` / `ordersApi.updateOrder()` in tables_screen.dart with `ref.read(orderRepositoryProvider)` calls. Dine-In order creation, adding items, and "complete table payment" must commit locally first and return immediately; never block the UI on HTTP.
3. Table status changes: add an outbox operation type `table_status` if missing, apply the change to a local tables cache immediately, enqueue the PATCH. Preserve operation ORDER per table (create order, set occupied, pay, set free) so the server replays them correctly.
4. Reads: `GET /api/tables` must fall back to the local cache when the backend is unreachable and refresh the cache on success. Do the same for menu categories/items/deals only if tables_screen depends on them.
5. IDs: offline orders need a client-generated UUID + temporary display number; map to the server id when sync completes and update the local row. Never lose the table-to-order link during the swap.
6. Remove the swallowed-exception pattern (`effectiveOrderId == null` after catch). Failures must surface as a local-save result, not a silent null.
7. Flag OFF: original HTTP path unchanged (keep it behind the flag, do not delete).

## Done when
- Backend stopped: open a table, add items, take payment, free the table. No errors; rows exist in `local_orders` + `sync_outbox`; table shows correct status.
- Backend started: queued ops replay in order, server ids are mapped back, outbox empties.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
