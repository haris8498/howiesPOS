import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../data/sync_repository.dart';
import '../../domain/models/data_sync_model.dart';

class DataSyncScreen extends ConsumerStatefulWidget {
  const DataSyncScreen({super.key});

  @override
  ConsumerState<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends ConsumerState<DataSyncScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dataSyncProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(dataSyncProvider);
    final syncNotifier = ref.read(dataSyncProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final summary = syncState.summary;
    final orders = syncState.orders;

    final numberFormat = NumberFormat('#,##0.00', 'en_US');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Row
              _buildHeader(context, ref, summary, isDark, syncNotifier),

              const SizedBox(height: 16),

              // 4 Metric KPI Cards Row
              _buildKpiMetricsRow(summary, numberFormat, isDark),

              const SizedBox(height: 16),

              // Search & Filter Toolbar
              _buildFilterToolbar(syncState, syncNotifier, isDark),

              const SizedBox(height: 16),

              // Main Orders Data Table
              Expanded(
                child: _buildSyncOrdersTable(
                  orders: orders,
                  isLoading: syncState.isLoading,
                  numberFormat: numberFormat,
                  isDark: isDark,
                  syncNotifier: syncNotifier,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Section
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    DataSyncSummary summary,
    bool isDark,
    DataSyncNotifier syncNotifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryRed, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'DATA SYNC LEDGER',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Cloud Sync Active',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Store transaction ledger with live cloud synchronization status (🟢 Synced / 🔴 Pending)',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Manual Trigger Batch Sync Button
            ElevatedButton.icon(
              onPressed: () async {
                final count = await syncNotifier.syncAllPending();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(count > 0 ? '$count pending order(s) synced to PostgreSQL Cloud.' : 'All local orders are already in sync with Cloud.'),
                        ],
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(summary.pendingCount > 0 ? 'Sync All (${summary.pendingCount} Pending)' : 'Sync All to Cloud'),
              style: ElevatedButton.styleFrom(
                backgroundColor: summary.pendingCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                elevation: 2,
              ),
            ),
            const SizedBox(width: 10),
            // Refresh Button
            IconButton.filledTonal(
              onPressed: () => syncNotifier.loadData(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh Ledger',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4 KPI Metric Cards Row
  // ---------------------------------------------------------------------------
  Widget _buildKpiMetricsRow(
    DataSyncSummary summary,
    NumberFormat numberFormat,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            // Card 1: TOTAL ORDERS
            Expanded(
              child: _buildMetricCard(
                title: 'TOTAL ORDERS',
                value: '${summary.totalOrders}',
                subtitle: 'Recorded in SQLite',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFF93C5FD).withValues(alpha: 0.4),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),

            // Card 2: TOTAL REVENUE
            Expanded(
              child: _buildMetricCard(
                title: 'TOTAL REVENUE',
                value: 'Rs. ${numberFormat.format(summary.totalRevenue)}',
                subtitle: 'Gross sales volume',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFFE11D48),
                iconBg: const Color(0xFFFFF1F2),
                borderColor: const Color(0xFFFDA4AF).withValues(alpha: 0.4),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),

            // Card 3: SYNCED TO CLOUD (Green)
            Expanded(
              child: _buildMetricCard(
                title: 'SYNCED TO CLOUD',
                value: '${summary.syncedCount}',
                subtitle: 'Backed up to PostgreSQL',
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFF86EFAC).withValues(alpha: 0.4),
                dotColor: const Color(0xFF16A34A),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 14),

            // Card 4: PENDING CLOUD SYNC (Red)
            Expanded(
              child: _buildMetricCard(
                title: 'PENDING CLOUD SYNC',
                value: '${summary.pendingCount}',
                subtitle: 'Stored locally in SQLite',
                icon: Icons.cloud_upload_outlined,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFCA5A5).withValues(alpha: 0.4),
                dotColor: const Color(0xFFDC2626),
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    Color? dotColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (dotColor != null) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search & Filter Toolbar
  // ---------------------------------------------------------------------------
  Widget _buildFilterToolbar(
    DataSyncState state,
    DataSyncNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (val) => notifier.setSearchQuery(val),
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by Order #, Customer, Phone, Table, or Items...',
                  hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 18),

          // SYNC Status Filter Group
          Row(
            children: [
              Text(
                'SYNC:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'All',
                isSelected: state.selectedSyncFilter == 'all',
                onTap: () => notifier.setSyncFilter('all'),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Synced',
                dotColor: const Color(0xFF16A34A),
                isSelected: state.selectedSyncFilter == 'synced',
                onTap: () => notifier.setSyncFilter('synced'),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Pending',
                dotColor: const Color(0xFFDC2626),
                isSelected: state.selectedSyncFilter == 'pending',
                onTap: () => notifier.setSyncFilter('pending'),
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(width: 18),

          // TYPE Filter Group
          Row(
            children: [
              Text(
                'TYPE:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: 'All',
                isSelected: state.selectedTypeFilter == 'all',
                onTap: () => notifier.setTypeFilter('all'),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Dine-In',
                isSelected: state.selectedTypeFilter == 'dineIn',
                onTap: () => notifier.setTypeFilter('dineIn'),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Takeaway',
                isSelected: state.selectedTypeFilter == 'takeaway',
                onTap: () => notifier.setTypeFilter('takeaway'),
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: 'Delivery',
                isSelected: state.selectedTypeFilter == 'delivery',
                onTap: () => notifier.setTypeFilter('delivery'),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    Color? dotColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (dotColor != null
                  ? dotColor.withValues(alpha: 0.15)
                  : AppColors.primaryRed.withValues(alpha: 0.12))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (dotColor ?? AppColors.primaryRed)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (dotColor ?? AppColors.primaryRed)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main Sync Orders Table
  // ---------------------------------------------------------------------------
  Widget _buildSyncOrdersTable({
    required List<DataSyncOrder> orders,
    required bool isLoading,
    required NumberFormat numberFormat,
    required bool isDark,
    required DataSyncNotifier syncNotifier,
  }) {
    if (isLoading) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
    }

    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white38 : AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No orders match the selected sync filter.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeaderCell('CLOUD SYNC', flex: 2),
                _buildTableHeaderCell('ORDER #', flex: 2),
                _buildTableHeaderCell('TYPE & TABLE', flex: 3),
                _buildTableHeaderCell('CUSTOMER', flex: 2),
                _buildTableHeaderCell('ORDERED ITEMS', flex: 6, padding: const EdgeInsets.only(right: 20)),
                _buildTableHeaderCell('PAYMENT', flex: 3),
                _buildTableHeaderCell('TOTAL', flex: 2, alignment: TextAlign.right),
                _buildTableHeaderCell('TIME', flex: 2, alignment: TextAlign.center),
                _buildTableHeaderCell('ACTIONS', flex: 1, alignment: TextAlign.center),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (ctx, i) => Divider(
                height: 1,
                thickness: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (ctx, idx) {
                final order = orders[idx];
                return _buildOrderRow(
                  order: order,
                  numberFormat: numberFormat,
                  isDark: isDark,
                  syncNotifier: syncNotifier,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(
    String label, {
    required int flex,
    TextAlign alignment = TextAlign.left,
    EdgeInsetsGeometry? padding,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Text(
          label,
          textAlign: alignment,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderRow({
    required DataSyncOrder order,
    required NumberFormat numberFormat,
    required bool isDark,
    required DataSyncNotifier syncNotifier,
  }) {
    final timeStr = DateFormat('hh:mm a').format(order.createdAt);
    final isSynced = order.isSynced;

    return InkWell(
      onTap: () => _showOrderSyncAuditDialog(context, order, isDark, syncNotifier),
      hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.015),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // 1. CLOUD SYNC Pill Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSynced
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSynced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSynced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSynced ? 'SYNCED' : 'PENDING',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: isSynced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. ORDER # (Brand Red)
            Expanded(
              flex: 2,
              child: Text(
                order.orderNumber,
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // 3. TYPE & TABLE
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    order.orderType,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    order.typeAndTable,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // 4. CUSTOMER
            Expanded(
              flex: 2,
              child: Text(
                order.customerName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // 5. ORDERED ITEMS (Expanded with generous right margin and readable typography)
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  order.itemsSummary.isNotEmpty ? order.itemsSummary : '—',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 6. PAYMENT (Clean single-line badge with icon)
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: order.isPaid
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: order.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 12,
                        color: order.isPaid ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${order.paymentMethod} • ${order.paymentStatus}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: order.isPaid ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. TOTAL
            Expanded(
              flex: 2,
              child: Text(
                'Rs. ${numberFormat.format(order.totalAmount)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),

            // 8. TIME
            Expanded(
              flex: 2,
              child: Text(
                timeStr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),

            // 9. ACTIONS
            Expanded(
              flex: 1,
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                tooltip: 'View Sync Audit',
                onPressed: () => _showOrderSyncAuditDialog(context, order, isDark, syncNotifier),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync Audit & Order Inspector Dialog (Professional Multi-Card Layout)
  // ---------------------------------------------------------------------------
  void _showOrderSyncAuditDialog(
    BuildContext context,
    DataSyncOrder order,
    bool isDark,
    DataSyncNotifier syncNotifier,
  ) {
    // Parse item breakdown from summary string
    final rawSummary = order.itemsSummary.trim();
    final List<String> parsedItems = rawSummary.isNotEmpty
        ? rawSummary
            .split(RegExp(r',\s*(?=\[CANCELLED\]|\d+x|[A-Z])'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : [];

    final isSynced = order.isSynced;
    final formattedCreatedTime = DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt);
    final formattedSyncedTime = order.syncedAt != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(order.syncedAt!)
        : 'Pending Sync';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Brand Banner Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'SYNC AUDIT INSPECTOR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${order.orderNumber}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${order.orderType} • ${order.typeAndTable}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Body Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSynced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSynced ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isSynced ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                        color: isSynced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isSynced ? 'SYNCHRONIZED TO CLOUD' : 'PENDING CLOUD UPLOAD',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              letterSpacing: 0.3,
                                              color: isSynced ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isSynced
                                                ? 'Backed up in PostgreSQL Cloud Database'
                                                : 'Saved locally in SQLite • Awaiting Cloud Sync',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: isSynced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Toggle Button
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(dialogContext);
                                  await syncNotifier.toggleOrderSyncStatus(order.id);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSynced ? const Color(0xFFE2E8F0) : const Color(0xFF16A34A),
                                  foregroundColor: isSynced ? const Color(0xFF334155) : Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                child: Text(isSynced ? 'Mark Pending' : 'Sync Now'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Section 1: Storage & Infrastructure Card
                        _buildSectionContainer(
                          isDark: isDark,
                          title: 'DATA PIPELINE & REPLICATION',
                          icon: Icons.storage_rounded,
                          iconColor: const Color(0xFF0284C7),
                          children: [
                            _buildAuditDataTile(
                              icon: Icons.sd_storage_rounded,
                              label: 'Local Storage',
                              value: order.sourceStorage,
                              isDark: isDark,
                              trailingChip: order.localSqliteId,
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.cloud_outlined,
                              label: 'Cloud Target',
                              value: order.targetStorage,
                              isDark: isDark,
                              valueColor: const Color(0xFF0284C7),
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.computer_rounded,
                              label: 'POS Device ID',
                              value: order.deviceId,
                              isDark: isDark,
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.access_time_rounded,
                              label: 'Local Created Time',
                              value: formattedCreatedTime,
                              isDark: isDark,
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.cloud_done_rounded,
                              label: 'Cloud Synced Time',
                              value: formattedSyncedTime,
                              isDark: isDark,
                              valueColor: isSynced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Section 2: Order & Financial Summary Card
                        _buildSectionContainer(
                          isDark: isDark,
                          title: 'ORDER & PAYMENT DETAILS',
                          icon: Icons.receipt_long_rounded,
                          iconColor: AppColors.primaryRed,
                          children: [
                            _buildAuditDataTile(
                              icon: Icons.person_outline_rounded,
                              label: 'Customer',
                              value: order.customerName,
                              isDark: isDark,
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.table_restaurant_rounded,
                              label: 'Service & Table',
                              value: '${order.orderType} (${order.typeAndTable})',
                              isDark: isDark,
                            ),
                            const Divider(height: 14),
                            _buildAuditDataTile(
                              icon: Icons.payments_outlined,
                              label: 'Payment Method',
                              value: '${order.paymentMethod} (${order.paymentStatus})',
                              isDark: isDark,
                              valueColor: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order Total:',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'PKR ${order.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Section 3: Ordered Items Breakdown
                        _buildSectionContainer(
                          isDark: isDark,
                          title: () {
                            final cancelledCount = parsedItems.where((i) => i.startsWith('[CANCELLED]')).length;
                            final activeCount = parsedItems.length - cancelledCount;
                            if (cancelledCount > 0) {
                              return 'ORDERED ITEMS ($activeCount active · $cancelledCount cancelled)';
                            }
                            return 'ORDERED ITEMS BREAKDOWN (${parsedItems.length})';
                          }(),
                          icon: Icons.fastfood_outlined,
                          iconColor: const Color(0xFFD97706),
                          children: [
                            if (parsedItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  order.itemsSummary.isNotEmpty ? order.itemsSummary : 'No items recorded.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: parsedItems.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 6),
                                itemBuilder: (ctx, itemIdx) {
                                  final itemText = parsedItems[itemIdx];
                                  final isCancelled = itemText.startsWith('[CANCELLED]');
                                  final cleanText = isCancelled
                                      ? itemText.replaceFirst('[CANCELLED]', '').trim()
                                      : itemText;
                                  final match = RegExp(r'^(\d+x)\s*(.*)$').firstMatch(cleanText);
                                  final qty = match?.group(1) ?? '1x';
                                  final name = match?.group(2) ?? cleanText;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isCancelled
                                          ? (isDark ? const Color(0xFF1A0A0A) : const Color(0xFFFFF5F5))
                                          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isCancelled
                                            ? AppColors.primaryRed.withValues(alpha: 0.35)
                                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCancelled
                                                ? AppColors.primaryRed.withValues(alpha: 0.18)
                                                : AppColors.primaryRed.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            qty,
                                            style: TextStyle(
                                              color: AppColors.primaryRed,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                              decorationColor: AppColors.primaryRed,
                                              decorationThickness: 2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isCancelled
                                                  ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                                  : (isDark ? Colors.white : AppColors.textPrimary),
                                              height: 1.3,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                              decorationColor: isCancelled
                                                  ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                                  : null,
                                              decorationThickness: 2,
                                            ),
                                          ),
                                        ),
                                        if (isCancelled) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryRed.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: AppColors.primaryRed.withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Text(
                                              'CANCELLED',
                                              style: TextStyle(
                                                color: AppColors.primaryRed,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 9,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // Actions Footer
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: const Text('Close Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (!isSynced) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    await syncNotifier.syncSingleOrder(order.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Order #${order.orderNumber} successfully synchronized to Cloud.'),
                                          backgroundColor: const Color(0xFF16A34A),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                                  label: const Text('Sync to PostgreSQL Cloud'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  Widget _buildSectionContainer({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAuditDataTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
    String? trailingChip,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor ?? (isDark ? Colors.white : AppColors.textPrimary),
              ),
            ),
            if (trailingChip != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  trailingChip,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

