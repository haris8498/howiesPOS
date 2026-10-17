import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { DealsService } from './deals.service';

describe('DealsService', () => {
  let service: DealsService;

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
    components: [
      {
        id: 'comp-1',
        deal_id: 'deal-1',
        item_name: 'Large Pizza',
        category: 'Pizza',
        quantity: '2x',
      },
      {
        id: 'comp-2',
        deal_id: 'deal-1',
        item_name: 'Garlic Bread',
        category: 'Appetizer',
        quantity: '1x',
      },
    ],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DealsService,
        {
          provide: PrismaService,
          useValue: {
            deal: {
              findMany: jest.fn().mockResolvedValue([mockDeal]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'deal-1') return Promise.resolve(mockDeal);
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const search = where?.OR?.[0]?.id || where?.OR?.[1]?.title?.equals || where?.id;
                if (search === 'deal-1' || search === 'Family Feast Combo') return Promise.resolve(mockDeal);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'deal-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockDeal,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockDeal),
            },
            dealComponent: {
              createMany: jest.fn().mockResolvedValue({ count: 2 }),
              deleteMany: jest.fn().mockResolvedValue({ count: 2 }),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                deal: {
                  create: jest.fn().mockResolvedValue(mockDeal),
                  update: jest.fn().mockResolvedValue(mockDeal),
                  findUnique: jest.fn().mockResolvedValue(mockDeal),
                  findFirst: jest.fn().mockResolvedValue(mockDeal),
                },
                dealComponent: {
                  createMany: jest.fn().mockResolvedValue({ count: 2 }),
                  deleteMany: jest.fn().mockResolvedValue({ count: 2 }),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<DealsService>(DealsService);
  });

  it('should list all deals', async () => {
    const result = await service.listDeals({});
    expect(result).toHaveLength(1);
    expect(result[0].title).toBe('Family Feast Combo');
  });

  it('should get deal by id', async () => {
    const result = await service.getDealById('deal-1');
    expect(result.id).toBe('deal-1');
    expect(result.components).toHaveLength(2);
  });

  it('should throw NotFoundException if deal does not exist', async () => {
    await expect(service.getDealById('non-existing')).rejects.toThrow(NotFoundException);
  });

  it('should create a deal with components via transaction', async () => {
    const result = await service.createDeal({
      title: 'Family Feast Combo',
      deal_price: 2499.0,
      components: [
        {
          item_name: 'Large Pizza',
          category: 'Pizza',
          quantity: '2x',
        },
      ],
    });
    expect(result).toBeDefined();
  });

  it('should update a deal and sync components', async () => {
    const result = await service.updateDeal('deal-1', {
      title: 'Updated Feast Combo',
      deal_price: 2599.0,
    });
    expect(result).toBeDefined();
  });

  it('should delete a deal', async () => {
    const result = await service.deleteDeal('deal-1');
    expect(result.message).toContain('deleted successfully');
  });
});
