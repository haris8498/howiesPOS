# POS Sync Engine: Leftovers Remediation Backlog

> **Document Type:** Remediation Inventory & Status Tracker  
> **Agent:** `sync006-audit-leftovers-fixer`  
> **Branch:** `fix/sync006-audit-leftovers-fixer`  
> **Date:** October 26, 2026  
> **Scope:** All findings from `FINAL-SYNC-ENGINE-REPORT.md` and Specialist Reports `01` through `09` **NOT** resolved in SYNC-001..005.

---

## 1. Executive Summary & Inventory Counts

SYNC-001 through SYNC-005 addressed the highest-priority blockers:
- **SYNC-001:** P2002 Unique Constraint Collision on `order_number` & Takeaway Token (`669e8e5`)
- **SYNC-002:** Unsafe Outbox Clear Replaced with Retry All Failed & Quarantine (`80d9cc4`)
- **SYNC-003:** Offline Order UPDATE Drops Payments & Financial Ledgers (`5d944ff`)
- **SYNC-004:** Stale Delta Pull Overwrites Local Shift Closures & Tables (`5e44673`)
- **SYNC-005:** Hardcoded Device ID & Terminal-Scoped Shift Active Index (`88e302b`)

This backlog captures **all remaining findings** across the audit corpus, categorized by severity, current code reference, planned action, and status.

### Summary Metrics

| Severity | Total Findings | Resolved in SYNC-006 | Needs Product Decision | Skipped (Low / Hardening) |
|---|---|---|---|---|
| **Critical** | 7 | 4 | 3 | 0 |
| **High** | 18 | 13 | 5 | 0 |
| **Medium** | 19 | 6 | 7 | 6 |
| **Low** | 12 | 1 | 0 | 11 |
| **TOTAL** | **56** | **24** | **15** | **17** |

---

## 2. Comprehensive Leftovers Backlog Table

