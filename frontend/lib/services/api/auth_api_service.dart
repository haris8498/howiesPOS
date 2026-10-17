import '../../core/network/api_client.dart';
import '../../core/security/token_storage.dart';

class AuthApiService {
  final ApiClient _apiClient;

  AuthApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Authenticate user via POST /api/auth/login
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      'auth/login',
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response is Map<String, dynamic> && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String? ?? '';
      final user = data['user'] as Map<String, dynamic>? ?? {};

      if (accessToken.isNotEmpty) {
        await TokenStorage.saveUserSession(
          token: accessToken,
          userId: user['id']?.toString() ?? '',
          username: user['username']?.toString() ?? username,
          email: user['email']?.toString() ?? '',
          role: user['role']?.toString() ?? 'Cashier',
          isDefault: user['is_default'] == true,
        );
      }

      return data;
    }

    throw const ApiException('Invalid response format from login endpoint.');
  }

  /// Fetch currently authenticated user profile via GET /api/auth/me
  Future<Map<String, dynamic>> getMe() async {
    final response = await _apiClient.get('auth/me');
    if (response is Map<String, dynamic> && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to retrieve user profile.');
  }

  /// Logout user and clear stored JWT session
  Future<void> logout() async {
    await TokenStorage.clearSession();
  }
}
