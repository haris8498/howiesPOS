import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../application/orders/complete_order_usecase.dart';
import '../config/feature_flags.dart';
import '../core/sync/sync_providers.dart';
import '../domain/models/menu_item.dart';
import '../domain/models/order_model.dart';
import '../domain/models/restaurant_table.dart';
import '../domain/repositories/inventory_repository.dart';
import '../domain/repositories/kitchen_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/table_repository.dart';
import '../domain/services/order_number_generator.dart';
import '../domain/services/pricing_engine.dart';
import '../services/api/api_providers.dart';
import '../services/api/menu_api_service.dart';
import '../services/api/settings_api_service.dart';
import '../services/mock_api_service.dart';
import 'repositories/api_inventory_repository.dart';
import 'repositories/api_kitchen_repository.dart';
import 'repositories/api_table_repository.dart';
import 'repositories/drift_offline_first_order_repository.dart';
import 'repositories/order_repository_provider.dart';
import '../features/reports/reports_providers.dart';
import 'daily_calculation_repository.dart';

export 'repositories/order_repository_provider.dart' show orderRepositoryProvider;

class PosState {
  final List<MenuItem> menuItems;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final OrderType selectedOrderType;
  final RestaurantTable? selectedTable;
  final int guestCount;
  final String waiterName;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final double deliveryFee;
  final List<OrderItem> currentCart;
  final double discountPercentage;
  final double discountAmount;
  final double taxPercentage;
  final double serviceChargePercentage;
  final List<OrderModel> heldOrders;
  final List<OrderModel> completedOrders;
  final int takeAwayTokenCounter;
  final bool isLoading;
  final PricingEngine _pricingEngine;

  PosState({
    required this.menuItems,
    this.categories = const ['All', 'Pizza', 'Burgers', 'Deals', 'Fries', 'Drinks', 'Desserts', 'Addons'],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.selectedOrderType = OrderType.dineIn,
    this.selectedTable,
    this.guestCount = 2,
    this.waiterName = 'Elena (Cashier)',
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryFee = 4.99,
    this.currentCart = const [],
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.taxPercentage = 8.5,
    this.serviceChargePercentage = 5.0,
    this.heldOrders = const [],
    this.completedOrders = const [],
    this.takeAwayTokenCounter = 101,
    this.isLoading = false,
    PricingEngine? pricingEngine,
  }) : _pricingEngine = pricingEngine ??
            PricingEngine(
              policy: PricingPolicy(
                taxPercentage: taxPercentage,
                serviceChargePercentage: serviceChargePercentage,
                standardDeliveryFee: deliveryFee,
              ),
            );

  PriceBreakdown get priceBreakdown => _pricingEngine.calculateOrderTotals(
        items: currentCart,
        orderType: selectedOrderType,
        discountPercentage: discountPercentage,
        discountAmount: discountAmount,
        customDeliveryFee: (selectedOrderType == OrderType.delivery || selectedOrderType == OrderType.online) ? deliveryFee : 0.0,
      );

  double get subtotal => priceBreakdown.subtotal;
  double get effectiveDiscountAmount => priceBreakdown.discountAmount;
  double get effectiveDiscountPercentage => priceBreakdown.discountPercentage;
  double get taxableSubtotal => priceBreakdown.taxableSubtotal;
  double get taxAmount => priceBreakdown.taxAmount;
  double get serviceChargeAmount => priceBreakdown.serviceChargeAmount;
  double get totalDeliveryFee => priceBreakdown.deliveryFee;
  double get grandTotal => priceBreakdown.grandTotal;

  PosState copyWith({
    List<MenuItem>? menuItems,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    OrderType? selectedOrderType,
    RestaurantTable? selectedTable,
    int? guestCount,
    String? waiterName,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    double? deliveryFee,
    List<OrderItem>? currentCart,
    double? discountPercentage,
    double? discountAmount,
    double? taxPercentage,
    double? serviceChargePercentage,
    List<OrderModel>? heldOrders,
    List<OrderModel>? completedOrders,
    int? takeAwayTokenCounter,
    bool? isLoading,
  }) {
    return PosState(
      menuItems: menuItems ?? this.menuItems,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedOrderType: selectedOrderType ?? this.selectedOrderType,
      selectedTable: selectedTable ?? this.selectedTable,
      guestCount: guestCount ?? this.guestCount,
      waiterName: waiterName ?? this.waiterName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      currentCart: currentCart ?? this.currentCart,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      serviceChargePercentage: serviceChargePercentage ?? this.serviceChargePercentage,
      heldOrders: heldOrders ?? this.heldOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      takeAwayTokenCounter: takeAwayTokenCounter ?? this.takeAwayTokenCounter,
      isLoading: isLoading ?? this.isLoading,
      pricingEngine: _pricingEngine,
    );
  }
}

