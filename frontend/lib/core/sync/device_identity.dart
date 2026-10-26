import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../security/windows_dpapi.dart';

/// Immutable model representing the local POS terminal and hardware identity.
///
/// Implements SYNC-005:
/// - [deviceId]: RFC 9562 / v4 UUID generated once on first application launch.
///   Persisted in secure storage outside SQLite/Drift so DB restorations do not wipe device identity.
/// - [terminalId]: Human-assigned label/register number (e.g. '1', '2', 'P1').
/// - [terminalName]: Friendly human name for the register (e.g. 'Register 1 - Front Counter').
/// - [restaurantId]: Multi-tenant / store identifier (defaults to 'default').
class DeviceIdentity {
  final String deviceId;
  final String terminalId;
  final String terminalName;
  final String restaurantId;
  final bool isInitialized;

  const DeviceIdentity({
    required this.deviceId,
    this.terminalId = '1',
    this.terminalName = 'Register 1',
    this.restaurantId = 'default',
    this.isInitialized = true,
  });

  DeviceIdentity copyWith({
    String? deviceId,
    String? terminalId,
    String? terminalName,
    String? restaurantId,
    bool? isInitialized,
  }) {
    return DeviceIdentity(
      deviceId: deviceId ?? this.deviceId,
      terminalId: terminalId ?? this.terminalId,
      terminalName: terminalName ?? this.terminalName,
      restaurantId: restaurantId ?? this.restaurantId,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'terminal_id': terminalId,
        'terminal_name': terminalName,
        'restaurant_id': restaurantId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceIdentity &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId &&
          terminalId == other.terminalId &&
          terminalName == other.terminalName &&
          restaurantId == other.restaurantId &&
          isInitialized == other.isInitialized;

  @override
  int get hashCode =>
      deviceId.hashCode ^
      terminalId.hashCode ^
      terminalName.hashCode ^
      restaurantId.hashCode ^
      isInitialized.hashCode;

  @override
  String toString() =>
      'DeviceIdentity(deviceId: $deviceId, terminalId: $terminalId, terminalName: $terminalName, restaurantId: $restaurantId)';
}

/// Secure storage service managing device hardware identity and terminal configuration.
///
/// Storage Strategy:
/// - Uses Windows DPAPI (via [WindowsDpapi.protectString]) on Windows platforms to encrypt
///   identity keys before writing them to [SharedPreferences].
/// - Falls back to unencrypted storage on non-Windows platforms or in unit test mocks.
/// - Persisted completely outside Drift/SQLite database so database wipes, drops, or re-indexes
///   cannot erase or re-randomize the device's persistent hardware identifier.
class DeviceIdentityService {
  static const String _keyEncDeviceId = 'enc_dpapi_device_id';
  static const String _keyEncTerminalId = 'enc_dpapi_terminal_id';
  static const String _keyEncTerminalName = 'enc_dpapi_terminal_name';
  static const String _keyEncRestaurantId = 'enc_dpapi_restaurant_id';

  // Legacy / fallback plaintext keys
  static const String _plainKeyDeviceId = 'pos_device_id';
  static const String _plainKeyTerminalId = 'pos_terminal_id';
  static const String _plainKeyTerminalName = 'pos_terminal_name';
  static const String _plainKeyRestaurantId = 'pos_restaurant_id';

  static DeviceIdentity? _cachedIdentity;
  static String? _inMemoryFallbackDeviceId;
  static String? _inMemoryFallbackTerminalId;

  final SharedPreferences? customPrefs;
  final Uuid _uuid;

  DeviceIdentityService({
    this.customPrefs,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Whether DPAPI encryption is supported on current platform
  static bool get isDpapiSupported => Platform.isWindows;

  /// Fast synchronous accessor for current deviceId.
  /// Used by constructors and sync workers that need the ID synchronously.
  static String get currentDeviceId {
    if (_cachedIdentity != null && _cachedIdentity!.deviceId.isNotEmpty) {
      return _cachedIdentity!.deviceId;
    }
    _inMemoryFallbackDeviceId ??= const Uuid().v4();
    return _inMemoryFallbackDeviceId!;
  }

  /// Fast synchronous accessor for current terminalId.
  static String get currentTerminalId {
    if (_cachedIdentity != null && _cachedIdentity!.terminalId.isNotEmpty) {
      return _cachedIdentity!.terminalId;
    }
    return _inMemoryFallbackTerminalId ?? '1';
  }

  /// Sets mock/in-memory identity for tests or explicit configuration.
  static void setMockIdentity(DeviceIdentity identity) {
    _cachedIdentity = identity;
    _inMemoryFallbackDeviceId = identity.deviceId;
    _inMemoryFallbackTerminalId = identity.terminalId;
  }

  /// Resets cached identity in memory (useful for unit tests).
  static void resetForTesting() {
    _cachedIdentity = null;
    _inMemoryFallbackDeviceId = null;
    _inMemoryFallbackTerminalId = null;
  }

  Future<SharedPreferences> _getPrefs() async {
    if (customPrefs != null) return customPrefs!;
    return await SharedPreferences.getInstance();
  }

  static String _encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    if (isDpapiSupported) {
      try {
        return WindowsDpapi.protectString(plaintext,
            description: 'HungryHowies Device Identity');
      } catch (_) {
        return plaintext;
      }
    }
    return plaintext;
  }

  static String _decrypt(String ciphertext) {
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

  /// Loads existing identity or initializes a new UUID device id on first launch.
  Future<DeviceIdentity> getOrInitializeIdentity({
    String? defaultTerminalId,
    String? defaultTerminalName,
    String? defaultRestaurantId,
  }) async {
    final prefs = await _getPrefs();

    // 1. Try reading encrypted device ID
    String? deviceId;
    final encDeviceId = prefs.getString(_keyEncDeviceId);
    if (encDeviceId != null && encDeviceId.isNotEmpty) {
      deviceId = _decrypt(encDeviceId);
    }

    // Fallback: check legacy plaintext key
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = prefs.getString(_plainKeyDeviceId);
    }

    // 2. Generate UUID if first launch
    final isNewDevice = deviceId == null || deviceId.isEmpty;
    if (isNewDevice) {
      // Use existing fallback ID if generated earlier in session, otherwise new UUID v4
      deviceId = _inMemoryFallbackDeviceId ?? _uuid.v4();
      final cipher = _encrypt(deviceId);
      await prefs.setString(_keyEncDeviceId, cipher);
      await prefs.setString(_plainKeyDeviceId, deviceId);
    }

    // 3. Read or default terminalId
    String? terminalId;
    final encTerminalId = prefs.getString(_keyEncTerminalId);
    if (encTerminalId != null && encTerminalId.isNotEmpty) {
      terminalId = _decrypt(encTerminalId);
    }
    terminalId ??= prefs.getString(_plainKeyTerminalId) ??
        _inMemoryFallbackTerminalId ??
        defaultTerminalId ??
        '1';

    // 4. Read or default terminalName
    String? terminalName;
    final encTerminalName = prefs.getString(_keyEncTerminalName);
    if (encTerminalName != null && encTerminalName.isNotEmpty) {
      terminalName = _decrypt(encTerminalName);
    }
    terminalName ??= prefs.getString(_plainKeyTerminalName) ??
        defaultTerminalName ??
        'Register $terminalId';

    // 5. Read or default restaurantId
    String? restaurantId;
    final encRestaurantId = prefs.getString(_keyEncRestaurantId);
    if (encRestaurantId != null && encRestaurantId.isNotEmpty) {
      restaurantId = _decrypt(encRestaurantId);
    }
    restaurantId ??= prefs.getString(_plainKeyRestaurantId) ??
        defaultRestaurantId ??
        'default';

    // Persist all attributes on first initialization
    if (isNewDevice || !prefs.containsKey(_keyEncTerminalId)) {
      await prefs.setString(_keyEncTerminalId, _encrypt(terminalId));
      await prefs.setString(_plainKeyTerminalId, terminalId);
      await prefs.setString(_keyEncTerminalName, _encrypt(terminalName));
      await prefs.setString(_plainKeyTerminalName, terminalName);
      await prefs.setString(_keyEncRestaurantId, _encrypt(restaurantId));
      await prefs.setString(_plainKeyRestaurantId, restaurantId);
    }

    final identity = DeviceIdentity(
      deviceId: deviceId,
      terminalId: terminalId,
      terminalName: terminalName,
      restaurantId: restaurantId,
      isInitialized: true,
    );

    _cachedIdentity = identity;
    _inMemoryFallbackDeviceId = identity.deviceId;
    _inMemoryFallbackTerminalId = identity.terminalId;

    return identity;
  }

  /// Updates terminal setup (human-assigned terminal ID and terminal name).
  Future<DeviceIdentity> updateTerminalSetup({
    required String terminalId,
    String? terminalName,
    String? restaurantId,
  }) async {
    final current = await getOrInitializeIdentity();
    final prefs = await _getPrefs();

    final effectiveTerminalName =
        terminalName ?? current.terminalName;
    final effectiveRestaurantId =
        restaurantId ?? current.restaurantId;

    // Encrypt & store
    await prefs.setString(_keyEncTerminalId, _encrypt(terminalId));
    await prefs.setString(_plainKeyTerminalId, terminalId);

    await prefs.setString(_keyEncTerminalName, _encrypt(effectiveTerminalName));
    await prefs.setString(_plainKeyTerminalName, effectiveTerminalName);

    await prefs.setString(_keyEncRestaurantId, _encrypt(effectiveRestaurantId));
    await prefs.setString(_plainKeyRestaurantId, effectiveRestaurantId);

    final updated = current.copyWith(
      terminalId: terminalId,
      terminalName: effectiveTerminalName,
      restaurantId: effectiveRestaurantId,
    );

    _cachedIdentity = updated;
    _inMemoryFallbackTerminalId = updated.terminalId;

    return updated;
  }
}

/// State notifier for reactive Riverpod UI bindings.
class DeviceIdentityNotifier extends StateNotifier<DeviceIdentity> {
  final DeviceIdentityService _service;

  DeviceIdentityNotifier(this._service)
      : super(DeviceIdentity(
          deviceId: DeviceIdentityService.currentDeviceId,
          terminalId: DeviceIdentityService.currentTerminalId,
          terminalName: 'Register ${DeviceIdentityService.currentTerminalId}',
          restaurantId: 'default',
          isInitialized: false,
        )) {
    _init();
  }

  Future<void> _init() async {
    final identity = await _service.getOrInitializeIdentity();
    state = identity;
  }

  Future<void> updateTerminal({
    required String terminalId,
    String? terminalName,
    String? restaurantId,
  }) async {
    final updated = await _service.updateTerminalSetup(
      terminalId: terminalId,
      terminalName: terminalName,
      restaurantId: restaurantId,
    );
    state = updated;
  }
}

/// Provider exposing the [DeviceIdentityService] singleton.
final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService();
});

/// Riverpod provider exposing reactive [DeviceIdentity].
final deviceIdentityProvider =
    StateNotifierProvider<DeviceIdentityNotifier, DeviceIdentity>((ref) {
  final service = ref.watch(deviceIdentityServiceProvider);
  return DeviceIdentityNotifier(service);
});

/// Direct provider for current deviceId.
final currentDeviceIdProvider = Provider<String>((ref) {
  return ref.watch(deviceIdentityProvider).deviceId;
});

/// Direct provider for current terminalId.
final currentTerminalIdProvider = Provider<String>((ref) {
  return ref.watch(deviceIdentityProvider).terminalId;
});
