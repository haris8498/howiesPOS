import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { KitchenGateway } from './kitchen.gateway';
import { UpdateKitchenStatusDto } from './dto/update-kitchen-status.dto';
import { UpdateCookingTimeDto } from './dto/update-cooking-time.dto';
import { QueryKitchenDto } from './dto/query-kitchen.dto';

const KITCHEN_ORDER_INCLUDE = {
  order_items: true,
  online_detail: {
    include: {
      customer: {
        select: { id: true, full_name: true, phone: true },
      },
    },
  },
  takeaway_detail: {
    include: {
      customer: {
        select: { id: true, full_name: true, phone: true },
      },
    },
  },
  dine_in_detail: {
    include: {
      table: {
        select: { id: true, name: true, table_number: true },
      },
    },
  },
} as const;

@Injectable()
export class KitchenService {
  private readonly logger = new Logger(KitchenService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly kitchenGateway: KitchenGateway,
  ) {}

  private async getDealMap(): Promise<Map<string, any>> {
    try {
      if (!this.prisma.deal) return new Map();
      const deals = await this.prisma.deal.findMany({
        include: { components: true },
      });
      const map = new Map<string, any>();
      for (const d of deals) {
        map.set(d.title.toLowerCase().trim(), d);
      }
      return map;
    } catch (err: any) {
      this.logger.warn(`Could not load deals for kitchen orders: ${err?.message ?? err}`);
      return new Map();
    }
  }

  private enrichKitchenOrder(order: any, dealMap: Map<string, any>) {
    if (!order || !order.order_items) return order;

    const enrichedItems = order.order_items.map((item: any) => {
      const lowerName = (item.item_name || '').toLowerCase().trim();
      const matchedDeal = dealMap.get(lowerName);
      if (matchedDeal && matchedDeal.components && matchedDeal.components.length > 0) {
        return {
          ...item,
          is_deal: true,
          deal_components: matchedDeal.components.map((c: any) => ({
            id: c.id,
            item_name: c.item_name,
            quantity: c.quantity * (item.quantity || 1),
            size: c.size,
            notes: c.notes,
          })),
        };
      }
      return {
        ...item,
        is_deal: false,
        deal_components: [],
      };
    });

    return {
      ...order,
      order_items: enrichedItems,
    };
  }

  async getKitchenOrders(query: QueryKitchenDto = {}) {
    const where: Prisma.OrderWhereInput = {};

    if (query.status) {
      where.status = query.status;
    } else {
      // Default: Active kitchen orders (exclude completed, cancelled, served unless explicitly queried)
      where.status = {
        in: ['newOrder', 'accepted', 'preparing', 'ready'],
      };
    }

    if (query.order_type) {
      where.order_type = query.order_type;
    }

    if (query.search) {
      where.OR = [
        { order_number: { contains: query.search, mode: 'insensitive' } },
        { online_detail: { customer_name: { contains: query.search, mode: 'insensitive' } } },
        { takeaway_detail: { customer_name: { contains: query.search, mode: 'insensitive' } } },
        { takeaway_detail: { token_number: { contains: query.search, mode: 'insensitive' } } },
      ];
    }

    const orders = await this.prisma.order.findMany({
      where,
      include: KITCHEN_ORDER_INCLUDE,
      orderBy: { created_at: 'asc' },
    });

    const dealMap = await this.getDealMap();
    return orders.map((o) => this.enrichKitchenOrder(o, dealMap));
  }

  async getKitchenOrderById(id: string) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: KITCHEN_ORDER_INCLUDE,
    });

    if (!order) {
      throw new NotFoundException(`Kitchen order with ID '${id}' not found`);
    }

    const dealMap = await this.getDealMap();
    return this.enrichKitchenOrder(order, dealMap);
  }

  async updateStatus(id: string, dto: UpdateKitchenStatusDto) {
    const existing = await this.prisma.order.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Kitchen order with ID '${id}' not found`);
    }

    // Update status in transactional consistency
    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        status: dto.status,
      },
      include: KITCHEN_ORDER_INCLUDE,
    });

    // Real-time Socket.IO emission
    this.kitchenGateway.emitOrderStatusChanged(updated);

    if (dto.status === 'ready') {
      this.kitchenGateway.emitOrderReady(updated);
    } else if (dto.status === 'cancelled' || dto.status === 'rejected') {
      this.kitchenGateway.emitOrderCancelled(updated);
    }

    return updated;
  }

  async updateCookingTime(id: string, dto: UpdateCookingTimeDto) {
    const existing = await this.prisma.order.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Kitchen order with ID '${id}' not found`);
    }

    let estimatedReadyAt: Date;
    if (dto.estimated_ready_at) {
      estimatedReadyAt = new Date(dto.estimated_ready_at);
      if (isNaN(estimatedReadyAt.getTime())) {
        throw new BadRequestException('Invalid estimated_ready_at date string');
      }
    } else {
      estimatedReadyAt = new Date(Date.now() + dto.cooking_time_minutes * 60 * 1000);
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        cooking_time_minutes: dto.cooking_time_minutes,
        estimated_ready_at: estimatedReadyAt,
      },
      include: KITCHEN_ORDER_INCLUDE,
    });

    this.kitchenGateway.emitOrderUpdated(updated);
    return updated;
  }

  async sendKitchenTicket(id: string) {
    const existing = await this.prisma.order.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Kitchen order with ID '${id}' not found`);
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        kitchen_ticket_sent: true,
      },
      include: KITCHEN_ORDER_INCLUDE,
    });

    this.kitchenGateway.emitKitchenTicketSent(updated);
    return updated;
  }
}
