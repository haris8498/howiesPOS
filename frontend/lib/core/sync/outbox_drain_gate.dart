import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/feature_flags.dart';
import '../database/app_database.dart';
import 'sync_providers.dart';

/// State of the Outbox Drain Gate (D-04 / SYNC-027).
class OutboxDrainGateState {
  final bool featureFlag;
  final int nonTerminalCount;
  final bool isOnline;
  final bool isDraining;
  final bool isDrainDismissedForSession;
  final List<SyncOutboxEntry> permanentlyFailedEntries;
  final String? lastDecisionLog;

  const OutboxDrainGateState({
    required this.featureFlag,
    required this.nonTerminalCount,
    this.isOnline = true,
    this.isDraining = false,
    this.isDrainDismissedForSession = false,
    this.permanentlyFailedEntries = const [],
    this.lastDecisionLog,
  });

  /// Routing rule (Task 2):
  /// Order repository uses the local-first path if flag == true OR outbox is non-empty.
  /// The online-only path is chosen ONLY when the flag is false AND the outbox is empty.
  bool get shouldUseLocalFirst => featureFlag || nonTerminalCount > 0;

  /// Whether the blocking drain modal must be displayed (Task 3):
  /// If flag is false and outbox is non-empty, and cashier has not dismissed it for offline work.
  bool get shouldShowDrainModal =>
      !featureFlag && nonTerminalCount > 0 && !isDrainDismissedForSession;

  /// Whether there are pending rows in the outbox.
  bool get hasPendingRows => nonTerminalCount > 0;

  /// Count of permanently failed (4xx / FATAL / CONFLICT / QUARANTINED) entries.
  int get permanentlyFailedCount => permanentlyFailedEntries.length;

