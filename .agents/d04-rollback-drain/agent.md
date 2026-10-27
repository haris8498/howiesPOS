---
name: d04-rollback-drain
description: Fixes D-04 (SYNC-027/FLG-02): startup outbox drain gate so turning OFFLINE_FIRST_ENABLED off never strands unsynced orders. Wave 1.
---

# Agent: D-04 Rollback Outbox Drain

## Mission
Flipping `OFFLINE_FIRST_ENABLED = false` while the local outbox still has unsynced orders must not strand them in SQLite.

## Scope (may touch)
Flutter only: feature-flag provider, `orderRepositoryProvider` selection logic, app startup/bootstrap, a new drain modal/screen, outbox DAO read helpers, tests. No backend or schema changes.

## Tasks
1. Add `OutboxDrainGate` (Riverpod) that, at startup and whenever the flag changes, counts non-terminal outbox rows (pending, failed-retryable, in-flight).
2. **Routing rule:** order repository uses the local-first path if `flag == true` **or** outbox is non-empty. The online-only path is chosen only when the flag is false **and** the outbox is empty. Never switch routing silently with rows pending.
3. If flag is false and outbox is non-empty, show a blocking **Drain modal**: count of unsynced orders, progress bar, **Sync now** (runs the existing sync worker until empty, with retries and backoff), and **Export backup** (writes the outbox as JSON to a user-chosen/documents folder).
4. If there is no network, the modal explains it and the app stays in drain-pending mode (local routing on) until connectivity returns; it must auto-resume.
5. Rows that permanently fail (4xx business errors) are listed in the modal with the error; they stay in the outbox (flagged), they are **never** deleted or purged by this flow. Verify no code path from the modal calls the "clear sync errors" purge.
6. Log each gate decision (flag, count, route chosen) for support.

## Acceptance criteria
- Flag false + 3 pending orders: modal shown, after sync all 3 on the server, then routing switches to online.
- Flag false + offline: app keeps working locally, nothing lost, modal explains.
- Flag false + empty outbox: no modal, behaves exactly like pre-offline app.
- Flag true: unchanged behaviour.

## Tests to add
Unit tests for the routing matrix (flag × outbox state × network); widget test for the modal; test that export produces valid JSON containing every pending row.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-04` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-04-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-04-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
