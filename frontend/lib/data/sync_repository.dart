import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/data_sync_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/sync_api_service.dart';

class DataSyncState {
  final DataSyncSummary summary;
  final List<DataSyncOrder> orders;
  final bool isLoading;
  final bool isSyncing;
  final String selectedSyncFilter; // 'all', 'synced', 'pending'
  final String selectedTypeFilter; // 'all', 'dineIn', 'takeaway', 'delivery'
  final String searchQuery;
  final String? errorMessage;

  const DataSyncState({
    this.summary = const DataSyncSummary(),
    this.orders = const [],
    this.isLoading = false,
    this.isSyncing = false,
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
      selectedSyncFilter: selectedSyncFilter ?? this.selectedSyncFilter,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class DataSyncNotifier extends StateNotifier<DataSyncState> {
  final SyncApiService _syncApiService;

  DataSyncNotifier(this._syncApiService) : super(const DataSyncState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _syncApiService.getSyncOverview(
        syncStatus: state.selectedSyncFilter,
        orderType: state.selectedTypeFilter,
        search: state.searchQuery,
      );
      state = state.copyWith(
        summary: res.summary,
        orders: res.orders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
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
      await _syncApiService.syncSingleOrder(orderId);
      await loadData();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<int> syncAllPending() async {
    state = state.copyWith(isSyncing: true);
    try {
      if (state.orders.isEmpty) {
        await loadData();
      }
      var targetIds = state.orders.where((o) => !o.isSynced).map((o) => o.id).toList();
      // If none found in currently filtered view, fetch complete sync overview
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
  return DataSyncNotifier(api);
});
