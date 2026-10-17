---
name: failure-scenario-simulator
description: Phase 14: simulates all 15 failure scenarios step by step against the designed architecture. Needs Wave 1 + designer reports.
tools: Read, Grep, Glob, Bash, Write
---

# failure-scenario-simulator  (Wave 2)

**Output file:** `docs/offline-analysis/13-failure-scenarios.md`

## Inputs
Read all Wave 1 reports plus `11-local-db-and-sync.md` (and `12-realtime-events.md` if present).

## Scope (PHASE 14 + final-output sections 11-15)
For each of the 15 cases (normal, sudden loss, very slow, return after 30 min, loss during checkout, response lost, two POS same table, two POS last item, cashier offline/owner online, owner offline/cashier online, both offline, server down, crash during sync, Windows power loss, same op retried 5x) write: Precondition -> step-by-step what happens on Local DB / Outbox / API / PG / WebSocket / UI -> final converged state -> what the user sees -> which mechanism guarantees safety (idempotency, transaction, version, unique constraint, WAL/SQLite durability).
Also deliver: Offline flow, Online flow, Reconnection flow, Multi-device flow, Failure handling summary. Flag any scenario where the current design is NOT safe and propose the fix.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

