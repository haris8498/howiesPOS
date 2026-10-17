import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/customer_model.dart';
import '../services/api/api_providers.dart';
import '../services/api/customers_api_service.dart';
import '../services/mock_api_service.dart';

class CustomerState {
  final List<CustomerModel> customers;
  final bool isLoading;
  final String searchQuery;

  const CustomerState({
    required this.customers,
    this.isLoading = false,
    this.searchQuery = '',
  });

  List<CustomerModel> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    final q = searchQuery.toLowerCase();
    return customers.where((c) {
      return c.fullName.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();
  }

  CustomerState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    String? searchQuery,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomersApiService _customersApiService;

  CustomerNotifier({CustomersApiService? customersApiService})
      : _customersApiService = customersApiService ?? CustomersApiService(),
        super(CustomerState(
          customers: MockApiService.getInitialCustomers(),
        )) {
    loadCustomers();
  }

  Future<void> loadCustomers({String? search}) async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonList = await _customersApiService.listCustomers(search: search);
      if (jsonList.isNotEmpty) {
        final list = jsonList.map((j) => CustomerModel.fromBackendJson(j)).toList();
        state = state.copyWith(customers: list, isLoading: false);
        return;
      }
    } catch (_) {}
    state = state.copyWith(isLoading: false);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<CustomerModel?> addCustomer(CustomerModel customer) async {
    try {
      final res = await _customersApiService.createCustomer(customer.toCreateDto());
      final created = CustomerModel.fromBackendJson(res);
      state = state.copyWith(customers: [created, ...state.customers]);
      return created;
    } catch (_) {
      state = state.copyWith(customers: [customer, ...state.customers]);
      return customer;
    }
  }

  Future<void> updateCustomer(String id, CustomerModel customer) async {
    try {
      final res = await _customersApiService.updateCustomer(id, customer.toCreateDto());
      final updated = CustomerModel.fromBackendJson(res);
      final list = state.customers.map((c) => c.id == id ? updated : c).toList();
      state = state.copyWith(customers: list);
    } catch (_) {
      final list = state.customers.map((c) => c.id == id ? customer : c).toList();
      state = state.copyWith(customers: list);
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await _customersApiService.deleteCustomer(id);
    } catch (_) {}
    state = state.copyWith(customers: state.customers.where((c) => c.id != id).toList());
  }
}

final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  final customersApi = ref.watch(customersApiServiceProvider);
  return CustomerNotifier(customersApiService: customersApi);
});
