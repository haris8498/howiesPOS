import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/inventory_item.dart';
import '../../domain/models/user_role.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _stockFilter = 'ALL'; // ALL, LOW_STOCK, IN_STOCK

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventoryData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(inventoryProvider);
    final invNotifier = ref.read(inventoryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredItems = invState.items.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.skuCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.supplierName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_stockFilter == 'LOW_STOCK' && !item.isLowStock) return false;
      if (_stockFilter == 'IN_STOCK' && item.isLowStock) return false;

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Main Title & Action Buttons (Matching Tables Screen)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryRed, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STOCK & INVENTORY CATALOGUE',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time stock valuation, usage consumption, remaining levels & reorder alerts',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  
                  Builder(
                    builder: (context) {
                      final role = ref.watch(authProvider).currentUser.role;
                      final canAddStock = ref.watch(roleRightsProvider).isActionGranted(
                        role,
                        'stock_add',
                        defaultIfMissing: role != UserRole.cashier,
                      );
                      if (!canAddStock) return const SizedBox.shrink();

                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showAddStockItemDialog(context, ref),
                        icon: const Icon(Icons.add_box_rounded, color: Colors.white, size: 16),
                        label: const Text('+ NEW ITEM'),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Compact Stat Overview Row (Matching Table Module)
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Available Stock',
                  value: '${invState.totalRemainingQuantity.toStringAsFixed(0)} Units',
                  icon: Icons.inventory_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  bgColor: isDark ? const Color(0xFF142E18) : const Color(0xFFEBF7ED),
                  isSelected: _stockFilter == 'IN_STOCK',
                  onTap: () => setState(() => _stockFilter = _stockFilter == 'IN_STOCK' ? 'ALL' : 'IN_STOCK'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Stock Used',
                  value: 'PKR ${invState.totalUsedStockValue.toStringAsFixed(0)}',
                  icon: Icons.trending_down_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: isDark ? const Color(0xFF2E2414) : const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Low Stock Alert',
                  value: '${invState.lowStockCount} Items',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFD32F2F),
                  bgColor: isDark ? const Color(0xFF2E1414) : const Color(0xFFFDF0F0),
                  isSelected: _stockFilter == 'LOW_STOCK',
                  onTap: () => setState(() => _stockFilter = _stockFilter == 'LOW_STOCK' ? 'ALL' : 'LOW_STOCK'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Stock Worth',
                  value: 'PKR ${invState.totalStockValue.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  isSelected: _stockFilter == 'ALL',
                  onTap: () => setState(() => _stockFilter = 'ALL'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Low Stock Warning Banner
          if (invState.lowStockCount > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _stockFilter == 'LOW_STOCK'
                    ? const Color(0xFFFEF2F2)
                    : (isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFFFBEB)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _stockFilter == 'LOW_STOCK'
                      ? const Color(0xFFF87171)
                      : const Color(0xFFFCD34D),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _stockFilter == 'LOW_STOCK' ? AppColors.danger : const Color(0xFFD97706),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stockFilter == 'LOW_STOCK'
                              ? 'LOW STOCK ALERT FILTER ACTIVE (${invState.lowStockCount} Critical Items)'
                              : 'CRITICAL INVENTORY ALERT: ${invState.lowStockCount} items below reorder threshold!',
                          style: TextStyle(
                            color: _stockFilter == 'LOW_STOCK' ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _stockFilter == 'LOW_STOCK'
                              ? 'These items need urgent supplier reorder to prevent kitchen stockout.'
                              : 'Items: ${invState.items.where((i) => i.isLowStock).map((i) => i.name).take(4).join(', ')}${invState.lowStockCount > 4 ? '...' : ''}',
                          style: TextStyle(
                            color: _stockFilter == 'LOW_STOCK' ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _stockFilter = _stockFilter == 'LOW_STOCK' ? 'ALL' : 'LOW_STOCK';
                      });
                    },
                    icon: Icon(
                      _stockFilter == 'LOW_STOCK' ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                      size: 14,
                      color: _stockFilter == 'LOW_STOCK' ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                    ),
                    label: Text(
                      _stockFilter == 'LOW_STOCK' ? 'Show All Items' : 'View Low Items (${invState.lowStockCount})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: _stockFilter == 'LOW_STOCK' ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: (_stockFilter == 'LOW_STOCK' ? AppColors.danger : const Color(0xFFD97706)).withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Section & Status Filter Chips & Search Bar (Matching Table Module)
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Quick Stock Status Filter Chips (All, Low Stock, In Stock)
                      _buildStatusFilterChip('ALL', 'All Items', isDark, count: invState.items.length),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        'LOW_STOCK',
                        'Low Alert',
                        isDark,
                        icon: Icons.warning_amber_rounded,
                        count: invState.lowStockCount,
                        isDanger: true,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip('IN_STOCK', 'In Stock', isDark, count: invState.items.length - invState.lowStockCount),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search Bar by Stock Item Name, SKU or Supplier (Matching Tables Screen)
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search stock item...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryRed),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stock Items List Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _stockFilter == 'LOW_STOCK'
                                  ? 'No low stock items! All inventory is above threshold.'
                                  : 'No stock items match your filter criteria',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, _) => Divider(
                          color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildStockRow(context, item, invNotifier, isDark);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
              : (isDark ? const Color(0xFF1E293B) : AppColors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? iconColor : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(
    String filter,
    String label,
    bool isDark, {
    IconData? icon,
    int? count,
    bool isDanger = false,
  }) {
    final isSelected = _stockFilter == filter;
    final activeColor = isDanger ? AppColors.danger : AppColors.primaryRed;
    return InkWell(
      onTap: () {
        setState(() => _stockFilter = filter);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : AppColors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDanger
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF334155) : AppColors.borderGray)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDanger ? AppColors.danger : (isDark ? Colors.white70 : AppColors.textSecondary)),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDanger ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary)),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDanger ? AppColors.danger.withValues(alpha: 0.15) : (isDark ? const Color(0xFF334155) : AppColors.lightGray)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDanger ? AppColors.danger : (isDark ? Colors.white70 : AppColors.textPrimary)),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockRow(BuildContext context, InventoryItem item, InventoryNotifier invNotifier, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.isLowStock
                  ? AppColors.danger.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF1E293B) : AppColors.lightGray),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
              color: item.isLowStock ? AppColors.danger : AppColors.primaryRed,
              size: 18,
            ),
          ),

          const SizedBox(width: 12),

          // Item Name & Category
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.skuCode,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Category: ${item.category}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Remaining Stock Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMAINING',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${item.currentStock.toStringAsFixed(1)} ${item.unit}',
                      style: TextStyle(
                        color: item.isLowStock ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item.initialStock > 0) ? (item.currentStock / item.initialStock).clamp(0.0, 1.0) : 0.5,
                    backgroundColor: isDark ? const Color(0xFF334155) : AppColors.borderGray,
                    color: item.isLowStock ? AppColors.danger : const Color(0xFF2E7D32),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Min: ${item.minThreshold} ${item.unit}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Used Stock Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USED',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.usedStock.toStringAsFixed(1)} ${item.unit}',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.isLowStock
                  ? AppColors.danger.withValues(alpha: 0.15)
                  : const Color(0xFF2E7D32).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: item.isLowStock ? AppColors.danger : const Color(0xFF2E7D32),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.isLowStock) ...[
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 12),
                  const SizedBox(width: 4),
                ],
                Text(
                  item.isLowStock ? 'LOW ALERT' : 'IN STOCK',
                  style: TextStyle(
                    color: item.isLowStock ? AppColors.danger : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // View Audit Report Button
          IconButton(
            icon: Icon(
              Icons.analytics_outlined,
              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              size: 18,
            ),
            tooltip: 'View Usage & Stock Movements Report',
            onPressed: () => _showItemAuditReportModal(context, item, invNotifier),
          ),
        ],
      ),
    );
  }

  void _showItemAuditReportModal(BuildContext context, InventoryItem item, InventoryNotifier invNotifier) {
    final invState = ref.read(inventoryProvider);
    final itemMovements = invState.movements.where((m) => m.itemId == item.id).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderGray),
          ),
          title: Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.primaryRed),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STOCK USAGE & AUDIT REPORT: ${item.name}',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'SKU: ${item.skuCode} • Supplier: ${item.supplierName}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.borderGray),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _modalKpiCard('Initial Stock', '${item.initialStock} ${item.unit}', AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _modalKpiCard('Used Quantity', '${item.usedStock} ${item.unit}', AppColors.gold),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _modalKpiCard('Remaining Stock', '${item.currentStock} ${item.unit}', item.isLowStock ? AppColors.danger : AppColors.success),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('MOVEMENT & USAGE HISTORY LOGS', style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  const SizedBox(height: 10),

                  itemMovements.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: const Text('No stock movements logged for this item yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: itemMovements.length,
                          separatorBuilder: (_, _) => const Divider(color: AppColors.borderGray, height: 1),
                          itemBuilder: (context, idx) {
                            final m = itemMovements[idx];
                            final isStockIn = m.type == StockMovementType.stockIn;
                            final isWastage = m.type == StockMovementType.wastage;
                            final typeLabel = isStockIn
                                ? 'STOCK IN (+)'
                                : (isWastage ? 'WASTAGE (-)' : 'STOCK OUT (-)');
                            final typeColor = isStockIn
                                ? AppColors.success
                                : (isWastage ? AppColors.danger : const Color(0xFFD97706));

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                isStockIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: typeColor,
                              ),
                              title: Text(
                                '$typeLabel: ${m.quantity} ${m.unit}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isStockIn ? AppColors.textPrimary : typeColor),
                              ),
                              subtitle: Text('${m.reason} • ${m.timestamp.hour}:${m.timestamp.minute < 10 ? '0' : ''}${m.timestamp.minute}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              trailing: Text(
                                'PKR ${m.costImpact.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        );
      },
    );
  }

  Widget _modalKpiCard(String label, String val, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }


  void _showAddStockItemDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '50');
    final minCtrl = TextEditingController(text: '10');
    final unitCtrl = TextEditingController(text: 'kg');
    final costCtrl = TextEditingController(text: '850');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'ADD / RESTOCK ITEM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandYellow,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'OWNER',
                                    style: TextStyle(
                                      color: AppColors.deepRed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Type item name to restock existing or create new category',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dialogInput('Item Name (Existing or New)', nameCtrl),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _dialogInput('Quantity to Add (+)', stockCtrl, isNum: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _dialogInput('Min Threshold Qty', minCtrl, isNum: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _dialogInput('Unit (kg, liters, units)', unitCtrl)),
                            const SizedBox(width: 8),
                            Expanded(child: _dialogInput('Cost Per Unit (PKR)', costCtrl, isNum: true)),
                          ],
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter an item name!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                final qty = double.tryParse(stockCtrl.text) ?? 50.0;
                                final minThresh = double.tryParse(minCtrl.text) ?? 10.0;
                                final cost = double.tryParse(costCtrl.text) ?? 100.0;
                                final unit = unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'kg';

                                final success = await ref.read(inventoryProvider.notifier).addOrUpdateStock(
                                      itemName: name,
                                      category: 'General',
                                      quantity: qty,
                                      unit: unit,
                                      costPerUnit: cost,
                                      supplierName: 'General Supplier',
                                      reason: 'Initial Inward / Restock',
                                      minThreshold: minThresh,
                                    );

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }

                                if (context.mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Successfully processed stock for "$name"!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save stock item "$name". Please verify connection.'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                              label: const Text(
                                'SAVE & PROCESS STOCK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _dialogInput(String label, TextEditingController ctrl, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.lightGray,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderGray)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed)),
      ),
    );
  }
}
