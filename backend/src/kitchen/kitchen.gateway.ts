import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';
import * as crypto from 'crypto';

/**
 * Standard Canonical Realtime Event Envelope (§9.2)
 * All WebSocket frames emitted follow this notification-only format.
 */
export interface RealtimeEventEnvelope<T = Record<string, unknown>> {
  event_id: string;        // UUID v4 for deduplication
  event_name: string;      // Lowercase dot-separated: 'order.created'
  entity: string;          // Target database table: 'orders'
  entity_id: string;       // Primary Key UUID
  action: 'CREATED' | 'UPDATED' | 'DELETED' | 'STATUS_CHANGED';
  version: number;         // OCC integer version token
  change_seq: number;      // Store-scoped monotonic sequence number
  occurred_at: string;     // ISO 8601 UTC timestamp
  origin_device_id: string;// Terminal ID e.g. 'POS-P1'
  origin_user_id: string;  // Staff user UUID
  store_id: string;        // Multi-tenant store code
  payload: T;              // Lightweight metadata (no PII, no large trees)
}

export interface KitchenOrderEventPayload {
  orderId: string;
  orderNumber: string;
  tokenNumber?: string | null;
  orderType: string;
  orderSource?: string;
  status: string;
  tableId?: string | null;
  tableName?: string | null;
  guestCount: number;
  waiterName?: string | null;
  customerName?: string | null;
  customerPhone?: string | null;
  deliveryAddress?: string | null;
  kitchenTicketSent: boolean;
  cookingTimeMinutes?: number | null;
  estimatedReadyAt?: Date | string | null;
  createdAt: Date | string;
  items: Array<{
    id: string;
    menuItemId?: string | null;
    itemName: string;
    quantity: number;
    selectedSize: string;
    selectedCrust: string;
    extraToppings?: string;
    notes?: string;
    unitPrice: number;
    totalPrice: number;
  }>;
}

