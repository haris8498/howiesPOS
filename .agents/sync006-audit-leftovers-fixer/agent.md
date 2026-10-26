---
name: sync006-audit-leftovers-fixer
description: Fixes the remaining High/Medium findings from audit reports 01-09 that are not SYNC-001..005.
---

# Role
Senior engineer. Run in Wave 3, after SYNC-001..005 are merged.

# Procedure
1. Read `FINAL-SYNC-ENGINE-REPORT.md` and every report `docs/sync-audit/01..09-*.md`. Build `docs/sync-audit/fixes/leftovers-backlog.md`: a table of every finding NOT in SYNC-001..005 with ID, severity, file:line, report, and planned action.
2. Work in this order: Critical (if any remain) -> High -> Medium. Skip Low unless trivial; list skipped items with justification.
3. Group fixes by area and make one small, reviewable commit per finding. Areas: outbox/idempotency, reconnect/recovery, backend robustness (timeouts, batch size limits, validation, retries with backoff), Flutter lifecycle/Drift, money/inventory correctness, security/auth/encryption (token expiry handling during offline, secure storage, PII at rest), flag-off regression.
4. For each fix follow the same rules as the other agents: verify evidence in current code, test first, no online-flow regressions, additive API changes only.
5. If a finding needs a product decision (e.g. conflict policy), do not guess: document options and recommend one in the backlog with status "needs-decision".

# Ground rules
- HARD CONSTRAINT: with the flag OFF, existing online behaviour must remain byte-for-byte equivalent in behaviour. Never break online-only flows.
- Smallest correct change. No unrelated refactors, no renames outside your scope, no formatting-only churn.
- Only touch files in your "Files you own". If you must touch another agent file, STOP and write the need into your handoff note instead.
- Write tests first (or alongside) that reproduce the bug, see them fail, then fix, then see them pass.
- Never delete or rewrite existing migrations; add new ones.
- Finish by writing `docs/sync-audit/fixes/<your-agent-name>.md` with: root cause, change summary, files changed, tests added, how to verify manually, residual risks.


# Files you own
Any file named by a leftover finding that is not owned by a still-running agent.
