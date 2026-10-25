const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('--- ALL ORDERS IN POSTGRESQL (last 20) ---');
    take: 20,
    orderBy: { created_at: 'desc' },
    select: {
      id: true,
      order_number: true,
      shift_id: true,
      status: true,
      is_paid: true,
      order_type: true,
      created_at: true,
      grand_total: true,
    }
  });
  console.log('Orders:', JSON.stringify(orders, null, 2));

  console.log('\n--- ACTIVE SHIFTS IN POSTGRESQL ---');
  const activeShifts = await prisma.dailyCalculation.findMany({
    where: { status: 'ACTIVE' },
  });
  console.log('Active shifts:', JSON.stringify(activeShifts, null, 2));

  // Check unresolved orders query with active shift
  if (activeShifts.length > 0) {
    const active = activeShifts[0];
    const sessionStartTime = new Date(active.created_at || active.date);
    console.log('\n--- Running exact unresolvedOrders query for shift:', active.id, 'started at:', sessionStartTime.toISOString());
    const unresolved = await prisma.order.findMany({
      where: {
        AND: [
          {
            OR: [
              { shift_id: active.id },
              {
                shift_id: null,
                created_at: { gte: sessionStartTime },
              },
            ],
          },
          {
            OR: [
              { status: { in: ['newOrder', 'pending', 'confirmed', 'preparing', 'ready', 'served', 'accepted', 'in_progress'] } },
              { is_paid: false, status: { notIn: ['cancelled', 'rejected'] } },
            ],
          },
        ],
      },
      select: {
        id: true,
        order_number: true,
        shift_id: true,
        status: true,
        is_paid: true,
        order_type: true,
        created_at: true,
        grand_total: true,
      }
    });
    console.log('Unresolved count:', unresolved.length);
    console.log('Unresolved orders:', JSON.stringify(unresolved, null, 2));
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
