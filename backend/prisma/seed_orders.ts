import { PrismaClient } from '@prisma/client';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding dummy Takeaway and Delivery orders...');

  // 1. A Takeaway Order
  const takeawayOrderId = crypto.randomUUID();
  await prisma.order.create({
    data: {
      id: takeawayOrderId,
      order_number: 'HH-TAK-' + Math.floor(Math.random() * 10000),
      order_type: 'Takeaway',
      order_source: 'Direct POS',
      status: 'completed',
      guest_count: 1,
      waiter_name: 'Cashier',
      customer_name: 'Ali Khan',
      customer_phone: '03001234567',
      subtotal: 1200.00,
      delivery_fee: 0.00,
      grand_total: 1200.00,
      payment_status: 'COMPLETED',
      payment_method: 'cash',
      is_paid: true,
      order_items: {
        create: [
          {
            item_name: 'Chicken Tikka Pizza',
            quantity: 1,
            unit_price: 1200.00,
            total_price: 1200.00,
            selected_size: 'Large'
          }
        ]
      },
      payments: {
        create: [
          {
            payment_method: 'cash',
            amount: 1200.00,
            tendered_amount: 1500.00,
            change_returned: 300.00,
            payment_status: 'COMPLETED'
          }
        ]
      }
    }
  });
  console.log('Takeaway Order created.');

  // 2. A Delivery Order
  const deliveryOrderId = crypto.randomUUID();
  await prisma.order.create({
    data: {
      id: deliveryOrderId,
      order_number: 'HH-DEL-' + Math.floor(Math.random() * 10000),
      order_type: 'Delivery',
      order_source: 'Phone',
      status: 'preparing',
      guest_count: 1,
      waiter_name: 'Call Center',
      customer_name: 'Sara Ahmed',
      customer_phone: '03339876543',
      delivery_address: 'House 4, Street 10, F-8/4, Islamabad',
      subtotal: 2500.00,
      delivery_fee: 150.00,
      grand_total: 2650.00,
      payment_status: 'UNPAID',
      payment_method: 'cash',
      is_paid: false,
      order_items: {
        create: [
          {
            item_name: 'Fajita Sensation Pizza',
            quantity: 2,
            unit_price: 1000.00,
            total_price: 2000.00,
            selected_size: 'Medium'
          },
          {
            item_name: 'Garlic Bread',
            quantity: 1,
            unit_price: 500.00,
            total_price: 500.00,
            selected_size: 'Regular'
          }
        ]
      }
    }
  });
  console.log('Delivery Order created.');

  // 3. Another Delivery Order
  const deliveryOrderId2 = crypto.randomUUID();
  await prisma.order.create({
    data: {
      id: deliveryOrderId2,
      order_number: 'HH-DEL-' + Math.floor(Math.random() * 10000),
      order_type: 'Delivery',
      order_source: 'Direct POS',
      status: 'completed',
      guest_count: 1,
      waiter_name: 'Cashier',
      customer_name: 'Usman',
      customer_phone: '03215554443',
      delivery_address: 'Apartment 12, Heights, G-11',
      subtotal: 3500.00,
      delivery_fee: 200.00,
      grand_total: 3700.00,
      payment_status: 'COMPLETED',
      payment_method: 'card',
      is_paid: true,
      order_items: {
        create: [
          {
            item_name: 'Supreme Deal',
            quantity: 1,
            unit_price: 3500.00,
            total_price: 3500.00,
            selected_size: 'Combo'
          }
        ]
      },
      payments: {
        create: [
          {
            payment_method: 'card',
            amount: 3700.00,
            tendered_amount: 3700.00,
            change_returned: 0.00,
            payment_status: 'COMPLETED'
          }
        ]
      }
    }
  });
  console.log('Another Delivery Order created.');

  // 4. A PENDING Online Takeaway Order
  const onlineTakeawayId = crypto.randomUUID();
  await prisma.order.create({
    data: {
      id: onlineTakeawayId,
      order_number: 'ONL-TAK-' + Math.floor(Math.random() * 10000),
      order_type: 'takeAway',
      order_source: 'Online Website',
      status: 'newOrder',
      guest_count: 1,
      waiter_name: 'System',
      customer_name: 'Zainab',
      customer_phone: '03445556667',
      subtotal: 800.00,
      delivery_fee: 0.00,
      grand_total: 800.00,
      payment_status: 'UNPAID',
      payment_method: 'cash',
      is_paid: false,
      order_items: {
        create: [
          {
            item_name: 'Margherita Pizza',
            quantity: 1,
            unit_price: 800.00,
            total_price: 800.00,
            selected_size: 'Regular'
          }
        ]
      }
    }
  });
  console.log('Pending Online Takeaway Order created.');

  // 5. A PENDING Delivery Order
  const newDeliveryId = crypto.randomUUID();
  await prisma.order.create({
    data: {
      id: newDeliveryId,
      order_number: 'ONL-DEL-' + Math.floor(Math.random() * 10000),
      order_type: 'delivery',
      order_source: 'Mobile App',
      status: 'newOrder',
      guest_count: 1,
      waiter_name: 'System',
      customer_name: 'Hamza',
      customer_phone: '03112223334',
      delivery_address: 'House 55, Street 12, G-10/2',
      subtotal: 1500.00,
      delivery_fee: 150.00,
      grand_total: 1650.00,
      payment_status: 'UNPAID',
      payment_method: 'cash',
      is_paid: false,
      order_items: {
        create: [
          {
            item_name: 'Pepperoni Passion',
            quantity: 1,
            unit_price: 1500.00,
            total_price: 1500.00,
            selected_size: 'Large'
          }
        ]
      }
    }
  });
  console.log('Pending Delivery Order created.');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
