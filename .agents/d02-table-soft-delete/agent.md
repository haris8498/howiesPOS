---
name: d02-table-soft-delete
description: Fixes D-02 (SYNC-012/TBL-12): soft-delete for dining tables so offline orders for a deleted table are never lost. Wave 1.
---

# Agent: D-02 Table Soft-Delete

## Mission
An admin deleting a table in the web portal must never orphan or reject orders an offline cashier took for that table. Replace hard delete with soft delete (`is_deleted`) end to end.

## Scope (may touch)
- Backend: `prisma/schema.prisma` (DiningTable model only), a new additive migration, tables module (controller/service/DTOs), sync pull/push handlers that read or write tables.
- Flutter: Drift tables table + migration step (bump schema version), table repository, delta-pull apply logic, tables screen filtering.
- **You are the only agent allowed to edit `schema.prisma` in Wave 1.**

## Tasks
1. Add `isDeleted Boolean @default(false)`, `deletedAt DateTime?`, `deletedBy String?` to DiningTable. Additive migration; existing rows default to not deleted.
2. If table number is uniquely constrained, replace with a **partial unique index** (`WHERE is_deleted = false`) in raw SQL inside the migration so a number can be reused after deletion.
3. `DELETE /tables/:id` becomes a soft delete (set flags, keep row and FKs). Add restore endpoint (`POST /tables/:id/restore`) guarded by admin role.
4. All normal list/read queries exclude deleted tables. The **sync delta pull must include tombstones** (`isDeleted: true`) so clients learn about deletions.
5. Order push: an order referencing a soft-deleted table is **accepted**, never rejected. Return a non-fatal warning code `TABLE_DELETED` in the sync ack and persist the order with its original tableId.
6. Flutter: add `is_deleted` to the Drift table (migration step, no data loss). On tombstone pull, hide the table from the grid **unless a local open order still exists on it**; in that case keep it visible (badge "removed") until that order is closed/paid.
7. Admin web/API: when deleting a table that has open orders, return them in the response so the UI can warn (do not block).

## Acceptance criteria
- Deleting a table with an offline order later synced results in the order stored, no error, warning surfaced.
- Table number can be reused after deletion.
- Tombstones propagate to a client that was offline during the delete.
- All existing table tests still pass.

## Tests to add
Backend e2e for delete → order push → ack warning; partial-unique reuse; tombstone in delta pull. Flutter unit test for tombstone apply with and without a local open order.

## Handoff
Document the new DiningTable fields in `docs/fixes/D-02-report.md`; D-01 builds on this model.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-02` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-02-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-02-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
