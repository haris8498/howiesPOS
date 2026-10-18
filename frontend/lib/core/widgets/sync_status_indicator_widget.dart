import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/feature_flags.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';
import '../sync/sync_health_provider.dart';

/// Sync Status Indicator Light Widget per Architecture Spec §3.3 and Wave 3 directive.
///
/// Semantics (Strictly Two Colors):
/// - Green: Healthy (backend reachable, worker running, outbox draining or empty).
///   Gently pulses while actively pushing/draining.
/// - Red: Not syncing (backend offline, worker stopped, failed items, or stuck > 2 min).
///
/// Features:
/// - 12px indicator dot with soft ambient glow.
/// - Optional tiny pending count badge when pendingCount > 0.
/// - Tap to open Data Sync screen based on user role.
/// - Tooltip and Semantics label for high accessibility.
/// - When `FeatureFlags.offlineFirstEnabled == false`, renders `SizedBox.shrink()` (never misleading green).
class SyncStatusIndicatorWidget extends ConsumerStatefulWidget {
  const SyncStatusIndicatorWidget({super.key});

  @override
  ConsumerState<SyncStatusIndicatorWidget> createState() => _SyncStatusIndicatorWidgetState();
}

class _SyncStatusIndicatorWidgetState extends ConsumerState<SyncStatusIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialPulsing = ref.read(rawSyncHealthProvider).isPulsing;
        _updatePulseAnimation(initialPulsing);
      }
    });
  }

  void _updatePulseAnimation(bool isPulsing) {
    if (!mounted) return;
    if (isPulsing) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _navigateToDataSync(BuildContext context) {
    final authState = ref.read(authProvider);
    final targetRoute = switch (authState.currentUser.role) {
      UserRole.owner => '/owner/data-sync',
      UserRole.manager => '/manager/data-sync',
      UserRole.cashier => '/sales/data-sync',
    };
    try {
      context.push(targetRoute);
    } catch (_) {
      try {
        context.go(targetRoute);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FeatureFlags.offlineFirstEnabled) {
      return const SizedBox.shrink();
    }

    ref.listen<AsyncValue<SyncHealthState>>(syncHealthProvider, (_, next) {
      final isPulsing = next.value?.isPulsing ?? false;
      _updatePulseAnimation(isPulsing);
    });

    final healthAsync = ref.watch(syncHealthProvider);
    final SyncHealthState health = healthAsync.value ?? ref.watch(rawSyncHealthProvider);

    final Color dotColor = health.isGreen ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final Color glowColor = health.isGreen
        ? const Color(0xFF22C55E).withValues(alpha: 0.45)
        : const Color(0xFFEF4444).withValues(alpha: 0.45);

    return Semantics(
      label: health.semanticsLabel,
      button: true,
      child: Tooltip(
        message: '${health.tooltipText}\nTap to view Data Sync Ledger',
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToDataSync(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glowMultiplier = health.isPulsing ? _glowAnimation.value : 0.6;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: glowMultiplier),
                              blurRadius: health.isPulsing ? 8 : 4,
                              spreadRadius: health.isPulsing ? 2 : 1,
                            ),
                          ],
                        ),
                      ),
                      if (health.pendingCount > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: dotColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: dotColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${health.pendingCount}',
                            style: TextStyle(
                              color: dotColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
