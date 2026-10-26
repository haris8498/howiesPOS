# Fix Report: SYNC-002 - Cashier UI Button Permanently Purges Unsynced Orders

## 1. Root Cause Analysis
On the cashier `DataSyncScreen` (`frontend/lib/features/sync/data_sync_screen.dart:214-239`), a prominent red button labeled *"Clear N Sync Errors"* directly invoked `syncNotifier.clearFailedErrors()`, which routed to `outboxDao.clearFailedEntries()`.

In `outbox_dao.dart` (lines 140-151), `clearFailedEntries()` performed:
```dart
Future<int> clearFailedEntries() {
  return (update(syncOutbox)
        ..where((t) =>
            t.status.equals(SyncOutboxStatus.conflict) |
            t.status.equals(SyncOutboxStatus.failedFatal) |
            t.status.equals(SyncOutboxStatus.failedRetryable) |
            t.retryCount.isBiggerOrEqualValue(5)))
      .write(SyncOutboxCompanion(
        status: const Value(SyncOutboxStatus.synced),
        ackedAt: Value(DateTime.now()),
      ));
}
```
This wrote `status = 'SYNCED'` and `ackedAt = DateTime.now()` to all unacknowledged outbox rows without transmitting them to the backend server. Cashiers attempting to clear the red error indicator or make the sync light green permanently marked offline orders, order items, customer records, and drawer variances as synced locally. Subsequent 30-day retention pruning jobs permanently deleted these entries from SQLite, causing catastrophic data and financial loss.

## 2. Change Summary
1. **Neutralized Unsafe DAO Semantics:**
   - Prohibited setting `SyncOutboxStatus.synced` locally on unacknowledged rows. Only authenticated server acknowledgement via `markSynced(id, ackedAt)` is permitted to write `SYNCED`.
   - Deprecated `clearFailedEntries()` in `outbox_dao.dart` and redirected calls to `resetFailedEntries()`. Even if invoked by legacy callers, it safely resets mutations to `PENDING` rather than erasing them.
2. **Safe Retry Mechanism (`resetFailedEntries`):**
   - Resets failed mutations (`CONFLICT`, `FAILED_FATAL`, `FAILED_RETRYABLE`, `QUARANTINED`, `DEAD_LETTER`, `retryCount >= 5`) to `status: 'PENDING'` with `retryCount = 0` and `nextRetryAt = null`.
   - Leaves existing `SYNCED` rows completely untouched.
   - Triggers the background worker (`triggerPush(force: true)`) to immediately resubmit the queue.
3. **Quarantine & Dead-Letter Isolation:**
   - Implemented `markQuarantined` and `markDeadLetter` in `OutboxDao` to isolate non-retryable server failures (`status = 'QUARANTINED'`) with failure reasons and conflict details retained.
   - Mutations are retained locally in SQLite and never deleted or bypassed.
   - Added `exportQuarantinedJson()` to serialize quarantined/failed mutations into a diagnostics bundle for tech support.
4. **Immutable Audit Logging:**
   - Implemented `recordAuditLog` in `OutboxDao`, logging user-initiated state changes (`action`, `userId`, `userName`, `entryIds`, `timestamp`, `details`) into the `SyncConflicts` quarantine registry (`entityType: 'audit_log'`, `conflictType: 'USER_ACTION'`, `resolutionStatus: 'SUPERVISOR_ACKNOWLEDGED'`).
5. **UI Rectification in `DataSyncScreen`:**
   - Removed the destructive "Clear N Sync Errors" button.
   - Replaced it with an amber **"Retry failed"** button (`ValueKey('retry_failed_button')`) that resets failed entries to `PENDING`, pushes to the worker, and displays feedback via SnackBar.
   - Added a manager-only **"Export / Report to support"** action (`ValueKey('export_support_button')`) gated by role (`isManager || isOwner`). Cashiers cannot access diagnostic export.
   - Built a diagnostic dialog displaying quarantined entry counts, JSON payload preview, and clipboard copy action.
   - Prevented header flex overflow by expanding the title column.
   - Enforced zero discard/delete options: there is no UI path that allows a user or cashier to discard or delete unsent outbox orders.

