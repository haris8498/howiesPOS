import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { OrderItem, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { KitchenGateway } from '../kitchen/kitchen.gateway';
import { v7 as uuidv7 } from 'uuid';
import { CreateOrderDto, CreateOrderItemDto } from './dto/create-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { QueryOrderDto } from './dto/query-order.dto';

/** Standard include clause reused across all queries */
const ORDER_INCLUDE = {
  order_items: true,
  payments: true,
  online_detail: {
    include: { delivery_dispatch: true },
  },
  takeaway_detail: true,
  dine_in_detail: {
    include: {
      table: { select: { id: true, name: true, table_number: true } },
    },
  },
} as const;

// ---------------------------------------------------------------------------
// Result shape returned by every query — base order + detail sub-objects
// ---------------------------------------------------------------------------
export type OrderWithDetails = Prisma.OrderGetPayload<{
  include: typeof ORDER_INCLUDE;
}>;

@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly kitchenGateway?: KitchenGateway,
  ) {}

  private round(val: number): number {
    return Math.round((val + Number.EPSILON) * 100) / 100;
  }

  // -------------------------------------------------------------------------
  // LIST ORDERS
  // -------------------------------------------------------------------------
  async listOrders(query: QueryOrderDto = {}): Promise<OrderWithDetails[]> {
    const where: Prisma.OrderWhereInput = {};

    if (query.shift_id) {
      where.shift_id = query.shift_id;
    }
    if (query.order_type) {
      where.order_type = { equals: query.order_type, mode: 'insensitive' };
    }
    if (query.status) {
      where.status = query.status;
    }
    if (query.is_held !== undefined) {
      where.is_held = query.is_held;
    }
    if (query.is_paid !== undefined) {
      where.is_paid = query.is_paid;
    }

    // customer_id filter — search across both online and takeaway details
    if (query.customer_id) {
      where.OR = [
        { online_detail: { customer_id: query.customer_id } },
        { takeaway_detail: { customer_id: query.customer_id } },
      ];
    }

    // table_id filter — applies only to dine-in
    if (query.table_id) {
      where.dine_in_detail = { table_id: query.table_id };
    }

    if (query.order_source) {
      where.online_detail = {
        ...(where.online_detail as Prisma.OnlineOrderDetailWhereInput),
        order_source: { equals: query.order_source, mode: 'insensitive' },
      };
    }

    if (query.from_date || query.to_date) {
      where.created_at = {};
      if (query.from_date) where.created_at.gte = new Date(query.from_date);
      if (query.to_date) where.created_at.lte = new Date(query.to_date);
    }

    // Free-text search — order_number on base, customer details in sub-tables
    if (query.search) {
      where.OR = [
        { order_number: { contains: query.search, mode: 'insensitive' } },
        { online_detail: { customer_name: { contains: query.search, mode: 'insensitive' } } },
        { online_detail: { customer_phone: { contains: query.search, mode: 'insensitive' } } },
        { takeaway_detail: { token_number: { contains: query.search, mode: 'insensitive' } } },
        { takeaway_detail: { customer_name: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    return this.prisma.order.findMany({
      where,
      include: ORDER_INCLUDE,
      orderBy: { created_at: 'desc' },
    });
  }

  // -------------------------------------------------------------------------
  // GET SINGLE ORDER
  // -------------------------------------------------------------------------
  async getOrderById(id: string): Promise<OrderWithDetails> {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });

    if (!order) {
      throw new NotFoundException(`Order with ID '${id}' not found`);
    }

    return order;
  }

  // -------------------------------------------------------------------------
  // CREATE ORDER
  // -------------------------------------------------------------------------
  async createOrder(dto: CreateOrderDto): Promise<OrderWithDetails> {
    const result = await this.prisma.$transaction(async (tx) => {
      return this.createOrderInTx(tx, dto, dto.id);
    });

    if (result) {
      this.kitchenGateway?.emitOrderCreated(result);
    }

    return result;
  }

  /**
   * Internal transactional order creation, reusable by offline sync handlers
   * and cloud endpoints within an existing transaction context.
   */
  async createOrderInTx(
    tx: Prisma.TransactionClient,
    dto: CreateOrderDto,
    explicitOrderId?: string,
  ): Promise<OrderWithDetails> {
    // 0. Idempotency guard: If order with this explicit ID already exists, return it immediately
    if (explicitOrderId) {
      const existingOrderById = await tx.order.findUnique({
        where: { id: explicitOrderId },
        include: ORDER_INCLUDE,
      });
      if (existingOrderById) {
        this.logger.log(
          `Order '${explicitOrderId}' already exists in database — returning existing record (idempotent).`,
        );
        return existingOrderById;
      }
    }

    // 1. Resolve customer snapshot for online / takeaway
    let customerName = dto.customer_name ?? '';
      let customerPhone = dto.customer_phone ?? '';
      if (dto.customer_id) {
        try {
          const customer = await tx.customer.findUnique({ where: { id: dto.customer_id } });
          if (customer) {
            customerName = customerName || customer.full_name;
            customerPhone = customerPhone || customer.phone;
          }
        } catch {
          // invalid UUID — skip customer link
        }
      }

      // 2. Resolve table for dine-in
      let resolvedTableId: string | undefined;
      if (dto.table_id) {
        try {
          const table = await tx.restaurantTable.findFirst({
            where: {
              OR: [
                { id: dto.table_id },
                { table_number: dto.table_id },
                { name: dto.table_id },
              ],
            },
          });
          if (table) {
            resolvedTableId = table.id;
          } else {
            this.logger.warn(`Table '${dto.table_id}' not found — saving without table link`);
          }
        } catch {
          this.logger.warn(`Could not resolve table '${dto.table_id}'`);
        }
      }

      // 3. Sanitize menu items (validate menu_item_id FK)
      const sanitizedItems = await Promise.all(
        dto.items.map(async (item) => {
          let validMenuItemId: string | undefined;
          if (item.menu_item_id) {
            try {
              const menuItem = await tx.menuItem.findUnique({ where: { id: item.menu_item_id } });
              if (menuItem) validMenuItemId = menuItem.id;
            } catch {
              validMenuItemId = undefined;
            }
          }
          return { ...item, menu_item_id: validMenuItemId };
        }),
      );

      // 4. Financial totals
      const calculatedSubtotal = this.round(
        sanitizedItems.reduce((sum, item) => sum + this.round(item.unit_price * item.quantity), 0),
      );
      const subtotal = dto.subtotal !== undefined ? this.round(dto.subtotal) : calculatedSubtotal;

      const normalizedType = dto.order_type?.toLowerCase() ?? '';
      const isOnlineType =
        normalizedType === 'online' || normalizedType === 'delivery';
      const isTakeawayType =
        normalizedType === 'takeaway' || normalizedType === 'take_away';
      const isDineInType = !isOnlineType && !isTakeawayType;

      // Tax calculation: accurate custom tax assignment for all order types
      const taxAmountRaw = this.round(dto.tax_amount ?? dto.dine_in_tax ?? 0.0);
      const dineInTaxRaw = isDineInType ? taxAmountRaw : 0.0;
      const deliveryFeeRaw = isOnlineType ? this.round(dto.delivery_fee ?? 0.0) : 0.0;

      let discountPercentageRaw = dto.discount_percentage !== undefined ? this.round(dto.discount_percentage) : 0.0;
      let discountAmountRaw = dto.discount_amount !== undefined ? this.round(dto.discount_amount) : 0.0;

      // Ensure bidirectional consistency between percentage and absolute amount
      if (discountPercentageRaw > 0 && discountAmountRaw === 0.0 && subtotal > 0) {
        discountAmountRaw = this.round(subtotal * (discountPercentageRaw / 100));
      } else if (discountAmountRaw > 0 && discountPercentageRaw === 0.0 && subtotal > 0) {
        discountPercentageRaw = this.round((discountAmountRaw / subtotal) * 100);
      }

      if (discountAmountRaw > subtotal) {
        discountAmountRaw = subtotal;
      }

      const grandTotal =
        dto.grand_total !== undefined
          ? this.round(dto.grand_total)
          : this.round(subtotal - discountAmountRaw + taxAmountRaw + deliveryFeeRaw);

      // 5. Order number (Terminal-prefixed P<terminal>-<seq> or legacy 3-digit sequential 101-999)
      let orderNumber = dto.order_number;
      let clientOrderNumber: string | null = dto.client_order_number || null;
      if (!orderNumber) {
        // Query recent orders to find latest pure 3-digit numeric order number
        const recentOrders: Array<{ order_number: string }> = tx.order.findMany
          ? await tx.order.findMany({
              orderBy: { created_at: 'desc' },
              take: 50,
              select: { order_number: true },
            })
          : [await tx.order.findFirst({ orderBy: { created_at: 'desc' }, select: { order_number: true } })].filter((o): o is { order_number: string } => Boolean(o));

        let nextNum = 101;
        const latestLegacy = recentOrders.find((o) => /^\d{3}$/.test(o.order_number));
        if (latestLegacy) {
          const parsed = parseInt(latestLegacy.order_number, 10);
          if (!isNaN(parsed) && parsed >= 100 && parsed < 999) {
            nextNum = parsed + 1;
          } else if (!isNaN(parsed) && parsed >= 999) {
            nextNum = 101;
          }
        } else if (recentOrders.length > 0) {
          const parsed = parseInt(recentOrders[0].order_number.replace(/\D/g, ''), 10);
          if (!isNaN(parsed) && parsed >= 100 && parsed < 999) {
            nextNum = parsed + 1;
          } else if (!isNaN(parsed) && parsed >= 999) {
            nextNum = 101;
          }
        }

        while (await tx.order.findUnique({ where: { order_number: String(nextNum) } })) {
          nextNum++;
          if (nextNum > 999) {
            nextNum = 101;
          }
        }
        orderNumber = String(nextNum);
      } else {
        orderNumber = orderNumber.trim();
        clientOrderNumber = dto.client_order_number || orderNumber;
        const existingOrderNum = await tx.order.findUnique({ where: { order_number: orderNumber } });
        if (existingOrderNum && (!explicitOrderId || existingOrderNum.id !== explicitOrderId)) {
          if (explicitOrderId) {
            let suffix = 1;
            const maxBaseLen = 30 - (String(suffix).length + 1);
            let candidate = `${orderNumber.slice(0, maxBaseLen)}-${suffix}`;
            while (await tx.order.findUnique({ where: { order_number: candidate } })) {
              suffix++;
              const curMaxBaseLen = 30 - (String(suffix).length + 1);
              candidate = `${orderNumber.slice(0, curMaxBaseLen)}-${suffix}`;
            }
            this.logger.warn(
              `Order number collision for offline order ${explicitOrderId}. Reassigned from '${orderNumber}' to '${candidate}'`,
            );
            orderNumber = candidate;
          } else {
            throw new ConflictException(`Order number '${orderNumber}' already exists`);
          }
        }
      }

      // 5B. Resolve Active Shift Session
      let activeShiftId: string | null = dto.shift_id || null;
      const hadExplicitShiftId = Boolean(dto.shift_id);

      if (activeShiftId) {
        try {
          const shiftExists = await tx.dailyCalculation.findUnique({
            where: { id: activeShiftId },
            select: { id: true },
          });
          if (!shiftExists) {
            this.logger.warn(
              `Shift ID '${activeShiftId}' does not exist yet. Linking order without shift_id (OBX-07 / MNY-07).`,
            );
            activeShiftId = null;
          }
        } catch (err) {
          this.logger.warn(`Failed to verify shift ID '${activeShiftId}': ${err}`);
          activeShiftId = null;
        }
      }

      // OBX-07 / MNY-07: Do not arbitrarily attach offline order to an unrelated active shift if its own shift was specified
      if (!activeShiftId && !hadExplicitShiftId) {
        try {
          const activeShift = await tx.dailyCalculation.findFirst({
            where: { status: 'ACTIVE' },
            orderBy: { created_at: 'desc' },
            select: { id: true },
          });
          if (activeShift) {
            activeShiftId = activeShift.id;
          }
        } catch (err) {
          this.logger.warn(`Could not resolve active shift for order: ${err}`);
        }
      }

      // 6. Create base order
      const createdOrder = await tx.order.create({
        data: {
          ...(explicitOrderId ? { id: explicitOrderId } : {}),
          ...(dto.created_at ? { created_at: new Date(dto.created_at) } : {}),
          order_number: orderNumber,
          client_order_number: clientOrderNumber,
          order_type: dto.order_type,
          shift_id: activeShiftId,
          status: dto.status ?? 'newOrder',
          subtotal,
          discount_percentage: discountPercentageRaw,
          discount_amount: discountAmountRaw,
          tax_amount: taxAmountRaw,
          grand_total: grandTotal,
          payment_status: dto.payment_status ?? (dto.is_paid ? 'PAID' : 'UNPAID'),
          is_paid: dto.is_paid ?? false,
          is_held: dto.is_held ?? false,
          kitchen_ticket_sent: dto.kitchen_ticket_sent ?? false,
          rejection_reason: dto.rejection_reason,
          cooking_time_minutes: dto.cooking_time_minutes,
          estimated_ready_at: dto.estimated_ready_at ? new Date(dto.estimated_ready_at) : null,
        } as any,
      });

      // 7. Create type-specific detail record
      if (isOnlineType) {
        const onlineDetail = await tx.onlineOrderDetail.create({
          data: {
            order_id: createdOrder.id,
            order_source: dto.order_source ?? 'POS',
            customer_id: dto.customer_id,
            customer_name: customerName,
            customer_phone: customerPhone,
            delivery_address: dto.delivery_address ?? '',
            delivery_fee: deliveryFeeRaw,
          },
        });

        // Automatically create initial dispatch record for delivery tracking
        if (tx.deliveryDispatch) {
          await tx.deliveryDispatch.create({
            data: {
              online_order_detail_id: onlineDetail.id,
              dispatch_status: 'pending',
              estimated_delivery_time:
                dto.estimated_ready_at ? new Date(dto.estimated_ready_at) : new Date(Date.now() + 40 * 60 * 1000),
            },
          });
        }
      } else if (isTakeawayType) {
        let tokenNumber =
          dto.token_number ??
          `TK-${Math.floor(100 + Math.random() * 900)}`;
        const existingToken = await tx.takeawayOrderDetail.findUnique({
          where: { token_number: tokenNumber },
        });
        if (existingToken) {
          let suffix = 1;
          const maxBaseLen = 20 - (String(suffix).length + 1);
          let candidate = `${tokenNumber.slice(0, maxBaseLen)}-${suffix}`;
          while (await tx.takeawayOrderDetail.findUnique({ where: { token_number: candidate } })) {
            suffix++;
            const curMaxBaseLen = 20 - (String(suffix).length + 1);
            candidate = `${tokenNumber.slice(0, curMaxBaseLen)}-${suffix}`;
          }
          this.logger.warn(
            `Takeaway token collision for order ${explicitOrderId || createdOrder.id}. Reassigned from '${tokenNumber}' to '${candidate}'`,
          );
          tokenNumber = candidate;
        }

        await tx.takeawayOrderDetail.create({
          data: {
            order_id: createdOrder.id,
            token_number: tokenNumber,
            customer_id: dto.customer_id,
            customer_name: customerName || 'Walk-in Customer',
            customer_phone: customerPhone,
            served_by: dto.waiter_name ?? 'Cashier',
          },
        });
      } else {
        // dineIn (default)
        if (resolvedTableId) {
          await tx.dineInOrderDetail.create({
            data: {
              order_id: createdOrder.id,
              table_id: resolvedTableId,
              guest_count: dto.guest_count ?? 1,
              waiter_name: dto.waiter_name ?? 'Cashier',
              dine_in_tax: dineInTaxRaw,
            } as any,
          });

          await tx.restaurantTable.update({
            where: { id: resolvedTableId },
            data: {
              status: 'occupied',
              current_bill_amount: grandTotal,
              active_order_id: createdOrder.id,
              occupied_since: new Date(),
            },
          });
        }
      }

      // 8. Create order items (Task 1: preserve client UUID v7 & ledger fields)
      await tx.orderItem.createMany({
        data: sanitizedItems.map((item) => {
          const isVoided = Boolean(item.is_cancelled || item.voidedAt || item.voided_at);
          const voidedDate = item.voidedAt
            ? new Date(item.voidedAt)
            : item.voided_at
            ? new Date(item.voided_at)
            : isVoided
            ? new Date()
            : null;
          return {
            ...(item.id ? { id: item.id } : {}),
            order_id: createdOrder.id,
            menu_item_id: item.menu_item_id,
            item_name: item.item_name,
            quantity: item.quantity,
            selected_size: item.selected_size ?? 'Regular',
            selected_crust: item.selected_crust ?? 'Original',
            extra_toppings: item.extra_toppings ?? '',
            unit_price: item.unit_price,
            total_price: this.round(item.unit_price * item.quantity),
            notes: item.notes ?? '',
            is_cancelled: isVoided,
            cancelled_at: isVoided ? (item.cancelled_at ? new Date(item.cancelled_at) : voidedDate) : null,
            cancel_reason: item.cancel_reason ?? null,
            cancelled_by: item.cancelled_by ?? null,
            voidedAt: voidedDate,
            voidedBy: item.voidedBy || item.voided_by || (isVoided ? (item.cancelled_by ?? 'staff') : null),
            supersedesItemId: item.supersedesItemId || (item as any).supersedes_item_id || null,
            createdByDeviceId: item.createdByDeviceId || (item as any).created_by_device_id || null,
            clientCreatedAt: item.clientCreatedAt
              ? new Date(item.clientCreatedAt)
              : (item as any).client_created_at
              ? new Date((item as any).client_created_at)
              : item.created_at
              ? new Date(item.created_at)
              : dto.created_at
              ? new Date(dto.created_at)
              : new Date(),
          };
        }),
      });

      // 9. Payments
      if (dto.payments && dto.payments.length > 0) {
        await tx.orderPayment.createMany({
          data: dto.payments.map((p) => ({
            ...(p.id ? { id: p.id } : {}),
            ...(p.created_at ? { created_at: new Date(p.created_at) } : dto.created_at ? { created_at: new Date(dto.created_at) } : {}),
            order_id: createdOrder.id,
            payment_method: p.payment_method,
            amount: p.amount,
            tendered_amount: p.tendered_amount,
            change_returned: p.change_returned,
            transaction_reference: p.transaction_reference,
            card_last_four: p.card_last_four,
            bank_name: p.bank_name,
            payment_status: p.payment_status ?? 'COMPLETED',
            notes: p.notes,
            received_by: p.received_by ?? dto.waiter_name ?? 'Cashier',
          })),
        });
      } else if (dto.is_paid || dto.payment_status === 'PAID') {
        await tx.orderPayment.create({
          data: {
            ...(dto.created_at ? { created_at: new Date(dto.created_at) } : {}),
            order_id: createdOrder.id,
            payment_method: dto.payment_method || 'cash',
            amount: grandTotal,
            tendered_amount: grandTotal,
            change_returned: 0,
            payment_status: 'COMPLETED',
            received_by: dto.waiter_name ?? 'Cashier',
          },
        });
      }

      // 10. Record Sync Log in database (data_sync_logs)
      try {
        await (tx as any).dataSyncLog.create({
          data: {
            order_id: createdOrder.id,
            order_number: createdOrder.order_number,
            sync_type: 'ORDER',
            sync_status: (createdOrder as any).sync_status || 'synced',
            is_synced: (createdOrder as any).is_synced !== false,
            source_storage: 'SQLite Local',
            target_storage: 'PostgreSQL Cloud',
            synced_at: new Date(),
            device_id: (createdOrder as any).device_id || 'POS-TERMINAL-01',
            payload_json: JSON.stringify({
              order_number: createdOrder.order_number,
              order_type: createdOrder.order_type,
              grand_total: Number(createdOrder.grand_total),
              items_count: sanitizedItems.length,
              customer_name: customerName,
              action: 'ORDER_CREATED',
            }),
          },
        });
        this.logger.log(`Recorded dataSyncLog for order #${createdOrder.order_number}`);
      } catch (syncLogErr: any) {
        this.logger.warn(`Could not record dataSyncLog for order #${createdOrder.order_number}: ${syncLogErr?.message}`);
      }

      this.logger.log(
        `Created order '${createdOrder.order_number}' (${createdOrder.order_type}) — PKR ${grandTotal}`,
      );

    return tx.order.findUnique({
      where: { id: createdOrder.id },
      include: ORDER_INCLUDE,
    }) as Promise<OrderWithDetails>;
  }

  // -------------------------------------------------------------------------
  // UPDATE ORDER
  // -------------------------------------------------------------------------
  async updateOrder(id: string, dto: UpdateOrderDto): Promise<OrderWithDetails> {
    const existing = await this.prisma.order.findUnique({
      where: { id },
      include: ORDER_INCLUDE,
    });

    if (!existing) {
      throw new NotFoundException(`Order with ID '${id}' not found`);
    }

    // Guard: completed or paid orders are immutable historical records.
    // Only a status-only patch (via updateOrderStatus) to 'cancelled' is allowed after completion.
    if (existing.is_paid || existing.status === 'completed' || existing.status === 'cancelled') {
      throw new BadRequestException(
        `Order '${existing.order_number}' is already ${existing.is_paid ? 'paid' : existing.status} and cannot be modified.`,
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const orderType = dto.order_type ?? existing.order_type;

      // Recalculate subtotal if items changed
      let subtotal =
        dto.subtotal !== undefined ? this.round(dto.subtotal) : Number(existing.subtotal);

      if (dto.items && dto.items.length > 0) {
        const fullReplace = dto.fullReplace === true || (dto as any).full_replace === true;
        const existingItems = existing.order_items || [];
        const existingItemsMap = new Map(existingItems.map((i: any) => [i.id, i]));
        const incomingItemIds = new Set<string>();

        const sanitizedItems = await Promise.all(
          dto.items.map(async (item) => {
            let validMenuItemId: string | undefined;
            if (item.menu_item_id) {
              try {
                const menuItem = await tx.menuItem.findUnique({ where: { id: item.menu_item_id } });
                if (menuItem) validMenuItemId = menuItem.id;
              } catch {
                validMenuItemId = undefined;
              }
            }
            return { ...item, menu_item_id: validMenuItemId };
          }),
        );

        for (const item of sanitizedItems) {
          if (item.id && existingItemsMap.has(item.id)) {
            const prev = existingItemsMap.get(item.id)!;
            const unitPrice = item.unit_price !== undefined ? item.unit_price : Number(prev.unit_price);
            const isVoidRequested = Boolean(
              item.is_cancelled === true ||
              item.voidedAt !== undefined ||
              item.voided_at !== undefined
            );
            const isDetailsChanged =
              (item.quantity !== undefined && item.quantity !== prev.quantity) ||
              (item.unit_price !== undefined && Number(item.unit_price) !== Number(prev.unit_price)) ||
              (item.selected_size !== undefined && item.selected_size !== prev.selected_size) ||
              (item.selected_crust !== undefined && item.selected_crust !== prev.selected_crust);

            if (isVoidRequested) {
              incomingItemIds.add(item.id);
              if (!prev.voidedAt) {
                const now = new Date();
                await tx.orderItem.update({
                  where: { id: item.id },
                  data: {
                    voidedAt: now,
                    voidedBy: item.cancelled_by || item.voided_by || (item as any).voidedBy || 'staff',
                    is_cancelled: true,
                    cancelled_at: now,
                    cancel_reason: item.cancel_reason || 'Voided',
                    cancelled_by: item.cancelled_by || item.voided_by || (item as any).voidedBy || 'staff',
                  },
                });
              }
            } else if (prev.voidedAt) {
              // Task 3: Void always wins over a live copy! Never revive a voided item.
              incomingItemIds.add(item.id);
            } else if (isDetailsChanged) {
              // Task 3: Ledger semantics: items are never updated or deleted.
              // Quantity/modifier change = new item with supersedesItemId + void of old one.
              const now = new Date();
              await tx.orderItem.update({
                where: { id: prev.id },
                data: {
                  voidedAt: now,
                  voidedBy: item.cancelled_by || item.voided_by || (item as any).voidedBy || 'system',
                  is_cancelled: true,
                  cancelled_at: now,
                  cancel_reason: item.cancel_reason || 'Superseded by updated item',
                  cancelled_by: item.cancelled_by || item.voided_by || (item as any).voidedBy || 'system',
                },
              });

              const newId = uuidv7();
              const createdNew = await tx.orderItem.create({
                data: {
                  id: newId,
                  order_id: id,
                  menu_item_id: item.menu_item_id ?? prev.menu_item_id,
                  item_name: item.item_name ?? prev.item_name,
                  quantity: item.quantity,
                  selected_size: item.selected_size ?? prev.selected_size,
                  selected_crust: item.selected_crust ?? prev.selected_crust,
                  extra_toppings: item.extra_toppings ?? prev.extra_toppings,
                  unit_price: new Prisma.Decimal(unitPrice),
                  total_price: new Prisma.Decimal(this.round(unitPrice * item.quantity)),
                  notes: item.notes ?? prev.notes,
                  is_cancelled: false,
                  voidedAt: null,
                  supersedesItemId: prev.id,
                  createdByDeviceId: item.createdByDeviceId || (item as any).created_by_device_id || null,
                  clientCreatedAt: new Date(),
                },
              });
              incomingItemIds.add(createdNew.id);
            } else {
              // Unchanged active item: preserve as-is
              incomingItemIds.add(item.id);
              if (item.notes !== undefined && item.notes !== prev.notes) {
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
            const createdItem = await tx.orderItem.create({
              data: {
                id: itemId,
                order_id: id,
                menu_item_id: item.menu_item_id,
                item_name: item.item_name,
                quantity: item.quantity,
                selected_size: item.selected_size ?? 'Regular',
                selected_crust: item.selected_crust ?? 'Original',
                extra_toppings: item.extra_toppings ?? '',
                unit_price: new Prisma.Decimal(item.unit_price),
                total_price: new Prisma.Decimal(this.round(item.unit_price * item.quantity)),
                notes: item.notes ?? '',
                is_cancelled: isVoided,
                cancelled_at: isVoided ? new Date() : null,
                cancel_reason: item.cancel_reason ?? null,
                cancelled_by: item.cancelled_by ?? null,
                voidedAt: isVoided ? new Date() : null,
                voidedBy: isVoided ? (item.cancelled_by || item.voided_by || 'staff') : null,
                supersedesItemId: item.supersedesItemId || (item as any).supersedes_item_id || null,
                createdByDeviceId: item.createdByDeviceId || (item as any).created_by_device_id || null,
                clientCreatedAt: item.clientCreatedAt ? new Date(item.clientCreatedAt) : new Date(),
              },
            });
            incomingItemIds.add(createdItem.id);
          }
        }

        // SYNC-032 / D-05: Items absent from the payload are NOT removed unless explicit fullReplace: true
        if (fullReplace) {
          for (const existingItem of existingItems) {
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

        // Recalculate active subtotal from getActiveItems (Task 5)
        const activeItems = await this.getActiveItems(id, tx);
        if (dto.subtotal === undefined) {
          subtotal = this.round(
            activeItems.reduce((sum: number, i: any) => sum + Number(i.total_price), 0),
          );
        }
      }

      const normalizedType = orderType.toLowerCase();
      const isOnlineType =
        normalizedType === 'online' || normalizedType === 'delivery';
      const isTakeawayType =
        normalizedType === 'takeaway' || normalizedType === 'take_away';
      const isDineInType = !isOnlineType && !isTakeawayType;

      const deliveryFee = isOnlineType
        ? dto.delivery_fee !== undefined
          ? this.round(dto.delivery_fee)
          : Number(existing.online_detail?.delivery_fee ?? 0)
        : 0.0;

      const taxAmount =
        dto.tax_amount !== undefined
          ? this.round(dto.tax_amount)
          : dto.dine_in_tax !== undefined
          ? this.round(dto.dine_in_tax)
          : Number(existing.tax_amount ?? 0);

      const dineInTax = isDineInType ? taxAmount : undefined;

      let discountPercentageRaw: number =
        dto.discount_percentage !== undefined
          ? this.round(dto.discount_percentage)
          : Number(existing.discount_percentage ?? 0);

      let discountAmount: number =
        dto.discount_amount !== undefined
          ? this.round(dto.discount_amount)
          : Number(existing.discount_amount ?? 0);

      if (dto.discount_percentage !== undefined && dto.discount_amount === undefined) {
        discountAmount = this.round(subtotal * (discountPercentageRaw / 100));
      } else if (dto.discount_amount !== undefined && dto.discount_percentage === undefined) {
        discountPercentageRaw = subtotal > 0 ? this.round((discountAmount / subtotal) * 100) : 0.0;
      }

      if (discountAmount > subtotal) {
        discountAmount = subtotal;
      }

      const grandTotal =
        dto.grand_total !== undefined
          ? this.round(dto.grand_total)
          : this.round(subtotal - discountAmount + taxAmount + deliveryFee);

      const isPaid =
        dto.is_paid !== undefined
          ? dto.is_paid
          : dto.payment_status !== undefined
          ? dto.payment_status === 'PAID'
          : existing.is_paid;

      const paymentStatus =
        dto.payment_status !== undefined
          ? dto.payment_status
          : dto.is_paid !== undefined
          ? dto.is_paid ? 'PAID' : 'UNPAID'
          : existing.payment_status;

      // Update base order
      await tx.order.update({
        where: { id },
        data: {
          order_type: orderType,
          status: dto.status ?? existing.status,
          subtotal,
          discount_percentage: discountPercentageRaw ?? 0.0,
          discount_amount: discountAmount,
          tax_amount: taxAmount,
          grand_total: grandTotal,
          payment_status: paymentStatus,
          is_paid: isPaid,
          is_held: dto.is_held !== undefined ? dto.is_held : existing.is_held,
          kitchen_ticket_sent:
            dto.kitchen_ticket_sent !== undefined
              ? dto.kitchen_ticket_sent
              : existing.kitchen_ticket_sent,
          rejection_reason:
            dto.rejection_reason !== undefined ? dto.rejection_reason : existing.rejection_reason,
          cooking_time_minutes:
            dto.cooking_time_minutes !== undefined
              ? dto.cooking_time_minutes
              : existing.cooking_time_minutes,
          estimated_ready_at:
            dto.estimated_ready_at !== undefined
              ? dto.estimated_ready_at ? new Date(dto.estimated_ready_at) : null
              : existing.estimated_ready_at,
        },
      });

      // Update type-specific detail
      if (isOnlineType) {
        if (existing.online_detail) {
          await tx.onlineOrderDetail.update({
            where: { order_id: id },
            data: {
              customer_name: dto.customer_name ?? existing.online_detail.customer_name,
              customer_phone: dto.customer_phone ?? existing.online_detail.customer_phone,
              delivery_address: dto.delivery_address ?? existing.online_detail.delivery_address,
              delivery_fee: deliveryFee,
            },
          });
        } else {
          await tx.onlineOrderDetail.create({
            data: {
              order_id: id,
              customer_name: dto.customer_name ?? 'POS Customer',
              customer_phone: dto.customer_phone ?? '',
              delivery_address: dto.delivery_address ?? '',
              delivery_fee: deliveryFee,
              order_source: 'POS',
            },
          }).catch(() => {});
        }
      } else if (isTakeawayType) {
        if (existing.takeaway_detail) {
          await tx.takeawayOrderDetail.update({
            where: { order_id: id },
            data: {
              customer_name: dto.customer_name ?? existing.takeaway_detail.customer_name,
              customer_phone: dto.customer_phone ?? existing.takeaway_detail.customer_phone,
            },
          });
        } else {
          await tx.takeawayOrderDetail.create({
            data: {
              order_id: id,
              customer_name: dto.customer_name ?? 'Guest Customer',
              customer_phone: dto.customer_phone ?? '',
              token_number: existing.order_number,
            },
          }).catch(() => {});
        }
      } else if (isDineInType) {
        const tableId = dto.table_id ?? existing.dine_in_detail?.table_id;
        if (tableId && existing.dine_in_detail) {
          await tx.dineInOrderDetail.update({
            where: { order_id: id },
            data: {
              guest_count: dto.guest_count ?? existing.dine_in_detail.guest_count,
              waiter_name: dto.waiter_name ?? existing.dine_in_detail.waiter_name,
              ...(dineInTax !== undefined ? { dine_in_tax: dineInTax } : {}),
            },
          });

          // Update table with current bill and keep status as occupied.
          // Tables remain occupied until staff explicitly clicks 'Free Table' or releases the table.
          await tx.restaurantTable.update({
            where: { id: tableId },
            data: {
              current_bill_amount: grandTotal,
              status: 'occupied',
            },
          }).catch(() => {});
        }
      }

      // If delivery/online order is paid or marked completed, update delivery dispatch to 'delivered'
      if (isOnlineType && (dto.status === 'completed' || isPaid)) {
        const dispatch = await tx.deliveryDispatch.findFirst({
          where: {
            online_order_detail: { order_id: id },
            dispatch_status: { notIn: ['delivered', 'cancelled'] },
          },
        });
        if (dispatch) {
          await tx.deliveryDispatch.update({
            where: { id: dispatch.id },
            data: {
              dispatch_status: 'delivered',
              delivered_at: new Date(),
            },
          });
          if (dispatch.rider_id) {
            const rider = await tx.deliveryRider.findUnique({ where: { id: dispatch.rider_id } });
            if (rider && rider.active_deliveries_count > 0) {
              await tx.deliveryRider.update({
                where: { id: rider.id },
                data: {
                  active_deliveries_count: { decrement: 1 },
                  total_completed_deliveries: { increment: 1 },
                },
              });
            }
          }
        }
      }

      // Payments
      if (dto.payments && dto.payments.length > 0) {
        await tx.orderPayment.deleteMany({ where: { order_id: id } });
        await tx.orderPayment.createMany({
          data: dto.payments.map((p) => ({
            order_id: id,
            payment_method: p.payment_method,
            amount: p.amount,
            tendered_amount: p.tendered_amount,
            change_returned: p.change_returned,
            transaction_reference: p.transaction_reference,
            card_last_four: p.card_last_four,
            bank_name: p.bank_name,
            payment_status: p.payment_status ?? 'COMPLETED',
            notes: p.notes,
            received_by: p.received_by ?? dto.waiter_name ?? 'Cashier',
          })),
        });
      } else if (isPaid || paymentStatus === 'PAID') {
        const count = await tx.orderPayment.count({ where: { order_id: id } });
        if (count === 0) {
          await tx.orderPayment.create({
            data: {
              order_id: id,
              payment_method: dto.payment_method || 'cash',
              amount: grandTotal,
              tendered_amount: grandTotal,
              change_returned: 0,
              payment_status: 'COMPLETED',
              received_by: dto.waiter_name ?? 'Cashier',
            },
          });
        }
      }

      this.logger.log(`Updated order '${existing.order_number}' (${id})`);

      return tx.order.findUnique({
        where: { id },
        include: ORDER_INCLUDE,
      }) as Promise<OrderWithDetails>;
    });
  }

  // -------------------------------------------------------------------------
  // UPDATE STATUS ONLY
  // -------------------------------------------------------------------------
  async updateOrderStatus(id: string, dto: UpdateOrderStatusDto): Promise<OrderWithDetails> {
    const existing = await this.prisma.order.findUnique({ where: { id } });

    if (!existing) {
      throw new NotFoundException(`Order with ID '${id}' not found`);
    }

    if (dto.status === 'cancelled') {
      await this.prisma.orderItem.updateMany({
        where: { order_id: id, is_cancelled: false },
        data: {
          is_cancelled: true,
          cancelled_at: new Date(),
          cancel_reason: dto.rejection_reason || 'Order Cancelled',
        },
      });
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        status: dto.status,
        rejection_reason:
          dto.rejection_reason !== undefined ? dto.rejection_reason : existing.rejection_reason,
      },
      include: ORDER_INCLUDE,
    });

    if (dto.status === 'completed') {
      const dispatch = await this.prisma.deliveryDispatch.findFirst({
        where: {
          online_order_detail: { order_id: id },
          dispatch_status: { notIn: ['delivered', 'cancelled'] },
        },
      });
      if (dispatch) {
        await this.prisma.deliveryDispatch.update({
          where: { id: dispatch.id },
          data: {
            dispatch_status: 'delivered',
            delivered_at: new Date(),
          },
        });
        if (dispatch.rider_id) {
          const rider = await this.prisma.deliveryRider.findUnique({ where: { id: dispatch.rider_id } });
          if (rider && rider.active_deliveries_count > 0) {
            await this.prisma.deliveryRider.update({
              where: { id: rider.id },
              data: {
                active_deliveries_count: { decrement: 1 },
                total_completed_deliveries: { increment: 1 },
              },
            });
          }
        }
      }
    }

    this.logger.log(`Status for order '${existing.order_number}' → '${dto.status}'`);
    return updated as OrderWithDetails;
  }

  // -------------------------------------------------------------------------
  // DELETE ORDER
  // -------------------------------------------------------------------------
  async deleteOrder(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.order.findUnique({ where: { id } });

    if (!existing) {
      throw new NotFoundException(`Order with ID '${id}' not found`);
    }

    // Guard: paid and completed orders are permanent financial records — never delete them
    if (existing.is_paid || existing.status === 'completed') {
      throw new BadRequestException(
        `Order '${existing.order_number}' is ${existing.is_paid ? 'paid' : 'completed'} and cannot be deleted. ` +
        `Paid/completed orders are permanent financial records.`,
      );
    }

    await this.prisma.order.delete({ where: { id } });
    this.kitchenGateway?.emitOrderCancelled(existing as any);

    this.logger.log(`Deleted order '${existing.order_number}' (${id})`);
    return { message: `Order '${existing.order_number}' deleted successfully` };
  }

  // -------------------------------------------------------------------------
  // CANCEL ORDER ITEM
  // -------------------------------------------------------------------------

  /**
   * Expose getActiveItems(orderId, tx) in the orders service as the single source
   * of active items per SYNC-032 / D-05. Active items have voidedAt == null && is_cancelled == false.
   */
  async getActiveItems(orderId: string, tx?: Prisma.TransactionClient): Promise<OrderItem[]> {
    const client = tx || this.prisma;
    return client.orderItem.findMany({
      where: {
        order_id: orderId,
        voidedAt: null,
        is_cancelled: false,
      },
      orderBy: {
        clientCreatedAt: 'asc',
      },
    });
  }

  /**
   * Append batch of items to an order (POST /orders/:id/items).
   * Ledger semantics: Items are appended with client UUID v7 IDs (or newly generated UUID v7).
   * Existing active items are never overwritten or deleted.
   * Merge rule: set-union by id; a void always wins over a live copy. Inserts are idempotent.
   */
  async appendOrderItems(
    orderId: string,
    items: CreateOrderItemDto[],
    deviceId?: string,
    txInput?: Prisma.TransactionClient,
  ): Promise<OrderWithDetails> {
    const execute = async (tx: Prisma.TransactionClient) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: ORDER_INCLUDE,
      });
      if (!order) {
        throw new NotFoundException(`Order with ID '${orderId}' not found`);
      }

      const existingItems = await tx.orderItem.findMany({
        where: { order_id: orderId },
      });
      const existingMap = new Map(existingItems.map((i: any) => [i.id, i]));

      for (const item of items) {
        const itemId = item.id ? item.id : uuidv7();
        if (existingMap.has(itemId)) {
          // Idempotent: ON CONFLICT DO NOTHING
          // Merge rule: a void always wins over a live copy
          const existing = existingMap.get(itemId)!;
          const isIncomingVoided = Boolean(item.voidedAt || item.voided_at || item.is_cancelled);
          if (isIncomingVoided && !existing.voidedAt) {
            const now = new Date();
            await tx.orderItem.update({
              where: { id: itemId },
              data: {
                voidedAt: item.voidedAt ? new Date(item.voidedAt) : (item.voided_at ? new Date(item.voided_at) : now),
                voidedBy: item.voidedBy || item.voided_by || 'staff',
                is_cancelled: true,
                cancelled_at: item.cancelled_at ? new Date(item.cancelled_at) : now,
                cancel_reason: item.cancel_reason || 'Voided',
                cancelled_by: item.cancelled_by || item.voidedBy || item.voided_by || 'staff',
              },
            });
          }
          continue;
        }

        let validMenuItemId: string | undefined = undefined;
        if (item.menu_item_id) {
          try {
            const menuItem = await tx.menuItem.findUnique({ where: { id: item.menu_item_id } });
            if (menuItem) validMenuItemId = menuItem.id;
          } catch {
            validMenuItemId = undefined;
          }
        }

        const isVoided = Boolean(item.voidedAt || item.voided_at || item.is_cancelled);
        const voidedAtDate = item.voidedAt
          ? new Date(item.voidedAt)
          : item.voided_at
          ? new Date(item.voided_at)
          : isVoided
          ? new Date()
          : null;

        await tx.orderItem.create({
          data: {
            id: itemId,
            order_id: orderId,
            menu_item_id: validMenuItemId,
            item_name: item.item_name,
            quantity: item.quantity,
            selected_size: item.selected_size ?? 'Regular',
            selected_crust: item.selected_crust ?? 'Original',
            extra_toppings: item.extra_toppings ?? '',
            unit_price: new Prisma.Decimal(item.unit_price),
            total_price: new Prisma.Decimal(this.round(item.unit_price * item.quantity)),
            notes: item.notes ?? '',
            is_cancelled: isVoided,
            cancelled_at: isVoided ? (item.cancelled_at ? new Date(item.cancelled_at) : voidedAtDate) : null,
            cancel_reason: item.cancel_reason ?? null,
            cancelled_by: item.cancelled_by ?? null,
            voidedAt: voidedAtDate,
            voidedBy: item.voidedBy || item.voided_by || (isVoided ? (item.cancelled_by ?? 'staff') : null),
            supersedesItemId: item.supersedesItemId || item.supersedes_item_id || null,
            createdByDeviceId: item.createdByDeviceId || item.created_by_device_id || deviceId || null,
            clientCreatedAt: item.clientCreatedAt
              ? new Date(item.clientCreatedAt)
              : item.client_created_at
              ? new Date(item.client_created_at)
              : new Date(),
          },
        });
      }

      // Recompute subtotal from active items
      const activeItems = await this.getActiveItems(orderId, tx);
      const subtotal = this.round(
        activeItems.reduce((sum: number, i: any) => sum + Number(i.total_price), 0),
      );

      const discountPercentage = Number(order.discount_percentage);
      const discountAmount =
        discountPercentage > 0
          ? this.round((subtotal * discountPercentage) / 100)
          : Number(order.discount_amount);
      const taxableAmount = Math.max(0, subtotal - discountAmount);
      const taxAmount = Number(order.tax_amount);
      const grandTotal = this.round(taxableAmount + taxAmount);

      await tx.order.update({
        where: { id: orderId },
        data: {
          subtotal: new Prisma.Decimal(subtotal),
          grand_total: new Prisma.Decimal(grandTotal),
          version: { increment: 1 },
        },
      });

      const res = tx.order.findUniqueOrThrow
        ? await tx.order.findUniqueOrThrow({
            where: { id: orderId },
            include: ORDER_INCLUDE,
          })
        : await tx.order.findUnique({
            where: { id: orderId },
            include: ORDER_INCLUDE,
          });
      return res as OrderWithDetails;
    };

    return txInput ? execute(txInput) : this.prisma.$transaction(execute);
  }

  /**
   * Void an order line item (POST /orders/:id/items/:itemId/void).
   * Ledger semantics: Items are never deleted. Voiding marks voidedAt and is_cancelled.
   * If already voided, returns idempotently.
   */
  async voidOrderItem(
    orderId: string,
    itemId: string,
    voidedBy?: string,
    reason?: string,
    txInput?: Prisma.TransactionClient,
  ): Promise<OrderWithDetails> {
    const execute = async (tx: Prisma.TransactionClient) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: ORDER_INCLUDE,
      });
      if (!order) {
        throw new NotFoundException(`Order with ID '${orderId}' not found`);
      }

      const item = await tx.orderItem.findUnique({
        where: { id: itemId },
      });
      if (!item || item.order_id !== orderId) {
        throw new NotFoundException(`Order item with ID '${itemId}' not found in order '${orderId}'`);
      }

      if (!item.voidedAt) {
        const now = new Date();
        await tx.orderItem.update({
          where: { id: itemId },
          data: {
            voidedAt: now,
            voidedBy: voidedBy || 'staff',
            is_cancelled: true,
            cancelled_at: now,
            cancel_reason: reason || 'Voided',
            cancelled_by: voidedBy || 'staff',
          },
        });
      }

      const activeItems = await this.getActiveItems(orderId, tx);
      const subtotal = this.round(
        activeItems.reduce((sum: number, i: any) => sum + Number(i.total_price), 0),
      );

      const discountPercentage = Number(order.discount_percentage);
      const discountAmount =
        discountPercentage > 0
          ? this.round((subtotal * discountPercentage) / 100)
          : Number(order.discount_amount);
      const taxableAmount = Math.max(0, subtotal - discountAmount);
      const taxAmount = Number(order.tax_amount);
      const grandTotal = this.round(taxableAmount + taxAmount);

      await tx.order.update({
        where: { id: orderId },
        data: {
          subtotal: new Prisma.Decimal(subtotal),
          grand_total: new Prisma.Decimal(grandTotal),
          version: { increment: 1 },
        },
      });

      const res = tx.order.findUniqueOrThrow
        ? await tx.order.findUniqueOrThrow({
            where: { id: orderId },
            include: ORDER_INCLUDE,
          })
        : await tx.order.findUnique({
            where: { id: orderId },
            include: ORDER_INCLUDE,
          });
      return res as OrderWithDetails;
    };

    return txInput ? execute(txInput) : this.prisma.$transaction(execute);
  }

  async cancelOrderItem(
    orderId: string,
    dto: { item_id: string; cancel_quantity?: number; reason?: string; cancelled_by?: string },
  ): Promise<OrderWithDetails> {
    return this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: {
          order_items: true,
          dine_in_detail: true,
          online_detail: true,
          payments: true,
        },
      });

      if (!order) {
        throw new NotFoundException(`Order with ID '${orderId}' not found`);
      }

      const item = order.order_items.find((i) => i.id === dto.item_id);
      if (!item) {
        throw new NotFoundException(`Order item with ID '${dto.item_id}' not found in this order`);
      }

      if (item.is_cancelled) {
        // Idempotent: if item is already cancelled, safely return order without throwing error
        const existingOrder = await tx.order.findUnique({
          where: { id: orderId },
          include: ORDER_INCLUDE,
        });
        return existingOrder as OrderWithDetails;
      }

      const cancelQty = dto.cancel_quantity && dto.cancel_quantity > 0 ? dto.cancel_quantity : item.quantity;

      if (cancelQty < item.quantity) {
        // 1. Partial Cancellation: Split item into remaining active + cancelled entry
        const remainingQty = item.quantity - cancelQty;
        const unitPriceNum = Number(item.unit_price);

        // A. Update active item with reduced quantity
        await tx.orderItem.update({
          where: { id: item.id },
          data: {
            quantity: remainingQty,
            total_price: new Prisma.Decimal(this.round(unitPriceNum * remainingQty)),
          },
        });

        // B. Create separated cancelled item record with line-through audit
        await tx.orderItem.create({
          data: {
            order_id: orderId,
            menu_item_id: item.menu_item_id,
            item_name: item.item_name,
            quantity: cancelQty,
            unit_price: item.unit_price,
            total_price: new Prisma.Decimal(this.round(unitPriceNum * cancelQty)),
            selected_size: item.selected_size,
            selected_crust: item.selected_crust,
            extra_toppings: item.extra_toppings,
            notes: item.notes,
            is_cancelled: true,
            cancelled_at: new Date(),
            cancel_reason: dto.reason || 'Cancelled by Cashier',
            cancelled_by: dto.cancelled_by || 'Cashier',
          },
        });
      } else {
        // 2. Full item cancellation
        await tx.orderItem.update({
          where: { id: item.id },
          data: {
            is_cancelled: true,
            cancelled_at: new Date(),
            cancel_reason: dto.reason || 'Cancelled by Cashier',
            cancelled_by: dto.cancelled_by || 'Cashier',
          },
        });
      }

      // 3. Fetch updated items to recalculate order totals
      const allItems = await tx.orderItem.findMany({
        where: { order_id: orderId },
      });

      const activeItems = allItems.filter((i) => !i.is_cancelled);

      const subtotal = this.round(
        activeItems.reduce((sum, it) => sum + Number(it.total_price), 0),
      );

      const discountPercentage = Number(order.discount_percentage || 0);
      const discountAmount = this.round((subtotal * discountPercentage) / 100);
      const taxableAmount = Math.max(0, subtotal - discountAmount);

      // If order has dine-in tax or standard tax
      const currentTax = Number(order.tax_amount || 0);
      const prevSubtotal = Number(order.subtotal) || 1;
      const taxRate = prevSubtotal > 0 ? currentTax / prevSubtotal : 0;
      const newTax = this.round(taxableAmount * taxRate);

      // Preserve delivery fee for delivery/online orders
      const deliveryFee = Number(order.online_detail?.delivery_fee || 0);
      const grandTotal = this.round(taxableAmount + newTax + deliveryFee);

      // Recalculate payment status based on payment ledger history
      const totalPaid = (order.payments || []).reduce((sum, p) => sum + Number(p.amount || 0), 0);
      let paymentStatus = order.payment_status;
      let isPaid = order.is_paid;

      if (totalPaid >= grandTotal && grandTotal > 0) {
        paymentStatus = 'PAID';
        isPaid = true;
      } else if (totalPaid > 0) {
        paymentStatus = 'PARTIALLY_PAID';
        isPaid = false;
      } else if (grandTotal === 0 && activeItems.length === 0) {
        paymentStatus = 'CANCELLED';
        isPaid = false;
      }

      // 4. Update Order financial totals atomically
      const updatedOrder = await tx.order.update({
        where: { id: orderId },
        data: {
          subtotal: new Prisma.Decimal(subtotal),
          discount_amount: new Prisma.Decimal(discountAmount),
          tax_amount: new Prisma.Decimal(newTax),
          grand_total: new Prisma.Decimal(grandTotal),
          status: activeItems.length === 0 ? 'cancelled' : order.status,
          payment_status: paymentStatus,
          is_paid: isPaid,
        },
        include: ORDER_INCLUDE,
      });

      // 5. If Dine-In, update table current_bill_amount (table remains occupied until bill/payment settled)
      if (order.dine_in_detail?.table_id) {
        await tx.restaurantTable.update({
          where: { id: order.dine_in_detail.table_id },
          data: {
            current_bill_amount: new Prisma.Decimal(grandTotal),
          },
        });
      }

      this.logger.log(
        `Cancelled item '${item.item_name}' from order '${order.order_number}'. New grand total: PKR ${grandTotal}`,
      );
      return updatedOrder as OrderWithDetails;
    });
  }
}
