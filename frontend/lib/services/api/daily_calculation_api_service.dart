import '../../core/network/api_client.dart';

class DailyCalculationApiService {
  final ApiClient _apiClient;

  DailyCalculationApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/daily-calculations/active-session
  Future<Map<String, dynamic>> getActiveSession({String? cashierId}) async {
    final params = <String, dynamic>{};
    if (cashierId != null && cashierId.isNotEmpty) {
      params['cashier_id'] = cashierId;
    }

    final response = await _apiClient.get('daily-calculations/active-session', queryParameters: params);
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }

  /// POST /api/daily-calculations/active-session/expense
  Future<Map<String, dynamic>> addActiveExpense(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('daily-calculations/active-session/expense', body: payload);
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }

  /// DELETE /api/daily-calculations/active-session/expense/:id
  Future<bool> deleteActiveExpense(String id) async {
    final response = await _apiClient.delete('daily-calculations/active-session/expense/$id');
    return response != null;
  }

  /// POST /api/daily-calculations/start-session
  Future<Map<String, dynamic>> startSession(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('daily-calculations/start-session', body: payload);
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }

  /// GET /api/daily-calculations/live-summary
  Future<Map<String, dynamic>> getLiveSummary({String? date, String? cashierId}) async {
    final params = <String, dynamic>{};
    if (date != null && date.isNotEmpty) {
      params['date'] = date;
    }
    if (cashierId != null && cashierId.isNotEmpty) {
      params['cashier_id'] = cashierId;
    }

    final response = await _apiClient.get('daily-calculations/live-summary', queryParameters: params);
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }

  /// POST /api/daily-calculations/submit
  Future<Map<String, dynamic>> submitDailyCalculation(Map<String, dynamic> payload) async {
    final response = await _apiClient.post('daily-calculations/submit', body: payload);
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }

  /// GET /api/daily-calculations
  Future<List<Map<String, dynamic>>> listDailyCalculations({
    String? startDate,
    String? endDate,
    String? cashierId,
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) params['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    if (cashierId != null && cashierId.isNotEmpty) params['cashierId'] = cashierId;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await _apiClient.get('daily-calculations', queryParameters: params);
    if (response is List) {
      return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// GET /api/daily-calculations/:id
  Future<Map<String, dynamic>> getCalculationById(String id) async {
    final response = await _apiClient.get('daily-calculations/$id');
    if (response is Map<String, dynamic>) {
      return response.containsKey('data') && response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
    }
    return {};
  }
}