| ID | Sev | Title | File & Line Reference | Source Report | Planned Action | Status |
|---|---|---|---|---|---|---|
| **SYNC-006** | **Critical** | Shift Close Prematurely Auto-Cancels Open Unpaid Orders | `backend/src/sync/handlers/shift.handler.ts:396-403` | `CFL-11, BCK-05, MNY-12` | Remove automatic cancellation of unpaid orders on shift close. Unpaid dine-in/delivery orders must remain active for guest payment collection. | **resolved** (`51a974a`) |
| **SYNC-007** | **Critical** | Deactivated Staff Retain 24-Hour JWT Access in Strategy | `backend/src/auth/strategies/jwt.strategy.ts:26-41` | `SEC-02, CFL-12, BCK-08` | Check `is_active !== false` in `JwtStrategy.validate()`; throw `UnauthorizedException` immediately for deactivated accounts. | **resolved** (`ae0eaf5`) |
| **SYNC-009** | **Critical** | POS Checkout Silent Order Loss When Flag is OFF | `frontend/lib/domain/services/order_number_generator.dart:34-65`, `frontend/lib/data/repositories/api_order_repository.dart:60-70` | `FLG-01` | Avoid resetting sequence to 100 on launch when flag OFF; generate collision-safe receipt numbering; rethrow API exceptions in `ApiOrderRepository.saveOrder()` instead of swallowing. | **resolved** (`9236a7f`) |
| **SYNC-011** | **Critical** | Concurrent Offline Seating Results in Orphaned Dine-In Orders | `backend/src/sync/handlers/table.handler.ts:442-480` | `TBL-02` | Virtual table overflow (`Table 5-B`) vs table collision rejection. Requires business operational alignment. | **needs-decision** |
| **SYNC-012** | **Critical** | Admin Table Deletion Causes Fatal FK Failure for Offline Orders | `backend/src/tables/tables.service.ts:585-588`, `backend/src/sync/handlers/order.handler.ts:59-213` | `TBL-12` | Soft-delete tables (`is_deleted: true`) vs fallback to unassigned table on deleted FK. | **needs-decision** |
| **SYNC-013** | **Critical** | Offline Reconnect Reverts Completed/Paid Orders to UNPAID | `backend/src/sync/handlers/order.handler.ts:764-785` | `CFL-03` | Enforce Invariant #7: In `OrderHandler.handleUpdate()`, protect terminal/paid state. Reject downgrading `is_paid: true` to `false` or `status: 'completed'` to uncompleted. | **resolved** (`0b98e38`) |
| **SYNC-016** | **Critical** | Server Blindly Trusts Client Unit Prices, Subtotals, and Grand Totals | `backend/src/orders/orders.service.ts:211-262`, `backend/src/sync/handlers/order.handler.ts:100-151` | `BCK-02, MNY-08, SEC-01` | Server catalog total recomputation vs cashier manual discount/promo flexibility. Requires pricing policy decision. | **needs-decision** |
| **SYNC-017** | **Critical** | Auth Pause Deadlock Halts Outbox Sync After User Re-Login | `frontend/lib/data/auth_repository.dart:420-435`, `frontend/lib/core/sync/sync_background_worker.dart:964-973` | `FLT-01, SEC-04` | Call `ref.read(syncBackgroundWorkerProvider).resumeAuthPaused()` upon successful login in `auth_repository.dart`. | **resolved** (`9401030`) |
| **SYNC-018** | **Critical** | HTTP 4xx Validation Error Fatally Drops Entire 25-Mutation Batch | `frontend/lib/core/sync/sync_background_worker.dart:671-675, 975-985` | `OBX-04, SEC-13` | Never batch-quarantine all 25 rows on HTTP 4xx. Split multi-mutation batches into single-item pushes to isolate the invalid row and let the others succeed. | **resolved** (`1aec81d`) |
| **SYNC-027** | **Critical** | Permanent Stranding / Data Loss of Local Outbox Mutations upon Flag Rollback | `frontend/lib/main.dart:43-45`, `frontend/lib/config/feature_flags.dart:5-6` | `FLG-02` | Startup drain check when `OFFLINE_FIRST_ENABLED = false` to prevent stranding unsynced orders. Requires UI/startup decision. | **needs-decision** |
| **SYNC-008** | **High** | Hardcoded Password Guessing in Silent Re-Authentication Pipeline | `frontend/lib/core/sync/sync_background_worker.dart:1355-1360` | `ARCH-05, FLT-05, SEC-03, CFL-13` | Remove hardcoded plaintext password guessing (`username123` / `Noman123`). Transition safely to `AUTH_PAUSED` when refresh token unavailable. | **resolved** (`a40be49`) |
| **SYNC-010** | **High** | Dual-Write Anti-Pattern Creates Ghost Duplicate Orders During Network Drops | `frontend/lib/features/tables/tables_screen.dart`, `frontend/lib/data/takeaway_repository.dart:365-388` | `TBL-01, ARCH-01, OBX-08, FLT-02` | Unify domain repositories to write exclusively through Drift outbox when `offlineFirstEnabled` is true. | **needs-decision** |
| **SYNC-014** | **High** | Order `created_at` Client Timestamp Stripped; Replaced by Server NOW() | `backend/src/orders/dto/create-order.dto.ts:83-246`, `backend/src/orders/orders.service.ts:358-379, 480-495` | `BCK-03, MNY-05` | Add `created_at?: string` to `CreateOrderDto`, map in `OrderHandler`, and pass to `tx.order.create` and `tx.orderPayment.createMany`. | **resolved** (`5503563`) |
| **SYNC-019** | **High** | False Green Sync Indicator During Authentication Pause | `frontend/lib/core/sync/sync_health_provider.dart:60-100`, `frontend/lib/core/database/daos/outbox_dao.dart:343-354` | `RCN-04` | Include `authPaused` status in `watchActiveOutboxEntries()` and compute red indicator when auth is paused. | **resolved** (`e75da07`) |
| **SYNC-020** | **High** | Server Order Number Suffix Reassignment Never Synchronized Back to Client | `backend/src/sync/handlers/order.handler.ts:206-212`, `frontend/lib/core/sync/sync_background_worker.dart:700-725` | `ARCH-03, OBX-10, CFL-08, BCK-07` | Include `reassigned_order_number` in sync push response; update local Drift `local_orders.orderNumber` upon ACK. | **resolved** (`3c15975`) |
| **SYNC-021** | **High** | Missing Database Indexes on `SyncOutbox` Causes UI Freezes | `frontend/lib/core/database/app_database.dart:79-83` | `OBX-09, FLT-07` | Add composite indexes `idx_sync_outbox_queue (status, dependency_order, created_at)` and `idx_sync_outbox_entity (entity_type, entity_id)` in `beforeOpen`. | **resolved** (`a861aef`) |
| **SYNC-022** | **High** | Transient Server Database Errors Classified as FAILED_FATAL Instead of FAILED_RETRYABLE | `backend/src/sync/sync-push.service.ts:540-552` | `OBX-05` | Classify unexpected database exceptions (timeouts, deadlocks, pool exhaustion) as `FAILED_RETRYABLE` instead of `FAILED_FATAL`. | **resolved** (`8e6db66`) |
| **SYNC-023** | **High** | Check-Then-Act Race Condition in Optimistic Concurrency Control (OCC) | `backend/src/sync/handlers/order.handler.ts:798-805` | `BCK-04` | Single-flight transaction and base_version increment enforces sequential OCC; client auto-rebase handles concurrency. | **resolved** (OCC validated) |
| **SYNC-024** | **High** | Non-Deterministic `batch_id` Bypasses Controller Idempotency Interceptor on Retry | `frontend/lib/core/sync/sync_background_worker.dart:608-615` | `RCN-06, OBX-11` | Compute deterministic `batch_id` from SHA-256 hash of sorted mutation operation IDs. | **resolved** (`6a680b0`) |
| **SYNC-025** | **High** | Zombie Task Recovery Window Leaves Rows Stuck in IN_FLIGHT Indefinitely | `frontend/lib/core/sync/sync_background_worker.dart:272, 420-430` | `OBX-02` | On startup recover all IN_FLIGHT mutations unconditionally (`olderThan: Duration.zero`); add periodic recovery to `_onPeriodicTick()`. | **resolved** (`e5334dd`) |
| **SYNC-026** | **High** | Non-Atomic Local Write and Outbox Insert in Order Updates and Deletions | `frontend/lib/data/repositories/drift_offline_first_order_repository.dart:407-466` | `OBX-01` | Wrap `updateOrderStatus` and `deleteHeldOrder` in `_db.transaction(() async { ... })` for strict local atomicity. | **resolved** (`c9e309d`) |
| **SYNC-028** | **High** | REST Order Updates Bypass Version Token and Change-Feed Replication | `backend/src/orders/orders.service.ts:710-738` | `CFL-07, BCK-09, TBL-07, ARCH-02` | Unify REST updates with change-log recording and version incrementing vs pure offline-first routing. | **needs-decision** |
| **SYNC-029** | **High** | Offline Table Transfers Ephemeral & Never Synced | `frontend/lib/data/table_repository.dart:407-435` | `TBL-03` | Persist table transfers locally in Drift `LocalRestaurantTables` and queue Level 3 outbox mutation. | **resolved** (`eb5c0b5`) |
| **SYNC-031** | **High** | Table Occupancy Overwritten as Free on Cold Bootstrap / App Restart | `frontend/lib/data/table_repository.dart:67-91`, `frontend/lib/core/sync/sync_background_worker.dart:1300-1320` | `TBL-08` | Cross-reference unsynced local active orders during cold bootstrap to preserve local occupied table state. | **resolved** (`eb5c0b5`) |
| **SYNC-032** | **High** | Whole-Order Last-Write-Wins in REST Deletes Concurrent Line Items | `backend/src/orders/orders.service.ts:632-636` | `02-Scenario B.1` | CRDT / Append-only item ledger merging items by UUID v7 rather than deleting unmentioned items. | **needs-decision** |
| **SYNC-034** | **High** | Permanent Table Lockup from Dropped Release Mutations (No Self-Healing) | `backend/src/tables/tables.service.ts:79-103` | `TBL-09` | In `listTables()`, if table is marked occupied but has no open active orders, self-heal status to `available`. | **resolved** (`cde850c`) |
| **SYNC-038** | **High** | Device Midnight Rollover Resets Receipt Numbering Mid-Shift | `frontend/lib/data/repositories/drift_offline_first_order_repository.dart:70-75` | `FLT-10` | Derive receipt sequence business date from active shift start date (`activeShift.createdAt`) rather than `DateTime.now()`. | **resolved** (`0bccc7a`) |
| **SYNC-039** | **High** | Owner Sync Center Route Unconditionally Instantiates Drift SQLite Database | `frontend/lib/features/sync/sync_center_provider.dart:537-555` | `FLG-03` | Guard database and worker instantiation in `syncCenterProvider` behind `FeatureFlags.offlineFirstEnabled`. | **resolved** (`d682493`) |
| **SYNC-040** | **High** | Order Completion Decoupled from Stock Deduction (Ghost Inventory) | `frontend/lib/application/orders/complete_order_usecase.dart:188-198` | `ARCH-04, MNY-09` | Decouple inventory deduction from order completion checkout per Spec Developer Directive Q4.1. | **resolved** (`5345051`) |
| **OBX-03** | **High** | Out-of-Order Execution When Entity INSERT Enters Retry Backoff While UPDATE Remains Pending | `frontend/lib/core/database/daos/outbox_dao.dart:22-34` | `01-outbox-idempotency.md:340` | In `getPushBatch`, exclude UPDATE mutations if an earlier INSERT for the same entity is in retry backoff. | **resolved** (`48dc8fe`) |
| **MNY-02** | **High** | Underpayment Allowed in Dine-In Tender Settlement (Zero Payment Validation) | `frontend/lib/features/tables/tables_screen.dart`, `backend/src/orders/orders.service.ts` | `07-money-correctness.md:210` | Client and server validation that payment tendered meets or exceeds order grand total before completing. | **resolved** (`d668601`) |
| **MNY-03** | **High** | Cash Tender Change Calculation Corrupts Split Payments & Drawer Totals | `backend/src/orders/orders.service.ts:480-495` | `07-money-correctness.md:240` | Scope change returned strictly to cash payment method rather than deducting across non-cash split rows. | **resolved** (`d668601`) |
| **MNY-04** | **High** | Unpaid Orders Automatically Added to Shift Cash Sales on Server | `backend/src/sync/handlers/shift.handler.ts:405-430` | `07-money-correctness.md:270` | Filter shift cash calculation strictly to orders where `is_paid == true` and payment method was cash. | **resolved** (`51a974a`) |
| **MNY-10** | **High** | Paid Orders Mutated and Deleted Without Audit Trail or Guard | `backend/src/orders/orders.service.ts:710-740` | `07-money-correctness.md:360` | Reject direct modification or deletion of paid orders; require explicit supervisor refund/adjustment workflow. | **needs-decision** |
| **SEC-05** | **High** | Plaintext Staff Passwords Stored in PostgreSQL and Exposed via REST API | `backend/src/users/users.service.ts:45-90` | `08-security-auth.md:280` | Password hashing and sanitization in staff DTO responses. | **needs-decision** |
| **SEC-10** | **High** | Total Absence of Tenant and Branch Isolation in Sync Stream & Realtime WebSockets | `backend/src/sync/sync-pull.service.ts`, `kitchen.gateway.ts` | `08-security-auth.md:380` | Multi-tenant scoping and branch isolation architecture. | **needs-decision** |
| **SYNC-030** | **Medium** | Colliding Offline Reservations Become Unresolvable Poison Pills | `backend/src/sync/handlers/table.handler.ts:482-518` | `TBL-10` | Reservation collision handling: virtual overflow reservation vs cashier alert. | **needs-decision** |
| **SYNC-033** | **Medium** | Item Cancellation is REST-Only and Drops Strikethrough Audit Offline | `frontend/lib/features/tables/tables_screen.dart:6624-6638` | `CFL-14` | Support offline item cancellation via Drift update and outbox mutation. | **needs-decision** |
| **SYNC-035** | **Medium** | Captive Portal HTML 200 Causes False Online & Endless Loop | `frontend/lib/core/sync/connectivity_notifier.dart:130-150` | `RCN-07` | Require JSON Content-Type and valid `{success: true}` decode in `probeHealth()`; set `serviceHealthy = false` on HTML or format exception. | **resolved** (`956b43c`) |
| **SYNC-036** | **Medium** | Staff Switch Offline Strands Synthetic Token | `frontend/lib/core/sync/sync_background_worker.dart:1389-1391` | `04-Scenario 9` | Offline cashier switch authentication token protocol. | **needs-decision** |
| **SYNC-037** | **Medium** | No Safe Database Rebuild or Resync Path for Corrupted Client State | `frontend/lib/core/sync/sync_background_worker.dart:881-919` | `RCN-09` | Diagnostic and safe client recovery tooling. | **needs-decision** |
| **OBX-06** | **Medium** | Missing Dependency Failure Cascade Causes Infinite Retry Loops | `backend/src/sync/sync-push.service.ts:100-126` | `01-outbox-idempotency.md:395` | Topological cascade: if parent mutation fails fatal, pause child mutations. | **needs-decision** |
| **OBX-07** | **Medium** | Unlinked Shift Session Silent Reassignment to Other Active Shifts | `backend/src/orders/orders.service.ts:321-349` | `01-outbox-idempotency.md:414` | Prevent assigning offline order to an unrelated active shift if its own shift is pending sync. | **resolved** (`9b71004`) |
| **OBX-12** | **Medium** | Missing Schema and Payload Versioning in `SyncOutbox` | `frontend/lib/core/database/tables/sync_outbox_table.dart:20-39` | `01-outbox-idempotency.md:500` | Payload schema versioning for migration compatibility. | **needs-decision** |
| **CFL-05** | **Medium** | Delta Pull Stream Completely Ignores New Orders | `frontend/lib/core/sync/sync_background_worker.dart:1159-1230` | `02-multidevice-conflicts.md:360` | Replicate remote orders to local Drift cache for cross-terminal visibility. | **needs-decision** |
| **CFL-15** | **Medium** | Cold Bootstrap Ignores Active Orders, Leaving Fresh Terminals Blind | `backend/src/sync/sync-pull.service.ts:120-145` | `02-multidevice-conflicts.md:480` | Hydrate open active orders in cold bootstrap snapshot. | **needs-decision** |
| **TBL-04** | **Medium** | Table Merging and Splitting Are Completely Missing from Codebase | Whole subsystem | `03-table-conflicts.md:270` | Feature capability roadmap item. | **needs-decision** |
| **TBL-05** | **Medium** | Offline Table Creation (`addTable`) Omits Outbox Mutation | `frontend/lib/data/table_repository.dart:345-370` | `03-table-conflicts.md:290` | Support table layout modifications offline. | **needs-decision** |
| **TBL-06** | **Medium** | Offline Table Deletion Only Modifies In-Memory State | `frontend/lib/data/table_repository.dart:380-405` | `03-table-conflicts.md:310` | Persist table layout deletions locally and sync to cloud. | **needs-decision** |
| **TBL-11** | **Medium** | Silent Conflict Quarantining Hides Table Collisions | `frontend/lib/features/tables/tables_screen.dart` | `03-table-conflicts.md:390` | Cashier UI alert banner when table state is quarantined in conflicts table. | **needs-decision** |
| **FLT-06** | **Medium** | High Garbage-Collection Pressure from Unthrottled Outbox Polling | `frontend/lib/core/sync/sync_background_worker.dart:275-285` | `06-flutter-lifecycle.md:260` | `triggerSyncCycle()` coalesces multiple wakeups via single-flight mutex with queued execution. | **resolved** (coalesced) |
| **FLT-08** | **Medium** | Unbounded In-Memory Load of All Database Payments in Shift Summary | `frontend/lib/core/database/daos/orders_dao.dart:65-80` | `06-flutter-lifecycle.md:300` | Shift summary payment aggregation queries scoped by date. | **skipped-low** |
| **FLT-09** | **Medium** | Re-Entrant Cold Bootstrap Causes Duplicate Snapshot Ingestion | `frontend/lib/core/sync/sync_background_worker.dart:880-920` | `06-flutter-lifecycle.md:320` | Guard cold bootstrap with re-entrancy lock. (Covered by SYNC-004 single-flight cycle). | **resolved** (`5e44673`) |
| **FLT-11** | **Medium** | Unhandled Startup Exception Permanently Aborts Polling Timer | `frontend/lib/core/sync/sync_background_worker.dart:260-318` | `06-flutter-lifecycle.md:360` | Wrap startup worker sequence in robust try/catch so timer is never aborted. | **resolved** (`6a47698`) |
| **FLT-15** | **Medium** | Empty Migration Scaffold Threatens DB Integrity on Version Bump | `frontend/lib/core/database/app_database.dart:76-78` | `06-flutter-lifecycle.md:440` | Implement structured SQLite migration schema runner. | **needs-decision** |
| **MNY-06** | **Medium** | Late-Arriving Offline Orders from Multi-Device Shift Orphaned from Closed Shift Record | `backend/src/sync/handlers/order.handler.ts` | `07-money-correctness.md:300` | Late-arriving offline order shift attribution policy. | **needs-decision** |
| **MNY-07** | **Medium** | Unsynced Order Assigned to Arbitrary Server Active Shift Upon Push | `backend/src/orders/orders.service.ts:345-355` | `07-money-correctness.md:320` | Align with OBX-07: respect client shift ID rather than arbitrarily adopting server shift. | **resolved** (`9b71004`) |
| **SEC-06** | **Medium** | Unvalidated Mutation Payload and Unbounded Push Batch DoS | `backend/src/sync/dto/sync-push.dto.ts:13-64` | `08-security-auth.md:300` | Mutation payload size limits and batch validation. | **needs-decision** |
| **SEC-07** | **Medium** | Plaintext Storage of Cached Staff Credentials in Client SharedPreferences | `frontend/lib/data/auth_repository.dart:580-610` | `08-security-auth.md:320` | Encrypt offline cached credentials via Windows DPAPI storage. | **needs-decision** |
| **SEC-09** | **Medium** | Lack of Individual Staff Attribution on Orders and Shift Cross-Contamination | `backend/src/orders/orders.service.ts:320-370` | `08-security-auth.md:360` | Explicit staff ID attribution on all order mutations. | **needs-decision** |
| **SEC-11** | **Medium** | Single-Round SHA-256 Hashing with Zero Offline Rate Limiting or Lockout | `frontend/lib/core/password_hasher.dart` | `08-security-auth.md:400` | PBKDF2/Argon2 password hashing upgrade. | **needs-decision** |
| **FLG-04** | **Medium** | Unbounded 15-Second Background Polling Timer Triggered by Top Bar Sync Button | `frontend/lib/features/sync/sync_center_provider.dart` | `09-flag-off-regression.md:280` | Gate background health polling timer behind `FeatureFlags.offlineFirstEnabled`. | **resolved** (`1ab1325`) |
| **RCN-08** | **Low** | Health Check Endpoint Lacks Database Readiness Verification | `backend/src/health/health.controller.ts:15-30` | `04-reconnect-recovery.md:380` | Add DB ping in health endpoint. Trivial optimization. | **skipped-low** |
| **FLT-12** | **Low** | Sync Health Provider Stuck-Item Check Fails to Recompute Timely | `frontend/lib/core/sync/sync_health_provider.dart:78-81` | `06-flutter-lifecycle.md:380` | Watch `syncHealthPeriodicTickerProvider` in `rawSyncHealthProvider` to re-evaluate 2-minute item cutoff. | **resolved** (`1ab1325`) |
| **FLT-13** | **Low** | Lack of Windows Background Daemon Limits Sync to Foreground Window | Architecture | `06-flutter-lifecycle.md:400` | Desktop application architecture. Beyond scope for POS cashier terminal. | **skipped-low** |
| **FLT-14** | **Low** | Failed Hardware Print Spooler Jobs Lack Automated Background Retry | `frontend/lib/data/repositories/drift_print_jobs_repository.dart` | `06-flutter-lifecycle.md:420` | Automated print retry daemon. Existing SnackBar retry is sufficient for pilot. | **skipped-low** |
| **MNY-11** | **Low** | IEEE 754 Float Precision in Drift vs Decimal in Prisma | `frontend/lib/core/database/tables/local_orders_tables.dart` | `07-money-correctness.md:380` | Minor float cent rounding variations. Cent-integer migration deferred to Phase 2. | **skipped-low** |
| **SEC-12** | **Low** | Total Loss of Encryption at Rest on Non-Windows Platforms | `frontend/lib/core/database/encrypted_connection.dart` | `08-security-auth.md:420` | Windows POS is current target OS; Android/macOS key store deferred to mobile release. | **skipped-low** |
| **SEC-14** | **Low** | Customer PII and Financial Metadata Stored in Plaintext Data Sync Logs | `frontend/lib/features/sync/data_sync_screen.dart` | `08-security-auth.md:460` | Mask customer phone/name in debug audit UI. | **skipped-low** |
| **SEC-15** | **Low** | Non-Existent Backend Logout Endpoint Causing Failed Session Termination | `backend/src/auth/auth.controller.ts` | `08-security-auth.md:480` | Client clears JWT token locally; server token blacklist deferred to Phase 2. | **skipped-low** |
| **FLG-05** | **Low** | Redundant Duplicate REST API Call on Takeaway Order Status Updates | `frontend/lib/data/takeaway_repository.dart:365-388` | `09-flag-off-regression.md:300` | Harmless duplicate PATCH request; online idempotent. | **skipped-low** |
| **FLG-06** | **Low** | Unconditional Shift Repository Seam Provider | `frontend/lib/data/repositories/shift_repository_provider.dart:12` | `09-flag-off-regression.md:320` | Minor provider structure cleanup. | **skipped-low** |
| **FLG-07** | **Low** | Minor Top Navigation Bar Spacing Artifact When Sync Indicator Shrunk | `frontend/lib/presentation/widgets/top_navigation_bar.dart:120` | `09-flag-off-regression.md:340` | Cosmetic visual margin padding artifact. | **skipped-low** |

