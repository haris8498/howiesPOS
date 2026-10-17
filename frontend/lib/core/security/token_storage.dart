import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_role.dart';

/// Secure token & session persistence layer
class TokenStorage {
  static const String _keyToken = 'auth_jwt_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyIsDefault = 'auth_user_is_default';

  static String? _cachedToken;

  /// Cache token in memory for synchronous access during API requests
  static String? get cachedToken => _cachedToken;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_keyToken);
    return _cachedToken;
  }

  static Future<void> saveUserSession({
    required String token,
    required String userId,
    required String username,
    required String email,
    required String role,
    bool isDefault = false,
  }) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, username);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserRole, role);
    await prefs.setBool(_keyIsDefault, isDefault);
  }

  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.isEmpty) return null;

    final userId = prefs.getString(_keyUserId);
    final username = prefs.getString(_keyUserName);
    final email = prefs.getString(_keyUserEmail);
    final roleStr = prefs.getString(_keyUserRole);
    final isDefault = prefs.getBool(_keyIsDefault) ?? false;

    if (userId == null || username == null) return null;

    _cachedToken = token;

    UserRole parsedRole = UserRole.cashier;
    if (roleStr != null) {
      final lower = roleStr.toLowerCase();
      if (lower == 'owner' || lower == 'superadmin') {
        parsedRole = UserRole.owner;
      } else if (lower == 'manager' || lower == 'storemanager') {
        parsedRole = UserRole.manager;
      } else {
        parsedRole = UserRole.cashier;
      }
    }

    return {
      'token': token,
      'userId': userId,
      'username': username,
      'email': email ?? '',
      'roleStr': roleStr ?? 'Cashier',
      'role': parsedRole,
      'isDefault': isDefault,
    };
  }

  static Future<void> clearSession() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyIsDefault);
  }
}
