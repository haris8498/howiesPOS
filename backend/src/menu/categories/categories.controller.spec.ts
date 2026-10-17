import { Test, TestingModule } from '@nestjs/testing';
import { CategoriesController } from './categories.controller';
import { CategoriesService } from './categories.service';
import { PermissionsService } from '../../permissions/permissions.service';

describe('CategoriesController', () => {
  let controller: CategoriesController;

  const mockCategory = {
    id: 'pizza',
    name: 'Pizza',
    badge_text: 'HOT',
    image_path: 'assets/images/pizza.png',
    description: 'Crust pizzas',
    icon_name: 'local_pizza',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CategoriesController],
      providers: [
        {
          provide: CategoriesService,
          useValue: {
            listCategories: jest.fn().mockResolvedValue([mockCategory]),
            getCategoryById: jest.fn().mockResolvedValue(mockCategory),
            createCategory: jest.fn().mockResolvedValue(mockCategory),
            updateCategory: jest.fn().mockResolvedValue(mockCategory),
            deleteCategory: jest.fn().mockResolvedValue({ message: 'Category deleted' }),
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

    controller = module.get<CategoriesController>(CategoriesController);
  });

  it('should list categories', async () => {
    const result = await controller.listCategories();
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
  });

  it('should get category by id', async () => {
    const result = await controller.getCategoryById('pizza');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('pizza');
  });

  it('should create category', async () => {
    const result = await controller.createCategory({
      id: 'pizza',
      name: 'Pizza',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Category created successfully');
  });

  it('should update category', async () => {
    const result = await controller.updateCategory('pizza', {
      name: 'Pizza Edited',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Category updated successfully');
  });

  it('should delete category', async () => {
    const result = await controller.deleteCategory('pizza');
    expect(result.success).toBe(true);
  });
});
