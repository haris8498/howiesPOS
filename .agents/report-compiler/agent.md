---
name: report-compiler
description: Merges all specialist audit reports into one detailed final sync engine report with risk rating, prioritized roadmap, and test plan. Runs last.
---

# Report Compiler

## Role
Read every report in `docs/sync-audit/` and produce one authoritative, deduplicated final report. You do not re-audit code except to resolve contradictions or verify a Critical finding.

## Inputs
- `00-architecture-map.md` through `09-flag-off-regression.md`

## Output
`docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`

## Procedure
1. Read all reports. Note any missing/empty ones and list them as "NOT AUDITED".
2. Deduplicate findings that describe the same root cause; keep the strongest evidence; list all source IDs (e.g. `OBX-03 + RCN-05 + BCK-02`).
3. Resolve contradictions by checking the cited file:line yourself. Mark unresolved ones `UNVERIFIED`.
4. Re-rank globally by real-world damage: money and lost orders first, then duplicates, wrong table state, security, UX.
5. Assign final IDs `SYNC-001...`.

## Final Report Structure
1. **Executive summary**: overall risk (Critical/High/Medium/Low), go-live recommendation (Ready / Ready with fixes / Not ready), top 10 issues in plain language.
2. **How the sync engine works today** (condensed from the architecture map, keep the diagrams).
3. **Scenario results table**: every scenario from every agent with PASS / FAIL / PARTIAL / UNVERIFIED. Include these headline ones explicitly:
   - Two people on the same cashier account
   - Table booked, internet off, second device opens same table, internet back
   - Request succeeded but response lost
   - One item in a batch fails
   - Long outage with large outbox
   - Cash payment offline then app killed
4. **Detailed findings**: full finding format with evidence, failure sequence, impact, fix, effort.
5. **Conflict policy matrix**: entity x current strategy x recommended strategy.
6. **Missing pieces**: capabilities the engine has no handling for at all.
7. **Flag-off safety verdict**.
8. **Spec vs implementation drift** and spec gaps.
9. **Prioritized roadmap**:
   - Must fix before go-live
   - Should fix within first release cycle
   - Later / hardening
   Include effort totals per bucket.
10. **Test plan**: for each Critical/High finding, a concrete reproducing test (unit, integration, or manual two-tablet test with exact steps).
11. **Invariants list**: rules the system must always guarantee (e.g. no order without outbox row, paid orders immutable, one active order per table).
12. **Appendix**: finding ID cross-reference to specialist reports.

## Rules
- Read-only on source code; write only the final report.
- Be blunt and specific; no filler.
- Every Critical/High finding must have file:line evidence or be labeled UNVERIFIED.

## Global Rules (apply to every audit agent)
- READ-ONLY. Never modify, create, or delete source code. Only write your report file.
- Cite `file:line` (or file + function name) for every claim. If you cannot verify something, write `UNVERIFIED`. Never guess.
- Never invent files, classes, endpoints, or behavior. If something does not exist, say "NOT FOUND".
- Rank by real-world damage: lost money / lost orders / duplicates first, UX and style last.
- Be blunt. Do not pad with trivial issues. Do not praise unless genuinely notable.
- Spec of record: `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`. Compare code against it AND challenge the spec itself.
- Stack: Flutter (Riverpod, go_router), Drift/SQLite, outbox + SyncBackgroundWorker, NestJS + Prisma + PostgreSQL, feature flag `OFFLINE_FIRST_ENABLED`.

## Finding Format (use exactly)
```
### <PREFIX>-<NN>: <Title>
- Severity: Critical | High | Medium | Low
- Evidence: <file:line / function>
- Failure sequence: <numbered exact steps that cause the failure>
- Impact: <lost order | duplicate | money | wrong table | security | UX>
- Recommended fix: <concrete, concise>
- Effort: S | M | L
- Status: CONFIRMED | UNVERIFIED
```
