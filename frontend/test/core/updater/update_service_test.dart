import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hungry_howies_pos/core/updater/app_version_provider.dart';
import 'package:hungry_howies_pos/core/updater/github_release_client.dart';
import 'package:hungry_howies_pos/core/updater/update_models.dart';
import 'package:hungry_howies_pos/core/updater/update_service.dart';
import 'package:hungry_howies_pos/core/updater/windows_updater.dart';

class _MockReleaseClient implements IGitHubReleaseClient {
  ParsedRelease? releaseToReturn;
  bool shouldThrow = false;

  _MockReleaseClient({this.releaseToReturn, this.shouldThrow = false});

  @override
  Future<ParsedRelease?> getLatestStableRelease() async {
    if (shouldThrow) {
      throw Exception('Network unreachable');
    }
    return releaseToReturn;
  }
}

class _MockVersionProvider implements IAppVersionProvider {
  final String version;
  _MockVersionProvider(this.version);

  @override
  Future<String> getAppVersion() async => version;
}

class _MockWindowsUpdater implements IWindowsUpdater {
  UpdateInfo? executedUpdate;

  @override
  Future<void> executeUpdate(
    UpdateInfo update, {
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    executedUpdate = update;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService.checkForUpdate', () {
    test(
      'returns UpdateInfo when remote version is newer and asset is valid',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockClient = _MockReleaseClient(
          releaseToReturn: const ParsedRelease(
            tagName: 'v1.0.1',
            releaseName: "Hungry Howie's POS v1.0.1",
            body: '• Important fix',
            isDraft: false,
            isPrerelease: false,
            assetName: 'Hungry-Howies-POS-Windows.zip',
            downloadUrl:
                'https://github.com/haris8498/howiesPOS/releases/download/v1.0.1/asset.zip',
            assetSize: 122752555,
          ),
        );

        final service = UpdateService(
          releaseClient: mockClient,
          versionProvider: _MockVersionProvider('1.0.0'),
          windowsUpdater: _MockWindowsUpdater(),
          prefs: prefs,
        );

        final update = await service.checkForUpdate(force: true);

        expect(update, isNotNull);
        expect(update!.currentVersion, '1.0.0');
        expect(update.latestVersion, '1.0.1');
        expect(update.releaseTag, 'v1.0.1');
        expect(update.releaseNotes, '• Important fix');
        expect(update.hasUpdate, isTrue);
        expect(update.assetName, 'Hungry-Howies-POS-Windows.zip');
      },
    );

    test('returns null when app is up to date (same version)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockClient = _MockReleaseClient(
        releaseToReturn: const ParsedRelease(
          tagName: 'v1.0.0',
          releaseName: "Hungry Howie's POS v1.0.0",
          body: '',
          isDraft: false,
          isPrerelease: false,
          assetName: 'Hungry-Howies-POS-Windows.zip',
          downloadUrl: 'https://example.com/asset.zip',
          assetSize: 1000,
        ),
      );

      final service = UpdateService(
        releaseClient: mockClient,
        versionProvider: _MockVersionProvider('1.0.0'),
        windowsUpdater: _MockWindowsUpdater(),
        prefs: prefs,
      );

      final update = await service.checkForUpdate(force: true);
      expect(update, isNull);
    });

    test(
      'returns null when installed version is newer (downgrade prevention)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockClient = _MockReleaseClient(
          releaseToReturn: const ParsedRelease(
            tagName: 'v1.0.0',
            releaseName: 'Old Release',
            body: '',
            isDraft: false,
            isPrerelease: false,
            assetName: 'Hungry-Howies-POS-Windows.zip',
            downloadUrl: 'https://example.com/asset.zip',
            assetSize: 1000,
          ),
        );

        final service = UpdateService(
          releaseClient: mockClient,
          versionProvider: _MockVersionProvider('1.1.0'),
          windowsUpdater: _MockWindowsUpdater(),
          prefs: prefs,
        );

        final update = await service.checkForUpdate(force: true);
        expect(update, isNull);
      },
    );

    test('returns null when required Windows asset is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockClient = _MockReleaseClient(
        releaseToReturn: const ParsedRelease(
          tagName: 'v2.0.0',
          releaseName: 'Major Release',
          body: 'New features',
          isDraft: false,
          isPrerelease: false,
          assetName: null,
          downloadUrl: null,
          assetSize: 0,
        ),
      );

      final service = UpdateService(
        releaseClient: mockClient,
        versionProvider: _MockVersionProvider('1.0.0'),
        windowsUpdater: _MockWindowsUpdater(),
        prefs: prefs,
      );

      final update = await service.checkForUpdate(force: true);
      expect(update, isNull);
    });

    test('uses fallback release notes when body is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockClient = _MockReleaseClient(
        releaseToReturn: const ParsedRelease(
          tagName: 'v1.0.5',
          releaseName: 'Release 1.0.5',
          body: '   ',
          isDraft: false,
          isPrerelease: false,
          assetName: 'Hungry-Howies-POS-Windows.zip',
          downloadUrl: 'https://example.com/asset.zip',
          assetSize: 1000,
        ),
      );

      final service = UpdateService(
        releaseClient: mockClient,
        versionProvider: _MockVersionProvider('1.0.0'),
        windowsUpdater: _MockWindowsUpdater(),
        prefs: prefs,
      );

      final update = await service.checkForUpdate(force: true);
      expect(update, isNotNull);
      expect(
        update!.releaseNotes,
        "A new version of Hungry Howie's POS is available.",
      );
    });

    test('catches network exceptions silently and returns null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockClient = _MockReleaseClient(shouldThrow: true);

      final service = UpdateService(
        releaseClient: mockClient,
        versionProvider: _MockVersionProvider('1.0.0'),
        windowsUpdater: _MockWindowsUpdater(),
        prefs: prefs,
      );

      final update = await service.checkForUpdate(force: true);
      expect(update, isNull);
    });

    test(
      'cooldown skips redundant check, but force bypasses cooldown',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final mockClient = _MockReleaseClient(
          releaseToReturn: const ParsedRelease(
            tagName: 'v1.0.2',
            releaseName: '1.0.2',
            body: 'Notes',
            isDraft: false,
            isPrerelease: false,
            assetName: 'Hungry-Howies-POS-Windows.zip',
            downloadUrl: 'https://example.com/asset.zip',
            assetSize: 1000,
          ),
        );

        final service = UpdateService(
          releaseClient: mockClient,
          versionProvider: _MockVersionProvider('1.0.0'),
          windowsUpdater: _MockWindowsUpdater(),
          prefs: prefs,
        );

        // First check records timestamp
        final first = await service.checkForUpdate(force: false);
        expect(first, isNotNull);

        // Second check immediately without force -> skipped by cooldown
        final second = await service.checkForUpdate(force: false);
        expect(second, isNull);

        // Third check with force -> succeeds
        final third = await service.checkForUpdate(force: true);
        expect(third, isNotNull);
      },
    );
  });
}
