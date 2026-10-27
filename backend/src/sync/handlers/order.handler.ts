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
import { v7 as uuidv7 } from 'uuid';
import { CreateOrderDto, CreateOrderItemDto, CreateOrderPaymentDto } from '../../orders/dto/create-order.dto';

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
      case 'ITEM_ADD':
        return this.handleItemAdd(tx, mutation, context);
      case 'ITEM_VOID':
        return this.handleItemVoid(tx, mutation, context);
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

  // ---------------------------------------------------------------------------
  // Shared Calculation & Extraction Helpers
  // ---------------------------------------------------------------------------

  private round(val: number): number {
    return Math.round((val + Number.EPSILON) * 100) / 100;
  }

  private toIsoString(val: any): string {
    if (!val) return new Date().toISOString();
    if (val instanceof Date) return val.toISOString();
    try {
      const d = new Date(val);
      return isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
    } catch {
      return new Date().toISOString();
    }
  }

  private mapItems(items: any[]): CreateOrderItemDto[] {
    return (items || []).map((item: any) => ({
      id: item.id,
      menu_item_id: item.menu_item_id,
      item_name: item.item_name || item.itemName || 'Item',
      quantity: item.quantity !== undefined ? Number(item.quantity) : 1,
      unit_price: item.unit_price !== undefined ? Number(item.unit_price) : 0,
      total_price:
        item.total_price !== undefined
          ? Number(item.total_price)
          : this.round((Number(item.unit_price) || 0) * (Number(item.quantity) || 1)),
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
    }));
  }

  private mapPayments(payments: any[]): CreateOrderPaymentDto[] {
    return (payments || []).map((p: any) => ({
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
      created_at: p.created_at || p.createdAt,
    }));
  }

  private extractSubtotal(
    payload: any,
    items?: any[],
    existingOrder?: any,
  ): number {
    if (items && items.length > 0) {
      const activeItems = items.filter((i) => !i.is_cancelled);
      const calculated = activeItems.reduce(
        (sum: number, i: any) =>
          sum + this.round(Number(i.unit_price || 0) * Number(i.quantity || 1)),
        0,
      );
      if (payload.subtotal !== undefined) {
        return this.round(Number(payload.subtotal));
      }
      return this.round(calculated);
    }

    if (payload.subtotal !== undefined) {
      return this.round(Number(payload.subtotal));
    }

    if (existingOrder?.subtotal !== undefined) {
      return this.round(Number(existingOrder.subtotal));
    }

    return 0;
  }

  private extractDiscount(
    payload: any,
    subtotal: number,
    existingOrder?: any,
  ): { discountPercentage: number; discountAmount: number } {
    let discountAmount: number | undefined;
    let discountPercentage: number | undefined;

    if (payload.discount_amount !== undefined) {
      discountAmount = Number(payload.discount_amount);
    } else if (payload.discountAmount !== undefined) {
      discountAmount = Number(payload.discountAmount);
    } else if (payload.discounts !== undefined) {
      if (typeof payload.discounts === 'number') {
        discountAmount = Number(payload.discounts);
      } else if (Array.isArray(payload.discounts)) {
        discountAmount = payload.discounts.reduce(
          (sum: number, d: any) => sum + (Number(d.amount ?? d.value ?? 0) || 0),
          0,
        );
      } else if (typeof payload.discounts === 'object' && payload.discounts !== null) {
        discountAmount = Number(payload.discounts.amount ?? payload.discounts.value ?? 0);
      }
    }

    if (payload.discount_percentage !== undefined) {
      discountPercentage = Number(payload.discount_percentage);
    } else if (payload.discountPercentage !== undefined) {
      discountPercentage = Number(payload.discountPercentage);
    }

    if (discountAmount === undefined && existingOrder?.discount_amount !== undefined) {
      discountAmount = Number(existingOrder.discount_amount);
    }
    if (discountPercentage === undefined && existingOrder?.discount_percentage !== undefined) {
      discountPercentage = Number(existingOrder.discount_percentage);
    }

    let rawAmount = this.round(discountAmount ?? 0);
    let rawPct = this.round(discountPercentage ?? 0);

    if (rawPct > 0 && rawAmount === 0 && subtotal > 0) {
      rawAmount = this.round(subtotal * (rawPct / 100));
    } else if (rawAmount > 0 && rawPct === 0 && subtotal > 0) {
      rawPct = this.round((rawAmount / subtotal) * 100);
    }

    if (rawAmount > subtotal) {
      rawAmount = subtotal;
    }

    return {
      discountAmount: rawAmount,
      discountPercentage: rawPct,
    };
  }

  private extractTax(
    payload: any,
    orderType: string,
    existingOrder?: any,
  ): { taxAmount: number; dineInTax: number } {
    let taxAmount: number | undefined;

    if (payload.tax_amount !== undefined) {
      taxAmount = Number(payload.tax_amount);
    } else if (payload.taxAmount !== undefined) {
      taxAmount = Number(payload.taxAmount);
    } else if (payload.dine_in_tax !== undefined) {
      taxAmount = Number(payload.dine_in_tax);
    } else if (payload.dineInTax !== undefined) {
      taxAmount = Number(payload.dineInTax);
    } else if (payload.taxes !== undefined) {
      if (typeof payload.taxes === 'number') {
        taxAmount = Number(payload.taxes);
      } else if (Array.isArray(payload.taxes)) {
        taxAmount = payload.taxes.reduce(
          (sum: number, t: any) => sum + (Number(t.amount ?? t.value ?? 0) || 0),
          0,
        );
      } else if (typeof payload.taxes === 'object' && payload.taxes !== null) {
        taxAmount = Number(payload.taxes.amount ?? payload.taxes.value ?? 0);
      }
    }

    if (taxAmount === undefined && existingOrder?.tax_amount !== undefined) {
      taxAmount = Number(existingOrder.tax_amount);
    }

    const rawTax = this.round(taxAmount ?? 0);
    const normalizedType = (orderType || '').toLowerCase();
    const isOnline = normalizedType === 'online' || normalizedType === 'delivery';
    const isTakeaway = normalizedType === 'takeaway' || normalizedType === 'take_away';
    const isDineIn = !isOnline && !isTakeaway;
    const dineInTax = isDineIn ? rawTax : 0;

    return {
      taxAmount: rawTax,
      dineInTax,
    };
  }

  private extractDeliveryFee(
    payload: any,
    orderType: string,
    existingOrder?: any,
  ): number {
    const normalizedType = (orderType || '').toLowerCase();
    const isOnline = normalizedType === 'online' || normalizedType === 'delivery';
    if (!isOnline) return 0;

    if (payload.delivery_fee !== undefined) {
      return this.round(Number(payload.delivery_fee));
    }
    if (payload.deliveryFee !== undefined) {
      return this.round(Number(payload.deliveryFee));
    }
    if (existingOrder?.online_detail?.delivery_fee !== undefined) {
      return this.round(Number(existingOrder.online_detail.delivery_fee));
    }
    return 0;
  }

  private computeGrandTotal(
    subtotal: number,
    discountAmount: number,
    taxAmount: number,
    deliveryFee: number,
    payloadGrandTotal?: any,
  ): number {
    const calculated = this.round(
      subtotal - discountAmount + taxAmount + deliveryFee,
    );
    if (payloadGrandTotal !== undefined) {
      return this.round(Number(payloadGrandTotal));
    }
    return calculated;
  }

  // ---------------------------------------------------------------------------
  // INSERT MUTATION HANDLER
  // ---------------------------------------------------------------------------

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
      const ts = this.toIsoString(
        (existingOrder as any).updated_at || existingOrder.created_at,
      );
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
      created_at: payload.created_at || payload.createdAt,
      items: this.mapItems(payload.items),
      payments: this.mapPayments(payload.payments),
    };

    // 2.5 Check if referenced table is soft-deleted
    const targetTableId = payload.table_id || payload.dine_in_detail?.table_id;
    let isTableDeleted = false;
    if (targetTableId && tx.restaurantTable?.findFirst) {
      try {
        const tbl = await tx.restaurantTable.findFirst({
          where: {
            OR: [
              { id: targetTableId },
              { table_number: targetTableId },
              { name: targetTableId },
            ],
          },
          select: { id: true, is_deleted: true },
        });
        if (tbl && tbl.is_deleted) {
          isTableDeleted = true;
          this.logger.warn(
            `Order ${orderId} references soft-deleted table ${targetTableId} - accepting with TABLE_DELETED warning`,
          );
        }
      } catch (err) {
        this.logger.warn(`Failed to check table soft-delete status for table ${targetTableId}: ${err}`);
      }
    }

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
      server_timestamp: this.toIsoString(updatedAt),
      order_number: createdOrder.order_number,
      client_order_number: payload.order_number,
      reassigned_order_number: isReassigned ? createdOrder.order_number : undefined,
      reassigned_token_number: isReassigned ? createdOrder.takeaway_detail?.token_number : undefined,
      token_number: createdOrder.takeaway_detail?.token_number,
      warning_code: isTableDeleted ? 'TABLE_DELETED' : undefined,
      warnings: isTableDeleted ? ['TABLE_DELETED'] : undefined,
    };
  }

  // ---------------------------------------------------------------------------
  // UPDATE MUTATION HANDLER (SYNC-003 Fixed)
  // ---------------------------------------------------------------------------

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
        dine_in_detail: true,
        online_detail: true,
        takeaway_detail: true,
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
      // Check if this is an idempotent replay of an already-applied update
      const existingPayments = existingOrder.payments || [];
      const isReplay =
        currentVersion === mutation.base_version + 1 &&
        (!payload.status || existingOrder.status === payload.status) &&
        (payload.is_paid === undefined || existingOrder.is_paid === payload.is_paid) &&
        (!payload.payments ||
          payload.payments.every((p: any) =>
            existingPayments.some(
              (ep: any) =>
                (p.id && ep.id === p.id) ||
                (ep.payment_method === (p.payment_method || 'cash') &&
                  Number(ep.amount) === Number(p.amount)),
            ),
          ));

      if (isReplay) {
        this.logger.log(
          `Order update ${orderId} is an idempotent replay — returning DUPLICATE`,
        );
        return {
          operation_id: mutation.operation_id,
          entity_id: orderId,
          status: 'DUPLICATE',
          server_version: currentVersion,
          server_timestamp: this.toIsoString((existingOrder as any).updated_at),
        };
      }

      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'CONFLICT',
        server_version: currentVersion,
        server_timestamp: this.toIsoString((existingOrder as any).updated_at),
        conflict_details: {
          message:
            'OCC Version Conflict: Order has been modified on server',
          client_base_version: mutation.base_version,
          server_version: currentVersion,
        },
      };
    }

    const hasIncomingPayments =
      Array.isArray(payload.payments) && payload.payments.length > 0;
    const hasIncomingItems =
      Array.isArray(payload.items) && payload.items.length > 0;
    const hasFinancialUpdates =
      hasIncomingPayments ||
      hasIncomingItems ||
      payload.subtotal !== undefined ||
      payload.discount_amount !== undefined ||
      payload.discountAmount !== undefined ||
      payload.discounts !== undefined ||
      payload.discount_percentage !== undefined ||
      payload.discountPercentage !== undefined ||
      payload.tax_amount !== undefined ||
      payload.taxAmount !== undefined ||
      payload.dine_in_tax !== undefined ||
      payload.dineInTax !== undefined ||
      payload.taxes !== undefined ||
      payload.grand_total !== undefined ||
      payload.delivery_fee !== undefined ||
      payload.deliveryFee !== undefined;

    // 1. Recompute Financial Totals
    const orderType = payload.order_type || existingOrder.order_type || 'dineIn';
    const subtotal = this.extractSubtotal(payload, payload.items, existingOrder);
    const { discountAmount, discountPercentage } = this.extractDiscount(
      payload,
      subtotal,
      existingOrder,
    );
    const { taxAmount, dineInTax } = this.extractTax(
      payload,
      orderType,
      existingOrder,
    );
    const deliveryFee = this.extractDeliveryFee(payload, orderType, existingOrder);
    const orderTotal = this.computeGrandTotal(
      subtotal,
      discountAmount,
      taxAmount,
      deliveryFee,
      payload.grand_total,
    );

    // 2. Validate Payments
    const existingPayments = existingOrder.payments || [];
    const incomingPayments = hasIncomingPayments
      ? this.mapPayments(payload.payments)
      : [];

    const effectivePaymentTotal = hasIncomingPayments
      ? this.round(
          incomingPayments.reduce((sum, p) => sum + (Number(p.amount) || 0), 0),
        )
      : this.round(
          existingPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0),
        );

    const isPaidRequested =
      payload.is_paid === true ||
      payload.payment_status === 'PAID' ||
      payload.status === 'completed';

    // Server-side validation: sum(payments) must be >= order total for is_paid = true
    if (isPaidRequested && effectivePaymentTotal < orderTotal && orderTotal > 0) {
      this.logger.warn(
        `Order ${orderId} payment mismatch: payments (${effectivePaymentTotal}) < order total (${orderTotal})`,
      );
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'CONFLICT',
        server_version: currentVersion,
        server_timestamp: this.toIsoString((existingOrder as any).updated_at),
        conflict_details: {
          message: `Payment total mismatch: sum of payments (${effectivePaymentTotal}) is less than order total (${orderTotal})`,
          order_total: orderTotal,
          payments_total: effectivePaymentTotal,
        },
      };
    }

    // 3. Process Line Items with Append-Only Ledger Semantics (SYNC-032 / D-05)
    if (hasIncomingItems && tx.orderItem) {
      const fullReplace = payload.fullReplace === true || payload.full_replace === true;
      const currentItems = existingOrder.order_items || [];
      const currentItemsMap = new Map(currentItems.map((i: any) => [i.id, i]));
      const incomingItemIds = new Set<string>();

      for (const item of payload.items) {
        const itemName = item.item_name || item.itemName || 'Item';
        const quantity = item.quantity !== undefined ? Number(item.quantity) : 1;
        const unitPrice = item.unit_price !== undefined ? Number(item.unit_price) : 0;
        const totalPrice =
          item.total_price !== undefined
            ? Number(item.total_price)
            : this.round(unitPrice * quantity);

        let validMenuItemId: string | undefined = undefined;
        if (item.menu_item_id && tx.menuItem?.findUnique) {
          try {
            const mi = await tx.menuItem.findUnique({
              where: { id: item.menu_item_id },
            });
            if (mi) validMenuItemId = mi.id;
          } catch {
            validMenuItemId = undefined;
          }
        }

        if (item.id && currentItemsMap.has(item.id)) {
          incomingItemIds.add(item.id);
          const prev = currentItemsMap.get(item.id)!;
          const isVoidRequested = Boolean(
            item.is_cancelled === true ||
            item.voidedAt !== undefined ||
            item.voided_at !== undefined
          );
          const isDetailsChanged =
            (quantity !== undefined && quantity !== prev.quantity) ||
            (unitPrice !== undefined && Number(unitPrice) !== Number(prev.unit_price));

          if (isVoidRequested) {
            if (!prev.voidedAt && tx.orderItem.update) {
              const now = new Date();
              await tx.orderItem.update({
                where: { id: item.id },
                data: {
                  voidedAt: now,
                  voidedBy: item.cancelled_by || item.voided_by || item.voidedBy || 'sync',
                  is_cancelled: true,
                  cancelled_at: now,
                  cancel_reason: item.cancel_reason || 'Voided via sync',
                  cancelled_by: item.cancelled_by || item.voided_by || item.voidedBy || 'sync',
                },
              });
            }
          } else if (prev.voidedAt) {
            // Task 3: Void always wins over a live copy!
          } else if (isDetailsChanged) {
            // Task 3: Quantity change = new item with supersedesItemId + void of old one
            const now = new Date();
            if (tx.orderItem.update) {
              await tx.orderItem.update({
                where: { id: prev.id },
                data: {
                  voidedAt: now,
                  voidedBy: item.cancelled_by || item.voided_by || item.voidedBy || 'sync',
                  is_cancelled: true,
                  cancelled_at: now,
                  cancel_reason: item.cancel_reason || 'Superseded by updated item',
                  cancelled_by: item.cancelled_by || item.voided_by || item.voidedBy || 'sync',
                },
              });
            }

            const newId = uuidv7();
            if (tx.orderItem.create) {
              const createdNew = await tx.orderItem.create({
                data: {
                  id: newId,
                  order_id: orderId,
                  menu_item_id: validMenuItemId ?? prev.menu_item_id,
                  item_name: itemName,
                  quantity,
                  selected_size:
                    item.selected_size || item.size_name || item.sizeName || prev.selected_size || 'Regular',
                  selected_crust:
                    item.selected_crust || item.selectedCrust || prev.selected_crust || 'Original',
                  extra_toppings:
                    item.extra_toppings || item.extraToppings || prev.extra_toppings || '',
                  unit_price: new Prisma.Decimal(unitPrice),
                  total_price: new Prisma.Decimal(totalPrice),
                  notes: item.notes !== undefined ? item.notes : prev.notes,
                  is_cancelled: false,
                  voidedAt: null,
                  supersedesItemId: prev.id,
                  createdByDeviceId: item.createdByDeviceId || item.created_by_device_id || context.deviceId || null,
                  clientCreatedAt: new Date(),
                },
              });
              if (createdNew?.id) incomingItemIds.add(createdNew.id);
            }
          } else {
            // Active item unchanged
            if (item.notes !== undefined && item.notes !== prev.notes && tx.orderItem.update) {
              await tx.orderItem.update({
                where: { id: item.id },
                data: { notes: item.notes },
              });
            }
          }
        } else {
          // Task 1: Client generates UUID v7 ids for every new line item; server stores that id
          const itemId = item.id ? item.id : uuidv7();
          const isVoided = Boolean(item.is_cancelled || item.voidedAt || item.voided_at);
          if (tx.orderItem.create) {
            const createdItem = await tx.orderItem.create({
              data: {
                id: itemId,
                order_id: orderId,
                menu_item_id: validMenuItemId,
                item_name: itemName,
                quantity,
                selected_size:
                  item.selected_size || item.size_name || item.sizeName || 'Regular',
                selected_crust:
                  item.selected_crust || item.selectedCrust || 'Original',
                extra_toppings: item.extra_toppings || item.extraToppings || '',
                unit_price: new Prisma.Decimal(unitPrice),
                total_price: new Prisma.Decimal(totalPrice),
                notes: item.notes || '',
                is_cancelled: isVoided,
                cancelled_at: isVoided ? new Date() : null,
                cancel_reason: item.cancel_reason ?? null,
                cancelled_by: item.cancelled_by ?? null,
                voidedAt: isVoided ? new Date() : null,
                voidedBy: isVoided ? (item.cancelled_by || item.voided_by || 'sync') : null,
                supersedesItemId: item.supersedesItemId || item.supersedes_item_id || null,
                createdByDeviceId: item.createdByDeviceId || item.created_by_device_id || context.deviceId || null,
                clientCreatedAt: item.clientCreatedAt ? new Date(item.clientCreatedAt) : new Date(),
              },
            });
            if (createdItem?.id) incomingItemIds.add(createdItem.id);
          }
        }
      }

      // SYNC-032 / D-05: Items absent from the payload are NOT deleted unless explicit fullReplace: true
      if (fullReplace && tx.orderItem.update) {
        for (const existingItem of currentItems) {
          if (!incomingItemIds.has(existingItem.id) && !existingItem.voidedAt && !existingItem.is_cancelled) {
            const now = new Date();
            await tx.orderItem.update({
              where: { id: existingItem.id },
              data: {
                voidedAt: now,
                voidedBy: 'fullReplace',
                is_cancelled: true,
                cancelled_at: now,
                cancel_reason: 'Removed via full-replace order update',
              },
            });
          }
        }
      }
    }

    // 4. Upsert Payments Idempotently by Client ID
    if (hasIncomingPayments && tx.orderPayment) {
      for (let index = 0; index < incomingPayments.length; index++) {
        const p = incomingPayments[index];
        const paymentId = p.id || `${orderId}-pay-${index}`;
        const amount = Number(p.amount) || 0;
        const tenderedAmount =
          p.tendered_amount !== undefined ? Number(p.tendered_amount) : undefined;
        const changeReturned =
          p.change_returned !== undefined ? Number(p.change_returned) : undefined;
        const method = p.payment_method || 'cash';
        const pStatus = p.payment_status || 'COMPLETED';
        const ref = p.transaction_reference || null;
        const lastFour = p.card_last_four || null;
        const bank = p.bank_name || null;
        const notes = p.notes || null;
        const receivedBy = p.received_by || payload.waiter_name || 'Cashier';

        if (tx.orderPayment.upsert) {
          await tx.orderPayment.upsert({
            where: { id: paymentId },
            create: {
              id: paymentId,
              order_id: orderId,
              payment_method: method,
              amount: new Prisma.Decimal(amount),
              tendered_amount:
                tenderedAmount !== undefined
                  ? new Prisma.Decimal(tenderedAmount)
                  : undefined,
              change_returned:
                changeReturned !== undefined
                  ? new Prisma.Decimal(changeReturned)
                  : undefined,
              transaction_reference: ref,
              card_last_four: lastFour,
              bank_name: bank,
              payment_status: pStatus,
              notes,
              received_by: receivedBy,
            },
            update: {
              payment_method: method,
              amount: new Prisma.Decimal(amount),
              tendered_amount:
                tenderedAmount !== undefined
                  ? new Prisma.Decimal(tenderedAmount)
                  : undefined,
              change_returned:
                changeReturned !== undefined
                  ? new Prisma.Decimal(changeReturned)
                  : undefined,
              transaction_reference: ref,
              card_last_four: lastFour,
              bank_name: bank,
              payment_status: pStatus,
              notes,
              received_by: receivedBy,
            },
          });
        }
      }
    }

    // 5. Update Base Order
    // SYNC-013: Terminal and Paid Order Immutability Invariant
    // Once an order is marked paid or completed on the server, a stale offline update cannot downgrade it back to unpaid or accepted.
    let isPaid = existingOrder.is_paid;
    if (!existingOrder.is_paid) {
      isPaid = isPaidRequested
        ? effectivePaymentTotal >= orderTotal
        : payload.is_paid !== undefined
        ? payload.is_paid
        : false;
    }

    const paymentStatus = isPaid
      ? 'PAID'
      : (existingOrder.payment_status === 'PAID' ? 'PAID' : (payload.payment_status || existingOrder.payment_status));

    let status = existingOrder.status;
    if (existingOrder.status === 'completed') {
      status = 'completed';
    } else {
      status = isPaidRequested && effectivePaymentTotal >= orderTotal && payload.status
        ? payload.status
        : payload.status ?? existingOrder.status;
    }

    const orderUpdateData: any = {
      ...(status ? { status } : {}),
      payment_status: paymentStatus,
      is_paid: isPaid,
      ...(payload.is_held !== undefined ? { is_held: payload.is_held } : {}),
      ...(payload.rejection_reason
        ? { rejection_reason: payload.rejection_reason }
        : {}),
      version: { increment: 1 },
    };

    if (hasFinancialUpdates) {
      orderUpdateData.subtotal = new Prisma.Decimal(subtotal);
      orderUpdateData.discount_percentage = new Prisma.Decimal(discountPercentage);
      orderUpdateData.discount_amount = new Prisma.Decimal(discountAmount);
      orderUpdateData.tax_amount = new Prisma.Decimal(taxAmount);
      orderUpdateData.grand_total = new Prisma.Decimal(orderTotal);
    }

    const updated = await tx.order.update({
      where: { id: orderId },
      data: orderUpdateData,
    });

    // 6. Update Dine-In Detail and Table Bill if Applicable
    if (dineInTax > 0 && existingOrder.dine_in_detail && tx.dineInOrderDetail?.update) {
      await tx.dineInOrderDetail
        .update({
          where: { order_id: orderId },
          data: { dine_in_tax: new Prisma.Decimal(dineInTax) },
        })
        .catch(() => {});
    }

    const tableId = payload.table_id || existingOrder.dine_in_detail?.table_id;
    let isUpdateTableDeleted = false;
    if (tableId && tx.restaurantTable?.findFirst) {
      try {
        const tbl = await tx.restaurantTable.findFirst({
          where: {
            OR: [
              { id: tableId },
              { table_number: tableId },
              { name: tableId },
            ],
          },
          select: { id: true, is_deleted: true },
        });
        if (tbl && tbl.is_deleted) {
          isUpdateTableDeleted = true;
        }
      } catch (err) {
        this.logger.warn(`Failed to check table soft-delete status: ${err}`);
      }
    }
    if (tableId && tx.restaurantTable?.update) {
      await tx.restaurantTable
        .update({
          where: { id: tableId },
          data: {
            current_bill_amount: new Prisma.Decimal(orderTotal),
          },
        })
        .catch(() => {});
    }

    // 7. Audit & Change Log Recording
    const newVersion = (updated as any).version ?? currentVersion + 1;
    const updatedAt = (updated as any).updated_at || new Date();

    const paymentMethodsBreakdown: Record<string, number> = {};
    if (hasIncomingPayments) {
      for (const p of incomingPayments) {
        const m = p.payment_method || 'cash';
        paymentMethodsBreakdown[m] =
          (paymentMethodsBreakdown[m] || 0) + (Number(p.amount) || 0);
      }
    } else {
      for (const p of existingPayments) {
        const m = p.payment_method || 'cash';
        paymentMethodsBreakdown[m] =
          (paymentMethodsBreakdown[m] || 0) + Number(p.amount || 0);
      }
    }

    await this.changeLogService.record(
      tx,
      'order',
      updated.id,
      'UPDATE',
      newVersion,
      {
        id: updated.id,
        order_number: updated.order_number,
        order_type: updated.order_type,
        status: updated.status,
        subtotal: Number(updated.subtotal ?? subtotal),
        discount_amount: Number(updated.discount_amount ?? discountAmount),
        tax_amount: Number(updated.tax_amount ?? taxAmount),
        grand_total: Number(updated.grand_total ?? orderTotal),
        payment_status: updated.payment_status,
        is_paid: updated.is_paid,
        paid_at: updated.is_paid ? updatedAt : undefined,
        payments_count: hasIncomingPayments
          ? incomingPayments.length
          : existingPayments.length,
        payment_methods: paymentMethodsBreakdown,
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
      server_timestamp: this.toIsoString(updatedAt),
      warning_code: isUpdateTableDeleted ? 'TABLE_DELETED' : undefined,
      warnings: isUpdateTableDeleted ? ['TABLE_DELETED'] : undefined,
    };
  }

  // ---------------------------------------------------------------------------
  // DELETE MUTATION HANDLER
  // ---------------------------------------------------------------------------


  // ---------------------------------------------------------------------------
  // ITEM_ADD MUTATION HANDLER (SYNC-032 / D-05)
  // ---------------------------------------------------------------------------

  private async handleItemAdd(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const payload = mutation.payload || {};
    const orderId = payload.order_id || payload.orderId || mutation.entity_id;
    const existingOrder = await tx.order.findUnique({
      where: { id: orderId },
      include: { order_items: true, payments: true },
    });

    if (!existingOrder) {
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'FAILED_RETRYABLE',
        server_version: mutation.base_version ?? 1,
        server_timestamp: new Date().toISOString(),
        error_message: `Order '${orderId}' not found for ITEM_ADD`,
      };
    }

    const items = Array.isArray(payload.items)
      ? payload.items
      : payload.item
      ? [payload.item]
      : [payload];

    const existingItems = existingOrder.order_items || [];
    const existingMap = new Map(existingItems.map((i: any) => [i.id, i]));

    for (const rawItem of items) {
      const itemId = rawItem.id || mutation.entity_id;
      if (existingMap.has(itemId)) {
        // Idempotent: ON CONFLICT DO NOTHING / void always wins
        const existing = existingMap.get(itemId)!;
        const isIncomingVoided = Boolean(rawItem.voidedAt || rawItem.voided_at || rawItem.is_cancelled);
        if (isIncomingVoided && !existing.voidedAt && tx.orderItem?.update) {
          const now = new Date();
          await tx.orderItem.update({
            where: { id: itemId },
            data: {
              voidedAt: rawItem.voidedAt ? new Date(rawItem.voidedAt) : (rawItem.voided_at ? new Date(rawItem.voided_at) : now),
              voidedBy: rawItem.voidedBy || rawItem.voided_by || 'sync',
              is_cancelled: true,
              cancelled_at: now,
              cancel_reason: rawItem.cancel_reason || 'Voided',
            },
          });
        }
        continue;
      }

      let validMenuItemId: string | undefined = undefined;
      if (rawItem.menu_item_id && tx.menuItem?.findUnique) {
        try {
          const menuItem = await tx.menuItem.findUnique({ where: { id: rawItem.menu_item_id } });
          if (menuItem) validMenuItemId = menuItem.id;
        } catch {
          validMenuItemId = undefined;
        }
      }

      const isVoided = Boolean(rawItem.voidedAt || rawItem.voided_at || rawItem.is_cancelled);
      const voidedAtDate = rawItem.voidedAt
        ? new Date(rawItem.voidedAt)
        : rawItem.voided_at
        ? new Date(rawItem.voided_at)
        : isVoided
        ? new Date()
        : null;

      const unitPrice = rawItem.unit_price !== undefined ? Number(rawItem.unit_price) : 0;
      const quantity = rawItem.quantity !== undefined ? Number(rawItem.quantity) : 1;

      if (tx.orderItem?.create) {
        await tx.orderItem.create({
          data: {
            id: itemId,
            order_id: orderId,
            menu_item_id: validMenuItemId,
            item_name: rawItem.item_name || rawItem.itemName || 'Item',
            quantity,
            selected_size: rawItem.selected_size || rawItem.sizeName || 'Regular',
            selected_crust: rawItem.selected_crust || rawItem.selectedCrust || 'Original',
            extra_toppings: rawItem.extra_toppings || rawItem.extraToppings || '',
            unit_price: new Prisma.Decimal(unitPrice),
            total_price: new Prisma.Decimal(this.round(unitPrice * quantity)),
            notes: rawItem.notes || '',
            is_cancelled: isVoided,
            cancelled_at: isVoided ? (rawItem.cancelled_at ? new Date(rawItem.cancelled_at) : voidedAtDate) : null,
            cancel_reason: rawItem.cancel_reason ?? null,
            cancelled_by: rawItem.cancelled_by ?? null,
            voidedAt: voidedAtDate,
            voidedBy: rawItem.voidedBy || rawItem.voided_by || (isVoided ? (rawItem.cancelled_by ?? 'sync') : null),
            supersedesItemId: rawItem.supersedesItemId || rawItem.supersedes_item_id || null,
            createdByDeviceId: rawItem.createdByDeviceId || rawItem.created_by_device_id || context.deviceId || null,
            clientCreatedAt: rawItem.clientCreatedAt
              ? new Date(rawItem.clientCreatedAt)
              : rawItem.client_created_at
              ? new Date(rawItem.client_created_at)
              : mutation.created_at
              ? new Date(mutation.created_at)
              : new Date(),
          },
        });
      }
    }

    const activeItems = await this.ordersService.getActiveItems(orderId, tx);
    const subtotal = this.round(
      activeItems.reduce((sum: number, i: any) => sum + Number(i.total_price), 0),
    );

    const discountPercentage = Number(existingOrder.discount_percentage);
    const discountAmount =
      discountPercentage > 0
        ? this.round((subtotal * discountPercentage) / 100)
        : Number(existingOrder.discount_amount);
    const taxableAmount = Math.max(0, subtotal - discountAmount);
    const taxAmount = Number(existingOrder.tax_amount);
    const grandTotal = this.round(taxableAmount + taxAmount);

    const updated = await tx.order.update({
      where: { id: orderId },
      data: {
        subtotal: new Prisma.Decimal(subtotal),
        grand_total: new Prisma.Decimal(grandTotal),
        version: { increment: 1 },
      },
    });

    const newVersion = (updated as any).version ?? ((existingOrder as any).version || 1) + 1;
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
        subtotal,
        grand_total: grandTotal,
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
      server_timestamp: this.toIsoString(updatedAt),
    };
  }

  // ---------------------------------------------------------------------------
  // ITEM_VOID MUTATION HANDLER (SYNC-032 / D-05)
  // ---------------------------------------------------------------------------

  private async handleItemVoid(
    tx: Prisma.TransactionClient,
    mutation: SyncMutationDto,
    context: SyncMutationContext,
  ): Promise<SyncMutationResult> {
    const payload = mutation.payload || {};
    const orderId = payload.order_id || payload.orderId || mutation.entity_id;
    const itemId = payload.item_id || payload.itemId || payload.id || mutation.entity_id;

    const existingOrder = await tx.order.findUnique({
      where: { id: orderId },
      include: { order_items: true },
    });

    if (!existingOrder) {
      return {
        operation_id: mutation.operation_id,
        entity_id: orderId,
        status: 'FAILED_RETRYABLE',
        server_version: mutation.base_version ?? 1,
        server_timestamp: new Date().toISOString(),
        error_message: `Order '${orderId}' not found for ITEM_VOID`,
      };
    }

    const existingItem = await tx.orderItem.findUnique({
      where: { id: itemId },
    });

    const now = new Date();
    const voidedBy = payload.voided_by || payload.voidedBy || 'sync';
    const reason = payload.reason || payload.cancel_reason || 'Voided via sync';

    if (existingItem) {
      if (!existingItem.voidedAt && tx.orderItem?.update) {
        await tx.orderItem.update({
          where: { id: itemId },
          data: {
            voidedAt: now,
            voidedBy,
            is_cancelled: true,
            cancelled_at: now,
            cancel_reason: reason,
            cancelled_by: voidedBy,
          },
        });
      }
    } else if (tx.orderItem?.create) {
      // Tombstone insert for commutativity (VOID arriving before ADD)
      await tx.orderItem.create({
        data: {
          id: itemId,
          order_id: orderId,
          item_name: payload.item_name || payload.itemName || 'Voided Item',
          quantity: payload.quantity !== undefined ? Number(payload.quantity) : 1,
          unit_price: new Prisma.Decimal(0),
          total_price: new Prisma.Decimal(0),
          is_cancelled: true,
          cancelled_at: now,
          cancel_reason: reason,
          cancelled_by: voidedBy,
          voidedAt: now,
          voidedBy,
          clientCreatedAt: mutation.created_at ? new Date(mutation.created_at) : now,
        },
      });
    }

    const activeItems = await this.ordersService.getActiveItems(orderId, tx);
    const subtotal = this.round(
      activeItems.reduce((sum: number, i: any) => sum + Number(i.total_price), 0),
    );

    const discountPercentage = Number(existingOrder.discount_percentage);
    const discountAmount =
      discountPercentage > 0
        ? this.round((subtotal * discountPercentage) / 100)
        : Number(existingOrder.discount_amount);
    const taxableAmount = Math.max(0, subtotal - discountAmount);
    const taxAmount = Number(existingOrder.tax_amount);
    const grandTotal = this.round(taxableAmount + taxAmount);

    const updated = await tx.order.update({
      where: { id: orderId },
      data: {
        subtotal: new Prisma.Decimal(subtotal),
        grand_total: new Prisma.Decimal(grandTotal),
        version: { increment: 1 },
      },
    });

    const newVersion = (updated as any).version ?? ((existingOrder as any).version || 1) + 1;
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
        subtotal,
        grand_total: grandTotal,
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
      server_timestamp: this.toIsoString(updatedAt),
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
      server_timestamp: this.toIsoString(updatedAt),
    };
  }
}
