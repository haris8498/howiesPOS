/// Production SQLite Database Schema Mapping definitions for Enterprise POS
class DatabaseSchema {
  DatabaseSchema._();

  static const String tableUsers = 'users';
  static const String tableRoles = 'roles';
  static const String tablePermissions = 'permissions';
  static const String tableRolePermissions = 'role_permissions';
  static const String tableTables = 'tables';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableProducts = 'products';
  static const String tableCategories = 'categories';
  static const String tableInventory = 'inventory';
  static const String tableInventoryTransactions = 'inventory_transactions';
  static const String tableSuppliers = 'suppliers';
  static const String tablePurchases = 'purchases';
  static const String tableExpenses = 'expenses';
  static const String tableCustomers = 'customers';
  static const String tablePayments = 'payments';
  static const String tableKitchenOrders = 'kitchen_orders';
  static const String tableSettings = 'settings';

  static const List<String> createTableQueries = [
    '''
    CREATE TABLE IF NOT EXISTS $tableUsers (
      id TEXT PRIMARY KEY,
      fullName TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      role TEXT NOT NULL,
      isClockedIn INTEGER NOT NULL,
      hourlyRate REAL NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableProducts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      basePrice REAL NOT NULL,
      imageUrl TEXT NOT NULL,
      isVeg INTEGER NOT NULL,
      isSpicy INTEGER NOT NULL,
      isAvailable INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableInventory (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      currentStock REAL NOT NULL,
      minThreshold REAL NOT NULL,
      unit TEXT NOT NULL,
      costPerUnit REAL NOT NULL,
      supplierName TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $tableOrders (
      id TEXT PRIMARY KEY,
      orderNumber TEXT NOT NULL,
      tableNumber TEXT,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      grandTotal REAL NOT NULL,
      cashierName TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
    ''',
  ];
}
