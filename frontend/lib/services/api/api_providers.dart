import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/kitchen_socket_service.dart';
import 'auth_api_service.dart';
import 'customers_api_service.dart';
import 'delivery_api_service.dart';
import 'expenses_api_service.dart';
import 'inventory_api_service.dart';
import 'kitchen_api_service.dart';
import 'menu_api_service.dart';
import 'orders_api_service.dart';
import 'permissions_api_service.dart';
import 'reports_api_service.dart';
import 'settings_api_service.dart';
import 'staff_api_service.dart';
import 'tables_api_service.dart';
import 'users_api_service.dart';
import 'daily_calculation_api_service.dart';
import 'sync_api_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final kitchenSocketServiceProvider = Provider<KitchenSocketService>((ref) {
  final service = KitchenSocketService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(apiClient: ref.watch(apiClientProvider));
});

final usersApiServiceProvider = Provider<UsersApiService>((ref) {
  return UsersApiService(apiClient: ref.watch(apiClientProvider));
});

final staffApiServiceProvider = Provider<StaffApiService>((ref) {
  return StaffApiService(apiClient: ref.watch(apiClientProvider));
});

final permissionsApiServiceProvider = Provider<PermissionsApiService>((ref) {
  return PermissionsApiService(apiClient: ref.watch(apiClientProvider));
});

final menuApiServiceProvider = Provider<MenuApiService>((ref) {
  return MenuApiService(apiClient: ref.watch(apiClientProvider));
});

final customersApiServiceProvider = Provider<CustomersApiService>((ref) {
  return CustomersApiService(apiClient: ref.watch(apiClientProvider));
});

final ordersApiServiceProvider = Provider<OrdersApiService>((ref) {
  return OrdersApiService(apiClient: ref.watch(apiClientProvider));
});

final tablesApiServiceProvider = Provider<TablesApiService>((ref) {
  return TablesApiService(apiClient: ref.watch(apiClientProvider));
});

final deliveryApiServiceProvider = Provider<DeliveryApiService>((ref) {
  return DeliveryApiService(apiClient: ref.watch(apiClientProvider));
});

final inventoryApiServiceProvider = Provider<InventoryApiService>((ref) {
  return InventoryApiService(apiClient: ref.watch(apiClientProvider));
});

final expensesApiServiceProvider = Provider<ExpensesApiService>((ref) {
  return ExpensesApiService(apiClient: ref.watch(apiClientProvider));
});

final dailyCalculationApiServiceProvider = Provider<DailyCalculationApiService>((ref) {
  return DailyCalculationApiService(apiClient: ref.watch(apiClientProvider));
});

final settingsApiServiceProvider = Provider<SettingsApiService>((ref) {
  return SettingsApiService(apiClient: ref.watch(apiClientProvider));
});

final reportsApiServiceProvider = Provider<ReportsApiService>((ref) {
  return ReportsApiService(apiClient: ref.watch(apiClientProvider));
});


final syncApiServiceProvider = Provider<SyncApiService>((ref) {
  return SyncApiService(apiClient: ref.watch(apiClientProvider));
});

final kitchenApiServiceProvider = Provider<KitchenApiService>((ref) {
  return KitchenApiService(apiClient: ref.watch(apiClientProvider));
});

