import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ItemsService } from './items.service';

describe('ItemsService', () => {
  let service: ItemsService;

  const mockItem = {
    id: 'item-1',
    category_id: 'pizza',
    name: 'Pepperoni Passion',
    description: 'Loaded with pepperoni',
    base_price: new Prisma.Decimal(899.0),
    image_url: 'assets/images/pepperoni.png',
    is_veg: false,
    is_spicy: true,
    is_available: true,
    category: { id: 'pizza', name: 'Pizza' },
    sizes: [],
    options: [],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ItemsService,
        {
          provide: PrismaService,
          useValue: {
            menuCategory: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'pizza') return Promise.resolve({ id: 'pizza', name: 'Pizza' });
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const search = where?.OR?.[0]?.name?.equals || where?.OR?.[1]?.id?.equals || where?.id;
                if (search === 'pizza') return Promise.resolve({ id: 'pizza', name: 'Pizza' });
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: data.id || 'cat-new',
                  name: data.name,
                  badge_text: data.badge_text || '',
                  image_path: '',
                  description: '',
                  icon_name: '',
                }),
              ),
            },
            menuItem: {
              findMany: jest.fn().mockResolvedValue([mockItem]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'item-1') return Promise.resolve(mockItem);
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const search = where?.OR?.[0]?.id || where?.OR?.[1]?.name?.equals || where?.id;
                if (search === 'item-1' || search === 'Pepperoni Passion') return Promise.resolve(mockItem);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'item-new',
                  ...data,
                  category: { id: data.category_id || 'pizza', name: 'Pizza' },
                  sizes: [],
                  options: [],
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockItem,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockItem),
            },
            orderItem: {
              updateMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
            menuItemSize: {
              deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
            menuItemOption: {
              deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
          },
        },
      ],
    }).compile();

    service = module.get<ItemsService>(ItemsService);
  });

  it('should list menu items with filters', async () => {
    const result = await service.listItems({ category_id: 'pizza', is_available: true });
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('item-1');
  });

  it('should get item by id', async () => {
    const result = await service.getItemById('item-1');
    expect(result.id).toBe('item-1');
  });

  it('should throw NotFoundException if item does not exist', async () => {
    await expect(service.getItemById('non-existing')).rejects.toThrow(NotFoundException);
  });

  it('should create menu item with valid category', async () => {
    const result = await service.createItem({
      category_id: 'pizza',
      name: 'BBQ Chicken',
      base_price: 999.0,
      is_veg: false,
      is_spicy: false,
    });
    expect(result.name).toBe('BBQ Chicken');
  });

  it('should auto-create category if category does not exist during creation', async () => {
    const result = await service.createItem({
      category_id: 'appetizers',
      name: 'BBQ Chicken',
      base_price: 999.0,
      is_veg: false,
      is_spicy: false,
    });
    expect(result.name).toBe('BBQ Chicken');
  });

  it('should update menu item and validate new category if provided', async () => {
    const result = await service.updateItem('item-1', {
      name: 'Super Pepperoni Passion',
      base_price: 949.0,
    });
    expect(result.name).toBe('Super Pepperoni Passion');
  });

  it('should toggle availability', async () => {
    const result = await service.updateAvailability('item-1', { is_available: false });
    expect(result.is_available).toBe(false);
  });

  it('should delete menu item', async () => {
    const result = await service.deleteItem('item-1');
    expect(result.message).toContain('deleted successfully');
  });
});
