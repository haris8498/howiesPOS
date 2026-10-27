import { ConflictException } from '@nestjs/common';
import { SyncPushService } from './sync-push.service';
import { SyncPullService } from './sync-pull.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrderHandler } from './handlers/order.handler';
import { TableHandler } from './handlers/table.handler';
import { TablesService } from '../tables/tables.service';
import { OrdersService } from '../orders/orders.service';
import { ChangeLogService } from './change-log.service';

describe('SYNC-012 / TBL-12: Soft-Delete Dining Tables End-to-End', () => {
  let pushService: SyncPushService;
  let pullService: SyncPullService;
  let tablesService: TablesService;
  let orderHandler: OrderHandler;
  let tableHandler: TableHandler;
  let registry: HandlerRegistry;
  let changeLogService: ChangeLogService;

  // In-memory simulated PostgreSQL state
  let tablesDb: Map<string, any>;
  let ordersDb: Map<string, any>;
  let dineInDetailsDb: Map<string, any>;
  let changeLogsDb: any[];
  let globalSequence: bigint;

  let mockPrisma: any;

  beforeEach(() => {
    tablesDb = new Map();
    ordersDb = new Map();
    dineInDetailsDb = new Map();
    changeLogsDb = [];
    globalSequence = BigInt(0);

    mockPrisma = {
      restaurantTable: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id) return Promise.resolve(tablesDb.get(where.id) || null);
          return Promise.resolve(null);
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const tbl of tablesDb.values()) {
            if (where.is_deleted !== undefined && tbl.is_deleted !== where.is_deleted) {
              continue;
            }
            if (where.id && typeof where.id === 'object' && where.id.not === tbl.id) {
              continue;
            }
            if (where.table_number && tbl.table_number.toLowerCase() === where.table_number.toLowerCase()) {
              return Promise.resolve(tbl);
            }
            if (where.name && tbl.name.toLowerCase() === where.name.toLowerCase()) {
              return Promise.resolve(tbl);
            }
            if (where.OR) {
              const matched = where.OR.some((c: any) => {
                if (c.id && tbl.id === c.id) return true;
                if (c.table_number) {
                  const val = typeof c.table_number === 'object' ? c.table_number.equals : c.table_number;
                  if (val && tbl.table_number.toLowerCase() === val.toLowerCase()) return true;
                }
                if (c.name) {
                  const val = typeof c.name === 'object' ? c.name.equals : c.name;
                  if (val && tbl.name.toLowerCase() === val.toLowerCase()) return true;
                }
                return false;
              });
              if (matched) return Promise.resolve(tbl);
            }
          }
          return Promise.resolve(null);
        }),
        findMany: jest.fn().mockImplementation((args: any = {}) => {
          const where = args?.where;
          const res = [];
          for (const tbl of tablesDb.values()) {
            if (where?.is_deleted !== undefined && tbl.is_deleted !== where.is_deleted) {
              continue;
            }
            res.push(tbl);
          }
          return Promise.resolve(res);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          // Check partial unique index: table_number unique among non-deleted
          for (const tbl of tablesDb.values()) {
            if (!tbl.is_deleted && tbl.table_number.toLowerCase() === data.table_number.toLowerCase()) {
              const err: any = new Error('Unique constraint failed on the fields: (table_number) WHERE is_deleted = false');
              err.code = 'P2002';
              err.meta = { target: ['restaurant_tables_table_number_active_key'] };
              throw err;
            }
          }
          const row = {
            ...data,
            id: data.id || `tbl-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
            is_deleted: data.is_deleted ?? false,
            deleted_at: data.deleted_at ?? null,
            deleted_by: data.deleted_by ?? null,
            version: data.version ?? 1,
            updated_at: new Date(),
          };
          tablesDb.set(row.id, row);
          return Promise.resolve(row);
        }),
        update: jest.fn().mockImplementation(({ where, data }) => {
          const row = tablesDb.get(where.id);
          if (!row) throw new Error(`Table ${where.id} not found`);
          const newVersion = data.version?.increment ? row.version + 1 : (data.version ?? row.version);
          const updated = {
            ...row,
            ...data,
            version: newVersion,
            updated_at: new Date(),
          };
          tablesDb.set(where.id, updated);
          return Promise.resolve(updated);
        }),
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          let count = 0;
          for (const [id, row] of tablesDb.entries()) {
            if (where.is_deleted !== undefined && row.is_deleted !== where.is_deleted) continue;
            tablesDb.set(id, { ...row, ...data, version: row.version + 1 });
            count++;
          }
          return Promise.resolve({ count });
        }),
      },
      order: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          return Promise.resolve(ordersDb.get(where.id) || null);
        }),
        findFirst: jest.fn().mockImplementation(() => Promise.resolve(null)),
        findMany: jest.fn().mockImplementation(({ where }: any = {}) => {
          const res = [];
          for (const ord of ordersDb.values()) {
            if (where?.status?.notIn && where.status.notIn.includes(ord.status)) continue;
            if (where?.is_paid !== undefined && ord.is_paid !== where.is_paid) continue;
            res.push(ord);
          }
          return Promise.resolve(res);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const row = {
            ...data,
            version: 1,
            created_at: data.created_at ? new Date(data.created_at) : new Date(),
            updated_at: new Date(),
          };
          ordersDb.set(row.id, row);
          return Promise.resolve(row);
        }),
      },
      dineInOrderDetail: {
        create: jest.fn().mockImplementation(({ data }) => {
          // Foreign key check: table must exist in tablesDb (even if is_deleted: true!)
          if (!tablesDb.has(data.table_id)) {
            const err: any = new Error(`Foreign key constraint failed on table_id: ${data.table_id}`);
            err.code = 'P2003';
            throw err;
          }
          const detail = { ...data, id: `dio-${Date.now()}` };
          dineInDetailsDb.set(detail.order_id, detail);
          return Promise.resolve(detail);
        }),
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockImplementation(({ where }) => {
          let count = 0;
          for (const d of dineInDetailsDb.values()) {
            if (d.table_id === where.table_id) count++;
          }
          return Promise.resolve(count);
        }),
      },
      orderItem: {
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      orderPayment: {
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      systemChangeLog: {
        create: jest.fn().mockImplementation(({ data }) => {
          globalSequence++;
          const entry = {
            id: `log-${globalSequence}`,
            global_sequence: globalSequence,
            ...data,
            created_at: new Date(),
          };
          changeLogsDb.push(entry);
          return Promise.resolve(entry);
        }),
        findMany: jest.fn().mockImplementation(({ where }) => {
          const minSeq = where?.global_sequence?.gt ? BigInt(where.global_sequence.gt) : BigInt(0);
          return Promise.resolve(
            changeLogsDb.filter((l) => l.global_sequence > minSeq),
          );
        }),
        findFirst: jest.fn().mockImplementation(() => {
          if (changeLogsDb.length === 0) return Promise.resolve(null);
          return Promise.resolve(changeLogsDb[changeLogsDb.length - 1]);
        }),
      },
      storeSetting: { findMany: jest.fn().mockResolvedValue([]) },
      rolePermission: { findMany: jest.fn().mockResolvedValue([]) },
      staffUser: { findMany: jest.fn().mockResolvedValue([]) },
      menuCategory: { findMany: jest.fn().mockResolvedValue([]) },
      menuItem: { findMany: jest.fn().mockResolvedValue([]) },
      menuItemSize: { findMany: jest.fn().mockResolvedValue([]) },
      menuItemOption: { findMany: jest.fn().mockResolvedValue([]) },
      deal: { findMany: jest.fn().mockResolvedValue([]) },
      floorZone: { findMany: jest.fn().mockResolvedValue([]) },
      deliveryRider: { findMany: jest.fn().mockResolvedValue([]) },
      dailyCalculation: { findFirst: jest.fn().mockResolvedValue(null) },
      device: { findUnique: jest.fn().mockResolvedValue(null) },
      processedOperation: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({}) },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return callback(mockPrisma);
      }),
    };

    changeLogService = new ChangeLogService(mockPrisma);
    tablesService = new TablesService(mockPrisma, undefined, changeLogService);

    const ordersService = {
      createOrderInTx: jest.fn().mockImplementation(async (tx, dto, orderId) => {
        // Resolve table
        let resolvedTableId = dto.table_id;
        let isTableDeleted = false;
        if (dto.table_id) {
          const tbl = await tx.restaurantTable.findFirst({
            where: {
              OR: [{ id: dto.table_id }, { table_number: dto.table_id }],
            },
          });
          if (tbl) {
            resolvedTableId = tbl.id;
            isTableDeleted = tbl.is_deleted === true;
          }
        }

        const created = await tx.order.create({
          data: {
            id: orderId,
            order_number: dto.order_number,
            client_order_number: dto.client_order_number || dto.order_number,
            order_type: dto.order_type,
            status: dto.status || 'newOrder',
            grand_total: dto.grand_total ?? 1000,
            is_paid: dto.is_paid ?? false,
          },
        });

        if (resolvedTableId) {
          await tx.dineInOrderDetail.create({
            data: {
              order_id: created.id,
              table_id: resolvedTableId,
              guest_count: dto.guest_count ?? 2,
            },
          });

          if (!isTableDeleted) {
            await tx.restaurantTable.update({
              where: { id: resolvedTableId },
              data: {
                status: 'occupied',
                current_bill_amount: 1000,
                active_order_id: created.id,
              },
            });
          }
        }

        return created;
      }),
    } as any;

    registry = new HandlerRegistry();
    orderHandler = new OrderHandler(registry, ordersService, changeLogService);
    orderHandler.onModuleInit();

    tableHandler = new TableHandler(registry, changeLogService);
    tableHandler.onModuleInit();

    pushService = new SyncPushService(mockPrisma, registry);
    pullService = new SyncPullService(mockPrisma, changeLogService);
  });

  describe('1. Partial Unique Index: Table Number Reuse After Soft Delete', () => {
    it('allows a deleted table number to be reused by a new table', async () => {
      // Create Table 5
      const table1 = await tablesService.createTable({
        table_number: 'T-05',
        name: 'Table 5',
        capacity: 4,
        section: 'Hall',
      });
      expect(table1.table_number).toBe('T-05');
      expect(table1.is_deleted).toBe(false);

      // Soft delete Table 5
      const delResult = await tablesService.deleteTable(table1.id, 'admin-1');
      expect(delResult.message).toContain('deleted successfully');
      expect(tablesDb.get(table1.id).is_deleted).toBe(true);
      expect(tablesDb.get(table1.id).deleted_by).toBe('admin-1');

      // Recreate Table 5 with the same number T-05
      const table2 = await tablesService.createTable({
        table_number: 'T-05',
        name: 'New Table 5',
        capacity: 6,
        section: 'Hall',
      });

      expect(table2.table_number).toBe('T-05');
      expect(table2.id).not.toBe(table1.id);
      expect(table2.is_deleted).toBe(false);

      // Verify that createTable rejects if another ACTIVE table has T-05
      await expect(
        tablesService.createTable({
          table_number: 'T-05',
          name: 'Another Table 5',
          capacity: 4,
          section: 'Hall',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('2. Delta Pull Propagation of Deletion Tombstones', () => {
    it('propagates is_deleted: true tombstone in delta pull feed', async () => {
      // Create and delete a table
      const tbl = await tablesService.createTable({
        table_number: 'T-12',
        name: 'Table 12',
        capacity: 4,
      });

      const del = await tablesService.deleteTable(tbl.id, 'owner');
      expect(del.table.is_deleted).toBe(true);

      // Pull delta changes from cursor 0
      const pullResult = await pullService.pullChanges({ cursor: '0' });
      expect(pullResult.success).toBe(true);
      expect(pullResult.changes.length).toBeGreaterThan(0);

      const tombstone = pullResult.changes.find(
        (c) => c.entity_type === 'restaurant_table' && c.entity_id === tbl.id && c.operation === 'DELETE',
      );

      expect(tombstone).toBeDefined();
      expect(tombstone?.is_deleted).toBe(true);
      expect((tombstone?.data as any)?.is_deleted).toBe(true);
      expect((tombstone?.data as any)?.table_number).toBe('T-12');
    });

    it('excludes soft-deleted tables from cold bootstrap catalog snapshot', async () => {
      await tablesService.createTable({ table_number: 'T-20', name: 'Table 20', capacity: 2 });
      const delTbl = await tablesService.createTable({ table_number: 'T-21', name: 'Table 21', capacity: 2 });
      await tablesService.deleteTable(delTbl.id);

      const bootstrap = await pullService.getBootstrapData();
      const activeTableNumbers = bootstrap.tables.map((t: any) => t.table_number);
      expect(activeTableNumbers).toContain('T-20');
      expect(activeTableNumbers).not.toContain('T-21');
    });
  });

  describe('3. Delete -> Offline Order Push -> Non-Fatal TABLE_DELETED Warning ACK', () => {
    it('accepts offline order referencing soft-deleted table, preserves original tableId, and returns TABLE_DELETED warning', async () => {
      // Step A: Table is created
      const table = await tablesService.createTable({
        table_number: 'T-07',
        name: 'Table 7',
        capacity: 4,
      });
      const originalTableId = table.id;

      // Step B: Offline cashier takes an order for Table 7 (client local mutation generated)
      const offlineOrderId = 'ord-offline-999';
      const orderMutation = {
        operation_id: 'op-order-push-1',
        entity_type: 'order',
        entity_id: offlineOrderId,
        operation_type: 'INSERT',
        base_version: 1,
        payload: {
          id: offlineOrderId,
          order_number: '107',
          order_type: 'dineIn',
          table_id: originalTableId,
          guest_count: 2,
          grand_total: 2500,
          items: [{ item_name: 'Super Pizza', quantity: 2, unit_price: 1250, total_price: 2500 }],
        },
      };

      // Step C: Meanwhile, an admin deletes Table 7 in the web portal
      const deleteResponse = await tablesService.deleteTable(originalTableId, 'admin');
      expect(deleteResponse.message).toContain('deleted successfully');
      expect(tablesDb.get(originalTableId).is_deleted).toBe(true);

      // Step D: POS terminal reconnects and pushes the offline order
      const pushResponse = await pushService.pushMutations({
        device_id: 'POS-TERMINAL-01',
        batch_id: 'batch-recovery-01',
        mutations: [orderMutation as any],
      });

      expect(pushResponse.success).toBe(true);
      expect(pushResponse.results.length).toBe(1);

      const ack = pushResponse.results[0];
      // Acceptance criterion: Accepted, never rejected
      expect(ack.status).toBe('SYNCED');
      expect(ack.entity_id).toBe(offlineOrderId);

      // Acceptance criterion: Surfaced TABLE_DELETED non-fatal warning code
      expect(ack.warning_code).toBe('TABLE_DELETED');
      expect(ack.warnings).toContain('TABLE_DELETED');

      // Acceptance criterion: Persisted order with original tableId
      const savedDineInDetail = dineInDetailsDb.get(offlineOrderId);
      expect(savedDineInDetail).toBeDefined();
      expect(savedDineInDetail.table_id).toBe(originalTableId);

      // Acceptance criterion: Table remains soft-deleted in database
      const dbTable = tablesDb.get(originalTableId);
      expect(dbTable.is_deleted).toBe(true);
    });
  });

  describe('4. Admin Delete Warning with Open Orders and Table Restore', () => {
    it('returns open orders in delete response when deleting table that has open orders', async () => {
      const table = await tablesService.createTable({
        table_number: 'T-30',
        name: 'Table 30',
        capacity: 4,
      });

      // Place open order on table
      const order = {
        id: 'ord-open-1',
        order_number: '301',
        table_id: table.id,
        status: 'inProgress',
        is_paid: false,
        grand_total: 1800,
        created_at: new Date(),
      };
      ordersDb.set(order.id, order);
      dineInDetailsDb.set(order.id, { order_id: order.id, table_id: table.id });

      // Admin deletes table with open order: UI warning returned, not blocked
      const result = await tablesService.deleteTable(table.id);
      expect(result.message).toContain('deleted successfully');
      expect(result.has_open_orders).toBe(true);
      expect(result.open_orders.length).toBe(1);
      expect(result.open_orders[0].id).toBe('ord-open-1');
    });

    it('restores soft-deleted table and rejects restore if number is active elsewhere', async () => {
      const table = await tablesService.createTable({
        table_number: 'T-40',
        name: 'Table 40',
        capacity: 4,
      });

      await tablesService.deleteTable(table.id);
      expect(tablesDb.get(table.id).is_deleted).toBe(true);

      // Restore table
      const restoreResult = await tablesService.restoreTable(table.id);
      expect(restoreResult.message).toContain('restored successfully');
      expect(restoreResult.table.is_deleted).toBe(false);
      expect(tablesDb.get(table.id).is_deleted).toBe(false);

      // Delete again, create another active table with T-40, then restore should fail with conflict
      await tablesService.deleteTable(table.id);
      await tablesService.createTable({ table_number: 'T-40', name: 'New 40', capacity: 2 });

      await expect(tablesService.restoreTable(table.id)).rejects.toThrow(ConflictException);
    });
  });
});
