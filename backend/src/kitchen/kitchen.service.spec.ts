import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { KitchenService } from './kitchen.service';
import { KitchenGateway } from './kitchen.gateway';

describe('KitchenService', () => {
  let service: KitchenService;
  let gateway: KitchenGateway;

  const mockOrder = {
    id: 'ord-101',
    order_number: 'ORD-101',
    token_number: 'TK-12',
    order_type: 'takeAway',
    status: 'preparing',
    guest_count: 1,
    kitchen_ticket_sent: false,
    cooking_time_minutes: 15,
    estimated_ready_at: new Date('2026-09-26T22:30:00Z'),
    created_at: new Date('2026-09-26T22:00:00Z'),
    order_items: [
      {
        id: 'item-1',
        item_name: 'Pepperoni Pizza',
        quantity: 2,
        selected_size: 'Large',
        selected_crust: 'Butter Cheese',
        unit_price: 15.99,
        total_price: 31.98,
      },
    ],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        KitchenService,
        {
          provide: PrismaService,
          useValue: {
            order: {
              findMany: jest.fn().mockResolvedValue([mockOrder]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'ord-101') return Promise.resolve(mockOrder);
                return Promise.resolve(null);
              }),
              update: jest.fn().mockImplementation(({ data }) => {
                return Promise.resolve({
                  ...mockOrder,
                  ...data,
                });
              }),
            },
          },
        },
        {
          provide: KitchenGateway,
          useValue: {
            emitOrderCreated: jest.fn(),
            emitOrderUpdated: jest.fn(),
            emitOrderStatusChanged: jest.fn(),
            emitOrderReady: jest.fn(),
            emitOrderCancelled: jest.fn(),
            emitKitchenTicketSent: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<KitchenService>(KitchenService);
    gateway = module.get<KitchenGateway>(KitchenGateway);
  });

  it('should get kitchen orders', async () => {
    const orders = await service.getKitchenOrders();
    expect(orders).toBeDefined();
    expect(orders.length).toBe(1);
    expect(orders[0].order_number).toBe('ORD-101');
  });

  it('should get a single kitchen order by id', async () => {
    const order = await service.getKitchenOrderById('ord-101');
    expect(order.id).toBe('ord-101');
  });

  it('should throw NotFoundException if order does not exist', async () => {
    await expect(service.getKitchenOrderById('invalid-id')).rejects.toThrow(NotFoundException);
  });

  it('should update status and emit events', async () => {
    const updated = await service.updateStatus('ord-101', { status: 'ready' });
    expect(updated.status).toBe('ready');
    expect(gateway.emitOrderStatusChanged).toHaveBeenCalled();
    expect(gateway.emitOrderReady).toHaveBeenCalled();
  });

  it('should update cooking time and calculate ETA', async () => {
    const updated = await service.updateCookingTime('ord-101', {
      cooking_time_minutes: 20,
    });
    expect(updated.cooking_time_minutes).toBe(20);
    expect(gateway.emitOrderUpdated).toHaveBeenCalled();
  });

  it('should send kitchen ticket and emit event', async () => {
    const updated = await service.sendKitchenTicket('ord-101');
    expect(updated.kitchen_ticket_sent).toBe(true);
    expect(gateway.emitKitchenTicketSent).toHaveBeenCalled();
  });
});
