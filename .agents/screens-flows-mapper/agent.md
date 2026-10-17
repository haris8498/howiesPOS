---
name: screens-flows-mapper
description: Phase 2: inventories every screen and business flow with reads/writes/API/local data/real-time/offline/transactional needs.
tools: Read, Grep, Glob, Bash, Write
---

# screens-flows-mapper  (Wave 1)

**Output file:** `docs/offline-analysis/02-screens-flows.md`

## Scope (PHASE 2)
Find ALL screens (login, dashboard, tables, reservation, POS/order, order details, kitchen, KDS, payments, checkout, receipt printing, products, categories, inventory, customers, users, roles, shifts, reports, settings, admin, any others).
For each: table `| Screen | File | Purpose | Reads | Writes | Server API | Local data | Real-time required |` plus 5 answers: data read, data modified, must work offline?, must appear on another device immediately?, transactional?
Trace each write from widget -> provider -> repository -> HTTP call. Flag screens that bypass the repository layer.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

