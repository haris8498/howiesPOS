const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function truncateTables() {
  console.log('Executing TRUNCATE query on PostgreSQL...');

  const sql = `
    TRUNCATE TABLE
        order_payments,
        order_items,
        dine_in_order_details,
        online_order_details,
        takeaway_order_details,
        delivery_dispatches,
        orders,
        daily_calculations,
        data_sync_logs,
        processed_operations,
        system_change_logs
    RESTART IDENTITY CASCADE;
  `;

  try {
    await prisma.$executeRawUnsafe(sql);
    console.log('✅ Successfully truncated tables and restarted identities:');
    console.log('   - order_payments');
    console.log('   - order_items');
    console.log('   - dine_in_order_details');
    console.log('   - online_order_details');
    console.log('   - takeaway_order_details');
    console.log('   - delivery_dispatches');
    console.log('   - orders');
    console.log('   - daily_calculations');
    console.log('   - data_sync_logs');
    console.log('   - processed_operations');
    console.log('   - system_change_logs');
  } catch (err) {
    console.error('❌ Truncate failed:', err.message);
    if (err.message.includes("Can't reach database server")) {
      console.log('\nPostgreSQL is not running. Please start it with:');
      console.log('  net start postgresql-x64-18 (in an Administrator command prompt)');
    }
  } finally {
    await prisma.$disconnect();
  }
}

truncateTables();

