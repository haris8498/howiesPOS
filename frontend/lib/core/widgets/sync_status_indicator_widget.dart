import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sync/sync_providers.dart';

/// Sync Status Indicator Widget per Architecture Spec §3.3.
///
/// Exposes real-time connectivity and outbox synchronization status:
/// - Green: All Synced (Cloud ACKed)
/// - Amber: Offline / N Pending push
/// - Blue: Syncing in progress
/// - Orange: Auth Paused (HTTP 401, token expired)
/// - Yellow: Circuit Breaker active (Cloud Maintenance)
/// - Red: Conflict detected
///
/// Mount Location Recommendation:
/// Mount in the POS application top navigation bar or status footer
/// (e.g., inside POS header adjacent to the cashier profile badge).
class SyncStatusIndicatorWidget extends ConsumerWidget {
  const SyncStatusIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(syncIndicatorProvider);

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (viewModel.state) {
      case SyncIndicatorState.allSynced:
        backgroundColor = const Color(0xFF1B5E20).withAlpha(40);
        foregroundColor = const Color(0xFF4CAF50);
        icon = Icons.cloud_done_rounded;
        break;
      case SyncIndicatorState.syncing:
        backgroundColor = const Color(0xFF0D47A1).withAlpha(40);
        foregroundColor = const Color(0xFF2196F3);
        icon = Icons.sync_rounded;
        break;
      case SyncIndicatorState.pendingOffline:
        backgroundColor = const Color(0xFFE65100).withAlpha(40);
        foregroundColor = const Color(0xFFFF9800);
        icon = Icons.cloud_off_rounded;
        break;
      case SyncIndicatorState.authPaused:
        backgroundColor = const Color(0xFFBF360C).withAlpha(40);
        foregroundColor = const Color(0xFFFF5722);
        icon = Icons.vpn_key_rounded;
        break;
      case SyncIndicatorState.circuitBreaker:
        backgroundColor = const Color(0xFFF57F17).withAlpha(40);
        foregroundColor = const Color(0xFFFFEB3B);
        icon = Icons.warning_amber_rounded;
        break;
      case SyncIndicatorState.conflict:
        backgroundColor = const Color(0xFFB71C1C).withAlpha(40);
        foregroundColor = const Color(0xFFF44336);
        icon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foregroundColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewModel.state == SyncIndicatorState.syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          else
            Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            viewModel.label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
