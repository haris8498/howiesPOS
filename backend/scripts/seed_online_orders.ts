import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  for(let i = 1; i <= 5; i++) {
    await prisma.order.create({
      data: {
        order_number: 'ONL-' + Date.now() + '-' + i,
        order_type: 'online',
        status: 'pending',
        subtotal: 1500,
        grand_total: 1500,
        customer_name: 'Online User ' + i,
        customer_phone: '123456789' + i,
        delivery_address: '123 Street ' + i,
        order_source: 'Website',
      }
    });
  }
  console.log('✅ Added 5 online pending orders.');
}

main().catch(console.error).finally(async () => await prisma.$disconnect());
