import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server } from 'socket.io';
import { KitchenGateway } from './kitchen.gateway';

describe('KitchenGateway', () => {
  let gateway: KitchenGateway;

  const mockServer = {
    to: jest.fn().mockReturnThis(),
    emit: jest.fn(),
  };

  const mockOrder = {
    id: 'ord-101',
    order_number: 'ORD-101',
    token_number: 'TK-12',
    order_type: 'takeAway',
    status: 'preparing',
    guest_count: 1,
    kitchen_ticket_sent: true,
    created_at: new Date('2026-09-26T22:00:00Z'),
    order_items: [
      {
        id: 'item-1',
        item_name: 'Hawaiian Pizza',
        quantity: 1,
        selected_size: 'Medium',
        selected_crust: 'Original',
        unit_price: 12.5,
        total_price: 12.5,
      },
    ],
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        KitchenGateway,
        {
          provide: JwtService,
          useValue: {
            verify: jest.fn().mockReturnValue({ sub: 'user-1', username: 'chef' }),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn().mockReturnValue('test-secret'),
          },
        },
      ],
    }).compile();

    gateway = module.get<KitchenGateway>(KitchenGateway);
    gateway.server = mockServer as unknown as Server;
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });

  it('should format order payload properly', () => {
    const payload = gateway.formatOrderPayload(mockOrder);
    expect(payload.orderId).toBe('ord-101');
    expect(payload.orderNumber).toBe('ORD-101');
    expect(payload.items.length).toBe(1);
    expect(payload.items[0].itemName).toBe('Hawaiian Pizza');
  });

  it('should emit order.created event', () => {
    gateway.emitOrderCreated(mockOrder);
    expect(mockServer.to).toHaveBeenCalledWith('kitchen');
    expect(mockServer.emit).toHaveBeenCalledWith(
      'order.created',
      expect.objectContaining({ orderId: 'ord-101' }),
    );
  });

  it('should emit order.status_changed event', () => {
    gateway.emitOrderStatusChanged(mockOrder);
    expect(mockServer.to).toHaveBeenCalledWith('kitchen');
    expect(mockServer.emit).toHaveBeenCalledWith(
      'order.status_changed',
      expect.objectContaining({ orderId: 'ord-101' }),
    );
  });

  it('should emit order.ready event', () => {
    gateway.emitOrderReady(mockOrder);
    expect(mockServer.to).toHaveBeenCalledWith('kitchen');
    expect(mockServer.emit).toHaveBeenCalledWith(
      'order.ready',
      expect.objectContaining({ orderId: 'ord-101' }),
    );
  });

  it('should emit order.cancelled event', () => {
    gateway.emitOrderCancelled(mockOrder);
    expect(mockServer.to).toHaveBeenCalledWith('kitchen');
    expect(mockServer.emit).toHaveBeenCalledWith(
      'order.cancelled',
      expect.objectContaining({ orderId: 'ord-101' }),
    );
  });

  it('should emit kitchen.ticket_sent event', () => {
    gateway.emitKitchenTicketSent(mockOrder);
    expect(mockServer.to).toHaveBeenCalledWith('kitchen');
    expect(mockServer.emit).toHaveBeenCalledWith(
      'kitchen.ticket_sent',
      expect.objectContaining({ orderId: 'ord-101' }),
    );
  });
});
