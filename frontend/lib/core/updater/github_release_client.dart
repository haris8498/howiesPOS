import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Raw parsed release representation from GitHub Releases API.
class ParsedRelease {
  final String tagName;
  final String releaseName;
  final String body;
  final bool isDraft;
  final bool isPrerelease;
  final String? assetName;
  final String? downloadUrl;
  final int assetSize;

  const ParsedRelease({
    required this.tagName,
    required this.releaseName,
    required this.body,
    required this.isDraft,
    required this.isPrerelease,
    this.assetName,
    this.downloadUrl,
    this.assetSize = 0,
  });

  bool get hasValidAsset =>
      assetName != null &&
      downloadUrl != null &&
      downloadUrl!.isNotEmpty &&
      assetSize > 0;
}

/// Interface for interacting with the GitHub Releases API.
abstract class IGitHubReleaseClient {
  Future<ParsedRelease?> getLatestStableRelease();
}

/// Production implementation of [IGitHubReleaseClient] targeting GitHub API.
class GitHubReleaseClient implements IGitHubReleaseClient {
  static const String defaultApiUrl =
      'https://api.github.com/repos/haris8498/howiesPOS/releases/latest';
  static const String defaultTargetAsset = 'Hungry-Howies-POS-Windows.zip';

  final String apiUrl;
  final String targetAssetName;
  final http.Client _client;
  final Duration timeout;

  GitHubReleaseClient({
    this.apiUrl = defaultApiUrl,
    this.targetAssetName = defaultTargetAsset,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  @override
  Future<ParsedRelease?> getLatestStableRelease() async {
    try {
      final uri = Uri.parse(apiUrl);
      if (!uri.isScheme('https')) {
        debugPrint('[GitHubReleaseClient] Insecure scheme rejected: $apiUrl');
        return null;
      }

      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'HungryHowiesPOS',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[GitHubReleaseClient] Non-200 response: ${response.statusCode}',
        );
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[GitHubReleaseClient] Invalid JSON response format');
        return null;
      }

      return parseReleaseJson(decoded, targetAssetName: targetAssetName);
    } catch (e) {
      // Silently catch and log network/timeout/parsing errors to avoid blocking the POS
      debugPrint('[GitHubReleaseClient] Failed to fetch latest release: $e');
      return null;
    }
  }

  /// Parses a GitHub Release JSON map into a [ParsedRelease].
  ///
  /// Ignores draft and pre-release items.
  /// Dynamically locates the target Windows asset without hardcoded URLs.
  static ParsedRelease? parseReleaseJson(
    Map<String, dynamic> json, {
    String targetAssetName = defaultTargetAsset,
  }) {
    final isDraft = json['draft'] as bool? ?? false;
    final isPrerelease = json['prerelease'] as bool? ?? false;

    // Strict requirement: Ignore drafts and pre-releases
    if (isDraft || isPrerelease) {
      return null;
    }

    final tagName = json['tag_name'] as String? ?? '';
    if (tagName.isEmpty) {
      return null;
    }

    final releaseName = json['name'] as String? ?? tagName;
    final body = json['body'] as String? ?? '';

    // Search assets dynamically for the Windows ZIP
    String? matchedAssetName;
    String? downloadUrl;
    int assetSize = 0;

    final assetsList = json['assets'] as List<dynamic>? ?? [];
    for (final item in assetsList) {
      if (item is Map<String, dynamic>) {
        final name = item['name'] as String? ?? '';
        if (name.toLowerCase() == targetAssetName.toLowerCase()) {
          matchedAssetName = name;
          final url = item['browser_download_url'] as String? ?? '';
          if (url.startsWith('https://')) {
            downloadUrl = url;
          }
          final sizeNum = item['size'] as num?;
          if (sizeNum != null) {
            assetSize = sizeNum.toInt();
          }
          break;
        }
      }
    }

    return ParsedRelease(
      tagName: tagName,
      releaseName: releaseName,
      body: body,
      isDraft: isDraft,
      isPrerelease: isPrerelease,
      assetName: matchedAssetName,
      downloadUrl: downloadUrl,
      assetSize: assetSize,
    );
  }
}
