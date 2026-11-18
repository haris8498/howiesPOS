import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🔄 Executing TRUNCATE on transactional tables...');
  const query = `
    TRUNCATE TABLE
      order_payments,
      order_items,
      dine_in_order_details,
      online_order_details,
      takeaway_order_details,
      delivery_dispatches,
      orders,
      daily_expense_items,
      daily_calculations,
      data_sync_logs,
      processed_operations,
      system_change_logs
    RESTART IDENTITY CASCADE;
  `;

  try {
    await prisma.$executeRawUnsafe(query);
    console.log('✅ TRUNCATE COMPLETE: All specified tables truncated and identities reset!');
  } catch (err: any) {
    console.error('❌ Error executing TRUNCATE:', err.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
