# Fix agents for open items D-01 .. D-06

Layout: `.agents/<agent-name>/agent.md`

| Agent | Item | Wave |
|---|---|---|
| d02-table-soft-delete | D-02 | 1 |
| d04-rollback-drain | D-04 | 1 |
| d06-credential-security | D-06 | 1 |
| d05-order-line-item-ledger | D-05 | 2 |
| d01-table-seating-overflow | D-01 | 2 |
| d03-server-pricing-authority | D-03 | 3 |
| z-integration-verifier | all | 4 |

Wave 1 runs in parallel, Wave 2 runs in parallel after Wave 1 is merged, Wave 3 runs after Wave 2 is merged, Wave 4 runs last.
See RUN_PROMPT.md for the orchestration prompt.
