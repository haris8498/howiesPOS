import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/role_rights_model.dart';
import '../domain/models/user_role.dart';
import '../services/api/api_providers.dart';
import '../services/api/permissions_api_service.dart';
import 'auth_repository.dart';

class RoleRightsState {
  final UserRole selectedRole;
  final List<ModulePermission> managerPermissions;
  final List<ModulePermission> cashierPermissions;
  final bool isLoading;

  const RoleRightsState({
    this.selectedRole = UserRole.manager,
    required this.managerPermissions,
    required this.cashierPermissions,
    this.isLoading = false,
  });

  List<ModulePermission> get currentPermissions =>
      selectedRole == UserRole.manager ? managerPermissions : cashierPermissions;

  int get grantedCount => currentPermissions.where((p) => p.isGranted).length;
  int get restrictedCount => currentPermissions.where((p) => !p.isGranted).length;
  int get sensitiveCount => currentPermissions.where((p) => p.isSensitive && p.isGranted).length;

  bool isModuleGranted(UserRole role, String moduleKeyOrName, {bool defaultIfMissing = false}) {
    if (role == UserRole.owner) return true;
    final perms = role == UserRole.manager ? managerPermissions : cashierPermissions;
    if (perms.isEmpty) return defaultIfMissing;

    final norm = moduleKeyOrName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Map any key or module name to canonical module slug
    String canonical = norm;
    if (norm.contains('pos') || norm.contains('billing')) {
      canonical = 'pos';
    } else if (norm.contains('table')) {
      canonical = 'tables';
    } else if (norm.contains('takeaway')) {
      canonical = 'takeaway';
    } else if (norm.contains('delivery')) {
      canonical = 'delivery';
    } else if (norm.contains('online')) {
      canonical = 'online_orders';
    } else if (norm.contains('daily') || norm.contains('calculation')) {
      canonical = 'daily_calculation';
    } else if (norm.contains('menu')) {
      canonical = 'menu';
    } else if (norm.contains('inout')) {
      canonical = 'stock_in_out';
    } else if (norm.contains('stock')) {
      canonical = 'stock';
    } else if (norm.contains('user') || norm.contains('staff')) {
      canonical = 'users';
    } else if (norm.contains('expense')) {
      canonical = 'expenses';
    } else if (norm.contains('report')) {
      canonical = 'reports';
    } else if (norm.contains('sync')) {
      canonical = 'data_sync';
    }

    // 1. Direct match on root module permission (csh_mod_* or mgr_mod_*)
    final modPerm = perms.firstWhere(
      (p) {
        final pid = p.id.toLowerCase();
        final pNorm = p.moduleName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final isAllowAccess = p.actionName.toLowerCase().contains('allow access');

        if (canonical == 'pos') {
          return pid == 'csh_mod_pos' || pid == 'mgr_mod_pos' || (isAllowAccess && pNorm.contains('pos'));
        } else if (canonical == 'tables') {
          return pid == 'csh_mod_tables' || pid == 'mgr_mod_tables' || (isAllowAccess && pNorm.contains('table'));
        } else if (canonical == 'takeaway') {
          return pid == 'csh_mod_takeaway' || pid == 'mgr_mod_takeaway' || (isAllowAccess && pNorm.contains('takeaway'));
        } else if (canonical == 'delivery') {
          return pid == 'csh_mod_delivery' || pid == 'mgr_mod_delivery' || (isAllowAccess && pNorm.contains('delivery'));
        } else if (canonical == 'online_orders') {
          return pid == 'csh_mod_online_orders' || pid == 'mgr_mod_online_orders' || (isAllowAccess && pNorm.contains('online'));
        } else if (canonical == 'daily_calculation') {
          return pid == 'csh_mod_daily_calculation' || pid == 'mgr_mod_daily_calculation' || (isAllowAccess && pNorm.contains('calculation'));
        } else if (canonical == 'menu') {
          return pid == 'csh_mod_menu' || pid == 'mgr_mod_menu' || (isAllowAccess && pNorm.contains('menu'));
        } else if (canonical == 'stock_in_out') {
          return pid == 'csh_mod_stock_in_out' || pid == 'mgr_mod_stock_in_out' || (isAllowAccess && pNorm.contains('inout'));
        } else if (canonical == 'stock') {
          return pid == 'csh_mod_stock' || pid == 'mgr_mod_stock' || (isAllowAccess && pNorm.contains('stock') && !pNorm.contains('inout'));
        } else if (canonical == 'users') {
          return pid == 'csh_mod_users' || pid == 'mgr_mod_users' || (isAllowAccess && (pNorm.contains('user') || pNorm.contains('staff')));
        } else if (canonical == 'expenses') {
          return pid == 'csh_mod_expenses' || pid == 'mgr_mod_expenses' || (isAllowAccess && pNorm.contains('expense'));
        } else if (canonical == 'reports') {
          return pid == 'csh_mod_reports' || pid == 'mgr_mod_reports' || (isAllowAccess && pNorm.contains('report'));
        } else if (canonical == 'data_sync') {
          return pid == 'csh_mod_data_sync' || pid == 'mgr_mod_data_sync' || (isAllowAccess && pNorm.contains('sync'));
        }

        return pid.contains(canonical);
      },
      orElse: () => const ModulePermission(
        id: '',
        moduleName: '',
        actionName: '',
        description: '',
        isGranted: false,
      ),
    );

    if (modPerm.id.isNotEmpty) {
      return modPerm.isGranted;
    }

    return defaultIfMissing;
  }

