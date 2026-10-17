import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

interface SizeSpec {
  size_name: string;
  price: number;
}

interface OptionSpec {
  option_type: string;
  option_name: string;
  additional_price: number;
}

interface ItemSpec {
  name: string;
  description?: string;
  base_price: number;
  image_url?: string;
  is_veg?: boolean;
  is_spicy?: boolean;
  sizes?: SizeSpec[];
  options?: OptionSpec[];
}

interface CategorySpec {
  id: string;
  name: string;
  badge_text: string;
  image_path: string;
  description: string;
  icon_name: string;
  items: ItemSpec[];
}

// Common Pizza Crusts and Toppings
const pizzaCrusts: OptionSpec[] = [
  { option_type: 'crust', option_name: 'Original Crust', additional_price: 0 },
  { option_type: 'crust', option_name: 'Butter Cheese Crust', additional_price: 150 },
  { option_type: 'crust', option_name: 'Garlic Herb Crust', additional_price: 120 },
  { option_type: 'crust', option_name: 'Cajun Crust', additional_price: 120 },
  { option_type: 'crust', option_name: 'Sesame Crust', additional_price: 100 },
];

const pizzaToppings: OptionSpec[] = [
  { option_type: 'topping', option_name: 'Extra Mozzarella Cheese', additional_price: 200 },
  { option_type: 'topping', option_name: 'Mushrooms', additional_price: 100 },
  { option_type: 'topping', option_name: 'Jalapenos', additional_price: 80 },
  { option_type: 'topping', option_name: 'Black Olives', additional_price: 90 },
  { option_type: 'topping', option_name: 'Extra Chicken', additional_price: 180 },
];

const classicPizzaSizes: SizeSpec[] = [
  { size_name: 'Small', price: 849 },
  { size_name: 'Medium', price: 1449 },
  { size_name: 'Large', price: 1749 },
  { size_name: 'Family', price: 2349 },
];

const modernPizzaSizes: SizeSpec[] = [
  { size_name: 'Small', price: 849 },
  { size_name: 'Medium', price: 1549 },
  { size_name: 'Large', price: 1999 },
  { size_name: 'Family', price: 2499 },
];

const crownCrustSizes: SizeSpec[] = [
  { size_name: 'Medium', price: 1549 },
  { size_name: 'Large', price: 1999 },
  { size_name: 'Family', price: 2499 },
];

const specialPizzaSizes: SizeSpec[] = [
  { size_name: 'Medium', price: 1699 },
  { size_name: 'Large', price: 2199 },
  { size_name: 'Family', price: 2999 },
];

const steakOptions: OptionSpec[] = [
  { option_type: 'side', option_name: 'Mash Potato', additional_price: 0 },
  { option_type: 'side', option_name: 'Plain', additional_price: 0 },
  { option_type: 'addon', option_name: 'Crispy Chessy Potato', additional_price: 150 },
];

const beefPattyOptions: OptionSpec[] = [
  { option_type: 'patty', option_name: '150g Patty', additional_price: 0 },
  { option_type: 'patty', option_name: '200g Patty', additional_price: 150 },
  { option_type: 'patty', option_name: '250g Patty', additional_price: 250 },
];

const iceCreamSizes: SizeSpec[] = [
  { size_name: 'Single Scope', price: 199 },
  { size_name: 'Double Scope', price: 399 },
];

