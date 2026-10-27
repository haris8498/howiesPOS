---
name: d01-table-seating-overflow
description: Fixes D-01 (SYNC-011/SYNC-030/TBL-02): virtual overflow tables so concurrent offline seating at the same table never discards an order. Wave 2.
---

# Agent: D-01 Concurrent Seating → Virtual Overflow Table

## Mission
Two offline cashiers seat different parties at Table 4. On reconnect, today one party's table assignment effectively wins and the other is lost or corrupted. New policy: **neither order or assignment is discarded**; the later claimant is moved to a virtual overflow table (`4-B`, `4-C`, ...).

## Preconditions
D-02 is merged (DiningTable has `isDeleted`). You edit the DiningTable model block of `schema.prisma` only; D-05 edits OrderItem in parallel on another branch.

## Scope (may touch)
Backend tables + orders sync handler, DiningTable additive migration. Flutter: tables Drift table + migration, table/order repositories, sync apply, tables screen (overflow rendering), snackbar/banner for reassignment.

## Tasks
1. Add to DiningTable (additive): `isOverflow Boolean @default(false)`, `parentTableId String?` (self relation), `overflowSuffix String?`.
2. Conflict detection (server, inside the order-push transaction, with a row lock `SELECT ... FOR UPDATE` on the table row): an incoming order claims table T while another **different, still-open** order already holds T.
3. Deterministic winner: earlier `seatedAt` (fallback `createdAt`) keeps T; ties broken by smaller order UUID. The loser is reassigned to an overflow table of T: reuse an existing free overflow table or create the next suffix (B, C, ...). Both orders stay fully intact (items, payments, timestamps).
4. Idempotency: replaying the same push never creates a second overflow table or reassigns twice.
5. Ack payload includes `tableReassigned: [{orderId, fromTableId, toTableId, toLabel}]`. Flutter applies it: updates the local order's tableId, upserts the overflow table row, and shows a non-blocking banner "Table 4 had two parties, one moved to 4-B".
6. UI: overflow tables render next to their parent in the grid with a distinct style; they auto-hide (not delete) when empty and closed. Normal order flow on an overflow table works like any table (pay, transfer, close).
7. Offline caveat: on a single device, seating a table that already has a local open order is blocked as before; the overflow logic only handles cross-device collisions at sync time.

## Acceptance criteria
- Two devices seat Table 4 offline, then sync in either order: same outcome both times, two intact orders, one on 4, one on 4-B.
- Third collision gives 4-C. Replays are no-ops.
- Server restart/replay mid-sync leaves no half-applied state (transaction).

## Tests to add
Backend e2e for 2- and 3-way collisions, both sync orders, replay; Flutter test for applying `tableReassigned` and overflow rendering.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-01` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-01-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-01-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
