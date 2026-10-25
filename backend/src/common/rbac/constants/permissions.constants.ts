export const PERMISSIONS_METADATA_KEY = 'permissions';

export interface DefaultPermissionDefinition {
  id: string;
  role: 'manager' | 'cashier';
  module_name: string;
  action_name: string;
  description: string;
  is_granted: boolean;
  is_sensitive: boolean;
}

export const INITIAL_MANAGER_PERMISSIONS: DefaultPermissionDefinition[] = [
  { id: 'mgr_mod_online_orders', role: 'manager', module_name: 'Online Orders', action_name: 'Allow Access to Online Orders', description: 'View online orders', is_granted: true, is_sensitive: false },
  { id: 'mgr_online_orders_accept', role: 'manager', module_name: 'Online Orders', action_name: 'Accept/Reject Orders', description: 'Accept or reject customer orders', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_takeaway', role: 'manager', module_name: 'Takeaway Counter', action_name: 'Allow Access to Takeaway', description: 'View takeaway orders', is_granted: true, is_sensitive: false },
  { id: 'mgr_takeaway_create', role: 'manager', module_name: 'Takeaway Counter', action_name: 'Create Takeaway Orders', description: 'Punch new takeaway orders', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_delivery', role: 'manager', module_name: 'Delivery Tracking', action_name: 'Allow Access to Delivery', description: 'View delivery tracking', is_granted: true, is_sensitive: false },
  { id: 'mgr_del_assign', role: 'manager', module_name: 'Delivery Tracking', action_name: 'Assign Riders', description: 'Assign riders to orders', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_stock_in_out', role: 'manager', module_name: 'Stock In / Out', action_name: 'Allow Access to Stock In / Out', description: 'View stock transactions', is_granted: true, is_sensitive: false },
  { id: 'mgr_stock_in_action', role: 'manager', module_name: 'Stock In / Out', action_name: 'Perform Stock In', description: 'Add inward stock', is_granted: true, is_sensitive: false },
  { id: 'mgr_stock_out_action', role: 'manager', module_name: 'Stock In / Out', action_name: 'Perform Stock Out', description: 'Record wastage or out', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_reports', role: 'manager', module_name: 'Reports', action_name: 'Allow Access to Reports', description: 'View reports', is_granted: true, is_sensitive: true },
  { id: 'mgr_rep_export', role: 'manager', module_name: 'Reports', action_name: 'Export Reports', description: 'Export PDF & Excel', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_tables', role: 'manager', module_name: 'Tables', action_name: 'Allow Access to Tables', description: 'View operations for Tables', is_granted: true, is_sensitive: false },
  { id: 'mgr_tables_add', role: 'manager', module_name: 'Tables', action_name: 'Add Tables', description: 'Add operations for Tables', is_granted: true, is_sensitive: false },
  { id: 'mgr_tables_edit', role: 'manager', module_name: 'Tables', action_name: 'Edit Tables', description: 'Edit operations for Tables', is_granted: true, is_sensitive: false },
  { id: 'mgr_tables_delete', role: 'manager', module_name: 'Tables', action_name: 'Delete Tables', description: 'Delete operations for Tables', is_granted: true, is_sensitive: true },
  { id: 'mgr_mod_menu', role: 'manager', module_name: 'Menu Catalog', action_name: 'Allow Access to Menu Catalog', description: 'View operations for Menu Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_menu_add', role: 'manager', module_name: 'Menu Catalog', action_name: 'Add Menu Catalog', description: 'Add operations for Menu Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_menu_edit', role: 'manager', module_name: 'Menu Catalog', action_name: 'Edit Menu Catalog', description: 'Edit operations for Menu Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_menu_delete', role: 'manager', module_name: 'Menu Catalog', action_name: 'Delete Menu Catalog', description: 'Delete operations for Menu Catalog', is_granted: true, is_sensitive: true },
  { id: 'mgr_mod_stock', role: 'manager', module_name: 'Stock Catalog', action_name: 'Allow Access to Stock Catalog', description: 'View operations for Stock Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_stock_add', role: 'manager', module_name: 'Stock Catalog', action_name: 'Add Stock Catalog', description: 'Add operations for Stock Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_stock_edit', role: 'manager', module_name: 'Stock Catalog', action_name: 'Edit Stock Catalog', description: 'Edit operations for Stock Catalog', is_granted: true, is_sensitive: false },
  { id: 'mgr_stock_delete', role: 'manager', module_name: 'Stock Catalog', action_name: 'Delete Stock Catalog', description: 'Delete operations for Stock Catalog', is_granted: true, is_sensitive: true },
  { id: 'mgr_mod_users', role: 'manager', module_name: 'Users', action_name: 'Allow Access to Users', description: 'View operations for Users', is_granted: true, is_sensitive: false },
  { id: 'mgr_users_add', role: 'manager', module_name: 'Users', action_name: 'Add Users', description: 'Add operations for Users', is_granted: true, is_sensitive: false },
  { id: 'mgr_users_edit', role: 'manager', module_name: 'Users', action_name: 'Edit Users', description: 'Edit operations for Users', is_granted: true, is_sensitive: true },
  { id: 'mgr_users_delete', role: 'manager', module_name: 'Users', action_name: 'Delete Users', description: 'Delete operations for Users', is_granted: true, is_sensitive: true },
  { id: 'mgr_users_salary_disburse', role: 'manager', module_name: 'Users', action_name: 'Mark Salary Paid', description: 'Disburse payroll', is_granted: true, is_sensitive: true },
  { id: 'mgr_mod_expenses', role: 'manager', module_name: 'Expenses', action_name: 'Allow Access to Expenses', description: 'View operations for Expenses', is_granted: true, is_sensitive: false },
  { id: 'mgr_expenses_add', role: 'manager', module_name: 'Expenses', action_name: 'Add Expenses', description: 'Add operations for Expenses', is_granted: true, is_sensitive: false },
  { id: 'mgr_expenses_edit', role: 'manager', module_name: 'Expenses', action_name: 'Edit Expenses', description: 'Edit operations for Expenses', is_granted: true, is_sensitive: false },
  { id: 'mgr_expenses_delete', role: 'manager', module_name: 'Expenses', action_name: 'Delete Expenses', description: 'Delete operations for Expenses', is_granted: true, is_sensitive: true },
  { id: 'mgr_mod_daily_calculation', role: 'manager', module_name: 'Daily Calculation', action_name: 'Allow Access to Daily Calculation', description: 'View & Audit Daily Calculations', is_granted: true, is_sensitive: false },
  { id: 'mgr_mod_data_sync', role: 'manager', module_name: 'Data Sync', action_name: 'Allow Access to Data Sync', description: 'View & Manage SQLite/Cloud Data Synchronization', is_granted: true, is_sensitive: false },
];

export const INITIAL_CASHIER_PERMISSIONS: DefaultPermissionDefinition[] = [
  { id: 'csh_mod_daily_calculation', role: 'cashier', module_name: 'Daily Calculation', action_name: 'Allow Access to Daily Calculation', description: 'Submit Day Settlement & Reset Portal', is_granted: true, is_sensitive: false },
  { id: 'csh_mod_online_orders', role: 'cashier', module_name: 'Online Orders', action_name: 'Allow Access to Online Orders', description: 'View online orders', is_granted: true, is_sensitive: false },
  { id: 'csh_online_orders_accept', role: 'cashier', module_name: 'Online Orders', action_name: 'Accept/Reject Orders', description: 'Accept or reject customer orders', is_granted: false, is_sensitive: false },
  { id: 'csh_mod_takeaway', role: 'cashier', module_name: 'Takeaway Counter', action_name: 'Allow Access to Takeaway', description: 'View takeaway orders', is_granted: true, is_sensitive: false },
  { id: 'csh_takeaway_create', role: 'cashier', module_name: 'Takeaway Counter', action_name: 'Create Takeaway Orders', description: 'Punch new takeaway orders', is_granted: false, is_sensitive: false },
  { id: 'csh_mod_delivery', role: 'cashier', module_name: 'Delivery Tracking', action_name: 'Allow Access to Delivery', description: 'View delivery tracking', is_granted: true, is_sensitive: false },
  { id: 'csh_del_assign', role: 'cashier', module_name: 'Delivery Tracking', action_name: 'Assign Riders', description: 'Assign riders to orders', is_granted: false, is_sensitive: false },
  { id: 'csh_mod_stock_in_out', role: 'cashier', module_name: 'Stock In / Out', action_name: 'Allow Access to Stock In / Out', description: 'View stock transactions', is_granted: false, is_sensitive: false },
  { id: 'csh_stock_in_action', role: 'cashier', module_name: 'Stock In / Out', action_name: 'Perform Stock In', description: 'Add inward stock', is_granted: false, is_sensitive: false },
  { id: 'csh_stock_out_action', role: 'cashier', module_name: 'Stock In / Out', action_name: 'Perform Stock Out', description: 'Record wastage or out', is_granted: false, is_sensitive: false },
  { id: 'csh_mod_reports', role: 'cashier', module_name: 'Reports', action_name: 'Allow Access to Reports', description: 'View reports', is_granted: true, is_sensitive: true },
  { id: 'csh_rep_export', role: 'cashier', module_name: 'Reports', action_name: 'Export Reports', description: 'Export PDF & Excel', is_granted: false, is_sensitive: false },
  { id: 'csh_mod_tables', role: 'cashier', module_name: 'Tables', action_name: 'Allow Access to Tables', description: 'View operations for Tables', is_granted: true, is_sensitive: false },
  { id: 'csh_tables_add', role: 'cashier', module_name: 'Tables', action_name: 'Add Tables', description: 'Add operations for Tables', is_granted: false, is_sensitive: false },
  { id: 'csh_tables_edit', role: 'cashier', module_name: 'Tables', action_name: 'Edit Tables', description: 'Edit operations for Tables', is_granted: false, is_sensitive: false },
  { id: 'csh_tables_delete', role: 'cashier', module_name: 'Tables', action_name: 'Delete Tables', description: 'Delete operations for Tables', is_granted: false, is_sensitive: true },
  { id: 'csh_mod_menu', role: 'cashier', module_name: 'Menu Catalog', action_name: 'Allow Access to Menu Catalog', description: 'View operations for Menu Catalog', is_granted: true, is_sensitive: false },
  { id: 'csh_menu_add', role: 'cashier', module_name: 'Menu Catalog', action_name: 'Add Menu Catalog', description: 'Add operations for Menu Catalog', is_granted: false, is_sensitive: false },
  { id: 'csh_menu_edit', role: 'cashier', module_name: 'Menu Catalog', action_name: 'Edit Menu Catalog', description: 'Edit operations for Menu Catalog', is_granted: false, is_sensitive: false },
  { id: 'csh_menu_delete', role: 'cashier', module_name: 'Menu Catalog', action_name: 'Delete Menu Catalog', description: 'Delete operations for Menu Catalog', is_granted: false, is_sensitive: true },
  { id: 'csh_mod_stock', role: 'cashier', module_name: 'Stock Catalog', action_name: 'Allow Access to Stock Catalog', description: 'View operations for Stock Catalog', is_granted: false, is_sensitive: false },
  { id: 'csh_stock_add', role: 'cashier', module_name: 'Stock Catalog', action_name: 'Add Stock Catalog', description: 'Add operations for Stock Catalog', is_granted: false, is_sensitive: false },
  { id: 'csh_stock_edit', role: 'cashier', module_name: 'Stock Catalog', action_name: 'Edit Stock Catalog', description: 'Edit operations for Stock Catalog', is_granted: false, is_sensitive: false },
  { id: 'csh_stock_delete', role: 'cashier', module_name: 'Stock Catalog', action_name: 'Delete Stock Catalog', description: 'Delete operations for Stock Catalog', is_granted: false, is_sensitive: true },
  { id: 'csh_mod_users', role: 'cashier', module_name: 'Users', action_name: 'Allow Access to Users', description: 'View operations for Users', is_granted: false, is_sensitive: false },
  { id: 'csh_users_add', role: 'cashier', module_name: 'Users', action_name: 'Add Users', description: 'Add operations for Users', is_granted: false, is_sensitive: false },
  { id: 'csh_users_edit', role: 'cashier', module_name: 'Users', action_name: 'Edit Users', description: 'Edit operations for Users', is_granted: false, is_sensitive: true },
  { id: 'csh_users_delete', role: 'cashier', module_name: 'Users', action_name: 'Delete Users', description: 'Delete operations for Users', is_granted: false, is_sensitive: true },
  { id: 'csh_users_salary_disburse', role: 'cashier', module_name: 'Users', action_name: 'Mark Salary Paid', description: 'Disburse payroll', is_granted: false, is_sensitive: true },
  { id: 'csh_mod_expenses', role: 'cashier', module_name: 'Expenses', action_name: 'Allow Access to Expenses', description: 'View operations for Expenses', is_granted: false, is_sensitive: false },
  { id: 'csh_expenses_add', role: 'cashier', module_name: 'Expenses', action_name: 'Add Expenses', description: 'Add operations for Expenses', is_granted: false, is_sensitive: false },
  { id: 'csh_expenses_edit', role: 'cashier', module_name: 'Expenses', action_name: 'Edit Expenses', description: 'Edit operations for Expenses', is_granted: false, is_sensitive: false },
  { id: 'csh_expenses_delete', role: 'cashier', module_name: 'Expenses', action_name: 'Delete Expenses', description: 'Delete operations for Expenses', is_granted: false, is_sensitive: true },
  { id: 'csh_mod_data_sync', role: 'cashier', module_name: 'Data Sync', action_name: 'Allow Access to Data Sync', description: 'View & Manage SQLite/Cloud Data Synchronization', is_granted: true, is_sensitive: false },
];

