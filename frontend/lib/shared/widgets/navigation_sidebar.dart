import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../data/auth_repository.dart';
import '../../data/online_orders_repository.dart';
import '../../domain/models/user_role.dart';

import '../../data/role_rights_repository.dart';
import '../../data/network_speed_provider.dart';
import 'sync_button.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class NavigationSidebar extends ConsumerWidget {
  final String currentRoute;

  const NavigationSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final role = authState.currentUser.role;
    final pendingOnlineOrders = ref.watch(onlineOrdersProvider).pendingCount;
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isOwnerPortal = role == UserRole.owner || currentRoute.startsWith('/owner');

    List<_NavItem> navItems = [];

    if (role == UserRole.owner) {
      navItems = [
        _NavItem('Tables', '/owner/tables', Icons.table_restaurant_rounded),
        _NavItem('Online Orders', '/owner/online-orders', Icons.cloud_download_rounded, badgeCount: pendingOnlineOrders, isComingSoon: true),
        _NavItem('Takeaway', '/owner/takeaway', Icons.shopping_bag_rounded),
        _NavItem('Menu Catalog', '/owner/menu', Icons.restaurant_menu_rounded),
        _NavItem('Delivery Tracking', '/owner/delivery', Icons.two_wheeler_rounded),
        _NavItem('Stock Catalog', '/owner/stock', Icons.inventory_2_rounded),
        _NavItem('Stock In / Out', '/owner/stock-in-out', Icons.compare_arrows_rounded),
        _NavItem('Users', '/owner/users', Icons.people_alt_rounded),
        _NavItem('Staff Users', '/owner/passwords', Icons.manage_accounts_rounded),
        _NavItem('Staff Permissions', '/owner/rights', Icons.admin_panel_settings_rounded),
        _NavItem('Expenses', '/owner/expenses', Icons.account_balance_wallet_rounded),
        _NavItem('Daily Calculation', '/owner/daily-calculation', Icons.calculate_rounded),
        _NavItem('Reports', '/owner/reports', Icons.analytics_rounded),
        _NavItem('Sync Center', '/owner/sync-center', Icons.cloud_sync_rounded),
        ];
    } else if (role == UserRole.manager) {
      final roleRights = ref.watch(roleRightsProvider);

      bool can(String key, {String? moduleName, bool defaultIfMissing = false}) {
        return roleRights.isModuleGranted(
          UserRole.manager,
          moduleName ?? key,
          defaultIfMissing: defaultIfMissing,
        );
      }

      navItems = [];
      if (can('tables', moduleName: 'Tables', defaultIfMissing: true)) navItems.add(_NavItem('Tables', '/manager/tables', Icons.table_restaurant_rounded));
      if (can('online_orders', moduleName: 'Online Orders')) navItems.add(_NavItem('Online Orders', '/manager/online-orders', Icons.cloud_download_rounded, badgeCount: pendingOnlineOrders, isComingSoon: true));
      if (can('takeaway', moduleName: 'Takeaway Counter', defaultIfMissing: true)) navItems.add(_NavItem('Takeaway', '/manager/takeaway', Icons.shopping_bag_rounded));
      if (can('menu', moduleName: 'Menu Catalog')) navItems.add(_NavItem('Menu Catalog', '/manager/menu', Icons.restaurant_menu_rounded));
      if (can('delivery', moduleName: 'Delivery Tracking')) navItems.add(_NavItem('Delivery Tracking', '/manager/delivery', Icons.two_wheeler_rounded));
      if (can('stock', moduleName: 'Stock Catalog')) navItems.add(_NavItem('Stock Catalog', '/manager/stock', Icons.inventory_2_rounded));
      if (can('stock_in_out', moduleName: 'Stock In / Out')) navItems.add(_NavItem('Stock In / Out', '/manager/stock-in-out', Icons.compare_arrows_rounded));
      if (can('users', moduleName: 'Users')) navItems.add(_NavItem('Users', '/manager/users', Icons.people_alt_rounded));
      if (can('passwords', moduleName: 'Staff Users')) navItems.add(_NavItem('Staff Users', '/manager/passwords', Icons.manage_accounts_rounded));
      if (can('rights', moduleName: 'Staff Permissions')) navItems.add(_NavItem('Staff Permissions', '/manager/rights', Icons.admin_panel_settings_rounded));
      if (can('expenses', moduleName: 'Expenses')) navItems.add(_NavItem('Expenses', '/manager/expenses', Icons.account_balance_wallet_rounded));
      if (can('daily_calculation', moduleName: 'Daily Calculation', defaultIfMissing: true)) navItems.add(_NavItem('Daily Calculation', '/manager/daily-calculation', Icons.calculate_rounded));
      if (can('reports', moduleName: 'Reports')) navItems.add(_NavItem('Reports', '/manager/reports', Icons.analytics_rounded));
      if (can('data_sync', moduleName: 'Sync Center', defaultIfMissing: true)) navItems.add(_NavItem('Sync Center', '/manager/sync-center', Icons.cloud_sync_rounded));

      // Fallback if no modules granted
      if (navItems.isEmpty) {
        navItems.add(_NavItem('Tables', '/manager/tables', Icons.table_restaurant_rounded));
      }
    } else {
      final roleRights = ref.watch(roleRightsProvider);

      bool can(String key, {String? moduleName, bool defaultIfMissing = false}) {
        return roleRights.isModuleGranted(
          UserRole.cashier,
          moduleName ?? key,
          defaultIfMissing: defaultIfMissing,
        );
      }

      navItems = [];
      if (can('tables', moduleName: 'Tables', defaultIfMissing: true)) navItems.add(_NavItem('Tables', '/sales/tables', Icons.table_restaurant_rounded));
      if (can('online_orders', moduleName: 'Online Orders')) navItems.add(_NavItem('Online Orders', '/sales/online-orders', Icons.cloud_download_rounded, badgeCount: pendingOnlineOrders, isComingSoon: true));
      if (can('takeaway', moduleName: 'Takeaway Counter', defaultIfMissing: true)) navItems.add(_NavItem('Takeaway', '/sales/takeaway', Icons.shopping_bag_rounded));
      if (can('menu', moduleName: 'Menu Catalog')) navItems.add(_NavItem('Menu Catalog', '/sales/menu', Icons.restaurant_menu_rounded));
      if (can('delivery', moduleName: 'Delivery Tracking')) navItems.add(_NavItem('Delivery Tracking', '/sales/delivery', Icons.two_wheeler_rounded));
      if (can('stock', moduleName: 'Stock Catalog')) navItems.add(_NavItem('Stock Catalog', '/sales/stock', Icons.inventory_2_rounded));
      if (can('stock_in_out', moduleName: 'Stock In / Out')) navItems.add(_NavItem('Stock In / Out', '/sales/stock-in-out', Icons.compare_arrows_rounded));
      if (can('users', moduleName: 'Users')) navItems.add(_NavItem('Users', '/sales/users', Icons.people_alt_rounded));
      if (can('expenses', moduleName: 'Expenses')) navItems.add(_NavItem('Expenses', '/sales/expenses', Icons.account_balance_wallet_rounded));
      if (can('daily_calculation', moduleName: 'Daily Calculation', defaultIfMissing: true)) navItems.add(_NavItem('Daily Calculation', '/sales/daily-calculation', Icons.calculate_rounded));
      if (can('reports', moduleName: 'Reports')) navItems.add(_NavItem('Reports', '/sales/reports', Icons.analytics_rounded));
      if (can('data_sync', moduleName: 'Sync Center', defaultIfMissing: true)) navItems.add(_NavItem('Sync Center', '/sales/sync-center', Icons.cloud_sync_rounded));
      
      // Fallback if no modules granted
      if (navItems.isEmpty) {
        navItems.add(_NavItem('Tables', '/sales/tables', Icons.table_restaurant_rounded));
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? 72 : 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: isCollapsed ? 72 : 250,
            child: Column(
              children: [
                // 1. Premium Hungry Howie's Brand Header (Collapsible / Expandable)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 8 : 14,
                    vertical: isCollapsed ? 14 : 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: isCollapsed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 36,
                                  width: 36,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    padding: const EdgeInsets.all(5),
                                    color: AppColors.brandYellow,
                                    child: const Icon(
                                      Icons.local_pizza_rounded,
                                      color: AppColors.deepRed,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (!isOwnerPortal) ...[
                              const SizedBox(height: 8),
                              SyncButton(
                                variant: SyncButtonVariant.sidebarHeader,
                                currentRoute: currentRoute,
                                isCollapsed: true,
                                isDark: isDark,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Tooltip(
                              message: 'Expand Sidebar',
                              child: InkWell(
                                onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = false,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.menu_open_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 38,
                                  width: 38,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    padding: const EdgeInsets.all(6),
                                    color: AppColors.brandYellow,
                                    child: const Icon(
                                      Icons.local_pizza_rounded,
                                      color: AppColors.deepRed,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HUNGRY HOWIE\'S',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'FLAVORED CRUST PIZZA',
                                    style: TextStyle(
                                      color: AppColors.brandYellow,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isOwnerPortal) ...[
                              SyncButton(
                                variant: SyncButtonVariant.sidebarHeader,
                                currentRoute: currentRoute,
                                isCollapsed: false,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Tooltip(
                              message: 'Collapse Sidebar',
                              child: InkWell(
                                onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = true,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.menu_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 10),

                // 2. Navigation Links List
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCollapsed ? 8 : 12,
                      vertical: 4,
                    ),
                    itemCount: navItems.length,
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = currentRoute == item.route;

                      if (isCollapsed) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Tooltip(
                            message: item.isComingSoon
                                ? '${item.title} (Coming Soon)'
                                : (item.badgeCount > 0 ? '${item.title} (${item.badgeCount})' : item.title),
                            preferBelow: false,
                            verticalOffset: 20,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
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
                                child: Container(
                                  height: 44,
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [AppColors.primaryRed, Color(0xFFDC2626)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryRed.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        item.icon,
                                        color: item.isComingSoon
                                            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                            : (isSelected
                                                ? Colors.white
                                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                        size: 21,
                                      ),
                                      if (item.badgeCount > 0 && !item.isComingSoon)
                                        Positioned(
                                          top: 6,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: AppColors.brandYellow,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 8,
                                              minHeight: 8,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: isSelected
                            ? BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primaryRed, Color(0xFFDC2626)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              )
                            : null,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    color: item.isComingSoon
                                        ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                        : (isSelected
                                            ? Colors.white
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        color: item.isComingSoon
                                            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                            : (isSelected
                                                ? Colors.white
                                                : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B))),
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.isComingSoon)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.8),
                                      ),
                                      child: const Text(
                                        'Coming Soon',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    )
                                  else if (item.badgeCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : AppColors.brandYellow,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item.badgeCount}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppColors.primaryRed : const Color(0xFF78350F),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. Ultra-Sleek Executive Footer (Network Meter & Logout)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 8 : 12,
                    vertical: isCollapsed ? 12 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: isCollapsed
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Vertical Network Lights Capsule
                            _buildVerticalNetworkSpeedIndicators(context, ref, isDark),
                            const SizedBox(height: 8),
                            // Collapsed Sync Action
                            if (!isOwnerPortal) ...[
                              SyncButton(
                                variant: SyncButtonVariant.sidebarFooter,
                                currentRoute: currentRoute,
                                isCollapsed: true,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Collapsed Logout Action
                            Tooltip(
                              message: 'Log Out',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _confirmLogout(context, ref, isDark),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.danger.withValues(alpha: isDark ? 0.35 : 0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.logout_rounded,
                                      color: AppColors.danger,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Full-width Sync Data Action Button
                            if (!isOwnerPortal) ...[
                              SyncButton(
                                variant: SyncButtonVariant.sidebarFooter,
                                currentRoute: currentRoute,
                                isCollapsed: false,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left Side: Professional Network Quality & Latency Capsule
                                Flexible(
                                  child: _buildNetworkSpeedIndicators(context, ref, isDark),
                                ),
                                const SizedBox(width: 6),

                                // Right Side: Professional Logout Action Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _confirmLogout(context, ref, isDark),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.danger.withValues(alpha: isDark ? 0.35 : 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.logout_rounded, color: AppColors.danger, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Logout',
                                            style: TextStyle(
                                              color: AppColors.danger,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Vertical Network Quality & Latency Capsule Widget (When Collapsed) ---
  Widget _buildVerticalNetworkSpeedIndicators(BuildContext context, WidgetRef ref, bool isDark) {
    final netState = ref.watch(networkSpeedProvider);
    final isGreen = netState.level == NetworkSpeedLevel.fast;
    final isOrange = netState.level == NetworkSpeedLevel.medium;
    final isRed = netState.level == NetworkSpeedLevel.slow || netState.level == NetworkSpeedLevel.offline;

    final String latencyLabel = netState.level == NetworkSpeedLevel.offline
        ? 'Offline'
        : '${netState.latencyMs}ms';

    return Tooltip(
      message: 'Network: $latencyLabel\n${netState.statusMessage}\nTap for diagnostics',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNetworkDiagnosticsDialog(context, ref, isDark),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTrafficDot(
                  color: const Color(0xFF10B981),
                  isActive: isGreen,
                ),
                const SizedBox(height: 5),
                _buildTrafficDot(
                  color: const Color(0xFFF59E0B),
                  isActive: isOrange,
                ),
                const SizedBox(height: 5),
                _buildTrafficDot(
                  color: const Color(0xFFEF4444),
                  isActive: isRed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Horizontal Network Quality & Latency Pill Widget ---
  Widget _buildNetworkSpeedIndicators(BuildContext context, WidgetRef ref, bool isDark) {
    final netState = ref.watch(networkSpeedProvider);
    final isGreen = netState.level == NetworkSpeedLevel.fast;
    final isOrange = netState.level == NetworkSpeedLevel.medium;
    final isRed = netState.level == NetworkSpeedLevel.slow || netState.level == NetworkSpeedLevel.offline;

    final String latencyLabel = netState.level == NetworkSpeedLevel.offline
        ? 'Offline'
        : '${netState.latencyMs}ms';

    final Color activeColor = isGreen
        ? const Color(0xFF10B981)
        : (isOrange ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Tooltip(
      message: '${netState.statusMessage}\nTap for network diagnostics',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNetworkDiagnosticsDialog(context, ref, isDark),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 3 LED Status Micro-Dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTrafficDot(
                      color: const Color(0xFFEF4444),
                      isActive: isRed,
                    ),
                    const SizedBox(width: 3.5),
                    _buildTrafficDot(
                      color: const Color(0xFFF59E0B),
                      isActive: isOrange,
                    ),
                    const SizedBox(width: 3.5),
                    _buildTrafficDot(
                      color: const Color(0xFF10B981),
                      isActive: isGreen,
                    ),
                  ],
                ),
                const SizedBox(width: 5),
                // Latency Badge
                Flexible(
                  child: Text(
                    latencyLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                      letterSpacing: 0.2,
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

  Widget _buildTrafficDot({
    required Color color,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 7.5 : 5.5,
      height: isActive ? 7.5 : 5.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? color : color.withValues(alpha: 0.22),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }

  // --- Network Diagnostics Dialog ---
  void _showNetworkDiagnosticsDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final netState = ref.watch(networkSpeedProvider);
        final isGreen = netState.level == NetworkSpeedLevel.fast;
        final isOrange = netState.level == NetworkSpeedLevel.medium;

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NETWORK STATUS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Live POS Connection Health',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
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
                Divider(height: 20, color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _diagRow('Status', isGreen ? 'Optimal (Fast)' : (isOrange ? 'Moderate' : 'Offline / Poor'), isDark),
                      const SizedBox(height: 6),
                      _diagRow('Ping Latency', '${netState.latencyMs} ms', isDark),
                      const SizedBox(height: 6),
                      _diagRow('Cloud Gateway', 'Connected (1.1.1.1:53)', isDark),
                      const SizedBox(height: 6),
                      _diagRow('POS Terminal', 'Branch #402 (Primary)', isDark),
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

  Widget _diagRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Safe Logout Confirmation Dialog ---
  void _confirmLogout(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'LOG OUT OF POS',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to end your active session and sign out of Hungry Howie\'s POS?',
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final String title;
  final String route;
  final IconData icon;
  final int badgeCount;
  final bool isComingSoon;

  _NavItem(
    this.title,
    this.route,
    this.icon, {
    this.badgeCount = 0,
    this.isComingSoon = false,
  });
}
