import { RealtimeGateway } from '../../realtime/realtime.gateway';
import { Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateDealDto, UpdateDealDto } from '../dto/deal.dto';
import { QueryDealDto } from '../dto/query-menu.dto';

@Injectable()
export class DealsService {
  private readonly logger = new Logger(DealsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async listDeals(query: QueryDealDto = {}) {
    const where: Prisma.DealWhereInput = {};

    if (query.is_available !== undefined) {
      where.is_available = query.is_available;
    }

    if (query.search) {
      where.OR = [
        { title: { contains: query.search, mode: 'insensitive' } },
        { subtitle: { contains: query.search, mode: 'insensitive' } },
        { description: { contains: query.search, mode: 'insensitive' } },
      ];
    }

    return this.prisma.deal.findMany({
      where,
      include: {
        components: true,
      },
      orderBy: { title: 'asc' },
    });
  }

  async getDealById(id: string) {
    const deal = await this.prisma.deal.findUnique({
      where: { id },
      include: {
        components: true,
      },
    });

    if (!deal) {
      throw new NotFoundException(`Deal with ID '${id}' not found`);
    }

    return deal;
  }

  async createDeal(dto: CreateDealDto) {
    const created = await this.prisma.$transaction(async (tx) => {
      const deal = await tx.deal.create({
        data: {
          title: dto.title,
          subtitle: dto.subtitle,
          deal_price: dto.deal_price,
          original_price: dto.original_price,
          badge_text: dto.badge_text ?? 'EXCLUSIVE DEAL',
          image_path: dto.image_path,
          description: dto.description,
          is_available: dto.is_available ?? true,
        },
      });

      if (dto.components && dto.components.length > 0) {
        await tx.dealComponent.createMany({
          data: dto.components.map((c) => ({
            deal_id: deal.id,
            item_name: c.item_name,
            category: c.category,
            quantity: c.quantity ?? '1x',
          })),
        });
      }

      return tx.deal.findUnique({
        where: { id: deal.id },
        include: { components: true },
      });
    });

    this.logger.log(`Created deal '${created?.title}' (${created?.id})`);
    if (created) {
      this.realtimeGateway?.broadcastEvent({
        eventName: 'deal:created',
        alternateEventName: 'menu:updated',
        entity: 'deals',
        entityId: created.id,
        action: 'CREATED',
        payload: created,
      });
    }
    return created;
  }

  async updateDeal(id: string, dto: UpdateDealDto) {
    const existing = await this.prisma.deal.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Deal with ID '${id}' not found`);
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.deal.update({
        where: { id },
        data: {
          title: dto.title ?? existing.title,
          subtitle: dto.subtitle !== undefined ? dto.subtitle : existing.subtitle,
          deal_price: dto.deal_price !== undefined ? dto.deal_price : existing.deal_price,
          original_price:
            dto.original_price !== undefined ? dto.original_price : existing.original_price,
          badge_text: dto.badge_text !== undefined ? dto.badge_text : existing.badge_text,
          image_path: dto.image_path !== undefined ? dto.image_path : existing.image_path,
          description: dto.description !== undefined ? dto.description : existing.description,
          is_available: dto.is_available !== undefined ? dto.is_available : existing.is_available,
        },
      });

      if (dto.components !== undefined) {
        // Synchronize deal components
        await tx.dealComponent.deleteMany({
          where: { deal_id: id },
        });

        if (dto.components.length > 0) {
          await tx.dealComponent.createMany({
            data: dto.components.map((c) => ({
              deal_id: id,
              item_name: c.item_name,
              category: c.category,
              quantity: c.quantity ?? '1x',
            })),
          });
        }
      }

      return tx.deal.findUnique({
        where: { id },
        include: { components: true },
      });
    });

    this.logger.log(`Updated deal '${updated?.title}' (${id})`);
    if (updated) {
      this.realtimeGateway?.broadcastEvent({
        eventName: 'deal:updated',
        alternateEventName: 'menu:updated',
        entity: 'deals',
        entityId: id,
        action: 'UPDATED',
        payload: updated,
      });
    }
    return updated;
  }

  async deleteDeal(idOrTitle: string): Promise<{ message: string }> {
    const existing = await this.prisma.deal.findFirst({
      where: {
        OR: [
          { id: idOrTitle },
          { title: { equals: idOrTitle, mode: 'insensitive' } },
          { title: { contains: idOrTitle, mode: 'insensitive' } },
        ],
      },
    });

    if (!existing) {
      throw new NotFoundException(`Deal '${idOrTitle}' not found`);
    }

    await this.prisma.dealComponent.deleteMany({
      where: { deal_id: existing.id },
    });

    await this.prisma.deal.delete({
      where: { id: existing.id },
    });

    this.logger.log(`Deleted deal '${existing.title}' (${existing.id})`);
    this.realtimeGateway?.broadcastEvent({
      eventName: 'deal:deleted',
      alternateEventName: 'menu:updated',
      entity: 'deals',
      entityId: existing.id,
      action: 'DELETED',
      payload: { id: existing.id, title: existing.title },
    });
    return { message: `Deal '${existing.title}' deleted successfully` };
  }
}
