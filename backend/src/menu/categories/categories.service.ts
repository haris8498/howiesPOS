import { RealtimeGateway } from '../../realtime/realtime.gateway';
import { ConflictException, Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { MenuCategory } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ChangeLogService } from '../../sync/change-log.service';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';

@Injectable()
export class CategoriesService {
  private readonly logger = new Logger(CategoriesService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
    @Optional() private readonly changeLogService?: ChangeLogService,
  ) {}

  async listCategories(): Promise<MenuCategory[]> {
    return this.prisma.menuCategory.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async getCategoryById(id: string): Promise<MenuCategory> {
    const category = await this.prisma.menuCategory.findUnique({
      where: { id },
      include: {
        menu_items: {
          include: {
            sizes: true,
            options: true,
          },
        },
      },
    });

    if (!category) {
      throw new NotFoundException(`Category with ID '${id}' not found`);
    }

    return category;
  }

  async createCategory(dto: CreateCategoryDto): Promise<MenuCategory> {
    const id = dto.id.trim();
    const created = await this.prisma.menuCategory.upsert({
      where: { id },
      update: {
        name: dto.name,
        badge_text: dto.badge_text ?? 'Category',
        image_path: dto.image_path ?? '',
        description: dto.description ?? '',
        icon_name: dto.icon_name ?? 'fastfood',
      },
      create: {
        id,
        name: dto.name,
        badge_text: dto.badge_text ?? 'Category',
        image_path: dto.image_path ?? '',
        description: dto.description ?? '',
        icon_name: dto.icon_name ?? 'fastfood',
      },
    });

    this.logger.log(`Created/Updated menu category '${created.name}' (${created.id})`);

    this.realtimeGateway?.broadcastEvent({
      eventName: 'category:created',
      alternateEventName: 'menu:updated',
      entity: 'menu_categories',
      entityId: created.id,
      action: 'CREATED',
      payload: created,
    });

    if (this.changeLogService) {
      try {
        await this.changeLogService.record(
          this.prisma,
          'menu_category',
          created.id,
          'INSERT',
          1,
          created,
          false,
        );
      } catch (err) {
        this.logger.warn(`Failed to record change log for category ${created.id}: ${err}`);
      }
    }

    return created;
  }

  async updateCategory(id: string, dto: UpdateCategoryDto): Promise<MenuCategory> {
    const existing = await this.prisma.menuCategory.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Category with ID '${id}' not found`);
    }

    const updated = await this.prisma.menuCategory.update({
      where: { id },
      data: {
        name: dto.name ?? existing.name,
        badge_text: dto.badge_text ?? existing.badge_text,
        image_path: dto.image_path ?? existing.image_path,
        description: dto.description ?? existing.description,
        icon_name: dto.icon_name ?? existing.icon_name,
      },
    });

    this.logger.log(`Updated menu category '${updated.name}'`);

    this.realtimeGateway?.broadcastEvent({
      eventName: 'category:updated',
      alternateEventName: 'menu:updated',
      entity: 'menu_categories',
      entityId: updated.id,
      action: 'UPDATED',
      payload: updated,
    });

    if (this.changeLogService) {
      try {
        await this.changeLogService.record(
          this.prisma,
          'menu_category',
          updated.id,
          'UPDATE',
          1,
          updated,
          false,
        );
      } catch (err) {
        this.logger.warn(`Failed to record change log for category ${updated.id}: ${err}`);
      }
    }

    return updated;
  }

  async deleteCategory(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.menuCategory.findUnique({
      where: { id },
      include: {
        menu_items: true,
      },
    });

    if (!existing) {
      throw new NotFoundException(`Category with ID '${id}' not found`);
    }

    if (existing.menu_items && existing.menu_items.length > 0) {
      await this.prisma.menuItem.deleteMany({
        where: { category_id: id },
      });
    }

    await this.prisma.menuCategory.delete({
      where: { id },
    });

    this.logger.log(`Deleted menu category '${existing.name}' (${id})`);

    this.realtimeGateway?.broadcastEvent({
      eventName: 'category:deleted',
      alternateEventName: 'menu:updated',
      entity: 'menu_categories',
      entityId: existing.id,
      action: 'DELETED',
      payload: { id: existing.id, name: existing.name },
    });

    if (this.changeLogService) {
      try {
        await this.changeLogService.record(
          this.prisma,
          'menu_category',
          existing.id,
          'DELETE',
          1,
          { id: existing.id },
          true,
        );
      } catch (err) {
        this.logger.warn(`Failed to record change log for deleted category ${existing.id}: ${err}`);
      }
    }

    return { message: `Category '${existing.name}' deleted successfully` };
  }
}
