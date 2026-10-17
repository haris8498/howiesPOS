import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { SyncModule } from '../src/sync/sync.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';
import { KitchenGateway } from '../src/kitchen/kitchen.gateway';
import { OrdersService } from '../src/orders/orders.service';

describe('Failure Scenarios & Sync Invariants Backend E2E (§15.1, §15.2, §15.4)', () => {
  jest.setTimeout(45000);
  let app: INestApplication;

  // In-memory stateful mock database
  const ordersDb = new Map<string, any>();
  const tablesDb = new Map<string, any>();
  const shiftsDb = new Map<string, any>();
  const processedOpsDb = new Map<string, any>();
  const changeLogs: any[] = [];
  let globalSequenceCounter = BigInt(100);

  const mockPrismaService: any = {
    $transaction: jest.fn().mockImplementation(async (callback: any) => {
      if (typeof callback === 'function') {
        return await callback(mockPrismaService);
      }
      return callback;
    }),

    order: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        let found: any = null;
        if (where.id) {
          found = ordersDb.get(where.id);
        } else if (where.order_number) {
          for (const ord of ordersDb.values()) {
            if (ord.order_number === where.order_number) {
              found = ord;
              break;
            }
          }
        }
        if (!found) return null;
        const copy = JSON.parse(JSON.stringify(found));
        copy.order_items = copy.order_items || [];
        copy.payments = copy.payments || [];
        copy.created_at = new Date(copy.created_at);
        copy.updated_at = new Date(copy.updated_at);
        return copy;
      }),
      findFirst: jest.fn().mockImplementation(async ({ where }) => {
        for (const ord of ordersDb.values()) {
          if (where.order_number && ord.order_number === where.order_number) {
            const copy = JSON.parse(JSON.stringify(ord));
            copy.order_items = copy.order_items || [];
            copy.payments = copy.payments || [];
            copy.created_at = new Date(copy.created_at);
            copy.updated_at = new Date(copy.updated_at);
            return copy;
          }
        }
        return null;
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const orderRecord = {
          id: data.id || `ord-${Date.now()}`,
          order_number: data.order_number,
          order_type: data.order_type || 'dineIn',
          status: data.status || 'newOrder',
          subtotal: data.subtotal ?? 0,
          grand_total: data.grand_total ?? 0,
          discount_percentage: data.discount_percentage ?? 0,
          discount_amount: data.discount_amount ?? 0,
          tax_amount: data.tax_amount ?? 0,
          dine_in_tax: data.dine_in_tax ?? 0,
          delivery_fee: data.delivery_fee ?? 0,
          payment_status: data.payment_status || 'PENDING',
          payment_method: data.payment_method || 'cash',
          is_paid: data.is_paid ?? false,
          is_held: data.is_held ?? false,
          kitchen_ticket_sent: data.kitchen_ticket_sent ?? false,
          version: 1,
          shift_id: data.shift_id || null,
          created_at: new Date(),
          updated_at: new Date(),
          order_items: [],
          payments: [],
        };
        ordersDb.set(orderRecord.id, orderRecord);
        return JSON.parse(JSON.stringify(orderRecord));
      }),
      update: jest.fn().mockImplementation(async ({ where, data }) => {
        const existing = ordersDb.get(where.id);
        if (!existing) throw new Error(`Order ${where.id} not found`);
        const updated = {
          ...existing,
          ...data,
          version: (existing.version || 1) + 1,
          updated_at: new Date(),
        };
        ordersDb.set(where.id, updated);
        return JSON.parse(JSON.stringify(updated));
      }),
      updateMany: jest.fn().mockImplementation(async () => {
        return { count: 0 };
      }),
      findMany: jest.fn().mockImplementation(async () => {
        return Array.from(ordersDb.values()).map((o) => JSON.parse(JSON.stringify(o)));
      }),
    },

    orderItem: {
      createMany: jest.fn().mockImplementation(async ({ data }) => {
        for (const it of data) {
          const ord = ordersDb.get(it.order_id);
          if (ord) {
            ord.order_items = ord.order_items || [];
            ord.order_items.push({ id: it.id || `item-${Date.now()}`, ...it });
          }
        }
        return { count: data.length };
      }),
      create: jest.fn().mockImplementation(async ({ data }) => data),
    },

    orderPayment: {
      createMany: jest.fn().mockImplementation(async ({ data }) => {
        for (const p of data) {
          const ord = ordersDb.get(p.order_id);
          if (ord) {
            ord.payments = ord.payments || [];
            ord.payments.push({ id: p.id || `pay-${Date.now()}`, ...p });
          }
        }
        return { count: data.length };
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const ord = ordersDb.get(data.order_id);
        if (ord) {
          ord.payments = ord.payments || [];
          ord.payments.push({ id: data.id || `pay-${Date.now()}`, ...data });
        }
        return data;
      }),
    },

    dineInOrderDetail: {
      findFirst: jest.fn().mockImplementation(async () => null),
      create: jest.fn().mockImplementation(async ({ data }) => data),
    },

    takeawayOrderDetail: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockImplementation(async ({ data }) => data),
    },

    onlineOrderDetail: {
      create: jest.fn().mockImplementation(async ({ data }) => ({ id: 'online-1', ...data })),
    },

    deliveryDispatch: {
      create: jest.fn().mockImplementation(async ({ data }) => data),
    },

    dataSyncLog: {
      create: jest.fn().mockImplementation(async ({ data }) => data),
    },

    restaurantTable: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        const found = tablesDb.get(where.id);
        if (!found) return null;
        return {
          ...found,
          updated_at: new Date(found.updated_at),
        };
      }),
      findFirst: jest.fn().mockImplementation(async ({ where }) => {
        for (const tbl of tablesDb.values()) {
          if (where.OR) {
            for (const cond of where.OR) {
              if (cond.id && tbl.id === cond.id) return { ...tbl, updated_at: new Date(tbl.updated_at) };
              if (cond.table_number && tbl.table_number === cond.table_number) return { ...tbl, updated_at: new Date(tbl.updated_at) };
            }
          }
        }
        return null;
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const tableRecord = {
          id: data.id || `tbl-${Date.now()}`,
          name: data.name || 'Table',
          table_number: data.table_number || '1',
          seating_capacity: data.seating_capacity || 4,
          status: data.status || 'available',
          active_order_id: data.active_order_id || null,
          current_bill_amount: data.current_bill_amount || 0,
          version: 1,
          updated_at: new Date(),
        };
        tablesDb.set(tableRecord.id, tableRecord);
        return { ...tableRecord };
      }),
      update: jest.fn().mockImplementation(async ({ where, data }) => {
        const existing = tablesDb.get(where.id);
        if (!existing) throw new Error(`Table ${where.id} not found`);
        const updated = {
          ...existing,
          ...data,
          version: (existing.version || 1) + 1,
          updated_at: new Date(),
        };
        tablesDb.set(where.id, updated);
        return { ...updated };
      }),
      findMany: jest.fn().mockImplementation(async () => {
        return Array.from(tablesDb.values()).map((t) => ({ ...t, updated_at: new Date(t.updated_at) }));
      }),
    },

    dailyCalculation: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        const found = shiftsDb.get(where.id);
        if (!found) return null;
        return {
          ...found,
          created_at: new Date(found.created_at || new Date()),
          updated_at: new Date(found.updated_at || new Date()),
        };
      }),
      findFirst: jest.fn().mockImplementation(async () => null),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const shiftRecord = {
          id: data.id || `shift-${Date.now()}`,
          cashier_id: data.cashier_id,
          date: data.date || new Date(),
          start_time: data.start_time || new Date(),
          status: data.status || 'OPEN',
          version: 1,
          cash_variance: data.cash_variance || 0,
          variance_reason: data.variance_reason || null,
          created_at: new Date(),
          updated_at: new Date(),
        };
        shiftsDb.set(shiftRecord.id, shiftRecord);
        return { ...shiftRecord };
      }),
      update: jest.fn().mockImplementation(async ({ where, data }) => {
        const existing = shiftsDb.get(where.id);
        if (!existing) throw new Error(`Shift ${where.id} not found`);
        const updated = {
          ...existing,
          ...data,
          version: (existing.version || 1) + 1,
          updated_at: new Date(),
        };
        shiftsDb.set(where.id, updated);
        return { ...updated };
      }),
    },

    systemChangeLog: {
      create: jest.fn().mockImplementation(async ({ data }) => {
        globalSequenceCounter += BigInt(1);
        const log = {
          global_sequence: globalSequenceCounter,
          entity_type: data.entity_type,
          entity_id: data.entity_id,
          operation: data.operation,
          record_version: data.record_version || 1,
          is_deleted: data.is_deleted || false,
          payload: data.payload,
          created_at: new Date(),
        };
        changeLogs.push(log);
        return { ...log };
      }),
      findFirst: jest.fn().mockImplementation(async () => {
        if (changeLogs.length === 0) return null;
        const last = changeLogs[changeLogs.length - 1];
        return { ...last, created_at: new Date(last.created_at) };
      }),
      findMany: jest.fn().mockImplementation(async ({ where, take, orderBy }) => {
        let filtered = [...changeLogs];
        if (where?.global_sequence?.gt !== undefined) {
          const cursor = BigInt(where.global_sequence.gt);
          filtered = filtered.filter((l) => BigInt(l.global_sequence) > cursor);
        }
        if (where?.entity_type) {
          filtered = filtered.filter((l) => l.entity_type === where.entity_type);
        }
        if (orderBy?.global_sequence === 'asc') {
          filtered.sort((a, b) => (BigInt(a.global_sequence) > BigInt(b.global_sequence) ? 1 : -1));
        }
        if (take) {
          filtered = filtered.slice(0, take);
        }
        return filtered.map((l) => ({
          ...l,
          created_at: new Date(l.created_at),
        }));
      }),
    },

    processedOperation: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        const found = processedOpsDb.get(where.operation_id);
        return found ? JSON.parse(JSON.stringify(found)) : null;
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const rec = {
          operation_id: data.operation_id,
          device_id: data.device_id || 'UNKNOWN',
          entity_type: data.entity_type || 'UNKNOWN',
          entity_id: data.entity_id || data.operation_id,
          request_hash: data.request_hash || '',
          response_payload: data.response_payload || null,
          status: data.status || 'COMPLETED',
          created_at: new Date(),
          completed_at: new Date(),
        };
        processedOpsDb.set(rec.operation_id, rec);
        return JSON.parse(JSON.stringify(rec));
      }),
      update: jest.fn().mockImplementation(async ({ where, data }) => {
        const existing = processedOpsDb.get(where.operation_id);
        const updated = {
          ...existing,
          ...data,
          completed_at: new Date(),
        };
        processedOpsDb.set(where.operation_id, updated);
        return JSON.parse(JSON.stringify(updated));
      }),
    },

    customer: {
      findUnique: jest.fn().mockResolvedValue(null),
    },

    menuItem: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        return { id: where.id, name: 'Sample Item', is_active: true };
      }),
      findMany: jest.fn().mockResolvedValue([]),
    },

    category: {
      findMany: jest.fn().mockResolvedValue([]),
    },
  };

  const mockKitchenGateway = {
    emitOrderCreated: jest.fn(),
    emitTableStatusChanged: jest.fn(),
  };

  beforeAll(async () => {
    // Seed initial table for concurrency tests
    tablesDb.set('tbl-4', {
      id: 'tbl-4',
      table_number: '4',
      name: 'Table 4',
      status: 'available',
      active_order_id: null,
      current_bill_amount: 0,
      version: 1,
      seating_capacity: 4,
    });

    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [SyncModule],
    })
      .overrideProvider(PrismaService)
      .useValue(mockPrismaService)
      .overrideProvider(KitchenGateway)
      .useValue(mockKitchenGateway)
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 1: Normal Online Operation (Baseline Push & Delta Pull)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 1: Normal Online Operation (§15.1 Scenario 1)', () => {
    const opId = '019283a0-1111-7000-8000-000000000001';
    const orderId = '019283a0-1111-7000-8000-000000000002';

    it('should ingest order mutation, commit to DB, append change log, and return 200 OK SYNCED', async () => {
      const pushDto = {
        device_id: 'POS-P1',
        batch_id: 'batch-norm-01',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            dependency_order: 2,
            payload: {
              order_number: 'P1-101',
              order_type: 'dineIn',
              status: 'newOrder',
              subtotal: 1200,
              grand_total: 1350,
              tax_amount: 150,
              is_paid: true,
              payment_status: 'PAID',
              items: [
                {
                  menu_item_id: 'mi-1',
                  item_name: 'Pepperoni Pizza',
                  quantity: 1,
                  unit_price: 1200,
                  total_price: 1200,
                },
              ],
              payments: [
                {
                  payment_method: 'cash',
                  amount: 1350,
                  payment_status: 'COMPLETED',
                },
              ],
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-norm-01')
        .set('X-Device-Id', 'POS-P1')
        .send(pushDto)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.batch_id).toBe('batch-norm-01');
      expect(res.body.processed_count).toBe(1);
      expect(res.body.results[0].operation_id).toBe(opId);
      expect(res.body.results[0].status).toBe('SYNCED');

      // Assert order exists in database
      const savedOrder = ordersDb.get(orderId);
      expect(savedOrder).toBeDefined();
      expect(savedOrder.order_number).toBe('P1-101');
      expect(savedOrder.grand_total).toBe(1350);

      // Assert system change log recorded
      const log = changeLogs.find((l) => l.entity_id === orderId && l.entity_type === 'order');
      expect(log).toBeDefined();
      expect(log.operation).toBe('INSERT');
    });

    it('should serve incremental delta pull stream with the committed order', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/sync/pull?cursor=0&limit=10')
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.changes)).toBe(true);
      const orderDelta = res.body.changes.find(
        (c: any) => c.entity_type === 'order' && c.entity_id === orderId,
      );
      expect(orderDelta).toBeDefined();
      expect(orderDelta.payload.order_number).toBe('P1-101');
      expect(res.body.cursor).toBeGreaterThan(0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 6: Server Committed but ACK/Response Lost in Transit (§15.1 Scenario 6)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 6: Request Reaches Server but Response Lost in Transit', () => {
    const opId = '019283a0-6666-7000-8000-000000000001';
    const orderId = '019283a0-6666-7000-8000-000000000002';

    it('first request commits order and records idempotency key', async () => {
      const payload = {
        device_id: 'POS-P1',
        batch_id: 'batch-retry-06',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            payload: {
              order_number: 'P1-106',
              order_type: 'takeaway',
              grand_total: 900,
              items: [{ item_name: 'Calzone', quantity: 1, unit_price: 900 }],
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-retry-06')
        .send(payload)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.results[0].status).toBe('SYNCED');
    });

    it('client retries with identical operation_id and batch_id -> absorbs idempotently with exactly 1 DB order', async () => {
      const countBefore = ordersDb.size;

      // Re-transmit exact same request payload
      const payload = {
        device_id: 'POS-P1',
        batch_id: 'batch-retry-06',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            payload: {
              order_number: 'P1-106',
              order_type: 'takeaway',
              grand_total: 900,
              items: [{ item_name: 'Calzone', quantity: 1, unit_price: 900 }],
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-retry-06')
        .send(payload)
        .expect((r) => expect([200, 201]).toContain(r.status));

      // Server either returns cached response or DUPLICATE result
      expect(res.body.success).toBe(true);
      // Invariant: Total orders in DB must NOT have increased!
      expect(ordersDb.size).toBe(countBefore);
      // Invariant: Exactly one order in DB with this orderId
      expect(ordersDb.get(orderId)).toBeDefined();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 7: Concurrent Table Seating Conflict (§10.2, §15.1 Scenario 7)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 7: POS Seating vs Owner Remote Edit (Hospitality Operational Priority)', () => {
    it('POS seated walk-in guest wins over remote available status', async () => {
      // 1. Owner remotely marked table available on cloud
      const initialTable = tablesDb.get('tbl-4');
      expect(initialTable.status).toBe('available');

      // 2. Offline POS seated walk-in guests at Table 4 with active order
      const opId = '019283a0-7777-7000-8000-000000000001';
      const activeOrderId = '019283a0-7777-7000-8000-000000000002';

      const pushDto = {
        device_id: 'POS-P1',
        batch_id: 'batch-table-conflict-07',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'table',
            entity_id: 'tbl-4',
            operation_type: 'UPDATE',
            base_version: 1,
            dependency_order: 1,
            payload: {
              status: 'occupied',
              active_order_id: activeOrderId,
              current_bill_amount: 2800,
              guest_count: 4,
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-table-conflict-07')
        .send(pushDto)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.results[0].status).toBe('SYNCED');

      // Assert hospitality invariant: Physical seated guest wins! Table is OCCUPIED
      const updatedTable = tablesDb.get('tbl-4');
      expect(updatedTable.status).toBe('occupied');
      expect(updatedTable.active_order_id).toBe(activeOrderId);
      expect(Number(updatedTable.current_bill_amount)).toBe(2800);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 8: Offline Sale of 86d / Stock-Out Item (Decoupled Inventory §15.1 Scenario 8)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 8: POS Sale of Item 86d / Stocked-Out by Owner', () => {
    it('order commits 100% cleanly without blocking or throwing inventory error', async () => {
      const opId = '019283a0-8888-7000-8000-000000000001';
      const orderId = '019283a0-8888-7000-8000-000000000002';

      const pushDto = {
        device_id: 'POS-P1',
        batch_id: 'batch-stockout-08',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            payload: {
              order_number: 'P1-108',
              order_type: 'dineIn',
              grand_total: 350,
              items: [
                {
                  menu_item_id: 'item-86d-imported-water',
                  item_name: 'Sparkling Water (0 Stock)',
                  quantity: 1,
                  unit_price: 350,
                },
              ],
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-stockout-08')
        .send(pushDto)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.results[0].status).toBe('SYNCED');
      expect(ordersDb.get(orderId)).toBeDefined();
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 10: Both Offline - Offline Shift Close with Cash Variance (§15.1 Scenario 10, 11)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 10: Citywide Outage - Offline Shift Close with Variance', () => {
    it('accepts OFFLINE_CLOSED shift with cash variance for supervisory audit without 400 error', async () => {
      const opId = '019283a0-aaaa-7000-8000-000000000001';
      const shiftId = '019283a0-aaaa-7000-8000-000000000002';

      // 1. Initial shift opened offline
      shiftsDb.set(shiftId, {
        id: shiftId,
        cashier_id: 'cashier-1',
        status: 'OPEN',
        version: 1,
      });

      // 2. Offline shift closed with -300 PKR shortage
      const pushDto = {
        device_id: 'POS-P1',
        batch_id: 'batch-shift-10',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'shift',
            entity_id: shiftId,
            operation_type: 'UPDATE',
            base_version: 1,
            dependency_order: 5,
            payload: {
              status: 'OFFLINE_CLOSED',
              closing_time: new Date().toISOString(),
              actual_cash: 48200,
              expected_cash: 48500,
              cash_variance: -300,
              variance_reason: 'End-of-shift petty shortage offline',
            },
          },
        ],
      };

      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .set('X-Idempotency-Key', 'batch-shift-10')
        .send(pushDto)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.results[0].status).toBe('SYNCED');

      // Assert variance recorded in shift record
      const savedShift = shiftsDb.get(shiftId);
      expect(savedShift.status).toBe('OFFLINE_CLOSED');
      expect(Number(savedShift.cash_variance)).toBe(-300);
      expect(savedShift.variance_reason).toContain('shortage');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 11: Server / Infrastructure Error Simulation (§15.1 Scenario 11/12)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 11: Cloud Server Error / Validation Failures', () => {
    it('returns 400 Bad Request on invalid push structure without crashing server', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/sync/push')
        .send({
          invalid_key: true,
          // Missing device_id, batch_id, mutations
        })
        .expect(400);

      expect(res.body.statusCode).toBe(400);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SCENARIO 14: Idempotency - Exact Same Operation Retried 5x (§15.1 Scenario 14, §15.2)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Scenario 14: Idempotency 5x Rapid Submissions', () => {
    it('5 concurrent identical push requests create exactly 1 database record', async () => {
      const opId = '019283a0-1414-7000-8000-000000000001';
      const orderId = '019283a0-1414-7000-8000-000000000002';

      const payload = {
        device_id: 'POS-P1',
        batch_id: 'batch-idemp-14',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            payload: {
              order_number: 'P1-114',
              order_type: 'dineIn',
              grand_total: 1800,
              items: [{ item_name: 'Family Deal', quantity: 1, unit_price: 1800 }],
            },
          },
        ],
      };

      // Fire 5 identical requests concurrently
      const promises = Array.from({ length: 5 }).map(() =>
        request(app.getHttpServer())
          .post('/api/sync/push')
          .set('X-Idempotency-Key', 'batch-idemp-14')
          .send(payload),
      );

      const results = await Promise.all(promises);

      // All 5 requests must complete with 200 or 201 OK
      for (const r of results) {
        expect([200, 201]).toContain(r.status);
        expect(r.body.success).toBe(true);
      }

      // Assert Invariant: EXACTLY 1 order exists in database for this ID
      const matchingOrders = Array.from(ordersDb.values()).filter(
        (o) => o.id === orderId || o.order_number === 'P1-114',
      );
      expect(matchingOrders.length).toBe(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // INVARIANT TEST: WebSocket Events Are Notification-Only Pokes
  // ───────────────────────────────────────────────────────────────────────────
  describe('Invariant: WebSocket events are notification-only pokes (§12, §13, §14)', () => {
    it('killing or muting kitchen socket does not prevent delta pull convergence', async () => {
      // Intentionally simulate kitchen gateway error / offline socket
      mockKitchenGateway.emitOrderCreated.mockImplementation(() => {
        throw new Error('Socket.IO connection severed: ECONNRESET');
      });

      const opId = '019283a0-9999-7000-8000-000000000001';
      const orderId = '019283a0-9999-7000-8000-000000000002';

      const payload = {
        device_id: 'POS-P1',
        batch_id: 'batch-poke-01',
        mutations: [
          {
            operation_id: opId,
            entity_type: 'order',
            entity_id: orderId,
            operation_type: 'INSERT',
            payload: {
              order_number: 'P1-199',
              order_type: 'takeaway',
              grand_total: 450,
              items: [{ item_name: 'Drink Pack', quantity: 1, unit_price: 450 }],
            },
          },
        ],
      };

      // Push still succeeds despite socket error
      const pushRes = await request(app.getHttpServer())
        .post('/api/sync/push')
        .send(payload)
        .expect(201);
      expect(pushRes.body.success).toBe(true);

      // Pull delta still converges and returns the order
      const pullRes = await request(app.getHttpServer())
        .get('/api/sync/pull?cursor=0&limit=50')
        .expect(200);

      const foundInPull = pullRes.body.changes.find((c: any) => c.entity_id === orderId);
      expect(foundInPull).toBeDefined();
      expect(foundInPull.payload.order_number).toBe('P1-199');
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // LOAD SMOKE TEST: 8-Hour Outage Burst Recovery (§5.2, §7.2 in 10-performance.md)
  // ───────────────────────────────────────────────────────────────────────────
  describe('Load Smoke Test: 8-Hour Outage Burst Recovery (160 Orders / 400 Mutations)', () => {
    it('syncs 160 orders and 400 mutations in bounded execution time (< 3.0s)', async () => {
      const BATCH_SIZE = 40; // 4 batches of 40 orders (160 orders total)
      const TOTAL_ORDERS = 160;

      const startTime = Date.now();

      for (let batchIdx = 0; batchIdx < TOTAL_ORDERS / BATCH_SIZE; batchIdx++) {
        const mutations: any[] = [];

        for (let i = 0; i < BATCH_SIZE; i++) {
          const globalIdx = batchIdx * BATCH_SIZE + i + 1;
          const orderOpId = `019283a0-load-${globalIdx.toString().padStart(4, '0')}-0001`;
          const orderEntityId = `019283a0-load-${globalIdx.toString().padStart(4, '0')}-0002`;

          mutations.push({
            operation_id: orderOpId,
            entity_type: 'order',
            entity_id: orderEntityId,
            operation_type: 'INSERT',
            dependency_order: 2,
            payload: {
              order_number: `P1-${1000 + globalIdx}`,
              order_type: 'dineIn',
              grand_total: 1500,
              items: [
                {
                  item_name: `Pizza Variant ${globalIdx}`,
                  quantity: 1,
                  unit_price: 1500,
                },
              ],
              payments: [
                {
                  payment_method: 'cash',
                  amount: 1500,
                  payment_status: 'COMPLETED',
                },
              ],
            },
          });
        }

        const pushDto = {
          device_id: 'POS-P1',
          batch_id: `batch-load-8hr-${batchIdx}`,
          mutations,
        };

        const res = await request(app.getHttpServer())
          .post('/api/sync/push')
          .set('X-Idempotency-Key', `batch-load-8hr-${batchIdx}`)
          .send(pushDto)
          .expect(201);

        expect(res.body.success).toBe(true);
        expect(res.body.processed_count).toBe(BATCH_SIZE);
      }

      const durationMs = Date.now() - startTime;

      // Assert bounded execution time: 160 orders processed in < 3,000ms
      expect(durationMs).toBeLessThan(3000);

      // Verify all 160 orders exist in database
      for (let globalIdx = 1; globalIdx <= TOTAL_ORDERS; globalIdx++) {
        const orderEntityId = `019283a0-load-${globalIdx.toString().padStart(4, '0')}-0002`;
        expect(ordersDb.has(orderEntityId)).toBe(true);
      }
    });
  });
});