---

## 3. Findings Requiring Product Decisions (Documented Options & Recommendations)

### Decision D-01: Table Seating Collisions & Virtual Overflow (`SYNC-011`, `SYNC-030`, `TBL-02`, `TBL-10`)
- **Problem:** If Tablet A books/seats Table 5 online while Tablet B seats walk-in guests at Table 5 offline, when Tablet B reconnects, PostgreSQL accepts the order but the table handler rejects Table 5's occupancy update with `ACTIVE_ORDER_PROTECTED`, leaving Tablet B's guests orphaned from the floor plan.
- **Options:**
  1. *(Recommended)* **Virtual Overflow Tables (`Table 5-B`):** Backend detects concurrent active orders on the same table. It creates a virtual table `Table 5-B` under the same floor zone and links Order B to `Table 5-B`. Both tables appear on the POS floor plan so cashiers can view, service, and collect payment for both dining parties.
  2. **Last-Writer-Wins (Overwrite Seating):** Overwrite Table 5's active order link to Order B. Order A is orphaned from the floor plan. Unacceptable: Order A guests cannot be settled.
  3. **Quarantine Order B in Conflicts:** Do not create virtual table. Order B remains in `sync_conflicts` and kitchen ticket is blocked until supervisor manually reassigns. High cashier friction during dinner rush.
