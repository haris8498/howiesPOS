const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function testDatabase() {
  console.log('--- Testing Local PostgreSQL Connection ---');
  console.log('Target URL:', process.env.DATABASE_URL || '(Default from .env)');

  try {
    await prisma.$connect();
    console.log(' Connected to local PostgreSQL database successfully!\n');

    // Query tables
    const userCount = await prisma.staffUser.count();
    console.log(` Staff Users in DB: ${userCount}`);

    const tableCount = await prisma.restaurantTable.count();
    console.log(` Restaurant Tables in DB: ${tableCount}`);

    const categoryCount = await prisma.menuCategory.count();
    console.log(` Menu Categories in DB: ${categoryCount}`);

    const itemCount = await prisma.menuItem.count();
    console.log(` Menu Items in DB: ${itemCount}`);

    const orderCount = await prisma.order.count();
    console.log(` Orders in DB: ${orderCount}`);

    console.log('\n Real local database is active and working properly.');
  } catch (err) {
    console.error('❌ Connection failed:', err.message);
    console.log('\nTroubleshooting Checklist:');
    console.log('1. Verify PostgreSQL service is running: Run "net start postgresql-x64-18" as Administrator.');
    console.log('2. Check DATABASE_URL in backend/.env.');
    console.log('3. Run "npx prisma db push" to initialize tables if they do not exist yet.');
  } finally {
    await prisma.$disconnect();
  }
}

testDatabase();

