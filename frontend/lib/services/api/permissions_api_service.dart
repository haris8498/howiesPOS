import '../../core/network/api_client.dart';

class PermissionsApiService {
  final ApiClient _apiClient;

  PermissionsApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/permissions/role/:role
  Future<List<Map<String, dynamic>>> getPermissionsByRole(String role) async {
    final response = await _apiClient.get('permissions/role/$role');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// PATCH /api/permissions/:id/toggle
  Future<Map<String, dynamic>> togglePermission(String id) async {
    final response = await _apiClient.patch('permissions/$id/toggle');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to toggle permission');
  }

  /// PATCH /api/permissions/:id
  Future<Map<String, dynamic>> updatePermission(String id, bool isGranted) async {
    final response = await _apiClient.patch(
      'permissions/$id',
      body: {'is_granted': isGranted},
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update permission');
  }

  /// POST /api/permissions/presets
  Future<List<Map<String, dynamic>>> applyPreset({
    required String role,
    required String preset,
  }) async {
    final response = await _apiClient.post(
      'permissions/presets',
      body: {
        'role': role,
        'preset': preset,
      },
    );
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }
}
