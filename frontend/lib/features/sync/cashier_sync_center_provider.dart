import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/feature_flags.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/sync_outbox_table.dart';
import '../../core/sync/connectivity_notifier.dart';
import '../../core/network/realtime_socket_service.dart';
import '../../core/sync/sync_background_worker.dart';
import '../../core/sync/sync_providers.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/cashier_sync_model.dart';
import '../../services/api/api_providers.dart';
import '../../services/api/sync_api_service.dart';

class CashierSyncCenterState {
  final bool isLoading;
  final bool isSyncing;
  final bool isOnline;
  final bool isSocketConnected;
  final CashierShiftModel? currentShift;
  final List<CashierShiftModel> shifts;
  final String? selectedShiftId;
  final CashierSyncSummary summary;
  final List<CashierShiftOrderModel> allOrders;
  final List<CashierShiftOrderModel> filteredOrders;
  final String selectedTypeFilter; // 'all', 'dineIn', 'takeaway', 'delivery'
  final String selectedStatusFilter; // 'all', 'synced', 'pending', 'failed'
  final String searchQuery;
  final List<CashierSyncTimelineEvent> timelineEvents;
  final String? errorMessage;
  final String? successMessage;

  const CashierSyncCenterState({
    this.isLoading = false,
    this.isSyncing = false,
    this.isOnline = true,
    this.isSocketConnected = false,
    this.currentShift,
    this.shifts = const [],
    this.selectedShiftId,
    this.summary = const CashierSyncSummary(),
    this.allOrders = const [],
    this.filteredOrders = const [],
    this.selectedTypeFilter = 'all',
    this.selectedStatusFilter = 'all',
    this.searchQuery = '',
    this.timelineEvents = const [],
    this.errorMessage,
    this.successMessage,
  });

