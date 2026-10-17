import '../../core/network/api_client.dart';

class StaffApiService {
  final ApiClient _apiClient;

  StaffApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/staff
  Future<List<Map<String, dynamic>>> listStaff({
    String? search,
    String? role,
    String? status,
    bool? isSalaryPaid,
    String? monthYear,
  }) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (isSalaryPaid != null) params['is_salary_paid'] = isSalaryPaid;
    if (monthYear != null && monthYear.isNotEmpty) params['month_year'] = monthYear;

    final response = await _apiClient.get('staff', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/staff/stats
  Future<Map<String, dynamic>> getStaffStats({String? monthYear}) async {
    final params = <String, dynamic>{};
    if (monthYear != null && monthYear.isNotEmpty) params['month_year'] = monthYear;

    final response = await _apiClient.get('staff/stats', queryParameters: params);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// GET /api/staff/:id
  Future<Map<String, dynamic>> getStaffById(String id) async {
    final response = await _apiClient.get('staff/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('Staff member not found with id: $id');
  }

  /// POST /api/staff
  Future<Map<String, dynamic>> createStaff({
    required String fullName,
    required String phone,
    required String role,
    String status = 'Active',
    String? joiningDate,
    String assignedShift = 'Morning Shift',
    double monthlySalary = 65000.0,
    double hourlyRate = 406.0,
    String? username,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'status': status,
      'assigned_shift': assignedShift,
      'monthly_salary': monthlySalary,
      'hourly_rate': hourlyRate,
    };
    if (joiningDate != null) body['joining_date'] = joiningDate;
    if (username != null) body['username'] = username;
    if (password != null) body['password'] = password;

    final response = await _apiClient.post('staff', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create staff member');
  }

  /// PATCH /api/staff/:id
  Future<Map<String, dynamic>> updateStaff(String id, Map<String, dynamic> updates) async {
    final response = await _apiClient.patch('staff/$id', body: updates);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update staff member');
  }

  /// DELETE /api/staff/:id
  Future<void> deleteStaff(String id) async {
    await _apiClient.delete('staff/$id');
  }

  /// POST /api/staff/:id/salary-settle
  Future<Map<String, dynamic>> settleSalary(String id, {String? monthYear}) async {
    final body = <String, dynamic>{};
    if (monthYear != null) body['month_year'] = monthYear;
    final response = await _apiClient.post('staff/$id/salary-settle', body: body);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// POST /api/staff/:id/toggle-salary
  Future<Map<String, dynamic>> toggleSalary(String id, {String? monthYear}) async {
    final body = <String, dynamic>{};
    if (monthYear != null) body['month_year'] = monthYear;
    final response = await _apiClient.post('staff/$id/toggle-salary', body: body);
    return response['data'] as Map<String, dynamic>? ?? {};
  }
}
