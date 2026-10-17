import '../../core/network/api_client.dart';

class ExpensesApiService {
  final ApiClient _apiClient;

  ExpensesApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/expenses
  Future<List<Map<String, dynamic>>> listExpenses({
    String? category,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (category != null && category.isNotEmpty && category != 'All') {
      params['category'] = category;
    }
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get('expenses', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/expenses/summary
  Future<Map<String, dynamic>> getExpenseSummary({
    String? category,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final response = await _apiClient.get('expenses/summary', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// GET /api/expenses/:id
  Future<Map<String, dynamic>> getExpenseById(String id) async {
    final response = await _apiClient.get('expenses/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Expense not found with id: $id');
  }

  /// POST /api/expenses
  Future<Map<String, dynamic>> createExpense({
    required String title,
    required String category,
    required double amount,
    required String date,
    String? note,
    String recordedBy = 'Store Manager',
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'category': category,
      'amount': amount,
      'date': date,
      'recorded_by': recordedBy,
    };
    if (note != null && note.isNotEmpty) {
      body['note'] = note;
    }

    final response = await _apiClient.post('expenses', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create expense record');
  }

  /// PATCH /api/expenses/:id
  Future<Map<String, dynamic>> updateExpense(String id, Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('expenses/$id', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update expense record');
  }

  /// DELETE /api/expenses/:id
  Future<void> deleteExpense(String id) async {
    await _apiClient.delete('expenses/$id');
  }
}
