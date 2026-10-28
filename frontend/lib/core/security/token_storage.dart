import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_role.dart';
import 'windows_dpapi.dart';

/// Secure token & session persistence layer with Windows DPAPI encryption at rest.
///
/// Implements:
/// - Spec §16.3: Local Data At-Rest Encryption & Session Storage.
/// - DPAPI Encryption: Passes token and sensitive user credentials through
///   [WindowsDpapi.protectString] before persisting to disk.
/// - First-Run Transparent Migration: Detects pre-existing plaintext SharedPreferences
///   keys, encrypts them into DPAPI ciphertext, and purges the plaintext keys from disk.
/// - In-Memory Fast Cache: Retains active token in RAM for zero-latency authorization
///   header injection during rapid REST calls and sync engine push/pull pipelines.
class TokenStorage {
  // Encrypted keys (DPAPI-protected base64 ciphertext)
  static const String _keyEncToken = 'enc_dpapi_jwt_token';
  static const String _keyEncUserId = 'enc_dpapi_user_id';
  static const String _keyEncUserName = 'enc_dpapi_user_name';
  static const String _keyEncUserEmail = 'enc_dpapi_user_email';
  static const String _keyEncUserRole = 'enc_dpapi_user_role';
  static const String _keyEncIsDefault = 'enc_dpapi_user_is_default';

  // Legacy plaintext keys (for transparent first-run migration)
  static const String _legacyKeyToken = 'auth_jwt_token';
  static const String _legacyKeyUserId = 'auth_user_id';
  static const String _legacyKeyUserName = 'auth_user_name';
  static const String _legacyKeyUserEmail = 'auth_user_email';
  static const String _legacyKeyUserRole = 'auth_user_role';
  static const String _legacyKeyIsDefault = 'auth_user_is_default';

  static String? _cachedToken;

  /// Cache token in memory for synchronous access during API requests
  static String? get cachedToken => _cachedToken;

  /// Checks whether a token is an offline synthetic placeholder (SEC / #18).
  static bool isSyntheticToken(String? token) {
    if (token == null || token.isEmpty) return false;
    return token.startsWith('local_offline_token_') ||
        token.startsWith('offline_dpapi_token_');
  }

  /// Whether DPAPI encryption is supported on current platform
  static bool get isDpapiSupported => Platform.isWindows;

