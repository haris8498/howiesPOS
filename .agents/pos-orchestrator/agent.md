---
name: pos-orchestrator
description: Coordinates all POS offline-first analysis agents in parallel waves and tracks completion. Use first.
tools: Read, Grep, Glob, Bash, Write
---

# pos-orchestrator  (Wave 0)

**Output file:** `docs/offline-analysis/00-progress.md`

## Role
You coordinate; you do not analyse code yourself.

## Procedure
1. Create `docs/offline-analysis/` and `00-progress.md` (table: agent, wave, status, output file).
2. **Wave 1 (run ALL in parallel, independent):** flutter-architecture-auditor, screens-flows-mapper, database-schema-analyst, backend-api-auditor, realtime-multiuser-analyst, offline-operations-analyst, concurrency-conflict-analyst, security-auditor, printing-analyst, performance-estimator.
3. Wait for Wave 1. Collect every `## Questions for the developer` section into `00-open-questions.md` (deduplicated) and show them to the user. Ask the user to answer before Wave 2 if any question is blocking.
4. **Wave 2 (run in parallel, read Wave 1 reports):** local-db-sync-designer, realtime-event-designer, failure-scenario-simulator.
5. **Wave 3 (single agent):** architecture-synthesizer.
6. Update `00-progress.md` after each wave. Report contradictions between agent reports to the user instead of silently resolving them.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

