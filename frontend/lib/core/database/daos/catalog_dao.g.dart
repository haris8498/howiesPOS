// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalMenuCategoriesTable get localMenuCategories =>
      attachedDatabase.localMenuCategories;
  $LocalMenuItemsTable get localMenuItems => attachedDatabase.localMenuItems;
  $LocalMenuItemSizesTable get localMenuItemSizes =>
      attachedDatabase.localMenuItemSizes;
  $LocalMenuItemOptionsTable get localMenuItemOptions =>
      attachedDatabase.localMenuItemOptions;
  $LocalDealsTable get localDeals => attachedDatabase.localDeals;
  $LocalDealComponentsTable get localDealComponents =>
      attachedDatabase.localDealComponents;
  $LocalRestaurantTablesTable get localRestaurantTables =>
      attachedDatabase.localRestaurantTables;
  $LocalFloorZonesTable get localFloorZones => attachedDatabase.localFloorZones;
  $LocalStaffUsersTable get localStaffUsers => attachedDatabase.localStaffUsers;
  $LocalRolePermissionsTable get localRolePermissions =>
      attachedDatabase.localRolePermissions;
  $LocalStoreSettingsTable get localStoreSettings =>
      attachedDatabase.localStoreSettings;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$LocalMenuCategoriesTableTableManager get localMenuCategories =>
      $$LocalMenuCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.localMenuCategories,
      );
  $$LocalMenuItemsTableTableManager get localMenuItems =>
      $$LocalMenuItemsTableTableManager(
        _db.attachedDatabase,
        _db.localMenuItems,
      );
  $$LocalMenuItemSizesTableTableManager get localMenuItemSizes =>
      $$LocalMenuItemSizesTableTableManager(
        _db.attachedDatabase,
        _db.localMenuItemSizes,
      );
  $$LocalMenuItemOptionsTableTableManager get localMenuItemOptions =>
      $$LocalMenuItemOptionsTableTableManager(
        _db.attachedDatabase,
        _db.localMenuItemOptions,
      );
  $$LocalDealsTableTableManager get localDeals =>
      $$LocalDealsTableTableManager(_db.attachedDatabase, _db.localDeals);
  $$LocalDealComponentsTableTableManager get localDealComponents =>
      $$LocalDealComponentsTableTableManager(
        _db.attachedDatabase,
        _db.localDealComponents,
      );
  $$LocalRestaurantTablesTableTableManager get localRestaurantTables =>
      $$LocalRestaurantTablesTableTableManager(
        _db.attachedDatabase,
        _db.localRestaurantTables,
      );
  $$LocalFloorZonesTableTableManager get localFloorZones =>
      $$LocalFloorZonesTableTableManager(
        _db.attachedDatabase,
        _db.localFloorZones,
      );
  $$LocalStaffUsersTableTableManager get localStaffUsers =>
      $$LocalStaffUsersTableTableManager(
        _db.attachedDatabase,
        _db.localStaffUsers,
      );
  $$LocalRolePermissionsTableTableManager get localRolePermissions =>
      $$LocalRolePermissionsTableTableManager(
        _db.attachedDatabase,
        _db.localRolePermissions,
      );
  $$LocalStoreSettingsTableTableManager get localStoreSettings =>
      $$LocalStoreSettingsTableTableManager(
        _db.attachedDatabase,
        _db.localStoreSettings,
      );
}
