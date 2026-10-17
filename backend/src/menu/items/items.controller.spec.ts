import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { ItemsController } from './items.controller';
import { ItemsService } from './items.service';
import { PermissionsService } from '../../permissions/permissions.service';

describe('ItemsController', () => {
  let controller: ItemsController;

  const mockItem = {
    id: 'item-1',
    category_id: 'pizza',
    name: 'Pepperoni Pizza',
    description: 'Crispy pepperoni pizza',
    base_price: new Prisma.Decimal(899.0),
    image_url: 'assets/images/pepperoni.png',
    is_veg: false,
    is_spicy: true,
    is_available: true,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [ItemsController],
      providers: [
        {
          provide: ItemsService,
          useValue: {
            listItems: jest.fn().mockResolvedValue([mockItem]),
            getItemById: jest.fn().mockResolvedValue(mockItem),
            createItem: jest.fn().mockResolvedValue(mockItem),
            updateItem: jest.fn().mockResolvedValue(mockItem),
            updateAvailability: jest.fn().mockResolvedValue({ ...mockItem, is_available: false }),
            deleteItem: jest.fn().mockResolvedValue({ message: 'Item deleted' }),
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

    controller = module.get<ItemsController>(ItemsController);
  });

  it('should list menu items', async () => {
    const result = await controller.listItems({});
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
  });

  it('should get menu item by id', async () => {
    const result = await controller.getItemById('item-1');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('item-1');
  });

  it('should create menu item', async () => {
    const result = await controller.createItem({
      category_id: 'pizza',
      name: 'Pepperoni Pizza',
      base_price: 899.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item created successfully');
  });

  it('should update menu item', async () => {
    const result = await controller.updateItem('item-1', {
      name: 'New Name',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item updated successfully');
  });

  it('should toggle availability', async () => {
    const result = await controller.updateAvailability('item-1', { is_available: false });
    expect(result.success).toBe(true);
    expect(result.data?.is_available).toBe(false);
  });

  it('should delete menu item', async () => {
    const result = await controller.deleteItem('item-1');
    expect(result.success).toBe(true);
  });
});
