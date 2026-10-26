import { ConflictException } from '@nestjs/common';
import { SyncPushService } from './sync-push.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { OrderHandler } from './handlers/order.handler';
import { OrdersService } from '../orders/orders.service';
import { ChangeLogService } from './change-log.service';

describe('SYNC-001: P2002 Unique Constraint Handling', () => {
  let pushService: SyncPushService;
  let orderHandler: OrderHandler;
  let registry: HandlerRegistry;
  let mockPrisma: any;
  let mockOrdersService: any;
  let mockChangeLogService: any;
  let mockDbOrders: Map<string, any>;
  let mockDbOrderNumbers: Map<string, string>;
  let mockDbTokens: Set<string>;

  beforeEach(() => {
    mockDbOrders = new Map();
    mockDbOrderNumbers = new Map();
    mockDbTokens = new Set();

    mockPrisma = {
      order: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          if (where.id) return Promise.resolve(mockDbOrders.get(where.id) || null);
          if (where.order_number) {
            const id = mockDbOrderNumbers.get(where.order_number);
            return Promise.resolve(id ? mockDbOrders.get(id) : null);
          }
          return Promise.resolve(null);
        }),
      },
      $transaction: jest.fn().mockImplementation(async (callback) => {
        const mockTx = {
          order: {
            findUnique: jest.fn().mockImplementation(({ where }) => {
              if (where.id) return Promise.resolve(mockDbOrders.get(where.id) || null);
              if (where.order_number) {
                const id = mockDbOrderNumbers.get(where.order_number);
                return Promise.resolve(id ? mockDbOrders.get(id) : null);
              }
              return Promise.resolve(null);
            }),
            create: jest.fn().mockImplementation(({ data }) => {
              if (mockDbOrders.has(data.id)) {
                const err: any = new Error('Unique constraint failed on the fields: (id)');
                err.code = 'P2002';
                err.meta = { target: ['id'] };
                throw err;
              }
              if (mockDbOrderNumbers.has(data.order_number)) {
                const err: any = new Error('Unique constraint failed on the fields: (order_number)');
                err.code = 'P2002';
                err.meta = { target: ['order_number'] };
                throw err;
              }
              const order = { ...data, created_at: new Date(), version: 1 };
              mockDbOrders.set(data.id, order);
              mockDbOrderNumbers.set(data.order_number, data.id);
              return Promise.resolve(order);
            }),
          },
          takeawayOrderDetail: {
            findUnique: jest.fn().mockImplementation(({ where }) => {
              if (mockDbTokens.has(where.token_number)) {
                return Promise.resolve({ token_number: where.token_number });
              }
              return Promise.resolve(null);
            }),
            create: jest.fn().mockImplementation(({ data }) => {
              if (mockDbTokens.has(data.token_number)) {
                const err: any = new Error('Unique constraint failed on the fields: (token_number)');
                err.code = 'P2002';
                err.meta = { target: ['token_number'] };
                throw err;
              }
              mockDbTokens.add(data.token_number);
              return Promise.resolve(data);
            }),
          },
        };
        return await callback(mockTx);
      }),
    };

    mockOrdersService = {
      createOrderInTx: jest.fn().mockImplementation(async (tx, dto, explicitId) => {
        let orderNum = dto.order_number;
        let clientOrderNum = dto.order_number;
        const existingWithNum = await tx.order.findUnique({ where: { order_number: orderNum } });
        if (existingWithNum && existingWithNum.id !== explicitId) {
          let suffix = 1;
          while (await tx.order.findUnique({ where: { order_number: `${dto.order_number}-${suffix}` } })) {
            suffix++;
          }
          orderNum = `${dto.order_number}-${suffix}`;
        }
        return await tx.order.create({
          data: {
            id: explicitId || 'auto-id',
            order_number: orderNum,
            client_order_number: clientOrderNum,
            order_type: dto.order_type || 'dineIn',
            status: dto.status || 'newOrder',
            grand_total: dto.grand_total || 0,
            subtotal: dto.subtotal || 0,
            is_paid: dto.is_paid || false,
            payment_status: dto.payment_status || 'UNPAID',
            version: 1,
          },
        });
      }),
    };

    mockChangeLogService = {
      record: jest.fn().mockResolvedValue({ id: 'log-1' }),
    };

    registry = new HandlerRegistry();
    orderHandler = new OrderHandler(registry, mockOrdersService, mockChangeLogService);
    orderHandler.onModuleInit();

    pushService = new SyncPushService(mockPrisma, registry);
  });

  it('1. Same mutation pushed twice -> DUPLICATE, one row', async () => {
    const mutation = {
      operation_id: 'op-dup-1',
      entity_type: 'order',
      entity_id: 'ord-same-1',
      operation_type: 'INSERT',
      dependency_order: 1,
      payload: {
        order_number: 'P1-101',
        grand_total: 25,
      },
    };

    // First push
    const res1 = await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'batch-1',
      mutations: [mutation as any],
    });

    expect(res1.results[0].status).toBe('SYNCED');
    expect(mockDbOrders.size).toBe(1);

    // Second push of identical mutation
    const res2 = await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'batch-2',
      mutations: [mutation as any],
    });

    expect(res2.results[0].status).toBe('DUPLICATE');
    expect(mockDbOrders.size).toBe(1);
  });

  it('2. Two devices push different orders with the same order_number -> both persisted, distinct final numbers, nothing lost', async () => {
    const mutA = {
      operation_id: 'op-a',
      entity_type: 'order',
      entity_id: 'ord-dev-a',
      operation_type: 'INSERT',
      dependency_order: 1,
      payload: { order_number: 'P1-101', grand_total: 30 },
    };
    const mutB = {
      operation_id: 'op-b',
      entity_type: 'order',
      entity_id: 'ord-dev-b',
      operation_type: 'INSERT',
      dependency_order: 1,
      payload: { order_number: 'P1-101', grand_total: 45 },
    };

    // Device A pushes P1-101
    const resA = await pushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'batch-a',
      mutations: [mutA as any],
    });
    expect(resA.results[0].status).toBe('SYNCED');

    // Device B pushes colliding P1-101
    const resB = await pushService.pushMutations({
      device_id: 'POS-02',
      batch_id: 'batch-b',
      mutations: [mutB as any],
    });

    // Must NOT be DUPLICATE! Both orders must be in DB
    expect(resB.results[0].status).toBe('APPLIED');
    expect(mockDbOrders.size).toBe(2);
    expect(mockDbOrders.has('ord-dev-a')).toBe(true);
    expect(mockDbOrders.has('ord-dev-b')).toBe(true);

    const orderA = mockDbOrders.get('ord-dev-a');
    const orderB = mockDbOrders.get('ord-dev-b');
    expect(orderA.order_number).not.toEqual(orderB.order_number);
    expect(orderB.order_number).toBe('P1-101-1');
  });

  it('3. Unknown P2002 target -> not acknowledged as success or DUPLICATE', async () => {
    // Handler that throws P2002 on an unknown field, e.g. 'phone'
    const unknownP2002Handler = {
      entityType: 'order',
      handle: jest.fn().mockImplementation(async () => {
        const err: any = new Error('Unique constraint failed on the fields: (phone)');
        err.code = 'P2002';
        err.meta = { target: ['phone'] };
        throw err;
      }),
    };
    const customRegistry = new HandlerRegistry();
    customRegistry.register(unknownP2002Handler as any);
    const customPush = new SyncPushService(mockPrisma, customRegistry);

    const res = await customPush.pushMutations({
      device_id: 'POS-01',
      batch_id: 'batch-unknown',
      mutations: [
        {
          operation_id: 'op-unk',
          entity_type: 'order',
          entity_id: 'ord-unk-1',
          operation_type: 'INSERT',
          dependency_order: 1,
          payload: {},
        } as any,
      ],
    });

    expect(res.results[0].status).not.toBe('SYNCED');
    expect(res.results[0].status).not.toBe('DUPLICATE');
    expect(res.results[0].status).toBe('FAILED_RETRYABLE');
  });

  it('4. Concurrent pushes (Promise.all) do not lose orders', async () => {
    const mut1 = {
      operation_id: 'op-conc-1',
      entity_type: 'order',
      entity_id: 'ord-conc-1',
      operation_type: 'INSERT',
      dependency_order: 1,
      payload: { order_number: 'P1-200', grand_total: 20 },
    };
    const mut2 = {
      operation_id: 'op-conc-2',
      entity_type: 'order',
      entity_id: 'ord-conc-2',
      operation_type: 'INSERT',
      dependency_order: 1,
      payload: { order_number: 'P1-200', grand_total: 40 },
    };

    const [res1, res2] = await Promise.all([
      pushService.pushMutations({ device_id: 'POS-01', batch_id: 'batch-c1', mutations: [mut1 as any] }),
      pushService.pushMutations({ device_id: 'POS-02', batch_id: 'batch-c2', mutations: [mut2 as any] }),
    ]);

    const statuses = [res1.results[0].status, res2.results[0].status];
    expect(statuses).toContain('SYNCED');
    expect(statuses).toContain('APPLIED');
    expect(mockDbOrders.size).toBe(2);
    expect(mockDbOrders.has('ord-conc-1')).toBe(true);
    expect(mockDbOrders.has('ord-conc-2')).toBe(true);
  });
});
