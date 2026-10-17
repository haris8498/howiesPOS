import '../../core/network/api_client.dart';

class TablesApiService {
  final ApiClient _apiClient;

  TablesApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/tables
  Future<List<Map<String, dynamic>>> listTables({String? section, String? status}) async {
    final params = <String, dynamic>{};
    if (section != null && section.isNotEmpty && section != 'All') {
      params['section'] = section;
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }

    final response = await _apiClient.get('tables', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/tables/:id
  Future<Map<String, dynamic>> getTableById(String id) async {
    final response = await _apiClient.get('tables/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Table not found with id: $id');
  }

  /// POST /api/tables
  Future<Map<String, dynamic>> createTable(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('tables', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create table');
  }

  /// PATCH /api/tables/:id
  Future<Map<String, dynamic>> updateTable(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('tables/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update table');
  }

  /// PATCH /api/tables/:id/status
  Future<Map<String, dynamic>> updateTableStatus(
    String id, {
    required String status,
    double? currentBillAmount,
    String? activeOrderId,
    int? currentCustomerCount,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      'active_order_id': activeOrderId,
    };
    if (currentBillAmount != null) body['current_bill_amount'] = currentBillAmount;
    if (currentCustomerCount != null) body['current_customer_count'] = currentCustomerCount;

    final response = await _apiClient.patch('tables/$id/status', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update table status');
  }

  /// POST /api/tables/:id/release
  Future<Map<String, dynamic>> releaseTable(String id) async {
    final response = await _apiClient.post('tables/$id/release');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// POST /api/tables/transfer
  Future<Map<String, dynamic>> transferTable({
    required String fromTableId,
    required String toTableId,
  }) async {
    final response = await _apiClient.post(
      'tables/transfer',
      body: {
        'from_table_id': fromTableId,
        'to_table_id': toTableId,
      },
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to transfer table');
  }

  /// PATCH /api/tables/:id/reservation
  Future<Map<String, dynamic>> updateReservation(
    String id, {
    required String reservedCustomerName,
    String? reservationTime,
    int? partySize,
  }) async {
    final body = <String, dynamic>{
      'reserved_customer_name': reservedCustomerName,
    };
    if (reservationTime != null) body['reservation_time'] = reservationTime;
    if (partySize != null) body['party_size'] = partySize;

    final response = await _apiClient.patch('tables/$id/reservation', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update table reservation');
  }

  /// DELETE /api/tables/:id
  Future<void> deleteTable(String id) async {
    await _apiClient.delete('tables/$id');
  }

  /// GET /api/tables/zones
  Future<List<Map<String, dynamic>>> listZones() async {
    final response = await _apiClient.get('tables/zones');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// POST /api/tables/zones
  Future<Map<String, dynamic>> createZone(String name) async {
    final response = await _apiClient.post('tables/zones', body: {'name': name});
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create zone');
  }

  /// DELETE /api/tables/zones/:idOrName
  Future<void> deleteZone(String idOrName) async {
    await _apiClient.delete('tables/zones/$idOrName');
  }
}
