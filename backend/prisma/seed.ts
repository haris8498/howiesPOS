import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';
import {
  INITIAL_CASHIER_PERMISSIONS,
  INITIAL_MANAGER_PERMISSIONS,
} from '../src/common/rbac/constants/permissions.constants';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding initial POS staff users...');

  const nomanPasswordHash = await argon2.hash('Noman123');
  const defaultPassword = 'Password123!';
  const defaultPasswordHash = await argon2.hash(defaultPassword);

  // Clean up legacy owner usernames if present
  await prisma.staffUser.deleteMany({
    where: {
      role: 'owner',
      username: { notIn: ['Noman', 'noman'] },
    },
  });

  const users = [
    {
      username: 'Noman',
      password_hash: nomanPasswordHash,
      role: 'owner',
      is_default: true,
      updated_by: 'Super Admin',
    },
    {
      username: 'manager',
      password_hash: defaultPasswordHash,
      role: 'manager',
      is_default: true,
      updated_by: 'Store Admin',
    },
    {
      username: 'poscashier',
      password_hash: defaultPasswordHash,
      role: 'cashier',
      is_default: true,
      updated_by: 'POS Admin',
    },
  ];

  for (const u of users) {
    await prisma.staffUser.upsert({
      where: { username: u.username },
      update: {
        password_hash: u.password_hash,
        role: u.role,
        is_default: u.is_default,
      },
      create: u,
    });
    console.log(`✅ Seeded user @${u.username} (${u.role})`);
  }

  console.log('🏛️ Seeding floor zones into database...');

  const defaultZones = ['Hall', 'Family Hall', 'Office', 'Terrace'];
  const zoneMap: Record<string, string> = {};

  for (const zoneName of defaultZones) {
    const zone = await prisma.floorZone.upsert({
      where: { name: zoneName },
      update: {},
      create: { name: zoneName },
    });
    zoneMap[zoneName] = zone.id;
  }
  console.log(`✅ Seeded ${defaultZones.length} floor zones into 'floor_zones' table`);

  console.log('🍽️ Seeding restaurant floor tables into database...');

  const initialTables = [
    // Hall Section
    ...Array.from({ length: 10 }, (_, i) => {
      const num = i + 1;
      const numStr = num < 10 ? `0${num}` : `${num}`;
      return {
        table_number: `H-${numStr}`,
        name: `Hall Table ${numStr}`,
        capacity: num % 3 === 0 ? 6 : 4,
        section: 'Hall',
        zone_id: zoneMap['Hall'],
        status: 'available',
      };
    }),
    // Family Hall Section
    ...Array.from({ length: 15 }, (_, i) => {
      const num = i + 1;
      const numStr = num < 10 ? `0${num}` : `${num}`;
      return {
        table_number: `FH-${numStr}`,
        name: `Family Hall Table ${numStr}`,
        capacity: num % 2 === 0 ? 6 : (num % 5 === 0 ? 8 : 4),
        section: 'Family Hall',
        zone_id: zoneMap['Family Hall'],
        status: 'available',
      };
    }),
    // Executive / VIP Office Section
    ...Array.from({ length: 4 }, (_, i) => {
      const num = i + 1;
      const numStr = num < 10 ? `0${num}` : `${num}`;
      return {
        table_number: `OFF-${numStr}`,
        name: `VIP Office Table ${numStr}`,
        capacity: num % 2 === 0 ? 10 : 8,
        section: 'Office',
        zone_id: zoneMap['Office'],
        status: 'available',
      };
    }),
    // Terrace Section
    ...Array.from({ length: 6 }, (_, i) => {
      const num = i + 1;
      const numStr = num < 10 ? `0${num}` : `${num}`;
      return {
        table_number: `T-${numStr}`,
        name: `Terrace Table ${numStr}`,
        capacity: num % 2 === 0 ? 4 : 2,
        section: 'Terrace',
        zone_id: zoneMap['Terrace'],
        status: 'available',
      };
    }),
  ];

  for (const t of initialTables) {
    await prisma.restaurantTable.upsert({
      where: { table_number: t.table_number },
      update: {
        name: t.name,
        capacity: t.capacity,
        section: t.section,
        zone_id: t.zone_id,
      },
      create: t,
    });
  }
  console.log(`✅ Seeded ${initialTables.length} restaurant tables into 'restaurant_tables' table`);

  console.log('🍕 Seeding Menu Categories into database...');

  const categories = [
    {
      id: 'deals',
      name: 'Exclusive Deals',
      badge_text: 'HOT DEALS',
      image_path: 'assets/images/Pizza.png',
      description: 'Value meal combos, family feast bundles, discounted combos & seasonal specials.',
      icon_name: 'local_offer_rounded',
    },
    {
      id: 'pizza',
      name: 'Pizza',
      badge_text: 'Pizza',
      image_path: 'assets/images/Pizza.png',
      description: 'Melted cheese, chicken toppings, colorful vegetables & crispy charred crust.',
      icon_name: 'local_pizza_rounded',
    },
    {
      id: 'chicken-steak',
      name: 'Chicken Steak',
      badge_text: 'Steak',
      image_path: 'assets/images/chicken_steak.png',
      description: 'Tender grilled chicken steak with creamy sauce, mashed potato & vegetables.',
      icon_name: 'set_meal_rounded',
    },
    {
      id: 'burger',
      name: 'Burger',
      badge_text: 'Burger',
      image_path: 'assets/images/beef_burger_hero.jpg',
      description: 'Gourmet beef & chicken burgers with melted cheese, lettuce, tomato & brioche bun.',
      icon_name: 'lunch_dining_rounded',
    },
    {
      id: 'dajjaj-brost',
      name: 'Dajjaj Brost',
      badge_text: 'Brost',
      image_path: 'assets/images/broast_hero.jpg',
      description: 'Golden crispy broast chicken pieces served with fries, garlic dip & lemon.',
      icon_name: 'restaurant_rounded',
    },
    {
      id: 'pasta',
      name: 'Pasta',
      badge_text: 'Pasta',
      image_path: 'assets/images/pasta_hero.jpg',
      description: 'Creamy chicken Alfredo pasta with parmesan cheese, Italian herbs & grilled chicken.',
      icon_name: 'ramen_dining_rounded',
    },
    {
      id: 'panini',
      name: 'Panini',
      badge_text: 'Panini',
      image_path: 'assets/images/panini_hero.jpg',
      description: 'Toasted grilled panini sandwich with melted cheese, chicken & fresh vegetables.',
      icon_name: 'breakfast_dining_rounded',
    },
    {
      id: 'appetizer',
      name: 'Appetizer',
      badge_text: 'Appetizer',
      image_path: 'assets/images/appetizer_hero.jpg',
      description: 'Crispy nuggets, wings, french fries & dipping sauces served on a platter.',
      icon_name: 'tapas_rounded',
    },
    {
      id: 'fries',
      name: 'Fries',
      badge_text: 'Fries',
      image_path: 'assets/images/fries_hero.jpg',
      description: 'Golden crispy French fries including loaded fries with melted cheese & sauces.',
      icon_name: 'fastfood_rounded',
    },
    {
      id: 'beverages',
      name: 'Beverages',
      badge_text: 'Drinks',
      image_path: 'assets/images/beverages_hero.jpg',
      description: 'Ice-cold soft drinks, bottled mineral water & cold beverages with ice condensation.',
      icon_name: 'local_drink_rounded',
    },
    {
      id: 'extra-topping',
      name: 'Extra Topping',
      badge_text: 'Topping',
      image_path: 'assets/images/toppings_hero.jpg',
      description: 'Melted cheese, BBQ sauce, garlic mayo, jalapeno sauce & honey mustard.',
      icon_name: 'category_rounded',
    },
    {
      id: 'hot-beverages',
      name: 'Hot Beverages',
      badge_text: 'Hot Coffee',
      image_path: 'assets/images/hot_beverages_hero.jpg',
      description: 'Cappuccino, espresso, latte, hot chocolate & brewed tea cups with steam.',
      icon_name: 'coffee_rounded',
    },
    {
      id: 'cold-coffee',
      name: 'Cold Coffee',
      badge_text: 'Iced Coffee',
      image_path: 'assets/images/cold_coffee_hero.jpg',
      description: 'Caramel iced latte, vanilla iced latte, mocha & strawberry iced latte with ice.',
      icon_name: 'icecream_rounded',
    },
    {
      id: 'ice-cream',
      name: 'Ice Cream',
      badge_text: 'Ice Cream',
      image_path: 'assets/images/ice_cream_hero.jpg',
      description: 'Kulfa, mango, vanilla, chocolate & strawberry scoops in elegant bowls.',
      icon_name: 'cookie_rounded',
    },
    {
      id: 'mocktails',
      name: 'Mocktails',
      badge_text: 'Mocktail',
      image_path: 'assets/images/mocktails_hero.jpg',
      description: 'Vibrant colorful mocktails in elegant glasses with fresh fruit & mint garnishes.',
      icon_name: 'local_bar_rounded',
    },
    {
      id: 'mojito',
      name: 'Mojito',
      badge_text: 'Mojito',
      image_path: 'assets/images/Mojito.png',
      description: 'Fresh mojitos with crushed ice, mint leaves, lime slices & fruit flavors.',
      icon_name: 'local_cafe_rounded',
    },
    {
      id: 'smoothies',
      name: 'Smoothies',
      badge_text: 'Smoothie',
      image_path: 'assets/images/Smooth.png',
      description: 'Thick creamy fruit smoothies featuring mango, banana, mixed berry & strawberry.',
      icon_name: 'blender_rounded',
    },
    {
      id: 'ice-shakes',
      name: 'Ice Shakes',
      badge_text: 'Shake',
      image_path: 'assets/images/ice shake.webp',
      description: 'Rich thick ice shakes in mango, vanilla, caramel, chocolate & Kulfa flavors.',
      icon_name: 'water_drop_rounded',
    },
    {
      id: 'milk-shakes',
      name: 'Milk Shakes',
      badge_text: 'Milkshake',
      image_path: 'assets/images/Milk shake.png',
      description: 'Creamy chilled milkshakes with apple, banana, seasonal fruit & strawberry.',
      icon_name: 'emoji_food_beverage_rounded',
    },
    {
      id: 'soft-drinks',
      name: 'Soft Drinks',
      badge_text: 'Soda',
      image_path: 'assets/images/soft.png',
      description: 'Fresh lime and mint-based refreshing drinks served in glasses with crushed ice.',
      icon_name: 'wine_bar_rounded',
    },
  ];

  for (const cat of categories) {
    await prisma.menuCategory.upsert({
      where: { id: cat.id },
      update: {
        name: cat.name,
        badge_text: cat.badge_text,
        image_path: cat.image_path,
        description: cat.description,
        icon_name: cat.icon_name,
      },
      create: cat,
    });
  }
  console.log(`✅ Seeded ${categories.length} menu categories`);

  interface SeedMenuItem {
    id: string;
    category_id: string;
    name: string;
    description: string;
    base_price: number;
    image_url: string;
    is_spicy?: boolean;
    is_veg?: boolean;
    sizes?: { size_name: string; price: number }[];
    options?: { option_type: string; option_name: string; additional_price: number }[];
  }

  const standardPizzaOptions = [
    { option_type: 'crust', option_name: 'Original Crust', additional_price: 0 },
    { option_type: 'crust', option_name: 'Butter Cheese Crust', additional_price: 150 },
    { option_type: 'crust', option_name: 'Garlic Herb Crust', additional_price: 120 },
    { option_type: 'crust', option_name: 'Cajun Crust', additional_price: 120 },
    { option_type: 'crust', option_name: 'Sesame Crust', additional_price: 100 },
    { option_type: 'topping', option_name: 'Extra Mozzarella Cheese', additional_price: 200 },
    { option_type: 'topping', option_name: 'Mushrooms', additional_price: 100 },
    { option_type: 'topping', option_name: 'Jalapenos', additional_price: 80 },
    { option_type: 'topping', option_name: 'Black Olives', additional_price: 90 },
    { option_type: 'topping', option_name: 'Extra Chicken', additional_price: 180 },
  ];

  const classicPizzaSizes = [
    { size_name: 'Small', price: 849.0 },
    { size_name: 'Medium', price: 1449.0 },
    { size_name: 'Large', price: 1749.0 },
    { size_name: 'Family', price: 2349.0 },
  ];

  const modernPizzaSizes = [
    { size_name: 'Small', price: 849.0 },
    { size_name: 'Medium', price: 1549.0 },
    { size_name: 'Large', price: 1999.0 },
    { size_name: 'Family', price: 2499.0 },
  ];

  const specialPizzaSizes = [
    { size_name: 'Medium', price: 1699.0 },
    { size_name: 'Large', price: 2199.0 },
    { size_name: 'Family', price: 2999.0 },
  ];

  const menuItems: SeedMenuItem[] = [
    // -------------------------------------------------------------------------
    // 1. PIZZAS - CLASSIC, MODERN & SPECIAL
    // -------------------------------------------------------------------------
    {
      id: 'item-pizza-fajita',
      category_id: 'pizza',
      name: 'Fajita Pizza',
      description: 'Tender marinated fajita chicken, onions, bell peppers and melted mozzarella.',
      base_price: 849.0,
      image_url: 'assets/images/Fajita.png',
      is_spicy: true,
      sizes: classicPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-tikka',
      category_id: 'pizza',
      name: 'Chicken Tikka Pizza',
      description: 'Traditional spiced Pakistani BBQ chicken tikka chunks with onions & herbs.',
      base_price: 849.0,
      image_url: 'assets/images/Pizza.png',
      is_spicy: true,
      sizes: classicPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-malai-boti',
      category_id: 'pizza',
      name: 'Malai Boti Pizza',
      description: 'Creamy marinated chicken malai boti with cheddar, mozzarella & white sauce.',
      base_price: 899.0,
      image_url: 'assets/images/Pizza.png',
      sizes: [
        { size_name: 'Small', price: 899.0 },
        { size_name: 'Medium', price: 1499.0 },
        { size_name: 'Large', price: 1799.0 },
        { size_name: 'Family', price: 2399.0 },
      ],
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-sausage-cheese',
      category_id: 'pizza',
      name: 'Sausage Cheese Pizza',
      description: 'Sliced chicken sausage chunks layered with mozzarella, cheddar and oregano.',
      base_price: 849.0,
      image_url: 'assets/images/Pizza.png',
      sizes: classicPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-hot-spicy',
      category_id: 'pizza',
      name: 'Hot & Spicy Pizza',
      description: 'Fiery chili chicken chunks, jalapeno peppers, crushed red pepper and garlic sauce.',
      base_price: 849.0,
      image_url: 'assets/images/Pizza.png',
      is_spicy: true,
      sizes: classicPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-tandoori',
      category_id: 'pizza',
      name: 'Tandoori Bonfire Pizza',
      description: 'Smoky tandoori chicken, grilled capsicum, sweet corn and creamy garlic drizzle.',
      base_price: 899.0,
      image_url: 'assets/images/Pizza.png',
      is_spicy: true,
      sizes: [
        { size_name: 'Small', price: 899.0 },
        { size_name: 'Medium', price: 1499.0 },
        { size_name: 'Large', price: 1799.0 },
        { size_name: 'Family', price: 2399.0 },
      ],
      options: standardPizzaOptions,
    },
    // Modern Pizzas
    {
      id: 'item-pizza-ring',
      category_id: 'pizza',
      name: 'Ring Pizza',
      description: 'Handcrafted twisted cheesy crust ring topped with savory chicken and BBQ swirl.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-crown-crust',
      category_id: 'pizza',
      name: 'Crown Crust Modern Pizza',
      description: 'Signature crown pockets stuffed with cheesy chicken boti and creamy dips.',
      base_price: 1549.0,
      image_url: 'assets/images/Modern.png',
      sizes: [
        { size_name: 'Medium', price: 1549.0 },
        { size_name: 'Large', price: 1999.0 },
        { size_name: 'Family', price: 2499.0 },
      ],
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-pepperoni',
      category_id: 'pizza',
      name: 'Pepperoni Passion Pizza',
      description: 'Generous layers of beef pepperoni and golden melted mozzarella cheese.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-doner-kebab',
      category_id: 'pizza',
      name: 'Doner Kebab Pizza',
      description: 'Turkish-style shaved chicken kebab slices with white garlic herb sauce.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-kebab-stuffer',
      category_id: 'pizza',
      name: 'Kebab Stuffer Pizza',
      description: 'Seekh kebab rolls baked right inside the crust edge with chili garlic base.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-cheese-stick',
      category_id: 'pizza',
      name: 'Cheese Stick Pizza',
      description: 'Crispy mozzarella cheese sticks baked directly into the pizza rim.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-chicken-stuffer',
      category_id: 'pizza',
      name: 'Chicken Stuffer Pizza',
      description: 'Double-stuffed chicken layers with spicy herbs, black olives and cheddar sauce.',
      base_price: 849.0,
      image_url: 'assets/images/Modern.png',
      sizes: modernPizzaSizes,
      options: standardPizzaOptions,
    },
    // Special Pizzas
    {
      id: 'item-pizza-arabic-crispy',
      category_id: 'pizza',
      name: 'Arabic Crispy Special Pizza',
      description: 'Crispy fried chicken toppings, Arabic garlic mayo drizzle, olives & sweet corn.',
      base_price: 1699.0,
      image_url: 'assets/images/Special.png',
      sizes: specialPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-cheese-gold',
      category_id: 'pizza',
      name: 'Hungry Cheese Gold Pizza',
      description: 'Triple cheese blend (mozzarella, gouda, cheddar) with golden cheese burst rim.',
      base_price: 1699.0,
      image_url: 'assets/images/Special.png',
      sizes: specialPizzaSizes,
      options: standardPizzaOptions,
    },
    {
      id: 'item-pizza-howie-special',
      category_id: 'pizza',
      name: 'Howie Special Pizza',
      description: 'Pepperoni, smoked chicken ham, mushrooms, green peppers & Butter Cheese crust.',
      base_price: 1499.0,
      image_url: 'assets/images/Pizza.png',
      sizes: [
        { size_name: 'Regular', price: 1499.0 },
        { size_name: 'Large', price: 1899.0 },
        { size_name: 'Extra Large', price: 2499.0 },
      ],
      options: standardPizzaOptions,
    },

    // -------------------------------------------------------------------------
    // 2. CHICKEN STEAK
    // -------------------------------------------------------------------------
    {
      id: 'item-steak-tarragon',
      category_id: 'chicken-steak',
      name: 'Tarragon Chicken Steak',
      description: 'Grilled chicken fillet with rich French tarragon herb cream sauce, fries & veggies.',
      base_price: 1499.0,
      image_url: 'assets/images/chicken_steak.png',
    },
    {
      id: 'item-steak-mushroom',
      category_id: 'chicken-steak',
      name: 'Mushroom Cream Steak',
      description: 'Pan-seared chicken steak served with creamy brown mushroom glaze.',
      base_price: 1499.0,
      image_url: 'assets/images/chicken_steak.png',
    },
    {
      id: 'item-steak-twin',
      category_id: 'chicken-steak',
      name: 'Twin Sensation Steak',
      description: 'Two grilled chicken fillets with twin sauces: creamy tarragon and spicy Mexican.',
      base_price: 1599.0,
      image_url: 'assets/images/chicken_steak.png',
    },
    {
      id: 'item-steak-smoked-bbq',
      category_id: 'chicken-steak',
      name: 'Smoked BBQ Steak',
      description: 'Charcoal grilled chicken fillet glazed in hickory smoked barbecue sauce.',
      base_price: 1499.0,
      image_url: 'assets/images/chicken_steak.png',
    },
    {
      id: 'item-steak-hot-shot',
      category_id: 'chicken-steak',
      name: 'Hot Shot Jalapeno Steak',
      description: 'Spicy grilled chicken steak smothered in fiery jalapeno cheese sauce.',
      base_price: 1499.0,
      image_url: 'assets/images/chicken_steak.png',
      is_spicy: true,
    },
    {
      id: 'item-steak-mexican',
      category_id: 'chicken-steak',
      name: 'Mexican Hot & Spicy Steak',
      description: 'Spiced Mexican grilled steak with salsa dressing, sweet corn and fries.',
      base_price: 1499.0,
      image_url: 'assets/images/chicken_steak.png',
      is_spicy: true,
    },

    // -------------------------------------------------------------------------
    // 3. BURGERS (BEEF & CHICKEN)
    // -------------------------------------------------------------------------
    {
      id: 'item-burger-beef-cheese-stuff',
      category_id: 'burger',
      name: 'Beef Cheese Stuff Burger',
      description: 'Succulent 200g beef patty stuffed with melted cheddar, BBQ sauce & sesame bun.',
      base_price: 1349.0,
      image_url: 'assets/images/beef_burger_hero.jpg',
      sizes: [
        { size_name: 'Single Patty', price: 1349.0 },
        { size_name: 'Double Patty', price: 1749.0 },
      ],
    },
    {
      id: 'item-burger-hungry-stacker',
      category_id: 'burger',
      name: 'Hungry Stacker Burger',
      description: 'Double beef patties, crispy turkey bacon, double cheese slices & secret sauce.',
      base_price: 1349.0,
      image_url: 'assets/images/beef_burger_hero.jpg',
    },
    {
      id: 'item-burger-smashroom',
      category_id: 'burger',
      name: 'The Smashroom Beef Burger',
      description: 'Smashed beef patty, sautéed garlic mushrooms, Swiss cheese and caramelized onions.',
      base_price: 1099.0,
      image_url: 'assets/images/beef_burger_hero.jpg',
    },
    {
      id: 'item-burger-mexicano-beef',
      category_id: 'burger',
      name: 'Mexicano Beef Burger',
      description: 'Juicy spiced beef patty with jalapeños, spicy mayo and pepperjack cheese.',
      base_price: 999.0,
      image_url: 'assets/images/beef_burger_hero.jpg',
      is_spicy: true,
    },
    {
      id: 'item-burger-classic-beef',
      category_id: 'burger',
      name: 'Classic Beef Burger',
      description: 'Traditional grilled beef patty with iceberg lettuce, pickles and burger sauce.',
      base_price: 999.0,
      image_url: 'assets/images/beef_burger_hero.jpg',
    },
    {
      id: 'item-burger-hungry-special',
      category_id: 'burger',
      name: 'Hungry Special Chicken Burger',
      description: 'Tender grilled chicken thigh with smoky sauce, cheddar slice and brioche bun.',
      base_price: 899.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
    },
    {
      id: 'item-burger-crispy-bbq',
      category_id: 'burger',
      name: 'Crispy BBQ Chicken Burger',
      description: 'Fried crispy chicken fillet coated in sweet & tangy BBQ sauce.',
      base_price: 999.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
    },
    {
      id: 'item-burger-juicy-lucy',
      category_id: 'burger',
      name: 'Juicy Lucy Chicken Burger',
      description: 'Cheese-filled grilled chicken patty with fresh lettuce and tomato slices.',
      base_price: 899.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
    },
    {
      id: 'item-burger-student',
      category_id: 'burger',
      name: 'Student Saver Burger',
      description: 'Crispy chicken patty with classic mayo and fresh iceberg lettuce.',
      base_price: 450.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
    },
    {
      id: 'item-burger-zeleto-zinger',
      category_id: 'burger',
      name: 'Zeleto Zinger Burger',
      description: 'Spicy seasoned crunchy zinger fillet topped with jalapenos and cheese sauce.',
      base_price: 549.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
      is_spicy: true,
    },
    {
      id: 'item-burger-zinger',
      category_id: 'burger',
      name: 'Crispy Zinger Burger',
      description: 'Crispy golden fried chicken breast fillet with lettuce and creamy mayonnaise.',
      base_price: 499.0,
      image_url: 'assets/images/chicken_burger_hero.jpg',
      is_spicy: true,
      sizes: [
        { size_name: 'Single Zinger', price: 499.0 },
        { size_name: 'Double Zinger Stacker', price: 749.0 },
      ],
    },

    // -------------------------------------------------------------------------
    // 4. DAJJAJ BROAST
    // -------------------------------------------------------------------------
    {
      id: 'item-broast-half',
      category_id: 'dajjaj-brost',
      name: 'Half Dajjaj Broast (with Fries & Garlic Sauce)',
      description: 'Crispy golden spiced Pakistani broast chicken pieces served with fries, bun & garlic dip.',
      base_price: 1250.0,
      image_url: 'assets/images/broast_hero.jpg',
    },
    {
      id: 'item-broast-family',
      category_id: 'dajjaj-brost',
      name: 'Family Dajjaj Broast (with Fries & Garlic Sauce)',
      description: 'Full family size crispy broast bucket with extra fries, garlic sauce cups and buns.',
      base_price: 2400.0,
      image_url: 'assets/images/broast_hero.jpg',
    },

    // -------------------------------------------------------------------------
    // 5. PASTA
    // -------------------------------------------------------------------------
    {
      id: 'item-pasta-alfredo',
      category_id: 'pasta',
      name: 'Chicken Fettuccine Alfredo',
      description: 'Fettuccine pasta in rich parmesan cream sauce with grilled chicken slices.',
      base_price: 999.0,
      image_url: 'assets/images/pasta_hero.jpg',
    },
    {
      id: 'item-pasta-penne-arrabiata',
      category_id: 'pasta',
      name: 'Penne Arrabiata',
      description: 'Spicy Italian tomato herb sauce with garlic, black olives and parmesan.',
      base_price: 999.0,
      image_url: 'assets/images/pasta_hero.jpg',
      is_spicy: true,
    },
    {
      id: 'item-pasta-hungry-parmesan',
      category_id: 'pasta',
      name: 'Hungry Parmesan Pasta',
      description: 'Signature loaded pasta with four kinds of cheese, herbs and chicken chunks.',
      base_price: 1099.0,
      image_url: 'assets/images/pasta_hero.jpg',
    },

    // -------------------------------------------------------------------------
    // 6. PANINI
    // -------------------------------------------------------------------------
    {
      id: 'item-panini-cheesy',
      category_id: 'panini',
      name: 'Cheesy Grilled Panini',
      description: 'Artisan grilled Italian panini bread stuffed with chicken, melted mozzarella & cheddar.',
      base_price: 1099.0,
      image_url: 'assets/images/panini_hero.jpg',
    },
    {
      id: 'item-panini-club',
      category_id: 'panini',
      name: 'Hungry Club Panini',
      description: 'Triple decker style panini with grilled chicken, fried egg, cheese & tomato slices.',
      base_price: 849.0,
      image_url: 'assets/images/panini_hero.jpg',
    },
    {
      id: 'item-panini-bbq',
      category_id: 'panini',
      name: 'Special BBQ Panini',
      description: 'Smoky BBQ chicken chunks with caramelized onions and cheddar cheese.',
      base_price: 849.0,
      image_url: 'assets/images/panini_hero.jpg',
    },

    // -------------------------------------------------------------------------
    // 7. APPETIZERS
    // -------------------------------------------------------------------------
    {
      id: 'item-app-nuggets',
      category_id: 'appetizer',
      name: 'Crispy Nuggets (6 pcs with Fries)',
      description: '6 pieces of crispy chicken nuggets served with golden fries and chili garlic dip.',
      base_price: 399.0,
      image_url: 'assets/images/Nuggets.png',
    },
    {
      id: 'item-app-crispy-wings',
      category_id: 'appetizer',
      name: 'Crispy Fried Wings (6 pcs)',
      description: 'Crispy seasoned chicken wings with secret spice blend.',
      base_price: 399.0,
      image_url: 'assets/images/Wings.png',
    },
    {
      id: 'item-app-peri-wings',
      category_id: 'appetizer',
      name: 'Peri-Peri Glazed Wings (6 pcs)',
      description: 'Tossed in tangy flame-grilled African peri-peri glaze.',
      base_price: 499.0,
      image_url: 'assets/images/peri.png',
      is_spicy: true,
    },
    {
      id: 'item-app-honey-wings',
      category_id: 'appetizer',
      name: 'Honey BBQ Wings (6 pcs)',
      description: 'Glazed in sweet clover honey and smoky barbecue sauce.',
      base_price: 499.0,
      image_url: 'assets/images/Honey.png',
    },

    // -------------------------------------------------------------------------
    // 8. FRIES
    // -------------------------------------------------------------------------
    {
      id: 'item-fries-loaded',
      category_id: 'fries',
      name: 'Hungry Loaded Fries',
      description: 'Crispy fries smothered in hot cheese sauce, jalapenos, minced chicken and BBQ drizzle.',
      base_price: 749.0,
      image_url: 'assets/images/Loaded.png',
    },
    {
      id: 'item-fries-honey-mustard',
      category_id: 'fries',
      name: 'Honey Mustard Fries',
      description: 'Golden fries drizzled with creamy honey mustard sauce.',
      base_price: 449.0,
      image_url: 'assets/images/Mustard.png',
    },
    {
      id: 'item-fries-garlic-mayo',
      category_id: 'fries',
      name: 'Garlic Mayo Fries',
      description: 'Fries seasoned and topped with creamy house garlic mayonnaise sauce.',
      base_price: 499.0,
      image_url: 'assets/images/Garlic.png',
    },
    {
      id: 'item-fries-masala',
      category_id: 'fries',
      name: 'Masala Fries',
      description: 'Classic fries tossed with spicy chaat masala seasoning.',
      base_price: 299.0,
      image_url: 'assets/images/Masala.png',
      is_spicy: true,
    },
    {
      id: 'item-fries-plain',
      category_id: 'fries',
      name: 'Plain French Fries',
      description: 'Lightly salted crispy golden potato fries.',
      base_price: 279.0,
      image_url: 'assets/images/Simple.png',
    },
    {
      id: 'item-fries-bbq',
      category_id: 'fries',
      name: 'BBQ Fries',
      description: 'Crispy fries tossed with smoky BBQ seasonings and barbecue dip.',
      base_price: 449.0,
      image_url: 'assets/images/BBQ_Fries.png',
    },

    // -------------------------------------------------------------------------
    // 9. BEVERAGES
    // -------------------------------------------------------------------------
    {
      id: 'item-bev-coke-nr',
      category_id: 'beverages',
      name: 'NR Coke Bottle (500ml)',
      description: 'Chilled refreshing Coca-Cola bottle.',
      base_price: 100.0,
      image_url: 'assets/images/Coke.png',
    },
    {
      id: 'item-bev-sprite-nr',
      category_id: 'beverages',
      name: 'NR Sprite Bottle (500ml)',
      description: 'Chilled refreshing Sprite lemon lime bottle.',
      base_price: 100.0,
      image_url: 'assets/images/Sprite.png',
    },
    {
      id: 'item-bev-coke-tin',
      category_id: 'beverages',
      name: 'Coke 250ml Tin Pack',
      description: 'Chilled Coke aluminum can.',
      base_price: 160.0,
      image_url: 'assets/images/CokeTin.png',
    },
    {
      id: 'item-bev-sprite-tin',
      category_id: 'beverages',
      name: 'Sprite 250ml Tin Pack',
      description: 'Chilled Sprite aluminum can.',
      base_price: 160.0,
      image_url: 'assets/images/SpriteTin.png',
    },
    {
      id: 'item-bev-water',
      category_id: 'beverages',
      name: 'Nestlé Pure Life Mineral Water (500ml)',
      description: 'Pure bottled mineral water.',
      base_price: 80.0,
      image_url: 'assets/images/Mineral.png',
    },

    // -------------------------------------------------------------------------
    // 10. EXTRA TOPPING
    // -------------------------------------------------------------------------
    {
      id: 'item-top-cheese',
      category_id: 'extra-topping',
      name: 'Extra Cheese',
      description: 'Extra melted cheddar and mozzarella cheese dip.',
      base_price: 200.0,
      image_url: 'assets/images/Cheese.png',
    },
    {
      id: 'item-top-bbq-sauce',
      category_id: 'extra-topping',
      name: 'BBQ Sauce Dip',
      description: 'Hickory smoked barbecue dipping sauce.',
      base_price: 150.0,
      image_url: 'assets/images/BBqSauce.png',
    },
    {
      id: 'item-top-garlic-mayo',
      category_id: 'extra-topping',
      name: 'Garlic Mayo Dip',
      description: 'Creamy garlic infused mayonnaise dip.',
      base_price: 150.0,
      image_url: 'assets/images/GarlicMayo.png',
    },
    {
      id: 'item-top-mash-potato',
      category_id: 'extra-topping',
      name: 'Mashed Potato',
      description: 'Buttery smooth mashed potato side.',
      base_price: 250.0,
      image_url: 'assets/images/MeshPatato.png',
    },
    {
      id: 'item-top-jalapeno-sauce',
      category_id: 'extra-topping',
      name: 'Jalapeno Sauce Dip',
      description: 'Zesty and spicy pickled jalapeno cream sauce.',
      base_price: 150.0,
      image_url: 'assets/images/Jalapino.png',
    },
    {
      id: 'item-top-honey-mustard',
      category_id: 'extra-topping',
      name: 'Honey Mustard Dip',
      description: 'Sweet and tangy golden honey mustard.',
      base_price: 150.0,
      image_url: 'assets/images/HoneyMustord.png',
    },

    // -------------------------------------------------------------------------
    // 11. HOT BEVERAGES
    // -------------------------------------------------------------------------
    {
      id: 'item-bev-cappuccino',
      category_id: 'hot-beverages',
      name: 'Classic Italian Cappuccino',
      description: 'Fresh espresso shot with steamed milk foam and cocoa dusting.',
      base_price: 599.0,
      image_url: 'assets/images/Capachino.png',
    },
    {
      id: 'item-bev-americano',
      category_id: 'hot-beverages',
      name: 'Americano Coffee',
      description: 'Double espresso pulled with hot mineral water for deep aroma.',
      base_price: 399.0,
      image_url: 'assets/images/Amercino.png',
    },
    {
      id: 'item-bev-espresso-single',
      category_id: 'hot-beverages',
      name: 'Espresso Single Shot',
      description: 'Pure concentrated single shot of freshly roasted coffee.',
      base_price: 399.0,
      image_url: 'assets/images/Expresso.png',
    },
    {
      id: 'item-bev-espresso-double',
      category_id: 'hot-beverages',
      name: 'Espresso Double Shot',
      description: 'Double shot rich espresso with dark crema.',
      base_price: 750.0,
      image_url: 'assets/images/ExpressoDouble.png',
    },
    {
      id: 'item-bev-hot-chocolate',
      category_id: 'hot-beverages',
      name: 'Rich Hot Chocolate',
      description: 'Belgian cocoa melted with warm whole milk and marshmallows.',
      base_price: 699.0,
      image_url: 'assets/images/Hot_Chocolate.png',
    },
    {
      id: 'item-bev-mocha',
      category_id: 'hot-beverages',
      name: 'Mocha Hot Coffee',
      description: 'Espresso combined with chocolate ganache and steamed milk.',
      base_price: 650.0,
      image_url: 'assets/images/Mocha.png',
    },
    {
      id: 'item-bev-latte',
      category_id: 'hot-beverages',
      name: 'Cafe Latte',
      description: 'Smooth steamed milk layered over bold espresso.',
      base_price: 580.0,
      image_url: 'assets/images/Latte.png',
    },
    {
      id: 'item-bev-karak-chai',
      category_id: 'hot-beverages',
      name: 'Special Karak Doodh Patti Mix Tea',
      description: 'Rich authentic Pakistani milk brewed tea with cardamom.',
      base_price: 200.0,
      image_url: 'assets/images/mix.png',
    },
    {
      id: 'item-bev-green-tea',
      category_id: 'hot-beverages',
      name: 'Organic Green Tea',
      description: 'Calming brewed organic green tea leaves with lemon.',
      base_price: 120.0,
      image_url: 'assets/images/Greentead.png',
    },

    // -------------------------------------------------------------------------
    // 12. COLD COFFEE
    // -------------------------------------------------------------------------
    {
      id: 'item-coffee-strawberry-iced',
      category_id: 'cold-coffee',
      name: 'Strawberry Iced Latte',
      description: 'Cold espresso, creamy milk, strawberry puree and ice.',
      base_price: 599.0,
      image_url: 'assets/images/Strawberry.png',
    },
    {
      id: 'item-coffee-caramel-iced',
      category_id: 'cold-coffee',
      name: 'Caramel Iced Latte',
      description: 'Cold espresso, creamy milk, ice and sweet caramel drizzle.',
      base_price: 599.0,
      image_url: 'assets/images/Cerimal.png',
    },
    {
      id: 'item-coffee-vanilla-iced',
      category_id: 'cold-coffee',
      name: 'Vanilla Iced Latte',
      description: 'Espresso on ice with Madagascan vanilla and whole milk.',
      base_price: 599.0,
      image_url: 'assets/images/Venala.png',
    },
    {
      id: 'item-coffee-mocha-iced',
      category_id: 'cold-coffee',
      name: 'Mocha Iced Latte',
      description: 'Iced espresso mixed with chocolate syrup and chilled milk.',
      base_price: 599.0,
      image_url: 'assets/images/Mocha_Lead.png',
    },
    {
      id: 'item-coffee-dark-chocolate',
      category_id: 'cold-coffee',
      name: 'Iced Dark Chocolate Shake',
      description: 'Intense dark chocolate blended with espresso and ice.',
      base_price: 750.0,
      image_url: 'assets/images/ice shake.webp',
    },

    // -------------------------------------------------------------------------
    // 13. ICE CREAM
    // -------------------------------------------------------------------------
    {
      id: 'item-icecream-kulfa',
      category_id: 'ice-cream',
      name: 'Shahi Kulfa Ice Cream Scoop',
      description: 'Traditional royal pistachio and saffron infused kulfa ice cream.',
      base_price: 250.0,
      image_url: 'assets/images/ice_cream_hero.jpg',
    },
    {
      id: 'item-icecream-mango',
      category_id: 'ice-cream',
      name: 'Mango Delight Ice Cream Scoop',
      description: 'Sweet fresh Sindhri mango flavored ice cream scoop.',
      base_price: 250.0,
      image_url: 'assets/images/ice_cream_hero.jpg',
    },
    {
      id: 'item-icecream-vanilla',
      category_id: 'ice-cream',
      name: 'French Vanilla Ice Cream Scoop',
      description: 'Classic creamy French vanilla bean scoop.',
      base_price: 250.0,
      image_url: 'assets/images/ice_cream_hero.jpg',
    },
    {
      id: 'item-icecream-chocolate',
      category_id: 'ice-cream',
      name: 'Belgian Chocolate Ice Cream Scoop',
      description: 'Decadent dark chocolate ice cream scoop with chocolate chips.',
      base_price: 250.0,
      image_url: 'assets/images/ice_cream_hero.jpg',
    },
    {
      id: 'item-icecream-strawberry',
      category_id: 'ice-cream',
      name: 'Fresh Strawberry Ice Cream Scoop',
      description: 'Natural strawberry chunks blended into creamy ice cream.',
      base_price: 250.0,
      image_url: 'assets/images/ice_cream_hero.jpg',
    },

    // -------------------------------------------------------------------------
    // 14. MOCKTAILS
    // -------------------------------------------------------------------------
    {
      id: 'item-mocktail-pink-lady',
      category_id: 'mocktails',
      name: 'Pink Lady Mocktail',
      description: 'Pomegranate and cranberry blend with citrus fizz and maraschino cherry.',
      base_price: 590.0,
      image_url: 'assets/images/pink.png',
    },
    {
      id: 'item-mocktail-pina-colada',
      category_id: 'mocktails',
      name: 'Pina Colada Mocktail',
      description: 'Creamy coconut cream shaken with fresh pineapple juice and crushed ice.',
      base_price: 650.0,
      image_url: 'assets/images/pina.png',
    },
    {
      id: 'item-mocktail-zinga-lady',
      category_id: 'mocktails',
      name: 'Zinga Lady Mocktail',
      description: 'Spiced ginger citrus cooler with soda and fresh orange garnish.',
      base_price: 650.0,
      image_url: 'assets/images/Zinga.png',
    },
    {
      id: 'item-mocktail-pineapple',
      category_id: 'mocktails',
      name: 'Pineapple (with coconut) Mocktail',
      description: 'Tropical pineapple puree layered with coconut nectar.',
      base_price: 590.0,
      image_url: 'assets/images/pineApple.png',
    },
    {
      id: 'item-mocktail-amazon-blast',
      category_id: 'mocktails',
      name: 'Amazon Blast Mocktail',
      description: 'Kiwi, green apple and passion fruit explosion over crushed ice.',
      base_price: 590.0,
      image_url: 'assets/images/Amazon.png',
    },
    {
      id: 'item-mocktail-blue-lady',
      category_id: 'mocktails',
      name: 'Blue Lady Colada Mocktail',
      description: 'Blue Curacao syrup infused coconut colada drink.',
      base_price: 590.0,
      image_url: 'assets/images/BlueLady.png',
    },

    // -------------------------------------------------------------------------
    // 15. MOJITO
    // -------------------------------------------------------------------------
    {
      id: 'item-mojito-blueberry',
      category_id: 'mojito',
      name: 'Blue Berry Mojito',
      description: 'Wild blueberry puree muddled with fresh mint, lime juice and soda.',
      base_price: 450.0,
      image_url: 'assets/images/blueBerry.png',
    },
    {
      id: 'item-mojito-bluelagoon',
      category_id: 'mojito',
      name: 'Blue Lagoon Mojito',
      description: 'Ocean blue citrus syrup, fresh mint sprigs and fizzy lemonade.',
      base_price: 450.0,
      image_url: 'assets/images/Blue lagon.png',
    },
    {
      id: 'item-mojito-greenapple',
      category_id: 'mojito',
      name: 'Green Apple Mojito',
      description: 'Tart green apple cordial with crushed ice and sparkling soda.',
      base_price: 450.0,
      image_url: 'assets/images/greenpple.png',
    },
    {
      id: 'item-mojito-strawberry',
      category_id: 'mojito',
      name: 'Strawberry Mojito',
      description: 'Ripe red strawberries muddled with mint and lemon fizz.',
      base_price: 450.0,
      image_url: 'assets/images/Strawberry.png',
    },
    {
      id: 'item-mojito-watermelon',
      category_id: 'mojito',
      name: 'Watermelon Mojito',
      description: 'Sweet fresh watermelon juice with mint and sparkling mineral water.',
      base_price: 450.0,
      image_url: 'assets/images/WaterMellon.png',
    },
    {
      id: 'item-mojito-passion',
      category_id: 'mojito',
      name: 'Passion Fruit Mojito',
      description: 'Exotic passion fruit pulp muddled with fresh mint and citrus soda.',
      base_price: 450.0,
      image_url: 'assets/images/passon.png',
    },
    {
      id: 'item-mojito-mint',
      category_id: 'mojito',
      name: 'Fresh Mint Lemon Mojito',
      description: 'Crushed ice, fresh mint sprigs, lime wedges and sparkling soda.',
      base_price: 350.0,
      image_url: 'assets/images/Mojito.png',
    },

    // -------------------------------------------------------------------------
    // 16. SMOOTHIES
    // -------------------------------------------------------------------------
    {
      id: 'item-smoothie-mango',
      category_id: 'smoothies',
      name: 'Mango Cream Smoothie',
      description: 'Creamy blended Sindhri mango with yogurt and honey.',
      base_price: 199.0,
      image_url: 'assets/images/MangoS.png',
    },
    {
      id: 'item-smoothie-banana',
      category_id: 'smoothies',
      name: 'Banana Milk Smoothie',
      description: 'Sweet banana smoothie whipped with milk and crushed ice.',
      base_price: 199.0,
      image_url: 'assets/images/BananaS.png',
    },
    {
      id: 'item-smoothie-mixberry',
      category_id: 'smoothies',
      name: 'Mix Berry Blast Smoothie',
      description: 'Strawberries, blackberries and raspberries blended thick.',
      base_price: 199.0,
      image_url: 'assets/images/MixBerry.png',
    },
    {
      id: 'item-smoothie-blueberry',
      category_id: 'smoothies',
      name: 'Blueberry Fresh Smoothie',
      description: 'Antioxidant rich wild blueberries whipped with Greek yogurt.',
      base_price: 199.0,
      image_url: 'assets/images/blueBerry.png',
    },
    {
      id: 'item-smoothie-strawberry',
      category_id: 'smoothies',
      name: 'Strawberry Swirl Smoothie',
      description: 'Fresh organic strawberries blended with creamy milk.',
      base_price: 199.0,
      image_url: 'assets/images/StrawBerryS.png',
    },

    // -------------------------------------------------------------------------
    // 17. ICE SHAKES
    // -------------------------------------------------------------------------
    {
      id: 'item-shake-mango',
      category_id: 'ice-shakes',
      name: 'Thick Mango Ice Shake',
      description: 'Luscious mango ice cream shaken thick with cold milk.',
      base_price: 590.0,
      image_url: 'assets/images/MangoI.png',
    },
    {
      id: 'item-shake-vanilla',
      category_id: 'ice-shakes',
      name: 'Rich Vanilla Ice Shake',
      description: 'French vanilla ice shake with whipped cream crown.',
      base_price: 590.0,
      image_url: 'assets/images/VanalaI.png',
    },
    {
      id: 'item-shake-caramel',
      category_id: 'ice-shakes',
      name: 'Salted Caramel Ice Shake',
      description: 'Salted caramel gelato blended with vanilla and toffee drizzle.',
      base_price: 590.0,
      image_url: 'assets/images/CarimalI.png',
    },
    {
      id: 'item-shake-chocolate',
      category_id: 'ice-shakes',
      name: 'Double Chocolate Ice Shake',
      description: 'Belgian chocolate shake loaded with chocolate drizzle.',
      base_price: 590.0,
      image_url: 'assets/images/ChocolateI.png',
    },
    {
      id: 'item-shake-strawberry',
      category_id: 'ice-shakes',
      name: 'Strawberry Ice Shake',
      description: 'Creamy strawberry ice cream shake with berry sprinkles.',
      base_price: 590.0,
      image_url: 'assets/images/StrawBerryI.png',
    },
    {
      id: 'item-shake-kulfa',
      category_id: 'ice-shakes',
      name: 'Thick Kulfa Ice Shake',
      description: 'Rich thick shake made with shahi kulfa ice cream and topped with almonds.',
      base_price: 590.0,
      image_url: 'assets/images/KulfaI.png',
    },

    // -------------------------------------------------------------------------
    // 18. MILK SHAKES
    // -------------------------------------------------------------------------
    {
      id: 'item-milkshake-apple',
      category_id: 'milk-shakes',
      name: 'Apple Milkshake',
      description: 'Fresh crisp apple slices blended with chilled sweet milk.',
      base_price: 400.0,
      image_url: 'assets/images/apples.png',
    },
    {
      id: 'item-milkshake-banana',
      category_id: 'milk-shakes',
      name: 'Banana Milkshake',
      description: 'Wholesome ripe banana milkshake with crushed pistachios.',
      base_price: 400.0,
      image_url: 'assets/images/BananaShake.png',
    },
    {
      id: 'item-milkshake-seasonal',
      category_id: 'milk-shakes',
      name: 'Seasonal Special Milkshake',
      description: 'Fresh seasonal market fruits whipped with chilled milk.',
      base_price: 400.0,
      image_url: 'assets/images/Sessional.png',
    },
    {
      id: 'item-milkshake-strawberry',
      category_id: 'milk-shakes',
      name: 'Strawberry Milkshake',
      description: 'Classic cold strawberry milkshake topped with berry foam.',
      base_price: 400.0,
      image_url: 'assets/images/StrawBerryS.png',
    },

    // -------------------------------------------------------------------------
    // 19. SOFT DRINKS
    // -------------------------------------------------------------------------
    {
      id: 'item-soft-fresh-lime',
      category_id: 'soft-drinks',
      name: 'Fresh Lime Soda',
      description: 'Freshly squeezed lime juice with 7Up/Sprite and black salt.',
      base_price: 250.0,
      image_url: 'assets/images/FreshLime.png',
    },
    {
      id: 'item-soft-mint-margarita',
      category_id: 'soft-drinks',
      name: 'Mint Margarita',
      description: 'Signature chilled green mint margarita with crushed ice and lemon.',
      base_price: 300.0,
      image_url: 'assets/images/Mint.png',
    },
  ];

  for (const item of menuItems) {
    const { sizes, options, ...itemData } = item;
    const upserted = await prisma.menuItem.upsert({
      where: { id: itemData.id },
      update: {
        category_id: itemData.category_id,
        name: itemData.name,
        description: itemData.description,
        base_price: itemData.base_price,
        image_url: itemData.image_url,
        is_spicy: itemData.is_spicy ?? false,
        is_veg: itemData.is_veg ?? false,
        is_available: true,
      },
      create: {
        id: itemData.id,
        category_id: itemData.category_id,
        name: itemData.name,
        description: itemData.description,
        base_price: itemData.base_price,
        image_url: itemData.image_url,
        is_spicy: itemData.is_spicy ?? false,
        is_veg: itemData.is_veg ?? false,
        is_available: true,
      },
    });

    if (sizes && sizes.length > 0) {
      await prisma.menuItemSize.deleteMany({ where: { menu_item_id: upserted.id } });
      await prisma.menuItemSize.createMany({
        data: sizes.map((s) => ({
          menu_item_id: upserted.id,
          size_name: s.size_name,
          price: s.price,
        })),
      });
    }

    if (options && options.length > 0) {
      await prisma.menuItemOption.deleteMany({ where: { menu_item_id: upserted.id } });
      await prisma.menuItemOption.createMany({
        data: options.map((o) => ({
          menu_item_id: upserted.id,
          option_type: o.option_type,
          option_name: o.option_name,
          additional_price: o.additional_price,
        })),
      });
    }
  }
  console.log(`✅ Seeded ${menuItems.length} menu items with sizes and options into PostgreSQL database`);

  console.log('🎁 Seeding Exclusive Deals & Combos...');

  const deals = [
    {
      id: 'deal-exclusive-combo',
      title: 'EXCLUSIVE DEALS (Pizza+Biryani+Panini+Shakes+Bottle)',
      subtitle: 'Ultimate Mega Feast for 4-6 Persons',
      deal_price: 2499.0,
      original_price: 3499.0,
      badge_text: 'HOT EXCLUSIVE DEAL',
      image_path: 'assets/images/image.jpg',
      description: '1 Large Pizza + 1 Chicken Biryani + 1 Panini + 2 Ice Shakes + 1.5L Bottle.',
      is_available: true,
      components: [
        { item_name: 'Large Classic Pizza', category: 'Pizza', quantity: '1x' },
        { item_name: 'Chicken Biryani Rice', category: 'Rice', quantity: '1x' },
        { item_name: 'Cheesy Panini Sandwich', category: 'Panini', quantity: '1x' },
        { item_name: 'Thick Ice Shakes', category: 'Shakes', quantity: '2x' },
        { item_name: '1.5L Pepsi Bottle', category: 'Drinks', quantity: '1x' },
      ],
    },
    {
      id: 'deal-family-feast',
      title: 'Family Feast Combo Deal',
      subtitle: 'Complete Party Spread for the Whole Family',
      deal_price: 3299.0,
      original_price: 4500.0,
      badge_text: 'FAMILY PACK',
      image_path: 'assets/images/Special.png',
      description: '2 Family Size Pizzas + 4 Crispy Dajjaj Broast + 1 Loaded Fries + 1.5L Coke Bottle.',
      is_available: true,
      components: [
        { item_name: 'Family Size Pizzas', category: 'Pizza', quantity: '2x' },
        { item_name: 'Crispy Dajjaj Broast Pieces', category: 'Brost', quantity: '4x' },
        { item_name: 'Hungry Loaded Fries Platter', category: 'Fries', quantity: '1x' },
        { item_name: '1.5L Cold Coke Bottle', category: 'Drinks', quantity: '1x' },
      ],
    },
    {
      id: 'deal-duo-craver',
      title: 'Duo Craver Pack',
      subtitle: 'Two Gourmet Burgers with Fries & Drinks',
      deal_price: 1649.0,
      original_price: 2199.0,
      badge_text: 'BURGER DUO',
      image_path: 'assets/images/beef_burger_hero.jpg',
      description: '2 Gourmet Beef or Chicken Burgers + 1 Large Garlic Mayo Fries + 2 Cold Drinks.',
      is_available: true,
      components: [
        { item_name: 'Gourmet Burgers (Beef/Chicken)', category: 'Burger', quantity: '2x' },
        { item_name: 'Large Garlic Mayo Fries', category: 'Fries', quantity: '1x' },
        { item_name: 'Soft Drink Tin Packs', category: 'Drinks', quantity: '2x' },
      ],
    },
    {
      id: 'deal-midnight-craving',
      title: 'Midnight Craving Deal',
      subtitle: 'Late Night Pizza & Panini Satisfier',
      deal_price: 1999.0,
      original_price: 2600.0,
      badge_text: 'NIGHT SPECIAL',
      image_path: 'assets/images/Pizza.png',
      description: '1 Large Classic Pizza + 1 Cheesy Panini Sandwich + 2 Soft Drinks.',
      is_available: true,
      components: [
        { item_name: 'Large Classic Pizza', category: 'Pizza', quantity: '1x' },
        { item_name: 'Cheesy Grilled Panini', category: 'Panini', quantity: '1x' },
        { item_name: 'Cold Beverages', category: 'Drinks', quantity: '2x' },
      ],
    },
    {
      id: 'deal-student-saver',
      title: 'Student Saver Deal',
      subtitle: 'Crunchy Zinger with Fries and Drink',
      deal_price: 749.0,
      original_price: 950.0,
      badge_text: 'STUDENT SPECIAL',
      image_path: 'assets/images/chicken_burger_hero.jpg',
      description: '1 Zinger Burger + 1 Plain Fries + 1 Cold Drink.',
      is_available: true,
      components: [
        { item_name: 'Crispy Zinger Burger', category: 'Burger', quantity: '1x' },
        { item_name: 'Plain French Fries', category: 'Fries', quantity: '1x' },
        { item_name: 'Cold Drink 500ml', category: 'Drinks', quantity: '1x' },
      ],
    },
  ];

  for (const deal of deals) {
    const { components, ...dealData } = deal;
    const upsertedDeal = await prisma.deal.upsert({
      where: { id: dealData.id },
      update: {
        title: dealData.title,
        subtitle: dealData.subtitle,
        deal_price: dealData.deal_price,
        original_price: dealData.original_price,
        badge_text: dealData.badge_text,
        image_path: dealData.image_path,
        description: dealData.description,
        is_available: dealData.is_available,
      },
      create: {
        id: dealData.id,
        title: dealData.title,
        subtitle: dealData.subtitle,
        deal_price: dealData.deal_price,
        original_price: dealData.original_price,
        badge_text: dealData.badge_text,
        image_path: dealData.image_path,
        description: dealData.description,
        is_available: dealData.is_available,
      },
    });

    if (components && components.length > 0) {
      await prisma.dealComponent.deleteMany({ where: { deal_id: upsertedDeal.id } });
      await prisma.dealComponent.createMany({
        data: components.map((c) => ({
          deal_id: upsertedDeal.id,
          item_name: c.item_name,
          category: c.category,
          quantity: c.quantity,
        })),
      });
    }
  }
  console.log(`✅ Seeded ${deals.length} exclusive deals into PostgreSQL database`);

  console.log('🔒 Seeding default role permissions into database...');
  const allPermissions = [...INITIAL_MANAGER_PERMISSIONS, ...INITIAL_CASHIER_PERMISSIONS];
  for (const p of allPermissions) {
    await prisma.rolePermission.upsert({
      where: { id: p.id },
      update: {
        role: p.role,
        module_name: p.module_name,
        action_name: p.action_name,
        description: p.description,
        is_granted: p.is_granted,
        is_sensitive: p.is_sensitive,
      },
      create: {
        id: p.id,
        role: p.role,
        module_name: p.module_name,
        action_name: p.action_name,
        description: p.description,
        is_granted: p.is_granted,
        is_sensitive: p.is_sensitive,
      },
    });
  }
  console.log('🛵 Seeding Pakistani delivery riders fleet into database...');
  const deliveryRiders = [
    {
      id: 'rider-pk-1',
      name: 'Muhammad Ali',
      phone: '+92 300 1234567',
      is_available: true,
      is_clocked_in: true,
      active_deliveries_count: 0,
      total_completed_deliveries: 52,
      avg_delivery_time_mins: 21.0,
      rating: 4.9,
    },
    {
      id: 'rider-pk-2',
      name: 'Hamza Khan',
      phone: '+92 312 9876543',
      is_available: true,
      is_clocked_in: true,
      active_deliveries_count: 0,
      total_completed_deliveries: 45,
      avg_delivery_time_mins: 23.5,
      rating: 4.8,
    },
    {
      id: 'rider-pk-3',
      name: 'Bilal Ahmed',
      phone: '+92 333 4567890',
      is_available: true,
      is_clocked_in: true,
      active_deliveries_count: 0,
      total_completed_deliveries: 38,
      avg_delivery_time_mins: 20.0,
      rating: 4.7,
    },
    {
      id: 'rider-pk-4',
      name: 'Usman Tariq',
      phone: '+92 345 6789012',
      is_available: true,
      is_clocked_in: true,
      active_deliveries_count: 0,
      total_completed_deliveries: 64,
      avg_delivery_time_mins: 19.5,
      rating: 4.9,
    },
    {
      id: 'rider-pk-5',
      name: 'Zubair Shah',
      phone: '+92 321 2345678',
      is_available: false,
      is_clocked_in: false,
      active_deliveries_count: 0,
      total_completed_deliveries: 29,
      avg_delivery_time_mins: 24.0,
      rating: 4.6,
    },
  ];

  for (const rider of deliveryRiders) {
    await prisma.deliveryRider.upsert({
      where: { phone: rider.phone },
      update: {
        name: rider.name,
        is_available: rider.is_available,
        is_clocked_in: rider.is_clocked_in,
        total_completed_deliveries: rider.total_completed_deliveries,
        avg_delivery_time_mins: rider.avg_delivery_time_mins,
        rating: rider.rating,
      },
      create: rider,
    });
  }
  console.log(`✅ Seeded ${deliveryRiders.length} Pakistani delivery riders into 'delivery_riders' table`);

  // Ensure full HTML menu is synchronized
  const { seedHtmlMenu } = await import('./seed_html_menu');
  await seedHtmlMenu(prisma);

  console.log('✨ All menu, staff, and restaurant data seeded successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
