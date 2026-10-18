---
name: integration-qa
description: Final gate. Verifies the whole offline pipeline end to end (backend down/up), flag-OFF regression, and static checks. Runs LAST; reports, does not silently rewrite.
mode: verify-and-report
depends_on: [worker-bootstrap, tables-offline-wiring, datasync-local-screen, riverpod-lifecycle-guard, sync-status-light]
---

# integration-qa

## Mission
Prove the original complaint is solved: "backend on works; terminate backend and orders are not stored locally".

## Test matrix (record PASS/FAIL in `docs/offline-remaining/QA.md`)
1. Backend ON, flag ON: takeaway/delivery and Dine-In orders complete normally; light green; outbox empty afterwards.
2. Backend OFF at launch: app opens, menu/tables load from local cache, light red.
3. Backend killed mid-session: create dine-in order, add items, pay, free table. No exception dialogs; `local_orders` + `sync_outbox` rows present; table status correct.
4. Data Sync screen offline: shows pending rows from Drift, no console error spam.
5. Backend restarted: worker drains in order, server ids mapped, outbox empty, light returns to green, Data Sync shows synced.
6. Duplicate protection: kill backend during a drain, restart; no duplicate orders on the server (idempotency key respected).
7. Flag OFF: identical to the pre-offline app (direct HTTP), light hidden, worker not started.
8. Tab navigation: zero "Tried to modify a provider while the widget tree was building" errors.
9. Static: `dart analyze` 0 issues, `flutter test` passes, backend tests untouched and passing.

## Rules
- You may only fix trivial analyzer/format issues. Any functional failure goes in the report with file/line, repro steps, and the agent that should fix it.
- End with a verdict: READY / NOT READY and the blocking items.

## Global rules (apply to every agent)
- Project: Hungry Howie's POS (Flutter + Riverpod + go_router; Drift/SQLite local DB; NestJS backend at http://localhost:3000).
- Source of truth: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. If your task conflicts with it, stop and report; do not improvise.
- Do NOT break existing online behavior. Respect the `OFFLINE_FIRST_ENABLED` feature flag: when OFF, behavior must be identical to today.
- Never mutate a Riverpod provider inside `build`, `initState`, `didUpdateWidget`, `didChangeDependencies` or `dispose`. Defer with `WidgetsBinding.instance.addPostFrameCallback` (guard with `mounted`) or `Future.microtask`.
- Stay inside the files you own (listed below). If you need a change elsewhere, write it in your report under "Requests for other agents" instead of editing.
- Make the smallest diff that works. No unrelated refactors, no renames, no formatting-only churn.
- Before finishing: run `dart analyze` on every file you touched (must be 0 issues) and `dart run build_runner build --delete-conflicting-outputs` only if you changed Drift tables/annotated classes.
- Finish by writing `docs/offline-remaining/reports/<your-agent-name>.md`: what changed (file + line ranges), what you verified, open risks, requests for other agents.
