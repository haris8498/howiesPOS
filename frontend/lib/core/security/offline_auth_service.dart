import 'dart:math';
import 'local_credential_verifier.dart';
import 'offline_credential_store.dart';

/// Status outcomes for offline authentication attempts.
enum OfflineAuthStatus {
  success,
  invalidCredentials,
  userNotFound,
  expired,
  lockedOut,
  unauthorizedRole,
}

/// Result object for offline authentication attempts.
class OfflineAuthResult {
  final OfflineAuthStatus status;
  final OfflineCredential? credential;
  final String? errorMessage;
  final int? lockoutSecondsRemaining;

  const OfflineAuthResult({
    required this.status,
    this.credential,
    this.errorMessage,
    this.lockoutSecondsRemaining,
  });

  bool get isSuccess => status == OfflineAuthStatus.success;

  factory OfflineAuthResult.success(OfflineCredential cred) => OfflineAuthResult(
        status: OfflineAuthStatus.success,
        credential: cred,
      );

  factory OfflineAuthResult.invalidCredentials({String? message}) => OfflineAuthResult(
        status: OfflineAuthStatus.invalidCredentials,
        errorMessage: message ?? 'Invalid username or password.',
      );

  factory OfflineAuthResult.userNotFound([String? username]) => OfflineAuthResult(
        status: OfflineAuthStatus.userNotFound,
        errorMessage: username != null
            ? 'User "$username" has not cached offline credentials on this terminal. Please log in online first.'
            : 'User not found in offline credential cache.',
      );

  factory OfflineAuthResult.expired({required DateTime lastOnlineAt, required int maxDays}) =>
      OfflineAuthResult(
        status: OfflineAuthStatus.expired,
        errorMessage:
            'Offline login expired. Last online login was ${lastOnlineAt.toLocal().toString().split('.')[0]}. '
            'An internet connection is required after $maxDays days of offline use.',
      );

  factory OfflineAuthResult.lockedOut(int secondsRemaining) => OfflineAuthResult(
        status: OfflineAuthStatus.lockedOut,
        lockoutSecondsRemaining: secondsRemaining,
        errorMessage:
            'Too many failed login attempts. Terminal access locked for $secondsRemaining seconds.',
      );

  factory OfflineAuthResult.unauthorizedRole(String role) => OfflineAuthResult(
        status: OfflineAuthStatus.unauthorizedRole,
        errorMessage: 'Role "$role" is not authorized for manager approval.',
      );
}

/// State tracking failed attempts and exponential lockout per user.
class _UserLockoutState {
  int failedAttempts = 0;
  DateTime? lockedUntil;

  bool isLocked(DateTime now) {
    if (lockedUntil == null) return false;
    return now.isBefore(lockedUntil!);
  }

