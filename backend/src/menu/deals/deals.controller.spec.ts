import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { DealsController } from './deals.controller';
import { DealsService } from './deals.service';
import { PermissionsService } from '../../permissions/permissions.service';

describe('DealsController', () => {
  let controller: DealsController;

  const mockDeal = {
    id: 'deal-1',
    title: 'Family Feast Combo',
    subtitle: '2 Large Pizzas + Garlic Bread + 1.5L Coke',
    deal_price: new Prisma.Decimal(2499.0),
    original_price: new Prisma.Decimal(3299.0),
    badge_text: 'HOT DEAL',
    image_path: 'assets/images/family_feast.png',
    description: 'Perfect for 4-5 persons',
    is_available: true,
    components: [],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [DealsController],
      providers: [
        {
          provide: DealsService,
          useValue: {
            listDeals: jest.fn().mockResolvedValue([mockDeal]),
            getDealById: jest.fn().mockResolvedValue(mockDeal),
            createDeal: jest.fn().mockResolvedValue(mockDeal),
            updateDeal: jest.fn().mockResolvedValue(mockDeal),
            deleteDeal: jest.fn().mockResolvedValue({ message: 'Deal deleted' }),
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

    controller = module.get<DealsController>(DealsController);
  });

  it('should list deals', async () => {
    const result = await controller.listDeals({});
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
  });

  it('should get deal by id', async () => {
    const result = await controller.getDealById('deal-1');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('deal-1');
  });

  it('should create deal', async () => {
    const result = await controller.createDeal({
      title: 'Family Feast Combo',
      deal_price: 2499.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Deal created successfully');
  });

  it('should update deal', async () => {
    const result = await controller.updateDeal('deal-1', {
      title: 'Updated Feast Combo',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Deal updated successfully');
  });

  it('should delete deal', async () => {
    const result = await controller.deleteDeal('deal-1');
    expect(result.success).toBe(true);
  });
});
