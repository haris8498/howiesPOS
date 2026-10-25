/// Semantic versioning utility for Hungry Howie's POS auto-updater.
///
/// Supports comparison of standard semantic versions (e.g., 1.0.0, 1.0.1, 1.1.0, 2.0.0),
/// tags with 'v' prefixes (e.g., v1.0.1), and Flutter build suffixes (e.g., 1.0.0+1).
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? build;
  final String raw;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
    required this.raw,
  });

  /// Parses a version string into a [SemanticVersion].
  ///
  /// Normalizes leading 'v' / 'V' characters and ignores trailing metadata/build numbers
  /// unless needed for disambiguation.
  /// Returns `null` if the string cannot be parsed into a valid semantic version.
  static SemanticVersion? tryParse(String? rawInput) {
    if (rawInput == null) return null;
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // Normalize 'v' or 'V' prefix
    String cleaned = trimmed;
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }

    // Split build metadata (+1) if present
    int? buildNumber;
    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      cleaned = parts[0];
      if (parts.length > 1) {
        buildNumber = int.tryParse(parts[1].trim());
      }
    }

    // Split release/pre-release hyphen if present (e.g., 1.0.0-beta)
    if (cleaned.contains('-')) {
      cleaned = cleaned.split('-')[0];
    }

    final segments = cleaned.split('.');
    if (segments.isEmpty || segments.length > 3) {
      return null;
    }

    final major = int.tryParse(segments[0]);
    if (major == null || major < 0) return null;

    final minor = segments.length > 1 ? int.tryParse(segments[1]) : 0;
    if (minor == null || minor < 0) return null;

    final patch = segments.length > 2 ? int.tryParse(segments[2]) : 0;
    if (patch == null || patch < 0) return null;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNumber,
      raw: trimmed,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }
    // If major, minor, and patch are identical, compare build number if both exist
    if (build != null && other.build != null && build != other.build) {
      return build!.compareTo(other.build!);
    }
    return 0;
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          build == other.build;

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => '$major.$minor.$patch${build != null ? '+$build' : ''}';
}

/// Helper utilities for version parsing and comparison.
class VersionUtils {
  VersionUtils._();

  /// Returns `true` if [remoteVersionTag] is strictly newer than [currentVersion].
  ///
  /// Returns `false` if versions are equal, if remote is older, or if either
  /// version string is malformed or invalid. Never downgrades.
  static bool isNewer(String? remoteVersionTag, String? currentVersion) {
    final remote = SemanticVersion.tryParse(remoteVersionTag);
    final current = SemanticVersion.tryParse(currentVersion);

    if (remote == null || current == null) {
      return false;
    }

    return remote > current;
  }

  /// Normalizes a version string by removing any 'v' prefix and trimming whitespace.
  static String normalize(String versionString) {
    final parsed = SemanticVersion.tryParse(versionString);
    if (parsed != null) {
      return '$parsed';
    }
    var cleaned = versionString.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1).trim();
    }
    return cleaned;
  }

  /// Compares two version strings:
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if equal or unparseable.
  static int compare(String? v1, String? v2) {
    final s1 = SemanticVersion.tryParse(v1);
    final s2 = SemanticVersion.tryParse(v2);
    if (s1 == null && s2 == null) return 0;
    if (s1 == null) return -1;
    if (s2 == null) return 1;
    return s1.compareTo(s2);
  }
}
