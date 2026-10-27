import 'package:drift/drift.dart';

/// Replicated Catalog & Reference Tables per Architecture Spec §5.3.
/// Strictly pull-only on the client (Directive Q9.1).

@DataClassName('LocalMenuCategory')
class LocalMenuCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMenuItem')
class LocalMenuItems extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  RealColumn get basePrice => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isVeg => boolean().withDefault(const Constant(false))();
  BoolColumn get isSpicy => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMenuItemSize')
class LocalMenuItemSizes extends Table {
  TextColumn get id => text()();
  TextColumn get menuItemId => text().references(LocalMenuItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get sizeName => text()();
  RealColumn get priceMultiplier => real().withDefault(const Constant(1.0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalMenuItemOption')
class LocalMenuItemOptions extends Table {
  TextColumn get id => text()();
  TextColumn get menuItemId => text().references(LocalMenuItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get groupName => text()();
  TextColumn get optionName => text()();
  RealColumn get additionalPrice => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalDeal')
class LocalDeals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get dealPrice => real()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalDealComponent')
class LocalDealComponents extends Table {
  TextColumn get id => text()();
  TextColumn get dealId => text().references(LocalDeals, #id, onDelete: KeyAction.cascade)();
  TextColumn get menuItemId => text().nullable()();
  TextColumn get quantity => text().withDefault(const Constant('1'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalRestaurantTable')
class LocalRestaurantTables extends Table {
  TextColumn get id => text()();
  TextColumn get zoneId => text().nullable()();
  TextColumn get tableNumber => text()();
  TextColumn get name => text()();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(const Constant('available'))();
  TextColumn get activeOrderId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalFloorZone')
class LocalFloorZones extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalStaffUser')
class LocalStaffUsers extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get role => text()();
  TextColumn get pinHash => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalRolePermission')
class LocalRolePermissions extends Table {
  TextColumn get id => text()();
  TextColumn get role => text()();
  TextColumn get moduleName => text()();
  TextColumn get actionName => text()();
  BoolColumn get isGranted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalStoreSetting')
class LocalStoreSettings extends Table {
  TextColumn get id => text()();
  TextColumn get chainName => text()();
  TextColumn get branchCode => text()();
  TextColumn get branchName => text()();
  TextColumn get storePhone => text()();
  RealColumn get taxPercentage => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}
