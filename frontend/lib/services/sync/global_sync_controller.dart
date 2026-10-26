import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/feature_flags.dart';
import '../../core/sync/sync_providers.dart';
import '../../data/customer_repository.dart';
import '../../data/daily_calculation_repository.dart';
import '../../data/delivery_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/kitchen_repository.dart';
import '../../data/network_speed_provider.dart';
import '../../data/online_orders_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/staff_repository.dart';
import '../../data/sync_repository.dart';
import '../../data/table_repository.dart';
import '../../data/takeaway_repository.dart';
import '../../features/reports/reports_providers.dart';

/// Global controller to synchronize offline pending data with Cloud PostgreSQL
/// and refresh live screen state across any module in Hungry Howie's POS.
class GlobalSyncController {
  static Future<void> syncAndRefreshAll({
    required WidgetRef ref,
    required BuildContext context,
    String? currentRoute,
    bool showFeedback = true,
  }) async {
    final syncState = ref.read(dataSyncProvider);
    if (syncState.isSyncing) {
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud synchronization is currently in progress...'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    int syncedCount = 0;
    bool syncSuccess = true;
    String? errorMessage;

    // 0. Explicitly probe health so online status is freshly verified (FLG-04)
    if (FeatureFlags.offlineFirstEnabled) {
      try {
        await ref.read(connectivityNotifierProvider.notifier).probeHealth();
      } catch (_) {}
    }

    final isOnline = ref.read(connectivityNotifierProvider).isOnline;

    // 1. Sync pending offline orders to Cloud if online
    if (isOnline) {
      try {
        syncedCount = await ref.read(dataSyncProvider.notifier).syncAllPending();
      } catch (e) {
        syncSuccess = false;
        errorMessage = e.toString();
      }
    } else {
      syncSuccess = false;
      errorMessage = 'Backend server is offline';
    }

    // 2. Refresh synchronization ledger overview
    try {
      await ref.read(dataSyncProvider.notifier).loadData();
    } catch (_) {}

    // 3. Intelligently refresh route-specific active screen data
    final route = currentRoute?.toLowerCase() ?? '';

    try {
      if (route.contains('table')) {
        await ref.read(tableProvider.notifier).loadTables();
      } else if (route.contains('pos') || route.contains('sales') || route.contains('menu')) {
        await ref.read(posProvider.notifier).refreshMenu();
      } else if (route.contains('takeaway')) {
        await ref.read(takeawayProvider.notifier).loadTakeawayOrders();
      } else if (route.contains('delivery')) {
        await ref.read(deliveryProvider.notifier).loadDeliveryData();
      } else if (route.contains('kitchen')) {
        ref.read(kitchenProvider.notifier).loadKitchenOrders();
      } else if (route.contains('online')) {
        await ref.read(onlineOrdersProvider.notifier).loadOnlineOrders();
      } else if (route.contains('stock') || route.contains('inventory')) {
        await ref.read(inventoryProvider.notifier).loadInventoryData();
      } else if (route.contains('expense')) {
        await ref.read(expenseProvider.notifier).loadExpenses();
      } else if (route.contains('calculation') || route.contains('daily')) {
        await ref.read(dailyCalculationProvider.notifier).fetchLiveSummary();
      } else if (route.contains('customer')) {
        await ref.read(customerProvider.notifier).loadCustomers();
      } else if (route.contains('staff') || route.contains('user')) {
        await ref.read(staffProvider.notifier).loadStaff();
      } else if (route.contains('report') || route.contains('dashboard')) {
        ref.invalidate(reportSummaryProvider);
        ref.invalidate(reportProductsProvider);
        ref.invalidate(cancelledOrdersProvider);
      } else {
        // Universal default refresh
        await ref.read(tableProvider.notifier).loadTables();
        await ref.read(posProvider.notifier).refreshMenu();
      }
    } catch (err) {
      debugPrint('⚠️ [GlobalSyncController] Screen reload error: $err');
    }

    // 4. Retest network health / cloud latency
    try {
      ref.read(networkSpeedProvider.notifier).checkSpeed();
    } catch (_) {}

    // 5. Present polished, non-intrusive feedback toast
    if (showFeedback && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final pendingCount = ref.read(dataSyncProvider).summary.pendingCount;

      if (!syncSuccess || !isOnline) {
        final reason = errorMessage != null ? ' ($errorMessage)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Mode: Backend server is offline$reason. Local orders safely stored in SQLite.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (syncedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cloud Sync Complete: $syncedCount pending order(s) uploaded. All screen data updated.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else if (pendingCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline orders remain pending: $pendingCount waiting for cloud sync worker.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data Synchronized: Everything is up-to-date with Cloud.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
