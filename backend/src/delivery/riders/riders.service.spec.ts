import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { DeliveryRider, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RidersService } from './riders.service';

describe('RidersService', () => {
  let service: RidersService;

  const mockRider: DeliveryRider = {
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

  const mockBusyRider: DeliveryRider = {
    id: 'r-2',
    name: 'Chris Rider',
    phone: '+1 555 3456',
    is_available: true,
    is_clocked_in: true,
    active_deliveries_count: 2,
    total_completed_deliveries: 105,
    avg_delivery_time_mins: new Prisma.Decimal(19.0),
    rating: new Prisma.Decimal(4.9),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RidersService,
        {
          provide: PrismaService,
          useValue: {
            deliveryRider: {
              findMany: jest.fn().mockResolvedValue([mockRider, mockBusyRider]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'r-1' || where.phone === '+1 555 9012') {
                  return Promise.resolve({ ...mockRider, dispatches: [] });
                }
                if (where.id === 'r-2' || where.phone === '+1 555 3456') {
                  return Promise.resolve({ ...mockBusyRider, dispatches: [{ id: 'disp-1' }] });
                }
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'r-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ where, data }) =>
                Promise.resolve({
                  ...(where.id === 'r-2' ? mockBusyRider : mockRider),
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockRider),
            },
          },
        },
      ],
    }).compile();

    service = module.get<RidersService>(RidersService);
  });

  it('should list all riders', async () => {
    const riders = await service.listRiders();
    expect(riders).toHaveLength(2);
    expect(riders[0].name).toBe('Dave Speedster');
  });

  it('should list riders with search query', async () => {
    const riders = await service.listRiders({ search: 'Dave' });
    expect(riders).toHaveLength(2);
  });

  it('should get rider by id', async () => {
    const rider = await service.getRiderById('r-1');
    expect(rider.id).toBe('r-1');
    expect(rider.name).toBe('Dave Speedster');
  });

  it('should throw NotFoundException for invalid rider id', async () => {
    await expect(service.getRiderById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should register a new rider', async () => {
    const newRider = await service.createRider({
      name: 'Michael Fast',
      phone: '+1 555 7777',
      is_available: true,
      is_clocked_in: true,
    });
    expect(newRider.name).toBe('Michael Fast');
    expect(newRider.phone).toBe('+1 555 7777');
    expect(newRider.active_deliveries_count).toBe(0);
  });

  it('should throw ConflictException on duplicate rider phone', async () => {
    await expect(
      service.createRider({
        name: 'Duplicate Dave',
        phone: '+1 555 9012',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should update rider details', async () => {
    const updated = await service.updateRider('r-1', {
      name: 'Dave Champion',
    });
    expect(updated.name).toBe('Dave Champion');
  });

  it('should toggle rider duty clock-in/out', async () => {
    const toggled = await service.toggleRiderDuty('r-1', { is_clocked_in: false });
    expect(toggled.is_clocked_in).toBe(false);
  });

  it('should delete rider with no active assignments', async () => {
    const result = await service.deleteRider('r-1');
    expect(result.message).toContain('deleted successfully');
  });

  it('should throw BadRequestException when deleting a rider with active dispatches', async () => {
    await expect(service.deleteRider('r-2')).rejects.toThrow(BadRequestException);
  });
});
