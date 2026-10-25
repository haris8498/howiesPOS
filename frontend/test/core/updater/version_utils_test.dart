import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/updater/version_utils.dart';

void main() {
  group('SemanticVersion parsing & comparison', () {
    test('parses standard 3-segment semver', () {
      final v = SemanticVersion.tryParse('1.0.0');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 0);
      expect(v.patch, 0);
      expect(v.build, isNull);
    });

    test('normalizes lowercase and uppercase v prefix', () {
      final v1 = SemanticVersion.tryParse('v1.0.1');
      final v2 = SemanticVersion.tryParse('V2.3.4');
      expect(v1, isNotNull);
      expect(v1!.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 1);

      expect(v2, isNotNull);
      expect(v2!.major, 2);
      expect(v2.minor, 3);
      expect(v2.patch, 4);
    });

    test('parses Flutter build suffix (e.g. 1.0.0+1)', () {
      final v = SemanticVersion.tryParse('1.0.0+1');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 0);
      expect(v.patch, 0);
      expect(v.build, 1);
    });

    test('handles 2-segment semver cleanly', () {
      final v = SemanticVersion.tryParse('2.1');
      expect(v, isNotNull);
      expect(v!.major, 2);
      expect(v.minor, 1);
      expect(v.patch, 0);
    });

    test('returns null for malformed or invalid version strings', () {
      expect(SemanticVersion.tryParse(null), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(SemanticVersion.tryParse('   '), isNull);
      expect(SemanticVersion.tryParse('invalid'), isNull);
      expect(SemanticVersion.tryParse('v'), isNull);
      expect(SemanticVersion.tryParse('1.2.3.4.5'), isNull);
      expect(SemanticVersion.tryParse('-1.0.0'), isNull);
      expect(SemanticVersion.tryParse('a.b.c'), isNull);
    });

    test('equality checks work for identical versions', () {
      final v1 = SemanticVersion.tryParse('1.0.0');
      final v2 = SemanticVersion.tryParse('v1.0.0');
      expect(v1, equals(v2));
    });
  });

  group('VersionUtils.isNewer', () {
    test('detects strictly newer patch version', () {
      expect(VersionUtils.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(VersionUtils.isNewer('v1.0.1', '1.0.0'), isTrue);
      expect(VersionUtils.isNewer('v1.0.10', 'v1.0.2'), isTrue);
    });

    test('detects strictly newer minor version', () {
      expect(VersionUtils.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(VersionUtils.isNewer('v1.2.0', '1.1.9'), isTrue);
    });

    test('detects strictly newer major version', () {
      expect(VersionUtils.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(VersionUtils.isNewer('v3.0.0', 'v2.10.5'), isTrue);
    });

    test('rejects older versions (prevents downgrade)', () {
      expect(VersionUtils.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(VersionUtils.isNewer('v1.0.0', '1.1.0'), isFalse);
      expect(VersionUtils.isNewer('v0.9.9', '1.0.0'), isFalse);
    });

    test('rejects equal versions', () {
      expect(VersionUtils.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(VersionUtils.isNewer('v1.0.0', '1.0.0'), isFalse);
      expect(VersionUtils.isNewer('1.0.0+1', '1.0.0+1'), isFalse);
    });

    test('handles Flutter build suffixes when semver is equal', () {
      expect(VersionUtils.isNewer('1.0.0+2', '1.0.0+1'), isTrue);
      expect(VersionUtils.isNewer('1.0.0+1', '1.0.0+2'), isFalse);
    });

    test(
      'gracefully returns false for malformed versions without crashing',
      () {
        expect(VersionUtils.isNewer('invalid', '1.0.0'), isFalse);
        expect(VersionUtils.isNewer('1.0.1', 'invalid'), isFalse);
        expect(VersionUtils.isNewer(null, '1.0.0'), isFalse);
        expect(VersionUtils.isNewer('1.0.1', null), isFalse);
        expect(VersionUtils.isNewer('', ''), isFalse);
      },
    );
  });

  group('VersionUtils.normalize and compare', () {
    test('normalizes version strings', () {
      expect(VersionUtils.normalize('v1.0.1'), '1.0.1');
      expect(VersionUtils.normalize('V2.0.0'), '2.0.0');
      expect(VersionUtils.normalize('1.0.0'), '1.0.0');
    });

    test('compares versions correctly (-1, 0, 1)', () {
      expect(VersionUtils.compare('1.0.1', '1.0.0'), 1);
      expect(VersionUtils.compare('1.0.0', '1.0.1'), -1);
      expect(VersionUtils.compare('1.0.0', 'v1.0.0'), 0);
      expect(VersionUtils.compare('invalid', '1.0.0'), -1);
    });
  });
}
