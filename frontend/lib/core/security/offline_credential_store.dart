import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_credential_verifier.dart';
import 'windows_dpapi.dart';

/// Stored offline authentication verifier record.
///
/// Contains ONLY the user identifier, cryptographic salt, derived verifier,
/// key-derivation parameters, and the timestamp of the last successful online login.
///
/// Plaintext passwords and server password hashes are NEVER stored.
class OfflineCredential {
  final String userId;
  final String username;
  final String role;
  final String saltHex;
  final String verifierHex;
  final VerifierParams params;
  final DateTime lastOnlineLoginAt;
  final bool isPin;

  const OfflineCredential({
    required this.userId,
    required this.username,
    required this.role,
    required this.saltHex,
    required this.verifierHex,
    required this.params,
    required this.lastOnlineLoginAt,
    this.isPin = false,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'role': role,
        'salt': saltHex,
        'verifier': verifierHex,
        'params': params.toJson(),
        'lastOnlineLoginAt': lastOnlineLoginAt.toIso8601String(),
        'isPin': isPin,
      };

  factory OfflineCredential.fromJson(Map<String, dynamic> json) => OfflineCredential(
        userId: json['userId'] as String,
        username: json['username'] as String,
        role: json['role'] as String? ?? 'cashier',
        saltHex: json['salt'] as String,
        verifierHex: json['verifier'] as String,
        params: VerifierParams.fromJson(
          Map<String, dynamic>.from(json['params'] as Map? ?? {}),
        ),
        lastOnlineLoginAt: DateTime.parse(json['lastOnlineLoginAt'] as String),
        isPin: json['isPin'] as bool? ?? false,
      );
}

/// Windows DPAPI-protected offline credential persistence store.
///
/// Stores credential blobs encrypted at-rest using Win32 `CryptProtectData` (user scope).
/// Automatically migrates and purges legacy SHA-256 password caches.
class OfflineCredentialStore {
  static const String _keyEncCredentials = 'enc_dpapi_offline_credentials_v2';

  // Legacy plaintext and unsalted/raw SHA-256 keys to purge on migration
  static const String _legacyHashPrefix = 'auth_pwd_hash_';
  static const String _legacySaltPrefix = 'auth_salt_';
  static const String _legacyCustomUsersKey = 'auth_custom_staff_users_v1';
  static const String _legacyDeletedUsersKey = 'auth_deleted_staff_users_v1';

  final SharedPreferences? _prefsOverride;

  OfflineCredentialStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  /// Whether Windows DPAPI is natively supported on the running platform.
  bool get isDpapiSupported => Platform.isWindows;

  /// Encrypts plaintext JSON blob using DPAPI user scope on Windows.
  String _encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    if (isDpapiSupported) {
      try {
        return WindowsDpapi.protectString(
          plaintext,
          description: 'HungryHowies DPAPI Offline Credentials',
        );
      } catch (_) {
        return plaintext;
      }
    }
    return plaintext;
  }

  /// Decrypts ciphertext JSON blob using DPAPI user scope on Windows.
  String _decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return ciphertext;
    if (isDpapiSupported) {
      try {
        return WindowsDpapi.unprotectString(ciphertext);
      } catch (_) {
        return ciphertext;
      }
    }
    return ciphertext;
  }

  /// Loads all cached credentials from DPAPI-protected storage.
  Future<Map<String, OfflineCredential>> _loadAllInternal() async {
    final prefs = await _getPrefs();
    final encBlob = prefs.getString(_keyEncCredentials);
    if (encBlob == null || encBlob.isEmpty) {
      return {};
    }

    try {
      final decryptedJson = _decrypt(encBlob);
      final decoded = json.decode(decryptedJson) as Map<String, dynamic>;
      final result = <String, OfflineCredential>{};
      for (final entry in decoded.entries) {
        result[entry.key] = OfflineCredential.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Saves all cached credentials into DPAPI-protected storage.
  Future<void> _saveAllInternal(Map<String, OfflineCredential> map) async {
    final prefs = await _getPrefs();
    if (map.isEmpty) {
      await prefs.remove(_keyEncCredentials);
      return;
    }

    final rawJson = json.encode(
      map.map((k, v) => MapEntry(k, v.toJson())),
    );
    final encrypted = _encrypt(rawJson);
    await prefs.setString(_keyEncCredentials, encrypted);
  }

  /// Saves or updates an offline credential in the DPAPI-protected store.
  Future<void> saveCredential(OfflineCredential credential) async {
    final map = await _loadAllInternal();
    final key = credential.username.toLowerCase().trim();
    map[key] = credential;
    // Also index by userId for direct ID-based lookups
    map['id:${credential.userId.trim()}'] = credential;
    await _saveAllInternal(map);
  }

  /// Retrieves an offline credential by username or userId.
  Future<OfflineCredential?> getCredential(String usernameOrId) async {
    final map = await _loadAllInternal();
    final clean = usernameOrId.toLowerCase().trim();

    // 1. Direct username lookup
    if (map.containsKey(clean)) {
      return map[clean];
    }

    // 2. Direct ID lookup
    if (map.containsKey('id:$clean')) {
      return map['id:$clean'];
    }

    // 3. Scan matching userId or username
    for (final cred in map.values) {
      if (cred.userId.toLowerCase() == clean || cred.username.toLowerCase() == clean) {
        return cred;
      }
    }

    return null;
  }

  /// Returns all cached credentials.
  Future<List<OfflineCredential>> getAllCredentials() async {
    final map = await _loadAllInternal();
    // Filter out duplicated 'id:...' lookup aliases
    final seenIds = <String>{};
    final list = <OfflineCredential>[];
    for (final cred in map.values) {
      if (seenIds.add(cred.userId)) {
        list.add(cred);
      }
    }
    return list;
  }

  /// Revokes (removes) a specific user from the offline credential cache.
  Future<void> removeCredential(String userId) async {
    final map = await _loadAllInternal();
    final cleanId = userId.toLowerCase().trim();
    map.removeWhere(
      (k, v) => v.userId.toLowerCase() == cleanId || k == 'id:$cleanId',
    );
    await _saveAllInternal(map);
  }

  /// Wipes all cached credentials completely from storage.
  Future<void> wipeAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyEncCredentials);
  }

  /// Purges all legacy un-slowed SHA-256 hashes and cache entries from disk.
  ///
  /// Removes legacy keys:
  /// - `auth_pwd_hash_*`
  /// - `auth_salt_*`
  /// - `auth_custom_staff_users_v1`
  /// - `auth_deleted_staff_users_v1`
  Future<void> purgeLegacyCache() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith(_legacyHashPrefix) ||
          key.startsWith(_legacySaltPrefix) ||
          key == _legacyCustomUsersKey ||
          key == _legacyDeletedUsersKey) {
        await prefs.remove(key);
      }
    }
  }

  /// Checks if any legacy cache keys still exist in storage (useful for tests).
  Future<bool> hasLegacyCacheKeys() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_legacyHashPrefix) ||
          key.startsWith(_legacySaltPrefix) ||
          key == _legacyCustomUsersKey ||
          key == _legacyDeletedUsersKey) {
        return true;
      }
    }
    return false;
  }
}
