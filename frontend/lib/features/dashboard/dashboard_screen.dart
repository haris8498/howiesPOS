import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/delivery_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/kitchen_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/staff_repository.dart';
import '../../data/table_repository.dart';
import '../../domain/models/user_role.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final role = authState.currentUser.role;

    switch (role) {
      case UserRole.owner:
        return _buildOwnerDashboard(context, ref);
      case UserRole.manager:
        return _buildManagerDashboard(context, ref);
      case UserRole.cashier:
        return _buildCashierDashboard(context, ref);
    }
  }

  Widget _buildOwnerDashboard(BuildContext context, WidgetRef ref) {
    final tableState = ref.watch(tableProvider);
    final kitchenState = ref.watch(kitchenProvider);
    final delState = ref.watch(deliveryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('CHAIN OWNER OVERVIEW & EXECUTIVE CONTROL', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(label: 'Full System Access Granted', color: AppColors.gold, icon: Icons.workspace_premium_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Order Type Specific KPI Cards
          Row(
            children: [
              const Expanded(child: StatCard(title: 'Total Dine In Orders', value: '412', icon: Icons.restaurant_rounded, iconColor: AppColors.success, subtitle: 'PKR 18,420 Dine In Rev')),
              const SizedBox(width: 10),
              const Expanded(child: StatCard(title: 'Total Take Away Orders', value: '640', icon: Icons.shopping_bag_rounded, iconColor: AppColors.primaryRed, subtitle: 'PKR 16,890 Take Away Rev')),
              const SizedBox(width: 10),
              const Expanded(child: StatCard(title: 'Total Delivery Orders', value: '368', icon: Icons.two_wheeler_rounded, iconColor: AppColors.gold, subtitle: 'PKR 13,610 Delivery Rev')),
              const SizedBox(width: 10),
              Expanded(child: StatCard(title: 'Active Floor Tables', value: '${tableState.occupiedCount}', icon: Icons.table_restaurant_rounded, iconColor: AppColors.primaryRed, subtitle: 'Out of ${tableState.tables.length}')),
              const SizedBox(width: 10),
              Expanded(child: StatCard(title: 'Orders In Kitchen', value: '${kitchenState.kitchenOrders.length}', icon: Icons.soup_kitchen_rounded, iconColor: AppColors.warning, subtitle: 'KDS Prep Queue')),
              const SizedBox(width: 10),
              Expanded(child: StatCard(title: 'Orders In Delivery', value: '${delState.deliveries.length}', icon: Icons.navigation_rounded, iconColor: AppColors.success, subtitle: 'Out for delivery')),
            ],
          ),

          const SizedBox(height: 20),

          // Revenue Analytics Breakdown by Order Type
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REVENUE BREAKDOWN BY ORDER TYPE', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(value: 45, title: '45% Dine In', color: AppColors.success, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              PieChartSectionData(value: 35, title: '35% Take Away', color: AppColors.primaryRed, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              PieChartSectionData(value: 20, title: '20% Delivery', color: AppColors.gold, radius: 50, titleStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('PEAK ORDER HOURS & POPULARITY', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 14),
                      ListTile(
                        leading: Icon(Icons.star_rounded, color: AppColors.gold),
                        title: Text('Most Popular Order Type: Take Away', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('45% of daily volume during lunch peak'),
                      ),
                      ListTile(
                        leading: Icon(Icons.access_time_filled_rounded, color: AppColors.primaryRed),
                        title: Text('Peak Hours: 6:00 PM - 9:00 PM', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('Highest Dine In & Delivery ticket volume'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagerDashboard(BuildContext context, WidgetRef ref) {
    final posState = ref.watch(posProvider);
    final tableState = ref.watch(tableProvider);
    final kitchenState = ref.watch(kitchenProvider);
    final staffState = ref.watch(staffProvider);
    final invState = ref.watch(inventoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('STORE MANAGER DASHBOARD', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(label: 'Shift Operations Control', color: AppColors.primaryRed),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: StatCard(title: 'Today\'s Orders', value: '${posState.completedOrders.length + 14}', icon: Icons.shopping_bag_rounded, iconColor: AppColors.primaryRed)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Active Floor Tables', value: '${tableState.occupiedCount} / ${tableState.tables.length}', icon: Icons.table_restaurant_rounded, iconColor: AppColors.primaryRed)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Pending KDS Tickets', value: '${kitchenState.kitchenOrders.length}', icon: Icons.soup_kitchen_rounded, iconColor: AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Total Staff', value: '${staffState.staffMembers.length}', icon: Icons.badge_rounded, iconColor: AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(title: 'Inventory Alerts', value: '${invState.lowStockCount}', icon: Icons.warning_amber_rounded, iconColor: AppColors.danger)),
            ],
          ),

          const SizedBox(height: 20),

          // Operational Quick Actions
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  onTap: () => context.go('/pos'),
                  child: Column(
                    children: const [
                      Icon(Icons.point_of_sale_rounded, color: AppColors.primaryRed, size: 36),
                      SizedBox(height: 8),
                      Text('POS Billing Terminal', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  onTap: () => context.go('/menu'),
                  child: Column(
                    children: const [
                      Icon(Icons.restaurant_menu_rounded, color: AppColors.primaryRed, size: 36),
                      SizedBox(height: 8),
                      Text('Menu Management', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  onTap: () => context.go('/tables'),
                  child: Column(
                    children: const [
                      Icon(Icons.table_restaurant_rounded, color: AppColors.success, size: 36),
                      SizedBox(height: 8),
                      Text('Floor Plan View', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  onTap: () => context.go('/kitchen'),
                  child: Column(
                    children: const [
                      Icon(Icons.soup_kitchen_rounded, color: AppColors.warning, size: 36),
                      SizedBox(height: 8),
                      Text('Kitchen KDS Screen', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashierDashboard(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('SALES PERSON (CASHIER) DASHBOARD', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              StatusBadge(label: 'Fast Billing Terminal Ready', color: AppColors.success, icon: Icons.bolt_rounded),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: GlassCard(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, color: AppColors.primaryRed, size: 64),
                  const SizedBox(height: 14),
                  const Text('HIGH-SPEED POS BILLING TERMINAL', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Select order type (Dine In, Take Away, Delivery) & process billing', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text('OPEN POS BILLING NOW', style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    ),
                    onPressed: () => context.go('/pos'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
