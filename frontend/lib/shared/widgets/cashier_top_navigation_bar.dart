import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../core/widgets/sync_status_indicator_widget.dart';
import '../../data/auth_repository.dart';
import '../../data/network_speed_provider.dart';
import '../../data/online_orders_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/user_role.dart';
import '../widgets/sync_button.dart';

class CashierTopNavigationBar extends ConsumerWidget {
  final String currentRoute;

  const CashierTopNavigationBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOnlineOrders = ref.watch(onlineOrdersProvider).pendingCount;
    final roleRights = ref.watch(roleRightsProvider);
    final authState = ref.watch(authProvider);
    final userRole = authState.isAuthenticated ? authState.currentUser.role : UserRole.cashier;

    bool can(String key, {String? moduleName, bool defaultIfMissing = false}) {
      return roleRights.isModuleGranted(
        userRole,
        moduleName ?? key,
        defaultIfMissing: defaultIfMissing,
      );
    }

    // Build the top bar navigation tabs dynamically based on granted staff permissions:
    final List<_TopNavItem> navItems = [
      if (can('tables', moduleName: 'Tables', defaultIfMissing: true))
        _TopNavItem(
          title: 'Tables',
          route: '/sales/tables',
          icon: Icons.table_restaurant_rounded,
          alternativeRoutes: ['/sales/pos', '/sales/orders'],
        )
      else if (can('pos', moduleName: 'POS Billing', defaultIfMissing: true))
        _TopNavItem(
          title: 'POS Sales',
          route: '/sales/pos',
          icon: Icons.point_of_sale_rounded,
        ),
      if (can('takeaway', moduleName: 'Takeaway Counter', defaultIfMissing: true))
        _TopNavItem(
          title: 'Takeaway',
          route: '/sales/takeaway',
          icon: Icons.shopping_bag_rounded,
        ),
      if (can('delivery', moduleName: 'Delivery Tracking', defaultIfMissing: true))
        _TopNavItem(
          title: 'Delivery Tracking',
          route: '/sales/delivery',
          icon: Icons.two_wheeler_rounded,
        ),
      if (can('online_orders', moduleName: 'Online Orders', defaultIfMissing: true))
        _TopNavItem(
          title: 'Online Orders',
          route: '/sales/online-orders',
          icon: Icons.cloud_download_rounded,
          badgeCount: pendingOnlineOrders,
          isComingSoon: true,
        ),
      if (can('daily_calculation', moduleName: 'Daily Calculation', defaultIfMissing: true))
        _TopNavItem(
          title: 'Daily Calculation',
          route: '/sales/daily-calculation',
          icon: Icons.calculate_rounded,
        ),
      if (can('menu', moduleName: 'Menu Catalog', defaultIfMissing: true))
        _TopNavItem(
          title: 'Menu Catalog',
          route: '/sales/menu',
          icon: Icons.restaurant_menu_rounded,
        ),
      if (can('stock', moduleName: 'Stock Catalog', defaultIfMissing: false))
        _TopNavItem(
          title: 'Stock Catalog',
          route: '/sales/stock',
          icon: Icons.inventory_2_rounded,
        ),
      if (can('stock_in_out', moduleName: 'Stock In / Out', defaultIfMissing: false))
        _TopNavItem(
          title: 'Stock In / Out',
          route: '/sales/stock-in-out',
          icon: Icons.compare_arrows_rounded,
        ),
      if (can('users', moduleName: 'Users', defaultIfMissing: false))
        _TopNavItem(
          title: 'Users',
          route: '/sales/users',
          icon: Icons.people_alt_rounded,
        ),
      if (can('expenses', moduleName: 'Expenses', defaultIfMissing: false))
        _TopNavItem(
          title: 'Expenses',
          route: '/sales/expenses',
          icon: Icons.account_balance_wallet_rounded,
        ),
      if (can('reports', moduleName: 'Reports', defaultIfMissing: true))
        _TopNavItem(
          title: 'Reports',
          route: '/sales/reports',
          icon: Icons.analytics_rounded,
        ),
      if (can('data_sync', moduleName: 'Data Sync', defaultIfMissing: true))
        _TopNavItem(
          title: 'Data Synced',
          route: '/sales/data-sync',
          icon: Icons.cloud_sync_rounded,
        ),
    ];

    // Fallback if no modules are enabled so the bar remains functional
    if (navItems.isEmpty) {
      navItems.add(
        _TopNavItem(
          title: 'Tables',
          route: '/sales/tables',
          icon: Icons.table_restaurant_rounded,
          alternativeRoutes: ['/sales/pos', '/sales/orders'],
        ),
      );
    }

