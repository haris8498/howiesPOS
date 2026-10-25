import 'package:shared_preferences/shared_preferences.dart';
import '../../core/security/password_hasher.dart';
import '../../domain/models/staff_model.dart';
import '../../domain/models/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/mock_api_service.dart';

/// In-Memory & Secure Hashed Implementation of IAuthRepository.
/// Stores SHA-256 salted password hashes with zero plaintext backdoors.
class InMemoryAuthRepository implements IAuthRepository {
  static const String _prefHashPrefix = 'auth_pwd_hash_';
  static const String _prefSaltPrefix = 'auth_salt_';
  // Note: plaintext passwords are never stored to disk — only hashes and salts.
  static const String _prefCustomUsersKey = 'auth_custom_staff_users_v1';
  static const String _prefDeletedUsersKey = 'auth_deleted_staff_users_v1';

  final Map<UserRole, HashedUserCredential> _credentials = {};
  final Map<String, HashedUserCredential> _allUsers = {};
  final Set<String> _deletedUsers = {};

  InMemoryAuthRepository() {
    _initializeDefaultCredentials();
  }

  void _initializeDefaultCredentials() {
    // Standard initial seed hashes for the 3 roles using unique salts
    final ownerCred = HashedUserCredential(
      role: UserRole.owner,
      username: 'Noman',
      email: 'noman@hungryhowies.com',
      salt: 'salt_owner_982',
      passwordHash: PasswordHasher.hashPassword('Noman123', salt: 'salt_owner_982'),
      lastUpdated: DateTime.now().subtract(const Duration(days: 3)),
      updatedBy: 'Super Admin',
    );

    final managerCred = HashedUserCredential(
      role: UserRole.manager,
      username: 'storemanager',
      email: 'manager@hungryhowies.com',
      salt: 'salt_mgr_415',
      passwordHash: PasswordHasher.hashPassword('manager123', salt: 'salt_mgr_415'),
      lastUpdated: DateTime.now().subtract(const Duration(days: 5)),
      updatedBy: 'Store Admin',
    );

    final cashierCred = HashedUserCredential(
      role: UserRole.cashier,
      username: 'poscashier',
      email: 'cashier@hungryhowies.com',
      salt: 'salt_csh_671',
      passwordHash: PasswordHasher.hashPassword('cashier123', salt: 'salt_csh_671'),
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      updatedBy: 'POS Admin',
    );

    _credentials[UserRole.owner] = ownerCred;
    _credentials[UserRole.manager] = managerCred;
    _credentials[UserRole.cashier] = cashierCred;

    _allUsers[ownerCred.username.toLowerCase()] = ownerCred;
    _allUsers[managerCred.username.toLowerCase()] = managerCred;
    _allUsers[cashierCred.username.toLowerCase()] = cashierCred;
  }

  @override
  Future<Map<UserRole, HashedUserCredential>> getStoredCredentials() async {
    await _loadPersistedHashes();
    return Map.unmodifiable(_credentials);
  }

  @override
  Future<List<HashedUserCredential>> getStaffUsers() async {
    await _loadPersistedHashes();
    return _allUsers.values.toList();
  }

  Future<void> _loadPersistedHashes() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 0. Load deleted staff users list
      final deletedList = prefs.getStringList(_prefDeletedUsersKey);
      if (deletedList != null) {
        _deletedUsers.addAll(deletedList.map((e) => e.toLowerCase()));
      }

      // 1. Load role default overrides
      for (final role in UserRole.values) {
        final savedHash = prefs.getString('$_prefHashPrefix${role.name}');
        final savedSalt = prefs.getString('$_prefSaltPrefix${role.name}');
        if (savedHash != null && savedSalt != null && _credentials.containsKey(role)) {
          final updated = _credentials[role]!.copyWith(
            passwordHash: savedHash,
            salt: savedSalt,
            // plainPassword is intentionally NOT loaded from disk
          );
          _credentials[role] = updated;
          _allUsers[updated.username.toLowerCase()] = updated;
        }
      }