## 3. Files Changed
- `frontend/lib/core/database/daos/outbox_dao.dart`
- `frontend/lib/features/sync/data_sync_screen.dart`

## 4. Tests Added
- `frontend/test/core/database/outbox_dao_safe_sync_test.dart` (4 unit tests):
  1. `Retry resets FAILED -> PENDING and leaves SYNCED untouched`: Verifies that `conflict`, `failedFatal`, `failedRetryable`, `quarantined`, and `retryCount >= 5` are reset to `PENDING` with `retryCount = 0` and `nextRetryAt = null`, while `SYNCED` entries remain untouched.
  2. `No DAO method can mark an unacknowledged entry SYNCED`: Verifies that calling `clearFailedEntries()` resets entries to `PENDING` and cannot mark unacknowledged entries as `SYNCED`.
  3. `Audit row written for any state change by a user action`: Verifies that `resetFailedEntries`, `resetSingleEntry`, and `markQuarantined` write an audit row in `SyncConflicts` containing user identity and affected entry IDs.
  4. `Quarantine retains entry without deletion and exports diagnostic JSON`: Verifies that quarantined entries are retained in SQLite and correctly exported via `exportQuarantinedJson()`.

- `frontend/test/features/sync/data_sync_screen_test.dart` (3 widget tests):
  1. `Button label is "Retry failed" and tapping resets entries to PENDING without marking SYNCED`: Verifies the old "Clear" button is gone, "Retry failed" is displayed, tapping resets entries to `PENDING`, leaves `SYNCED` rows intact, triggers worker push, and shows feedback.
  2. `Role gating: "Export / Report to support" action is visible for Manager, hidden for Cashier`: Verifies role-based access control and verifies opening the dialog records an audit entry.
  3. `Confirmation / discard check: no UI path exists that deletes or discards unsent outbox orders`: Verifies that no discard, delete, or clear buttons exist for outbox entries on the screen.

## 5. How to Verify Manually
1. Set `OFFLINE_FIRST_ENABLED=true` in `frontend/lib/config/feature_flags.dart`.
2. Launch the application.
3. Simulate failed sync entries by inserting rows with `status = 'FAILED_FATAL'` or `status = 'FAILED_RETRYABLE'` into SQLite table `sync_outbox`.
4. Open `/sales/data-sync` as Cashier:
   - Notice the button reads **"Retry failed"** with a refresh icon.
   - Notice the "Clear N Sync Errors" button is nowhere on the screen.
   - Notice the "Export / Report to support" button is not visible.
5. Tap **"Retry failed"**:
   - Check SQLite `sync_outbox`: all failed rows now have `status = 'PENDING'` and `retry_count = 0`.
   - Check SQLite `sync_conflicts`: an audit log row is recorded with `action = 'RETRY_FAILED_ENTRIES'`.
6. Switch user / log in as Manager or navigate to `/manager/data-sync`:
   - Notice the **"Export / Report to support"** outlined button is now visible.
   - Tap **"Export / Report to support"** -> a dialog opens displaying quarantined and failed count and the diagnostic JSON payload.
   - Click **"Copy Diagnostic Payload"** -> copies the JSON bundle to clipboard.
   - Verify an audit log row is recorded in `sync_conflicts` with `action = 'EXPORT_REPORT_TO_SUPPORT'`.

## 6. Residual Risks
- The backend sync push endpoint (`POST /api/sync/push`) must be able to process retried orders idempotently by checking the operation's UUID v7 in `processed_operations` or upserting records.
- Cashier UI status light reflects the actual count of pending, failed, and quarantined entries; it will not turn green until all pending items are acknowledged by the server.
