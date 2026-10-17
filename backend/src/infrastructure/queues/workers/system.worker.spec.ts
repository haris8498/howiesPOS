import { Test, TestingModule } from '@nestjs/testing';
import { SystemWorker } from './system.worker';
import { RedisService } from '../../redis/redis.service';

describe('SystemWorker', () => {
  let worker: SystemWorker;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SystemWorker,
        {
          provide: RedisService,
          useValue: {
            getConnectionOptions: jest.fn().mockReturnValue({
              host: 'localhost',
              port: 6379,
              retryStrategy: () => null,
            }),
          },
        },
      ],
    }).compile();

    worker = module.get<SystemWorker>(SystemWorker);
  });

  it('should be defined', () => {
    expect(worker).toBeDefined();
  });

  it('should process job payload safely', async () => {
    const mockJob = {
      id: 'job-1',
      name: 'ping-job',
      data: {
        type: 'PING',
      },
    } as unknown as Parameters<typeof worker.processJob>[0];

    const result = await worker.processJob(mockJob);
    expect(result.success).toBe(true);
  });

  it('should process AUDIT_LOG job payload safely', async () => {
    const mockJob = {
      id: 'job-2',
      name: 'audit-job',
      data: {
        type: 'AUDIT_LOG',
        orderId: 'ord-123',
      },
    } as unknown as Parameters<typeof worker.processJob>[0];

    const result = await worker.processJob(mockJob);
    expect(result.success).toBe(true);
  });

  it('should close worker gracefully on module destroy', async () => {
    await expect(worker.onModuleDestroy()).resolves.not.toThrow();
  });
});
