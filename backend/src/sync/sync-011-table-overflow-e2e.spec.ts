import { SyncPushService } from './sync-push.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrderHandler } from './handlers/order.handler';
import { TableHandler } from './handlers/table.handler';
import { OrdersService } from '../orders/orders.service';
import { ChangeLogService } from './change-log.service';

describe('SYNC-011 / TBL-02: Concurrent Offline Seating & Virtual Overflow Tables End-to-End', () => {
  let pushService: SyncPushService;
  let orderHandler: OrderHandler;
  let tableHandler: TableHandler;
  let registry: HandlerRegistry;
  let changeLogService: ChangeLogService;
  let ordersService: OrdersService;

  // In-memory simulated PostgreSQL state
  let tablesDb: Map<string, any>;
  let ordersDb: Map<string, any>;
  let dineInDetailsDb: Map<string, any>;
  let orderItemsDb: Map<string, any>;
  let paymentsDb: Map<string, any>;
  let changeLogsDb: any[];

  let mockPrisma: any;

  beforeEach(() => {
    tablesDb = new Map();
    ordersDb = new Map();
    dineInDetailsDb = new Map();
    orderItemsDb = new Map();
    paymentsDb = new Map();
    changeLogsDb = [];

    // Base mock table: Table 4
    const table4 = {
      id: 'tbl-4-uuid',
      table_number: '4',
      name: 'Table 4',
      capacity: 4,
      section: 'Main Hall',
      zone_id: 'zone-1',
      status: 'available',
      current_customer_count: 0,
      current_bill_amount: 0,
      occupied_since: null,
      active_order_id: null,
      is_deleted: false,
      deleted_at: null,
      deleted_by: null,
      is_overflow: false,
      parent_table_id: null,
      overflow_suffix: null,
      version: 1,
      updated_at: new Date('2026-10-27T10:00:00Z'),
    };
    tablesDb.set(table4.id, { ...table4 });

    mockPrisma = {
      $transaction: jest.fn().mockImplementation(async (callback) => {
        return await callback(mockPrisma);
      }),
      $queryRaw: jest.fn().mockImplementation(async (strings: any, ...values: any[]) => {
        // Simulated SELECT ... FOR UPDATE on restaurant_tables
        const target = values[0];
        for (const tbl of tablesDb.values()) {
          if (tbl.id === target || tbl.table_number === target || tbl.name === target) {
            return [{ ...tbl }];
          }
        }
        return [];
      }),
      restaurantTable: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id) return Promise.resolve(tablesDb.get(where.id) || null);
          if (where.table_number) {
            for (const t of tablesDb.values()) {
              if (t.table_number === where.table_number && !t.is_deleted) return Promise.resolve(t);
            }
          }
          return Promise.resolve(null);
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const tbl of tablesDb.values()) {
            if (where.is_deleted !== undefined && tbl.is_deleted !== where.is_deleted) continue;
            if (where.parent_table_id && tbl.parent_table_id !== where.parent_table_id) continue;
            if (where.id && tbl.id === where.id) return Promise.resolve(tbl);
            if (where.table_number && tbl.table_number === where.table_number) return Promise.resolve(tbl);
            if (where.OR) {
              const matched = where.OR.some((c: any) => {
                if (c.id && tbl.id === c.id) return true;
                if (c.table_number && tbl.table_number === c.table_number) return true;
                if (c.name && tbl.name === c.name) return true;
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
            if (where?.is_deleted !== undefined && tbl.is_deleted !== where.is_deleted) continue;
            if (where?.parent_table_id !== undefined && tbl.parent_table_id !== where.parent_table_id) continue;
            res.push(tbl);
          }
          if (args?.orderBy?.table_number === 'asc') {
            res.sort((a, b) => a.table_number.localeCompare(b.table_number));
          }
          return Promise.resolve(res);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const row = {
            ...data,
            id: data.id || `tbl-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
            is_deleted: data.is_deleted ?? false,
            is_overflow: data.is_overflow ?? false,
            parent_table_id: data.parent_table_id ?? null,
            overflow_suffix: data.overflow_suffix ?? null,
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
      },
      order: {
        findUnique: jest.fn().mockImplementation(({ where, include }) => {
          const ord = ordersDb.get(where.id);
          if (!ord) return Promise.resolve(null);
          const detail = dineInDetailsDb.get(ord.id);
          const tbl = detail ? tablesDb.get(detail.table_id) : null;
          return Promise.resolve({
            ...ord,
            order_items: Array.from(orderItemsDb.values()).filter((i) => i.order_id === ord.id),
            payments: Array.from(paymentsDb.values()).filter((p) => p.order_id === ord.id),
            dine_in_detail: detail ? { ...detail, table: tbl } : null,
          });
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const ord of ordersDb.values()) {
            if (where.id && ord.id !== where.id) continue;
            if (where.is_paid !== undefined && ord.is_paid !== where.is_paid) continue;
            if (where.status?.notIn && where.status.notIn.includes(ord.status)) continue;
            const detail = dineInDetailsDb.get(ord.id);
            const tbl = detail ? tablesDb.get(detail.table_id) : null;
            return Promise.resolve({
              ...ord,
              dine_in_detail: detail ? { ...detail, table: tbl } : null,
            });
          }
          return Promise.resolve(null);
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
        update: jest.fn().mockImplementation(({ where, data }) => {
          const row = ordersDb.get(where.id);
          if (!row) throw new Error(`Order ${where.id} not found`);
          const updated = { ...row, ...data, updated_at: new Date() };
          ordersDb.set(where.id, updated);
          return Promise.resolve(updated);
        }),
      },
      dineInOrderDetail: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.order_id) {
            const detail = dineInDetailsDb.get(where.order_id);
            if (!detail) return Promise.resolve(null);
            const tbl = tablesDb.get(detail.table_id);
            return Promise.resolve({ ...detail, table: tbl });
          }
          return Promise.resolve(null);
        }),
        findFirst: jest.fn().mockImplementation(({ where }) => {
          for (const detail of dineInDetailsDb.values()) {
            if (where.table_id && detail.table_id !== where.table_id) continue;
            if (where.order_id?.not && detail.order_id === where.order_id.not) continue;
            const ord = ordersDb.get(detail.order_id);
            if (where.order?.is_paid !== undefined && ord?.is_paid !== where.order.is_paid) continue;
            if (where.order?.status?.notIn && where.order.status.notIn.includes(ord?.status)) continue;
            const tbl = tablesDb.get(detail.table_id);
            return Promise.resolve({ ...detail, order: ord, table: tbl });
          }
          return Promise.resolve(null);
        }),
        create: jest.fn().mockImplementation(({ data }) => {
          const row = { ...data, id: data.id || `detail-${Date.now()}` };
          dineInDetailsDb.set(data.order_id, row);
          return Promise.resolve(row);
        }),
        updateMany: jest.fn().mockImplementation(({ where, data }) => {
          let count = 0;
          for (const [orderId, detail] of dineInDetailsDb.entries()) {
            if (where.order_id && orderId === where.order_id) {
              dineInDetailsDb.set(orderId, { ...detail, ...data });
              count++;
            }
          }
          return Promise.resolve({ count });
        }),
      },
      orderItem: {
        createMany: jest.fn().mockImplementation(({ data }) => {
          for (const item of data) {
            orderItemsDb.set(item.id || `item-${Math.random()}`, item);
          }
          return Promise.resolve({ count: data.length });
        }),
      },
      orderPayment: {
        createMany: jest.fn().mockImplementation(({ data }) => {
          for (const p of data) {
            paymentsDb.set(p.id || `pay-${Math.random()}`, p);
          }
          return Promise.resolve({ count: data.length });
        }),
      },
      systemChangeLog: {
        create: jest.fn().mockImplementation(({ data }) => {
          changeLogsDb.push(data);
          return Promise.resolve(data);
        }),
        aggregate: jest.fn().mockResolvedValue({ _max: { sequence: BigInt(1) } }),
      },
      processedOperation: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({}),
      },
      device: {
        upsert: jest.fn().mockResolvedValue({}),
      },
    };

    ordersService = {
      createOrderInTx: jest.fn().mockImplementation(async (tx, dto, orderId) => {
        const orderRow = {
          id: orderId,
          order_number: dto.order_number,
          order_type: dto.order_type,
          status: dto.status || 'newOrder',
          subtotal: dto.subtotal || 1000,
          grand_total: dto.grand_total || 1000,
          is_paid: dto.is_paid || false,
          payment_status: dto.payment_status || 'UNPAID',
          created_at: dto.created_at ? new Date(dto.created_at) : (dto.seated_at ? new Date(dto.seated_at) : new Date()),
          updated_at: new Date(),
          version: 1,
        };
        await tx.order.create({ data: orderRow });

        if (dto.table_id) {
          await tx.dineInOrderDetail.create({
            data: {
              order_id: orderRow.id,
              table_id: dto.table_id,
              guest_count: dto.guest_count || 2,
              seated_at: dto.seated_at ? new Date(dto.seated_at) : orderRow.created_at,
            },
          });

          await tx.restaurantTable.update({
            where: { id: dto.table_id },
            data: {
              status: 'occupied',
              active_order_id: orderRow.id,
              current_bill_amount: orderRow.grand_total,
              occupied_since: orderRow.created_at,
            },
          });
        }

        return orderRow;
      }),
    } as any;

    changeLogService = {
      record: jest.fn().mockImplementation(async (tx, entityType, entityId, operation, version, snapshot) => {
        changeLogsDb.push({ entityType, entityId, operation, version, snapshot });
      }),
    } as any;

    registry = new HandlerRegistry();
    orderHandler = new OrderHandler(registry, ordersService, changeLogService);
    orderHandler.onModuleInit();

    tableHandler = new TableHandler(registry, changeLogService, undefined);
    tableHandler.onModuleInit();

    pushService = new SyncPushService(
      mockPrisma,
      registry,
      undefined,
      undefined,
    );
  });

  // ---------------------------------------------------------------------------
  // TEST 1: 2-Way Collision (Device 1 syncs first, then Device 2)
  // ---------------------------------------------------------------------------
  it('should reassign second claimant to virtual overflow Table 4-B when Device 1 syncs first', async () => {
    // Device 1 seated at 12:00:00Z
    const t1 = '2026-10-27T12:00:00.000Z';
    // Device 2 seated at 12:05:00Z (later)
    const t2 = '2026-10-27T12:05:00.000Z';

    const batch1 = {
      device_id: 'POS-01',
      batch_id: 'batch-p1-1',
      mutations: [
        {
          operation_id: 'op-order-1',
          entity_type: 'order',
          entity_id: 'ord-uuid-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: {
            id: 'ord-uuid-1',
            order_number: 'P1-101',
            table_id: 'tbl-4-uuid',
            order_type: 'dineIn',
            grand_total: 2500,
            seated_at: t1,
          },
        },
      ],
    };

    // 1. Device 1 syncs first
    const res1 = await pushService.pushMutations(batch1);
    expect(res1.success).toBe(true);
    expect(res1.results[0].status).toBe('SYNCED');

    // Table 4 is occupied by Order 1
    const tbl4After1 = tablesDb.get('tbl-4-uuid');
    expect(tbl4After1.status).toBe('occupied');
    expect(tbl4After1.active_order_id).toBe('ord-uuid-1');

    // 2. Device 2 syncs
    const batch2 = {
      device_id: 'POS-02',
      batch_id: 'batch-p2-1',
      mutations: [
        {
          operation_id: 'op-order-2',
          entity_type: 'order',
          entity_id: 'ord-uuid-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: {
            id: 'ord-uuid-2',
            order_number: 'P2-101',
            table_id: 'tbl-4-uuid', // Also claims Table 4!
            order_type: 'dineIn',
            grand_total: 3200,
            seated_at: t2,
          },
        },
      ],
    };

    const res2 = await pushService.pushMutations(batch2);
    expect(res2.success).toBe(true);

    // Order 2 status is APPLIED with reassignment
    const order2Result = res2.results[0];
    expect(order2Result.status).toBe('APPLIED');
    expect(order2Result.table_reassigned).toBeDefined();
    expect(order2Result.table_reassigned?.orderId).toBe('ord-uuid-2');
    expect(order2Result.table_reassigned?.fromTableId).toBe('tbl-4-uuid');
    expect(order2Result.table_reassigned?.toLabel).toBe('4-B');

    // Root tableReassigned in ACK envelope
    expect(res2.tableReassigned).toHaveLength(1);
    expect(res2.tableReassigned[0].toLabel).toBe('4-B');

    // Verify database state: both orders exist and are intact!
    expect(ordersDb.get('ord-uuid-1')).toBeDefined();
    expect(ordersDb.get('ord-uuid-2')).toBeDefined();

    // Table 4 remains with Order 1
    const tbl4Final = tablesDb.get('tbl-4-uuid');
    expect(tbl4Final.active_order_id).toBe('ord-uuid-1');

    // Table 4-B exists, is occupied with Order 2
    const overflowTable = Array.from(tablesDb.values()).find((t) => t.table_number === '4-B');
    expect(overflowTable).toBeDefined();
    expect(overflowTable.is_overflow).toBe(true);
    expect(overflowTable.parent_table_id).toBe('tbl-4-uuid');
    expect(overflowTable.overflow_suffix).toBe('B');
    expect(overflowTable.active_order_id).toBe('ord-uuid-2');

    // DineInDetail for Order 2 points to 4-B
    const detail2 = dineInDetailsDb.get('ord-uuid-2');
    expect(detail2.table_id).toBe(overflowTable.id);
  });

  // ---------------------------------------------------------------------------
  // TEST 2: Deterministic Winner with Reverse Sync Order (Device 2 syncs first, then Device 1)
  // ---------------------------------------------------------------------------
  it('should deterministically give Table 4 to earlier seated party even when later party syncs first', async () => {
    // Device 1 seated at 12:00:00Z (earlier)
    const t1 = '2026-10-27T12:00:00.000Z';
    // Device 2 seated at 12:05:00Z (later)
    const t2 = '2026-10-27T12:05:00.000Z';

    // 1. Device 2 syncs FIRST
    const batch2 = {
      device_id: 'POS-02',
      batch_id: 'batch-rev-p2',
      mutations: [
        {
          operation_id: 'op-rev-2',
          entity_type: 'order',
          entity_id: 'ord-uuid-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: {
            id: 'ord-uuid-2',
            order_number: 'P2-101',
            table_id: 'tbl-4-uuid',
            order_type: 'dineIn',
            grand_total: 3200,
            seated_at: t2,
          },
        },
      ],
    };

    const res2 = await pushService.pushMutations(batch2);
    expect(res2.success).toBe(true);
    expect(res2.results[0].status).toBe('SYNCED');
    expect(tablesDb.get('tbl-4-uuid').active_order_id).toBe('ord-uuid-2');

    // 2. Device 1 syncs SECOND (with earlier timestamp t1 < t2)
    const batch1 = {
      device_id: 'POS-01',
      batch_id: 'batch-rev-p1',
      mutations: [
        {
          operation_id: 'op-rev-1',
          entity_type: 'order',
          entity_id: 'ord-uuid-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: {
            id: 'ord-uuid-1',
            order_number: 'P1-101',
            table_id: 'tbl-4-uuid',
            order_type: 'dineIn',
            grand_total: 2500,
            seated_at: t1,
          },
        },
      ],
    };

    const res1 = await pushService.pushMutations(batch1);
    expect(res1.success).toBe(true);

    // Device 1's ACK reports that existing Order 2 was displaced to 4-B
    expect(res1.tableReassigned).toHaveLength(1);
    expect(res1.tableReassigned[0].orderId).toBe('ord-uuid-2');
    expect(res1.tableReassigned[0].toLabel).toBe('4-B');

    // FINAL OUTCOME IS IDENTICAL: Table 4 has Order 1; Table 4-B has Order 2!
    const tbl4Final = tablesDb.get('tbl-4-uuid');
    expect(tbl4Final.active_order_id).toBe('ord-uuid-1');

    const overflow4B = Array.from(tablesDb.values()).find((t) => t.table_number === '4-B');
    expect(overflow4B).toBeDefined();
    expect(overflow4B.active_order_id).toBe('ord-uuid-2');

    const detail2 = dineInDetailsDb.get('ord-uuid-2');
    expect(detail2.table_id).toBe(overflow4B.id);
  });

  // ---------------------------------------------------------------------------
  // TEST 3: 3-Way Collision -> Table 4, Table 4-B, Table 4-C
  // ---------------------------------------------------------------------------
  it('should create Table 4-B and Table 4-C upon 3 concurrent offline seatings', async () => {
    const t1 = '2026-10-27T12:00:00.000Z';
    const t2 = '2026-10-27T12:05:00.000Z';
    const t3 = '2026-10-27T12:10:00.000Z';

    // Sync Order 1
    await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'b-3way-1',
      mutations: [
        {
          operation_id: 'op-3w-1',
          entity_type: 'order',
          entity_id: 'ord-3w-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: { id: 'ord-3w-1', order_number: '101', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 1000, seated_at: t1 },
        },
      ],
    });

    // Sync Order 2 (second collision)
    const res2 = await pushService.pushMutations({
      device_id: 'POS-02',
      batch_id: 'b-3way-2',
      mutations: [
        {
          operation_id: 'op-3w-2',
          entity_type: 'order',
          entity_id: 'ord-3w-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: { id: 'ord-3w-2', order_number: '102', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 2000, seated_at: t2 },
        },
      ],
    });
    expect(res2.tableReassigned[0].toLabel).toBe('4-B');

    // Sync Order 3 (third collision)
    const res3 = await pushService.pushMutations({
      device_id: 'POS-03',
      batch_id: 'b-3way-3',
      mutations: [
        {
          operation_id: 'op-3w-3',
          entity_type: 'order',
          entity_id: 'ord-3w-3',
          operation_type: 'INSERT',
          created_at: t3,
          payload: { id: 'ord-3w-3', order_number: '103', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 3000, seated_at: t3 },
        },
      ],
    });
    expect(res3.tableReassigned[0].toLabel).toBe('4-C');

    // All three tables exist and hold their respective intact orders
    expect(tablesDb.get('tbl-4-uuid').active_order_id).toBe('ord-3w-1');

    const tbl4B = Array.from(tablesDb.values()).find((t) => t.table_number === '4-B');
    expect(tbl4B).toBeDefined();
    expect(tbl4B.active_order_id).toBe('ord-3w-2');

    const tbl4C = Array.from(tablesDb.values()).find((t) => t.table_number === '4-C');
    expect(tbl4C).toBeDefined();
    expect(tbl4C.active_order_id).toBe('ord-3w-3');
    expect(tbl4C.is_overflow).toBe(true);
    expect(tbl4C.parent_table_id).toBe('tbl-4-uuid');
    expect(tbl4C.overflow_suffix).toBe('C');
  });

  // ---------------------------------------------------------------------------
  // TEST 4: Idempotency & Replay (Never creates a second overflow table or reassigns twice)
  // ---------------------------------------------------------------------------
  it('should be strictly idempotent on replay without creating duplicate overflow tables', async () => {
    const t1 = '2026-10-27T12:00:00.000Z';
    const t2 = '2026-10-27T12:05:00.000Z';

    // Order 1 syncs
    await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'b-idemp-1',
      mutations: [
        {
          operation_id: 'op-idemp-1',
          entity_type: 'order',
          entity_id: 'ord-idemp-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: { id: 'ord-idemp-1', order_number: '101', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 1000, seated_at: t1 },
        },
      ],
    });

    const push2 = {
      device_id: 'POS-02',
      batch_id: 'b-idemp-2',
      mutations: [
        {
          operation_id: 'op-idemp-2',
          entity_type: 'order',
          entity_id: 'ord-idemp-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: { id: 'ord-idemp-2', order_number: '102', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 2000, seated_at: t2 },
        },
      ],
    };

    // First push of Order 2
    const firstRes = await pushService.pushMutations(push2);
    expect(firstRes.results[0].status).toBe('APPLIED');
    expect(firstRes.tableReassigned[0].toLabel).toBe('4-B');

    const tableCountBefore = tablesDb.size;

    // Replay of the exact same push
    const replayRes = await pushService.pushMutations(push2);
    expect(replayRes.results[0].status).toBe('DUPLICATE');
    expect(replayRes.tableReassigned).toBeDefined();
    expect(replayRes.tableReassigned[0].toLabel).toBe('4-B');

    // No new tables created in database
    expect(tablesDb.size).toBe(tableCountBefore);
  });

  // ---------------------------------------------------------------------------
  // TEST 5: Subsequent Table Status UPDATE mutation redirects to Table 4-B
  // ---------------------------------------------------------------------------
  it('should redirect subsequent Table 4 status update from loser device to Table 4-B without conflict', async () => {
    const t1 = '2026-10-27T12:00:00.000Z';
    const t2 = '2026-10-27T12:05:00.000Z';

    // 1. Order 1 claims Table 4
    await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'b-tblup-1',
      mutations: [
        {
          operation_id: 'op-ord-1',
          entity_type: 'order',
          entity_id: 'ord-tblup-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: { id: 'ord-tblup-1', order_number: '101', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 1000, seated_at: t1 },
        },
      ],
    });

    // 2. Order 2 claims Table 4 and gets reassigned to 4-B
    await pushService.pushMutations({
      device_id: 'POS-02',
      batch_id: 'b-tblup-2',
      mutations: [
        {
          operation_id: 'op-ord-2',
          entity_type: 'order',
          entity_id: 'ord-tblup-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: { id: 'ord-tblup-2', order_number: '102', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 2000, seated_at: t2 },
        },
      ],
    });

    // 3. Device 2 pushes its local table status update (which still references tbl-4-uuid and active_order_id: ord-tblup-2)
    const tableUpdateBatch = {
      device_id: 'POS-02',
      batch_id: 'b-tblup-3',
      mutations: [
        {
          operation_id: 'op-tbl-2',
          entity_type: 'table',
          entity_id: 'tbl-4-uuid',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: {
            id: 'tbl-4-uuid',
            status: 'occupied',
            active_order_id: 'ord-tblup-2',
            current_bill_amount: 2500,
          },
        },
      ],
    };

    const tableUpdateRes = await pushService.pushMutations(tableUpdateBatch);
    expect(tableUpdateRes.success).toBe(true);
    expect(tableUpdateRes.results[0].status).toBe('APPLIED');
    expect(tableUpdateRes.tableReassigned[0].toLabel).toBe('4-B');

    // Table 4 remains with Order 1
    expect(tablesDb.get('tbl-4-uuid').active_order_id).toBe('ord-tblup-1');

    // Table 4-B bill was updated
    const tbl4B = Array.from(tablesDb.values()).find((t) => t.table_number === '4-B');
    expect(tbl4B.active_order_id).toBe('ord-tblup-2');
  });

  // ---------------------------------------------------------------------------
  // TEST 6: Free Overflow Table Reuse (Reuses 4-B when previous order completed)
  // ---------------------------------------------------------------------------
  it('should reuse an existing free overflow table before creating suffix C', async () => {
    const t1 = '2026-10-27T12:00:00.000Z';
    const t2 = '2026-10-27T12:05:00.000Z';
    const t3 = '2026-10-27T13:00:00.000Z';

    // 1. Order 1 on Table 4
    await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'b-reuse-1',
      mutations: [
        {
          operation_id: 'op-r-1',
          entity_type: 'order',
          entity_id: 'ord-r-1',
          operation_type: 'INSERT',
          created_at: t1,
          payload: { id: 'ord-r-1', order_number: '101', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 1000, seated_at: t1 },
        },
      ],
    });

    // 2. Order 2 on 4-B
    await pushService.pushMutations({
      device_id: 'POS-02',
      batch_id: 'b-reuse-2',
      mutations: [
        {
          operation_id: 'op-r-2',
          entity_type: 'order',
          entity_id: 'ord-r-2',
          operation_type: 'INSERT',
          created_at: t2,
          payload: { id: 'ord-r-2', order_number: '102', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 2000, seated_at: t2 },
        },
      ],
    });

    const tbl4B = Array.from(tablesDb.values()).find((t) => t.table_number === '4-B');
    expect(tbl4B).toBeDefined();

    // 3. Order 2 completes and pays -> Table 4-B becomes available / free
    const ord2 = ordersDb.get('ord-r-2');
    ord2.is_paid = true;
    ord2.status = 'completed';
    tbl4B.status = 'available';
    tbl4B.active_order_id = null;

    // 4. A third party collides on Table 4 (at t3)
    const res3 = await pushService.pushMutations({
      device_id: 'POS-03',
      batch_id: 'b-reuse-3',
      mutations: [
        {
          operation_id: 'op-r-3',
          entity_type: 'order',
          entity_id: 'ord-r-3',
          operation_type: 'INSERT',
          created_at: t3,
          payload: { id: 'ord-r-3', order_number: '103', table_id: 'tbl-4-uuid', order_type: 'dineIn', grand_total: 3000, seated_at: t3 },
        },
      ],
    });

    // Should REUSE 4-B instead of generating 4-C!
    expect(res3.tableReassigned[0].toLabel).toBe('4-B');
    expect(tablesDb.get(tbl4B.id).active_order_id).toBe('ord-r-3');

    // No Table 4-C exists
    const tbl4C = Array.from(tablesDb.values()).find((t) => t.table_number === '4-C');
    expect(tbl4C).toBeUndefined();
  });
});
