import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/realtime_socket_service.dart';
import '../../data/customer_repository.dart';
import '../../data/daily_calculation_repository.dart';
import '../../data/delivery_repository.dart';
import '../../data/expense_repository.dart';
import '../../data/inventory_repository.dart';
import '../../data/kitchen_repository.dart';
import '../../data/online_orders_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../data/staff_repository.dart';
import '../../data/table_repository.dart';
import '../../data/takeaway_repository.dart';
import '../../features/reports/reports_providers.dart';

/// Centralized Realtime State Synchronization Manager.
/// Binds real-time Socket.IO events to Riverpod state invalidations and automatic UI updates.
class RealtimeSyncManager {
  final Ref _ref;
  final RealtimeSocketService _socket;
  final Map<String, Timer> _debounceTimers = {};
  bool _isInitialized = false;

  RealtimeSyncManager(this._ref, this._socket);

  /// Initialize real-time synchronization listeners across all POS modules.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('[RealtimeSyncManager] Initializing application-wide real-time listeners...');

    // 1. MENU & DEALS
    _socket.on('menu:item_created', (_) => _refreshMenu());
    _socket.on('menu:item_updated', (_) => _refreshMenu());
    _socket.on('menu:item_deleted', (_) => _refreshMenu());
    _socket.on('menu:updated', (_) => _refreshMenu());
    _socket.on('category:created', (_) => _refreshMenu());
    _socket.on('category:updated', (_) => _refreshMenu());
    _socket.on('category:deleted', (_) => _refreshMenu());
    _socket.on('deal:created', (_) => _refreshMenu());
    _socket.on('deal:updated', (_) => _refreshMenu());
    _socket.on('deal:deleted', (_) => _refreshMenu());
    _socket.on('menu:size_updated', (_) => _refreshMenu());
    _socket.on('menu:option_updated', (_) => _refreshMenu());

    // 2. TABLES & FLOOR ZONES
    _socket.on('table:created', (_) => _refreshTables());
    _socket.on('table:updated', (_) => _refreshTables());
    _socket.on('table:deleted', (_) => _refreshTables());
    _socket.on('table:status_changed', (_) => _refreshTables());
    _socket.on('table:transferred', (_) => _refreshTables());
    _socket.on('table:zone_created', (_) => _refreshTables());
    _socket.on('table:zone_deleted', (_) => _refreshTables());

    // 3. ORDERS (Affects Tables, Takeaway, Delivery, Online, Kitchen, Shift calculation)
    _socket.on('order:created', (_) => _handleOrderEvent());
    _socket.on('order:updated', (_) => _handleOrderEvent());
    _socket.on('order:status_changed', (_) => _handleOrderEvent());
    _socket.on('order:ready', (_) => _handleOrderEvent());
    _socket.on('order:cancelled', (_) => _handleOrderEvent());
    _socket.on('kitchen:ticket_sent', (_) => _handleOrderEvent());

    // 4. DELIVERY & RIDERS
    _socket.on('rider:created', (_) => _refreshDelivery());
    _socket.on('rider:updated', (_) => _refreshDelivery());
    _socket.on('rider:deleted', (_) => _refreshDelivery());
    _socket.on('delivery:dispatch_created', (_) => _refreshDelivery());
    _socket.on('delivery:rider_assigned', (_) => _refreshDelivery());
    _socket.on('delivery:status_changed', (_) => _refreshDelivery());
    _socket.on('delivery:dispatch_deleted', (_) => _refreshDelivery());
    _socket.on('delivery:updated', (_) => _refreshDelivery());

    // 5. STAFF & USERS & PERMISSIONS
    _socket.on('staff:created', (_) => _refreshStaff());
    _socket.on('staff:updated', (_) => _refreshStaff());
    _socket.on('staff:deleted', (_) => _refreshStaff());
    _socket.on('user:updated', (_) {
      _refreshStaff();
      _refreshPermissions();
    });
    _socket.on('permission:updated', (_) => _refreshPermissions());

    // 6. SHIFTS & EXPENSES & DAILY CALCULATION
    _socket.on('shift:started', (_) => _refreshShift());
    _socket.on('shift:closed', (_) => _refreshShift());
    _socket.on('shift:updated', (_) => _refreshShift());
    _socket.on('expense:created', (_) {
      _refreshExpenses();
      _refreshShift();
    });
    _socket.on('expense:updated', (_) {
      _refreshExpenses();
      _refreshShift();
    });
    _socket.on('expense:deleted', (_) {
      _refreshExpenses();
      _refreshShift();
    });

    // 7. INVENTORY
    _socket.on('inventory:item_created', (_) => _refreshInventory());
    _socket.on('inventory:item_updated', (_) => _refreshInventory());
    _socket.on('inventory:item_deleted', (_) => _refreshInventory());
    _socket.on('inventory:stock_movement', (_) => _refreshInventory());
    _socket.on('inventory:updated', (_) => _refreshInventory());

