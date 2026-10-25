import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/inventory_item.dart';
import '../../domain/models/user_role.dart';

class StockInOutScreen extends ConsumerStatefulWidget {
  const StockInOutScreen({super.key});

  @override
  ConsumerState<StockInOutScreen> createState() => _StockInOutScreenState();
}

class _StockInOutScreenState extends ConsumerState<StockInOutScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'ITEMS'; // ITEMS, LOW_STOCK, ALL, IN, OUT, WASTAGE
  String? _selectedProductFilterId; // Selected product for top metrics & movement inspection

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

    // Filter by selected product for top metrics
    final selectedProduct = _selectedProductFilterId != null
        ? invState.items.where((i) => i.id == _selectedProductFilterId).firstOrNull
        : null;

    final productMovements = _selectedProductFilterId != null
        ? invState.movements.where((m) =>
            m.itemId == _selectedProductFilterId ||
            (selectedProduct != null && m.itemName.trim().toLowerCase() == selectedProduct.name.trim().toLowerCase())).toList()
        : invState.movements;

    // Calculate metrics
    final stockInMovements = productMovements.where((m) => m.type == StockMovementType.stockIn).toList();
    final stockOutMovements = productMovements.where((m) => m.type == StockMovementType.stockOut || m.type == StockMovementType.saleAutoDeduction).toList();
    final wastageMovements = productMovements.where((m) => m.type == StockMovementType.wastage).toList();

    final totalStockInQty = stockInMovements.fold(0.0, (sum, m) => sum + m.quantity);
    final totalStockOutQty = stockOutMovements.fold(0.0, (sum, m) => sum + m.quantity);
    final totalWastageQty = wastageMovements.fold(0.0, (sum, m) => sum + m.quantity);
    final totalLogsCount = productMovements.length;

    final unitSuffix = selectedProduct != null ? ' ${selectedProduct.unit}' : ' Qty';

    final filteredMovements = productMovements.where((m) {
      final matchesSearch = _searchQuery.isEmpty ||
          m.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.reason.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedTypeFilter == 'IN' && m.type != StockMovementType.stockIn) return false;
      if (_selectedTypeFilter == 'OUT' && (m.type != StockMovementType.stockOut && m.type != StockMovementType.saleAutoDeduction)) return false;
      if (_selectedTypeFilter == 'WASTAGE' && m.type != StockMovementType.wastage) return false;

      return true;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Quick Operations
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
                    child: const Icon(Icons.swap_vert_rounded, color: AppColors.primaryRed, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STOCK IN & STOCK OUT MODULE',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add stock items (Stock In) or remove inventory (Stock Out / Wastage) with live logs',
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
                      final roleRights = ref.watch(roleRightsProvider);
                      final canStockIn = roleRights.isActionGranted(
                        role,
                        'stock_in_action',
                        defaultIfMissing: role != UserRole.cashier,
                      );
                      final canStockOut = roleRights.isActionGranted(
                        role,
                        'stock_out_action',
                        defaultIfMissing: role != UserRole.cashier,
                      );

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canStockIn)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showStockInDialog(context, ref, invState),
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
                              label: const Text('+ STOCK IN (ADD)'),
                            ),
                          if (canStockIn && canStockOut)
                            const SizedBox(width: 10),
                          if (canStockOut)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showStockOutDialog(context, ref, invState),
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 18),
                              label: const Text('- STOCK OUT (REMOVE)'),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Product Filter Dropdown in Front of Top Metrics
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedProductFilterId != null
                    ? AppColors.primaryRed
                    : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
                width: _selectedProductFilterId != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.primaryRed),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FILTER TOP METRICS BY PRODUCT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _selectedProductFilterId == null
                          ? 'All Products (Storewide Combined)'
                          : '${selectedProduct?.name ?? "Product"} (${selectedProduct?.category ?? ""})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedProductFilterId != null ? AppColors.primaryRed : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedProductFilterId,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.all_inclusive_rounded, size: 16, color: AppColors.primaryRed),
                                SizedBox(width: 8),
                                Text('All Products (Overall Store Data)', style: TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          ...invState.items.map((item) {
                            return DropdownMenuItem<String?>(
                              value: item.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.name} (${item.category}) — Current: ${item.currentStock % 1 == 0 ? item.currentStock.toInt() : item.currentStock.toStringAsFixed(1)} ${item.unit}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedProductFilterId = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                if (_selectedProductFilterId != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Show All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () => setState(() => _selectedProductFilterId = null),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Compact Stat Overview Row (Filtered by Product or Storewide)
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Stock Inward',
                  value: '${totalStockInQty % 1 == 0 ? totalStockInQty.toInt() : totalStockInQty.toStringAsFixed(1)}$unitSuffix',
                  icon: Icons.south_west_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  bgColor: isDark ? const Color(0xFF142E18) : const Color(0xFFEBF7ED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Stock Outward',
                  value: '${totalStockOutQty % 1 == 0 ? totalStockOutQty.toInt() : totalStockOutQty.toStringAsFixed(1)}$unitSuffix',
                  icon: Icons.north_east_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: isDark ? const Color(0xFF2E2414) : const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Wastage / Spoiled',
                  value: '${totalWastageQty % 1 == 0 ? totalWastageQty.toInt() : totalWastageQty.toStringAsFixed(1)}$unitSuffix',
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFD32F2F),
                  bgColor: isDark ? const Color(0xFF2E1414) : const Color(0xFFFDF0F0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Audit Logs',
                  value: '$totalLogsCount Logs',
                  icon: Icons.swap_vert_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Movement Log Search & Filter Chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChoiceChip('ITEMS', '📦 Stock By Category (${invState.items.length})', isDark, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      _buildTypeChoiceChip('LOW_STOCK', '⚠️ Low Alert (${invState.lowStockCount})', isDark, color: AppColors.danger),
                      const SizedBox(width: 6),
                      _buildTypeChoiceChip('ALL', '📜 Movement Audit Logs (${productMovements.length})', isDark),
                      const SizedBox(width: 6),
                      _buildTypeChoiceChip('IN', 'Stock In (+)', isDark, color: const Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      _buildTypeChoiceChip('OUT', 'Stock Out (-)', isDark, color: const Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      _buildTypeChoiceChip('WASTAGE', 'Wastage 🗑️', isDark, color: AppColors.danger),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search Bar
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
                    hintText: (_selectedTypeFilter == 'ITEMS' || _selectedTypeFilter == 'LOW_STOCK') ? 'Search stock items...' : 'Search movement logs...',
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

          // Movements History Log / Stock Items Grouped by Category
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (_selectedTypeFilter == 'ITEMS' || _selectedTypeFilter == 'LOW_STOCK')
                    ? Builder(
                        builder: (context) {
                          final filteredStockItems = invState.items.where((i) {
                            if (_selectedProductFilterId != null && i.id != _selectedProductFilterId) return false;
                            final q = _searchQuery.toLowerCase();
                            final matches = q.isEmpty ||
                                i.name.toLowerCase().contains(q) ||
                                i.skuCode.toLowerCase().contains(q) ||
                                i.category.toLowerCase().contains(q) ||
                                i.supplierName.toLowerCase().contains(q);
                            if (!matches) return false;
                            if (_selectedTypeFilter == 'LOW_STOCK' && !i.isLowStock) return false;
                            return true;
                          }).toList();

                          if (filteredStockItems.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedTypeFilter == 'LOW_STOCK' ? 'No low stock items found' : 'No stock items found',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Group by Category
                          final Map<String, List<InventoryItem>> categoryMap = {};
                          for (final item in filteredStockItems) {
                            final cat = item.category.trim().isNotEmpty ? item.category.trim() : 'General';
                            categoryMap.putIfAbsent(cat, () => []).add(item);
                          }
                          final sortedCats = categoryMap.keys.toList()..sort((a, b) => a.compareTo(b));

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: sortedCats.length,
                            itemBuilder: (context, catIdx) {
                              final catName = sortedCats[catIdx];
                              final catItems = categoryMap[catName]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildCategoryHeader(context, catName, catItems, invState, isDark),
                                  ...catItems.map((item) => _buildStockItemRow(context, item, invState, isDark)),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          );
                        },
                      )
                    : (filteredMovements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'No stock movement transactions recorded',
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
                            itemCount: filteredMovements.length,
                            separatorBuilder: (_, _) => Divider(
                              color: isDark ? const Color(0xFF334155) : AppColors.borderGray,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final m = filteredMovements[index];
                              return _buildMovementRow(context, m, isDark);
                            },
                          )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    String categoryName,
    List<InventoryItem> items,
    InventoryState state,
    bool isDark,
  ) {
    final role = ref.watch(authProvider).currentUser.role;
    final roleRights = ref.watch(roleRightsProvider);
    final canStockIn = roleRights.isActionGranted(
      role,
      'stock_in_action',
      defaultIfMissing: role != UserRole.cashier,
    );
    final canStockOut = roleRights.isActionGranted(
      role,
      'stock_out_action',
      defaultIfMissing: role != UserRole.cashier,
    );

    final totalStockValuation = items.fold(0.0, (sum, i) => sum + i.totalStockValue);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.category_rounded, size: 16, color: AppColors.primaryRed),
          ),
          const SizedBox(width: 10),
          Text(
            categoryName.toUpperCase(),
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${items.length} ${items.length == 1 ? "item" : "items"} • Worth: PKR ${totalStockValuation.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          if (canStockIn)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 30),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showStockInDialog(context, ref, state, preSelectedCategory: categoryName),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text('+ IN ($categoryName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          if (canStockIn && canStockOut)
            const SizedBox(width: 6),
          if (canStockOut)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 30),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showStockOutDialog(context, ref, state, preSelectedCategory: categoryName),
              icon: const Icon(Icons.remove_rounded, size: 14),
              label: Text('- OUT ($categoryName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
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
    );
  }

  Widget _buildTypeChoiceChip(String type, String label, bool isDark, {Color? color}) {
    final isSelected = _selectedTypeFilter == type;
    final activeColor = color ?? AppColors.primaryRed;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white : AppColors.textPrimary),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.white,
      side: BorderSide(
        color: isSelected
            ? activeColor
            : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
        width: 1.2,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedTypeFilter = type);
        }
      },
    );
  }

  Widget _buildMovementRow(BuildContext context, StockMovement m, bool isDark) {
    final isStockIn = m.type == StockMovementType.stockIn;
    final isWastage = m.type == StockMovementType.wastage;

    final badgeColor = isStockIn
        ? const Color(0xFF2E7D32)
        : (isWastage ? AppColors.danger : const Color(0xFFD97706));
    final badgeLabel = isStockIn
        ? 'STOCK IN (+)'
        : (isWastage ? 'WASTAGE (-)' : 'STOCK OUT (-)');

    return Container(
      color: isDark ? const Color(0xFF0F172A) : AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            child: Icon(
              isStockIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: badgeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.itemName,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor, width: 1),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Reason: ${m.reason} • ${m.timestamp.day}/${m.timestamp.month} ${m.timestamp.hour}:${m.timestamp.minute < 10 ? "0" : ""}${m.timestamp.minute}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isStockIn ? "+" : "-"}${m.quantity} ${m.unit}',
                style: TextStyle(
                  color: isStockIn ? const Color(0xFF2E7D32) : AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Impact: PKR ${m.costImpact.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockItemRow(
    BuildContext context,
    InventoryItem item,
    InventoryState state,
    bool isDark,
  ) {
    final isLow = item.isLowStock;
    final statusColor = isLow ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);

    return Container(
      color: isDark ? const Color(0xFF0F172A) : AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(
              Icons.inventory_2_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLow ? '⚠️ LOW ALERT' : 'IN STOCK',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.skuCode,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Stock Levels
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE STOCK',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${item.currentStock.toStringAsFixed(0)} ${item.unit}',
                  style: TextStyle(
                    color: isLow ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Used: ${item.usedStock.toStringAsFixed(0)} ${item.unit}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Price & Worth
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'UNIT COST / WORTH',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                Text(
                  'PKR ${item.costPerUnit.toStringAsFixed(0)} / ${item.unit}',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Worth: PKR ${item.totalStockValue.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Action Buttons: + IN and - OUT scoped strictly to this item and its category
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 32),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showStockInDialog(
                  context,
                  ref,
                  state,
                  preSelectedItemId: item.id,
                  preSelectedCategory: item.category,
                ),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('+ IN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 32),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showStockOutDialog(
                  context,
                  ref,
                  state,
                  preSelectedItemId: item.id,
                  preSelectedCategory: item.category,
                ),
                icon: const Icon(Icons.remove_rounded, size: 14),
                label: const Text('- OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStockInDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryState state, {
    String? preSelectedItemId,
    String? preSelectedCategory,
  }) {
    // Resolve category scope
    String? effectiveCategory = preSelectedCategory;
    if (effectiveCategory == null && preSelectedItemId != null) {
      final match = state.items.where((i) => i.id == preSelectedItemId).firstOrNull;
      if (match != null) effectiveCategory = match.category;
    }

    // Filter available items strictly to category if scoped
    final categoryItems = (effectiveCategory != null && effectiveCategory.trim().isNotEmpty)
        ? state.items.where((i) => i.category.trim().toLowerCase() == effectiveCategory!.trim().toLowerCase()).toList()
        : state.items;

    bool isCustomItemMode = categoryItems.isEmpty;
    String? selectedItemId = preSelectedItemId;
    if (selectedItemId == null || !categoryItems.any((i) => i.id == selectedItemId)) {
      selectedItemId = categoryItems.isNotEmpty ? categoryItems.first.id : null;
    }

    final customNameCtrl = TextEditingController();
    final customUnitCtrl = TextEditingController(text: 'kg');
    final customCostCtrl = TextEditingController(text: '850');
    final customMinThresholdCtrl = TextEditingController(text: '10');
    final qtyCtrl = TextEditingController(text: '25');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedItem = categoryItems.firstWhere(
              (i) => i.id == selectedItemId,
              orElse: () => categoryItems.isNotEmpty
                  ? categoryItems.first
                  : const InventoryItem(
                      id: '',
                      skuCode: '',
                      name: '',
                      category: '',
                      currentStock: 0,
                      minThreshold: 0,
                      unit: 'units',
                      costPerUnit: 0,
                      supplierName: '',
                    ),
            );

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Premium Brand Header Bar
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
                            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'RECORD STOCK IN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (effectiveCategory != null && effectiveCategory.trim().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.brandYellow,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'CATEGORY: ${effectiveCategory.toUpperCase()}',
                                          style: const TextStyle(
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
                                  effectiveCategory != null && effectiveCategory.trim().isNotEmpty
                                      ? 'Add stock strictly within "$effectiveCategory" category'
                                      : 'Restock existing inventory or type custom item & category',
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

                    // 2. Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Segmented Mode Selector: Existing vs Custom
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: categoryItems.isEmpty
                                        ? null
                                        : () => setDialogState(() => isCustomItemMode = false),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: !isCustomItemMode
                                            ? AppColors.primaryRed.withValues(alpha: isDark ? 0.25 : 0.08)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !isCustomItemMode
                                              ? AppColors.primaryRed
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          width: !isCustomItemMode ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.list_alt_rounded, size: 16, color: !isCustomItemMode ? AppColors.primaryRed : AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Existing Items (${categoryItems.length})',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: !isCustomItemMode ? AppColors.primaryRed : (isDark ? Colors.white : AppColors.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setDialogState(() => isCustomItemMode = true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isCustomItemMode
                                            ? AppColors.primaryRed.withValues(alpha: isDark ? 0.25 : 0.08)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isCustomItemMode
                                              ? AppColors.primaryRed
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          width: isCustomItemMode ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_box_rounded, size: 16, color: isCustomItemMode ? AppColors.primaryRed : AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Text(
                                            '+ Custom Item',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: isCustomItemMode ? AppColors.primaryRed : (isDark ? Colors.white : AppColors.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            if (!isCustomItemMode) ...[
                              // Select Existing Item Dropdown (Strictly Filtered to this Category)
                              Row(
                                children: [
                                  const Icon(Icons.inventory_rounded, size: 16, color: AppColors.primaryRed),
                                  const SizedBox(width: 6),
                                  Text(
                                    effectiveCategory != null && effectiveCategory.trim().isNotEmpty
                                        ? 'SELECT ITEM IN "${effectiveCategory.toUpperCase()}"'
                                        : 'SELECT EXISTING RAW STOCK ITEM',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedItemId,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryRed),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                                ),
                                items: categoryItems.map((i) {
                                  return DropdownMenuItem(
                                    value: i.id,
                                    child: Text(
                                      '${i.name} • Current: ${i.currentStock.toStringAsFixed(0)} ${i.unit}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedItemId = val;
                                  });
                                },
                              ),
                              if (selectedItem.id.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Category: ${selectedItem.category}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      Text('Unit Cost: PKR ${selectedItem.costPerUnit.toStringAsFixed(0)} / ${selectedItem.unit}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
                                    ],
                                  ),
                                ),
                              ],
                            ] else ...[
                              // Custom Item Input Form
                              if (effectiveCategory != null && effectiveCategory.trim().isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 14, color: AppColors.primaryRed),
                                      const SizedBox(width: 8),
                                      Text('Category Locked To: ', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                                      Text(effectiveCategory, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.primaryRed)),
                                    ],
                                  ),
                                ),
                              ],
                              Row(
                                children: [
                                  const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.primaryRed),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TYPE CUSTOM ITEM NAME',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: customNameCtrl,
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Mozzarella Cheese or Tomato Sauce',
                                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
                                  prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18, color: AppColors.primaryRed),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('UNIT (kg, liters, units)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: customUnitCtrl,
                                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            hintText: 'kg / liters / units',
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('UNIT COST (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: customCostCtrl,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            prefixText: 'PKR ',
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('MIN THRESHOLD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: customMinThresholdCtrl,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. 10',
                                            prefixIcon: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                                            filled: true,
                                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 18),

                            // Quantity Section & Quick Preset Chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.add_shopping_cart_rounded, size: 16, color: AppColors.primaryRed),
                                    const SizedBox(width: 6),
                                    Text(
                                      'INWARD QUANTITY (+)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '+${qtyCtrl.text} Units',
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {}),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter quantity to add (+)',
                                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
                                prefixIcon: const Icon(Icons.exposure_plus_1_rounded, size: 18, color: AppColors.success),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.success, width: 2)),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Quick Quantity Presets Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [5, 10, 25, 50, 100].map((presetVal) {
                                final isSelected = qtyCtrl.text == presetVal.toString();
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      qtyCtrl.text = presetVal.toString();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.success
                                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.success
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Text(
                                      '+$presetVal Qty',
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 24),

                            // Submit Action Button
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
                                    final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                                    if (qty <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a valid positive quantity!'), backgroundColor: AppColors.danger),
                                      );
                                      return;
                                    }

                                    final targetName = isCustomItemMode
                                        ? customNameCtrl.text.trim()
                                        : (selectedItem.id.isNotEmpty ? selectedItem.name : '');

                                    if (targetName.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please select or type an item name!'), backgroundColor: AppColors.danger),
                                      );
                                      return;
                                    }

                                    // Strictly scope category to effectiveCategory when selected
                                    final targetCat = (effectiveCategory != null && effectiveCategory.trim().isNotEmpty)
                                        ? effectiveCategory.trim()
                                        : (isCustomItemMode ? 'General' : (selectedItem.category.isNotEmpty ? selectedItem.category : 'General'));

                                    final targetUnit = isCustomItemMode ? (customUnitCtrl.text.trim().isNotEmpty ? customUnitCtrl.text.trim() : 'kg') : selectedItem.unit;
                                    final targetCost = isCustomItemMode ? (double.tryParse(customCostCtrl.text.trim()) ?? 100.0) : selectedItem.costPerUnit;
                                    final targetSupplier = isCustomItemMode ? 'General Supplier' : (selectedItem.supplierName.isNotEmpty ? selectedItem.supplierName : 'General Supplier');
                                    final targetMinThreshold = isCustomItemMode
                                        ? (double.tryParse(customMinThresholdCtrl.text.trim()) ?? 10.0)
                                        : (selectedItem.id.isNotEmpty ? selectedItem.minThreshold : 10.0);

                                    final success = await ref.read(inventoryProvider.notifier).addOrUpdateStock(
                                          itemName: targetName,
                                          category: targetCat,
                                          quantity: qty,
                                          unit: targetUnit,
                                          costPerUnit: targetCost,
                                          supplierName: targetSupplier,
                                          reason: 'Stock In Restock',
                                          minThreshold: targetMinThreshold,
                                        );

                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }

                                    if (context.mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully recorded Stock In (+${qty.toStringAsFixed(0)} $targetUnit) for "$targetName" in $targetCat!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to record Stock In for "$targetName". Please check backend connection.'),
                                            backgroundColor: AppColors.danger,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                                  label: const Text(
                                    'CONFIRM & RECORD STOCK IN',
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
      },
    );
  }

  void _showStockOutDialog(
    BuildContext context,
    WidgetRef ref,
    InventoryState state, {
    String? preSelectedItemId,
    String? preSelectedCategory,
  }) {
    // Resolve category scope
    String? effectiveCategory = preSelectedCategory;
    if (effectiveCategory == null && preSelectedItemId != null) {
      final match = state.items.where((i) => i.id == preSelectedItemId).firstOrNull;
      if (match != null) effectiveCategory = match.category;
    }

    // Filter available items strictly to category if scoped
    final categoryItems = (effectiveCategory != null && effectiveCategory.trim().isNotEmpty)
        ? state.items.where((i) => i.category.trim().toLowerCase() == effectiveCategory!.trim().toLowerCase()).toList()
        : state.items;

    if (categoryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No stock items found in category "${effectiveCategory ?? "selected"}" to deduct stock from!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    String? selectedItemId = preSelectedItemId;
    if (selectedItemId == null || !categoryItems.any((i) => i.id == selectedItemId)) {
      selectedItemId = categoryItems.isNotEmpty ? categoryItems.first.id : null;
    }

    StockMovementType type = StockMovementType.stockOut;

    InventoryItem? initialItem;
    if (selectedItemId != null) {
      final idx = categoryItems.indexWhere((i) => i.id == selectedItemId);
      if (idx >= 0) initialItem = categoryItems[idx];
    }

    final defaultQty = (initialItem != null && initialItem.currentStock < 10.0)
        ? (initialItem.currentStock.truncateToDouble() == initialItem.currentStock
            ? initialItem.currentStock.toInt().toString()
            : initialItem.currentStock.toString())
        : '10';

    final qtyCtrl = TextEditingController(text: defaultQty);
    final reasonCtrl = TextEditingController(text: 'Kitchen Usage Prep');
    String? errorText;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            InventoryItem? currentItem;
            if (selectedItemId != null) {
              final idx = categoryItems.indexWhere((i) => i.id == selectedItemId);
              if (idx >= 0) currentItem = categoryItems[idx];
            }
            final availableStock = currentItem?.currentStock ?? 0.0;
            final unitStr = currentItem?.unit ?? 'units';
            final enteredQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
            final isExcessive = enteredQty > availableStock;
            final isInvalidQty = enteredQty <= 0;

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
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFFEE2E2))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.primaryRed, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'RECORD STOCK OUT',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (effectiveCategory != null && effectiveCategory.trim().isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'CATEGORY: ${effectiveCategory.toUpperCase()}',
                                          style: const TextStyle(
                                            color: AppColors.primaryRed,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  effectiveCategory != null && effectiveCategory.trim().isNotEmpty
                                      ? 'Deduct stock strictly from items in "$effectiveCategory"'
                                      : 'Deduct usage or mark expired/damaged items',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 22),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Select Item strictly from this category
                            Text(
                              effectiveCategory != null && effectiveCategory.trim().isNotEmpty
                                  ? 'SELECT RAW ITEM IN "${effectiveCategory.toUpperCase()}"'
                                  : 'SELECT RAW STOCK ITEM',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedItemId,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryRed),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                              ),
                              items: categoryItems.map((i) {
                                return DropdownMenuItem(
                                  value: i.id,
                                  child: Text('${i.name} (Available: ${i.currentStock % 1 == 0 ? i.currentStock.toInt() : i.currentStock.toStringAsFixed(1)} ${i.unit})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedItemId = val;
                                  errorText = null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),

                            // Available Stock Badge / Info Pill
                            if (currentItem != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: availableStock > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: availableStock > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      availableStock > 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: availableStock > 0 ? const Color(0xFF16A34A) : AppColors.danger,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Available in Stock: $availableStock $unitStr',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: availableStock > 0 ? const Color(0xFF15803D) : AppColors.danger,
                                        ),
                                      ),
                                    ),
                                    if (availableStock > 0)
                                      InkWell(
                                        onTap: () {
                                          final maxStr = availableStock.truncateToDouble() == availableStock
                                              ? availableStock.toInt().toString()
                                              : availableStock.toString();
                                          qtyCtrl.text = maxStr;
                                          setDialogState(() {
                                            errorText = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'USE MAX',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),

                            // Deduction Reason Type
                            Text(
                              'DEDUCTION REASON TYPE',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<StockMovementType>(
                              initialValue: type,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: StockMovementType.stockOut,
                                  child: Row(
                                    children: [
                                      Icon(Icons.restaurant_rounded, size: 16, color: Color(0xFFD97706)),
                                      SizedBox(width: 8),
                                      Text('Kitchen / Store Usage (Stock Out)'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: StockMovementType.wastage,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                      SizedBox(width: 8),
                                      Text('Expired / Damaged / Spoiled (Wastage)'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    type = val;
                                    if (val == StockMovementType.stockOut && (reasonCtrl.text.isEmpty || reasonCtrl.text.contains('Expired') || reasonCtrl.text.contains('Wastage'))) {
                                      reasonCtrl.text = 'Kitchen Usage Prep';
                                    } else if (val == StockMovementType.wastage && (reasonCtrl.text.isEmpty || reasonCtrl.text.contains('Kitchen'))) {
                                      reasonCtrl.text = 'Expired / Damaged Item';
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Outward Quantity
                            Text(
                              'OUTWARD QUANTITY (-)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              onChanged: (_) {
                                setDialogState(() {
                                  errorText = null;
                                });
                              },
                              decoration: InputDecoration(
                                suffixText: unitStr,
                                suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 2)),
                                errorText: isExcessive
                                    ? 'Exceeds available stock ($availableStock $unitStr)'
                                    : (isInvalidQty && qtyCtrl.text.isNotEmpty ? 'Enter a quantity greater than 0' : errorText),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Reason Note
                            Text(
                              'TRANSACTION NOTE / REASON',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: reasonCtrl,
                              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter reason for deduction...',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                onPressed: () async {
                                  final qty = double.tryParse(qtyCtrl.text.trim());
                                  if (qty == null || qty <= 0) {
                                    setDialogState(() {
                                      errorText = 'Please enter a valid positive quantity';
                                    });
                                    return;
                                  }

                                  if (qty > availableStock) {
                                    setDialogState(() {
                                      errorText = 'Outward quantity ($qty) cannot exceed available stock ($availableStock $unitStr)';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cannot record stock out! Outward quantity ($qty) exceeds available stock ($availableStock $unitStr).'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                    return;
                                  }

                                  if (selectedItemId != null) {
                                    final success = await ref.read(inventoryProvider.notifier).addStockMovement(
                                          itemId: selectedItemId!,
                                          type: type,
                                          quantity: qty,
                                          reason: reasonCtrl.text.trim().isNotEmpty
                                              ? reasonCtrl.text.trim()
                                              : (type == StockMovementType.wastage ? 'Wastage' : 'Kitchen Usage'),
                                        );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }

                                    if (context.mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Successfully recorded stock deduction of $qty $unitStr for ${currentItem?.name ?? "item"} in ${currentItem?.category ?? ""}',
                                            ),
                                            backgroundColor: const Color(0xFF16A34A),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Failed to record stock out! Outward quantity exceeds available stock.'),
                                            backgroundColor: AppColors.danger,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                                label: const Text(
                                  'CONFIRM & DEDUCT STOCK OUT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.8,
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
      },
    );
  }
}
