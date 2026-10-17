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
    if (json['sizes'] is List) {
      for (final s in json['sizes'] as List) {
        if (s is Map && s['size_name'] != null) {
          sizes.add(s['size_name'].toString());
        }
      }
    }
    if (sizes.isEmpty) {
      sizes = ['Regular', 'Large', 'Extra Large'];
    }

    // Options (crusts, buns, toppings)
    List<String> crusts = [];
    List<String> toppings = [];
    if (json['options'] is List) {
      for (final o in json['options'] as List) {
        if (o is Map && o['option_name'] != null) {
          final type = o['option_type']?.toString().toLowerCase() ?? '';
          if (type.contains('topping')) {
            toppings.add(o['option_name'].toString());
          } else {
            crusts.add(o['option_name'].toString());
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
    );
  }
}