  int secondsRemaining(DateTime now) {
    if (lockedUntil == null) return 0;
    final diff = lockedUntil!.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

/// Hardened offline authentication service.
///
/// Implements SEC-05, SEC-07, and SEC-11 offline security requirements:
/// 1. Verifies typed credentials against locally stored Argon2id verifiers.
/// 2. Enforces cache expiration (default: 14 days since last online login).
/// 3. Protects against brute-force attacks via exponential lockout after 5 failed attempts.
/// 4. Performs constant-time verifier comparisons to prevent side-channel timing attacks.
/// 5. Exposes [verifyManagerCredential] for offline manager PIN/password approvals (reused by D-03).
class OfflineAuthService {
  final OfflineCredentialStore store;

  /// Default offline cache lifetime before requiring online re-authentication (14 days).
  final Duration maxOfflineDuration;

  /// Failed attempts threshold before exponential lockout begins.
  final int maxFailedAttemptsBeforeLockout;

  /// Base backoff duration for the first lockout trigger (30 seconds).
  final Duration baseLockoutDuration;

  /// In-memory tracker for consecutive failures and active lockouts.
  final Map<String, _UserLockoutState> _lockoutStates = {};

  OfflineAuthService({
    OfflineCredentialStore? store,
    Duration? maxOfflineDuration,
    int? maxFailedAttemptsBeforeLockout,
    Duration? baseLockoutDuration,
  })  : store = store ?? OfflineCredentialStore(),
        maxOfflineDuration = maxOfflineDuration ?? const Duration(days: 14),
        maxFailedAttemptsBeforeLockout = maxFailedAttemptsBeforeLockout ?? 5,
        baseLockoutDuration = baseLockoutDuration ?? const Duration(seconds: 30);

  /// Authenticates a staff user offline by verifying their typed password against
  /// the DPAPI-cached Argon2id verifier.
  Future<OfflineAuthResult> authenticateOffline(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.trim().isEmpty) {
      return OfflineAuthResult.invalidCredentials(message: 'Username and password cannot be empty.');
    }

    final now = DateTime.now();
    final lockoutKey = cleanUsername.toLowerCase();
    final lockout = _lockoutStates.putIfAbsent(lockoutKey, () => _UserLockoutState());

    // 1. Check if user is locked out
    if (lockout.isLocked(now)) {
      return OfflineAuthResult.lockedOut(lockout.secondsRemaining(now));
    }

    // 2. Retrieve DPAPI-protected cached credential
    final cred = await store.getCredential(cleanUsername);
    if (cred == null) {
      return OfflineAuthResult.userNotFound(cleanUsername);
    }

    // 3. Check cache expiry (default 14 days)
    final age = now.difference(cred.lastOnlineLoginAt);
    if (age > maxOfflineDuration) {
      return OfflineAuthResult.expired(
        lastOnlineAt: cred.lastOnlineLoginAt,
        maxDays: maxOfflineDuration.inDays,
      );
    }

    // 4. Derive candidate verifier using same salt and parameters
    final saltBytes = LocalCredentialVerifier.hexToBytes(cred.saltHex);
    final candidateVerifierBytes = await LocalCredentialVerifier.deriveVerifier(
      password: password.trim(),
      salt: saltBytes,
      params: cred.params,
    );

    final storedVerifierBytes = LocalCredentialVerifier.hexToBytes(cred.verifierHex);

    // 5. Constant-time byte comparison
    final isValid = LocalCredentialVerifier.constantTimeEquals(
      candidateVerifierBytes,
      storedVerifierBytes,
    );

    if (!isValid) {
      _recordFailure(lockout, now);
      if (lockout.isLocked(now)) {
        return OfflineAuthResult.lockedOut(lockout.secondsRemaining(now));
      }
      return OfflineAuthResult.invalidCredentials();
    }

    // 6. Success: reset failure count
    _resetLockout(lockoutKey);
    return OfflineAuthResult.success(cred);
  }

  /// Caches a user's offline authentication verifier following a successful ONLINE login.
  ///
  /// - Derives a new Argon2id verifier with a fresh per-user 128-bit random salt.
  /// - Saves the record encrypted under Windows DPAPI user scope.
  /// - Purges any legacy raw SHA-256 password caches.
  /// - Resets any active lockout counters for this user.
  Future<OfflineCredential> cacheOnlineLogin({
    required String userId,
    required String username,
    required String role,
    required String password,
    VerifierParams params = const VerifierParams(),
    bool isPin = false,
  }) async {
    final cleanUsername = username.trim();
    final cleanUserId = userId.trim();

    // 1. Generate 16-byte cryptographically secure random salt
    final saltBytes = LocalCredentialVerifier.generateRandomSalt(16);
    final saltHex = LocalCredentialVerifier.bytesToHex(saltBytes);

    // 2. Derive verifier using Argon2id
    final verifierBytes = await LocalCredentialVerifier.deriveVerifier(
      password: password.trim(),
      salt: saltBytes,
      params: params,
    );
    final verifierHex = LocalCredentialVerifier.bytesToHex(verifierBytes);

    final credential = OfflineCredential(
      userId: cleanUserId,
      username: cleanUsername,
      role: role.trim(),
      saltHex: saltHex,
      verifierHex: verifierHex,
      params: params,
      lastOnlineLoginAt: DateTime.now(),
      isPin: isPin,
    );

    // 3. Save to DPAPI-protected store
    await store.saveCredential(credential);

    // 4. Purge legacy SHA-256 caches from disk
    await store.purgeLegacyCache();

    // 5. Reset failure counters
    _resetLockout(cleanUsername.toLowerCase());
    _resetLockout(cleanUserId.toLowerCase());

    return credential;
  }

  /// Verifies a manager or owner credential (PIN or password) for offline supervisor overrides.
  ///
  /// Exposes standard interface for D-03 to reuse (e.g. offline discount/void/shift overrides).
  Future<OfflineAuthResult> verifyManagerCredential(
    String managerIdOrUsername,
    String credentialOrPin,
  ) async {
    final clean = managerIdOrUsername.trim();
    if (clean.isEmpty || credentialOrPin.trim().isEmpty) {
      return OfflineAuthResult.invalidCredentials(message: 'Manager ID and credential/PIN are required.');
    }

    final now = DateTime.now();
    final lockoutKey = 'mgr:${clean.toLowerCase()}';
    final lockout = _lockoutStates.putIfAbsent(lockoutKey, () => _UserLockoutState());

    if (lockout.isLocked(now)) {
      return OfflineAuthResult.lockedOut(lockout.secondsRemaining(now));
    }

    final cred = await store.getCredential(clean);
    if (cred == null) {
      return OfflineAuthResult.userNotFound(clean);
    }

    // Role check: must be manager or owner
    final roleLower = cred.role.toLowerCase();
    if (roleLower != 'manager' && roleLower != 'owner' && roleLower != 'superadmin') {
      return OfflineAuthResult.unauthorizedRole(cred.role);
    }

    // Cache expiry check
    final age = now.difference(cred.lastOnlineLoginAt);
    if (age > maxOfflineDuration) {
      return OfflineAuthResult.expired(
        lastOnlineAt: cred.lastOnlineLoginAt,
        maxDays: maxOfflineDuration.inDays,
      );
    }

    final saltBytes = LocalCredentialVerifier.hexToBytes(cred.saltHex);
    final candidateVerifier = await LocalCredentialVerifier.deriveVerifier(
      password: credentialOrPin.trim(),
      salt: saltBytes,
      params: cred.params,
    );

    final storedVerifier = LocalCredentialVerifier.hexToBytes(cred.verifierHex);
    final isValid = LocalCredentialVerifier.constantTimeEquals(candidateVerifier, storedVerifier);

    if (!isValid) {
      _recordFailure(lockout, now);
      if (lockout.isLocked(now)) {
        return OfflineAuthResult.lockedOut(lockout.secondsRemaining(now));
      }
      return OfflineAuthResult.invalidCredentials(message: 'Invalid manager PIN or password.');
    }

    _resetLockout(lockoutKey);
    return OfflineAuthResult.success(cred);
  }

  /// Records an authentication failure and applies exponential lockout if threshold reached.
  void _recordFailure(_UserLockoutState lockout, DateTime now) {
    lockout.failedAttempts++;
    if (lockout.failedAttempts >= maxFailedAttemptsBeforeLockout) {
      // Exponential backoff: base * 2^(failures - threshold)
      final exponent = lockout.failedAttempts - maxFailedAttemptsBeforeLockout;
      final multiplier = pow(2, exponent).toInt();
      final lockoutDuration = baseLockoutDuration * multiplier;
      // Cap at 24 hours
      final effectiveDuration = lockoutDuration > const Duration(hours: 24)
          ? const Duration(hours: 24)
          : lockoutDuration;
      lockout.lockedUntil = now.add(effectiveDuration);
    }
  }

  /// Resets lockout state for a specific user identifier.
  void _resetLockout(String key) {
    _lockoutStates.remove(key.toLowerCase());
  }

  /// Explicitly revokes offline access for a specific user (e.g. deactivated by admin).
  Future<void> revokeUser(String userId) async {
    await store.removeCredential(userId);
    _resetLockout(userId.toLowerCase());
  }

  /// Completely wipes all offline credential caches (e.g. terminal decommission or emergency lock).
  Future<void> revokeAll() async {
    await store.wipeAll();
    _lockoutStates.clear();
  }

  /// Helper to check current failed attempts count (useful for testing).
  int getFailedAttempts(String key) {
    return _lockoutStates[key.toLowerCase()]?.failedAttempts ?? 0;
  }
}