@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: '/',
})
export class KitchenGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(KitchenGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  afterInit() {
    this.logger.log('Socket.IO Gateway initialized for Kitchen / KDS real-time events');
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth?.token ||
        client.handshake.headers?.authorization?.replace('Bearer ', '');

      if (!token) {
        this.logger.warn(`Socket connection rejected: No token provided (${client.id})`);
        client.disconnect(true);
        return;
      }

      const secret =
        this.configService.get<string>('JWT_SECRET') || 'hungry-howies-pos-dev-secret-key-2026';
      const payload = this.jwtService.verify(token, { secret });
      client.data.user = payload;

      // Automatically join the general kitchen room and partitioned store rooms (§9.3)
      await client.join('kitchen');
      const storeId = payload.store_id || 'DEFAULT';
      await client.join(`store:${storeId}:all`);
      if (payload.role === 'owner' || payload.role === 'admin' || payload.role === 'manager') {
        await client.join(`store:${storeId}:owner`);
      } else {
        await client.join(`store:${storeId}:cashier`);
      }

      this.logger.log(
        `Client authenticated and connected to Kitchen Gateway: ${client.id} (User: ${payload.username || payload.sub}, Store: ${storeId})`,
      );
    } catch (err: unknown) {
      this.logger.warn(`Socket connection unauthorized: ${(err as Error).message} (${client.id})`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected from Kitchen Gateway: ${client.id}`);
  }

  @SubscribeMessage('join_kitchen')
  handleJoinKitchen(client: Socket): { status: string; room: string } {
    client.join('kitchen');
    return { status: 'joined', room: 'kitchen' };
  }

  @SubscribeMessage('leave_kitchen')
  handleLeaveKitchen(client: Socket): { status: string; room: string } {
    client.leave('kitchen');
    return { status: 'left', room: 'kitchen' };
  }

  @SubscribeMessage('join_store')
  handleJoinStore(client: Socket, storeId: string): { status: string; store: string } {
    client.join(`store:${storeId}:all`);
    client.join(`store:${storeId}:cashier`);
    return { status: 'joined', store: storeId };
  }

  formatOrderPayload(order: Record<string, unknown>): KitchenOrderEventPayload {
    const onlineDetail = order.online_detail as Record<string, unknown> | undefined;
    const takeawayDetail = order.takeaway_detail as Record<string, unknown> | undefined;
    const dineInDetail = order.dine_in_detail as Record<string, unknown> | undefined;

    const table = (dineInDetail?.table || order.table) as { id?: string; name?: string } | undefined;
    const customer = order.customer as { full_name?: string; phone?: string } | undefined;
    const items = (order.order_items as Array<Record<string, unknown>>) || [];

    const tokenNumber = takeawayDetail?.token_number
      ? String(takeawayDetail.token_number)
      : order.token_number
        ? String(order.token_number)
        : null;

    const customerName =
      (onlineDetail?.customer_name as string) ||
      (takeawayDetail?.customer_name as string) ||
      (order.customer_name as string) ||
      customer?.full_name ||
      null;

    const customerPhone =
      (onlineDetail?.customer_phone as string) ||
      (takeawayDetail?.customer_phone as string) ||
      (order.customer_phone as string) ||
      customer?.phone ||
      null;

    const deliveryAddress = (onlineDetail?.delivery_address as string) || (order.delivery_address as string) || null;
    const tableId = dineInDetail?.table_id ? String(dineInDetail.table_id) : order.table_id ? String(order.table_id) : null;
    const guestCount = dineInDetail?.guest_count ? Number(dineInDetail.guest_count) : Number(order.guest_count) || 1;
    const waiterName = dineInDetail?.waiter_name ? String(dineInDetail.waiter_name) : order.waiter_name ? String(order.waiter_name) : null;

    return {
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      tokenNumber,
      orderType: String(order.order_type),
      orderSource: order.order_source ? String(order.order_source) : undefined,
      status: String(order.status),
      tableId,
      tableName: table?.name || null,
      guestCount,
      waiterName,
      customerName,
      customerPhone,
      deliveryAddress,
      kitchenTicketSent: Boolean(order.kitchen_ticket_sent),
      cookingTimeMinutes: order.cooking_time_minutes ? Number(order.cooking_time_minutes) : null,
      estimatedReadyAt: order.estimated_ready_at as Date | string | null,
      createdAt: order.created_at as Date | string,
      items: items.map((item) => ({
        id: String(item.id),
        menuItemId: item.menu_item_id ? String(item.menu_item_id) : null,
        itemName: String(item.item_name),
        quantity: Number(item.quantity),
        selectedSize: String(item.selected_size),
        selectedCrust: String(item.selected_crust),
        extraToppings: item.extra_toppings ? String(item.extra_toppings) : undefined,
        notes: item.notes ? String(item.notes) : undefined,
        unitPrice: Number(item.unit_price),
        totalPrice: Number(item.total_price),
      })),
    };
  }

  /**
   * Factory for creating canonical RealtimeEventEnvelope instances (§9.2)
   */
  createEnvelope<T = Record<string, unknown>>(params: {
    eventName: string;
    entity: string;
    entityId: string;
    action: 'CREATED' | 'UPDATED' | 'DELETED' | 'STATUS_CHANGED';
    version?: number;
    changeSeq?: number;
    originDeviceId?: string;
    originUserId?: string;
    storeId?: string;
    payload: T;
  }): RealtimeEventEnvelope<T> {
    return {
      event_id: crypto.randomUUID(),
      event_name: params.eventName,
      entity: params.entity,
      entity_id: params.entityId,
      action: params.action,
      version: params.version ?? 1,
      change_seq: params.changeSeq ?? 0,
      occurred_at: new Date().toISOString(),
      origin_device_id: params.originDeviceId || 'POS-P1',
      origin_user_id: params.originUserId || 'SYSTEM',
      store_id: params.storeId || 'DEFAULT',
      payload: params.payload,
    };
  }

  /**
   * Broadcast canonical envelope to partitioned store rooms and kitchen room (§9.3, §9.4)
   */
  emitRealtimeEnvelope<T = Record<string, unknown>>(envelope: RealtimeEventEnvelope<T>) {
    if (!this.server) return;
    const storeId = envelope.store_id || 'DEFAULT';

    // Partitioned rooms
    this.server.to(`store:${storeId}:owner`).emit(envelope.event_name, envelope);
    this.server.to(`store:${storeId}:cashier`).emit(envelope.event_name, envelope);
    this.server.to(`store:${storeId}:all`).emit(envelope.event_name, envelope);
    this.server.to('kitchen').emit('realtime.event', envelope);
  }

  emitOrderCreated(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit for backwards compatibility with existing clients
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('order.created', payload);
    this.server.to('kitchen').emit('kitchen.order_created', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'order.created',
      entity: 'orders',
      entityId: String(order.id),
      action: 'CREATED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        orderType: String(order.order_type),
        status: String(order.status),
        grandTotal: Number(order.grand_total) || 0,
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Emitted order.created event for Order #${payload.orderNumber}`);
  }

  emitOrderUpdated(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('order.updated', payload);
    this.server.to('kitchen').emit('kitchen.order_updated', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'order.updated',
      entity: 'orders',
      entityId: String(order.id),
      action: 'UPDATED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        orderType: String(order.order_type),
        status: String(order.status),
        grandTotal: Number(order.grand_total) || 0,
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Emitted order.updated event for Order #${payload.orderNumber}`);
  }

  emitOrderStatusChanged(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('order.status_changed', payload);
    this.server.to('kitchen').emit('kitchen.status_changed', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'order.status_changed',
      entity: 'orders',
      entityId: String(order.id),
      action: 'STATUS_CHANGED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        status: String(order.status),
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(
      `Emitted order.status_changed (${payload.status}) for Order #${payload.orderNumber}`,
    );
  }

  emitOrderReady(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('order.ready', payload);
    this.server.to('kitchen').emit('kitchen.order_ready', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'order.ready',
      entity: 'orders',
      entityId: String(order.id),
      action: 'STATUS_CHANGED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        status: 'ready',
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Emitted order.ready for Order #${payload.orderNumber}`);
  }

  emitOrderCancelled(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('order.cancelled', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'order.cancelled',
      entity: 'orders',
      entityId: String(order.id),
      action: 'DELETED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        status: 'cancelled',
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Emitted order.cancelled for Order #${payload.orderNumber}`);
  }

  emitKitchenTicketSent(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    // 1. Legacy emit
    const payload = this.formatOrderPayload(order);
    this.server.to('kitchen').emit('kitchen.ticket_sent', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');
    const envelope = this.createEnvelope({
      eventName: 'kitchen.ticket_sent',
      entity: 'orders',
      entityId: String(order.id),
      action: 'UPDATED',
      version: Number((order as any).version) || 1,
      changeSeq: Number((order as any).change_seq) || 0,
      originDeviceId: String((order as any).device_id || 'POS-P1'),
      originUserId: String((order as any).user_id || 'SYSTEM'),
      storeId: effectiveStoreId,
      payload: {
        orderId: String(order.id),
        orderNumber: String(order.order_number),
        kitchenTicketSent: true,
      },
    });
    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Emitted kitchen.ticket_sent for Order #${payload.orderNumber}`);
  }
}
