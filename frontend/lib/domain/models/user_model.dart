import 'user_role.dart';

class Permission {
  final String id;
  final String key; // e.g. 'inventory.view', 'sales.delete', 'settings.view'
  final String name;
  final String description;

  const Permission({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
  });
}

class Role {
  final String id;
  final String name;
  final UserRole roleEnum;
  final List<Permission> permissions;

  const Role({
    required this.id,
    required this.name,
    required this.roleEnum,
    required this.permissions,
  });
}

class User {
  final String id;
  final String name;
  final String username;
  final String roleId;
  final String roleName;
  final UserRole roleEnum;
  final String passwordHash;
  final bool isActive;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String assignedBranchId;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.roleEnum,
    required this.passwordHash,
    this.isActive = true,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.assignedBranchId = 'branch-402',
  });

  bool hasPermission(String permissionKey) {
    if (roleEnum == UserRole.owner) return true; // Owner has all permissions
    return permissions.contains(permissionKey);
  }
}
