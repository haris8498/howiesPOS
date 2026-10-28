import 'reflect-metadata';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { SyncPushDto } from './sync-push.dto';

describe('SyncPushDto Validation', () => {
  const createMutation = (index: number) => ({
    operation_id: `op-${index}`,
    entity_type: 'order',
    entity_id: `ent-${index}`,
    operation_type: 'INSERT',
    payload: { id: index },
  });

  it('accepts 100 mutations and rejects 101 mutations', async () => {
    // 100 mutations accepted
    const payload100 = {
      device_id: 'dev-1',
      batch_id: 'batch-1',
      mutations: Array.from({ length: 100 }, (_, i) => createMutation(i)),
    };
    const dto100 = plainToInstance(SyncPushDto, payload100);
    const errors100 = await validate(dto100);
    expect(errors100.length).toBe(0);

    // 101 mutations rejected
    const payload101 = {
      device_id: 'dev-1',
      batch_id: 'batch-1',
      mutations: Array.from({ length: 101 }, (_, i) => createMutation(i)),
    };
    const dto101 = plainToInstance(SyncPushDto, payload101);
    const errors101 = await validate(dto101);
    expect(errors101.length).toBeGreaterThan(0);
    const mutationError = errors101.find((err) => err.property === 'mutations');
    expect(mutationError).toBeDefined();
    expect(mutationError?.constraints).toHaveProperty('arrayMaxSize');
  });
});
