import '../../core/network/api_client.dart';

class DeliveryApiService {
  final ApiClient _apiClient;

  DeliveryApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // ----------------------------------------------------
  // RIDERS
  // ----------------------------------------------------

  /// GET /api/delivery/riders
  Future<List<Map<String, dynamic>>> listRiders({
    bool? isClockedIn,
    bool? isAvailable,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (isClockedIn != null) params['is_clocked_in'] = isClockedIn;
    if (isAvailable != null) params['is_available'] = isAvailable;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get('delivery/riders', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/delivery/riders
  Future<Map<String, dynamic>> createRider(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('delivery/riders', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to register rider');
  }

  /// PATCH /api/delivery/riders/:id
  Future<Map<String, dynamic>> updateRider(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('delivery/riders/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update rider');
  }

  /// PATCH /api/delivery/riders/:id/duty
  Future<Map<String, dynamic>> toggleRiderDuty(String id, bool isClockedIn) async {
    final response = await _apiClient.patch(
      'delivery/riders/$id/duty',
      body: {'is_clocked_in': isClockedIn},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to toggle rider duty status');
  }

  /// DELETE /api/delivery/riders/:id
  Future<void> deleteRider(String id) async {
    await _apiClient.delete('delivery/riders/$id');
  }

  // ----------------------------------------------------
  // DISPATCHES
  // ----------------------------------------------------

  /// GET /api/delivery/dispatches
  Future<List<Map<String, dynamic>>> listDispatches({
    String? status,
    String? riderId,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') {
      params['dispatch_status'] = status;
    }
    if (riderId != null) params['rider_id'] = riderId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get('delivery/dispatches', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/delivery/dispatches
  Future<Map<String, dynamic>> createDispatch(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('delivery/dispatches', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create dispatch record');
  }

  /// POST /api/delivery/dispatches/:id/assign
  Future<Map<String, dynamic>> assignRider(
    String id, {
    required String riderId,
    String? estimatedDeliveryTime,
  }) async {
    final body = <String, dynamic>{'rider_id': riderId};
    if (estimatedDeliveryTime != null) {
      body['estimated_delivery_time'] = estimatedDeliveryTime;
    }

    final response = await _apiClient.post('delivery/dispatches/$id/assign', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to assign rider');
  }

  /// PATCH /api/delivery/dispatches/:id/status
  Future<Map<String, dynamic>> updateDispatchStatus(
    String id,
    String status,
  ) async {
    final response = await _apiClient.patch(
      'delivery/dispatches/$id/status',
      body: {'dispatch_status': status},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update dispatch status');
  }

  /// DELETE /api/delivery/dispatches/:id
  Future<void> deleteDispatch(String id) async {
    await _apiClient.delete('delivery/dispatches/$id');
  }
}
