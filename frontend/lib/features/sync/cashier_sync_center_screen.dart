import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../config/feature_flags.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_providers.dart';
import '../../domain/models/cashier_sync_model.dart';
import '../../services/api/api_providers.dart';
import '../../shared/widgets/refund_order_dialog.dart';
import 'cashier_sync_center_provider.dart';

class CashierSyncCenterScreen extends ConsumerStatefulWidget {
  const CashierSyncCenterScreen({super.key});

  @override
  ConsumerState<CashierSyncCenterScreen> createState() => _CashierSyncCenterScreenState();
}

class _CashierSyncCenterScreenState extends ConsumerState<CashierSyncCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashierSyncCenterProvider);
    final notifier = ref.read(cashierSyncCenterProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final numberFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header with Sync Now button and Live Status
              _buildTopHeader(context, state, notifier, isDark),

              const SizedBox(height: 14),

              // 2. Current Shift Details Card & Shift Selector
              _buildCurrentShiftCard(context, state, notifier, isDark, dateFormat),

              const SizedBox(height: 14),

              // 3. 5 KPI Summary Cards Row
              _buildKpiSummaryRow(state.summary, isDark),

              const SizedBox(height: 14),

              // 4. Tab Bar (Shift Orders, Pending, Failed, Timeline)
              _buildTabBar(isDark, state.summary),

              const SizedBox(height: 12),

              // 5. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: All Shift Orders Sync
                    _buildShiftOrdersTab(context, state, notifier, isDark, numberFormat, dateFormat),

                    // Tab 2: Pending Uploads
                    _buildPendingUploadsTab(context, state, notifier, isDark, numberFormat, dateFormat),

                    // Tab 3: Failed Uploads
                    _buildFailedUploadsTab(context, state, notifier, isDark, numberFormat, dateFormat),

                    // Tab 4: Shift Sync Timeline
                    _buildShiftTimelineTab(state, isDark, dateFormat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Header
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(
    BuildContext context,
    CashierSyncCenterState state,
    CashierSyncCenterNotifier notifier,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryRed, size: 26),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MY SYNC CENTER',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Text(
                        'CASHIER PORTAL',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Shift-First Offline Sync & Transaction Audit Ledger',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Live Status & Actions
        Row(
          children: [
            // Online/Offline Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.isOnline
                    ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                    : const Color(0xFFDC2626).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: state.isOnline ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 16,
                    color: state.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isOnline ? 'ONLINE 🟢' : 'OFFLINE 🔴',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: state.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Sync Now Button
            ElevatedButton.icon(
              onPressed: state.isSyncing ? null : () => notifier.triggerManualSync(),
              icon: state.isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 16),
              label: Text(state.isSyncing ? 'Syncing...' : 'Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),

            const SizedBox(width: 8),

            // Refresh Button
            IconButton.filledTonal(
              onPressed: () => notifier.loadInitialData(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh Ledger',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Current Shift Card & Selector
  // ---------------------------------------------------------------------------
  Widget _buildCurrentShiftCard(
    BuildContext context,
    CashierSyncCenterState state,
    CashierSyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    final shift = state.currentShift;
    final selectedShiftId = state.selectedShiftId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Shift Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),

              // Shift Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          shift != null
                              ? 'SHIFT #${shift.id.length > 8 ? shift.id.substring(0, 8).toUpperCase() : shift.id}'
                              : 'NO ACTIVE SHIFT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (shift != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: shift.isActive
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                  : const Color(0xFF64748B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              shift.isActive ? 'OPEN / ACTIVE 🟢' : 'CLOSED',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: shift.isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shift != null
                          ? 'Cashier: ${shift.cashierName} • Started: ${DateFormat('dd MMM yyyy, hh:mm a').format(shift.createdAt)} • Terminal: POS-01'
                          : 'No shift session detected. Start a shift from Daily Calculations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Shift Selector Dropdown ("My Shifts")
              if (state.shifts.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedShiftId ?? shift?.id,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: state.shifts.map((s) {
                        final isAct = s.isActive;
                        final shiftDate = DateFormat('MM/dd HH:mm').format(s.createdAt);
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAct ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                size: 12,
                                color: isAct ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${s.cashierName} ($shiftDate) - ${s.status}',
                                style: TextStyle(
                                  fontWeight: isAct ? FontWeight.bold : FontWeight.normal,
                                  color: isAct ? const Color(0xFF16A34A) : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          notifier.selectShift(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Offline Reassurance Notice (if offline)
          if (!state.isOnline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode — All shift orders are persisted safely in local SQLite storage and will synchronize automatically when connection is restored.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
  }

  // ---------------------------------------------------------------------------
  // 5 KPI Summary Row
  // ---------------------------------------------------------------------------
  Widget _buildKpiSummaryRow(CashierSyncSummary summary, bool isDark) {
    return Row(
      children: [
        // 1. TOTAL ORDERS
        Expanded(
          child: _buildSummaryCard(
            title: 'TOTAL ORDERS',
            value: '${summary.totalOrders}',
            subtitle: 'This shift',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF2563EB),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // 2. UPLOADED
        Expanded(
          child: _buildSummaryCard(
            title: 'UPLOADED',
            value: '${summary.uploadedCount}',
            subtitle: 'Synced to cloud ✓',
            icon: Icons.cloud_done_rounded,
            color: const Color(0xFF16A34A),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // 3. PENDING
        Expanded(
          child: _buildSummaryCard(
            title: 'PENDING',
            value: '${summary.pendingCount}',
            subtitle: 'Queued in outbox ⏳',
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFD97706),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // 4. FAILED
        Expanded(
          child: _buildSummaryCard(
            title: 'FAILED',
            value: '${summary.failedCount}',
            subtitle: summary.failedCount > 0 ? 'Action required ⚠️' : 'Zero errors',
            icon: Icons.error_outline_rounded,
            color: summary.failedCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // 5. LAST SYNC
        Expanded(
          child: _buildSummaryCard(
            title: 'LAST SYNC',
            value: summary.lastSyncTime.isNotEmpty ? summary.lastSyncTime : 'Ready',
            subtitle: 'PostgreSQL status',
            icon: Icons.sync_rounded,
            color: const Color(0xFF7C3AED),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
  // Tab Bar
  // ---------------------------------------------------------------------------
  Widget _buildTabBar(bool isDark, CashierSyncSummary summary) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primaryRed,
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        indicatorColor: AppColors.primaryRed,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list_alt_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Shift Orders (${summary.totalOrders})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Pending Uploads (${summary.pendingCount})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Failed Uploads (${summary.failedCount})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.timeline_rounded, size: 16),
                SizedBox(width: 6),
                Text('Shift Timeline'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: All Shift Orders Tab
  // ---------------------------------------------------------------------------
  Widget _buildShiftOrdersTab(
    BuildContext context,
    CashierSyncCenterState state,
    CashierSyncCenterNotifier notifier,
    bool isDark,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    return Column(
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Search field
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search order #, customer, or table...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Status Filter Chips
              Row(
                children: [
                  _buildSmallFilterChip('All', state.selectedStatusFilter == 'all', () => notifier.setStatusFilter('all'), isDark),
                  const SizedBox(width: 5),
                  _buildSmallFilterChip('Uploaded', state.selectedStatusFilter == 'synced', () => notifier.setStatusFilter('synced'), isDark, dotColor: const Color(0xFF16A34A)),
                  const SizedBox(width: 5),
                  _buildSmallFilterChip('Pending', state.selectedStatusFilter == 'pending', () => notifier.setStatusFilter('pending'), isDark, dotColor: const Color(0xFFD97706)),
                  const SizedBox(width: 5),
                  _buildSmallFilterChip('Failed', state.selectedStatusFilter == 'failed', () => notifier.setStatusFilter('failed'), isDark, dotColor: const Color(0xFFDC2626)),
                ],
              ),

              const SizedBox(width: 12),

              // Type Filter Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.selectedTypeFilter,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Types')),
                      DropdownMenuItem(value: 'dineIn', child: Text('Dine In')),
                      DropdownMenuItem(value: 'takeaway', child: Text('Takeaway')),
                      DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setTypeFilter(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Orders List Table
        Expanded(
          child: Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: state.filteredOrders.isEmpty
                  ? Center(
                      child: Text(
                        'No orders found for this shift matching the filters.',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: state.filteredOrders.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (ctx, idx) {
                        final order = state.filteredOrders[idx];
                        return _buildOrderListItem(context, order, notifier, isDark, numberFormat, dateFormat);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark, {Color? dotColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (dotColor != null ? dotColor.withValues(alpha: 0.15) : AppColors.primaryRed.withValues(alpha: 0.12))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? (dotColor ?? AppColors.primaryRed) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? (dotColor ?? AppColors.primaryRed) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(
    BuildContext context,
    CashierShiftOrderModel order,
    CashierSyncCenterNotifier notifier,
    bool isDark,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (order.syncStatus == 'failed') {
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'Failed 🔴';
      statusIcon = Icons.error_rounded;
    } else if (order.isSynced) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'Uploaded 🟢';
      statusIcon = Icons.cloud_done_rounded;
    } else {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Pending 🟡';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return ListTile(
      onTap: () => _showOrderDetailsDialog(context, order, isDark, numberFormat, dateFormat),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(statusIcon, color: statusColor, size: 20),
      ),
      title: Row(
        children: [
          Text(
            '#${order.orderNumber}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              order.orderType,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
          ),
          if (order.tableNumber != null && order.tableNumber!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              '• Table ${order.tableNumber}',
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'Created: ${dateFormat.format(order.createdAt)} • Status: ${order.status.toUpperCase()} (${order.isPaid ? 'PAID' : 'UNPAID'})',
        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${numberFormat.format(order.grandTotal)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Pending Uploads Tab
  // ---------------------------------------------------------------------------
  Widget _buildPendingUploadsTab(
    BuildContext context,
    CashierSyncCenterState state,
    CashierSyncCenterNotifier notifier,
    bool isDark,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    final pendingOrders = state.allOrders.where((o) => o.syncStatus == 'pending').toList();

    return Column(
      children: [
        // Reassurance Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Uploads: ${pendingOrders.length} order(s)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'These orders are stored safely in your local SQLite database outbox and will upload automatically as soon as the backend server is reachable.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => notifier.triggerManualSync(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 14),
                label: const Text('Sync All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: pendingOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF16A34A)),
                          SizedBox(height: 8),
                          Text(
                            'All orders in this shift are completely synchronized with Cloud!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: pendingOrders.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (ctx, idx) {
                        final order = pendingOrders[idx];
                        final duration = DateTime.now().difference(order.createdAt);
                        final durationStr = duration.inMinutes > 0
                            ? '${duration.inMinutes}m ago'
                            : '${duration.inSeconds}s ago';

                        return ListTile(
                          onTap: () => _showOrderDetailsDialog(context, order, isDark, numberFormat, dateFormat),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                          ),
                          title: Text('#${order.orderNumber} • ${order.orderType} (PKR ${numberFormat.format(order.grandTotal)})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('Created: ${dateFormat.format(order.createdAt)} • Pending for: $durationStr',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Queued in Outbox ⏳', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Failed Uploads Tab
  // ---------------------------------------------------------------------------
  Widget _buildFailedUploadsTab(
    BuildContext context,
    CashierSyncCenterState state,
    CashierSyncCenterNotifier notifier,
    bool isDark,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    final failedOrders = state.allOrders.where((o) => o.syncStatus == 'failed').toList();

    return Column(
      children: [
        if (failedOrders.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${failedOrders.length} Order(s) Failed Synchronization',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Review the failure reasons below and click Retry to re-queue the operation with existing idempotency guarantees.',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => notifier.retryAllFailed(),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        Expanded(
          child: Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: failedOrders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF16A34A)),
                          SizedBox(height: 8),
                          Text(
                            'Zero sync failures! All shift operations are clean.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: failedOrders.length,
                      separatorBuilder: (ctx, idx) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (ctx, idx) {
                        final order = failedOrders[idx];
                        return ListTile(
                          onTap: () => _showOrderDetailsDialog(context, order, isDark, numberFormat, dateFormat),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          ),
                          title: Text('#${order.orderNumber} • PKR ${numberFormat.format(order.grandTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Error: ${order.errorMessage ?? "Rejected by server"}',
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w600)),
                              Text('Retries: ${order.retryCount} • Created: ${dateFormat.format(order.createdAt)}',
                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () => notifier.retryFailedOrder(order.id),
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Shift Sync Timeline Tab
  // ---------------------------------------------------------------------------
  Widget _buildShiftTimelineTab(CashierSyncCenterState state, bool isDark, DateFormat dateFormat) {
    final events = state.timelineEvents;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: events.isEmpty
          ? Center(
              child: Text(
                'No timeline events recorded for this shift.',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (ctx, idx) {
                final ev = events[idx];
                final isLast = idx == events.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time
                      SizedBox(
                        width: 70,
                        child: Text(
                          DateFormat('hh:mm a').format(ev.time),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),

                      // Timeline node line
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: ev.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: ev.color, width: 1.5),
                            ),
                            child: Icon(ev.icon, size: 12, color: ev.color),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(width: 14),

                      // Event details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ev.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ev.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Order Details Modal
  // ---------------------------------------------------------------------------
  void _showOrderDetailsDialog(
    BuildContext context,
    CashierShiftOrderModel order,
    bool isDark,
    NumberFormat numberFormat,
    DateFormat dateFormat,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryRed, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Order #${order.orderNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: ORDER INFORMATION
                _buildSectionHeader('ORDER INFORMATION', isDark),
                const SizedBox(height: 8),
                _buildModalRow('Order Number:', '#${order.orderNumber}', isDark),
                _buildModalRow('Local Order ID:', order.id, isDark),
                _buildModalRow('Order Type:', order.orderType, isDark),
                if (order.tableNumber != null && order.tableNumber!.isNotEmpty)
                  _buildModalRow('Table:', order.tableNumber!, isDark),
                _buildModalRow('Total Amount:', 'PKR ${numberFormat.format(order.grandTotal)}', isDark, isBold: true),
                _buildModalRow('Created Time:', dateFormat.format(order.createdAt), isDark),
                _buildModalRow('Terminal/Device:', order.deviceId, isDark),

                const SizedBox(height: 14),

                // Section 2: ORDER STATUS
                _buildSectionHeader('ORDER STATUS', isDark),
                const SizedBox(height: 8),
                _buildModalRow('Order Status:', order.status.toUpperCase(), isDark),
                _buildModalRow(
                  'Payment Status:',
                  order.isPaid ? 'PAID ✓' : 'UNPAID',
                  isDark,
                  color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),

                const SizedBox(height: 14),

                // Section 3: SYNC INFORMATION
                _buildSectionHeader('SYNC INFORMATION', isDark),
                const SizedBox(height: 8),
                _buildModalRow('Local SQLite Status:', 'Healthy & Persisted (ACID)', isDark, color: const Color(0xFF16A34A)),
                _buildModalRow(
                  'Upload Status:',
                  order.isSynced ? 'Uploaded to PostgreSQL ✓' : (order.syncStatus == 'failed' ? 'Failed ❌' : 'Queued in Outbox ⏳'),
                  isDark,
                  color: order.isSynced ? const Color(0xFF16A34A) : (order.syncStatus == 'failed' ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                ),
                if (order.syncedAt != null)
                  _buildModalRow('Uploaded Timestamp:', dateFormat.format(order.syncedAt!), isDark),
                if (order.operationId != null && order.operationId!.isNotEmpty)
                  _buildModalRow('Operation ID:', order.operationId!, isDark),
                _buildModalRow('Retry Count:', '${order.retryCount}', isDark),

                if (order.syncStatus == 'failed' && order.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sync Failure Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFDC2626))),
                        const SizedBox(height: 4),
                        Text(order.errorMessage!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (order.isPaid &&
              order.status.toLowerCase() != 'refunded' &&
              order.status.toLowerCase() != 'cancelled') ...[
            Builder(
              builder: (ctxBtn) {
                final isOnline = ref.watch(connectivityNotifierProvider).isOnline;
                return Tooltip(
                  message: isOnline ? '' : 'Refund requires an internet connection',
                  child: ElevatedButton.icon(
                    onPressed: isOnline
                        ? () async {
                            final ordersApiService = ref.read(ordersApiServiceProvider);
                            final result = await RefundOrderDialog.show(
                              context,
                              orderId: order.id,
                              orderNumber: order.orderNumber,
                              grandTotal: order.grandTotal,
                              ordersApiService: ordersApiService,
                            );

                            if (result != null && context.mounted) {
                              Navigator.pop(ctx);
                              if (FeatureFlags.offlineFirstEnabled) {
                                try {
                                  final db = ref.read(appDatabaseProvider);
                                  await (db.update(db.localOrders)..where((t) => t.id.equals(order.id)))
                                      .write(const LocalOrdersCompanion(status: Value('cancelled')));
                                } catch (_) {}
                              }
                              await ref.read(cashierSyncCenterProvider.notifier).loadInitialData();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Order #${order.orderNumber} has been successfully refunded.'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    icon: const Icon(Icons.assignment_return_rounded, size: 16),
                    label: Text(
                      isOnline ? 'Refund Order' : 'Refund requires an internet connection',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      disabledForegroundColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                );
              },
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, bool isDark, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? (isDark ? Colors.white : AppColors.textPrimary),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
