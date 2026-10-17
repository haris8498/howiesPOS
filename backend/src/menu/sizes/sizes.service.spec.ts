import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { SizesService } from './sizes.service';

describe('SizesService', () => {
  let service: SizesService;
  let prisma: PrismaService;

  const mockItem = {
    id: 'item-1',
    name: 'Pepperoni Pizza',
  };

  const mockSize = {
    id: 'size-1',
    menu_item_id: 'item-1',
    size_name: 'Medium',
    price: new Prisma.Decimal(1199.0),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SizesService,
        {
          provide: PrismaService,
          useValue: {
            menuItem: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'item-1') return Promise.resolve(mockItem);
                return Promise.resolve(null);
              }),
            },
            menuItemSize: {
              findMany: jest.fn().mockResolvedValue([mockSize]),
              findFirst: jest.fn().mockResolvedValue(null),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'size-1') return Promise.resolve(mockSize);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'size-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockSize,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockSize),
            },
          },
        },
      ],
    }).compile();

    service = module.get<SizesService>(SizesService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should list sizes for an item', async () => {
    const result = await service.listSizesByItem('item-1');
    expect(result).toHaveLength(1);
    expect(result[0].size_name).toBe('Medium');
  });

  it('should throw NotFoundException if item does not exist when listing sizes', async () => {
    await expect(service.listSizesByItem('non-existing')).rejects.toThrow(NotFoundException);
  });

  it('should create size for an item', async () => {
    const result = await service.createSize('item-1', {
      size_name: 'Large',
      price: 1499.0,
    });
    expect(result.size_name).toBe('Large');
  });

  it('should throw ConflictException if duplicate size name is provided', async () => {
    (prisma.menuItemSize.findFirst as jest.Mock).mockResolvedValueOnce(mockSize);

    await expect(
      service.createSize('item-1', {
        size_name: 'Medium',
        price: 1299.0,
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should update size', async () => {
    const result = await service.updateSize('size-1', {
      price: 1249.0,
    });
    expect(result).toBeDefined();
  });

  it('should delete size', async () => {
    const result = await service.deleteSize('size-1');
    expect(result.message).toContain('deleted successfully');
  });
});
