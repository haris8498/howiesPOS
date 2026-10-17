import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { DispatchesService } from './dispatches.service';

describe('DispatchesService', () => {
  let service: DispatchesService;

  const mockOrder = {
    id: 'ord-1',
    order_number: 'ORD-1001',
    order_type: 'delivery',
    status: 'newOrder',
    delivery_dispatch: null,
    order_items: [],
    customer: null,
  };

  const mockNonDeliveryOrder = {
    id: 'ord-2',
    order_number: 'ORD-1002',
    order_type: 'dineIn',
    status: 'newOrder',
    delivery_dispatch: null,
    order_items: [],
    customer: null,
  };

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

  const mockNewRider = {
    id: 'r-2',
    name: 'Chris Rider',
    phone: '+1 555 3456',
    is_available: true,
    is_clocked_in: true,
    active_deliveries_count: 1,
    total_completed_deliveries: 10,
    avg_delivery_time_mins: new Prisma.Decimal(20.0),
    rating: new Prisma.Decimal(5.0),
  };

  const mockOffDutyRider = {
    id: 'r-off',
    name: 'Off Duty Rider',
    phone: '+1 555 9999',
    is_available: false,
    is_clocked_in: false,
    active_deliveries_count: 0,
    total_completed_deliveries: 10,
    avg_delivery_time_mins: new Prisma.Decimal(25.0),
    rating: new Prisma.Decimal(4.5),
  };

  const mockOnlineOrderDetail = {
    id: 'ood-1',
    order_id: 'ord-1',
    customer_id: null,
    order_source: 'Direct Delivery',
    delivery_address: '123 Main St',
    delivery_notes: null,
    driver_notes: null,
    estimated_delivery_time: new Date('2026-09-26T21:00:00Z'),
    delivered_at: null,
    tracking_url: null,
    order: mockOrder,
    delivery_dispatch: null,
  };

  const mockDispatch = {
    id: 'disp-1',
    online_order_detail_id: 'ood-1',
    rider_id: 'r-1',
    dispatch_status: 'pending',
    estimated_delivery_time: new Date('2026-09-26T21:00:00Z'),
    dispatched_at: null,
    delivered_at: null,
    online_order_detail: {
      ...mockOnlineOrderDetail,
      order: mockOrder,
    },
    rider: mockRider,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DispatchesService,
        {
          provide: PrismaService,
          useValue: {
            deliveryDispatch: {
              findMany: jest.fn().mockResolvedValue([mockDispatch]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'disp-1' || where.online_order_detail_id === 'ood-1') {
                  return Promise.resolve(mockDispatch);
                }
                return Promise.resolve(null);
              }),
            },
            onlineOrderDetail: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'ood-1') return Promise.resolve(mockOnlineOrderDetail);
                if (where.order_id === 'ord-1') {
                  return Promise.resolve({
                    ...mockOnlineOrderDetail,
                    delivery_dispatch: { id: 'disp-1' },
                  });
                }
                if (where.order_id === 'ord-create') {
                  return Promise.resolve({
                    ...mockOnlineOrderDetail,
                    order_id: 'ord-create',
                    delivery_dispatch: null,
                  });
                }
                if (where.order_id === 'ord-dup') {
                  return Promise.resolve({
                    ...mockOnlineOrderDetail,
                    id: 'ood-dup',
                    delivery_dispatch: mockDispatch,
                  });
                }
                return Promise.resolve(null);
              }),
            },
            order: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'ord-1') return Promise.resolve(mockOrder);
                if (where.id === 'ord-2') return Promise.resolve(mockNonDeliveryOrder);
                if (where.id === 'ord-dup') {
                  return Promise.resolve({
                    ...mockOrder,
                    id: 'ord-dup',
                    delivery_dispatch: mockDispatch,
                  });
                }
                return Promise.resolve(null);
              }),
            },
            deliveryRider: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'r-1') return Promise.resolve(mockRider);
                if (where.id === 'r-2') return Promise.resolve(mockNewRider);
                if (where.id === 'r-off') return Promise.resolve(mockOffDutyRider);
                return Promise.resolve(null);
              }),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                deliveryDispatch: {
                  findUnique: jest.fn().mockResolvedValue(mockDispatch),
                  findUniqueOrThrow: jest.fn().mockResolvedValue(mockDispatch),
                  create: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      id: 'disp-new',
                      ...data,
                      online_order_detail: {
                        ...mockOnlineOrderDetail,
                        order: mockOrder,
                      },
                      rider: mockRider,
                    }),
                  ),
                  update: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      ...mockDispatch,
                      ...data,
                    }),
                  ),
                  delete: jest.fn().mockResolvedValue(mockDispatch),
                },
                deliveryRider: {
                  findUnique: jest.fn().mockImplementation(({ where }) => {
                    if (where.id === 'r-1') return Promise.resolve(mockRider);
                    if (where.id === 'r-2') return Promise.resolve(mockNewRider);
                    if (where.id === 'r-off') return Promise.resolve(mockOffDutyRider);
                    return Promise.resolve(null);
                  }),
                  update: jest.fn().mockResolvedValue(mockRider),
                },
                order: {
                  update: jest.fn().mockResolvedValue(mockOrder),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<DispatchesService>(DispatchesService);
  });

  it('should list all delivery dispatches', async () => {
    const list = await service.listDispatches();
    expect(list).toHaveLength(1);
    expect(list[0].id).toBe('disp-1');
  });

  it('should get dispatch by id', async () => {
    const dispatch = await service.getDispatchById('disp-1');
    expect(dispatch.id).toBe('disp-1');
  });

  it('should get dispatch by order id', async () => {
    const dispatch = await service.getDispatchByOrderId('ord-1');
    expect(dispatch.id).toBe('disp-1');
  });

  it('should create a dispatch for valid delivery order', async () => {
    const created = await service.createDispatch({
      order_id: 'ord-create',
      rider_id: 'r-1',
    });
    expect(created.id).toBe('disp-new');
  });

  it('should reject dispatch for non-delivery order type', async () => {
    await expect(
      service.createDispatch({
        order_id: 'ord-2',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('should reject duplicate dispatch for the same order', async () => {
    await expect(
      service.createDispatch({
        order_id: 'ord-dup',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should reject assigning an off-duty rider during dispatch creation', async () => {
    await expect(
      service.createDispatch({
        order_id: 'ord-create',
        rider_id: 'r-off',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should assign a rider and update dispatch status', async () => {
    const updated = await service.assignRider('disp-1', {
      rider_id: 'r-2',
    });
    expect(updated.dispatch_status).toBe('outForDelivery');
  });

  it('should update dispatch status to delivered', async () => {
    const delivered = await service.updateDispatchStatus('disp-1', {
      dispatch_status: 'delivered',
    });
    expect(delivered.dispatch_status).toBe('delivered');
  });

  it('should delete a dispatch record', async () => {
    const result = await service.deleteDispatch('disp-1');
    expect(result.message).toContain('deleted successfully');
  });
});
