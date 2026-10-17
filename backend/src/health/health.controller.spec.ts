import { Test, TestingModule } from '@nestjs/testing';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';
import { PrismaService } from '../prisma/prisma.service';

describe('HealthController', () => {
  let controller: HealthController;
  let mockPrismaService: Partial<PrismaService>;

  beforeEach(async () => {
    mockPrismaService = {
      isHealthy: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        HealthService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return health status with database connected', async () => {
    const result = await controller.check();
    expect(result.success).toBe(true);
    expect(result.status).toBe('ok');
    expect(result.service).toBe('hungry-howies-pos-api');
    expect(result.database).toBe('connected');
    expect(result.timestamp).toBeDefined();
  });
});
