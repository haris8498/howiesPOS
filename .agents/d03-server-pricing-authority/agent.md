---
name: d03-server-pricing-authority
description: Fixes D-03 (SYNC-016/BCK-02): server-authoritative pricing with ±1.00 tolerance and manager-approved, audited discounts. Wave 3.
---

# Agent: D-03 Server Pricing Authority & Discount Control

## Mission
The server currently trusts client subtotal and grand total. Make the server authoritative while never losing a real sale that already happened offline.

## Preconditions
D-05 (ledger + `getActiveItems`) and D-06 (`OfflineAuthService.verifyManagerCredential`, `PasswordService`) are merged. You own the OrderItem/Order pricing fields and may add an audit model to `schema.prisma` (additive migration).

## Scope (may touch)
Backend orders/pricing module, a new `PricingService`, DiscountAudit model + migration, sync push validation. Flutter: checkout/discount UI, outbox payload for approvals, display of server-corrected totals.

## Tasks
1. `PricingService.calculate(orderId, tx)`: from active ledger items (D-05) and catalog prices, modifiers, tax and service-charge rules, minus validated discounts → server `subtotal`, `tax`, `grandTotal`. Use fixed-point/decimal arithmetic (Prisma `Decimal`), never floats.
2. Tolerance: `PRICING_ROUNDING_TOLERANCE` env, default `1.00`. If |client total − server total| ≤ tolerance: accept, store **server** totals, keep `clientReportedTotal`. If outside: **still persist the order** (the sale happened), set `pricingStatus = MISMATCH`, store both totals, write an audit row, and surface it in an admin review list. Online REST (not offline sync) may reject with 422.
3. Never trust client prices blindly: compare each line's client unit price to the catalog; differences are recorded in the audit row.
4. Discounts: any discount > 0 requires `approvedByManagerId`. Server validates the manager exists, is active, has role MANAGER/ADMIN. Online flow verifies the manager credential server-side (via `PasswordService`). Offline flow: the Flutter app verifies locally (D-06) and attaches an approval record `{managerId, deviceId, approvedAt, reason}` to the outbox op; the server accepts it if the manager is valid and records `source = OFFLINE`.
5. Discount without a valid approval: online → 403. Offline sync → order persisted, discount **not applied to the authoritative total**, flagged `UNAUTHORIZED_DISCOUNT` for review.
6. `DiscountAudit` table: orderId, amount, percent/type, reason, cashierId, approvedBy, deviceId, source (ONLINE/OFFLINE), createdAt. Immutable (no update/delete endpoints).
7. Flutter: discount button opens a manager-credential dialog; totals shown after sync are reconciled to server totals with a small notice if they changed.

## Acceptance criteria
- Tampered client total is corrected, order kept, mismatch flagged.
- Rounding difference of 0.50 accepted silently.
- Discount with manager approval applied + audited; without approval handled per rule 5.
- Totals computed only from non-voided ledger items.

## Tests to add
PricingService unit tests (tax, modifiers, decimals), tolerance boundary tests (exactly 1.00 and 1.01), discount authorization matrix (online/offline × approved/unapproved), audit immutability.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/D-03` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/D-03-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/D-03-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
