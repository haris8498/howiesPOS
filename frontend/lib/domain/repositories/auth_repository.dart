import '../models/staff_model.dart';
import '../models/user_role.dart';

/// User credential representation with hashed password for local authentication
class HashedUserCredential {
  final UserRole role;
  final String username;
  final String email;
  final String passwordHash;
  final String salt;
  final String? plainPassword;
  final DateTime lastUpdated;
  final String updatedBy;

  const HashedUserCredential({
    required this.role,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.salt,
    this.plainPassword,
    required this.lastUpdated,
    this.updatedBy = 'Super Admin',
  });

  HashedUserCredential copyWith({
    UserRole? role,
    String? username,
    String? email,
    String? passwordHash,
    String? salt,
    String? plainPassword,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return HashedUserCredential(
      role: role ?? this.role,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      plainPassword: plainPassword ?? this.plainPassword,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

/// Abstract contract for Authentication & Role credentials
abstract class IAuthRepository {
  Future<Map<UserRole, HashedUserCredential>> getStoredCredentials();
  Future<List<HashedUserCredential>> getStaffUsers();
  Future<bool> verifyCredentials(UserRole role, String candidatePassword);
  Future<HashedUserCredential?> findCredentialByUsername(String identifier);
  Future<void> updatePassword(UserRole role, String newPassword, {String updatedBy = 'Super Admin'});
  Future<void> updateUserPassword(String username, String newPassword, {String updatedBy = 'Super Admin'});
  Future<void> resetPasswordToDefault(UserRole role);
  Future<void> resetUserPassword(String username);
  Future<bool> addStaffUser({
    required String username,
    required UserRole role,
    required String password,
    String? email,
    String? fullName,
    String createdBy = 'Owner',
  });
  Future<bool> updateStaffUser({
    required String oldUsername,
    required String newUsername,
    required UserRole newRole,
    String? newPassword,
    String updatedBy = 'Owner',
  });
  Future<bool> deleteStaffUser(String username);
  Future<StaffMember?> getStaffForRole(UserRole role);
  Future<StaffMember?> getStaffForUsername(String username);
}