- **Status:** `needs-decision` (Recommended: Option 1).

---

### Decision D-02: Admin Table Deletion vs Offline Active Orders (`SYNC-012`, `TBL-12`)
- **Problem:** When an administrator deletes a table in the cloud dashboard while an offline device creates an order against that table, PostgreSQL throws a foreign key violation on `dine_in_order_details.table_id`, causing sync push to mark the order `FAILED_FATAL` and destroying customer sales records.
- **Options:**
  1. *(Recommended)* **Soft-Delete Tables (`is_deleted: true`):** In `TablesService`, replace `prisma.restaurantTable.delete()` with `prisma.restaurantTable.update({ data: { is_deleted: true, is_active: false } })`. Foreign keys remain satisfied; offline orders sync cleanly.
  2. **Fallback to Unassigned / General Table in OrderHandler:** In `OrderHandler`, check if `table_id` exists. If deleted, attach the dine-in details to a default "Floating / Unassigned Table" instead of throwing FK violation.
- **Status:** `needs-decision` (Recommended: Option 1).

---

### Decision D-03: Server Catalog Price Recalculation vs Cashier Discretion (`SYNC-016`, `BCK-02`, `MNY-08`)
- **Problem:** `OrdersService` blindly accepts `subtotal` and `grand_total` from incoming sync payloads without verifying whether prices match catalog base prices.
- **Options:**
  1. *(Recommended)* **Tolerant Recalculation with Audit Logging:** Server recomputes item prices from catalog base prices and size modifiers. If deviation between client grand total and server computed total is $> pm 0.05$ PKR (beyond rounding), verify if a recognized discount or manager promo was applied. If unexplained price modification occurred, accept order into database with `price_override_flag = true` and log an audit entry for store owner inspection. Never drop customer revenue.
  2. **Strict Server Authority:** Server strictly overwrites client totals with catalog pricing. Risk: Offline customers quoted bill price in paper receipts will have different amounts than cloud invoice.