// Concrete Singletons backed by REST APIs or Offline Drift Storage
final tableRepositoryProvider = Provider<ITableRepository>((ref) {
  return ApiTableRepository(tablesApiService: ref.read(tablesApiServiceProvider));
});

final inventoryRepositoryProvider = Provider<IInventoryRepository>((ref) {
  return ApiInventoryRepository(inventoryApiService: ref.read(inventoryApiServiceProvider));
});

final kitchenRepositoryProvider = Provider<IKitchenRepository>((ref) {
  return ApiKitchenRepository(kitchenApiService: ref.read(kitchenApiServiceProvider));
});

final pricingEngineProvider = Provider<PricingEngine>((ref) => const PricingEngine());

final orderNumberGeneratorProvider = Provider<IOrderNumberGenerator>((ref) {
  if (FeatureFlags.offlineFirstEnabled) {
    final db = ref.watch(appDatabaseProvider);
    return OrderNumberGenerator(terminalSequencesDao: db.terminalSequencesDao);
  }
  // SYNC-009: In legacy online mode (flag OFF), use collision-resistant legacy order numbering
  return OrderNumberGenerator(useLegacyFormat: true);
});

final completeOrderUseCaseProvider = Provider<CompleteOrderUseCase>((ref) {
  return CompleteOrderUseCase(
    orderRepository: ref.watch(orderRepositoryProvider),
    tableRepository: ref.watch(tableRepositoryProvider),
    kitchenRepository: ref.watch(kitchenRepositoryProvider),
    inventoryRepository: ref.watch(inventoryRepositoryProvider),
    pricingEngine: ref.watch(pricingEngineProvider),
    orderNumberGenerator: ref.watch(orderNumberGeneratorProvider),
  );
});

class PosNotifier extends StateNotifier<PosState> {
  final CompleteOrderUseCase? completeOrderUseCase;
  final IOrderNumberGenerator _numberGenerator;
  final MenuApiService _menuApiService;
  final SettingsApiService _settingsApiService;
  final IOrderRepository? _orderRepository;
  final Ref? _ref;
  StreamSubscription<List<OrderModel>>? _ordersSubscription;

  /// In-flight checkout future lock for Tier 1 duplicate submit defense (§15.2)
  Future<OrderModel>? _activeCheckoutFuture;

  PosNotifier({
    this.completeOrderUseCase,
    IOrderNumberGenerator? numberGenerator,
    MenuApiService? menuApiService,
    SettingsApiService? settingsApiService,
    IOrderRepository? orderRepository,
    Ref? ref,
  })  : _numberGenerator = numberGenerator ?? OrderNumberGenerator(),
        _menuApiService = menuApiService ?? MenuApiService(),
        _settingsApiService = settingsApiService ?? SettingsApiService(),
        _orderRepository = orderRepository,
        _ref = ref,
        super(PosState(
          menuItems: MockApiService.getInitialMenuItems(),
        )) {
    _loadMenuAndSettings();
    _initOrderStream();
  }

