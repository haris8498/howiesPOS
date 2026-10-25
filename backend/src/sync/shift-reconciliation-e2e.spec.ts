import { ShiftHandler } from './handlers/shift.handler';
import { SyncPushService } from './sync-push.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { ChangeLogService } from './change-log.service';

describe('Shift Reconciliation & Offline/Online Lifecycle E2E (§5.2, §6.3, §7.3, §8.2, §21)', () => {
  let shiftHandler: ShiftHandler;
  let syncPushService: SyncPushService;
  let registry: HandlerRegistry;
  let mockChangeLogService: any;
  let mockRealtimeGateway: any;
  let mockPrisma: any;

  beforeEach(() => {
    registry = new HandlerRegistry();
    mockChangeLogService = {
      record: jest.fn().mockResolvedValue(1),
      getMaxSequence: jest.fn().mockResolvedValue(100),
    };
    mockRealtimeGateway = {
      emitShiftStarted: jest.fn(),
      emitShiftClosed: jest.fn(),
      emitShiftUpdated: jest.fn(),
      emitOrderCreated: jest.fn(),
      emitOrderUpdated: jest.fn(),
    };

    shiftHandler = new ShiftHandler(registry, mockChangeLogService as ChangeLogService);
    shiftHandler.onModuleInit();

    mockPrisma = {
      $transaction: jest.fn(async (callback) => {
        return await callback(mockTx);
      }),
      processedOperation: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({ id: 'proc-1', status: 'COMPLETED' }),
      },
      dailyCalculation: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      order: {
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
    };

    syncPushService = new SyncPushService(
      mockPrisma,
      registry,
      undefined,
      mockRealtimeGateway,
    );
  });

  let mockTx: any;
  beforeEach(() => {
    mockTx = {
      dailyCalculation: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      order: {
        findMany: jest.fn().mockResolvedValue([]),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      processedOperation: {
        findUnique: jest.fn().mockResolvedValue({ status: 'COMPLETED' }),
      },
    };
  });

  it('Phase 2 & 3: Cashier opens Shift A -> creates orders -> closes Shift A offline -> pushes batch -> Shift A closed cleanly', async () => {
    const shiftId = 'shift-a-uuid-1';
    const openOpId = 'op-shift-a-open';
    const closeOpId = 'op-shift-a-close';

    // Mock shift initially does not exist, then exists as ACTIVE
    let shiftCreated = false;
    mockTx.dailyCalculation.findUnique.mockImplementation(async ({ where }: any) => {
      if (where.id === shiftId && shiftCreated) {
        return {
          id: shiftId,
          status: 'ACTIVE',
          starting_cash: 5000,
          created_at: new Date('2026-10-25T08:00:00Z'),
          version: 1,
        };
      }
      return null;
    });
    mockTx.dailyCalculation.create.mockImplementation(async ({ data }: any) => {
      shiftCreated = true;
      return {
        ...data,
        id: shiftId,
        version: 1,
        created_at: new Date('2026-10-25T08:00:00Z'),
      };
    });



    mockTx.dailyCalculation.update.mockImplementation(async ({ where, data }: any) => ({
      id: where.id,
      ...data,
      version: 2,
      updated_at: new Date('2026-10-25T16:00:00Z'),
    }));

    mockTx.order.findMany.mockResolvedValue([
      {
        id: 'ord-1',
        shift_id: shiftId,
        order_type: 'takeaway',
        grand_total: 1500,
        discount_amount: 100,
        tax_amount: 200,
        payments: [{ amount: 1500, payment_method: 'cash' }],
      },
    ]);

    const batch = {
      device_id: 'POS-01',
      batch_id: 'batch-shift-a',
      mutations: [
        {
          operation_id: openOpId,
          entity_type: 'shift',
          entity_id: shiftId,
          operation_type: 'INSERT' as const,
          dependency_order: 0,
          created_at: '2026-10-25T08:00:00Z',
          payload: {
            id: shiftId,
            shift_name: 'Morning Shift',
            cashier_id: 'cashier-1',
            cashier_name: 'Alice',
            starting_cash: 5000,
            status: 'OFFLINE_CLOSED', // Shift was closed locally before sync
          },
        },
        {
          operation_id: closeOpId,
          entity_type: 'shift',
          entity_id: shiftId,
          operation_type: 'UPDATE' as const,
          dependency_order: 5,
          depends_on_operation_id: openOpId,
          created_at: '2026-10-25T16:00:00Z',
          payload: {
            id: shiftId,
            actual_cash_counted: 6500,
            expected_cash_drawer: 6500,
            cash_variance: 0,
            status: 'CLOSED',
          },
        },
      ],
    };

    const pushResult = await syncPushService.pushMutations(batch);

    expect(pushResult.success).toBe(true);
    expect(pushResult.processed_count).toBe(2);
    expect(pushResult.results[0].status).toBe('SYNCED');
    expect(pushResult.results[1].status).toBe('SYNCED');

    // Realtime events emitted
    expect(mockRealtimeGateway.emitShiftClosed).toHaveBeenCalledWith(
      expect.objectContaining({ id: shiftId }),
    );
  });

  it('Phase 4 & 6: Consecutive offline shifts (Shift A close -> Shift B open) topological order prevents active shift conflict', async () => {
    const shiftAId = 'shift-a-uuid';
    const shiftBId = 'shift-b-uuid';
    const closeAOpId = 'op-shift-a-close';
    const openBOpId = 'op-shift-b-open';

    mockTx.dailyCalculation.findUnique.mockImplementation(async ({ where }: any) => {
      if (where.id === shiftAId) {
        return {
          id: shiftAId,
          status: 'ACTIVE',
          starting_cash: 5000,
          created_at: new Date('2026-10-25T08:00:00Z'),
          version: 1,
        };
      }
      return null;
    });

    // When Shift B open checks activeShift, Shift A has already been closed!
    mockTx.dailyCalculation.findFirst.mockResolvedValue(null);

    mockTx.dailyCalculation.update.mockResolvedValue({
      id: shiftAId,
      status: 'CLOSED',
      version: 2,
    });

    mockTx.dailyCalculation.create.mockResolvedValue({
      id: shiftBId,
      status: 'ACTIVE',
      version: 1,
    });

    const batch = {
      device_id: 'POS-01',
      batch_id: 'batch-consecutive',
      mutations: [
        {
          operation_id: openBOpId,
          entity_type: 'shift',
          entity_id: shiftBId,
          operation_type: 'INSERT' as const,
          dependency_order: 0,
          depends_on_operation_id: closeAOpId, // Explicit causal chain
          created_at: '2026-10-25T16:05:00Z',
          payload: {
            id: shiftBId,
            starting_cash: 5000,
            status: 'ACTIVE',
          },
        },
        {
          operation_id: closeAOpId,
          entity_type: 'shift',
          entity_id: shiftAId,
          operation_type: 'UPDATE' as const,
          dependency_order: 5,
          created_at: '2026-10-25T16:00:00Z',
          payload: {
            id: shiftAId,
            actual_cash_counted: 5000,
            status: 'CLOSED',
          },
        },
      ],
    };

    const pushResult = await syncPushService.pushMutations(batch);

    expect(pushResult.success).toBe(true);
    // Shift A close was processed FIRST because Shift B depends on Shift A close
    expect(pushResult.results[0].operation_id).toBe(closeAOpId);
    expect(pushResult.results[0].status).toBe('SYNCED');
    expect(pushResult.results[1].operation_id).toBe(openBOpId);
    expect(pushResult.results[1].status).toBe('SYNCED');
  });

  it('Phase 6: Server already has active shift -> opening another returns CONFLICT and preserves offline shift as OFFLINE_CLOSED', async () => {
    const existingServerShiftId = 'shift-server-active';
    const offlineShiftId = 'shift-offline-conflict';

    mockTx.dailyCalculation.findUnique.mockResolvedValue(null);
    mockTx.dailyCalculation.findFirst.mockResolvedValue({
      id: existingServerShiftId,
      status: 'ACTIVE',
    });

    mockTx.dailyCalculation.create.mockImplementation(async ({ data }: any) => ({
      ...data,
      id: offlineShiftId,
      version: 1,
    }));

    const result = await shiftHandler.handle(
      mockTx as any,
      {
        operation_id: 'op-conflict-open',
        entity_type: 'shift',
        entity_id: offlineShiftId,
        operation_type: 'INSERT',
        dependency_order: 0,
        payload: {
          id: offlineShiftId,
          starting_cash: 5000,
          status: 'ACTIVE',
        },
      },
      { deviceId: 'POS-02', operationId: 'op-conflict-open', receivedAt: new Date() },
    );

    expect(result.status).toBe('CONFLICT');
    expect(result.conflict_details?.code).toBe('ACTIVE_SHIFT_EXISTS');

    // Verified that offline shift was inserted as OFFLINE_CLOSED to preserve FKs and offline orders!
    expect(mockTx.dailyCalculation.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          id: offlineShiftId,
          status: 'OFFLINE_CLOSED',
        }),
      }),
    );
  });

  it('Phase 5: Idempotency ledger returns DUPLICATE on identical replay without executing transaction', async () => {
    mockPrisma.processedOperation.findUnique.mockResolvedValue({
      operation_id: 'op-already-synced',
      status: 'COMPLETED',
      response_payload: { server_version: 3 },
      created_at: new Date('2026-10-25T10:00:00Z'),
    });

    const pushResult = await syncPushService.pushMutations({
      device_id: 'POS-01',
      batch_id: 'batch-dup',
      mutations: [
        {
          operation_id: 'op-already-synced',
          entity_type: 'shift',
          entity_id: 'shift-1',
          operation_type: 'INSERT',
          payload: {},
        },
      ],
    });

    expect(pushResult.success).toBe(true);
    expect(pushResult.results[0].status).toBe('DUPLICATE');
    expect(pushResult.results[0].server_version).toBe(3);
    // Database transaction was NOT executed
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
  });
});
