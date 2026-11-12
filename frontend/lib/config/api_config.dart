import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _definedSocketUrl = String.fromEnvironment('SOCKET_BASE_URL');

  // Real Online Backend (Contabo VPS):
  static const String onlineBaseUrl = 'http://213.199.57.65/api';
  static const String onlineSocketUrl = 'http://213.199.57.65';

  /// The base URL for REST API endpoints.
  /// Automatically resolves VPS http://213.199.57.65/api or custom --dart-define.
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    // Real online VPS backend:
    return onlineBaseUrl;
  }

  /// The base URL for WebSocket / Socket.IO connections.
  static String get socketUrl {
    if (_definedSocketUrl.isNotEmpty) {
      return _definedSocketUrl;
    }
    // Real online VPS backend:
    return onlineSocketUrl;
  }

  /// Default network timeout duration
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Helper to get target URL for different environments
  static String getBaseUrlForEnvironment({String env = 'dev'}) {
    switch (env.toLowerCase()) {
      case 'local':
        return 'http://localhost:3000/api';
      case 'android_emulator':
        return 'http://10.0.2.2:3000/api';
      case 'prod':
      case 'production':
      case 'staging':
      case 'dev':
      default:
        return baseUrl;
    }
  }
}
