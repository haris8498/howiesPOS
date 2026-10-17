import '../../core/network/api_client.dart';

class KitchenApiService {
  final ApiClient _apiClient;

  KitchenApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/kitchen/orders
  Future<List<Map<String, dynamic>>> getKitchenOrders({
    String? status,
    String? orderType,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all' && status != 'All') {
      params['status'] = status;
    }
    if (orderType != null && orderType.isNotEmpty) {
      params['order_type'] = orderType;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final response = await _apiClient.get('kitchen/orders', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/kitchen/orders/:id
  Future<Map<String, dynamic>> getKitchenOrderById(String id) async {
    final response = await _apiClient.get('kitchen/orders/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Kitchen order not found with id: $id');
  }

  /// PATCH /api/kitchen/orders/:id/status
  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    final response = await _apiClient.patch(
      'kitchen/orders/$id/status',
      body: {'status': status},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update kitchen order status');
  }

  /// PATCH /api/kitchen/orders/:id/cooking
  Future<Map<String, dynamic>> updateCookingTime(String id, int cookingTimeMinutes) async {
    final response = await _apiClient.patch(
      'kitchen/orders/$id/cooking',
      body: {'cooking_time_minutes': cookingTimeMinutes},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update cooking timer');
  }

  /// POST /api/kitchen/orders/:id/send-ticket
  Future<Map<String, dynamic>> sendKitchenTicket(String id) async {
    final response = await _apiClient.post('kitchen/orders/$id/send-ticket');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }
}