  CashierSyncCenterState copyWith({
    bool? isLoading,
    bool? isSyncing,
    bool? isOnline,
    bool? isSocketConnected,
    CashierShiftModel? currentShift,
    List<CashierShiftModel>? shifts,
    String? selectedShiftId,
    CashierSyncSummary? summary,
    List<CashierShiftOrderModel>? allOrders,
    List<CashierShiftOrderModel>? filteredOrders,
    String? selectedTypeFilter,
    String? selectedStatusFilter,
    String? searchQuery,
    List<CashierSyncTimelineEvent>? timelineEvents,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CashierSyncCenterState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      isSocketConnected: isSocketConnected ?? this.isSocketConnected,
      currentShift: currentShift ?? this.currentShift,
      shifts: shifts ?? this.shifts,
      selectedShiftId: selectedShiftId ?? this.selectedShiftId,
      summary: summary ?? this.summary,
      allOrders: allOrders ?? this.allOrders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      timelineEvents: timelineEvents ?? this.timelineEvents,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class CashierSyncCenterNotifier extends StateNotifier<CashierSyncCenterState> {
  final SyncApiService _syncApi;
  final AppDatabase? _db;
  final ConnectivityNotifier? _connectivity;
  final RealtimeSocketService? _socket;
  final SyncBackgroundWorker? _worker;
  final String _currentUserId;
  final String _currentUsername;

  StreamSubscription? _outboxSub;
  SocketEventCallback? _socketSyncCallback;

  CashierSyncCenterNotifier({
    required SyncApiService syncApi,
    AppDatabase? db,
    ConnectivityNotifier? connectivity,
    RealtimeSocketService? socket,
    SyncBackgroundWorker? worker,
    required String currentUserId,
    required String currentUsername,
  })  : _syncApi = syncApi,
        _db = db,
        _connectivity = connectivity,
        _socket = socket,
        _worker = worker,
        _currentUserId = currentUserId,
        _currentUsername = currentUsername,
        super(const CashierSyncCenterState()) {
    _init();
  }

  void _init() {
    state = state.copyWith(
      isOnline: _connectivity?.isOnline ?? true,
      isSocketConnected: _socket?.isConnected ?? false,
    );

    // 1. Listen to Local Outbox Stream
    final db = _db;
    if (db != null) {
      _outboxSub = db.outboxDao.watchActiveOutboxEntries().listen((entries) {
        if (state.selectedShiftId != null) {
          _refreshShiftOrdersSilently(state.selectedShiftId!);
        }
      });
    }

    // 2. Listen to Socket Realtime Events
    final socket = _socket;
    if (socket != null) {
      _socketSyncCallback = (data) {
        if (state.selectedShiftId != null) {
          _refreshShiftOrdersSilently(state.selectedShiftId!);
        }
      };
      socket.on('sync:success', _socketSyncCallback!);
      socket.on('shift:updated', _socketSyncCallback!);
    }

    loadInitialData();
  }

  @override
  void dispose() {
    _outboxSub?.cancel();
    final socket = _socket;
    if (_socketSyncCallback != null && socket != null) {
      socket.off('sync:success', _socketSyncCallback);
      socket.off('shift:updated', _socketSyncCallback);
    }
    super.dispose();
  }

  /// Initial load: fetch shifts, identify active shift, load its orders
  Future<void> loadInitialData({bool silent = false}) async {
    if (!silent && state.shifts.isEmpty) {
      state = state.copyWith(isLoading: true, clearMessages: true);
    }

    final isOnline = _connectivity?.isOnline ?? true;
    state = state.copyWith(
      isOnline: isOnline,
      isSocketConnected: _socket?.isConnected ?? false,
    );

    List<CashierShiftModel> localShifts = [];
    final db = _db;
    if (FeatureFlags.offlineFirstEnabled && db != null) {
      localShifts = await _loadLocalCashierShifts();
    }

    if (!isOnline) {
      // Offline Mode
      CashierShiftModel? activeShift = localShifts.firstWhere(
        (s) => s.isActive,
        orElse: () => localShifts.isNotEmpty ? localShifts.first : _dummyActiveShift(),
      );

      final shiftToSelect = (state.selectedShiftId == null ||
              state.selectedShiftId == 'LOCAL-SHIFT-01' ||
              !localShifts.any((s) => s.id == state.selectedShiftId))
          ? activeShift.id
          : state.selectedShiftId!;

      state = state.copyWith(
        shifts: localShifts,
        currentShift: activeShift,
        selectedShiftId: shiftToSelect,
        isLoading: false,
      );

      await _loadOrdersForShiftOffline(shiftToSelect);
      return;
    }

    // Online Mode
    try {
      final remoteShiftsJson = await _syncApi.getCashierShifts();
      final remoteShifts = remoteShiftsJson.map((j) => CashierShiftModel.fromJson(j)).toList();

      // Merge remote with local shifts
      final mergedShifts = <CashierShiftModel>[];
      final seenIds = <String>{};

      for (final s in remoteShifts) {
        mergedShifts.add(s);
        seenIds.add(s.id);
      }

      for (final ls in localShifts) {
        if (!seenIds.contains(ls.id)) {
          mergedShifts.add(ls);
          seenIds.add(ls.id);
        }
      }

      CashierShiftModel? activeShift = mergedShifts.firstWhere(
        (s) => s.isActive,
        orElse: () => mergedShifts.isNotEmpty ? mergedShifts.first : _dummyActiveShift(),
      );

      final targetShiftId = (state.selectedShiftId == null ||
              state.selectedShiftId == 'LOCAL-SHIFT-01' ||
              !mergedShifts.any((s) => s.id == state.selectedShiftId))
          ? activeShift.id
          : state.selectedShiftId!;

      state = state.copyWith(
        shifts: mergedShifts,
        currentShift: activeShift,
        selectedShiftId: targetShiftId,
        isLoading: false,
      );

      await selectShift(targetShiftId, silent: silent);
    } catch (e) {
      // Fallback to offline
      CashierShiftModel? activeShift = localShifts.firstWhere(
        (s) => s.isActive,
        orElse: () => localShifts.isNotEmpty ? localShifts.first : _dummyActiveShift(),
      );

      final shiftToSelect = (state.selectedShiftId == null ||
              state.selectedShiftId == 'LOCAL-SHIFT-01' ||
              !localShifts.any((s) => s.id == state.selectedShiftId))
          ? activeShift.id
          : state.selectedShiftId!;

      state = state.copyWith(
        shifts: localShifts,
        currentShift: activeShift,
        selectedShiftId: shiftToSelect,
        isLoading: false,
      );

      await _loadOrdersForShiftOffline(shiftToSelect);
    }
  }

  CashierShiftModel _dummyActiveShift() {
    return CashierShiftModel(
      id: 'LOCAL-SHIFT-01',
      shiftName: 'General Shift',
      cashierId: _currentUserId,
      cashierName: _currentUsername.isNotEmpty ? _currentUsername : 'Cashier',
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      status: 'ACTIVE',
      startingCash: 0.0,
      createdAt: DateTime.now(),
    );
  }

  Future<List<CashierShiftModel>> _loadLocalCashierShifts() async {
    final db = _db;
    if (db == null) return [];
    try {
      final rows = await (db.select(db.localDailyCalculations)
            ..where((t) => t.status.equals('ACTIVE') | t.cashierId.equals(_currentUserId) | t.cashierName.equals(_currentUsername))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();


      return rows.map((r) => CashierShiftModel(
        id: r.id,
        shiftName: 'Shift Session',
        cashierId: r.cashierId,
        cashierName: r.cashierName,
        date: DateFormat('yyyy-MM-dd').format(r.createdAt),
        status: r.status,
        startingCash: r.startingCash,
        createdAt: r.createdAt,
        submittedAt: r.submittedAt,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Select a shift and load its sync ledger
  Future<void> selectShift(String shiftId, {bool silent = false}) async {
    state = state.copyWith(selectedShiftId: shiftId);

    final isOnline = _connectivity?.isOnline ?? true;
    if (!isOnline) {
      await _loadOrdersForShiftOffline(shiftId);
      return;
    }

    try {
      final res = await _syncApi.getCashierShiftDetails(shiftId);
      final rawOrders = res['orders'] as List<dynamic>? ?? [];
      final orders = rawOrders
          .whereType<Map<String, dynamic>>()
          .map((j) => CashierShiftOrderModel.fromJson(j))
          .toList();

      // Merge with any local pending outbox records
      final merged = await _mergeLocalOutboxStatus(shiftId, orders);
      _applyOrdersAndSummary(merged);
    } catch (e) {
      // Offline fallback
      await _loadOrdersForShiftOffline(shiftId);
    }
  }

  Future<void> _refreshShiftOrdersSilently(String shiftId) async {
    await selectShift(shiftId, silent: true);
  }

  Future<void> _loadOrdersForShiftOffline(String shiftId) async {
    final db = _db;
    if (db == null) return;
    try {

      // Query local orders matching shiftId OR unassigned shift
      final orders = await (db.select(db.localOrders)
            ..where((t) => (t.shiftId.equals(shiftId) | t.shiftId.isNull()) & t.isDeleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      // Query outbox
      final outboxEntries = await (db.select(db.syncOutbox)..where((t) => t.entityType.equals('order'))).get();
      final outboxMap = {for (final e in outboxEntries) e.entityId: e};

      final mapped = orders.map((o) {
        final outbox = outboxMap[o.id];
        String syncStatus = 'synced';
        bool isSynced = true;

        if (outbox != null) {
          if (outbox.status == SyncOutboxStatus.failedFatal || outbox.status == SyncOutboxStatus.conflict) {
            syncStatus = 'failed';
            isSynced = false;
          } else if (outbox.status == SyncOutboxStatus.synced) {
            syncStatus = 'synced';
            isSynced = true;
          } else {
            syncStatus = 'pending';
            isSynced = false;
          }
        } else if (o.syncStatus.contains('pending')) {
          syncStatus = 'pending';
          isSynced = false;
        }

        String displayType = 'Dine In';
        if (o.orderType.toLowerCase().contains('takeaway')) {
          displayType = 'Takeaway';
        } else if (o.orderType.toLowerCase().contains('online') || o.orderType.toLowerCase().contains('delivery')) {
          displayType = 'Delivery';
        }

        return CashierShiftOrderModel(
          id: o.id,
          orderNumber: o.orderNumber,
          orderType: displayType,
          rawOrderType: o.orderType,
          customerName: 'Guest',
          status: o.status,
          isPaid: o.isPaid,
          grandTotal: o.grandTotal,
          syncStatus: syncStatus,
          isSynced: isSynced,
          createdAt: o.createdAt,
          syncedAt: outbox?.ackedAt ?? o.serverUpdatedAt,
          deviceId: o.deviceId,
          retryCount: outbox?.retryCount ?? 0,
          errorMessage: outbox?.lastError,
          operationId: outbox?.operationId,
        );
      }).toList();

      _applyOrdersAndSummary(mapped);
    } catch (_) {}
  }

  Future<List<CashierShiftOrderModel>> _mergeLocalOutboxStatus(
    String shiftId,
    List<CashierShiftOrderModel> serverOrders,
  ) async {
    final db = _db;
    if (db == null) return serverOrders;

    try {
      final outboxEntries = await (db.select(db.syncOutbox)..where((t) => t.entityType.equals('order'))).get();
      final outboxMap = {for (final e in outboxEntries) e.entityId: e};

      // Also get any local orders not yet on server

      final localOrders = await (db.select(db.localOrders)
            ..where((t) => (t.shiftId.equals(shiftId) | t.shiftId.isNull()) & t.isDeleted.equals(false)))
          .get();

      final serverOrderIds = {for (final o in serverOrders) o.id};
      final result = List<CashierShiftOrderModel>.from(serverOrders);

      // Add local-only orders that are pending
      for (final lo in localOrders) {
        if (!serverOrderIds.contains(lo.id)) {
          final outbox = outboxMap[lo.id];
          String syncStatus = 'synced';
          bool isSynced = true;

          if (outbox != null) {
            if (outbox.status == SyncOutboxStatus.failedFatal || outbox.status == SyncOutboxStatus.conflict) {
              syncStatus = 'failed';
              isSynced = false;
            } else if (outbox.status == SyncOutboxStatus.synced) {
              syncStatus = 'synced';
              isSynced = true;
            } else {
              syncStatus = 'pending';
              isSynced = false;
            }
          } else if (lo.syncStatus.contains('pending')) {
            syncStatus = 'pending';
            isSynced = false;
          }

          String displayType = 'Dine In';
          if (lo.orderType.toLowerCase().contains('takeaway')) {
            displayType = 'Takeaway';
          } else if (lo.orderType.toLowerCase().contains('online') || lo.orderType.toLowerCase().contains('delivery')) {
            displayType = 'Delivery';
          }

          result.add(CashierShiftOrderModel(
            id: lo.id,
            orderNumber: lo.orderNumber,
            orderType: displayType,
            rawOrderType: lo.orderType,
            customerName: 'Guest',
            status: lo.status,
            isPaid: lo.isPaid,
            grandTotal: lo.grandTotal,
            syncStatus: syncStatus,
            isSynced: isSynced,
            createdAt: lo.createdAt,
            syncedAt: outbox?.ackedAt ?? lo.serverUpdatedAt,
            deviceId: lo.deviceId,
            retryCount: outbox?.retryCount ?? 0,
            errorMessage: outbox?.lastError,
            operationId: outbox?.operationId,
          ));
        }
      }

      // Sort by creation time descending
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (_) {
      return serverOrders;
    }
  }

  void _applyOrdersAndSummary(List<CashierShiftOrderModel> orders) {
    final uploadedCount = orders.where((o) => o.isSynced).length;
    final pendingCount = orders.where((o) => o.syncStatus == 'pending').length;
    final failedCount = orders.where((o) => o.syncStatus == 'failed').length;

    final lastSyncTime = _worker?.lastSuccessAt != null
        ? DateFormat('hh:mm:ss a').format(_worker!.lastSuccessAt!)
        : (uploadedCount > 0 ? DateFormat('hh:mm:ss a').format(DateTime.now()) : 'Never');

    final summary = CashierSyncSummary(
      totalOrders: orders.length,
      uploadedCount: uploadedCount,
      pendingCount: pendingCount,
      failedCount: failedCount,
      lastSyncTime: lastSyncTime,
    );

    // Build timeline events
    final timeline = <CashierSyncTimelineEvent>[];
    final selectedShift = state.shifts.firstWhere(
      (s) => s.id == state.selectedShiftId,
      orElse: () => _dummyActiveShift(),
    );

    timeline.add(CashierSyncTimelineEvent(
      time: selectedShift.createdAt,
      title: 'Shift Started',
      description: 'Opened with starting cash float PKR ${selectedShift.startingCash.toStringAsFixed(0)}',
      icon: Icons.login_rounded,
      color: const Color(0xFF2563EB),
    ));

    for (final o in orders.take(15)) {
      if (o.isSynced) {
        timeline.add(CashierSyncTimelineEvent(
          time: o.syncedAt ?? o.createdAt,
          title: 'Order #${o.orderNumber} Uploaded',
          description: '${o.orderType} • PKR ${o.grandTotal.toStringAsFixed(0)} backed up to PostgreSQL Cloud',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
        ));
      } else if (o.syncStatus == 'failed') {
        timeline.add(CashierSyncTimelineEvent(
          time: o.createdAt,
          title: 'Order #${o.orderNumber} Sync Failed',
          description: o.errorMessage ?? 'Upload rejected by server',
          icon: Icons.error_rounded,
          color: const Color(0xFFDC2626),
        ));
      } else {
        timeline.add(CashierSyncTimelineEvent(
          time: o.createdAt,
          title: 'Order #${o.orderNumber} Queued Locally',
          description: 'Stored safely in local SQLite outbox (Waiting for upload)',
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFD97706),
        ));
      }
    }

    if (selectedShift.submittedAt != null) {
      timeline.add(CashierSyncTimelineEvent(
        time: selectedShift.submittedAt!,
        title: 'Shift Closed',
        description: 'Daily calculation submitted and drawer closed',
        icon: Icons.lock_clock_rounded,
        color: const Color(0xFF64748B),
      ));
    }

    timeline.sort((a, b) => b.time.compareTo(a.time));

    state = state.copyWith(
      allOrders: orders,
      summary: summary,
      timelineEvents: timeline,
    );

    _filterOrders();
  }

  void _filterOrders() {
    var filtered = state.allOrders;

    // Type filter
    if (state.selectedTypeFilter != 'all') {
      final f = state.selectedTypeFilter.toLowerCase();
      filtered = filtered.where((o) {
        final raw = o.rawOrderType.toLowerCase();
        final disp = o.orderType.toLowerCase();
        if (f == 'takeaway' || f == 'take_away') {
          return raw.contains('take') || disp.contains('take');
        }
        if (f == 'delivery' || f == 'online') {
          return raw.contains('deliv') || raw.contains('online') || disp.contains('deliv') || disp.contains('online');
        }
        if (f.contains('dine')) {
          return raw.contains('dine') || disp.contains('dine');
        }
        return raw == f || disp == f;
      }).toList();
    }

    // Status filter
    if (state.selectedStatusFilter != 'all') {
      filtered = filtered.where((o) => o.syncStatus == state.selectedStatusFilter).toList();
    }

    // Search query
    if (state.searchQuery.trim().isNotEmpty) {
      final q = state.searchQuery.trim().toLowerCase();
      filtered = filtered.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          (o.tableNumber != null && o.tableNumber!.toLowerCase().contains(q))).toList();
    }

    state = state.copyWith(filteredOrders: filtered);
  }

  void setTypeFilter(String type) {
    state = state.copyWith(selectedTypeFilter: type);
    _filterOrders();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatusFilter: status);
    _filterOrders();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _filterOrders();
  }

  /// Retry single failed order
  Future<void> retryFailedOrder(String orderId) async {
    final db = _db;
    final worker = _worker;
    if (db != null && worker != null) {
      await (db.update(db.syncOutbox)..where((t) => t.entityId.equals(orderId))).write(
        const SyncOutboxCompanion(
          status: Value(SyncOutboxStatus.pending),
          retryCount: Value(0),
        ),
      );
      await worker.triggerPush(force: true);
      if (state.selectedShiftId != null) {
        await selectShift(state.selectedShiftId!, silent: true);
      }
    }
  }

  /// Retry all failed orders for this shift
  Future<void> retryAllFailed() async {
    final db = _db;
    final worker = _worker;
    if (db != null && worker != null) {
      final failedOrderIds = state.allOrders
          .where((o) => o.syncStatus == 'failed')
          .map((o) => o.id)
          .toList();

      if (failedOrderIds.isNotEmpty) {
        await (db.update(db.syncOutbox)..where((t) => t.entityId.isIn(failedOrderIds))).write(
          const SyncOutboxCompanion(
            status: Value(SyncOutboxStatus.pending),
            retryCount: Value(0),
          ),
        );
      }
      await worker.triggerPush(force: true);
      if (state.selectedShiftId != null) {
        await selectShift(state.selectedShiftId!, silent: true);
      }
    }
  }

  /// Manual trigger sync cycle
  Future<void> triggerManualSync() async {
    state = state.copyWith(isSyncing: true, clearMessages: true);
    final db = _db;
    if (db != null) {
      try {
        await db.outboxDao.resetFailedEntries();
      } catch (_) {}
    }

    final worker = _worker;
    if (worker != null) {
      try {
        if (_currentUsername.isNotEmpty) {
          await worker.trySilentReauth(_currentUsername);
        }
        await worker.triggerPush(force: true);
        await worker.triggerPull();
      } catch (e) {
        state = state.copyWith(errorMessage: 'Sync error: $e');
      }
    }
    state = state.copyWith(isSyncing: false);
    if (state.selectedShiftId != null) {
      await selectShift(state.selectedShiftId!, silent: true);
    }
  }
}

final cashierSyncCenterProvider =
    StateNotifierProvider.autoDispose<CashierSyncCenterNotifier, CashierSyncCenterState>((ref) {
  final api = ref.watch(syncApiServiceProvider);
  final db = FeatureFlags.offlineFirstEnabled ? ref.watch(appDatabaseProvider) : null;
  final connectivity = FeatureFlags.offlineFirstEnabled ? ref.watch(connectivityNotifierProvider.notifier) : null;
  final socket = RealtimeSocketService.instance;
  final worker = FeatureFlags.offlineFirstEnabled ? ref.watch(syncBackgroundWorkerProvider) : null;
  final authState = ref.watch(authProvider);

  return CashierSyncCenterNotifier(
    syncApi: api,
    db: db,
    connectivity: connectivity,
    socket: socket,
    worker: worker,
    currentUserId: authState.currentUser.id,
    currentUsername: authState.currentUser.fullName,
  );
});