  OutboxDrainGateState copyWith({
    bool? featureFlag,
    int? nonTerminalCount,
    bool? isOnline,
    bool? isDraining,
    bool? isDrainDismissedForSession,
    List<SyncOutboxEntry>? permanentlyFailedEntries,
    String? lastDecisionLog,
  }) {
    return OutboxDrainGateState(
      featureFlag: featureFlag ?? this.featureFlag,
      nonTerminalCount: nonTerminalCount ?? this.nonTerminalCount,
      isOnline: isOnline ?? this.isOnline,
      isDraining: isDraining ?? this.isDraining,
      isDrainDismissedForSession:
          isDrainDismissedForSession ?? this.isDrainDismissedForSession,
      permanentlyFailedEntries:
          permanentlyFailedEntries ?? this.permanentlyFailedEntries,
      lastDecisionLog: lastDecisionLog ?? this.lastDecisionLog,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutboxDrainGateState &&
          runtimeType == other.runtimeType &&
          featureFlag == other.featureFlag &&
          nonTerminalCount == other.nonTerminalCount &&
          isOnline == other.isOnline &&
          isDraining == other.isDraining &&
          isDrainDismissedForSession == other.isDrainDismissedForSession &&
          permanentlyFailedEntries.length ==
              other.permanentlyFailedEntries.length &&
          lastDecisionLog == other.lastDecisionLog;

  @override
  int get hashCode =>
      featureFlag.hashCode ^
      nonTerminalCount.hashCode ^
      isOnline.hashCode ^
      isDraining.hashCode ^
      isDrainDismissedForSession.hashCode ^
      permanentlyFailedEntries.length.hashCode ^
      lastDecisionLog.hashCode;
}

/// OutboxDrainGate manages the startup & flag cutover drain gate (D-04).
///
/// Prevents stranding unsynced orders in SQLite WAL when OFFLINE_FIRST_ENABLED
/// is flipped to false.
class OutboxDrainGate extends StateNotifier<OutboxDrainGateState> {
  final AppDatabase db;
  final Ref ref;

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  StreamSubscription<int>? _outboxSub;
  StreamSubscription<List<SyncOutboxEntry>>? _failedSub;
  VoidCallback? _connListenerRemover;

  OutboxDrainGate({
    required this.db,
    required this.ref,
    bool? initialFlag,
    int initialCount = 0,
  }) : super(OutboxDrainGateState(
          featureFlag: initialFlag ?? FeatureFlags.offlineFirstEnabled,
          nonTerminalCount: initialCount,
        )) {
    _logDecision(state.featureFlag, state.nonTerminalCount);
    _init();
  }

  void _init() {
    // 1. Initial count of non-terminal rows and permanently failed entries
    Future.wait([
      db.outboxDao.getNonTerminalCount().then((count) {
        if (!mounted) return;
        _updateCounts(count);
      }),
      db.outboxDao.getPermanentlyFailedEntries().then((entries) {
        if (!mounted) return;
        state = state.copyWith(permanentlyFailedEntries: entries);
      }),
    ]).whenComplete(() {
      if (!mounted) return;
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    });

    // 2. Reactive subscription to non-terminal outbox count
    _outboxSub = db.outboxDao.watchNonTerminalCount().listen((count) {
      if (!mounted) return;
      _updateCounts(count);
    });

    // Reactive subscription to permanently failed entries
    _failedSub = db.outboxDao.watchPermanentlyFailedEntries().listen((entries) {
      if (!mounted) return;
      state = state.copyWith(permanentlyFailedEntries: entries);
    });

    // 3. Listen to connectivity state changes (Auto-resume §4)
    final connNotifier = ref.read(connectivityNotifierProvider.notifier);
    state = state.copyWith(isOnline: connNotifier.isOnline);

    _connListenerRemover = connNotifier.addListener((connState) {
      if (!mounted) return;
      final wasOffline = !state.isOnline;
      final isNowOnline = connState.isOnline;

      state = state.copyWith(isOnline: isNowOnline);

      // Task 4: If connectivity returns while in drain-pending mode, auto-resume
      if (wasOffline && isNowOnline && state.shouldShowDrainModal && !state.isDraining) {
        debugPrint('[OutboxDrainGate] Connectivity restored: auto-resuming outbox drain');
        syncNow();
      }
    });
  }

  void updateFeatureFlag(bool flag) {
    if (state.featureFlag == flag) return;
    state = state.copyWith(featureFlag: flag);
    _logDecision(state.featureFlag, state.nonTerminalCount);
  }

  void _updateCounts(int count) {
    if (state.nonTerminalCount == count) return;
    state = state.copyWith(nonTerminalCount: count);
    _logDecision(state.featureFlag, count);
  }

  void _logDecision(bool flag, int count) {
    final localFirst = flag || count > 0;
    final route = localFirst
        ? 'DriftOfflineFirstOrderRepository (local-first)'
        : 'ApiOrderRepository (online-only)';
    final reason = flag
        ? 'flag is ON'
        : (count > 0
            ? 'flag is OFF but outbox has $count unsynced row(s)'
            : 'flag is OFF and outbox is empty');

    final logMessage =
        '[OutboxDrainGate] Gate decision: flag=$flag, pendingCount=$count -> Route: $route ($reason)';
    debugPrint(logMessage);
    state = state.copyWith(lastDecisionLog: logMessage);
  }

  /// Runs the existing sync worker until the outbox is empty, with retries and backoff (Task 3).
  Future<void> syncNow() async {
    if (state.isDraining) return;

    state = state.copyWith(isDraining: true);
    debugPrint('[OutboxDrainGate] Starting syncNow outbox drain...');

    try {
      final worker = ref.read(syncBackgroundWorkerProvider);
      worker.start();

      while (mounted && state.nonTerminalCount > 0) {
        final conn = ref.read(connectivityNotifierProvider);
        if (!conn.isOnline) {
          debugPrint('[OutboxDrainGate] Offline: pausing syncNow until connectivity returns');
          break;
        }

        final result = await worker.triggerSyncCycle(force: true);

        // Fetch remaining non-terminal count
        final remaining = await db.outboxDao.getNonTerminalCount();
        _updateCounts(remaining);

        if (remaining == 0) {
          debugPrint('[OutboxDrainGate] Outbox successfully drained to 0!');
          break;
        }

        // If nothing was pushed and there was a network/auth error or no ready batch, stop loop
        if (result.pushedCount == 0 && (result.networkOrAuthError || !result.pushSuccess)) {
          debugPrint('[OutboxDrainGate] Sync batch paused due to network or retry backoff');
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } catch (e, stack) {
      debugPrint('[OutboxDrainGate] Error in syncNow: $e\n$stack');
    } finally {
      if (mounted) {
        state = state.copyWith(isDraining: false);
      }
    }
  }

  /// Writes the outbox as JSON to a user-chosen or documents folder (Task 3).
  ///
  /// Every pending and failed row is safely exported. Never mutates or deletes rows.
  Future<String> exportBackup({String? targetDirectoryPath}) async {
    final jsonContent = await db.outboxDao.exportOutboxBackupJson();

    Directory dir;
    if (targetDirectoryPath != null && targetDirectoryPath.isNotEmpty) {
      dir = Directory(targetDirectoryPath);
    } else {
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.current;
      }
    }

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final filePath = p.join(dir.path, 'outbox_backup_$timestamp.json');
    final file = File(filePath);
    await file.writeAsString(jsonContent);

    debugPrint('[OutboxDrainGate] Exported outbox backup to: $filePath');
    return filePath;
  }

  /// Allows cashier to dismiss the drain modal for the session when offline so POS can operate (Task 4).
  void dismissModalForOfflineSession() {
    state = state.copyWith(isDrainDismissedForSession: true);
    debugPrint('[OutboxDrainGate] Modal dismissed for offline session; local routing active');
  }

  void resetDismissedForTesting() {
    state = state.copyWith(isDrainDismissedForSession: false);
  }

  @override
  void dispose() {
    _outboxSub?.cancel();
    _failedSub?.cancel();
    _connListenerRemover?.call();
    super.dispose();
  }
}

/// OutboxDrainGate provider (Riverpod §17.1, D-04).
final outboxDrainGateProvider =
    StateNotifierProvider<OutboxDrainGate, OutboxDrainGateState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final flag = ref.watch(offlineFirstFeatureFlagProvider);

  final gate = OutboxDrainGate(
    db: db,
    ref: ref,
    initialFlag: flag,
  );

  // Sync if feature flag updates dynamically
  ref.listen<bool>(offlineFirstFeatureFlagProvider, (_, nextFlag) {
    gate.updateFeatureFlag(nextFlag);
  });

  return gate;
});
