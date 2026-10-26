import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import '../database/app_database.dart';
import '../database/daos/retention_dao.dart';
import '../database/tables/sync_outbox_table.dart';
import '../database/tables/local_daily_calculations_table.dart';
import '../database/tables/sync_conflicts_table.dart';
import '../network/api_client.dart';
import '../network/kitchen_socket_service.dart';
import '../security/token_storage.dart';
import 'connectivity_notifier.dart';
import 'device_identity.dart';

export '../database/daos/retention_dao.dart' show RetentionPruneResult;

/// Result of a single-flight sync cycle (SYNC-004).
class SyncCycleResult {
  final int pushedCount;
  final int pulledCount;
  final int skippedForPendingCount;
  final bool pushSuccess;
  final bool pullSuccess;
  final bool networkOrAuthError;

  const SyncCycleResult({
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.skippedForPendingCount = 0,
    this.pushSuccess = true,
    this.pullSuccess = true,
    this.networkOrAuthError = false,
  });

  @override
  String toString() =>
      'SyncCycleResult(pushed: $pushedCount, pulled: $pulledCount, skipped_for_pending: $skippedForPendingCount, pushSuccess: $pushSuccess, pullSuccess: $pullSuccess)';
}

/// Result of applying a single pull change delta (SYNC-004).
enum PullApplyResult {
  applied,
  ignoredStale,
  skippedPending,
}

class PushBatchDrainResult {
  final int pushedCount;
  final bool success;
  final bool networkOrAuthError;

  const PushBatchDrainResult({
    required this.pushedCount,
    required this.success,
    required this.networkOrAuthError,
  });
}

class PullStreamResult {
  final int pulledCount;
  final int skippedForPendingCount;
  final bool success;

  const PullStreamResult({
    required this.pulledCount,
    required this.skippedForPendingCount,
    required this.success,
  });
}


/// Worker operational status
enum SyncWorkerStatus {
  idle,
  pushing,
  pulling,
  authPaused,
  circuitBreakerTripped,
  error,
  stopped,
}

/// State of the background synchronization worker
class SyncWorkerState {
  final SyncWorkerStatus status;
  final int pendingCount;
  final DateTime? lastSuccessfulPush;
  final DateTime? lastSuccessfulPull;
  final int consecutiveTimeouts;
  final bool isCircuitBreakerTripped;
  final bool isAuthPaused;
  final String? lastError;

  const SyncWorkerState({
    this.status = SyncWorkerStatus.idle,
    this.pendingCount = 0,
    this.lastSuccessfulPush,
    this.lastSuccessfulPull,
    this.consecutiveTimeouts = 0,
    this.isCircuitBreakerTripped = false,
    this.isAuthPaused = false,
    this.lastError,
  });

  bool get isPushing => status == SyncWorkerStatus.pushing;
  bool get isPulling => status == SyncWorkerStatus.pulling;
  bool get isIdle => status == SyncWorkerStatus.idle;

  SyncWorkerState copyWith({
    SyncWorkerStatus? status,
    int? pendingCount,
    DateTime? lastSuccessfulPush,
    DateTime? lastSuccessfulPull,
    int? consecutiveTimeouts,
    bool? isCircuitBreakerTripped,
    bool? isAuthPaused,
    String? lastError,
  }) {
    return SyncWorkerState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSuccessfulPush: lastSuccessfulPush ?? this.lastSuccessfulPush,
      lastSuccessfulPull: lastSuccessfulPull ?? this.lastSuccessfulPull,
      consecutiveTimeouts: consecutiveTimeouts ?? this.consecutiveTimeouts,
      isCircuitBreakerTripped: isCircuitBreakerTripped ?? this.isCircuitBreakerTripped,
      isAuthPaused: isAuthPaused ?? this.isAuthPaused,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncWorkerState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          lastSuccessfulPush == other.lastSuccessfulPush &&
          lastSuccessfulPull == other.lastSuccessfulPull &&
          consecutiveTimeouts == other.consecutiveTimeouts &&
          isCircuitBreakerTripped == other.isCircuitBreakerTripped &&
          isAuthPaused == other.isAuthPaused &&
          lastError == other.lastError;

  @override
  int get hashCode =>
      status.hashCode ^
      pendingCount.hashCode ^
      lastSuccessfulPush.hashCode ^
      lastSuccessfulPull.hashCode ^
      consecutiveTimeouts.hashCode ^
      isCircuitBreakerTripped.hashCode ^
      isAuthPaused.hashCode ^
      lastError.hashCode;

  @override
  String toString() =>
      'SyncWorkerState(status: $status, pending: $pendingCount, timeouts: $consecutiveTimeouts, circuitBreaker: $isCircuitBreakerTripped, authPaused: $isAuthPaused)';
}

/// StateNotifier wrapper for SyncWorkerState
class SyncStateNotifier extends StateNotifier<SyncWorkerState> {
  SyncStateNotifier([super.initialState = const SyncWorkerState()]);

  SyncWorkerState get currentState => state;

  void updateState(SyncWorkerState newState) {
    state = newState;
  }
}

/// Background synchronization engine orchestrating Push and Pull pipelines.
///
/// Implements:
/// - Spec §6.1-§6.4 (Push batch <=25, dependency ordering, retry backoff with jitter)
/// - Spec §8.1.1-§8.1.3 (Push, Pull delta feed, Cold-start Bootstrap)
/// - Spec §13 (Reconnection flow)
/// - Spec §15.2 (Anti-duplicate ladder & in-flight locking)
/// - Spec §15.3 (Startup zombie recovery & PRAGMA wal_checkpoint cadence)
/// - Approved Deviation #3 (AUTH_PAUSED on HTTP 401 instead of quarantine)
/// - Risk #8 (Single worker lifecycle with explicit disposal)
class SyncBackgroundWorker {
  final AppDatabase db;
  final ApiClient? apiClient;
  final http.Client? httpClient;
  final ConnectivityNotifier connectivityNotifier;
  final KitchenSocketService? socketService;
  final String deviceId;
  final int batchSize;
  final Duration pollInterval;
  final Duration circuitBreakerPauseDuration;
  final Duration retentionPeriod;
  final Duration retentionPruneInterval;
  final Duration zombieTimeout;
  final Random _random;
  final String? syncUrlOverride;

  DateTime? _lastPruneAt;

  final SyncStateNotifier stateNotifier = SyncStateNotifier();

  bool _isDisposed = false;
  bool _isRunning = false;
  bool _isPushing = false;
  bool _isPulling = false;
  bool _isCycleRunning = false;
  bool _queuedCycle = false;
  bool _queuedForcePush = false;
  Completer<SyncCycleResult>? _activeCycleCompleter;
  Completer<SyncCycleResult>? _queuedCycleCompleter;
  SyncCycleResult? lastCycleResult;
  int _mutationsProcessedSinceLastWalCheckpoint = 0;

  Timer? _periodicTimer;
  Timer? _circuitBreakerTimer;
  StreamSubscription<int>? _outboxSubscription;
  VoidCallback? _connectivityListenerRemover;
  SocketEventCallback? _socketPokeCallback;

  SyncBackgroundWorker({
    required this.db,
    this.apiClient,
    this.httpClient,
    required this.connectivityNotifier,
    this.socketService,
    String? deviceId,
    this.batchSize = 25,
    this.pollInterval = const Duration(seconds: 30),
    this.circuitBreakerPauseDuration = const Duration(seconds: 30),
    this.retentionPeriod = const Duration(days: 30),
    this.retentionPruneInterval = const Duration(hours: 24),
    this.zombieTimeout = const Duration(seconds: 60),
    Random? random,
    this.syncUrlOverride,
  })  : deviceId = deviceId ?? DeviceIdentityService.currentDeviceId,
        _random = random ?? Random();


  SyncWorkerState get state => stateNotifier.currentState;

  bool get isRunning => _isRunning && !_isDisposed;
  bool get isDraining => _isPushing || _isPulling || _isCycleRunning;
  DateTime? get lastSuccessAt => state.lastSuccessfulPush ?? state.lastSuccessfulPull;
  String? get lastError => state.lastError;

