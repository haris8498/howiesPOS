import '../../domain/models/order_model.dart';
import '../../services/api/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../data/takeaway_repository.dart';
import '../../domain/models/takeaway_model.dart';
import '../../domain/models/user_role.dart';
import '../../services/receipt_printer_service.dart';
import '../../shared/widgets/cashier_sidebar_footer.dart';

class TakeawayScreen extends ConsumerStatefulWidget {
  const TakeawayScreen({super.key});

  @override
  ConsumerState<TakeawayScreen> createState() => _TakeawayScreenState();
}

class _TakeawayScreenState extends ConsumerState<TakeawayScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String? _selectedOrderId;
  String? _activeDetailOrderId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TakeawayOrder? _getSelectedOrder(List<TakeawayOrder> orders) {
    if (orders.isEmpty) return null;
    if (_selectedOrderId != null) {
      final found = orders.where((o) => o.id == _selectedOrderId).firstOrNull;
      if (found != null) return found;
    }
    return orders.where((o) => !o.isPaid && o.status.toLowerCase() != 'completed').firstOrNull ?? orders.firstOrNull;
  }

  List<String> _splitItemsSummary(String summary) {
    if (summary.trim().isEmpty) return [];
    final List<String> result = [];
    int depth = 0;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < summary.length; i++) {
      final char = summary[i];
      if (char == '(') {
        depth++;
        buffer.write(char);
      } else if (char == ')') {
        if (depth > 0) depth--;
        buffer.write(char);
      } else if (char == ',' && depth == 0) {
        final str = buffer.toString().trim();
        if (str.isNotEmpty) result.add(str);
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) result.add(remaining);
    return result;
  }

  Widget _buildOrderedItemsBreakdown(TakeawayOrder order, bool isDark) {
    if (order.items.isNotEmpty) {
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: order.items.length,
        separatorBuilder: (context, index) => Divider(
          height: 16,
          thickness: 1,
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        itemBuilder: (context, index) {
          final it = order.items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: it.isCancelled
                        ? AppColors.danger.withValues(alpha: 0.12)
                        : AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: it.isCancelled
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : AppColors.primaryRed.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${it.quantity}x',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: it.isCancelled ? AppColors.danger : AppColors.primaryRed,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        it.item.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          decoration: it.isCancelled ? TextDecoration.lineThrough : null,
                          color: it.isCancelled
                              ? AppColors.danger
                              : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      if (it.selectedSize.isNotEmpty && it.selectedSize != 'Regular')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Size: ${it.selectedSize}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (it.isCancelled && it.cancelReason != null && it.cancelReason!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Cancelled: ${it.cancelReason}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.danger,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (it.totalPrice > 0)
                  Text(
                    'PKR ${it.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: it.isCancelled
                          ? const Color(0xFF94A3B8)
                          : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    final parsed = _splitItemsSummary(order.itemsSummary);
    if (parsed.isEmpty) {
      return Center(
        child: Text(
          'No items recorded for this order',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final regex = RegExp(r'^(\d+)x\s+(.+)$');
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: parsed.length,
      separatorBuilder: (context, index) => Divider(
        height: 16,
        thickness: 1,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
      itemBuilder: (context, index) {
        final raw = parsed[index];
        final match = regex.firstMatch(raw);
        final qty = match != null ? match.group(1)! : '1';
        final name = match != null ? match.group(2)! : raw;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryRed.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${qty}x',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTakeawayActionPillButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool isFilled,
    required bool isDark,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFilled
              ? (isEnabled ? color : color.withValues(alpha: 0.5))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFilled
                ? color
                : (isEnabled ? color : color.withValues(alpha: 0.4)),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isFilled
                  ? color.withValues(alpha: isDark ? 0.35 : 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: isFilled ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isFilled ? Colors.white : color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isFilled ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isFilled)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: color.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final takeawayState = ref.watch(takeawayProvider);
    final takeawayNotifier = ref.read(takeawayProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If an order is active/selected for full details view, render the Full Screen Takeaway Order Details view (Not in pop-up)
    if (_activeDetailOrderId != null) {
      final activeOrder = takeawayState.orders.where((o) => o.id == _activeDetailOrderId).firstOrNull;
      if (activeOrder != null) {
        return _buildFullTakeawayOrderScreen(context, ref, activeOrder, takeawayState, takeawayNotifier, isDark);
      }
    }

    final activeCount = takeawayState.orders.where((o) => o.status != 'Completed' && o.status != 'Cancelled').length;
    final readyCount = takeawayState.orders.where((o) => o.status == 'Ready for Pickup').length;
    final completedToday = takeawayState.orders.where((o) => o.status == 'Completed').length;
    final cancelledCount = takeawayState.orders.where((o) => o.status == 'Cancelled').length;

    final filteredOrders = takeawayState.orders.where((o) {
      // 1. Status Filter
      if (_selectedFilter == 'Active') {
        if (o.status == 'Completed' || o.status == 'Cancelled') return false;
      } else if (_selectedFilter == 'Ready for Pickup') {
        if (o.status != 'Ready for Pickup') return false;
      } else if (_selectedFilter == 'Completed') {
        if (o.status != 'Completed' && !o.isPaid) return false;
      } else if (_selectedFilter == 'Cancelled') {
        if (o.status != 'Cancelled') return false;
      }

      // 2. Search Query Filter
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return o.tokenNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone.toLowerCase().contains(q) ||
          o.itemsSummary.toLowerCase().contains(q);
    }).toList();

    final selectedOrder = _getSelectedOrder(takeawayState.orders);
    if (_selectedOrderId == null && selectedOrder != null) {
      _selectedOrderId = selectedOrder.id;
    }

    final bool canEditSelected = selectedOrder != null &&
        !selectedOrder.isPaid &&
        selectedOrder.status.toLowerCase() != 'completed' &&
        !selectedOrder.isBillPrinted;

    final bool canSettleSelected = selectedOrder != null &&
        !selectedOrder.isPaid &&
        selectedOrder.status.toLowerCase() != 'completed';

    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier;
    final bool canCreateTakeaway = ref.watch(roleRightsProvider).isActionGranted(
      authState.currentUser.role,
      'takeaway_create',
      defaultIfMissing: authState.currentUser.role != UserRole.cashier,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(18.0, 18.0, 18.0, isCashier ? 0.0 : 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCashier) ...[
            // 1. Left Action Column (Sidebar - Cashier only)
            SizedBox(
              width: 240,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  // Button 1: Edit & Add (Outline Purple)
                  _buildTakeawayActionPillButton(
                    title: 'Edit & Add',
                    icon: Icons.post_add_rounded,
                    color: const Color(0xFF9333EA),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: canEditSelected,
                    onTap: () {
                      final sel = _getSelectedOrder(takeawayState.orders);
                      if (sel != null && !sel.isPaid && sel.status.toLowerCase() != 'completed' && !sel.isBillPrinted) {
                        _openEditTakeawayOrderDialog(context, ref, sel, takeawayNotifier, isDark);
                      } else if (sel != null && (sel.isPaid || sel.isBillPrinted)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cannot edit order ${sel.tokenNumber} because bill is already printed or settled.')),
                        );
                      } else {
                        if (canCreateTakeaway) {
                          _openCreateTakeawayOrderDialog(context, ref, takeawayNotifier, isDark);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You do not have permission to create takeaway orders.')),
                          );
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 2: Kitchen (KOT) (Outline Orange)
                  _buildTakeawayActionPillButton(
                    title: 'Kitchen (KOT)',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFFD97706),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedOrder != null,
                    onTap: () {
                      final sel = _getSelectedOrder(takeawayState.orders);
                      if (sel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or create a takeaway order first.')),
                        );
                        return;
                      }
                      _showTakeawayKitchenReceiptDialog(context, sel, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 3: Customer Bill (Outline Blue)
                  _buildTakeawayActionPillButton(
                    title: 'Customer Bill',
                    icon: Icons.description_rounded,
                    color: const Color(0xFF2563EB),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedOrder != null,
                    onTap: () {
                      final sel = _getSelectedOrder(takeawayState.orders);
                      if (sel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or create a takeaway order first.')),
                        );
                        return;
                      }
                      _showTakeawayCustomerBillDialog(context, ref, sel, takeawayNotifier, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button: Cancel Item (Outline Red)
                  _buildTakeawayActionPillButton(
                    title: 'Cancel Item',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedOrder != null && !selectedOrder.isPaid && selectedOrder.status.toLowerCase() != 'cancelled',
                    onTap: () {
                      final sel = _getSelectedOrder(takeawayState.orders);
                      if (sel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a takeaway order.')),
                        );
                        return;
                      }
                      _showCancelTakeawayItemDialog(context, ref, sel, takeawayNotifier, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 4: Full Bill & Pay (Solid Red)
                  _buildTakeawayActionPillButton(
                    title: 'Full Bill & Pay',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFFDC2626),
                    isFilled: true,
                    isDark: isDark,
                    isEnabled: canSettleSelected,
                    onTap: () {
                      final sel = _getSelectedOrder(takeawayState.orders);
                      if (sel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select an active takeaway order to pay.')),
                        );
                        return;
                      }
                      if (sel.isPaid || sel.status.toLowerCase() == 'completed') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Token "${sel.tokenNumber}" is already paid and completed.')),
                        );
                        return;
                      }
                      _showTakeawayFullBillDialog(context, ref, sel, takeawayNotifier, isDark);
                    },
                  ),

                  const SizedBox(height: 14),

                  if (canCreateTakeaway) ...[
                    // New Order Direct Action Button
                    OutlinedButton.icon(
                      onPressed: () => _openCreateTakeawayOrderDialog(context, ref, takeawayNotifier, isDark),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primaryRed),
                      label: const Text('+ New Takeaway Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.primaryRed)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Profile & Options: Margin bottom 0
          const CashierSidebarFooter(),
        ],
      ),
    ),

            const SizedBox(width: 18),
          ],

    // 2. Right Main Queue Content
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Header Row with Main Title & Create Order Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFD97706), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TAKEAWAY COUNTER ORDERS',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage pickup customer tokens, kitchen tickets (KOT), and counter payments',
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
                    if (canCreateTakeaway)
                      ElevatedButton.icon(
                        onPressed: () => _openCreateTakeawayOrderDialog(context, ref, takeawayNotifier, isDark),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('+ Create Takeaway Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Mini Stat Overview Row
                // Mini Stat Overview Row (Clickable to Filter)
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Active Orders',
                        value: '$activeCount',
                        icon: Icons.pending_actions_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        isSelected: _selectedFilter == 'Active',
                        onTap: () {
                          setState(() {
                            _selectedFilter = _selectedFilter == 'Active' ? 'All' : 'Active';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Ready for Pickup',
                        value: '$readyCount',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFEBF7ED),
                        isSelected: _selectedFilter == 'Ready for Pickup',
                        onTap: () {
                          setState(() {
                            _selectedFilter = _selectedFilter == 'Ready for Pickup' ? 'All' : 'Ready for Pickup';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Completed Today',
                        value: '$completedToday',
                        icon: Icons.task_alt_rounded,
                        iconColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        isSelected: _selectedFilter == 'Completed',
                        onTap: () {
                          setState(() {
                            _selectedFilter = _selectedFilter == 'Completed' ? 'All' : 'Completed';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Total Counter Orders',
                        value: '${takeawayState.orders.length}',
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.primaryRed,
                        bgColor: AppColors.primaryRed.withValues(alpha: 0.08),
                        isSelected: _selectedFilter == 'All',
                        onTap: () {
                          setState(() {
                            _selectedFilter = 'All';
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Filter Chips & Search Bar Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              filterKey: 'All',
                              label: 'All Orders',
                              count: takeawayState.orders.length,
                              activeColor: AppColors.primaryRed,
                              icon: Icons.receipt_long_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              filterKey: 'Active',
                              label: 'Active',
                              count: activeCount,
                              activeColor: const Color(0xFFD97706),
                              icon: Icons.pending_actions_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              filterKey: 'Ready for Pickup',
                              label: 'Ready for Pickup',
                              count: readyCount,
                              activeColor: const Color(0xFF16A34A),
                              icon: Icons.check_circle_outline_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              filterKey: 'Completed',
                              label: 'Completed',
                              count: completedToday,
                              activeColor: const Color(0xFF2563EB),
                              icon: Icons.task_alt_rounded,
                              isDark: isDark,
                            ),
                            if (cancelledCount > 0) ...[
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                filterKey: 'Cancelled',
                                label: 'Cancelled',
                                count: cancelledCount,
                                activeColor: const Color(0xFF6B7280),
                                icon: Icons.cancel_outlined,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          hintText: 'Search token, customer or phone...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFD97706)),
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
                            borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Orders List View
                Expanded(
                  child: filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedFilter == 'Completed'
                                    ? Icons.task_alt_rounded
                                    : (_selectedFilter == 'Ready for Pickup'
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.takeout_dining_rounded),
                                size: 52,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _selectedFilter == 'Completed'
                                    ? 'No completed takeaway orders found'
                                    : (_selectedFilter == 'Ready for Pickup'
                                        ? 'No orders currently ready for pickup'
                                        : (_searchQuery.isNotEmpty
                                            ? 'No takeaway orders found matching "$_searchQuery"'
                                            : 'No takeaway orders in this category')),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_selectedFilter != 'All' || _searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'All';
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Show All Orders'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryRed,
                                    side: const BorderSide(color: AppColors.primaryRed),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredOrders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _buildTakeawayOrderCard(context, ref, order, takeawayNotifier, isDark);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildFilterChip({
    required String filterKey,
    required String label,
    required int count,
    required Color activeColor,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppColors.textPrimary),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? iconColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: iconColor),
          ],
        ),
      ),
    );
  }


  Widget _buildTakeawayOrderCard(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    final isCompletedOrPaid = order.isPaid || order.status.toLowerCase() == 'completed';
    final isSelected = _selectedOrderId == order.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrderId = order.id;
          _activeDetailOrderId = order.id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : (isCompletedOrPaid
                    ? (isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0))
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primaryRed.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: isSelected ? 10 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Token Number, Customer & Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompletedOrPaid ? const Color(0xFF16A34A) : AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.tokenNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (order.customerName.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.customerPhone.isNotEmpty)
                          Text(
                            order.customerPhone,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (isCompletedOrPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else if (order.isBillPrinted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2563EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.lock_rounded, color: Color(0xFF2563EB), size: 13),
                        SizedBox(width: 4),
                        Text(
                          'BILL PRINTED',
                          style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          order.status.toUpperCase(),
                          style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Items summary
            Text(
              'ITEMS SUMMARY:',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              order.itemsSummary,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            // Grand Total & View Details Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'PKR ${order.grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.primaryRed),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Full Screen Takeaway Order Details View (Not in Pop-up, With Same Navbar & Left Sidebar)
  Widget _buildFullTakeawayOrderScreen(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayState takeawayState,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    final isCompletedOrPaid = order.isPaid || order.status.toLowerCase() == 'completed';
    final isLockedFromEdit = isCompletedOrPaid || order.isBillPrinted;
    final timeStr = DateFormat('hh:mm a, dd MMM yyyy').format(order.createdAt);
    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier;

    final bool canEditSelected = !isLockedFromEdit;
    final bool canSettleSelected = !isCompletedOrPaid;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.0, 18.0, 18.0, isCashier ? 0.0 : 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCashier) ...[
            // 1. Left Action Column (Sidebar - Same actions available for active takeaway order)
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Button 1: Edit & Add (Outline Purple)
                          _buildTakeawayActionPillButton(
                            title: 'Edit & Add',
                            icon: Icons.post_add_rounded,
                            color: const Color(0xFF9333EA),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: canEditSelected,
                            onTap: () {
                              if (!order.isPaid && order.status.toLowerCase() != 'completed' && !order.isBillPrinted) {
                                _openEditTakeawayOrderDialog(context, ref, order, takeawayNotifier, isDark);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cannot edit order ${order.tokenNumber} because bill is already printed or settled.')),
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 10),

                          // Button 2: Kitchen (KOT) (Outline Orange)
                          _buildTakeawayActionPillButton(
                            title: 'Kitchen (KOT)',
                            icon: Icons.soup_kitchen_rounded,
                            color: const Color(0xFFD97706),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: true,
                            onTap: () => _showTakeawayKitchenReceiptDialog(context, order, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Button 3: Customer Bill (Outline Blue)
                          _buildTakeawayActionPillButton(
                            title: 'Customer Bill',
                            icon: Icons.description_rounded,
                            color: const Color(0xFF2563EB),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: true,
                            onTap: () => _showTakeawayCustomerBillDialog(context, ref, order, takeawayNotifier, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Cancel Item in Detail
                          _buildTakeawayActionPillButton(
                            title: 'Cancel Item',
                            icon: Icons.cancel_outlined,
                            color: const Color(0xFFEF4444),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: !order.isPaid && order.status.toLowerCase() != 'cancelled',
                            onTap: () => _showCancelTakeawayItemDialog(context, ref, order, takeawayNotifier, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Button 4: Full Bill & Pay (Solid Red)
                          _buildTakeawayActionPillButton(
                            title: 'Full Bill & Pay',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFFDC2626),
                            isFilled: true,
                            isDark: isDark,
                            isEnabled: canSettleSelected,
                            onTap: () {
                              if (order.isPaid || order.status.toLowerCase() == 'completed') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Token "${order.tokenNumber}" is already paid and completed.')),
                                );
                                return;
                              }
                              _showTakeawayFullBillDialog(context, ref, order, takeawayNotifier, isDark);
                            },
                          ),

                          const SizedBox(height: 16),

                          // Return to Takeaway Queue Button
                          InkWell(
                            onTap: () => setState(() => _activeDetailOrderId = null),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primaryRed),
                                  SizedBox(width: 8),
                                  Text(
                                    'View All Takeaway Orders',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Profile & Options: Margin bottom 0
                  const CashierSidebarFooter(),
                ],
              ),
            ),

            const SizedBox(width: 18),
          ],

          // 2. Main Order Details View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Row with Order Title, Status, and Edit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TOKEN ${order.tokenNumber}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCompletedOrPaid ? const Color(0xFF16A34A) : (order.isBillPrinted ? const Color(0xFF2563EB) : AppColors.brandYellow),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCompletedOrPaid
                                      ? 'COMPLETED / PAID'
                                      : (order.isBillPrinted ? 'BILL PRINTED' : order.status.toUpperCase()),
                                  style: TextStyle(
                                    color: isCompletedOrPaid || order.isBillPrinted ? Colors.white : AppColors.deepRed,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Takeaway Order • Created: $timeStr',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Quick Action: Edit / Modify
                      if (!isLockedFromEdit)
                        ElevatedButton.icon(
                          onPressed: () => _openEditTakeawayOrderDialog(context, ref, order, takeawayNotifier, isDark),
                          icon: const Icon(Icons.post_add_rounded, size: 18),
                          label: const Text('Edit & Add Items'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Main Content View
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side of Details: Customer & Items Breakdown
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Customer Info Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.person_pin_rounded, color: AppColors.primaryRed, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order.customerName.isNotEmpty ? order.customerName : 'Walk-in Customer',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              order.customerPhone.isNotEmpty ? 'Phone: ${order.customerPhone}' : 'Phone: Not provided',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  'ORDERED ITEMS BREAKDOWN',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: _buildOrderedItemsBreakdown(order, isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Right side of Details: Financial Summary & Actions
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PAYMENT & BILL SUMMARY',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildDetailRow('Subtotal', 'PKR ${order.subtotal.toStringAsFixed(0)}', isDark),
                                      if (order.discountAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        _buildDetailRow(
                                          order.discountPercentage > 0
                                              ? 'Discount (${order.discountPercentage.toStringAsFixed(0)}%)'
                                              : 'Discount',
                                          '- PKR ${order.discountAmount.toStringAsFixed(0)}',
                                          isDark,
                                          valueColor: const Color(0xFF16A34A),
                                        ),
                                      ],
                                      if (order.taxAmount > 0) ...[
                                        const SizedBox(height: 8),
                                        _buildDetailRow('GST / Tax', '+ PKR ${order.taxAmount.toStringAsFixed(0)}', isDark),
                                      ],
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Grand Total',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 17,
                                            ),
                                          ),
                                          Text(
                                            'PKR ${order.grandTotal.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppColors.primaryRed,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // Quick Action Buttons Row in Details
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showTakeawayKitchenReceiptDialog(context, order, isDark),
                                        icon: const Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFFD97706)),
                                        label: const Text('Print KOT', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFD97706)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showTakeawayCustomerBillDialog(context, ref, order, takeawayNotifier, isDark),
                                        icon: const Icon(Icons.description_rounded, size: 16, color: Color(0xFF2563EB)),
                                        label: const Text('Customer Bill', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF2563EB)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isCompletedOrPaid) ...[
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _showTakeawayFullBillDialog(context, ref, order, takeawayNotifier, isDark),
                                    icon: const Icon(Icons.payments_rounded, size: 16),
                                    label: const Text('Full Bill & Pay (Settle Order)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryRed,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? (isDark ? Colors.white : AppColors.textPrimary),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Create Takeaway Order Dialog with Full Interactive Menu Selection (Same as Tables POS)
  void _openCreateTakeawayOrderDialog(
    BuildContext context,
    WidgetRef ref,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) {
        return _TakeawayOrderMenuDialog(isDark: isDark, ref: ref, takeawayNotifier: takeawayNotifier);
      },
    );
  }

  // Edit Existing Takeaway Order Dialog
  void _openEditTakeawayOrderDialog(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) {
        return _TakeawayOrderMenuDialog(
          isDark: isDark,
          ref: ref,
          takeawayNotifier: takeawayNotifier,
          existingOrder: order,
        );
      },
    );
  }


  // Cancel Takeaway Order Item Dialog
  void _showCancelTakeawayItemDialog(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _CancelTakeawayItemModal(
          parentContext: context,
          ref: ref,
          order: order,
          takeawayNotifier: takeawayNotifier,
          isDark: isDark,
        );
      },
    );
  }


  // Takeaway Kitchen Ticket (KOT) Dialog
  void _showTakeawayKitchenReceiptDialog(BuildContext context, TakeawayOrder order, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'TAKEAWAY KITCHEN TICKET (KOT)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'HUNGRY HOWIE\'S KITCHEN (TAKEAWAY)',
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Token: ${order.tokenNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primaryRed)),
                            Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Time: ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const Divider(height: 16),
                        const Text('ITEMS TO PREPARE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        const SizedBox(height: 6),
                        if (order.items.isNotEmpty)
                          ...order.items.map((it) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          it.isCancelled ? '• -${it.quantity} ${it.item.name}' : '• ${it.quantity}x ${it.item.name}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            decoration: it.isCancelled ? TextDecoration.lineThrough : null,
                                            decorationColor: AppColors.danger,
                                            decorationThickness: 2,
                                            color: it.isCancelled ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (it.isCancelled && it.cancelReason != null && it.cancelReason!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        'Reason: ${it.cancelReason}',
                                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.danger),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                        else
                          Text(order.itemsSummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Builder(
                    builder: (context) {
                      final kotReceipt = ReceiptData.fromTakeawayOrder(
                        order: order,
                        type: ReceiptType.kitchenKot,
                      );
                      final hasCancelledItems = order.items.any((i) => i.isCancelled);

                      return FutureBuilder<bool>(
                        future: ReceiptPrinterService.isKitchenReceiptPrinted(
                          order.id.isNotEmpty ? order.id : order.tokenNumber,
                          tokenNumber: order.tokenNumber,
                          currentItemsSignature: kotReceipt.itemsSignature,
                        ),
                        builder: (context, snapshot) {
                          final isPrinted = snapshot.data ?? false;
                          if (isPrinted) {
                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Takeaway kitchen ticket has already been printed once. Modify order or cancel items to print an updated ticket.',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.lock_clock_rounded, size: 16),
                                    label: const Text('ALREADY PRINTED (BLOCKED)'),
                                    style: ElevatedButton.styleFrom(
                                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                      disabledForegroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final isModified = hasCancelledItems;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(dialogContext);

                                // Physical Thermal Print to Attached Laptop Printer
                                await ReceiptPrinterService.printReceipt(
                                  context: context,
                                  receipt: ReceiptData.fromTakeawayOrder(
                                    order: order,
                                    type: ReceiptType.kitchenKot,
                                    isModified: isModified,
                                  ),
                                  forcePrint: isModified,
                                );
                              },
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: Text(isModified ? 'PRINT UPDATED KITCHEN TICKET' : 'PRINT KITCHEN TICKET (KOT)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isModified ? const Color(0xFFEA580C) : const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Takeaway Customer Bill Dialog with interactive discount and thermal printing
  void _showTakeawayCustomerBillDialog(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _TakeawayCustomerBillDialog(
          parentContext: context,
          ref: ref,
          order: order,
          takeawayNotifier: takeawayNotifier,
          isDark: isDark,
        );
      },
    );
  }

  // Takeaway Full Bill / Cash Payment Calculator Dialog
  void _showTakeawayFullBillDialog(
    BuildContext context,
    WidgetRef ref,
    TakeawayOrder order,
    TakeawayNotifier takeawayNotifier,
    bool isDark,
  ) {
    if (order.isPaid) {
      _showTakeawayFinalPaidReceiptDialog(context, order, order.grandTotal, 0.0, isDark);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _TakeawayFullBillCalculatorDialog(
          parentContext: context,
          ref: ref,
          order: order,
          takeawayNotifier: takeawayNotifier,
          isDark: isDark,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Takeaway Customer Pre-Bill Dialog with Reactive Discount Controls
// ---------------------------------------------------------------------------
class _TakeawayCustomerBillDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final TakeawayOrder order;
  final TakeawayNotifier takeawayNotifier;
  final bool isDark;

  const _TakeawayCustomerBillDialog({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.takeawayNotifier,
    required this.isDark,
  });

  @override
  State<_TakeawayCustomerBillDialog> createState() => _TakeawayCustomerBillDialogState();
}

class _TakeawayCustomerBillDialogState extends State<_TakeawayCustomerBillDialog> {
  late TextEditingController _discountController;
  double _discountPercentage = 0.0;
  bool _isDiscountAmountMode = false;
  double _customDiscountAmount = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.discountPercentage > 0) {
      _discountPercentage = widget.order.discountPercentage;
      _isDiscountAmountMode = false;
      _discountController = TextEditingController(
        text: _discountPercentage.toStringAsFixed(_discountPercentage.truncateToDouble() == _discountPercentage ? 0 : 1),
      );
    } else if (widget.order.discountAmount > 0) {
      _customDiscountAmount = widget.order.discountAmount;
      _isDiscountAmountMode = true;
      _discountController = TextEditingController(
        text: _customDiscountAmount.toStringAsFixed(0),
      );
    } else {
      _discountController = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  void _setDiscountPreset(double pct) {
    setState(() {
      _isDiscountAmountMode = false;
      _discountPercentage = pct;
      _discountController.text = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.order.subtotal;
    final discountAmount = _isDiscountAmountMode
        ? _customDiscountAmount.clamp(0.0, subtotal)
        : (subtotal * (_discountPercentage / 100.0)).clamp(0.0, subtotal);

    final effectiveDiscountPct = subtotal > 0
        ? (_isDiscountAmountMode ? (discountAmount / subtotal) * 100.0 : _discountPercentage)
        : 0.0;

    final grandTotal = (subtotal - discountAmount + widget.order.taxAmount).clamp(0.0, double.infinity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TAKEAWAY CUSTOMER BILL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Token: ${widget.order.tokenNumber} • Pre-Bill Calculation',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DISCOUNT INPUT & SELECTOR SECTION
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.discount_rounded, color: Color(0xFF16A34A), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'APPLY DISCOUNT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: widget.isDark ? Colors.white : AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // Discount Mode Switcher (% vs PKR)
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isDiscountAmountMode = false;
                                          _discountPercentage = subtotal > 0 ? (_customDiscountAmount / subtotal) * 100.0 : 0.0;
                                          _discountController.text = _discountPercentage.toStringAsFixed(_discountPercentage.truncateToDouble() == _discountPercentage ? 0 : 1);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: !_isDiscountAmountMode ? const Color(0xFF16A34A) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '% Percent',
                                          style: TextStyle(
                                            color: !_isDiscountAmountMode ? Colors.white : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isDiscountAmountMode = true;
                                          _customDiscountAmount = (subtotal * (_discountPercentage / 100.0));
                                          _discountController.text = _customDiscountAmount.toStringAsFixed(0);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _isDiscountAmountMode ? const Color(0xFF16A34A) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'PKR Flat',
                                          style: TextStyle(
                                            color: _isDiscountAmountMode ? Colors.white : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Quick Preset Chips for Discount
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildDiscountPresetChip('0% (None)', 0.0),
                              _buildDiscountPresetChip('5%', 5.0),
                              _buildDiscountPresetChip('10%', 10.0),
                              _buildDiscountPresetChip('15%', 15.0),
                              _buildDiscountPresetChip('20%', 20.0),
                              _buildDiscountPresetChip('50%', 50.0),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Discount Input TextField
                          TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              color: widget.isDark ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: _isDiscountAmountMode ? 'Discount Amount (PKR)' : 'Discount Rate (%)',
                              labelStyle: const TextStyle(fontSize: 12),
                              hintText: _isDiscountAmountMode ? 'Enter flat discount amount' : 'Enter discount percentage',
                              prefixText: _isDiscountAmountMode ? 'PKR ' : null,
                              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                              suffixText: _isDiscountAmountMode ? null : '%',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                final parsed = double.tryParse(val) ?? 0.0;
                                if (_isDiscountAmountMode) {
                                  _customDiscountAmount = parsed;
                                  _discountPercentage = subtotal > 0 ? (parsed / subtotal) * 100.0 : 0.0;
                                } else {
                                  _discountPercentage = parsed;
                                  _customDiscountAmount = subtotal * (parsed / 100.0);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Customer Bill Invoice Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'HUNGRY HOWIE\'S PIZZA',
                              style: TextStyle(
                                color: widget.isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Center(
                            child: Text(
                              'Takeaway Customer Pre-Bill',
                              style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Token: ${widget.order.tokenNumber}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed),
                              ),
                              Text(
                                'Customer: ${widget.order.customerName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Text(
                            'Items: ${widget.order.itemsSummary}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),

                          // Subtotal
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(fontSize: 12)),
                              Text(
                                'PKR ${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),

                          // Discount (Live)
                          if (discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discount (${effectiveDiscountPct.toStringAsFixed(0)}%):',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '-PKR ${discountAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ],

                          const Divider(height: 16),

                          // Grand Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL BILL DUE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              Text(
                                'PKR ${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Save Discount & Print Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);

                                // 1. Save discount in backend database
                                try {
                                  await widget.takeawayNotifier.updateOrderDiscount(
                                    widget.order.id,
                                    discountPercentage: effectiveDiscountPct,
                                    discountAmount: discountAmount,
                                  );
                                } catch (e) {
                                  debugPrint('⚠️ Error saving takeaway discount to DB: $e');
                                }

                                if (!context.mounted) return;
                                Navigator.pop(context);

                                // 2. Updated TakeawayOrder representation for thermal printing
                                final updatedOrder = widget.order.copyWith(
                                  discountPercentage: effectiveDiscountPct,
                                  discountAmount: discountAmount,
                                  grandTotal: grandTotal,
                                );

                                // 3. Thermal Print Customer Pre-Bill
                                await ReceiptPrinterService.printReceipt(
                                  context: widget.parentContext,
                                  receipt: ReceiptData.fromTakeawayOrder(
                                    order: updatedOrder,
                                    type: ReceiptType.preBill,
                                  ),
                                );

                                if (widget.parentContext.mounted) {
                                  ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text('Discount of PKR ${discountAmount.toStringAsFixed(0)} applied & saved to Token ${widget.order.tokenNumber}!'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              },
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(
                          _isSaving ? 'SAVING DISCOUNT & PRINTING...' : 'SAVE DISCOUNT & PRINT PRE-BILL',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountPresetChip(String label, double pct) {
    final isSelected = !_isDiscountAmountMode && (_discountPercentage - pct).abs() < 0.1;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (widget.isDark ? Colors.white : AppColors.textPrimary),
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isSelected ? const Color(0xFF16A34A) : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      onSelected: (_) => _setDiscountPreset(pct),
    );
  }
}

// ---------------------------------------------------------------------------
// Takeaway Full Bill & Cash Calculator Dialog
// ---------------------------------------------------------------------------
class _TakeawayFullBillCalculatorDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final TakeawayOrder order;
  final TakeawayNotifier takeawayNotifier;
  final bool isDark;

  const _TakeawayFullBillCalculatorDialog({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.takeawayNotifier,
    required this.isDark,
  });

  @override
  State<_TakeawayFullBillCalculatorDialog> createState() => _TakeawayFullBillCalculatorDialogState();
}

class _TakeawayFullBillCalculatorDialogState extends State<_TakeawayFullBillCalculatorDialog> {
  final TextEditingController _cashController = TextEditingController();
  late TextEditingController _discountController;
  double _cashGiven = 5000.0;
  double _discountPercentage = 0.0;
  bool _isDiscountAmountMode = false;
  double _customDiscountAmount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.order.discountPercentage > 0) {
      _discountPercentage = widget.order.discountPercentage;
      _isDiscountAmountMode = false;
      _discountController = TextEditingController(
        text: _discountPercentage.toStringAsFixed(_discountPercentage.truncateToDouble() == _discountPercentage ? 0 : 1),
      );
    } else if (widget.order.discountAmount > 0) {
      _customDiscountAmount = widget.order.discountAmount;
      _isDiscountAmountMode = true;
      _discountController = TextEditingController(
        text: _customDiscountAmount.toStringAsFixed(0),
      );
    } else {
      _discountController = TextEditingController(text: '0');
    }

    final defaultAmount = widget.order.grandTotal > 5000 ? widget.order.grandTotal : 5000.0;
    _cashGiven = defaultAmount;
    _cashController.text = defaultAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _setCash(double amount) {
    setState(() {
      _cashGiven = amount;
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  void _setDiscountPreset(double pct) {
    setState(() {
      _isDiscountAmountMode = false;
      _discountPercentage = pct;
      _discountController.text = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.order.subtotal;
    final discountAmount = _isDiscountAmountMode
        ? _customDiscountAmount.clamp(0.0, subtotal)
        : (subtotal * (_discountPercentage / 100.0)).clamp(0.0, subtotal);

    final effectiveDiscountPct = subtotal > 0
        ? (_isDiscountAmountMode ? (discountAmount / subtotal) * 100.0 : _discountPercentage)
        : 0.0;

    final netTotal = (subtotal - discountAmount + widget.order.taxAmount).clamp(0.0, double.infinity);
    final changeReturn = _cashGiven - netTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.calculate_rounded, color: Color(0xFF16A34A), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'FULL BILL & CASH CALCULATOR',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // 1. DISCOUNT ADJUSTMENT SECTION
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.discount_rounded, color: Color(0xFF16A34A), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'DISCOUNT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: widget.isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        // Discount Mode Switcher
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isDiscountAmountMode = false;
                                    _discountPercentage = subtotal > 0 ? (_customDiscountAmount / subtotal) * 100.0 : 0.0;
                                    _discountController.text = _discountPercentage.toStringAsFixed(_discountPercentage.truncateToDouble() == _discountPercentage ? 0 : 1);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: !_isDiscountAmountMode ? const Color(0xFF16A34A) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '%',
                                    style: TextStyle(
                                      color: !_isDiscountAmountMode ? Colors.white : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isDiscountAmountMode = true;
                                    _customDiscountAmount = (subtotal * (_discountPercentage / 100.0));
                                    _discountController.text = _customDiscountAmount.toStringAsFixed(0);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isDiscountAmountMode ? const Color(0xFF16A34A) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'PKR',
                                    style: TextStyle(
                                      color: _isDiscountAmountMode ? Colors.white : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Preset Chips
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildDiscountPresetChip('0%', 0.0),
                        _buildDiscountPresetChip('5%', 5.0),
                        _buildDiscountPresetChip('10%', 10.0),
                        _buildDiscountPresetChip('15%', 15.0),
                        _buildDiscountPresetChip('20%', 20.0),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Discount Input TextField
                    TextField(
                      controller: _discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: _isDiscountAmountMode ? 'Discount (PKR)' : 'Discount (%)',
                        labelStyle: const TextStyle(fontSize: 11),
                        prefixText: _isDiscountAmountMode ? 'PKR ' : null,
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 13),
                        suffixText: _isDiscountAmountMode ? null : '%',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          final parsed = double.tryParse(val) ?? 0.0;
                          if (_isDiscountAmountMode) {
                            _customDiscountAmount = parsed;
                            _discountPercentage = subtotal > 0 ? (parsed / subtotal) * 100.0 : 0.0;
                          } else {
                            _discountPercentage = parsed;
                            _customDiscountAmount = subtotal * (parsed / 100.0);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Summary Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 12)),
                        Text('PKR ${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    if (discountAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount (${effectiveDiscountPct.toStringAsFixed(0)}%):',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '-PKR ${discountAmount.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PAYABLE TOTAL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        Text(
                          'PKR ${netTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // CASH CALCULATOR INPUT
              Text(
                'CASH CALCULATOR & TENDERED AMOUNT',
                style: TextStyle(
                  color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Quick Cash Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickCashChip('Exact', netTotal),
                  _buildQuickCashChip('PKR 1000', 1000),
                  _buildQuickCashChip('PKR 2000', 2000),
                  _buildQuickCashChip('PKR 5000', 5000),
                  _buildQuickCashChip('PKR 10000', 10000),
                ],
              ),

              const SizedBox(height: 12),

              // Cash Input Field
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: 'Customer Cash Received (PKR)',
                  prefixText: 'PKR ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed, fontSize: 16),
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _cashGiven = double.tryParse(val) ?? 0.0;
                  });
                },
              ),

              const SizedBox(height: 12),

              // Live Change / Remaining Result Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: changeReturn >= 0 ? const Color(0xFFEBF7ED) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: changeReturn >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          changeReturn >= 0 ? Icons.price_check_rounded : Icons.warning_amber_rounded,
                          color: changeReturn >= 0 ? const Color(0xFF16A34A) : AppColors.danger,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              changeReturn >= 0 ? 'RETURN CHANGE TO CUSTOMER:' : 'REMAINING BALANCE SHORT:',
                              style: TextStyle(
                                color: changeReturn >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              changeReturn >= 0
                                  ? 'PKR ${_cashGiven.toStringAsFixed(0)} - PKR ${netTotal.toStringAsFixed(0)}'
                                  : 'Need more cash from customer',
                              style: TextStyle(
                                color: changeReturn >= 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'PKR ${changeReturn >= 0 ? changeReturn.toStringAsFixed(0) : (-changeReturn).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: changeReturn >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons: Mark as Tender & Pay Now
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final updatedOrder = widget.order.copyWith(
                          discountPercentage: effectiveDiscountPct,
                          discountAmount: discountAmount,
                          grandTotal: netTotal,
                        );
                        Navigator.pop(context); // Close calculator dialog
                        showDialog(
                          context: widget.parentContext,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (tenderContext) => _TakeawayPaymentTenderDialog(
                            parentContext: widget.parentContext,
                            ref: widget.ref,
                            order: updatedOrder,
                            takeawayNotifier: widget.takeawayNotifier,
                            isDark: widget.isDark,
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                      label: const Text('Mark as Tender'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updatedOrder = widget.order.copyWith(
                          discountPercentage: effectiveDiscountPct,
                          discountAmount: discountAmount,
                          grandTotal: netTotal,
                        );

                        // Mark order paid with discount persisted to DB
                        await widget.takeawayNotifier.markOrderPaid(
                          widget.order.id,
                          discountPercentage: effectiveDiscountPct,
                          discountAmount: discountAmount,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);

                        // Show Final Paid Receipt Dialog with Cash & Change Details
                        _showTakeawayFinalPaidReceiptDialog(
                          widget.parentContext,
                          updatedOrder,
                          _cashGiven,
                          changeReturn >= 0 ? changeReturn : 0.0,
                          widget.isDark,
                          takeawayNotifier: widget.takeawayNotifier,
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountPresetChip(String label, double pct) {
    final isSelected = !_isDiscountAmountMode && (_discountPercentage - pct).abs() < 0.1;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (widget.isDark ? Colors.white : AppColors.textPrimary),
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      onSelected: (_) => _setDiscountPreset(pct),
    );
  }

  Widget _buildQuickCashChip(String label, double amount) {
    final isSelected = (_cashGiven - amount).abs() < 1;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (widget.isDark ? Colors.white : AppColors.textPrimary),
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      onSelected: (_) => _setCash(amount),
    );
  }
}

// ---------------------------------------------------------------------------
// Takeaway Payment Tender / Multi-Tender Information Dialog
// ---------------------------------------------------------------------------
class _TakeawayPaymentTenderDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final TakeawayOrder order;
  final TakeawayNotifier takeawayNotifier;
  final bool isDark;

  const _TakeawayPaymentTenderDialog({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.takeawayNotifier,
    required this.isDark,
  });

  @override
  State<_TakeawayPaymentTenderDialog> createState() => _TakeawayPaymentTenderDialogState();
}

class _TakeawayPaymentTenderDialogState extends State<_TakeawayPaymentTenderDialog> {
  bool _foreignCurrency = false;
  late TextEditingController _cashController;
  late TextEditingController _creditController;

  // Machine / Bank Rows
  late TextEditingController _bankAmountController;
  String _bankCardType = 'Bank Transfer';
  final TextEditingController _bankCardNoController = TextEditingController();
  final TextEditingController _bankHolderController = TextEditingController();

  late TextEditingController _easyPaisaAmountController;
  String _easyPaisaType = 'EasyPaisa';
  final TextEditingController _easyPaisaCardNoController = TextEditingController();
  final TextEditingController _easyPaisaHolderController = TextEditingController();

  late TextEditingController _jazzCashAmountController;
  String _jazzCashType = 'JazzCash';
  final TextEditingController _jazzCashCardNoController = TextEditingController();
  final TextEditingController _jazzCashHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: '0.00');
    _creditController = TextEditingController(text: '0.00');
    _bankAmountController = TextEditingController(text: '0.00');
    _easyPaisaAmountController = TextEditingController(text: '0.00');
    _jazzCashAmountController = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _cashController.dispose();
    _creditController.dispose();
    _bankAmountController.dispose();
    _bankCardNoController.dispose();
    _bankHolderController.dispose();
    _easyPaisaAmountController.dispose();
    _easyPaisaCardNoController.dispose();
    _easyPaisaHolderController.dispose();
    _jazzCashAmountController.dispose();
    _jazzCashCardNoController.dispose();
    _jazzCashHolderController.dispose();
    super.dispose();
  }

  double get _totalPayment {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final bank = double.tryParse(_bankAmountController.text) ?? 0.0;
    final easyPaisa = double.tryParse(_easyPaisaAmountController.text) ?? 0.0;
    final jazzCash = double.tryParse(_jazzCashAmountController.text) ?? 0.0;
    return cash + credit + bank + easyPaisa + jazzCash;
  }

  double get _change {
    return _totalPayment - widget.order.grandTotal;
  }

  void _completePayment({bool printReceipt = true}) {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final bank = double.tryParse(_bankAmountController.text) ?? 0.0;
    final easyPaisa = double.tryParse(_easyPaisaAmountController.text) ?? 0.0;
    final jazzCash = double.tryParse(_jazzCashAmountController.text) ?? 0.0;

    final List<Map<String, dynamic>> paymentsList = [];
    if (cash > 0) {
      paymentsList.add({
        'payment_method': 'cash',
        'amount': cash > widget.order.grandTotal ? widget.order.grandTotal : cash,
        'tendered_amount': cash,
        'change_returned': _change > 0 ? _change : 0.0,
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }
    if (credit > 0) {
      paymentsList.add({
        'payment_method': 'card',
        'amount': credit,
        'tendered_amount': credit,
        'change_returned': 0.0,
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }
    if (bank > 0) {
      paymentsList.add({
        'payment_method': 'bank_transfer',
        'amount': bank,
        'tendered_amount': bank,
        'change_returned': 0.0,
        'card_last_four': _bankCardNoController.text.isNotEmpty ? _bankCardNoController.text : null,
        'bank_name': _bankHolderController.text.isNotEmpty ? _bankHolderController.text : 'Bank Transfer',
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }
    if (easyPaisa > 0) {
      paymentsList.add({
        'payment_method': 'easypaisa',
        'amount': easyPaisa,
        'tendered_amount': easyPaisa,
        'change_returned': 0.0,
        'transaction_reference': _easyPaisaCardNoController.text.isNotEmpty ? _easyPaisaCardNoController.text : null,
        'bank_name': 'EasyPaisa',
        'notes': _easyPaisaHolderController.text.isNotEmpty ? _easyPaisaHolderController.text : null,
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }
    if (jazzCash > 0) {
      paymentsList.add({
        'payment_method': 'jazzcash',
        'amount': jazzCash,
        'tendered_amount': jazzCash,
        'change_returned': 0.0,
        'transaction_reference': _jazzCashCardNoController.text.isNotEmpty ? _jazzCashCardNoController.text : null,
        'bank_name': 'JazzCash',
        'notes': _jazzCashHolderController.text.isNotEmpty ? _jazzCashHolderController.text : null,
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }
    if (paymentsList.isEmpty) {
      paymentsList.add({
        'payment_method': 'cash',
        'amount': widget.order.grandTotal,
        'tendered_amount': widget.order.grandTotal,
        'change_returned': 0.0,
        'payment_status': 'COMPLETED',
        'received_by': 'Cashier',
      });
    }

    String primaryMethod = 'Cash';
    if (paymentsList.length > 1) {
      primaryMethod = 'Split';
    } else if (credit > 0) {
      primaryMethod = 'Card';
    } else if (bank > 0) {
      primaryMethod = 'Bank Transfer';
    } else if (easyPaisa > 0) {
      primaryMethod = 'EasyPaisa';
    } else if (jazzCash > 0) {
      primaryMethod = 'JazzCash';
    }

    widget.takeawayNotifier.markOrderPaid(
      widget.order.id,
      paymentMethod: primaryMethod,
      payments: paymentsList,
    );
    Navigator.pop(context);

    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text('Payment of PKR ${_totalPayment.toStringAsFixed(0)} tendered for Token ${widget.order.tokenNumber} (${widget.order.customerName})! Order is completed.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );

    if (printReceipt) {
      _showTakeawayFinalPaidReceiptDialog(
        widget.parentContext,
        widget.order,
        _totalPayment > 0 ? _totalPayment : widget.order.grandTotal,
        _change > 0 ? _change : 0.0,
        widget.isDark,
        takeawayNotifier: widget.takeawayNotifier,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final totalPayment = _totalPayment;
    final change = _change;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE8F1EC),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Window Title Bar (Payment Tender)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD3E4DB),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Tender - Takeaway (${widget.order.tokenNumber})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Section Header Bar (Payment Information)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: isDark ? const Color(0xFF334155) : const Color(0xFFB5D7C7),
              child: const Text(
                'Payment Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF064E3B),
                ),
              ),
            ),

            // 3. Main Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Form: Bill Amount & Foreign Currency
                    Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Bill Amount',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                            alignment: Alignment.centerRight,
                            child: Text(
                              widget.order.grandTotal.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Row(
                          children: [
                            Checkbox(
                              value: _foreignCurrency,
                              onChanged: (val) => setState(() => _foreignCurrency = val ?? false),
                              activeColor: const Color(0xFF16A34A),
                            ),
                            const Text('Foreign Currency', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cash Payment & Credit Payment Inputs
                    Row(
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Cash Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: _buildNumericField(_cashController, isDark, onExact: () {
                            setState(() => _cashController.text = widget.order.grandTotal.toStringAsFixed(2));
                          }),
                        ),
                        const SizedBox(width: 20),
                        const SizedBox(
                          width: 110,
                          child: Text(
                            'Credit Payment',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: _buildNumericField(_creditController, isDark, onExact: () {
                            setState(() => _creditController.text = widget.order.grandTotal.toStringAsFixed(2));
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Machine / Bank Tender Grid
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFD6E9DF),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Machine/Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Card Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 2, child: Text('Card No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                SizedBox(width: 8),
                                Expanded(flex: 3, child: Text('Card Holder Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                              ],
                            ),
                          ),

                          // Table Rows
                          _buildBankRow('Bank Transfer', _bankAmountController, _bankCardType, (v) => setState(() => _bankCardType = v!), _bankCardNoController, _bankHolderController, isDark),
                          const Divider(height: 1),
                          _buildBankRow('EASY PAISA', _easyPaisaAmountController, _easyPaisaType, (v) => setState(() => _easyPaisaType = v!), _easyPaisaCardNoController, _easyPaisaHolderController, isDark),
                          const Divider(height: 1),
                          _buildBankRow('JAZZ CASH', _jazzCashAmountController, _jazzCashType, (v) => setState(() => _jazzCashType = v!), _jazzCashCardNoController, _jazzCashHolderController, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Summary & Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD3E4DB),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFB5D7C7))),
              ),
              child: Row(
                children: [
                  // Total Payment
                  const Text('Total Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      totalPayment.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Change
                  const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      change.toStringAsFixed(2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: change >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Quick Keypad Icon Button
                  IconButton(
                    tooltip: 'Exact Amount',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.keyboard_alt_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () {
                      setState(() {
                        _cashController.text = widget.order.grandTotal.toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(width: 6),

                  // Save Tender Button
                  ElevatedButton.icon(
                    onPressed: () => _completePayment(printReceipt: false),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('SAVE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Print & Finish Button
                  ElevatedButton.icon(
                    onPressed: () => _completePayment(printReceipt: true),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('PRINT & FINISH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericField(TextEditingController controller, bool isDark, {VoidCallback? onExact}) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (onExact != null) ...[
          const SizedBox(width: 4),
          InkWell(
            onTap: onExact,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
              ),
              child: const Text('Max', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBankRow(
    String title,
    TextEditingController amountCtrl,
    String cardType,
    ValueChanged<String?> onTypeChanged,
    TextEditingController cardNoCtrl,
    TextEditingController holderCtrl,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          // Machine/Bank Title
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Amount (Yellow highlight background matching POS)
          Expanded(
            flex: 2,
            child: TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                filled: true,
                fillColor: const Color(0xFFFEF08A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFFACC15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFFEAB308), width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),

          // Card Type / Service Type
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: cardType,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  items: {cardType, 'Card', 'Online QR', 'Other'}
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: onTypeChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Card No / Ref No
          Expanded(
            flex: 2,
            child: TextField(
              controller: cardNoCtrl,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                hintText: 'Card/Txn#',
                hintStyle: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Card Holder Name
          Expanded(
            flex: 3,
            child: TextField(
              controller: holderCtrl,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                hintText: 'Holder Name',
                hintStyle: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Takeaway Final Paid Receipt Dialog
// ---------------------------------------------------------------------------
void _showTakeawayFinalPaidReceiptDialog(
  BuildContext context,
  TakeawayOrder order,
  double cashGiven,
  double changeReturned,
  bool isDark, {
  TakeawayNotifier? takeawayNotifier,
}) {
  // Parse items from summary string
  final rawParts = order.itemsSummary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'FULL BILL RECEIPT',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Receipt Body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Restaurant Name
                      Text(
                        "HUNGRY HOWIES",
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'PAID RECEIPT • Takeaway • Thank you!',
                        style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),

                      // Order Info
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Token:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary)),
                            Text(order.tokenNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Customer:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary)),
                            Text(order.customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      if (order.customerPhone.isNotEmpty && order.customerPhone != 'N/A')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Phone:', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary)),
                              Text(order.customerPhone, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Items List
                      if (rawParts.isNotEmpty)
                        ...rawParts.map((itemStr) {
                          // Check if item starts with quantity like "1x " or "2x "
                          final regex = RegExp(r'^(\d+)x\s+(.+)$');
                          final match = regex.firstMatch(itemStr);
                          final qty = match != null ? match.group(1)! : '1';
                          final itemName = match != null ? match.group(2)! : itemStr;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$qty×',
                                    style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(order.itemsSummary, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textPrimary, fontSize: 12)),
                        ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 6),

                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:', style: TextStyle(fontSize: 12)),
                          Text('PKR ${order.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${order.discountPercentage > 0 ? "${order.discountPercentage.toStringAsFixed(0)}%" : "Flat"}):',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '-PKR ${order.discountAmount.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 12),

                      // Total Bill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(
                            'PKR ${order.grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                        ],
                      ),

                      // Cash Returned — only show if > 0
                      if (changeReturned > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF7ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CASH RETURNED:',
                                style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                              Text(
                                'PKR ${changeReturned.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action: Print Receipt & Finish
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogContext);

                      // Ensure order is marked paid and completed in DB and state
                      if (takeawayNotifier != null) {
                        try {
                          await takeawayNotifier.markOrderPaid(
                            order.id,
                            discountPercentage: order.discountPercentage,
                            discountAmount: order.discountAmount,
                          );
                        } catch (_) {}
                      }

                      // Physical Thermal Print to Attached Laptop Printer
                      if (context.mounted) {
                        await ReceiptPrinterService.printReceipt(
                          context: context,
                          receipt: ReceiptData.fromTakeawayOrder(
                            order: order,
                            type: ReceiptType.customerReceipt,
                            paymentMethod: 'CASH',
                            tenderedAmount: cashGiven > 0 ? cashGiven : order.grandTotal,
                            changeReturned: changeReturned,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('PRINT RECEIPT & FINISH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TakeawayMenuItem {
  final String name;
  final String category;
  final double price;
  final String imagePath;

  const _TakeawayMenuItem({
    required this.name,
    required this.category,
    required this.price,
    required this.imagePath,
  });
}

class _TakeawayOrderItem {
  final _TakeawayMenuItem item;
  int quantity;
  final int initialOrderedQty;

  _TakeawayOrderItem({
    required this.item,
    this.quantity = 1,
    this.initialOrderedQty = 0,
  });

  bool get isExistingOrderedItem => initialOrderedQty > 0;
  double get totalPrice => item.price * quantity;
}

class _TakeawayOrderMenuDialog extends StatefulWidget {
  final bool isDark;
  final WidgetRef ref;
  final TakeawayNotifier takeawayNotifier;
  final TakeawayOrder? existingOrder;

  const _TakeawayOrderMenuDialog({
    required this.isDark,
    required this.ref,
    required this.takeawayNotifier,
    this.existingOrder,
  });

  @override
  State<_TakeawayOrderMenuDialog> createState() => _TakeawayOrderMenuDialogState();
}

class _TakeawayOrderMenuDialogState extends State<_TakeawayOrderMenuDialog> {
  final TextEditingController _menuSearchController = TextEditingController();
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;

  String _selectedCategory = 'All';
  String _menuQuery = '';
  final List<_TakeawayOrderItem> _cartItems = [];

  final List<_TakeawayMenuItem> _menuDatabase = const [
    // Exclusive Deals & Combos
    _TakeawayMenuItem(name: "EXCLUSIVE DEALS (Pizza+Biryani+Panini+Shakes+Bottle)", category: 'Deals', price: 2499, imagePath: 'assets/images/image.jpg'),
    _TakeawayMenuItem(name: "Family Feast Combo Deal (2 Family Pizzas + 4 Broast + Loaded Fries + 1.5L Coke)", category: 'Deals', price: 3299, imagePath: 'assets/images/Special.png'),
    _TakeawayMenuItem(name: "Duo Craver Pack (2 Gourmet Burgers + Garlic Fries + 2 Drinks)", category: 'Deals', price: 1649, imagePath: 'assets/images/beef_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Midnight Craving Deal (1 Large Pizza + Cheesy Panini + 2 Drinks)", category: 'Deals', price: 1999, imagePath: 'assets/images/Pizza.png'),
    _TakeawayMenuItem(name: "Student Saver Deal (1 Zinger Burger + Plain Fries + 1 Drink)", category: 'Deals', price: 749, imagePath: 'assets/images/chicken_burger_hero.jpg'),

    // Pizzas
    _TakeawayMenuItem(name: "Classic Fajita Pizza (Small)", category: 'Pizza', price: 849, imagePath: 'assets/images/Fajita.png'),
    _TakeawayMenuItem(name: "Classic Fajita Pizza (Medium)", category: 'Pizza', price: 1449, imagePath: 'assets/images/Fajita.png'),
    _TakeawayMenuItem(name: "Classic Fajita Pizza (Large)", category: 'Pizza', price: 1749, imagePath: 'assets/images/Fajita.png'),
    _TakeawayMenuItem(name: "Classic Fajita Pizza (Family)", category: 'Pizza', price: 2349, imagePath: 'assets/images/Fajita.png'),
    _TakeawayMenuItem(name: "Modern Crown Crust (Medium)", category: 'Pizza', price: 1549, imagePath: 'assets/images/Modern.png'),
    _TakeawayMenuItem(name: "Modern Crown Crust (Large)", category: 'Pizza', price: 1999, imagePath: 'assets/images/Modern.png'),
    _TakeawayMenuItem(name: "Special Arabic Crispy (Medium)", category: 'Pizza', price: 1699, imagePath: 'assets/images/Special.png'),
    _TakeawayMenuItem(name: "Special Hungry Cheese Gold (Large)", category: 'Pizza', price: 2199, imagePath: 'assets/images/Special.png'),

    // Steaks
    _TakeawayMenuItem(name: "Tarragon Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    _TakeawayMenuItem(name: "Mushroom Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    _TakeawayMenuItem(name: "Twin Chicken Steak", category: 'Steak', price: 1599, imagePath: 'assets/images/chicken_steak.png'),
    _TakeawayMenuItem(name: "Smoked BBQ Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    _TakeawayMenuItem(name: "Hot Shot Jalapeno Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),

    // Burgers
    _TakeawayMenuItem(name: "Beef Cheese Stuff Burger", category: 'Burger', price: 1349, imagePath: 'assets/images/beef_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Hungry Stacker Beef Burger", category: 'Burger', price: 1349, imagePath: 'assets/images/beef_burger_hero.jpg'),
    _TakeawayMenuItem(name: "The Smashroom Beef Burger", category: 'Burger', price: 1099, imagePath: 'assets/images/beef_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Hungry Special Chicken Burger", category: 'Burger', price: 899, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Crispy BBQ Chicken Burger", category: 'Burger', price: 999, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Zinger Burger", category: 'Burger', price: 499, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    _TakeawayMenuItem(name: "Student Burger", category: 'Burger', price: 450, imagePath: 'assets/images/chicken_burger_hero.jpg'),

    // Brost
    _TakeawayMenuItem(name: "Half Dajjaj Broast (with Fries)", category: 'Brost', price: 1250, imagePath: 'assets/images/broast_hero.jpg'),
    _TakeawayMenuItem(name: "Family Dajjaj Broast (with Fries)", category: 'Brost', price: 2400, imagePath: 'assets/images/broast_hero.jpg'),

    // Pasta
    _TakeawayMenuItem(name: "Chicken Alfredo Pasta", category: 'Pasta', price: 999, imagePath: 'assets/images/pasta_hero.jpg'),
    _TakeawayMenuItem(name: "Penne Arrabiata Pasta", category: 'Pasta', price: 999, imagePath: 'assets/images/penne.png'),
    _TakeawayMenuItem(name: "Hungry Parmesan Pasta", category: 'Pasta', price: 1099, imagePath: 'assets/images/Permission.png'),

    // Panini
    _TakeawayMenuItem(name: "Cheesy Panini Sandwich", category: 'Panini', price: 1099, imagePath: 'assets/images/panini_hero.jpg'),
    _TakeawayMenuItem(name: "Hungry Club Panini", category: 'Panini', price: 849, imagePath: 'assets/images/panini_hero.jpg'),
    _TakeawayMenuItem(name: "Special BBQ Panini", category: 'Panini', price: 849, imagePath: 'assets/images/panini_hero.jpg'),

    // Appetizer
    _TakeawayMenuItem(name: "Chicken Nuggets (6pcs with Fries)", category: 'Appetizer', price: 399, imagePath: 'assets/images/Nuggets.png'),
    _TakeawayMenuItem(name: "Crispy Chicken Wings (6pcs)", category: 'Appetizer', price: 399, imagePath: 'assets/images/Wings.png'),
    _TakeawayMenuItem(name: "Peri-Peri Wings (6pcs)", category: 'Appetizer', price: 499, imagePath: 'assets/images/peri.png'),
    _TakeawayMenuItem(name: "Honey BBQ Wings (6pcs)", category: 'Appetizer', price: 499, imagePath: 'assets/images/Honey.png'),

    // Fries
    _TakeawayMenuItem(name: "Hungry Loaded Fries", category: 'Fries', price: 749, imagePath: 'assets/images/Loaded.png'),
    _TakeawayMenuItem(name: "Honey Mustard Fries", category: 'Fries', price: 449, imagePath: 'assets/images/Mustard.png'),
    _TakeawayMenuItem(name: "Garlic Mayo Fries", category: 'Fries', price: 499, imagePath: 'assets/images/Garlic.png'),
    _TakeawayMenuItem(name: "Masala Fries", category: 'Fries', price: 299, imagePath: 'assets/images/Masala.png'),
    _TakeawayMenuItem(name: "Plain Salted Fries", category: 'Fries', price: 279, imagePath: 'assets/images/Simple.png'),

    // Drinks / Soft Drinks
    _TakeawayMenuItem(name: "Fresh Lime Drink", category: 'Drinks', price: 250, imagePath: 'assets/images/FreshLime.png'),
    _TakeawayMenuItem(name: "Mint Margarita", category: 'Drinks', price: 300, imagePath: 'assets/images/Mint.png'),
    _TakeawayMenuItem(name: "NR Coke", category: 'Drinks', price: 100, imagePath: 'assets/images/Coke.png'),
    _TakeawayMenuItem(name: "NR Sprite", category: 'Drinks', price: 100, imagePath: 'assets/images/Sprite.png'),
    _TakeawayMenuItem(name: "Coke Tin Pack", category: 'Drinks', price: 160, imagePath: 'assets/images/CokeTin.png'),
    _TakeawayMenuItem(name: "Mineral Water", category: 'Drinks', price: 80, imagePath: 'assets/images/Mineral.png'),

    // Toppings
    _TakeawayMenuItem(name: "Extra Cheese Topping", category: 'Topping', price: 200, imagePath: 'assets/images/Cheese.png'),
    _TakeawayMenuItem(name: "Extra BBQ Sauce", category: 'Topping', price: 150, imagePath: 'assets/images/BBqSauce.png'),
    _TakeawayMenuItem(name: "Extra Garlic Mayo", category: 'Topping', price: 150, imagePath: 'assets/images/GarlicMayo.png'),
    _TakeawayMenuItem(name: "Mash Potato Side", category: 'Topping', price: 250, imagePath: 'assets/images/MeshPatato.png'),

    // Hot & Cold Beverages
    _TakeawayMenuItem(name: "Cappuccino Coffee", category: 'Hot Coffee', price: 599, imagePath: 'assets/images/Capachino.png'),
    _TakeawayMenuItem(name: "Espresso Double Shot", category: 'Hot Coffee', price: 750, imagePath: 'assets/images/ExpressoDouble.png'),
    _TakeawayMenuItem(name: "Strawberry Iced Latte", category: 'Cold Coffee', price: 599, imagePath: 'assets/images/Strawberry.png'),
    _TakeawayMenuItem(name: "Caramel Iced Latte", category: 'Cold Coffee', price: 599, imagePath: 'assets/images/Cerimal.png'),

    // Ice Cream & Desserts
    _TakeawayMenuItem(name: "Kulfa Ice Cream (Single)", category: 'Dessert', price: 199, imagePath: 'assets/images/ice_cream_hero.jpg'),
    _TakeawayMenuItem(name: "Kulfa Ice Cream (Double)", category: 'Dessert', price: 399, imagePath: 'assets/images/ice_cream_hero.jpg'),
    _TakeawayMenuItem(name: "Pina Colada Mocktail", category: 'Dessert', price: 650, imagePath: 'assets/images/pina.png'),
    _TakeawayMenuItem(name: "Blueberry Mojito", category: 'Dessert', price: 450, imagePath: 'assets/images/blueBerry.png'),
    _TakeawayMenuItem(name: "Mango Smoothie", category: 'Dessert', price: 199, imagePath: 'assets/images/MangoS.png'),
    _TakeawayMenuItem(name: "Chocolate Ice Shake", category: 'Dessert', price: 590, imagePath: 'assets/images/ChocolateI.png'),
    _TakeawayMenuItem(name: "Banana Milkshake", category: 'Dessert', price: 400, imagePath: 'assets/images/BananaShake.png'),
  ];

  double _discountPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingOrder;
    _customerNameController = TextEditingController(
      text: existing == null || existing.customerName == 'Guest Customer' || existing.customerName == 'Takeaway Customer'
          ? ''
          : existing.customerName,
    );
    _customerPhoneController = TextEditingController(
      text: existing == null || existing.customerPhone == 'N/A'
          ? ''
          : existing.customerPhone,
    );

    if (existing != null) {
      _discountPercentage = existing.discountPercentage;

      if (existing.items.isNotEmpty) {
        for (final oi in existing.items) {
          if (oi.isCancelled) continue;
          final found = _menuDatabase.firstWhere(
            (m) => m.name.toLowerCase() == oi.item.name.toLowerCase() ||
                   m.name.toLowerCase().contains(oi.item.name.toLowerCase()) ||
                   oi.item.name.toLowerCase().contains(m.name.toLowerCase()),
            orElse: () => _TakeawayMenuItem(
              name: oi.item.name,
              category: 'Custom',
              price: oi.unitPrice > 0
                  ? oi.unitPrice
                  : (oi.quantity > 0 ? existing.subtotal / oi.quantity : 0.0),
              imagePath: 'assets/images/Pizza.png',
            ),
          );
          _cartItems.add(_TakeawayOrderItem(
            item: found,
            quantity: oi.quantity,
            initialOrderedQty: oi.quantity,
          ));
        }
      } else {
        // Parse items from itemsSummary
        final rawParts = existing.itemsSummary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        for (final part in rawParts) {
          final regex = RegExp(r'^(\d+)x\s+(.+)$');
          final match = regex.firstMatch(part);
          final qty = match != null ? (int.tryParse(match.group(1)!) ?? 1) : 1;
          final name = match != null ? match.group(2)!.trim() : part.trim();

          final found = _menuDatabase.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase() ||
                   m.name.toLowerCase().contains(name.toLowerCase()) ||
                   name.toLowerCase().contains(m.name.toLowerCase()),
            orElse: () => _TakeawayMenuItem(
              name: name,
              category: 'Custom',
              price: rawParts.length == 1 && existing.subtotal > 0
                  ? (existing.subtotal / qty)
                  : (existing.subtotal > 0 ? existing.subtotal / (rawParts.length * qty) : 0.0),
              imagePath: 'assets/images/Pizza.png',
            ),
          );
          _cartItems.add(_TakeawayOrderItem(
            item: found,
            quantity: qty,
            initialOrderedQty: qty,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _menuSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _discountAmount {
    return _subtotal * (_discountPercentage / 100);
  }

  double get _totalBill {
    return (_subtotal - _discountAmount).clamp(0.0, double.infinity);
  }

  void _addItemToCart(_TakeawayMenuItem item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((c) => c.item.name == item.name);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity += 1;
      } else {
        _cartItems.add(_TakeawayOrderItem(item: item, quantity: 1));
      }
    });
  }

  void _decrementCartItem(int index) {
    setState(() {
      final cartItem = _cartItems[index];
      if (cartItem.isExistingOrderedItem) {
        if (cartItem.quantity > cartItem.initialOrderedQty) {
          cartItem.quantity -= 1;
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot remove already ordered items here. Please use "Cancel Item" to cancel existing items.'),
              backgroundColor: Color(0xFFDC2626),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (_cartItems[index].quantity > 1) {
          _cartItems[index].quantity -= 1;
        } else {
          _cartItems.removeAt(index);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final takeawayState = widget.ref.watch(takeawayProvider);
    final nextToken = 'TK-${takeawayState.tokenCounter}';
    final categories = ['All', 'Deals', 'Pizza', 'Steak', 'Burger', 'Brost', 'Pasta', 'Panini', 'Appetizer', 'Fries', 'Drinks', 'Topping', 'Hot Coffee', 'Cold Coffee', 'Dessert'];

    final filteredMenu = _menuDatabase.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _menuQuery.isEmpty || item.name.toLowerCase().contains(_menuQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final isEditing = widget.existingOrder != null;
    final displayToken = widget.existingOrder?.tokenNumber ?? nextToken;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
        child: Column(
          children: [
            // Top Bar Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.post_add_rounded : Icons.shopping_bag_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'EDIT & ADD ITEMS — $displayToken' : 'TAKEAWAY ORDER SELECTION — $nextToken',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.6),
                      ),
                      Text(
                        isEditing ? 'Modify or add items, customer info & discount. Updates DB immediately.' : 'Select menu items for counter takeaway order & generate kitchen token',
                        style: const TextStyle(color: AppColors.brandYellow, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body (Split Layout: Menu Grid Left, Cart & Customer Details Right)
            Expanded(
              child: Row(
                children: [
                  // Left Column: Menu Filter & Items Grid
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search Input
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _menuSearchController,
                                    onChanged: (val) => setState(() => _menuQuery = val.trim()),
                                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search items (e.g. Fajita, Burger, Steak)...',
                                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary, fontSize: 12),
                                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryRed),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Category Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    selectedColor: AppColors.primaryRed,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) => setState(() => _selectedCategory = cat),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Items Grid
                          Expanded(
                            child: filteredMenu.isEmpty
                                ? Center(
                                    child: Text(
                                      'No menu items found.',
                                      style: TextStyle(color: isDark ? Colors.white : AppColors.textSecondary),
                                    ),
                                  )
                                : GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 2.5,
                                    ),
                                    itemCount: filteredMenu.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredMenu[index];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.asset(
                                                item.imagePath,
                                                width: 38,
                                                height: 38,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  width: 38,
                                                  height: 38,
                                                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                                                  child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    item.name,
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10.5,
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'PKR ${item.price.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      color: AppColors.primaryRed,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              onTap: () => _addItemToCart(item),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryRed,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Column: Customer Details & Cart Summary
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: Border(left: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(isEditing ? Icons.post_add_rounded : Icons.shopping_cart_rounded, color: AppColors.primaryRed, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'EDIT & ADD ITEMS' : 'TAKEAWAY CART',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Customer Details Inputs
                        TextField(
                          controller: _customerNameController,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Customer Name',
                            labelStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            labelText: 'Phone Number (Optional)',
                            labelStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cart Items List
                        Expanded(
                          child: _cartItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No items selected yet.\nTap + on menu items to add.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 12),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _cartItems.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final cartItem = _cartItems[index];
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
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
                                                  cartItem.item.name,
                                                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'PKR ${cartItem.totalPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                '@ PKR ${cartItem.item.price.toStringAsFixed(0)}',
                                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 10),
                                              ),
                                              const Spacer(),
                                              InkWell(
                                                onTap: () => _decrementCartItem(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(Icons.remove_rounded, color: AppColors.primaryRed, size: 14),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Text(
                                                  '${cartItem.quantity}',
                                                  style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    cartItem.quantity += 1;
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryRed,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),

                        const Divider(height: 16),

                        // Discount in % selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.percent_rounded, size: 13, color: Color(0xFF16A34A)),
                                      SizedBox(width: 4),
                                      Text('Discount (%):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                  if (_discountPercentage > 0)
                                    Text(
                                      '${_discountPercentage.toStringAsFixed(0)}% OFF (-PKR ${_discountAmount.toStringAsFixed(0)})',
                                      style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                children: [0.0, 5.0, 10.0, 15.0, 20.0, 25.0].map((pct) {
                                  final isSel = (_discountPercentage - pct).abs() < 0.01;
                                  return InkWell(
                                    onTap: () => setState(() => _discountPercentage = pct),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : Colors.white),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isSel ? const Color(0xFF16A34A) : AppColors.borderGray),
                                      ),
                                      child: Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSel ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Total Price Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Text('PKR ${_subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              if (_discountAmount > 0) ...[
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Discount (${_discountPercentage.toStringAsFixed(0)}%):', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                    Text('-PKR ${_discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  Text(
                                    'PKR ${_totalBill.toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Create / Update Order Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _cartItems.isEmpty
                                ? null
                                : () async {
                                    final summaryParts = _cartItems.map((c) => '${c.quantity}x ${c.item.name}').join(', ');
                                    final itemsList = _cartItems.map((c) => {
                                      'item_name': c.item.name,
                                      'quantity': c.quantity,
                                      'unit_price': c.item.price,
                                      'total_price': c.totalPrice,
                                      'selected_size': 'Regular',
                                      'selected_crust': 'Original',
                                    }).toList();

                                    final custName = _customerNameController.text.trim().isEmpty
                                        ? 'Takeaway Customer'
                                        : _customerNameController.text.trim();
                                    final custPhone = _customerPhoneController.text.trim().isEmpty
                                        ? 'N/A'
                                        : _customerPhoneController.text.trim();

                                    if (isEditing) {
                                      await widget.takeawayNotifier.updateTakeawayOrder(
                                        orderId: widget.existingOrder!.id,
                                        customerName: custName,
                                        customerPhone: custPhone,
                                        itemsSummary: summaryParts,
                                        subtotal: _subtotal,
                                        discountPercentage: _discountPercentage,
                                        discountAmount: _discountAmount,
                                        items: itemsList,
                                      );
                                      // Unmark kitchen receipt print lock so the updated KOT can be printed
                                      await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
                                        orderId: widget.existingOrder!.id,
                                        tokenNumber: widget.existingOrder!.tokenNumber,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Takeaway Order ${widget.existingOrder!.tokenNumber} updated successfully in database!'),
                                            backgroundColor: const Color(0xFF16A34A),
                                          ),
                                        );
                                      }
                                    } else {
                                      await widget.takeawayNotifier.addOrder(
                                        customerName: custName,
                                        customerPhone: custPhone,
                                        itemsSummary: summaryParts,
                                        subtotal: _subtotal,
                                        discountPercentage: _discountPercentage,
                                        discountAmount: _discountAmount,
                                        items: itemsList,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Takeaway Order $nextToken created successfully! Token generated.'),
                                            backgroundColor: const Color(0xFF16A34A),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 16),
                            label: Text(isEditing ? 'SAVE & UPDATE ORDER (PKR ${_totalBill.toStringAsFixed(0)})' : 'CREATE ORDER (PKR ${_totalBill.toStringAsFixed(0)})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isEditing ? const Color(0xFF2563EB) : AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Cancel Takeaway Item Modal
// ---------------------------------------------------------------------------
class _CancelTakeawayItemModal extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final TakeawayOrder order;
  final TakeawayNotifier takeawayNotifier;
  final bool isDark;

  const _CancelTakeawayItemModal({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.takeawayNotifier,
    required this.isDark,
  });

  @override
  State<_CancelTakeawayItemModal> createState() => _CancelTakeawayItemModalState();
}

class _CancelTakeawayItemModalState extends State<_CancelTakeawayItemModal> {
  // Map of item_id -> quantity to cancel
  final Map<String, int> _cancelQuantities = {};

  String _selectedReason = 'Customer Changed Mind';
  final TextEditingController _customReasonController = TextEditingController();
  bool _isCustomReason = false;
  bool _isLoading = false;
  bool _isLoadingItems = false;
  List<OrderItem> _items = [];

  final List<String> _commonReasons = [
    'Customer Changed Mind',
    'Ordered by Mistake',
    'Kitchen Delay',
    'Out of Ingredients',
    'Wrong Order Item',
  ];

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.order.items);
    if (_items.isEmpty) {
      _loadOrderItems();
    } else {
      _initCancelQuantities();
    }
  }

  void _initCancelQuantities() {
    _cancelQuantities.clear();
    for (final item in _items) {
      if (item.isCancelled) continue;
      final itemId = item.id ?? item.item.name;
      _cancelQuantities[itemId] = 0;
    }
  }

  Future<void> _loadOrderItems() async {
    setState(() => _isLoadingItems = true);
    try {
      final data = await widget.ref.read(ordersApiServiceProvider).getOrderById(widget.order.id);
      if (data['order_items'] is List) {
        final fetched = (data['order_items'] as List)
            .map((i) => OrderItem.fromBackendJson(i as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _items = fetched;
            _initCancelQuantities();
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching items in modal: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  int _getTotalSelectedCancelQty() {
    return _cancelQuantities.values.fold(0, (sum, q) => sum + q);
  }

  void _decrementActiveItem(OrderItem item) {
    final itemId = item.id ?? item.item.name;
    final maxQty = item.quantity;
    final currentCancel = _cancelQuantities[itemId] ?? 0;

    if (currentCancel < maxQty) {
      setState(() {
        _cancelQuantities[itemId] = currentCancel + 1;
      });
    }
  }

  void _restoreCancelledItem(OrderItem item) {
    final itemId = item.id ?? item.item.name;
    final currentCancel = _cancelQuantities[itemId] ?? 0;

    if (currentCancel > 0) {
      setState(() {
        _cancelQuantities[itemId] = currentCancel - 1;
      });
    }
  }

  void _cancelAllOfItem(OrderItem item) {
    final itemId = item.id ?? item.item.name;
    final maxQty = item.quantity;
    setState(() {
      _cancelQuantities[itemId] = maxQty;
    });
  }

  Future<void> _handleConfirmCancel() async {
    final totalToCancel = _getTotalSelectedCancelQty();
    if (totalToCancel == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please click - on at least one item to cancel its quantity.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final effectiveReason = _isCustomReason
        ? _customReasonController.text.trim()
        : _selectedReason;

    if (effectiveReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for cancellation.')),
      );
      return;
    }

    final parentMessenger = ScaffoldMessenger.of(widget.parentContext);
    setState(() => _isLoading = true);

    try {
      final orderId = widget.order.id;
      final currentUser = widget.ref.read(authProvider).currentUser;
      final cashierName = currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Cashier';
      final ordersApi = widget.ref.read(ordersApiServiceProvider);

      // Check if ALL active items in this takeaway order are being cancelled
      final activeItems = _items.where((i) => !i.isCancelled).toList();
      final totalActiveQty = activeItems.fold<int>(0, (sum, i) => sum + i.quantity);
      final isCancellingEntireOrder = totalToCancel >= totalActiveQty;

      // Cancel each item with its designated cancel quantity (skipping already cancelled items)
      for (final item in _items) {
        if (item.isCancelled) continue;
        final itemId = item.id ?? '';
        final cancelQty = _cancelQuantities[itemId] ?? 0;

        if (cancelQty > 0 && itemId.isNotEmpty) {
          await ordersApi.cancelOrderItem(
            orderId,
            itemId: itemId,
            cancelQuantity: cancelQty,
            reason: effectiveReason,
            cancelledBy: cashierName,
          );
        }
      }

      // If all active items are cancelled, mark the entire takeaway order as cancelled
      if (isCancellingEntireOrder) {
        await ordersApi.updateOrderStatus(
          orderId,
          status: 'cancelled',
          rejectionReason: effectiveReason,
        );
      }

      // Invalidate thermal/kitchen receipt print markers
      if (orderId.isNotEmpty) {
        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
          orderId: orderId,
          tokenNumber: widget.order.tokenNumber,
        );
      }

      // Reload takeaway orders
      await widget.takeawayNotifier.loadTakeawayOrders();

      if (mounted) {
        Navigator.pop(context);
        parentMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  isCancellingEntireOrder
                      ? 'Takeaway order ${widget.order.tokenNumber} fully cancelled.'
                      : '$totalToCancel item(s) cancelled with strikethrough.',
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel item: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final allItems = _items;
    final activeItems = allItems.where((i) => !i.isCancelled).toList();
    final totalToCancel = _getTotalSelectedCancelQty();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CANCEL ORDER ITEMS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Token: ${widget.order.tokenNumber} • Tap [-] on items to cancel quantity',
                            style: const TextStyle(
                              color: Color(0xFFFECACA),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoadingItems)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                              SizedBox(height: 12),
                              Text('Loading order items...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else if (activeItems.isEmpty && allItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No items in this takeaway order.',
                            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else ...[
                      // 1. Interactive Item List with [-] buttons and separated LineThrough preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ORDER ITEMS & CANCELLATION PREVIEW',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (totalToCancel > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFEF4444)),
                              ),
                              child: Text(
                                '$totalToCancel Selected to Cancel',
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Items List
                      ...allItems.map((item) {
                        final itemId = item.id ?? item.item.name;
                        final name = item.item.name;
                        final initialQty = item.quantity;
                        final unitPrice = item.unitPrice;
                        final isAlreadyCancelled = item.isCancelled;

                        if (isAlreadyCancelled) {
                          // Already cancelled in previous operation: show with lineThrough
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2).withValues(alpha: isDark ? 0.2 : 0.6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${initialQty}x $name',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Color(0xFFDC2626),
                                      decorationThickness: 2,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ALREADY CANCELLED',
                                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final cancelQty = _cancelQuantities[itemId] ?? 0;
                        final activeQty = initialQty - cancelQty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cancelQty > 0
                                  ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: cancelQty > 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Active Row with [-] decrement button
                              Row(
                                children: [
                                  // [-] Decrement Button
                                  Tooltip(
                                    message: 'Cancel 1 qty of this item',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: activeQty > 0 ? () => _decrementActiveItem(item) : null,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: activeQty > 0
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF94A3B8).withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: activeQty > 0
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: const Icon(
                                            Icons.remove_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Item Name and Active Qty
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          activeQty > 0 ? '${activeQty}x $name' : '$name (0 active)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: activeQty > 0
                                                ? (isDark ? Colors.white : AppColors.textPrimary)
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        Text(
                                          'PKR ${unitPrice.toStringAsFixed(0)} each • Total: PKR ${(unitPrice * activeQty).toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quick Cancel All Button
                                  if (activeQty > 0 && initialQty > 1)
                                    TextButton(
                                      onPressed: () => _cancelAllOfItem(item),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFDC2626),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Cancel All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),

                              // Separated Cancelled Line Through Row (Shown on screen immediately when minus is pressed!)
                              if (cancelQty > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFDC2626), size: 15),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${cancelQty}x $name (CANCELLED)',
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Color(0xFFDC2626),
                                            decorationThickness: 2.2,
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '- PKR ${(unitPrice * cancelQty).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // [+] Restore button
                                      Tooltip(
                                        message: 'Restore 1 qty back to active',
                                        child: InkWell(
                                          onTap: () => _restoreCancelledItem(item),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFDC2626)),
                                            ),
                                            child: const Icon(Icons.add_rounded, size: 13, color: Color(0xFFDC2626)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),

                      // 2. Cancellation Reason
                      const Text(
                        '2. REASON FOR CANCELLATION',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ..._commonReasons.map((reason) {
                            final isSel = !_isCustomReason && _selectedReason == reason;
                            return ChoiceChip(
                              label: Text(reason, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : null)),
                              selected: isSel,
                              selectedColor: const Color(0xFFDC2626),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _isCustomReason = false;
                                    _selectedReason = reason;
                                  });
                                }
                              },
                            );
                          }),
                          ChoiceChip(
                            label: Text('Other / Custom', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isCustomReason ? Colors.white : null)),
                            selected: _isCustomReason,
                            selectedColor: const Color(0xFFDC2626),
                            onSelected: (val) {
                              setState(() => _isCustomReason = true);
                            },
                          ),
                        ],
                      ),

                      if (_isCustomReason) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customReasonController,
                          decoration: InputDecoration(
                            hintText: 'Enter reason for cancellation...',
                            hintStyle: const TextStyle(fontSize: 12),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back / Keep Items'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || totalToCancel == 0 ? null : _handleConfirmCancel,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.delete_forever_rounded, size: 18),
                      label: Text(_isLoading ? 'Processing...' : 'Confirm Cancellation ($totalToCancel)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