    return Container(
      height: 56,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryRed,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Navigation items tabs (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: navItems.map((item) {
                  final bool isSelected = currentRoute == item.route ||
                      (item.alternativeRoutes?.contains(currentRoute) ?? false);

                  if (isSelected) {
                    // Active Pill Style (White background with Red Text)
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x25000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: AppColors.primaryRed, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (item.badgeCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandYellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  color: AppColors.deepRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  // Inactive Item Style
                  return InkWell(
                    onTap: item.isComingSoon
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🚀 Online Orders module is Coming Soon!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () => context.go(item.route),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.title,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          if (item.isComingSoon) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandYellow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Coming Soon',
                                style: TextStyle(
                                  color: AppColors.deepRed,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ] else if (item.badgeCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandYellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${item.badgeCount}',
                                style: const TextStyle(
                                  color: AppColors.deepRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. Global Sync / Refresh Data Button with live Cloud status
          SyncButton(
            variant: SyncButtonVariant.cashierTopBar,
            currentRoute: currentRoute,
          ),

          const SizedBox(width: 8),

          // Sync status light (green/red offline-first health indicator)
          const SyncStatusIndicatorWidget(),

          const SizedBox(width: 8),

          // 3. Rightmost Network Status 3-Line Capsule
          _buildNetworkStatusBadge(context, ref),
        ],
      ),
    );
  }

  // --- Rightmost Network Status 3-Line Capsule ---
  Widget _buildNetworkStatusBadge(BuildContext context, WidgetRef ref) {
    final netState = ref.watch(networkSpeedProvider);
    final isGreen = netState.level == NetworkSpeedLevel.fast;
    final isOrange = netState.level == NetworkSpeedLevel.medium;
    final isRed = netState.level == NetworkSpeedLevel.slow || netState.level == NetworkSpeedLevel.offline;

    final String latencyLabel = netState.level == NetworkSpeedLevel.offline
        ? 'Offline'
        : '${netState.latencyMs}ms';

    return Tooltip(
      message: 'Network Status: $latencyLabel\n${netState.statusMessage}\nTap for diagnostics',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNetworkDiagnosticsDialog(context, ref),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3 Network Status Lines / Signal Bars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildSignalBar(height: 7, color: const Color(0xFFEF4444), isActive: isRed || isOrange || isGreen),
                    const SizedBox(width: 3),
                    _buildSignalBar(height: 11, color: const Color(0xFFFBBF24), isActive: isOrange || isGreen),
                    const SizedBox(width: 3),
                    _buildSignalBar(height: 16, color: const Color(0xFF10B981), isActive: isGreen),
                  ],
                ),
                const SizedBox(width: 7),
                Text(
                  latencyLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalBar({
    required double height,
    required Color color,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }

  // --- Network Diagnostics Dialog for Cashier ---
  void _showNetworkDiagnosticsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final netState = ref.watch(networkSpeedProvider);
        final isGreen = netState.level == NetworkSpeedLevel.fast;
        final isOrange = netState.level == NetworkSpeedLevel.medium;

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderGray),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isGreen ? const Color(0xFF10B981) : (isOrange ? const Color(0xFFF59E0B) : AppColors.danger)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isGreen ? Icons.wifi_rounded : (isOrange ? Icons.wifi_2_bar_rounded : Icons.wifi_off_rounded),
                            color: isGreen ? const Color(0xFF10B981) : (isOrange ? const Color(0xFFF59E0B) : AppColors.danger),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NETWORK STATUS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Live POS Connection Health',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.borderGray),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _diagRow('Status', isGreen ? 'Optimal (Fast)' : (isOrange ? 'Moderate' : 'Offline / Poor')),
                      const SizedBox(height: 6),
                      _diagRow('Ping Latency', '${netState.latencyMs} ms'),
                      const SizedBox(height: 6),
                      _diagRow('Cloud Gateway', 'Connected (1.1.1.1:53)'),
                      const SizedBox(height: 6),
                      _diagRow('POS Terminal', 'Branch #402 (Primary)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(networkSpeedProvider.notifier).checkSpeed();
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Testing network connection speed...'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('RETEST CONNECTION SPEED'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _diagRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _TopNavItem {
  final String title;
  final String route;
  final IconData icon;
  final int badgeCount;
  final bool isComingSoon;
  final List<String>? alternativeRoutes;

  _TopNavItem({
    required this.title,
    required this.route,
    required this.icon,
    this.badgeCount = 0,
    this.isComingSoon = false,
    this.alternativeRoutes,
  });
}
