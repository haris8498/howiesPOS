import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { RedisService } from './redis.service';

describe('RedisService', () => {
  let service: RedisService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RedisService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockImplementation((key: string) => {
              if (key === 'REDIS_HOST') return 'localhost';
              if (key === 'REDIS_PORT') return 6379;
              if (key === 'REDIS_PASSWORD') return '';
              return null;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<RedisService>(RedisService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should return connection options', () => {
    const opts = service.getConnectionOptions();
    expect(opts.host).toBe('localhost');
    expect(opts.port).toBe(6379);
  });

  it('should return health status safely without throwing if disconnected', async () => {
    const healthy = await service.isHealthy();
    expect(typeof healthy).toBe('boolean');
  });

  it('should handle get/set/del safely when disconnected', async () => {
    const val = await service.get('non-existing-key');
    expect(val).toBeNull();
    await expect(service.set('test-key', 'value', 60)).resolves.not.toThrow();
    await expect(service.del('test-key')).resolves.not.toThrow();
  });

  it('should handle onModuleDestroy gracefully', async () => {
    await expect(service.onModuleDestroy()).resolves.not.toThrow();
  });
});