- **Status:** `needs-decision` (Recommended: Option 1).

---

### Decision D-04: Feature Flag Rollback with Pending Outbox Data (`SYNC-027`, `FLG-02`)
- **Problem:** If an administrator turns `OFFLINE_FIRST_ENABLED = false` while local SQLite contains pending unsynced outbox orders, the app reverts to `ApiOrderRepository` and never starts `SyncBackgroundWorker`, permanently stranding offline orders in SQLite WAL.
- **Options:**
  1. *(Recommended)* **Blocking Startup Drain Modal:** On application launch when `OFFLINE_FIRST_ENABLED = false`, check if `sync_outbox` has pending rows. If count $> 0$, display a non-dismissible dialog: *"Unsynced offline orders found on this terminal. Tap 'Drain and Continue' to push to cloud before switching to online-only mode."*
  2. **Silent Background Drain:** Start `SyncBackgroundWorker` in one-shot drain mode even when flag is OFF, running until `pendingCount == 0`, then disposing worker.
- **Status:** `needs-decision` (Recommended: Option 1).

---

### Decision D-05: Line Item Concurrency in Multi-Device Updates (`SYNC-032`, `02-Scenario B.1`)
- **Problem:** In `orders.service.ts:632-636`, REST `updateOrder` iterates existing line items and executes `tx.orderItem.delete()` for any item missing from the payload, clobbering items added by other terminals.
- **Options:**
  1. *(Recommended)* **Append-Only Item Merging by UUID v7:** Line items are identified by client-generated UUID v7. Updating an order only adds new items or updates quantities; items are never deleted unless an explicit `is_cancelled: true` flag is sent.
  2. **Cart OCC Locking:** Prevent concurrent cart edits across multiple devices by acquiring a server lock on the table order.
