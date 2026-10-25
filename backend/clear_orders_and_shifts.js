const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function clearData() {
  console.log('--- STARTING CLEANUP OF ORDERS, CALCULATIONS & SHIFTS ---');

  const result = await prisma.$transaction(async (tx) => {
    // 1. Order details & dependencies
    const deletedDispatches = await tx.deliveryDispatch.deleteMany({});
    const deletedOnlineDetails = await tx.onlineOrderDetail.deleteMany({});
    const deletedTakeawayDetails = await tx.takeawayOrderDetail.deleteMany({});
    const deletedDineInDetails = await tx.dineInOrderDetail.deleteMany({});
    const deletedOrderItems = await tx.orderItem.deleteMany({});
    const deletedOrderPayments = await tx.orderPayment.deleteMany({});

    // 2. Orders
    const deletedOrders = await tx.order.deleteMany({});

    // 3. Shift calculations & daily expenses
    const deletedDailyExpenses = await tx.dailyExpenseItem.deleteMany({});
    const deletedDailyCalculations = await tx.dailyCalculation.deleteMany({});

    // 4. Reset restaurant tables occupied status
    const resetTables = await tx.restaurantTable.updateMany({
      data: {
        status: 'available',
        current_customer_count: 0,
        current_bill_amount: 0,
        occupied_since: null,
        active_order_id: null,
      },
    });

    // 5. Reset customer order stats
    const resetCustomers = await tx.customer.updateMany({
      data: {
        total_orders_count: 0,
        total_spent: 0.0,
        loyalty_points: 0,
      },
    });

    // 6. Clear sync logs & idempotency operations related to orders / shifts
    const deletedSyncLogs = await tx.dataSyncLog.deleteMany({});
    const deletedProcessedOps = await tx.processedOperation.deleteMany({
      where: {
        entity_type: {
          in: ['Order', 'DailyCalculation', 'DailyExpenseItem', 'ORDER', 'SHIFT', 'DAILY_CALCULATION'],
        },
      },
    });
    const deletedChangeLogs = await tx.systemChangeLog.deleteMany({
      where: {
        entity_type: {
          in: ['Order', 'DailyCalculation', 'DailyExpenseItem', 'ORDER', 'SHIFT', 'DAILY_CALCULATION'],
        },
      },
    });

    return {
      deletedOrders: deletedOrders.count,
      deletedOrderItems: deletedOrderItems.count,
      deletedOrderPayments: deletedOrderPayments.count,
      deletedDailyCalculations: deletedDailyCalculations.count,
      deletedDailyExpenses: deletedDailyExpenses.count,
      resetTables: resetTables.count,
      resetCustomers: resetCustomers.count,
      deletedSyncLogs: deletedSyncLogs.count,
      deletedProcessedOps: deletedProcessedOps.count,
      deletedChangeLogs: deletedChangeLogs.count,
    };
  });

  console.log('✅ Cleanup successful:');
  console.log(`- Orders deleted: ${result.deletedOrders}`);
  console.log(`- Order items deleted: ${result.deletedOrderItems}`);
  console.log(`- Order payments deleted: ${result.deletedOrderPayments}`);
  console.log(`- Shift calculations deleted: ${result.deletedDailyCalculations}`);
  console.log(`- Shift expense items deleted: ${result.deletedDailyExpenses}`);
  console.log(`- Restaurant tables reset to available: ${result.resetTables}`);
  console.log(`- Customers reset (total orders & spent = 0): ${result.resetCustomers}`);
  console.log(`- Sync logs cleared: ${result.deletedSyncLogs}`);
  console.log(`- Idempotency & change logs cleared: ${result.deletedProcessedOps + result.deletedChangeLogs}`);
}

clearData()
  .catch((err) => {
    console.error('❌ Error clearing database records:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
