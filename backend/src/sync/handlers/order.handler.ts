import {
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  SyncEntityHandler,
  SyncMutationContext,
  SyncMutationResult,
} from './sync-entity.handler';
import { HandlerRegistry } from './handler-registry.service';
import { OrdersService } from '../../orders/orders.service';
import { ChangeLogService } from '../change-log.service';
import { SyncMutationDto } from '../dto/sync-push.dto';
import { CreateOrderDto } from '../../orders/dto/create-order.dto';

@Injectable()
export class OrderHandler implements SyncEntityHandler, OnModuleInit {
  readonly entityType = 'order';
  private readonly logger = new Logger(OrderHandler.name);

  constructor(
    private readonly handlerRegistry: HandlerRegistry,
    private readonly ordersService: OrdersService,
    private readonly changeLogService: ChangeLogService,
  ) {}

  onModuleInit() {
    this.handlerRegistry.register(this);
  }

  async handle(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const opType = (mutation.operation_type || 'INSERT').toUpperCase();

    switch (opType) {
      case 'INSERT':
        return this.handleInsert(tx, mutation, context);
      case 'UPDATE':
        return this.handleUpdate(tx, mutation, context);
      case 'DELETE':
        return this.handleDelete(tx, mutation, context);
      default:
        return {
          operation_id: mutation.operation_id,
          entity_id: mutation.entity_id,
          status: 'FAILED_FATAL',
          server_version: mutation.base_version ?? 1,
          server_timestamp: new Date().toISOString(),
          error_message: `Unsupported operation_type '${mutation.operation_type}' for order`,
        };
    }
  }

  private async handleInsert(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const orderId = mutation.entity_id;
    const payload = mutation.payload || {};

    // 1. Check if order with this UUID already exists (Idempotent / Duplicate)
    const existingOrder = await tx.order.findUnique({
      where: { id: orderId },
      include: {
        order_items: true,
        payments: true,
      },
    });

    if (existingOrder) {
      this.logger.log(`Order ${orderId} already exists in database — returning DUPLICATE`);
      const v = (existingOrder as any).version ?? 1;
      const ts = (
        (existingOrder as any).updated_at ||
        existingOrder.created_at ||
        new Date()
      ).toISOString();
      return {
        operation_id: mutation.operation_id,
        entity_id: existingOrder.id,
        status: 'DUPLICATE',
        server_version: v,
        server_timestamp: ts,
      };
    }

    // 2. Map payload into CreateOrderDto preserving client IDs
    const createDto: CreateOrderDto = {
      id: orderId,
      order_number: payload.order_number,
      client_order_number: payload.client_order_number || payload.order_number,
      order_type: payload.order_type || 'dineIn',
      shift_id: payload.shift_id,
      status: payload.status ?? 'newOrder',
      subtotal: payload.subtotal !== undefined ? Number(payload.subtotal) : undefined,
      discount_percentage:
        payload.discount_percentage !== undefined
          ? Number(payload.discount_percentage)
          : undefined,
      discount_amount:
        payload.discount_amount !== undefined
          ? Number(payload.discount_amount)
          : undefined,
      tax_amount:
        payload.tax_amount !== undefined ? Number(payload.tax_amount) : undefined,
      dine_in_tax:
        payload.dine_in_tax !== undefined ? Number(payload.dine_in_tax) : undefined,
      delivery_fee:
        payload.delivery_fee !== undefined ? Number(payload.delivery_fee) : undefined,
      grand_total:
        payload.grand_total !== undefined ? Number(payload.grand_total) : undefined,
      payment_status: payload.payment_status,
      payment_method: payload.payment_method,
      is_paid: payload.is_paid,
      is_held: payload.is_held,
      kitchen_ticket_sent: payload.kitchen_ticket_sent,
      rejection_reason: payload.rejection_reason,
      cooking_time_minutes: payload.cooking_time_minutes,
      estimated_ready_at: payload.estimated_ready_at,
      table_id: payload.table_id,
      guest_count: payload.guest_count,
      waiter_name: payload.waiter_name,
      customer_id: payload.customer_id,
      customer_name: payload.customer_name,
      customer_phone: payload.customer_phone,
      delivery_address: payload.delivery_address,
      token_number: payload.token_number,
      items: (payload.items || []).map((item: any) => ({
        id: item.id,
        menu_item_id: item.menu_item_id,
        item_name: item.item_name || item.itemName || 'Item',
        quantity: item.quantity !== undefined ? Number(item.quantity) : 1,
        unit_price: item.unit_price !== undefined ? Number(item.unit_price) : 0,
        total_price: item.total_price !== undefined ? Number(item.total_price) : undefined,
        category: item.category,
        selected_size:
          item.selected_size || item.size_name || item.sizeName || 'Regular',
        selected_crust:
          item.selected_crust || item.selectedCrust || 'Original',
        extra_toppings: item.extra_toppings || item.extraToppings || '',
        notes: item.notes || '',
        is_cancelled: item.is_cancelled,
        cancel_reason: item.cancel_reason,
        cancelled_by: item.cancelled_by,
        cancelled_at: item.cancelled_at,
      })),
      payments: (payload.payments || []).map((p: any) => ({
        id: p.id,
        payment_method: p.payment_method || p.paymentMethod || 'cash',
        amount: Number(p.amount) || 0,
        tendered_amount:
          p.tendered_amount !== undefined ? Number(p.tendered_amount) : undefined,
        change_returned:
          p.change_returned !== undefined ? Number(p.change_returned) : undefined,
        transaction_reference: p.transaction_reference || p.transactionReference,
        card_last_four: p.card_last_four || p.cardLastFour,
        bank_name: p.bank_name || p.bankName,
        payment_status: p.payment_status || p.paymentStatus || 'COMPLETED',
        notes: p.notes,
        received_by: p.received_by || p.receivedBy,
      })),
    };

    // 3. Delegate to ordersService.createOrderInTx
    const createdOrder = await this.ordersService.createOrderInTx(
      tx,
      createDto,
      orderId,
    );

    const version = (createdOrder as any).version ?? 1;
    const updatedAt =
      (createdOrder as any).updated_at || createdOrder.created_at || new Date();

    // 4. Record in system_change_logs inside the same transaction
    await this.changeLogService.record(
      tx,
      'order',
      createdOrder.id,
      'INSERT',
      version,
      {
        id: createdOrder.id,
        order_number: createdOrder.order_number,
        order_type: createdOrder.order_type,
        status: createdOrder.status,
        subtotal: Number(createdOrder.subtotal),
        grand_total: Number(createdOrder.grand_total),
        payment_status: createdOrder.payment_status,
        is_paid: createdOrder.is_paid,
        shift_id: createdOrder.shift_id,
        version,
        items_count: createdOrder.order_items?.length ?? 0,
        payments_count: createdOrder.payments?.length ?? 0,
        created_at: createdOrder.created_at,
        updated_at: updatedAt,
      },
      false,
    );

    const isReassigned = Boolean(
      (payload.order_number && createdOrder.order_number !== payload.order_number) ||
      (payload.token_number && createdOrder.takeaway_detail?.token_number !== payload.token_number),
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: createdOrder.id,
      status: isReassigned ? 'APPLIED' : 'SYNCED',
      server_version: version,
      server_timestamp: updatedAt.toISOString(),
      order_number: createdOrder.order_number,
      client_order_number: payload.order_number,
      token_number: createdOrder.takeaway_detail?.token_number,
    };
  }

