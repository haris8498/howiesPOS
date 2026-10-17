import { ConflictException } from '@nestjs/common';
import { SyncPushService } from './sync-push.service';
import { HandlerRegistry } from './handlers/handler-registry.service';
import { PrismaService } from '../prisma/prisma.service';

describe('SyncPushService', () => {
  let service: SyncPushService;
  let mockPrisma: any;
  let mockRegistry: HandlerRegistry;
  let executedOrder: string[];

  beforeEach(() => {
    executedOrder = [];
    mockPrisma = {
      $transaction: jest.fn().mockImplementation(async (callback) => {
        const mockTx = { txId: Math.random() };
        return await callback(mockTx);
      }),
    };

    mockRegistry = new HandlerRegistry();

    service = new SyncPushService(
      mockPrisma as PrismaService,
      mockRegistry,
    );
  });

  it('should process mutations strictly in dependency_order ASC then created_at ASC', async () => {
    const processedIds: string[] = [];

    const mockHandler = {
      entityType: 'test_entity',
      handle: jest.fn().mockImplementation(async (tx, mutation) => {
        processedIds.push(mutation.operation_id);
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'SYNCED',
          server_version: 1,
          server_timestamp: new Date().toISOString(),
        };
      }),
    };
    mockRegistry.register(mockHandler as any);

    const mutations = [
      {
        operation_id: 'op-level-3-late',
        entity_type: 'test_entity',
        entity_id: 'e3b',
        operation_type: 'INSERT',
        dependency_order: 3,
        created_at: '2026-10-17T12:05:00Z',
        payload: {},
      },
      {
        operation_id: 'op-level-1',
        entity_type: 'test_entity',
        entity_id: 'e1',
        operation_type: 'INSERT',
        dependency_order: 1,
        created_at: '2026-10-17T12:00:00Z',
        payload: {},
      },
      {
        operation_id: 'op-level-2',
        entity_type: 'test_entity',
        entity_id: 'e2',
        operation_type: 'INSERT',
        dependency_order: 2,
        created_at: '2026-10-17T12:02:00Z',
        payload: {},
      },
      {
        operation_id: 'op-level-3-early',
        entity_type: 'test_entity',
        entity_id: 'e3a',
        operation_type: 'INSERT',
        dependency_order: 3,
        created_at: '2026-10-17T12:01:00Z',
        payload: {},
      },
    ];

    const result = await service.pushMutations({
      device_id: 'POS-P1',
      batch_id: 'batch-sort-1',
      mutations: mutations as any,
    });

    expect(result.success).toBe(true);
    expect(result.processed_count).toBe(4);
    // Topological order: level 1, level 2, level 3 early, level 3 late
    expect(processedIds).toEqual([
      'op-level-1',
      'op-level-2',
      'op-level-3-early',
      'op-level-3-late',
    ]);
  });

  it('should isolate mutations so one bad mutation does not poison the batch (partial failure)', async () => {
    const mockHandler = {
      entityType: 'order',
      handle: jest.fn().mockImplementation(async (tx, mutation) => {
        if (mutation.operation_id === 'bad-mutation-2') {
          throw new ConflictException("Order number 'P1-102' already exists");
        }
        if (mutation.operation_id === 'fatal-mutation-4') {
          throw new Error('Fatal validation DB crash');
        }
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'SYNCED',
          server_version: 1,
          server_timestamp: new Date().toISOString(),
        };
      }),
    };
    mockRegistry.register(mockHandler as any);

    const mutations = [
      {
        operation_id: 'good-mutation-1',
        entity_type: 'order',
        entity_id: 'ord-1',
        operation_type: 'INSERT',
        dependency_order: 1,
        payload: {},
      },
      {
        operation_id: 'bad-mutation-2',
        entity_type: 'order',
        entity_id: 'ord-2',
        operation_type: 'INSERT',
        dependency_order: 2,
        payload: {},
      },
      {
        operation_id: 'good-mutation-3',
        entity_type: 'order',
        entity_id: 'ord-3',
        operation_type: 'INSERT',
        dependency_order: 3,
        payload: {},
      },
      {
        operation_id: 'fatal-mutation-4',
        entity_type: 'order',
        entity_id: 'ord-4',
        operation_type: 'INSERT',
        dependency_order: 4,
        payload: {},
      },
    ];

    const result = await service.pushMutations({
      device_id: 'POS-P1',
      batch_id: 'batch-partial-1',
      mutations: mutations as any,
    });

    expect(result.success).toBe(true);
    expect(result.processed_count).toBe(4);

    expect(result.results[0].status).toBe('SYNCED');
    expect(result.results[0].operation_id).toBe('good-mutation-1');

    expect(result.results[1].status).toBe('CONFLICT');
    expect(result.results[1].operation_id).toBe('bad-mutation-2');

    expect(result.results[2].status).toBe('SYNCED');
    expect(result.results[2].operation_id).toBe('good-mutation-3');

    expect(result.results[3].status).toBe('FAILED_FATAL');
    expect(result.results[3].operation_id).toBe('fatal-mutation-4');
  });

  it('should return FAILED_FATAL for mutations with unknown entity type without failing batch', async () => {
    const result = await service.pushMutations({
      device_id: 'POS-P1',
      batch_id: 'batch-unknown-1',
      mutations: [
        {
          operation_id: 'unregistered-op',
          entity_type: 'non_existent_entity',
          entity_id: 'xyz',
          operation_type: 'INSERT',
          dependency_order: 1,
          payload: {},
        },
      ] as any,
    });

    expect(result.success).toBe(true);
    expect(result.results[0].status).toBe('FAILED_FATAL');
    expect(result.results[0].error_message).toContain('No sync entity handler registered');
  });
});
