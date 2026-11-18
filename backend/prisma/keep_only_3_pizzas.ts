import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const classicSizes = [
  { size_name: 'Small', price: 849 },
  { size_name: 'Medium', price: 1449 },
  { size_name: 'Large', price: 1749 },
  { size_name: 'Family', price: 2349 },
];

const modernSizes = [
  { size_name: 'Small', price: 849 },
  { size_name: 'Medium', price: 1549 },
  { size_name: 'Large', price: 1999 },
  { size_name: 'Family', price: 2499 },
];

const specialSizes = [
  { size_name: 'Medium', price: 1699 },
  { size_name: 'Large', price: 2199 },
  { size_name: 'Family', price: 2999 },
];

const classicFlavors = [
  'Fajita Pizza',
  'Chicken Tikka',
  'Malai Boti',
  'Sausage Chesse',
  'Hot & Spicy',
  'Tandoori Bonfire',
];

const modernFlavors = [
  'Ring Pizza',
  'Crown Crust',
  'Peperoni Passion',
  'Doner Kebab',
  'Kebab Stuffer',
  'Cheese Stick',
  'Chicken Stuffer',
];

const specialFlavors = [
  'Arabic Crispy',
  'Hungry Cheese Gold Pizza',
];

const pizzaCrusts = [
  { option_type: 'crust', option_name: 'Original Crust', additional_price: 0 },
  { option_type: 'crust', option_name: 'Butter Cheese Crust', additional_price: 150 },
  { option_type: 'crust', option_name: 'Garlic Herb Crust', additional_price: 120 },
  { option_type: 'crust', option_name: 'Cajun Crust', additional_price: 120 },
  { option_type: 'crust', option_name: 'Sesame Crust', additional_price: 100 },
];

const pizzaToppings = [
  { option_type: 'topping', option_name: 'Extra Mozzarella Cheese', additional_price: 200 },
  { option_type: 'topping', option_name: 'Mushrooms', additional_price: 100 },
  { option_type: 'topping', option_name: 'Jalapenos', additional_price: 80 },
  { option_type: 'topping', option_name: 'Black Olives', additional_price: 90 },
  { option_type: 'topping', option_name: 'Extra Chicken', additional_price: 180 },
];

async function main() {
  console.log('🍕 Cleaning Pizza category: keeping ONLY the 3 Pizzas (Classic, Modern, Special)...');

  // 1. Find or create Pizza category
  let pizzaCategory = await prisma.menuCategory.findFirst({
    where: {
      OR: [
        { id: 'pizza' },
        { name: { contains: 'pizza', mode: 'insensitive' } },
      ],
    },
  });

  if (!pizzaCategory) {
    pizzaCategory = await prisma.menuCategory.create({
      data: {
        id: 'pizza',
        name: 'Pizza',
        badge_text: 'Pizza',
        image_path: 'assets/images/Pizza.png',
        description: 'Melted cheese, chicken toppings, colorful vegetables & crispy charred crust.',
        icon_name: 'local_pizza_rounded',
      },
    });
  }

  const categoryId = pizzaCategory.id;

  // 2. Identify all pizza items currently in DB
  const existingPizzaItems = await prisma.menuItem.findMany({
    where: {
      OR: [
        { category_id: categoryId },
        {
          AND: [
            { name: { contains: 'pizza', mode: 'insensitive' } },
            { category_id: { not: 'deals' } },
          ],
        },
      ],
    },
  });

  console.log(`Found ${existingPizzaItems.length} existing pizza-related items to remove/clean.`);

  // 3. Unlink FK order items and remove all old pizza items
  for (const item of existingPizzaItems) {
    await prisma.orderItem.updateMany({
      where: { menu_item_id: item.id },
      data: { menu_item_id: null },
    });

    await prisma.menuItemSize.deleteMany({ where: { menu_item_id: item.id } });
    await prisma.menuItemOption.deleteMany({ where: { menu_item_id: item.id } });
    await prisma.menuItem.delete({ where: { id: item.id } });
    console.log(`  🗑️ Deleted old item: ${item.name} (${item.id})`);
  }

  // 4. Create ONLY the 3 Pizzas
  const pizzasToCreate = [
    {
      id: 'pizza-classic',
      name: "Classic Pizza's",
      description: "Classic Pizza with rich mozzarella, savory tomato base & authentic flavors.",
      base_price: 849,
      image_url: 'assets/images/Fajita.png',
      sizes: classicSizes,
      flavors: classicFlavors,
    },
    {
      id: 'pizza-modern',
      name: "Modren Pizza's",
      description: "Modern Specialty Pizzas with handcrafted stuffed crusts and signature toppings.",
      base_price: 849,
      image_url: 'assets/images/Modern.png',
      sizes: modernSizes,
      flavors: modernFlavors,
    },
    {
      id: 'pizza-special',
      name: "Special Pizza's",
      description: "Luxury Special Pizzas loaded with gourmet Arabic tenders and triple cheese burst.",
      base_price: 1699,
      image_url: 'assets/images/Special.png',
      sizes: specialSizes,
      flavors: specialFlavors,
    },
  ];

  for (const p of pizzasToCreate) {
    const item = await prisma.menuItem.create({
      data: {
        id: p.id,
        category_id: categoryId,
        name: p.name,
        description: p.description,
        base_price: p.base_price,
        image_url: p.image_url,
        is_available: true,
      },
    });

    // Create sizes
    await prisma.menuItemSize.createMany({
      data: p.sizes.map((s) => ({
        menu_item_id: item.id,
        size_name: s.size_name,
        price: s.price,
      })),
    });

    // Create options (flavors + crusts + toppings)
    const optionsData = [
      ...p.flavors.map((flv) => ({
        menu_item_id: item.id,
        option_type: 'flavor',
        option_name: flv,
        additional_price: 0,
      })),
      ...pizzaCrusts.map((c) => ({
        menu_item_id: item.id,
        option_type: c.option_type,
        option_name: c.option_name,
        additional_price: c.additional_price,
      })),
      ...pizzaToppings.map((t) => ({
        menu_item_id: item.id,
        option_type: t.option_type,
        option_name: t.option_name,
        additional_price: t.additional_price,
      })),
    ];

    await prisma.menuItemOption.createMany({ data: optionsData });

    console.log(`  ✨ Created: ${p.name} with ${p.sizes.length} sizes and ${p.flavors.length} flavors`);
  }

  // 5. Verify database state
  const finalPizzas = await prisma.menuItem.findMany({
    where: { category_id: categoryId },
    include: { sizes: true, options: true },
  });

  console.log('\n======================================================');
  console.log(`✅ DATABASE PIZZA CLEANUP COMPLETE!`);
  console.log(`Total Pizza items in database: ${finalPizzas.length}`);
  finalPizzas.forEach((p) => {
    const flavors = p.options.filter((o) => o.option_type === 'flavor').map((o) => o.option_name);
    const sizeList = p.sizes.map((s) => `${s.size_name}: PKR ${s.price}`).join(', ');
    console.log(`- ${p.name} (Base PKR ${p.base_price})`);
    console.log(`  Sizes: ${sizeList}`);
    console.log(`  Flavors (${flavors.length}): ${flavors.join(', ')}`);
  });
  console.log('======================================================');
}

main()
  .catch((e) => {
    console.error('Error during cleanup:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
