import '../config/feature_flags.dart';
import '../core/sync/sync_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/realtime_socket_service.dart';
import '../core/security/offline_auth_service.dart';
import '../core/security/permission_checker.dart';
import '../core/security/token_storage.dart';
import '../domain/models/staff_model.dart';
import '../domain/models/user_role.dart';
import '../domain/repositories/auth_repository.dart';
import '../services/api/api_providers.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/staff_api_service.dart';
import '../services/api/users_api_service.dart';
import 'repositories/in_memory_auth_repository.dart';

/// Legacy compatible UI Model for displaying user credential metadata safely
class UserCredential {
  final UserRole role;
  final String username;
  final String email;
  final String password; // Hidden / Masked or temporary change buffer
  final DateTime lastUpdated;
  final String updatedBy;
  final bool isDefault;
  final String? id;

  const UserCredential({
    required this.role,
    required this.username,
    required this.email,
    required this.password,
    required this.lastUpdated,
    this.updatedBy = 'Super Admin',
    this.isDefault = false,
    this.id,
  });

  UserCredential copyWith({
    UserRole? role,
    String? username,
    String? email,
    String? password,
    DateTime? lastUpdated,
    String? updatedBy,
    bool? isDefault,
    String? id,
  }) {
    return UserCredential(
      role: role ?? this.role,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      isDefault: isDefault ?? this.isDefault,
      id: id ?? this.id,
    );
  }
}

class AuthState {
  final StaffMember currentUser;
  final UserRole? selectedRole;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final Map<UserRole, UserCredential> credentials;
  final List<UserCredential> staffUsers;

  const AuthState({
    required this.currentUser,
    this.selectedRole,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    required this.credentials,
    this.staffUsers = const [],
  });

  AuthState copyWith({
    StaffMember? currentUser,
    UserRole? selectedRole,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    Map<UserRole, UserCredential>? credentials,
    List<UserCredential>? staffUsers,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      selectedRole: selectedRole ?? this.selectedRole,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      credentials: credentials ?? this.credentials,
      staffUsers: staffUsers ?? this.staffUsers,
    );
  }
}

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return InMemoryAuthRepository();
});