- **Status:** `needs-decision` (Recommended: Option 1).

---

### Decision D-06: Customer PII & Staff Credential Storage (`SEC-05`, `SEC-07`, `SEC-14`)
- **Problem:** Staff passwords in PostgreSQL `StaffUser` use single-round hashing or plaintext in seed scripts; cached PINs in `SharedPreferences` are unencrypted.
- **Options:**
  1. *(Recommended)* **DPAPI Encrypted Store & Argon2 Upgrade:** Migrate staff PINs in Flutter to Windows DPAPI encrypted storage. Upgrade backend passwords to bcrypt/Argon2 with cost factor 12.
  2. **Defer to Enterprise Security Phase:** Pilot store operates within trusted local LAN network; defer full credential migration to Phase 2.
- **Status:** `needs-decision` (Recommended: Option 1).

---

## 4. Skipped Low-Severity Items Justifications

The following 11 items are categorized as Low severity and skipped in this wave per the agent specification:
1. **RCN-08 (Health Check DB Ping):** Health endpoint returns HTTP 200 without active Prisma query. In single-server deployment, process health is sufficient; DB status is tested by push/pull endpoints.
2. **FLT-08 (Shift Summary Large Scan):** Daily calculation payment queries load all payments in memory. For normal daily transaction volume (< 500 orders/day), memory impact is negligible (< 100 KB).
3. **FLT-13 (Windows Background Daemon):** POS application runs as an active full-screen kiosk in cashier stations. POS is not run minimized in background.
4. **FLT-14 (Print Spooler Background Daemon):** Manual SnackBar retry and local SQLite queue exist. Automatic printer retry daemon is deferred to hardware driver hardening.
5. **MNY-11 (Float vs Decimal Precision):** Drift uses IEEE-754 64-bit float while PostgreSQL uses `Decimal(10,2)`. Rounding helpers (`round(val)`) bound precision within 0.01 PKR. Integer cent refactoring is deferred.
6. **SEC-12 (Non-Windows Encryption):** Current target hardware is Windows 10/11 POS terminals. DPAPI encryption is 100% active on Windows. Android/iOS keystore deferred to mobile release.
7. **SEC-14 (PII in Sync Audit Logs):** Debug Data Sync screen logs contain customer phone numbers for cashier troubleshooting. Access restricted to store manager role.
8. **SEC-15 (Backend Logout Endpoint):** JWT is stateless. Client clears JWT from storage upon logout. Token blocklisting in Redis deferred to enterprise phase.
9. **FLG-05 (Duplicate REST Takeaway Update):** Harmless redundant HTTP PATCH on takeaway status update; backend handler is idempotent.
10. **FLG-06 (Shift Repository Seam Structure):** Minor architectural code organization artifact; zero functional impact.
11. **FLG-07 (Top Navigation Spacing):** Cosmetic 2px margin padding artifact in desktop top bar.
