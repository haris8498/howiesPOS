import { Test, TestingModule } from '@nestjs/testing';
import { PricingController } from './pricing.controller';
import { PricingService } from './pricing.service';
import { PermissionsService } from '../permissions/permissions.service';
import { PrismaService } from '../prisma/prisma.service';
import { Reflector } from '@nestjs/core';

describe('PricingController', () => {
  let controller: PricingController;
  let mockPricingService: any;

  beforeEach(async () => {
    mockPricingService = {
      getPricingAudits: jest.fn().mockResolvedValue([
        { id: 'pa-1', pricing_status: 'MISMATCH' },
      ]),
      getDiscountAudits: jest.fn().mockResolvedValue([
        { id: 'da-1', amount: '50.00' },
      ]),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [PricingController],
      providers: [
        { provide: PricingService, useValue: mockPricingService },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
        {
          provide: PrismaService,
          useValue: {},
        },
        Reflector,
      ],
    }).compile();

    controller = module.get<PricingController>(PricingController);
  });

  it('surfaces pricing audits in admin review list', async () => {
    const result = await controller.getPricingAudits(undefined, 'MISMATCH', 'OFFLINE', 50, 0);
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
    expect(mockPricingService.getPricingAudits).toHaveBeenCalledWith({
      order_id: undefined,
      pricing_status: 'MISMATCH',
      source: 'OFFLINE',
      take: 50,
      skip: 0,
    });
  });

  it('surfaces discount audits list', async () => {
    const result = await controller.getDiscountAudits('ord-1', 50, 0);
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
    expect(mockPricingService.getDiscountAudits).toHaveBeenCalledWith('ord-1', 50, 0);
  });

  it('ensures no mutation endpoints (PUT/PATCH/DELETE) exist on PricingController (immutability)', () => {
    expect((controller as any).updatePricingAudit).toBeUndefined();
    expect((controller as any).deletePricingAudit).toBeUndefined();
    expect((controller as any).updateDiscountAudit).toBeUndefined();
    expect((controller as any).deleteDiscountAudit).toBeUndefined();
  });
});
