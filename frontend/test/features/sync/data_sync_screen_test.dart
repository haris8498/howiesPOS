import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/database/app_database.dart';
import 'package:hungry_howies_pos/core/database/tables/sync_outbox_table.dart';
import 'package:hungry_howies_pos/core/network/api_client.dart';
import 'package:hungry_howies_pos/core/sync/connectivity_notifier.dart';
import 'package:hungry_howies_pos/core/sync/sync_background_worker.dart';
import 'package:hungry_howies_pos/core/sync/sync_health_provider.dart';
import 'package:hungry_howies_pos/core/sync/sync_providers.dart';
import 'package:hungry_howies_pos/data/auth_repository.dart';
import 'package:hungry_howies_pos/data/sync_repository.dart';
import 'package:hungry_howies_pos/domain/models/data_sync_model.dart';
import 'package:hungry_howies_pos/domain/models/staff_model.dart';
import 'package:hungry_howies_pos/domain/models/user_role.dart';
import 'package:hungry_howies_pos/features/sync/data_sync_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(UserRole role) : super() {
    state = state.copyWith(
      currentUser: StaffMember(
        id: '019283a0-0000-7000-8000-000000000099',
        fullName: 'Test Staff',
        phone: '1234567890',
        role: role,
        hourlyRate: 15.0,
        assignedShift: 'Morning',
      ),
      isAuthenticated: true,
    );
  }
}

class MockConnectivityNotifier extends ConnectivityNotifier {
  MockConnectivityNotifier() : super(apiClient: ApiClient());

  @override
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {}
}

class MockSyncBackgroundWorker extends SyncBackgroundWorker {
  bool pushTriggered = false;

  MockSyncBackgroundWorker(AppDatabase db, ConnectivityNotifier connectivityNotifier)
      : super(db: db, connectivityNotifier: connectivityNotifier);

  @override
  Future<void> triggerPush({bool force = false}) async {
    pushTriggered = true;
  }
}

class MockDataSyncNotifier extends StateNotifier<DataSyncState> implements DataSyncNotifier {
  MockDataSyncNotifier([DataSyncState? state]) : super(state ?? const DataSyncState());

  @override
  Future<void> loadData({bool silent = false}) async {}

  @override
  Future<int> syncAllPending() async => 0;

  @override
  Future<void> clearFailedErrors() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late MockConnectivityNotifier mockConnectivity;
  late MockSyncBackgroundWorker mockWorker;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    mockConnectivity = MockConnectivityNotifier();
    mockWorker = MockSyncBackgroundWorker(db, mockConnectivity);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen({
    required UserRole role,
    int failedCount = 0,
    int pendingCount = 0,
  }) {
    return ProviderScope(
      key: ValueKey('$role-$failedCount-$pendingCount'),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authProvider.overrideWith((ref) => MockAuthNotifier(role)),
        syncBackgroundWorkerProvider.overrideWithValue(mockWorker),
        connectivityNotifierProvider.overrideWith((ref) => mockConnectivity),
        dataSyncProvider.overrideWith(
          (ref) => MockDataSyncNotifier(
            DataSyncState(
              summary: DataSyncSummary(
                pendingCount: pendingCount,
                syncedCount: 10,
                totalOrders: 10 + pendingCount,
              ),
            ),
          ),
        ),
        rawSyncHealthProvider.overrideWithValue(
          SyncHealthState(
            status: failedCount > 0 ? SyncHealthStatus.red : SyncHealthStatus.green,
            failedCount: failedCount,
            pendingCount: pendingCount,
            tooltipText: failedCount > 0 ? 'Sync error - $failedCount failed' : 'Synced',
            semanticsLabel: failedCount > 0 ? 'Sync status: Error' : 'Sync status: Synced',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DataSyncScreen(),
        ),
      ),
    );
  }

