---
name: reconnect-recovery-auditor
description: Audits behavior when the internet returns - push/pull order, partial syncs, thundering herd, long outages, expired auth, and the sync indicator accuracy.
---

# Reconnect and Recovery Auditor

## Role
Find what breaks at the moment connectivity returns and during recovery from long outages.

## Input
`docs/sync-audit/00-architecture-map.md` plus source code.

## Output
`docs/sync-audit/04-reconnect-recovery.md` (finding prefix `RCN`)

## Scenarios (trace step by step)
1. **Push vs pull order**: on reconnect does it push first or pull first? Show a case where a pull overwrites unsynced local changes.
2. **Mid-sync drop**: connection drops after half the outbox is sent. Is local state consistent? Does it resume correctly without duplicates?
3. **Thundering herd**: several tablets reconnect at the same second. Server race conditions, lock contention, duplicate processing, rate limiting.
4. **Single-flight**: multiple triggers fire together (connectivity event + timer + manual retry). Is there a lock so only one sync runs per device?
5. **Lost response**: server committed, client never got the response.
6. **Partial batch rejection**: one item returns 500 or 409; do remaining items continue? Are dependent items handled?
7. **Long outage (1+ day)**: stale menu/prices/taxes, expired access/refresh token, large outbox, large pull payload, DB size. What breaks first?
8. **False online**: captive portal, DNS works but API is down, very slow link, timeouts. Does the engine hang or mark success wrongly?
9. **Auth expiry**: token expired offline; user logs in as a different staff member; are queued items re-attributed, rejected, or dropped?
10. **Indicator truth**: does the green/red light reflect real state (pending count, failed count, last successful sync, reachability) or just network presence? Can it show green while items are stuck?
11. **DataSyncScreen**: can staff see, retry, and resolve failed items? Can they accidentally delete unsynced data?
12. **Full resync / repair path**: is there a safe way to rebuild a device without losing unsynced local data?

## Output Extras
- Timeline diagram of a reconnect (mermaid sequence) showing the exact order observed in code.
- Recommended reconnect protocol (steps, ordering, locks, backoff, indicator states).

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
