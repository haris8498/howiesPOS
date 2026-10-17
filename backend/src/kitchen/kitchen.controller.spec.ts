import { Test, TestingModule } from '@nestjs/testing';
import { KitchenController } from './kitchen.controller';
import { KitchenService } from './kitchen.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('KitchenController', () => {
  let controller: KitchenController;

  const mockOrder = {
    id: 'ord-101',
    order_number: 'ORD-101',
    token_number: 'TK-12',
    order_type: 'takeAway',
    status: 'preparing',
    order_items: [],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [KitchenController],
      providers: [
        {
          provide: KitchenService,
          useValue: {
            getKitchenOrders: jest.fn().mockResolvedValue([mockOrder]),
            getKitchenOrderById: jest.fn().mockResolvedValue(mockOrder),
            updateStatus: jest.fn().mockResolvedValue({ ...mockOrder, status: 'ready' }),
            updateCookingTime: jest
              .fn()
              .mockResolvedValue({ ...mockOrder, cooking_time_minutes: 25 }),
            sendKitchenTicket: jest
              .fn()
              .mockResolvedValue({ ...mockOrder, kitchen_ticket_sent: true }),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    controller = module.get<KitchenController>(KitchenController);
  });

  it('should return kitchen orders', async () => {
    const result = await controller.getKitchenOrders({});
    expect(result.success).toBe(true);
    expect(result.data.length).toBe(1);
  });

  it('should return order by id', async () => {
    const result = await controller.getKitchenOrderById('ord-101');
    expect(result.success).toBe(true);
    expect(result.data.id).toBe('ord-101');
  });

  it('should update order status', async () => {
    const result = await controller.updateStatus('ord-101', { status: 'ready' });
    expect(result.success).toBe(true);
    expect(result.data.status).toBe('ready');
  });

  it('should update cooking time', async () => {
    const result = await controller.updateCookingTime('ord-101', { cooking_time_minutes: 25 });
    expect(result.success).toBe(true);
    expect(result.data.cooking_time_minutes).toBe(25);
  });

  it('should send kitchen ticket', async () => {
    const result = await controller.sendKitchenTicket('ord-101');
    expect(result.success).toBe(true);
    expect(result.data.kitchen_ticket_sent).toBe(true);
  });
});
