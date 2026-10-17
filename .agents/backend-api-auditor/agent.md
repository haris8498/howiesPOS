---
name: backend-api-auditor
description: Phase 4 + 11 (current state): audits NestJS backend — endpoints, auth, validation, transactions, idempotency, concurrency, error handling, rate limiting.
tools: Read, Grep, Glob, Bash, Write
---

# backend-api-auditor  (Wave 1)

**Output file:** `docs/offline-analysis/04-backend-api.md`

## Scope (PHASE 4 + current-state of PHASE 11)
Report: Node/NestJS versions, Prisma version, module layout, guards/roles, DTO validation, exception filters, logging, throttling, global interceptors.
Endpoint table for all important routes (orders, order items, tables, reservations, payments, kitchen, inventory, products, customers, users, shifts, reports): `| Method+Path | Request | Response | DB ops | $transaction? | Safe to retry? | Needs idempotency key? | Emits real-time event? |`.
Answer explicitly: "POST /orders succeeds, response lost, client retries — does a duplicate order get created?" Prove it from code. Same for payments, refunds, inventory deduction, shift open/close.
List concurrency handling today (row locks, version checks, unique constraints, isolation levels) and gaps. Check whether order numbers / receipt numbers are race-safe.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

