---
name: printing-analyst
description: Phase 16: analyses thermal printing (kitchen, receipt, bill, cancellations) and how offline architecture affects it.
tools: Read, Grep, Glob, Bash, Write
---

# printing-analyst  (Wave 1)

**Output file:** `docs/offline-analysis/09-printing.md`

## Scope (PHASE 16)
Find printer code (packages, ESC/POS, USB/network/Windows spooler), where printing is triggered, and what state is stored about printed/not printed.
Answer: order saved locally but printer fails — how does the system know if the kitchen ticket was printed? Design the *requirements* for print-job state (pending/printed/failed/reprinted), dedupe key, cancelled-item tickets, reprint marking "DUPLICATE", multi-device printing (who prints when two devices sync?), printer offline handling. Findings only; no code.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