  bool isActionGranted(UserRole role, String actionKeyOrName, {bool defaultIfMissing = false}) {
    if (role == UserRole.owner) return true;
    final perms = role == UserRole.manager ? managerPermissions : cashierPermissions;
    if (perms.isEmpty) return defaultIfMissing;

    final cleanKey = actionKeyOrName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final match = perms.firstWhere(
      (p) {
        final pid = p.id.toLowerCase();
        final pAct = p.actionName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        return pid == cleanKey ||
            pid == 'csh_$cleanKey' ||
            pid == 'mgr_$cleanKey' ||
            pid.endsWith('_$cleanKey') ||
            pAct == cleanKey ||
            pAct.contains(cleanKey) ||
            cleanKey.contains(pAct);
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

    return defaultIfMissing;
  }

  RoleRightsState copyWith({
    UserRole? selectedRole,
    List<ModulePermission>? managerPermissions,
    List<ModulePermission>? cashierPermissions,
    bool? isLoading,
  }) {
    return RoleRightsState(
      selectedRole: selectedRole ?? this.selectedRole,
      managerPermissions: managerPermissions ?? this.managerPermissions,
      cashierPermissions: cashierPermissions ?? this.cashierPermissions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RoleRightsNotifier extends StateNotifier<RoleRightsState> {
  final PermissionsApiService _permissionsApiService;

  RoleRightsNotifier({PermissionsApiService? permissionsApiService})
      : _permissionsApiService = permissionsApiService ?? PermissionsApiService(),
        super(RoleRightsState(
          selectedRole: UserRole.manager,
          managerPermissions: _getInitialManagerPermissions(),
          cashierPermissions: _getInitialCashierPermissions(),
        ));

  Future<void> loadPermissions() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      // 1. Manager permissions
      final managerJson = await _permissionsApiService.getPermissionsByRole('Manager');
      if (!mounted) return;
      List<ModulePermission> mgr = [];
      if (managerJson.isNotEmpty) {
        final fetched = managerJson.map((j) => ModulePermission.fromBackendJson(j)).toList();
        final fetchedIds = fetched.map((p) => p.id).toSet();
        mgr = [
          ...fetched,
          ..._getInitialManagerPermissions().where((p) => !fetchedIds.contains(p.id)),
        ];
      } else {
        mgr = state.managerPermissions;
      }

      // 2. Cashier permissions
      final cashierJson = await _permissionsApiService.getPermissionsByRole('Cashier');
      if (!mounted) return;
      List<ModulePermission> csh = [];
      if (cashierJson.isNotEmpty) {
        final fetched = cashierJson.map((j) => ModulePermission.fromBackendJson(j)).toList();
        final fetchedIds = fetched.map((p) => p.id).toSet();
        csh = [
          ...fetched,
          ..._getInitialCashierPermissions().where((p) => !fetchedIds.contains(p.id)),
        ];
      } else {
        csh = state.cashierPermissions;
      }

      if (!mounted) return;
      state = state.copyWith(
        managerPermissions: mgr,
        cashierPermissions: csh,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  void selectRole(UserRole role) {
    if (!mounted) return;
    state = state.copyWith(selectedRole: role);
  }

  Future<void> togglePermission(String permissionId) async {
    bool? backendGranted;
    try {
      final res = await _permissionsApiService.togglePermission(permissionId);
      if (res['is_granted'] is bool) {
        backendGranted = res['is_granted'] as bool;
      }
    } catch (_) {}

    if (!mounted) return;

    final updatedMgr = state.managerPermissions.map((p) {
      if (p.id == permissionId) {
        return p.copyWith(isGranted: backendGranted ?? !p.isGranted);
      }
      return p;
    }).toList();

    final updatedCsh = state.cashierPermissions.map((p) {
      if (p.id == permissionId) {
        return p.copyWith(isGranted: backendGranted ?? !p.isGranted);
      }
      return p;
    }).toList();

    state = state.copyWith(
      managerPermissions: updatedMgr,
      cashierPermissions: updatedCsh,
    );
  }

  Future<void> applyPreset(String presetType) async {
    if (!mounted) return;
    final roleName = state.selectedRole == UserRole.manager ? 'Manager' : 'Cashier';
    try {
      final result = await _permissionsApiService.applyPreset(role: roleName, preset: presetType);
      if (!mounted) return;
      if (result.isNotEmpty) {
        final perms = result.map((j) => ModulePermission.fromBackendJson(j)).toList();
        _setUpdated(perms);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    if (presetType == 'STRICT') {
      final updated = state.currentPermissions.map((p) {
        if (p.isSensitive) return p.copyWith(isGranted: false);
        return p;
      }).toList();
      _setUpdated(updated);
    } else if (presetType == 'FULL') {
      final updated = state.currentPermissions.map((p) => p.copyWith(isGranted: true)).toList();
      _setUpdated(updated);
    } else if (presetType == 'DEFAULT') {
      if (state.selectedRole == UserRole.manager) {
        state = state.copyWith(managerPermissions: _getInitialManagerPermissions());
      } else {
        state = state.copyWith(cashierPermissions: _getInitialCashierPermissions());
      }
    }
  }

  void _setUpdated(List<ModulePermission> updated) {
    if (!mounted) return;
    if (state.selectedRole == UserRole.manager) {
      state = state.copyWith(managerPermissions: updated);
    } else {
      state = state.copyWith(cashierPermissions: updated);
    }
  }

  static List<ModulePermission> _getInitialManagerPermissions() {
    return const [
      ModulePermission(id: 'mgr_mod_pos', moduleName: 'POS Billing', actionName: 'Allow Access to POS Sales', description: 'Access POS terminal and billing', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_online_orders', moduleName: 'Online Orders', actionName: 'Allow Access to Online Orders', description: 'View online orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_online_orders_accept', moduleName: 'Online Orders', actionName: 'Accept/Reject Orders', description: 'Accept or reject customer orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_takeaway', moduleName: 'Takeaway Counter', actionName: 'Allow Access to Takeaway', description: 'View takeaway orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_takeaway_create', moduleName: 'Takeaway Counter', actionName: 'Create Takeaway Orders', description: 'Punch new takeaway orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_delivery', moduleName: 'Delivery Tracking', actionName: 'Allow Access to Delivery', description: 'View delivery tracking', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_del_assign', moduleName: 'Delivery Tracking', actionName: 'Assign Riders', description: 'Assign riders to orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_stock_in_out', moduleName: 'Stock In / Out', actionName: 'Allow Access to Stock In / Out', description: 'View stock transactions', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_stock_in_action', moduleName: 'Stock In / Out', actionName: 'Perform Stock In', description: 'Add inward stock', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_stock_out_action', moduleName: 'Stock In / Out', actionName: 'Perform Stock Out', description: 'Record wastage or out', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_reports', moduleName: 'Reports', actionName: 'Allow Access to Reports', description: 'View reports', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_rep_export', moduleName: 'Reports', actionName: 'Export Reports', description: 'Export PDF & Excel', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_tables', moduleName: 'Tables', actionName: 'Allow Access to Tables', description: 'View operations for Tables', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_tables_add', moduleName: 'Tables', actionName: 'Add Tables', description: 'Add operations for Tables', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_tables_edit', moduleName: 'Tables', actionName: 'Edit Tables', description: 'Edit operations for Tables', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_tables_delete', moduleName: 'Tables', actionName: 'Delete Tables', description: 'Delete operations for Tables', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_mod_menu', moduleName: 'Menu Catalog', actionName: 'Allow Access to Menu Catalog', description: 'View operations for Menu Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_menu_add', moduleName: 'Menu Catalog', actionName: 'Add Menu Catalog', description: 'Add operations for Menu Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_menu_edit', moduleName: 'Menu Catalog', actionName: 'Edit Menu Catalog', description: 'Edit operations for Menu Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_menu_delete', moduleName: 'Menu Catalog', actionName: 'Delete Menu Catalog', description: 'Delete operations for Menu Catalog', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_mod_stock', moduleName: 'Stock Catalog', actionName: 'Allow Access to Stock Catalog', description: 'View operations for Stock Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_stock_add', moduleName: 'Stock Catalog', actionName: 'Add Stock Catalog', description: 'Add operations for Stock Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_stock_edit', moduleName: 'Stock Catalog', actionName: 'Edit Stock Catalog', description: 'Edit operations for Stock Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_stock_delete', moduleName: 'Stock Catalog', actionName: 'Delete Stock Catalog', description: 'Delete operations for Stock Catalog', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_mod_users', moduleName: 'Users', actionName: 'Allow Access to Users', description: 'View operations for Users', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_users_add', moduleName: 'Users', actionName: 'Add Users', description: 'Add operations for Users', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_users_edit', moduleName: 'Users', actionName: 'Edit Users', description: 'Edit operations for Users', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_users_delete', moduleName: 'Users', actionName: 'Delete Users', description: 'Delete operations for Users', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_users_salary_disburse', moduleName: 'Users', actionName: 'Mark Salary Paid', description: 'Disburse payroll', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_mod_expenses', moduleName: 'Expenses', actionName: 'Allow Access to Expenses', description: 'View operations for Expenses', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_expenses_add', moduleName: 'Expenses', actionName: 'Add Expenses', description: 'Add operations for Expenses', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_expenses_edit', moduleName: 'Expenses', actionName: 'Edit Expenses', description: 'Edit operations for Expenses', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_expenses_delete', moduleName: 'Expenses', actionName: 'Delete Expenses', description: 'Delete operations for Expenses', isGranted: true, isSensitive: true),
      ModulePermission(id: 'mgr_mod_daily_calculation', moduleName: 'Daily Calculation', actionName: 'Allow Access to Daily Calculation', description: 'View & Audit Daily Calculations', isGranted: true, isSensitive: false),
      ModulePermission(id: 'mgr_mod_data_sync', moduleName: 'Data Sync', actionName: 'Allow Access to Data Sync', description: 'View & Manage SQLite/Cloud Data Synchronization', isGranted: true, isSensitive: false),
    ];
  }

  static List<ModulePermission> _getInitialCashierPermissions() {
    return const [
      ModulePermission(id: 'csh_mod_daily_calculation', moduleName: 'Daily Calculation', actionName: 'Allow Access to Daily Calculation', description: 'Submit Day Settlement & Reset Portal', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_mod_data_sync', moduleName: 'Data Sync', actionName: 'Allow Access to Data Sync', description: 'View & Manage SQLite/Cloud Data Synchronization', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_mod_pos', moduleName: 'POS Billing', actionName: 'Allow Access to POS Sales', description: 'Access POS terminal and billing', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_mod_online_orders', moduleName: 'Online Orders', actionName: 'Allow Access to Online Orders', description: 'View online orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_online_orders_accept', moduleName: 'Online Orders', actionName: 'Accept/Reject Orders', description: 'Accept or reject customer orders', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_mod_takeaway', moduleName: 'Takeaway Counter', actionName: 'Allow Access to Takeaway', description: 'View takeaway orders', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_takeaway_create', moduleName: 'Takeaway Counter', actionName: 'Create Takeaway Orders', description: 'Punch new takeaway orders', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_mod_delivery', moduleName: 'Delivery Tracking', actionName: 'Allow Access to Delivery', description: 'View delivery tracking', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_del_assign', moduleName: 'Delivery Tracking', actionName: 'Assign Riders', description: 'Assign riders to orders', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_mod_stock_in_out', moduleName: 'Stock In / Out', actionName: 'Allow Access to Stock In / Out', description: 'View stock transactions', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_stock_in_action', moduleName: 'Stock In / Out', actionName: 'Perform Stock In', description: 'Add inward stock', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_stock_out_action', moduleName: 'Stock In / Out', actionName: 'Perform Stock Out', description: 'Record wastage or out', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_mod_reports', moduleName: 'Reports', actionName: 'Allow Access to Reports', description: 'View reports', isGranted: true, isSensitive: true),
      ModulePermission(id: 'csh_rep_export', moduleName: 'Reports', actionName: 'Export Reports', description: 'Export PDF & Excel', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_mod_tables', moduleName: 'Tables', actionName: 'Allow Access to Tables', description: 'View operations for Tables', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_tables_add', moduleName: 'Tables', actionName: 'Add Tables', description: 'Add operations for Tables', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_tables_edit', moduleName: 'Tables', actionName: 'Edit Tables', description: 'Edit operations for Tables', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_tables_delete', moduleName: 'Tables', actionName: 'Delete Tables', description: 'Delete operations for Tables', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_mod_menu', moduleName: 'Menu Catalog', actionName: 'Allow Access to Menu Catalog', description: 'View operations for Menu Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_menu_add', moduleName: 'Menu Catalog', actionName: 'Add Menu Catalog', description: 'Add operations for Menu Catalog', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_menu_edit', moduleName: 'Menu Catalog', actionName: 'Edit Menu Catalog', description: 'Edit operations for Menu Catalog', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_menu_delete', moduleName: 'Menu Catalog', actionName: 'Delete Menu Catalog', description: 'Delete operations for Menu Catalog', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_mod_stock', moduleName: 'Stock Catalog', actionName: 'Allow Access to Stock Catalog', description: 'View operations for Stock Catalog', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_stock_add', moduleName: 'Stock Catalog', actionName: 'Add Stock Catalog', description: 'Add operations for Stock Catalog', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_stock_edit', moduleName: 'Stock Catalog', actionName: 'Edit Stock Catalog', description: 'Edit operations for Stock Catalog', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_stock_delete', moduleName: 'Stock Catalog', actionName: 'Delete Stock Catalog', description: 'Delete operations for Stock Catalog', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_mod_users', moduleName: 'Users', actionName: 'Allow Access to Users', description: 'View operations for Users', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_users_add', moduleName: 'Users', actionName: 'Add Users', description: 'Add operations for Users', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_users_edit', moduleName: 'Users', actionName: 'Edit Users', description: 'Edit operations for Users', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_users_delete', moduleName: 'Users', actionName: 'Delete Users', description: 'Delete operations for Users', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_users_salary_disburse', moduleName: 'Users', actionName: 'Mark Salary Paid', description: 'Disburse payroll', isGranted: false, isSensitive: true),
      ModulePermission(id: 'csh_mod_expenses', moduleName: 'Expenses', actionName: 'Allow Access to Expenses', description: 'View operations for Expenses', isGranted: true, isSensitive: false),
      ModulePermission(id: 'csh_expenses_add', moduleName: 'Expenses', actionName: 'Add Expenses', description: 'Add operations for Expenses', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_expenses_edit', moduleName: 'Expenses', actionName: 'Edit Expenses', description: 'Edit operations for Expenses', isGranted: false, isSensitive: false),
      ModulePermission(id: 'csh_expenses_delete', moduleName: 'Expenses', actionName: 'Delete Expenses', description: 'Delete operations for Expenses', isGranted: false, isSensitive: true),
    ];
  }
}

final roleRightsProvider = StateNotifierProvider<RoleRightsNotifier, RoleRightsState>((ref) {
  final permsApi = ref.watch(permissionsApiServiceProvider);
  final authState = ref.watch(authProvider);
  final notifier = RoleRightsNotifier(permissionsApiService: permsApi);
  if (authState.isAuthenticated) {
    notifier.loadPermissions();
  }
  return notifier;
});
