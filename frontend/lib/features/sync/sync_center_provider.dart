import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/sync_outbox_table.dart';
import '../../core/network/realtime_socket_service.dart';
import '../../core/sync/connectivity_notifier.dart';
import '../../config/feature_flags.dart';
import '../../core/sync/sync_background_worker.dart';
import '../../core/sync/sync_providers.dart';
import '../../data/role_rights_repository.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';
import '../../services/api/api_providers.dart';
import '../../services/api/sync_api_service.dart';

class SyncModuleInfo {
  final String id;
  final String name;
  final int localCount;
  final int serverCount;
  final DateTime lastSyncedAt;
  final String status; // 'synced', 'syncing', 'pending', 'failed', 'conflict'
  final int pendingCount;
  final int failedCount;

  const SyncModuleInfo({
    required this.id,
    required this.name,
    required this.localCount,
    required this.serverCount,
    required this.lastSyncedAt,
    required this.status,
    required this.pendingCount,
    required this.failedCount,
  });

  SyncModuleInfo copyWith({
    String? id,
    String? name,
    int? localCount,
    int? serverCount,
    DateTime? lastSyncedAt,
    String? status,
    int? pendingCount,
    int? failedCount,
  }) {
    return SyncModuleInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      localCount: localCount ?? this.localCount,
      serverCount: serverCount ?? this.serverCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

class SyncCenterState {
  final bool isOnline;
  final bool backendConnected;
  final bool databaseConnected;
  final bool socketConnected;
  final DateTime? lastSyncTime;
  final String overallHealth; // 'Healthy', 'Syncing', 'Warning', 'Critical', 'Offline'
  final List<SyncModuleInfo> modules;
  final List<SyncOutboxEntry> pendingOperations;
  final List<SyncOutboxEntry> failedOperations;
  final List<Map<String, dynamic>> conflicts;
  final List<Map<String, dynamic>> history;
  final int historyTotal;
  final int historyPage;
  final int historyLimit;
  final String historyModuleFilter;
  final String historyStatusFilter;
  final String historySearchQuery;
  final bool isLoading;
  final bool isSyncingNow;
  final String? errorMessage;

  const SyncCenterState({
    this.isOnline = true,
    this.backendConnected = true,
    this.databaseConnected = true,
    this.socketConnected = false,
    this.lastSyncTime,
    this.overallHealth = 'Healthy',
    this.modules = const [],
    this.pendingOperations = const [],
    this.failedOperations = const [],
    this.conflicts = const [],
    this.history = const [],
    this.historyTotal = 0,
    this.historyPage = 1,
    this.historyLimit = 30,
    this.historyModuleFilter = 'all',
    this.historyStatusFilter = 'all',
    this.historySearchQuery = '',
    this.isLoading = false,
    this.isSyncingNow = false,
    this.errorMessage,
  });

  SyncCenterState copyWith({
    bool? isOnline,
    bool? backendConnected,
    bool? databaseConnected,
    bool? socketConnected,
    DateTime? lastSyncTime,
    String? overallHealth,
    List<SyncModuleInfo>? modules,
    List<SyncOutboxEntry>? pendingOperations,
    List<SyncOutboxEntry>? failedOperations,
    List<Map<String, dynamic>>? conflicts,
    List<Map<String, dynamic>>? history,
    int? historyTotal,
    int? historyPage,
    int? historyLimit,
    String? historyModuleFilter,
    String? historyStatusFilter,
    String? historySearchQuery,
    bool? isLoading,
    bool? isSyncingNow,
    String? errorMessage,
  }) {
    return SyncCenterState(
      isOnline: isOnline ?? this.isOnline,
      backendConnected: backendConnected ?? this.backendConnected,
      databaseConnected: databaseConnected ?? this.databaseConnected,
      socketConnected: socketConnected ?? this.socketConnected,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      overallHealth: overallHealth ?? this.overallHealth,
      modules: modules ?? this.modules,
      pendingOperations: pendingOperations ?? this.pendingOperations,
      failedOperations: failedOperations ?? this.failedOperations,
      conflicts: conflicts ?? this.conflicts,
      history: history ?? this.history,
      historyTotal: historyTotal ?? this.historyTotal,
      historyPage: historyPage ?? this.historyPage,
      historyLimit: historyLimit ?? this.historyLimit,
      historyModuleFilter: historyModuleFilter ?? this.historyModuleFilter,
      historyStatusFilter: historyStatusFilter ?? this.historyStatusFilter,
      historySearchQuery: historySearchQuery ?? this.historySearchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSyncingNow: isSyncingNow ?? this.isSyncingNow,
      errorMessage: errorMessage,
    );
  }
}

class SyncCenterNotifier extends StateNotifier<SyncCenterState> {
  final AppDatabase? _db;
  final SyncApiService _syncApi;
  final ConnectivityNotifier _connectivity;
  final RealtimeSocketService _socket;
  final SyncBackgroundWorker? _worker;
  final RoleRightsState _roleRights;
  final UserRole _userRole;

  StreamSubscription<List<SyncOutboxEntry>>? _outboxSub;
  StreamSubscription<bool>? _socketSub;

  SyncCenterNotifier({
    AppDatabase? db,
    required SyncApiService syncApi,
    required ConnectivityNotifier connectivity,
    required RealtimeSocketService socket,
    SyncBackgroundWorker? worker,
    required RoleRightsState roleRights,
    required UserRole userRole,
  })  : _db = db,
        _syncApi = syncApi,
        _connectivity = connectivity,
        _socket = socket,
        _worker = worker,
        _roleRights = roleRights,
        _userRole = userRole,
        super(SyncCenterState(databaseConnected: db != null)) {
    _init();
  }

  void _init() {
    // 1. Initial State
    state = state.copyWith(
      isOnline: _connectivity.isOnline,
      socketConnected: _socket.isConnected,
      databaseConnected: _db != null,
      lastSyncTime: _worker?.lastSuccessAt ?? DateTime.now(),
    );

    // 2. Listen to Outbox Changes from SQLite Drift if active
    if (_db != null) {
      _outboxSub = _db!.outboxDao.watchActiveOutboxEntries().listen((entries) {
      final pending = entries.where((e) =>
          e.status == SyncOutboxStatus.pending ||
          e.status == SyncOutboxStatus.inFlight ||
          e.status == SyncOutboxStatus.failedRetryable).toList();

      final failed = entries.where((e) =>
          e.status == SyncOutboxStatus.failedFatal ||
          e.status == SyncOutboxStatus.conflict ||
          e.retryCount >= 5).toList();

      state = state.copyWith(
        pendingOperations: pending,
        failedOperations: failed,
      );
      _recalculateHealth();
    });
    }

    // 3. Listen to Socket Connection
    _socketSub = _socket.connectionStream.listen((connected) {
      state = state.copyWith(socketConnected: connected);
      _recalculateHealth();
    });

    // 4. Listen to Socket.IO Sync Events
    _socket.on('sync:status_updated', _onSocketSyncStatusUpdated);
    _socket.on('sync:outbox_updated', _onSocketOutboxUpdated);
    _socket.on('sync:conflict', _onSocketConflict);
    _socket.on('sync:pushed', _onSocketPushed);
    _socket.on('sync:pulled', _onSocketPulled);

    // 5. Initial Data Load
    loadAll();
  }

  void _onSocketSyncStatusUpdated(Map<String, dynamic> data) {
    debugPrint('[SyncCenter] Received sync:status_updated');
    loadModules();
  }

  void _onSocketOutboxUpdated(Map<String, dynamic> data) {
    debugPrint('[SyncCenter] Received sync:outbox_updated');
    loadHistory();
  }

  void _onSocketConflict(Map<String, dynamic> data) {
    debugPrint('[SyncCenter] Received sync:conflict');
    loadConflicts();
  }

  void _onSocketPushed(Map<String, dynamic> data) {
    state = state.copyWith(lastSyncTime: DateTime.now());
    loadModules();
    loadHistory();
  }

  void _onSocketPulled(Map<String, dynamic> data) {
    state = state.copyWith(lastSyncTime: DateTime.now());
    loadModules();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Future.wait([
        loadModules(),
        loadHistory(),
        loadConflicts(),
      ]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
      _recalculateHealth();
    }
  }

  Future<void> loadModules() async {
    // 1. Fetch Local Drift Database counts using select(table).get()
    final localOrders = _db != null ? await _safeCount(() => _db!.select(_db!.localOrders).get().then((v) => v.length)) : 0;
    final localItems = _db != null ? await _safeCount(() => _db!.select(_db!.localOrderItems).get().then((v) => v.length)) : 0;
    final localTables = _db != null ? await _safeCount(() => _db!.select(_db!.localRestaurantTables).get().then((v) => v.length)) : 0;
    final localMenu = _db != null ? await _safeCount(() => _db!.select(_db!.localMenuItems).get().then((v) => v.length)) : 0;
    final localCats = _db != null ? await _safeCount(() => _db!.select(_db!.localMenuCategories).get().then((v) => v.length)) : 0;
    final localDeals = _db != null ? await _safeCount(() => _db!.select(_db!.localDeals).get().then((v) => v.length)) : 0;
    final localStaff = _db != null ? await _safeCount(() => _db!.select(_db!.localStaffUsers).get().then((v) => v.length)) : 0;
    final localSettings = _db != null ? await _safeCount(() => _db!.select(_db!.localStoreSettings).get().then((v) => v.length)) : 0;
    final localShifts = _db != null ? await _safeCount(() => _db!.select(_db!.localDailyCalculations).get().then((v) => v.length)) : 0;
    final localPayments = _db != null ? await _safeCount(() => _db!.select(_db!.localOrderPayments).get().then((v) => v.length)) : 0;

    // 2. Fetch Server counts if online
    List<Map<String, dynamic>> serverModules = [];
    if (_connectivity.isOnline) {
      serverModules = await _syncApi.getSyncModules();
    }

    final serverMap = <String, Map<String, dynamic>>{};
    for (final sm in serverModules) {
      final id = sm['id']?.toString() ?? '';
      serverMap[id] = sm;
    }

    // 3. Define Master Modules List
    final allModules = [
      _createModule('orders', 'Orders', localOrders, serverMap['orders']),
      _createModule('order_items', 'Order Items', localItems, serverMap['order_items']),
      _createModule('tables', 'Tables & Floor', localTables, serverMap['tables']),
      _createModule('menu', 'Menu Items', localMenu, serverMap['menu']),
      _createModule('categories', 'Categories', localCats, serverMap['categories']),
      _createModule('deals', 'Deals & Combos', localDeals, serverMap['deals']),
      _createModule('staff', 'Staff & Roles', localStaff, serverMap['staff']),
      _createModule('customers', 'Customers', 0, serverMap['customers']),
      _createModule('delivery', 'Delivery Dispatches', 0, serverMap['delivery']),
      _createModule('inventory', 'Inventory & Stock', 0, serverMap['inventory']),
      _createModule('payments', 'Payments', localPayments, serverMap['payments']),
      _createModule('expenses', 'Expenses', 0, serverMap['expenses']),
      _createModule('settings', 'Store Settings', localSettings, serverMap['settings']),
      _createModule('shifts', 'Daily Shifts', localShifts, serverMap['shifts']),
    ];

    // 4. Apply Manager RBAC Filtering if needed
    final filtered = allModules.where((m) => _isModuleAllowedForRole(m.id)).toList();

    state = state.copyWith(
      modules: filtered,
      isOnline: _connectivity.isOnline,
      backendConnected: _connectivity.isOnline,
      lastSyncTime: _worker?.lastSuccessAt ?? state.lastSyncTime ?? DateTime.now(),
    );
    _recalculateHealth();
  }

  bool _isModuleAllowedForRole(String moduleId) {
    if (_userRole == UserRole.owner) return true;
    switch (moduleId) {
      case 'orders':
      case 'order_items':
        return _roleRights.isModuleGranted(UserRole.manager, 'pos', defaultIfMissing: true);
      case 'tables':
        return _roleRights.isModuleGranted(UserRole.manager, 'tables', defaultIfMissing: true);
      case 'menu':
      case 'categories':
      case 'deals':
        return _roleRights.isModuleGranted(UserRole.manager, 'menu', defaultIfMissing: true);
      case 'staff':
        return _roleRights.isModuleGranted(UserRole.manager, 'staff', defaultIfMissing: false);
      case 'customers':
        return true;
      case 'delivery':
        return _roleRights.isModuleGranted(UserRole.manager, 'delivery', defaultIfMissing: true);
      case 'inventory':
        return _roleRights.isModuleGranted(UserRole.manager, 'stock', defaultIfMissing: true);
      case 'payments':
        return true;
      case 'expenses':
        return _roleRights.isModuleGranted(UserRole.manager, 'expenses', defaultIfMissing: true);
      case 'settings':
        return false; // Sensitive owner settings hidden from managers
      case 'shifts':
        return _roleRights.isModuleGranted(UserRole.manager, 'daily_calculation', defaultIfMissing: true);
      default:
        return true;
    }
  }

  SyncModuleInfo _createModule(String id, String name, int localCount, Map<String, dynamic>? serverData) {
    final serverCount = (serverData?['server_count'] as num?)?.toInt() ?? localCount;
    DateTime lastSyncedAt = DateTime.now();
    if (serverData?['last_synced_at'] != null) {
      try {
        lastSyncedAt = DateTime.parse(serverData!['last_synced_at'].toString());
      } catch (_) {}
    }

    final pCount = state.pendingOperations.where((o) => o.entityType.toLowerCase().contains(id.replaceAll('_', ''))).length;
    final fCount = state.failedOperations.where((o) => o.entityType.toLowerCase().contains(id.replaceAll('_', ''))).length;

    String status = 'synced';
    if (!_connectivity.isOnline) {
      status = pCount > 0 ? 'pending' : 'synced';
    } else if (fCount > 0) {
      status = 'failed';
    } else if (pCount > 0) {
      status = 'pending';
    }

    return SyncModuleInfo(
      id: id,
      name: name,
      localCount: localCount,
      serverCount: serverCount,
      lastSyncedAt: lastSyncedAt,
      status: status,
      pendingCount: pCount,
      failedCount: fCount,
    );
  }

  Future<void> loadHistory({int? page, String? module, String? status, String? search}) async {
    final targetPage = page ?? state.historyPage;
    final targetModule = module ?? state.historyModuleFilter;
    final targetStatus = status ?? state.historyStatusFilter;
    final targetSearch = search ?? state.historySearchQuery;

    if (!_connectivity.isOnline) {
      if (_db == null) {
        state = state.copyWith(history: [], historyTotal: 0);
        return;
      }
      // Local fallback: read all outbox history from Drift SQLite
      final allOutbox = await _db!.outboxDao.getAllEntries();
      final mapped = allOutbox.map((e) => {
        'id': e.operationId,
        'action': e.operationType,
        'module': e.entityType,
        'status': e.status.toUpperCase(),
        'timestamp': e.createdAt.toIso8601String(),
        'retries': e.retryCount,
        'payload': e.payload,
      }).toList();

      state = state.copyWith(
        history: mapped.reversed.take(50).toList(),
        historyTotal: mapped.length,
        historyPage: 1,
        historyLimit: 50,
        historyModuleFilter: targetModule,
        historyStatusFilter: targetStatus,
        historySearchQuery: targetSearch,
      );
      return;
    }

    final result = await _syncApi.getSyncHistory(
      page: targetPage,
      limit: state.historyLimit,
      module: targetModule,
      status: targetStatus,
      search: targetSearch,
    );

    final data = (result['data'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final meta = result['meta'] as Map<String, dynamic>? ?? {};

    state = state.copyWith(
      history: data,
      historyTotal: (meta['total'] as num?)?.toInt() ?? data.length,
      historyPage: (meta['page'] as num?)?.toInt() ?? targetPage,
      historyModuleFilter: targetModule,
      historyStatusFilter: targetStatus,
      historySearchQuery: targetSearch,
    );
  }

  Future<void> loadConflicts() async {
    if (_connectivity.isOnline) {
      final serverConflicts = await _syncApi.getSyncConflicts();
      state = state.copyWith(conflicts: serverConflicts);
    } else {
      if (_db == null) {
        state = state.copyWith(conflicts: []);
        return;
      }
      // Local SQLite Drift conflicts
      final localConflicts = await (_db!.select(_db!.syncConflicts)).get();
      final mapped = localConflicts.map((c) => {
        'id': c.id,
        'entity': c.entityType,
        'details': c.errorMessage ?? c.conflictType,
        'status': c.resolutionStatus.toUpperCase(),
        'detected_at': c.createdAt.toIso8601String(),
      }).toList();
      state = state.copyWith(conflicts: mapped);
    }
  }

  Future<void> triggerSyncNow() async {
    if (state.isSyncingNow) return;
    state = state.copyWith(isSyncingNow: true);
    try {
      if (_worker != null) {
        await _worker!.triggerPush(force: true);
        await _worker!.triggerPull();
      }
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Sync error: $e');
    } finally {
      state = state.copyWith(isSyncingNow: false);
      _recalculateHealth();
    }
  }

  Future<void> retrySingleOutbox(int id) async {
    try {
      if (_db != null) {
        await _db!.outboxDao.resetSingleEntry(id);
      }
      if (_worker != null) {
        await _worker!.triggerPush(force: true);
      }
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Retry failed: $e');
    }
  }

  Future<void> retryAllFailed() async {
    try {
      if (_db != null) {
        await _db!.outboxDao.resetFailedEntries();
      }
      if (_worker != null) {
        await _worker!.triggerPush(force: true);
      }
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to reset all: $e');
    }
  }

  void _recalculateHealth() {
    if (!_connectivity.isOnline) {
      state = state.copyWith(overallHealth: 'Offline');
      return;
    }
    if (state.failedOperations.isNotEmpty) {
      state = state.copyWith(overallHealth: 'Critical');
      return;
    }
    if (state.pendingOperations.isNotEmpty || state.conflicts.isNotEmpty) {
      state = state.copyWith(overallHealth: 'Warning');
      return;
    }
    if (state.isSyncingNow) {
      state = state.copyWith(overallHealth: 'Syncing');
      return;
    }
    state = state.copyWith(overallHealth: 'Healthy');
  }

  Future<int> _safeCount(Future<int> Function() counter) async {
    try {
      return await counter();
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _outboxSub?.cancel();
    _socketSub?.cancel();
    _socket.off('sync:status_updated', _onSocketSyncStatusUpdated);
    _socket.off('sync:outbox_updated', _onSocketOutboxUpdated);
    _socket.off('sync:conflict', _onSocketConflict);
    _socket.off('sync:pushed', _onSocketPushed);
    _socket.off('sync:pulled', _onSocketPulled);
    super.dispose();
  }
}

final syncCenterProvider = StateNotifierProvider.autoDispose<SyncCenterNotifier, SyncCenterState>((ref) {
  // SYNC-039: Guard Drift DB and sync worker behind FeatureFlags.offlineFirstEnabled to prevent leak when OFF
  final db = FeatureFlags.offlineFirstEnabled ? ref.watch(appDatabaseProvider) : null;
  final syncApi = ref.watch(syncApiServiceProvider);
  final connectivity = ref.watch(connectivityNotifierProvider.notifier);
  final socket = ref.watch(realtimeSocketServiceProvider);
  final worker = FeatureFlags.offlineFirstEnabled ? ref.watch(syncBackgroundWorkerProvider) : null;
  final roleRights = ref.watch(roleRightsProvider);
  final userRole = ref.watch(authProvider).currentUser.role;

  return SyncCenterNotifier(
    db: db,
    syncApi: syncApi,
    connectivity: connectivity,
    socket: socket,
    worker: worker,
    roleRights: roleRights,
    userRole: userRole,
  );
});
