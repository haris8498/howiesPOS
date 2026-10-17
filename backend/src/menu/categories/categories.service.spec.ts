import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { MenuCategory } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CategoriesService } from './categories.service';

describe('CategoriesService', () => {
  let service: CategoriesService;
  let prisma: PrismaService;

  const mockCategory: MenuCategory = {
    id: 'pizza',
    name: 'Pizza',
    badge_text: 'HOT',
    image_path: 'assets/images/pizza.png',
    description: 'Delicious crust pizzas',
    icon_name: 'local_pizza',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoriesService,
        {
          provide: PrismaService,
          useValue: {
            menuCategory: {
              findMany: jest.fn().mockResolvedValue([mockCategory]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'pizza') return Promise.resolve(mockCategory);
                return Promise.resolve(null);
              }),
              upsert: jest.fn().mockImplementation(({ where, create, update }) =>
                Promise.resolve({
                  id: where.id,
                  ...create,
                  ...update,
                }),
              ),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockCategory,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockCategory),
            },
            menuItem: {
              deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
              count: jest.fn().mockImplementation(({ where }) => {
                if (where.category_id === 'pizza-with-items') {
                  return Promise.resolve(5);
                }
                return Promise.resolve(0);
              }),
            },
          },
        },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should list all categories', async () => {
    const result = await service.listCategories();
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('pizza');
  });

  it('should get a category by id', async () => {
    const result = await service.getCategoryById('pizza');
    expect(result).toEqual(mockCategory);
  });

  it('should throw NotFoundException if category does not exist', async () => {
    await expect(service.getCategoryById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should create a new category', async () => {
    const result = await service.createCategory({
      id: 'burger',
      name: 'Burger',
      badge_text: 'NEW',
    });
    expect(result.id).toBe('burger');
    expect(result.name).toBe('Burger');
  });

  it('should upsert category if id already exists', async () => {
    const result = await service.createCategory({
      id: 'pizza',
      name: 'Duplicate Pizza',
    });
    expect(result.id).toBe('pizza');
    expect(result.name).toBe('Duplicate Pizza');
  });

  it('should update an existing category', async () => {
    const result = await service.updateCategory('pizza', {
      name: 'Artisan Pizza',
    });
    expect(result.name).toBe('Artisan Pizza');
  });

  it('should delete a category with no menu items', async () => {
    const result = await service.deleteCategory('pizza');
    expect(result.message).toContain('deleted successfully');
  });

  it('should delete category with existing items by cascading', async () => {
    (prisma.menuCategory.findUnique as jest.Mock).mockResolvedValueOnce({
      id: 'pizza-with-items',
      name: 'Pizza With Items',
      menu_items: [{ id: 'item-1' }],
    });

    const result = await service.deleteCategory('pizza-with-items');
    expect(result.message).toContain('deleted successfully');
  });
});
