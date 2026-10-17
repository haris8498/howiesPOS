import { ShiftHandler } from './shift.handler';
import { HandlerRegistry } from './handler-registry.service';
import { ChangeLogService } from '../change-log.service';
import { SyncPushService } from '../sync-push.service';

describe('ShiftHandler (§7.3, §6.3, §8.3(3), §21 Decision 2)', () => {
  let handler: ShiftHandler;
  let mockRegistry: any;
  let mockChangeLogService: any;

  beforeEach(() => {
    mockRegistry = {
      register: jest.fn(),
    };
    mockChangeLogService = {
      record: jest.fn(),
    };
    handler = new ShiftHandler(
      mockRegistry as HandlerRegistry,
      mockChangeLogService as ChangeLogService,
    );
  });

  it('should register itself in handler registry on module init', () => {
    handler.onModuleInit();
    expect(mockRegistry.register).toHaveBeenCalledWith(handler);
    expect(handler.entityType).toBe('shift');
  });

  describe('handle INSERT (Shift Open - Level 0)', () => {
    it('should return DUPLICATE if shift ID already exists (idempotent open)', async () => {
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'shift-uuid-1',
            version: 1,
            created_at: new Date('2026-10-17T08:00:00Z'),
            updated_at: new Date('2026-10-17T08:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-open-1',
          entity_type: 'shift',
          entity_id: 'shift-uuid-1',
          operation_type: 'INSERT',
          dependency_order: 0,
          payload: {
            starting_cash: 5000,
            cashier_id: 'cashier-1',
            cashier_name: 'Cashier One',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-open-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('DUPLICATE');
      expect(result.entity_id).toBe('shift-uuid-1');
      expect(result.server_version).toBe(1);
    });

    it('should open shift with starting cash and record change log on new INSERT', async () => {
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue(null),
          create: jest.fn().mockResolvedValue({
            id: 'shift-uuid-2',
            shift_name: 'Morning Shift',
            cashier_id: 'cashier-2',
            cashier_name: 'Cashier Two',
            starting_cash: 5000,
            status: 'ACTIVE',
            version: 1,
            created_at: new Date('2026-10-17T08:00:00Z'),
            updated_at: new Date('2026-10-17T08:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-open-2',
          entity_type: 'shift',
          entity_id: 'shift-uuid-2',
          operation_type: 'INSERT',
          dependency_order: 0,
          payload: {
            shift_name: 'Morning Shift',
            starting_cash: 5000,
            cashier_id: 'cashier-2',
            cashier_name: 'Cashier Two',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-open-2', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.entity_id).toBe('shift-uuid-2');
      expect(result.server_version).toBe(1);
      expect(mockTx.dailyCalculation.create).toHaveBeenCalled();
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'shift',
        'shift-uuid-2',
        'INSERT',
        1,
        expect.objectContaining({ starting_cash: 5000, status: 'ACTIVE' }),
        false,
      );
    });
  });

  describe('handle UPDATE (Shift Close - Level 5)', () => {
    it('Scenario 1: close offline then sync (stores cash_variance and OFFLINE_CLOSED status)', async () => {
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'shift-uuid-3',
            status: 'ACTIVE',
            version: 1,
            starting_cash: 5000,
            created_at: new Date('2026-10-17T08:00:00Z'),
          }),
          update: jest.fn().mockResolvedValue({
            id: 'shift-uuid-3',
            shift_name: 'Full Day',
            status: 'OFFLINE_CLOSED',
            cash_submitted: 12500,
            cash_variance: -500, // PKR 500 shortage
            variance_reason: 'Cash drawer shortage reported offline',
            version: 2,
            updated_at: new Date('2026-10-17T18:00:00Z'),
            submitted_at: new Date('2026-10-17T18:00:00Z'),
          }),
        },
        order: {
          updateMany: jest.fn().mockResolvedValue({ count: 5 }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-close-1',
          entity_type: 'shift',
          entity_id: 'shift-uuid-3',
          operation_type: 'UPDATE',
          dependency_order: 5,
          base_version: 1,
          payload: {
            status: 'OFFLINE_CLOSED',
            actual_cash_counted: 12500,
            expected_cash_drawer: 13000,
            cash_variance: -500, // Shortage of 500
            variance_reason: 'Cash drawer shortage reported offline',
            closing_notes: 'Closed offline before internet restored',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-close-1', receivedAt: new Date() },
      );

      expect(result.status).toBe('SYNCED');
      expect(result.entity_id).toBe('shift-uuid-3');
      expect(result.server_version).toBe(2);
      expect(mockTx.dailyCalculation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'shift-uuid-3' },
          data: expect.objectContaining({
            status: 'OFFLINE_CLOSED',
            variance_reason: 'Cash drawer shortage reported offline',
          }),
        }),
      );
      expect(mockTx.order.updateMany).toHaveBeenCalled();
      expect(mockChangeLogService.record).toHaveBeenCalledWith(
        mockTx,
        'shift',
        'shift-uuid-3',
        'UPDATE',
        2,
        expect.objectContaining({
          status: 'OFFLINE_CLOSED',
          cash_variance: -500,
        }),
        false,
      );
    });

    it('Scenario 2: two closes for same shift (idempotent close)', async () => {
      // First close already transitioned shift to OFFLINE_CLOSED
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'shift-uuid-3',
            status: 'OFFLINE_CLOSED',
            version: 2,
            cash_variance: -500,
            updated_at: new Date('2026-10-17T18:00:00Z'),
          }),
          update: jest.fn(),
        },
      };

      const secondCloseResult = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-close-retry',
          entity_type: 'shift',
          entity_id: 'shift-uuid-3',
          operation_type: 'UPDATE',
          dependency_order: 5,
          base_version: 2,
          payload: {
            status: 'OFFLINE_CLOSED',
            actual_cash_counted: 12500,
            cash_variance: -500,
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-close-retry', receivedAt: new Date() },
      );

      // Must be idempotent DUPLICATE, no update called
      expect(secondCloseResult.status).toBe('DUPLICATE');
      expect(secondCloseResult.entity_id).toBe('shift-uuid-3');
      expect(secondCloseResult.server_version).toBe(2);
      expect(mockTx.dailyCalculation.update).not.toHaveBeenCalled();
    });

    it('Scenario 3: close attempted with unsynced dependency (rejects with FAILED_RETRYABLE)', async () => {
      const mockTx = {
        processedOperation: {
          findUnique: jest.fn().mockResolvedValue(null), // Dependency not found in ledger
        },
        dailyCalculation: {
          findUnique: jest.fn(),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-close-dep',
          entity_type: 'shift',
          entity_id: 'shift-uuid-4',
          operation_type: 'UPDATE',
          dependency_order: 5,
          depends_on_operation_id: 'uncompleted-order-op-99',
          payload: {
            status: 'OFFLINE_CLOSED',
            cash_variance: 0,
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-close-dep', receivedAt: new Date() },
      );

      expect(result.status).toBe('FAILED_RETRYABLE');
      expect(result.error_message).toContain('Unsynced dependency');
      expect(result.error_message).toContain('uncompleted-order-op-99');
      expect(mockTx.dailyCalculation.findUnique).not.toHaveBeenCalled();
    });

    it('Scenario 4: OCC version conflict when server has been modified (server > base_version)', async () => {
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue({
            id: 'shift-uuid-5',
            status: 'ACTIVE',
            version: 3, // Server is already at version 3
            updated_at: new Date('2026-10-17T15:00:00Z'),
          }),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-close-conflict',
          entity_type: 'shift',
          entity_id: 'shift-uuid-5',
          operation_type: 'UPDATE',
          dependency_order: 5,
          base_version: 1, // Client expects version 1
          payload: {
            status: 'OFFLINE_CLOSED',
            cash_variance: 0,
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-close-conflict', receivedAt: new Date() },
      );

      expect(result.status).toBe('CONFLICT');
      expect(result.server_version).toBe(3);
      expect(result.conflict_details).toBeDefined();
      expect(result.conflict_details.message).toContain('OCC Version Conflict');
    });

    it('Scenario 5: returns FAILED_FATAL if shift record does not exist on UPDATE', async () => {
      const mockTx = {
        dailyCalculation: {
          findUnique: jest.fn().mockResolvedValue(null),
        },
      };

      const result = await handler.handle(
        mockTx as any,
        {
          operation_id: 'op-shift-close-missing',
          entity_type: 'shift',
          entity_id: 'non-existent-shift',
          operation_type: 'UPDATE',
          dependency_order: 5,
          payload: {
            status: 'OFFLINE_CLOSED',
          },
        },
        { deviceId: 'POS-P1', operationId: 'op-shift-close-missing', receivedAt: new Date() },
      );

      expect(result.status).toBe('FAILED_FATAL');
      expect(result.error_message).toContain("Shift 'non-existent-shift' not found");
    });
  });

  describe('Topological Dependency Ordering (§6.3)', () => {
    it('Scenario 6: orders created offline before close all sync before the closure operation', async () => {
      const executionSequence: string[] = [];

      const mockPrisma = {
        $transaction: jest.fn().mockImplementation(async (cb) => {
          return await cb({
            processedOperation: {
              findUnique: jest.fn().mockResolvedValue({ status: 'COMPLETED' }),
            },
          });
        }),
      };

      const registry = new HandlerRegistry();
      const mockChangeLog = { record: jest.fn() };
      const shiftH = new ShiftHandler(registry, mockChangeLog as any);
      shiftH.onModuleInit();

      // Custom mock handlers to capture execution sequence
      const mockOrderHandler = {
        entityType: 'order',
        handle: jest.fn().mockImplementation(async (tx, mutation) => {
          executionSequence.push(`order:${mutation.entity_id}`);
          return {
            operation_id: mutation.operation_id,
            entity_id: mutation.entity_id,
            status: 'SYNCED',
            server_version: 1,
            server_timestamp: new Date().toISOString(),
          };
        }),
      };
      registry.register(mockOrderHandler as any);

      // Override shift handler with spy
      const originalHandle = shiftH.handle.bind(shiftH);
      jest.spyOn(shiftH, 'handle').mockImplementation(async (tx, mutation, ctx) => {
        const op = (mutation.operation_type || 'INSERT').toUpperCase();
        executionSequence.push(`shift:${op}:${mutation.entity_id}`);
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'SYNCED',
          server_version: op === 'INSERT' ? 1 : 2,
          server_timestamp: new Date().toISOString(),
        };
      });

      const pushService = new SyncPushService(mockPrisma as any, registry);

      // Intentionally scrambled mutations order in push batch
      const scrambledBatch = [
        {
          operation_id: 'op-shift-close',
          entity_type: 'shift',
          entity_id: 'shift-1',
          operation_type: 'UPDATE',
          dependency_order: 5, // Level 5: Shift Close
          created_at: '2026-10-17T18:00:00Z',
          payload: { status: 'OFFLINE_CLOSED', cash_variance: -100 },
        },
        {
          operation_id: 'op-order-2',
          entity_type: 'order',
          entity_id: 'order-2',
          operation_type: 'INSERT',
          dependency_order: 2, // Level 2: Order Header
          created_at: '2026-10-17T11:00:00Z',
          payload: { order_number: 'P1-102', shift_id: 'shift-1' },
        },
        {
          operation_id: 'op-shift-open',
          entity_type: 'shift',
          entity_id: 'shift-1',
          operation_type: 'INSERT',
          dependency_order: 0, // Level 0: Shift Session
          created_at: '2026-10-17T08:00:00Z',
          payload: { starting_cash: 5000 },
        },
        {
          operation_id: 'op-order-1',
          entity_type: 'order',
          entity_id: 'order-1',
          operation_type: 'INSERT',
          dependency_order: 2, // Level 2: Order Header
          created_at: '2026-10-17T09:00:00Z',
          payload: { order_number: 'P1-101', shift_id: 'shift-1' },
        },
      ];

      const res = await pushService.pushMutations({
        device_id: 'POS-P1',
        batch_id: 'batch-topological-test',
        mutations: scrambledBatch as any,
      });

      expect(res.success).toBe(true);
      expect(res.processed_count).toBe(4);

      // Verify strict topological ordering:
      // Level 0 (Shift Open) -> Level 2 (Orders by created_at) -> Level 5 (Shift Close)
      expect(executionSequence).toEqual([
        'shift:INSERT:shift-1',
        'order:order-1',
        'order:order-2',
        'shift:UPDATE:shift-1',
      ]);
    });
  });
});
