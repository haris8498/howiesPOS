// ignore_for_file: prefer_initializing_formals
import 'dart:io';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/feature_flags.dart';
import '../core/database/app_database.dart';
import '../core/database/tables/sync_outbox_table.dart';
import '../core/sync/connectivity_notifier.dart';
import '../core/sync/sync_background_worker.dart';
import '../core/sync/sync_providers.dart';
import '../domain/models/data_sync_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/sync_api_service.dart';

class DataSyncState {
  final DataSyncSummary summary;
  final List<DataSyncOrder> orders;
  final List<DataSyncOrder> allOrders;
  final bool isLoading;
  final bool isSyncing;
  final bool isOffline;
  final String selectedSyncFilter; // 'all', 'synced', 'pending', 'failed'
  final String selectedTypeFilter; // 'all', 'dineIn', 'takeaway', 'delivery'
  final String selectedDatePreset; // 'all', 'today', 'yesterday', 'this_week', 'custom'
  final DateTime? selectedDate;
  final String selectedShift; // 'all', 'active', or specific shift id
  final List<Map<String, String>> availableShifts;
  final String searchQuery;
  final String? errorMessage;

  const DataSyncState({
    this.summary = const DataSyncSummary(),
    this.orders = const [],
    this.allOrders = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOffline = false,
    this.selectedSyncFilter = 'all',
    this.selectedTypeFilter = 'all',
    this.selectedDatePreset = 'all',
    this.selectedDate,
    this.selectedShift = 'all',
    this.availableShifts = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  DataSyncState copyWith({
    DataSyncSummary? summary,
    List<DataSyncOrder>? orders,
    List<DataSyncOrder>? allOrders,
    bool? isLoading,
    bool? isSyncing,
    bool? isOffline,
    String? selectedSyncFilter,
    String? selectedTypeFilter,
    String? selectedDatePreset,
    DateTime? selectedDate,
    String? selectedShift,
    List<Map<String, String>>? availableShifts,
    String? searchQuery,
    String? errorMessage,
  }) {
    return DataSyncState(
      summary: summary ?? this.summary,
      orders: orders ?? this.orders,
      allOrders: allOrders ?? this.allOrders,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      selectedSyncFilter: selectedSyncFilter ?? this.selectedSyncFilter,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      selectedDatePreset: selectedDatePreset ?? this.selectedDatePreset,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedShift: selectedShift ?? this.selectedShift,
      availableShifts: availableShifts ?? this.availableShifts,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class DataSyncNotifier extends StateNotifier<DataSyncState> {
  final SyncApiService _syncApiService;
  final AppDatabase? _db;
  final ConnectivityNotifier? _connectivity;
  final SyncBackgroundWorker? _worker;

  DataSyncNotifier(
    this._syncApiService, {
    AppDatabase? db,
    ConnectivityNotifier? connectivity,
    SyncBackgroundWorker? worker,
  })  : _db = db,
        _connectivity = connectivity,
        _worker = worker,
        super(const DataSyncState()) {
    loadData();
  }

  Future<List<DataSyncOrder>> _loadLocalOrders() async {
    final db = _db;
    if (db == null) return [];
    try {
      final orders = await (db.select(db.localOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
      if (orders.isEmpty) return [];

      final outboxEntries = await (db.select(db.syncOutbox)..where((t) => t.entityType.equals('order'))).get();
      final outboxMap = {for (final e in outboxEntries) e.entityId: e};

      final allItems = await db.select(db.localOrderItems).get();
      final itemsByOrder = <String, List<String>>{};
      for (final it in allItems) {
        if (!it.isCancelled) {
          itemsByOrder.putIfAbsent(it.orderId, () => []).add('${it.quantity}x ${it.itemName}');
        }
      }

      return orders.map((o) {
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

        final itemsList = itemsByOrder[o.id] ?? [];
        final itemsSummary = itemsList.join(', ');

        String displayType = 'Dine-In';
        if (o.orderType.toLowerCase().contains('takeaway')) {
          displayType = 'Takeaway';
        } else if (o.orderType.toLowerCase().contains('online') || o.orderType.toLowerCase().contains('delivery')) {
          displayType = 'Delivery';
        }

        return DataSyncOrder(
          id: o.id,
          orderNumber: o.orderNumber,
          orderType: displayType,
          rawOrderType: o.orderType,
          typeAndTable: displayType == 'Dine-In' ? 'Dine-In' : displayType,
          customerName: 'Walk-in Guest',
          itemsSummary: itemsSummary.isNotEmpty ? itemsSummary : 'Items Ordered',
          paymentMethod: o.isPaid ? 'Cash' : 'Unpaid',
          paymentStatus: o.paymentStatus,
          isPaid: o.isPaid,
          totalAmount: o.grandTotal,
          createdAt: o.createdAt,
          syncStatus: syncStatus,
          isSynced: isSynced,
          syncedAt: outbox?.ackedAt ?? o.serverUpdatedAt,
          localSqliteId: o.id,
          deviceId: o.deviceId,
          sourceStorage: 'SQLite Local',
          targetStorage: 'PostgreSQL Cloud',
          shiftId: o.shiftId,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, String>>> _loadAvailableShifts() async {
    final db = _db;
    if (db == null) return [];
    try {
      final shifts = await (db.select(db.localDailyCalculations)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      return shifts.map((s) => {
        'id': s.id,
        'name': '${s.cashierName} (${s.status}) - ${DateFormat('MM/dd HH:mm').format(s.createdAt)}',
        'status': s.status,
        'cashierName': s.cashierName,
        'createdAt': s.createdAt.toIso8601String(),
        'submittedAt': s.submittedAt?.toIso8601String() ?? '',
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<DataSyncOrder> _filterOrders(List<DataSyncOrder> orders) {
    var filtered = orders;

    // 1. Sync Status Filter
    if (state.selectedSyncFilter != 'all') {
      if (state.selectedSyncFilter == 'synced') {
        filtered = filtered.where((o) => o.isSynced).toList();
      } else if (state.selectedSyncFilter == 'pending') {
        filtered = filtered.where((o) => !o.isSynced && o.syncStatus != 'failed').toList();
      } else if (state.selectedSyncFilter == 'failed') {
        filtered = filtered.where((o) => o.syncStatus == 'failed').toList();
      }
    }

    // 2. Order Type Filter
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

    // 3. Date Filter (Owner Portal Feature)
    if (state.selectedDatePreset != 'all') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (state.selectedDatePreset == 'today') {
        filtered = filtered.where((o) {
          final od = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
          return od.isAtSameMomentAs(today);
        }).toList();
      } else if (state.selectedDatePreset == 'yesterday') {
        final yesterday = today.subtract(const Duration(days: 1));
        filtered = filtered.where((o) {
          final od = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
          return od.isAtSameMomentAs(yesterday);
        }).toList();
      } else if (state.selectedDatePreset == 'this_week') {
        final weekAgo = today.subtract(const Duration(days: 7));
        filtered = filtered.where((o) => o.createdAt.isAfter(weekAgo)).toList();
      } else if (state.selectedDatePreset == 'custom' && state.selectedDate != null) {
        final custom = DateTime(state.selectedDate!.year, state.selectedDate!.month, state.selectedDate!.day);
        filtered = filtered.where((o) {
          final od = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
          return od.isAtSameMomentAs(custom);
        }).toList();
      }
    }

    // 4. Shift Filter (Cashier Portal Feature)
    if (state.selectedShift != 'all') {
      if (state.selectedShift == 'active') {
        final activeShift = state.availableShifts.firstWhere((s) => s['status'] == 'ACTIVE' || s['status'] == 'active', orElse: () => {});
        final activeId = activeShift['id'];
        final createdAtStr = activeShift['createdAt'];
        final activeStart = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
        filtered = filtered.where((o) {
          if (activeId != null && activeId.isNotEmpty && o.shiftId == activeId) {
            return true;
          }
          if (activeStart != null && (o.shiftId == null || o.shiftId!.isEmpty)) {
            return o.createdAt.isAfter(activeStart) || o.createdAt.isAtSameMomentAs(activeStart);
          }
          if (activeId == null || activeId.isEmpty) {
            return true;
          }
          return false;
        }).toList();
      } else {
        final selectedShift = state.availableShifts.firstWhere((s) => s['id'] == state.selectedShift, orElse: () => {});
        final sId = selectedShift['id'];
        final startStr = selectedShift['createdAt'];
        final endStr = selectedShift['submittedAt'];
        final startTime = startStr != null ? DateTime.tryParse(startStr) : null;
        final endTime = (endStr != null && endStr.isNotEmpty) ? DateTime.tryParse(endStr) : null;
        filtered = filtered.where((o) {
          if (sId != null && sId.isNotEmpty && o.shiftId == sId) {
            return true;
          }
          if (startTime != null && (o.shiftId == null || o.shiftId!.isEmpty)) {
            final afterStart = o.createdAt.isAfter(startTime) || o.createdAt.isAtSameMomentAs(startTime);
            final beforeEnd = endTime == null || o.createdAt.isBefore(endTime) || o.createdAt.isAtSameMomentAs(endTime);
            return afterStart && beforeEnd;
          }
          return false;
        }).toList();
      }
    }

    // 5. Search Query Filter
    if (state.searchQuery.trim().isNotEmpty) {
      final q = state.searchQuery.trim().toLowerCase();
      filtered = filtered.where((o) =>
          o.orderNumber.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.itemsSummary.toLowerCase().contains(q)).toList();
    }

    return filtered;
  }

  void _applyFilters() {
    final filtered = _filterOrders(state.allOrders);
    final totalRevenue = filtered.fold<double>(0.0, (sum, o) => sum + o.totalAmount);
    final syncedCount = filtered.where((o) => o.isSynced).length;
    final pendingCount = filtered.where((o) => !o.isSynced && o.syncStatus != 'failed').length;

    state = state.copyWith(
      orders: filtered,
      summary: DataSyncSummary(
        totalOrders: filtered.length,
        totalRevenue: totalRevenue,
        syncedCount: syncedCount,
        pendingCount: pendingCount,
        lastSyncTimestamp: state.summary.lastSyncTimestamp,
        sqliteStorageStatus: state.summary.sqliteStorageStatus,
        cloudStorageStatus: state.summary.cloudStorageStatus,
      ),
    );
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent && state.allOrders.isEmpty) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    List<DataSyncOrder> localOrders = [];
    List<Map<String, String>> shifts = [];
    if (FeatureFlags.offlineFirstEnabled && _db != null) {
      localOrders = await _loadLocalOrders();
      shifts = await _loadAvailableShifts();
    }

    final isOnline = _connectivity?.isOnline ?? true;
    if (FeatureFlags.offlineFirstEnabled && !isOnline) {
      final totalRevenue = localOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
      final syncedCount = localOrders.where((o) => o.isSynced).length;
      final pendingCount = localOrders.where((o) => !o.isSynced).length;

      state = state.copyWith(
        summary: DataSyncSummary(
          totalOrders: localOrders.length,
          totalRevenue: totalRevenue,
          syncedCount: syncedCount,
          pendingCount: pendingCount,
          lastSyncTimestamp: _worker?.lastSuccessAt != null
              ? DateFormat('hh:mm:ss a').format(_worker!.lastSuccessAt!)
              : '',
          sqliteStorageStatus: 'HEALTHY',
          cloudStorageStatus: 'OFFLINE',
        ),
        allOrders: localOrders,
        availableShifts: shifts,
        isLoading: false,
        isOffline: true,
      );
      _applyFilters();
      return;
    }

    try {
      final res = await _syncApiService.getSyncOverview(
        syncStatus: state.selectedSyncFilter,
        orderType: state.selectedTypeFilter,
        search: state.searchQuery,
      );

      final mergedOrders = <DataSyncOrder>[];
      final seenIds = <String>{};

      if (FeatureFlags.offlineFirstEnabled) {
        final pendingLocal = localOrders.where((o) => !o.isSynced);
        for (final p in pendingLocal) {
          mergedOrders.add(p);
          seenIds.add(p.id);
        }
      }

      for (final s in res.orders) {
        if (!seenIds.contains(s.id)) {
          mergedOrders.add(s);
          seenIds.add(s.id);
        }
      }

      final totalPending = FeatureFlags.offlineFirstEnabled
          ? localOrders.where((o) => !o.isSynced).length
          : res.summary.pendingCount;

      state = state.copyWith(
        summary: DataSyncSummary(
          totalOrders: res.summary.totalOrders + (mergedOrders.length - res.orders.length),
          totalRevenue: res.summary.totalRevenue,
          syncedCount: res.summary.syncedCount,
          pendingCount: totalPending,
          lastSyncTimestamp: res.summary.lastSyncTimestamp,
          sqliteStorageStatus: 'HEALTHY',
          cloudStorageStatus: 'CONNECTED',
        ),
        allOrders: mergedOrders,
        availableShifts: shifts,
        isLoading: false,
        isOffline: false,
      );
      _applyFilters();
    } catch (e) {
      if (FeatureFlags.offlineFirstEnabled && localOrders.isNotEmpty) {
        final totalRevenue = localOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
        final syncedCount = localOrders.where((o) => o.isSynced).length;
        final pendingCount = localOrders.where((o) => !o.isSynced).length;

        state = state.copyWith(
          summary: DataSyncSummary(
            totalOrders: localOrders.length,
            totalRevenue: totalRevenue,
            syncedCount: syncedCount,
            pendingCount: pendingCount,
            lastSyncTimestamp: _worker?.lastSuccessAt != null
                ? DateFormat('hh:mm:ss a').format(_worker!.lastSuccessAt!)
                : '',
            sqliteStorageStatus: 'HEALTHY',
            cloudStorageStatus: 'DISCONNECTED',
          ),
          allOrders: localOrders,
          availableShifts: shifts,
          isLoading: false,
          isOffline: true,
        );
        _applyFilters();
      } else {
        final isNetErr = e is SocketException || e.toString().contains('SocketException') || e.toString().contains('Connection refused');
        state = state.copyWith(
          isLoading: false,
          errorMessage: isNetErr ? 'Cannot connect to backend server' : e.toString(),
          isOffline: true,
        );
      }
    }
  }

  Future<void> setSyncFilter(String filter) async {
    state = state.copyWith(selectedSyncFilter: filter);
    _applyFilters();
  }

  Future<void> setTypeFilter(String type) async {
    state = state.copyWith(selectedTypeFilter: type);
    _applyFilters();
  }

  Future<void> setDatePreset(String preset, {DateTime? customDate}) async {
    state = state.copyWith(selectedDatePreset: preset, selectedDate: customDate);
    _applyFilters();
  }

  Future<void> setShiftFilter(String shiftId) async {
    state = state.copyWith(selectedShift: shiftId);
    _applyFilters();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  Future<void> syncSingleOrder(String orderId) async {
    state = state.copyWith(isSyncing: true);
    try {
      final worker = _worker;
      if (FeatureFlags.offlineFirstEnabled && worker != null) {
        final db = _db;
        if (db != null) {
          await (db.update(db.syncOutbox)
                ..where((t) => t.entityId.equals(orderId)))
              .write(const SyncOutboxCompanion(
                status: Value(SyncOutboxStatus.pending),
                retryCount: Value(0),
              ));
        }
        await worker.triggerPush(force: true);
      }

      // Also mark synced on cloud backend ledger
      try {
        await _syncApiService.syncSingleOrder(orderId);
      } catch (_) {}

      await loadData(silent: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<int> syncAllPending() async {
    state = state.copyWith(isSyncing: true);
    try {
      final worker = _worker;
      if (FeatureFlags.offlineFirstEnabled && worker != null) {
        final db = _db;
        if (db != null) {
          await db.outboxDao.resetFailedEntries();
        }

        if (worker.state.isCircuitBreakerTripped) {
          worker.stateNotifier.updateState(
            worker.state.copyWith(
              isCircuitBreakerTripped: false,
              consecutiveTimeouts: 0,
              lastError: null,
            ),
          );
        }

        final pendingBefore = state.summary.pendingCount;
        await worker.triggerPush(force: true);

        try {
          final pendingIds = state.allOrders.where((o) => !o.isSynced).map((o) => o.id).toList();
          if (pendingIds.isNotEmpty) {
            await _syncApiService.syncBatchOrders(pendingIds);
          }
        } catch (_) {}

        await loadData(silent: true);
        final pendingAfter = state.summary.pendingCount;

        if (worker.state.lastError != null && worker.state.lastError!.isNotEmpty) {
          state = state.copyWith(errorMessage: worker.state.lastError);
        }

        final actuallySynced = pendingBefore - pendingAfter;
        return actuallySynced > 0 ? actuallySynced : 0;
      }

      if (state.allOrders.isEmpty) {
        await loadData(silent: true);
      }
      var targetIds = state.allOrders.where((o) => !o.isSynced).map((o) => o.id).toList();
      if (targetIds.isEmpty) {
        final fullRes = await _syncApiService.getSyncOverview();
        targetIds = fullRes.orders.where((o) => !o.isSynced).map((o) => o.id).toList();
      }
      if (targetIds.isEmpty) {
        await loadData(silent: true);
        return 0;
      }
      final count = await _syncApiService.syncBatchOrders(targetIds);
      await loadData(silent: true);
      return count;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return 0;
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> clearFailedErrors() async {
    try {
      final db = _db;
      if (db != null) {
        await db.outboxDao.clearFailedEntries();
      }
      await loadData(silent: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleOrderSyncStatus(String orderId) async {
    try {
      await _syncApiService.toggleSyncStatus(orderId);
      await loadData(silent: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final dataSyncProvider = StateNotifierProvider<DataSyncNotifier, DataSyncState>((ref) {
  final api = ref.watch(syncApiServiceProvider);
  final db = FeatureFlags.offlineFirstEnabled ? ref.watch(appDatabaseProvider) : null;
  final connectivity = FeatureFlags.offlineFirstEnabled ? ref.watch(connectivityNotifierProvider.notifier) : null;
  final worker = FeatureFlags.offlineFirstEnabled ? ref.watch(syncBackgroundWorkerProvider) : null;
  return DataSyncNotifier(api, db: db, connectivity: connectivity, worker: worker);
});