const menuData: CategorySpec[] = [
  // 1. Pakistani Karahi
  {
    id: 'pakistani-karahi',
    name: 'Pakistani Karahi',
    badge_text: 'Karahi & Handi',
    image_path: 'assets/images/pakistani_karahi.jpg',
    description: 'Authentic Pakistani Chicken Karahi, Handi & aromatic Biryani cooked with rich spices and herbs.',
    icon_name: 'local_fire_department_rounded',
    items: [
      {
        name: 'Chicken Karahi',
        description: 'Authentic Pakistani chicken karahi cooked in traditional wok with fresh tomatoes and ginger.',
        base_price: 1099,
        image_url: 'assets/images/pakistani_karahi.jpg',
        sizes: [
          { size_name: 'Half', price: 1099 },
          { size_name: 'Full', price: 1999 },
        ],
      },
      {
        name: 'Lemon chilli chicken Karahi',
        description: 'Tangy and spicy chicken karahi flavored with fresh green chillies and lemon juice.',
        base_price: 1099,
        image_url: 'assets/images/pakistani_karahi.jpg',
        is_spicy: true,
        sizes: [
          { size_name: 'Half', price: 1099 },
          { size_name: 'Full', price: 1999 },
        ],
      },
      {
        name: 'Special Green Handi',
        description: 'Creamy boneless chicken cooked in clay handi with rich coriander, mint, and green chilli masala.',
        base_price: 1199,
        image_url: 'assets/images/pakistani_karahi.jpg',
        sizes: [
          { size_name: 'Half', price: 1199 },
          { size_name: 'Full', price: 2099 },
        ],
      },
      {
        name: 'Butter chicken Handi',
        description: 'Makhni style tender chicken cooked with pure butter, cream, and aromatic spices.',
        base_price: 1299,
        image_url: 'assets/images/pakistani_karahi.jpg',
        sizes: [
          { size_name: 'Half', price: 1299 },
          { size_name: 'Full', price: 2199 },
        ],
      },
      {
        name: 'Chicken Ginger',
        description: 'Boneless chicken infused with freshly julienned ginger, garlic, and special spices.',
        base_price: 1199,
        image_url: 'assets/images/pakistani_karahi.jpg',
        sizes: [
          { size_name: 'Half', price: 1199 },
          { size_name: 'Full', price: 2099 },
        ],
      },
      {
        name: 'White chicken Handi',
        description: 'Rich and creamy white gravy handi cooked with almonds, cream, and mild black pepper.',
        base_price: 1299,
        image_url: 'assets/images/pakistani_karahi.jpg',
        sizes: [
          { size_name: 'Half', price: 1299 },
          { size_name: 'Full', price: 2199 },
        ],
      },
    ],
  },

  // 2. Biryani
  {
    id: 'biryani',
    name: 'Biryani',
    badge_text: 'Biryani',
    image_path: 'assets/images/pakistani_biryani.jpg',
    description: 'Aromatic Bombay Chicken Biryani and Hungry Special Biryani cooked with fragrant basmati rice.',
    icon_name: 'restaurant_menu_rounded',
    items: [
      {
        name: 'Bombay chicken Baryani',
        description: 'Traditional aromatic basmati rice layered with spiced chicken, potatoes, and prunes.',
        base_price: 385,
        image_url: 'assets/images/pakistani_biryani.jpg',
        sizes: [
          { size_name: 'Half', price: 385 },
          { size_name: 'Full', price: 699 },
        ],
      },
      {
        name: 'Hungry special Baryani',
        description: 'Chef signature spicy and flavorful chicken biryani prepared with extra tender chicken and royal spices.',
        base_price: 450,
        image_url: 'assets/images/pakistani_biryani.jpg',
        sizes: [
          { size_name: 'Half', price: 450 },
          { size_name: 'Full', price: 800 },
        ],
      },
    ],
  },

  // 3. Pizza
  {
    id: 'pizza',
    name: 'Pizza',
    badge_text: 'Pizza',
    image_path: 'assets/images/Pizza.png',
    description: 'Melted cheese, chicken toppings, colorful vegetables & crispy charred crust.',
    icon_name: 'local_pizza_rounded',
    items: [
      // Classic
      {
        name: 'Fajita Pizza',
        description: 'Spiced fajita chicken, onions, bell peppers and premium mozzarella cheese.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Chicken Tikka',
        description: 'Traditional spiced barbecue chicken tikka chunks with onions and mozzarella.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Malai Boti',
        description: 'Creamy marinated malai boti chicken chunks with mild spices and melted cheese.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Sausage Chesse',
        description: 'Delicious chicken sausages layered over rich marinara and double mozzarella.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Hot & Spicy',
        description: 'Fiery chicken chunks, hot jalapenos, onions, tomatoes and spicy sauce.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        is_spicy: true,
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Tandoori Bonfire',
        description: 'Tandoori marinated chicken, bonfire smoke aroma, red onions and capsicum.',
        base_price: 849,
        image_url: 'assets/images/Fajita.png',
        sizes: classicPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },

      // Modern
      {
        name: 'Ring Pizza',
        description: 'Unique ring-shaped stuffed crust pizza loaded with savory fillings.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Crown Crust',
        description: 'Regal crown crust pockets filled with chicken kebab and cheese balls.',
        base_price: 1549,
        image_url: 'assets/images/Modern.png',
        sizes: crownCrustSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Peperoni Passion',
        description: 'Generous layers of premium pepperoni and melted mozzarella cheese.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Doner Kebab',
        description: 'Authentic doner kebab slices, garlic drizzle, and melted cheese.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Kebab Stuffer',
        description: 'Stuffed crust perimeter packed with juicy seekh kebab and spices.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Cheese Stick',
        description: 'Crispy golden baked cheese stick crust packed with stringy mozzarella.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Chicken Stuffer',
        description: 'Deep stuffed crust filled with seasoned shredded chicken and cream cheese.',
        base_price: 849,
        image_url: 'assets/images/Modern.png',
        sizes: modernPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },

      // Special
      {
        name: 'Arabic Crispy',
        description: 'Crispy Arabic spiced chicken tenders, special garlic tahini sauce and herbs.',
        base_price: 1699,
        image_url: 'assets/images/Special.png',
        sizes: specialPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
      {
        name: 'Hungry Cheese Gold Pizza',
        description: 'Chef signature luxury gold pizza with triple layer mozzarella, cheddar, and gouda.',
        base_price: 1699,
        image_url: 'assets/images/Special.png',
        sizes: specialPizzaSizes,
        options: [...pizzaCrusts, ...pizzaToppings],
      },
    ],
  },

  // 4. Chicken Steak
  {
    id: 'chicken-steak',
    name: 'Chicken Steak',
    badge_text: 'Steak',
    image_path: 'assets/images/chicken_steak.png',
    description: 'Tender grilled chicken steak with creamy sauce, mashed potato & vegetables.',
    icon_name: 'set_meal_rounded',
    items: [
      {
        name: 'Tarragon',
        description: 'Grilled chicken fillet topped with classic creamy French tarragon herb sauce.',
        base_price: 1499,
        image_url: 'assets/images/chicken_steak.png',
        options: steakOptions,
      },
      {
        name: 'Mashroom',
        description: 'Tender chicken breast served with rich sautéed wild mushroom cream sauce.',
        base_price: 1499,
        image_url: 'assets/images/chicken_steak.png',
        options: steakOptions,
      },
      {
        name: 'Twin Steak',
        description: 'Dual grilled chicken fillets served with duo signature sauces for double flavor.',
        base_price: 1599,
        image_url: 'assets/images/chicken_steak.png',
        options: steakOptions,
      },
      {
        name: 'Smoked BBQ',
        description: 'Flame grilled chicken steak glazed in sweet, tangy and hickory smoked BBQ sauce.',
        base_price: 1499,
        image_url: 'assets/images/chicken_steak.png',
        options: steakOptions,
      },
      {
        name: 'Hot Shot Jalapeno',
        description: 'Fiery grilled steak smothered in spicy jalapeno pepper cream sauce.',
        base_price: 1499,
        image_url: 'assets/images/chicken_steak.png',
        is_spicy: true,
        options: steakOptions,
      },
      {
        name: 'Mexican Hot & Spicy',
        description: 'Zesty Mexican seasoned chicken steak accompanied by spicy tomato salsa sauce.',
        base_price: 1499,
        image_url: 'assets/images/chicken_steak.png',
        is_spicy: true,
        options: steakOptions,
      },
    ],
  },

  // 5. Burger
  {
    id: 'burger',
    name: 'Burger',
    badge_text: 'Burger',
    image_path: 'assets/images/beef_burger_hero.jpg',
    description: 'Gourmet beef & chicken burgers with melted cheese, lettuce, tomato & brioche bun.',
    icon_name: 'lunch_dining_rounded',
    items: [
      // Beef
      {
        name: 'Beef Cheese Stuff Burger',
        description: 'Thick grilled beef patty stuffed with melted cheese center, pickles, and signature sauce.',
        base_price: 1349,
        image_url: 'assets/images/beef_burger_hero.jpg',
        options: beefPattyOptions,
      },
      {
        name: 'Hungry Stacker',
        description: 'Double stacked prime beef patties layered with cheddar cheese, caramelized onions and relish.',
        base_price: 1349,
        image_url: 'assets/images/beef_burger_hero.jpg',
        options: beefPattyOptions,
      },
      {
        name: 'The Smashroom',
        description: 'Smashed beef patty with melted swiss cheese, sautéed mushrooms and garlic herb aioli.',
        base_price: 1099,
        image_url: 'assets/images/beef_burger_hero.jpg',
        options: beefPattyOptions,
      },
      {
        name: 'Mexicano Beef',
        description: 'Spicy seasoned beef patty topped with jalapenos, salsa, and pepper jack cheese.',
        base_price: 999,
        image_url: 'assets/images/beef_burger_hero.jpg',
        is_spicy: true,
        options: beefPattyOptions,
      },
      {
        name: 'Classic Beef',
        description: 'Timeless flame-broiled beef patty with crisp lettuce, fresh tomato, onion and mayo.',
        base_price: 999,
        image_url: 'assets/images/beef_burger_hero.jpg',
        options: beefPattyOptions,
      },

      // Chicken
      {
        name: 'Hungry Special',
        description: 'Chef special crispy chicken fillet loaded with double cheese and secret Howie sauce.',
        base_price: 899,
        image_url: 'assets/images/chicken_burger_hero.jpg',
      },
      {
        name: 'Crispy BBQ',
        description: 'Golden crispy chicken fillet smothered in smoky BBQ sauce with crunchy slaw.',
        base_price: 999,
        image_url: 'assets/images/chicken_burger_hero.jpg',
      },
      {
        name: 'Juicy Lucy',
        description: 'Tender marinated chicken breast fillet grilled to juicy perfection with herb mayo.',
        base_price: 899,
        image_url: 'assets/images/chicken_burger_hero.jpg',
      },
      {
        name: 'Student Burger',
        description: 'Pocket-friendly crispy fried chicken burger seasoned with tasty spices.',
        base_price: 450,
        image_url: 'assets/images/chicken_burger_hero.jpg',
      },
      {
        name: 'Zeleto Zinger',
        description: 'Extra spicy crispy zinger chicken fillet with egg, lettuce and hot chili drizzle.',
        base_price: 549,
        image_url: 'assets/images/chicken_burger_hero.jpg',
        is_spicy: true,
      },
      {
        name: 'Zinger Burger',
        description: 'Crispy fried spicy zinger chicken thigh with crunchy lettuce and creamy mayo.',
        base_price: 499,
        image_url: 'assets/images/chicken_burger_hero.jpg',
        is_spicy: true,
      },
    ],
  },

  // 6. Dajjaj Brost
  {
    id: 'dajjaj-brost',
    name: 'Dajjaj Brost',
    badge_text: 'Brost',
    image_path: 'assets/images/broast_hero.jpg',
    description: 'Golden crispy broast chicken pieces served with fries, garlic dip & lemon.',
    icon_name: 'restaurant_rounded',
    items: [
      {
        name: 'Half Broast (with Fries & Garlic Sauce)',
        description: 'Crispy golden fried broast chicken half portion served with salted fries and garlic dip.',
        base_price: 1250,
        image_url: 'assets/images/broast_hero.jpg',
      },
      {
        name: 'Family Broast (with Fries & Garlic Sauce)',
        description: 'Full family feast crispy golden broast chicken served with extra fries and signature garlic sauce.',
        base_price: 2400,
        image_url: 'assets/images/broast_hero.jpg',
      },
    ],
  },

  // 7. Pasta
  {
    id: 'pasta',
    name: 'Pasta',
    badge_text: 'Pasta',
    image_path: 'assets/images/pasta_hero.jpg',
    description: 'Creamy chicken Alfredo pasta with parmesan cheese, Italian herbs & grilled chicken.',
    icon_name: 'ramen_dining_rounded',
    items: [
      {
        name: 'Chicken Alfredo',
        description: 'Creamy Alfredo sauce, grilled chicken, parmesan cheese, and fresh herbs.',
        base_price: 999,
        image_url: 'assets/images/pasta_hero.jpg',
      },
      {
        name: 'Penne Arrabiata',
        description: 'Penne pasta cooked in spicy Arrabiata sauce with Italian herbs and garlic.',
        base_price: 999,
        image_url: 'assets/images/penne.png',
        is_spicy: true,
      },
      {
        name: 'Hungry Parmesan',
        description: 'Signature parmesan pasta loaded with creamy cheese and premium seasonings.',
        base_price: 1099,
        image_url: 'assets/images/Permission.png',
      },
    ],
  },

  // 8. Panini
  {
    id: 'panini',
    name: 'Panini',
    badge_text: 'Panini',
    image_path: 'assets/images/panini_hero.jpg',
    description: 'Toasted grilled panini sandwich with melted cheese, chicken & fresh vegetables.',
    icon_name: 'breakfast_dining_rounded',
    items: [
      {
        name: 'Chessey Panini',
        description: 'Loaded with melted cheese, fresh vegetables, and toasted artisan bread. Served with fries & coleslaw.',
        base_price: 1099,
        image_url: 'assets/images/panini_hero.jpg',
      },
      {
        name: 'Hungry Club',
        description: 'A classic club-style panini filled with premium ingredients and signature sauces. Served with fries & coleslaw.',
        base_price: 849,
        image_url: 'assets/images/panini_hero.jpg',
      },
      {
        name: 'Special BBQ',
        description: 'Smoky BBQ flavor combined with grilled fillings and perfectly toasted bread. Served with fries & coleslaw.',
        base_price: 849,
        image_url: 'assets/images/panini_hero.jpg',
      },
    ],
  },

  // 9. Appetizer
  {
    id: 'appetizer',
    name: 'Appetizer',
    badge_text: 'Appetizer',
    image_path: 'assets/images/appetizer_hero.jpg',
    description: 'Crispy nuggets, wings, french fries & dipping sauces served on a platter.',
    icon_name: 'tapas_rounded',
    items: [
      {
        name: 'Nuggets (with Fries) - 6pcs',
        description: 'Golden crispy chicken nuggets served with fresh fries and signature dipping sauce.',
        base_price: 399,
        image_url: 'assets/images/Nuggets.png',
      },
      {
        name: 'Crispy Wings - 6pcs',
        description: 'Crunchy chicken wings seasoned and fried to perfection.',
        base_price: 399,
        image_url: 'assets/images/Wings.png',
      },
      {
        name: 'Peri-Peri Wings - 6pcs',
        description: 'Spicy peri-peri flavored wings with a bold and zesty taste.',
        base_price: 499,
        image_url: 'assets/images/peri.png',
        is_spicy: true,
      },
      {
        name: 'Honey BBQ Wings - 6pcs',
        description: 'Sweet and smoky BBQ wings glazed with rich honey sauce.',
        base_price: 499,
        image_url: 'assets/images/Honey.png',
      },
    ],
  },

  // 10. Fries
  {
    id: 'fries',
    name: 'Fries',
    badge_text: 'Fries',
    image_path: 'assets/images/fries_hero.jpg',
    description: 'Golden crispy French fries including loaded fries with melted cheese & sauces.',
    icon_name: 'fastfood_rounded',
    items: [
      {
        name: 'Hungry Loaded Fries',
        description: 'Crispy fries topped with premium sauces, cheese, and signature loaded toppings.',
        base_price: 749,
        image_url: 'assets/images/Loaded.png',
      },
      {
        name: 'Honey Mustard Fries',
        description: 'Golden fries coated with rich honey mustard sauce for a sweet and tangy flavor.',
        base_price: 449,
        image_url: 'assets/images/Mustard.png',
      },
      {
        name: 'Garlic Mayo Fries',
        description: 'Freshly cooked fries served with creamy garlic mayonnaise.',
        base_price: 499,
        image_url: 'assets/images/Garlic.png',
      },
      {
        name: 'Masala Fries',
        description: 'Crispy fries tossed with flavorful house special masala seasoning.',
        base_price: 299,
        image_url: 'assets/images/Masala.png',
        is_spicy: true,
      },
      {
        name: 'Plain Fries',
        description: 'Classic golden fries cooked to perfection with a crispy exterior.',
        base_price: 279,
        image_url: 'assets/images/Simple.png',
      },
      {
        name: 'BBQ Fries',
        description: 'Loaded with smoky BBQ flavor and premium seasonings.',
        base_price: 449,
        image_url: 'assets/images/BBQ_Fries.png',
      },
    ],
  },

  // 11. Soup
  {
    id: 'soup',
    name: 'Soup',
    badge_text: 'Soup',
    image_path: 'assets/images/delicious_soup.jpg',
    description: 'Warm, rich & comforting Hot & Sour, Corn, and Hungry Special Soups.',
    icon_name: 'soup_kitchen_rounded',
    items: [
      {
        name: 'Hot and Savour soup',
        description: 'Classic hot and sour chicken soup with shredded vegetables, egg drops and spicy seasoning.',
        base_price: 399,
        image_url: 'assets/images/delicious_soup.jpg',
        is_spicy: true,
        sizes: [
          { size_name: 'Half', price: 399 },
          { size_name: 'Full', price: 849 },
        ],
      },
      {
        name: 'Corn soup',
        description: 'Mild, sweet and rich chicken corn soup prepared with fresh sweet corn kernels.',
        base_price: 349,
        image_url: 'assets/images/delicious_soup.jpg',
        sizes: [
          { size_name: 'Half', price: 349 },
          { size_name: 'Full', price: 799 },
        ],
      },
      {
        name: 'Hungry special soup',
        description: 'Signature hearty soup loaded with chicken chunks, mushrooms, prawns and secret herbs.',
        base_price: 599,
        image_url: 'assets/images/delicious_soup.jpg',
        sizes: [
          { size_name: 'Half', price: 599 },
          { size_name: 'Full', price: 999 },
        ],
      },
    ],
  },

  // 12. Tandoori
  {
    id: 'tandoori',
    name: 'Tandoori',
    badge_text: 'Tandoori',
    image_path: 'assets/images/tandoori_naan.jpg',
    description: 'Freshly baked Roti, Roghni Naan, Sada Naan & Kalwanji Naan straight from clay tandoor.',
    icon_name: 'bakery_dining_rounded',
    items: [
      {
        name: 'Roti',
        description: 'Freshly baked whole wheat flatbread made in hot clay tandoor.',
        base_price: 30,
        image_url: 'assets/images/tandoori_naan.jpg',
        is_veg: true,
      },
      {
        name: 'Sada naan',
        description: 'Soft and fluffy white flour tandoori naan bread.',
        base_price: 50,
        image_url: 'assets/images/tandoori_naan.jpg',
        is_veg: true,
      },
      {
        name: 'Roghni naan',
        description: 'Rich tandoori naan brushed with butter, sesame seeds and milk wash.',
        base_price: 99,
        image_url: 'assets/images/tandoori_naan.jpg',
        is_veg: true,
      },
      {
        name: 'Klwanji naan',
        description: 'Aromatic tandoori naan topped with black nigella seeds and butter.',
        base_price: 99,
        image_url: 'assets/images/tandoori_naan.jpg',
        is_veg: true,
      },
    ],
  },

  // 13. Salad
  {
    id: 'salad',
    name: 'Salad & Raita',
    badge_text: 'Salad & Raita',
    image_path: 'assets/images/salad_raita_hero.jpg',
    description: 'Fresh crispy Green Salad and soothing Zeera Raita to complement your meal.',
    icon_name: 'eco_rounded',
    items: [
      {
        name: 'Grean salad',
        description: 'Crisp cucumber, tomatoes, onions, carrots, and fresh lemon wedges.',
        base_price: 120,
        image_url: 'assets/images/salad_raita_hero.jpg',
        is_veg: true,
      },
      {
        name: 'Zeera Raita',
        description: 'Cool whisked yogurt infused with roasted cumin seeds and fine herbs.',
        base_price: 99,
        image_url: 'assets/images/salad_raita_hero.jpg',
        is_veg: true,
      },
    ],
  },

  // 14. Beverages
  {
    id: 'beverages',
    name: 'Beverages',
    badge_text: 'Drinks',
    image_path: 'assets/images/beverages_hero.jpg',
    description: 'Ice-cold soft drinks, bottled mineral water & cold beverages with ice condensation.',
    icon_name: 'local_drink_rounded',
    items: [
      {
        name: 'NR Coke',
        description: 'Refreshing Coca-Cola served chilled for the perfect meal companion.',
        base_price: 100,
        image_url: 'assets/images/Coke.png',
      },
      {
        name: 'NR Sprite',
        description: 'Lemon-lime flavored soft drink with a crisp and refreshing taste.',
        base_price: 100,
        image_url: 'assets/images/Sprite.png',
      },
      {
        name: 'Coke Tin Pack',
        description: 'Premium canned Coca-Cola served ice cold.',
        base_price: 160,
        image_url: 'assets/images/CokeTin.png',
      },
      {
        name: 'Sprite Tin Pack',
        description: 'Refreshing canned Sprite with a crisp citrus flavor.',
        base_price: 160,
        image_url: 'assets/images/SpriteTin.png',
      },
      {
        name: 'Mineral Water',
        description: 'Pure and refreshing bottled mineral water.',
        base_price: 80,
        image_url: 'assets/images/Mineral.png',
      },
    ],
  },

  // 15. Extra Topping
  {
    id: 'extra-topping',
    name: 'Extra Topping',
    badge_text: 'Topping',
    image_path: 'assets/images/toppings_hero.jpg',
    description: 'Melted cheese, BBQ sauce, garlic mayo, jalapeno sauce & honey mustard.',
    icon_name: 'category_rounded',
    items: [
      {
        name: 'Chesse',
        description: 'Extra portion of melted mozzarella and cheddar cheese blend.',
        base_price: 200,
        image_url: 'assets/images/Cheese.png',
      },
      {
        name: 'BBQ Sauce',
        description: 'Rich, smoky, sweet and savory barbecue dipping sauce.',
        base_price: 150,
        image_url: 'assets/images/BBqSauce.png',
      },
      {
        name: 'Garlic Mayo',
        description: 'Creamy garlic infused mayonnaise dressing.',
        base_price: 150,
        image_url: 'assets/images/GarlicMayo.png',
      },
      {
        name: 'Mash Potato',
        description: 'Velvety smooth mashed potato with butter and milk.',
        base_price: 250,
        image_url: 'assets/images/MeshPatato.png',
      },
      {
        name: 'Jalapino Sauce',
        description: 'Spicy and tangy jalapeno pepper sauce.',
        base_price: 150,
        image_url: 'assets/images/Jalapino.png',
        is_spicy: true,
      },
      {
        name: 'Honey Mustard',
        description: 'Sweet honey blended with zesty whole grain mustard.',
        base_price: 150,
        image_url: 'assets/images/HoneyMustord.png',
      },
    ],
  },

  // 16. Hot Beverages
  {
    id: 'hot-beverages',
    name: 'Hot Beverages',
    badge_text: 'Hot Coffee',
    image_path: 'assets/images/hot_beverages_hero.jpg',
    description: 'Cappuccino, espresso, latte, hot chocolate & brewed tea cups with steam.',
    icon_name: 'coffee_rounded',
    items: [
      {
        name: 'Cappucino Coffee',
        description: 'Freshly brewed espresso layered with warm, thick milk foam art.',
        base_price: 599,
        image_url: 'assets/images/Capachino.png',
      },
      {
        name: 'Americano',
        description: 'A classic rich espresso shot diluted with hot water for a smooth finish.',
        base_price: 399,
        image_url: 'assets/images/Amercino.png',
      },
      {
        name: 'Espresso (Single Shot)',
        description: 'A full-bodied, intense single shot of premium coffee concentrate.',
        base_price: 399,
        image_url: 'assets/images/Expresso.png',
      },
      {
        name: 'Espresso (Double Shot)',
        description: 'An extra bold double shot of our premium espresso blend.',
        base_price: 750,
        image_url: 'assets/images/ExpressoDouble.png',
      },
      {
        name: 'Hot Chocolate',
        description: 'Rich, creamy melted chocolate topped with sweet milk foam.',
        base_price: 699,
        image_url: 'assets/images/Hot_Chocolate.png',
      },
      {
        name: 'Mocha',
        description: 'The perfect blend of espresso, steamed milk, and rich chocolate sauce.',
        base_price: 650,
        image_url: 'assets/images/Mocha.png',
      },
      {
        name: 'Latte',
        description: 'Steamed milk and a shot of rich espresso topped with a thin layer of foam.',
        base_price: 580,
        image_url: 'assets/images/Latte.png',
      },
      {
        name: 'Mix Tea',
        description: 'Traditional black tea brewed with fresh milk and cardamom.',
        base_price: 200,
        image_url: 'assets/images/mix.png',
      },
      {
        name: 'Green Tea',
        description: 'Refreshing, warm green tea packed with healthy antioxidants.',
        base_price: 120,
        image_url: 'assets/images/Greentead.png',
        is_veg: true,
      },
    ],
  },

  // 17. Cold Coffee
  {
    id: 'cold-coffee',
    name: 'Cold Coffee',
    badge_text: 'Iced Coffee',
    image_path: 'assets/images/cold_coffee_hero.jpg',
    description: 'Caramel iced latte, vanilla iced latte, mocha & strawberry iced latte with ice.',
    icon_name: 'icecream_rounded',
    items: [
      {
        name: 'Strawberry Iced Latte',
        description: 'A pink, creamy iced latte infused with natural sweet strawberry puree layers.',
        base_price: 599,
        image_url: 'assets/images/Strawberry.png',
      },
      {
        name: 'Caramel Iced Latte',
        description: 'Iced espresso and cold milk sweetened with golden buttery caramel drizzle.',
        base_price: 599,
        image_url: 'assets/images/Cerimal.png',
      },
      {
        name: 'Vanilla Iced Latte',
        description: 'Smooth iced latte flavored with rich, premium aromatic vanilla extract.',
        base_price: 599,
        image_url: 'assets/images/Venala.png',
      },
      {
        name: 'Mocha Iced Latte',
        description: 'Chilled milk, espresso, and delicious chocolate sauce served over ice.',
        base_price: 599,
        image_url: 'assets/images/Mocha_Lead.png',
      },
      {
        name: 'Iced Dark Chocolate',
        description: 'A decadent iced dark chocolate beverage topped with rich chocolate shavings.',
        base_price: 750,
        image_url: 'assets/images/Ice_dark.png',
      },
    ],
  },

  // 18. Ice Cream
  {
    id: 'ice-cream',
    name: 'Ice Cream',
    badge_text: 'Ice Cream',
    image_path: 'assets/images/ice_cream_hero.jpg',
    description: 'Kulfa, mango, vanilla, chocolate & strawberry scoops in elegant bowls.',
    icon_name: 'cookie_rounded',
    items: [
      {
        name: 'Kulfa',
        description: 'Traditional rich and nutty desi kulfa ice cream scoop.',
        base_price: 199,
        image_url: 'assets/images/KulfaI.png',
        sizes: iceCreamSizes,
      },
      {
        name: 'Mango',
        description: 'Sweet and luscious ripe mango ice cream scoop.',
        base_price: 199,
        image_url: 'assets/images/MangoI.png',
        sizes: iceCreamSizes,
      },
      {
        name: 'Vanilla',
        description: 'Creamy Madagascar vanilla bean ice cream scoop.',
        base_price: 199,
        image_url: 'assets/images/VanalaI.png',
        sizes: iceCreamSizes,
      },
      {
        name: 'Chocolate',
        description: 'Rich and decadent dark Belgian chocolate ice cream scoop.',
        base_price: 199,
        image_url: 'assets/images/ChocolateI.png',
        sizes: iceCreamSizes,
      },
      {
        name: 'Strawberry',
        description: 'Sweet and refreshing pink strawberry swirl ice cream scoop.',
        base_price: 199,
        image_url: 'assets/images/StrawBerryI.png',
        sizes: iceCreamSizes,
      },
    ],
  },

  // 19. Mocktails
  {
    id: 'mocktails',
    name: 'Mocktails',
    badge_text: 'Mocktail',
    image_path: 'assets/images/mocktails_hero.jpg',
    description: 'Vibrant colorful mocktails in elegant glasses with fresh fruit & mint garnishes.',
    icon_name: 'local_bar_rounded',
    items: [
      {
        name: 'Pink Lady',
        description: 'Vibrant pink tropical beverage served with a strawberry/citrus garnish.',
        base_price: 590,
        image_url: 'assets/images/pink.png',
      },
      {
        name: 'Pina Colada',
        description: 'Classic rich and creamy mocktail blended with sweet coconut and fresh pineapple.',
        base_price: 650,
        image_url: 'assets/images/pina.png',
      },
      {
        name: 'Zinga Lady',
        description: 'A colorful tropical zesty blend served chilled with a fresh fruit garnish.',
        base_price: 650,
        image_url: 'assets/images/Zinga.png',
      },
      {
        name: 'Pineapple (with coconut)',
        description: 'Chilled pineapple juice layered with creamy sweet coconut syrup flavor.',
        base_price: 590,
        image_url: 'assets/images/pineApple.png',
      },
      {
        name: 'Amazone Blast',
        description: 'An exotic colorful layered mocktail packed with sweet tropical fruit juices.',
        base_price: 590,
        image_url: 'assets/images/Amazon.png',
      },
      {
        name: 'Blue Lady Colada',
        description: 'Bright blue tropical coconut colada served in a premium glass.',
        base_price: 590,
        image_url: 'assets/images/BlueLady.png',
      },
    ],
  },

  // 20. Mojito
  {
    id: 'mojito',
    name: 'Mojito',
    badge_text: 'Mojito',
    image_path: 'assets/images/Mojito.png',
    description: 'Fresh mojitos with crushed ice, mint leaves, lime slices & fruit flavors.',
    icon_name: 'local_cafe_rounded',
    items: [
      {
        name: 'Blue Berry',
        description: 'Deep blueberry/purple mojito infused with fresh blueberries, lime, and mint.',
        base_price: 450,
        image_url: 'assets/images/blueBerry.png',
      },
      {
        name: 'Blue Lagon',
        description: 'Vibrant blue drink with lime slices, mint leaves, and crushed ice.',
        base_price: 450,
        image_url: 'assets/images/Blue lagon.png',
      },
      {
        name: 'Green Apple',
        description: 'Crispy green apple flavors blended with fresh lime, mint, and sparkling soda.',
        base_price: 450,
        image_url: 'assets/images/greenpple.png',
      },
      {
        name: 'Strawberry',
        description: 'Bright red strawberry mojito with fresh strawberry slices and mint garnish.',
        base_price: 450,
        image_url: 'assets/images/Strawberry.png',
      },
      {
        name: 'Watermelon',
        description: 'Fresh watermelon-red mojito served with sliced watermelon and fresh mint leaves.',
        base_price: 450,
        image_url: 'assets/images/WaterMellon.png',
      },
      {
        name: 'Passion Fruit',
        description: 'Golden tropical passion fruit pulp served with fresh citrus and mint leaves.',
        base_price: 450,
        image_url: 'assets/images/passon.png',
      },
    ],
  },

  // 21. Smoothies
  {
    id: 'smoothies',
    name: 'Smoothies',
    badge_text: 'Smoothie',
    image_path: 'assets/images/Smooth.png',
    description: 'Thick creamy fruit smoothies featuring mango, banana, mixed berry & strawberry.',
    icon_name: 'blender_rounded',
    items: [
      {
        name: 'Mango',
        description: 'Bright golden-orange smoothie blended with fresh sweet mango chunks.',
        base_price: 199,
        image_url: 'assets/images/MangoS.png',
      },
      {
        name: 'Banana',
        description: 'Thick, creamy pale-yellow smoothie crafted with sweet bananas and fresh cream.',
        base_price: 199,
        image_url: 'assets/images/BananaS.png',
      },
      {
        name: 'Mix Berry',
        description: 'Rich purple/red berry smoothie containing a custom blend of forest berries.',
        base_price: 199,
        image_url: 'assets/images/MixBerry.png',
      },
      {
        name: 'Blue Berry',
        description: 'Deep blue berry smoothie blended creamy and thick with sweet blueberries.',
        base_price: 199,
        image_url: 'assets/images/blueBerry.png',
      },
      {
        name: 'Strawberry',
        description: 'Vibrant pink/red strawberry smoothie blended with fresh strawberries and Greek yogurt.',
        base_price: 199,
        image_url: 'assets/images/StrawBerryS.png',
      },
    ],
  },

  // 22. Ice Shakes
  {
    id: 'ice-shakes',
    name: 'Ice Shakes',
    badge_text: 'Shake',
    image_path: 'assets/images/ice shake.webp',
    description: 'Rich thick ice shakes in mango, vanilla, caramel, chocolate & Kulfa flavors.',
    icon_name: 'water_drop_rounded',
    items: [
      {
        name: 'Mango',
        description: 'Rich golden-yellow shake served with fresh mango pieces and sweet mango drizzle.',
        base_price: 590,
        image_url: 'assets/images/MangoI.png',
      },
      {
        name: 'Vanilla',
        description: 'Thick, creamy vanilla bean shake topped with whipped cream.',
        base_price: 590,
        image_url: 'assets/images/VanalaI.png',
      },
      {
        name: 'Caramel',
        description: 'Rich caramel ice shake with thick buttery caramel drizzle and golden toppings.',
        base_price: 590,
        image_url: 'assets/images/CarimalI.png',
      },
      {
        name: 'Chocolate',
        description: 'Decadent dark chocolate shake loaded with chocolate drizzle and chocolate shavings.',
        base_price: 590,
        image_url: 'assets/images/ChocolateI.png',
      },
      {
        name: 'Strawberry',
        description: 'Creamy soft-pink shake blended with fresh strawberries and strawberry drizzle.',
        base_price: 590,
        image_url: 'assets/images/StrawBerryI.png',
      },
      {
        name: 'Special Kulfa',
        description: 'Traditional rich kulfa-inspired shake garnished with almonds and pistachios.',
        base_price: 590,
        image_url: 'assets/images/KulfaI.png',
      },
    ],
  },

  // 23. Milk Shakes
  {
    id: 'milk-shakes',
    name: 'Milk Shakes',
    badge_text: 'Milkshake',
    image_path: 'assets/images/Milk shake.png',
    description: 'Creamy chilled milkshakes with apple, banana, seasonal fruit & strawberry.',
    icon_name: 'emoji_food_beverage_rounded',
    items: [
      {
        name: 'Apple',
        description: 'Delicious light-green apple shake blended with fresh apple slices.',
        base_price: 400,
        image_url: 'assets/images/apples.png',
      },
      {
        name: 'Banana',
        description: 'Rich and sweet shake made with fresh bananas and high-quality milk.',
        base_price: 400,
        image_url: 'assets/images/BananaShake.png',
      },
      {
        name: 'Seasonal',
        description: 'Creamy mixed fruit milkshake crafted using premium seasonal fruits.',
        base_price: 400,
        image_url: 'assets/images/Sessional.png',
      },
      {
        name: 'Strawberry',
        description: 'Creamy soft-pink milkshake flavored with fresh sweet strawberries.',
        base_price: 400,
        image_url: 'assets/images/StrawberryShake.png',
      },
    ],
  },

  // 24. Soft Drinks
  {
    id: 'soft-drinks',
    name: 'Soft Drinks',
    badge_text: 'Soda',
    image_path: 'assets/images/soft.png',
    description: 'Fresh lime and mint-based refreshing drinks served in glasses with crushed ice.',
    icon_name: 'wine_bar_rounded',
    items: [
      {
        name: 'Fresh Lime',
        description: 'Bright lime drink with lime wedges, mint garnish, crushed ice, and refreshing condensation.',
        base_price: 250,
        image_url: 'assets/images/FreshLime.png',
      },
      {
        name: 'Mint Margrita',
        description: 'Refreshing green mint blend served with lime slices, mint leaves, and crushed ice in a tall glass.',
        base_price: 300,
        image_url: 'assets/images/Mint.png',
      },
    ],
  },
];

export async function seedHtmlMenu(customPrisma?: PrismaClient) {
  const p = customPrisma || prisma;
  console.log('🚀 Synchronizing Hungry Howies HTML Menu with PostgreSQL Database...');

  // 1. Clean up unused legacy categories ('abc', 'cat-pizza')
  for (const legacyId of ['abc', 'cat-pizza']) {
    const legacyCat = await p.menuCategory.findUnique({
      where: { id: legacyId },
      include: {
        menu_items: {
          include: { order_items: true },
        },
      },
    });

    if (legacyCat) {
      let canDeleteCat = true;
      for (const item of legacyCat.menu_items) {
        if (item.order_items.length === 0) {
          await p.menuItemSize.deleteMany({ where: { menu_item_id: item.id } });
          await p.menuItemOption.deleteMany({ where: { menu_item_id: item.id } });
          await p.menuItem.delete({ where: { id: item.id } });
          console.log(`🧹 Deleted obsolete item '${item.name}' from '${legacyId}'`);
        } else {
          canDeleteCat = false;
        }
      }
      if (canDeleteCat) {
        await p.menuCategory.delete({ where: { id: legacyId } });
        console.log(`🧹 Deleted legacy category '${legacyId}'`);
      }
    }
  }

  // 2. Build set of valid HTML item names per category
  const validCategoryIds = new Set(menuData.map((c) => c.id));
  const validItemsByCategory: Record<string, Set<string>> = {};
  for (const c of menuData) {
    validItemsByCategory[c.id] = new Set(c.items.map((i) => i.name.toLowerCase()));
  }

  // 3. Upsert each category and its authentic items
  let totalCategories = 0;
  let totalItems = 0;
  let totalSizes = 0;
  let totalOptions = 0;

  for (const catSpec of menuData) {
    const category = await p.menuCategory.upsert({
      where: { id: catSpec.id },
      update: {
        name: catSpec.name,
        badge_text: catSpec.badge_text,
        image_path: catSpec.image_path,
        description: catSpec.description,
        icon_name: catSpec.icon_name,
      },
      create: {
        id: catSpec.id,
        name: catSpec.name,
        badge_text: catSpec.badge_text,
        image_path: catSpec.image_path,
        description: catSpec.description,
        icon_name: catSpec.icon_name,
      },
    });
    totalCategories++;
    console.log(`\n📁 Category [${category.id}]: ${category.name}`);

    for (const itemSpec of catSpec.items) {
      let item = await p.menuItem.findFirst({
        where: {
          category_id: category.id,
          name: { equals: itemSpec.name, mode: 'insensitive' },
        },
      });

      if (item) {
        item = await p.menuItem.update({
          where: { id: item.id },
          data: {
            name: itemSpec.name,
            description: itemSpec.description ?? '',
            base_price: itemSpec.base_price,
            image_url: itemSpec.image_url ?? '',
            is_veg: itemSpec.is_veg ?? false,
            is_spicy: itemSpec.is_spicy ?? false,
            is_available: true,
          },
        });
      } else {
        item = await p.menuItem.create({
          data: {
            category_id: category.id,
            name: itemSpec.name,
            description: itemSpec.description ?? '',
            base_price: itemSpec.base_price,
            image_url: itemSpec.image_url ?? '',
            is_veg: itemSpec.is_veg ?? false,
            is_spicy: itemSpec.is_spicy ?? false,
            is_available: true,
          },
        });
      }
      totalItems++;

      // Sync sizes
      if (itemSpec.sizes && itemSpec.sizes.length > 0) {
        await p.menuItemSize.deleteMany({
          where: { menu_item_id: item.id },
        });

        await p.menuItemSize.createMany({
          data: itemSpec.sizes.map((s) => ({
            menu_item_id: item.id,
            size_name: s.size_name,
            price: s.price,
          })),
        });
        totalSizes += itemSpec.sizes.length;
      }

      // Sync options
      if (itemSpec.options && itemSpec.options.length > 0) {
        await p.menuItemOption.deleteMany({
          where: { menu_item_id: item.id },
        });

        await p.menuItemOption.createMany({
          data: itemSpec.options.map((o) => ({
            menu_item_id: item.id,
            option_type: o.option_type,
            option_name: o.option_name,
            additional_price: o.additional_price,
          })),
        });
        totalOptions += itemSpec.options.length;
      }

      console.log(`  ✓ ${item.name} (PKR ${item.base_price})`);
    }

    // 4. Remove obsolete unreferenced items in this category that are not in the HTML
    const existingItems = await p.menuItem.findMany({
      where: { category_id: category.id },
      include: { order_items: true },
    });

    for (const exItem of existingItems) {
      const isAllowed = validItemsByCategory[category.id].has(exItem.name.toLowerCase());
      if (!isAllowed) {
        if (exItem.order_items.length === 0) {
          await p.menuItemSize.deleteMany({ where: { menu_item_id: exItem.id } });
          await p.menuItemOption.deleteMany({ where: { menu_item_id: exItem.id } });
          await p.menuItem.delete({ where: { id: exItem.id } });
          console.log(`  🗑️ Removed unlisted legacy item: '${exItem.name}'`);
        } else {
          console.log(`  ⚠️ Preserved legacy item with orders: '${exItem.name}'`);
        }
      }
    }
  }

  console.log('\n======================================================');
  console.log(`✨ DATABASE SYNC COMPLETE!`);
  console.log(`- Categories: ${totalCategories}`);
  console.log(`- Menu Items: ${totalItems}`);
  console.log(`- Tiered Sizes: ${totalSizes}`);
  console.log(`- Options/Addons: ${totalOptions}`);
  console.log('======================================================');
}

if (require.main === module) {
  seedHtmlMenu()
    .catch((err) => {
      console.error('❌ Error during menu sync:', err);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
