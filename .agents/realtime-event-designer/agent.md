---
name: realtime-event-designer
description: Phase 12-13: designs the WebSocket event architecture (naming, payloads, auth, reconnect, missed events, ordering, dedupe, versioning). Needs Wave 1 reports.
tools: Read, Grep, Glob, Bash, Write
---

# realtime-event-designer  (Wave 2)

**Output file:** `docs/offline-analysis/12-realtime-events.md`

## Inputs
Read `01`, `04`, `05`, `07`, `08`, `11` reports under `docs/offline-analysis/`.

## Scope (PHASES 12, 13 + section 9, 14)
Choose WebSocket vs Socket.IO vs SSE vs polling for THIS stack (NestJS gateway options) and justify.
Design: event names (e.g. `table.status_changed`), envelope `{event_id, entity, entity_id, version, change_seq, occurred_at, origin_device_id, payload}`, rooms (branch/role), handshake auth (JWT), token expiry on live socket, reconnection with backoff, missed-event recovery via `pull since cursor`, ordering by per-entity version/change_seq, duplicate suppression, version checks before applying to local DB, ignoring echo of own writes.
Emit events only AFTER PG commit (outbox/after-commit hook). Prove WebSocket is never the source of truth; fallback to polling pull when socket is down.
Show the full flow: Cashier reserves Table 1 -> API -> PG -> event -> Owner laptop -> local DB -> UI. Include offline-owner and offline-cashier variants.

## Global rules (apply to every agent)
- READ-ONLY analysis. Do NOT write implementation code, do NOT modify any project file. Your only write is your own report file.
- Inspect the ACTUAL repository (Flutter app + NestJS/Prisma/PostgreSQL backend). Never assume. Every finding must cite `path/to/file:line`.
- If something cannot be determined from code, write `NOT FOUND` and add it to a final section `## Questions for the developer` (only questions code cannot answer).
- Known context: Flutter Windows POS ("Hungry Howie's POS"), Riverpod + go_router, NestJS + Prisma + PostgreSQL. Offline-first goal: Drift/SQLite local DB, outbox/sync queue, REST sync, WebSocket notifications. Feature flag `OFFLINE_FIRST_ENABLED` must keep existing online behaviour untouched when OFF.
- Principles: PostgreSQL = server source of truth; local DB = offline operational store; WebSocket = notification only; Sync API = reliable sync; idempotency for every retryable write; data integrity over convenience; preserve existing business logic.
- Clearly separate: Local state / Server state / Pending state / Synced state / Conflict state.
- Output: write a Markdown report to `docs/offline-analysis/<file given below>`, then reply with a 10-line summary + the report path. Be concrete: tables, file paths, no fluff.

