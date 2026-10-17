import '../../domain/models/role_rights_model.dart';
import '../../domain/models/user_role.dart';

/// Centralized authorization and permission engine.
/// Evaluates role-based and granular permissions cleanly across the app.
class PermissionChecker {
  const PermissionChecker();

  /// Check whether a user with a given role and permission list has permission for an action/module.
  bool hasPermission({
    required UserRole role,
    required String permissionId,
    List<ModulePermission> customPermissions = const [],
  }) {
    // 1. Owner role has absolute unrestricted authority across all modules
    if (role == UserRole.owner) {
      return true;
    }

    // 2. For Manager or Cashier, inspect granted custom permissions if provided
    if (customPermissions.isNotEmpty) {
      final cleanKey = permissionId.toLowerCase().replaceAll(' ', '_');
      final match = customPermissions.firstWhere(
        (p) {
          final pid = p.id.toLowerCase();
          return pid == cleanKey ||
              pid == 'mgr_$cleanKey' ||
              pid == 'csh_$cleanKey' ||
              pid == 'mgr_mod_$cleanKey' ||
              pid == 'csh_mod_$cleanKey' ||
              pid == 'mod_$cleanKey' ||
              pid.endsWith(cleanKey) ||
              pid.contains(cleanKey);
        },
        orElse: () => const ModulePermission(
          id: '',
          moduleName: '',
          actionName: '',
          description: '',
          isGranted: false,
        ),
      );
      if (match.id.isNotEmpty) {
        return match.isGranted;
      }
    }

    // 3. Default fallback role permissions
    return _getDefaultRolePermission(role, permissionId);
  }

  /// Evaluates standard default permissions per role
  bool _getDefaultRolePermission(UserRole role, String permissionId) {
    switch (role) {
      case UserRole.owner:
        return true;
      case UserRole.manager:
        // Managers have access to all operational modules by default, except master password resets
        if (permissionId == 'auth_master_reset') return false;
        return true;
      case UserRole.cashier:
        // Cashiers only have access to operational sales, tables, takeaway, delivery
        const cashierAllowed = {
          'mod_pos',
          'mod_tables',
          'mod_takeaway',
          'mod_delivery',
          'mod_menu_view',
          'pos_order_create',
          'pos_payment_accept',
          'table_view',
          'table_order_update',
        };
        return cashierAllowed.contains(permissionId);
    }
  }

  /// Validate if a route path is accessible for a given role
  bool isRouteAllowed(String routePath, UserRole role) {
    if (role == UserRole.owner) return true;
    if (routePath.startsWith('/owner')) return false;
    if (routePath.startsWith('/manager') && role != UserRole.manager) return false;
    return true;
  }
}
