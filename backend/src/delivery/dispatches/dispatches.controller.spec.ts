import { Test, TestingModule } from '@nestjs/testing';
import { DispatchesController } from './dispatches.controller';
import { DispatchesService } from './dispatches.service';
import { PermissionsGuard } from '../../common/rbac/guards/permissions.guard';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

describe('DispatchesController', () => {
  let controller: DispatchesController;

  const mockDispatch = {
    id: 'disp-1',
    order_id: 'ord-1',
    rider_id: 'r-1',
    dispatch_status: 'pending',
    estimated_delivery_time: new Date('2026-09-26T21:00:00Z'),
    dispatched_at: null,
    delivered_at: null,
    order: { id: 'ord-1', order_number: 'ORD-1001', order_items: [], customer: null },
    rider: { id: 'r-1', name: 'Dave Speedster' },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [DispatchesController],
      providers: [
        {
          provide: DispatchesService,
          useValue: {
            listDispatches: jest.fn().mockResolvedValue([mockDispatch]),
            getDispatchById: jest.fn().mockResolvedValue(mockDispatch),
            getDispatchByOrderId: jest.fn().mockResolvedValue(mockDispatch),
            createDispatch: jest.fn().mockResolvedValue(mockDispatch),
            assignRider: jest.fn().mockResolvedValue({
              ...mockDispatch,
              rider_id: 'r-2',
              dispatch_status: 'outForDelivery',
            }),
            updateDispatchStatus: jest
              .fn()
              .mockResolvedValue({ ...mockDispatch, dispatch_status: 'delivered' }),
            deleteDispatch: jest
              .fn()
              .mockResolvedValue({ message: 'Delivery dispatch record deleted successfully' }),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<DispatchesController>(DispatchesController);
  });

  it('should return list of dispatches', async () => {
    const response = await controller.listDispatches({});
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
  });

  it('should return dispatch by id', async () => {
    const response = await controller.getDispatchById('disp-1');
    expect(response.success).toBe(true);
    expect(response.data!.id).toBe('disp-1');
  });

  it('should return dispatch by order id', async () => {
    const response = await controller.getDispatchByOrderId('ord-1');
    expect(response.success).toBe(true);
    expect(response.data!.id).toBe('disp-1');
  });

  it('should create dispatch', async () => {
    const response = await controller.createDispatch({
      order_id: 'ord-1',
    });
    expect(response.success).toBe(true);
    expect(response.data!.id).toBe('disp-1');
  });

  it('should assign rider to dispatch', async () => {
    const response = await controller.assignRider('disp-1', {
      rider_id: 'r-2',
    });
    expect(response.success).toBe(true);
    expect(response.data!.rider_id).toBe('r-2');
  });

  it('should update dispatch status', async () => {
    const response = await controller.updateDispatchStatus('disp-1', {
      dispatch_status: 'delivered',
    });
    expect(response.success).toBe(true);
    expect(response.data!.dispatch_status).toBe('delivered');
  });

  it('should delete dispatch', async () => {
    const response = await controller.deleteDispatch('disp-1');
    expect(response.success).toBe(true);
    expect(response.message).toContain('deleted successfully');
  });
});
