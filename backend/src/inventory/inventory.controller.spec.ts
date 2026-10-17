import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

describe('InventoryController', () => {
  let controller: InventoryController;

  const mockItem = {
    id: 'item-1',
    sku_code: 'SKU-101',
    name: 'Pizza Flour',
    category: 'Bakery',
    initial_stock: new Prisma.Decimal(100.0),
    used_stock: new Prisma.Decimal(20.0),
    current_stock: new Prisma.Decimal(80.0),
    min_threshold: new Prisma.Decimal(15.0),
    unit: 'kg',
    cost_per_unit: new Prisma.Decimal(120.0),
    supplier_name: 'Metro Flour Mills',
    last_restocked_date: new Date('2026-09-20T10:00:00Z'),
    stock_movements: [],
  };

  const mockMovement = {
    id: 'mov-1',
    item_id: 'item-1',
    item_name: 'Pizza Flour',
    movement_type: 'stockIn',
    quantity: new Prisma.Decimal(50.0),
    unit: 'kg',
    reason: 'Restock Inward',
    timestamp: new Date('2026-09-20T10:00:00Z'),
    cost_impact: new Prisma.Decimal(6000.0),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [InventoryController],
      providers: [
        {
          provide: InventoryService,
          useValue: {
            listItems: jest.fn().mockResolvedValue([mockItem]),
            getLowStockItems: jest.fn().mockResolvedValue([mockItem]),
            getItemById: jest.fn().mockResolvedValue(mockItem),
            createItem: jest.fn().mockResolvedValue(mockItem),
            updateItem: jest.fn().mockResolvedValue({ ...mockItem, name: 'Updated Flour' }),
            deleteItem: jest
              .fn()
              .mockResolvedValue({ message: 'Inventory item deleted successfully' }),
            stockIn: jest.fn().mockResolvedValue({ item: mockItem, movement: mockMovement }),
            stockOut: jest.fn().mockResolvedValue({
              item: mockItem,
              movement: { ...mockMovement, movement_type: 'stockOut' },
            }),
            listMovements: jest.fn().mockResolvedValue([mockMovement]),
            getMovementsByItemId: jest.fn().mockResolvedValue([mockMovement]),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<InventoryController>(InventoryController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return list of inventory items', async () => {
    const response = await controller.listItems({});
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });

  it('should return low stock items', async () => {
    const response = await controller.getLowStockItems();
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });

  it('should return item by id', async () => {
    const response = await controller.getItemById('item-1');
    expect(response.success).toBe(true);
    expect(response.data!.id).toBe('item-1');
  });

  it('should create new item', async () => {
    const response = await controller.createItem({
      sku_code: 'SKU-101',
      name: 'Pizza Flour',
    });
    expect(response.success).toBe(true);
    expect(response.data!.sku_code).toBe('SKU-101');
  });

  it('should update item', async () => {
    const response = await controller.updateItem('item-1', {
      name: 'Updated Flour',
    });
    expect(response.success).toBe(true);
    expect(response.data!.name).toBe('Updated Flour');
  });

  it('should delete item', async () => {
    const response = await controller.deleteItem('item-1');
    expect(response.success).toBe(true);
    expect(response.message).toContain('deleted successfully');
  });

  it('should perform stock-in', async () => {
    const response = await controller.stockIn({
      item_id: 'item-1',
      quantity: 50.0,
    });
    expect(response.success).toBe(true);
    expect(response.data!.movement.movement_type).toBe('stockIn');
  });

  it('should perform stock-out', async () => {
    const response = await controller.stockOut({
      item_id: 'item-1',
      quantity: 10.0,
    });
    expect(response.success).toBe(true);
    expect(response.data!.movement.movement_type).toBe('stockOut');
  });

  it('should list all stock movements', async () => {
    const response = await controller.listMovements({});
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });

  it('should get movements by item id', async () => {
    const response = await controller.getMovementsByItemId('item-1');
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });
});
