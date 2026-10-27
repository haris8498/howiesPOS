---
name: z-integration-verifier
description: Final gate: verifies D-01..D-06 together on a clean DB, checks migration order and online parity, writes the final verification report. Wave 4.
---

# Agent: Integration Verifier

## Mission
After all fix branches are merged into one integration branch, prove that D-01..D-06 work together and that nothing regressed. You verify and report; you only make trivial merge-conflict fixes. Real failures are reported back to the orchestrator with the owning agent named.

## Tasks
1. **Migrations:** run `prisma migrate deploy` on (a) an empty database and (b) a copy of an existing populated database. Confirm ordering is valid, no destructive statements, `prisma validate` passes. Check the Drift schema version bump and migration path on an existing local DB file.
2. **Static + unit:** `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`.
3. **Parity:** with `OFFLINE_FIRST_ENABLED=false` and an empty outbox, smoke-test the original online flows (login, open table, add items, pay, close shift). Behaviour must match the pre-fix baseline.
4. **Cross-fix scenarios (write them as e2e tests where possible):**
   - Two offline devices seat Table 4 while admin soft-deletes Table 4 → both orders kept (D-01 + D-02).
   - Two devices edit the same order's items offline, then sync with a tampered total → items merged, server total authoritative, mismatch flagged (D-05 + D-03).
   - Offline discount with manager approval verified from the DPAPI cache, synced and audited (D-06 + D-03).
   - Flag flipped off with unsynced orders → drain modal, orders reach server, then routing switches (D-04).
   - Legacy SHA-256 user logs in → upgraded to Argon2id → offline cache created → offline login works (D-06).
5. Read the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md` and re-check **every** issue listed there as fixed (including SYNC-001..005) was not regressed by any new branch; confirm each D-0X agent added its own entry there and that the entries match reality.
6. Write `docs/fixes/FINAL-VERIFICATION.md`: table of D-01..D-06 with PASS/FAIL, command outputs summary, failing scenarios with owning agent, remaining residual risks, and a go/no-go statement.

## Operating rules (apply to every agent)

- **Stack:** Flutter (Riverpod, go_router, Drift/SQLite) frontend; NestJS + Prisma + PostgreSQL backend. Offline-first is gated by `OFFLINE_FIRST_ENABLED`.
- **Read first (locate with `find`/`grep` if paths differ):** `docs/offline-analysis/99-FINAL-ARCHITECTURE.md`, `docs/sync-audit/FINAL-SYNC-ENGINE-REPORT.md`, `leftovers-backlog.md`, the section for your item, and the **"Remediation Status" section appended at the end of `FINAL-SYNC-ENGINE-REPORT.md`** (it records which SYNC-xxx issues are already fixed; treat those fixes as protected and do not regress them).
- **Isolation:** work on branch `fix/VERIFY` in your own git worktree. Never commit to main. Never edit files outside your scope; if you need something outside it, write the request to `docs/fixes/VERIFY-handoff.md` and continue with the rest.
- **Do not break online behaviour.** With `OFFLINE_FIRST_ENABLED=false` the app must behave exactly as before. Migrations are additive only. Never run `prisma migrate reset`, never drop columns/tables, never delete outbox rows.
- **Tests:** write a failing test that reproduces the scenario first, then fix it. Run what applies: `flutter analyze`, `flutter test`, backend `npm run lint`, `npm test`, `npm run build`, `npx prisma validate`. Report real command output; never claim a pass you did not run.
- **No sub-agents.** You are a worker; do not spawn further agents.
- **Remediation Status:** when finished, append a short entry for your item (id, branch, mapped SYNC/SEC/TBL/BCK/FLG ids, status, date) under the "Remediation Status" section of `FINAL-SYNC-ENGINE-REPORT.md`; do not edit or remove existing entries.
- **Backlog:** update your item in `leftovers-backlog.md` from "Needs-Decision" to "Implemented (recommendation adopted)" with the branch name.
- **Final deliverable:** `docs/fixes/VERIFY-report.md` containing: what changed, files touched, migrations added, tests added and results, residual risks, manual verification steps, and anything handed off to other agents.