  group('DataSyncScreen SYNC-002 Widget Tests', () {
    testWidgets('Button label is "Retry failed" and tapping resets entries to PENDING without marking SYNCED',
        (WidgetTester tester) async {
      // Seed SQLite with 1 failedFatal and 1 synced entry
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0010-7000-8000-000000000010'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0010-7000-8000-000000000020'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-110"}'),
          status: const Value(SyncOutboxStatus.failedFatal),
          retryCount: const Value(2),
        ),
      );

      final ackedTime = DateTime.now().subtract(const Duration(hours: 2));
      await db.outboxDao.insertEntry(
        SyncOutboxCompanion(
          operationId: const Value('019283a0-0011-7000-8000-000000000011'),
          deviceId: const Value('POS-P1'),
          entityType: const Value('order'),
          entityId: const Value('019283a0-0011-7000-8000-000000000021'),
          operationType: const Value('INSERT'),
          payload: const Value('{"order_number":"P1-111"}'),
          status: const Value(SyncOutboxStatus.synced),
          ackedAt: Value(ackedTime),
        ),
      );

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen(role: UserRole.cashier, failedCount: 1));
      await tester.pumpAndSettle();

      // Guard: Dangerous "Clear N Sync Errors" button must NEVER exist
      expect(find.textContaining('Clear 1 Sync Error'), findsNothing);
      expect(find.textContaining('Clear Sync Error'), findsNothing);

      // Verify "Retry failed" button is rendered
      final retryButtonFinder = find.byKey(const ValueKey('retry_failed_button'));
      expect(retryButtonFinder, findsOneWidget);
      expect(find.text('Retry failed'), findsOneWidget);

      // Tap "Retry failed"
      await tester.tap(retryButtonFinder);
      await tester.pumpAndSettle();

      // Verify failed entry was safely transitioned to PENDING (retryCount=0, nextRetryAt=null)
      final resetEntry = await db.outboxDao.getEntryByOperationId('019283a0-0010-7000-8000-000000000010');
      expect(resetEntry!.status, equals(SyncOutboxStatus.pending));
      expect(resetEntry.retryCount, equals(0));
      expect(resetEntry.nextRetryAt, isNull);

      // Verify SYNCED entry was untouched
      final syncedEntry = await db.outboxDao.getEntryByOperationId('019283a0-0011-7000-8000-000000000011');
      expect(syncedEntry!.status, equals(SyncOutboxStatus.synced));

      // Verify worker push was triggered
      expect(mockWorker.pushTriggered, isTrue);

      // Verify SnackBar message informs cashier
      expect(find.textContaining('Retrying 1 failed sync item'), findsOneWidget);
    });

    testWidgets('Role gating: "Export / Report to support" action is visible for Manager, hidden for Cashier',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Cashier Role: Support export action must NOT be rendered
      await tester.pumpWidget(buildScreen(role: UserRole.cashier, failedCount: 1));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('export_support_button')), findsNothing);
      expect(find.text('Export / Report to support'), findsNothing);

      // 2. Manager Role: Support export action MUST be rendered
      await tester.pumpWidget(buildScreen(role: UserRole.manager, failedCount: 1));
      await tester.pumpAndSettle();

      final exportButton = find.byKey(const ValueKey('export_support_button'));
      expect(exportButton, findsOneWidget);
      expect(find.text('Export / Report to support'), findsOneWidget);

      // Tap "Export / Report to support"
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      // Verify support dialog opened
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Copy Diagnostic Payload'), findsOneWidget);

      // Verify audit row was written to sync_conflicts
      final auditLogs = await db.outboxDao.getAuditLogs();
      expect(auditLogs, isNotEmpty);
      expect(auditLogs.first.conflictType, equals('USER_ACTION'));
      expect(auditLogs.first.payload, contains('EXPORT_REPORT_TO_SUPPORT'));
    });

    testWidgets('Confirmation / discard check: no UI path exists that deletes or discards unsent outbox orders',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildScreen(role: UserRole.manager, failedCount: 3));
      await tester.pumpAndSettle();

      // Verify no discard or delete buttons exist for outbox entries
      expect(find.widgetWithText(ElevatedButton, 'Discard'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Discard'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Discard'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Delete'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Clear'), findsNothing);

      // Verify the only error handling action is "Retry failed"
      expect(find.text('Retry failed'), findsOneWidget);
    });
  });
}
