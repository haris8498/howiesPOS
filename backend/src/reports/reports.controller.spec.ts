import { Test, TestingModule } from '@nestjs/testing';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('ReportsController', () => {
  let controller: ReportsController;

  const mockSummary = {
    totalRevenue: 5000,
    totalOrders: 20,
    totalUnitsSold: 35,
    avgItemPrice: 142.85,
    topCategory: 'Pizza',
    totalExpenses: 800,
    netProfit: 4200,
    dateRange: {
      startDate: '2026-09-01T00:00:00.000Z',
      endDate: '2026-09-30T23:59:59.999Z',
      period: 'This Month',
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ReportsController],
      providers: [
        {
          provide: ReportsService,
          useValue: {
            getSummary: jest.fn().mockResolvedValue(mockSummary),
            getProductPerformance: jest.fn().mockResolvedValue([]),
            getOrderTypeStats: jest.fn().mockResolvedValue([]),
            getDailySalesTrend: jest.fn().mockResolvedValue([]),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    controller = module.get<ReportsController>(ReportsController);
  });

  it('should return report summary', async () => {
    const result = await controller.getSummary({ period: 'thisMonth' });
    expect(result.success).toBe(true);
    expect(result.data.totalRevenue).toBe(5000);
    expect(result.data.netProfit).toBe(4200);
  });

  it('should return product performance', async () => {
    const result = await controller.getProductPerformance({});
    expect(result.success).toBe(true);
    expect(Array.isArray(result.data)).toBe(true);
  });

  it('should return order type distribution', async () => {
    const result = await controller.getOrderTypeStats({});
    expect(result.success).toBe(true);
    expect(Array.isArray(result.data)).toBe(true);
  });

  it('should return daily sales trend', async () => {
    const result = await controller.getDailySalesTrend({});
    expect(result.success).toBe(true);
    expect(Array.isArray(result.data)).toBe(true);
  });
});
