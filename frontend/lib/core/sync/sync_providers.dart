import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/feature_flags.dart';
import '../database/app_database.dart';
import '../../services/api/api_providers.dart';
import 'connectivity_notifier.dart';
import 'sync_background_worker.dart';

/// Database provider (singleton root for SQLite/Drift).
/// Can be overridden in tests with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

/// Connectivity monitor provider probing `/api/health`.
final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final notifier = ConnectivityNotifier(apiClient: apiClient);
  notifier.startMonitoring();
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
