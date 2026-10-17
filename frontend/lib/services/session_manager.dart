import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/user_role.dart';

class SessionManager {
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserName = 'auth_user_name';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyIsLoggedIn = 'auth_is_logged_in';

  static Future<void> saveSession({
    required String userId,
    required String userName,
    required UserRole role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserRole, role.name);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;

    final userId = prefs.getString(_keyUserId);
    final userName = prefs.getString(_keyUserName);
    final roleStr = prefs.getString(_keyUserRole);

    if (userId == null || roleStr == null) return null;

    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.cashier,
    );

    return {
      'userId': userId,
      'userName': userName ?? 'User',
      'role': role,
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserRole);
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}
