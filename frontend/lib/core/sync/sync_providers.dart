import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/feature_flags.dart';
import '../database/app_database.dart';
import '../../services/api/api_providers.dart';
import '../../services/receipt_printer_service.dart';
import 'connectivity_notifier.dart';
import 'sync_background_worker.dart';

import '../database/tables/sync_conflicts_table.dart';

/// Database provider (singleton root for SQLite/Drift).
/// Can be overridden in tests with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ReceiptPrinterService.setDatabase(db);
  ref.onDispose(() {
    ReceiptPrinterService.setDatabase(null);
    db.close();
  });
  return db;
});

/// Connectivity monitor provider probing `/api/health`.
final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = ConnectivityNotifier(apiClient: apiClient);
  // FLG-04: Only start active polling when offline-first mode is enabled
  if (FeatureFlags.offlineFirstEnabled) {
    notifier.startMonitoring();
  }
  ref.onDispose(() {
    notifier.dispose();
  });
  return notifier;
});

/// Background sync engine provider with single worker lifecycle (Risk #8).
final syncBackgroundWorkerProvider = Provider<SyncBackgroundWorker>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final apiClient = ref.watch(apiClientProvider);
  final connectivity = ref.watch(connectivityNotifierProvider.notifier);
  final socketService = ref.watch(kitchenSocketServiceProvider);

  final worker = SyncBackgroundWorker(
    db: db,
    apiClient: apiClient,
    connectivityNotifier: connectivity,
    socketService: socketService,
  );

  // If feature flag is enabled, start background sync worker immediately
  if (FeatureFlags.offlineFirstEnabled) {
    worker.start();
  }

  ref.onDispose(() {
    worker.dispose();
  });

  return worker;
});

/// Real-time sync worker state provider.
final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, SyncWorkerState>((ref) {
  final worker = ref.watch(syncBackgroundWorkerProvider);
  return worker.stateNotifier;
});

/// Reactive stream of pending/retryable mutation count in the outbox.
final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.outboxDao.watchPendingCount();
});

/// Reactive stream of unresolved pending conflicts in sync_conflicts (§3.3 Tier 5).
final unresolvedConflictCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.syncConflicts)
        ..where((t) => t.resolutionStatus.equals(ConflictResolutionStatus.pending)))
      .watch()
      .map((list) => list.length);
});

/// Model representing conflict badge state for supervisory alert (§3.3 Tier 5).
class SyncConflictBadgeState {
  final bool hasConflict;
  final int conflictCount;
  final String label;
  final String colorName; // 'orange' (warning) or 'red' (critical)
  final int colorHex; // 0xFFFF5722 (Deep Orange) or 0xFFE53935 (Red)

  const SyncConflictBadgeState({
    this.hasConflict = false,
    this.conflictCount = 0,
    this.label = '',
    this.colorName = 'red',
    this.colorHex = 0xFFE53935,
  });

  static const none = SyncConflictBadgeState();
}

/// Provider exposing red/orange badge state for unresolved sync conflicts.
/// Surfaces state through Riverpod without modifying existing screen layouts.
final syncConflictBadgeProvider = Provider<SyncConflictBadgeState>((ref) {
  final conflictCount = ref.watch(unresolvedConflictCountProvider).value ?? 0;
  if (conflictCount <= 0) {
    return SyncConflictBadgeState.none;
  }

  return SyncConflictBadgeState(
    hasConflict: true,
    conflictCount: conflictCount,
    label: '$conflictCount Conflict${conflictCount > 1 ? 's' : ''} Detected',
    colorName: conflictCount > 3 ? 'red' : 'orange',
    colorHex: conflictCount > 3 ? 0xFFE53935 : 0xFFFF5722,
  );
});

/// UI Sync Indicator Display Model per Spec §3.3.
enum SyncIndicatorState {
  allSynced, // Green dot: "All Synced"
  pendingOffline, // Amber pill: "Offline — N Pending"
  syncing, // Blue spinning: "Syncing..."
  authPaused, // Orange key: "Session Expired — Login Required"
  conflict, // Red alert badge: "Conflict Detected"
  circuitBreaker, // Yellow banner: "Cloud Maintenance — POS Local"
}

/// Formatted sync indicator view model for future UI consumption.
class SyncIndicatorViewModel {
  final SyncIndicatorState state;
  final String label;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final bool isOnline;

  const SyncIndicatorViewModel({
    required this.state,
    required this.label,
    required this.pendingCount,
    this.lastSyncAt,
    required this.isOnline,
  });
}

/// Provider computing UI sync indicator state without touching existing screens.
final syncIndicatorProvider = Provider<SyncIndicatorViewModel>((ref) {
  final workerState = ref.watch(syncStateProvider);
  final connState = ref.watch(connectivityNotifierProvider);
  final pendingCount = ref.watch(pendingOutboxCountProvider).value ?? workerState.pendingCount;
  final conflictCount = ref.watch(unresolvedConflictCountProvider).value ?? 0;

  if (workerState.isAuthPaused) {
    return SyncIndicatorViewModel(
      state: SyncIndicatorState.authPaused,
      label: 'Session Expired — Please Login',
      pendingCount: pendingCount,
      lastSyncAt: workerState.lastSuccessfulPush,
      isOnline: connState.isOnline,
    );
  }

  if (workerState.isCircuitBreakerTripped) {
    return SyncIndicatorViewModel(
      state: SyncIndicatorState.circuitBreaker,
      label: 'Cloud Maintenance — POS Local',
      pendingCount: pendingCount,
      lastSyncAt: workerState.lastSuccessfulPush,
      isOnline: false,
    );
  }

  if (conflictCount > 0) {
    return SyncIndicatorViewModel(
      state: SyncIndicatorState.conflict,
      label: '$conflictCount Conflict${conflictCount > 1 ? 's' : ''} Detected',
      pendingCount: pendingCount,
      lastSyncAt: workerState.lastSuccessfulPush,
      isOnline: connState.isOnline,
    );
  }

  if (workerState.isPushing || workerState.isPulling) {
    return SyncIndicatorViewModel(
      state: SyncIndicatorState.syncing,
      label: 'Syncing $pendingCount changes...',
      pendingCount: pendingCount,
      lastSyncAt: workerState.lastSuccessfulPush,
      isOnline: connState.isOnline,
    );
  }

  if (!connState.isOnline || pendingCount > 0) {
    return SyncIndicatorViewModel(
      state: SyncIndicatorState.pendingOffline,
      label: connState.isOnline ? '$pendingCount Pending Sync' : 'Offline — $pendingCount Pending',
      pendingCount: pendingCount,
      lastSyncAt: workerState.lastSuccessfulPush,
      isOnline: connState.isOnline,
    );
  }

  return SyncIndicatorViewModel(
    state: SyncIndicatorState.allSynced,
    label: 'All Synced',
    pendingCount: 0,
    lastSyncAt: workerState.lastSuccessfulPush ?? workerState.lastSuccessfulPull,
    isOnline: true,
  );
});
