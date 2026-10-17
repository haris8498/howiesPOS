import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🚀 Seeding 15 orders (3 Website, 3 POS Online, 3 Mobile App, 3 Takeaway, 3 Dine-In)...');

  // Fetch an available restaurant table for Dine-In orders
  const tables = await prisma.restaurantTable.findMany({ take: 3 });
  const tableIds = tables.length > 0 ? tables.map(t => t.id) : [];

  if (tableIds.length === 0) {
    console.log('⚠️ No restaurant tables found in database. Creating default tables first...');
    const defaultTable = await prisma.restaurantTable.create({
      data: {
        table_number: 'T-101',
        name: 'Hall Table 101',
        capacity: 4,
        section: 'Hall',
        status: 'available',
      },
    });
    tableIds.push(defaultTable.id);
  }

  // ----------------------------------------------------
  // 1. 3 ONLINE ORDERS — WEBSITE
  // ----------------------------------------------------
  const websiteOrders = [
    {
      orderNumber: 'WEB-1001',
      customerName: 'Sarah Ahmed',
      phone: '+92 300 1112233',
      address: 'House 42, Street 15, F-7/2, Islamabad',
      status: 'newOrder',
      itemName: 'Howie Special Pizza',
      qty: 1,
      unitPrice: 1499,
    },
    {
      orderNumber: 'WEB-1002',
      customerName: 'Bilal Khan',
      phone: '+92 321 4445566',
      address: 'Apartment 4B, Silver Heights, E-11, Islamabad',
      status: 'accepted',
      itemName: 'Meat Eaters Pizza',
      qty: 2,
      unitPrice: 1699,
    },
    {
      orderNumber: 'WEB-1003',
      customerName: 'Ayesha Malik',
      phone: '+92 333 7778899',
      address: 'Villa 12, Sector I-8/3, Islamabad',
      status: 'preparing',
      itemName: 'Chicken Bacon Ranch Pizza',
      qty: 1,
      unitPrice: 1599,
    },
  ];

  for (const w of websiteOrders) {
    const subtotal = w.unitPrice * w.qty;
    const deliveryFee = 150;
    const grandTotal = subtotal + deliveryFee;

    await prisma.order.upsert({
      where: { order_number: w.orderNumber },
      update: {},
      create: {
        order_number: w.orderNumber,
        order_type: 'online',
        status: w.status,
        subtotal,
        discount_amount: 0,
        tax_amount: 0,
        grand_total: grandTotal,
        payment_status: 'UNPAID',
        is_paid: false,
        kitchen_ticket_sent: true,
        order_items: {
          create: [
            {
              item_name: w.itemName,
              quantity: w.qty,
              unit_price: w.unitPrice,
              total_price: subtotal,
              selected_size: 'Large',
              selected_crust: 'Original',
            },
          ],
        },
        online_detail: {
          create: {
            order_source: 'Website',
            customer_name: w.customerName,
            customer_phone: w.phone,
            delivery_address: w.address,
            delivery_fee: deliveryFee,
          },
        },
      },
    });
    console.log(`✅ Seeded Website Order: ${w.orderNumber} (${w.customerName})`);
  }

  // ----------------------------------------------------
  // 2. 3 ONLINE ORDERS — POS (Delivery via POS)
  // ----------------------------------------------------
  const posOnlineOrders = [
    {
      orderNumber: 'POS-DEL-2001',
      customerName: 'Zainab Fatima',
      phone: '+92 301 9988776',
      address: 'Flat 302, G-9 Markaz, Islamabad',
      status: 'preparing',
      itemName: 'Howie Angus Cheeseburger',
      qty: 2,
      unitPrice: 1149,
    },
    {
      orderNumber: 'POS-DEL-2002',
      customerName: 'Hamza Ali',
      phone: '+92 312 3344556',
      address: 'House 88, Street 4, H-13, Islamabad',
      status: 'ready',
      itemName: 'Spicy Buffalo Chicken Burger',
      qty: 3,
      unitPrice: 1099,
    },
    {
      orderNumber: 'POS-DEL-2003',
      customerName: 'Tariq Mahmood',
      phone: '+92 345 6677889',
      address: 'Office 12, Business Arcade, Blue Area, Islamabad',
      status: 'completed',
      itemName: 'Family Feast Combo Deal',
      qty: 1,
      unitPrice: 3299,
    },
  ];

  for (const p of posOnlineOrders) {
    const subtotal = p.unitPrice * p.qty;
    const deliveryFee = 200;
    const grandTotal = subtotal + deliveryFee;

    await prisma.order.upsert({
      where: { order_number: p.orderNumber },
      update: {},
      create: {
        order_number: p.orderNumber,
        order_type: 'online',
        status: p.status,
        subtotal,
        discount_amount: 0,
        tax_amount: 0,
        grand_total: grandTotal,
        payment_status: p.status === 'completed' ? 'PAID' : 'UNPAID',
        is_paid: p.status === 'completed',
        kitchen_ticket_sent: true,
        order_items: {
          create: [
            {
              item_name: p.itemName,
              quantity: p.qty,
              unit_price: p.unitPrice,
              total_price: subtotal,
              selected_size: 'Regular',
              selected_crust: 'Original',
            },
          ],
        },
        online_detail: {
          create: {
            order_source: 'POS',
            customer_name: p.customerName,
            customer_phone: p.phone,
            delivery_address: p.address,
            delivery_fee: deliveryFee,
          },
        },
      },
    });
    console.log(`✅ Seeded POS Online Order: ${p.orderNumber} (${p.customerName})`);
  }

  // ----------------------------------------------------
  // 3. 3 ONLINE ORDERS — MOBILE APP
  // ----------------------------------------------------
  const mobileOrders = [
    {
      orderNumber: 'MOB-3001',
      customerName: 'Usman Ghani',
      phone: '+92 302 5544332',
      address: 'House 19, Street 8, G-10/2, Islamabad',
      status: 'newOrder',
      itemName: 'Duo Craver Pack',
      qty: 1,
      unitPrice: 1649,
    },
    {
      orderNumber: 'MOB-3002',
      customerName: 'Mariam Nawaz',
      phone: '+92 334 1122334',
      address: 'Tower A, Executive Heights, Gulberg Greens, Islamabad',
      status: 'accepted',
      itemName: 'Midnight Craving Deal',
      qty: 2,
      unitPrice: 1999,
    },
    {
      orderNumber: 'MOB-3003',
      customerName: 'Omar Farooq',
      phone: '+92 313 7788990',
      address: 'Street 3, Phase 4, Bahria Town, Rawalpindi',
      status: 'ready',
      itemName: 'EXCLUSIVE DEALS Combo',
      qty: 1,
      unitPrice: 2499,
    },
  ];

  for (const m of mobileOrders) {
    const subtotal = m.unitPrice * m.qty;
    const deliveryFee = 150;
    const grandTotal = subtotal + deliveryFee;

    await prisma.order.upsert({
      where: { order_number: m.orderNumber },
      update: {},
      create: {
        order_number: m.orderNumber,
        order_type: 'online',
        status: m.status,
        subtotal,
        discount_amount: 0,
        tax_amount: 0,
        grand_total: grandTotal,
        payment_status: 'UNPAID',
        is_paid: false,
        kitchen_ticket_sent: true,
        order_items: {
          create: [
            {
              item_name: m.itemName,
              quantity: m.qty,
              unit_price: m.unitPrice,
              total_price: subtotal,
              selected_size: 'Regular',
              selected_crust: 'Original',
            },
          ],
        },
        online_detail: {
          create: {
            order_source: 'MobileApp',
            customer_name: m.customerName,
            customer_phone: m.phone,
            delivery_address: m.address,
            delivery_fee: deliveryFee,
          },
        },
      },
    });
    console.log(`✅ Seeded Mobile App Order: ${m.orderNumber} (${m.customerName})`);
  }

  // ----------------------------------------------------
  // 4. 3 TAKEAWAY ORDERS
  // ----------------------------------------------------
  const takeawayOrders = [
    {
      orderNumber: 'TAK-4001',
      tokenNumber: 'TK-101',
      customerName: 'Muhammad Rizwan',
      phone: '+92 300 8877665',
      status: 'newOrder',
      itemName: 'Crispy Seasoned Cajun Fries',
      qty: 2,
      unitPrice: 499,
    },
    {
      orderNumber: 'TAK-4002',
      tokenNumber: 'TK-102',
      customerName: 'Kashif Raza',
      phone: '+92 322 1122445',
      status: 'ready',
      itemName: 'Student Saver Deal',
      qty: 1,
      unitPrice: 749,
    },
    {
      orderNumber: 'TAK-4003',
      tokenNumber: 'TK-103',
      customerName: 'Walk-in Counter Customer',
      phone: '+92 333 0001122',
      status: 'completed',
      itemName: 'Howie Special Pizza',
      qty: 1,
      unitPrice: 1499,
    },
  ];

  for (const t of takeawayOrders) {
    const subtotal = t.unitPrice * t.qty;
    const grandTotal = subtotal;

    await prisma.order.upsert({
      where: { order_number: t.orderNumber },
      update: {},
      create: {
        order_number: t.orderNumber,
        order_type: 'takeaway',
        status: t.status,
        subtotal,
        discount_amount: 0,
        tax_amount: 0,
        grand_total: grandTotal,
        payment_status: t.status === 'completed' ? 'PAID' : 'UNPAID',
        is_paid: t.status === 'completed',
        kitchen_ticket_sent: true,
        order_items: {
          create: [
            {
              item_name: t.itemName,
              quantity: t.qty,
              unit_price: t.unitPrice,
              total_price: subtotal,
              selected_size: 'Regular',
              selected_crust: 'Cajun',
            },
          ],
        },
        takeaway_detail: {
          create: {
            token_number: t.tokenNumber,
            customer_name: t.customerName,
            customer_phone: t.phone,
            served_by: 'Cashier Counter 1',
          },
        },
      },
    });
    console.log(`✅ Seeded Takeaway Order: ${t.orderNumber} Token ${t.tokenNumber}`);
  }

  // ----------------------------------------------------
  // 5. 3 DINE-IN ORDERS
  // ----------------------------------------------------
  const dineInOrders = [
    {
      orderNumber: 'DIN-5001',
      tableId: tableIds[0] || tableIds[0],
      guestCount: 3,
      waiterName: 'Marcus Vance',
      status: 'preparing',
      itemName: 'Meat Eaters Pizza',
      qty: 1,
      unitPrice: 1699,
    },
    {
      orderNumber: 'DIN-5002',
      tableId: tableIds[1] || tableIds[0],
      guestCount: 4,
      waiterName: 'Elena Rostova',
      status: 'ready',
      itemName: 'Chicken Bacon Ranch Pizza',
      qty: 2,
      unitPrice: 1599,
    },
    {
      orderNumber: 'DIN-5003',
      tableId: tableIds[2] || tableIds[0],
      guestCount: 2,
      waiterName: 'Tariq Mahmood',
      status: 'completed',
      itemName: 'Howie Angus Cheeseburger',
      qty: 2,
      unitPrice: 1149,
    },
  ];

  for (const d of dineInOrders) {
    const subtotal = d.unitPrice * d.qty;
    const grandTotal = subtotal;

    await prisma.order.upsert({
      where: { order_number: d.orderNumber },
      update: {},
      create: {
        order_number: d.orderNumber,
        order_type: 'dineIn',
        status: d.status,
        subtotal,
        discount_amount: 0,
        tax_amount: 0,
        grand_total: grandTotal,
        payment_status: d.status === 'completed' ? 'PAID' : 'UNPAID',
        is_paid: d.status === 'completed',
        kitchen_ticket_sent: true,
        order_items: {
          create: [
            {
              item_name: d.itemName,
              quantity: d.qty,
              unit_price: d.unitPrice,
              total_price: subtotal,
              selected_size: 'Large',
              selected_crust: 'Butter Cheese',
            },
          ],
        },
        dine_in_detail: {
          create: {
            table_id: d.tableId,
            guest_count: d.guestCount,
            waiter_name: d.waiterName,
          },
        },
      },
    });
    console.log(`✅ Seeded Dine-In Order: ${d.orderNumber} (Table ${d.tableId})`);
  }

  console.log('✨ All 15 orders created successfully in database!');
}

main()
  .catch((e) => {
    console.error('❌ Error seeding orders:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
