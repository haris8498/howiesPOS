

class ApiConfig {
  ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _definedSocketUrl = String.fromEnvironment('SOCKET_BASE_URL');

  /// The base URL for REST API endpoints.
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    return 'http://213.199.57.65/api';
  }

  /// The base URL for WebSocket / Socket.IO connections.
  static String get socketUrl {
    if (_definedSocketUrl.isNotEmpty) {
      return _definedSocketUrl;
    }
    return 'http://213.199.57.65';
  }

  /// Default network timeout duration
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Helper to get target URL for different environments
  static String getBaseUrlForEnvironment({String env = 'dev'}) {
    switch (env.toLowerCase()) {
      case 'prod':
      case 'production':
        return 'https://api.hungryhowiespos.com/api';
      case 'staging':
        return 'https://staging-api.hungryhowiespos.com/api';
      case 'android_emulator':
        return 'http://10.0.2.2:3000/api';
      case 'dev':
      default:
        return baseUrl;
    }
  }
}