  String get _baseUrl {
    if (syncUrlOverride != null && syncUrlOverride!.isNotEmpty) {
      return syncUrlOverride!;
    }
    final base = apiClient?.baseUrl ?? ApiConfig.baseUrl;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. LIFECYCLE & STARTUP RECOVERY (§15.3 & Risk #8)
  // ───────────────────────────────────────────────────────────────────────────

  /// Starts the sync background engine.
  Future<void> start() async {
    if (_isRunning || _isDisposed) return;
    _isRunning = true;

    // FLT-11: Start periodic polling timer FIRST so periodic ticks are never aborted by startup exceptions
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(pollInterval, (_) {
      if (!_isDisposed && connectivityNotifier.isOnline) {
        _onPeriodicTick();
      }
    });

    // 1. Startup Recovery: Reap ALL orphaned IN_FLIGHT mutations left by unexpected crashes (§15.3, SYNC-025)
    try {
      await recoverOrphanedOutboxTasks(olderThan: Duration.zero);
    } catch (e) {
      debugPrint('[SyncWorker] Startup task recovery error: $e');
    }

    // 2. Watch local pending outbox entries
    try {
      _outboxSubscription = db.outboxDao.watchPendingCount().listen((count) {
        if (!_isDisposed) {
          stateNotifier.updateState(state.copyWith(pendingCount: count));
          if (count > 0 && connectivityNotifier.isOnline && !state.isAuthPaused && !state.isCircuitBreakerTripped) {
            triggerSyncCycle();
          }
        }
      });
    } catch (e) {
      debugPrint('[SyncWorker] Outbox watch error: $e');
    }

    // 3. Listen to connectivity state changes (Reconnection Flow §13)
    try {
      _connectivityListenerRemover = connectivityNotifier.addListener((connState) {
        if (!_isDisposed && connState.isOnline) {
          // Just came online: drain outbox immediately then pull deltas
          reconnect();
        }
      });
    } catch (e) {
      debugPrint('[SyncWorker] Connectivity listener error: $e');
    }

    // 4. Wire Real-Time "Poke" via Socket.IO (§9.1 & §4.4)
    if (socketService != null) {
      try {
        _socketPokeCallback = (payload) {
          if (!_isDisposed && connectivityNotifier.isOnline) {
            triggerSyncCycle();
          }
        };
        socketService!.on('*', _socketPokeCallback!);
      } catch (e) {
        debugPrint('[SyncWorker] Socket wire error: $e');
      }
    }

    // 5. Check if initial cold-start bootstrap is required (§8.1.3)
    try {
      final initialCursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      if (initialCursor == 0 && connectivityNotifier.isOnline) {
        await bootstrapInitialData();
      }
    } catch (e) {
      debugPrint('[SyncWorker] Bootstrap error: $e');
    }

    // 6. 30-Day Retention Pruning Job on Startup (§3.3, §18 Phase 7, Directive Q9.2)
    try {
      await pruneOldSyncedData();
    } catch (e) {
      debugPrint('[SyncWorker] Startup retention prune error: $e');
    }
  }

  /// Stops background activities without disposing.
  void stop() {
    _isRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _circuitBreakerTimer?.cancel();
    _circuitBreakerTimer = null;
    stateNotifier.updateState(state.copyWith(status: SyncWorkerStatus.stopped));
  }

  /// Single worker lifecycle with explicit disposal (Risk #8).
  void dispose() {
    _isDisposed = true;
    _isRunning = false;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _circuitBreakerTimer?.cancel();
    _circuitBreakerTimer = null;

    _outboxSubscription?.cancel();
    _outboxSubscription = null;

    _connectivityListenerRemover?.call();
    _connectivityListenerRemover = null;

    if (socketService != null && _socketPokeCallback != null) {
      socketService!.off('*', _socketPokeCallback);
      _socketPokeCallback = null;
    }

    if (_activeCycleCompleter != null && !_activeCycleCompleter!.isCompleted) {
      _activeCycleCompleter!.complete(const SyncCycleResult());
    }
    if (_queuedCycleCompleter != null && !_queuedCycleCompleter!.isCompleted) {
      _queuedCycleCompleter!.complete(const SyncCycleResult());
    }
  }

  /// Recovers zombie tasks older than [olderThan] left in `IN_FLIGHT` state per Spec §15.3.
  /// Safe because server processing is strictly idempotent.
  Future<int> recoverOrphanedOutboxTasks({Duration olderThan = const Duration(seconds: 60)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final count = await (db.update(db.syncOutbox)
          ..where((t) =>
              t.status.equals(SyncOutboxStatus.inFlight) &
              (olderThan == Duration.zero
                  ? const Constant(true)
                  : (t.sentAt.isNull() | t.sentAt.isSmallerOrEqual(Variable(cutoff))))))
        .write(const SyncOutboxCompanion(status: Value(SyncOutboxStatus.pending)));
    return count;
  }

  /// Cadence checkpointing for SQLite WAL mode (Risk #3).
  Future<void> walCheckpointCadence() async {
    try {
      await db.customStatement('PRAGMA wal_checkpoint(PASSIVE);');
    } catch (_) {}
  }

  /// 30-Day Retention Pruning Job per Spec §3.3, §18 Phase 7, Directive Q9.2.
  ///
  /// Prunes:
  /// - `local_orders` with syncStatus = 'synced' older than [olderThan] (default 30 days)
  /// - `sync_outbox` with status = 'SYNCED' older than [olderThan]
  /// - `offline_print_jobs` with status = 'PRINTED' older than [olderThan]
  ///
  /// Invariant: NEVER prunes pending, retryable, conflict, or failed rows.
  Future<RetentionPruneResult> pruneOldSyncedData({
    Duration? olderThan,
    DateTime? referenceDate,
  }) async {
    try {
      final effectiveDuration = olderThan ?? retentionPeriod;
      final result = await db.pruneSyncedDataOlderThan(
        olderThan: effectiveDuration,
        referenceDate: referenceDate,
      );
      _lastPruneAt = DateTime.now();
      return result;
    } catch (_) {
      // Non-blocking: database pruning failure should never halt sync engine
      return const RetentionPruneResult(
        ordersDeleted: 0,
        outboxDeleted: 0,
        printJobsDeleted: 0,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. RECONNECTION & TRIGGERS (§13)
  // ───────────────────────────────────────────────────────────────────────────

  /// Immediate reconnection sync: drains outbox batches then pulls deltas.
  Future<void> reconnect() async {
    if (_isDisposed) return;
    stateNotifier.updateState(state.copyWith(
      isCircuitBreakerTripped: false,
      consecutiveTimeouts: 0,
      lastError: null,
    ));
    await triggerSyncCycle(force: true);
  }

  void _onPeriodicTick() {
    // SYNC-025: Periodically recover orphaned in-flight tasks exceeding zombieTimeout
    recoverOrphanedOutboxTasks(olderThan: zombieTimeout);

    if (!state.isAuthPaused && !state.isCircuitBreakerTripped) {
      triggerSyncCycle();
    }

    // Check retention pruning cadence (§3.3, §18 Phase 7, Directive Q9.2)
    final now = DateTime.now();
    if (_lastPruneAt == null || now.difference(_lastPruneAt!) >= retentionPruneInterval) {
      pruneOldSyncedData();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. SINGLE-FLIGHT SYNC CYCLE (SYNC-004)
  // ───────────────────────────────────────────────────────────────────────────

  /// Runs a single-flight sync cycle: one mutex around a cycle that runs
  /// strictly in order PUSH (drain outbox) -> PULL (apply deltas).
  /// Overlapping triggers are coalesced into one queued run, never run in parallel.
  Future<SyncCycleResult> triggerSyncCycle({bool force = false}) async {
    if (_isDisposed) {
      return const SyncCycleResult();
    }

    if (_isCycleRunning) {
      _queuedCycle = true;
      if (force) {
        _queuedForcePush = true;
      }
      _queuedCycleCompleter ??= Completer<SyncCycleResult>();
      return _queuedCycleCompleter!.future;
    }

    _isCycleRunning = true;
    _activeCycleCompleter = Completer<SyncCycleResult>();

    var currentForce = force;
    SyncCycleResult lastResult = const SyncCycleResult();

    try {
      while (!_isDisposed) {
        lastResult = await _executeSyncCycle(force: currentForce);

        if (_activeCycleCompleter != null && !_activeCycleCompleter!.isCompleted) {
          _activeCycleCompleter!.complete(lastResult);
        }

        if (_queuedCycle && !_isDisposed) {
          _queuedCycle = false;
          currentForce = _queuedForcePush;
          _queuedForcePush = false;

          _activeCycleCompleter = _queuedCycleCompleter ?? Completer<SyncCycleResult>();
          _queuedCycleCompleter = null;
        } else {
          break;
        }
      }
    } catch (e, stack) {
      debugPrint('[SyncWorker] Unexpected error in sync cycle loop: $e\n$stack');
      if (_activeCycleCompleter != null && !_activeCycleCompleter!.isCompleted) {
        _activeCycleCompleter!.completeError(e, stack);
      }
      if (_queuedCycleCompleter != null && !_queuedCycleCompleter!.isCompleted) {
        _queuedCycleCompleter!.completeError(e, stack);
      }
    } finally {
      _isCycleRunning = false;
      _activeCycleCompleter = null;
      _queuedCycleCompleter = null;
      _queuedCycle = false;
      _queuedForcePush = false;
    }

    return lastResult;
  }

  /// Triggers a push synchronization cycle (runs under single-flight mutex: push then pull).
  Future<void> triggerPush({bool force = false}) => triggerSyncCycle(force: force);

  /// Triggers a delta pull replication stream (runs under single-flight mutex: push then pull).
  Future<void> triggerPull() => triggerSyncCycle();

  Future<SyncCycleResult> _executeSyncCycle({bool force = false}) async {
    // 1. PUSH: drain outbox
    final pushResult = await _drainPushOutbox(force: force);

    int pulledCount = 0;
    int skippedForPendingCount = 0;
    bool pullSuccess = true;

    // 2. PULL: only run if push did NOT fail with auth or network error (§5)
    if (!pushResult.networkOrAuthError &&
        !_isDisposed &&
        !state.isAuthPaused &&
        !state.isCircuitBreakerTripped) {
      final pullResult = await _pullDeltas();
      pulledCount = pullResult.pulledCount;
      skippedForPendingCount = pullResult.skippedForPendingCount;
      pullSuccess = pullResult.success;
    } else {
      pullSuccess = !pushResult.networkOrAuthError;
    }

    // 3. Short log line per cycle (counts pushed/pulled/skipped-for-pending) (§6)
    debugPrint(
      '[SyncWorker] Cycle finished: pushed=${pushResult.pushedCount}, pulled=$pulledCount, skipped_for_pending=$skippedForPendingCount',
    );

    final cycleResult = SyncCycleResult(
      pushedCount: pushResult.pushedCount,
      pulledCount: pulledCount,
      skippedForPendingCount: skippedForPendingCount,
      pushSuccess: pushResult.success,
      pullSuccess: pullSuccess,
      networkOrAuthError: pushResult.networkOrAuthError,
    );

    lastCycleResult = cycleResult;
    return cycleResult;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. PUSH PIPELINE (Spec §6.1-§6.4, §8.1.1)
  // ───────────────────────────────────────────────────────────────────────────

  Future<PushBatchDrainResult> _drainPushOutbox({bool force = false}) async {
    if (force) {
      if (state.isCircuitBreakerTripped || state.isAuthPaused) {
        stateNotifier.updateState(state.copyWith(
          isCircuitBreakerTripped: false,
          isAuthPaused: false,
          consecutiveTimeouts: 0,
          lastError: null,
        ));
      }
      try {
        await db.outboxDao.resetFailedEntries();
      } catch (_) {}
    }
    if (_isDisposed || (!force && (state.isAuthPaused || state.isCircuitBreakerTripped))) {
      return PushBatchDrainResult(
        pushedCount: 0,
        success: false,
        networkOrAuthError: state.isAuthPaused || state.isCircuitBreakerTripped,
      );
    }

    _isPushing = true;
    stateNotifier.updateState(state.copyWith(status: SyncWorkerStatus.pushing));

    int pushedCount = 0;
    bool success = true;
    bool networkOrAuthError = false;

    try {
      while (!_isDisposed && !state.isAuthPaused && !state.isCircuitBreakerTripped) {
        // Query batch sorted by dependency_order ASC, created_at ASC LIMIT 25 (§6.3)
        final batch = await db.outboxDao.getPushBatch(limit: batchSize, now: DateTime.now());
        if (batch.isEmpty) {
          break; // Queue fully drained
        }

        final inFlightSuccess = await _processPushBatch(batch);
        if (!inFlightSuccess) {
          networkOrAuthError = true;
          success = false;
          break; // Stop loop on network error, circuit breaker, or auth pause
        } else {
          pushedCount += batch.length;
        }
      }
    } finally {
      _isPushing = false;
      if (!_isDisposed && state.status == SyncWorkerStatus.pushing) {
        stateNotifier.updateState(state.copyWith(status: SyncWorkerStatus.idle));
      }
    }

    return PushBatchDrainResult(
      pushedCount: pushedCount,
      success: success,
      networkOrAuthError: networkOrAuthError,
    );
  }

  /// Computes deterministic batch_id from SHA-256 of sorted operation IDs (SYNC-024)
  static String computeBatchId(Iterable<SyncOutboxEntry> entries) {
    final sortedOpIds = entries.map((e) => e.operationId).toList()..sort();
    return sha256.convert(utf8.encode(sortedOpIds.join(':'))).toString();
  }

  Future<bool> _processPushBatch(List<SyncOutboxEntry> batch) async {
    final now = DateTime.now();
    final batchIds = batch.map((e) => e.id).toList();

    // Mark batch IN_FLIGHT (Tier 3 Anti-duplicate defense §15.2)
    await db.outboxDao.markInFlight(batchIds, now);

    // SYNC-024: Deterministic batch_id from SHA-256 of sorted operation IDs
    final batchId = computeBatchId(batch);
    final mutations = batch.map((entry) {
      dynamic parsedPayload;
      try {
        parsedPayload = jsonDecode(entry.payload);
      } catch (_) {
        parsedPayload = entry.payload;
      }

      return {
        'operation_id': entry.operationId,
        'entity_type': entry.entityType,
        'entity_id': entry.entityId,
        'operation_type': entry.operationType,
        'base_version': entry.baseVersion,
        'dependency_order': entry.dependencyOrder,
        if (entry.dependsOnOperationId != null)
          'depends_on_operation_id': entry.dependsOnOperationId,
        'created_at': entry.createdAt.toIso8601String(),
        'payload': parsedPayload,
      };
    }).toList();

    final requestBody = jsonEncode({
      'device_id': deviceId,
      'batch_id': batchId,
      'mutations': mutations,
    });

    final uri = Uri.parse('$_baseUrl/sync/push');
    final headers = await _buildHeaders(extraHeaders: {
      'X-Idempotency-Key': batchId,
    });

    http.Response response;
    try {
      final client = httpClient ?? http.Client();
      response = await client
          .post(uri, headers: headers, body: requestBody)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Network timeout / SocketException
      await _handleNetworkFailure(batch, 'Network failure: $e');
      return false;
    }

    // Handle HTTP 401 Unauthorized (Approved Deviation #3)
    if (response.statusCode == 401) {
      await _handleAuthPaused(batch, 'HTTP 401 Unauthorized: token expired or invalid');
      return false;
    }

    // Handle 5xx / 4xx server network error
    if (response.statusCode >= 500) {
      await _handleNetworkFailure(batch, 'Server error (HTTP ${response.statusCode})');
      return false;
    }

    if (response.statusCode >= 400 && response.statusCode < 500) {
      // Client validation failure or bad request (SYNC-018: Invariant #3 No Batch Poisoning)
      if (batch.length > 1) {
        debugPrint('[SyncWorker] SYNC-018: HTTP ${response.statusCode} on batch of ${batch.length} items. Isolating poison pill via single-item dispatch...');
        for (final singleEntry in batch) {
          await _processPushBatch([singleEntry]);
        }
        return true;
      } else {
        await _handleFatalBatch(batch, 'Client error (HTTP ${response.statusCode}): ${response.body}');
        return true;
      }
    }

    // HTTP 200 OK: Process per-mutation results transactionally
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = decoded['results'] as List<dynamic>? ?? [];

      await db.transaction(() async {
        for (final entry in batch) {
          final result = results.whereType<Map<String, dynamic>>().firstWhere(
                (r) => r['operation_id'] == entry.operationId,
                orElse: () => <String, dynamic>{},
              );

          if (result.isEmpty) {
            // No result found for this mutation; keep as retryable
            await db.outboxDao.markFailedRetryable(
              entry.id,
              error: 'Missing result envelope from server',
              retryCount: entry.retryCount + 1,
              nextRetryAt: _computeNextRetry(entry.retryCount),
            );
            continue;
          }

          final status = (result['status'] as String? ?? 'FAILED_FATAL').toUpperCase();
          final serverVersion = (result['server_version'] as num?)?.toInt() ?? 1;
          final serverTimestamp = result['server_timestamp'] != null
              ? DateTime.tryParse(result['server_timestamp'].toString()) ?? DateTime.now()
              : DateTime.now();
          final errorMessage = result['error_message']?.toString();
          final conflictDetails = result['conflict_details'];

          if (status == 'SYNCED' || status == 'DUPLICATE' || status == 'APPLIED') {
            await db.outboxDao.markSynced(entry.id, serverTimestamp);

            // Stamp replicated operational tables (§3.3 Tier 4)
            if (entry.entityType == 'order') {
              await db.ordersDao.markOrderSynced(entry.entityId, serverVersion, serverTimestamp);

              // SYNC-020: If server reassigned order_number due to collision, update local SQLite row
              final reassignedOrderNumber = result['reassigned_order_number'] ?? (status == 'APPLIED' ? result['order_number'] : null);
              if (reassignedOrderNumber is String && reassignedOrderNumber.isNotEmpty) {
                final localOrder = await db.ordersDao.getOrderById(entry.entityId);
                if (localOrder != null && localOrder.orderNumber != reassignedOrderNumber) {
                  debugPrint('[SyncWorker] SYNC-020: Updating local order ${entry.entityId} orderNumber from ${localOrder.orderNumber} to reassigned $reassignedOrderNumber');
                  await db.ordersDao.updateReassignedOrderNumber(entry.entityId, reassignedOrderNumber);
                }
              }
            } else if (entry.entityType == 'shift') {
              await db.dailyCalculationsDao.markCalculationSynced(entry.entityId, serverVersion);
              if (entry.operationType == 'UPDATE') {
                await db.dailyCalculationsDao.markShiftClosed(entry.entityId, closedAt: serverTimestamp);
              }
            }
          } else if (status == 'CONFLICT') {
            Map<String, dynamic>? detailsMap;
            if (conflictDetails is Map<String, dynamic>) {
              detailsMap = conflictDetails;
            } else if (conflictDetails is String) {
              try {
                final parsed = jsonDecode(conflictDetails);
                if (parsed is Map<String, dynamic>) {
                  detailsMap = parsed;
                }
              } catch (_) {}
            }

            final isTable = entry.entityType == 'table' || entry.entityType == 'restaurant_table';
            final isAutoResolvable = detailsMap?['auto_resolvable'] == true;
            final serverState = detailsMap?['server_state'] as Map<String, dynamic>?;

            if (isTable && isAutoResolvable && serverState != null) {
              // Auto-resolve per Hospitality Policy (§10.1, §10.2):
              // Update local row to server state, mark outbox SYNCED
              await db.catalogDao.upsertRestaurantTables([
                LocalRestaurantTablesCompanion(
                  id: Value(entry.entityId),
                  zoneId: Value(serverState['zone_id']?.toString()),
                  tableNumber: Value(serverState['table_number']?.toString() ?? ''),
                  name: Value(serverState['name']?.toString() ?? ''),
                  capacity: Value((serverState['capacity'] as num?)?.toInt() ?? 4),
                  status: Value(serverState['status']?.toString() ?? 'available'),
                  activeOrderId: Value(serverState['active_order_id']?.toString()),
                  version: Value((serverState['version'] as num?)?.toInt() ?? serverVersion),
                ),
              ]);

              await db.outboxDao.markSynced(entry.id, serverTimestamp);

              // Durably record resolved conflict in sync_conflicts for audit trail
              await db.into(db.syncConflicts).insert(
                    SyncConflictsCompanion(
                      id: Value(const Uuid().v7()),
                      operationId: Value(entry.operationId),
                      entityType: Value(entry.entityType),
                      entityId: Value(entry.entityId),
                      conflictType: Value(
                        detailsMap?['conflict_code']?.toString() ?? ConflictType.occMismatch,
                      ),
                      resolutionStatus: const Value(ConflictResolutionStatus.autoResolved),
                      errorMessage: Value(errorMessage),
                      payload: Value(entry.payload),
                      serverState: Value(jsonEncode(serverState)),
                      createdAt: Value(DateTime.now()),
                      resolvedAt: Value(DateTime.now()),
                    ),
                  );
            } else if (entry.entityType == 'order' && serverVersion > entry.baseVersion && entry.retryCount < 3) {
              // Auto-rebase OCC base_version for order update and requeue
              await db.ordersDao.markOrderSynced(entry.entityId, serverVersion, serverTimestamp);
              await (db.update(db.syncOutbox)..where((t) => t.id.equals(entry.id))).write(
                SyncOutboxCompanion(
                  baseVersion: Value(serverVersion),
                  status: const Value(SyncOutboxStatus.pending),
                  retryCount: Value(entry.retryCount + 1),
                  conflictDetails: const Value(null),
                  lastError: const Value(null),
                ),
              );
            } else {
              // Cannot auto-resolve: record in sync_conflicts with conflictDetails and mark outbox as CONFLICT
              final conflictCode = detailsMap?['conflict_code']?.toString() ?? ConflictType.occMismatch;
              final formattedDetails = conflictDetails != null
                  ? (conflictDetails is String ? conflictDetails : jsonEncode(conflictDetails))
                  : (errorMessage ?? 'Server OCC conflict detected');

              await db.outboxDao.markConflict(
                entry.id,
                conflictDetails: formattedDetails,
              );

              // Quarantine to sync_conflicts table (§3.3 Tier 5) with pending resolution
              await db.into(db.syncConflicts).insert(
                    SyncConflictsCompanion(
                      id: Value(const Uuid().v7()),
                      operationId: Value(entry.operationId),
                      entityType: Value(entry.entityType),
                      entityId: Value(entry.entityId),
                      conflictType: Value(conflictCode),
                      resolutionStatus: const Value(ConflictResolutionStatus.pending),
                      errorMessage: Value(errorMessage),
                      payload: Value(entry.payload),
                      serverState: Value(
                        serverState != null
                            ? jsonEncode(serverState)
                            : (conflictDetails != null
                                ? (conflictDetails is String ? conflictDetails : jsonEncode(conflictDetails))
                                : null),
                      ),
                      createdAt: Value(DateTime.now()),
                    ),
                  );

              if (entry.entityType == 'order') {
                await db.ordersDao.markOrderConflict(entry.entityId);
              }
            }
          } else if (status == 'FAILED_FATAL') {
            // Poison-pill isolation: quarantine fatal error without blocking other mutations
            await db.outboxDao.markFailedFatal(
              entry.id,
              error: errorMessage ?? 'Fatal operation failure',
              conflictDetails: conflictDetails != null ? jsonEncode(conflictDetails) : null,
            );

            await db.into(db.syncConflicts).insert(
                  SyncConflictsCompanion(
                    id: Value(const Uuid().v7()),
                    operationId: Value(entry.operationId),
                    entityType: Value(entry.entityType),
                    entityId: Value(entry.entityId),
                    conflictType: const Value(ConflictType.fatalError),
                    resolutionStatus: const Value(ConflictResolutionStatus.pending),
                    errorMessage: Value(errorMessage ?? 'Fatal operation failure'),
                    payload: Value(entry.payload),
                    createdAt: Value(DateTime.now()),
                  ),
                );
          } else if (status == 'FAILED_RETRYABLE') {
            await db.outboxDao.markFailedRetryable(
              entry.id,
              error: errorMessage ?? 'Server requested retry',
              retryCount: entry.retryCount + 1,
              nextRetryAt: _computeNextRetry(entry.retryCount),
            );
          }
        }
      });

      // Reset circuit breaker consecutive failure counter on successful request
      stateNotifier.updateState(state.copyWith(
        consecutiveTimeouts: 0,
        isCircuitBreakerTripped: false,
        lastSuccessfulPush: DateTime.now(),
        lastError: null,
      ));

      // Checkpoint cadence check
      _mutationsProcessedSinceLastWalCheckpoint += batch.length;
      if (_mutationsProcessedSinceLastWalCheckpoint >= 1000) {
        await walCheckpointCadence();
        _mutationsProcessedSinceLastWalCheckpoint = 0;
      }

      return true;
    } catch (e) {
      await _handleNetworkFailure(batch, 'Failed to process push response: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. RETRY BACKOFF & CIRCUIT BREAKER (§6.4)
  // ───────────────────────────────────────────────────────────────────────────

  /// Computes exponential backoff with jitter per Spec §6.4:
  /// delay = min(300, 2.0 * 2^retry_count) * (0.75 + 0.5 * random())
  DateTime _computeNextRetry(int retryCount) {
    final baseDelay = min(300.0, 2.0 * pow(2, retryCount));
    final jitter = 0.75 + 0.5 * _random.nextDouble();
    final delaySeconds = baseDelay * jitter;
    return DateTime.now().add(Duration(milliseconds: (delaySeconds * 1000).toInt()));
  }

  Future<void> _handleNetworkFailure(List<SyncOutboxEntry> batch, String error) async {
    final nextTimeouts = state.consecutiveTimeouts + 1;
    final tripsBreaker = nextTimeouts >= 5;

    // Apply backoff formula to all entries in failed batch
    for (final entry in batch) {
      final nextRetryAt = _computeNextRetry(entry.retryCount);
      await db.outboxDao.markFailedRetryable(
        entry.id,
        error: error,
        retryCount: entry.retryCount + 1,
        nextRetryAt: nextRetryAt,
      );
    }

    stateNotifier.updateState(state.copyWith(
      status: tripsBreaker ? SyncWorkerStatus.circuitBreakerTripped : SyncWorkerStatus.error,
      consecutiveTimeouts: nextTimeouts,
      isCircuitBreakerTripped: tripsBreaker,
      lastError: error,
    ));

    if (tripsBreaker) {
      _tripCircuitBreaker();
    }
  }

  void _tripCircuitBreaker() {
    _circuitBreakerTimer?.cancel();
    _circuitBreakerTimer = Timer(circuitBreakerPauseDuration, () async {
      if (_isDisposed) return;

      // After 30s pause, probe /api/health
      final isHealthy = await connectivityNotifier.probeHealth();
      if (isHealthy) {
        // Reset circuit breaker
        stateNotifier.updateState(state.copyWith(
          status: SyncWorkerStatus.idle,
          consecutiveTimeouts: 0,
          isCircuitBreakerTripped: false,
          lastError: null,
        ));
        // Resume push processing
        triggerPush();
      } else {
        // Still down: schedule another check
        _tripCircuitBreaker();
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. AUTHENTICATION PAUSE & RESUME (Approved Deviation #3)
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleAuthPaused(List<SyncOutboxEntry> batch, String error) async {
    final newToken = await trySilentReauth();
    if (newToken != null && newToken.isNotEmpty) {
      stateNotifier.updateState(state.copyWith(isAuthPaused: false));
      await resumeAuthPaused();
      return;
    }

    for (final entry in batch) {
      await db.outboxDao.markAuthPaused(entry.id, error: error);
    }

    stateNotifier.updateState(state.copyWith(
      status: SyncWorkerStatus.authPaused,
      isAuthPaused: true,
      lastError: error,
    ));
  }

  /// Resumes outbox queue from AUTH_PAUSED back to PENDING after successful re-auth.
  Future<void> resumeAuthPaused() async {
    await db.outboxDao.resumeAuthPaused();
    stateNotifier.updateState(state.copyWith(
      status: SyncWorkerStatus.idle,
      isAuthPaused: false,
      lastError: null,
    ));
    await triggerPush();
  }

  Future<void> _handleFatalBatch(List<SyncOutboxEntry> batch, String error) async {
    for (final entry in batch) {
      await db.outboxDao.markFailedFatal(entry.id, error: error);
      await db.into(db.syncConflicts).insert(
            SyncConflictsCompanion(
              id: Value(const Uuid().v7()),
              operationId: Value(entry.operationId),
              entityType: Value(entry.entityType),
              entityId: Value(entry.entityId),
              conflictType: const Value(ConflictType.fatalError),
              resolutionStatus: const Value(ConflictResolutionStatus.pending),
              errorMessage: Value(error),
              payload: Value(entry.payload),
              createdAt: Value(DateTime.now()),
            ),
          );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. PULL PIPELINE (§8.1.2, §8.1.3, §10.2)
  // ───────────────────────────────────────────────────────────────────────────

  /// Checks if the target entity has any pending or in-flight outbox entries (SYNC-004 §2).
  Future<bool> _hasPendingOutbox(String entityId) async {
    if (entityId.isEmpty) return false;
    final pending = await (db.select(db.syncOutbox)
          ..where((t) =>
              t.entityId.equals(entityId) &
              (t.status.equals(SyncOutboxStatus.pending) |
                  t.status.equals(SyncOutboxStatus.inFlight) |
                  t.status.equals(SyncOutboxStatus.failedRetryable) |
                  t.status.equals(SyncOutboxStatus.authPaused)))
          ..limit(1))
        .get();
    return pending.isNotEmpty;
  }

  /// Internal delta pull replication stream (runs strictly after push under single-flight mutex).
  Future<PullStreamResult> _pullDeltas() async {
    if (_isDisposed || state.isAuthPaused || state.isCircuitBreakerTripped) {
      return const PullStreamResult(pulledCount: 0, skippedForPendingCount: 0, success: false);
    }

    _isPulling = true;
    stateNotifier.updateState(state.copyWith(status: SyncWorkerStatus.pulling));

    int pulledCount = 0;
    int skippedForPendingCount = 0;
    bool success = true;

    try {
      final currentCursor = await db.syncCursorsDao.getLastPulledSequence('GLOBAL_PULL_CURSOR');
      if (currentCursor == 0) {
        await bootstrapInitialData();
        return const PullStreamResult(pulledCount: 0, skippedForPendingCount: 0, success: true);
      }

      var cursor = currentCursor;
      var hasMore = true;

      while (hasMore && !_isDisposed) {
        final uri = Uri.parse('$_baseUrl/sync/pull').replace(queryParameters: {
          'cursor': cursor.toString(),
          'device_id': deviceId,
          'limit': '100',
        });

        final headers = await _buildHeaders();
        final client = httpClient ?? http.Client();
        final response = await client.get(uri, headers: headers).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          success = false;
          break;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final changes = decoded['changes'] as List<dynamic>? ?? [];
        final nextCursor = (decoded['next_cursor'] as num?)?.toInt() ?? cursor;
        hasMore = decoded['has_more'] == true;

        if (changes.isNotEmpty) {
          int? lastAppliedSeq;
          bool hadPendingSkip = false;

          await db.transaction(() async {
            for (final change in changes.whereType<Map<String, dynamic>>()) {
              final entityId = change['entity_id']?.toString() ?? '';
              final changeSeq = (change['sequence'] as num?)?.toInt();

              // Check if entity has pending/in-flight outbox entries (§2)
              if (entityId.isNotEmpty && await _hasPendingOutbox(entityId)) {
                hadPendingSkip = true;
                skippedForPendingCount++;
                break; // Do not apply; skip and re-pull later from lastAppliedSeq
              }

              final applyResult = await _applyPullChange(change);
              if (applyResult == PullApplyResult.applied) {
                pulledCount++;
                if (changeSeq != null) lastAppliedSeq = changeSeq;
              } else if (applyResult == PullApplyResult.ignoredStale) {
                if (changeSeq != null) lastAppliedSeq = changeSeq;
              } else if (applyResult == PullApplyResult.skippedPending) {
                hadPendingSkip = true;
                skippedForPendingCount++;
                break;
              }
            }

            // Advance cursor only after batch changes processed inside transaction (§4)
            final targetCursor = hadPendingSkip
                ? (lastAppliedSeq ?? cursor)
                : nextCursor;

            if (targetCursor > cursor) {
              await db.syncCursorsDao.setCursor(
                'GLOBAL_PULL_CURSOR',
                targetCursor,
                lastSyncAttempt: DateTime.now(),
                lastSuccessfulSync: DateTime.now(),
              );
              cursor = targetCursor;
            }
          });

          if (hadPendingSkip) {
            hasMore = false; // Stop further paging in this cycle; wait for push to drain
          }
        } else {
          await db.syncCursorsDao.setCursor(
            'GLOBAL_PULL_CURSOR',
            nextCursor,
            lastSyncAttempt: DateTime.now(),
            lastSuccessfulSync: DateTime.now(),
          );
          cursor = nextCursor;
        }
      }

      stateNotifier.updateState(state.copyWith(
        lastSuccessfulPull: DateTime.now(),
      ));
    } catch (e, stack) {
      debugPrint('[SyncWorker] Pull replication error: $e\n$stack');
      success = false;
    } finally {
      _isPulling = false;
      if (!_isDisposed && state.status == SyncWorkerStatus.pulling) {
        stateNotifier.updateState(state.copyWith(status: SyncWorkerStatus.idle));
      }
    }

    return PullStreamResult(
      pulledCount: pulledCount,
      skippedForPendingCount: skippedForPendingCount,
      success: success,
    );
  }

  /// Cold-start bootstrap catalog hydration (§8.1.3).
  Future<bool> bootstrapInitialData() async {
    try {
      final uri = Uri.parse('$_baseUrl/sync/bootstrap').replace(queryParameters: {'raw': 'true'});
      final headers = await _buildHeaders(extraHeaders: {
        'Accept': 'application/json',
      });

      final client = httpClient ?? http.Client();
      final response = await client.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return false;
      }

      dynamic bodyJson;
      // Handle optional gzip decompression if server compressed
      final isGzipped = response.headers['content-encoding'] == 'gzip' ||
          (response.bodyBytes.length > 2 && response.bodyBytes[0] == 0x1f && response.bodyBytes[1] == 0x8b);

      if (isGzipped) {
        final decompressed = gzip.decode(response.bodyBytes);
        bodyJson = jsonDecode(utf8.decode(decompressed));
      } else {
        bodyJson = jsonDecode(response.body);
      }

      if (bodyJson is Map<String, dynamic>) {
        await _applyBootstrapData(bodyJson);
        stateNotifier.updateState(state.copyWith(
          lastSuccessfulPull: DateTime.now(),
        ));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _applyBootstrapData(Map<String, dynamic> data) async {
    await db.transaction(() async {
      // 1. Store settings
      if (data['store_settings'] is List) {
        for (final s in (data['store_settings'] as List).whereType<Map<String, dynamic>>()) {
          await db.catalogDao.upsertStoreSettings(LocalStoreSettingsCompanion(
            id: Value(s['id']?.toString() ?? 'store-1'),
            chainName: Value(s['chain_name']?.toString() ?? 'Hungry Howies'),
            branchCode: Value(s['branch_code']?.toString() ?? 'HH01'),
            branchName: Value(s['branch_name']?.toString() ?? 'Main Branch'),
            storePhone: Value(s['store_phone']?.toString() ?? ''),
            taxPercentage: Value((s['tax_percentage'] as num?)?.toDouble() ?? 0.0),
          ));
        }
      }

      // 2. Role permissions
      if (data['role_permissions'] is List) {
        final list = <LocalRolePermissionsCompanion>[];
        for (final p in (data['role_permissions'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalRolePermissionsCompanion(
            id: Value(p['id']?.toString() ?? const Uuid().v7()),
            role: Value(p['role']?.toString() ?? 'cashier'),
            moduleName: Value(p['module_name']?.toString() ?? ''),
            actionName: Value(p['action_name']?.toString() ?? ''),
            isGranted: Value(p['is_granted'] == true),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertRolePermissions(list);
      }

      // 3. Staff users
      if (data['staff_users'] is List) {
        final list = <LocalStaffUsersCompanion>[];
        for (final u in (data['staff_users'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalStaffUsersCompanion(
            id: Value(u['id']?.toString() ?? const Uuid().v7()),
            username: Value(u['username']?.toString() ?? ''),
            role: Value(u['role']?.toString() ?? 'cashier'),
            pinHash: Value(u['pin_hash']?.toString()),
            isActive: Value(u['is_active'] != false),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertStaffUsers(list);
      }

      // 4. Menu categories
      if (data['categories'] is List) {
        final list = <LocalMenuCategoriesCompanion>[];
        for (final c in (data['categories'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalMenuCategoriesCompanion(
            id: Value(c['id']?.toString() ?? ''),
            name: Value(c['name']?.toString() ?? ''),
            displayOrder: Value((c['display_order'] as num?)?.toInt() ?? 0),
            isActive: Value(c['is_active'] != false),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertMenuCategories(list);
      }

      // 5. Menu items
      if (data['menu_items'] is List) {
        final list = <LocalMenuItemsCompanion>[];
        for (final item in (data['menu_items'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalMenuItemsCompanion(
            id: Value(item['id']?.toString() ?? ''),
            categoryId: Value(item['category_id']?.toString() ?? ''),
            name: Value(item['name']?.toString() ?? ''),
            basePrice: Value((item['base_price'] as num?)?.toDouble() ?? 0.0),
            isAvailable: Value(item['is_available'] != false),
            isVeg: Value(item['is_veg'] == true),
            isSpicy: Value(item['is_spicy'] == true),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertMenuItems(list);
      }

      // 6. Menu sizes
      if (data['menu_sizes'] is List) {
        final list = <LocalMenuItemSizesCompanion>[];
        for (final s in (data['menu_sizes'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalMenuItemSizesCompanion(
            id: Value(s['id']?.toString() ?? ''),
            menuItemId: Value(s['menu_item_id']?.toString() ?? ''),
            sizeName: Value(s['size_name']?.toString() ?? ''),
            priceMultiplier: Value((s['price_multiplier'] as num?)?.toDouble() ?? 1.0),
            isDefault: Value(s['is_default'] == true),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertMenuItemSizes(list);
      }

      // 7. Menu options
      if (data['menu_options'] is List) {
        final list = <LocalMenuItemOptionsCompanion>[];
        for (final o in (data['menu_options'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalMenuItemOptionsCompanion(
            id: Value(o['id']?.toString() ?? ''),
            menuItemId: Value(o['menu_item_id']?.toString() ?? ''),
            groupName: Value(o['group_name']?.toString() ?? ''),
            optionName: Value(o['option_name']?.toString() ?? ''),
            additionalPrice: Value((o['additional_price'] as num?)?.toDouble() ?? 0.0),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertMenuItemOptions(list);
      }

      // 8. Deals and components
      if (data['deals'] is List) {
        final dealList = <LocalDealsCompanion>[];
        final compList = <LocalDealComponentsCompanion>[];
        for (final d in (data['deals'] as List).whereType<Map<String, dynamic>>()) {
          dealList.add(LocalDealsCompanion(
            id: Value(d['id']?.toString() ?? ''),
            name: Value(d['name']?.toString() ?? ''),
            dealPrice: Value((d['deal_price'] as num?)?.toDouble() ?? 0.0),
            isAvailable: Value(d['is_available'] != false),
          ));
          if (d['components'] is List) {
            for (final comp in (d['components'] as List).whereType<Map<String, dynamic>>()) {
              compList.add(LocalDealComponentsCompanion(
                id: Value(comp['id']?.toString() ?? const Uuid().v7()),
                dealId: Value(d['id']?.toString() ?? ''),
                menuItemId: Value(comp['menu_item_id']?.toString()),
                quantity: Value(comp['quantity']?.toString() ?? '1'),
              ));
            }
          }
        }
        if (dealList.isNotEmpty) await db.catalogDao.upsertDeals(dealList);
        if (compList.isNotEmpty) await db.catalogDao.upsertDealComponents(compList);
      }

      // 9. Floor zones
      if (data['floor_zones'] is List) {
        final list = <LocalFloorZonesCompanion>[];
        for (final z in (data['floor_zones'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalFloorZonesCompanion(
            id: Value(z['id']?.toString() ?? ''),
            name: Value(z['name']?.toString() ?? ''),
            displayOrder: Value((z['display_order'] as num?)?.toInt() ?? 0),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertFloorZones(list);
      }

      // 10B. Active Shift from Bootstrap
      if (data['active_shift'] is Map<String, dynamic>) {
        final shift = data['active_shift'] as Map<String, dynamic>;
        final shiftId = shift['id']?.toString();
        if (shiftId != null && shiftId.isNotEmpty) {
          final existingShift = await db.dailyCalculationsDao.getCalculationById(shiftId);
          final isLocallyClosed = existingShift != null &&
              (existingShift.status.toUpperCase() == DailyCalculationStatus.closed ||
               existingShift.status.toUpperCase() == DailyCalculationStatus.offlineClosed);

          if (!isLocallyClosed) {
            final startingCash = (shift['starting_cash'] as num?)?.toDouble() ??
                (shift['opening_float'] as num?)?.toDouble() ?? 0.0;
            final status = shift['status']?.toString() ?? DailyCalculationStatus.active;
            final createdAt = shift['created_at'] != null
                ? DateTime.tryParse(shift['created_at'].toString()) ?? DateTime.now()
                : DateTime.now();

            await db.dailyCalculationsDao.upsertCalculation(
              LocalDailyCalculationsCompanion(
                id: Value(shiftId),
                cashierId: Value(shift['cashier_id']?.toString() ?? 'UNKNOWN'),
                cashierName: Value(shift['cashier_name']?.toString() ?? 'Cashier'),
                startingCash: Value(startingCash),
                expectedCashDrawer: Value(startingCash),
                status: Value(status),
                createdAt: Value(createdAt),
                syncStatus: const Value('synced'),
                serverVersion: Value((shift['version'] as num?)?.toInt() ?? 1),
              ),
            );
          }
        }
      }

      // 10. Tables
      if (data['tables'] is List) {
        final list = <LocalRestaurantTablesCompanion>[];
        for (final t in (data['tables'] as List).whereType<Map<String, dynamic>>()) {
          list.add(LocalRestaurantTablesCompanion(
            id: Value(t['id']?.toString() ?? ''),
            zoneId: Value(t['zone_id']?.toString()),
            tableNumber: Value(t['table_number']?.toString() ?? ''),
            name: Value(t['name']?.toString() ?? ''),
            capacity: Value((t['capacity'] as num?)?.toInt() ?? 4),
            status: Value(t['status']?.toString() ?? 'available'),
            activeOrderId: Value(t['active_order_id']?.toString()),
            version: Value((t['version'] as num?)?.toInt() ?? 1),
          ));
        }
        if (list.isNotEmpty) await db.catalogDao.upsertRestaurantTables(list);
      }

      // 11. Initial cursor sequence
      final maxSeq = (data['max_global_sequence'] as num?)?.toInt() ?? 0;
      await db.syncCursorsDao.setCursor(
        'GLOBAL_PULL_CURSOR',
        maxSeq,
        lastSyncAttempt: DateTime.now(),
        lastSuccessfulSync: DateTime.now(),
      );
    });
  }

  @visibleForTesting
  Future<PullApplyResult> applyPullChange(Map<String, dynamic> change) => _applyPullChange(change);

  Future<PullApplyResult> _applyPullChange(Map<String, dynamic> change) async {
    final entityType = (change['entity_type'] as String? ?? '').toLowerCase().trim();
    final entityId = change['entity_id']?.toString() ?? '';
    final recordVersion = (change['record_version'] as num?)?.toInt() ?? 1;
    final isDeleted = change['is_deleted'] == true || change['operation'] == 'DELETE';
    final payload = change['payload'] is Map<String, dynamic>
        ? change['payload'] as Map<String, dynamic>
        : (change['data'] is Map<String, dynamic> ? change['data'] as Map<String, dynamic> : <String, dynamic>{});

    // 1. Ignore echo of own writes (§10.1 & Phase 5)
    final changeDeviceId = payload['origin_device_id'] ?? payload['device_id'];
    if (changeDeviceId != null && changeDeviceId.toString() == deviceId) {
      return PullApplyResult.ignoredStale; // Ignore echo of own writes
    }
    final changeOpId = payload['operation_id']?.toString();
    if (changeOpId != null) {
      final ownEntry = await db.outboxDao.getEntryByOperationId(changeOpId);
      if (ownEntry != null) {
        return PullApplyResult.ignoredStale; // Ignore echo of own writes via operation_id match
      }
    }

    // 2. Pending outbox guard (§2): Do not apply pull delta for an entity that still has pending/in-flight outbox entries.
    if (entityId.isNotEmpty && await _hasPendingOutbox(entityId)) {
      return PullApplyResult.skippedPending;
    }

    switch (entityType) {
      case 'restaurant_table':
      case 'table':
        final existing = await db.catalogDao.getTableById(entityId);
        // Apply table changes only when version is newer (§10 OCC)
        if (existing != null && existing.version >= recordVersion) {
          return PullApplyResult.ignoredStale;
        }

        if (isDeleted) {
          await (db.delete(db.localRestaurantTables)..where((t) => t.id.equals(entityId))).go();
          return PullApplyResult.applied;
        } else {
          // Hospitality Operational Priority (§10.2):
          // If local table is occupied by an active local order, physical seated guest wins!
          var finalStatus = payload['status']?.toString() ?? 'available';
          String? finalOrderId = payload['active_order_id']?.toString();

          if (existing != null && existing.status == 'occupied' && existing.activeOrderId != null) {
            // Keep local occupancy
            finalStatus = 'occupied';
            finalOrderId = existing.activeOrderId;
          }

          await db.catalogDao.upsertRestaurantTables([
            LocalRestaurantTablesCompanion(
              id: Value(entityId),
              zoneId: Value(payload['zone_id']?.toString()),
              tableNumber: Value(payload['table_number']?.toString() ?? existing?.tableNumber ?? ''),
              name: Value(payload['name']?.toString() ?? existing?.name ?? ''),
              capacity: Value((payload['capacity'] as num?)?.toInt() ?? existing?.capacity ?? 4),
              status: Value(finalStatus),
              activeOrderId: Value(finalOrderId),
              version: Value(recordVersion),
            ),
          ]);
          return PullApplyResult.applied;
        }

      case 'shift':
      case 'daily_calculation':
        final existingShift = await db.dailyCalculationsDao.getCalculationById(entityId);
        final isLocallyClosed = existingShift != null &&
            (existingShift.status.toUpperCase() == DailyCalculationStatus.closed ||
             existingShift.status.toUpperCase() == DailyCalculationStatus.offlineClosed);

        if (existingShift != null && existingShift.serverVersion >= recordVersion && !isLocallyClosed) {
          return PullApplyResult.ignoredStale;
        }

        if (isDeleted) {
          await (db.delete(db.localDailyCalculations)..where((t) => t.id.equals(entityId))).go();
          return PullApplyResult.applied;
        } else {
          final serverStatus = (payload['status']?.toString() ?? DailyCalculationStatus.active).toUpperCase();

          // Terminal closure guard: A locally CLOSED or OFFLINE_CLOSED shift must NEVER revert to ACTIVE.
          String finalStatus;
          if (isLocallyClosed) {
            if (serverStatus == DailyCalculationStatus.closed) {
              finalStatus = DailyCalculationStatus.closed;
            } else {
              // Stale server delta says ACTIVE; keep local closed status!
              finalStatus = existingShift.status;
            }
          } else {
            finalStatus = serverStatus;
          }

          final startingCash = (payload['starting_cash'] as num?)?.toDouble() ??
              (payload['opening_float'] as num?)?.toDouble() ??
              existingShift?.startingCash ??
              0.0;
          final serverActualCash = (payload['actual_cash_counted'] as num?)?.toDouble() ??
              (payload['cash_submitted'] as num?)?.toDouble();
          final serverCashVariance = (payload['cash_variance'] as num?)?.toDouble();

          // Merge counted cash and variance from local if locally closed
          final double? finalActualCash;
          final double finalCashVariance;
          if (isLocallyClosed && existingShift.actualCashCounted != null) {
            finalActualCash = existingShift.actualCashCounted;
            finalCashVariance = existingShift.cashVariance;
          } else {
            finalActualCash = serverActualCash ?? existingShift?.actualCashCounted;
            finalCashVariance = serverCashVariance ?? existingShift?.cashVariance ?? 0.0;
          }

          final closingNotes = (isLocallyClosed && existingShift.closingNotes != null)
              ? existingShift.closingNotes
              : (payload['closing_notes']?.toString() ?? existingShift?.closingNotes);

          final submittedAt = (isLocallyClosed && existingShift.submittedAt != null)
              ? existingShift.submittedAt
              : (payload['submitted_at'] != null
                  ? DateTime.tryParse(payload['submitted_at'].toString()) ?? existingShift?.submittedAt
                  : existingShift?.submittedAt);

          final createdAt = payload['created_at'] != null
              ? DateTime.tryParse(payload['created_at'].toString()) ?? DateTime.now()
              : (existingShift?.createdAt ?? DateTime.now());

          final syncStatus = isLocallyClosed && finalStatus != DailyCalculationStatus.closed
              ? existingShift.syncStatus
              : 'synced';

          final effectiveVersion = recordVersion > (existingShift?.serverVersion ?? 0)
              ? recordVersion
              : (existingShift?.serverVersion ?? recordVersion);

          await db.dailyCalculationsDao.upsertCalculation(
            LocalDailyCalculationsCompanion(
              id: Value(entityId),
              cashierId: Value(payload['cashier_id']?.toString() ?? existingShift?.cashierId ?? 'UNKNOWN'),
              cashierName: Value(payload['cashier_name']?.toString() ?? existingShift?.cashierName ?? 'Cashier'),
              startingCash: Value(startingCash),
              expectedCashDrawer: Value(startingCash),
              actualCashCounted: finalActualCash != null ? Value(finalActualCash) : const Value.absent(),
              cashVariance: Value(finalCashVariance),
              status: Value(finalStatus),
              closingNotes: Value(closingNotes),
              submittedAt: Value(submittedAt),
              createdAt: Value(createdAt),
              syncStatus: Value(syncStatus),
              serverVersion: Value(effectiveVersion),
            ),
          );
          return PullApplyResult.applied;
        }

      case 'order':
        final existingOrder = await db.ordersDao.getOrderById(entityId);
        if (existingOrder != null && existingOrder.serverVersion >= recordVersion) {
          return PullApplyResult.ignoredStale; // Ignore stale or duplicate
        }

        if (isDeleted) {
          await db.ordersDao.deleteOrder(entityId);
          return PullApplyResult.applied;
        } else if (existingOrder != null) {
          final serverUpdatedAt = change['created_at'] != null
              ? DateTime.tryParse(change['created_at'].toString()) ?? DateTime.now()
              : DateTime.now();

          await (db.update(db.localOrders)..where((t) => t.id.equals(entityId))).write(
            LocalOrdersCompanion(
              status: Value(payload['status']?.toString() ?? existingOrder.status),
              paymentStatus: Value(payload['payment_status']?.toString() ?? existingOrder.paymentStatus),
              isPaid: Value(payload['is_paid'] == true || existingOrder.isPaid),
              serverVersion: Value(recordVersion),
              serverUpdatedAt: Value(serverUpdatedAt),
              syncStatus: const Value('synced'),
            ),
          );
          return PullApplyResult.applied;
        }
        return PullApplyResult.ignoredStale;

      case 'menu_category':
      case 'category':
        if (isDeleted) {
          await (db.delete(db.localMenuCategories)..where((t) => t.id.equals(entityId))).go();
        } else {
          await db.catalogDao.upsertMenuCategories([
            LocalMenuCategoriesCompanion(
              id: Value(entityId),
              name: Value(payload['name']?.toString() ?? ''),
              displayOrder: Value((payload['display_order'] as num?)?.toInt() ?? 0),
              isActive: Value(payload['is_active'] != false),
            ),
          ]);
        }
        return PullApplyResult.applied;

      case 'menu_item':
      case 'item':
        if (isDeleted) {
          await (db.delete(db.localMenuItems)..where((t) => t.id.equals(entityId))).go();
        } else {
          await db.catalogDao.upsertMenuItems([
            LocalMenuItemsCompanion(
              id: Value(entityId),
              categoryId: Value(payload['category_id']?.toString() ?? ''),
              name: Value(payload['name']?.toString() ?? ''),
              basePrice: Value((payload['base_price'] as num?)?.toDouble() ?? 0.0),
              isAvailable: Value(payload['is_available'] != false),
              isVeg: Value(payload['is_veg'] == true),
              isSpicy: Value(payload['is_spicy'] == true),
            ),
          ]);
        }
        return PullApplyResult.applied;

      case 'floor_zone':
        if (isDeleted) {
          await (db.delete(db.localFloorZones)..where((t) => t.id.equals(entityId))).go();
        } else {
          await db.catalogDao.upsertFloorZones([
            LocalFloorZonesCompanion(
              id: Value(entityId),
              name: Value(payload['name']?.toString() ?? ''),
              displayOrder: Value((payload['display_order'] as num?)?.toInt() ?? 0),
            ),
          ]);
        }
        return PullApplyResult.applied;

      case 'staff_user':
        if (isDeleted) {
          await (db.delete(db.localStaffUsers)..where((t) => t.id.equals(entityId))).go();
        } else {
          await db.catalogDao.upsertStaffUsers([
            LocalStaffUsersCompanion(
              id: Value(entityId),
              username: Value(payload['username']?.toString() ?? ''),
              role: Value(payload['role']?.toString() ?? 'cashier'),
              pinHash: Value(payload['pin_hash']?.toString()),
              isActive: Value(payload['is_active'] != false),
            ),
          ]);
        }
        return PullApplyResult.applied;

      case 'store_setting':
      case 'setting':
        await db.catalogDao.upsertStoreSettings(LocalStoreSettingsCompanion(
          id: Value(entityId.isNotEmpty ? entityId : 'store-1'),
          chainName: Value(payload['chain_name']?.toString() ?? 'Hungry Howies'),
          branchCode: Value(payload['branch_code']?.toString() ?? 'HH01'),
          branchName: Value(payload['branch_name']?.toString() ?? 'Main Branch'),
          storePhone: Value(payload['store_phone']?.toString() ?? ''),
          taxPercentage: Value((payload['tax_percentage'] as num?)?.toDouble() ?? 0.0),
        ));
        return PullApplyResult.applied;
    }
    return PullApplyResult.ignoredStale;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. HTTP HEADERS
  // ───────────────────────────────────────────────────────────────────────────

  Future<String?> trySilentReauth([String? explicitUsername]) async {
    // SYNC-008: Plaintext password guessing ('username123' or 'Noman123') removed.
    // Silent reauth without a valid refresh token endpoint is unsafe.
    // Returning null allows the sync worker to safely pause (AUTH_PAUSED) until
    // a user explicitly authenticates.
    return null;
  }

  Future<Map<String, String>> _buildHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    var token = await TokenStorage.getToken();
    if (token == null || token.isEmpty || token.startsWith('local_offline_token_')) {
      final newToken = await trySilentReauth();
      if (newToken != null && newToken.isNotEmpty) {
        token = newToken;
      }
    }

    if (token != null && token.isNotEmpty && !token.startsWith('local_offline_token_')) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }
}
