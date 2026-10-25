import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Injectable, Logger } from '@nestjs/common';
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
  event_name: string;      // Lowercase dot or colon separated: 'order.created' or 'order:created'
  entity: string;          // Target database table: 'orders', 'menu', 'tables', etc.
  entity_id: string;       // Primary Key UUID or identifier
  action: 'CREATED' | 'UPDATED' | 'DELETED' | 'STATUS_CHANGED';
  version: number;         // OCC integer version token
  change_seq: number;      // Store-scoped monotonic sequence number
  occurred_at: string;     // ISO 8601 UTC timestamp
  origin_device_id: string;// Terminal ID e.g. 'POS-P1'
  origin_user_id: string;  // Staff user UUID
  store_id: string;        // Multi-tenant store code
  payload: T;              // Metadata / record payload
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

@Injectable()
@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: '/',
})
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  afterInit() {
    this.logger.log('Realtime Gateway initialized on namespace "/" for multi-client POS synchronization');
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        client.handshake.auth?.token ||
        (client.handshake.query?.token as string) ||
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

      const storeId = payload.store_id || 'DEFAULT';
      const role = (payload.role || 'cashier').toLowerCase();

      // Automatically join general and partitioned rooms (§9.3)
      await client.join('authenticated');
      await client.join('pos');
      await client.join('kitchen');
      await client.join(`store:${storeId}:all`);

      if (role === 'owner' || role === 'admin' || role === 'manager') {
        await client.join(`store:${storeId}:owner`);
      } else {
        await client.join(`store:${storeId}:cashier`);
      }

      this.logger.log(
        `Client authenticated and connected to Realtime Gateway: ${client.id} (User: ${payload.username || payload.sub}, Role: ${role}, Store: ${storeId})`,
      );

      client.emit('connected', {
        status: 'authenticated',
        socketId: client.id,
        user: payload.username || payload.sub,
        storeId,
      });
    } catch (err: unknown) {
      this.logger.warn(`Socket connection unauthorized: ${(err as Error).message} (${client.id})`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const user = client.data?.user;
    const username = user?.username || user?.sub || 'anonymous';
    this.logger.log(`Client disconnected from Realtime Gateway: ${client.id} (${username})`);
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

  @SubscribeMessage('join_pos')
  handleJoinPos(client: Socket): { status: string; room: string } {
    client.join('pos');
    return { status: 'joined', room: 'pos' };
  }

  @SubscribeMessage('join_store')
  handleJoinStore(client: Socket, storeId: string): { status: string; store: string } {
    client.join(`store:${storeId}:all`);
    client.join(`store:${storeId}:cashier`);
    return { status: 'joined', store: storeId };
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
   * Broadcast canonical envelope to partitioned store rooms and general rooms (§9.3, §9.4)
   */
  emitRealtimeEnvelope<T = Record<string, unknown>>(envelope: RealtimeEventEnvelope<T>) {
    if (!this.server) return;
    const storeId = envelope.store_id || 'DEFAULT';

    // Partitioned rooms
    this.server.to(`store:${storeId}:owner`).emit(envelope.event_name, envelope);
    this.server.to(`store:${storeId}:cashier`).emit(envelope.event_name, envelope);
    this.server.to(`store:${storeId}:all`).emit(envelope.event_name, envelope);
    this.server.to('kitchen').emit('realtime.event', envelope);
    this.server.to('pos').emit('realtime.event', envelope);
    this.server.emit('realtime:event', envelope);
  }

  /**
   * Universal broadcast method that emits both colon-separated and dot-separated event names,
   * broadcasting to all connected POS clients as well as store-scoped rooms.
   */
  broadcastEvent<T = Record<string, unknown>>(params: {
    eventName: string; // e.g. 'table:updated'
    alternateEventName?: string; // e.g. 'table.updated'
    entity: string;
    entityId?: string;
    action: 'CREATED' | 'UPDATED' | 'DELETED' | 'STATUS_CHANGED';
    payload: T;
    storeId?: string;
  }) {
    if (!this.server) return;
    const storeId = params.storeId || 'DEFAULT';
    const entityId = params.entityId || String((params.payload as any)?.id || '0');

    const envelope = this.createEnvelope({
      eventName: params.eventName,
      entity: params.entity,
      entityId,
      action: params.action,
      storeId,
      payload: params.payload,
    });

    const eventNames = [params.eventName];
    if (params.alternateEventName) {
      eventNames.push(params.alternateEventName);
    } else {
      if (params.eventName.includes(':')) {
        eventNames.push(params.eventName.replace(/:/g, '.'));
      } else if (params.eventName.includes('.')) {
        eventNames.push(params.eventName.replace(/\./g, ':'));
      }
    }

    for (const name of eventNames) {
      this.server.emit(name, params.payload);
      this.server.to(`store:${storeId}:all`).emit(name, params.payload);
      this.server.to('pos').emit(name, params.payload);
      this.server.to('kitchen').emit(name, params.payload);
    }

    this.emitRealtimeEnvelope(envelope);

    this.logger.log(`Broadcasted [${eventNames.join(' / ')}] on entity '${params.entity}' (id: ${entityId})`);
  }

  // ---------------------------------------------------------------------------
  // ORDER REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

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

  emitOrderCreated(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy direct emits
    this.server.to('kitchen').emit('order.created', payload);
    this.server.to('kitchen').emit('kitchen.order_created', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    // 3. Global POS broadcast
    const posPayload = {
      ...payload,
      id: String(order.id),
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      orderType: String(order.order_type),
      status: String(order.status),
      grandTotal: Number(order.grand_total) || 0,
    };
    this.server.emit('order:created', posPayload);
    this.server.to('pos').emit('order:created', posPayload);
    this.server.to(`store:${effectiveStoreId}:all`).emit('order:created', posPayload);

    this.logger.log(`Emitted order.created event for Order #${payload.orderNumber}`);
  }

  emitOrderUpdated(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy emit
    this.server.to('kitchen').emit('order.updated', payload);
    this.server.to('kitchen').emit('kitchen.order_updated', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    // 3. Global POS broadcast
    const posPayload = {
      ...payload,
      id: String(order.id),
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      orderType: String(order.order_type),
      status: String(order.status),
      grandTotal: Number(order.grand_total) || 0,
    };
    this.server.emit('order:updated', posPayload);
    this.server.to('pos').emit('order:updated', posPayload);
    this.server.to(`store:${effectiveStoreId}:all`).emit('order:updated', posPayload);

    this.logger.log(`Emitted order.updated event for Order #${payload.orderNumber}`);
  }

  emitOrderStatusChanged(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy emit
    this.server.to('kitchen').emit('order.status_changed', payload);
    this.server.to('kitchen').emit('kitchen.status_changed', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    // 3. Global POS broadcast
    const posPayload = {
      ...payload,
      id: String(order.id),
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      status: String(order.status),
    };
    this.server.emit('order:status_changed', posPayload);
    this.server.to('pos').emit('order:status_changed', posPayload);
    this.server.to(`store:${effectiveStoreId}:all`).emit('order:status_changed', posPayload);

    this.logger.log(`Emitted order.status_changed (${payload.status}) for Order #${payload.orderNumber}`);
  }

  emitOrderReady(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy emit
    this.server.to('kitchen').emit('order.ready', payload);
    this.server.to('kitchen').emit('kitchen.order_ready', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    const posPayload = {
      ...payload,
      id: String(order.id),
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      status: 'ready',
    };
    this.server.emit('order:ready', posPayload);
    this.server.to('pos').emit('order:ready', posPayload);
    this.server.to(`store:${effectiveStoreId}:all`).emit('order:ready', posPayload);

    this.logger.log(`Emitted order.ready for Order #${payload.orderNumber}`);
  }

  emitOrderCancelled(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy emit
    this.server.to('kitchen').emit('order.cancelled', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    const posPayload = {
      ...payload,
      id: String(order.id),
      orderId: String(order.id),
      orderNumber: String(order.order_number),
      status: 'cancelled',
    };
    this.server.emit('order:cancelled', posPayload);
    this.server.to('pos').emit('order:cancelled', posPayload);
    this.server.to(`store:${effectiveStoreId}:all`).emit('order:cancelled', posPayload);

    this.logger.log(`Emitted order.cancelled for Order #${payload.orderNumber}`);
  }

  emitKitchenTicketSent(order: Record<string, unknown>, storeId?: string) {
    if (!this.server) return;
    const payload = this.formatOrderPayload(order);
    const effectiveStoreId = String((order as any).store_id || storeId || 'DEFAULT');

    // 1. Kitchen legacy emit
    this.server.to('kitchen').emit('kitchen.ticket_sent', payload);

    // 2. Canonical RealtimeEventEnvelope broadcast (§9.2, §9.4)
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

    this.server.emit('kitchen:ticket_sent', payload);
    this.server.to('pos').emit('kitchen:ticket_sent', payload);

    this.logger.log(`Emitted kitchen.ticket_sent for Order #${payload.orderNumber}`);
  }

  // ---------------------------------------------------------------------------
  // MENU / CATALOG REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitCategoryCreated(category: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'category:created',
      entity: 'menu_categories',
      entityId: String(category.id),
      action: 'CREATED',
      payload: category,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(category.id),
      action: 'UPDATED',
      payload: { type: 'category', action: 'created', item: category },
    });
  }

  emitCategoryUpdated(category: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'category:updated',
      entity: 'menu_categories',
      entityId: String(category.id),
      action: 'UPDATED',
      payload: category,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(category.id),
      action: 'UPDATED',
      payload: { type: 'category', action: 'updated', item: category },
    });
  }

  emitCategoryDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'category:deleted',
      entity: 'menu_categories',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: id,
      action: 'UPDATED',
      payload: { type: 'category', action: 'deleted', id },
    });
  }

  emitMenuItemCreated(item: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'menu:item_created',
      alternateEventName: 'menu.item_created',
      entity: 'menu_items',
      entityId: String(item.id),
      action: 'CREATED',
      payload: item,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: { type: 'item', action: 'created', item },
    });
  }

  emitMenuItemUpdated(item: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'menu:item_updated',
      alternateEventName: 'menu.item_updated',
      entity: 'menu_items',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: item,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: { type: 'item', action: 'updated', item },
    });
  }

  emitMenuItemDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'menu:item_deleted',
      alternateEventName: 'menu.item_deleted',
      entity: 'menu_items',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: id,
      action: 'UPDATED',
      payload: { type: 'item', action: 'deleted', id },
    });
  }

  emitDealCreated(deal: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'deal:created',
      entity: 'deals',
      entityId: String(deal.id),
      action: 'CREATED',
      payload: deal,
    });
    this.broadcastEvent({
      eventName: 'deal:updated',
      entity: 'deals',
      entityId: String(deal.id),
      action: 'UPDATED',
      payload: deal,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(deal.id),
      action: 'UPDATED',
      payload: { type: 'deal', action: 'created', deal },
    });
  }

  emitDealUpdated(deal: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'deal:updated',
      entity: 'deals',
      entityId: String(deal.id),
      action: 'UPDATED',
      payload: deal,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(deal.id),
      action: 'UPDATED',
      payload: { type: 'deal', action: 'updated', deal },
    });
  }

  emitDealDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'deal:deleted',
      entity: 'deals',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: id,
      action: 'UPDATED',
      payload: { type: 'deal', action: 'deleted', id },
    });
  }

  emitSizeOrOptionUpdated(type: 'size' | 'option', payload: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: `menu:${type}_updated`,
      entity: 'menu',
      entityId: String(payload.id || '0'),
      action: 'UPDATED',
      payload,
    });
    this.broadcastEvent({
      eventName: 'menu:updated',
      entity: 'menu',
      entityId: String(payload.id || '0'),
      action: 'UPDATED',
      payload: { type, action: 'updated', item: payload },
    });
  }

  // ---------------------------------------------------------------------------
  // TABLES REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitTableCreated(table: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'table:created',
      entity: 'tables',
      entityId: String(table.id),
      action: 'CREATED',
      payload: table,
    });
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: String(table.id),
      action: 'UPDATED',
      payload: table,
    });
  }

  emitTableUpdated(table: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: String(table.id),
      action: 'UPDATED',
      payload: table,
    });
  }

  emitTableStatusChanged(table: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'table:status_changed',
      alternateEventName: 'table.status_changed',
      entity: 'tables',
      entityId: String(table.id),
      action: 'STATUS_CHANGED',
      payload: table,
    });
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: String(table.id),
      action: 'UPDATED',
      payload: table,
    });
  }

  emitTableTransferred(payload: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'table:transferred',
      entity: 'tables',
      entityId: String(payload.fromTableId || payload.from_table_id || '0'),
      action: 'UPDATED',
      payload,
    });
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: String(payload.fromTableId || '0'),
      action: 'UPDATED',
      payload,
    });
  }

  emitTableDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'table:deleted',
      entity: 'tables',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
  }

  emitZoneChanged(action: 'created' | 'deleted', zone: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: `table:zone_${action}`,
      entity: 'floor_zones',
      entityId: String(zone.id || zone.name || '0'),
      action: action === 'created' ? 'CREATED' : 'DELETED',
      payload: zone,
    });
    this.broadcastEvent({
      eventName: 'table:updated',
      entity: 'tables',
      entityId: String(zone.id || '0'),
      action: 'UPDATED',
      payload: { zone, action },
    });
  }

  // ---------------------------------------------------------------------------
  // STAFF & USERS & PERMISSIONS REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitStaffCreated(staff: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'staff:created',
      entity: 'staff_members',
      entityId: String(staff.id),
      action: 'CREATED',
      payload: staff,
    });
    this.broadcastEvent({
      eventName: 'staff:updated',
      entity: 'staff_members',
      entityId: String(staff.id),
      action: 'UPDATED',
      payload: staff,
    });
  }

  emitStaffUpdated(staff: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'staff:updated',
      entity: 'staff_members',
      entityId: String(staff.id),
      action: 'UPDATED',
      payload: staff,
    });
  }

  emitStaffDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'staff:deleted',
      entity: 'staff_members',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'staff:updated',
      entity: 'staff_members',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
  }

  emitUserUpdated(user: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'user:updated',
      entity: 'staff_users',
      entityId: String(user.id),
      action: 'UPDATED',
      payload: user,
    });
    this.broadcastEvent({
      eventName: 'staff:updated',
      entity: 'staff_members',
      entityId: String(user.id),
      action: 'UPDATED',
      payload: user,
    });
  }

  emitPermissionUpdated(permission: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'permission:updated',
      entity: 'role_permissions',
      entityId: String(permission.id || 'all'),
      action: 'UPDATED',
      payload: permission,
    });
  }

  // ---------------------------------------------------------------------------
  // DELIVERY & RIDERS REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitRiderCreated(rider: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'rider:created',
      entity: 'delivery_riders',
      entityId: String(rider.id),
      action: 'CREATED',
      payload: rider,
    });
    this.broadcastEvent({
      eventName: 'rider:updated',
      entity: 'delivery_riders',
      entityId: String(rider.id),
      action: 'UPDATED',
      payload: rider,
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: String(rider.id),
      action: 'UPDATED',
      payload: { type: 'rider', rider },
    });
  }

  emitRiderUpdated(rider: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'rider:updated',
      entity: 'delivery_riders',
      entityId: String(rider.id),
      action: 'UPDATED',
      payload: rider,
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: String(rider.id),
      action: 'UPDATED',
      payload: { type: 'rider', rider },
    });
  }

  emitRiderDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'rider:deleted',
      entity: 'delivery_riders',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: id,
      action: 'DELETED',
      payload: { type: 'rider', id },
    });
  }

  emitDispatchCreated(dispatch: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'delivery:dispatch_created',
      entity: 'delivery_dispatches',
      entityId: String(dispatch.id),
      action: 'CREATED',
      payload: dispatch,
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: String(dispatch.id),
      action: 'UPDATED',
      payload: { type: 'dispatch', dispatch },
    });
  }

  emitDispatchUpdated(dispatch: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'delivery:status_changed',
      entity: 'delivery_dispatches',
      entityId: String(dispatch.id),
      action: 'STATUS_CHANGED',
      payload: dispatch,
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: String(dispatch.id),
      action: 'UPDATED',
      payload: { type: 'dispatch', dispatch },
    });
  }

  emitDispatchDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'delivery:dispatch_deleted',
      entity: 'delivery_dispatches',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'delivery:updated',
      entity: 'delivery',
      entityId: id,
      action: 'DELETED',
      payload: { type: 'dispatch', id },
    });
  }

  // ---------------------------------------------------------------------------
  // SHIFTS / DAILY CALCULATION REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitShiftStarted(session: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'shift:started',
      entity: 'daily_calculations',
      entityId: String(session.id),
      action: 'CREATED',
      payload: session,
    });
    this.broadcastEvent({
      eventName: 'shift:updated',
      entity: 'daily_calculations',
      entityId: String(session.id),
      action: 'UPDATED',
      payload: session,
    });
  }

  emitShiftClosed(session: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'shift:closed',
      entity: 'daily_calculations',
      entityId: String(session.id),
      action: 'STATUS_CHANGED',
      payload: session,
    });
    this.broadcastEvent({
      eventName: 'shift:updated',
      entity: 'daily_calculations',
      entityId: String(session.id),
      action: 'UPDATED',
      payload: session,
    });
  }

  emitShiftUpdated(session: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'shift:updated',
      entity: 'daily_calculations',
      entityId: String(session.id),
      action: 'UPDATED',
      payload: session,
    });
  }

  // ---------------------------------------------------------------------------
  // STORE SETTINGS REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitSettingsUpdated(settings: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'settings:updated',
      alternateEventName: 'settings.updated',
      entity: 'store_settings',
      entityId: String(settings.id || '1'),
      action: 'UPDATED',
      payload: settings,
    });
  }

  // ---------------------------------------------------------------------------
  // INVENTORY REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitInventoryItemCreated(item: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'inventory:item_created',
      entity: 'inventory_items',
      entityId: String(item.id),
      action: 'CREATED',
      payload: item,
    });
    this.broadcastEvent({
      eventName: 'inventory:updated',
      entity: 'inventory',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: item,
    });
  }

  emitInventoryItemUpdated(item: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'inventory:item_updated',
      entity: 'inventory_items',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: item,
    });
    this.broadcastEvent({
      eventName: 'inventory:updated',
      entity: 'inventory',
      entityId: String(item.id),
      action: 'UPDATED',
      payload: item,
    });
  }

  emitInventoryItemDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'inventory:item_deleted',
      entity: 'inventory_items',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'inventory:updated',
      entity: 'inventory',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
  }

  emitStockMovementRecorded(movement: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'inventory:stock_movement',
      entity: 'stock_movements',
      entityId: String(movement.id),
      action: 'CREATED',
      payload: movement,
    });
    this.broadcastEvent({
      eventName: 'inventory:updated',
      entity: 'inventory',
      entityId: String(movement.item_id || '0'),
      action: 'UPDATED',
      payload: movement,
    });
  }

  // ---------------------------------------------------------------------------
  // EXPENSES REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitExpenseCreated(expense: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'expense:created',
      entity: 'expenses',
      entityId: String(expense.id),
      action: 'CREATED',
      payload: expense,
    });
    this.broadcastEvent({
      eventName: 'expense:updated',
      entity: 'expenses',
      entityId: String(expense.id),
      action: 'UPDATED',
      payload: expense,
    });
    this.broadcastEvent({
      eventName: 'shift:updated',
      entity: 'daily_calculations',
      entityId: String(expense.id),
      action: 'UPDATED',
      payload: { type: 'expense', expense },
    });
  }

  emitExpenseUpdated(expense: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'expense:updated',
      entity: 'expenses',
      entityId: String(expense.id),
      action: 'UPDATED',
      payload: expense,
    });
    this.broadcastEvent({
      eventName: 'shift:updated',
      entity: 'daily_calculations',
      entityId: String(expense.id),
      action: 'UPDATED',
      payload: { type: 'expense', expense },
    });
  }

  emitExpenseDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'expense:deleted',
      entity: 'expenses',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'expense:updated',
      entity: 'expenses',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
  }

  // ---------------------------------------------------------------------------
  // CUSTOMERS REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitCustomerCreated(customer: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'customer:created',
      entity: 'customers',
      entityId: String(customer.id),
      action: 'CREATED',
      payload: customer,
    });
    this.broadcastEvent({
      eventName: 'customer:updated',
      entity: 'customers',
      entityId: String(customer.id),
      action: 'UPDATED',
      payload: customer,
    });
  }

  emitCustomerUpdated(customer: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'customer:updated',
      entity: 'customers',
      entityId: String(customer.id),
      action: 'UPDATED',
      payload: customer,
    });
  }

  emitCustomerDeleted(id: string) {
    this.broadcastEvent({
      eventName: 'customer:deleted',
      entity: 'customers',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
    this.broadcastEvent({
      eventName: 'customer:updated',
      entity: 'customers',
      entityId: id,
      action: 'DELETED',
      payload: { id },
    });
  }

  // ---------------------------------------------------------------------------
  // SYNC CENTER REAL-TIME BROADCASTS
  // ---------------------------------------------------------------------------

  emitSyncStatusUpdated(statusPayload: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'sync:status_updated',
      entity: 'sync',
      entityId: 'global',
      action: 'UPDATED',
      payload: statusPayload,
    });
  }

  emitSyncOutboxUpdated(outboxPayload: Record<string, unknown>) {
    this.broadcastEvent({
      eventName: 'sync:outbox_updated',
      entity: 'sync',
      entityId: 'global',
      action: 'UPDATED',
      payload: outboxPayload,
    });
  }
}
