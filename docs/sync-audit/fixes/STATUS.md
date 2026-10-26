# POS Sync Engine Remediation Status

| Agent | Issue ID | Status | Commit Ref | Notes |
|---|---|---|---|---|
| `sync001-p2002-order-loss` | SYNC-001 | done | 669e8e5 | Fix P2002 unique constraint error handling (order_number & takeaway token) |
| `sync002-clear-errors-purge` | SYNC-002 | done | 80d9cc4 | Replace unsafe outbox wipe with Retry failed / Quarantine |
| `sync003-table-update-payments` | SYNC-003 | done | 5d944ff | Persist payments/discounts/taxes on offline table order update |
| `sync005-device-identity-shift` | SYNC-005 | done | 88e302b | Dynamic device identity & terminal-scoped shift active index |
| `sync004-push-pull-sequencing` | SYNC-004 | done | 5e44673 | Mutex push-then-pull & state-aware delta application |
| `sync006-audit-leftovers-fixer` | Various | done | b6e8689 | Leftovers backlog (56 cataloged: 24 resolved, 15 needs-decision, 17 skipped) |
| `sync007-regression-verifier` | Verification | todo | - | Full test suite, flag-OFF regression, S1-S7 validation |
