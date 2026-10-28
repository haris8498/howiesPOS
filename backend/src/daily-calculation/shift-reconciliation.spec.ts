import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { DailyCalculationService } from './daily-calculation.service';
import { PrismaService } from '../prisma/prisma.service';

describe('Shift Reconciliation - Part 1: Cash Refunds & Drawer Totals', () => {
  let service: DailyCalculationService;
  let mockPrisma: any;

  const mockActiveShift = {
    id: 'shift-active-today',
    date: new Date('2026-10-28T08:00:00Z'),
    created_at: new Date('2026-10-28T08:00:00Z'),
    shift_name: 'Morning Shift',
    cashier_id: 'cashier-1',
    cashier_name: 'Alice',
    starting_cash: new Prisma.Decimal(5000),
    total_change_cash: new Prisma.Decimal(5000),
    status: 'ACTIVE',
    restaurant_id: 'default',
    terminal_id: '1',
    expense_items: [],
  };

  beforeEach(async () => {
    mockPrisma = {
      dailyCalculation: {
        findFirst: jest.fn().mockImplementation(({ where }: any) => {
          if (where?.status === 'ACTIVE') {
            return Promise.resolve(mockActiveShift);
          }
          return Promise.resolve(mockActiveShift);
        }),
        findUnique: jest.fn().mockResolvedValue(mockActiveShift),
        update: jest.fn().mockImplementation(({ data }: any) =>
          Promise.resolve({
            ...mockActiveShift,
            ...data,
          }),
        ),
      },
      order: {
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      orderAdjustment: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      dailyExpenseItem: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      deliveryDispatch: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      expense: {
        create: jest.fn().mockResolvedValue({}),
      },
      deliveryRider: {
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      $transaction: jest.fn().mockImplementation((fn: (tx: any) => Promise<any>) => fn(mockPrisma)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DailyCalculationService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<DailyCalculationService>(DailyCalculationService);
  });

  // Test 1: Cross-shift cash refund lowers the active shift's expected drawer cash
  it('1. Cross-shift cash refund lowers the active shift\'s expected drawer cash', async () => {
    // Orders query mock: unresolved orders check (where.AND) returns [], getLiveSummary returns active completed orders
    const activeOrders = [
      {
        id: 'ord-today-1',
        shift_id: 'shift-active-today',
        order_number: 'ORD-101',
        order_type: 'takeaway',
        status: 'completed',
        is_paid: true,
        grand_total: new Prisma.Decimal(2000),
        discount_amount: new Prisma.Decimal(0),
        tax_amount: new Prisma.Decimal(0),
        payments: [{ payment_method: 'cash', amount: new Prisma.Decimal(2000) }],
      },
    ];

    mockPrisma.order.findMany.mockImplementation(({ where }: any) => {
      if (where?.AND) {
        return Promise.resolve([]); // 0 unresolved orders
      }
      return Promise.resolve(activeOrders);
    });

    // An earlier order from yesterday's shift was refunded in cash during today's shift
    mockPrisma.orderAdjustment.findMany.mockResolvedValue([
      {
        id: 'adj-refund-1',
        shift_id: 'shift-active-today', // refunded during today's shift
        type: 'REFUND',
        amount: new Prisma.Decimal(1000),
        refund_method: 'cash',
        order: {
          id: 'ord-yesterday-99',
          shift_id: 'shift-closed-yesterday', // original order from earlier/closed shift
          payments: [{ payment_method: 'cash', amount: new Prisma.Decimal(1000) }],
        },
      },
    ]);

    const live = await service.getLiveSummary('2026-10-28', 'cashier-1');

    expect(live.has_active_session).toBe(true);
    expect(live.total_cash_sales).toBe(2000);
    expect(live.cash_refunds_total).toBe(1000);
    // Expected drawer cash = starting_cash (5000) + cash_sales (2000) - cash_refunds (1000) = 6000
    expect(live.expected_drawer_cash).toBe(6000);
    expect(live.expected_cash_in_hand).toBe(6000);

    // Also verify shift close calculates expected_cash_in_hand and persists cash_refunds_total
    const closed = await service.submitDailyCalculation(
      {
        shift_id: 'shift-active-today',
        cashier_id: 'cashier-1',
        date: '2026-10-28',
        cash_submitted: 6000,
      },
      { id: 'cashier-1', username: 'Alice' },
    );

    expect(mockPrisma.dailyCalculation.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'shift-active-today' },
        data: expect.objectContaining({
          cash_refunds_total: new Prisma.Decimal(1000),
          expected_cash_in_hand: new Prisma.Decimal(6000),
        }),
      }),
    );
  });

  // Test 2: Same-shift refund is NOT deducted twice
  it('2. Same-shift refund is NOT deducted twice', async () => {
    // In same-shift refund:
    // Order was cancelled upon refund, so order.findMany does not include it.
    // Only valid active orders (e.g. 2000 cash order) are in total_cash_sales.
    mockPrisma.order.findMany.mockResolvedValueOnce([
      {
        id: 'ord-today-2',
        shift_id: 'shift-active-today',
        order_number: 'ORD-102',
        order_type: 'takeaway',
        status: 'completed',
        is_paid: true,
        grand_total: new Prisma.Decimal(2000),
        discount_amount: new Prisma.Decimal(0),
        tax_amount: new Prisma.Decimal(0),
        payments: [{ payment_method: 'cash', amount: new Prisma.Decimal(2000) }],
      },
    ]);

    // The refunded order belongs to the SAME active shift
    mockPrisma.orderAdjustment.findMany.mockResolvedValueOnce([
      {
        id: 'adj-refund-same-shift',
        shift_id: 'shift-active-today',
        type: 'REFUND',
        amount: new Prisma.Decimal(500),
        refund_method: 'cash',
        order: {
          id: 'ord-today-cancelled',
          shift_id: 'shift-active-today', // SAME shift!
          payments: [{ payment_method: 'cash', amount: new Prisma.Decimal(500) }],
        },
      },
    ]);

    const live = await service.getLiveSummary('2026-10-28', 'cashier-1');

    // Same-shift refund must NOT be added to cash_refunds_total (as the sale is already absent from cash sales)
    expect(live.total_cash_sales).toBe(2000);
    expect(live.cash_refunds_total).toBe(0);
    // Expected drawer cash = starting_cash (5000) + cash_sales (2000) = 7000 (NOT 6500)
    expect(live.expected_drawer_cash).toBe(7000);
    expect(live.expected_cash_in_hand).toBe(7000);
  });
});
