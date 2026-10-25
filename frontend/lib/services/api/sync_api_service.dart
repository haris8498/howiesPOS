import '../../core/network/api_client.dart';
import '../../domain/models/data_sync_model.dart';

class SyncApiService {
  final ApiClient _apiClient;

  SyncApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/sync/overview
  Future<({DataSyncSummary summary, List<DataSyncOrder> orders})> getSyncOverview({
    String? syncStatus,
    String? orderType,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (syncStatus != null && syncStatus.isNotEmpty) queryParams['sync_status'] = syncStatus;
    if (orderType != null && orderType.isNotEmpty) queryParams['order_type'] = orderType;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _apiClient.get('sync/overview', queryParameters: queryParams);

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      final summary = data['summary'] != null
          ? DataSyncSummary.fromJson(data['summary'] as Map<String, dynamic>)
          : const DataSyncSummary();

      final ordersRaw = data['orders'] as List<dynamic>? ?? [];
      final orders = ordersRaw
          .whereType<Map<String, dynamic>>()
          .map((j) => DataSyncOrder.fromJson(j))
          .toList();

      return (summary: summary, orders: orders);
    }

    throw const ApiException('Failed to load data sync overview');
  }

  /// POST /api/sync/order/:id
  Future<void> syncSingleOrder(String orderId) async {
    final response = await _apiClient.post('sync/order/$orderId');
    if (response is Map<String, dynamic> && response['success'] == true) {
      return;
    }
    throw const ApiException('Failed to sync order to cloud');
  }

  /// POST /api/sync/batch
  Future<int> syncBatchOrders(List<String> orderIds) async {
    final response = await _apiClient.post('sync/batch', body: {
      'orders': orderIds.map((id) => {'id': id}).toList(),
      'device_id': 'POS-TERMINAL-01',
    });

    if (response is Map<String, dynamic> && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      return (data['synced_count'] as num?)?.toInt() ?? 0;
    }

    return 0;
  }

  /// POST /api/sync/toggle/:id
  Future<void> toggleSyncStatus(String orderId, {String? status}) async {
    await _apiClient.post('sync/toggle/$orderId', body: {
      if (status != null) 'status': status,
    });
  }

  /// GET /api/sync/modules
  Future<List<Map<String, dynamic>>> getSyncModules() async {
    try {
      final response = await _apiClient.get('sync/modules');
      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/sync/history
  Future<Map<String, dynamic>> getSyncHistory({
    int page = 1,
    int limit = 30,
    String? module,
    String? status,
    String? search,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (module != null && module.isNotEmpty && module != 'all') {
        query['module'] = module;
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        query['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        query['search'] = search;
      }

      final response = await _apiClient.get('sync/history', queryParameters: query);
      if (response is Map<String, dynamic>) {
        return response;
      }
      return {
        'data': <dynamic>[],
        'meta': {'total': 0, 'page': page, 'limit': limit, 'totalPages': 0}
      };
    } catch (_) {
      return {
        'data': <dynamic>[],
        'meta': {'total': 0, 'page': page, 'limit': limit, 'totalPages': 0}
      };
    }
  }

  /// GET /api/sync/conflicts
  Future<List<Map<String, dynamic>>> getSyncConflicts() async {
    try {
      final response = await _apiClient.get('sync/conflicts');
      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/sync/cashier-shifts
  Future<List<Map<String, dynamic>>> getCashierShifts() async {
    try {
      final response = await _apiClient.get('sync/cashier-shifts');
      if (response is Map<String, dynamic> && response['data'] is List) {
        return (response['data'] as List).whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /api/sync/cashier-shift/:shiftId
  Future<Map<String, dynamic>> getCashierShiftDetails(String shiftId) async {
    try {
      final response = await _apiClient.get('sync/cashier-shift/$shiftId');
      if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      rethrow;
    }
  }
}
