import { Test, TestingModule } from '@nestjs/testing';
import { Prisma, RestaurantTable } from '@prisma/client';
import { TablesController } from './tables.controller';
import { TablesService } from './tables.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('TablesController', () => {
  let controller: TablesController;

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


  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [TablesController],
      providers: [
        {
          provide: TablesService,
          useValue: {
            listTables: jest.fn().mockResolvedValue([mockTable]),
            getTableById: jest.fn().mockResolvedValue(mockTable),
            createTable: jest.fn().mockResolvedValue(mockTable),
            updateTable: jest.fn().mockResolvedValue(mockTable),
            updateTableStatus: jest.fn().mockResolvedValue({
              ...mockTable,
              status: 'occupied',
            }),
            releaseTable: jest.fn().mockResolvedValue({
              ...mockTable,
              status: 'available',
            }),
            transferTable: jest.fn().mockResolvedValue({
              fromTable: { ...mockTable, status: 'available' },
              toTable: { ...mockTable, id: 'tbl-2', status: 'occupied' },
            }),
            updateTableReservation: jest.fn().mockResolvedValue({
              ...mockTable,
              status: 'reserved',
              reserved_customer_name: 'David Beckham',
            }),
            deleteTable: jest.fn().mockResolvedValue({ message: 'Table deleted' }),
            restoreTable: jest.fn().mockResolvedValue({ message: 'Table restored', table: mockTable }),
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

    controller = module.get<TablesController>(TablesController);
  });

  it('should list tables', async () => {
    const result = await controller.listTables({});
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
    expect(result.data?.[0].table_number).toBe('T-01');
  });

  it('should get table by id', async () => {
    const result = await controller.getTableById('tbl-1');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('tbl-1');
  });

  it('should create table', async () => {
    const result = await controller.createTable({
      table_number: 'T-01',
      name: 'Table 1',
      capacity: 4,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Table created successfully');
  });

  it('should update table', async () => {
    const result = await controller.updateTable('tbl-1', {
      name: 'New Table Name',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Table updated successfully');
  });

  it('should update table status', async () => {
    const result = await controller.updateTableStatus('tbl-1', {
      status: 'occupied',
    });
    expect(result.success).toBe(true);
    expect(result.data?.status).toBe('occupied');
  });

  it('should release table', async () => {
    const result = await controller.releaseTable('tbl-1');
    expect(result.success).toBe(true);
    expect(result.data?.status).toBe('available');
  });

  it('should transfer table', async () => {
    const result = await controller.transferTable({
      from_table_id: 'tbl-1',
      to_table_id: 'tbl-2',
    });
    expect(result.success).toBe(true);
    expect(result.data?.fromTable.status).toBe('available');
    expect(result.data?.toTable.status).toBe('occupied');
  });

  it('should update table reservation', async () => {
    const result = await controller.updateTableReservation('tbl-1', {
      reserved_customer_name: 'David Beckham',
    });
    expect(result.success).toBe(true);
    expect(result.data?.status).toBe('reserved');
  });

  it('should restore table', async () => {
    const result = await controller.restoreTable('tbl-1');
    expect(result.success).toBe(true);
    expect(result.message).toContain('restored');
  });

  it('should delete table', async () => {
    const result = await controller.deleteTable('tbl-1');
    expect(result.success).toBe(true);
  });
});
