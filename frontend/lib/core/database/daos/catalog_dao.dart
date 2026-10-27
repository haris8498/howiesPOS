import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/catalog_tables.dart';

part 'catalog_dao.g.dart';

@DriftAccessor(tables: [
  LocalMenuCategories,
  LocalMenuItems,
  LocalMenuItemSizes,
  LocalMenuItemOptions,
  LocalDeals,
  LocalDealComponents,
  LocalRestaurantTables,
  LocalFloorZones,
  LocalStaffUsers,
  LocalRolePermissions,
  LocalStoreSettings,
])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  // ----------------------------------------------------
  // Upsert Methods (Batch & Atomic)
  // ----------------------------------------------------

  Future<void> upsertMenuCategories(List<LocalMenuCategoriesCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localMenuCategories, entries));
  }

  Future<void> upsertMenuItems(List<LocalMenuItemsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localMenuItems, entries));
  }

  Future<void> upsertMenuItemSizes(List<LocalMenuItemSizesCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localMenuItemSizes, entries));
  }

  Future<void> upsertMenuItemOptions(List<LocalMenuItemOptionsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localMenuItemOptions, entries));
  }

  Future<void> upsertDeals(List<LocalDealsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localDeals, entries));
  }

  Future<void> upsertDealComponents(List<LocalDealComponentsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localDealComponents, entries));
  }

  Future<void> upsertRestaurantTables(List<LocalRestaurantTablesCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localRestaurantTables, entries));
  }

  Future<void> upsertFloorZones(List<LocalFloorZonesCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localFloorZones, entries));
  }

  Future<void> upsertStaffUsers(List<LocalStaffUsersCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localStaffUsers, entries));
  }

  Future<void> upsertRolePermissions(List<LocalRolePermissionsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(localRolePermissions, entries));
  }

  Future<void> upsertStoreSettings(LocalStoreSettingsCompanion entry) {
    return into(localStoreSettings).insertOnConflictUpdate(entry);
  }

  // ----------------------------------------------------
  // Query Methods
  // ----------------------------------------------------

  Future<List<LocalMenuCategory>> getAllCategories() {
    return (select(localMenuCategories)
      ..where((t) => t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.displayOrder)]))
      .get();
  }

  Future<List<LocalMenuItem>> getAllMenuItems() {
    return (select(localMenuItems)
      ..where((t) => t.isAvailable.equals(true)))
      .get();
  }

  Future<List<LocalMenuItem>> getMenuItemsByCategory(String categoryId) {
    return (select(localMenuItems)
      ..where((t) => t.categoryId.equals(categoryId) & t.isAvailable.equals(true)))
      .get();
  }

  Future<List<LocalMenuItemSize>> getMenuItemSizes(String menuItemId) {
    return (select(localMenuItemSizes)..where((t) => t.menuItemId.equals(menuItemId))).get();
  }

  Future<List<LocalMenuItemOption>> getMenuItemOptions(String menuItemId) {
    return (select(localMenuItemOptions)..where((t) => t.menuItemId.equals(menuItemId))).get();
  }

  Future<List<LocalDeal>> getAllDeals() {
    return (select(localDeals)..where((t) => t.isAvailable.equals(true))).get();
  }

  Future<List<LocalDealComponent>> getDealComponents(String dealId) {
    return (select(localDealComponents)..where((t) => t.dealId.equals(dealId))).get();
  }

  Future<List<LocalRestaurantTable>> getAllTables({bool includeDeleted = false}) {
    if (includeDeleted) {
      return select(localRestaurantTables).get();
    }
    return (select(localRestaurantTables)..where((t) => t.isDeleted.equals(false))).get();
  }

  Future<LocalRestaurantTable?> getTableById(String id) {
    return (select(localRestaurantTables)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<LocalFloorZone>> getAllFloorZones() {
    return (select(localFloorZones)..orderBy([(t) => OrderingTerm.asc(t.displayOrder)])).get();
  }

  Future<List<LocalStaffUser>> getActiveStaffUsers() {
    return (select(localStaffUsers)..where((t) => t.isActive.equals(true))).get();
  }

  Future<LocalStaffUser?> getStaffUserByUsername(String username) {
    return (select(localStaffUsers)..where((t) => t.username.equals(username))).getSingleOrNull();
  }

  Future<List<LocalRolePermission>> getRolePermissions(String role) {
    return (select(localRolePermissions)..where((t) => t.role.equals(role))).get();
  }

  Future<LocalStoreSetting?> getStoreSettings() {
    return select(localStoreSettings).getSingleOrNull();
  }
}
