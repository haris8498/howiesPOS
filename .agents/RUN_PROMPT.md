You are the ORCHESTRATOR. Do NOT implement any fix yourself and do not edit application code. Your only jobs are to spawn the agents defined in `.agents/*/agent.md` (as sub-agents, one per file, passing the full agent.md as its instructions), enforce the order below, merge branches, and run gate checks.

Context: Hungry Howie's POS (Flutter + Drift, NestJS + Prisma + PostgreSQL). Open items D-01..D-06 from `leftovers-backlog.md` must be fixed by the agents in `.agents/`. Before anything else, read the "Remediation Status" section at the end of `FINAL-SYNC-ENGINE-REPORT.md`: it lists what is already fixed. Those fixes are protected and must not regress; every agent must also append its own entry there when done.

Setup (you do this once):
1. Create an integration branch `integration/d-fixes` from the current main/dev branch.
2. For every agent create a git worktree + branch `fix/D-0X` (or `fix/VERIFY`) from the integration branch's latest state at the start of that agent's wave.

Execution plan:

WAVE 1 — spawn these 3 agents IN PARALLEL (one message, three sub-agents):
  - d02-table-soft-delete
  - d04-rollback-drain
  - d06-credential-security
  Wait for all three to finish. GATE 1: read each docs/fixes/D-0X-report.md, then merge fix/D-02, fix/D-04, fix/D-06 into integration/d-fixes (resolve only trivial conflicts; if two agents appended to the Remediation Status section, keep both entries), run `npx prisma validate`, `npm test`, `flutter analyze`, `flutter test`. If a gate fails, re-spawn the owning agent with the failure output; do not continue until green.

WAVE 2 — spawn IN PARALLEL (worktrees cut from the updated integration branch):
  - d05-order-line-item-ledger
  - d01-table-seating-overflow
  (They edit different model blocks of schema.prisma; tell them explicitly to keep to their own model.) Wait for both. GATE 2: merge D-05 first, then D-01; make sure the two migrations have correct timestamp ordering and `prisma migrate deploy` works on an empty DB; run the same test suites. Re-spawn on failure.

WAVE 3 — spawn SEQUENTIALLY (single agent, needs D-05 and D-06 merged):
  - d03-server-pricing-authority
  Wait. GATE 3: merge, run all suites.

WAVE 4 — spawn SEQUENTIALLY, last:
  - z-integration-verifier
  If it reports failures, re-spawn the owning fix agent with the failing scenario, merge, and re-run the verifier. Repeat at most 2 rounds, then stop and report.

Rules for you:
- Always use sub-agents for the work; never write fix code yourself.
- Never run two agents that touch the same schema.prisma model at the same time.
- Never merge to main. Leave everything on integration/d-fixes.
- After each gate, print a short status table (agent, branch, tests, status).
- At the end, print: the final status table, links to docs/fixes/*-report.md and FINAL-VERIFICATION.md, the final Remediation Status section, and any residual risks.

Start now with Setup, then Wave 1.