    // 8. CUSTOMERS
    _socket.on('customer:created', (_) => _refreshCustomers());
    _socket.on('customer:updated', (_) => _refreshCustomers());
    _socket.on('customer:deleted', (_) => _refreshCustomers());

    // 9. RECONNECTION / RESYNC HANDLER (§8)
    _socket.onReconnect(() {
      debugPrint('[RealtimeSyncManager] Reconnection detected! Syncing all active modules with backend...');
      _resyncAllModules();
    });
  }

  void _debounce(String key, VoidCallback action, {int delayMs = 250}) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(Duration(milliseconds: delayMs), () {
      _debounceTimers.remove(key);
      try {
        action();
      } catch (err) {
        debugPrint('[RealtimeSyncManager] Debounced action error ($key): $err');
      }
    });
  }

  void _refreshMenu() {
    _debounce('menu', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Menu & Catalog...');
      _ref.read(posProvider.notifier).refreshMenu(silent: true);
    });
  }

  void _refreshTables() {
    _debounce('tables', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Tables...');
      _ref.read(tableProvider.notifier).loadTables(silent: true);
    });
  }

  void _refreshDelivery() {
    _debounce('delivery', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Delivery & Riders...');
      _ref.read(deliveryProvider.notifier).loadDeliveryData(silent: true);
    });
  }

  void _refreshStaff() {
    _debounce('staff', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Staff...');
      _ref.read(staffProvider.notifier).loadStaff();
    });
  }

  void _refreshPermissions() {
    _debounce('permissions', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Role Rights & Permissions...');
      _ref.read(roleRightsProvider.notifier).loadPermissions(force: true);
    });
  }

  void _refreshShift() {
    _debounce('shift', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Shift & Daily Calculation live summary...');
      _ref.read(dailyCalculationProvider.notifier).fetchLiveSummary();
    });
  }

  void _refreshExpenses() {
    _debounce('expenses', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Expenses...');
      _ref.read(expenseProvider.notifier).loadExpenses();
    });
  }

  void _refreshInventory() {
    _debounce('inventory', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Inventory...');
      _ref.read(inventoryProvider.notifier).loadInventoryData();
    });
  }

  void _refreshCustomers() {
    _debounce('customers', () {
      debugPrint('[RealtimeSyncManager] Invaliding and refreshing Customers...');
      _ref.read(customerProvider.notifier).loadCustomers();
    });
  }

  void _handleOrderEvent() {
    _debounce('orders', () {
      debugPrint('[RealtimeSyncManager] Order mutation received. Refreshing active order views...');
      // Tables reflect active dine-in orders and bill totals
      _ref.read(tableProvider.notifier).loadTables(silent: true);
      // Takeaway queue
      _ref.read(takeawayProvider.notifier).loadTakeawayOrders(silent: true);
      // Delivery tracking
      _ref.read(deliveryProvider.notifier).loadDeliveryData(silent: true);
      // Online web/app orders
      _ref.read(onlineOrdersProvider.notifier).loadOnlineOrders();
      // Kitchen KDS orders
      _ref.read(kitchenProvider.notifier).loadKitchenOrders();
      // Live daily calculation summary
      _ref.read(dailyCalculationProvider.notifier).fetchLiveSummary();
      // Invalidate analytical reports
      _ref.invalidate(reportSummaryProvider);
      _ref.invalidate(reportProductsProvider);
      _ref.invalidate(cancelledOrdersProvider);
    });
  }

  void _resyncAllModules() {
    _debounce('resync_all', () {
      _ref.read(tableProvider.notifier).loadTables(silent: true);
      _ref.read(posProvider.notifier).refreshMenu(silent: true);
      _ref.read(takeawayProvider.notifier).loadTakeawayOrders(silent: true);
      _ref.read(deliveryProvider.notifier).loadDeliveryData(silent: true);
      _ref.read(onlineOrdersProvider.notifier).loadOnlineOrders();
      _ref.read(kitchenProvider.notifier).loadKitchenOrders();
      _ref.read(dailyCalculationProvider.notifier).fetchLiveSummary();
      _ref.read(staffProvider.notifier).loadStaff();
    }, delayMs: 100);
  }

  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _socket.clearAllListeners();
    _socket.clearReconnectListeners();
    _isInitialized = false;
  }
}

/// Provider for RealtimeSyncManager
final realtimeSyncManagerProvider = Provider<RealtimeSyncManager>((ref) {
  final socket = ref.watch(realtimeSocketServiceProvider);
  final manager = RealtimeSyncManager(ref, socket);
  manager.initialize();
  ref.onDispose(() {
    manager.dispose();
  });
  return manager;
});