  private async handleUpdate(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const orderId = mutation.entity_id;
    const payload = mutation.payload || {};

    const existingOrder = await tx.order.findUnique({
      where: { id: orderId },
      include: {
        order_items: true,
        payments: true,
      },
    });

    if (!existingOrder) {
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'FAILED_FATAL',
        server_version: 0,
        server_timestamp: new Date().toISOString(),
        error_message: `Order '${orderId}' not found for update`,
      };
    }

    const currentVersion = (existingOrder as any).version ?? 1;
    // Check OCC version
    if (
      mutation.base_version !== undefined &&
      currentVersion > mutation.base_version
    ) {
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'CONFLICT',
        server_version: currentVersion,
        server_timestamp: (
          (existingOrder as any).updated_at || new Date()
        ).toISOString(),
        conflict_details: {
          message:
            'OCC Version Conflict: Order has been modified on server',
          client_base_version: mutation.base_version,
          server_version: currentVersion,
        },
      };
    }

    const updated = await tx.order.update({
      where: { id: orderId },
      data: {
        ...(payload.status ? { status: payload.status } : {}),
        ...(payload.payment_status
          ? { payment_status: payload.payment_status }
          : {}),
        ...(payload.is_paid !== undefined ? { is_paid: payload.is_paid } : {}),
        ...(payload.is_held !== undefined ? { is_held: payload.is_held } : {}),
        ...(payload.rejection_reason
          ? { rejection_reason: payload.rejection_reason }
          : {}),
        version: { increment: 1 },
      } as any,
    });

    const newVersion = (updated as any).version ?? currentVersion + 1;
    const updatedAt = (updated as any).updated_at || new Date();

    await this.changeLogService.record(
      tx,
      'order',
      updated.id,
      'UPDATE',
      newVersion,
      {
        id: updated.id,
        order_number: updated.order_number,
        status: updated.status,
        payment_status: updated.payment_status,
        is_paid: updated.is_paid,
        version: newVersion,
        updated_at: updatedAt,
      },
      false,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: updated.id,
      status: 'SYNCED',
      server_version: newVersion,
      server_timestamp: updatedAt.toISOString(),
    };
  }

  private async handleDelete(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const orderId = mutation.entity_id;
    const existing = await tx.order.findUnique({ where: { id: orderId } });
    if (!existing) {
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'DUPLICATE',
        server_version: 0,
        server_timestamp: new Date().toISOString(),
      };
    }

    const updated = await tx.order.update({
      where: { id: orderId },
      data: {
        status: 'cancelled',
        rejection_reason:
          mutation.payload?.rejection_reason || 'Cancelled via sync',
        version: { increment: 1 },
      } as any,
    });

    const newVersion = (updated as any).version ?? 2;
    const updatedAt = (updated as any).updated_at || new Date();

    await this.changeLogService.record(
      tx,
      'order',
      updated.id,
      'DELETE',
      newVersion,
      {
        id: updated.id,
        status: updated.status,
        rejection_reason: updated.rejection_reason,
        version: newVersion,
      },
      true,
    );

    return {
      operation_id: mutation.operation_id,
      entity_id: updated.id,
      status: 'SYNCED',
      server_version: newVersion,
      server_timestamp: updatedAt.toISOString(),
    };
  }
}
