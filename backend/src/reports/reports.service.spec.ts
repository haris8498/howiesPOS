import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ReportsService } from './reports.service';

describe('ReportsService', () => {
  let service: ReportsService;

  const mockOrders = [
    {
      id: 'ord-1',
      order_number: 'ORD-101',
      order_type: 'dineIn',
      status: 'completed',
      subtotal: new Prisma.Decimal(100.0),
      grand_total: new Prisma.Decimal(110.0),
      created_at: new Date('2026-09-26T10:00:00Z'),
      order_items: [
        {
          id: 'item-1',
          item_name: 'Fajita Pizza',
          quantity: 2,
          unit_price: new Prisma.Decimal(50.0),
          total_price: new Prisma.Decimal(100.0),
          menu_item: {
            category: { name: 'Pizza' },
          },
        },
      ],
    },
    {
      id: 'ord-2',
      order_number: 'ORD-102',
      order_type: 'takeAway',
      status: 'completed',
      subtotal: new Prisma.Decimal(40.0),
      grand_total: new Prisma.Decimal(44.0),
      created_at: new Date('2026-09-26T14:00:00Z'),
      order_items: [
        {
          id: 'item-2',
          item_name: 'Zinger Burger',
          quantity: 1,
          unit_price: new Prisma.Decimal(40.0),
          total_price: new Prisma.Decimal(40.0),
          menu_item: {
            category: { name: 'Burger' },
          },
        },
      ],
    },
  ];

  const mockExpenses = [
    {
      id: 'exp-1',
      amount: new Prisma.Decimal(30.0),
      date: new Date('2026-09-26T12:00:00Z'),
      category: 'Supplies',
    },
  ];

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReportsService,
        {
          provide: PrismaService,
          useValue: {
            order: {
              findMany: jest.fn().mockResolvedValue(mockOrders),
            },
            orderItem: {
              findMany: jest.fn().mockResolvedValue([
                {
                  id: 'item-1',
                  item_name: 'Fajita Pizza',
                  quantity: 2,
                  unit_price: new Prisma.Decimal(50.0),
                  total_price: new Prisma.Decimal(100.0),
                  menu_item: { category: { name: 'Pizza' } },
                },
                {
                  id: 'item-2',
                  item_name: 'Zinger Burger',
                  quantity: 1,
                  unit_price: new Prisma.Decimal(40.0),
                  total_price: new Prisma.Decimal(40.0),
                  menu_item: { category: { name: 'Burger' } },
                },
              ]),
            },
            expense: {
              findMany: jest.fn().mockResolvedValue(mockExpenses),
            },
            dailyCalculation: {
              findFirst: jest.fn().mockResolvedValue(null),
            },
          },
        },
      ],
    }).compile();

    service = module.get<ReportsService>(ReportsService);
  });

  it('should calculate executive summary metrics correctly', async () => {
    const summary = await service.getSummary({ period: 'today' });
    expect(summary.totalOrders).toBe(2);
    expect(summary.totalRevenue).toBe(154.0); // 110 + 44
    expect(summary.totalUnitsSold).toBe(3); // 2 + 1
    expect(summary.totalExpenses).toBe(30.0);
    expect(summary.netProfit).toBe(124.0); // 154 - 30
  });

  it('should calculate product sales performance breakdown', async () => {
    const products = await service.getProductPerformance({ period: 'thisMonth' });
    expect(products.length).toBe(2);
    expect(products[0].productName).toBe('Fajita Pizza');
    expect(products[0].unitsSold).toBe(2);
    expect(products[0].totalRevenue).toBe(100.0);
  });

  it('should calculate order type distribution', async () => {
    const stats = await service.getOrderTypeStats({ period: 'thisMonth' });
    expect(stats.length).toBe(2);
    const dineIn = stats.find((s) => s.orderType === 'dineIn');
    expect(dineIn).toBeDefined();
    expect(dineIn?.orderCount).toBe(1);
    expect(dineIn?.totalRevenue).toBe(110.0);
  });

  it('should calculate daily sales trend', async () => {
    const trends = await service.getDailySalesTrend({ period: 'thisMonth' });
    expect(trends.length).toBe(1);
    expect(trends[0].totalRevenue).toBe(154.0);
    expect(trends[0].orderCount).toBe(2);
  });

  it('should handle custom date range resolution safely', () => {
    const range = service.resolveDateRange({
      startDate: '2026-09-01',
      endDate: '2026-09-30',
    });
    expect(range.periodLabel).toBe('Custom Date');
    expect(range.start.getFullYear()).toBe(2026);
  });
});
