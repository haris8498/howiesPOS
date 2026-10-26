---
name: sync003-table-update-payments
description: Fixes SYNC-003 - offline dine-in order UPDATE ignores payments, discounts and taxes on the backend.
---

# Role
Backend engineer (NestJS + Prisma). Fix SYNC-003: Offline Table Order Updates Discard Payment Records.

# Reports to read
`FINAL-SYNC-ENGINE-REPORT.md`, `03-table-conflicts.md`, `07-money-correctness.md`

# Files you own
- `backend/src/**/order.handler.ts` (around lines 265-279, `handleUpdate`)
- tests for the handler; reuse existing payment/discount/tax helpers from `handleCreate` or `orders.service.ts` (read-only use; if they need changes, note it in handoff)

# Problem
`OrderHandler.handleUpdate()` sets status = completed and `is_paid = true` but ignores `payload.payments`, discounts and taxes, so the cloud shows a paid order with $0.00 in the ledger.

# Required fix
1. In `handleUpdate`, process `payload.payments`, `payload.discounts`, `payload.taxes` and updated line items inside ONE Prisma transaction, using the same code path/validation as create (extract a shared function rather than duplicating).
2. Idempotency: payments carry a client-generated id; upsert by that id so replays never double-count.
3. Server-side validation: recompute totals; sum(payments) must be >= order total for `is_paid = true`. If mismatch, do not set `is_paid`; return a conflict status that keeps the entry visible, never silent success.
4. Only mark completed/paid if the stored payments justify it. Update paid_at, payment method breakdown, and any till/shift totals the create path updates.
5. Preserve existing behaviour for status-only updates that carry no payments.
6. Inventory/stock deductions must behave identically to the online settle path (no double deduction on replay).

# Tests (must exist)
- Offline settle of a dine-in table creates payment rows equal to payload.
- Replay of the same update does not duplicate payments.
- Total mismatch is rejected/flagged, `is_paid` stays false.
- Discounts and taxes persisted and ledger total equals order total.
- Status-only update still works.

# Acceptance
For every order with `is_paid = true`, sum of payment rows equals the recorded total.

## Ground rules (apply to every agent)
- Read `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` and the specific report(s) listed below BEFORE editing anything. Re-verify the cited file:line evidence in the current code; line numbers may have drifted.
- Stack: Flutter (Riverpod, go_router, Drift/SQLite outbox) frontend; NestJS + Prisma + PostgreSQL backend. Feature flag `OFFLINE_FIRST_ENABLED`.
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.

