# Pilot Deployment Checklist
Before go-live:
- [ ] Every POS terminal runs Windows 10 build 1809+ or Windows 11 (DPAPI credential store fails at startup otherwise). [ENV-WINDOWS-VER]
- [ ] Server: `npx prisma migrate deploy` (3 new migrations: order_adjustments, shift cash refunds, MNY-06 late-synced fields).
- [ ] Server: run `npx ts-node scripts/wrap-legacy-hashes.ts --execute` once to upgrade inactive staff hashes to Argon2id. [SEC-LEGACY-WRAP]
- [ ] Confirm FeatureFlags.offlineFirstEnabled defaulting to true (no --dart-define) is the intended pilot mode, and build with the flag set explicitly. [FLG-DRIFT-01]
- [ ] Update one terminal holding unsynced orders from an older build; confirm it opens and pushes them (Drift v3 to v4).
- [ ] Run the 8-point pilot test (offline checkout x3 order types, offline void, offline staff switch, second register cold start, web edit visible on POS, refund with supervisor PIN, cross-shift cash refund, shift close with unsynced orders).
Known deferred (not fixed, see docs/sync-audit/fixes/leftovers-backlog.md): SEC-10 branch isolation, SYNC-037 db self-healing, TBL-04/05/06 offline table layout, SEC-09 staff attribution, TBL-11 conflict alert banner, ARCH-MISSING-02 device registration, SPEC-GAP-03 derived table status, SPEC-GAP-04 echo suppression (verify: origin_device_id is now recorded on REST change-log entries since Wave 5B, may be partly covered), and the low-severity items in the backlog.
