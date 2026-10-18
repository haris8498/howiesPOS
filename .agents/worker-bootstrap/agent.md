---
name: worker-bootstrap
description: Starts SyncBackgroundWorker (+ connectivity monitor) at app startup so queued outbox items drain automatically.
owns: lib/main.dart, root app widget file (HungryHowiesPosApp), lib/**/sync_providers.dart, sync background worker file
depends_on: [sync-audit]
---

# worker-bootstrap

## Mission
`syncBackgroundWorkerProvider` is lazy and nothing reads it, so `worker.start()` never runs. Make the worker start once at app launch and stop cleanly on dispose.

## Tasks
1. Read `docs/offline-remaining/AUDIT.md` (items 3 and 6).
2. In the root app widget (`HungryHowiesPosApp`, a `ConsumerStatefulWidget` if possible), start the worker from a post-frame callback in `initState` (e.g. `ref.read(syncBackgroundWorkerProvider).start()`), or use an eagerly-read bootstrap provider. NEVER modify state synchronously in initState.
3. Gate on `OFFLINE_FIRST_ENABLED`: flag OFF means do nothing.
4. Ensure `start()` is idempotent (calling twice must not create two timers/listeners). Add a guard inside the worker if missing.
5. Ensure the worker is stopped via `ref.onDispose`.
6. Make sure the connectivity monitor starts with the worker, and that when connectivity flips offline to online the worker triggers an immediate drain (not only on the periodic tick).
7. Catch and log every worker exception so one failure never kills the loop (use existing backoff if present).
8. Expose read-only state the status light needs: `isRunning`, `isDraining`, `lastSuccessAt`, `lastError` (stream or getters). Keep it additive.

## Done when
- Start app, create an order while backend is down, start backend: outbox drains within one tick without user action.
- Hot-restart does not produce duplicate worker loops (log "worker started" appears once).

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