final permissionCheckerProvider = Provider<PermissionChecker>((ref) {
  return const PermissionChecker();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _authApiService;
  final UsersApiService _usersApiService;
  final StaffApiService _staffApiService;
  final IAuthRepository _fallbackRepository;
  final PermissionChecker _permissionChecker;
  final OfflineAuthService _offlineAuthService;
  final Ref? _ref;
  PermissionChecker get permissionChecker => _permissionChecker;
  OfflineAuthService get offlineAuthService => _offlineAuthService;

  AuthNotifier({
    AuthApiService? authApiService,
    UsersApiService? usersApiService,
    StaffApiService? staffApiService,
    IAuthRepository? fallbackRepository,
    PermissionChecker? permissionChecker,
    OfflineAuthService? offlineAuthService,
    Ref? ref,
  })  : _ref = ref,
        _authApiService = authApiService ?? AuthApiService(),
        _usersApiService = usersApiService ?? UsersApiService(),
        _staffApiService = staffApiService ?? StaffApiService(),
        _fallbackRepository = fallbackRepository ?? InMemoryAuthRepository(),
        _permissionChecker = permissionChecker ?? const PermissionChecker(),
        _offlineAuthService = offlineAuthService ?? OfflineAuthService(),
        super(AuthState(
          currentUser: const StaffMember(
            id: 'default_admin',
            fullName: 'Noman',
            phone: '+1 555 0100',
            role: UserRole.owner,
            hourlyRate: 500.0,
            assignedShift: 'All Shifts',
          ),
          isAuthenticated: false,
          credentials: {
            UserRole.owner: UserCredential(
              role: UserRole.owner,
              username: 'Noman',
              email: 'noman@hungryhowies.com',
              password: '••••••••',
              lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
              updatedBy: 'Super Admin',
              isDefault: true,
            ),
            UserRole.manager: UserCredential(
              role: UserRole.manager,
              username: 'storemanager',
              email: 'manager@hungryhowies.com',
              password: '••••••••',
              lastUpdated: DateTime.now().subtract(const Duration(days: 5)),
              updatedBy: 'Store Admin',
              isDefault: true,
            ),
            UserRole.cashier: UserCredential(
              role: UserRole.cashier,
              username: 'poscashier',
              email: 'cashier@hungryhowies.com',
              password: '••••••••',
              lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
              updatedBy: 'POS Admin',
              isDefault: true,
            ),
          },
          staffUsers: const [],
        )) {
    _initAuth();
  }

  Future<void> _initAuth() async {
    await _restoreSession();
    if (!mounted) return;
    if (state.isAuthenticated) {
      await loadUsersFromBackend();
    } else {
      await _loadFallbackCredentials();
    }
  }

  Future<void> loadUsersFromBackend() async {
    final token = await TokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      await _loadFallbackCredentials();
      return;
    }

    try {
      final users = await _usersApiService.listUsers();
      if (!mounted) return;
      if (users.isNotEmpty) {
        final list = users.map((u) {
          final roleStr = u['role']?.toString().toLowerCase() ?? 'cashier';
          UserRole parsedRole = UserRole.cashier;
          if (roleStr == 'owner' || roleStr == 'superadmin') {
            parsedRole = UserRole.owner;
          } else if (roleStr == 'manager' || roleStr == 'storemanager') {
            parsedRole = UserRole.manager;
          }

          final username = u['username']?.toString() ?? '';
          final isDefault = u['is_default'] == true;

          final rawPwd = u['plain_password']?.toString() ?? u['password']?.toString() ?? '';
          final defaultPwd = username.toLowerCase() == 'noman'
              ? 'Noman123'
              : (parsedRole == UserRole.owner
                  ? 'owner123'
                  : (parsedRole == UserRole.manager ? 'manager123' : 'cashier123'));
          final displayPassword = rawPwd.isNotEmpty ? rawPwd : (isDefault ? defaultPwd : '');

          return UserCredential(
            id: u['id']?.toString(),
            role: parsedRole,
            username: username,
            email: u['email']?.toString() ?? '',
            password: displayPassword,
            lastUpdated: u['last_updated'] != null
                ? DateTime.tryParse(u['last_updated'].toString()) ?? DateTime.now()
                : DateTime.now(),
            updatedBy: u['updated_by']?.toString() ?? 'Super Admin',
            isDefault: isDefault,
          );
        }).toList();

        final updatedCreds = Map<UserRole, UserCredential>.from(state.credentials);
        for (final cred in list) {
          if (cred.isDefault) {
            updatedCreds[cred.role] = cred;
          }
        }

        if (!mounted) return;
        _persistLoadedUsers(list);
        state = state.copyWith(staffUsers: list, credentials: updatedCreds);
      }
    } catch (_) {
      // Offline fallback
      if (mounted) {
        await _loadFallbackCredentials();
      }
    }
  }

  Future<void> _persistLoadedUsers(List<UserCredential> users) async {
    for (final cred in users) {
      if (cred.username.isNotEmpty) {
        final defaultPwd = cred.username.toLowerCase() == 'noman'
            ? 'Noman123'
            : (cred.role == UserRole.owner
                ? 'owner123'
                : (cred.role == UserRole.manager ? 'manager123' : 'cashier123'));
        final pwd = cred.password.isNotEmpty ? cred.password : defaultPwd;
        await _fallbackRepository.addStaffUser(
          username: cred.username,
          role: cred.role,
          password: pwd,
          email: cred.email,
        );
      }
    }
  }

  Future<void> _loadFallbackCredentials() async {
    try {
      final creds = await _fallbackRepository.getStoredCredentials();
      if (!mounted) return;
      final updated = <UserRole, UserCredential>{};

      for (final entry in creds.entries) {
        updated[entry.key] = UserCredential(
          role: entry.value.role,
          username: entry.value.username,
          email: entry.value.email,
          password: '••••••••',
          lastUpdated: entry.value.lastUpdated,
          updatedBy: entry.value.updatedBy,
          isDefault: true,
        );
      }
      if (!mounted) return;
      final allStaff = await _fallbackRepository.getStaffUsers();
      final loadedStaff = allStaff.map((f) => UserCredential(
        role: f.role,
        username: f.username,
        email: f.email,
        password: '••••••••',
        lastUpdated: f.lastUpdated,
        updatedBy: f.updatedBy,
        isDefault: f.username.toLowerCase() == 'noman' || f.username.toLowerCase() == 'storemanager' || f.username.toLowerCase() == 'poscashier',
      )).toList();
      state = state.copyWith(credentials: updated, staffUsers: loadedStaff.isNotEmpty ? loadedStaff : state.staffUsers);
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    try {
      final session = await TokenStorage.getUserSession();
      if (!mounted) return;
      if (session != null) {
        final role = session['role'] as UserRole;
        final username = session['username'] as String;
        final userId = session['userId'] as String;

        // Verify with backend GET /api/auth/me
        try {
          final me = await _authApiService.getMe();
          if (!mounted) return;
          final meRole = me['role']?.toString().toLowerCase() ?? '';
          UserRole verifiedRole = role;
          if (meRole == 'owner' || meRole == 'superadmin') {
            verifiedRole = UserRole.owner;
          } else if (meRole == 'manager' || meRole == 'storemanager') {
            verifiedRole = UserRole.manager;
          } else if (meRole == 'cashier' || meRole == 'poscashier') {
            verifiedRole = UserRole.cashier;
          }

          final staff = StaffMember(
            id: me['id']?.toString() ?? userId,
            fullName: me['username']?.toString() ?? username,
            phone: '',
            role: verifiedRole,
            hourlyRate: 406.0,
            assignedShift: 'Active Shift',
          );

          if (!mounted) return;
          state = state.copyWith(
            currentUser: staff,
            selectedRole: verifiedRole,
            isAuthenticated: true,
          );
          return;
        } catch (_) {
          // Token still locally valid during temporary network disconnect
          if (!mounted) return;
          final staff = StaffMember(
            id: userId,
            fullName: username,
            phone: '',
            role: role,
            hourlyRate: 406.0,
            assignedShift: 'Active Shift',
          );
          state = state.copyWith(
            currentUser: staff,
            selectedRole: role,
            isAuthenticated: true,
          );
        }
      }
    } catch (_) {}
  }

  void selectRole(UserRole? role) {
    if (!mounted) return;
    state = state.copyWith(selectedRole: role, clearError: true);
  }

  /// Integrated Login against POST /api/auth/login
  Future<bool> login(String username, String password) async {
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();

    if (trimmedUsername.isEmpty) {
      if (mounted) state = state.copyWith(errorMessage: 'Please enter your username.');
      return false;
    }

    if (trimmedPassword.isEmpty) {
      if (mounted) state = state.copyWith(errorMessage: 'Please enter your password.');
      return false;
    }

    if (!mounted) return false;
    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Try real NestJS backend REST login
    try {
      final loginData = await _authApiService.login(
        username: trimmedUsername,
        password: trimmedPassword,
      );
      if (!mounted) return false;

      final user = loginData['user'] as Map<String, dynamic>? ?? {};
      final roleStr = user['role']?.toString().toLowerCase() ?? '';

      UserRole parsedRole = UserRole.cashier;
      if (roleStr == 'owner' || roleStr == 'superadmin') {
        parsedRole = UserRole.owner;
      } else if (roleStr == 'manager' || roleStr == 'storemanager') {
        parsedRole = UserRole.manager;
      } else {
        parsedRole = UserRole.cashier;
      }

      // Try fetching staff profile
      StaffMember? profile;
      try {
        final staffList = await _staffApiService.listStaff(search: trimmedUsername);
        if (staffList.isNotEmpty) {
          profile = StaffMember.fromBackendJson(staffList.first);
        }
      } catch (_) {}

      profile ??= StaffMember(
        id: user['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: user['username']?.toString() ?? trimmedUsername,
        phone: '',
        role: parsedRole,
        hourlyRate: 406.0,
        assignedShift: 'Active Shift',
      );

      if (!mounted) return false;
      state = state.copyWith(
        currentUser: profile,
        selectedRole: parsedRole,
        isAuthenticated: true,
        isLoading: false,
        clearError: true,
      );

      // Cache Argon2id local verifier in DPAPI-protected store and purge legacy cache
      final userId = user['id']?.toString() ?? profile.id;
      _saveLoginOffline(userId, trimmedUsername, trimmedPassword, parsedRole, user['email']?.toString());
      loadUsersFromBackend();

      final token = loginData['token']?.toString() ?? loginData['accessToken']?.toString();
      RealtimeSocketService.instance.connect(explicitToken: token);

      // SYNC-017: Resume sync outbox from AUTH_PAUSED immediately upon successful authentication
      if (_ref != null && FeatureFlags.offlineFirstEnabled) {
        try {
          _ref.read(syncBackgroundWorkerProvider).resumeAuthPaused();
        } catch (_) {}
      }

      return true;
    } on UnauthorizedException catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.message.isNotEmpty ? e.message : 'Invalid username or password.',
        );
      }
      return false;
    } on ApiException catch (e) {
      if (e is NetworkException || e.message.toLowerCase().contains('network') || e.message.toLowerCase().contains('socket') || e.message.toLowerCase().contains('clientexception') || e.message.toLowerCase().contains('connection') || e.message.toLowerCase().contains('disallowed')) {
        return _loginFallback(trimmedUsername, trimmedPassword);
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.message);
      }
      return false;
    } catch (_) {
      return _loginFallback(trimmedUsername, trimmedPassword);
    }
  }

  Future<void> _saveLoginOffline(
    String userId,
    String username,
    String password,
    UserRole role,
    String? email,
  ) async {
    try {
      await _offlineAuthService.cacheOnlineLogin(
        userId: userId,
        username: username,
        role: role.name,
        password: password,
      );
    } catch (_) {}
  }

  /// Offline local fallback verification if backend is completely unreachable
  Future<bool> _loginFallback(String username, String password) async {
    try {
      final authResult = await _offlineAuthService.authenticateOffline(username, password);
      if (!mounted) return false;

      if (!authResult.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: authResult.errorMessage ?? 'Offline login failed.',
        );
        return false;
      }

      final cred = authResult.credential!;
      final roleStr = cred.role.toLowerCase();
      UserRole parsedRole = UserRole.cashier;
      if (roleStr == 'owner' || roleStr == 'superadmin') {
        parsedRole = UserRole.owner;
      } else if (roleStr == 'manager' || roleStr == 'storemanager') {
        parsedRole = UserRole.manager;
      }

      final activeStaff = StaffMember(
        id: cred.userId,
        fullName: cred.username,
        phone: '',
        role: parsedRole,
        hourlyRate: 406.0,
        assignedShift: 'Offline Shift',
      );

      await TokenStorage.saveUserSession(
        token: 'offline_dpapi_token_${cred.username}',
        userId: activeStaff.id,
        username: cred.username,
        email: '${cred.username}@hungryhowies.com',
        role: parsedRole.name,
        isDefault: true,
      );

      if (!mounted) return false;
      state = state.copyWith(
        currentUser: activeStaff,
        selectedRole: parsedRole,
        isAuthenticated: true,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Login failed: $e',
        );
      }
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _authApiService.logout();
    } catch (_) {
      await TokenStorage.clearSession();
    }
    RealtimeSocketService.instance.disconnect();
    if (!mounted) return;
    state = state.copyWith(
      isAuthenticated: false,
      selectedRole: null,
      clearError: true,
    );
  }

  Future<bool> updatePassword(UserRole role, String newPassword) async {
    final cred = state.credentials[role];
    if (cred != null && cred.id != null) {
      try {
        await _usersApiService.updatePassword(cred.id!, newPassword);
        await loadUsersFromBackend();
        return true;
      } catch (_) {}
    }
    await _fallbackRepository.updatePassword(role, newPassword);
    await _loadFallbackCredentials();
    return true;
  }

  Future<bool> updateUserPassword(String username, String newPassword) async {
    final target = state.staffUsers.firstWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => UserCredential(
        role: UserRole.cashier,
        username: username,
        email: '',
        password: '',
        lastUpdated: DateTime.now(),
      ),
    );

    if (target.id != null) {
      try {
        await _usersApiService.updatePassword(target.id!, newPassword);
        await _fallbackRepository.updateUserPassword(username, newPassword);
        await loadUsersFromBackend();
        return true;
      } catch (_) {}
    }

    await _fallbackRepository.updateUserPassword(username, newPassword);
    await _loadFallbackCredentials();
    return true;
  }

  Future<bool> addStaffUser({
    required String username,
    required UserRole role,
    required String password,
    String? email,
    String? fullName,
  }) async {
    try {
      final user = await _usersApiService.createUser(
        username: username,
        email: email ?? '$username@hungryhowies.com',
        password: password,
        role: role.name,
      );
      final newCred = UserCredential(
        id: user['id']?.toString(),
        role: role,
        username: username,
        email: email ?? '$username@hungryhowies.com',
        password: password,
        lastUpdated: DateTime.now(),
        updatedBy: state.currentUser.fullName,
        isDefault: false,
      );
      state = state.copyWith(staffUsers: [...state.staffUsers, newCred]);
      await _fallbackRepository.addStaffUser(
        username: username,
        role: role,
        password: password,
        email: email,
        fullName: fullName,
      );
      await loadUsersFromBackend();
      return true;
    } catch (_) {
      final ok = await _fallbackRepository.addStaffUser(
        username: username,
        role: role,
        password: password,
        email: email,
        fullName: fullName,
      );
      await _loadFallbackCredentials();
      return ok;
    }
  }

  Future<bool> updateStaffUser({
    String? id,
    required String oldUsername,
    required String newUsername,
    required UserRole newRole,
    String? newPassword,
  }) async {
    final effectiveId = id ??
        state.staffUsers
            .firstWhere(
              (u) =>
                  u.username.toLowerCase() == oldUsername.toLowerCase() ||
                  (id != null && u.id == id),
              orElse: () => UserCredential(
                role: newRole,
                username: oldUsername,
                email: '',
                password: '',
                lastUpdated: DateTime.now(),
              ),
            )
            .id ??
        oldUsername;

    try {
      await _usersApiService.updateUser(
        effectiveId,
        username: newUsername,
        role: newRole.name,
      );
      if (newPassword != null && newPassword.isNotEmpty) {
        await _usersApiService.updatePassword(effectiveId, newPassword);
      }

      // Keep local offline repository fully synced
      await _fallbackRepository.updateStaffUser(
        oldUsername: oldUsername,
        newUsername: newUsername,
        newRole: newRole,
        newPassword: newPassword,
      );

      // If the modified user is currently logged in, update the active session
      if (state.currentUser.fullName.toLowerCase() == oldUsername.toLowerCase() ||
          state.currentUser.id == effectiveId) {
        final updatedStaff = state.currentUser.copyWith(
          fullName: newUsername,
          role: newRole,
        );
        state = state.copyWith(
          currentUser: updatedStaff,
          selectedRole: newRole,
        );
        final existingToken = await TokenStorage.getToken();
        if (existingToken != null && existingToken.isNotEmpty) {
          await TokenStorage.saveUserSession(
            token: existingToken,
            userId: effectiveId,
            username: newUsername,
            email: '$newUsername@hungryhowies.com',
            role: newRole.name,
            isDefault: false,
          );
        }
      }

      await loadUsersFromBackend();
      return true;
    } on ApiException catch (_) {
      return false;
    } catch (_) {
      final ok = await _fallbackRepository.updateStaffUser(
        oldUsername: oldUsername,
        newUsername: newUsername,
        newRole: newRole,
        newPassword: newPassword,
      );
      await _loadFallbackCredentials();
      return ok;
    }
  }

  Future<bool> deleteStaffUser(String username) async {
    final target = state.staffUsers.firstWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => UserCredential(
        role: UserRole.cashier,
        username: username,
        email: '',
        password: '',
        lastUpdated: DateTime.now(),
      ),
    );

    final effectiveId = target.id ?? username;
    try {
      await _usersApiService.deleteUser(effectiveId);
      state = state.copyWith(
        staffUsers: state.staffUsers.where((u) => u.id != target.id && u.username != username).toList(),
      );
      await _fallbackRepository.deleteStaffUser(username);
      await loadUsersFromBackend();
      return true;
    } catch (_) {}

    final ok = await _fallbackRepository.deleteStaffUser(username);
    await _loadFallbackCredentials();
    return ok;
  }

  Future<void> resetUserPassword(String username) async {
    final target = state.staffUsers.firstWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => UserCredential(
        role: UserRole.cashier,
        username: username,
        email: '',
        password: '',
        lastUpdated: DateTime.now(),
      ),
    );

    final defaultPwd = target.username.toLowerCase() == 'noman'
        ? 'Noman123'
        : (target.role == UserRole.owner
            ? 'owner123'
            : (target.role == UserRole.manager ? 'manager123' : 'cashier123'));

    await updateUserPassword(username, defaultPwd);
  }
}

final offlineAuthServiceProvider = Provider<OfflineAuthService>((ref) {
  return OfflineAuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authApi = ref.watch(authApiServiceProvider);
  final usersApi = ref.watch(usersApiServiceProvider);
  final staffApi = ref.watch(staffApiServiceProvider);
  final repo = ref.watch(authRepositoryProvider);
  final checker = ref.watch(permissionCheckerProvider);
  final offlineAuth = ref.watch(offlineAuthServiceProvider);

  return AuthNotifier(
    authApiService: authApi,
    usersApiService: usersApi,
    staffApiService: staffApi,
    fallbackRepository: repo,
    permissionChecker: checker,
    offlineAuthService: offlineAuth,
    ref: ref,
  );
});
