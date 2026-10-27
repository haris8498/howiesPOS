import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/outbox_drain_gate.dart';

/// Blocking Drain Modal displayed when OFFLINE_FIRST_ENABLED is false but
/// unsynced orders remain in local SQLite outbox (D-04 / SYNC-027).
class OutboxDrainModal extends ConsumerStatefulWidget {
  const OutboxDrainModal({super.key});

  /// Displays the drain modal dialog modally (blocking, non-barrier dismissible).
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const OutboxDrainModal(),
    );
  }

  @override
  ConsumerState<OutboxDrainModal> createState() => _OutboxDrainModalState();
}

class _OutboxDrainModalState extends ConsumerState<OutboxDrainModal> {
  String? _exportSuccessMessage;
  String? _errorMessage;

  Future<void> _handleSyncNow() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await ref.read(outboxDrainGateProvider.notifier).syncNow();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sync encountered an error: $e';
        });
      }
    }
  }

  Future<void> _handleExportBackup() async {
    setState(() {
      _exportSuccessMessage = null;
      _errorMessage = null;
    });

    try {
      final path =
          await ref.read(outboxDrainGateProvider.notifier).exportBackup();
      if (mounted) {
        setState(() {
          _exportSuccessMessage = 'Backup written to:\n$path';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Export failed: $e';
        });
      }
    }
  }

  void _handleWorkOffline() {
    ref.read(outboxDrainGateProvider.notifier).dismissModalForOfflineSession();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleContinueOnline() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(outboxDrainGateProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(gate),
                const SizedBox(height: 16),

                // Network Status Banner
                _buildNetworkStatusBanner(gate),
                const SizedBox(height: 16),

                // Progress Bar (when draining or pending)
                _buildProgressSection(gate),
                const SizedBox(height: 16),

                // Error messages
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Export Success Notification
                if (_exportSuccessMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _exportSuccessMessage!,
                            style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Permanently Failed Orders Section (Task 5)
                if (gate.permanentlyFailedCount > 0) ...[
                  _buildPermanentlyFailedSection(gate.permanentlyFailedEntries),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 8),

                // Action Buttons
                _buildActionButtons(gate),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(OutboxDrainGateState gate) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: gate.nonTerminalCount > 0
                ? AppColors.warning.withValues(alpha: 0.15)
                : AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            gate.nonTerminalCount > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: gate.nonTerminalCount > 0
                ? const Color(0xFFD97706)
                : AppColors.success,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gate.nonTerminalCount > 0
                    ? 'Unsynced Orders Gate'
                    : 'Outbox Drained Successfully',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                gate.nonTerminalCount > 0
                    ? 'Offline-first is OFF, but this terminal contains unsynced orders.'
                    : 'All pending orders are synced. Safe to operate in online-only mode.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkStatusBanner(OutboxDrainGateState gate) {
    final isOnline = gate.isOnline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withValues(alpha: 0.08)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.25)
              : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? AppColors.success : const Color(0xFFB45309),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline ? 'Network Online' : 'No Network Connection (Offline Mode)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? AppColors.success : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          if (!isOnline) ...[
            const SizedBox(height: 6),
            const Text(
              'No network connection. The app stays in safe local-first mode. Orders are preserved in SQLite WAL and will NOT be lost. Sync will auto-resume once connection returns.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF78350F),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(OutboxDrainGateState gate) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${gate.nonTerminalCount} order(s) awaiting sync',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (gate.isDraining)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: gate.isDraining
                  ? null
                  : (gate.nonTerminalCount == 0 ? 1.0 : 0.0),
              backgroundColor: AppColors.borderGray,
              color: gate.nonTerminalCount == 0
                  ? AppColors.success
                  : AppColors.primaryRed,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gate.isDraining
                ? 'Syncing pending orders with backoff and retries...'
                : (gate.nonTerminalCount == 0
                    ? 'Outbox queue empty. Routing switched to online-only.'
                    : 'Drain pending orders before switching to online-only REST mode.'),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPermanentlyFailedSection(List<SyncOutboxEntry> failedEntries) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFB91C1C), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permanently Failed Orders (${failedEntries.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'The following rows encountered 4xx business errors. They remain safely stored in SQLite WAL and are NEVER deleted or purged. Export a backup to share with support.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
          ),
          const Divider(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: failedEntries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final entry = failedEntries[index];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.entityType.toUpperCase()}: ${entry.entityId.substring(0, 8)}...',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.status,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.lastError ?? 'Unknown error',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.danger),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OutboxDrainGateState gate) {
    if (gate.nonTerminalCount == 0) {
      return ElevatedButton.icon(
        key: const Key('drain_modal_continue_online_button'),
        onPressed: _handleContinueOnline,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Continue to Online Mode'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Export backup button (Task 3)
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('drain_modal_export_button'),
                onPressed: _handleExportBackup,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Backup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderGray),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Sync now button (Task 3)
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('drain_modal_sync_now_button'),
                onPressed:
                    (!gate.isOnline || gate.isDraining) ? null : _handleSyncNow,
                icon: gate.isDraining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(gate.isDraining ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        // Cashier can continue offline if network is unavailable (Task 4)
        if (!gate.isOnline) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('drain_modal_work_offline_button'),
            onPressed: _handleWorkOffline,
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('Work Offline (Continue Local Mode)'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ],
    );
  }
}
