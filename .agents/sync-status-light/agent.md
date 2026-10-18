---
name: sync-status-light
description: Adds a green/red status light in the top-right of the app bar showing whether data is syncing, driven by real worker + connectivity + outbox state.
owns: lib/**/sync_status_indicator*.dart, lib/**/sync_health_provider.dart, top navigation bar widget (top-right slot only)
depends_on: [worker-bootstrap]
---

# sync-status-light

## Mission
A small light in the TOP-RIGHT of the main top bar that tells the cashier at a glance whether data is syncing.

## Semantics (exactly two colors)
- GREEN = healthy: backend reachable, worker running, outbox empty or draining without failures.
- RED = not syncing: backend unreachable/offline, OR worker not running, OR any outbox item failed/stuck (retries over threshold, or oldest pending item older than 2 minutes while online).
- While actively pushing, the green dot gently pulses (animation only, still green).
- Tooltip / tap text: "Synced", "Syncing - 3 pending", "Offline - 3 saved locally", "Sync error - 2 failed". Tap opens the Data Sync screen.

## Tasks
1. Reuse the existing `SyncStatusIndicatorWidget` if present; restyle to the dot + tiny optional pending badge. Do not create a second widget.
2. Create `syncHealthProvider` combining: connectivity monitor, worker state (`isRunning`, `isDraining`, `lastError` exposed by worker-bootstrap), and Drift `watch` queries on `sync_outbox` (pending count, failed count, oldest pending timestamp).
3. Mount in the top bar's top-right slot of the portal shell, visible on every screen. Add `Tooltip` + `Semantics` labels; dot about 12px with soft glow; tooltip text covers accessibility (do not rely on color alone).
4. Debounce state changes (~800 ms) to avoid flicker when connectivity flaps.
5. Flag OFF: render nothing (never a misleading green).
6. No provider mutation during build/lifecycle (streams/watchers only).
7. Add a widget test with a fake health provider for: green idle, green pulsing, red offline, red failed.

## Done when
- Backend running: green. Stop backend: red within seconds with "Offline - N saved locally". Start backend: green again once outbox drains.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
