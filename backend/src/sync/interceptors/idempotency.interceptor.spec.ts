import { ConflictException, ExecutionContext, CallHandler } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { of, throwError, lastValueFrom } from 'rxjs';
import { PrismaService } from '../../prisma/prisma.service';
import { IdempotencyInterceptor, canonicalJson } from './idempotency.interceptor';

describe('IdempotencyInterceptor (§8.2, §7.1, §15.2)', () => {
  let interceptor: IdempotencyInterceptor;
  let prisma: PrismaService;

  // In-memory mock database for processed_operations
  const ledger = new Map<string, any>();

  const mockPrisma = {
    processedOperation: {
      findUnique: jest.fn().mockImplementation(({ where }: { where: { operation_id: string } }) => {
        const found = ledger.get(where.operation_id);
        return Promise.resolve(found ? { ...found } : null);
      }),
      create: jest.fn().mockImplementation(({ data }: { data: any }) => {
        if (ledger.has(data.operation_id)) {
          const err = new Error('Unique constraint failed on processed_operations_operation_id_key');
          (err as any).code = 'P2002';
          return Promise.reject(err);
        }
        const record = { ...data, created_at: new Date() };
        ledger.set(data.operation_id, record);
        return Promise.resolve(record);
      }),
      update: jest.fn().mockImplementation(({ where, data }: { where: { operation_id: string }; data: any }) => {
        const existing = ledger.get(where.operation_id) || {};
        const updated = { ...existing, ...data };
        ledger.set(where.operation_id, updated);
        return Promise.resolve(updated);
      }),
      delete: jest.fn().mockImplementation(({ where }: { where: { operation_id: string } }) => {
        const existed = ledger.get(where.operation_id);
        ledger.delete(where.operation_id);
        return Promise.resolve(existed);
      }),
    },
  };

  const createMockContext = (
    headers: Record<string, string> = {},
    body: Record<string, any> = {},
    url = '/api/orders',
    method = 'POST',
  ): { context: ExecutionContext; res: any } => {
    const res = {
      statusCode: 201,
      status: jest.fn().mockReturnThis(),
    };
    const req = {
      headers,
      body,
      url,
      method,
      originalUrl: url,
    };
    const context = {
      switchToHttp: () => ({
        getRequest: () => req,
        getResponse: () => res,
      }),
    } as unknown as ExecutionContext;

    return { context, res };
  };

  beforeEach(async () => {
    ledger.clear();
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        IdempotencyInterceptor,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    interceptor = module.get<IdempotencyInterceptor>(IdempotencyInterceptor);
  });

  it('should pass through unchanged when neither X-Idempotency-Key nor operation_id is present', async () => {
    const { context } = createMockContext({}, { item_name: 'Cheese Pizza' });
    const handler: CallHandler = {
      handle: jest.fn().mockReturnValue(of({ success: true, data: { orderId: 'ord-123' } })),
    };

    const observable = await interceptor.intercept(context, handler);
    const result = await lastValueFrom(observable);

    expect(result).toEqual({ success: true, data: { orderId: 'ord-123' } });
    expect(handler.handle).toHaveBeenCalledTimes(1);
    expect(mockPrisma.processedOperation.findUnique).not.toHaveBeenCalled();
    expect(ledger.size).toBe(0);
  });

  it('should execute write request and record COMPLETED record in ledger', async () => {
    const { context } = createMockContext(
      { 'x-idempotency-key': '0192994c-8f12-789a-bcde-f0123456789a' },
      { order_type: 'takeaway', grand_total: 500 },
    );
    const handler: CallHandler = {
      handle: jest.fn().mockReturnValue(of({ success: true, data: { orderId: 'ord-555' } })),
    };

    const observable = await interceptor.intercept(context, handler);
    const result = await lastValueFrom(observable);

    expect(result).toEqual({ success: true, data: { orderId: 'ord-555' } });
    expect(handler.handle).toHaveBeenCalledTimes(1);

    const saved = ledger.get('0192994c-8f12-789a-bcde-f0123456789a');
    expect(saved).toBeDefined();
    expect(saved.status).toBe('COMPLETED');
    expect(saved.response_payload).toEqual({ success: true, data: { orderId: 'ord-555' } });
    expect(saved.request_hash).toBeDefined();
    expect(saved.request_hash).toHaveLength(64);
  });

  it('5x Replay Test: retrying the same idempotency key 5 times executes handler exactly once', async () => {
    const idempotencyKey = '0192994c-8f12-789a-bcde-5x-replay-key';
    const payload = {
      order_number: 'P1-101',
      order_type: 'dineIn',
      items: [{ item_name: 'BBQ Pizza', quantity: 2, unit_price: 600 }],
      grand_total: 1200,
    };

    const orderResponse = {
      success: true,
      message: 'Order created successfully',
      data: {
        id: '0192994c-8f12-789a-bcde-ord-001',
        order_number: 'P1-101',
        grand_total: 1200,
      },
    };

    const handler: CallHandler = {
      handle: jest.fn().mockReturnValue(of(orderResponse)),
    };

    // First call (original execution)
    const { context: ctx1 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);
    const res1 = await lastValueFrom(await interceptor.intercept(ctx1, handler));
    expect(res1).toEqual(orderResponse);
    expect(handler.handle).toHaveBeenCalledTimes(1);

    // 4 Subsequent Retries with identical idempotency key and body
    for (let i = 2; i <= 5; i++) {
      const { context: ctxN, res } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);
      const resN = await lastValueFrom(await interceptor.intercept(ctxN, handler));

      expect(resN).toEqual(orderResponse);
      expect(res.status).toHaveBeenCalledWith(201);
    }

    // Handler MUST have been invoked exactly ONCE across all 5 requests (§15.2 Gate 4)
    expect(handler.handle).toHaveBeenCalledTimes(1);
    expect(ledger.size).toBe(1);
  });

  it('Hash Mismatch Test: throws 409 ConflictException when same key is used with differing payload', async () => {
    const idempotencyKey = '0192994c-8f12-789a-bcde-hash-test-key';
    const originalPayload = {
      order_number: 'P1-101',
      grand_total: 1000,
    };
    const modifiedPayload = {
      order_number: 'P1-101',
      grand_total: 2500, // Altered amount!
    };

    const handler: CallHandler = {
      handle: jest.fn().mockReturnValue(of({ success: true, orderId: 'ord-101' })),
    };

    // 1st request succeeds
    const { context: ctx1 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, originalPayload);
    await lastValueFrom(await interceptor.intercept(ctx1, handler));
    expect(handler.handle).toHaveBeenCalledTimes(1);

    // 2nd request with same key but different body MUST throw ConflictException (409)
    const { context: ctx2 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, modifiedPayload);
    await expect(interceptor.intercept(ctx2, handler)).rejects.toThrow(ConflictException);

    // Handler was NOT called a second time
    expect(handler.handle).toHaveBeenCalledTimes(1);
  });

  it('Concurrent Duplicates Test: second in-flight request waits and returns cached response', async () => {
    const idempotencyKey = '0192994c-8f12-789a-bcde-concurrent-key';
    const payload = { order_number: 'P1-102', grand_total: 750 };
    const responsePayload = { success: true, data: { orderId: 'ord-102' } };

    // Create interceptor with short poll intervals for fast test execution
    const fastInterceptor = new IdempotencyInterceptor(mockPrisma as any, {
      staleTimeoutMs: 10000,
      pollIntervalMs: 10,
      maxWaitMs: 500,
    });

    const handler: CallHandler = {
      handle: jest.fn().mockImplementation(() => {
        // Return response wrapped in of
        return of(responsePayload);
      }),
    };

    // Simulate Request 1 arriving and creating PROCESSING
    const { context: ctx1 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);
    const { context: ctx2 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);

    // Run both requests concurrently
    const [res1, res2] = await Promise.all([
      lastValueFrom(await fastInterceptor.intercept(ctx1, handler)),
      lastValueFrom(await fastInterceptor.intercept(ctx2, handler)),
    ]);

    expect(res1).toEqual(responsePayload);
    expect(res2).toEqual(responsePayload);
    // Even under concurrency, handler is executed only once
    expect(handler.handle).toHaveBeenCalledTimes(1);
  });

  it('Stale PROCESSING Recovery Test: recovers and re-executes when previous processing crashed >30s ago', async () => {
    const idempotencyKey = '0192994c-8f12-789a-bcde-stale-crash-key';
    const payload = { order_number: 'P1-103', grand_total: 800 };
    const responsePayload = { success: true, data: { orderId: 'ord-103' } };

    // Seed a stale PROCESSING entry created 45 seconds ago (simulating crashed server)
    const staleDate = new Date(Date.now() - 45000);
    ledger.set(idempotencyKey, {
      operation_id: idempotencyKey,
      device_id: 'POS-P1',
      entity_type: 'order',
      entity_id: 'ord-103',
      request_hash: 'old-hash',
      status: 'PROCESSING',
      created_at: staleDate,
    });

    const handler: CallHandler = {
      handle: jest.fn().mockReturnValue(of(responsePayload)),
    };

    const { context } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);
    const result = await lastValueFrom(await interceptor.intercept(context, handler));

    expect(result).toEqual(responsePayload);
    expect(handler.handle).toHaveBeenCalledTimes(1);

    const record = ledger.get(idempotencyKey);
    expect(record.status).toBe('COMPLETED');
    expect(record.completed_at).toBeDefined();
  });

  it('Error Cleanup Test: removes PROCESSING lock on transaction failure so subsequent retry can succeed', async () => {
    const idempotencyKey = '0192994c-8f12-789a-bcde-error-cleanup-key';
    const payload = { order_number: 'P1-104', grand_total: 900 };

    const failingHandler: CallHandler = {
      handle: jest.fn().mockReturnValue(throwError(() => new Error('DB Lock Timeout'))),
    };

    const { context: ctx1 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);

    // Call 1 fails
    await expect(
      interceptor.intercept(ctx1, failingHandler).then((obs) => lastValueFrom(obs)),
    ).rejects.toThrow('DB Lock Timeout');

    // The lock record MUST be deleted so the client retry is not blocked
    expect(ledger.has(idempotencyKey)).toBe(false);

    // Call 2 (retry after network/db recovered) succeeds cleanly
    const successHandler: CallHandler = {
      handle: jest.fn().mockReturnValue(of({ success: true, orderId: 'ord-104' })),
    };
    const { context: ctx2 } = createMockContext({ 'x-idempotency-key': idempotencyKey }, payload);
    const result = await lastValueFrom(await interceptor.intercept(ctx2, successHandler));

    expect(result).toEqual({ success: true, orderId: 'ord-104' });
    expect(ledger.get(idempotencyKey).status).toBe('COMPLETED');
  });

  it('canonicalJson helper produces deterministic strings regardless of object key order', () => {
    const objA = { z: 1, a: 'test', m: { b: 2, a: 1 } };
    const objB = { a: 'test', m: { a: 1, b: 2 }, z: 1 };

    expect(canonicalJson(objA)).toBe(canonicalJson(objB));
    expect(canonicalJson(objA)).toBe('{"a":"test","m":{"a":1,"b":2},"z":1}');
  });
});
