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
  final bool isLoading;
  final bool isSyncing;
  final bool isOffline;
  final String selectedSyncFilter; // 'all', 'synced', 'pending', 'failed'
  final String selectedTypeFilter; // 'all', 'dineIn', 'takeaway', 'delivery'
  final String searchQuery;
  final String? errorMessage;

  const DataSyncState({
    this.summary = const DataSyncSummary(),
    this.orders = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOffline = false,
    this.selectedSyncFilter = 'all',
    this.selectedTypeFilter = 'all',
    this.searchQuery = '',
    this.errorMessage,
  });

  DataSyncState copyWith({
    DataSyncSummary? summary,
    List<DataSyncOrder>? orders,
    bool? isLoading,
    bool? isSyncing,
    bool? isOffline,
    String? selectedSyncFilter,
    String? selectedTypeFilter,
    String? searchQuery,
    String? errorMessage,
  }) {
    return DataSyncState(
      summary: summary ?? this.summary,
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOffline: isOffline ?? this.isOffline,
      selectedSyncFilter: selectedSyncFilter ?? this.selectedSyncFilter,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
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
          if (outbox.status == SyncOutboxStatus.failedFatal || outbox.status == SyncOutboxStatus.failedRetryable) {
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
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<DataSyncOrder> _filterOrders(List<DataSyncOrder> orders) {
    var filtered = orders;

    if (state.selectedSyncFilter != 'all') {
      if (state.selectedSyncFilter == 'synced') {
        filtered = filtered.where((o) => o.isSynced).toList();
      } else if (state.selectedSyncFilter == 'pending') {
        filtered = filtered.where((o) => !o.isSynced && o.syncStatus != 'failed').toList();
      } else if (state.selectedSyncFilter == 'failed') {
        filtered = filtered.where((o) => o.syncStatus == 'failed').toList();
      }
    }

    if (state.selectedTypeFilter != 'all') {
      filtered = filtered.where((o) =>
          o.rawOrderType.toLowerCase() == state.selectedTypeFilter.toLowerCase() ||
          o.orderType.toLowerCase() == state.selectedTypeFilter.toLowerCase()).toList();
    }

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

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    List<DataSyncOrder> localOrders = [];
    if (FeatureFlags.offlineFirstEnabled && _db != null) {
      localOrders = await _loadLocalOrders();
    }

    final isOnline = _connectivity?.isOnline ?? true;
    if (FeatureFlags.offlineFirstEnabled && !isOnline) {
      final filtered = _filterOrders(localOrders);
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
        orders: filtered,
        isLoading: false,
        isOffline: true,
      );
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
        for (final p in _filterOrders(pendingLocal.toList())) {
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
        orders: mergedOrders,
        isLoading: false,
        isOffline: false,
      );
    } catch (e) {
      if (FeatureFlags.offlineFirstEnabled && localOrders.isNotEmpty) {
        final filtered = _filterOrders(localOrders);
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
          orders: filtered,
          isLoading: false,
          isOffline: true,
        );
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
    await loadData();
  }

  Future<void> setTypeFilter(String type) async {
    state = state.copyWith(selectedTypeFilter: type);
    await loadData();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadData();
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
        await worker.triggerPush();
        await loadData();
      } else {
        await _syncApiService.syncSingleOrder(orderId);
        await loadData();
      }
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
          // Reset any conflict entries to pending so they can be re-evaluated
          await (db.update(db.syncOutbox)
                ..where((t) => t.status.equals(SyncOutboxStatus.conflict)))
              .write(const SyncOutboxCompanion(
                status: Value(SyncOutboxStatus.pending),
                retryCount: Value(0),
              ));
        }

        // Reset tripped circuit breaker on explicit manual sync request
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
        await worker.triggerPush();
        await loadData();
        final pendingAfter = state.summary.pendingCount;

        if (worker.state.lastError != null && worker.state.lastError!.isNotEmpty) {
          state = state.copyWith(errorMessage: worker.state.lastError);
        }

        final actuallySynced = pendingBefore - pendingAfter;
        return actuallySynced > 0 ? actuallySynced : 0;
      }

      if (state.orders.isEmpty) {
        await loadData();
      }
      var targetIds = state.orders.where((o) => !o.isSynced).map((o) => o.id).toList();
      if (targetIds.isEmpty) {
        final fullRes = await _syncApiService.getSyncOverview();
        targetIds = fullRes.orders.where((o) => !o.isSynced).map((o) => o.id).toList();
      }
      if (targetIds.isEmpty) {
        await loadData();
        return 0;
      }
      final count = await _syncApiService.syncBatchOrders(targetIds);
      await loadData();
      return count;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return 0;
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> toggleOrderSyncStatus(String orderId) async {
    try {
      await _syncApiService.toggleSyncStatus(orderId);
      await loadData();
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
