class MenuItem {
  final String id;
  final String name;
  final String category; // Pizza, Burgers, Deals, Fries, Drinks, Desserts, Addons
  final String description;
  final double basePrice;
  final String imageUrl;
  final bool isVeg;
  final bool isSpicy;
  final bool isAvailable;
  final List<String> availableSizes;
  final List<String> availableCrustsOrBuns;
  final List<String> availableToppings;
  final Map<String, double> sizePrices;
  final Map<String, double> optionPrices;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.basePrice,
    required this.imageUrl,
    this.isVeg = false,
    this.isSpicy = false,
    this.isAvailable = true,
    this.availableSizes = const ['Regular', 'Large', 'Extra Large'],
    this.availableCrustsOrBuns = const ['Original', 'Butter Cheese', 'Garlic Herb', 'Sesame Bun', 'Brioche Bun'],
    this.availableToppings = const ['Extra Cheese', 'Pepperoni', 'Bacon', 'Jalapeños', 'Mushrooms'],
    this.sizePrices = const {},
    this.optionPrices = const {},
  });

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    bool? isVeg,
    bool? isSpicy,
    bool? isAvailable,
    List<String>? availableSizes,
    List<String>? availableCrustsOrBuns,
    List<String>? availableToppings,
    Map<String, double>? sizePrices,
    Map<String, double>? optionPrices,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isVeg: isVeg ?? this.isVeg,
      isSpicy: isSpicy ?? this.isSpicy,
      isAvailable: isAvailable ?? this.isAvailable,
      availableSizes: availableSizes ?? this.availableSizes,
      availableCrustsOrBuns: availableCrustsOrBuns ?? this.availableCrustsOrBuns,
      availableToppings: availableToppings ?? this.availableToppings,
      sizePrices: sizePrices ?? this.sizePrices,
      optionPrices: optionPrices ?? this.optionPrices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'basePrice': basePrice,
      'imageUrl': imageUrl,
      'isVeg': isVeg ? 1 : 0,
      'isSpicy': isSpicy ? 1 : 0,
      'isAvailable': isAvailable ? 1 : 0,
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Pizza',
      description: map['description']?.toString() ?? '',
      basePrice: map['basePrice'] != null
          ? (map['basePrice'] as num).toDouble()
          : (double.tryParse(map['base_price']?.toString() ?? '0') ?? 0.0),
      imageUrl: map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? '',
      isVeg: map['isVeg'] == 1 || map['is_veg'] == true,
      isSpicy: map['isSpicy'] == 1 || map['is_spicy'] == true,
      isAvailable: map['isAvailable'] == 1 || map['is_available'] == true || map['is_available'] == null,
    );
  }

  factory MenuItem.fromBackendJson(Map<String, dynamic> json) {
    // Category name
    String categoryName = 'Pizza';
    if (json['category'] is Map && json['category']['name'] != null) {
      categoryName = json['category']['name'].toString();
    } else if (json['category_id'] != null) {
      categoryName = json['category_id'].toString();
    }

    // Sizes
    List<String> sizes = [];
    Map<String, double> sizePrices = {};
    if (json['sizes'] is List) {
      for (final s in json['sizes'] as List) {
        if (s is Map && s['size_name'] != null) {
          final sName = s['size_name'].toString();
          sizes.add(sName);
          if (s['price'] != null) {
            sizePrices[sName] = double.tryParse(s['price'].toString()) ?? 0.0;
          }
        }
      }
    }
    if (sizes.isEmpty) {
      sizes = ['Regular', 'Large', 'Extra Large'];
    }

    // Options (crusts, buns, toppings)
    List<String> crusts = [];
    List<String> toppings = [];
    Map<String, double> optionPrices = {};
    if (json['options'] is List) {
      for (final o in json['options'] as List) {
        if (o is Map && o['option_name'] != null) {
          final oName = o['option_name'].toString();
          final type = o['option_type']?.toString().toLowerCase() ?? '';
          if (o['additional_price'] != null) {
            optionPrices[oName] = double.tryParse(o['additional_price'].toString()) ?? 0.0;
          }
          if (type.contains('topping')) {
            toppings.add(oName);
          } else {
            crusts.add(oName);
          }
        }
      }
    }
    if (crusts.isEmpty) {
      crusts = ['Original', 'Butter Cheese', 'Garlic Herb', 'Sesame Bun', 'Brioche Bun'];
    }
    if (toppings.isEmpty) {
      toppings = ['Extra Cheese', 'Pepperoni', 'Bacon', 'Jalapeños', 'Mushrooms'];
    }

    return MenuItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: categoryName,
      description: json['description']?.toString() ?? '',
      basePrice: double.tryParse(json['base_price']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? '',
      isVeg: json['is_veg'] == true,
      isSpicy: json['is_spicy'] == true,
      isAvailable: json['is_available'] != false,
      availableSizes: sizes,
      availableCrustsOrBuns: crusts,
      availableToppings: toppings,
      sizePrices: sizePrices,
      optionPrices: optionPrices,
    );
  }
}
