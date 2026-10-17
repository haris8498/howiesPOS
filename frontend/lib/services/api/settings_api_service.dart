import '../../core/network/api_client.dart';

class SettingsApiService {
  final ApiClient _apiClient;

  SettingsApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/settings
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _apiClient.get('settings');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    return {};
  }

  /// PATCH /api/settings
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> dto) async {
    final response = await _apiClient.patch('settings', body: dto);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update store settings');
  }
}
