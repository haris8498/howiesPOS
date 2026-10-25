import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Abstraction for retrieving the application's runtime version.
///
/// Ensures decoupled testing without depending on platform channels.
abstract class IAppVersionProvider {
  Future<String> getAppVersion();
}

/// Production implementation reading application version from `pubspec.yaml`
/// via [PackageInfo.fromPlatform] (backed by Windows PE Version Info in Release mode).
class DefaultAppVersionProvider implements IAppVersionProvider {
  final String? overrideVersion;

  const DefaultAppVersionProvider({this.overrideVersion});

  @override
  Future<String> getAppVersion() async {
    if (overrideVersion != null && overrideVersion!.isNotEmpty) {
      return overrideVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        return info.version;
      }
    } catch (e) {
      debugPrint(
        '[AppVersionProvider] Error reading platform package info: $e',
      );
    }

    // Fallback to Dart environment define injected during flutter build
    const envVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');
    if (envVersion.isNotEmpty) {
      return envVersion;
    }

    return '1.0.0';
  }
}