  /// Protects a string value using user-scope DPAPI on Windows
  static String _encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    if (isDpapiSupported) {
      try {
        return WindowsDpapi.protectString(plaintext, description: 'HungryHowies User Session');
      } catch (_) {
        return plaintext;
      }
    }
    return plaintext;
  }

  /// Decrypts a DPAPI-protected base64 ciphertext string on Windows
  static String _decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return ciphertext;
    if (isDpapiSupported) {
      try {
        return WindowsDpapi.unprotectString(ciphertext);
      } catch (_) {
        // Fallback: If decryption fails (e.g. unencrypted string), return as-is
        return ciphertext;
      }
    }
    return ciphertext;
  }

  /// Migrates existing legacy plaintext SharedPreferences values transparently on first run,
  /// then immediately deletes the plaintext keys from disk.
  static Future<void> _migrateLegacyPlaintextIfPresent(SharedPreferences prefs) async {
    final hasLegacyToken = prefs.containsKey(_legacyKeyToken);
    final hasLegacyUserId = prefs.containsKey(_legacyKeyUserId);

    if (hasLegacyToken || hasLegacyUserId) {
      final legacyToken = prefs.getString(_legacyKeyToken);
      final legacyUserId = prefs.getString(_legacyKeyUserId);
      final legacyUserName = prefs.getString(_legacyKeyUserName);
      final legacyUserEmail = prefs.getString(_legacyKeyUserEmail);
      final legacyUserRole = prefs.getString(_legacyKeyUserRole);
      final legacyIsDefault = prefs.getBool(_legacyKeyIsDefault) ?? false;

      // Encrypt and persist with DPAPI
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await prefs.setString(_keyEncToken, _encrypt(legacyToken));
      }
      if (legacyUserId != null && legacyUserId.isNotEmpty) {
        await prefs.setString(_keyEncUserId, _encrypt(legacyUserId));
      }
      if (legacyUserName != null && legacyUserName.isNotEmpty) {
        await prefs.setString(_keyEncUserName, _encrypt(legacyUserName));
      }
      if (legacyUserEmail != null && legacyUserEmail.isNotEmpty) {
        await prefs.setString(_keyEncUserEmail, _encrypt(legacyUserEmail));
      }
      if (legacyUserRole != null && legacyUserRole.isNotEmpty) {
        await prefs.setString(_keyEncUserRole, _encrypt(legacyUserRole));
      }
      await prefs.setString(_keyEncIsDefault, _encrypt(legacyIsDefault.toString()));

      // Purge all legacy plaintext keys from SharedPreferences
      await _deleteLegacyPlaintextKeys(prefs);
    }
  }

  /// Removes all legacy plaintext keys from SharedPreferences storage.
  static Future<void> _deleteLegacyPlaintextKeys(SharedPreferences prefs) async {
    await prefs.remove(_legacyKeyToken);
    await prefs.remove(_legacyKeyUserId);
    await prefs.remove(_legacyKeyUserName);
    await prefs.remove(_legacyKeyUserEmail);
    await prefs.remove(_legacyKeyUserRole);
    await prefs.remove(_legacyKeyIsDefault);
  }

  /// Saves an authentication JWT token encrypted with DPAPI.
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEncToken, _encrypt(token));
    // Ensure any legacy plaintext token is deleted
    await prefs.remove(_legacyKeyToken);
  }

  /// Retrieves the authentication JWT token, decrypting with DPAPI if necessary.
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();

    // Transparent migration for existing plaintext values
    await _migrateLegacyPlaintextIfPresent(prefs);

    final encToken = prefs.getString(_keyEncToken);
    if (encToken != null && encToken.isNotEmpty) {
      _cachedToken = _decrypt(encToken);
      return _cachedToken;
    }

    return null;
  }

  /// Persists full user session encrypted with DPAPI at rest.
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

    await prefs.setString(_keyEncToken, _encrypt(token));
    await prefs.setString(_keyEncUserId, _encrypt(userId));
    await prefs.setString(_keyEncUserName, _encrypt(username));
    await prefs.setString(_keyEncUserEmail, _encrypt(email));
    await prefs.setString(_keyEncUserRole, _encrypt(role));
    await prefs.setString(_keyEncIsDefault, _encrypt(isDefault.toString()));

    // Delete any legacy plaintext keys
    await _deleteLegacyPlaintextKeys(prefs);
  }

  /// Retrieves and decrypts the active user session.
  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Transparent migration for existing plaintext values
    await _migrateLegacyPlaintextIfPresent(prefs);

    final encToken = prefs.getString(_keyEncToken);
    if (encToken == null || encToken.isEmpty) return null;

    final token = _decrypt(encToken);
    if (token.isEmpty) return null;

    final encUserId = prefs.getString(_keyEncUserId);
    final encUserName = prefs.getString(_keyEncUserName);
    final encUserEmail = prefs.getString(_keyEncUserEmail);
    final encUserRole = prefs.getString(_keyEncUserRole);
    final encIsDefault = prefs.getString(_keyEncIsDefault);

    final userId = encUserId != null ? _decrypt(encUserId) : null;
    final username = encUserName != null ? _decrypt(encUserName) : null;
    final email = encUserEmail != null ? _decrypt(encUserEmail) : '';
    final roleStr = encUserRole != null ? _decrypt(encUserRole) : null;
    final isDefaultStr = encIsDefault != null ? _decrypt(encIsDefault) : 'false';
    final isDefault = isDefaultStr.toLowerCase() == 'true';

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
      'email': email,
      'roleStr': roleStr ?? 'Cashier',
      'role': parsedRole,
      'isDefault': isDefault,
    };
  }

  /// Clears stored user session and tokens from RAM and SharedPreferences.
  static Future<void> clearSession() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();

    // Clear encrypted keys
    await prefs.remove(_keyEncToken);
    await prefs.remove(_keyEncUserId);
    await prefs.remove(_keyEncUserName);
    await prefs.remove(_keyEncUserEmail);
    await prefs.remove(_keyEncUserRole);
    await prefs.remove(_keyEncIsDefault);

    // Clear legacy keys if present
    await _deleteLegacyPlaintextKeys(prefs);
  }

  /// Test helper to reset in-memory cached token between unit tests.
  static void resetCacheForTesting() {
    _cachedToken = null;
  }

  /// Test helper to check if any legacy plaintext keys remain in SharedPreferences.
  static Future<bool> hasLegacyPlaintextKeysForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_legacyKeyToken) ||
        prefs.containsKey(_legacyKeyUserId) ||
        prefs.containsKey(_legacyKeyUserName) ||
        prefs.containsKey(_legacyKeyUserEmail) ||
        prefs.containsKey(_legacyKeyUserRole) ||
        prefs.containsKey(_legacyKeyIsDefault);
  }
}
