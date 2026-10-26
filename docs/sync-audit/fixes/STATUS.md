# POS Sync Engine Remediation Status

| Agent | Issue ID | Status | Commit Ref | Notes |
|---|---|---|---|---|
| `sync001-p2002-order-loss` | SYNC-001 | done | 669e8e5 | Fix P2002 unique constraint error handling (order_number & takeaway token) |
| `sync002-clear-errors-purge` | SYNC-002 | todo | - | Replace unsafe outbox wipe with Retry failed / Quarantine |
| `sync003-table-update-payments` | SYNC-003 | todo | - | Persist payments/discounts/taxes on offline table order update |
| `sync005-device-identity-shift` | SYNC-005 | todo | - | Dynamic device identity & terminal-scoped shift active index |
| `sync004-push-pull-sequencing` | SYNC-004 | todo | - | Mutex push-then-pull & state-aware delta application |
| `sync006-audit-leftovers-fixer` | Various | todo | - | Leftovers backlog (High & Medium findings) |
| `sync007-regression-verifier` | Verification | todo | - | Full test suite, flag-OFF regression, S1-S7 validation |
