import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_theme.dart';
import '../../data/auth_repository.dart';
import '../../data/pos_repository.dart';
import '../../data/role_rights_repository.dart';
import '../../domain/models/menu_item.dart';
import '../../domain/models/user_role.dart';
import '../../services/api/api_providers.dart';
import '../../shared/widgets/confirm_delete_dialog.dart';

class MenuCategoryItem {
  final String id;
  final String name;
  final String categoryKey;
  final String badgeText;
  final String imagePath;
  final Uint8List? imageBytes;
  final String description;
  final IconData icon;

  const MenuCategoryItem({
    required this.id,
    required this.name,
    required this.categoryKey,
    required this.badgeText,
    required this.imagePath,
    this.imageBytes,
    required this.description,
    required this.icon,
  });
}

class DealComponent {
  final String name;
  final String category;
  final String quantity;
  final IconData icon;

  const DealComponent({
    required this.name,
    required this.category,
    this.quantity = '1x',
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'quantity': quantity,
      };
}

class DealItem {
  final String id;
  final String title;
  final String subtitle;
  final double dealPrice;
  final double? originalPrice;
  final String badgeText;
  final String imagePath;
  final String description;
  final List<DealComponent> items;
  final bool isAvailable;

  const DealItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dealPrice,
    this.originalPrice,
    this.badgeText = 'EXCLUSIVE DEAL',
    required this.imagePath,
    required this.description,
    required this.items,
    this.isAvailable = true,
  });

  DealItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? dealPrice,
    double? originalPrice,
    String? badgeText,
    String? imagePath,
    String? description,
    List<DealComponent>? items,
    bool? isAvailable,
  }) {
    return DealItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      dealPrice: dealPrice ?? this.dealPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      badgeText: badgeText ?? this.badgeText,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      items: items ?? this.items,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class SizePricePair {
  final TextEditingController sizeController;
  final TextEditingController priceController;

  SizePricePair({String size = '', String price = ''})
      : sizeController = TextEditingController(text: size),
        priceController = TextEditingController(text: price);

  void dispose() {
    sizeController.dispose();
    priceController.dispose();
  }
}

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryKey = 'all';
  MenuCategoryItem? _selectedCategoryForDetails;
  final List<Map<String, dynamic>> _customMenuItems = [];
  // Cache of raw bytes for device-picked images — keyed by file path.
  // Image.file() can silently fail on Windows desktop; Image.memory() is 100% reliable.
  final Map<String, Uint8List> _deviceImageCache = {};
  final List<DealItem> _dealsList = [];
  int _activeDealIndex = 0;
  bool _showExclusiveDealsBanner = true;

  final List<MenuCategoryItem> _allCategories = [
    MenuCategoryItem(
      id: 'deals',
      name: 'Exclusive Deals',
      categoryKey: 'deals',
      badgeText: 'HOT DEALS',
      imagePath: 'assets/images/Pizza.png',
      description: 'Value meal combos, family feast bundles, discounted combos & seasonal specials.',
      icon: Icons.local_offer_rounded,
    ),
    MenuCategoryItem(
      id: 'pizza',
      name: 'Pizza',
      categoryKey: 'pizza',
      badgeText: 'Pizza',
      imagePath: 'assets/images/Pizza.png',
      description: 'Melted cheese, chicken toppings, colorful vegetables & crispy charred crust.',
      icon: Icons.local_pizza_rounded,
    ),
    MenuCategoryItem(
      id: 'chicken-steak',
      name: 'Chicken Steak',
      categoryKey: 'chicken-steak',
      badgeText: 'Steak',
      imagePath: 'assets/images/chicken_steak.png',
      description: 'Tender grilled chicken steak with creamy sauce, mashed potato & vegetables.',
      icon: Icons.set_meal_rounded,
    ),
    MenuCategoryItem(
      id: 'burger',
      name: 'Burger',
      categoryKey: 'burger',
      badgeText: 'Burger',
      imagePath: 'assets/images/beef_burger_hero.jpg',
      description: 'Gourmet beef & chicken burgers with melted cheese, lettuce, tomato & brioche bun.',
      icon: Icons.lunch_dining_rounded,
    ),
    MenuCategoryItem(
      id: 'dajjaj-brost',
      name: 'Dajjaj Brost',
      categoryKey: 'dajjaj-brost',
      badgeText: 'Brost',
      imagePath: 'assets/images/broast_hero.jpg',
      description: 'Golden crispy broast chicken pieces served with fries, garlic dip & lemon.',
      icon: Icons.restaurant_rounded,
    ),
    MenuCategoryItem(
      id: 'pasta',
      name: 'Pasta',
      categoryKey: 'pasta',
      badgeText: 'Pasta',
      imagePath: 'assets/images/pasta_hero.jpg',
      description: 'Creamy chicken Alfredo pasta with parmesan cheese, Italian herbs & grilled chicken.',
      icon: Icons.ramen_dining_rounded,
    ),
    MenuCategoryItem(
      id: 'panini',
      name: 'Panini',
      categoryKey: 'panini',
      badgeText: 'Panini',
      imagePath: 'assets/images/panini_hero.jpg',
      description: 'Toasted grilled panini sandwich with melted cheese, chicken & fresh vegetables.',
      icon: Icons.breakfast_dining_rounded,
    ),
    MenuCategoryItem(
      id: 'appetizer',
      name: 'Appetizer',
      categoryKey: 'appetizer',
      badgeText: 'Appetizer',
      imagePath: 'assets/images/appetizer_hero.jpg',
      description: 'Crispy nuggets, wings, french fries & dipping sauces served on a platter.',
      icon: Icons.tapas_rounded,
    ),
    MenuCategoryItem(
      id: 'fries',
      name: 'Fries',
      categoryKey: 'fries',
      badgeText: 'Fries',
      imagePath: 'assets/images/fries_hero.jpg',
      description: 'Golden crispy French fries including loaded fries with melted cheese & sauces.',
      icon: Icons.fastfood_rounded,
    ),
    MenuCategoryItem(
      id: 'beverages',
      name: 'Beverages',
      categoryKey: 'beverages',
      badgeText: 'Drinks',
      imagePath: 'assets/images/beverages_hero.jpg',
      description: 'Ice-cold soft drinks, bottled mineral water & cold beverages with ice condensation.',
      icon: Icons.local_drink_rounded,
    ),
    MenuCategoryItem(
      id: 'extra-topping',
      name: 'Extra Topping',
      categoryKey: 'extra-topping',
      badgeText: 'Topping',
      imagePath: 'assets/images/toppings_hero.jpg',
      description: 'Melted cheese, BBQ sauce, garlic mayo, jalapeno sauce & honey mustard.',
      icon: Icons.category_rounded,
    ),
    MenuCategoryItem(
      id: 'hot-beverages',
      name: 'Hot Beverages',
      categoryKey: 'hot-beverages',
      badgeText: 'Hot Coffee',
      imagePath: 'assets/images/hot_beverages_hero.jpg',
      description: 'Cappuccino, espresso, latte, hot chocolate & brewed tea cups with steam.',
      icon: Icons.coffee_rounded,
    ),
    MenuCategoryItem(
      id: 'cold-coffee',
      name: 'Cold Coffee',
      categoryKey: 'cold-coffee',
      badgeText: 'Iced Coffee',
      imagePath: 'assets/images/cold_coffee_hero.jpg',
      description: 'Caramel iced latte, vanilla iced latte, mocha & strawberry iced latte with ice.',
      icon: Icons.icecream_rounded,
    ),
    MenuCategoryItem(
      id: 'ice-cream',
      name: 'Ice Cream',
      categoryKey: 'ice-cream',
      badgeText: 'Ice Cream',
      imagePath: 'assets/images/ice_cream_hero.jpg',
      description: 'Kulfa, mango, vanilla, chocolate & strawberry scoops in elegant bowls.',
      icon: Icons.cookie_rounded,
    ),
    MenuCategoryItem(
      id: 'mocktails',
      name: 'Mocktails',
      categoryKey: 'mocktails',
      badgeText: 'Mocktail',
      imagePath: 'assets/images/mocktails_hero.jpg',
      description: 'Vibrant colorful mocktails in elegant glasses with fresh fruit & mint garnishes.',
      icon: Icons.local_bar_rounded,
    ),
    MenuCategoryItem(
      id: 'mojito',
      name: 'Mojito',
      categoryKey: 'mojito',
      badgeText: 'Mojito',
      imagePath: 'assets/images/Mojito.png',
      description: 'Fresh mojitos with crushed ice, mint leaves, lime slices & fruit flavors.',
      icon: Icons.local_cafe_rounded,
    ),
    MenuCategoryItem(
      id: 'smoothies',
      name: 'Smoothies',
      categoryKey: 'smoothies',
      badgeText: 'Smoothie',
      imagePath: 'assets/images/Smooth.png',
      description: 'Thick creamy fruit smoothies featuring mango, banana, mixed berry & strawberry.',
      icon: Icons.blender_rounded,
    ),
    MenuCategoryItem(
      id: 'ice-shakes',
      name: 'Ice Shakes',
      categoryKey: 'ice-shakes',
      badgeText: 'Shake',
      imagePath: 'assets/images/ice shake.webp',
      description: 'Rich thick ice shakes in mango, vanilla, caramel, chocolate & Kulfa flavors.',
      icon: Icons.water_drop_rounded,
    ),
    MenuCategoryItem(
      id: 'milk-shakes',
      name: 'Milk Shakes',
      categoryKey: 'milk-shakes',
      badgeText: 'Milkshake',
      imagePath: 'assets/images/Milk shake.png',
      description: 'Creamy chilled milkshakes with apple, banana, seasonal fruit & strawberry.',
      icon: Icons.emoji_food_beverage_rounded,
    ),
    MenuCategoryItem(
      id: 'soft-drinks',
      name: 'Soft Drinks',
      categoryKey: 'soft-drinks',
      badgeText: 'Soda',
      imagePath: 'assets/images/soft.png',
      description: 'Fresh lime and mint-based refreshing drinks served in glasses with crushed ice.',
      icon: Icons.wine_bar_rounded,
    ),
    MenuCategoryItem(
      id: 'pakistani-karahi',
      name: 'Pakistani Karahi',
      categoryKey: 'pakistani-karahi',
      badgeText: 'Karahi & Handi',
      imagePath: 'assets/images/pakistani_karahi.jpg',
      description: 'Authentic Pakistani Chicken Karahi, Handi & aromatic Biryani cooked with rich spices and herbs.',
      icon: Icons.local_fire_department_rounded,
    ),
    MenuCategoryItem(
      id: 'biryani',
      name: 'Biryani',
      categoryKey: 'biryani',
      badgeText: 'Biryani',
      imagePath: 'assets/images/pakistani_biryani.jpg',
      description: 'Aromatic Bombay Chicken Biryani and Hungry Special Biryani cooked with fragrant basmati rice.',
      icon: Icons.restaurant_menu_rounded,
    ),
    MenuCategoryItem(
      id: 'soup',
      name: 'Soup',
      categoryKey: 'soup',
      badgeText: 'Soup',
      imagePath: 'assets/images/delicious_soup.jpg',
      description: 'Warm, rich & comforting Hot & Sour, Corn, and Hungry Special Soups.',
      icon: Icons.soup_kitchen_rounded,
    ),
    MenuCategoryItem(
      id: 'tandoori',
      name: 'Tandoori',
      categoryKey: 'tandoori',
      badgeText: 'Tandoori',
      imagePath: 'assets/images/tandoori_naan.jpg',
      description: 'Freshly baked Roti, Roghni Naan, Sada Naan & Kalwanji Naan straight from clay tandoor.',
      icon: Icons.bakery_dining_rounded,
    ),
    MenuCategoryItem(
      id: 'salad',
      name: 'Salad & Raita',
      categoryKey: 'salad',
      badgeText: 'Salad & Raita',
      imagePath: 'assets/images/salad_raita_hero.jpg',
      description: 'Fresh crispy Green Salad and soothing Zeera Raita to complement your meal.',
      icon: Icons.eco_rounded,
    ),
  ];

  // Mutable lists for category sub-items
  late List<Map<String, dynamic>> _pizzaSubCategories;
  late List<Map<String, String>> _steakItems;
  late List<Map<String, String>> _beefBurgers;
  late List<Map<String, String>> _chickenBurgers;
  late List<Map<String, String>> _brostItems;
  late List<Map<String, String>> _pastaItems;
  late List<Map<String, String>> _paniniItems;
  late List<Map<String, String>> _appetizerItems;
  late List<Map<String, String>> _friesItems;
  late List<Map<String, String>> _beveragesItems;
  late List<Map<String, String>> _extraToppingItems;
  late List<Map<String, String>> _hotBeveragesItems;
  late List<Map<String, String>> _coldCoffeeItems;
  late List<String> _iceCreamFlavors;
  late List<Map<String, String>> _mocktailsItems;
  late List<Map<String, String>> _mojitoItems;
  late List<Map<String, String>> _smoothiesItems;
  late List<Map<String, String>> _iceShakesItems;
  late List<Map<String, String>> _milkShakesItems;
  late List<Map<String, String>> _softDrinksItems;

  @override
  void initState() {
    super.initState();
    _initSubItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoriesAndItemsFromBackend();
    });
  }

  Future<void> _loadCategoriesAndItemsFromBackend() async {
    try {
      final menuApi = ref.read(menuApiServiceProvider);
      // Run category, item, and deal requests concurrently in parallel for maximum speed
      final results = await Future.wait([
        menuApi.listCategories(),
        menuApi.listItems(),
        menuApi.listDeals(),
      ]);

      final dbCategories = results[0];
      final dbItems = results[1];
      final dbDeals = results[2];

      if (!mounted) return;

      setState(() {
        // 1. Load Categories
        for (final cat in dbCategories) {
          final catId = cat['id']?.toString() ?? '';
          final catName = cat['name']?.toString() ?? '';
          if (catName.isEmpty) continue;

          final imgPath = cat['image_path']?.toString() ?? '';
          Uint8List? imgBytes;
          if (imgPath.startsWith('data:image') || imgPath.contains(';base64,')) {
            try {
              imgBytes = base64Decode(imgPath.split(',').last);
              _deviceImageCache[imgPath] = imgBytes;
            } catch (_) {}
          }

          final existingIndex = _allCategories.indexWhere(
            (c) => c.id == catId || c.name.toLowerCase() == catName.toLowerCase(),
          );
          if (existingIndex == -1) {
            _allCategories.add(MenuCategoryItem(
              id: catId,
              name: catName,
              categoryKey: catId,
              badgeText: cat['badge_text']?.toString() ?? 'Category',
              imagePath: imgPath,
              imageBytes: imgBytes,
              description: cat['description']?.toString() ?? 'Delicious collection of $catName.',
              icon: Icons.category_rounded,
            ));
          } else {
            final existing = _allCategories[existingIndex];
            if (imgPath.isNotEmpty && (existing.imagePath.isEmpty || imgBytes != null)) {
              _allCategories[existingIndex] = MenuCategoryItem(
                id: existing.id,
                name: existing.name,
                categoryKey: existing.categoryKey,
                badgeText: cat['badge_text']?.toString() ?? existing.badgeText,
                imagePath: imgPath,
                imageBytes: imgBytes ?? existing.imageBytes,
                description: cat['description']?.toString() ?? existing.description,
                icon: existing.icon,
              );
            }
          }
        }

        // 2. Load Deals
        if (dbDeals.isNotEmpty) {
          final List<DealItem> loadedDeals = [];
          for (final d in dbDeals) {
            final components = <DealComponent>[];
            if (d['components'] is List) {
              for (final c in d['components'] as List) {
                components.add(DealComponent(
                  name: c['item_name']?.toString() ?? '',
                  category: c['category']?.toString() ?? '',
                  quantity: c['quantity']?.toString() ?? '1x',
                  icon: Icons.fastfood_rounded,
                ));
              }
            }
            loadedDeals.add(DealItem(
              id: d['id']?.toString() ?? '',
              title: d['title']?.toString() ?? '',
              subtitle: d['subtitle']?.toString() ?? '',
              dealPrice: double.tryParse(d['deal_price']?.toString() ?? '0') ?? 0.0,
              originalPrice: d['original_price'] != null ? double.tryParse(d['original_price'].toString()) : null,
              badgeText: d['badge_text']?.toString() ?? 'EXCLUSIVE DEAL',
              imagePath: d['image_path']?.toString() ?? '',
              description: d['description']?.toString() ?? '',
              items: components,
              isAvailable: d['is_available'] != false,
            ));
          }
          if (loadedDeals.isNotEmpty) {
            _dealsList.clear();
            _dealsList.addAll(loadedDeals);
          }
        }

        // 3. Populate Category-specific Sub-menus & Custom Items from Database
        final List<Map<String, String>> dbSteaks = [];
        final List<Map<String, String>> dbBeefBurgers = [];
        final List<Map<String, String>> dbChickenBurgers = [];
        final List<Map<String, String>> dbBroast = [];
        final List<Map<String, String>> dbPasta = [];
        final List<Map<String, String>> dbPanini = [];
        final List<Map<String, String>> dbAppetizers = [];
        final List<Map<String, String>> dbFries = [];
        final List<Map<String, String>> dbBeverages = [];
        final List<Map<String, String>> dbToppings = [];
        final List<Map<String, String>> dbHotBev = [];
        final List<Map<String, String>> dbColdCoffee = [];
        final List<String> dbIceCream = [];
        final List<Map<String, String>> dbMocktails = [];
        final List<Map<String, String>> dbMojito = [];
        final List<Map<String, String>> dbSmoothies = [];
        final List<Map<String, String>> dbIceShakes = [];
        final List<Map<String, String>> dbMilkShakes = [];
        final List<Map<String, String>> dbSoftDrinks = [];

        for (final item in dbItems) {
          final itemName = item['name']?.toString() ?? '';
          final categoryName = item['category']?['name']?.toString() ?? item['category_id']?.toString() ?? '';
          final catIdLower = (item['category_id']?.toString() ?? categoryName).toLowerCase();
          if (itemName.isEmpty) continue;

          final pVal = double.tryParse(item['base_price']?.toString() ?? '0') ?? 0.0;
          final priceStr = 'PKR ${pVal.toInt()}';
          final imgPath = item['image_url']?.toString() ?? '';

          if (catIdLower.contains('steak')) {
            dbSteaks.add({'name': itemName, 'price': priceStr});
          } else if (catIdLower.contains('burger')) {
            if (itemName.toLowerCase().contains('beef') || itemName.toLowerCase().contains('smash') || itemName.toLowerCase().contains('stacker')) {
              dbBeefBurgers.add({'name': itemName, 'price': priceStr});
            } else {
              dbChickenBurgers.add({'name': itemName, 'price': priceStr});
            }
          } else if (catIdLower.contains('brost') || catIdLower.contains('broast')) {
            dbBroast.add({'name': itemName, 'price': priceStr});
          } else if (catIdLower.contains('pasta')) {
            dbPasta.add({
              'name': itemName,
              'desc': item['description']?.toString() ?? '',
              'price': priceStr,
              'badge': item['is_spicy'] == true ? 'Spicy Italian' : 'Chef Special',
            });
          } else if (catIdLower.contains('panini')) {
            dbPanini.add({'name': itemName, 'price': priceStr});
          } else if (catIdLower.contains('appetizer')) {
            dbAppetizers.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('fries')) {
            dbFries.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower == 'beverages') {
            dbBeverages.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('topping')) {
            dbToppings.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('hot-bev') || catIdLower.contains('hot beverages')) {
            dbHotBev.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('cold-coffee') || catIdLower.contains('cold coffee')) {
            dbColdCoffee.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('ice-cream') || catIdLower.contains('ice cream')) {
            dbIceCream.add(itemName);
          } else if (catIdLower.contains('mocktail')) {
            dbMocktails.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('mojito')) {
            dbMojito.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('smoothie')) {
            dbSmoothies.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('ice-shake') || catIdLower.contains('ice shake')) {
            dbIceShakes.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('milk-shake') || catIdLower.contains('milk shake')) {
            dbMilkShakes.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          } else if (catIdLower.contains('soft-drink') || catIdLower.contains('soft drink')) {
            dbSoftDrinks.add({'name': itemName, 'price': priceStr, 'image': imgPath});
          }

          // Also keep in custom menu items for search & general lookup
          final exists = _customMenuItems.any((c) => c['name'] == itemName || c['id'] == item['id']);
          if (!exists) {
            final Map<String, String> pricesMap = {};
            if (item['sizes'] is List) {
              for (final s in (item['sizes'] as List)) {
                final sName = s['size_name']?.toString() ?? '';
                final sPrice = s['price']?.toString() ?? '';
                if (sName.isNotEmpty && sPrice.isNotEmpty) {
                  pricesMap[sName] = 'PKR $sPrice';
                }
              }
            }

            final List<String> flavorsList = [];
            if (item['options'] is List) {
              for (final o in (item['options'] as List)) {
                final oName = o['option_name']?.toString() ?? '';
                if (oName.isNotEmpty) flavorsList.add(oName);
              }
            }

            Uint8List? itemBytes;
            if (imgPath.startsWith('data:image') || imgPath.contains(';base64,')) {
              try {
                itemBytes = base64Decode(imgPath.split(',').last);
                _deviceImageCache[imgPath] = itemBytes;
              } catch (_) {}
            }

            _customMenuItems.add({
              'id': item['id'],
              'name': itemName,
              'category': categoryName,
              'price': pVal,
              'description': item['description']?.toString() ?? '',
              'badge': item['is_veg'] == true ? 'Veg' : (item['is_spicy'] == true ? 'Hot & Spicy' : 'Chef Special'),
              'imagePath': imgPath,
              'imageBytes': itemBytes,
              'hasCustomDeviceImage': imgPath.isNotEmpty && !imgPath.startsWith('assets/'),
              'pricesMap': pricesMap,
              'flavorsList': flavorsList,
              'extras': '',
            });
          }
        }

        // Merge DB items with sub-menu lists if DB items exist
        if (dbSteaks.isNotEmpty) _steakItems = dbSteaks;
        if (dbBeefBurgers.isNotEmpty) _beefBurgers = dbBeefBurgers;
        if (dbChickenBurgers.isNotEmpty) _chickenBurgers = dbChickenBurgers;
        if (dbBroast.isNotEmpty) _brostItems = dbBroast;
        if (dbPasta.isNotEmpty) _pastaItems = dbPasta;
        if (dbPanini.isNotEmpty) _paniniItems = dbPanini;
        if (dbAppetizers.isNotEmpty) _appetizerItems = dbAppetizers;
        if (dbFries.isNotEmpty) _friesItems = dbFries;
        if (dbBeverages.isNotEmpty) _beveragesItems = dbBeverages;
        if (dbToppings.isNotEmpty) _extraToppingItems = dbToppings;
        if (dbHotBev.isNotEmpty) _hotBeveragesItems = dbHotBev;
        if (dbColdCoffee.isNotEmpty) _coldCoffeeItems = dbColdCoffee;
        if (dbIceCream.isNotEmpty) _iceCreamFlavors = dbIceCream;
        if (dbMocktails.isNotEmpty) _mocktailsItems = dbMocktails;
        if (dbMojito.isNotEmpty) _mojitoItems = dbMojito;
        if (dbSmoothies.isNotEmpty) _smoothiesItems = dbSmoothies;
        if (dbIceShakes.isNotEmpty) _iceShakesItems = dbIceShakes;
        if (dbMilkShakes.isNotEmpty) _milkShakesItems = dbMilkShakes;
        if (dbSoftDrinks.isNotEmpty) _softDrinksItems = dbSoftDrinks;
      });
    } catch (_) {}
  }

  void _initSubItems() {
    _pizzaSubCategories = [
      {
        'id': 'p1',
        'title': "Classic Pizza's",
        'imagePath': 'assets/images/Fajita.png',
        'prices': {'Small': 'PKR 849', 'Medium': 'PKR 1449', 'Large': 'PKR 1749', 'Family': 'PKR 2349'},
        'flavors': ['Fajita Pizza', 'Chicken Tikka', 'Malai Boti', 'Sausage Cheese', 'Hot & Spicy', 'Tandoori Bonfire'],
      },
      {
        'id': 'p2',
        'title': "Modern Pizza's",
        'imagePath': 'assets/images/Modern.png',
        'prices': {'Small': 'PKR 849', 'Medium': 'PKR 1549', 'Large': 'PKR 1999', 'Family': 'PKR 2499'},
        'flavors': ['Ring Pizza', 'Crown Crust', 'Pepperoni Passion', 'Doner Kebab', 'Kebab Stuffer', 'Cheese Stick', 'Chicken Stuffer'],
      },
      {
        'id': 'p3',
        'title': "Special Pizza's",
        'imagePath': 'assets/images/Special.png',
        'prices': {'Medium': 'PKR 1699', 'Large': 'PKR 2199', 'Family': 'PKR 2999'},
        'flavors': ['Arabic Crispy', 'Hungry Cheese Gold Pizza'],
      },
    ];

    _steakItems = [
      {'name': 'Tarragon', 'price': 'PKR 1499'},
      {'name': 'Mushroom', 'price': 'PKR 1499'},
      {'name': 'Twin Steak', 'price': 'PKR 1599'},
      {'name': 'Smoked BBQ', 'price': 'PKR 1499'},
      {'name': 'Hot Shot Jalapeno', 'price': 'PKR 1499'},
      {'name': 'Mexican Hot & Spicy', 'price': 'PKR 1499'},
    ];

    _beefBurgers = [
      {'name': 'Beef Cheese Stuff Burger', 'price': 'PKR 1349'},
      {'name': 'Hungry Stacker', 'price': 'PKR 1349'},
      {'name': 'The Smashroom', 'price': 'PKR 1099'},
      {'name': 'Mexicano Beef', 'price': 'PKR 999'},
      {'name': 'Classic Beef', 'price': 'PKR 999'},
    ];

    _chickenBurgers = [
      {'name': 'Hungry Special', 'price': 'PKR 899'},
      {'name': 'Crispy BBQ', 'price': 'PKR 999'},
      {'name': 'Juicy Lucy', 'price': 'PKR 899'},
      {'name': 'Student Burger', 'price': 'PKR 450'},
      {'name': 'Zeleto Zinger', 'price': 'PKR 549'},
      {'name': 'Zinger Burger', 'price': 'PKR 499'},
    ];

    _brostItems = [
      {'name': 'Half Broast (with Fries & Garlic Sauce)', 'price': 'PKR 1250'},
      {'name': 'Family Broast (with Fries & Garlic Sauce)', 'price': 'PKR 2400'},
    ];

    _pastaItems = [
      {'name': 'Chicken Alfredo', 'desc': 'Creamy Alfredo sauce, grilled chicken, parmesan cheese & fresh herbs.', 'price': 'PKR 999', 'badge': 'Chef Special'},
      {'name': 'Penne Arrabiata', 'desc': 'Penne pasta cooked in spicy Arrabiata sauce with Italian herbs & garlic.', 'price': 'PKR 999', 'badge': 'Spicy Italian'},
      {'name': 'Hungry Parmesan', 'desc': 'Signature parmesan pasta loaded with creamy cheese & seasonings.', 'price': 'PKR 1099', 'badge': 'Signature'},
    ];

    _paniniItems = [
      {'name': 'Cheesy Panini', 'price': 'PKR 1099'},
      {'name': 'Hungry Club', 'price': 'PKR 849'},
      {'name': 'Special BBQ', 'price': 'PKR 849'},
    ];

    _appetizerItems = [
      {'name': 'Nuggets (with Fries) - 6pcs', 'price': 'PKR 399', 'image': 'assets/images/Nuggets.png'},
      {'name': 'Crispy Wings - 6pcs', 'price': 'PKR 399', 'image': 'assets/images/Wings.png'},
      {'name': 'Peri-Peri Wings - 6pcs', 'price': 'PKR 499', 'image': 'assets/images/peri.png'},
      {'name': 'Honey BBQ Wings - 6pcs', 'price': 'PKR 499', 'image': 'assets/images/Honey.png'},
    ];

    _friesItems = [
      {'name': 'Hungry Loaded Fries', 'price': 'PKR 749', 'image': 'assets/images/Loaded.png'},
      {'name': 'Honey Mustard Fries', 'price': 'PKR 449', 'image': 'assets/images/Mustard.png'},
      {'name': 'Garlic Mayo Fries', 'price': 'PKR 499', 'image': 'assets/images/Garlic.png'},
      {'name': 'Masala Fries', 'price': 'PKR 299', 'image': 'assets/images/Masala.png'},
      {'name': 'Plain Fries', 'price': 'PKR 279', 'image': 'assets/images/Simple.png'},
      {'name': 'BBQ Fries', 'price': 'PKR 449', 'image': 'assets/images/BBQ_Fries.png'},
    ];

    _beveragesItems = [
      {'name': 'NR Coke', 'price': 'PKR 100', 'image': 'assets/images/Coke.png'},
      {'name': 'NR Sprite', 'price': 'PKR 100', 'image': 'assets/images/Sprite.png'},
      {'name': 'Coke Tin Pack', 'price': 'PKR 160', 'image': 'assets/images/CokeTin.png'},
      {'name': 'Sprite Tin Pack', 'price': 'PKR 160', 'image': 'assets/images/SpriteTin.png'},
      {'name': 'Mineral Water', 'price': 'PKR 80', 'image': 'assets/images/Mineral.png'},
    ];

    _extraToppingItems = [
      {'name': 'Cheese', 'price': 'PKR 200', 'image': 'assets/images/Cheese.png'},
      {'name': 'BBQ Sauce', 'price': 'PKR 150', 'image': 'assets/images/BBqSauce.png'},
      {'name': 'Garlic Mayo', 'price': 'PKR 150', 'image': 'assets/images/GarlicMayo.png'},
      {'name': 'Mash Potato', 'price': 'PKR 250', 'image': 'assets/images/MeshPatato.png'},
      {'name': 'Jalapeno Sauce', 'price': 'PKR 150', 'image': 'assets/images/Jalapino.png'},
      {'name': 'Honey Mustard', 'price': 'PKR 150', 'image': 'assets/images/HoneyMustord.png'},
    ];

    _hotBeveragesItems = [
      {'name': 'Cappuccino Coffee', 'price': 'PKR 599', 'image': 'assets/images/Capachino.png'},
      {'name': 'Americano', 'price': 'PKR 399', 'image': 'assets/images/Amercino.png'},
      {'name': 'Espresso Single Shot', 'price': 'PKR 399', 'image': 'assets/images/Expresso.png'},
      {'name': 'Espresso Double Shot', 'price': 'PKR 750', 'image': 'assets/images/ExpressoDouble.png'},
      {'name': 'Hot Chocolate', 'price': 'PKR 699', 'image': 'assets/images/Hot_Chocolate.png'},
      {'name': 'Mocha', 'price': 'PKR 650', 'image': 'assets/images/Mocha.png'},
      {'name': 'Latte', 'price': 'PKR 580', 'image': 'assets/images/Latte.png'},
      {'name': 'Mix Tea', 'price': 'PKR 200', 'image': 'assets/images/mix.png'},
      {'name': 'Green Tea', 'price': 'PKR 120', 'image': 'assets/images/Greentead.png'},
    ];

    _coldCoffeeItems = [
      {'name': 'Strawberry Iced Latte', 'price': 'PKR 599', 'image': 'assets/images/Strawberry.png'},
      {'name': 'Caramel Iced Latte', 'price': 'PKR 599', 'image': 'assets/images/Cerimal.png'},
      {'name': 'Vanilla Iced Latte', 'price': 'PKR 599', 'image': 'assets/images/Venala.png'},
      {'name': 'Mocha Iced Latte', 'price': 'PKR 599', 'image': 'assets/images/Mocha_Lead.png'},
      {'name': 'Iced Dark Chocolate', 'price': 'PKR 750', 'image': 'assets/images/ice shake.webp'},
    ];

    _iceCreamFlavors = ['Kulfa', 'Mango', 'Vanilla', 'Chocolate', 'Strawberry'];

    _mocktailsItems = [
      {'name': 'Pink Lady', 'price': 'PKR 590', 'image': 'assets/images/pink.png'},
      {'name': 'Pina Colada', 'price': 'PKR 650', 'image': 'assets/images/pina.png'},
      {'name': 'Zinga Lady', 'price': 'PKR 650', 'image': 'assets/images/Zinga.png'},
      {'name': 'Pineapple (with coconut)', 'price': 'PKR 590', 'image': 'assets/images/pineApple.png'},
      {'name': 'Amazon Blast', 'price': 'PKR 590', 'image': 'assets/images/Amazon.png'},
      {'name': 'Blue Lady Colada', 'price': 'PKR 590', 'image': 'assets/images/BlueLady.png'},
    ];

    _mojitoItems = [
      {'name': 'Blue Berry', 'price': 'PKR 450', 'image': 'assets/images/blueBerry.png'},
      {'name': 'Blue Lagoon', 'price': 'PKR 450', 'image': 'assets/images/Blue lagon.png'},
      {'name': 'Green Apple', 'price': 'PKR 450', 'image': 'assets/images/greenpple.png'},
      {'name': 'Strawberry', 'price': 'PKR 450', 'image': 'assets/images/Strawberry.png'},
      {'name': 'Watermelon', 'price': 'PKR 450', 'image': 'assets/images/WaterMellon.png'},
      {'name': 'Passion Fruit', 'price': 'PKR 450', 'image': 'assets/images/passon.png'},
    ];

    _smoothiesItems = [
      {'name': 'Mango', 'price': 'PKR 199', 'image': 'assets/images/MangoS.png'},
      {'name': 'Banana', 'price': 'PKR 199', 'image': 'assets/images/BananaS.png'},
      {'name': 'Mix Berry', 'price': 'PKR 199', 'image': 'assets/images/MixBerry.png'},
      {'name': 'Blueberry', 'price': 'PKR 199', 'image': 'assets/images/blueBerry.png'},
      {'name': 'Strawberry', 'price': 'PKR 199', 'image': 'assets/images/StrawBerryS.png'},
    ];

    _iceShakesItems = [
      {'name': 'Mango', 'price': 'PKR 590', 'image': 'assets/images/MangoI.png'},
      {'name': 'Vanilla', 'price': 'PKR 590', 'image': 'assets/images/VanalaI.png'},
      {'name': 'Caramel', 'price': 'PKR 590', 'image': 'assets/images/CarimalI.png'},
      {'name': 'Chocolate', 'price': 'PKR 590', 'image': 'assets/images/ChocolateI.png'},
      {'name': 'Strawberry', 'price': 'PKR 590', 'image': 'assets/images/StrawBerryI.png'},
      {'name': 'Special Kulfa', 'price': 'PKR 590', 'image': 'assets/images/KulfaI.png'},
    ];

    _milkShakesItems = [
      {'name': 'Apple', 'price': 'PKR 400', 'image': 'assets/images/apples.png'},
      {'name': 'Banana', 'price': 'PKR 400', 'image': 'assets/images/BananaShake.png'},
      {'name': 'Seasonal', 'price': 'PKR 400', 'image': 'assets/images/Sessional.png'},
      {'name': 'Strawberry', 'price': 'PKR 400', 'image': 'assets/images/StrawBerryS.png'},
    ];

    _softDrinksItems = [
      {'name': 'Fresh Lime', 'price': 'PKR 250', 'image': 'assets/images/FreshLime.png'},
      {'name': 'Mint Margarita', 'price': 'PKR 300', 'image': 'assets/images/Mint.png'},
    ];

    _dealsList.addAll([
      DealItem(
        id: 'deal_exclusive_1',
        title: 'EXCLUSIVE DEALS',
        subtitle: "You'll Love!",
        dealPrice: 2499.0,
        originalPrice: 3650.0,
        badgeText: 'EXCLUSIVE DEAL',
        imagePath: 'assets/images/image.jpg',
        description: 'Get 1 Large Flavored Crust Pizza, 1 Special Steaming Chicken Biryani, 1 Cheesy Grilled Panini, 2 Rich Ice Shakes, and 1 Chilled Beverage Bottle at an unbeatable deal price!',
        items: const [
          DealComponent(name: '1x Large Flavored Crust Pizza', category: 'Pizza', quantity: '1x', icon: Icons.local_pizza_rounded),
          DealComponent(name: '1x Special Chicken Biryani', category: 'Biryani', quantity: '1x', icon: Icons.rice_bowl_rounded),
          DealComponent(name: '1x Cheesy Panini Sandwich', category: 'Panini', quantity: '1x', icon: Icons.lunch_dining_rounded),
          DealComponent(name: '2x Strawberry & Vanilla Shakes', category: 'Shakes', quantity: '2x', icon: Icons.local_drink_rounded),
          DealComponent(name: '1x 1.5L Chilled Beverage Bottle', category: 'Bottles', quantity: '1x', icon: Icons.wine_bar_rounded),
        ],
      ),
      DealItem(
        id: 'deal_family_feast',
        title: 'FAMILY FEAST COMBO',
        subtitle: 'Mega Food • Mega Savings',
        dealPrice: 3299.0,
        originalPrice: 4800.0,
        badgeText: 'MEGA SAVINGS',
        imagePath: 'assets/images/Special.png',
        description: '2 Family Size Flavored Crust Pizzas, 4 Crispy Dajjaj Broast Chicken pieces, 1 Hungry Loaded Fries, and 1 Chilled 1.5L Coke Bottle.',
        items: const [
          DealComponent(name: '2x Family Size Pizzas', category: 'Pizza', quantity: '2x', icon: Icons.local_pizza_rounded),
          DealComponent(name: '4x Crispy Dajjaj Broast', category: 'Broast', quantity: '4x', icon: Icons.restaurant_rounded),
          DealComponent(name: '1x Hungry Loaded Fries', category: 'Fries', quantity: '1x', icon: Icons.fastfood_rounded),
          DealComponent(name: '1x 1.5L Coke Bottle', category: 'Bottles', quantity: '1x', icon: Icons.wine_bar_rounded),
        ],
      ),
      DealItem(
        id: 'deal_duo_craver',
        title: 'DUO CRAVER PACK',
        subtitle: 'Double Flavor Feast',
        dealPrice: 1649.0,
        originalPrice: 2300.0,
        badgeText: 'POPULAR',
        imagePath: 'assets/images/beef_burger_hero.jpg',
        description: '2 Gourmet Beef or Chicken Burgers, 1 Large Crispy Garlic Mayo Fries, and 2 Ice Cold Soft Drink cans.',
        items: const [
          DealComponent(name: '2x Gourmet Burgers', category: 'Burger', quantity: '2x', icon: Icons.lunch_dining_rounded),
          DealComponent(name: '1x Garlic Mayo Fries', category: 'Fries', quantity: '1x', icon: Icons.fastfood_rounded),
          DealComponent(name: '2x Cold Soft Drink Tins', category: 'Drinks', quantity: '2x', icon: Icons.local_drink_rounded),
        ],
      ),
    ]);
  }

  Future<void> _confirmDelete({
    required String title,
    required String itemName,
    required FutureOr<void> Function() onConfirm,
  }) async {
    final confirmed = await showConfirmDeleteDialog(
      context: context,
      title: title,
      itemName: itemName,
      itemType: 'Menu Catalog',
      description: 'Are you sure you want to delete "$itemName"? This item will be removed from active ordering.',
      confirmButtonText: 'DELETE',
    );

    if (confirmed) {
      await onConfirm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$itemName" deleted successfully!'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get canAddMenu {
    final role = ref.read(authProvider).currentUser.role;
    return ref.read(roleRightsProvider).isActionGranted(
      role,
      'menu_add',
      defaultIfMissing: role == UserRole.owner || role == UserRole.manager,
    );
  }

  bool get canEditMenu {
    final role = ref.read(authProvider).currentUser.role;
    return ref.read(roleRightsProvider).isActionGranted(
      role,
      'menu_edit',
      defaultIfMissing: role == UserRole.owner || role == UserRole.manager,
    );
  }

  bool get canDeleteMenu {
    final role = ref.read(authProvider).currentUser.role;
    return ref.read(roleRightsProvider).isActionGranted(
      role,
      'menu_delete',
      defaultIfMissing: role == UserRole.owner || role == UserRole.manager,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(roleRightsProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isOwnerOrManager = canAddMenu || canEditMenu || canDeleteMenu;

    // If a specific category is selected, render its dedicated full view screen in place!
    if (_selectedCategoryForDetails != null) {
      return _buildDedicatedCategoryScreen(_selectedCategoryForDetails!, isDark, isOwnerOrManager);
    }

    final filteredList = _allCategories.where((item) {
      final matchesCategory = _selectedCategoryKey == 'all' || item.categoryKey == _selectedCategoryKey;
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    children: [
                      TextSpan(
                        text: 'EXPLORE OUR ',
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
                      ),
                      const TextSpan(
                        text: 'MENU CATALOG',
                        style: TextStyle(color: AppColors.primaryRed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover delicious favorites, freshly prepared meals, refreshing beverages and irresistible treats.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // Search Bar and Filter Pills
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search delicious dishes...',
                            hintStyle: TextStyle(
                              color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryRed, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Dropdown Filter Button
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.borderGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategoryKey,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryRed),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCategoryKey = val);
                            }
                          },
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Row(
                                children: [
                                  Icon(Icons.grid_view_rounded, size: 16, color: AppColors.primaryRed),
                                  SizedBox(width: 8),
                                  Text('All Categories'),
                                ],
                              ),
                            ),
                            ..._allCategories.map(
                              (cat) => DropdownMenuItem(
                                value: cat.categoryKey,
                                child: Row(
                                  children: [
                                    Icon(cat.icon, size: 16, color: AppColors.primaryRed),
                                    const SizedBox(width: 8),
                                    Text(cat.name),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (canAddMenu) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _openAddDealDialog(context, isDark),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Deal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _openAddMenuItemDialog(context, isDark),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Menu Item'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Main Dishes Grid Showcase with Exclusive Deals Banner
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.restaurant_rounded, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No menu items found matching your search.',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedCategoryKey = 'all';
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Exclusive Deals Showcase Hero Banner (at top of menu)
                      if (_showExclusiveDealsBanner &&
                          _dealsList.isNotEmpty &&
                          (_selectedCategoryKey == 'all' || _selectedCategoryKey == 'deals') &&
                          _searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: _buildExclusiveDealsHeroBanner(isDark, isOwnerOrManager),
                          ),
                        ),

                      // Section Header if on 'all'
                      if (_selectedCategoryKey == 'all' && _searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
                            child: Row(
                              children: [
                                const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.primaryRed),
                                const SizedBox(width: 8),
                                Text(
                                  'EXPLORE CATEGORIES',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${filteredList.length} Categories',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Main Dishes Grid
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 3;
                            if (constraints.crossAxisExtent < 480) {
                              crossAxisCount = 1;
                            } else if (constraints.crossAxisExtent < 640) {
                              crossAxisCount = 2;
                            }

                            return SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.82,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = filteredList[index];
                                  return _buildDishCard(context, item, isDark);
                                },
                                childCount: filteredList.length,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Dedicated Category Full Screen View inside main area (preserves left sidebar!)
  Widget _buildDedicatedCategoryScreen(MenuCategoryItem category, bool isDark, bool isOwnerOrManager) {
    return Container(
      color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Dedicated Screen Top Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _selectedCategoryForDetails = null);
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Menu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const Spacer(),
                Text(
                  category.name.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                if (canAddMenu) ...[
                  const SizedBox(width: 16),
                  if (category.categoryKey == 'deals') ...[
                    ElevatedButton.icon(
                      onPressed: () => _openAddDealDialog(context, isDark),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add New Deal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () => _openAddMenuItemDialog(context, isDark, defaultCategory: category.name),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Add to ${category.name}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ],
                if (canDeleteMenu) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      _confirmDelete(
                        title: 'Delete Category',
                        itemName: category.name,
                        onConfirm: () {
                          setState(() {
                            _allCategories.removeWhere((c) => c.id == category.id);
                            _customMenuItems.removeWhere((c) => (c['category'] as String?).toString().toLowerCase() == category.name.toLowerCase());
                            _selectedCategoryForDetails = null;
                          });
                          ref.read(posProvider.notifier).deleteCategory(category.id, category.name);
                        },
                      );
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Category'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Scrollable Screen Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: _buildCategoryDetailContent(category, isDark, isOwnerOrManager),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(BuildContext context, MenuCategoryItem item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dish Image with Badge
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildImageWidget(
                      item.imagePath,
                      imageBytes: item.imageBytes,
                      fit: BoxFit.cover,
                      fallback: Container(
                        color: isDark ? const Color(0xFF334155) : AppColors.offWhite,
                        child: Icon(item.icon, size: 64, color: AppColors.primaryRed),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.brandYellow, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: AppColors.brandYellow, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            item.badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          _confirmDelete(
                            title: 'Delete Category',
                            itemName: item.name,
                            onConfirm: () {
                              setState(() {
                                _allCategories.removeWhere((c) => c.id == item.id);
                                _customMenuItems.removeWhere((c) => (c['category'] as String?).toString().toLowerCase() == item.name.toLowerCase());
                                if (_selectedCategoryForDetails?.id == item.id) {
                                  _selectedCategoryForDetails = null;
                                }
                              });
                              ref.read(posProvider.notifier).deleteCategory(item.id, item.name);
                            },
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dish Content
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _selectedCategoryForDetails = item);
                            },
                            iconAlignment: IconAlignment.end,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text('View All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                            tooltip: 'Delete ${item.name}',
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () {
                              _confirmDelete(
                                title: 'Delete Menu Category',
                                itemName: item.name,
                                onConfirm: () {
                                  setState(() {
                                    _allCategories.removeWhere((c) => c.id == item.id);
                                    _customMenuItems.removeWhere((c) => (c['category'] as String?).toString().toLowerCase() == item.name.toLowerCase());
                                    if (_selectedCategoryForDetails?.id == item.id) {
                                      _selectedCategoryForDetails = null;
                                    }
                                  });
                                  ref.read(posProvider.notifier).deleteCategory(item.id, item.name);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDetailContent(MenuCategoryItem category, bool isDark, bool isOwnerOrManager) {
    final customForCategory = _customMenuItems.where((item) {
      final itemCat = (item['category'] as String).toLowerCase();
      final targetCat = category.name.toLowerCase();
      return itemCat == targetCat || itemCat.contains(targetCat) || targetCat.contains(itemCat);
    }).toList();

    Widget builtInContent;
    switch (category.categoryKey) {
      case 'deals':
        builtInContent = _buildDealsDetails(isDark, isOwnerOrManager);
        break;
      case 'pizza':
        builtInContent = _buildPizzaDetails(isDark);
        break;
      case 'chicken-steak':
        builtInContent = _buildSteakDetails(isDark);
        break;
      case 'burger':
        builtInContent = _buildBurgerDetails(isDark);
        break;
      case 'dajjaj-brost':
        builtInContent = _buildBrostDetails(isDark);
        break;
      case 'pasta':
        builtInContent = _buildPastaDetails(isDark);
        break;
      case 'panini':
        builtInContent = _buildPaniniDetails(isDark);
        break;
      case 'appetizer':
        builtInContent = _buildAppetizersDetails(isDark);
        break;
      case 'fries':
        builtInContent = _buildFriesDetails(isDark);
        break;
      case 'beverages':
        builtInContent = _buildBeveragesDetails(isDark);
        break;
      case 'extra-topping':
        builtInContent = _buildExtraToppingsDetails(isDark);
        break;
      case 'hot-beverages':
        builtInContent = _buildHotBeveragesDetails(isDark);
        break;
      case 'cold-coffee':
        builtInContent = _buildColdCoffeeDetails(isDark);
        break;
      case 'ice-cream':
        builtInContent = _buildIceCreamDetails(isDark);
        break;
      case 'mocktails':
        builtInContent = _buildMocktailsDetails(isDark);
        break;
      case 'mojito':
        builtInContent = _buildMojitoDetails(isDark);
        break;
      case 'smoothies':
        builtInContent = _buildSmoothiesDetails(isDark);
        break;
      case 'ice-shakes':
        builtInContent = _buildIceShakesDetails(isDark);
        break;
      case 'milk-shakes':
        builtInContent = _buildMilkShakesDetails(isDark);
        break;
      case 'soft-drinks':
        builtInContent = _buildSoftDrinksDetails(isDark);
        break;
      default:
        builtInContent = Center(
          child: Text(
            '${category.name} Selection',
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary),
          ),
        );
    }

    if (customForCategory.isEmpty) return builtInContent;

    return Column(
      children: [
        builtInContent,
        const SizedBox(height: 24),
        _buildCustomAddedDishesSection(category.name, customForCategory, isDark),
      ],
    );
  }

  // 0. Deals & Combos Details Section
  Widget _buildDealsDetails(bool isDark, bool isOwnerOrManager) {
    if (_dealsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.local_offer_outlined, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                'No exclusive deals available currently.',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (canAddMenu)
                ElevatedButton.icon(
                  onPressed: () => _openAddDealDialog(context, isDark),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add First Exclusive Deal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'EXCLUSIVE DEALS & COMBOS',
          'Huge savings on family combos, student specials, and all-in-one meal packages.',
          isDark,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 2;
            if (constraints.maxWidth < 650) {
              crossAxisCount = 1;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: constraints.maxWidth < 650 ? 0.95 : 1.05,
              ),
              itemCount: _dealsList.length,
              itemBuilder: (context, index) {
                final deal = _dealsList[index];
                return _buildDealCard(deal, isDark, isOwnerOrManager);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDealCard(DealItem deal, bool isDark, bool isOwnerOrManager) {
    final double savings = (deal.originalPrice != null && deal.originalPrice! > deal.dealPrice)
        ? (deal.originalPrice! - deal.dealPrice)
        : 0;
    final int discountPercent = (deal.originalPrice != null && deal.originalPrice! > 0)
        ? (((deal.originalPrice! - deal.dealPrice) / deal.originalPrice!) * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image with Badges
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImageWidget(
                    deal.imagePath,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      child: const Icon(Icons.local_offer_rounded, size: 48, color: AppColors.primaryRed),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Badge Tag Top Left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            deal.badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Savings Tag Top Right
                  if (discountPercent > 0)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandYellow,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          'SAVE $discountPercent%',
                          style: const TextStyle(
                            color: AppColors.deepRed,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  // Title and Subtitle Overlay Bottom
                  Positioned(
                    bottom: 10,
                    left: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (deal.subtitle.isNotEmpty)
                          Text(
                            deal.subtitle,
                            style: const TextStyle(
                              color: AppColors.brandYellow,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Deal Content Body
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Included items category pills
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INCLUDED ITEMS:',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: deal.items.map((c) {
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(c.icon, size: 13, color: AppColors.primaryRed),
                                    const SizedBox(width: 4),
                                    Text(
                                      c.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          deal.description,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            fontSize: 11,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Pricing Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (deal.originalPrice != null && deal.originalPrice! > 0)
                              Text(
                                'PKR ${deal.originalPrice!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              'PKR ${deal.dealPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (savings > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save PKR ${savings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDealPopup(deal, isDark),
                            icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                            label: const Text('View Deal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                          ),
                        ),
                        if (canEditMenu) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primaryRed),
                            tooltip: 'Edit Deal',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            onPressed: () => _openAddDealDialog(context, isDark, existingDeal: deal),
                          ),
                        ],
                        if (canDeleteMenu) ...[
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                            tooltip: 'Delete Deal',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                            onPressed: () {
                              _confirmDelete(
                                title: 'Delete Deal',
                                itemName: deal.title,
                                onConfirm: () async {
                                  setState(() {
                                    _dealsList.removeWhere((d) => d.id == deal.id || d.title == deal.title);
                                    if (_activeDealIndex >= _dealsList.length && _dealsList.isNotEmpty) {
                                      _activeDealIndex = _dealsList.length - 1;
                                    }
                                  });
                                  ref.read(posProvider.notifier).deleteMenuItem(deal.id);
                                  try {
                                    await ref.read(menuApiServiceProvider).deleteDeal(deal.id);
                                  } catch (_) {}
                                  _loadCategoriesAndItemsFromBackend();
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Exclusive Deals Hero Banner (Matches Reference Image)
  Widget _buildExclusiveDealsHeroBanner(bool isDark, bool isOwnerOrManager) {
    if (_dealsList.isEmpty) return const SizedBox.shrink();

    final deal = _dealsList[_activeDealIndex % _dealsList.length];
    final discountPercent = (deal.originalPrice != null && deal.originalPrice! > 0)
        ? (((deal.originalPrice! - deal.dealPrice) / deal.originalPrice!) * 100).round()
        : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1A102F),
            Color(0xFF0B0F19),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.brandYellow.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background subtle ambient glows
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryRed.withValues(alpha: 0.15),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: 150,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandYellow.withValues(alpha: 0.1),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Brand Header Row
                  Row(
                    children: [
                      // Hungry Howie's Brand Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Text(
                          'H',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Hungry Howie's®",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'FLAVORED CRUST PIZZA',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Carousel dots if multiple deals
                      if (_dealsList.length > 1) ...[
                        Row(
                          children: List.generate(_dealsList.length, (idx) {
                            final isActive = idx == (_activeDealIndex % _dealsList.length);
                            return InkWell(
                              onTap: () => setState(() => _activeDealIndex = idx),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isActive ? 22 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.brandYellow : Colors.white24,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() {
                              _activeDealIndex = (_activeDealIndex - 1 + _dealsList.length) % _dealsList.length;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() {
                              _activeDealIndex = (_activeDealIndex + 1) % _dealsList.length;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        const SizedBox(width: 8),
                      ],

                      if (canEditMenu) ...[
                        ElevatedButton.icon(
                          onPressed: () => _openAddDealDialog(context, isDark, existingDeal: deal),
                          icon: const Icon(Icons.edit_rounded, size: 13),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.white24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (canDeleteMenu) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            _confirmDelete(
                              title: 'Delete Deal',
                              itemName: deal.title,
                              onConfirm: () async {
                                setState(() {
                                  _dealsList.removeWhere((d) => d.id == deal.id || d.title == deal.title);
                                  if (_activeDealIndex >= _dealsList.length && _dealsList.isNotEmpty) {
                                    _activeDealIndex = _dealsList.length - 1;
                                  }
                                });
                                ref.read(posProvider.notifier).deleteMenuItem(deal.id);
                                try {
                                  await ref.read(menuApiServiceProvider).deleteDeal(deal.id);
                                } catch (_) {}
                                _loadCategoriesAndItemsFromBackend();
                              },
                            );
                          },
                          icon: const Icon(Icons.delete_forever_rounded, size: 14),
                          label: const Text('Delete Deal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        tooltip: 'Dismiss Banner',
                        onPressed: () => setState(() => _showExclusiveDealsBanner = false),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Main Interactive Deal Body
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;

                      final leftContent = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Yellow Oval Badge with "EXCLUSIVE DEALS" & "You'll Love!"
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.brandYellow,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  deal.title.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  deal.subtitle.isNotEmpty ? deal.subtitle : "You'll Love!",
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Circular Category Icons Row (Pizza, Biryani, Panini, Shakes, Bottles)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: deal.items.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final item = entry.value;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            item.icon,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (idx < deal.items.length - 1)
                                      Container(
                                        height: 32,
                                        width: 1,
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                        color: Colors.white24,
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Pricing & Action Button Row
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // View Latest Deals Button
                              ElevatedButton.icon(
                                onPressed: () => _showDealPopup(deal, isDark),
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                label: const Text(
                                  'View Latest Deals',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.6),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),

                              if (discountPercent > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandYellow.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.brandYellow, width: 1),
                                  ),
                                  child: Text(
                                    'SAVE $discountPercent% OFF',
                                    style: const TextStyle(
                                      color: AppColors.brandYellow,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );

                      final rightImage = Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 180,
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 6)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: _buildImageWidget(
                                deal.imagePath,
                                fit: BoxFit.cover,
                                fallback: Container(
                                  color: Colors.black26,
                                  child: const Icon(Icons.local_pizza_rounded, size: 60, color: AppColors.brandYellow),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'PKR ${deal.dealPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 3, child: leftContent),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: rightImage),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leftContent,
                            const SizedBox(height: 16),
                            Center(child: rightImage),
                          ],
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Bottom Tagline: "MORE FOOD • MORE SAVINGS"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 40, height: 2, color: AppColors.brandYellow),
                      const SizedBox(width: 10),
                      const Text(
                        'MORE FOOD  •  MORE SAVINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 40, height: 2, color: AppColors.brandYellow),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Deal Popup (Identical to User Reference Image)
  void _showDealPopup(DealItem deal, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF090D16)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.brandYellow, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Header: Logo + Close Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('H', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Hungry Howie's®",
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            Text(
                              'FLAVORED CRUST PIZZA',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) {
                            if (!canEditMenu && !canDeleteMenu) return const SizedBox.shrink();

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canEditMenu)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _openAddDealDialog(context, isDark, existingDeal: deal);
                                    },
                                    icon: const Icon(Icons.edit_rounded, size: 13),
                                    label: const Text('Edit Deal'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                if (canEditMenu && canDeleteMenu)
                                  const SizedBox(width: 8),
                                if (canDeleteMenu)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _confirmDelete(
                                        title: 'Delete Deal',
                                        itemName: deal.title,
                                      onConfirm: () async {
                                        setState(() {
                                          _dealsList.removeWhere((d) => d.id == deal.id || d.title == deal.title);
                                          if (_activeDealIndex >= _dealsList.length && _dealsList.isNotEmpty) {
                                            _activeDealIndex = _dealsList.length - 1;
                                          }
                                        });
                                        ref.read(posProvider.notifier).deleteMenuItem(deal.id);
                                        try {
                                          await ref.read(menuApiServiceProvider).deleteDeal(deal.id);
                                        } catch (_) {}
                                        _loadCategoriesAndItemsFromBackend();
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.delete_forever_rounded, size: 14),
                                  label: const Text('Delete Deal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            );
                          },
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Main Content: Promo Details & Image
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 580;

                        final leftPromo = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Yellow Burst Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.brandYellow,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deal.title.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    deal.subtitle.isNotEmpty ? deal.subtitle : "You'll Love!",
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Round Red Category Icons
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: deal.items.map((item) {
                                return Column(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(item.icon, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.category,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 18),

                            // Detailed Breakdown
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PACKAGE INCLUDES:',
                                    style: TextStyle(color: AppColors.brandYellow, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  ...deal.items.map((it) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                it.name,
                                                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const SizedBox(height: 6),
                                  Text(
                                    deal.description,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Price Display
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (deal.originalPrice != null && deal.originalPrice! > 0)
                                      Text(
                                        'PKR ${deal.originalPrice!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    Text(
                                      'PKR ${deal.dealPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.brandYellow,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        );

                        final rightMedia = Container(
                          height: 240,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _buildImageWidget(
                              deal.imagePath,
                              fit: BoxFit.cover,
                              fallback: Container(
                                color: Colors.black26,
                                child: const Icon(Icons.local_pizza_rounded, size: 80, color: AppColors.brandYellow),
                              ),
                            ),
                          ),
                        );

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: leftPromo),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: rightMedia),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              rightMedia,
                              const SizedBox(height: 16),
                              leftPromo,
                            ],
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Tagline Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 35, height: 2, color: AppColors.brandYellow),
                        const SizedBox(width: 10),
                        const Text(
                          'MORE FOOD  •  MORE SAVINGS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(width: 35, height: 2, color: AppColors.brandYellow),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('pizza')) return Icons.local_pizza_rounded;
    if (cat.contains('burger')) return Icons.lunch_dining_rounded;
    if (cat.contains('broast') || cat.contains('brost') || cat.contains('chicken')) return Icons.restaurant_rounded;
    if (cat.contains('steak')) return Icons.dinner_dining_rounded;
    if (cat.contains('pasta')) return Icons.ramen_dining_rounded;
    if (cat.contains('panini') || cat.contains('sandwich')) return Icons.bakery_dining_rounded;
    if (cat.contains('appetizer') || cat.contains('wing') || cat.contains('nugget')) return Icons.tapas_rounded;
    if (cat.contains('fries')) return Icons.fastfood_rounded;
    if (cat.contains('drink') || cat.contains('beverage') || cat.contains('juice') || cat.contains('coke') || cat.contains('soda')) return Icons.local_drink_rounded;
    if (cat.contains('coffee') || cat.contains('tea')) return Icons.coffee_rounded;
    if (cat.contains('ice cream') || cat.contains('dessert') || cat.contains('shake')) return Icons.icecream_rounded;
    if (cat.contains('topping') || cat.contains('sauce')) return Icons.category_rounded;
    return Icons.fastfood_rounded;
  }

  void _openDealMenuSelectorDialog(
    BuildContext context,
    bool isDark,
    List<Map<String, dynamic>> components,
    void Function(void Function()) setDealDialogState,
  ) {
    final searchController = TextEditingController();
    String selectedCategory = 'All';
    String searchQuery = '';

    // Collect all available dishes across backend database items and POS items
    final List<Map<String, dynamic>> allDishes = [];
    final Set<String> seenNames = {};

    // 1. Backend loaded custom items
    for (final item in _customMenuItems) {
      final name = item['name']?.toString().trim() ?? '';
      final cat = item['category']?.toString().trim() ?? 'General';
      if (name.isNotEmpty && !seenNames.contains(name.toLowerCase()) && cat.toLowerCase() != 'deals' && cat.toLowerCase() != 'exclusive deals') {
        seenNames.add(name.toLowerCase());
        final priceVal = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        allDishes.add({
          'name': name,
          'category': cat,
          'price': priceVal,
          'imagePath': item['imagePath']?.toString() ?? '',
          'imageBytes': item['imageBytes'] as Uint8List?,
        });
      }
    }

    // 2. POS provider menu items (if not already added)
    try {
      final posItems = ref.read(posProvider).menuItems;
      for (final item in posItems) {
        final name = item.name.trim();
        final cat = item.category.trim();
        if (name.isNotEmpty && !seenNames.contains(name.toLowerCase()) && cat.toLowerCase() != 'deals' && cat.toLowerCase() != 'exclusive deals') {
          seenNames.add(name.toLowerCase());
          allDishes.add({
            'name': name,
            'category': cat,
            'price': item.basePrice,
            'imagePath': item.imageUrl,
            'imageBytes': null,
          });
        }
      }
    } catch (_) {}

    // 3. Fallback catalogue of core Hungry Howie's dishes if database is still initializing
    if (allDishes.isEmpty) {
      final defaultCatalogue = [
        {'name': 'Classic Fajita Pizza (Small)', 'category': 'Pizza', 'price': 849.0, 'imagePath': 'assets/images/Fajita.png'},
        {'name': 'Classic Fajita Pizza (Medium)', 'category': 'Pizza', 'price': 1449.0, 'imagePath': 'assets/images/Fajita.png'},
        {'name': 'Classic Fajita Pizza (Large)', 'category': 'Pizza', 'price': 1749.0, 'imagePath': 'assets/images/Fajita.png'},
        {'name': 'Classic Fajita Pizza (Family)', 'category': 'Pizza', 'price': 2349.0, 'imagePath': 'assets/images/Fajita.png'},
        {'name': 'Modern Crown Crust (Medium)', 'category': 'Pizza', 'price': 1549.0, 'imagePath': 'assets/images/Modern.png'},
        {'name': 'Modern Crown Crust (Large)', 'category': 'Pizza', 'price': 1999.0, 'imagePath': 'assets/images/Modern.png'},
        {'name': 'Special Arabic Crispy (Medium)', 'category': 'Pizza', 'price': 1699.0, 'imagePath': 'assets/images/Special.png'},
        {'name': 'Tarragon Chicken Steak', 'category': 'Steak', 'price': 1499.0, 'imagePath': 'assets/images/chicken_steak.png'},
        {'name': 'Mushroom Chicken Steak', 'category': 'Steak', 'price': 1499.0, 'imagePath': 'assets/images/chicken_steak.png'},
        {'name': 'Beef Cheese Stuff Burger', 'category': 'Burger', 'price': 1349.0, 'imagePath': 'assets/images/beef_burger_hero.jpg'},
        {'name': 'Hungry Stacker Beef Burger', 'category': 'Burger', 'price': 1349.0, 'imagePath': 'assets/images/beef_burger_hero.jpg'},
        {'name': 'Zinger Burger', 'category': 'Burger', 'price': 499.0, 'imagePath': 'assets/images/chicken_burger_hero.jpg'},
        {'name': 'Crispy BBQ Chicken Burger', 'category': 'Burger', 'price': 999.0, 'imagePath': 'assets/images/chicken_burger_hero.jpg'},
        {'name': 'Half Dajjaj Broast (with Fries)', 'category': 'Brost', 'price': 1250.0, 'imagePath': 'assets/images/broast_hero.jpg'},
        {'name': 'Family Dajjaj Broast (with Fries)', 'category': 'Brost', 'price': 2400.0, 'imagePath': 'assets/images/broast_hero.jpg'},
        {'name': 'Chicken Alfredo Pasta', 'category': 'Pasta', 'price': 999.0, 'imagePath': 'assets/images/pasta_hero.jpg'},
        {'name': 'Penne Arrabiata Pasta', 'category': 'Pasta', 'price': 999.0, 'imagePath': 'assets/images/penne.png'},
        {'name': 'Cheesy Panini Sandwich', 'category': 'Panini', 'price': 1099.0, 'imagePath': 'assets/images/panini_hero.jpg'},
        {'name': 'Hungry Club Panini', 'category': 'Panini', 'price': 849.0, 'imagePath': 'assets/images/panini_hero.jpg'},
        {'name': 'Chicken Nuggets (6pcs with Fries)', 'category': 'Appetizer', 'price': 399.0, 'imagePath': 'assets/images/Nuggets.png'},
        {'name': 'Crispy Chicken Wings (6pcs)', 'category': 'Appetizer', 'price': 399.0, 'imagePath': 'assets/images/Wings.png'},
        {'name': 'Hungry Loaded Fries', 'category': 'Fries', 'price': 749.0, 'imagePath': 'assets/images/Loaded.png'},
        {'name': 'Masala Fries', 'category': 'Fries', 'price': 299.0, 'imagePath': 'assets/images/Masala.png'},
        {'name': 'NR Coke', 'category': 'Drinks', 'price': 100.0, 'imagePath': 'assets/images/Coke.png'},
        {'name': 'NR Sprite', 'category': 'Drinks', 'price': 100.0, 'imagePath': 'assets/images/Sprite.png'},
        {'name': 'Coke Tin Pack', 'category': 'Drinks', 'price': 160.0, 'imagePath': 'assets/images/CokeTin.png'},
        {'name': 'Mint Margarita', 'category': 'Drinks', 'price': 300.0, 'imagePath': 'assets/images/Mint.png'},
        {'name': 'Cappuccino Coffee', 'category': 'Hot Coffee', 'price': 599.0, 'imagePath': 'assets/images/Capachino.png'},
        {'name': 'Strawberry Iced Latte', 'category': 'Cold Coffee', 'price': 599.0, 'imagePath': 'assets/images/Strawberry.png'},
      ];
      for (final d in defaultCatalogue) {
        if (!seenNames.contains((d['name'] as String).toLowerCase())) {
          seenNames.add((d['name'] as String).toLowerCase());
          allDishes.add({
            'name': d['name'] as String,
            'category': d['category'] as String,
            'price': d['price'] as double,
            'imagePath': d['imagePath'] as String,
            'imageBytes': null,
          });
        }
      }
    }

    // Build categories list for horizontal filter chips
    final List<String> categories = ['All'];
    for (final c in _allCategories) {
      if (c.categoryKey.toLowerCase() != 'deals' && c.name.toLowerCase() != 'exclusive deals') {
        if (!categories.contains(c.name)) categories.add(c.name);
      }
    }
    for (final dish in allDishes) {
      final cat = dish['category'] as String;
      if (!categories.contains(cat)) categories.add(cat);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (selectorCtx) => StatefulBuilder(
        builder: (ctx, setSelectorState) {
          final filtered = allDishes.where((dish) {
            final cat = dish['category'] as String;
            final matchesCategory = selectedCategory == 'All' || cat.toLowerCase() == selectedCategory.toLowerCase();
            final name = dish['name'] as String;
            final matchesQuery = searchQuery.isEmpty || name.toLowerCase().contains(searchQuery.toLowerCase());
            return matchesCategory && matchesQuery;
          }).toList();

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SELECT DISHES FOR DEAL PACKAGE',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.6),
                              ),
                              Text(
                                'Tap "+ ADD" to include any dish from the menu • ${components.length} item(s) selected so far',
                                style: const TextStyle(color: AppColors.brandYellow, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(selectorCtx),
                        ),
                      ],
                    ),
                  ),

                  // Search & Category Filters
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: searchController,
                            onChanged: (val) => setSelectorState(() => searchQuery = val.trim()),
                            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Search menu dishes by name (e.g. Fajita, Burger, Panini, Broast)...',
                              hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary, fontSize: 12),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primaryRed),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        searchController.clear();
                                        setSelectorState(() => searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = selectedCategory.toLowerCase() == cat.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryRed,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                  onSelected: (_) => setSelectorState(() => selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Menu Items Grid
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No dishes found matching "$searchQuery"',
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(14),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.7,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final dish = filtered[idx];
                              final dishName = dish['name'] as String;
                              final dishCat = dish['category'] as String;
                              final dishPrice = dish['price'] as double;
                              final dishImg = dish['imagePath'] as String;
                              final dishBytes = dish['imageBytes'] as Uint8List?;

                              // Count how many times this item is already in components
                              final addedCount = components.where((c) {
                                final cName = (c['nameController'] as TextEditingController).text.trim().toLowerCase();
                                return cName == dishName.toLowerCase();
                              }).length;

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: addedCount > 0
                                        ? AppColors.primaryRed
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: addedCount > 0 ? 1.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: _buildItemThumbnailForSelector(dishImg, dishBytes),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            dishName,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              height: 1.15,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  dishCat,
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'PKR ${dishPrice.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppColors.primaryRed,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Add / Quantity button
                                    if (addedCount > 0)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              final existingIdx = components.lastIndexWhere((c) =>
                                                  (c['nameController'] as TextEditingController).text.trim().toLowerCase() ==
                                                  dishName.toLowerCase());
                                              if (existingIdx != -1) {
                                                components.removeAt(existingIdx);
                                                setSelectorState(() {});
                                                setDealDialogState(() {});
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.remove_rounded, size: 14),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '$addedCount',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.primaryRed),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              components.add({
                                                'category': dishCat,
                                                'nameController': TextEditingController(text: dishName),
                                                'quantity': '1x',
                                                'icon': _getCategoryIcon(dishCat),
                                              });
                                              setSelectorState(() {});
                                              setDealDialogState(() {});
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryRed,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          components.add({
                                            'category': dishCat,
                                            'nameController': TextEditingController(text: dishName),
                                            'quantity': '1x',
                                            'icon': _getCategoryIcon(dishCat),
                                          });
                                          setSelectorState(() {});
                                          setDealDialogState(() {});
                                        },
                                        icon: const Icon(Icons.add_rounded, size: 14),
                                        label: const Text('ADD'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryRed,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${components.length} item(s) included in this deal',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(selectorCtx),
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('DONE / CONFIRM SELECTION'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemThumbnailForSelector(String path, Uint8List? bytes) {
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(bytes, width: 44, height: 44, fit: BoxFit.cover);
    }
    if (path.startsWith('data:image') || path.contains(';base64,')) {
      try {
        final b = base64Decode(path.split(',').last);
        return Image.memory(b, width: 44, height: 44, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _fallbackThumb(),
      );
    }
    if (path.isNotEmpty && !path.startsWith('http')) {
      return Image.asset(
        path,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _fallbackThumb(),
      );
    }
    return _fallbackThumb();
  }

  Widget _fallbackThumb() {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.primaryRed.withValues(alpha: 0.1),
      child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 20),
    );
  }

  // Add / Edit Deal Dialog
  void _openAddDealDialog(BuildContext context, bool isDark, {DealItem? existingDeal}) {
    final titleController = TextEditingController(text: existingDeal?.title ?? '');
    final subtitleController = TextEditingController(text: existingDeal?.subtitle ?? '');
    final dealPriceController = TextEditingController(text: existingDeal != null ? existingDeal.dealPrice.toStringAsFixed(0) : '');
    final originalPriceController = TextEditingController(text: existingDeal?.originalPrice != null ? existingDeal!.originalPrice!.toStringAsFixed(0) : '');
    final badgeController = TextEditingController(text: existingDeal?.badgeText ?? '');
    final descController = TextEditingController(text: existingDeal?.description ?? '');

    String selectedImage = existingDeal?.imagePath ?? 'assets/images/image.jpg';
    String? customDeviceImagePath = (existingDeal?.imagePath.startsWith('assets/') ?? true) ? null : existingDeal?.imagePath;
    final imagePathNotifier = ValueNotifier<String>(selectedImage);

    // Initial item components: start completely empty when creating a new deal
    final List<Map<String, dynamic>> components = existingDeal != null
        ? existingDeal.items
            .map((it) => {
                  'category': it.category,
                  'nameController': TextEditingController(text: it.name),
                  'icon': it.icon,
                })
            .toList()
        : [];

    final List<Map<String, String>> presetImages = [
      {'label': 'Feast Collage Image', 'path': 'assets/images/image.jpg'},
      ..._allCategories
          .where((c) => c.imagePath.isNotEmpty)
          .map((c) => {'label': c.name, 'path': c.imagePath}),
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dealP = double.tryParse(dealPriceController.text.trim()) ?? 0;
          final origP = double.tryParse(originalPriceController.text.trim()) ?? 0;
          final savingsVal = (origP > dealP) ? (origP - dealP) : 0;
          final pct = origP > 0 ? ((savingsVal / origP) * 100).round() : 0;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingDeal != null ? 'EDIT EXCLUSIVE DEAL' : 'CREATE EXCLUSIVE DEAL',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Create bundle deals with custom category icons & special pricing',
                                style: TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Form Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deal Title & Tagline Row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('DEAL TITLE / PROMO NAME *', isDark),
                                    const SizedBox(height: 6),
                                    _buildStyledTextField(
                                      controller: titleController,
                                      hint: 'e.g. EXCLUSIVE DEALS or FAMILY FEAST',
                                      icon: Icons.title_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('SUBTITLE / TAGLINE', isDark),
                                    const SizedBox(height: 6),
                                    _buildStyledTextField(
                                      controller: subtitleController,
                                      hint: "e.g. You'll Love!",
                                      icon: Icons.auto_awesome_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Pricing Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('DEAL PRICE (RS/-) *', isDark),
                                    const SizedBox(height: 6),
                                    _buildStyledTextField(
                                      controller: dealPriceController,
                                      hint: 'e.g. 2499',
                                      icon: Icons.attach_money_rounded,
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('ORIGINAL / REGULAR PRICE (RS/-)', isDark),
                                    const SizedBox(height: 6),
                                    _buildStyledTextField(
                                      controller: originalPriceController,
                                      hint: 'e.g. 3650',
                                      icon: Icons.price_change_outlined,
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('BADGE TEXT', isDark),
                                    const SizedBox(height: 6),
                                    _buildStyledTextField(
                                      controller: badgeController,
                                      hint: 'EXCLUSIVE DEAL',
                                      icon: Icons.local_fire_department_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Savings Live Indicator
                          if (savingsVal > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.savings_rounded, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Customer Saves: PKR ${savingsVal.toStringAsFixed(0)} ($pct% OFF DISCOUNT)',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Included Items Header & Select From Menu Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('INCLUDED DEAL ITEMS & DISHES *', isDark),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${components.length} dishes included in this package',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _openDealMenuSelectorDialog(context, isDark, components, setDialogState),
                                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                                label: const Text('SELECT FROM MENU'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Empty State if no items added yet
                          if (components.isEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.touch_app_outlined, color: isDark ? Colors.white38 : AppColors.textSecondary, size: 28),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No items added to deal yet.',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Click "SELECT FROM MENU" above to browse real dishes and add them to this deal.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Component Rows List
                          ...components.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final comp = entry.value;
                            final compNameController = comp['nameController'] as TextEditingController;
                            final compCategory = comp['category'] as String? ?? 'General';
                            final compIcon = (comp['icon'] as IconData?) ?? _getCategoryIcon(compCategory);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(compIcon, size: 16, color: const Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      compCategory,
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: compNameController,
                                      style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 12.5),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                        hintText: 'Item description (e.g. 1x Large Pizza)',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                                    onPressed: () {
                                      setDialogState(() {
                                        components.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 16),

                          // Description
                          _buildFieldLabel('DESCRIPTION / TERMS', isDark),
                          const SizedBox(height: 6),
                          _buildStyledTextField(
                            controller: descController,
                            hint: 'Full details of this exclusive combo deal...',
                            icon: Icons.description_rounded,
                            isDark: isDark,
                            maxLines: 2,
                          ),

                          const SizedBox(height: 16),

                          // Image Selection
                          _buildFieldLabel('DEAL BANNER IMAGE', isDark),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  child: _buildImageWidget(
                                    customDeviceImagePath ?? selectedImage,
                                    fit: BoxFit.cover,
                                    fallback: const Icon(Icons.image_rounded, color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: presetImages.any((img) => img['path'] == selectedImage) ? selectedImage : presetImages.first['path'],
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      isExpanded: true,
                                      items: presetImages
                                          .map((img) => DropdownMenuItem(
                                                value: img['path']!,
                                                child: Text(
                                                  img['label']!,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            selectedImage = val;
                                            customDeviceImagePath = null;
                                            imagePathNotifier.value = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                  if (picked != null) {
                                    final bytes = await picked.readAsBytes();
                                    final base64String = base64Encode(bytes);
                                    final dataUrl = 'data:image/jpeg;base64,$base64String';
                                    setState(() {
                                      _deviceImageCache[dataUrl] = bytes;
                                      _deviceImageCache[picked.path] = bytes;
                                    });
                                    setDialogState(() {
                                      customDeviceImagePath = dataUrl;
                                      selectedImage = dataUrl;
                                      imagePathNotifier.value = dataUrl;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Icon(Icons.upload_file_rounded, size: 18),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final title = titleController.text.trim();
                                final subtitle = subtitleController.text.trim();
                                final dealPrice = double.tryParse(dealPriceController.text.trim()) ?? 0;
                                final origPrice = double.tryParse(originalPriceController.text.trim());
                                final badge = badgeController.text.trim().isEmpty ? 'EXCLUSIVE DEAL' : badgeController.text.trim();
                                final desc = descController.text.trim().isEmpty
                                    ? 'Delicious exclusive meal combo package.'
                                    : descController.text.trim();

                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a Deal Title!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                if (dealPrice <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid Deal Price!'), backgroundColor: AppColors.danger),
                                  );
                                  return;
                                }

                                final finalItems = components.map((comp) {
                                  final nameC = comp['nameController'] as TextEditingController;
                                  final cat = comp['category'] as String;
                                  final icon = (comp['icon'] as IconData?) ?? _getCategoryIcon(cat);
                                  return DealComponent(
                                    name: nameC.text.trim().isEmpty ? cat : nameC.text.trim(),
                                    category: cat,
                                    icon: icon,
                                  );
                                }).toList();

                                String imagePathToSave = imagePathNotifier.value.isNotEmpty
                                    ? imagePathNotifier.value
                                    : (customDeviceImagePath ?? selectedImage);

                                if (_deviceImageCache.containsKey(imagePathToSave)) {
                                  final deviceImageBytes = _deviceImageCache[imagePathToSave];
                                  if (deviceImageBytes != null && !imagePathToSave.startsWith('data:image')) {
                                    imagePathToSave = 'data:image/jpeg;base64,${base64Encode(deviceImageBytes)}';
                                  }
                                }

                                final newDeal = DealItem(
                                  id: existingDeal?.id ?? 'deal_${DateTime.now().millisecondsSinceEpoch}',
                                  title: title,
                                  subtitle: subtitle,
                                  dealPrice: dealPrice,
                                  originalPrice: origPrice,
                                  badgeText: badge,
                                  imagePath: imagePathToSave,
                                  description: desc,
                                  items: finalItems,
                                );

                                setState(() {
                                  if (existingDeal != null) {
                                    final idx = _dealsList.indexWhere((d) => d.id == existingDeal.id);
                                    if (idx >= 0) {
                                      _dealsList[idx] = newDeal;
                                    } else {
                                      _dealsList.add(newDeal);
                                    }
                                  } else {
                                    _dealsList.insert(0, newDeal);
                                  }
                                });

                                // Sync with POS provider as a MenuItem
                                final posMenuItem = MenuItem(
                                  id: newDeal.id,
                                  name: newDeal.title,
                                  category: 'Deals',
                                  description: newDeal.description,
                                  basePrice: newDeal.dealPrice,
                                  imageUrl: newDeal.imagePath,
                                );
                                ref.read(posProvider.notifier).addMenuItem(posMenuItem);

                                final dealDto = {
                                  'title': newDeal.title,
                                  'subtitle': newDeal.subtitle,
                                  'deal_price': newDeal.dealPrice,
                                  if (newDeal.originalPrice != null) 'original_price': newDeal.originalPrice,
                                  'badge_text': newDeal.badgeText,
                                  'image_path': newDeal.imagePath,
                                  'description': newDeal.description,
                                  'is_available': true,
                                  'components': finalItems.map((c) => {
                                    'item_name': c.name,
                                    'category': c.category,
                                    'quantity': c.quantity,
                                  }).toList(),
                                };

                                try {
                                  final menuApi = ref.read(menuApiServiceProvider);
                                  if (existingDeal != null) {
                                    await menuApi.updateDeal(existingDeal.id, dealDto);
                                  } else {
                                    await menuApi.createDeal(dealDto);
                                  }
                                  await _loadCategoriesAndItemsFromBackend();
                                } catch (e) {
                                  debugPrint('Error saving deal to backend: $e');
                                }

                                if (!context.mounted) return;
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Exclusive Deal "$title" saved successfully!'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              label: Text(
                                existingDeal != null ? 'UPDATE & SAVE DEAL' : 'PUBLISH EXCLUSIVE DEAL',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFieldLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFFDC2626), size: 18),
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF64748B) : AppColors.textSecondary,
            fontSize: 12.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // 1. Pizza Details Section
  Widget _buildPizzaDetails(bool isDark) {
    if (_pizzaSubCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No pizza items in menu.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary)),
        ),
      );
    }

    return Column(
      children: [
        _buildSectionHeader('OUR PIZZA SELECTION', 'Crafted with premium ingredients, rich mozzarella & authentic secret spices', isDark),
        const SizedBox(height: 16),
        ..._pizzaSubCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final cat = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPizzaCard(
              title: cat['title'] as String,
              imagePath: cat['imagePath'] as String,
              prices: Map<String, String>.from(cat['prices'] as Map),
              flavors: List<String>.from(cat['flavors'] as List),
              isDark: isDark,
              onDeleteCard: () {
                _confirmDelete(
                  title: 'Delete Sub-Category',
                  itemName: cat['title'] as String,
                  onConfirm: () {
                    setState(() {
                      _pizzaSubCategories.removeAt(index);
                    });
                  },
                );
              },
              onDeleteFlavor: (flavor) {
                _confirmDelete(
                  title: 'Delete Pizza Flavor',
                  itemName: flavor,
                  onConfirm: () {
                    setState(() {
                      (cat['flavors'] as List).remove(flavor);
                    });
                  },
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // 2. Chicken Steak Details Section
  Widget _buildSteakDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('CHICKEN STEAK', 'Tender, juicy & perfectly grilled chicken steaks with signature seasoning & rich flavors.', isDark),
        const SizedBox(height: 16),
        _buildTableCard(
          title: 'CHICKEN STEAK MENU',
          items: _steakItems,
          isDark: isDark,
          onDeleteItem: (index, item) {
            setState(() {
              _steakItems.removeAt(index);
            });
            ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAddonBox('SERVED WITH:', 'Mash Potato / Plain', Icons.restaurant_menu_rounded, isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddonBox('EXTRA:', 'Crispy Cheesy Potato — PKR 150', Icons.local_dining_rounded, isDark),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Burger Details Section
  Widget _buildBurgerDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('OUR BURGER SELECTION', 'Crafted with premium ingredients, fresh vegetables, signature sauces, and perfectly grilled patties.', isDark),
        const SizedBox(height: 16),
        _buildTableCard(
          title: 'BEEF BURGERS',
          items: _beefBurgers,
          isDark: isDark,
          onDeleteItem: (index, item) {
            setState(() {
              _beefBurgers.removeAt(index);
            });
            ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: const [
              Text('EXTRA BEEF PATTY OPTIONS', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(height: 6),
              Text('150g (Same Price)  •  200g (PKR 150)  •  250g (PKR 250)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildTableCard(
          title: 'CHICKEN BURGERS',
          items: _chickenBurgers,
          isDark: isDark,
          onDeleteItem: (index, item) {
            setState(() {
              _chickenBurgers.removeAt(index);
            });
            ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
          },
        ),
      ],
    );
  }

  // 4. Dajjaj Brost Details Section
  Widget _buildBrostDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('DAJJAJ BROST', 'Golden crispy broast chicken, perfectly seasoned and freshly prepared for a delicious family meal.', isDark),
        const SizedBox(height: 16),
        _buildTableCard(
          title: 'DAJJAJ BROST MENU',
          items: _brostItems,
          isDark: isDark,
          onDeleteItem: (index, item) {
            setState(() {
              _brostItems.removeAt(index);
            });
            ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
          },
        ),
      ],
    );
  }

  // 5. Pasta Details Section
  Widget _buildPastaDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('OUR PASTA SELECTION', 'Freshly prepared pasta tossed in rich sauces, premium cheeses, and authentic Italian flavors.', isDark),
        const SizedBox(height: 16),
        ..._pastaItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(item['name']!, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          if (item['badge'] != null && item['badge']!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(item['badge']!, style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item['desc'] ?? '', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Text(item['price']!, style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  tooltip: 'Delete ${item['name']}',
                  onPressed: () {
                    _confirmDelete(
                      title: 'Delete Pasta Item',
                      itemName: item['name']!,
                      onConfirm: () {
                        setState(() {
                          _pastaItems.removeAt(index);
                        });
                        ref.read(posProvider.notifier).deleteMenuItem(item['name']!);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 6. Panini Details Section
  Widget _buildPaniniDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('OUR PANINI SELECTION', 'Freshly grilled panini sandwiches packed with premium ingredients, melted cheese, signature sauces, and authentic flavors.', isDark),
        const SizedBox(height: 16),
        _buildTableCard(
          title: 'PANINI SANDWICHES',
          items: _paniniItems,
          isDark: isDark,
          onDeleteItem: (index, item) {
            setState(() {
              _paniniItems.removeAt(index);
            });
            ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
          },
        ),
        const SizedBox(height: 14),
        _buildAddonBox('SERVED WITH EVERY ORDER:', 'Golden Crispy Fries & Fresh Daily Coleslaw', Icons.check_circle_outline_rounded, isDark),
      ],
    );
  }

  // 7. Appetizers Details Section
  Widget _buildAppetizersDetails(bool isDark) {
    return _buildGridItemsSection(
      'OUR APPETIZER SELECTION',
      'Perfect starters made with crispy coatings, bold flavors, premium seasonings, and delicious dipping sauces.',
      _appetizerItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _appetizerItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 8. Fries Details Section
  Widget _buildFriesDetails(bool isDark) {
    return _buildGridItemsSection(
      'OUR FRIES SELECTION',
      'Golden crispy fries loaded with delicious toppings, signature sauces, premium seasonings, and irresistible flavors.',
      _friesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _friesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 9. Beverages Details Section
  Widget _buildBeveragesDetails(bool isDark) {
    return _buildGridItemsSection(
      'OUR BEVERAGES SELECTION',
      'Refresh your meal with chilled beverages, soft drinks, and refreshing drinks served ice cold.',
      _beveragesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _beveragesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 10. Extra Topping Details Section
  Widget _buildExtraToppingsDetails(bool isDark) {
    return _buildGridItemsSection(
      'EXTRA TOPPING SELECTION',
      'Customize your favorite meal with delicious premium toppings and signature sauces.',
      _extraToppingItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _extraToppingItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 11. Hot Beverages Details Section
  Widget _buildHotBeveragesDetails(bool isDark) {
    return _buildGridItemsSection(
      'HOT BEVERAGES',
      'Warm, freshly prepared beverages crafted to perfectly complement your meal.',
      _hotBeveragesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _hotBeveragesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 12. Cold Coffee Details Section
  Widget _buildColdCoffeeDetails(bool isDark) {
    return _buildGridItemsSection(
      'COLD COFFEE',
      'Chilled, creamy and refreshing coffee creations crafted with premium flavors.',
      _coldCoffeeItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _coldCoffeeItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 13. Ice Cream Details Section
  Widget _buildIceCreamDetails(bool isDark) {
    return Column(
      children: [
        _buildSectionHeader('ICE CREAM SELECTION', 'Creamy, delicious scoops in your favorite classic and refreshing flavors.', isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('FLAVOR', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                  Row(
                    children: [
                      SizedBox(width: 90, child: Text('Single Scope', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 90, child: Text('Double Scope', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      SizedBox(width: 36),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              ..._iceCreamFlavors.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final flavor = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(flavor, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: [
                            const SizedBox(width: 90, child: Text('PKR 199', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13))),
                            const SizedBox(width: 90, child: Text('PKR 399', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13))),
                            SizedBox(
                              width: 36,
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                tooltip: 'Delete $flavor',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  _confirmDelete(
                                    title: 'Delete Ice Cream Flavor',
                                    itemName: flavor,
                                    onConfirm: () {
                                      setState(() {
                                        _iceCreamFlavors.removeAt(index);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 14. Mocktails Details Section
  Widget _buildMocktailsDetails(bool isDark) {
    return _buildGridItemsSection(
      'OUR MOCKTAILS',
      'Refreshing handcrafted mocktails bursting with vibrant flavors, fresh fruits and signature blends.',
      _mocktailsItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _mocktailsItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 15. Mojito Details Section
  Widget _buildMojitoDetails(bool isDark) {
    return _buildGridItemsSection(
      'REFRESHING MOJITOS',
      'Refreshing handcrafted mojitos blended with fresh fruit, mint, citrus and sparkling flavors.',
      _mojitoItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _mojitoItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 16. Smoothies Details Section
  Widget _buildSmoothiesDetails(bool isDark) {
    return _buildGridItemsSection(
      'CREAMY SMOOTHIES',
      'Fresh, creamy and delicious fruit smoothies blended to perfection.',
      _smoothiesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _smoothiesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 17. Ice Shakes Details Section
  Widget _buildIceShakesDetails(bool isDark) {
    return _buildGridItemsSection(
      'INDULGENT ICE SHAKES',
      'Rich, creamy and indulgent shakes blended with delicious flavors for the perfect sweet treat.',
      _iceShakesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _iceShakesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 18. Milk Shakes Details Section
  Widget _buildMilkShakesDetails(bool isDark) {
    return _buildGridItemsSection(
      'CLASSIC MILK SHAKES',
      'Creamy, chilled and delicious milk shakes blended with fresh flavors for the perfect sweet treat.',
      _milkShakesItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _milkShakesItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // 19. Soft Drinks Details Section
  Widget _buildSoftDrinksDetails(bool isDark) {
    return _buildGridItemsSection(
      'REFRESHING SOFT DRINKS',
      'Fresh, chilled and refreshing drinks crafted with citrus, mint and premium ingredients.',
      _softDrinksItems,
      isDark,
      onDeleteItem: (index, item) {
        setState(() {
          _softDrinksItems.removeAt(index);
        });
        ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
      },
    );
  }

  // Helper Widgets
  Widget _buildImageWidget(
    String path, {
    Uint8List? imageBytes,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    required Widget fallback,
  }) {
    // 1. Direct raw memory bytes (highest priority, 100% reliable across Web and Desktop)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    final cleanPath = path.trim();
    if (cleanPath.isEmpty) return fallback;

    // 2. In-memory device cache
    if (_deviceImageCache.containsKey(cleanPath) && _deviceImageCache[cleanPath]!.isNotEmpty) {
      return Image.memory(
        _deviceImageCache[cleanPath]!,
        key: ValueKey('mem_${cleanPath.hashCode}'),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // 3. Data URI (Base64 encoded images stored permanently in PostgreSQL database)
    if (cleanPath.startsWith('data:image') || cleanPath.contains(';base64,')) {
      try {
        final base64Data = cleanPath.split(',').last;
        final decoded = base64Decode(base64Data);
        _deviceImageCache[cleanPath] = decoded;
        return Image.memory(
          decoded,
          key: ValueKey('data_${cleanPath.hashCode}'),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    // 4. Asset images
    if (cleanPath.startsWith('assets/')) {
      return Image.asset(
        cleanPath,
        key: ValueKey(cleanPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // 5. Network and Blob URLs (Blob URLs are created by web image picker e.g. blob:http://...)
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://') || cleanPath.startsWith('blob:')) {
      return Image.network(
        cleanPath,
        key: ValueKey(cleanPath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return fallback;
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPizzaCard({
    required String title,
    required String imagePath,
    Uint8List? imageBytes,
    required Map<String, String> prices,
    required List<String> flavors,
    required bool isDark,
    VoidCallback? onDeleteCard,
    Function(String flavor)? onDeleteFlavor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImageWidget(
                  imagePath,
                  imageBytes: imageBytes,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  fallback: Container(
                    width: 50,
                    height: 50,
                    color: AppColors.primaryRed.withValues(alpha: 0.1),
                    child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primaryRed),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (onDeleteCard != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                  tooltip: 'Delete $title',
                  onPressed: onDeleteCard,
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Price Table
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: prices.entries
                  .map(
                    (e) => Column(
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryRed)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('FLAVORS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: flavors
                .map(
                  (f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onDeleteFlavor != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => onDeleteFlavor(f),
                            child: const Icon(Icons.close_rounded, size: 13, color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard({
    required String title,
    required List<Map<String, String>> items,
    required bool isDark,
    Function(int index, Map<String, String> item)? onDeleteItem,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Red Top Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    'Price',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Sub-category Rows
            ...items.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                                  : const Color(0xFFF1F5F9),
                              width: 1,
                            ),
                          ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name']!,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primaryRed.withValues(alpha: 0.18)
                              : const Color(0xFFFFF0F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          item['price']!,
                          style: const TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (onDeleteItem != null && canDeleteMenu) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          tooltip: 'Delete ${item['name']}',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            _confirmDelete(
                              title: 'Delete Item',
                              itemName: item['name'] ?? 'Item',
                              onConfirm: () => onDeleteItem(index, item),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonBox(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItemsSection(
    String title,
    String subtitle,
    List<Map<String, dynamic>> items,
    bool isDark, {
    bool showHeader = true,
    Function(int index, Map<String, dynamic> item)? onDeleteItem,
  }) {
    return Column(
      children: [
        if (showHeader && title.isNotEmpty) ...[
          _buildSectionHeader(title, subtitle, isDark),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 2;
            if (constraints.maxWidth < 550) {
              crossAxisCount = 1;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 84,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final imagePath = (item['image'] ?? item['imagePath'] ?? '').toString();
                final Uint8List? imageBytes = item['imageBytes'] as Uint8List?;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImageWidget(
                          imagePath,
                          imageBytes: imageBytes,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          fallback: Container(
                            width: 56,
                            height: 56,
                            color: AppColors.primaryRed.withValues(alpha: 0.1),
                            child: const Icon(Icons.fastfood_rounded, color: AppColors.primaryRed, size: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['price']!,
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onDeleteItem != null) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                          tooltip: 'Delete ${item['name']}',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            _confirmDelete(
                              title: 'Delete Item',
                              itemName: item['name'] ?? 'Item',
                              onConfirm: () => onDeleteItem(index, item),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomAddedDishesSection(String categoryName, List<Map<String, dynamic>> items, bool isDark) {
    final multiSizeItems = <Map<String, dynamic>>[];
    final imageGridItems = <Map<String, dynamic>>[];
    final simpleListItems = <Map<String, String>>[];

    for (var item in items) {
      final Map<String, String> prices = item['pricesMap'] is Map
          ? Map<String, String>.from(item['pricesMap'])
          : {};
      final List<String> flavors = item['flavorsList'] is List
          ? List<String>.from(item['flavorsList'])
          : [];

      final hasMultipleSizes = prices.length > 1;
      final hasFlavors = flavors.isNotEmpty;
      final pVal = item['price'] != null ? (item['price'] as double).toStringAsFixed(0) : '1499';
      final pText = prices.isNotEmpty ? prices.values.first : 'PKR $pVal';
      final imageStr = (item['imagePath'] as String?);
      final imageBytes = item['imageBytes'] as Uint8List?;
      final hasImage = (imageStr != null && imageStr.isNotEmpty) || imageBytes != null;

      if (hasMultipleSizes || hasFlavors) {
        multiSizeItems.add(item);
      } else if (hasImage) {
        imageGridItems.add({
          'name': item['name'] ?? 'Custom Item',
          'price': pText,
          'image': imageStr ?? '',
          'imageBytes': imageBytes,
        });
      } else {
        simpleListItems.add({
          'name': item['name'] ?? 'Custom Item',
          'price': pText,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (multiSizeItems.isNotEmpty)
          ...multiSizeItems.map((item) {
            final Map<String, String> prices = item['pricesMap'] is Map
                ? Map<String, String>.from(item['pricesMap'])
                : {'Price': 'PKR ${(item['price'] ?? 999.0).toStringAsFixed(0)}'};
            final List<String> flavors = item['flavorsList'] is List
                ? List<String>.from(item['flavorsList'])
                : [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPizzaCard(
                title: item['name'] ?? 'Custom Sub-Category',
                imagePath: item['imagePath'] ?? 'assets/images/Fajita.png',
                imageBytes: item['imageBytes'] as Uint8List?,
                prices: prices.isEmpty ? {'Price': 'PKR 999'} : prices,
                flavors: flavors.isEmpty ? ['Standard'] : flavors,
                isDark: isDark,
                onDeleteCard: () {
                  _confirmDelete(
                    title: 'Delete Custom Dish',
                    itemName: item['name'] ?? 'Custom Sub-Category',
                    onConfirm: () {
                      setState(() {
                        _customMenuItems.remove(item);
                      });
                      ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
                    },
                  );
                },
                onDeleteFlavor: (flavor) {
                  _confirmDelete(
                    title: 'Delete Flavor',
                    itemName: flavor,
                    onConfirm: () {
                      setState(() {
                        if (item['flavorsList'] is List) {
                          (item['flavorsList'] as List).remove(flavor);
                        }
                      });
                    },
                  );
                },
              ),
            );
          }),
        if (imageGridItems.isNotEmpty) ...[
          if (multiSizeItems.isNotEmpty) const SizedBox(height: 16),
          _buildGridItemsSection(
            '',
            '',
            imageGridItems,
            isDark,
            showHeader: false,
            onDeleteItem: (index, item) {
              setState(() {
                _customMenuItems.removeWhere((c) => c['name'] == item['name']);
              });
              ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
            },
          ),
        ],
        if (simpleListItems.isNotEmpty) ...[
          if (multiSizeItems.isNotEmpty || imageGridItems.isNotEmpty) const SizedBox(height: 16),
          _buildTableCard(
            title: categoryName.toUpperCase(),
            items: simpleListItems,
            isDark: isDark,
            onDeleteItem: (index, item) {
              setState(() {
                _customMenuItems.removeWhere((c) => c['name'] == item['name']);
              });
              ref.read(posProvider.notifier).deleteMenuItem(item['name'] ?? '');
            },
          ),
        ],
      ],
    );
  }

  void _openAddMenuItemDialog(BuildContext context, bool isDark, {String? defaultCategory, String initialMode = 'existing'}) {
    String currentMode = initialMode; // 'existing' or 'new_category'

    // Controllers for "Add in Existing Category"
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    final List<SizePricePair> sizePricePairs = [
      SizePricePair(),
    ];

    final List<TextEditingController> flavorsControllers = [
      TextEditingController(),
    ];

    final badgeController = TextEditingController();
    final extrasController = TextEditingController();
    final descriptionController = TextEditingController();

    // Controllers for "Add New Category"
    final newCategoryNameController = TextEditingController();
    final newCategoryDescController = TextEditingController();

    String selectedCategory = defaultCategory ?? (_allCategories.isNotEmpty ? _allCategories.first.name : 'Pizza');
    String selectedImage = ''; // Default No Image selected
    String? customDeviceImagePath;

    // ValueNotifiers ensure save button always reads latest image path regardless of rebuild
    final newCategoryImageNotifier = ValueNotifier<String>('');
    final existingItemImageNotifier = ValueNotifier<String>('');

    String newCategoryImage = ''; // Default No Image selected
    String newCategoryBadge = 'Category';
    String? customNewCategoryDeviceImagePath;
    Uint8List? pickedNewCategoryBytes;
    Uint8List? pickedExistingItemBytes;

    final presetImages = [
      {'label': 'No Image (None)', 'path': ''},
      {'label': 'Fajita Pizza', 'path': 'assets/images/Fajita.png'},
      {'label': 'Modern Crown Pizza', 'path': 'assets/images/Modern.png'},
      {'label': 'Special Gold Pizza', 'path': 'assets/images/Special.png'},
      {'label': 'Chicken Steak', 'path': 'assets/images/chicken_steak.png'},
      {'label': 'Beef Burger', 'path': 'assets/images/beef_burger_hero.jpg'},
      {'label': 'Chicken Burger', 'path': 'assets/images/chicken_burger_hero.jpg'},
      {'label': 'Dajjaj Brost', 'path': 'assets/images/broast_hero.jpg'},
      {'label': 'Pasta', 'path': 'assets/images/pasta_hero.jpg'},
      {'label': 'Panini', 'path': 'assets/images/panini_hero.jpg'},
      {'label': 'Appetizer Platter', 'path': 'assets/images/appetizer_hero.jpg'},
      {'label': 'Fries', 'path': 'assets/images/fries_hero.jpg'},
      {'label': 'Cold Beverage', 'path': 'assets/images/beverages_hero.jpg'},
      {'label': 'Hot Cappuccino', 'path': 'assets/images/Capachino.png'},
      {'label': 'Ice Cream', 'path': 'assets/images/ice_cream_hero.jpg'},
      {'label': 'Blueberry Mojito', 'path': 'assets/images/blueBerry.png'},
      {'label': 'Smoothie', 'path': 'assets/images/Smooth.png'},
      {'label': 'Ice Shake', 'path': 'assets/images/ice shake.webp'},
      {'label': 'Milkshake', 'path': 'assets/images/Milk shake.png'},
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categoriesList = _allCategories.map((c) => c.name).toList();
          if (!categoriesList.contains(selectedCategory) && categoriesList.isNotEmpty) {
            selectedCategory = categoriesList.first;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Brand Gradient Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            currentMode == 'new_category' ? Icons.create_new_folder_rounded : Icons.restaurant_menu_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    currentMode == 'new_category' ? 'ADD NEW CATEGORY' : 'ADD IN EXISTING CATEGORY',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandYellow,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'CATALOG',
                                      style: TextStyle(
                                        color: AppColors.deepRed,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentMode == 'new_category'
                                    ? 'Create a brand new menu category section & preset profile'
                                    : 'Add dish sub-item, sizes, flavors & extra options to menu',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),

                  // 2. Dual Action Mode Switcher Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => currentMode = 'existing'),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                gradient: currentMode == 'existing' ? AppColors.brandGradient : null,
                                color: currentMode == 'existing'
                                    ? null
                                    : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: currentMode == 'existing'
                                      ? AppColors.primaryRed
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                boxShadow: currentMode == 'existing'
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.post_add_rounded,
                                    size: 18,
                                    color: currentMode == 'existing'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add in Existing Category',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: currentMode == 'existing'
                                          ? Colors.white
                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => currentMode = 'new_category'),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                gradient: currentMode == 'new_category' ? AppColors.brandGradient : null,
                                color: currentMode == 'new_category'
                                    ? null
                                    : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: currentMode == 'new_category'
                                      ? AppColors.primaryRed
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                ),
                                boxShadow: currentMode == 'new_category'
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryRed.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 18,
                                    color: currentMode == 'new_category'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add New Category',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: currentMode == 'new_category'
                                          ? Colors.white
                                          : (isDark ? Colors.white : AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Form Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: currentMode == 'new_category'
                          ? _buildNewCategoryForm(
                              context: context,
                              dialogContext: dialogContext,
                              isDark: isDark,
                              setDialogState: setDialogState,
                              nameController: newCategoryNameController,
                              descController: newCategoryDescController,
                              selectedImage: newCategoryImage,
                              customDeviceImagePath: customNewCategoryDeviceImagePath,
                              deviceImageBytes: pickedNewCategoryBytes,
                              selectedBadge: newCategoryBadge,
                              presetImages: presetImages,
                              imagePathNotifier: newCategoryImageNotifier,
                              onSelectImage: (val) {
                                setDialogState(() {
                                  newCategoryImage = val;
                                  newCategoryImageNotifier.value = val;
                                  if (val.isEmpty || presetImages.any((img) => img['path'] == val)) {
                                    customNewCategoryDeviceImagePath = null;
                                    pickedNewCategoryBytes = null;
                                  } else {
                                    customNewCategoryDeviceImagePath = val;
                                  }
                                });
                              },
                              onPickDeviceImage: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                  maxWidth: 600,
                                  maxHeight: 600,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  final base64String = base64Encode(bytes);
                                  final dataUrl = 'data:image/jpeg;base64,$base64String';
                                  _deviceImageCache[dataUrl] = bytes;
                                  _deviceImageCache[picked.path] = bytes;
                                  newCategoryImageNotifier.value = dataUrl;
                                  setDialogState(() {
                                    pickedNewCategoryBytes = bytes;
                                    customNewCategoryDeviceImagePath = picked.path;
                                    newCategoryImage = dataUrl;
                                  });
                                }
                              },
                              onClearDeviceImage: () {
                                setDialogState(() {
                                  pickedNewCategoryBytes = null;
                                  customNewCategoryDeviceImagePath = null;
                                  newCategoryImage = '';
                                });
                              },
                            )
                          : _buildExistingCategoryForm(
                              context: context,
                              dialogContext: dialogContext,
                              isDark: isDark,
                              setDialogState: setDialogState,
                              nameController: nameController,
                              priceController: priceController,
                              sizePricePairs: sizePricePairs,
                              flavorsControllers: flavorsControllers,
                              extrasController: extrasController,
                              descController: descriptionController,
                              badgeController: badgeController,
                              selectedCategory: selectedCategory,
                              onCategoryChanged: (val) {
                                setDialogState(() {
                                  selectedCategory = val;
                                });
                              },
                              selectedImage: selectedImage,
                              customDeviceImagePath: customDeviceImagePath,
                              deviceImageBytes: pickedExistingItemBytes,
                              categoriesList: categoriesList,
                              presetImages: presetImages,
                              imagePathNotifier: existingItemImageNotifier,
                              onSelectImage: (val) {
                                setDialogState(() {
                                  selectedImage = val;
                                  existingItemImageNotifier.value = val;
                                  if (val.isEmpty || presetImages.any((img) => img['path'] == val)) {
                                    customDeviceImagePath = null;
                                    pickedExistingItemBytes = null;
                                  } else {
                                    customDeviceImagePath = val;
                                  }
                                });
                              },
                              onPickDeviceImage: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                  maxWidth: 600,
                                  maxHeight: 600,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  final base64String = base64Encode(bytes);
                                  final dataUrl = 'data:image/jpeg;base64,$base64String';
                                  _deviceImageCache[dataUrl] = bytes;
                                  _deviceImageCache[picked.path] = bytes;
                                  existingItemImageNotifier.value = dataUrl;
                                  setDialogState(() {
                                    pickedExistingItemBytes = bytes;
                                    customDeviceImagePath = picked.path;
                                    selectedImage = dataUrl;
                                  });
                                }
                              },
                              onClearDeviceImage: () {
                                setDialogState(() {
                                  pickedExistingItemBytes = null;
                                  customDeviceImagePath = null;
                                  selectedImage = '';
                                });
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewCategoryForm({
    required BuildContext context,
    required BuildContext dialogContext,
    required bool isDark,
    required StateSetter setDialogState,
    required TextEditingController nameController,
    required TextEditingController descController,
    required String selectedImage,
    required String? customDeviceImagePath,
    Uint8List? deviceImageBytes,
    required String selectedBadge,
    required List<Map<String, String>> presetImages,
    required ValueNotifier<String> imagePathNotifier,
    required ValueChanged<String> onSelectImage,
    required Future<void> Function() onPickDeviceImage,
    required VoidCallback onClearDeviceImage,
  }) {
    final displayDevicePath = customDeviceImagePath ?? (selectedImage.isNotEmpty && !presetImages.any((img) => img['path'] == selectedImage) ? selectedImage : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Name
        Row(
          children: [
            const Icon(Icons.create_new_folder_rounded, size: 16, color: AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              'CATEGORY NAME',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Special Desserts & Mocktails',
            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.category_rounded, size: 20, color: AppColors.primaryRed),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Category Description
        Row(
          children: [
            const Icon(Icons.description_rounded, size: 16, color: AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              'CATEGORY DESCRIPTION',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descController,
          maxLines: 2,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Handcrafted sweets, ice cream scoops, cold thick shakes & fruit drinks.',
            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Category Image Preset & Device Image Upload Row
        Row(
          children: [
            const Icon(Icons.image_rounded, size: 16, color: AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              'CATEGORY BANNER IMAGE',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // If device image is selected → show filename chip + clear button
        if (displayDevicePath != null || deviceImageBytes != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildImageWidget(
                    displayDevicePath ?? '',
                    imageBytes: deviceImageBytes,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    fallback: const Icon(Icons.photo_library_rounded, size: 22, color: AppColors.primaryRed),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Device Image Selected', style: TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                      Text(
                        displayDevicePath != null ? displayDevicePath.split(RegExp(r'[/\\]')).last : 'Custom Image',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClearDeviceImage,
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.danger),
                  tooltip: 'Remove device image',
                ),
              ],
            ),
          ),
        ] else ...[
          // Dropdown for preset images (only shown when no device image selected)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: presetImages.any((img) => img['path'] == selectedImage) ? selectedImage : '',
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryRed),
                      items: presetImages.map((img) => DropdownMenuItem(
                        value: img['path']!,
                        child: Text(
                          img['label']!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) onSelectImage(val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onPickDeviceImage,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Device Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],


        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                final catName = nameController.text.trim();
                final catDesc = descController.text.trim().isEmpty
                    ? 'Delicious menu collection of $catName.'
                    : descController.text.trim();

                if (catName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter category name!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                // Compute image path freshly at save time from notifier
                String saveImagePath = imagePathNotifier.value.isNotEmpty
                    ? imagePathNotifier.value
                    : (selectedImage.isNotEmpty
                        ? selectedImage
                        : (customDeviceImagePath != null && customDeviceImagePath.isNotEmpty
                            ? customDeviceImagePath
                            : ''));

                if (deviceImageBytes != null && !saveImagePath.startsWith('data:image') && !saveImagePath.startsWith('assets/')) {
                  saveImagePath = 'data:image/jpeg;base64,${base64Encode(deviceImageBytes)}';
                }

                final key = catName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
                final badgeText = catName.length > 10 ? '${catName.substring(0, 8)}..' : catName;
                final newCategoryItem = MenuCategoryItem(
                  id: key,
                  name: catName,
                  categoryKey: key,
                  badgeText: badgeText,
                  imagePath: saveImagePath,
                  imageBytes: deviceImageBytes,
                  description: catDesc,
                  icon: Icons.category_rounded,
                );

                setState(() {
                  _allCategories.add(newCategoryItem);
                });

                // Persist category to PostgreSQL database
                ref.read(posProvider.notifier).addCategory(
                  id: key,
                  name: catName,
                  badgeText: badgeText,
                  imagePath: saveImagePath,
                  description: catDesc,
                ).then((_) => _loadCategoriesAndItemsFromBackend());

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New Category "$catName" created and added to Menu successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: const Text(
                'SAVE & CREATE CATEGORY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildExistingCategoryForm({
    required BuildContext context,
    required BuildContext dialogContext,
    required bool isDark,
    required StateSetter setDialogState,
    required TextEditingController nameController,
    required TextEditingController priceController,
    required List<SizePricePair> sizePricePairs,
    required List<TextEditingController> flavorsControllers,
    required TextEditingController extrasController,
    required TextEditingController descController,
    required TextEditingController badgeController,
    required String selectedCategory,
    required ValueChanged<String> onCategoryChanged,
    required String selectedImage,
    required String? customDeviceImagePath,
    Uint8List? deviceImageBytes,
    required List<String> categoriesList,
    required List<Map<String, String>> presetImages,
    required ValueNotifier<String> imagePathNotifier,
    required ValueChanged<String> onSelectImage,
    required Future<void> Function() onPickDeviceImage,
    required VoidCallback onClearDeviceImage,
  }) {
    final displayDevicePath = customDeviceImagePath ?? (selectedImage.isNotEmpty && !presetImages.any((img) => img['path'] == selectedImage) ? selectedImage : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Selection Dropdown
        Row(
          children: [
            const Icon(Icons.category_rounded, size: 16, color: AppColors.primaryRed),
            const SizedBox(width: 6),
            Text(
              'SELECT CATEGORY',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: categoriesList.contains(selectedCategory) ? selectedCategory : (categoriesList.isNotEmpty ? categoriesList.first : null),
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryRed),
              items: categoriesList
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) onCategoryChanged(val);
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Sub Item Name & Single Price Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fastfood_rounded, size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        'SUB ITEM / DISH NAME',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Classic Pizza\'s or Tarragon Steak',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12.5),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_rounded, size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        'DEFAULT PRICE (RS/-)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1499',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12.5),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // SIZES & PRICES (VARIANTS) WITH + BUTTON
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.format_size_rounded, size: 16, color: AppColors.primaryRed),
                const SizedBox(width: 6),
                Text(
                  'SIZES & PRICES (OPTIONAL VARIANTS)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setDialogState(() {
                  sizePricePairs.add(SizePricePair());
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: AppColors.primaryRed),
                    SizedBox(width: 4),
                    Text(
                      'Add Size & Price',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(sizePricePairs.length, (index) {
          final pair = sizePricePairs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: pair.sizeController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: index == 0 ? 'e.g. Small' : (index == 1 ? 'e.g. Medium' : 'e.g. Large'),
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.aspect_ratio_rounded, size: 18, color: AppColors.primaryRed),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: pair.priceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Price e.g. 849',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.payments_rounded, size: 18, color: AppColors.primaryRed),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                ),
                if (sizePricePairs.length > 1) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
                    onPressed: () {
                      setDialogState(() {
                        pair.dispose();
                        sizePricePairs.removeAt(index);
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 14),

        // FLAVORS WITH + BUTTON
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.primaryRed),
                const SizedBox(width: 6),
                Text(
                  'FLAVORS (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setDialogState(() {
                  flavorsControllers.add(TextEditingController());
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: AppColors.primaryRed),
                    SizedBox(width: 4),
                    Text(
                      'Add Flavor',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(flavorsControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: flavorsControllers[index],
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      hintText: index == 0 ? 'e.g. Fajita Pizza' : (index == 1 ? 'e.g. Chicken Tikka' : 'e.g. Malai Boti'),
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.local_fire_department_rounded, size: 18, color: AppColors.primaryRed),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                ),
                if (flavorsControllers.length > 1) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
                    onPressed: () {
                      setDialogState(() {
                        flavorsControllers[index].dispose();
                        flavorsControllers.removeAt(index);
                      });
                    },
                  ),
                ],
              ],
            ),
          );
        }),


        // Badge & Preset / Device Image Selection Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded, size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        'BADGE / TAG (WRITTEN OR SELECT)',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: badgeController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Chef Special, Hot & Spicy',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ['Chef Special', 'Bestseller', 'New Dish', 'Signature', 'Hot & Spicy', 'Veg']
                        .map((bText) => InkWell(
                              onTap: () {
                                setDialogState(() {
                                  badgeController.text = bText;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeController.text == bText
                                      ? AppColors.primaryRed
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  bText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeController.text == bText
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_rounded, size: 16, color: AppColors.primaryRed),
                      const SizedBox(width: 6),
                      Text(
                        'ITEM IMAGE',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Device image selected → show chip instead of dropdown
                  if (displayDevicePath != null || deviceImageBytes != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildImageWidget(
                              displayDevicePath ?? '',
                              imageBytes: deviceImageBytes,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              fallback: const Icon(Icons.photo_library_rounded, size: 22, color: AppColors.primaryRed),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Device Image Selected', style: TextStyle(fontSize: 11, color: AppColors.primaryRed, fontWeight: FontWeight.w600)),
                                Text(
                                  displayDevicePath != null ? displayDevicePath.split(RegExp(r'[/\\]')).last : 'Custom Image',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: onClearDeviceImage,
                            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.danger),
                            tooltip: 'Remove device image',
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: presetImages.any((img) => img['path'] == selectedImage) ? selectedImage : '',
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryRed),
                                items: presetImages.map((img) => DropdownMenuItem(
                                  value: img['path']!,
                                  child: Text(
                                    img['label']!,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) onSelectImage(val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: onPickDeviceImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Icon(Icons.upload_file_rounded, size: 16),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),


        const SizedBox(height: 22),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                final priceVal = double.tryParse(priceController.text.trim()) ?? 
                    (sizePricePairs.isNotEmpty ? double.tryParse(sizePricePairs.first.priceController.text.trim()) ?? 999.0 : 999.0);

                final Map<String, String> pricesMap = {};
                for (var pair in sizePricePairs) {
                  final sName = pair.sizeController.text.trim();
                  final sPrice = pair.priceController.text.trim();
                  if (sName.isNotEmpty && sPrice.isNotEmpty) {
                    pricesMap[sName] = sPrice.startsWith('Rs') ? sPrice : 'PKR $sPrice';
                  }
                }

                final List<String> flavorsList = flavorsControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                final extras = extrasController.text.trim();
                final desc = descController.text.trim().isEmpty
                    ? 'Delicious freshly prepared $selectedCategory item.'
                    : descController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter sub-item dish name!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                final badgeText = badgeController.text.trim().isEmpty ? 'Chef Special' : badgeController.text.trim();

                // Read freshest image path from notifier at save time
                String saveImagePath = imagePathNotifier.value.isNotEmpty
                    ? imagePathNotifier.value
                    : (selectedImage.isNotEmpty
                        ? selectedImage
                        : (customDeviceImagePath ?? ''));

                if (deviceImageBytes != null && !saveImagePath.startsWith('data:image') && !saveImagePath.startsWith('assets/')) {
                  saveImagePath = 'data:image/jpeg;base64,${base64Encode(deviceImageBytes)}';
                }

                final newItemMap = {
                  'name': name,
                  'category': selectedCategory,
                  'price': priceVal,
                  'description': desc,
                  'badge': badgeText,
                  'imagePath': saveImagePath,
                  'imageBytes': deviceImageBytes,
                  'hasCustomDeviceImage': (saveImagePath.isNotEmpty && !saveImagePath.startsWith('assets/')) || deviceImageBytes != null,
                  'pricesMap': pricesMap,
                  'flavorsList': flavorsList,
                  'extras': extras,
                };

                final posMenuItem = MenuItem(
                  id: 'menu_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  category: selectedCategory,
                  description: desc,
                  basePrice: priceVal,
                  imageUrl: saveImagePath,
                  isVeg: badgeText == 'Veg',
                  isSpicy: badgeText == 'Hot & Spicy',
                );

                final List<Map<String, dynamic>> sizesList = pricesMap.entries.map((e) {
                  final numericStr = e.value.replaceAll(RegExp(r'[^0-9.]'), '');
                  final p = double.tryParse(numericStr) ?? priceVal;
                  return {
                    'size_name': e.key,
                    'price': p,
                  };
                }).toList();

                final List<Map<String, dynamic>> optionsList = flavorsList.map((f) => {
                  'option_type': 'flavor',
                  'option_name': f,
                  'additional_price': 0,
                }).toList();

                final matchedCat = _allCategories.firstWhere(
                  (c) => c.name.toLowerCase() == selectedCategory.toLowerCase() ||
                         c.id.toLowerCase() == selectedCategory.toLowerCase() ||
                         c.categoryKey.toLowerCase() == selectedCategory.toLowerCase(),
                  orElse: () => MenuCategoryItem(
                    id: selectedCategory.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-'),
                    name: selectedCategory,
                    categoryKey: selectedCategory.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-'),
                    badgeText: 'Category',
                    imagePath: '',
                    description: '',
                    icon: Icons.category_rounded,
                  ),
                );

                ref.read(posProvider.notifier).addMenuItem(
                  posMenuItem,
                  categoryId: matchedCat.id,
                  sizes: sizesList.isNotEmpty ? sizesList : null,
                  options: optionsList.isNotEmpty ? optionsList : null,
                ).then((_) => _loadCategoriesAndItemsFromBackend());

                setState(() {
                  _customMenuItems.add(newItemMap);
                });

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sub-item "$name" added successfully to $selectedCategory!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: const Text(
                'SAVE & PUBLISH ITEM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
