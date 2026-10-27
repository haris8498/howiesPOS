---
name: d05-order-line-item-ledger
description: Fixes D-05 (SYNC-032): append-only UUID v7 order line-item ledger so REST order edits merge instead of replacing items. Wave 2.
---

# Agent: D-05 Append-Only Line-Item Ledger

## Mission
The REST order-modification endpoint currently replaces all line items with the whole-order payload, so two devices editing the same order destroy each other's items. Make line items an append-only ledger merged by id.

## Preconditions
Wave 1 branches (D-02, D-04, D-06) are merged. You are the only agent editing the OrderItem/Order parts of `schema.prisma` in Wave 2 (D-01 edits DiningTable only; keep your edits to separate model blocks).

## Scope (may touch)
Backend orders module/DTOs/service, `schema.prisma` OrderItem model + additive migration, sync push handler for orders. Flutter: Drift order-items table + migration, order repository, outbox op types, add/void item UI wiring. Do **not** implement pricing recalculation or discounts (that is D-03).

## Tasks
1. Client generates **UUID v7** ids for every new line item (`uuid` package `v7()`); server stores that id as the primary key (accept legacy ids as-is).
2. Add to OrderItem (additive): `voidedAt DateTime?`, `voidedBy String?`, `supersedesItemId String?`, `createdByDeviceId String?`, `clientCreatedAt DateTime?`. Backfill migration leaves existing rows valid.
3. Ledger semantics: items are never updated or deleted. Quantity/modifier change = new item with `supersedesItemId` + void of the old one. Void = set `voidedAt` (tombstone). Active items = not voided. Merge rule: **set-union by id; a void always wins over a live copy**. Inserts are idempotent (`ON CONFLICT DO NOTHING`).
4. New endpoints: `POST /orders/:id/items` (append batch), `POST /orders/:id/items/:itemId/void`. Keep the old whole-order `PUT` for backward compatibility but reimplement it as a diff → ledger ops. Items absent from the payload are **not** removed unless the request carries an explicit `fullReplace: true`.
5. Expose `getActiveItems(orderId, tx)` in the orders service as the single source of active items (D-03 will compute totals from it). Do not compute prices here.
6. Flutter: Drift item rows carry the new columns (migration step); repository add/void/replace-quantity produce outbox ops `ITEM_ADD` / `ITEM_VOID`; apply incoming server items by set-union with the same void-wins rule.
7. Sync ordering: ops for one order are applied in clientCreatedAt order but correctness must not depend on it (commutative merge).

## Acceptance criteria
- Device A adds item X and Device B adds item Y to the same order offline; after both sync the order has X and Y.
- A voids Z while B (offline) edits Z's quantity; result: Z voided, B's superseding item preserved or voided consistently, no duplicates, no lost items.
- Replaying the same ops any number of times yields identical state.
- Old clients using `PUT` still work.

## Tests to add
Backend merge property tests (any permutation of ops → same result), idempotency, legacy PUT compat; Flutter repository tests for add/void/apply.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-05` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-05-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-05-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
