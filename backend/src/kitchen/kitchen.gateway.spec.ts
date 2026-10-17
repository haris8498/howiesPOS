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

  describe('RealtimeEventEnvelope (§9.2, §9.3, §9.4)', () => {
    it('should create valid RealtimeEventEnvelope with UUID v4 and ISO timestamp', () => {
      const envelope = gateway.createEnvelope({
        eventName: 'order.created',
        entity: 'orders',
        entityId: 'ord-101',
        action: 'CREATED',
        version: 1,
        storeId: 'STORE-1',
        originDeviceId: 'POS-P1',
        payload: { orderNumber: 'P1-101' },
      });

      expect(envelope.event_id).toBeDefined();
      expect(envelope.event_id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
      expect(envelope.event_name).toBe('order.created');
      expect(envelope.entity).toBe('orders');
      expect(envelope.entity_id).toBe('ord-101');
      expect(envelope.action).toBe('CREATED');
      expect(envelope.version).toBe(1);
      expect(envelope.store_id).toBe('STORE-1');
      expect(envelope.origin_device_id).toBe('POS-P1');
      expect(envelope.occurred_at).toBeDefined();
      expect(envelope.payload).toEqual({ orderNumber: 'P1-101' });
    });

    it('should broadcast envelope to partitioned owner, cashier, all rooms and kitchen', () => {
      gateway.emitOrderCreated(mockOrder, 'STORE-1');

      expect(mockServer.to).toHaveBeenCalledWith('store:STORE-1:owner');
      expect(mockServer.to).toHaveBeenCalledWith('store:STORE-1:cashier');
      expect(mockServer.to).toHaveBeenCalledWith('store:STORE-1:all');
      expect(mockServer.to).toHaveBeenCalledWith('kitchen');

      expect(mockServer.emit).toHaveBeenCalledWith(
        'order.created',
        expect.objectContaining({
          event_id: expect.any(String),
          event_name: 'order.created',
          entity: 'orders',
          entity_id: 'ord-101',
          action: 'CREATED',
        }),
      );
    });

    it('should join partitioned rooms on join_store subscription', () => {
      const mockClient = {
        join: jest.fn(),
      } as any;

      const res = gateway.handleJoinStore(mockClient, 'STORE-123');
      expect(mockClient.join).toHaveBeenCalledWith('store:STORE-123:all');
      expect(mockClient.join).toHaveBeenCalledWith('store:STORE-123:cashier');
      expect(res).toEqual({ status: 'joined', store: 'STORE-123' });
    });
  });
});
