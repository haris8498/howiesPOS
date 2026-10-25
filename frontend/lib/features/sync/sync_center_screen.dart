import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../core/database/app_database.dart';
import 'sync_center_provider.dart';

class SyncCenterScreen extends ConsumerStatefulWidget {
  final bool isManager;

  const SyncCenterScreen({
    super.key,
    this.isManager = false,
  });

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncCenterProvider);
    final notifier = ref.read(syncCenterProvider.notifier);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header & Status Bar
              _buildTopHeader(context, syncState, notifier, isDark, dateFormat),

              if (!syncState.isOnline) ...[
                const SizedBox(height: 12),
                _buildOfflineBanner(isDark, notifier),
              ],

              const SizedBox(height: 16),

              // KPI Summary Cards
              _buildKpiSummaryCards(syncState, isDark, dateFormat),

              const SizedBox(height: 16),

              // Tab Bar
              _buildTabBar(isDark, syncState),

              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Module Sync Status
                    _buildModulesTab(syncState, notifier, isDark, dateFormat),

                    // Tab 2: Pending Operations
                    _buildPendingOperationsTab(syncState, notifier, isDark, dateFormat),

                    // Tab 3: Failed Sync
                    _buildFailedSyncTab(syncState, notifier, isDark, dateFormat),

                    // Tab 4: Conflicts (Read-Only Audit)
                    _buildConflictsTab(syncState, notifier, isDark, dateFormat),

                    // Tab 5: Sync History
                    _buildSyncHistoryTab(syncState, notifier, isDark, dateFormat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
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
                borderRadius: BorderRadius.circular(10),
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
                      widget.isManager ? 'Manager Sync Center' : 'Owner Sync Center',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildHealthBadge(state.overallHealth),
                  ],
                ),
                const SizedBox(width: 4),
                Text(
                  'Continuous real-time synchronization & offline data resilience',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Action Buttons
        Row(
          children: [
            // Retry All Failed Button
            if (state.failedOperations.isNotEmpty) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => notifier.retryAllFailed(),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: Text('Retry Failed (${state.failedOperations.length})'),
              ),
              const SizedBox(width: 10),
            ],

            // Refresh Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              onPressed: state.isLoading ? null : () => notifier.loadAll(),
              icon: Icon(Icons.refresh_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF334155)),
              label: Text(
                'Refresh',
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),

            // Sync Now Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (state.isSyncingNow || !state.isOnline)
                  ? null
                  : () => notifier.triggerSyncNow(),
              icon: state.isSyncingNow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                state.isSyncingNow ? 'Syncing...' : 'Sync Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthBadge(String health) {
    Color bg;
    Color fg;
    IconData icon;

    switch (health) {
      case 'Healthy':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = Icons.check_circle_rounded;
        break;
      case 'Syncing':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        icon = Icons.autorenew_rounded;
        break;
      case 'Warning':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.warning_amber_rounded;
        break;
      case 'Critical':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        icon = Icons.error_rounded;
        break;
      case 'Offline':
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        icon = Icons.cloud_off_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            health,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(bool isDark, SyncCenterNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'POS is currently in OFFLINE mode. All transactions and edits are safely persisted in local encrypted SQLite. Automatic two-way cloud sync will resume immediately once connectivity is re-established.',
              style: TextStyle(
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => notifier.loadAll(),
            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFD97706)),
            label: const Text('Re-check Link', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards(SyncCenterState state, bool isDark, DateFormat dateFormat) {
    return Row(
      children: [
        // Card 1: Network & Connection
        Expanded(
          child: _buildMetricCard(
            title: 'Network & Backend',
            value: state.isOnline ? 'Online' : 'Offline',
            subtitle: state.backendConnected ? 'API Connected' : 'Unreachable',
            valueColor: state.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            icon: state.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // Card 2: Local SQLite DB & Socket
        Expanded(
          child: _buildMetricCard(
            title: 'Drift DB & Socket',
            value: state.databaseConnected ? 'SQLite Active' : 'DB Error',
            subtitle: state.socketConnected ? 'Socket.IO Live' : 'Socket Reconnecting',
            valueColor: const Color(0xFF2563EB),
            icon: Icons.storage_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // Card 3: Pending Outbox
        Expanded(
          child: _buildMetricCard(
            title: 'Pending Outbox',
            value: state.pendingOperations.length.toString(),
            subtitle: state.pendingOperations.isEmpty ? 'All Caught Up' : 'Queued for Cloud',
            valueColor: state.pendingOperations.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFD97706),
            icon: Icons.upload_file_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // Card 4: Failed Sync
        Expanded(
          child: _buildMetricCard(
            title: 'Failed Mutations',
            value: state.failedOperations.length.toString(),
            subtitle: state.failedOperations.isEmpty ? 'No Errors' : 'Action Required',
            valueColor: state.failedOperations.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            icon: Icons.error_outline_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),

        // Card 5: Conflicts & Last Sync
        Expanded(
          child: _buildMetricCard(
            title: 'Conflicts / Last Sync',
            value: '${state.conflicts.length} Conflicts',
            subtitle: state.lastSyncTime != null
                ? 'Synced ${DateFormat('HH:mm:ss').format(state.lastSyncTime!)}'
                : 'Never Synced',
            valueColor: state.conflicts.isEmpty ? const Color(0xFF0D9488) : const Color(0xFFDC2626),
            icon: Icons.compare_arrows_rounded,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: valueColor, size: 20),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: valueColor,
                    fontWeight: FontWeight.w500,
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

  Widget _buildTabBar(bool isDark, SyncCenterState state) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primaryRed,
        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        indicatorColor: AppColors.primaryRed,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Modules (${state.modules.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.upload_file_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Pending Outbox (${state.pendingOperations.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Failed Sync (${state.failedOperations.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.compare_arrows_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Conflicts (${state.conflicts.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 16),
                const SizedBox(width: 6),
                Text('Sync History (${state.historyTotal})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 1: MODULE SYNC STATUS
  // ----------------------------------------------------
  Widget _buildModulesTab(
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    if (state.modules.isEmpty) {
      return Center(
        child: Text(
          'No modules available for current role',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Module Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Local DB', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Server DB', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Pending', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Failed', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Last Synced', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: state.modules.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getModuleIcon(m.id), size: 16, color: AppColors.primaryRed),
                                const SizedBox(width: 8),
                                Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          DataCell(Text(m.localCount.toString())),
                          DataCell(Text(state.isOnline ? m.serverCount.toString() : '— (Offline)')),
                          DataCell(
                            m.pendingCount > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      m.pendingCount.toString(),
                                      style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  )
                                : const Text('0'),
                          ),
                          DataCell(
                            m.failedCount > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      m.failedCount.toString(),
                                      style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  )
                                : const Text('0'),
                          ),
                          DataCell(Text(dateFormat.format(m.lastSyncedAt))),
                          DataCell(_buildModuleStatusBadge(m.status)),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.sync, size: 18),
                              tooltip: 'Trigger Sync',
                              onPressed: state.isOnline ? () => notifier.triggerSyncNow() : null,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getModuleIcon(String id) {
    switch (id) {
      case 'orders':
        return Icons.receipt_long_rounded;
      case 'order_items':
        return Icons.fastfood_rounded;
      case 'tables':
        return Icons.table_restaurant_rounded;
      case 'menu':
        return Icons.restaurant_menu_rounded;
      case 'categories':
        return Icons.category_rounded;
      case 'deals':
        return Icons.local_offer_rounded;
      case 'staff':
        return Icons.people_alt_rounded;
      case 'customers':
        return Icons.person_rounded;
      case 'delivery':
        return Icons.two_wheeler_rounded;
      case 'inventory':
        return Icons.inventory_2_rounded;
      case 'payments':
        return Icons.payment_rounded;
      case 'expenses':
        return Icons.account_balance_wallet_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'shifts':
        return Icons.calculate_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  Widget _buildModuleStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'synced':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        label = 'Synced';
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Pending';
        break;
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Failed';
        break;
      case 'syncing':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Syncing';
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // ----------------------------------------------------
  // TAB 2: PENDING OPERATIONS
  // ----------------------------------------------------
  Widget _buildPendingOperationsTab(
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    if (state.pendingOperations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
            const SizedBox(height: 12),
            Text(
              'No Pending Mutations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All local operations have been successfully synchronized to the server.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Operation ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Entity Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Retries', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: state.pendingOperations.map((entry) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              entry.operationId.length > 16
                                  ? '${entry.operationId.substring(0, 16)}...'
                                  : entry.operationId,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          DataCell(Text(entry.entityType)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getActionColor(entry.operationType).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                entry.operationType,
                                style: TextStyle(
                                  color: _getActionColor(entry.operationType),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(dateFormat.format(entry.createdAt))),
                          DataCell(Text(entry.retryCount.toString())),
                          DataCell(_buildOutboxStatusBadge(entry.status)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.code_rounded, size: 18),
                                  tooltip: 'Inspect Payload',
                                  onPressed: () => _showPayloadDialog(context, entry.operationId, entry.payload),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.replay_rounded, size: 18, color: AppColors.primaryRed),
                                  tooltip: 'Retry Now',
                                  onPressed: () => notifier.retrySingleOutbox(entry.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
        return const Color(0xFF16A34A);
      case 'UPDATE':
        return const Color(0xFF2563EB);
      case 'DELETE':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildOutboxStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'IN_FLIGHT':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'FAILED_RETRYABLE':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        break;
      case 'FAILED_FATAL':
      case 'CONFLICT':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
      case 'SYNCED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 3: FAILED SYNC
  // ----------------------------------------------------
  Widget _buildFailedSyncTab(
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    if (state.failedOperations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_rounded, size: 48, color: Color(0xFF16A34A)),
            const SizedBox(height: 12),
            Text(
              'Zero Sync Failures',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No failed mutations detected in local database outbox.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Operation ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Entity Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Retries', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Error Message', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: state.failedOperations.map((entry) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              entry.operationId.length > 16
                                  ? '${entry.operationId.substring(0, 16)}...'
                                  : entry.operationId,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                          DataCell(Text(entry.entityType)),
                          DataCell(Text('${entry.retryCount} / 5')),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                entry.lastError ?? entry.conflictDetails ?? 'Unknown error',
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(dateFormat.format(entry.createdAt))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_rounded, size: 18, color: AppColors.primaryRed),
                                  tooltip: 'Retry Operation',
                                  onPressed: () => notifier.retrySingleOutbox(entry.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                                  tooltip: 'Inspect Details',
                                  onPressed: () => _showErrorDetailDialog(context, entry),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 4: CONFLICTS (READ-ONLY AUDIT)
  // ----------------------------------------------------
  Widget _buildConflictsTab(
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    if (state.conflicts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF16A34A)),
            const SizedBox(height: 12),
            Text(
              'No Active Conflicts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All concurrent POS mutations passed OCC version checks without collision.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    ),
                    columns: const [
                      DataColumn(label: Text('Conflict ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Entity Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Conflict Details', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Detected At', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: state.conflicts.map((c) {
                      final detectedAtStr = c['detected_at']?.toString() ?? '';
                      DateTime detectedAt = DateTime.now();
                      try {
                        detectedAt = DateTime.parse(detectedAtStr);
                      } catch (_) {}

                      return DataRow(
                        cells: [
                          DataCell(Text(c['id']?.toString() ?? '—', style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text(c['entity']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 350),
                              child: Text(
                                c['details']?.toString() ?? '—',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c['status']?.toString().toUpperCase() ?? 'PENDING',
                                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          DataCell(Text(dateFormat.format(detectedAt))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.visibility_rounded, size: 18),
                              tooltip: 'View Conflict Details',
                              onPressed: () => _showGenericDialog(
                                context,
                                title: 'Conflict Audit Details',
                                content: jsonEncode(c),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // TAB 5: SYNC HISTORY
  // ----------------------------------------------------
  Widget _buildSyncHistoryTab(
    SyncCenterState state,
    SyncCenterNotifier notifier,
    bool isDark,
    DateFormat dateFormat,
  ) {
    return Column(
      children: [
        // Filter toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Search input
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Operation ID or entity...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (val) => notifier.loadHistory(search: val, page: 1),
                ),
              ),
              const SizedBox(width: 12),

              // Module Filter
              DropdownButton<String>(
                value: state.historyModuleFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Modules')),
                  DropdownMenuItem(value: 'orders', child: Text('Orders')),
                  DropdownMenuItem(value: 'restaurant_tables', child: Text('Tables')),
                  DropdownMenuItem(value: 'daily_calculations', child: Text('Shifts')),
                  DropdownMenuItem(value: 'expenses', child: Text('Expenses')),
                ],
                onChanged: (val) => notifier.loadHistory(module: val, page: 1),
              ),
              const SizedBox(width: 12),

              // Status Filter
              DropdownButton<String>(
                value: state.historyStatusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'SUCCESS', child: Text('Success')),
                  DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                ],
                onChanged: (val) => notifier.loadHistory(status: val, page: 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // History Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 20,
                          horizontalMargin: 16,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          ),
                          columns: const [
                            DataColumn(label: Text('Operation ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Inspect', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: state.history.map((h) {
                            final opId = h['id']?.toString() ?? '—';
                            final tsStr = h['timestamp']?.toString() ?? '';
                            DateTime ts = DateTime.now();
                            try {
                              ts = DateTime.parse(tsStr);
                            } catch (_) {}

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    opId.length > 16 ? '${opId.substring(0, 16)}...' : opId,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  ),
                                ),
                                DataCell(Text(h['module']?.toString() ?? '—')),
                                DataCell(
                                  Text(
                                    h['action']?.toString() ?? '—',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      h['status']?.toString().toUpperCase() ?? 'SUCCESS',
                                      style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                DataCell(Text(dateFormat.format(ts))),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.code_rounded, size: 18),
                                    tooltip: 'View Payload',
                                    onPressed: () => _showPayloadDialog(context, opId, jsonEncode(h['payload'] ?? h)),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
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

  void _showPayloadDialog(BuildContext context, String operationId, String payload) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            Text('Payload: $operationId', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: SelectableText(
              _formatJsonString(payload),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorDetailDialog(BuildContext context, SyncOutboxEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Sync Failure Details', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Operation ID: ${entry.operationId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Entity Type: ${entry.entityType}'),
                Text('Retries: ${entry.retryCount} / 5'),
                const Divider(height: 20),
                const Text('Error Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  entry.lastError ?? entry.conflictDetails ?? 'No details available',
                  style: const TextStyle(color: Color(0xFFDC2626), fontFamily: 'monospace', fontSize: 12),
                ),
                const Divider(height: 20),
                const Text('Payload:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  _formatJsonString(entry.payload),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGenericDialog(BuildContext context, {required String title, required String content}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              _formatJsonString(content),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }
}
