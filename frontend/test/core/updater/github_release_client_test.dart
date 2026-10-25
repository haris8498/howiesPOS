import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hungry_howies_pos/core/updater/github_release_client.dart';

class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  _FakeHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  group('GitHubReleaseClient.parseReleaseJson', () {
    test('successfully parses valid stable release with Windows asset', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': "Hungry Howie's POS v1.0.1",
        'body': '• Performance improvements\n• Bug fixes',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'Hungry-Howies-POS-Windows.zip',
            'browser_download_url':
                'https://github.com/haris8498/howiesPOS/releases/download/v1.0.1/Hungry-Howies-POS-Windows.zip',
            'size': 122752555,
          },
        ],
      };

      final parsed = GitHubReleaseClient.parseReleaseJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.tagName, 'v1.0.1');
      expect(parsed.releaseName, "Hungry Howie's POS v1.0.1");
      expect(parsed.body, contains('Performance improvements'));
      expect(parsed.isDraft, isFalse);
      expect(parsed.isPrerelease, isFalse);
      expect(parsed.assetName, 'Hungry-Howies-POS-Windows.zip');
      expect(parsed.downloadUrl, contains('Hungry-Howies-POS-Windows.zip'));
      expect(parsed.assetSize, 122752555);
      expect(parsed.hasValidAsset, isTrue);
    });

    test('ignores draft releases', () {
      final json = {
        'tag_name': 'v1.0.1',
        'draft': true,
        'prerelease': false,
        'assets': [
          {
            'name': 'Hungry-Howies-POS-Windows.zip',
            'browser_download_url': 'https://example.com/asset.zip',
            'size': 100,
          },
        ],
      };

      final parsed = GitHubReleaseClient.parseReleaseJson(json);
      expect(parsed, isNull);
    });

    test('ignores pre-releases', () {
      final json = {
        'tag_name': 'v1.0.1-rc1',
        'draft': false,
        'prerelease': true,
        'assets': [
          {
            'name': 'Hungry-Howies-POS-Windows.zip',
            'browser_download_url': 'https://example.com/asset.zip',
            'size': 100,
          },
        ],
      };

      final parsed = GitHubReleaseClient.parseReleaseJson(json);
      expect(parsed, isNull);
    });

    test('handles missing Windows asset cleanly', () {
      final json = {
        'tag_name': 'v1.0.1',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'some-other-asset.deb',
            'browser_download_url': 'https://example.com/asset.deb',
            'size': 500,
          },
        ],
      };

      final parsed = GitHubReleaseClient.parseReleaseJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.hasValidAsset, isFalse);
      expect(parsed.assetName, isNull);
      expect(parsed.downloadUrl, isNull);
    });

    test('matches Windows asset case-insensitively', () {
      final json = {
        'tag_name': 'v1.0.1',
        'draft': false,
        'prerelease': false,
        'assets': [
          {
            'name': 'hungry-howies-pos-windows.zip',
            'browser_download_url':
                'https://github.com/haris8498/howiesPOS/releases/download/v1.0.1/asset.zip',
            'size': 42000,
          },
        ],
      };

      final parsed = GitHubReleaseClient.parseReleaseJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.hasValidAsset, isTrue);
      expect(parsed.assetSize, 42000);
    });
  });

  group('GitHubReleaseClient network handling', () {
    test('returns parsed release on HTTP 200', () async {
      final client = _FakeHttpClient((request) async {
        final body = jsonEncode({
          'tag_name': 'v1.0.2',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'Hungry-Howies-POS-Windows.zip',
              'browser_download_url':
                  'https://github.com/haris8498/howiesPOS/releases/download/v1.0.2/asset.zip',
              'size': 99999,
            },
          ],
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final releaseClient = GitHubReleaseClient(client: client);
      final result = await releaseClient.getLatestStableRelease();

      expect(result, isNotNull);
      expect(result!.tagName, 'v1.0.2');
      expect(result.hasValidAsset, isTrue);
    });

    test('returns null on HTTP 404 or 500 without throwing', () async {
      final client = _FakeHttpClient((request) async {
        return http.StreamedResponse(Stream.value([]), 500);
      });

      final releaseClient = GitHubReleaseClient(client: client);
      final result = await releaseClient.getLatestStableRelease();

      expect(result, isNull);
    });

    test('returns null on network timeout without throwing', () async {
      final client = _FakeHttpClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final releaseClient = GitHubReleaseClient(client: client);
      final result = await releaseClient.getLatestStableRelease();

      expect(result, isNull);
    });

    test(
      'returns null on malformed non-JSON response without throwing',
      () async {
        final client = _FakeHttpClient((request) async {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode('<html><body>Error 502 Bad Gateway</body></html>'),
            ),
            200,
            headers: {'content-type': 'text/html'},
          );
        });

        final releaseClient = GitHubReleaseClient(client: client);
        final result = await releaseClient.getLatestStableRelease();

        expect(result, isNull);
      },
    );
  });
}
