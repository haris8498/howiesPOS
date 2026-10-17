import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { InventoryItem, Prisma, StockMovement } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { InventoryService } from './inventory.service';

describe('InventoryService', () => {
  let service: InventoryService;

  const mockItem1: InventoryItem = {
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
  };

  const mockLowStockItem: InventoryItem = {
    id: 'item-2',
    sku_code: 'SKU-102',
    name: 'Mozzarella Cheese',
    category: 'Dairy',
    initial_stock: new Prisma.Decimal(50.0),
    used_stock: new Prisma.Decimal(45.0),
    current_stock: new Prisma.Decimal(5.0),
    min_threshold: new Prisma.Decimal(10.0),
    unit: 'kg',
    cost_per_unit: new Prisma.Decimal(850.0),
    supplier_name: 'Prime Dairies',
    last_restocked_date: new Date('2026-09-18T10:00:00Z'),
  };

  const mockMovement: StockMovement = {
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
      providers: [
        InventoryService,
        {
          provide: PrismaService,
          useValue: {
            inventoryItem: {
              findMany: jest.fn().mockImplementation(({ where }) => {
                if (where?.category?.equals === 'Dairy') {
                  return Promise.resolve([mockLowStockItem]);
                }
                return Promise.resolve([mockItem1, mockLowStockItem]);
              }),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'item-1' || where.sku_code === 'SKU-101') {
                  return Promise.resolve({
                    ...mockItem1,
                    stock_movements: [mockMovement],
                  });
                }
                if (where.id === 'item-2' || where.sku_code === 'SKU-102') {
                  return Promise.resolve({
                    ...mockLowStockItem,
                    stock_movements: [],
                  });
                }
                if (where.id === 'item-clean') {
                  return Promise.resolve({
                    ...mockItem1,
                    id: 'item-clean',
                    name: 'Fresh Oregano',
                    stock_movements: [],
                  });
                }
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'item-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ where, data }) =>
                Promise.resolve({
                  ...(where.id === 'item-2' ? mockLowStockItem : mockItem1),
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockItem1),
            },
            stockMovement: {
              findMany: jest.fn().mockResolvedValue([mockMovement]),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'mov-new',
                  ...data,
                }),
              ),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                inventoryItem: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'item-1') return Promise.resolve(mockItem1);
                    if (where.id === 'item-2') return Promise.resolve(mockLowStockItem);
                    return Promise.resolve(null);
                  }),
                  create: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      id: 'item-created',
                      ...data,
                    }),
                  ),
                  update: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      ...mockItem1,
                      ...data,
                    }),
                  ),
                },
                stockMovement: {
                  create: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      id: 'mov-created',
                      ...data,
                    }),
                  ),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<InventoryService>(InventoryService);
  });

  it('should list all inventory items', async () => {
    const items = await service.listItems();
    expect(items).toHaveLength(2);
    expect(items[0].sku_code).toBe('SKU-101');
  });

  it('should list inventory items filtered by category', async () => {
    const items = await service.listItems({ category: 'Dairy' });
    expect(items).toHaveLength(1);
    expect(items[0].category).toBe('Dairy');
  });

  it('should filter low-stock inventory items', async () => {
    const items = await service.listItems({ is_low_stock: true });
    expect(items).toHaveLength(1);
    expect(items[0].id).toBe('item-2');
  });

  it('should get low-stock items list directly', async () => {
    const items = await service.getLowStockItems();
    expect(items).toHaveLength(1);
    expect(items[0].name).toBe('Mozzarella Cheese');
  });

  it('should get item by id with movements', async () => {
    const item = await service.getItemById('item-1');
    expect(item.id).toBe('item-1');
    expect(item.stock_movements).toHaveLength(1);
  });

  it('should throw NotFoundException for unknown item id', async () => {
    await expect(service.getItemById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should create new inventory item and log opening stock movement', async () => {
    const created = await service.createItem({
      sku_code: 'SKU-103',
      name: 'Tomato Puree',
      category: 'Sauces',
      initial_stock: 40.0,
      min_threshold: 10.0,
      unit: 'kg',
      cost_per_unit: 180.0,
      supplier_name: 'National Foods',
    });
    expect(created.sku_code).toBe('SKU-103');
    expect(created.name).toBe('Tomato Puree');
  });

  it('should throw ConflictException on duplicate SKU code', async () => {
    await expect(
      service.createItem({
        sku_code: 'SKU-101',
        name: 'Duplicate Flour',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should update inventory item details', async () => {
    const updated = await service.updateItem('item-1', {
      name: 'Premium Pizza Flour',
      min_threshold: 20.0,
    });
    expect(updated.name).toBe('Premium Pizza Flour');
  });

  it('should delete item with no stock movements', async () => {
    const result = await service.deleteItem('item-clean');
    expect(result.message).toContain('deleted successfully');
  });

  it('should throw BadRequestException when deleting item with existing movements', async () => {
    await expect(service.deleteItem('item-1')).rejects.toThrow(BadRequestException);
  });

  it('should perform stock-in and update item stock and movement ledger', async () => {
    const result = await service.stockIn({
      item_id: 'item-1',
      quantity: 50.0,
      reason: 'Inward shipment PO-100',
    });
    expect(result.movement.movement_type).toBe('stockIn');
  });

  it('should perform stock-out and reduce current stock', async () => {
    const result = await service.stockOut({
      item_id: 'item-1',
      quantity: 10.0,
      reason: 'Daily pizza production batch',
    });
    expect(result.movement.movement_type).toBe('stockOut');
  });

  it('should record wastage stock-out', async () => {
    const result = await service.stockOut({
      item_id: 'item-1',
      quantity: 5.0,
      movement_type: 'wastage',
      reason: 'Package tear / water damage',
    });
    expect(result.movement.movement_type).toBe('wastage');
  });

  it('should throw BadRequestException on stock-out exceeding available current stock', async () => {
    await expect(
      service.stockOut({
        item_id: 'item-2', // has current_stock 5.0
        quantity: 20.0,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should list all stock movement audit logs', async () => {
    const movements = await service.listMovements();
    expect(movements).toHaveLength(1);
    expect(movements[0].movement_type).toBe('stockIn');
  });

  it('should get movements by item id', async () => {
    const movements = await service.getMovementsByItemId('item-1');
    expect(movements).toHaveLength(1);
  });
});
