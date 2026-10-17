import { Test, TestingModule } from '@nestjs/testing';
import { QueueService } from './queue.service';
import { RedisService } from '../redis/redis.service';

describe('QueueService', () => {
  let service: QueueService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QueueService,
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

    service = module.get<QueueService>(QueueService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should report health check safely', async () => {
    const healthy = await service.isHealthy();
    expect(typeof healthy).toBe('boolean');
  });

  it('should handle adding system job when queue is not ready or fails safely', async () => {
    const job = await service.addSystemJob('test-job', { type: 'PING' });
    // Either enqueued or safely returned null without throwing uncaught exception
    expect(job === null || typeof job === 'object').toBe(true);
  });

  it('should close queues on module destroy gracefully', async () => {
    await expect(service.onModuleDestroy()).resolves.not.toThrow();
  });
});
