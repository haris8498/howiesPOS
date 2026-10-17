import { SyncPullService } from './sync-pull.service';
import { ChangeLogService } from './change-log.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SyncPullService', () => {
  let service: SyncPullService;
  let mockPrisma: any;
  let mockChangeLogService: any;

  beforeEach(() => {
    mockPrisma = {
      systemChangeLog: {
        findMany: jest.fn(),
      },
      storeSetting: { findMany: jest.fn().mockResolvedValue([{ id: 's1' }]) },
      rolePermission: { findMany: jest.fn().mockResolvedValue([{ id: 'r1' }]) },
      staffUser: { findMany: jest.fn().mockResolvedValue([{ id: 'u1', username: 'cashier1' }]) },
      menuCategory: { findMany: jest.fn().mockResolvedValue([{ id: 'c1', name: 'Pizzas' }]) },
      menuItem: { findMany: jest.fn().mockResolvedValue([{ id: 'm1', name: 'Cheese Pizza' }]) },
      menuItemSize: { findMany: jest.fn().mockResolvedValue([{ id: 'sz1' }]) },
      menuItemOption: { findMany: jest.fn().mockResolvedValue([{ id: 'opt1' }]) },
      deal: { findMany: jest.fn().mockResolvedValue([{ id: 'd1' }]) },
      floorZone: { findMany: jest.fn().mockResolvedValue([{ id: 'z1' }]) },
      restaurantTable: { findMany: jest.fn().mockResolvedValue([{ id: 't1' }]) },
      deliveryRider: { findMany: jest.fn().mockResolvedValue([{ id: 'dr1' }]) },
      dailyCalculation: { findFirst: jest.fn().mockResolvedValue({ id: 'shift-1', status: 'ACTIVE' }) },
      order: { findMany: jest.fn().mockResolvedValue([{ id: 'active-ord-1' }]) },
    };

    mockChangeLogService = {
      getMaxSequence: jest.fn().mockResolvedValue(BigInt(48215)),
    };

    service = new SyncPullService(
      mockPrisma as PrismaService,
      mockChangeLogService as ChangeLogService,
    );
  });

  describe('pullChanges paging (§8.1.2)', () => {
    it('should query global_sequence > cursor with paging and has_more flag', async () => {
      // Mock 3 results when limit is 2 (means has_more is true)
      mockPrisma.systemChangeLog.findMany.mockResolvedValue([
        {
          global_sequence: BigInt(101),
          entity_type: 'order',
          entity_id: 'ord-101',
          operation: 'INSERT',
          record_version: 1,
          is_deleted: false,
          payload: { order_number: 'P1-101' },
          created_at: new Date('2026-10-17T12:00:00Z'),
        },
        {
          global_sequence: BigInt(102),
          entity_type: 'order',
          entity_id: 'ord-102',
          operation: 'INSERT',
          record_version: 1,
          is_deleted: false,
          payload: { order_number: 'P1-102' },
          created_at: new Date('2026-10-17T12:01:00Z'),
        },
        {
          global_sequence: BigInt(103),
          entity_type: 'order',
          entity_id: 'ord-103',
          operation: 'INSERT',
          record_version: 1,
          is_deleted: false,
          payload: { order_number: 'P1-103' },
          created_at: new Date('2026-10-17T12:02:00Z'),
        },
      ]);

      const result = await service.pullChanges({
        cursor: '100',
        limit: 2,
        device_id: 'POS-P1',
      });

      expect(mockPrisma.systemChangeLog.findMany).toHaveBeenCalledWith({
        where: { global_sequence: { gt: BigInt(100) } },
        orderBy: { global_sequence: 'asc' },
        take: 3, // limit + 1
      });

      expect(result.success).toBe(true);
      expect(result.has_more).toBe(true);
      expect(result.cursor).toBe(102);
      expect(result.next_cursor).toBe(102);
      expect(result.changes).toHaveLength(2);
      expect(result.changes[0].sequence).toBe(101);
      expect(result.changes[1].sequence).toBe(102);
    });

    it('should return has_more=false when no more records remain', async () => {
      mockPrisma.systemChangeLog.findMany.mockResolvedValue([
        {
          global_sequence: BigInt(103),
          entity_type: 'order',
          entity_id: 'ord-103',
          operation: 'INSERT',
          record_version: 1,
          is_deleted: false,
          payload: { order_number: 'P1-103' },
          created_at: new Date('2026-10-17T12:02:00Z'),
        },
      ]);

      const result = await service.pullChanges({
        cursor: '102',
        limit: 2,
      });

      expect(result.has_more).toBe(false);
      expect(result.next_cursor).toBe(103);
      expect(result.changes).toHaveLength(1);
    });

    it('should return initial cursor when no changes found', async () => {
      mockPrisma.systemChangeLog.findMany.mockResolvedValue([]);

      const result = await service.pullChanges({
        cursor: '200',
        limit: 50,
      });

      expect(result.has_more).toBe(false);
      expect(result.next_cursor).toBe(200);
      expect(result.changes).toHaveLength(0);
    });
  });

  describe('getBootstrapData (§8.1.3)', () => {
    it('should return cold-start catalog snapshot with max_global_sequence', async () => {
      const bootstrap = await service.getBootstrapData();

      expect(bootstrap.max_global_sequence).toBe(48215);
      expect(bootstrap.server_timestamp).toBeDefined();
      expect(bootstrap.categories).toEqual([{ id: 'c1', name: 'Pizzas' }]);
      expect(bootstrap.menu_items).toEqual([{ id: 'm1', name: 'Cheese Pizza' }]);
      expect(bootstrap.active_shift).toEqual({ id: 'shift-1', status: 'ACTIVE' });
      expect(bootstrap.active_orders).toEqual([{ id: 'active-ord-1' }]);
      expect(bootstrap.store_settings).toBeDefined();
      expect(bootstrap.role_permissions).toBeDefined();
    });
  });
});
