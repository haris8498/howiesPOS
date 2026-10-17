import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { RidersController } from './riders.controller';
import { RidersService } from './riders.service';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

describe('RidersController', () => {
  let controller: RidersController;

  const mockRider = {
    id: 'r-1',
    name: 'Dave Speedster',
    phone: '+1 555 9012',
    is_available: true,
    is_clocked_in: true,
    active_deliveries_count: 0,
    total_completed_deliveries: 48,
    avg_delivery_time_mins: new Prisma.Decimal(22.5),
    rating: new Prisma.Decimal(4.8),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [RidersController],
      providers: [
        {
          provide: RidersService,
          useValue: {
            listRiders: jest.fn().mockResolvedValue([mockRider]),
            getRiderById: jest.fn().mockResolvedValue(mockRider),
            createRider: jest.fn().mockResolvedValue(mockRider),
            updateRider: jest.fn().mockResolvedValue({ ...mockRider, name: 'Dave Updated' }),
            toggleRiderDuty: jest.fn().mockResolvedValue({ ...mockRider, is_clocked_in: false }),
            deleteRider: jest
              .fn()
              .mockResolvedValue({ message: 'Delivery rider deleted successfully' }),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<RidersController>(RidersController);
  });

  it('should return all riders', async () => {
    const response = await controller.listRiders({});
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });

  it('should return rider by id', async () => {
    const response = await controller.getRiderById('r-1');
    expect(response.success).toBe(true);
    expect(response.data!.id).toBe('r-1');
  });

  it('should create rider', async () => {
    const response = await controller.createRider({
      name: 'Dave Speedster',
      phone: '+1 555 9012',
    });
    expect(response.success).toBe(true);
    expect(response.data!.name).toBe('Dave Speedster');
  });

  it('should update rider', async () => {
    const response = await controller.updateRider('r-1', {
      name: 'Dave Updated',
    });
    expect(response.success).toBe(true);
    expect(response.data!.name).toBe('Dave Updated');
  });

  it('should toggle rider duty', async () => {
    const response = await controller.toggleRiderDuty('r-1', { is_clocked_in: false });
    expect(response.success).toBe(true);
    expect(response.data!.is_clocked_in).toBe(false);
  });

  it('should delete rider', async () => {
    const response = await controller.deleteRider('r-1');
    expect(response.success).toBe(true);
    expect(response.message).toContain('deleted successfully');
  });
});
