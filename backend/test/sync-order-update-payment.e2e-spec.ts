import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { SyncModule } from '../src/sync/sync.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';
import { KitchenGateway } from '../src/kitchen/kitchen.gateway';
import { Prisma } from '@prisma/client';

describe('Test T-03: Offline Order UPDATE Drops Payments (SYNC-003 E2E)', () => {
  jest.setTimeout(30000);
  let app: INestApplication;

  // In-memory stateful mock database
  const ordersDb = new Map<string, any>();
  const orderPaymentsDb = new Map<string, any>();
  const tablesDb = new Map<string, any>();
  const processedOpsDb = new Map<string, any>();
  const changeLogs: any[] = [];
  let globalSequenceCounter = BigInt(1);

  const mockPrismaService: any = {
    $transaction: jest.fn().mockImplementation(async (callback: any) => {
      if (typeof callback === 'function') {
        return await callback(mockPrismaService);
      }
      return callback;
    }),

    order: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        const found = ordersDb.get(where.id);
        if (!found) return null;
        const copy = JSON.parse(JSON.stringify(found));
        copy.payments = Array.from(orderPaymentsDb.values()).filter(
          (p) => p.order_id === where.id,
        );
        copy.order_items = copy.order_items || [];
        return copy;
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        const record = {
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
          payment_status: data.payment_status || 'UNPAID',
          payment_method: data.payment_method || 'cash',
          is_paid: data.is_paid ?? false,
          is_held: data.is_held ?? false,
          version: 1,
          created_at: new Date(),
          updated_at: new Date(),
        };
        ordersDb.set(record.id, record);
        return JSON.parse(JSON.stringify(record));
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
    },

    orderPayment: {
      findMany: jest.fn().mockImplementation(async ({ where }) => {
        const payments = Array.from(orderPaymentsDb.values()).filter(
          (p) => !where?.order_id || p.order_id === where.order_id,
        );
        return JSON.parse(JSON.stringify(payments));
      }),
      upsert: jest.fn().mockImplementation(async ({ where, create, update }) => {
        const id = where.id;
        const existing = orderPaymentsDb.get(id);
        if (existing) {
          const updated = {
            ...existing,
            ...update,
            amount: update.amount instanceof Prisma.Decimal ? Number(update.amount) : Number(update.amount || 0),
          };
          orderPaymentsDb.set(id, updated);
          return JSON.parse(JSON.stringify(updated));
        } else {
          const rec = {
            ...create,
            id,
            amount: create.amount instanceof Prisma.Decimal ? Number(create.amount) : Number(create.amount || 0),
            created_at: new Date(),
          };
          orderPaymentsDb.set(id, rec);
          return JSON.parse(JSON.stringify(rec));
        }
      }),
    },

    restaurantTable: {
      update: jest.fn().mockResolvedValue({}),
      findUnique: jest.fn().mockResolvedValue(null),
    },

    systemChangeLog: {
      create: jest.fn().mockImplementation(async ({ data }) => {
        const entry = {
          id: `log-${Date.now()}-${Math.random()}`,
          global_sequence: ++globalSequenceCounter,
          created_at: new Date(),
          ...data,
        };
        changeLogs.push(entry);
        return entry;
      }),
    },

    processedOperation: {
      findUnique: jest.fn().mockImplementation(async ({ where }) => {
        return processedOpsDb.get(where.operation_id) || null;
      }),
      create: jest.fn().mockImplementation(async ({ data }) => {
        processedOpsDb.set(data.operation_id, data);
        return data;
      }),
      update: jest.fn().mockImplementation(async ({ where, data }) => {
        const prev = processedOpsDb.get(where.operation_id);
        const updated = { ...prev, ...data };
        processedOpsDb.set(where.operation_id, updated);
        return updated;
      }),
    },
  };

  const mockKitchenGateway = {
    emitOrderCreated: jest.fn(),
    emitOrderUpdated: jest.fn(),
  };

  beforeAll(async () => {
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

  beforeEach(() => {
    ordersDb.clear();
    orderPaymentsDb.clear();
    processedOpsDb.clear();
    changeLogs.length = 0;
  });

  it('T-03: Offline dine-in order UPDATE creates payment records in database', async () => {
    // 1. Setup: Create order ord-10 as UNPAID in database
    ordersDb.set('ord-10', {
      id: 'ord-10',
      order_number: 'P1-110',
      order_type: 'dineIn',
      status: 'accepted',
      subtotal: 2500,
      grand_total: 2500,
      payment_status: 'UNPAID',
      is_paid: false,
      version: 1,
      created_at: new Date(),
      updated_at: new Date(),
    });

    // 2. Send POST /api/sync/push with UPDATE mutation carrying payment
    const pushPayload = {
      device_id: 'POS-P1',
      batch_id: 'batch-settle-01',
      mutations: [
        {
          operation_id: 'op-settle-10',
          entity_type: 'order',
          entity_id: 'ord-10',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: {
            status: 'completed',
            payment_status: 'PAID',
            is_paid: true,
            payments: [
              {
                id: 'pay-uuid-10',
                payment_method: 'cash',
                amount: 2500,
                tendered_amount: 3000,
                change_returned: 500,
              },
            ],
          },
        },
      ],
    };

    const res = await request(app.getHttpServer())
      .post('/api/sync/push')
      .send(pushPayload)
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.results).toHaveLength(1);
    expect(res.body.results[0].status).toBe('SYNCED');
    expect(res.body.results[0].server_version).toBe(2);

    // 3. Verify orderPayment contains 1 row with amount 2500 and cash
    const payments = Array.from(orderPaymentsDb.values()).filter(
      (p) => p.order_id === 'ord-10',
    );
    expect(payments).toHaveLength(1);
    expect(payments[0].amount).toBe(2500);
    expect(payments[0].payment_method).toBe('cash');

    // 4. Verify order header in database is marked completed and paid
    const updatedOrder = ordersDb.get('ord-10');
    expect(updatedOrder.status).toBe('completed');
    expect(updatedOrder.payment_status).toBe('PAID');
    expect(updatedOrder.is_paid).toBe(true);
    expect(Number(updatedOrder.grand_total)).toBe(2500);
  });

  it('T-03b: Replay of the same UPDATE mutation does not duplicate payment rows', async () => {
    // Setup initial order
    ordersDb.set('ord-20', {
      id: 'ord-20',
      order_number: 'P1-120',
      order_type: 'dineIn',
      status: 'accepted',
      subtotal: 1500,
      grand_total: 1500,
      payment_status: 'UNPAID',
      is_paid: false,
      version: 1,
      created_at: new Date(),
      updated_at: new Date(),
    });

    const pushPayload = {
      device_id: 'POS-P1',
      batch_id: 'batch-replay-01',
      mutations: [
        {
          operation_id: 'op-replay-20',
          entity_type: 'order',
          entity_id: 'ord-20',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: {
            status: 'completed',
            payment_status: 'PAID',
            is_paid: true,
            payments: [
              {
                id: 'pay-uuid-20',
                payment_method: 'card',
                amount: 1500,
              },
            ],
          },
        },
      ],
    };

    // First push
    await request(app.getHttpServer())
      .post('/api/sync/push')
      .send(pushPayload)
      .expect(201);

    expect(orderPaymentsDb.size).toBe(1);

    // Replay of the same push
    const replayRes = await request(app.getHttpServer())
      .post('/api/sync/push')
      .send(pushPayload)
      .expect(201);

    // Payments must not be duplicated
    const payments = Array.from(orderPaymentsDb.values()).filter(
      (p) => p.order_id === 'ord-20',
    );
    expect(payments).toHaveLength(1);
    expect(payments[0].amount).toBe(1500);
  });

  it('T-03c: Underpayment mismatch is rejected as CONFLICT and is_paid stays false', async () => {
    ordersDb.set('ord-30', {
      id: 'ord-30',
      order_number: 'P1-130',
      order_type: 'dineIn',
      status: 'accepted',
      subtotal: 4000,
      grand_total: 4000,
      payment_status: 'UNPAID',
      is_paid: false,
      version: 1,
      created_at: new Date(),
      updated_at: new Date(),
    });

    const pushPayload = {
      device_id: 'POS-P1',
      batch_id: 'batch-mismatch-01',
      mutations: [
        {
          operation_id: 'op-mismatch-30',
          entity_type: 'order',
          entity_id: 'ord-30',
          operation_type: 'UPDATE',
          base_version: 1,
          payload: {
            status: 'completed',
            payment_status: 'PAID',
            is_paid: true,
            payments: [
              {
                id: 'pay-uuid-30',
                payment_method: 'cash',
                amount: 2500, // 2500 < 4000
              },
            ],
          },
        },
      ],
    };

    const res = await request(app.getHttpServer())
      .post('/api/sync/push')
      .send(pushPayload)
      .expect(201);

    expect(res.body.results[0].status).toBe('CONFLICT');

    // Verify order in database was not marked paid
    const order = ordersDb.get('ord-30');
    expect(order.is_paid).toBe(false);
    expect(order.status).toBe('accepted');
  });
});
