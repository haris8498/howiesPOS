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
      'status': ?status,
    });
  }
}
