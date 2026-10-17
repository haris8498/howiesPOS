import '../../core/network/api_client.dart';

class ReportsApiService {
  final ApiClient _apiClient;

  ReportsApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/reports/summary
  Future<Map<String, dynamic>> getSummary({
    String? startDate,
    String? endDate,
    String? period,
    String? orderType,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
      params['end_date'] = endDate;
    }
    if (period != null && period.isNotEmpty) params['period'] = period;
    if (orderType != null && orderType.isNotEmpty) {
      params['orderType'] = orderType;
      params['order_type'] = orderType;
    }

    final response = await _apiClient.get('reports/summary', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// GET /api/reports/products
  Future<List<Map<String, dynamic>>> getProductPerformance({
    String? startDate,
    String? endDate,
    String? period,
    String? category,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
      params['end_date'] = endDate;
    }
    if (period != null && period.isNotEmpty) params['period'] = period;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _apiClient.get('reports/products', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/reports/order-types
  Future<List<Map<String, dynamic>>> getOrderTypeStats({
    String? startDate,
    String? endDate,
    String? period,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
      params['end_date'] = endDate;
    }
    if (period != null && period.isNotEmpty) params['period'] = period;

    final response = await _apiClient.get('reports/order-types', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/reports/daily-sales
  Future<List<Map<String, dynamic>>> getDailySalesTrend({
    String? startDate,
    String? endDate,
    String? period,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
      params['end_date'] = endDate;
    }
    if (period != null && period.isNotEmpty) params['period'] = period;

    final response = await _apiClient.get('reports/daily-sales', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  /// GET /api/reports/cancelled-orders
  Future<List<Map<String, dynamic>>> getCancelledOrders({
    String? startDate,
    String? endDate,
    String? period,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['endDate'] = endDate;
      params['end_date'] = endDate;
    }
    if (period != null && period.isNotEmpty) params['period'] = period;

    final response = await _apiClient.get('reports/cancelled-orders', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List)
          .map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }
}
