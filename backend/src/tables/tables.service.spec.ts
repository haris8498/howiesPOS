import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma, RestaurantTable } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TablesService } from './tables.service';

describe('TablesService', () => {
  let service: TablesService;

  const mockTable: RestaurantTable = {
    id: 'tbl-1',
    table_number: 'T-01',
    name: 'Table 1',
    capacity: 4,
    section: 'Main Hall',
    zone_id: null,
    status: 'available',
    current_customer_count: 0,
    current_bill_amount: new Prisma.Decimal(0.0),
    occupied_since: null,
    active_order_id: null,
    reserved_customer_name: null,
    reservation_time: null,
    is_deleted: false,
    deleted_at: null,
    deleted_by: null,
    is_overflow: false,
    parent_table_id: null,
    overflow_suffix: null,
    version: 1,
    updated_at: new Date(),
  };

  const mockOccupiedTable: RestaurantTable = {
    id: 'tbl-2',
    table_number: 'T-02',
    name: 'Table 2',
    capacity: 6,
    section: 'Family Hall',
    zone_id: null,
    status: 'occupied',
    current_customer_count: 4,
    current_bill_amount: new Prisma.Decimal(1890.0),
    occupied_since: new Date('2026-09-26T20:00:00Z'),
    active_order_id: 'ord-101',
    reserved_customer_name: null,
    reservation_time: null,
    is_deleted: false,
    deleted_at: null,
    deleted_by: null,
    is_overflow: false,
    parent_table_id: null,
    overflow_suffix: null,
    version: 1,
    updated_at: new Date(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TablesService,
        {
          provide: PrismaService,
          useValue: {
            restaurantTable: {
              findMany: jest.fn().mockResolvedValue([mockTable, mockOccupiedTable]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'tbl-1' || where.table_number === 'T-01') {
                  return Promise.resolve(mockTable);
                }
                if (where.id === 'tbl-2' || where.table_number === 'T-02') {
                  return Promise.resolve(mockOccupiedTable);
                }
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const tableNumber =
                  where?.table_number?.equals ||
                  where?.OR?.find((o: any) => o.table_number?.equals)?.table_number?.equals ||
                  where?.table_number;
                const name =
                  where?.name?.equals ||
                  where?.OR?.find((o: any) => o.name?.equals)?.name?.equals ||
                  where?.name;
                const id = where?.id || where?.OR?.find((o: any) => o.id)?.id;
                if (
                  tableNumber === 'T-01' ||
                  name === 'Duplicate Table' ||
                  name === 'Table 1' ||
                  id === 'tbl-1'
                ) {
                  return Promise.resolve(mockTable);
                }
                if (tableNumber === 'T-02' || name === 'Table 2' || id === 'tbl-2') {
                  return Promise.resolve(mockOccupiedTable);
                }
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'tbl-new',
                  current_customer_count: 0,
                  current_bill_amount: new Prisma.Decimal(0.0),
                  occupied_since: null,
                  active_order_id: null,
                  reserved_customer_name: null,
                  reservation_time: null,
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockTable,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockTable),
            },
            order: {
              findMany: jest.fn().mockImplementation(({ where }: any) => {
                if (where?.OR?.some((cond: any) => cond.id === 'ord-101' || cond.dine_in_detail?.table_id === 'tbl-2')) {
                  return Promise.resolve([{ id: 'ord-101', order_number: '101', status: 'newOrder', grand_total: 1890, created_at: new Date() }]);
                }
                return Promise.resolve([]);
              }),
              findUnique: jest.fn().mockResolvedValue(null),
              updateMany: jest.fn().mockResolvedValue({ count: 1 }),
            },
            dineInOrderDetail: {
              deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
              updateMany: jest.fn().mockResolvedValue({ count: 1 }),
              count: jest.fn().mockResolvedValue(0),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                restaurantTable: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'tbl-2') return Promise.resolve(mockOccupiedTable);
                    if (where.id === 'tbl-1') return Promise.resolve(mockTable);
                    return Promise.resolve(null);
                  }),
                  update: jest.fn().mockImplementation(({ where, data }) => {
                    if (where.id === 'tbl-1') {
                      return Promise.resolve({ ...mockTable, ...data });
                    }
                    return Promise.resolve({ ...mockOccupiedTable, ...data });
                  }),
                },
                order: {
                  updateMany: jest.fn().mockResolvedValue({ count: 1 }),
                },
                dineInOrderDetail: {
                  findMany: jest.fn().mockResolvedValue([]),
                  updateMany: jest.fn().mockResolvedValue({ count: 1 }),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<TablesService>(TablesService);
  });

  it('should list all tables', async () => {
    const result = await service.listTables();
    expect(result).toHaveLength(2);
    expect(result[0].table_number).toBe('T-01');
  });

  it('unpushed-order table is not auto-freed', async () => {
    // ord-101 is missing from database (unpushed local order)
    const result = await service.listTables();
    const table2 = result.find((t) => t.id === 'tbl-2');
    expect(table2).toBeDefined();
    expect(table2.status).toBe('occupied');
    expect(table2.active_order_id).toBe('ord-101');
  });

  it('cancelled order no longer keeps the table occupied in tables.service', async () => {
    const prisma = (service as any).prisma;
    prisma.order.findMany.mockResolvedValueOnce([
      {
        id: 'ord-101',
        order_number: '101',
        status: 'cancelled',
        is_paid: false,
        order_items: [],
      },
    ]);
    const result = await service.listTables();
    const table2 = result.find((t) => t.id === 'tbl-2');
    expect(table2).toBeDefined();
    expect(table2.status).toBe('available');
    expect(table2.active_order_id).toBeNull();
    expect(table2.current_order_items).toEqual([]);
    expect(table2.current_bill_amount).toBe(0);
    expect(table2.current_customer_count).toBe(0);
  });

  it('should list tables with search filter', async () => {
    const result = await service.listTables({ search: 'T-01' });
    expect(result).toHaveLength(2);
  });

  it('should get table by id', async () => {
    const result = await service.getTableById('tbl-1');
    expect(result.id).toBe('tbl-1');
  });

  it('should throw NotFoundException for non-existing table id', async () => {
    await expect(service.getTableById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should create a new table', async () => {
    const result = await service.createTable({
      table_number: 'T-03',
      name: 'Table 3',
      capacity: 4,
      section: 'Outdoor Terrace',
    });
    expect(result.table_number).toBe('T-03');
    expect(result.name).toBe('Table 3');
  });

  it('should throw ConflictException if table_number already exists', async () => {
    await expect(
      service.createTable({
        table_number: 'T-01',
        name: 'Duplicate Table',
        capacity: 4,
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should update table details', async () => {
    const result = await service.updateTable('tbl-1', {
      name: 'Updated Table 1',
      capacity: 6,
    });
    expect(result.name).toBe('Updated Table 1');
  });

  it('should update table status to occupied', async () => {
    const result = await service.updateTableStatus('tbl-1', {
      status: 'occupied',
      active_order_id: 'ord-100',
      current_bill_amount: 1250.0,
      current_customer_count: 3,
    });
    expect(result.status).toBe('occupied');
  });

  it('should release table to available status', async () => {
    const result = await service.releaseTable('tbl-2');
    expect(result.status).toBe('available');
    expect(result.active_order_id).toBeNull();
  });

  it('should transfer dining session from occupied table to available table', async () => {
    const result = await service.transferTable({
      from_table_id: 'tbl-2',
      to_table_id: 'tbl-1',
    });
    expect(result.fromTable.status).toBe('available');
    expect(result.toTable.status).toBe('occupied');
  });

  it('should throw BadRequestException if transfer source and destination are the same', async () => {
    await expect(
      service.transferTable({
        from_table_id: 'tbl-1',
        to_table_id: 'tbl-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should update table reservation', async () => {
    const result = await service.updateTableReservation('tbl-1', {
      reserved_customer_name: 'David Beckham',
      reservation_time: '2026-09-27T19:00:00Z',
    });
    expect(result.status).toBe('reserved');
    expect(result.reserved_customer_name).toBe('David Beckham');
  });

  it('should delete an available table', async () => {
    const result = await service.deleteTable('tbl-1');
    expect(result.message).toContain('deleted successfully');
  });

  it('should soft-delete an occupied table and return open orders in response without blocking', async () => {
    const result = await service.deleteTable('tbl-2');
    expect(result.message).toContain('deleted successfully');
    expect(result.table.is_deleted).toBe(true);
    expect(result.has_open_orders).toBe(true);
    expect(result.open_orders.length).toBeGreaterThan(0);
  });

  it('should restore a soft-deleted table', async () => {
    const deletedMockTable = { ...mockTable, is_deleted: true, deleted_at: new Date() };
    (service as any).prisma.restaurantTable.findFirst = jest.fn().mockResolvedValueOnce(deletedMockTable).mockResolvedValueOnce(null);
    const result = await service.restoreTable('tbl-1');
    expect(result.message).toContain('restored successfully');
    expect(result.table.is_deleted).toBe(false);
  });
});