  void _initOrderStream() {
    final repo = _orderRepository;
    if (repo is DriftOfflineFirstOrderRepository) {
      _ordersSubscription = repo.watchAllOrders().listen((orders) {
        if (!mounted || orders.isEmpty) return;
        final completed = orders
            .where((o) =>
                o.status == OrderStatus.completed ||
                o.status == OrderStatus.accepted)
            .toList();
        final held = orders.where((o) => o.isHeld).toList();
        state = state.copyWith(
          completedOrders: completed,
          heldOrders: held,
        );
        final ref = _ref;
        if (ref != null) {
          try {
            ref.invalidate(reportSummaryProvider);
            ref.invalidate(reportProductsProvider);
            ref.invalidate(cancelledOrdersProvider);
            ref.read(dailyCalculationProvider.notifier).fetchLiveSummary();
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMenuAndSettings({bool silent = false}) async {
    if (!silent && state.menuItems.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    try {
      // 1. Load Categories
      final cats = await _menuApiService.listCategories();
      final catNames = <String>['All'];
      if (cats.isNotEmpty) {
        for (final c in cats) {
          final name = c['name']?.toString();
          if (name != null && !catNames.contains(name)) {
            catNames.add(name);
          }
        }
      }

      // 2. Load Items & Deals from Database
      final itemsJson = await _menuApiService.listItems();
      final dealsJson = await _menuApiService.listDeals();
      List<MenuItem> items = [];
      if (itemsJson.isNotEmpty) {
        items.addAll(itemsJson.map((j) => MenuItem.fromBackendJson(j)));
      }
      if (dealsJson.isNotEmpty) {
        for (final d in dealsJson) {
          items.add(MenuItem(
            id: d['id']?.toString() ?? '',
            name: d['title']?.toString() ?? '',
            category: 'Exclusive Deals',
            description: d['description']?.toString() ?? d['subtitle']?.toString() ?? '',
            basePrice: double.tryParse(d['deal_price']?.toString() ?? '0') ?? 0.0,
            imageUrl: d['image_path']?.toString() ?? '',
            isAvailable: d['is_available'] != false,
          ));
        }
      }

      if (items.isEmpty) {
        items = MockApiService.getInitialMenuItems();
      }

      // 3. Load Store Settings for Tax & Service Charge
      try {
        final settings = await _settingsApiService.getSettings();
        final tax = double.tryParse(settings['sales_tax_rate']?.toString() ?? '8.5') ?? 8.5;
        final service = double.tryParse(settings['dine_in_service_charge_rate']?.toString() ?? '5.0') ?? 5.0;

        state = state.copyWith(
          menuItems: items,
          categories: catNames.length > 1 ? catNames : state.categories,
          taxPercentage: tax,
          serviceChargePercentage: service,
          isLoading: false,
        );
        return;
      } catch (_) {}

      state = state.copyWith(
        menuItems: items,
        categories: catNames.length > 1 ? catNames : state.categories,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshMenu({bool silent = true}) async {
    await _loadMenuAndSettings(silent: silent);
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setOrderType(OrderType type) {
    state = state.copyWith(selectedOrderType: type);
  }

  void setSelectedTable(RestaurantTable? table) {
    state = state.copyWith(selectedTable: table);
  }

  void setGuestCount(int count) {
    state = state.copyWith(guestCount: count);
  }

  void setCustomerDetails({String? name, String? phone, String? address}) {
    state = state.copyWith(
      customerName: name,
      customerPhone: phone,
      deliveryAddress: address,
    );
  }

  void addToCart(MenuItem item, {String size = 'Large', String crust = 'Butter Cheese'}) {
    final existingIndex = state.currentCart.indexWhere(
      (i) => i.item.id == item.id && i.selectedSize == size && i.selectedCrust == crust,
    );

    if (existingIndex >= 0) {
      final updatedCart = List<OrderItem>.from(state.currentCart);
      final existingItem = updatedCart[existingIndex];
      updatedCart[existingIndex] = existingItem.copyWith(quantity: existingItem.quantity + 1);
      state = state.copyWith(currentCart: updatedCart);
    } else {
      final newItem = OrderItem(item: item, quantity: 1, selectedSize: size, selectedCrust: crust);
      state = state.copyWith(currentCart: [...state.currentCart, newItem]);
    }
  }

  void updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(index);
      return;
    }
    final updatedCart = List<OrderItem>.from(state.currentCart);
    updatedCart[index] = updatedCart[index].copyWith(quantity: newQuantity);
    state = state.copyWith(currentCart: updatedCart);
  }

  void removeFromCart(int index) {
    final updatedCart = List<OrderItem>.from(state.currentCart)..removeAt(index);
    state = state.copyWith(currentCart: updatedCart);
  }

  void clearCart() {
    state = state.copyWith(currentCart: [], discountPercentage: 0.0, discountAmount: 0.0, selectedTable: null);
  }

  void resetForNewShift() {
    state = state.copyWith(
      currentCart: [],
      discountPercentage: 0.0,
      discountAmount: 0.0,
      selectedTable: null,
      heldOrders: [],
    );
  }

  void applyDiscountPercentage(double percentage) {
    final clampedPct = percentage.clamp(0.0, 100.0);
    final calculatedAmount = state.subtotal * (clampedPct / 100);
    state = state.copyWith(
      discountPercentage: clampedPct,
      discountAmount: calculatedAmount,
    );
  }

  void applyDiscount(double amount) {
    final clampedAmount = amount.clamp(0.0, state.subtotal > 0 ? state.subtotal : double.infinity);
    final calculatedPct = state.subtotal > 0 ? (clampedAmount / state.subtotal) * 100 : 0.0;
    state = state.copyWith(
      discountPercentage: calculatedPct,
      discountAmount: clampedAmount,
    );
  }

  void holdOrder() {
    if (state.currentCart.isEmpty) return;
    final held = OrderModel(
      id: const Uuid().v4(),
      orderNumber: 'HH-HLD${state.heldOrders.length + 1}',
      tableId: state.selectedTable?.id,
      tableName: state.selectedTable?.name,
      guestCount: state.guestCount,
      waiterName: state.waiterName,
      type: state.selectedOrderType,
      status: OrderStatus.newOrder,
      items: List.from(state.currentCart),
      createdAt: DateTime.now(),
      discountPercentage: state.effectiveDiscountPercentage,
      discountAmount: state.effectiveDiscountAmount,
      isHeld: true,
    );
    state = state.copyWith(
      heldOrders: [...state.heldOrders, held],
      currentCart: [],
      discountPercentage: 0.0,
      discountAmount: 0.0,
      selectedTable: null,
    );
  }

  void resumeOrder(OrderModel order) {
    final updatedHeld = state.heldOrders.where((o) => o.id != order.id).toList();
    state = state.copyWith(
      heldOrders: updatedHeld,
      currentCart: List.from(order.items),
      discountPercentage: order.discountPercentage,
      discountAmount: order.discountAmount,
      selectedOrderType: order.type,
    );
  }

  Future<void> toggleAvailability(String itemId, bool isAvailable) async {
    try {
      await _menuApiService.updateAvailability(itemId, isAvailable);
    } catch (_) {}

    final updatedItems = state.menuItems.map((item) {
      if (item.id == itemId) return item.copyWith(isAvailable: isAvailable);
      return item;
    }).toList();
    state = state.copyWith(menuItems: updatedItems);
  }

  Future<void> addCategory({
    required String id,
    required String name,
    String? badgeText,
    String? imagePath,
    String? description,
    String? iconName,
  }) async {
    try {
      await _menuApiService.createCategory({
        'id': id,
        'name': name,
        'badge_text': badgeText ?? 'Category',
        'image_path': imagePath ?? '',
        'description': description ?? '',
        'icon_name': iconName ?? 'fastfood',
      });
    } catch (_) {}

    final updatedCats = List<String>.from(state.categories);
    if (!updatedCats.contains(name)) {
      updatedCats.add(name);
    }
    state = state.copyWith(categories: updatedCats);
  }

  Future<void> deleteCategory(String categoryId, String categoryName) async {
    try {
      await _menuApiService.deleteCategory(categoryId);
    } catch (_) {}

    final updatedCats = state.categories.where((c) => c != categoryName).toList();
    final updatedItems = state.menuItems.where((item) => item.category.toLowerCase() != categoryName.toLowerCase()).toList();
    state = state.copyWith(
      categories: updatedCats,
      menuItems: updatedItems,
    );
  }

  Future<void> addMenuItem(
    MenuItem newItem, {
    String? categoryId,
    List<Map<String, dynamic>>? sizes,
    List<Map<String, dynamic>>? options,
  }) async {
    state = state.copyWith(menuItems: [newItem, ...state.menuItems]);

    try {
      final catId = categoryId ?? newItem.category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      await _menuApiService.createItem({
        'category_id': catId,
        'name': newItem.name,
        'description': newItem.description,
        'base_price': newItem.basePrice,
        'image_url': newItem.imageUrl,
        'is_veg': newItem.isVeg,
        'is_spicy': newItem.isSpicy,
        'is_available': newItem.isAvailable,
        if (sizes != null && sizes.isNotEmpty) 'sizes': sizes,
        if (options != null && options.isNotEmpty) 'options': options,
      });
    } catch (_) {}
  }

  Future<void> deleteMenuItem(String itemId) async {
    state = state.copyWith(
      menuItems: state.menuItems.where((item) => item.id != itemId && item.name.toLowerCase() != itemId.toLowerCase()).toList(),
    );

    try {
      await _menuApiService.deleteItem(itemId);
    } catch (_) {}
  }

  void deleteMenuItemsByCategory(String category) {
    state = state.copyWith(
      menuItems: state.menuItems.where((item) => item.category.toLowerCase() != category.toLowerCase()).toList(),
    );
  }

  Future<OrderModel> processOrderCheckout(PaymentMethod paymentMethod) async {
    // Tier 1 Duplicate-Submit Protection (§15.2):
    // Reuse existing in-flight future if checkout is already executing
    if (_activeCheckoutFuture != null) {
      return _activeCheckoutFuture!;
    }

    final future = _doProcessOrderCheckout(paymentMethod);
    _activeCheckoutFuture = future;
    try {
      return await future;
    } finally {
      _activeCheckoutFuture = null;
    }
  }

  Future<OrderModel> _doProcessOrderCheckout(PaymentMethod paymentMethod) async {
    final command = CompleteOrderCommand(
      items: state.currentCart,
      orderType: state.selectedOrderType,
      paymentMethod: paymentMethod,
      selectedTable: state.selectedTable,
      guestCount: state.guestCount,
      waiterName: state.waiterName,
      customerName: state.customerName,
      customerPhone: state.customerPhone,
      deliveryAddress: state.deliveryAddress,
      discountPercentage: state.effectiveDiscountPercentage,
      discountAmount: state.effectiveDiscountAmount,
    );

    final useCase = completeOrderUseCase;
    if (useCase != null) {
      final result = await useCase.execute(command);
      if (result.isSuccess) {
        final completed = result.data;
        final existing = state.completedOrders.where((o) => o.id != completed.id).toList();
        state = state.copyWith(
          completedOrders: [completed, ...existing],
          currentCart: [],
          discountPercentage: 0.0,
          discountAmount: 0.0,
          selectedTable: null,
          takeAwayTokenCounter: state.takeAwayTokenCounter + 1,
        );
        return completed;
      }
    }

    // Fallback synchronous execution
    return checkoutCurrentOrder(paymentMethod);
  }

  OrderModel checkoutCurrentOrder(PaymentMethod paymentMethod) {
    final token = state.selectedOrderType == OrderType.takeAway
        ? _numberGenerator.generateTakeawayToken(currentCounter: state.takeAwayTokenCounter)
        : null;

    final newOrder = OrderModel(
      id: _numberGenerator.generateUniqueId(),
      orderNumber: _numberGenerator.generateOrderNumber(),
      tokenNumber: token,
      tableId: state.selectedTable?.id,
      tableName: state.selectedTable?.name,
      guestCount: state.guestCount,
      waiterName: state.waiterName,
      type: state.selectedOrderType,
      status: OrderStatus.accepted,
      items: List.from(state.currentCart),
      createdAt: DateTime.now(),
      discountPercentage: state.effectiveDiscountPercentage,
      discountAmount: state.effectiveDiscountAmount,
      taxPercentage: state.taxPercentage,
      serviceChargePercentage: state.serviceChargePercentage,
      deliveryFee: state.deliveryFee,
      customerName: state.customerName,
      customerPhone: state.customerPhone,
      deliveryAddress: state.deliveryAddress,
      paymentMethod: paymentMethod,
      isPaid: true,
      kitchenTicketSent: true,
    );

    final existing = state.completedOrders.where((o) => o.id != newOrder.id).toList();
    state = state.copyWith(
      completedOrders: [newOrder, ...existing],
      currentCart: [],
      discountAmount: 0.0,
      selectedTable: null,
      takeAwayTokenCounter: state.takeAwayTokenCounter + 1,
    );

    return newOrder;
  }
}

final posProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  final useCase = ref.watch(completeOrderUseCaseProvider);
  final numberGen = ref.watch(orderNumberGeneratorProvider);
  final menuApi = ref.watch(menuApiServiceProvider);
  final settingsApi = ref.watch(settingsApiServiceProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);

  return PosNotifier(
    completeOrderUseCase: useCase,
    numberGenerator: numberGen,
    menuApiService: menuApi,
    settingsApiService: settingsApi,
    orderRepository: orderRepo,
    ref: ref,
  );
});
