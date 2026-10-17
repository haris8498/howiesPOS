enum UserRole {
  owner,
  manager,
  cashier,
}

extension UserRoleX on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Chain Owner';
      case UserRole.manager:
        return 'Store Manager';
      case UserRole.cashier:
        return 'Sales Person (Cashier)';
    }
  }

  // --- Owner Permissions (Full Access) ---
  bool canAccessFullAnalytics() => this == UserRole.owner;
  bool canAccessSettings() => this == UserRole.owner;
  bool canManageUserRoles() => this == UserRole.owner;
  bool canDeleteFinancialRecords() => this == UserRole.owner;
  bool canDeleteHistoricalSales() => this == UserRole.owner;

  // --- Manager Permissions ---
  bool canAccessReports() => this == UserRole.owner || this == UserRole.manager;
  bool canManageInventory() => this == UserRole.owner || this == UserRole.manager;
  bool canManageMenu() => this == UserRole.owner || this == UserRole.manager;
  bool canAccessStaff() => this == UserRole.owner || this == UserRole.manager;
  bool canAccessExpenses() => this == UserRole.owner || this == UserRole.manager;

  // --- Cashier Permissions (POS Only) ---
  bool canCreateOrders() => true;
  bool canProcessPayments() => true;
  bool canAccessFloorPlan() => true;
  bool canAccessKitchenView() => this == UserRole.owner || this == UserRole.manager || this == UserRole.cashier;
}
