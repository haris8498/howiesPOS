import '../../core/network/api_client.dart';

class CustomersApiService {
  final ApiClient _apiClient;

  CustomersApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/customers
  Future<List<Map<String, dynamic>>> listCustomers({String? search, String? phone}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (phone != null && phone.isNotEmpty) params['phone'] = phone;

    final response = await _apiClient.get('customers', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/customers/:id
  Future<Map<String, dynamic>> getCustomerById(String id) async {
    final response = await _apiClient.get('customers/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Customer not found with id: $id');
  }

  /// POST /api/customers
  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> dto) async {
    final response = await _apiClient.post('customers', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create customer record');
  }

  /// PATCH /api/customers/:id
  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('customers/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update customer record');
  }

  /// DELETE /api/customers/:id
  Future<void> deleteCustomer(String id) async {
    await _apiClient.delete('customers/$id');
  }
}
