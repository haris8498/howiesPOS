import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_colors.dart';
import '../database/app_database.dart';
import 'connectivity_notifier.dart';
import 'sync_background_worker.dart';
import 'sync_providers.dart';

/// ShiftCloseSyncGuard (MNY-06).
///
/// Prevents late-arriving orders by ensuring the terminal's outbox order
/// mutations are drained before shift close. If offline, presents a clear
/// warning and allows shift close after confirmation without blocking.
class ShiftCloseSyncGuard {
  final AppDatabase db;
  final SyncBackgroundWorker? syncWorker;
  final ConnectivityNotifier connectivityNotifier;
  final Duration drainTimeout;
  final Duration pollInterval;

  const ShiftCloseSyncGuard({
    required this.db,
    this.syncWorker,
    required this.connectivityNotifier,
    this.drainTimeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 200),
  });

  /// Counts pending and retryable order mutations in outbox (excluding quarantined, fatal, and conflict).
  Future<int> getPendingOrderCount() => db.outboxDao.getPendingOrderCount();

  /// Guards shift close:
  /// - If 0 pending order mutations: returns true immediately.
  /// - If online: displays drain dialog, triggers push, and waits for outbox to drain.
  ///   If drained within timeout: returns true.
  ///   If timed out: shows remaining count and lets user retry or close anyway.
  /// - If offline: displays warning ("N orders have not synced yet and will be recorded as late-synced"),
  ///   and allows closing after confirmation.
  Future<bool> guardShiftClose(BuildContext context, {Duration? timeout}) async {
    final pendingCount = await getPendingOrderCount();
    if (pendingCount == 0) {
      return true;
    }

    final isOnline = connectivityNotifier.isOnline;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ShiftCloseSyncDialog(
        db: db,
        syncWorker: syncWorker,
        isOnline: isOnline,
        initialPendingCount: pendingCount,
        timeout: timeout ?? drainTimeout,
        pollInterval: pollInterval,
      ),
    );

    return result ?? false;
  }
}

/// Provider for [ShiftCloseSyncGuard].
final shiftCloseSyncGuardProvider = Provider<ShiftCloseSyncGuard>((ref) {
  return ShiftCloseSyncGuard(
    db: ref.watch(appDatabaseProvider),
    syncWorker: ref.watch(syncBackgroundWorkerProvider),
    connectivityNotifier: ref.watch(connectivityNotifierProvider.notifier),
  );
});

/// Dialog displayed during shift close when unsynced order mutations remain in outbox.
/// Reuses the D-04 drain-gate visual style.
class ShiftCloseSyncDialog extends StatefulWidget {
  final AppDatabase db;
  final SyncBackgroundWorker? syncWorker;
  final bool isOnline;
  final int initialPendingCount;
  final Duration timeout;
  final Duration pollInterval;

  const ShiftCloseSyncDialog({
    super.key,
    required this.db,
    this.syncWorker,
    required this.isOnline,
    required this.initialPendingCount,
    this.timeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 200),
  });

  @override
  State<ShiftCloseSyncDialog> createState() => _ShiftCloseSyncDialogState();
}

class _ShiftCloseSyncDialogState extends State<ShiftCloseSyncDialog> {
  late int _remainingCount;
  late bool _isOnline;
  bool _isDraining = false;
  bool _isTimedOut = false;
  Timer? _pollTimer;
  DateTime? _drainStartTime;

  @override
  void initState() {
    super.initState();
    _remainingCount = widget.initialPendingCount;
    _isOnline = widget.isOnline;

    if (_isOnline) {
      _startDrain();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startDrain() {
    _pollTimer?.cancel();
    setState(() {
      _isDraining = true;
      _isTimedOut = false;
    });

    _drainStartTime = DateTime.now();

    // Trigger push immediately
    try {
      widget.syncWorker?.triggerSyncCycle(force: true);
    } catch (_) {}

    _pollTimer = Timer.periodic(widget.pollInterval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final count = await widget.db.outboxDao.getPendingOrderCount();
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingCount = count;
      });

      if (count == 0) {
        timer.cancel();
        // Fully drained: close dialog and proceed with shift close
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      // Check timeout
      if (_drainStartTime != null &&
          DateTime.now().difference(_drainStartTime!) >= widget.timeout) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isDraining = false;
            _isTimedOut = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      key: const Key('shift_close_sync_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 16),
              if (!_isOnline)
                _buildOfflineContent(isDark)
              else if (_isTimedOut)
                _buildTimeoutContent(isDark)
              else
                _buildDrainingContent(isDark),
              const SizedBox(height: 20),
              _buildActionButtons(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    IconData icon;
    Color iconColor;
    Color iconBgColor;
    String title;

    if (!_isOnline) {
      icon = Icons.wifi_off_rounded;
      iconColor = const Color(0xFFD97706);
      iconBgColor = const Color(0xFFFEF3C7);
      title = 'Offline Shift Close Warning';
    } else if (_isTimedOut) {
      icon = Icons.warning_amber_rounded;
      iconColor = const Color(0xFFDC2626);
      iconBgColor = const Color(0xFFFEE2E2);
      title = 'Sync Incomplete / Timeout';
    } else {
      icon = Icons.cloud_sync_rounded;
      iconColor = const Color(0xFF16A34A);
      iconBgColor = const Color(0xFFDCFCE7);
      title = 'Syncing Pending Orders';
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Shift Close Synchronization Guard',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF33200A) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_remainingCount orders have not synced yet and will be recorded as late-synced.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This terminal is offline. You can proceed with closing the shift; unsynced orders remain safe in local storage and will upload automatically once reconnected.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF78350F),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrainingContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.offWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$_remainingCount order(s) awaiting sync',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              key: Key('shift_close_sync_drain_progress'),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Draining outbox before shift close to prevent late-arriving orders...',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_off_outlined, color: Color(0xFFB91C1C), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_remainingCount order(s) could not be synced before timeout.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The network connection may be slow or unresponsive. You can retry the push, or proceed to close the shift anyway (unpushed orders will sync later and be recorded as late-synced).',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7F1D1D),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    if (_isDraining) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            key: const Key('shift_close_sync_cancel_button'),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Cancel Close'),
          ),
        ],
      );
    }

    if (!_isOnline) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            key: const Key('shift_close_sync_cancel_button'),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(false);
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            key: const Key('shift_close_sync_close_anyway_button'),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Confirm & Close Shift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      );
    }

    // Timed out state
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          key: const Key('shift_close_sync_cancel_button'),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(false);
            }
          },
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          key: const Key('shift_close_sync_retry_button'),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry Sync'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderGray),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          onPressed: _startDrain,
        ),
        ElevatedButton(
          key: const Key('shift_close_sync_close_anyway_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Close Shift Anyway'),
        ),
      ],
    );
  }
}
