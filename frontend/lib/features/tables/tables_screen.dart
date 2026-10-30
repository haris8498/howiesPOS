import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../data/table_repository.dart';
import '../../domain/models/restaurant_table.dart';
import '../../core/sync/pricing_reconciliation_provider.dart';
import '../../shared/widgets/manager_approval_dialog.dart';
import '../../domain/models/user_role.dart';
import '../../services/api/api_providers.dart';
import '../../services/printer/escpos_builder.dart';
import '../../services/receipt_printer_service.dart';
import '../../shared/widgets/confirm_delete_dialog.dart';
import '../../shared/widgets/cashier_sidebar_footer.dart';
import 'package:uuid/uuid.dart';
import '../../config/feature_flags.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/table_reassignment_provider.dart';
import '../../data/repositories/order_repository_provider.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/order_model.dart';
import '../updater/open_order_guard_provider.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTableId;
  String? _activeDetailTableId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableProvider.notifier).loadTables();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  RestaurantTable? _getSelectedTable(List<RestaurantTable> tables) {
    if (tables.isEmpty) return null;
    if (_selectedTableId != null) {
      final found = tables.where((t) => t.id == _selectedTableId).firstOrNull;
      if (found != null) return found;
    }
    return tables.where((t) => t.status == TableStatus.occupied).firstOrNull ?? tables.firstOrNull;
  }

  Widget _buildTableActionPillButton({
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

  // Full Screen Table Order Details View (With Left Action Sidebar)
  Widget _buildFullTableOrderScreen(
    BuildContext context,
    RestaurantTable table,
    bool isDark,
    TableState tableState,
    TableNotifier tableNotifier,
  ) {
    final rawTicketId = (table.activeOrderNumber != null && table.activeOrderNumber!.isNotEmpty)
        ? table.activeOrderNumber!
        : (table.activeOrderId ?? table.tableNumber);
    final displayTicketId = EscPosBuilder.format3DigitOrderNumber(rawTicketId);
    final bool isOccupied = table.status == TableStatus.occupied;
    final orderItems = table.currentOrderItems;

    final isCashier = ref.watch(authProvider).currentUser.role == UserRole.cashier;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.0, 18.0, 18.0, isCashier ? 0.0 : 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCashier) ...[
            // 1. Left Action Column (Sidebar - Cashier only)
            SizedBox(
              width: 230,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  _buildTableActionPillButton(
                    title: isOccupied ? 'Edit / Modify Order' : 'Add Order',
                    icon: Icons.edit_note_rounded,
                    color: const Color(0xFF9333EA),
                    isFilled: false,
                    isDark: isDark,
                    onTap: () => _openTableOrderMenuDialog(context, ref, table, isDark),
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Kitchen (KOT)',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFFD97706),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: isOccupied || orderItems.isNotEmpty,
                    onTap: () {
                      if (!isOccupied && orderItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${table.name}" has no active kitchen order ticket.')),
                        );
                        return;
                      }
                      _showKitchenReceiptDialog(context, table, isDark);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Customer Bill',
                    icon: Icons.description_rounded,
                    color: const Color(0xFF2563EB),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: isOccupied || orderItems.isNotEmpty,
                    onTap: () {
                      if (!isOccupied && orderItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${table.name}" has no active bill.')),
                        );
                        return;
                      }
                      _showCustomerBillDialog(context, table, isDark);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Cancel Item',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    isFilled: false,
                    isDark: isDark,
                    isEnabled: isOccupied && orderItems.any((i) => i['is_cancelled'] != true && i['is_cancelled'] != 1),
                    onTap: () {
                      _showCancelTableItemDialog(context, ref, table, isDark);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Full Bill & Pay',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFFDC2626),
                    isFilled: true,
                    isDark: isDark,
                    isEnabled: isOccupied || orderItems.isNotEmpty,
                    onTap: () {
                      if (!isOccupied && orderItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${table.name}" has no active bill to settle.')),
                        );
                        return;
                      }
                      _showFullBillDialog(context, ref, table, isDark);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Return to Floor Plan Button
                  InkWell(
                    onTap: () => setState(() => _activeDetailTableId = null),
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
                            'View All Tables',
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

          // Bottom Tools: Margin bottom 0
          const CashierSidebarFooter(),
        ],
      ),
    ),

            const SizedBox(width: 18),
          ],

    // 2. Main Order Details Area (Full Screen view)
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Top Header Row with Table Title, Status, and Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              table.name.toUpperCase(),
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (table.isDeleted) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'REMOVED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOccupied ? AppColors.brandYellow : const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOccupied ? 'OCCUPIED' : (table.status == TableStatus.reserved ? 'RESERVED' : 'FREE'),
                                style: TextStyle(
                                  color: isOccupied ? AppColors.deepRed : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Section: ${table.section.isEmpty ? "General" : table.section} • Capacity: ${table.capacity} Seats ${isOccupied ? "• Ticket #$displayTicketId" : ""}',
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

                const SizedBox(height: 16),

                // Order Content Section
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
                    child: isOccupied || orderItems.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Stats Header Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryRed, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Order Ticket #$displayTicketId',
                                              style: TextStyle(
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Total items: ${orderItems.length}',
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('Current Total: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            'PKR ${table.currentBillAmount.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: AppColors.primaryRed,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Items Header
                              Text(
                                'ORDER ITEMS LIST',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Items List
                              Expanded(
                                child: orderItems.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No detailed item breakdown recorded for this order.',
                                          style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary),
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: orderItems.length,
                                        itemBuilder: (ctx, idx) {
                                          final item = orderItems[idx];
                                          final name = item['name']?.toString() ?? 'Item';
                                          final qty = item['quantity']?.toString() ?? '1';
                                          final price = (item['price'] is num)
                                              ? (item['price'] as num).toDouble()
                                              : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
                                           final itemTotal = (item['total'] is num)
                                              ? (item['total'] as num).toDouble()
                                              : (price * (int.tryParse(qty) ?? 1));
                                            final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
                                            final cancelReason = item['cancel_reason']?.toString();

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isCancelled
                                                    ? (isDark ? const Color(0xFF1F1111) : const Color(0xFFFFF5F5))
                                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isCancelled
                                                      ? AppColors.primaryRed.withValues(alpha: 0.35)
                                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isCancelled
                                                          ? AppColors.primaryRed.withValues(alpha: 0.15)
                                                          : AppColors.primaryRed,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: isCancelled
                                                          ? Border.all(color: AppColors.primaryRed.withValues(alpha: 0.4))
                                                          : null,
                                                    ),
                                                    child: Text(
                                                      isCancelled ? '-${qty}x' : '${qty}x',
                                                      style: TextStyle(
                                                        color: isCancelled ? AppColors.primaryRed : Colors.white,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 12,
                                                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                        decorationColor: AppColors.primaryRed,
                                                        decorationThickness: 2,
                                                      ),
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
                                                                name,
                                                                style: TextStyle(
                                                                  color: isCancelled
                                                                      ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                                                      : (isDark ? Colors.white : AppColors.textPrimary),
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 14,
                                                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                                  decorationColor: AppColors.primaryRed,
                                                                  decorationThickness: 2,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (isCancelled && cancelReason != null && cancelReason.isNotEmpty)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2),
                                                            child: Text(
                                                              'Reason: $cancelReason',
                                                              style: const TextStyle(
                                                                color: AppColors.primaryRed,
                                                                fontSize: 11,
                                                                fontStyle: FontStyle.italic,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        if (item['notes'] != null && item['notes'].toString().isNotEmpty && !isCancelled)
                                                          Text(
                                                            'Note: ${item['notes']}',
                                                            style: const TextStyle(
                                                              color: Color(0xFFD97706),
                                                              fontSize: 11.5,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'PKR ${itemTotal.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: isCancelled
                                                          ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                      decorationColor: AppColors.primaryRed,
                                                      decorationThickness: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),

                                const SizedBox(height: 14),

                                // Bill Breakdown Summary Bar
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Payable Amount:',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      'PKR ${table.currentBillAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.primaryRed,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEBF7ED),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 48),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${table.name} is FREE',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No active orders. Tap below to place a new dine-in order for this table.',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => _openTableOrderMenuDialog(context, ref, table, isDark),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                  label: const Text('Start Dine-In Order'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
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
  );
}

  @override
  Widget build(BuildContext context) {
    final tableState = ref.watch(tableProvider);
    final tableNotifier = ref.read(tableProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tableReassignments = ref.watch(tableReassignmentNotificationProvider);

    // If a table is active/opened, render the Full Screen Table Order Details view (Not in pop-up)
    if (_activeDetailTableId != null) {
      final activeTable = tableState.tables.where((t) => t.id == _activeDetailTableId).firstOrNull;
      if (activeTable != null) {
        return _buildFullTableOrderScreen(context, activeTable, isDark, tableState, tableNotifier);
      }
    }

    final allZones = {...tableState.zones, ...tableState.tables.map((t) => t.section).where((s) => s.isNotEmpty)};
    final sections = ['All', ...allZones, 'Free', 'Occupied', 'Reserved'];

    final filteredTables = tableState.tables.where((t) {
      // SYNC-012/TBL-12: On tombstone pull, hide table from grid unless local open order exists on it
      if (t.isDeleted) {
        final hasOpenOrder = t.status == TableStatus.occupied || (t.activeOrderId != null && t.currentBillAmount > 0);
        if (!hasOpenOrder) return false;
      }
      // D-01: Auto-hide empty/closed overflow tables
      if (t.isOverflow) {
        final hasActiveOrder = t.status == TableStatus.occupied || (t.activeOrderId != null && t.currentBillAmount > 0);
        if (!hasActiveOrder) return false;
      }

      final matchesSection = () {
        if (tableState.selectedSection == 'All') return true;
        if (tableState.selectedSection == 'Free') return t.status == TableStatus.available;
        if (tableState.selectedSection == 'Occupied') return t.status == TableStatus.occupied;
        if (tableState.selectedSection == 'Reserved') return t.status == TableStatus.reserved;
        return t.section == tableState.selectedSection;
      }();

      final matchesQuery = _searchQuery.isEmpty ||
          t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.tableNumber.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesSection && matchesQuery;
    }).toList();

    // D-01: Sort overflow tables immediately after their parent table
    filteredTables.sort((a, b) {
      final aBase = a.isOverflow && a.parentTableId != null
          ? (tableState.tables.where((t) => t.id == a.parentTableId).firstOrNull?.tableNumber ?? a.tableNumber.split('-').first)
          : a.tableNumber.split('-').first;
      final bBase = b.isOverflow && b.parentTableId != null
          ? (tableState.tables.where((t) => t.id == b.parentTableId).firstOrNull?.tableNumber ?? b.tableNumber.split('-').first)
          : b.tableNumber.split('-').first;

      if (aBase != bBase) {
        final aNum = int.tryParse(aBase);
        final bNum = int.tryParse(bBase);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return aBase.compareTo(bBase);
      }

      if (!a.isOverflow && b.isOverflow) return -1;
      if (a.isOverflow && !b.isOverflow) return 1;
      return a.tableNumber.compareTo(b.tableNumber);
    });

    final isCashier = ref.watch(authProvider).currentUser.role == UserRole.cashier;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.0, 18.0, 18.0, isCashier ? 0.0 : 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isCashier) ...[
            // 1. Left Action Column (Edit / Add Order, Kitchen Receipt, Customer Bill, Full Bill & Pay - Cashier only)
            SizedBox(
              width: 220,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  _buildTableActionPillButton(
                    title: 'Edit / Add Order',
                    icon: Icons.edit_note_rounded,
                    color: const Color(0xFF9333EA),
                    isFilled: false,
                    isDark: isDark,
                    onTap: () {
                      final selected = _getSelectedTable(tableState.tables);
                      if (selected != null) {
                        _openTableOrderMenuDialog(context, ref, selected, isDark);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select or create a table first.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Kitchen (KOT)',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFFD97706),
                    isFilled: false,
                    isDark: isDark,
                    onTap: () {
                      final selected = _getSelectedTable(tableState.tables);
                      if (selected == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a table.')),
                        );
                        return;
                      }
                      if (selected.status != TableStatus.occupied && selected.currentOrderItems.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${selected.name}" has no active kitchen order ticket.')),
                        );
                        return;
                      }
                      _showKitchenReceiptDialog(context, selected, isDark);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Customer Bill',
                    icon: Icons.description_rounded,
                    color: const Color(0xFF2563EB),
                    isFilled: false,
                    isDark: isDark,
                    onTap: () {
                      final selected = _getSelectedTable(tableState.tables);
                      if (selected == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a table.')),
                        );
                        return;
                      }
                      if (selected.status != TableStatus.occupied && selected.currentBillAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${selected.name}" has no active bill.')),
                        );
                        return;
                      }
                      _showCustomerBillDialog(context, selected, isDark);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildTableActionPillButton(
                    title: 'Full Bill & Pay',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFFDC2626),
                    isFilled: true,
                    isDark: isDark,
                    onTap: () {
                      final selected = _getSelectedTable(tableState.tables);
                      if (selected == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a table.')),
                        );
                        return;
                      }
                      if (selected.status != TableStatus.occupied && selected.currentBillAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Table "${selected.name}" has no active bill to settle.')),
                        );
                        return;
                      }
                      _showFullBillDialog(context, ref, selected, isDark);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Bottom Tools: Margin bottom 0
          const CashierSidebarFooter(),
        ],
      ),
    ),

            const SizedBox(width: 18),
          ],

    // 2. Right Main Floor Tables Area
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                // Header Row with Main Title & Add Table Button
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
                          child: const Icon(Icons.table_restaurant_rounded, color: AppColors.primaryRed, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FLOOR TABLES & DINE-IN CONTROL',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage restaurant floor layout, guest seating and live dine-in table orders',
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
                    Builder(
                      builder: (context) {
                        final userRole = ref.watch(authProvider).currentUser.role;
                        final canAddTable = ref.watch(roleRightsProvider).isActionGranted(
                          userRole,
                          'tables_add',
                          defaultIfMissing: true,
                        );
                        if (!canAddTable) return const SizedBox.shrink();
                        return ElevatedButton.icon(
                          onPressed: () => _openAddTableDialog(context, tableNotifier, isDark),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add New Table'),
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
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Compact Stat Overview Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'AVAILABLE TABLES',
                        value: '${tableState.availableCount}',
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        bgColor: const Color(0xFFEBF7ED),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'OCCUPIED TABLES',
                        value: '${tableState.occupiedCount}',
                        icon: Icons.restaurant_rounded,
                        iconColor: const Color(0xFFD32F2F),
                        bgColor: const Color(0xFFFDF0F0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'RESERVED TABLES',
                        value: '${tableState.reservedCount}',
                        icon: Icons.bookmark_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStatCard(
                        title: 'TOTAL TABLES',
                        value: '${tableState.tables.length}',
                        icon: Icons.grid_view_rounded,
                        iconColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Section Filter Chips & Table Search Bar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: sections.map((sec) {
                            final isSelected = tableState.selectedSection == sec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  sec,
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
                                onSelected: (_) => tableNotifier.setSection(sec),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Table Search Bar by Table Name or Number
                    SizedBox(
                      width: 240,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search table (e.g. Top 01)...',
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

                if (tableReassignments.isNotEmpty) ...[
                  for (final notif in tableReassignments)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E1A47) : const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A7C3AED),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              notif.message,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF581C87),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: const Color(0xFF7C3AED),
                            onPressed: () {
                              ref.read(tableReassignmentNotificationProvider.notifier).dismiss(notif);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
                // D-03 (SYNC-016): Pricing Reconciliation Notification Banner
                () {
                  final pricingNotifs = ref.watch(pricingReconciliationNotificationProvider);
                  if (pricingNotifs.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      for (final notif in pricingNotifs)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1AD97706),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  notif.message,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: const Color(0xFFD97706),
                                onPressed: () {
                                  ref.read(pricingReconciliationNotificationProvider.notifier).dismiss(notif);
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }(),

                // Visual Table Floor Plan Grid
                Expanded(
                  child: filteredTables.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.table_restaurant_rounded, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'No tables found matching your search',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filteredTables.length,
                          itemBuilder: (context, index) {
                            final table = filteredTables[index];
                            Color statusColor;
                            Color statusBgColor;
                            String statusLabel;

                            switch (table.status) {
                              case TableStatus.available:
                                statusColor = const Color(0xFF2E7D32);
                                statusBgColor = isDark ? const Color(0xFF142E18) : const Color(0xFFEBF7ED);
                                statusLabel = 'FREE';
                                break;
                              case TableStatus.occupied:
                                statusColor = const Color(0xFFD32F2F);
                                statusBgColor = isDark ? const Color(0xFF2E1414) : const Color(0xFFFDF0F0);
                                statusLabel = 'OCCUPIED';
                                break;
                              case TableStatus.reserved:
                                statusColor = const Color(0xFFD97706);
                                statusBgColor = isDark ? const Color(0xFF2E2414) : const Color(0xFFFFFBEB);
                                statusLabel = 'RESERVED';
                                break;
                            }

                            final userRole = ref.watch(authProvider).currentUser.role;
                            final bool isOwner = userRole == UserRole.owner;
                            final bool canDeleteTable = ref.watch(roleRightsProvider).isActionGranted(
                              userRole,
                              'tables_delete',
                              defaultIfMissing: isOwner,
                            );
                            final bool hasBill = table.status == TableStatus.occupied && table.currentBillAmount > 0;
                            final bool isSelected = _selectedTableId == table.id;

                            return Stack(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTableId = table.id;
                                      _activeDetailTableId = table.id;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryRed : (table.isOverflow ? const Color(0xFF7C3AED) : statusColor),
                                        width: isSelected ? 2.8 : (table.isOverflow ? 2.2 : 2.0),
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: (isSelected ? AppColors.primaryRed : statusColor).withValues(alpha: 0.25),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          table.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (hasBill)
                                          Text(
                                            'Bill: PKR ${table.currentBillAmount.toStringAsFixed(0)}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.primaryRed,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        else
                                          Text(
                                            '${table.capacity} Seats',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (table.isOverflow)
                                  Positioned(
                                    top: 8,
                                    left: isSelected ? 32 : (table.isDeleted ? 76 : 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x337C3AED),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.call_split_rounded, size: 10, color: Colors.white),
                                          SizedBox(width: 3),
                                          Text(
                                            'OVERFLOW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (table.isDeleted)
                                  Positioned(
                                    top: 8,
                                    left: isSelected ? 32 : 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'REMOVED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryRed,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                    ),
                                  ),
                                if (canDeleteTable)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () => _confirmDeleteTable(context, ref, table, isDark),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.danger,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
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

  // Table Order Details Screen / Dialog (Shows Full Order Details, Items & Quick Actions)
  // ignore: unused_element
  void _showTableOrderDetailsDialog(BuildContext context, WidgetRef ref, RestaurantTable table, bool isDark) {
    final rawTicketId = (table.activeOrderNumber != null && table.activeOrderNumber!.isNotEmpty)
        ? table.activeOrderNumber!
        : (table.activeOrderId ?? table.tableNumber);
    final displayTicketId = EscPosBuilder.format3DigitOrderNumber(rawTicketId);
    final bool isOccupied = table.status == TableStatus.occupied;
    final orderItems = table.currentOrderItems;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Brand Banner Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  table.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOccupied ? AppColors.brandYellow : const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isOccupied ? 'OCCUPIED' : (table.status == TableStatus.reserved ? 'RESERVED' : 'FREE'),
                                    style: TextStyle(
                                      color: isOccupied ? AppColors.deepRed : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Section: ${table.section.isEmpty ? "General" : table.section} • Capacity: ${table.capacity} Seats ${isOccupied ? "• Ticket #$displayTicketId" : ""}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
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

                // 2. Main Order Details Content Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOccupied || orderItems.isNotEmpty) ...[
                          // Order Summary Pill Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primaryRed),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Order Ticket #$displayTicketId',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Bill: PKR ${table.currentBillAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Ordered Items List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ORDERED ITEMS (${orderItems.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Price',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          if (orderItems.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Table is marked occupied with no saved item breakdown.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                              ),
                            )
                          else
                            ...orderItems.map((item) {
                              final name = item['name']?.toString() ?? 'Food Item';
                              final qty = item['quantity']?.toString() ?? '1';
                              final price = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
                              final itemTotal = (item['total'] is num) ? (item['total'] as num).toDouble() : (price * (int.tryParse(qty) ?? 1));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${qty}x',
                                        style: const TextStyle(
                                          color: AppColors.primaryRed,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                                            Text(
                                              'Note: ${item['notes']}',
                                              style: const TextStyle(
                                                color: Color(0xFFD97706),
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'PKR ${itemTotal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 14),

                          // Total Bill Breakdown Box
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Bill Amount:', style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('PKR ${table.currentBillAmount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 18)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Free / Empty Table Screen
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEBF7ED),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 36),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${table.name} is FREE',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No active orders on this table. You can start placing a dine-in order now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _openTableOrderMenuDialog(context, ref, table, isDark);
                                  },
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                  label: const Text('Start Dine-In Order'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Action Buttons Options
                        Text(
                          'ACTIONS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Action 1: Add / Modify Order
                        _buildActionOptionTile(
                          title: isOccupied ? 'Add Order / Modify Order' : 'Start / Create Order',
                          icon: Icons.add_shopping_cart_rounded,
                          iconColor: AppColors.primaryRed,
                          bgColor: AppColors.primaryRed.withValues(alpha: 0.1),
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(dialogContext);
                            _openTableOrderMenuDialog(context, ref, table, isDark);
                          },
                        ),

                        if (isOccupied) ...[
                          const SizedBox(height: 10),

                          // Action 2: Kitchen Receipt (KOT)
                          _buildActionOptionTile(
                            title: 'Kitchen Receipt (KOT)',
                            icon: Icons.soup_kitchen_rounded,
                            iconColor: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFFFBEB),
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showKitchenReceiptDialog(context, table, isDark);
                            },
                          ),

                          const SizedBox(height: 10),

                          // Action 3: Customer Bill
                          _buildActionOptionTile(
                            title: 'Customer Bill',
                            icon: Icons.description_rounded,
                            iconColor: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showCustomerBillDialog(context, table, isDark);
                            },
                          ),

                          const SizedBox(height: 10),

                          // Action: Cancel Order Item
                          _buildActionOptionTile(
                            title: 'Cancel Order Item',
                            icon: Icons.cancel_outlined,
                            iconColor: AppColors.danger,
                            bgColor: AppColors.danger.withValues(alpha: 0.1),
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showCancelTableItemDialog(context, ref, table, isDark);
                            },
                          ),

                          const SizedBox(height: 10),

                          // Action 4: Full Bill / Settle Invoice
                          _buildActionOptionTile(
                            title: 'Full Bill / Settle Invoice',
                            icon: Icons.receipt_long_rounded,
                            iconColor: const Color(0xFF16A34A),
                            bgColor: const Color(0xFFEBF7ED),
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showFullBillDialog(context, ref, table, isDark);
                            },
                          ),
                        ],

                        Builder(
                          builder: (context) {
                            final userRole = ref.watch(authProvider).currentUser.role;
                            final bool canDeleteTable = ref.watch(roleRightsProvider).isActionGranted(
                              userRole,
                              'tables_delete',
                              defaultIfMissing: userRole == UserRole.owner,
                            );
                            if (!canDeleteTable) return const SizedBox.shrink();
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 10),
                                _buildActionOptionTile(
                                  title: userRole == UserRole.owner ? 'Delete Table (Owner Only)' : 'Delete Table',
                                  icon: Icons.delete_forever_rounded,
                                  iconColor: AppColors.danger,
                                  bgColor: AppColors.danger.withValues(alpha: 0.1),
                                  isDark: isDark,
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    _confirmDeleteTable(context, ref, table, isDark);
                                  },
                                ),
                              ],
                            );
                          },
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


  Widget _buildActionOptionTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }


  // Cancel Order Item Dialog for Table
  void _showCancelTableItemDialog(BuildContext context, WidgetRef ref, RestaurantTable table, bool isDark) {
    if (table.currentOrderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in this table order to cancel.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _CancelTableItemModal(
          parentContext: context,
          ref: ref,
          table: table,
          isDark: isDark,
        );
      },
    );
  }

  // Kitchen Receipt (KOT) Dialog
  void _showKitchenReceiptDialog(BuildContext context, RestaurantTable table, bool isDark) {
    final screenContext = context;
    final rawTicketId = (table.activeOrderNumber != null && table.activeOrderNumber!.isNotEmpty)
        ? table.activeOrderNumber!
        : (table.activeOrderId ?? table.tableNumber);
    final displayTicketId = EscPosBuilder.format3DigitOrderNumber(rawTicketId);

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
                          Icon(Icons.soup_kitchen_rounded, color: Color(0xFFD97706), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'KITCHEN ORDER TICKET (KOT)',
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

                  // KOT Receipt Content Box
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
                            'HUNGRY HOWIE\'S KITCHEN',
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Table: ${table.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ticket: #$displayTicketId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryRed),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Time: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const Divider(height: 16),
                        const Text('ORDER ITEMS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        const SizedBox(height: 6),
                        if (table.currentOrderItems.isNotEmpty)
                          ...table.currentOrderItems.map((item) {
                            final name = item['name']?.toString() ?? 'Item';
                            final qty = item['quantity']?.toString() ?? '1';
                            final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
                            final cancelReason = item['cancel_reason']?.toString();
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
                                          isCancelled ? '• -$qty $name' : '• ${qty}x $name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            decorationColor: AppColors.danger,
                                            decorationThickness: 2,
                                            color: isCancelled ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isCancelled ? 'QTY: -$qty' : 'QTY: $qty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                                          decorationColor: AppColors.danger,
                                          color: isCancelled ? AppColors.danger : (isDark ? Colors.white : AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isCancelled && cancelReason != null && cancelReason.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12, top: 1),
                                      child: Text(
                                        'Reason: $cancelReason',
                                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.danger),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('• Current table items sent to kitchen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        const Divider(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Builder(
                    builder: (context) {
                      final kotReceipt = ReceiptData.fromTableKot(table: table, ticketId: displayTicketId);
                      final hasCancelled = table.currentOrderItems.any((i) => i['is_cancelled'] == true || i['is_cancelled'] == 1);

                      return FutureBuilder<List<bool>>(
                        future: Future.wait([
                          ReceiptPrinterService.isKitchenReceiptPrinted(
                            rawTicketId,
                            tokenNumber: table.tableNumber,
                            currentItemsSignature: kotReceipt.itemsSignature,
                          ),
                          ReceiptPrinterService.hasOrderEverPrintedKot(
                            rawTicketId,
                            tokenNumber: table.tableNumber,
                          ),
                        ]),
                        builder: (context, snapshot) {
                          final isPrinted = snapshot.data?[0] ?? false;
                          final hasEverPrinted = snapshot.data?[1] ?? false;
                          final isModified = hasEverPrinted || hasCancelled;

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
                                          'Kitchen ticket has already been printed. Modify order, add items, or cancel items to print an updated ticket.',
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

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isModified)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Order has been modified! Tap below to send the updated ticket to the kitchen.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);

                                    // Physical Thermal Print to Attached Win32 Printer Spooler
                                    final printSuccess = await ReceiptPrinterService.printReceipt(
                                      context: screenContext,
                                      receipt: ReceiptData.fromTableKot(
                                        table: table,
                                        ticketId: displayTicketId,
                                        isModified: isModified,
                                      ),
                                    );

                                    if (printSuccess) {
                                      await ReceiptPrinterService.markKitchenReceiptPrinted(
                                        rawTicketId,
                                        signature: kotReceipt.itemsSignature,
                                      );
                                      await ReceiptPrinterService.markKitchenReceiptPrinted(
                                        displayTicketId,
                                        signature: kotReceipt.itemsSignature,
                                      );
                                      if (hasCancelled) {
                                        await ReceiptPrinterService.markKitchenReceiptPrinted(
                                          '${rawTicketId}_cancel',
                                          signature: kotReceipt.itemsSignature,
                                        );
                                      }

                                      if (table.activeOrderId != null && table.activeOrderId!.isNotEmpty) {
                                        try {
                                          await ref.read(kitchenApiServiceProvider).sendKitchenTicket(table.activeOrderId!);
                                        } catch (e) {
                                          debugPrint('Error marking kitchen ticket as sent: $e');
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.print_rounded, size: 16),
                                  label: Text(isModified ? 'PRINT UPDATED KITCHEN RECEIPT' : 'PRINT KITCHEN RECEIPT'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isModified ? const Color(0xFFEA580C) : const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
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

  // Customer Bill (Pre-Bill, Table Remains Occupied) Dialog with Dine-In Tax and Discount Inputs
  void _showCustomerBillDialog(BuildContext context, RestaurantTable table, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _CustomerPreBillDialog(
          table: table,
          ref: ref,
          isDark: isDark,
          onPrint: (subtotal, discountAmount, taxAmount, grandTotal, taxRate, discountPercentage, managerApproval) async {
            // 1. Update order in database with discount, tax, and grand total
            final activeOrderId = table.activeOrderId;
            if (activeOrderId != null && activeOrderId.isNotEmpty) {
              try {
                if (FeatureFlags.offlineFirstEnabled) {
                  final orderRepo = ref.read(orderRepositoryProvider);
                  final existing = await orderRepo.getOrderById(activeOrderId);
                  if (existing != null) {
                    final updated = existing.copyWith(
                      discountAmount: discountAmount,
                      discountPercentage: discountPercentage,
                      taxAmount: taxAmount,
                      grandTotalOverride: grandTotal,
                      approvedByManagerId: managerApproval?.managerId,
                      managerApproval: managerApproval?.toJson(),
                      dineInDetail: existing.dineInDetail?.copyWith(dineInTax: taxAmount),
                    );
                    await orderRepo.updateOrder(updated);
                  }
                } else if (activeOrderId.length >= 20) {
                  final ordersApi = ref.read(ordersApiServiceProvider);
                  await ordersApi.updateOrder(activeOrderId, {
                    'discount_amount': discountAmount,
                    'discount_percentage': discountPercentage,
                    'tax_amount': taxAmount,
                    'dine_in_tax': taxAmount,
                    'grand_total': grandTotal,
                    if (managerApproval != null) 'approved_by_manager_id': managerApproval.managerId,
                    if (managerApproval != null) 'manager_approval': managerApproval.toJson(),
                  });
                }
                final notifier = ref.read(tableProvider.notifier);
                await notifier.updateTableBillAndStatus(
                  table.id,
                  grandTotal,
                  TableStatus.occupied,
                  activeOrderId: activeOrderId,
                  activeOrderNumber: table.activeOrderNumber,
                  orderItems: table.currentOrderItems,
                );
                await notifier.loadTables();
              } catch (e) {
                debugPrint('⚠️ Error saving customer bill discount in DB: $e');
              }
            }

            // 2. Physical Thermal Print to Attached Laptop Printer
            if (!context.mounted) return;
            await ReceiptPrinterService.printReceipt(
              context: context,
              receipt: ReceiptData.fromTablePreBill(
                table: table,
                subtotal: subtotal,
                discountAmount: discountAmount,
                taxAmount: taxAmount,
                grandTotal: grandTotal,
                taxRate: taxRate,
              ),
            );
          },
        );
      },
    );
  }


  // Full Bill / Cash Payment Calculator Dialog
  void _showFullBillDialog(BuildContext context, WidgetRef ref, RestaurantTable table, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return _FullBillCalculatorDialog(
          parentContext: context,
          ref: ref,
          table: table,
          isDark: isDark,
        );
      },
    );
  }

  void _openTableOrderMenuDialog(BuildContext context, WidgetRef ref, RestaurantTable table, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) {
        return _TableOrderMenuDialog(table: table, isDark: isDark, ref: ref);
      },
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
                    fontSize: 16,
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

  void _openAddTableDialog(BuildContext context, TableNotifier tableNotifier, bool isDark) {
    final nameController = TextEditingController(text: 'Table T-${ref.read(tableProvider).tables.length + 1}');
    final capacityController = TextEditingController(text: '4');
    String selectedSection = 'Hall';
    final stateZones = ref.read(tableProvider).zones;
    final dynamicZones = ref.read(tableProvider).tables.map((t) => t.section).where((s) => s.isNotEmpty).toSet();
    List<String> availableSections = {...stateZones, ...dynamicZones}.toList();
    if (availableSections.isEmpty) availableSections = ['Hall', 'Family Hall', 'Office', 'Terrace'];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 480,
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
                        child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'ADD NEW TABLE',
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
                              'Configure table name, guest capacity & floor zone',
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
                        // Section Label 1: Table Name
                        Row(
                          children: [
                            const Icon(Icons.drive_file_rename_outline_rounded, size: 16, color: AppColors.primaryRed),
                            const SizedBox(width: 6),
                            Text(
                              'TABLE NAME / LABEL',
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
                          controller: nameController,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Table T-30 or VIP-01',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.pin_rounded, size: 18, color: AppColors.primaryRed),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Section Label 2: Seating Capacity
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 16, color: AppColors.primaryRed),
                                const SizedBox(width: 6),
                                Text(
                                  'GUEST SEATING CAPACITY',
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
                              '${capacityController.text} Guests',
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter guest count (e.g. 4)',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.event_seat_rounded, size: 18, color: AppColors.primaryRed),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Quick Capacity Presets Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [2, 4, 6, 8, 10, 12].map((capVal) {
                            final isSelected = capacityController.text == capVal.toString();
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  capacityController.text = capVal.toString();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryRed
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryRed
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Text(
                                  '$capVal Seats',
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

                        const SizedBox(height: 18),

                        // Section Label 3: Floor Section / Zone Selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.layers_rounded, size: 16, color: AppColors.primaryRed),
                                const SizedBox(width: 6),
                                Text(
                                  'FLOOR SECTION / ZONE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                final zoneController = TextEditingController();
                                showDialog(
                                  context: dialogContext,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('Add New Zone', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                    content: TextField(
                                      controller: zoneController,
                                      autofocus: true,
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. VIP Lounge',
                                        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.black38),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryRed,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          final newZone = zoneController.text.trim();
                                          if (newZone.isNotEmpty) {
                                            tableNotifier.addZone(newZone);
                                            setDialogState(() {
                                              if (!availableSections.contains(newZone)) {
                                                availableSections.add(newZone);
                                              }
                                              selectedSection = newZone;
                                            });
                                            Navigator.pop(ctx);
                                          }
                                        },
                                        child: const Text('Add Zone'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.add_rounded, size: 14, color: AppColors.primaryRed),
                                    SizedBox(width: 4),
                                    Text('NEW ZONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Visual Segmented Floor Zone Cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.8,
                          children: availableSections.map((sec) {
                            final isSelected = selectedSection == sec;
                            IconData secIcon;
                            switch (sec) {
                              case 'Family Hall':
                                secIcon = Icons.family_restroom_rounded;
                                break;
                              case 'Hall':
                                secIcon = Icons.table_restaurant_rounded;
                                break;
                              case 'Office':
                                secIcon = Icons.business_center_rounded;
                                break;
                              case 'VIP Lounge':
                                secIcon = Icons.king_bed_rounded;
                                break;
                              case 'Outdoor Terrace':
                                secIcon = Icons.deck_rounded;
                                break;
                              default:
                                secIcon = Icons.table_restaurant_rounded;
                                break;
                            }

                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedSection = sec;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryRed.withValues(alpha: isDark ? 0.25 : 0.08)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryRed
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryRed
                                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        secIcon,
                                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary),
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            sec,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.primaryRed
                                                  : (isDark ? Colors.white : AppColors.textPrimary),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            isSelected ? 'Selected Zone' : 'Tap to select',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.primaryRed.withValues(alpha: 0.8)
                                                  : (isDark ? const Color(0xFF64748B) : AppColors.textSecondary),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 2),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.primaryRed,
                                          size: 16,
                                        ),
                                      ),
                                    InkWell(
                                      onTap: () async {
                                        final tablesInZone = ref.read(tableProvider).tables.where((t) => t.section.toLowerCase() == sec.toLowerCase()).length;
                                        final confirmed = await showConfirmDeleteDialog(
                                          context: dialogContext,
                                          title: 'DELETE FLOOR ZONE',
                                          itemName: '$sec Zone',
                                          itemType: 'Floor Section / Zone',
                                          description: 'Are you sure you want to permanently delete the "$sec" floor zone? ${tablesInZone > 0 ? "This zone currently contains $tablesInZone table(s). Deleting it will permanently delete all these tables from the database." : "This zone has no active tables and will be safely removed."}',
                                          confirmButtonText: 'DELETE ZONE',
                                        );
                                        if (confirmed) {
                                          await ref.read(tableProvider.notifier).deleteSection(sec);
                                          setDialogState(() {
                                            availableSections.remove(sec);
                                            if (selectedSection == sec) {
                                              selectedSection = availableSections.isNotEmpty ? availableSections.first : 'Hall';
                                            }
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Floor zone "$sec" deleted successfully.'),
                                                backgroundColor: AppColors.danger,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          color: isDark ? Colors.white38 : AppColors.textMuted,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // 3. Action Submit Button
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
                                final name = nameController.text.trim();
                                final cap = int.tryParse(capacityController.text.trim()) ?? 4;
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a table name!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                final existingTables = ref.read(tableProvider).tables;
                                final isDuplicate = existingTables.any((t) =>
                                    t.name.trim().toLowerCase() == name.toLowerCase() ||
                                    t.tableNumber.trim().toLowerCase() == name.toLowerCase());

                                if (isDuplicate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Table with name "$name" already exists! Please enter a unique table name.'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                final newTable = RestaurantTable(
                                  id: 'tbl_${DateTime.now().millisecondsSinceEpoch}',
                                  tableNumber: name,
                                  name: name,
                                  capacity: cap,
                                  status: TableStatus.available,
                                  section: selectedSection,
                                );
                                try {
                                  await tableNotifier.addTable(newTable);
                                  tableNotifier.setSection(selectedSection);
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Table "$name" ($cap Seats) added to $selectedSection zone!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Table "$name" ($cap Seats) added!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                              label: const Text(
                                'SAVE & CREATE TABLE',
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
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTable(BuildContext context, WidgetRef ref, RestaurantTable table, bool isDark) async {
    final isOccupied = table.status == TableStatus.occupied && table.currentBillAmount > 0;
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: 'DELETE RESTAURANT TABLE',
      itemName: '${table.name} (${table.tableNumber})',
      itemType: 'Floor Table',
      description: 'Are you sure you want to delete table "${table.name}" (${table.tableNumber}) located in "${table.section}"? This table will be permanently removed from the floor layout and database.',
      warningNote: isOccupied
          ? '⚠️ WARNING: Table is currently OCCUPIED with an active bill of PKR ${table.currentBillAmount.toStringAsFixed(0)}.'
          : 'This action is permanent and cannot be undone.',
      confirmButtonText: 'DELETE TABLE',
    );

    if (confirmed) {
      await ref.read(tableProvider.notifier).deleteTable(table.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table "${table.name}" has been deleted.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

class _OrderMenuItem {
  final String? id;
  final String name;
  final String category;
  final double price;
  final String imagePath;
  final Uint8List? imageBytes;

  const _OrderMenuItem({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imagePath,
    this.imageBytes,
  });

  _OrderMenuItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    String? imagePath,
    Uint8List? imageBytes,
  }) {
    return _OrderMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      imagePath: imagePath ?? this.imagePath,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class _OrderItem {
  final _OrderMenuItem item;
  int quantity;
  final int initialOrderedQty;

  _OrderItem({
    required this.item,
    this.quantity = 1,
    this.initialOrderedQty = 0,
  });

  bool get isExistingOrderedItem => initialOrderedQty > 0;
  double get totalPrice => item.price * quantity;
}

class _TableOrderMenuDialog extends StatefulWidget {
  final RestaurantTable table;
  final bool isDark;
  final WidgetRef ref;

  const _TableOrderMenuDialog({
    required this.table,
    required this.isDark,
    required this.ref,
  });

  @override
  State<_TableOrderMenuDialog> createState() => _TableOrderMenuDialogState();
}

class _TableOrderMenuDialogState extends State<_TableOrderMenuDialog> {
  final TextEditingController _menuSearchController = TextEditingController();
  String _selectedCategory = 'All';
  String _menuQuery = '';
  final List<_OrderItem> _cartItems = [];
  late final OpenOrderGuardNotifier _orderGuardNotifier;
  late final String _orderGuardId;

  void _updateOrderGuard() {
    _orderGuardNotifier.updateOrderOpen(_orderGuardId, _cartItems.isNotEmpty);
  }
  bool _isLoadingMenu = false;
  bool _isSubmittingOrder = false;
  String? _activeOrderId;
  String? _pendingNewOrderId;

  List<String> _categories = [
    'All',
    'Deals',
    'Pizza',
    'Steak',
    'Burger',
    'Brost',
    'Pasta',
    'Panini',
    'Appetizer',
    'Fries',
    'Drinks',
    'Topping',
    'Hot Coffee',
    'Cold Coffee',
    'Dessert'
  ];

  final List<_OrderMenuItem> _menuDatabase = [
    // Default initial seed
    const _OrderMenuItem(name: "EXCLUSIVE DEALS (Pizza+Biryani+Panini+Shakes+Bottle)", category: 'Deals', price: 2499, imagePath: 'assets/images/image.jpg'),
    const _OrderMenuItem(name: "Family Feast Combo Deal (2 Family Pizzas + 4 Broast + Loaded Fries + 1.5L Coke)", category: 'Deals', price: 3299, imagePath: 'assets/images/Special.png'),
    const _OrderMenuItem(name: "Duo Craver Pack (2 Gourmet Burgers + Garlic Fries + 2 Drinks)", category: 'Deals', price: 1649, imagePath: 'assets/images/beef_burger_hero.jpg'),
    const _OrderMenuItem(name: "Midnight Craving Deal (1 Large Pizza + Cheesy Panini + 2 Drinks)", category: 'Deals', price: 1999, imagePath: 'assets/images/Pizza.png'),
    const _OrderMenuItem(name: "Student Saver Deal (1 Zinger Burger + Plain Fries + 1 Drink)", category: 'Deals', price: 749, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    const _OrderMenuItem(name: "Classic Fajita Pizza (Small)", category: 'Pizza', price: 849, imagePath: 'assets/images/Fajita.png'),
    const _OrderMenuItem(name: "Classic Fajita Pizza (Medium)", category: 'Pizza', price: 1449, imagePath: 'assets/images/Fajita.png'),
    const _OrderMenuItem(name: "Classic Fajita Pizza (Large)", category: 'Pizza', price: 1749, imagePath: 'assets/images/Fajita.png'),
    const _OrderMenuItem(name: "Classic Fajita Pizza (Family)", category: 'Pizza', price: 2349, imagePath: 'assets/images/Fajita.png'),
    const _OrderMenuItem(name: "Modern Crown Crust (Medium)", category: 'Pizza', price: 1549, imagePath: 'assets/images/Modern.png'),
    const _OrderMenuItem(name: "Modern Crown Crust (Large)", category: 'Pizza', price: 1999, imagePath: 'assets/images/Modern.png'),
    const _OrderMenuItem(name: "Special Arabic Crispy (Medium)", category: 'Pizza', price: 1699, imagePath: 'assets/images/Special.png'),
    const _OrderMenuItem(name: "Special Hungry Cheese Gold (Large)", category: 'Pizza', price: 2199, imagePath: 'assets/images/Special.png'),
    const _OrderMenuItem(name: "Tarragon Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    const _OrderMenuItem(name: "Mushroom Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    const _OrderMenuItem(name: "Twin Chicken Steak", category: 'Steak', price: 1599, imagePath: 'assets/images/chicken_steak.png'),
    const _OrderMenuItem(name: "Smoked BBQ Chicken Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    const _OrderMenuItem(name: "Hot Shot Jalapeno Steak", category: 'Steak', price: 1499, imagePath: 'assets/images/chicken_steak.png'),
    const _OrderMenuItem(name: "Beef Cheese Stuff Burger", category: 'Burger', price: 1349, imagePath: 'assets/images/beef_burger_hero.jpg'),
    const _OrderMenuItem(name: "Hungry Stacker Beef Burger", category: 'Burger', price: 1349, imagePath: 'assets/images/beef_burger_hero.jpg'),
    const _OrderMenuItem(name: "The Smashroom Beef Burger", category: 'Burger', price: 1099, imagePath: 'assets/images/beef_burger_hero.jpg'),
    const _OrderMenuItem(name: "Hungry Special Chicken Burger", category: 'Burger', price: 899, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    const _OrderMenuItem(name: "Crispy BBQ Chicken Burger", category: 'Burger', price: 999, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    const _OrderMenuItem(name: "Zinger Burger", category: 'Burger', price: 499, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    const _OrderMenuItem(name: "Student Burger", category: 'Burger', price: 450, imagePath: 'assets/images/chicken_burger_hero.jpg'),
    const _OrderMenuItem(name: "Half Dajjaj Broast (with Fries)", category: 'Brost', price: 1250, imagePath: 'assets/images/broast_hero.jpg'),
    const _OrderMenuItem(name: "Family Dajjaj Broast (with Fries)", category: 'Brost', price: 2400, imagePath: 'assets/images/broast_hero.jpg'),
    const _OrderMenuItem(name: "Chicken Alfredo Pasta", category: 'Pasta', price: 999, imagePath: 'assets/images/pasta_hero.jpg'),
    const _OrderMenuItem(name: "Penne Arrabiata Pasta", category: 'Pasta', price: 999, imagePath: 'assets/images/penne.png'),
    const _OrderMenuItem(name: "Hungry Parmesan Pasta", category: 'Pasta', price: 1099, imagePath: 'assets/images/Permission.png'),
    const _OrderMenuItem(name: "Cheesy Panini Sandwich", category: 'Panini', price: 1099, imagePath: 'assets/images/panini_hero.jpg'),
    const _OrderMenuItem(name: "Hungry Club Panini", category: 'Panini', price: 849, imagePath: 'assets/images/panini_hero.jpg'),
    const _OrderMenuItem(name: "Special BBQ Panini", category: 'Panini', price: 849, imagePath: 'assets/images/panini_hero.jpg'),
    const _OrderMenuItem(name: "Chicken Nuggets (6pcs with Fries)", category: 'Appetizer', price: 399, imagePath: 'assets/images/Nuggets.png'),
    const _OrderMenuItem(name: "Crispy Chicken Wings (6pcs)", category: 'Appetizer', price: 399, imagePath: 'assets/images/Wings.png'),
    const _OrderMenuItem(name: "Peri-Peri Wings (6pcs)", category: 'Appetizer', price: 499, imagePath: 'assets/images/peri.png'),
    const _OrderMenuItem(name: "Honey BBQ Wings (6pcs)", category: 'Appetizer', price: 499, imagePath: 'assets/images/Honey.png'),
    const _OrderMenuItem(name: "Hungry Loaded Fries", category: 'Fries', price: 749, imagePath: 'assets/images/Loaded.png'),
    const _OrderMenuItem(name: "Honey Mustard Fries", category: 'Fries', price: 449, imagePath: 'assets/images/Mustard.png'),
    const _OrderMenuItem(name: "Garlic Mayo Fries", category: 'Fries', price: 499, imagePath: 'assets/images/Garlic.png'),
    const _OrderMenuItem(name: "Masala Fries", category: 'Fries', price: 299, imagePath: 'assets/images/Masala.png'),
    const _OrderMenuItem(name: "Plain Salted Fries", category: 'Fries', price: 279, imagePath: 'assets/images/Simple.png'),
    const _OrderMenuItem(name: "Fresh Lime Drink", category: 'Drinks', price: 250, imagePath: 'assets/images/FreshLime.png'),
    const _OrderMenuItem(name: "Mint Margarita", category: 'Drinks', price: 300, imagePath: 'assets/images/Mint.png'),
    const _OrderMenuItem(name: "NR Coke", category: 'Drinks', price: 100, imagePath: 'assets/images/Coke.png'),
    const _OrderMenuItem(name: "NR Sprite", category: 'Drinks', price: 100, imagePath: 'assets/images/Sprite.png'),
    const _OrderMenuItem(name: "Coke Tin Pack", category: 'Drinks', price: 160, imagePath: 'assets/images/CokeTin.png'),
    const _OrderMenuItem(name: "Mineral Water", category: 'Drinks', price: 80, imagePath: 'assets/images/Mineral.png'),
    const _OrderMenuItem(name: "Extra Cheese Topping", category: 'Topping', price: 200, imagePath: 'assets/images/Cheese.png'),
    const _OrderMenuItem(name: "Extra BBQ Sauce", category: 'Topping', price: 150, imagePath: 'assets/images/BBqSauce.png'),
    const _OrderMenuItem(name: "Extra Garlic Mayo", category: 'Topping', price: 150, imagePath: 'assets/images/GarlicMayo.png'),
    const _OrderMenuItem(name: "Mash Potato Side", category: 'Topping', price: 250, imagePath: 'assets/images/MeshPatato.png'),
    const _OrderMenuItem(name: "Cappuccino Coffee", category: 'Hot Coffee', price: 599, imagePath: 'assets/images/Capachino.png'),
    const _OrderMenuItem(name: "Espresso Double Shot", category: 'Hot Coffee', price: 750, imagePath: 'assets/images/ExpressoDouble.png'),
    const _OrderMenuItem(name: "Strawberry Iced Latte", category: 'Cold Coffee', price: 599, imagePath: 'assets/images/Strawberry.png'),
    const _OrderMenuItem(name: "Caramel Iced Latte", category: 'Cold Coffee', price: 599, imagePath: 'assets/images/Cerimal.png'),
    const _OrderMenuItem(name: "Kulfa Ice Cream (Single)", category: 'Dessert', price: 199, imagePath: 'assets/images/ice_cream_hero.jpg'),
    const _OrderMenuItem(name: "Kulfa Ice Cream (Double)", category: 'Dessert', price: 399, imagePath: 'assets/images/ice_cream_hero.jpg'),
    const _OrderMenuItem(name: "Pina Colada Mocktail", category: 'Dessert', price: 650, imagePath: 'assets/images/pina.png'),
    const _OrderMenuItem(name: "Blueberry Mojito", category: 'Dessert', price: 450, imagePath: 'assets/images/blueBerry.png'),
    const _OrderMenuItem(name: "Mango Smoothie", category: 'Dessert', price: 199, imagePath: 'assets/images/MangoS.png'),
    const _OrderMenuItem(name: "Chocolate Ice Shake", category: 'Dessert', price: 590, imagePath: 'assets/images/ChocolateI.png'),
    const _OrderMenuItem(name: "Banana Milkshake", category: 'Dessert', price: 400, imagePath: 'assets/images/BananaShake.png'),
  ];

  @override
  void initState() {
    super.initState();
    _orderGuardNotifier = widget.ref.read(openOrderGuardProvider.notifier);
    _orderGuardId = 'tables_${identityHashCode(this)}';
    final isOccupied = widget.table.status == TableStatus.occupied;
    _activeOrderId = isOccupied ? widget.table.activeOrderId : null;
    // Pre-load existing order items ONLY if table is actively occupied in this session
    if (isOccupied) {
      final existingItems = widget.table.currentOrderItems;
      for (final itemMap in existingItems) {
        if (itemMap['is_cancelled'] == true || itemMap['is_cancelled'] == 1) continue;
        final qty = (itemMap['quantity'] as int? ?? 1);
        final menuItem = _OrderMenuItem(
          id: itemMap['id']?.toString(),
          name: itemMap['name'] as String,
          category: itemMap['category'] as String? ?? 'General',
          price: double.tryParse(itemMap['price']?.toString() ?? '0') ?? 0.0,
          imagePath: itemMap['imagePath'] as String? ?? 'assets/images/Pizza.png',
        );
        _cartItems.add(_OrderItem(
          item: menuItem,
          quantity: qty,
          initialOrderedQty: qty,
        ));
      }
    }
    if (_cartItems.isNotEmpty) {
      _orderGuardNotifier.setOrderOpen(_orderGuardId);
    }
    _loadMenuAndDatabaseOrder();
  }

  Future<void> _loadMenuAndDatabaseOrder() async {
    setState(() => _isLoadingMenu = true);
    try {
      List<dynamic> dbCategories = [];
      List<dynamic> dbItems = [];
      List<dynamic> dbDeals = [];

      try {
        final menuApi = widget.ref.read(menuApiServiceProvider);
        final results = await Future.wait([
          menuApi.listCategories(),
          menuApi.listItems(),
          menuApi.listDeals(),
        ]);
        dbCategories = results[0];
        dbItems = results[1];
        dbDeals = results[2];
      } catch (err) {
        if (FeatureFlags.offlineFirstEnabled) {
          final db = widget.ref.read(appDatabaseProvider);
          final localCats = await db.catalogDao.getAllCategories();
          final localItems = await db.catalogDao.getAllMenuItems();
          final localDeals = await db.catalogDao.getAllDeals();
          dbCategories = localCats.map((c) => {'id': c.id, 'name': c.name}).toList();
          dbItems = localItems.map((i) => {
            'id': i.id,
            'name': i.name,
            'base_price': i.basePrice,
            'image_url': 'assets/images/Pizza.png',
            'category': {'name': i.categoryId},
          }).toList();
          dbDeals = localDeals.map((d) => {
            'id': d.id,
            'title': d.name,
            'deal_price': d.dealPrice,
            'image_path': 'assets/images/image.jpg',
          }).toList();
        } else {
          rethrow;
        }
      }

      final List<_OrderMenuItem> loadedItems = [];
      final Set<String> loadedCategories = {'All'};

      // 1. Add Deals from Database
      if (dbDeals.isNotEmpty) {
        loadedCategories.add('Deals');
        for (final deal in dbDeals) {
          final title = deal['title']?.toString().trim() ?? '';
          if (title.isEmpty) continue;
          final p = double.tryParse(deal['deal_price']?.toString() ?? '0') ?? 0.0;
          final img = deal['image_path']?.toString() ?? 'assets/images/image.jpg';

          Uint8List? imgBytes;
          if (img.startsWith('data:image') || img.contains(';base64,')) {
            try {
              imgBytes = base64Decode(img.split(',').last);
            } catch (_) {}
          }

          final alreadyInList = loadedItems.any(
            (it) => it.name.toLowerCase() == title.toLowerCase() || (deal['id'] != null && it.id == deal['id'].toString()),
          );
          if (!alreadyInList) {
            loadedItems.add(_OrderMenuItem(
              id: deal['id']?.toString(),
              name: title,
              category: 'Deals',
              price: p,
              imagePath: img,
              imageBytes: imgBytes,
            ));
          }
        }
      }

      // 2. Add Categories from Database
      for (final cat in dbCategories) {
        final catName = cat['name']?.toString().trim() ?? '';
        if (catName.isNotEmpty) {
          loadedCategories.add(catName);
        }
      }

      // 3. Add Items from Database
      for (final item in dbItems) {
        final itemId = item['id']?.toString();
        final itemName = item['name']?.toString().trim() ?? '';
        if (itemName.isEmpty) continue;

        final catName = item['category'] is Map
            ? (item['category']['name']?.toString().trim() ?? 'General')
            : 'General';
        final basePrice = double.tryParse(item['base_price']?.toString() ?? '0') ?? 0.0;
        final imgUrl = item['image_url']?.toString() ?? 'assets/images/Pizza.png';

        final alreadyInList = loadedItems.any(
          (it) => it.name.toLowerCase() == itemName.toLowerCase() || (itemId != null && it.id == itemId),
        );
        if (alreadyInList) continue;

        Uint8List? itemBytes;
        if (imgUrl.startsWith('data:image') || imgUrl.contains(';base64,')) {
          try {
            itemBytes = base64Decode(imgUrl.split(',').last);
          } catch (_) {}
        }

        loadedCategories.add(catName);

        // Check if item has sizes
        if (item['sizes'] is List && (item['sizes'] as List).isNotEmpty) {
          for (final size in (item['sizes'] as List)) {
            final sizeName = size['size_name']?.toString().trim() ?? '';
            final sizePrice = double.tryParse(size['price']?.toString() ?? '$basePrice') ?? basePrice;
            final fullName = '$itemName ($sizeName)';
            if (!loadedItems.any((it) => it.name.toLowerCase() == fullName.toLowerCase())) {
              loadedItems.add(_OrderMenuItem(
                id: itemId,
                name: fullName,
                category: catName,
                price: sizePrice,
                imagePath: imgUrl,
                imageBytes: itemBytes,
              ));
            }
          }
        } else {
          loadedItems.add(_OrderMenuItem(
            id: itemId,
            name: itemName,
            category: catName,
            price: basePrice,
            imagePath: imgUrl,
            imageBytes: itemBytes,
          ));
        }
      }

      // 4. Fetch Active Order & Items directly from Database ONLY IF TABLE IS OCCUPIED
      final isOccupied = widget.table.status == TableStatus.occupied;
      if (isOccupied && _activeOrderId != null && _activeOrderId!.isNotEmpty) {
        try {
          if (FeatureFlags.offlineFirstEnabled) {
            final orderRepo = widget.ref.read(orderRepositoryProvider);
            final localOrder = await orderRepo.getOrderById(_activeOrderId!);
            if (localOrder != null) {
              if (!localOrder.isPaid &&
                  localOrder.status != OrderStatus.completed &&
                  localOrder.status != OrderStatus.cancelled) {
                final List<_OrderItem> fetchedCart = [];
                for (final orderItem in localOrder.items) {
                  if (orderItem.isCancelled) continue;
                  final name = orderItem.item.name;
                  final qty = orderItem.quantity;
                  final price = orderItem.unitPrice;
                  final menuItemId = orderItem.item.id;

                  final existingItem = loadedItems.firstWhere(
                    (it) => it.name.toLowerCase() == name.toLowerCase(),
                    orElse: () => _OrderMenuItem(
                      id: menuItemId,
                      name: name,
                      category: orderItem.item.category,
                      price: price,
                      imagePath: orderItem.item.imageUrl.isNotEmpty ? orderItem.item.imageUrl : 'assets/images/Pizza.png',
                    ),
                  );

                  fetchedCart.add(_OrderItem(
                    item: existingItem.copyWith(price: price, id: menuItemId.isNotEmpty ? menuItemId : existingItem.id),
                    quantity: qty,
                    initialOrderedQty: qty,
                  ));
                }

                if (fetchedCart.isNotEmpty) {
                  final userAdded = _cartItems.where((c) => !fetchedCart.any((f) => f.item.name.toLowerCase() == c.item.name.toLowerCase())).toList();
                  _cartItems.clear();
                  _cartItems.addAll(fetchedCart);
                  _cartItems.addAll(userAdded);
                }
              } else {
                _activeOrderId = null;
              }
            }
          } else {
            final ordersApi = widget.ref.read(ordersApiServiceProvider);
            Map<String, dynamic>? activeOrderJson;

            try {
              activeOrderJson = await ordersApi.getOrderById(_activeOrderId!);
            } catch (_) {}

            if (activeOrderJson != null) {
              final isPaid = activeOrderJson['is_paid'] == true;
              final status = activeOrderJson['status']?.toString().toLowerCase();
              if (!isPaid && status != 'completed' && status != 'cancelled') {
                final rawItems = activeOrderJson['order_items'] ?? activeOrderJson['items'];
                if (rawItems is List && rawItems.isNotEmpty) {
                  final List<_OrderItem> fetchedCart = [];
                  for (final raw in rawItems) {
                    if (raw['is_cancelled'] == true || raw['is_cancelled'] == 1) continue;
                    final name = raw['item_name']?.toString() ?? '';
                    final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
                    final price = double.tryParse(raw['unit_price']?.toString() ?? '0') ?? 0.0;
                    final menuItemId = raw['menu_item_id']?.toString();

                    final existingItem = loadedItems.firstWhere(
                      (it) => it.name.toLowerCase() == name.toLowerCase(),
                      orElse: () => _OrderMenuItem(
                        id: menuItemId,
                        name: name,
                        category: 'General',
                        price: price,
                        imagePath: 'assets/images/Pizza.png',
                      ),
                    );

                    fetchedCart.add(_OrderItem(
                      item: existingItem.copyWith(price: price, id: menuItemId ?? existingItem.id),
                      quantity: qty,
                      initialOrderedQty: qty,
                    ));
                  }

                  if (fetchedCart.isNotEmpty) {
                    final userAdded = _cartItems.where((c) => !fetchedCart.any((f) => f.item.name.toLowerCase() == c.item.name.toLowerCase())).toList();
                    _cartItems.clear();
                    _cartItems.addAll(fetchedCart);
                    _cartItems.addAll(userAdded);
                  }
                }
              } else {
                _activeOrderId = null;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading active order from DB: $e');
        }
      } else if (!isOccupied) {
        _activeOrderId = null;
        _cartItems.clear();
      }

      if (mounted) {
        setState(() {
          if (loadedItems.isNotEmpty) {
            _menuDatabase.clear();
            _menuDatabase.addAll(loadedItems);
          }
          if (loadedCategories.length > 1) {
            _categories = loadedCategories.toList();
          }
          _isLoadingMenu = false;
        });
        _updateOrderGuard();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMenu = false);
      }
    }
  }

  @override
  void dispose() {
    _menuSearchController.dispose();
    Future.microtask(() {
      _orderGuardNotifier.clearOrderOpen(_orderGuardId);
    });
    super.dispose();
  }

  double get _totalBill {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  void _addItemToCart(_OrderMenuItem item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((c) => c.item.name == item.name);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity += 1;
      } else {
        _cartItems.add(_OrderItem(item: item, quantity: 1));
      }
    });
    _updateOrderGuard();
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
    _updateOrderGuard();
  }

  Widget _buildItemThumbnail(String path, Uint8List? bytes) {
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, width: 38, height: 38, fit: BoxFit.cover);
    }
    if (path.startsWith('data:image') || path.contains(';base64,')) {
      try {
        final b = base64Decode(path.split(',').last);
        return Image.memory(b, width: 38, height: 38, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 38,
          height: 38,
          color: AppColors.primaryRed.withValues(alpha: 0.1),
          child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
        ),
      );
    }
    if (path.isNotEmpty && !path.startsWith('http')) {
      return Image.asset(
        path,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 38,
          height: 38,
          color: AppColors.primaryRed.withValues(alpha: 0.1),
          child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      color: AppColors.primaryRed.withValues(alpha: 0.1),
      child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final table = widget.table;

    final filteredMenu = _menuDatabase.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _menuQuery.isEmpty || item.name.toLowerCase().contains(_menuQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER SELECTION — ${table.name.toUpperCase()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.6),
                      ),
                      Text(
                        'Section: ${table.section} • Current Status: ${table.status.name.toUpperCase()}${table.currentBillAmount > 0 ? ' (Bill: PKR ${table.currentBillAmount.toStringAsFixed(0)})' : ''}',
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

            // Content Body (Split Layout: Menu Grid Left, Cart Right)
            Expanded(
              child: Row(
                children: [
                  // Left Column: Menu Filter & Items
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search & Categories
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
                                      hintText: 'Search items to add (e.g. Fajita, Burger)...',
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
                              if (_isLoadingMenu) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Category Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();
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

                          Expanded(
                            child: _isLoadingMenu
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: AppColors.primaryRed,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Loading database catalog...',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : filteredMenu.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No items found matching your search.',
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
                                                  child: _buildItemThumbnail(item.imagePath, item.imageBytes),
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

                  // Right Column: Cart & Table Order Summary
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
                            const Icon(Icons.shopping_cart_rounded, color: AppColors.primaryRed, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'TABLE ORDER CART',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (widget.table.currentOrderItems.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryRed.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'MODIFYING',
                                  style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Divider(height: 20),

                        // Cart List
                        Expanded(
                          child: _cartItems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No items selected yet.\nTap + on items to add.',
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
                                                  _updateOrderGuard();
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

                        const Divider(height: 20),

                        // Total Price Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL BILL:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              Text(
                                'PKR ${_totalBill.toStringAsFixed(0)}',
                                style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _cartItems.isEmpty || _isSubmittingOrder
                                ? null
                                : () async {
                                    setState(() => _isSubmittingOrder = true);
                                    try {
                                    // Serialize cart items to persist in RestaurantTable
                                    final itemMaps = _cartItems
                                        .map((c) => {
                                              if (c.item.id != null) 'id': c.item.id,
                                              'name': c.item.name,
                                              'category': c.item.category,
                                              'price': c.item.price,
                                              'imagePath': c.item.imagePath,
                                              'quantity': c.quantity,
                                            })
                                        .toList();

                                    final bool isCurrentlyOccupied = widget.table.status == TableStatus.occupied;
                                    String? effectiveOrderId = isCurrentlyOccupied && _activeOrderId != null && _activeOrderId!.isNotEmpty ? _activeOrderId : null;
                                    String? effectiveOrderNumber = isCurrentlyOccupied ? widget.table.activeOrderNumber : null;
                                    final itemsPayload = _cartItems.map((c) => {
                                      if (c.item.id != null && c.item.id!.isNotEmpty && c.item.id!.length >= 30)
                                        'menu_item_id': c.item.id,
                                      'item_name': c.item.name,
                                      'quantity': c.quantity,
                                      'unit_price': c.item.price,
                                    }).toList();

                                    final orderItems = _cartItems.map((c) {
                                      final itemId = (c.item.id != null && c.item.id!.isNotEmpty && c.item.id!.length >= 30)
                                          ? c.item.id!
                                          : const Uuid().v7();
                                      return OrderItem(
                                        id: const Uuid().v7(),
                                        item: MenuItem(
                                          id: itemId,
                                          name: c.item.name,
                                          category: c.item.category,
                                          description: '',
                                          basePrice: c.item.price,
                                          imageUrl: c.item.imagePath,
                                        ),
                                        quantity: c.quantity,
                                        backendUnitPrice: c.item.price,
                                      );
                                    }).toList();

                                    if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
                                      // Existing order modification flow (unchanged)
                                      final ordersApi = widget.ref.read(ordersApiServiceProvider);
                                      try {
                                        final updatedOrder = await ordersApi.updateOrder(effectiveOrderId, {
                                          'order_type': 'dineIn',
                                          if (table.id.isNotEmpty) 'table_id': table.id,
                                          'status': 'accepted',
                                          'subtotal': _totalBill,
                                          'grand_total': _totalBill,
                                          'items': itemsPayload,
                                        });
                                        effectiveOrderId = updatedOrder['id']?.toString() ?? updatedOrder['data']?['id']?.toString() ?? effectiveOrderId;
                                        effectiveOrderNumber = updatedOrder['order_number']?.toString() ?? updatedOrder['data']?['order_number']?.toString() ?? effectiveOrderNumber;
                                        debugPrint('✅ Dine-in Order modified in DB successfully: $effectiveOrderId (#$effectiveOrderNumber)');
                                      } catch (apiErr) {
                                        debugPrint('⚠️ Orders API call error modifying dine-in order: $apiErr');
                                      }

                                      if (FeatureFlags.offlineFirstEnabled) {
                                        try {
                                          final orderRepo = widget.ref.read(orderRepositoryProvider);
                                          final existing = effectiveOrderId != null ? await orderRepo.getOrderById(effectiveOrderId) : null;
                                          if (existing != null) {
                                            final updated = existing.copyWith(
                                              items: orderItems,
                                              subtotalOverride: _totalBill,
                                              grandTotalOverride: _totalBill,
                                              status: OrderStatus.accepted,
                                            );
                                            final saved = await orderRepo.updateOrder(updated);
                                            effectiveOrderId = saved.id;
                                            effectiveOrderNumber = saved.orderNumber;
                                          }
                                          widget.ref.read(syncBackgroundWorkerProvider).triggerPush();
                                        } catch (driftErr) {
                                          debugPrint('⚠️ Drift offline order update error: $driftErr');
                                        }
                                      }
                                    } else {
                                      // New order creation / checkout flow (Fix for Wave 5a #10: eliminate dual-write)
                                      if (FeatureFlags.offlineFirstEnabled) {
                                        // 1. With OFFLINE_FIRST_ENABLED=true: route checkout only through orderRepositoryProvider (local write + outbox).
                                        // Remove the direct HTTP create and the fallback new-order path.
                                        try {
                                          final orderRepo = widget.ref.read(orderRepositoryProvider);
                                          final clientOrderId = const Uuid().v7();
                                          final newOrder = OrderModel(
                                            id: clientOrderId,
                                            orderNumber: '',
                                            type: OrderType.dineIn,
                                            status: OrderStatus.accepted,
                                            items: orderItems,
                                            createdAt: DateTime.now(),
                                            subtotalOverride: _totalBill,
                                            grandTotalOverride: _totalBill,
                                            dineInDetail: DineInOrderDetail(
                                              id: const Uuid().v7(),
                                              orderId: clientOrderId,
                                              tableId: table.id,
                                              guestCount: table.capacity > 0 ? table.capacity : 1,
                                              waiterName: 'Cashier',
                                            ),
                                          );
                                          final saved = await orderRepo.saveOrder(newOrder);
                                          effectiveOrderId = saved.id;
                                          effectiveOrderNumber = saved.orderNumber;
                                          widget.ref.read(syncBackgroundWorkerProvider).triggerPush();
                                          debugPrint('✅ Dine-in Order committed locally + outbox: $effectiveOrderId (#$effectiveOrderNumber)');
                                        } catch (driftErr) {
                                          debugPrint('⚠️ Drift offline order save error: $driftErr');
                                        }
                                      } else {
                                        // 2. With OFFLINE_FIRST_ENABLED=false: keep the online-only path working.
                                        // A timeout must not create a second order with a new ID. Reuse the same client-generated order ID/idempotency key on any retry.
                                        final clientOrderId = _pendingNewOrderId ??= const Uuid().v7();
                                        final ordersApi = widget.ref.read(ordersApiServiceProvider);
                                        try {
                                          final orderDto = {
                                            'id': clientOrderId,
                                            'order_type': 'dineIn',
                                            if (table.id.isNotEmpty) 'table_id': table.id,
                                            'guest_count': table.capacity > 0 ? table.capacity : 1,
                                            'status': 'accepted',
                                            'is_paid': false,
                                            'payment_status': 'UNPAID',
                                            'subtotal': _totalBill,
                                            'grand_total': _totalBill,
                                            'items': itemsPayload,
                                          };
                                          final createdOrder = await ordersApi.createOrder(orderDto);
                                          effectiveOrderId = createdOrder['id']?.toString() ?? createdOrder['data']?['id']?.toString() ?? clientOrderId;
                                          effectiveOrderNumber = createdOrder['order_number']?.toString() ?? createdOrder['data']?['order_number']?.toString();
                                          _pendingNewOrderId = null; // Clear on success
                                          debugPrint('✅ Dine-in Order saved in DB successfully: $effectiveOrderId (#$effectiveOrderNumber)');
                                        } catch (apiErr) {
                                          debugPrint('⚠️ Orders API call error in online-only mode (idempotency key preserved: $clientOrderId): $apiErr');
                                        }
                                      }
                                    }

                                    final rawTicketId = (table.activeOrderNumber != null && table.activeOrderNumber!.isNotEmpty)
                                        ? table.activeOrderNumber!
                                        : (table.activeOrderId ?? table.tableNumber);
                                    final displayTicketId = EscPosBuilder.format3DigitOrderNumber(rawTicketId);

                                    await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
                                      orderId: effectiveOrderId,
                                      orderNumber: effectiveOrderNumber ?? rawTicketId,
                                      tokenNumber: displayTicketId,
                                      tableNumber: table.tableNumber,
                                    );

                                    // 2. Update Table Status & Bill Amount in Database & POS state
                                    final notifier = widget.ref.read(tableProvider.notifier);
                                    await notifier.updateTableBillAndStatus(
                                      table.id,
                                      _totalBill,
                                      TableStatus.occupied,
                                      activeOrderId: effectiveOrderId,
                                      activeOrderNumber: effectiveOrderNumber,
                                      orderItems: itemMaps,
                                    );

                                    // 3. Reload tables from database
                                    await notifier.loadTables();

                                    _orderGuardNotifier.clearOrderOpen(_orderGuardId);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            effectiveOrderId != null
                                                ? '✅ Order of PKR ${_totalBill.toStringAsFixed(0)} saved in Database for ${table.name}!'
                                                : (widget.table.currentOrderItems.isEmpty
                                                    ? 'Order of PKR ${_totalBill.toStringAsFixed(0)} placed for ${table.name}! Status: OCCUPIED.'
                                                    : '${_cartItems.length} item(s) updated for ${table.name}. New total: PKR ${_totalBill.toStringAsFixed(0)}.'),
                                          ),
                                          backgroundColor: effectiveOrderId != null ? AppColors.success : const Color(0xFFD97706),
                                        ),
                                      );
                                    }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSubmittingOrder = false);
                                      }
                                    }
                                  },
                            icon: _isSubmittingOrder
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_rounded, size: 16),
                            label: Text(
                              _isSubmittingOrder
                                  ? 'PLACING ORDER...'
                                  : 'CONFIRM ORDER (PKR ${_totalBill.toStringAsFixed(0)})',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
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
// Customer Pre-Bill Dialog with Discount and Dine-In Tax Fields (Dine-In Orders)
// ---------------------------------------------------------------------------
class _CustomerPreBillDialog extends StatefulWidget {
  final RestaurantTable table;
  final WidgetRef ref;
  final bool isDark;
  final void Function(double subtotal, double discountAmount, double taxAmount, double grandTotal, double taxRate, double discountPercentage, ManagerApproval? managerApproval) onPrint;

  const _CustomerPreBillDialog({
    required this.table,
    required this.ref,
    required this.isDark,
    required this.onPrint,
  });

  @override
  State<_CustomerPreBillDialog> createState() => _CustomerPreBillDialogState();
}

class _CustomerPreBillDialogState extends State<_CustomerPreBillDialog> {
  late TextEditingController _taxRateController;
  late TextEditingController _discountController;
  double _taxRate = 0.0;
  double _discountPercentage = 0.0;
  bool _isDiscountAmountMode = false;
  double _customDiscountAmount = 0.0;
  ManagerApproval? _managerApproval;

  @override
  void initState() {
    super.initState();
    double subtotal = 0.0;
    for (final item in widget.table.currentOrderItems) {
      if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      subtotal += (price * qty);
    }
    if (subtotal <= 0) {
      subtotal = (widget.table.currentBillAmount + widget.table.discountAmount - widget.table.dineInTax).clamp(0.0, double.infinity);
    }

    final taxable = (subtotal - widget.table.discountAmount).clamp(0.0, double.infinity);
    if (widget.table.dineInTax > 0 && taxable > 0) {
      _taxRate = (widget.table.dineInTax / taxable) * 100.0;
    } else if (widget.table.dineInTax > 0 && subtotal > 0) {
      _taxRate = (widget.table.dineInTax / subtotal) * 100.0;
    } else {
      _taxRate = 0.0;
    }

    _taxRateController = TextEditingController(
      text: _taxRate.toStringAsFixed(_taxRate.truncateToDouble() == _taxRate ? 0 : 1),
    );

    if (widget.table.discountPercentage > 0) {
      _discountPercentage = widget.table.discountPercentage;
      _isDiscountAmountMode = false;
      _discountController = TextEditingController(
        text: _discountPercentage.toStringAsFixed(_discountPercentage.truncateToDouble() == _discountPercentage ? 0 : 1),
      );
    } else if (widget.table.discountAmount > 0) {
      _customDiscountAmount = widget.table.discountAmount;
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
    _taxRateController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _setTaxPreset(double rate) {
    setState(() {
      _taxRate = rate;
      _taxRateController.text = rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1);
    });
  }

  Future<void> _setDiscountPreset(double pct) async {
    if (pct == 0.0) {
      setState(() {
        _isDiscountAmountMode = false;
        _discountPercentage = 0.0;
        _managerApproval = null;
        _discountController.text = '0';
      });
      return;
    }

    final billAmount = widget.table.currentBillAmount > 0 ? widget.table.currentBillAmount : 0.0;
    double sub = 0.0;
    for (final item in widget.table.currentOrderItems) {
      if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      sub += (price * qty);
    }
    if (sub <= 0) sub = billAmount > 0 ? billAmount : 1449.0;
    final discountAmount = (sub * (pct / 100.0)).clamp(0.0, sub);

    final approval = await ManagerApprovalDialog.show(
      context,
      offlineAuthService: widget.ref.read(offlineAuthServiceProvider),
      actionTitle: 'Table ${widget.table.tableNumber} Discount (${pct.toStringAsFixed(0)}%)',
      discountAmount: discountAmount,
      discountPercentage: pct,
    );

    if (approval != null) {
      setState(() {
        _isDiscountAmountMode = false;
        _discountPercentage = pct;
        _managerApproval = approval;
        _discountController.text = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.table.currentOrderItems;
    final billAmount = widget.table.currentBillAmount > 0 ? widget.table.currentBillAmount : 0.0;

    double subtotal = 0.0;
    if (items.isNotEmpty) {
      for (final item in items) {
        if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        subtotal += (price * qty);
      }
    }
    if (subtotal <= 0) {
      subtotal = billAmount > 0 ? billAmount : 1449.0;
    }

    final double discountAmount = _isDiscountAmountMode
        ? _customDiscountAmount.clamp(0.0, subtotal)
        : (subtotal * (_discountPercentage / 100.0)).clamp(0.0, subtotal);

    final double effectiveDiscountPct = subtotal > 0
        ? (_isDiscountAmountMode ? (discountAmount / subtotal) * 100.0 : _discountPercentage)
        : 0.0;

    final double taxableAmount = (subtotal - discountAmount).clamp(0.0, double.infinity);
    final double taxAmount = (taxableAmount * (_taxRate / 100.0));
    final double grandTotal = (taxableAmount + taxAmount).clamp(0.0, double.infinity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Dine-In Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'CUSTOMER PRE-BILL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Dine-In Table Order Summary',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
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
                    // 1. DISCOUNT INPUT & PRESET SECTION
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
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
                                  const Icon(Icons.local_offer_rounded, color: Color(0xFF16A34A), size: 18),
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
                              // Mode Switcher (% or PKR)
                              Container(
                                decoration: BoxDecoration(
                                  color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _isDiscountAmountMode = false;
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

                    const SizedBox(height: 14),

                    // 2. DINE-IN TAX INPUT & SELECTOR SECTION (Exclusive for Dine-In)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
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
                                  const Icon(Icons.percent_rounded, color: Color(0xFF2563EB), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ADD DINE-IN TAX',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: widget.isDark ? Colors.white : AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Dine-In Exclusive',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Quick Preset Chips
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTaxPresetChip('0% (Exempt)', 0.0),
                              _buildTaxPresetChip('5% (GST)', 5.0),
                              _buildTaxPresetChip('8.5%', 8.5),
                              _buildTaxPresetChip('10%', 10.0),
                              _buildTaxPresetChip('16% (PRA)', 16.0),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Custom Tax Rate TextField
                          TextField(
                            controller: _taxRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              color: widget.isDark ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Dine-In Tax Rate (%)',
                              labelStyle: const TextStyle(fontSize: 12),
                              hintText: 'Enter tax percentage',
                              suffixText: '%',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _taxRate = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Receipt Preview Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Restaurant Brand Header
                          Text(
                            "HUNGRY HOWIES",
                            style: TextStyle(
                              color: widget.isDark ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PRE-BILL • Table Remains Occupied',
                            style: TextStyle(fontSize: 10, color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textMuted),
                          ),
                          const SizedBox(height: 10),
                          const Divider(),

                          // Table Number Row
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Table:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.white : AppColors.textPrimary)),
                                Text(widget.table.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 4),

                          // Items List
                          if (items.isNotEmpty)
                            ...items.map((item) {
                              final name = item['name'] as String? ?? 'Item';
                              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                              final lineTotal = price > 0 ? price * qty : (subtotal / items.length);
                              final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isCancelled
                                            ? AppColors.primaryRed.withValues(alpha: 0.15)
                                            : AppColors.primaryRed.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCancelled ? '-$qty×' : '$qty×',
                                        style: TextStyle(
                                          color: isCancelled ? AppColors.danger : AppColors.primaryRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                                          decorationColor: AppColors.danger,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isCancelled
                                              ? AppColors.danger
                                              : (widget.isDark ? Colors.white : AppColors.textPrimary),
                                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                                          decorationColor: AppColors.danger,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isCancelled
                                          ? '- PKR ${(price * qty).toStringAsFixed(0)}'
                                          : 'PKR ${lineTotal.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isCancelled
                                            ? AppColors.danger
                                            : (widget.isDark ? Colors.white : AppColors.textPrimary),
                                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                                        decorationColor: AppColors.danger,
                                        decorationThickness: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Current Table Session Order', style: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12)),
                            ),

                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 4),

                          // Subtotal Row
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Subtotal:', style: TextStyle(fontSize: 13, color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                Text('PKR ${subtotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.isDark ? Colors.white : AppColors.textPrimary)),
                              ],
                            ),
                          ),

                          // Discount Line (if > 0)
                          if (discountAmount > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Discount ', style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                                      if (effectiveDiscountPct > 0)
                                        Text('(${effectiveDiscountPct.toStringAsFixed(effectiveDiscountPct.truncateToDouble() == effectiveDiscountPct ? 0 : 1)}%):', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    '- PKR ${discountAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                            ),

                          // Dine-In Tax Line (Dynamic)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('Dine-In Tax ', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                                    Text('(${_taxRate.toStringAsFixed(_taxRate.truncateToDouble() == _taxRate ? 0 : 1)}%):', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text(
                                  '+ PKR ${taxAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                          ),

                          const Divider(thickness: 1.5),
                          const SizedBox(height: 4),

                          // FINAL TOTAL BILL DUE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL BILL DUE:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                              Text(
                                'PKR ${grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Print Pre-Bill Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (discountAmount > 0 && _managerApproval == null) {
                            final approval = await ManagerApprovalDialog.show(
                              context,
                              offlineAuthService: widget.ref.read(offlineAuthServiceProvider),
                              actionTitle: 'Table ${widget.table.tableNumber} Discount',
                              discountAmount: discountAmount,
                              discountPercentage: effectiveDiscountPct,
                            );
                            if (approval == null) return;
                            _managerApproval = approval;
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          widget.onPrint(subtotal, discountAmount, taxAmount, grandTotal, _taxRate, effectiveDiscountPct, _managerApproval);
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text('PRINT PRE-BILL (PKR ${grandTotal.toStringAsFixed(0)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
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
    final isSelected = !_isDiscountAmountMode && (_discountPercentage - pct).abs() < 0.01;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected ? Colors.white : (widget.isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF16A34A),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF16A34A) : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0)),
        ),
      ),
      onSelected: (_) => _setDiscountPreset(pct),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _buildTaxPresetChip(String label, double rate) {
    final isSelected = (_taxRate - rate).abs() < 0.01;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected ? Colors.white : (widget.isDark ? const Color(0xFF94A3B8) : AppColors.textPrimary),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      onSelected: (_) => _setTaxPreset(rate),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

class _FullBillCalculatorDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final RestaurantTable table;
  final bool isDark;

  const _FullBillCalculatorDialog({
    required this.parentContext,
    required this.ref,
    required this.table,
    required this.isDark,
  });

  @override
  State<_FullBillCalculatorDialog> createState() => _FullBillCalculatorDialogState();
}

class _FullBillCalculatorDialogState extends State<_FullBillCalculatorDialog> {
  final TextEditingController _cashController = TextEditingController();
  double _cashGiven = 5000.0;

  @override
  void initState() {
    super.initState();
    double subtotal = 0.0;
    for (final item in widget.table.currentOrderItems) {
      if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      subtotal += (price * qty);
    }
    if (subtotal <= 0) {
      subtotal = (widget.table.currentBillAmount + widget.table.discountAmount - widget.table.dineInTax).clamp(0.0, double.infinity);
    }
    if (subtotal <= 0) {
      subtotal = widget.table.currentBillAmount > 0 ? widget.table.currentBillAmount : 1449.0;
    }

    final discountAmount = widget.table.discountAmount;
    final dineInTax = widget.table.dineInTax;
    final netTotal = (subtotal - discountAmount + dineInTax).clamp(0.0, double.infinity);

    final defaultAmount = netTotal > 0 ? netTotal : 5000.0;
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
    final orderId = widget.table.activeOrderId ?? 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final items = widget.table.currentOrderItems;
    final rawBill = widget.table.currentBillAmount > 0 ? widget.table.currentBillAmount : 0.0;

    double subtotal = 0.0;
    if (items.isNotEmpty) {
      for (final item in items) {
        if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        subtotal += (price * qty);
      }
    }
    if (subtotal <= 0) {
      subtotal = rawBill > 0 ? rawBill : 1449.0;
    }

    // Retain exact discount and tax stored on table / database from Customer Bill
    final double discountAmount = widget.table.discountAmount.clamp(0.0, subtotal);
    final double effectiveDiscountPct = widget.table.discountPercentage > 0
        ? widget.table.discountPercentage
        : (subtotal > 0 && discountAmount > 0 ? (discountAmount / subtotal) * 100.0 : 0.0);

    final double taxableAmount = (subtotal - discountAmount).clamp(0.0, double.infinity);
    final double taxAmount = widget.table.dineInTax.clamp(0.0, double.infinity);
    final double taxRate = taxableAmount > 0 && taxAmount > 0 ? (taxAmount / taxableAmount) * 100.0 : 0.0;
    final double netTotal = (taxableAmount + taxAmount).clamp(0.0, double.infinity);
    final double changeReturn = _cashGiven - netTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
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
                        'FINAL BILL & CASH CALCULATOR',
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

              // Applied Discounts & Taxes Status Card (Read-Only Summary from Customer Pre-Bill)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                            Icon(Icons.table_restaurant_rounded, color: const Color(0xFF2563EB), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              widget.table.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pre-Bill Pricing Applied',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Applied Discount Tag
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: discountAmount > 0
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                  : (widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: discountAmount > 0
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DISCOUNT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  discountAmount > 0
                                      ? '- PKR ${discountAmount.toStringAsFixed(0)} (${effectiveDiscountPct.toStringAsFixed(effectiveDiscountPct.truncateToDouble() == effectiveDiscountPct ? 0 : 1)}%)'
                                      : 'No Discount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: discountAmount > 0
                                        ? const Color(0xFF16A34A)
                                        : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Applied Dine-In Tax Tag
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: taxAmount > 0
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                  : (widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: taxAmount > 0
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DINE-IN TAX',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  taxAmount > 0
                                      ? '+ PKR ${taxAmount.toStringAsFixed(0)} (${taxRate.toStringAsFixed(taxRate.truncateToDouble() == taxRate ? 0 : 1)}%)'
                                      : '0% (Exempt)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: taxAmount > 0
                                        ? const Color(0xFF2563EB)
                                        : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
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
                  _buildQuickCashChip('Exact (PKR ${netTotal.toStringAsFixed(0)})', netTotal),
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

              // Bill Breakdown Card (Subtotal - Discount + Dine-In Tax = Grand Total)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal:', style: TextStyle(fontSize: 12, color: widget.isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary)),
                        Text('PKR ${subtotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : AppColors.textPrimary)),
                      ],
                    ),
                    if (discountAmount > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount (${effectiveDiscountPct.toStringAsFixed(effectiveDiscountPct.truncateToDouble() == effectiveDiscountPct ? 0 : 1)}%):', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                          Text('- PKR ${discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dine-In Tax (${taxRate.toStringAsFixed(taxRate.truncateToDouble() == taxRate ? 0 : 1)}%):', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        Text('+ PKR ${taxAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                      ],
                    ),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL BILL DUE:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        Text('PKR ${netTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
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
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            changeReturn >= 0 ? Icons.price_check_rounded : Icons.warning_amber_rounded,
                            color: changeReturn >= 0 ? const Color(0xFF16A34A) : AppColors.danger,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  changeReturn >= 0 ? 'RETURN CHANGE TO CUSTOMER:' : 'REMAINING BALANCE SHORT:',
                                  style: TextStyle(
                                    color: changeReturn >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          builder: (tenderContext) => _PaymentTenderDialog(
                            parentContext: widget.parentContext,
                            ref: widget.ref,
                            table: widget.table,
                            orderId: orderId,
                            billAmount: netTotal,
                            subtotal: subtotal,
                            discountAmount: discountAmount,
                            discountPercentage: effectiveDiscountPct,
                            dineInTax: taxAmount,
                            taxRate: taxRate,
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
                        final effectiveOrderId = widget.table.activeOrderId ?? (orderId.length >= 20 ? orderId : null);
                        if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
                          try {
                            if (FeatureFlags.offlineFirstEnabled) {
                              final orderRepo = widget.ref.read(orderRepositoryProvider);
                              final existing = await orderRepo.getOrderById(effectiveOrderId);
                              if (existing != null) {
                                final paidOrder = existing.copyWith(
                                  status: OrderStatus.completed,
                                  paymentStatus: 'PAID',
                                  isPaid: true,
                                  discountAmount: discountAmount,
                                  discountPercentage: effectiveDiscountPct,
                                  taxAmount: taxAmount,
                                  grandTotalOverride: netTotal,
                                  payments: [
                                    OrderPaymentModel(
                                      id: const Uuid().v7(),
                                      paymentMethod: 'cash',
                                      amount: netTotal,
                                      tenderedAmount: _cashGiven > 0 ? _cashGiven : netTotal,
                                      changeReturned: changeReturn >= 0 ? changeReturn : 0.0,
                                      paymentStatus: 'COMPLETED',
                                      receivedBy: 'Cashier',
                                      createdAt: DateTime.now(),
                                    ),
                                  ],
                                  dineInDetail: existing.dineInDetail?.copyWith(dineInTax: taxAmount),
                                );
                                await orderRepo.updateOrder(paidOrder);
                              }
                            } else {
                              final ordersApi = widget.ref.read(ordersApiServiceProvider);
                              await ordersApi.updateOrder(effectiveOrderId, {
                                'status': 'completed',
                                'payment_status': 'PAID',
                                'is_paid': true,
                                'payment_method': 'Cash',
                                'discount_amount': discountAmount,
                                'discount_percentage': effectiveDiscountPct,
                                'dine_in_tax': taxAmount,
                                'tax_amount': taxAmount,
                                'grand_total': netTotal,
                                'payments': [
                                  {
                                    'payment_method': 'cash',
                                    'amount': netTotal,
                                    'tendered_amount': _cashGiven > 0 ? _cashGiven : netTotal,
                                    'change_returned': changeReturn >= 0 ? changeReturn : 0.0,
                                    'payment_status': 'COMPLETED',
                                    'received_by': 'Cashier',
                                  }
                                ],
                              });
                            }
                          } catch (e) {
                            debugPrint('⚠️ Error completing table payment in DB: $e');
                          }
                        }

                        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
      orderId: widget.table.activeOrderId,
      orderNumber: widget.table.activeOrderNumber,
      tokenNumber: EscPosBuilder.format3DigitOrderNumber(widget.table.activeOrderNumber ?? widget.table.tableNumber),
      tableNumber: widget.table.tableNumber,
    );

    final notifier = widget.ref.read(tableProvider.notifier);
                        await notifier.updateTableBillAndStatus(
                          widget.table.id,
                          0.0,
                          TableStatus.available,
                          activeOrderId: null,
                          orderItems: [],
                        );
                        await notifier.loadTables();

                        if (context.mounted) {
                          Navigator.pop(context);

                          // Show Final Paid Receipt Dialog with Cash, Discount, Dine-In Tax & Change Details
                          _showFinalPaidReceiptDialog(
                            widget.parentContext,
                            widget.table,
                            orderId,
                            subtotal,
                            discountAmount,
                            taxAmount,
                            taxRate,
                            netTotal,
                            _cashGiven,
                            changeReturn >= 0 ? changeReturn : 0.0,
                            widget.isDark,
                          );
                        }
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

void _showFinalPaidReceiptDialog(
  BuildContext context,
  RestaurantTable table,
  String orderId,
  double subtotal,
  double discountAmount,
  double dineInTax,
  double taxRate,
  double netTotal,
  double cashGiven,
  double changeReturned,
  bool isDark,
) {
  // Get items from the table
  final items = table.currentOrderItems;
  final rawOrderNo = (table.activeOrderNumber != null && table.activeOrderNumber!.isNotEmpty)
      ? table.activeOrderNumber!
      : (orderId.isNotEmpty ? orderId : (table.activeOrderId ?? table.tableNumber));
  final cleanReceiptNumber = EscPosBuilder.format3DigitOrderNumber(rawOrderNo);

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        clipBehavior: Clip.antiAlias,
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
                        Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'INVOICE RECEIPT',
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
                const SizedBox(height: 6),

                // Receipt Body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header
                      Text(
                        'INVOICE',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "HUNGRY HOWIE'S",
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),

                      // Table Number & Receipt Number
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Table: ${table.name}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary)),
                            Text('Receipt #: $cleanReceiptNumber', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Items List
                      if (items.isNotEmpty)
                        ...items.map((item) {
                          final name = item['name'] as String? ?? 'Item';
                          final qty = item['quantity'] as int? ?? 1;
                          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                          final isCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;
                          final lineTotal = price > 0
                              ? price * qty
                              : (items.length == 1 && subtotal > 0
                                  ? subtotal
                                  : (subtotal > 0 ? subtotal / items.length : 0.0));
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isCancelled
                                        ? AppColors.primaryRed.withValues(alpha: 0.15)
                                        : AppColors.primaryRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isCancelled ? '-$qty×' : '$qty×',
                                    style: TextStyle(
                                      color: isCancelled ? AppColors.danger : AppColors.primaryRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      decorationColor: AppColors.danger,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isCancelled
                                          ? AppColors.danger
                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                      decorationColor: AppColors.danger,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCancelled
                                      ? '- PKR ${(price * qty).toStringAsFixed(0)}'
                                      : (lineTotal > 0
                                          ? 'PKR ${lineTotal.toStringAsFixed(0)}'
                                          : (price > 0 ? 'PKR ${(price * qty).toStringAsFixed(0)}' : 'PKR 0')),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isCancelled
                                        ? AppColors.danger
                                        : (isDark ? Colors.white : AppColors.textPrimary),
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    decorationColor: AppColors.danger,
                                    decorationThickness: 2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Items cleared', style: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12)),
                        ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 4),

                      // Subtotal Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            Text('PKR ${subtotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
                          ],
                        ),
                      ),

                      // Discount Row (if > 0)
                      if (discountAmount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                              Text('- PKR ${discountAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF16A34A))),
                            ],
                          ),
                        ),

                      // Dine-In Tax Row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Dine-In Tax ', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                Text('(${taxRate.toStringAsFixed(taxRate.truncateToDouble() == taxRate ? 0 : 1)}%):', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('+ PKR ${dineInTax.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),

                      const Divider(height: 10),

                      // Total Bill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL BILL PAID:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          Text(
                            'PKR ${netTotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 19),
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
                                style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                              Text(
                                'PKR ${changeReturned.toStringAsFixed(0)}',
                                style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w900, fontSize: 17),
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
                        receipt: ReceiptData.fromTablePaid(
                          table: table,
                          orderId: cleanReceiptNumber,
                          subtotal: subtotal,
                          discountAmount: discountAmount,
                          taxAmount: dineInTax,
                          taxRate: taxRate,
                          grandTotal: netTotal,
                          tenderedAmount: cashGiven > 0 ? cashGiven : netTotal,
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
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Payment Tender / Multi-Tender Information Dialog
// ---------------------------------------------------------------------------
class _PaymentTenderDialog extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final RestaurantTable table;
  final String orderId;
  final double billAmount;
  final double? subtotal;
  final double? discountAmount;
  final double? discountPercentage;
  final double? dineInTax;
  final double? taxRate;
  final bool isDark;

  const _PaymentTenderDialog({
    required this.parentContext,
    required this.ref,
    required this.table,
    required this.orderId,
    required this.billAmount,
    this.subtotal,
    this.discountAmount,
    this.discountPercentage,
    this.dineInTax,
    this.taxRate,
    required this.isDark,
  });

  @override
  State<_PaymentTenderDialog> createState() => _PaymentTenderDialogState();
}

class _PaymentTenderDialogState extends State<_PaymentTenderDialog> {
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
    _cashController = TextEditingController(text: widget.billAmount > 0 ? widget.billAmount.toStringAsFixed(2) : '0.00');
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
    return _totalPayment - widget.billAmount;
  }

  Future<void> _completePayment({bool printReceipt = true}) async {
    // MNY-02: Guard against underpayment in bill settlement
    if (widget.billAmount > 0.001 && _totalPayment < widget.billAmount - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total tendered (PKR ${_totalPayment.toStringAsFixed(2)}) is less than bill amount (PKR ${widget.billAmount.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final effectiveOrderId = widget.table.activeOrderId ?? (widget.orderId.length >= 20 ? widget.orderId : null);

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final bank = double.tryParse(_bankAmountController.text) ?? 0.0;
    final easyPaisa = double.tryParse(_easyPaisaAmountController.text) ?? 0.0;
    final jazzCash = double.tryParse(_jazzCashAmountController.text) ?? 0.0;

    final changeDue = _change > 0 ? _change : 0.0;
    // MNY-03: Scope change returned strictly to cash tendered so net cash matches physical drawer
    final netCash = (cash - changeDue).clamp(0.0, cash);

    final List<Map<String, dynamic>> paymentsList = [];
    if (cash > 0) {
      paymentsList.add({
        'payment_method': 'cash',
        'amount': netCash,
        'tendered_amount': cash,
        'change_returned': changeDue,
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
        'amount': widget.billAmount,
        'tendered_amount': widget.billAmount,
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

    if (effectiveOrderId != null && effectiveOrderId.isNotEmpty) {
      try {
        if (FeatureFlags.offlineFirstEnabled) {
          final orderRepo = widget.ref.read(orderRepositoryProvider);
          final existing = await orderRepo.getOrderById(effectiveOrderId);
          if (existing != null) {
            final mappedPayments = paymentsList.map((p) => OrderPaymentModel(
              id: const Uuid().v7(),
              paymentMethod: p['payment_method']?.toString() ?? 'cash',
              amount: double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0,
              tenderedAmount: double.tryParse(p['tendered_amount']?.toString() ?? '0'),
              changeReturned: double.tryParse(p['change_returned']?.toString() ?? '0'),
              paymentStatus: 'COMPLETED',
              receivedBy: 'Cashier',
              createdAt: DateTime.now(),
            )).toList();
            final taxAmt = widget.dineInTax ?? widget.table.dineInTax;
            final updated = existing.copyWith(
              status: OrderStatus.completed,
              paymentStatus: 'PAID',
              isPaid: true,
              discountAmount: widget.discountAmount ?? widget.table.discountAmount,
              discountPercentage: widget.discountPercentage ?? widget.table.discountPercentage,
              taxAmount: taxAmt,
              grandTotalOverride: widget.billAmount,
              payments: mappedPayments,
              dineInDetail: existing.dineInDetail?.copyWith(dineInTax: taxAmt),
            );
            await orderRepo.updateOrder(updated);
          }
        } else {
          final ordersApi = widget.ref.read(ordersApiServiceProvider);
          await ordersApi.updateOrder(effectiveOrderId, {
            'status': 'completed',
            'payment_status': 'PAID',
            'is_paid': true,
            'payment_method': primaryMethod,
            'discount_amount': widget.discountAmount ?? widget.table.discountAmount,
            'discount_percentage': widget.discountPercentage ?? widget.table.discountPercentage,
            'dine_in_tax': widget.dineInTax ?? widget.table.dineInTax,
            'tax_amount': widget.dineInTax ?? widget.table.dineInTax,
            'grand_total': widget.billAmount,
            'payments': paymentsList,
          });
        }
        debugPrint('✅ Payment successfully persisted in DB for order: $effectiveOrderId');
      } catch (e) {
        debugPrint('⚠️ Error settling table payment in DB: $e');
      }
    }

    await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
      orderId: widget.table.activeOrderId,
      orderNumber: widget.table.activeOrderNumber,
      tokenNumber: EscPosBuilder.format3DigitOrderNumber(widget.table.activeOrderNumber ?? widget.table.tableNumber),
      tableNumber: widget.table.tableNumber,
    );

    final notifier = widget.ref.read(tableProvider.notifier);
    await notifier.updateTableBillAndStatus(
      widget.table.id,
      0.0,
      TableStatus.available,
      activeOrderId: null,
      orderItems: [],
    );
    await notifier.loadTables();

    if (!mounted) return;
    Navigator.pop(context);

    if (widget.parentContext.mounted) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Text('Payment of PKR ${_totalPayment.toStringAsFixed(0)} tendered for ${widget.table.name}! Table is now FREE.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      if (printReceipt) {
        final taxAmt = widget.dineInTax ?? widget.table.dineInTax;
        final discAmt = widget.discountAmount ?? widget.table.discountAmount;
        final subTot = widget.subtotal ?? (widget.billAmount + discAmt - taxAmt);
        final taxable = (subTot - discAmt).clamp(0.0, double.infinity);
        final tRate = widget.taxRate ?? (taxable > 0 && taxAmt > 0 ? (taxAmt / taxable * 100) : 0.0);

        _showFinalPaidReceiptDialog(
          widget.parentContext,
          widget.table,
          widget.orderId,
          subTot,
          discAmt,
          taxAmt,
          tRate,
          widget.billAmount,
          _totalPayment > 0 ? _totalPayment : widget.billAmount,
          _change > 0 ? _change : 0.0,
          widget.isDark,
        );
      }
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
                        'Payment Tender',
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
                              widget.billAmount.toStringAsFixed(2),
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
                            setState(() => _cashController.text = widget.billAmount.toStringAsFixed(2));
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
                            setState(() => _creditController.text = widget.billAmount.toStringAsFixed(2));
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
                        _cashController.text = widget.billAmount.toStringAsFixed(2);
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

          // Amount (Yellow highlight background as in POS image)
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
                fillColor: const Color(0xFFFEF08A), // Light yellow highlight matching POS
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

          // Card Holder / Sender Name
          Expanded(
            flex: 3,
            child: TextField(
              controller: holderCtrl,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white : AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                hintText: 'Customer / Holder Name',
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
// Cancel Table Item Modal
// ---------------------------------------------------------------------------
class _CancelTableItemModal extends StatefulWidget {
  final BuildContext parentContext;
  final WidgetRef ref;
  final RestaurantTable table;
  final bool isDark;

  const _CancelTableItemModal({
    required this.parentContext,
    required this.ref,
    required this.table,
    required this.isDark,
  });

  @override
  State<_CancelTableItemModal> createState() => _CancelTableItemModalState();
}

class _CancelTableItemModalState extends State<_CancelTableItemModal> {
  // Map of item_id -> quantity to cancel
  final Map<String, int> _cancelQuantities = {};

  String _selectedReason = 'Customer Changed Mind';
  final TextEditingController _customReasonController = TextEditingController();
  bool _isCustomReason = false;
  bool _isLoading = false;

  final List<String> _commonReasons = [
    'Customer Changed Mind',
    'Ordered by Mistake',
    'Kitchen Delay',
    'Out of Ingredients',
    'Wrong Table Item',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize default cancel quantity of 0 only for active items
    for (final item in widget.table.currentOrderItems) {
      if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
      final itemId = item['id']?.toString() ?? item['name']?.toString() ?? '';
      _cancelQuantities[itemId] = 0;
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

  void _decrementActiveItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString() ?? item['name']?.toString() ?? '';
    final maxQty = (item['quantity'] as num?)?.toInt() ?? int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final currentCancel = _cancelQuantities[itemId] ?? 0;

    if (currentCancel < maxQty) {
      setState(() {
        _cancelQuantities[itemId] = currentCancel + 1;
      });
    }
  }

  void _restoreCancelledItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString() ?? item['name']?.toString() ?? '';
    final currentCancel = _cancelQuantities[itemId] ?? 0;

    if (currentCancel > 0) {
      setState(() {
        _cancelQuantities[itemId] = currentCancel - 1;
      });
    }
  }

  void _cancelAllOfItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString() ?? item['name']?.toString() ?? '';
    final maxQty = (item['quantity'] as num?)?.toInt() ?? int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
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
      final orderId = widget.table.activeOrderId;
      final currentUser = widget.ref.read(authProvider).currentUser;
      final cashierName = currentUser.fullName.isNotEmpty ? currentUser.fullName : 'Cashier';

      if (orderId != null && orderId.isNotEmpty) {
        if (FeatureFlags.offlineFirstEnabled) {
          final orderRepo = widget.ref.read(orderRepositoryProvider);
          for (final item in widget.table.currentOrderItems) {
            if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
            final itemId = item['id']?.toString() ?? '';
            final cancelQty = _cancelQuantities[itemId] ?? 0;

            if (cancelQty > 0 && itemId.isNotEmpty) {
              await orderRepo.voidOrderItem(
                orderId,
                itemId,
                voidedBy: cashierName,
                reason: effectiveReason,
              );
            }
          }
          widget.ref.read(syncBackgroundWorkerProvider).triggerPush();
        } else {
          final ordersApi = widget.ref.read(ordersApiServiceProvider);

          // Cancel each item with its designated cancel quantity (skipping already cancelled items)
          for (final item in widget.table.currentOrderItems) {
            if (item['is_cancelled'] == true || item['is_cancelled'] == 1) continue;
            final itemId = item['id']?.toString() ?? '';
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
        }

        final activeOrderNum = widget.table.activeOrderNumber;
        final rawTicketId = (activeOrderNum != null && activeOrderNum.isNotEmpty)
            ? activeOrderNum
            : (orderId.isNotEmpty ? orderId : widget.table.tableNumber);
        final displayTicketId = EscPosBuilder.format3DigitOrderNumber(rawTicketId);
        await ReceiptPrinterService.unmarkOrderKitchenReceiptPrinted(
          orderId: orderId.isNotEmpty ? orderId : null,
          orderNumber: activeOrderNum ?? rawTicketId,
          tokenNumber: displayTicketId,
          tableNumber: widget.table.tableNumber,
        );

        // Prepare updated items with cancelled status for table state
        final updatedItems = widget.table.currentOrderItems.map((item) {
          final itemId = item['id']?.toString() ?? '';
          if ((_cancelQuantities[itemId] ?? 0) > 0) {
            final copy = Map<String, dynamic>.from(item);
            copy['is_cancelled'] = true;
            copy['cancel_reason'] = effectiveReason;
            copy['cancelled_by'] = cashierName;
            return copy;
          }
          return item;
        }).toList();

        final updatedTable = widget.table.copyWith(
          currentOrderItems: updatedItems,
        );

        // Update local table bill & items in state
        double newBill = 0.0;
        for (final item in updatedItems) {
          if (item['is_cancelled'] != true && item['is_cancelled'] != 1) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
            final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
            newBill += (qty * price);
          }
        }
        await widget.ref.read(tableProvider.notifier).updateTableBillAndStatus(
          widget.table.id,
          newBill,
          TableStatus.occupied,
          activeOrderId: orderId,
          activeOrderNumber: activeOrderNum,
          orderItems: updatedItems,
        );
      }

      await widget.ref.read(tableProvider.notifier).loadTables();

      if (mounted) {
        Navigator.pop(context);
        parentMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('$totalToCancel item(s) cancelled with strikethrough.'),
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
    final allItems = widget.table.currentOrderItems;
    final activeItems = allItems.where((i) => i['is_cancelled'] != true && i['is_cancelled'] != 1).toList();
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
                            'Table: ${widget.table.name} • Tap [-] on items to cancel quantity',
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
                    if (activeItems.isEmpty && allItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No items in this table order.',
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
                        final itemId = item['id']?.toString() ?? item['name']?.toString() ?? '';
                        final name = item['name']?.toString() ?? 'Item';
                        final initialQty = (item['quantity'] as num?)?.toInt() ?? int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                        final unitPrice = (item['price'] is num) ? (item['price'] as num).toDouble() : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
                        final isAlreadyCancelled = item['is_cancelled'] == true || item['is_cancelled'] == 1;

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
