import '../../core/network/api_client.dart';

class UsersApiService {
  final ApiClient _apiClient;

  UsersApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /api/users
  Future<List<Map<String, dynamic>>> listUsers() async {
    final response = await _apiClient.get('users');
    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// GET /api/users/:id
  Future<Map<String, dynamic>> getUserById(String id) async {
    final response = await _apiClient.get('users/$id');
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw ApiException('User not found with id: $id');
  }

  /// POST /api/users
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _apiClient.post(
      'users',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      },
    );
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to create user');
  }

  /// PATCH /api/users/:id
  Future<Map<String, dynamic>> updateUser(
    String id, {
    String? username,
    String? email,
    String? role,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;

    final response = await _apiClient.patch('users/$id', body: body);
    if (response is Map<String, dynamic> && response['data'] is Map) {
      return response['data'] as Map<String, dynamic>;
    }
    throw const ApiException('Failed to update user');
  }

  /// PATCH /api/users/:id/password
  Future<void> updatePassword(String id, String newPassword) async {
    await _apiClient.patch(
      'users/$id/password',
      body: {'new_password': newPassword},
    );
  }

  /// DELETE /api/users/:id
  Future<void> deleteUser(String id) async {
    await _apiClient.delete('users/$id');
  }
}
