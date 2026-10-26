---
name: sync001-p2002-order-loss
description: Fixes SYNC-001 - P2002 unique-constraint catch block that silently marks colliding orders DUPLICATE and loses them.
---

# Role
Backend engineer (NestJS + Prisma). Fix SYNC-001: Silent Order Annihilation.

# Reports to read
`FINAL-SYNC-ENGINE-REPORT.md`, `01-outbox-idempotency.md`, `05-backend-sync.md`, `07-money-correctness.md`

# Files you own
- `backend/src/**/sync-push.service.ts` (around lines 259-277)
- `backend/src/**/orders.service.ts` (around lines 302-318)
- related unit/e2e tests for these files

# Problem
When an offline device pushes an order whose human `order_number` (e.g. P1-101) or takeaway token collides, Postgres raises P2002. The catch block assumes P2002 always means the primary key (idempotency key / order id) already exists, rolls back, returns HTTP 200 `status: 'DUPLICATE'`. The client marks it SYNCED and purges it from the outbox. The order is never persisted or dispatched to the kitchen.

# Required fix
1. Inspect `error.meta.target` (the violated constraint/columns). Only treat P2002 as a true DUPLICATE when the target is the primary key / the idempotency (client mutation id / order uuid) constraint AND the existing row is the same order (compare id and payload hash if available).
2. For `order_number` / takeaway token collisions: do NOT report DUPLICATE. Resolve the collision by allocating a new server-side human-readable number (per restaurant + business day, inside the same transaction, using a safe sequence or retry loop with bounded attempts), keep the original as `client_order_number` (add nullable column via a NEW migration if none exists), and persist the order. Return `status: 'APPLIED'` with the final server order number so the client can update its local record.
3. For unknown P2002 targets: return a non-success status (`FAILED_RETRYABLE` or an HTTP error) so the client keeps the entry in the outbox. NEVER return a success-like status when the order is not stored.
4. After a DUPLICATE verdict, verify the row truly exists before acknowledging.
5. Log structured warnings with device id, mutation id, constraint target.
6. Keep the API response backward compatible (additive fields only) so flag-off and old clients are unaffected.

# Tests (must exist)
- Same mutation pushed twice -> DUPLICATE, one row.
- Two devices push different orders with the same `order_number` -> both persisted, distinct final numbers, nothing lost.
- Same collision for takeaway token.
- Unknown P2002 target -> not acknowledged as success.
- Concurrent pushes (Promise.all) do not lose orders.

# Acceptance
No code path returns a success/DUPLICATE status without a persisted order row. Tests above pass.

## Ground rules (apply to every agent)
- Read `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md` and the specific report(s) listed below BEFORE editing anything. Re-verify the cited file:line evidence in the current code; line numbers may have drifted.
- Stack: Flutter (Riverpod, go_router, Drift/SQLite outbox) frontend; NestJS + Prisma + PostgreSQL backend. Feature flag `OFFLINE_FIRST_ENABLED`.
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.

