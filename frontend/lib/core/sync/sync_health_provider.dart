import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/feature_flags.dart';
import '../database/app_database.dart';
import '../database/tables/sync_outbox_table.dart';
import 'sync_providers.dart';

enum SyncHealthStatus {
  green, // Healthy: online, worker running, outbox draining or empty
  red,   // Not syncing: offline, worker stopped, failed items, or stuck > 2 min
}

class SyncHealthState {
  final SyncHealthStatus status;
  final bool isPulsing;
  final int pendingCount;
  final int failedCount;
  final String tooltipText;
  final String semanticsLabel;

  const SyncHealthState({
    required this.status,
    this.isPulsing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    required this.tooltipText,
    required this.semanticsLabel,
  });

  bool get isGreen => status == SyncHealthStatus.green;
  bool get isRed => status == SyncHealthStatus.red;

  static const initial = SyncHealthState(
    status: SyncHealthStatus.green,
    isPulsing: false,
    pendingCount: 0,
    failedCount: 0,
    tooltipText: 'Synced',
    semanticsLabel: 'Sync status: Synced',
  );
}

/// Reactive stream of active outbox mutations from Drift SQLite.
final activeOutboxEntriesProvider = StreamProvider<List<SyncOutboxEntry>>((ref) {
  if (!FeatureFlags.offlineFirstEnabled) {
    return const Stream.empty();
  }
  final db = ref.watch(appDatabaseProvider);
  return db.outboxDao.watchActiveOutboxEntries();
});

/// Periodic timer stream provider ensuring stuck-item (2-min threshold) is recomputed timely (§15.3, FLT-12)
final syncHealthPeriodicTickerProvider = StreamProvider<int>((ref) {
  if (!FeatureFlags.offlineFirstEnabled) {
    return const Stream.empty();
  }
  return Stream.periodic(const Duration(seconds: 30), (i) => i);
});

/// Pure sync health computation combining connectivity, worker, and outbox state.
final rawSyncHealthProvider = Provider<SyncHealthState>((ref) {
  if (!FeatureFlags.offlineFirstEnabled) {
    return SyncHealthState.initial;
  }

  // FLT-12: Watch periodic ticker so stuck in-flight items are evaluated timely even if outbox table is quiet
  ref.watch(syncHealthPeriodicTickerProvider);

  final isOnline = ref.watch(connectivityNotifierProvider).isOnline;
  final worker = ref.watch(syncBackgroundWorkerProvider);
  final isRunning = worker.isRunning;
  final isDraining = worker.isDraining;
  final entriesAsync = ref.watch(activeOutboxEntriesProvider);
  final entries = entriesAsync.value ?? [];

  final pendingEntries = entries.where((e) =>
      e.status == SyncOutboxStatus.pending ||
      e.status == SyncOutboxStatus.inFlight ||
      e.status == SyncOutboxStatus.failedRetryable ||
      e.status == SyncOutboxStatus.authPaused).toList();
  final pendingCount = pendingEntries.length;

  final failedEntries = entries.where((e) =>
      e.status == SyncOutboxStatus.failedFatal ||
      e.status == SyncOutboxStatus.conflict ||
      e.retryCount >= 5).toList();
  final failedCount = failedEntries.length;

  final now = DateTime.now();
  final hasStuckItem = isOnline && entries.any((e) =>
      e.status == SyncOutboxStatus.inFlight &&
      now.difference(e.sentAt ?? e.createdAt).inMinutes >= 2);

  final isAuthPaused = worker.state.isAuthPaused ||
      entries.any((e) => e.status == SyncOutboxStatus.authPaused);

  // RED CONDITIONS (Strict 2-color policy per spec)
  if (!isOnline) {
    return SyncHealthState(
      status: SyncHealthStatus.red,
      isPulsing: false,
      pendingCount: pendingCount,
      failedCount: failedCount,
      tooltipText: 'Offline - $pendingCount saved locally',
      semanticsLabel: 'Sync status: Offline. $pendingCount orders saved locally.',
    );
  }

  if (!isRunning) {
    return SyncHealthState(
      status: SyncHealthStatus.red,
      isPulsing: false,
      pendingCount: pendingCount,
      failedCount: failedCount,
      tooltipText: 'Sync worker stopped',
      semanticsLabel: 'Sync status: Worker is stopped.',
    );
  }

  if (isAuthPaused) {
    return SyncHealthState(
      status: SyncHealthStatus.red,
      isPulsing: false,
      pendingCount: pendingCount,
      failedCount: failedCount,
      tooltipText: 'Auth paused - sign in required',
      semanticsLabel: 'Sync status: Authentication paused. Sign in required.',
    );
  }

  if (failedCount > 0) {
    return SyncHealthState(
      status: SyncHealthStatus.red,
      isPulsing: false,
      pendingCount: pendingCount,
      failedCount: failedCount,
      tooltipText: 'Sync error - $failedCount failed',
      semanticsLabel: 'Sync status: Error with $failedCount failed items.',
    );
  }

  if (hasStuckItem) {
    return SyncHealthState(
      status: SyncHealthStatus.red,
      isPulsing: false,
      pendingCount: pendingCount,
      failedCount: failedCount,
      tooltipText: 'Sync stuck - oldest item > 2 min',
      semanticsLabel: 'Sync status: Stuck. Oldest item pending over 2 minutes.',
    );
  }

  // GREEN CONDITIONS (Healthy, idle or draining)
  if (isDraining || pendingCount > 0) {
    return SyncHealthState(
      status: SyncHealthStatus.green,
      isPulsing: isDraining,
      pendingCount: pendingCount,
      failedCount: 0,
      tooltipText: pendingCount > 0 ? 'Syncing - $pendingCount pending' : 'Syncing',
      semanticsLabel: 'Sync status: Syncing with $pendingCount pending items.',
    );
  }

  return const SyncHealthState(
    status: SyncHealthStatus.green,
    isPulsing: false,
    pendingCount: 0,
    failedCount: 0,
    tooltipText: 'Synced',
    semanticsLabel: 'Sync status: Synced',
  );
});

/// Debounced sync health stream (~800 ms) preventing status light flicker during flaky connections.
final syncHealthProvider = StreamProvider<SyncHealthState>((ref) {
  final controller = StreamController<SyncHealthState>();
  Timer? debounceTimer;

  final initial = ref.watch(rawSyncHealthProvider);
  controller.add(initial);

  final sub = ref.listen<SyncHealthState>(rawSyncHealthProvider, (previous, next) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!controller.isClosed) {
        controller.add(next);
      }
    });
  });

  ref.onDispose(() {
    debounceTimer?.cancel();
    sub.close();
    controller.close();
  });

  return controller.stream;
});
