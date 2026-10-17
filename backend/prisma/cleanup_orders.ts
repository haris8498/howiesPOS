import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const result = await prisma.order.deleteMany({
    where: {
      order_type: { not: 'dineIn' },
    },
  });
  console.log(`Deleted ${result.count} non-dineIn orders.`);
}

main()
  .catch(e => console.error(e))
  .finally(async () => {
    await prisma.$disconnect();
  });