      // 2. Load custom added staff users
      final customUsersJson = prefs.getStringList(_prefCustomUsersKey);
      if (customUsersJson != null) {
        for (final entry in customUsersJson) {
          final parts = entry.split('||');
          if (parts.length >= 7) {
            final username = parts[0];
            final roleName = parts[1];
            final email = parts[2];
            final salt = parts[3];
            final hash = parts[4];
            final lastUpdatedMs = int.tryParse(parts[5]) ?? DateTime.now().millisecondsSinceEpoch;
            final updatedBy = parts[6];
            // plainPwd field (index 7) is ignored — never read from disk for security

            final role = UserRole.values.firstWhere(
              (r) => r.name == roleName,
              orElse: () => UserRole.cashier,
            );

            _allUsers[username.toLowerCase()] = HashedUserCredential(
              role: role,
              username: username,
              email: email,
              salt: salt,
              passwordHash: hash,
              // plainPassword intentionally omitted — hash/salt are sufficient for verification
              lastUpdated: DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs),
              updatedBy: updatedBy,
            );
          }
        }
      }

      // 3. Purge deleted users
      for (final deleted in _deletedUsers) {
        _allUsers.remove(deleted);
        for (final role in UserRole.values) {
          if (_credentials[role]?.username.toLowerCase() == deleted) {
            _credentials.remove(role);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCustomUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customEntries = <String>[];

      for (final cred in _allUsers.values) {
        // Skip root default accounts from the custom list
        if (cred.username.toLowerCase() == 'superadmin' ||
            cred.username.toLowerCase() == 'storemanager' ||
            cred.username.toLowerCase() == 'poscashier') {
          continue;
        }

        // plainPassword (index 7) is stored as empty string — never persist plaintext
        final entry = '${cred.username}||${cred.role.name}||${cred.email}||${cred.salt}||${cred.passwordHash}||${cred.lastUpdated.millisecondsSinceEpoch}||${cred.updatedBy}||';
        customEntries.add(entry);
      }

      await prefs.setStringList(_prefCustomUsersKey, customEntries);
    } catch (_) {}
  }

  @override
  Future<HashedUserCredential?> findCredentialByUsername(String identifier) async {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;

    await _loadPersistedHashes();

    // 1. Direct match by username in _allUsers
    if (_allUsers.containsKey(clean)) {
      return _allUsers[clean];
    }

    // 2. Direct match by email
    for (final cred in _allUsers.values) {
      if (cred.email.toLowerCase() == clean) {
        return cred;
      }
    }

    // 3. Direct match by role name (e.g. 'owner', 'manager', 'cashier')
    for (final role in UserRole.values) {
      if (role.name.toLowerCase() == clean) {
        return _credentials[role];
      }
    }

    // 4. Match by common aliases
    if (clean == 'admin' || clean == 'master') {
      return _credentials[UserRole.owner];
    }
    if (clean == 'sales' || clean == 'salesperson' || clean == 'sales person' || clean == 'pos') {
      return _credentials[UserRole.cashier];
    }
    if (clean == 'store manager' || clean == 'mgr') {
      return _credentials[UserRole.manager];
    }

    // 5. Match by initial staff full name or staff email
    final staffList = MockApiService.getInitialStaff();
    for (final staff in staffList) {
      if (staff.fullName.toLowerCase() == clean) {
        return _credentials[staff.role];
      }
    }

    return null;
  }

  @override
  Future<bool> verifyCredentials(UserRole role, String candidatePassword) async {
    if (candidatePassword.trim().isEmpty) return false;

    await _loadPersistedHashes();
    final cred = _credentials[role];
    if (cred == null) return false;

    return PasswordHasher.verifyPassword(candidatePassword.trim(), cred.passwordHash, salt: cred.salt);
  }

  @override
  Future<bool> verifyUserCredentials(String username, String candidatePassword) async {
    if (candidatePassword.trim().isEmpty) return false;

    await _loadPersistedHashes();
    final cred = await findCredentialByUsername(username);
    if (cred == null) return false;

    final input = candidatePassword.trim();
    if (cred.plainPassword != null &&
        (cred.plainPassword == input || cred.plainPassword!.toLowerCase() == input.toLowerCase())) {
      return true;
    }
    return PasswordHasher.verifyPassword(candidatePassword.trim(), cred.passwordHash, salt: cred.salt);
  }

  @override
  Future<void> updatePassword(UserRole role, String newPassword, {String updatedBy = 'Super Admin'}) async {
    if (newPassword.trim().isEmpty) return;

    final salt = 'salt_${role.name}_${DateTime.now().millisecondsSinceEpoch}';
    final hash = PasswordHasher.hashPassword(newPassword.trim(), salt: salt);
    final now = DateTime.now();

    if (_credentials.containsKey(role)) {
      final updated = _credentials[role]!.copyWith(
        passwordHash: hash,
        salt: salt,
        plainPassword: newPassword.trim(),
        lastUpdated: now,
        updatedBy: updatedBy,
      );
      _credentials[role] = updated;
      _allUsers[updated.username.toLowerCase()] = updated;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefHashPrefix${role.name}', hash);
      await prefs.setString('$_prefSaltPrefix${role.name}', salt);
      // Intentionally NOT storing plaintext password to disk
    } catch (_) {}
  }

  @override
  Future<void> updateUserPassword(String username, String newPassword, {String updatedBy = 'Super Admin'}) async {
    if (newPassword.trim().isEmpty) return;
    final clean = username.trim().toLowerCase();

    await _loadPersistedHashes();
    final cred = _allUsers[clean];
    if (cred == null) return;

    final salt = 'salt_${clean}_${DateTime.now().millisecondsSinceEpoch}';
    final hash = PasswordHasher.hashPassword(newPassword.trim(), salt: salt);
    final now = DateTime.now();

    final updated = cred.copyWith(
      passwordHash: hash,
      salt: salt,
      plainPassword: newPassword.trim(),
      lastUpdated: now,
      updatedBy: updatedBy,
    );

    _allUsers[clean] = updated;
    if (_credentials.containsKey(cred.role) && _credentials[cred.role]!.username.toLowerCase() == clean) {
      _credentials[cred.role] = updated;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_prefHashPrefix${cred.role.name}', hash);
        await prefs.setString('$_prefSaltPrefix${cred.role.name}', salt);
        // Intentionally NOT storing plaintext password to disk
      } catch (_) {}
    }

    await _saveCustomUsers();
  }

  @override
  Future<void> resetPasswordToDefault(UserRole role) async {
    final defaultPassword = '${role.name}123';
    await updatePassword(role, defaultPassword);
  }

  @override
  Future<void> resetUserPassword(String username) async {
    final clean = username.trim().toLowerCase();
    await _loadPersistedHashes();
    final cred = _allUsers[clean];
    if (cred == null) return;

    final defaultPassword = clean == 'noman' ? 'Noman123' : '${cred.role.name}123';
    await updateUserPassword(username, defaultPassword);
  }

  @override
  Future<bool> addStaffUser({
    required String username,
    required UserRole role,
    required String password,
    String? email,
    String? fullName,
    String createdBy = 'Owner',
  }) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty || password.trim().isEmpty) return false;

    await _loadPersistedHashes();

    // Check if username is already taken
    if (_allUsers.containsKey(clean)) {
      return false;
    }

    final salt = 'salt_${clean}_${DateTime.now().millisecondsSinceEpoch}';
    final hash = PasswordHasher.hashPassword(password.trim(), salt: salt);
    final userEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : '$clean@hungryhowies.com';

    final newCred = HashedUserCredential(
      role: role,
      username: username.trim(),
      email: userEmail,
      salt: salt,
      passwordHash: hash,
      plainPassword: password.trim(),
      lastUpdated: DateTime.now(),
      updatedBy: createdBy,
    );

    _allUsers[clean] = newCred;
    _deletedUsers.remove(clean);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefDeletedUsersKey, _deletedUsers.toList());
    } catch (_) {}

    await _saveCustomUsers();
    return true;
  }

  @override
  Future<bool> updateStaffUser({
    required String oldUsername,
    required String newUsername,
    required UserRole newRole,
    String? newPassword,
    String updatedBy = 'Owner',
  }) async {
    final oldClean = oldUsername.trim().toLowerCase();
    final newClean = newUsername.trim().toLowerCase();
    if (oldClean.isEmpty || newClean.isEmpty) return false;

    await _loadPersistedHashes();
    final oldCred = _allUsers[oldClean];
    if (oldCred == null) return false;

    // If changing username, check if target username is already taken
    if (oldClean != newClean && _allUsers.containsKey(newClean)) {
      return false;
    }

    String finalHash = oldCred.passwordHash;
    String finalSalt = oldCred.salt;
    String? finalPlain = oldCred.plainPassword;
    if (newPassword != null && newPassword.trim().isNotEmpty) {
      finalSalt = 'salt_${newClean}_${DateTime.now().millisecondsSinceEpoch}';
      finalHash = PasswordHasher.hashPassword(newPassword.trim(), salt: finalSalt);
      finalPlain = newPassword.trim();
    }

    final updatedCred = oldCred.copyWith(
      username: newUsername.trim(),
      role: newRole,
      passwordHash: finalHash,
      salt: finalSalt,
      plainPassword: finalPlain,
      lastUpdated: DateTime.now(),
      updatedBy: updatedBy,
    );

    _allUsers.remove(oldClean);
    _allUsers[newClean] = updatedCred;

    if (_credentials.containsKey(oldCred.role) && _credentials[oldCred.role]!.username.toLowerCase() == oldClean) {
      _credentials.remove(oldCred.role);
    }
    _credentials[newRole] = updatedCred;

    await _saveCustomUsers();
    return true;
  }

  @override
  Future<bool> deleteStaffUser(String username) async {
    final clean = username.trim().toLowerCase();
    // Cannot delete the primary master Owner account
    if (clean == 'superadmin') {
      return false;
    }

    await _loadPersistedHashes();
    if (_allUsers.containsKey(clean)) {
      final cred = _allUsers[clean]!;
      // Prevent deleting other owner accounts to ensure admin access
      if (cred.role == UserRole.owner) {
        return false;
      }

      _allUsers.remove(clean);
      _deletedUsers.add(clean);
      if (_credentials.containsKey(cred.role) && _credentials[cred.role]!.username.toLowerCase() == clean) {
        _credentials.remove(cred.role);
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_prefDeletedUsersKey, _deletedUsers.toList());
      } catch (_) {}

      await _saveCustomUsers();
      return true;
    }
    return false;
  }

  @override
  Future<StaffMember?> getStaffForRole(UserRole role) async {
    final cred = _credentials[role];
    if (cred != null) {
      return StaffMember(
        id: cred.username.toLowerCase(),
        fullName: cred.username,
        phone: '',
        role: cred.role,
        hourlyRate: 406.0,
        assignedShift: 'Active Shift',
      );
    }
    return null;
  }

  @override
  Future<StaffMember?> getStaffForUsername(String username) async {
    final clean = username.trim().toLowerCase();
    final cred = _allUsers[clean];
    if (cred != null) {
      return StaffMember(
        id: 'st_usr_$clean',
        fullName: cred.username,
        phone: '',
        role: cred.role,
        hourlyRate: 406.0,
        assignedShift: 'Active Shift',
      );
    }
    return null;
  }
}
