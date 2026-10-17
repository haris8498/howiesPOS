import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/sync_repository.dart';
import '../../services/sync/global_sync_controller.dart';

enum SyncButtonVariant {
  cashierTopBar,
  sidebarHeader,
  sidebarFooter,
}

class SyncButton extends ConsumerStatefulWidget {
  final SyncButtonVariant variant;
  final String? currentRoute;
  final bool isCollapsed;
  final bool isDark;

  const SyncButton({
    super.key,
    required this.variant,
    this.currentRoute,
    this.isCollapsed = false,
    this.isDark = false,
  });

  @override
  ConsumerState<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleSync() {
    GlobalSyncController.syncAndRefreshAll(
      ref: ref,
      context: context,
      currentRoute: widget.currentRoute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(dataSyncProvider);
    final isSyncing = syncState.isSyncing;
    final pendingCount = syncState.summary.pendingCount;

    if (isSyncing) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else {
      if (_animController.isAnimating) {
        _animController.stop();
        _animController.reset();
      }
    }

    switch (widget.variant) {
      case SyncButtonVariant.cashierTopBar:
        return _buildCashierTopBarButton(isSyncing, pendingCount);
      case SyncButtonVariant.sidebarHeader:
        return _buildSidebarHeaderButton(isSyncing, pendingCount);
      case SyncButtonVariant.sidebarFooter:
        return _buildSidebarFooterButton(isSyncing, pendingCount);
    }
  }

  // ---------------------------------------------------------------------------
  // Variant 1: Cashier Top Navigation Bar Pill
  // ---------------------------------------------------------------------------
  Widget _buildCashierTopBarButton(bool isSyncing, int pendingCount) {
    final hasPending = pendingCount > 0;
    final tooltipMsg = isSyncing
        ? 'Syncing local orders with Cloud PostgreSQL...'
        : (hasPending
            ? '$pendingCount pending order(s) waiting for cloud upload\nTap to sync now & refresh screen'
            : 'All orders in sync with Cloud\nTap to refresh screen data');

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSyncing ? null : _handleSync,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: hasPending
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasPending
                    ? AppColors.brandYellow
                    : Colors.white.withValues(alpha: 0.4),
                width: hasPending ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _animController,
                  child: Icon(
                    isSyncing
                        ? Icons.sync_rounded
                        : (hasPending
                            ? Icons.cloud_upload_rounded
                            : Icons.cloud_sync_rounded),
                    color: hasPending ? AppColors.brandYellow : Colors.white,
                    size: 18,
                  ),
                ),
                if (hasPending)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.brandYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Variant 2: Sidebar Brand Header Icon Button
  // ---------------------------------------------------------------------------
  Widget _buildSidebarHeaderButton(bool isSyncing, int pendingCount) {
    final hasPending = pendingCount > 0;
    final tooltipMsg = isSyncing
        ? 'Synchronizing data with Cloud...'
        : (hasPending
            ? '$pendingCount pending order(s) awaiting cloud sync\nTap to sync & refresh'
            : 'Cloud Synchronized\nTap to refresh screen data');

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSyncing ? null : _handleSync,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: hasPending
                  ? Colors.amber.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: hasPending
                  ? Border.all(color: AppColors.brandYellow, width: 1.2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RotationTransition(
                  turns: _animController,
                  child: Icon(
                    isSyncing ? Icons.sync_rounded : Icons.cloud_sync_rounded,
                    color: hasPending ? AppColors.brandYellow : Colors.white,
                    size: 18,
                  ),
                ),
                if (hasPending)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brandYellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Variant 3: Sidebar Footer Full-Width / Pill Action
  // ---------------------------------------------------------------------------
  Widget _buildSidebarFooterButton(bool isSyncing, int pendingCount) {
    final isDark = widget.isDark;
    final isCollapsed = widget.isCollapsed;
    final hasPending = pendingCount > 0;

    final tooltipMsg = isSyncing
        ? 'Syncing data with cloud...'
        : (hasPending
            ? '$pendingCount offline orders pending upload\nTap to synchronize'
            : 'Cloud sync active (All orders synced)\nTap to refresh screen');

    if (isCollapsed) {
      return Tooltip(
        message: tooltipMsg,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSyncing ? null : _handleSync,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasPending
                    ? AppColors.primaryRed.withValues(alpha: isDark ? 0.25 : 0.15)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPending
                      ? AppColors.primaryRed
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: hasPending ? 1.4 : 1,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  RotationTransition(
                    turns: _animController,
                    child: Icon(
                      isSyncing ? Icons.sync_rounded : Icons.cloud_sync_rounded,
                      color: hasPending ? AppColors.primaryRed : AppColors.primaryRed,
                      size: 18,
                    ),
                  ),
                  if (hasPending)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltipMsg,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSyncing ? null : _handleSync,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: hasPending
                  ? AppColors.primaryRed.withValues(alpha: isDark ? 0.2 : 0.08)
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPending
                    ? AppColors.primaryRed.withValues(alpha: 0.8)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: hasPending ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _animController,
                  child: Icon(
                    isSyncing
                        ? Icons.sync_rounded
                        : (hasPending
                            ? Icons.cloud_upload_rounded
                            : Icons.cloud_sync_rounded),
                    size: 15,
                    color: hasPending
                        ? AppColors.primaryRed
                        : (isDark ? const Color(0xFF38BDF8) : AppColors.primaryRed),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isSyncing
                      ? 'SYNCING...'
                      : (hasPending
                          ? 'SYNC DATA ($pendingCount PENDING)'
                          : 'SYNC / REFRESH DATA'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: hasPending
                        ? AppColors.primaryRed
                        : (isDark ? Colors.white : AppColors.textPrimary),
                  ),
                ),
                if (hasPending) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
