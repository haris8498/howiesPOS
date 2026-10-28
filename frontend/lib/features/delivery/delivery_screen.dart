import 'package:drift/drift.dart' show Value;
import '../../config/feature_flags.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_providers.dart';
import '../../shared/widgets/refund_order_dialog.dart';
import '../../domain/models/order_model.dart';
import '../../services/api/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/delivery_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/delivery_model.dart';
import '../../domain/models/user_role.dart';
import '../../services/receipt_printer_service.dart';
import '../../shared/widgets/cashier_sidebar_footer.dart';

class DeliveryScreen extends ConsumerStatefulWidget {
  const DeliveryScreen({super.key});

  @override
  ConsumerState<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends ConsumerState<DeliveryScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDeliveryId;
  String? _activeDetailDeliveryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DeliveryOrder? _getSelectedDelivery(List<DeliveryOrder> deliveries) {
    if (deliveries.isEmpty) return null;
    if (_selectedDeliveryId != null) {
      final found = deliveries.where((d) => d.id == _selectedDeliveryId).firstOrNull;
      if (found != null) return found;
    }
    return deliveries.where((d) => d.status != DeliveryStatus.delivered).firstOrNull ?? deliveries.firstOrNull;
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

  Widget _buildDeliveryOrderedItemsBreakdown(DeliveryOrder del, bool isDark) {
    if (del.items.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: del.items.length,
        separatorBuilder: (context, index) => Divider(
          height: 14,
          thickness: 1,
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        itemBuilder: (context, index) {
          final it = del.items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
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

    final parsed = _splitItemsSummary(del.itemsSummary);
    if (parsed.isEmpty) {
      return Text(
        'No items recorded for this order',
        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 13),
      );
    }

    final regex = RegExp(r'^(\d+)x\s+(.+)$');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: parsed.length,
      separatorBuilder: (context, index) => Divider(
        height: 14,
        thickness: 1,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
      itemBuilder: (context, index) {
        final raw = parsed[index];
        final match = regex.firstMatch(raw);
        final qty = match != null ? match.group(1)! : '1';
        final name = match != null ? match.group(2)! : raw;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
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

  Widget _buildDeliveryActionPillButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool isFilled,
    required bool isDark,
    required VoidCallback onTap,
    bool isEnabled = true,
    String? subtitle,
    String? tooltip,
  }) {
    final buttonContent = InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: subtitle != null ? 56 : 52,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isFilled ? Colors.white : color,
                      fontWeight: FontWeight.w800,
                      fontSize: subtitle != null ? 12.5 : 13,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isFilled ? Colors.white.withValues(alpha: 0.85) : color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 9.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
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

    if (tooltip != null || subtitle != null) {
      return Tooltip(
        message: tooltip ?? subtitle ?? '',
        child: buttonContent,
      );
    }
    return buttonContent;
  }

  @override
  Widget build(BuildContext context) {
    final delState = ref.watch(deliveryProvider);
    final delNotifier = ref.read(deliveryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If a delivery order is active/selected for full details view, render the Full Screen Delivery Order Details view (Not in pop-up)
    if (_activeDetailDeliveryId != null) {
      final activeDel = delState.deliveries.where((d) => d.id == _activeDetailDeliveryId).firstOrNull;
      if (activeDel != null) {
        return _buildFullDeliveryOrderScreen(context, ref, activeDel, delState, delNotifier, isDark);
      }
    }

    final filterOptions = ['All', 'Online Orders', 'Direct Delivery', 'Transit', 'Pending', 'Delivered', 'Riders'];

    final filteredDeliveries = delState.deliveries.where((del) {
      // 1. Category Filter
      final matchesFilter = () {
        if (_selectedFilter == 'All') return true;
        if (_selectedFilter == 'Online Orders') return del.orderSource == 'Online Orders';
        if (_selectedFilter == 'Direct Delivery') return del.orderSource != 'Online Orders';
        if (_selectedFilter == 'Transit') return del.status == DeliveryStatus.outForDelivery;
        if (_selectedFilter == 'Pending') {
          return del.status == DeliveryStatus.pending ||
              del.status == DeliveryStatus.preparing ||
              del.status == DeliveryStatus.accepted ||
              del.status == DeliveryStatus.readyForDispatch;
        }
        if (_selectedFilter == 'Delivered') return del.status == DeliveryStatus.delivered;
        return true;
      }();

      // 2. Search Query Filter
      final matchesQuery = _searchQuery.isEmpty ||
          del.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          del.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          del.customerPhone.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          del.deliveryAddress.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          del.orderSource.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesQuery;
    }).toList();

    final selectedDel = _getSelectedDelivery(delState.deliveries);
    if (_selectedDeliveryId == null && selectedDel != null) {
      _selectedDeliveryId = selectedDel.id;
    }

    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier;

    final bool isPaid = selectedDel?.paymentStatus == 'PAID';
    final bool isDelivered = selectedDel?.status == DeliveryStatus.delivered;
    final bool canEdit = selectedDel != null && !isPaid && !isDelivered && !selectedDel.isBillPrinted && selectedDel.status == DeliveryStatus.pending;
    final bool canReceivePayment = selectedDel != null && !isPaid;
    final isOnline = ref.watch(connectivityNotifierProvider).isOnline;
    final bool canRefundDel = selectedDel != null &&
        isPaid &&
        selectedDel.status != DeliveryStatus.cancelled &&
        selectedDel.status.name.toLowerCase() != 'refunded';
    final bool hasAssignPerm = ref.watch(roleRightsProvider).isActionGranted(
      authState.currentUser.role,
      'del_assign',
      defaultIfMissing: authState.currentUser.role != UserRole.cashier,
    );
    final bool canAssignRider = selectedDel != null && !isDelivered && hasAssignPerm;

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
                  _buildDeliveryActionPillButton(
                    title: 'Edit & Add',
                    icon: Icons.post_add_rounded,
                    color: const Color(0xFF9333EA),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedDel != null,
                    onTap: () {
                      if (selectedDel == null) {
                        _openCreateDeliveryOrderDialog(context, ref, isDark);
                        return;
                      }
                      if (canEdit) {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (dialogContext) => _CreateDeliveryOrderDialog(
                            isDark: isDark,
                            ref: ref,
                            existingOrder: selectedDel,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cannot edit order #${selectedDel.orderNumber} because it is already dispatched, billed or completed.')),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 2: Kitchen Bill (KOT) (Outline Orange)
                  _buildDeliveryActionPillButton(
                    title: 'Kitchen Bill (KOT)',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFFD97706),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedDel != null,
                    onTap: () {
                      if (selectedDel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a delivery order first.')),
                        );
                        return;
                      }
                      _showKitchenReceiptModal(context, selectedDel, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 3: Dispatch Bill (Outline Blue)
                  _buildDeliveryActionPillButton(
                    title: 'Dispatch Bill',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFF2563EB),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedDel != null,
                    onTap: () {
                      if (selectedDel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a delivery order first.')),
                        );
                        return;
                      }
                      _showDispatchBillModal(context, selectedDel, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button: Cancel Item (Outline Red)
                  _buildDeliveryActionPillButton(
                    title: 'Cancel Item',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: selectedDel != null && !isPaid && selectedDel.status != DeliveryStatus.cancelled,
                    onTap: () {
                      if (selectedDel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a delivery order.')),
                        );
                        return;
                      }
                      _showCancelDeliveryItemDialog(context, ref, selectedDel, isDark);
                    },
                  ),

                  const SizedBox(height: 10),

                  // Button 4: Refund Order (if paid) OR Receive Payment (Solid Green)
                  if (canRefundDel) ...[
                    _buildDeliveryActionPillButton(
                      title: 'Refund Order',
                      subtitle: isOnline ? null : 'Refund requires an internet connection',
                      icon: Icons.assignment_return_rounded,
                      color: const Color(0xFFDC2626),
                      isFilled: true,
                      isDark: isDark,
                      isEnabled: isOnline,
                      onTap: () => _handleRefundDeliveryOrder(context, ref, selectedDel, delNotifier),
                    ),
                  ] else ...[
                    _buildDeliveryActionPillButton(
                      title: selectedDel != null ? 'Receive Payment (PKR ${selectedDel.totalAmount.toStringAsFixed(0)})' : 'Receive Payment',
                      icon: Icons.attach_money_rounded,
                      color: const Color(0xFF16A34A),
                      isFilled: true,
                      isDark: isDark,
                      isEnabled: canReceivePayment,
                      onTap: () {
                        if (selectedDel == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select an active delivery order first.')),
                          );
                          return;
                        }
                        if (isPaid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Order #${selectedDel.orderNumber} is already paid.')),
                          );
                          return;
                        }
                        _showFinalBillModal(context, selectedDel, isDark);
                      },
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Button 5: Assign Rider & Dispatch (Solid Red)
                  _buildDeliveryActionPillButton(
                    title: 'Assign Rider & Dispatch',
                    icon: Icons.person_add_rounded,
                    color: const Color(0xFFDC2626),
                    isFilled: true,
                    isDark: isDark,
                    isEnabled: canAssignRider,
                    onTap: () {
                      if (selectedDel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a delivery order first.')),
                        );
                        return;
                      }
                      _showAssignRiderModal(context, delNotifier, delState, selectedDel);
                    },
                  ),

                  const SizedBox(height: 14),

                  // Direct Action: Create Delivery Order Button
                  OutlinedButton.icon(
                    onPressed: () => _openCreateDeliveryOrderDialog(context, ref, isDark),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primaryRed),
                    label: const Text('+ Create Delivery Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

    // 2. Right Main Delivery Orders Area
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Header Row with Title & Create Delivery Order Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVERY DISPATCH & ORDERS CONTROL',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create delivery orders, print KOT & bills, track riders and receive payments',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateDeliveryOrderDialog(context, ref, isDark),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create Delivery Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
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

                // Compact Stat Overview Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Active Deliveries',
                        value: '${delState.deliveries.where((d) => d.status != DeliveryStatus.delivered).length}',
                        icon: Icons.two_wheeler_rounded,
                        iconColor: const Color(0xFFD32F2F),
                        bgColor: const Color(0xFFFDF0F0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Online Orders',
                        value: '${delState.deliveries.where((d) => d.orderSource == 'Online Orders' && d.status != DeliveryStatus.delivered).length}',
                        icon: Icons.cloud_download_rounded,
                        iconColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFE0F2FE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Direct Delivery',
                        value: '${delState.deliveries.where((d) => d.orderSource != 'Online Orders' && d.status != DeliveryStatus.delivered).length}',
                        icon: Icons.storefront_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF3E8FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Active Riders',
                        value: '${delState.riders.where((r) => r.isClockedIn).length}',
                        icon: Icons.badge_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFEBF7ED),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'Total Delivered',
                        value: '${delState.deliveries.where((d) => d.status == DeliveryStatus.delivered).length}',
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Filter Chips & Search Bar (Identical to Tables Screen)
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filterOptions.map((opt) {
                            final isSelected = _selectedFilter == opt;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  opt,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white : AppColors.textPrimary),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primaryRed,
                                backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryRed
                                      : (isDark ? const Color(0xFF334155) : AppColors.borderGray),
                                  width: 1.2,
                                ),
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onSelected: (_) => setState(() => _selectedFilter = opt),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 240,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search order, phone, customer...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryRed),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Tab Body View
                Expanded(
                  child: _selectedFilter == 'Riders'
                      ? _buildRidersTab(delState, isDark)
                      : _buildActiveDeliveriesTab(filteredDeliveries, delNotifier, isDark),
                ),
              ],
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
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
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveriesTab(List<DeliveryOrder> deliveries, DeliveryNotifier notifier, bool isDark) {
    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.two_wheeler_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'No delivery orders found.',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final del = deliveries[index];
        return _DeliveryOrderCardItem(
          del: del,
          notifier: notifier,
          isDark: isDark,
          ref: ref,
          isSelected: _selectedDeliveryId == del.id,
          onSelect: () => setState(() {
            _selectedDeliveryId = del.id;
            _activeDetailDeliveryId = del.id;
          }),
          onShowKitchenReceipt: _showKitchenReceiptModal,
          onShowFinalBill: _showFinalBillModal,
          onShowDispatchBill: _showDispatchBillModal,
          onAssignRider: _showAssignRiderModal,
        );
      },
    );
  }

  Widget _buildFullDeliveryOrderScreen(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrder del,
    DeliveryState delState,
    DeliveryNotifier delNotifier,
    bool isDark,
  ) {
    final isDelivered = del.status == DeliveryStatus.delivered;
    final isPaid = del.paymentStatus == 'PAID';
    final isLockedFromEdit = isPaid || isDelivered || del.isBillPrinted || del.status != DeliveryStatus.pending;
    final timeStr = DateFormat('hh:mm a, dd MMM yyyy').format(del.createdAt);
    final authState = ref.watch(authProvider);
    final isCashier = authState.currentUser.role == UserRole.cashier;

    final bool canEditSelected = !isLockedFromEdit;
    final bool canSettleSelected = !isPaid;
    final isOnline = ref.watch(connectivityNotifierProvider).isOnline;
    final bool canRefundOrder = isPaid &&
        del.status != DeliveryStatus.cancelled &&
        del.status.name.toLowerCase() != 'refunded';
    final bool hasAssignPerm = ref.watch(roleRightsProvider).isActionGranted(
      authState.currentUser.role,
      'del_assign',
      defaultIfMissing: authState.currentUser.role != UserRole.cashier,
    );
    final bool canAssignRider = !isDelivered && hasAssignPerm;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.0, 18.0, 18.0, isCashier ? 0.0 : 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCashier) ...[
            // Left Action Column (Sidebar)
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
                          // Button 1: Edit & Add
                          _buildDeliveryActionPillButton(
                            title: 'Edit & Add',
                            icon: Icons.post_add_rounded,
                            color: const Color(0xFF9333EA),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: canEditSelected,
                            onTap: () {
                              if (canEditSelected) {
                                _openCreateDeliveryOrderDialog(context, ref, isDark, del);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cannot edit order #${del.orderNumber} because it is already dispatched, billed or completed.')),
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 10),

                          // Button 2: Kitchen Bill (KOT)
                          _buildDeliveryActionPillButton(
                            title: 'Kitchen Bill (KOT)',
                            icon: Icons.soup_kitchen_rounded,
                            color: const Color(0xFFD97706),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: true,
                            onTap: () => _showKitchenReceiptModal(context, del, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Button 3: Dispatch Bill
                          _buildDeliveryActionPillButton(
                            title: 'Dispatch Bill',
                            icon: Icons.two_wheeler_rounded,
                            color: const Color(0xFF2563EB),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: true,
                            onTap: () => _showDispatchBillModal(context, del, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Button: Cancel Item in Detail (Outline Red)
                          _buildDeliveryActionPillButton(
                            title: 'Cancel Item',
                            icon: Icons.cancel_outlined,
                            color: const Color(0xFFEF4444),
                            isFilled: false,
                            isDark: isDark,
                            isEnabled: !isPaid && del.status != DeliveryStatus.cancelled,
                            onTap: () => _showCancelDeliveryItemDialog(context, ref, del, isDark),
                          ),

                          const SizedBox(height: 10),

                          // Button 4: Refund Order (if paid) OR Receive Payment
                          if (canRefundOrder) ...[
                            _buildDeliveryActionPillButton(
                              title: 'Refund Order',
                              subtitle: isOnline ? null : 'Refund requires an internet connection',
                              icon: Icons.assignment_return_rounded,
                              color: const Color(0xFFDC2626),
                              isFilled: true,
                              isDark: isDark,
                              isEnabled: isOnline,
                              onTap: () => _handleRefundDeliveryOrder(context, ref, del, delNotifier),
                            ),
                          ] else ...[
                            _buildDeliveryActionPillButton(
                              title: 'Receive Payment (PKR ${del.totalAmount.toStringAsFixed(0)})',
                              icon: Icons.attach_money_rounded,
                              color: const Color(0xFF16A34A),
                              isFilled: true,
                              isDark: isDark,
                              isEnabled: canSettleSelected,
                              onTap: () {
                                if (isPaid) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Order #${del.orderNumber} is already paid.')),
                                  );
                                  return;
                                }
                                _showFinalBillModal(context, del, isDark);
                              },
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Button 5: Assign Rider & Dispatch
                          _buildDeliveryActionPillButton(
                            title: del.riderName == null ? 'Assign Rider & Dispatch' : 'Change Rider',
                            icon: Icons.person_add_rounded,
                            color: const Color(0xFFDC2626),
                            isFilled: true,
                            isDark: isDark,
                            isEnabled: canAssignRider,
                            onTap: () => _showAssignRiderModal(context, delNotifier, delState, del),
                          ),

                          const SizedBox(height: 16),

                          // Return to Delivery Tracking Queue Button
                          InkWell(
                            onTap: () => setState(() => _activeDetailDeliveryId = null),
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
                                  Icon(Icons.two_wheeler_rounded, size: 16, color: AppColors.primaryRed),
                                  SizedBox(width: 8),
                                  Text(
                                    'View All Delivery Orders',
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

          // Main Delivery Order Details View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Row with Order Title, Badges, and Edit Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ORDER #${del.orderNumber}',
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Source Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: del.orderSource == 'Online Orders'
                                      ? (isDark ? const Color(0xFF0369A1).withValues(alpha: 0.25) : const Color(0xFFE0F2FE))
                                      : (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.25) : const Color(0xFFF3E8FF)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: del.orderSource == 'Online Orders' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                                  ),
                                ),
                                child: Text(
                                  del.orderSource == 'Online Orders' ? 'ONLINE ORDER' : 'DIRECT DELIVERY',
                                  style: TextStyle(
                                    color: del.orderSource == 'Online Orders' ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Payment Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFFEBF7ED) : const Color(0xFFFDF0F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isPaid ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                                  ),
                                ),
                                child: Text(
                                  isPaid ? 'PAID (${del.paymentMethod})' : 'UNPAID (${del.paymentMethod})',
                                  style: TextStyle(
                                    color: isPaid ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDelivered ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  del.status.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Delivery Order • Created: $timeStr',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Quick Action: Edit / Modify
                      if (canEditSelected)
                        ElevatedButton.icon(
                          onPressed: () => _openCreateDeliveryOrderDialog(context, ref, isDark, del),
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
                          // Left Details Box: Customer info & Rider status
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Customer & Delivery Information Card
                                  Text(
                                    'CUSTOMER & DELIVERY INFO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(
                                          icon: Icons.person_rounded,
                                          label: 'Customer Name',
                                          value: del.customerName.isEmpty ? 'Walk-in / N/A' : del.customerName,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDetailRow(
                                          icon: Icons.phone_rounded,
                                          label: 'Customer Phone',
                                          value: del.customerPhone.isEmpty ? 'N/A' : del.customerPhone,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDetailRow(
                                          icon: Icons.location_on_rounded,
                                          label: 'Delivery Address',
                                          value: del.deliveryAddress.isEmpty ? 'N/A' : del.deliveryAddress,
                                          isDark: isDark,
                                          isHighlight: true,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDetailRow(
                                          icon: Icons.storefront_rounded,
                                          label: 'Order Category / Origin',
                                          value: del.orderSource,
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Rider & Assignment Info Card
                                  Text(
                                    'RIDER & DISPATCH INFO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.6,
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildDetailRow(
                                          icon: Icons.badge_rounded,
                                          label: 'Assigned Rider',
                                          value: del.riderName ?? 'No Rider Assigned',
                                          isDark: isDark,
                                          isHighlight: del.riderName != null,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDetailRow(
                                          icon: Icons.two_wheeler_rounded,
                                          label: 'Delivery Status',
                                          value: del.status.name.toUpperCase(),
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 10),
                                        _buildDetailRow(
                                          icon: Icons.access_time_filled_rounded,
                                          label: 'Estimated Delivery',
                                          value: DateFormat('hh:mm a').format(del.estimatedDeliveryTime),
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Right Details Box: Order Items & Billing Summary
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER ITEMS & BILLING SUMMARY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.6,
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Items summary box
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.fastfood_rounded, size: 16, color: AppColors.primaryRed),
                                              SizedBox(width: 8),
                                              Text(
                                                'Order Items',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          _buildDeliveryOrderedItemsBreakdown(del, isDark),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Financial Calculation Summary Box
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Delivery Fee', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 13)),
                                          Text('PKR ${del.deliveryCharge.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Payment Mode', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 13)),
                                          Text(del.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Grand Total',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                          ),
                                          Text(
                                            'PKR ${del.totalAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              color: AppColors.primaryRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (canRefundOrder) ...[
                                        const SizedBox(height: 12),
                                        Tooltip(
                                          message: isOnline ? '' : 'Refund requires an internet connection',
                                          child: ElevatedButton.icon(
                                            onPressed: isOnline
                                                ? () => _handleRefundDeliveryOrder(context, ref, del, delNotifier)
                                                : null,
                                            icon: const Icon(Icons.assignment_return_rounded, size: 16),
                                            label: Text(
                                              isOnline ? 'Refund Order' : 'Refund requires an internet connection',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFDC2626),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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


  // Handle Delivery Order Refund (Supervisor PIN protected)
  Future<void> _handleRefundDeliveryOrder(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrder del,
    DeliveryNotifier delNotifier,
  ) async {
    final isOnline = ref.read(connectivityNotifierProvider).isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refund requires an internet connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final targetOrderId = del.orderId.isNotEmpty ? del.orderId : del.id.replaceAll('del-', '');
    final ordersApiService = ref.read(ordersApiServiceProvider);

    final result = await RefundOrderDialog.show(
      context,
      orderId: targetOrderId,
      orderNumber: del.orderNumber,
      grandTotal: del.totalAmount,
      ordersApiService: ordersApiService,
    );

    if (result != null && context.mounted) {
      if (FeatureFlags.offlineFirstEnabled) {
        try {
          final db = ref.read(appDatabaseProvider);
          await (db.update(db.localOrders)..where((t) => t.id.equals(targetOrderId)))
              .write(const LocalOrdersCompanion(status: Value('cancelled')));
        } catch (_) {}
      }

      await delNotifier.loadDeliveryData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery order #${del.orderNumber} has been successfully refunded.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  // Cancel Delivery Order Item Dialog
  void _showCancelDeliveryItemDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryOrder del,
    bool isDark,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _CancelDeliveryItemModal(
          parentContext: context,
          ref: ref,
          order: del,
          isDark: isDark,
        );
      },
    );
  }

  // Kitchen Receipt Modal
  // Kitchen Receipt Modal with Interactive Cooking Time Input
  void _showKitchenReceiptModal(BuildContext context, DeliveryOrder del, bool isDark) {
    int cookingMinutes = 25;
    final cookingController = TextEditingController(text: '$cookingMinutes');
    final quickTimers = [10, 15, 20, 25, 30, 45, 60];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final targetTime = DateFormat('hh:mm a').format(del.createdAt.add(Duration(minutes: cookingMinutes)));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 22),
                            SizedBox(width: 8),
                            Text('DELIVERY KITCHEN TICKET (KOT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

                    // Interactive Cooking Time Input Field & Presets Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 15, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Cooking Time (Minutes):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Decrement Button
                              InkWell(
                                onTap: () {
                                  if (cookingMinutes > 5) {
                                    setDialogState(() {
                                      cookingMinutes -= 5;
                                      cookingController.text = '$cookingMinutes';
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.remove, size: 16, color: Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Numeric Input Field
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: cookingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFD97706)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      suffixText: 'mins',
                                      suffixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val.trim());
                                      if (parsed != null && parsed > 0 && parsed <= 300) {
                                        setDialogState(() => cookingMinutes = parsed);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Increment Button
                              InkWell(
                                onTap: () {
                                  if (cookingMinutes < 180) {
                                    setDialogState(() {
                                      cookingMinutes += 5;
                                      cookingController.text = '$cookingMinutes';
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.add, size: 16, color: Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick Preset Chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: quickTimers.map((mins) {
                              final isSel = cookingMinutes == mins;
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    cookingMinutes = mins;
                                    cookingController.text = '$mins';
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFFD97706) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isSel ? const Color(0xFFD97706) : AppColors.borderGray),
                                  ),
                                  child: Text(
                                    '$mins min',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // KOT Ticket Preview Box
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
                          const Center(child: Text('HUNGRY HOWIE\'S KITCHEN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #: ${del.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Type: DELIVERY', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Customer: ${del.customerName} (${del.customerPhone})', style: const TextStyle(fontSize: 11)),
                          Text('Address: ${del.deliveryAddress}', style: const TextStyle(fontSize: 11)),
                          const SizedBox(height: 8),
                          // Dynamic Cooking Time Ticket Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer_rounded, size: 14, color: Color(0xFFD97706)),
                                    const SizedBox(width: 5),
                                    Text('COOKING TIME: $cookingMinutes MINS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFB45309))),
                                  ],
                                ),
                                Text(
                                  'Target: $targetTime',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 16),
                          const Text('ORDER ITEMS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          const SizedBox(height: 6),
                          if (del.items.isNotEmpty)
                            ...del.items.map((it) {
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
                            Text('• ${del.itemsSummary}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final kotReceipt = ReceiptData.fromDeliveryOrder(
                          order: del,
                          type: ReceiptType.kitchenKot,
                        );

                        return FutureBuilder<bool>(
                          future: ReceiptPrinterService.isKitchenReceiptPrinted(
                            del.orderNumber,
                            tokenNumber: del.orderNumber,
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
                                            'Delivery kitchen ticket has already been printed once. Modify order or cancel items to print an updated ticket.',
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

                            final hasCancelled = del.items.any((i) => i.isCancelled);
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);

                                  // Physical Thermal Print to Attached Laptop Printer
                                  await ReceiptPrinterService.printReceipt(
                                    context: context,
                                    receipt: ReceiptData.fromDeliveryOrder(
                                      order: del,
                                      type: ReceiptType.kitchenKot,
                                      isModified: hasCancelled,
                                    ),
                                    forcePrint: hasCancelled,
                                  );
                                },
                                icon: const Icon(Icons.print_rounded, size: 16),
                                label: Text(hasCancelled ? 'PRINT UPDATED KITCHEN RECEIPT' : 'PRINT KITCHEN RECEIPT ($cookingMinutes MINS)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasCancelled ? const Color(0xFFEA580C) : const Color(0xFFD97706),
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
      ),
    );
  }

  // Final Customer Full Bill / Cash Payment Calculator Modal
  void _showFinalBillModal(BuildContext context, DeliveryOrder del, bool isDark) {
    final taxAmount = del.totalAmount * 0.05;
    final grandTotal = del.totalAmount + del.deliveryCharge + taxAmount;

    if (del.paymentStatus.toUpperCase() == 'PAID') {
      _showDeliveryFinalPaidReceiptDialog(context, del, grandTotal, 0.0, isDark);
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _DeliveryFullBillCalculatorDialog(
          parentContext: context,
          ref: ref,
          delivery: del,
          notifier: ref.read(deliveryProvider.notifier),
          isDark: isDark,
        );
      },
    );
  }

  // Rider Dispatch Bill Modal with Interactive Shipping Time Input
  void _showDispatchBillModal(BuildContext context, DeliveryOrder del, bool isDark) {
    if (del.riderName == null || del.riderName!.trim().isEmpty || del.riderId == null || del.riderId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assign Rider is compulsory before printing the Dispatch Bill! Please select an on-duty rider first.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 4),
        ),
      );
      _showAssignRiderModal(
        context,
        ref.read(deliveryProvider.notifier),
        ref.read(deliveryProvider),
        del,
        openDispatchBillOnSuccess: true,
      );
      return;
    }

    final taxAmount = del.totalAmount * 0.05;
    final grandTotal = del.totalAmount + del.deliveryCharge + taxAmount;
    int shippingMinutes = 20;
    final shippingController = TextEditingController(text: '$shippingMinutes');
    final quickTimers = [10, 15, 20, 25, 30, 40, 50, 60];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final now = DateTime.now();
          final dispatchTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final arrivalTime = DateFormat('hh:mm a').format(now.add(Duration(minutes: shippingMinutes)));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.two_wheeler_rounded, color: Color(0xFF2563EB), size: 22),
                            SizedBox(width: 8),
                            Text('RIDER DISPATCH BILL (SLIP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

                    // Interactive Shipping Time Input Field & Presets Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_shipping_rounded, size: 15, color: Color(0xFF2563EB)),
                              SizedBox(width: 6),
                              Text(
                                'Shipping / Estimated Delivery Time (Minutes):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1D4ED8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Decrement Button
                              InkWell(
                                onTap: () {
                                  if (shippingMinutes > 5) {
                                    setDialogState(() {
                                      shippingMinutes -= 5;
                                      shippingController.text = '$shippingMinutes';
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.remove, size: 16, color: Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Numeric Input Field
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: shippingController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF2563EB)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      suffixText: 'mins',
                                      suffixStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val.trim());
                                      if (parsed != null && parsed > 0 && parsed <= 300) {
                                        setDialogState(() => shippingMinutes = parsed);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Increment Button
                              InkWell(
                                onTap: () {
                                  if (shippingMinutes < 180) {
                                    setDialogState(() {
                                      shippingMinutes += 5;
                                      shippingController.text = '$shippingMinutes';
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(Icons.add, size: 16, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quick Preset Chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: quickTimers.map((mins) {
                              final isSel = shippingMinutes == mins;
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    shippingMinutes = mins;
                                    shippingController.text = '$mins';
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isSel ? const Color(0xFF2563EB) : AppColors.borderGray),
                                  ),
                                  child: Text(
                                    '$mins min',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      color: isSel ? Colors.white : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Dispatch Slip Thermal Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(child: Text('HUNGRY HOWIE\'S DISPATCH SLIP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                          const Center(child: Text('Rider Delivery Gate Pass', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold))),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #: ${del.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Rider: ${del.riderName ?? 'UNASSIGNED'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Customer: ${del.customerName} (${del.customerPhone})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Delivery Address: ${del.deliveryAddress}', style: const TextStyle(fontSize: 11)),
                          Text('Dispatched At: $dispatchTime', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),

                          // Dynamic Shipping Time Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 5),
                                    Text('SHIPPING TIME: $shippingMinutes MINS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF1D4ED8))),
                                  ],
                                ),
                                Text(
                                  'Est. Arrival: $arrivalTime',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),

                          const Divider(height: 16),
                          const Text('ORDER ITEMS SUMMARY:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          const SizedBox(height: 4),
                          Text('• ${del.itemsSummary}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('CASH TO COLLECT FROM CUSTOMER:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                              Text(
                                'PKR ${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ],
                          ),
                          Text(
                            'Payment Status: ${del.paymentStatus == 'PAID' ? 'PAID ONLINE (DO NOT COLLECT)' : 'CASH ON DELIVERY (COLLECT RS/- ${grandTotal.toStringAsFixed(0)})'}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: del.paymentStatus == 'PAID' ? const Color(0xFF16A34A) : AppColors.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          ref.read(deliveryProvider.notifier).markBillPrinted(del.id);

                          // Physical Thermal Print to Attached Laptop Printer
                          await ReceiptPrinterService.printReceipt(
                            context: context,
                            receipt: ReceiptData.fromDeliveryOrder(
                              order: del,
                              type: ReceiptType.deliveryDispatch,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text('PRINT DISPATCH BILL ($shippingMinutes MINS)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Interactive Create Delivery Order Modal with Menu Selection
  void _openCreateDeliveryOrderDialog(BuildContext context, WidgetRef ref, bool isDark, [DeliveryOrder? existingOrder]) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => _CreateDeliveryOrderDialog(isDark: isDark, ref: ref, existingOrder: existingOrder),
    );
  }

  Widget _buildRidersTab(DeliveryState state, bool isDark) {
    final notifier = ref.read(deliveryProvider.notifier);
    final authState = ref.watch(authProvider);
    final isSalesman = authState.currentUser.role == UserRole.cashier;
    final onDutyCount = state.riders.where((r) => r.isClockedIn).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header toolbar for Riders Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.two_wheeler_rounded, color: AppColors.primaryRed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'DELIVERY RIDERS FLEET',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$onDutyCount ON DUTY / ${state.riders.length} TOTAL',
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (!isSalesman)
              ElevatedButton.icon(
                onPressed: () => _openAddRiderDialog(context, notifier, isDark),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('REGISTER NEW RIDER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Riders Grid View
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 140,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: state.riders.length,
            itemBuilder: (context, index) {
              final rider = state.riders[index];
              // Check if rider has active orders assigned
              final activeOrder = state.deliveries.firstWhere(
                (d) => d.riderId == rider.id && d.status != DeliveryStatus.delivered,
                orElse: () => DeliveryOrder(
                  id: '',
                  orderId: '',
                  orderNumber: '',
                  customerName: '',
                  customerPhone: '',
                  deliveryAddress: '',
                  status: DeliveryStatus.pending,
                  createdAt: DateTime.now(),
                  estimatedDeliveryTime: DateTime.now(),
                ),
              );
              final hasActiveAssignment = activeOrder.id.isNotEmpty;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: rider.isClockedIn
                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header: Avatar, Name, Phone & Status Badge
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: rider.isClockedIn
                                      ? [AppColors.primaryRed, const Color(0xFFDC2626)]
                                      : [const Color(0xFF64748B), const Color(0xFF475569)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (rider.isClockedIn ? AppColors.primaryRed : Colors.grey)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  rider.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: rider.isClockedIn ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rider.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    rider.phone,
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Duty Status Badge / Button
                        InkWell(
                          onTap: () => notifier.toggleRiderDuty(rider.id),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: rider.isClockedIn
                                  ? const Color(0xFFEBF7ED)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: rider.isClockedIn
                                    ? const Color(0xFF2E7D32)
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: rider.isClockedIn ? const Color(0xFF2E7D32) : const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  rider.isClockedIn ? 'ON DUTY' : 'OFF DUTY',
                                  style: TextStyle(
                                    color: rider.isClockedIn ? const Color(0xFF2E7D32) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Current Active Assignment Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: hasActiveAssignment
                            ? AppColors.primaryRed.withValues(alpha: 0.08)
                            : (rider.isClockedIn ? const Color(0xFFEBF7ED) : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasActiveAssignment
                              ? AppColors.primaryRed.withValues(alpha: 0.3)
                              : (rider.isClockedIn ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : Colors.transparent),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasActiveAssignment ? Icons.local_shipping_rounded : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: hasActiveAssignment ? AppColors.primaryRed : (rider.isClockedIn ? const Color(0xFF2E7D32) : AppColors.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasActiveAssignment
                                  ? 'Active: Order #${activeOrder.orderNumber}'
                                  : (rider.isClockedIn ? 'Idle • Ready for dispatch' : 'Clocked Out'),
                              style: TextStyle(
                                color: hasActiveAssignment
                                    ? AppColors.primaryRed
                                    : (rider.isClockedIn ? const Color(0xFF2E7D32) : AppColors.textMuted),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openAddRiderDialog(BuildContext context, DeliveryNotifier notifier, bool isDark) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_add_rounded, color: AppColors.primaryRed, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Register New Rider',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const Divider(height: 20),
              const SizedBox(height: 10),

              // Rider Name Field
              const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Hassan Ahmed',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Rider Phone Field
              const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  hintText: 'e.g. +92 300 1234567',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all rider details!'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }
                    final newRider = DeliveryRider(
                      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      isClockedIn: true,
                    );
                    notifier.addRider(newRider);
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rider ${newRider.name} registered successfully!'), backgroundColor: AppColors.success),
                    );
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('SAVE & REGISTER RIDER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
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
      ),
    );
  }



  void _showAssignRiderModal(
    BuildContext context,
    DeliveryNotifier notifier,
    DeliveryState state,
    DeliveryOrder del, {
    bool openDispatchBillOnSuccess = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onDutyRiders = state.riders.where((r) => r.isClockedIn).toList();
    final offDutyRiders = state.riders.where((r) => !r.isClockedIn).toList();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primaryRed, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ASSIGN / TRANSFER RIDER',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Order #${del.orderNumber} • ${del.customerName}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  const Divider(height: 20),

                  // Active ON DUTY Section
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AVAILABLE ON-DUTY RIDERS (${onDutyRiders.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: Color(0xFF16A34A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (onDutyRiders.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NO RIDERS CURRENTLY ON DUTY!',
                                  style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Off-duty riders cannot be assigned to orders. Please mark a rider ON DUTY in the Riders Fleet tab first.',
                                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ...onDutyRiders.map((r) {
                      final isCurrentAssigned = del.riderId == r.id;
                      final bgColor = isCurrentAssigned
                          ? const Color(0xFFEBF7ED)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
                      final borderColor = isCurrentAssigned
                          ? const Color(0xFF86EFAC)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: bgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: borderColor, width: 1.2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
                              child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFF16A34A), size: 20),
                            ),
                            title: Text(
                              r.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              r.phone,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: isCurrentAssigned
                                  ? null
                                  : () async {
                                      final success = await notifier.assignRider(del.id, r.id, r.name);
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                      if (success && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Rider ${r.name} assigned to Order #${del.orderNumber}! Status: Out for Delivery.'),
                                            backgroundColor: const Color(0xFF16A34A),
                                          ),
                                        );
                                        if (openDispatchBillOnSuccess) {
                                          final updatedDel = del.copyWith(
                                            riderId: r.id,
                                            riderName: r.name,
                                            status: DeliveryStatus.outForDelivery,
                                          );
                                          _showDispatchBillModal(context, updatedDel, isDark);
                                        }
                                      }
                                    },
                              icon: Icon(isCurrentAssigned ? Icons.check_circle_rounded : Icons.send_rounded, size: 14),
                              label: Text(isCurrentAssigned ? 'Assigned' : 'Dispatch'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFBBF7D0),
                                disabledForegroundColor: const Color(0xFF166534),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],

                  // OFF DUTY Section (Disabled / Blocked)
                  if (offDutyRiders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'OFF-DUTY RIDERS (BLOCKED FROM ASSIGNMENT)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...offDutyRiders.map((r) {
                      final offBgColor = isDark ? const Color(0xFF141E2E).withValues(alpha: 0.5) : const Color(0xFFF1F5F9).withValues(alpha: 0.7);
                      final offBorderColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: offBgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: offBorderColor),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              child: const Icon(Icons.person_off_rounded, color: Colors.grey, size: 18),
                            ),
                            title: Text(
                              r.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                              ),
                            ),
                            subtitle: Text(
                              '${r.phone} • OFF DUTY',
                              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'OFF DUTY',
                                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Dialog for Creating / Editing Delivery Order with Menu Selection
class _CreateDeliveryOrderDialog extends StatefulWidget {
  final bool isDark;
  final WidgetRef ref;
  final DeliveryOrder? existingOrder;

  const _CreateDeliveryOrderDialog({
    required this.isDark,
    required this.ref,
    this.existingOrder,
  });

  @override
  State<_CreateDeliveryOrderDialog> createState() => _CreateDeliveryOrderDialogState();
}

class _CreateDeliveryOrderDialogState extends State<_CreateDeliveryOrderDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _feeController = TextEditingController(text: '150');
  double _deliveryFee = 150.0;
  String _paymentMethod = 'Cash on Delivery';

  String _selectedCategory = 'All';

  final List<Map<String, dynamic>> _menuItems = const [
    // Deals
    {'name': 'EXCLUSIVE DEALS (Pizza+Biryani+Panini+Shakes+Bottle)', 'price': 2499.0, 'cat': 'Deals', 'image': 'assets/images/image.jpg'},
    {'name': 'Family Feast Combo Deal (2 Family Pizzas + 4 Broast + Loaded Fries + 1.5L Coke)', 'price': 3299.0, 'cat': 'Deals', 'image': 'assets/images/Special.png'},
    {'name': 'Duo Craver Pack (2 Gourmet Burgers + Garlic Fries + 2 Drinks)', 'price': 1649.0, 'cat': 'Deals', 'image': 'assets/images/beef_burger_hero.jpg'},
    {'name': 'Midnight Craving Deal (1 Large Pizza + Cheesy Panini + 2 Drinks)', 'price': 1999.0, 'cat': 'Deals', 'image': 'assets/images/Pizza.png'},
    {'name': 'Student Saver Deal (1 Zinger Burger + Plain Fries + 1 Drink)', 'price': 749.0, 'cat': 'Deals', 'image': 'assets/images/chicken_burger_hero.jpg'},

    // Pizzas
    {'name': 'Classic Fajita Pizza (Small)', 'price': 849.0, 'cat': 'Pizza', 'image': 'assets/images/Fajita.png'},
    {'name': 'Classic Fajita Pizza (Medium)', 'price': 1449.0, 'cat': 'Pizza', 'image': 'assets/images/Fajita.png'},
    {'name': 'Classic Fajita Pizza (Large)', 'price': 1749.0, 'cat': 'Pizza', 'image': 'assets/images/Fajita.png'},
    {'name': 'Classic Fajita Pizza (Family)', 'price': 2349.0, 'cat': 'Pizza', 'image': 'assets/images/Fajita.png'},
    {'name': 'Modern Crown Crust (Medium)', 'price': 1549.0, 'cat': 'Pizza', 'image': 'assets/images/Modern.png'},
    {'name': 'Modern Crown Crust (Large)', 'price': 1999.0, 'cat': 'Pizza', 'image': 'assets/images/Modern.png'},
    {'name': 'Special Arabic Crispy (Medium)', 'price': 1699.0, 'cat': 'Pizza', 'image': 'assets/images/Special.png'},
    {'name': 'Special Hungry Cheese Gold (Large)', 'price': 2199.0, 'cat': 'Pizza', 'image': 'assets/images/Special.png'},

    // Steaks
    {'name': 'Tarragon Chicken Steak', 'price': 1499.0, 'cat': 'Steak', 'image': 'assets/images/chicken_steak.png'},
    {'name': 'Mushroom Chicken Steak', 'price': 1499.0, 'cat': 'Steak', 'image': 'assets/images/chicken_steak.png'},
    {'name': 'Twin Chicken Steak', 'price': 1599.0, 'cat': 'Steak', 'image': 'assets/images/chicken_steak.png'},
    {'name': 'Smoked BBQ Chicken Steak', 'price': 1499.0, 'cat': 'Steak', 'image': 'assets/images/chicken_steak.png'},
    {'name': 'Hot Shot Jalapeno Steak', 'price': 1499.0, 'cat': 'Steak', 'image': 'assets/images/chicken_steak.png'},

    // Burgers
    {'name': 'Beef Cheese Stuff Burger', 'price': 1349.0, 'cat': 'Burger', 'image': 'assets/images/beef_burger_hero.jpg'},
    {'name': 'Hungry Stacker Beef Burger', 'price': 1349.0, 'cat': 'Burger', 'image': 'assets/images/beef_burger_hero.jpg'},
    {'name': 'The Smashroom Beef Burger', 'price': 1099.0, 'cat': 'Burger', 'image': 'assets/images/beef_burger_hero.jpg'},
    {'name': 'Hungry Special Chicken Burger', 'price': 899.0, 'cat': 'Burger', 'image': 'assets/images/chicken_burger_hero.jpg'},
    {'name': 'Crispy BBQ Chicken Burger', 'price': 999.0, 'cat': 'Burger', 'image': 'assets/images/chicken_burger_hero.jpg'},
    {'name': 'Zinger Burger', 'price': 499.0, 'cat': 'Burger', 'image': 'assets/images/chicken_burger_hero.jpg'},
    {'name': 'Student Burger', 'price': 450.0, 'cat': 'Burger', 'image': 'assets/images/chicken_burger_hero.jpg'},

    // Broast
    {'name': 'Half Dajjaj Broast (with Fries)', 'price': 1250.0, 'cat': 'Broast', 'image': 'assets/images/broast_hero.jpg'},
    {'name': 'Family Dajjaj Broast (with Fries)', 'price': 2400.0, 'cat': 'Broast', 'image': 'assets/images/broast_hero.jpg'},

    // Pasta
    {'name': 'Chicken Alfredo Pasta', 'price': 999.0, 'cat': 'Pasta', 'image': 'assets/images/pasta_hero.jpg'},
    {'name': 'Penne Arrabiata Pasta', 'price': 999.0, 'cat': 'Pasta', 'image': 'assets/images/penne.png'},
    {'name': 'Hungry Parmesan Pasta', 'price': 1099.0, 'cat': 'Pasta', 'image': 'assets/images/Permission.png'},

    // Panini
    {'name': 'Cheesy Panini Sandwich', 'price': 1099.0, 'cat': 'Panini', 'image': 'assets/images/panini_hero.jpg'},
    {'name': 'Hungry Club Panini', 'price': 849.0, 'cat': 'Panini', 'image': 'assets/images/panini_hero.jpg'},
    {'name': 'Special BBQ Panini', 'price': 849.0, 'cat': 'Panini', 'image': 'assets/images/panini_hero.jpg'},

    // Appetizer
    {'name': 'Nuggets (with Fries) - 6pcs', 'price': 399.0, 'cat': 'Appetizer', 'image': 'assets/images/Nuggets.png'},
    {'name': 'Crispy Wings - 6pcs', 'price': 399.0, 'cat': 'Appetizer', 'image': 'assets/images/Wings.png'},
    {'name': 'Peri-Peri Wings (6pcs)', 'price': 499.0, 'cat': 'Appetizer', 'image': 'assets/images/peri.png'},
    {'name': 'Honey BBQ Wings (6pcs)', 'price': 499.0, 'cat': 'Appetizer', 'image': 'assets/images/Honey.png'},

    // Fries
    {'name': 'Hungry Loaded Fries', 'price': 749.0, 'cat': 'Fries', 'image': 'assets/images/Loaded.png'},
    {'name': 'Honey Mustard Fries', 'price': 449.0, 'cat': 'Fries', 'image': 'assets/images/Mustard.png'},

    // Drinks
    {'name': 'Fresh Lime Soft Drink', 'price': 250.0, 'cat': 'Drinks', 'image': 'assets/images/FreshLime.png'},
    {'name': 'NR Coke', 'price': 100.0, 'cat': 'Drinks', 'image': 'assets/images/Coke.png'},
    {'name': 'Coke Tin Pack', 'price': 160.0, 'cat': 'Drinks', 'image': 'assets/images/CokeTin.png'},
    {'name': 'Mineral Water', 'price': 80.0, 'cat': 'Drinks', 'image': 'assets/images/Mineral.png'},

    // Desserts
    {'name': 'Kulfa Ice Cream (Single)', 'price': 199.0, 'cat': 'Dessert', 'image': 'assets/images/ice_cream_hero.jpg'},
    {'name': 'Kulfa Ice Cream (Double)', 'price': 399.0, 'cat': 'Dessert', 'image': 'assets/images/ice_cream_hero.jpg'},
    {'name': 'Pina Colada Mocktail', 'price': 650.0, 'cat': 'Dessert', 'image': 'assets/images/pina.png'},
    {'name': 'Blueberry Mojito', 'price': 450.0, 'cat': 'Dessert', 'image': 'assets/images/blueBerry.png'},
    {'name': 'Chocolate Ice Shake', 'price': 590.0, 'cat': 'Dessert', 'image': 'assets/images/ChocolateI.png'},
  ];

  final Map<String, int> _cart = {};
  final Map<String, double> _customItemPrices = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      final ord = widget.existingOrder!;
      _nameController.text = ord.customerName;
      _phoneController.text = ord.customerPhone;
      _addressController.text = ord.deliveryAddress;
      _deliveryFee = ord.deliveryCharge;
      _feeController.text = ord.deliveryCharge.toStringAsFixed(0);
      _paymentMethod = ord.paymentMethod;

      if (ord.items.isNotEmpty) {
        for (final oi in ord.items) {
          if (oi.isCancelled) continue;
          _cart[oi.item.name] = oi.quantity;
          if (oi.unitPrice > 0) {
            _customItemPrices[oi.item.name] = oi.unitPrice;
          }
        }
      } else {
        // Parse existing items from itemsSummary
        final parts = ord.itemsSummary.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
        final regex = RegExp(r'^(\d+)x\s+(.+)$');
        for (final p in parts) {
          final match = regex.firstMatch(p);
          if (match != null) {
            final qty = int.tryParse(match.group(1)!) ?? 1;
            final name = match.group(2)!;
            _cart[name] = qty;
          } else {
            _cart[p] = 1;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  double get _itemsSubtotal {
    double sum = 0.0;
    _cart.forEach((itemName, qty) {
      double price = _customItemPrices[itemName] ?? 0.0;
      if (price <= 0.0) {
        final item = _menuItems.firstWhere(
          (m) => m['name'].toString().toLowerCase() == itemName.toLowerCase() ||
                 m['name'].toString().toLowerCase().contains(itemName.toLowerCase()) ||
                 itemName.toLowerCase().contains(m['name'].toString().toLowerCase()),
          orElse: () => {'name': itemName, 'price': 0.0},
        );
        price = ((item['price'] as num?)?.toDouble() ?? 0.0);
      }
      sum += price * qty;
    });
    return sum;
  }

  double get _totalBill => _itemsSubtotal + _deliveryFee;

  String get _itemsSummaryText {
    if (_cart.isEmpty) return 'No items selected';
    return _cart.entries.map((e) => '${e.value}x ${e.key}').join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isEditing = widget.existingOrder != null;
    final categories = ['All', 'Deals', 'Pizza', 'Steak', 'Burger', 'Broast', 'Pasta', 'Panini', 'Appetizer', 'Fries', 'Drinks', 'Dessert'];

    final filteredMenu = _menuItems.where((item) {
      if (_selectedCategory == 'All') return true;
      return item['cat'] == _selectedCategory;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.post_add_rounded : Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'EDIT & ADD ITEMS — #${widget.existingOrder!.orderNumber}' : 'CREATE NEW DELIVERY ORDER',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Split (Customer Form Left, Menu Selector & Cart Right)
            Expanded(
              child: Row(
                children: [
                  // Left Form: Customer & Delivery Info
                  Container(
                    width: 340,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CUSTOMER & DELIVERY DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Customer Full Name *', hintText: 'e.g. Hassan Ali'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Phone Number *', hintText: '0300-1234567'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _addressController,
                            maxLines: 2,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Delivery Address *', hintText: 'House #, Street #, Sector/Area'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _feeController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                            decoration: const InputDecoration(labelText: 'Delivery Fee (PKR )', hintText: '150', prefixText: 'PKR '),
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim()) ?? 0.0;
                              setState(() => _deliveryFee = parsed);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Panel: Menu Grid & Live Cart
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SELECT MENU ITEMS TO ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryRed)),
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
                          const SizedBox(height: 10),

                          // Menu Items Grid with Dish Images
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 3.8,
                              ),
                              itemCount: filteredMenu.length,
                              itemBuilder: (context, index) {
                                final item = filteredMenu[index];
                                final name = item['name'] as String;
                                final price = item['price'] as double;
                                final imagePath = item['image'] as String;
                                final qty = _cart[name] ?? 0;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          imagePath,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 44,
                                            height: 44,
                                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                                            child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.5,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'PKR ${price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.primaryRed,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (qty > 0) ...[
                                        if (!isEditing)
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (_cart[name]! > 1) {
                                                  _cart[name] = _cart[name]! - 1;
                                                } else {
                                                  _cart.remove(name);
                                                }
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryRed.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.remove_rounded, color: AppColors.primaryRed, size: 14),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            '$qty',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _cart[name] = (qty + 1);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Items: $_itemsSummaryText',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Subtotal: PKR ${_itemsSubtotal.toStringAsFixed(0)} + Delivery Fee: PKR ${_deliveryFee.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('TOTAL: PKR ${_totalBill.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final name = _nameController.text.trim();
                                final phone = _phoneController.text.trim();
                                final address = _addressController.text.trim();

                                if (name.isEmpty || phone.isEmpty || address.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please fill all customer details (Name, Phone, Address)!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                if (_cart.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add at least one menu item to the order!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                final itemsList = _cart.entries.map((e) {
                                  double price = _customItemPrices[e.key] ?? 0.0;
                                  if (price <= 0.0) {
                                    final matchItem = _menuItems.firstWhere(
                                      (m) => m['name'].toString().toLowerCase() == e.key.toLowerCase() ||
                                             m['name'].toString().toLowerCase().contains(e.key.toLowerCase()) ||
                                             e.key.toLowerCase().contains(m['name'].toString().toLowerCase()),
                                      orElse: () => {'name': e.key, 'price': 0.0},
                                    );
                                    price = ((matchItem['price'] as num?)?.toDouble() ?? 0.0);
                                  }
                                  return {
                                    'item_name': e.key,
                                    'quantity': e.value,
                                    'unit_price': price,
                                    'total_price': price * e.value,
                                    'selected_size': 'Regular',
                                    'selected_crust': 'Original',
                                  };
                                }).toList();

                                if (isEditing) {
                                  await widget.ref.read(deliveryProvider.notifier).updateDeliveryOrder(
                                    orderId: widget.existingOrder!.orderId.isNotEmpty ? widget.existingOrder!.orderId : widget.existingOrder!.id,
                                    customerName: name,
                                    customerPhone: phone,
                                    deliveryAddress: address,
                                    deliveryFee: _deliveryFee,
                                    subtotal: _itemsSubtotal,
                                    grandTotal: _totalBill,
                                    paymentMethod: _paymentMethod,
                                    itemsSummary: _itemsSummaryText,
                                    items: itemsList,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delivery Order #${widget.existingOrder!.orderNumber} updated successfully in database!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } else {
                                  final created = await widget.ref.read(deliveryProvider.notifier).createDeliveryOrder(
                                    customerName: name,
                                    customerPhone: phone,
                                    deliveryAddress: address,
                                    deliveryFee: _deliveryFee,
                                    subtotal: _itemsSubtotal,
                                    grandTotal: _totalBill,
                                    paymentMethod: _paymentMethod,
                                    paymentStatus: _paymentMethod == 'Paid Online' ? 'PAID' : 'UNPAID',
                                    itemsSummary: _itemsSummaryText,
                                    items: itemsList,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Delivery Order #${created.orderNumber} created and saved in database!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 18),
                              label: Text(isEditing ? 'SAVE & UPDATE ORDER (PKR ${_totalBill.toStringAsFixed(0)})' : 'CONFIRM & DISPATCH DELIVERY ORDER (PKR ${_totalBill.toStringAsFixed(0)})'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEditing ? const Color(0xFF2563EB) : AppColors.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
          ],
        ),
      ),
    );
  }
}

class _DeliveryOrderCardItem extends StatelessWidget {
  final DeliveryOrder del;
  final DeliveryNotifier notifier;
  final bool isDark;
  final WidgetRef ref;
  final bool isSelected;
  final VoidCallback? onSelect;
  final Function(BuildContext, DeliveryOrder, bool) onShowKitchenReceipt;
  final Function(BuildContext, DeliveryOrder, bool) onShowFinalBill;
  final Function(BuildContext, DeliveryOrder, bool) onShowDispatchBill;
  final Function(BuildContext, DeliveryNotifier, DeliveryState, DeliveryOrder) onAssignRider;

  const _DeliveryOrderCardItem({
    required this.del,
    required this.notifier,
    required this.isDark,
    required this.ref,
    this.isSelected = false,
    this.onSelect,
    required this.onShowKitchenReceipt,
    required this.onShowFinalBill,
    required this.onShowDispatchBill,
    required this.onAssignRider,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivered = del.status == DeliveryStatus.delivered;
    final isPaid = del.paymentStatus == 'PAID';
    final isOnlineOrder = del.orderSource == 'Online Orders';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryRed
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primaryRed.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect?.call(),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Rider / Delivery Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOnlineOrder
                        ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                        : AppColors.primaryRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOnlineOrder ? Icons.cloud_download_rounded : Icons.two_wheeler_rounded,
                    color: isOnlineOrder ? const Color(0xFF0284C7) : AppColors.primaryRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Order #, Customer, Badges & Address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Order ${del.orderNumber}',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),

                          // Order Source Badge (Online Orders vs Direct Delivery)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOnlineOrder
                                  ? (isDark ? const Color(0xFF0369A1).withValues(alpha: 0.25) : const Color(0xFFE0F2FE))
                                  : (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.25) : const Color(0xFFF3E8FF)),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOnlineOrder ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOnlineOrder ? Icons.language_rounded : Icons.storefront_rounded,
                                  size: 11,
                                  color: isOnlineOrder ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isOnlineOrder ? 'ONLINE ORDER' : 'DIRECT DELIVERY',
                                  style: TextStyle(
                                    color: isOnlineOrder ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Payment Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFFEBF7ED) : const Color(0xFFFDF0F0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isPaid ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                              ),
                            ),
                            child: Text(
                              isPaid ? 'PAID (${del.paymentMethod})' : 'UNPAID (${del.paymentMethod})',
                              style: TextStyle(
                                color: isPaid ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Delivery Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDelivered ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              del.status.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            del.customerName.isEmpty ? 'Walk-in Customer' : del.customerName,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '  •  ',
                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted),
                          ),
                          Icon(
                            Icons.delivery_dining_rounded,
                            size: 14,
                            color: del.riderName != null ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            del.riderName != null ? 'Rider: ${del.riderName}' : 'Unassigned Rider',
                            style: TextStyle(
                              color: del.riderName != null ? const Color(0xFF2E7D32) : AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              del.deliveryAddress.isEmpty ? 'No address specified' : del.deliveryAddress,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Amount & View Details Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${del.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: AppColors.primaryRed,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
  required bool isDark,
  bool isHighlight = false,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 15,
        color: isHighlight ? AppColors.primaryRed : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 125,
        child: Text(
          '$label:',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            color: isHighlight
                ? (isDark ? Colors.white : AppColors.textPrimary)
                : (isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary),
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Delivery Full Bill & Cash Calculator Dialog
// ---------------------------------------------------------------------------
class _DeliveryFullBillCalculatorDialog extends StatefulWidget {

  final BuildContext parentContext;
  final WidgetRef ref;
  final DeliveryOrder delivery;
  final DeliveryNotifier notifier;
  final bool isDark;

  const _DeliveryFullBillCalculatorDialog({
    required this.parentContext,
    required this.ref,
    required this.delivery,
    required this.notifier,
    required this.isDark,
  });

  @override
  State<_DeliveryFullBillCalculatorDialog> createState() => _DeliveryFullBillCalculatorDialogState();
}

class _DeliveryFullBillCalculatorDialogState extends State<_DeliveryFullBillCalculatorDialog> {
  final TextEditingController _cashController = TextEditingController();
  double _cashGiven = 5000.0;

  @override
  void initState() {
    super.initState();
    final taxAmount = widget.delivery.totalAmount * 0.05;
    final grandTotal = widget.delivery.totalAmount + widget.delivery.deliveryCharge + taxAmount;
    final defaultAmount = grandTotal > 5000 ? grandTotal : 5000.0;
    _cashGiven = defaultAmount;
    _cashController.text = defaultAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _setCash(double amount) {
    setState(() {
      _cashGiven = amount;
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taxAmount = widget.delivery.totalAmount * 0.05;
    final netTotal = widget.delivery.totalAmount + widget.delivery.deliveryCharge + taxAmount;
    final changeReturn = _cashGiven - netTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
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
                        Navigator.pop(context); // Close calculator dialog
                        showDialog(
                          context: widget.parentContext,
                          barrierColor: Colors.black.withValues(alpha: 0.8),
                          builder: (tenderContext) => _DeliveryPaymentTenderDialog(
                            parentContext: widget.parentContext,
                            ref: widget.ref,
                            delivery: widget.delivery,
                            notifier: widget.notifier,
                            grandTotal: netTotal,
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
                      onPressed: () {
                        widget.notifier.updatePaymentStatus(widget.delivery.id, 'PAID', paymentMethod: 'Cash');
                        Navigator.pop(context);

                        // Show Final Paid Receipt Dialog with Cash & Change Details
                        _showDeliveryFinalPaidReceiptDialog(
                          widget.parentContext,
                          widget.delivery,
                          netTotal,
                          changeReturn >= 0 ? changeReturn : 0.0,
                          widget.isDark,
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
// Delivery Payment Tender / Multi-Tender Information Dialog
// ---------------------------------------------------------------------------
class _DeliveryPaymentTenderDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final DeliveryOrder delivery;
  final DeliveryNotifier notifier;
  final double grandTotal;
  final bool isDark;

  const _DeliveryPaymentTenderDialog({
    required this.parentContext,
    required this.ref,
    required this.delivery,
    required this.notifier,
    required this.grandTotal,
    required this.isDark,
  });

  @override
  State<_DeliveryPaymentTenderDialog> createState() => _DeliveryPaymentTenderDialogState();
}

class _DeliveryPaymentTenderDialogState extends State<_DeliveryPaymentTenderDialog> {
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
    return _totalPayment - widget.grandTotal;
  }

  void _completePayment({bool printReceipt = true}) {
    widget.notifier.updatePaymentStatus(widget.delivery.id, 'PAID', paymentMethod: 'Tender Settled');
    Navigator.pop(context);

    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text('Payment of PKR ${_totalPayment.toStringAsFixed(0)} tendered for #${widget.delivery.orderNumber} (${widget.delivery.customerName})!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );

    if (printReceipt) {
      _showDeliveryFinalPaidReceiptDialog(
        widget.parentContext,
        widget.delivery,
        widget.grandTotal,
        _change > 0 ? _change : 0.0,
        widget.isDark,
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
                        'Delivery Payment Tender - #${widget.delivery.orderNumber}',
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
                              widget.grandTotal.toStringAsFixed(2),
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
                            setState(() => _cashController.text = widget.grandTotal.toStringAsFixed(2));
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
                            setState(() => _creditController.text = widget.grandTotal.toStringAsFixed(2));
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
                        _cashController.text = widget.grandTotal.toStringAsFixed(2);
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
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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

  Widget _buildNumericField(TextEditingController controller, bool isDark, {required VoidCallback onExact}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: onExact,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: const Text('Exact', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildBankRow(
    String machineName,
    TextEditingController amountCtrl,
    String selectedType,
    ValueChanged<String?> onTypeChanged,
    TextEditingController cardNoCtrl,
    TextEditingController holderCtrl,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              machineName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isDense: true,
                  items: ['Bank Transfer', 'EasyPaisa', 'JazzCash', 'Visa', 'MasterCard']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11))))
                      .toList(),
                  onChanged: onTypeChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: cardNoCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'Txn / Card #',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: holderCtrl,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'Holder / Account Name',
                  hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery Final Paid Receipt Dialog
// ---------------------------------------------------------------------------
void _showDeliveryFinalPaidReceiptDialog(
  BuildContext context,
  DeliveryOrder del,
  double grandTotal,
  double changeReturned,
  bool isDark,
) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
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
                        'DELIVERY PAID RECEIPT',
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
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "HUNGRY HOWIES",
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DELIVERY TAX INVOICE • PAID (${del.orderSource})',
                          style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),

                    // Order Number & Customer
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary)),
                          Text('#${del.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Customer:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                          Text('${del.customerName} (${del.customerPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Address:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                          Expanded(
                            child: Text(
                              del.deliveryAddress,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (del.riderName != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rider:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                            Text(del.riderName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    const Divider(),
                    const SizedBox(height: 4),

                    // Items Subtotal & Delivery
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Subtotal:', style: TextStyle(fontSize: 12)),
                        Text('PKR ${del.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Fee:', style: TextStyle(fontSize: 12)),
                        Text('PKR ${del.deliveryCharge.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(),
                    const SizedBox(height: 4),

                    // Total Bill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('NET TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(
                          'PKR ${grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 18),
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
                              style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                            Text(
                              'PKR ${changeReturned.toStringAsFixed(0)}',
                              style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dialogContext);

                    // Physical Thermal Print to Attached Laptop Printer
                    await ReceiptPrinterService.printReceipt(
                      context: context,
                      receipt: ReceiptData.fromDeliveryOrder(
                        order: del,
                        type: ReceiptType.customerReceipt,
                        paymentMethod: del.paymentMethod.toUpperCase(),
                        tenderedAmount: grandTotal + changeReturned,
                        changeReturned: changeReturned,
                      ),
                    );
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
      );
    },
  );
}


// ---------------------------------------------------------------------------
// Cancel Delivery Item Modal
// ---------------------------------------------------------------------------
class _CancelDeliveryItemModal extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final DeliveryOrder order;
  final bool isDark;

  const _CancelDeliveryItemModal({
    required this.parentContext,
    required this.ref,
    required this.order,
    required this.isDark,
  });

  @override
  State<_CancelDeliveryItemModal> createState() => _CancelDeliveryItemModalState();
}

class _CancelDeliveryItemModalState extends State<_CancelDeliveryItemModal> {
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
    'Customer Cancelled Order',
    'Ordered by Mistake',
    'Kitchen Delay',
    'Customer Address Unreachable',
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
      final effectiveOrderId = widget.order.orderId.isNotEmpty ? widget.order.orderId : widget.order.id;
      final data = await widget.ref.read(ordersApiServiceProvider).getOrderById(effectiveOrderId);
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
      debugPrint('⚠️ Error fetching items in delivery cancel modal: $e');
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
      final orderId = widget.order.orderId.isNotEmpty ? widget.order.orderId : widget.order.id;
      final currentUser = widget.ref.read(authProvider).currentUser;
      final cashierName = currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Cashier';
      final ordersApi = widget.ref.read(ordersApiServiceProvider);

      // Check if ALL active items in this delivery order are being cancelled
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

      // If all active items are cancelled, mark the entire delivery order as cancelled
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
          orderNumber: widget.order.orderNumber,
          tokenNumber: widget.order.orderNumber,
        );
      }

      // Reload delivery data from backend
      await widget.ref.read(deliveryProvider.notifier).loadDeliveryData();

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
                      ? 'Delivery order #${widget.order.orderNumber} fully cancelled.'
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
                            'Order: #${widget.order.orderNumber} • Tap [-] on items to cancel quantity',
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
                            'No items in this delivery order.',
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
