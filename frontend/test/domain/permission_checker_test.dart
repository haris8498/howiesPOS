import 'package:flutter_test/flutter_test.dart';
import 'package:hungry_howies_pos/core/security/permission_checker.dart';
import 'package:hungry_howies_pos/domain/models/role_rights_model.dart';
import 'package:hungry_howies_pos/domain/models/user_role.dart';

void main() {
  group('PermissionChecker Authorization Tests', () {
    const checker = PermissionChecker();

    test('Owner role has unrestricted permissions across all modules', () {
      expect(checker.hasPermission(role: UserRole.owner, permissionId: 'mod_reports'), isTrue);
      expect(checker.hasPermission(role: UserRole.owner, permissionId: 'auth_master_reset'), isTrue);
      expect(checker.hasPermission(role: UserRole.owner, permissionId: 'random_custom_action'), isTrue);
    });

    test('Cashier is restricted from administrative modules by default', () {
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'mod_pos'), isTrue);
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'mod_tables'), isTrue);
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'mod_reports'), isFalse);
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'mod_expenses'), isFalse);
    });

    test('Cashier has discount rights by default under cashier discount policy', () {
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'order_discount'), isTrue);
      expect(checker.hasPermission(role: UserRole.cashier, permissionId: 'pos_discount'), isTrue);
    });

    test('Manager honors custom module permission grants', () {
      final permissions = [
        const ModulePermission(
          id: 'mod_expenses',
          moduleName: 'Expenses',
          actionName: 'View Expenses',
          description: 'Expense access',
          isGranted: false, // Explicitly revoked
        ),
      ];

      expect(
        checker.hasPermission(
          role: UserRole.manager,
          permissionId: 'mod_expenses',
          customPermissions: permissions,
        ),
        isFalse,
      );
    });

    test('isRouteAllowed checks portal paths correctly', () {
      expect(checker.isRouteAllowed('/owner/dashboard', UserRole.owner), isTrue);
      expect(checker.isRouteAllowed('/owner/dashboard', UserRole.manager), isFalse);
      expect(checker.isRouteAllowed('/owner/dashboard', UserRole.cashier), isFalse);
      expect(checker.isRouteAllowed('/sales/tables', UserRole.cashier), isTrue);
    });
  });
}
