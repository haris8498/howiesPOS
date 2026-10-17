import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { MenuItem, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateMenuItemDto, UpdateAvailabilityDto, UpdateMenuItemDto } from '../dto/menu-item.dto';
import { QueryMenuItemDto } from '../dto/query-menu.dto';

export interface FullMenuItem extends MenuItem {
  category?: {
    id: string;
    name: string;
    badge_text: string;
  };
  sizes?: {
    id: string;
    size_name: string;
    price: Prisma.Decimal;
  }[];
  options?: {
    id: string;
    option_type: string;
    option_name: string;
    additional_price: Prisma.Decimal;
  }[];
}

@Injectable()
export class ItemsService {
  private readonly logger = new Logger(ItemsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listItems(query?: QueryMenuItemDto): Promise<FullMenuItem[]> {
    const where: Prisma.MenuItemWhereInput = {};

    if (query?.category_id) {
      where.category_id = query.category_id;
    }

    if (query?.is_available !== undefined) {
      where.is_available = query.is_available;
    }

    if (query?.is_veg !== undefined) {
      where.is_veg = query.is_veg;
    }

    if (query?.is_spicy !== undefined) {
      where.is_spicy = query.is_spicy;
    }

    if (query?.search) {
      const search = query.search.trim();
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ];
    }

    return this.prisma.menuItem.findMany({
      where,
      include: {
        category: {
          select: {
            id: true,
            name: true,
            badge_text: true,
          },
        },
        sizes: {
          orderBy: { price: 'asc' },
        },
        options: {
          orderBy: { option_name: 'asc' },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  async getItemById(id: string): Promise<FullMenuItem> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id },
      include: {
        category: {
          select: {
            id: true,
            name: true,
            badge_text: true,
          },
        },
        sizes: {
          orderBy: { price: 'asc' },
        },
        options: {
          orderBy: { option_name: 'asc' },
        },
      },
    });

    if (!item) {
      throw new NotFoundException(`Menu item with ID '${id}' not found`);
    }

    return item;
  }

  async createItem(dto: CreateMenuItemDto): Promise<FullMenuItem> {
    let category = await this.prisma.menuCategory.findUnique({
      where: { id: dto.category_id },
    });

    if (!category) {
      category = await this.prisma.menuCategory.findFirst({
        where: {
          OR: [
            { name: { equals: dto.category_id, mode: 'insensitive' } },
            { id: { equals: dto.category_id.toLowerCase().replace(/[^a-z0-9]/g, '-') } },
          ],
        },
      });
    }

    if (!category) {
      const generatedId = dto.category_id.toLowerCase().replace(/[^a-z0-9]/g, '-');
      category = await this.prisma.menuCategory.create({
        data: {
          id: generatedId || `cat-${Date.now()}`,
          name: dto.category_id,
          badge_text: dto.category_id,
          description: `Category for ${dto.category_id}`,
        },
      });
    }

    const resolvedCategoryId = category.id;

    // Use transaction if sizes or options are provided
    if ((dto.sizes && dto.sizes.length > 0) || (dto.options && dto.options.length > 0)) {
      return this.prisma.$transaction(async (tx) => {
        const createdItem = await tx.menuItem.create({
          data: {
            category_id: resolvedCategoryId,
            name: dto.name,
            description: dto.description ?? '',
            base_price: dto.base_price,
            image_url: dto.image_url ?? '',
            is_veg: dto.is_veg ?? false,
            is_spicy: dto.is_spicy ?? false,
            is_available: dto.is_available ?? true,
          },
        });

        if (dto.sizes && dto.sizes.length > 0) {
          await tx.menuItemSize.createMany({
            data: dto.sizes.map((s) => ({
              menu_item_id: createdItem.id,
              size_name: s.size_name,
              price: s.price,
            })),
          });
        }

        if (dto.options && dto.options.length > 0) {
          await tx.menuItemOption.createMany({
            data: dto.options.map((o) => ({
              menu_item_id: createdItem.id,
              option_type: o.option_type,
              option_name: o.option_name,
              additional_price: o.additional_price ?? 0.0,
            })),
          });
        }

        return tx.menuItem.findUniqueOrThrow({
          where: { id: createdItem.id },
          include: {
            category: { select: { id: true, name: true, badge_text: true } },
            sizes: true,
            options: true,
          },
        });
      });
    }

    const created = await this.prisma.menuItem.create({
      data: {
        category_id: dto.category_id,
        name: dto.name,
        description: dto.description ?? '',
        base_price: dto.base_price,
        image_url: dto.image_url ?? '',
        is_veg: dto.is_veg ?? false,
        is_spicy: dto.is_spicy ?? false,
        is_available: dto.is_available ?? true,
      },
      include: {
        category: { select: { id: true, name: true, badge_text: true } },
        sizes: true,
        options: true,
      },
    });

    this.logger.log(`Created menu item '${created.name}' (${created.id})`);
    return created;
  }

  async updateItem(id: string, dto: UpdateMenuItemDto): Promise<FullMenuItem> {
    const existing = await this.prisma.menuItem.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Menu item with ID '${id}' not found`);
    }

    if (dto.category_id && dto.category_id !== existing.category_id) {
      const category = await this.prisma.menuCategory.findUnique({
        where: { id: dto.category_id },
      });
      if (!category) {
        throw new BadRequestException(`Category with ID '${dto.category_id}' does not exist`);
      }
    }

    const updated = await this.prisma.menuItem.update({
      where: { id },
      data: {
        category_id: dto.category_id ?? existing.category_id,
        name: dto.name ?? existing.name,
        description: dto.description ?? existing.description,
        base_price: dto.base_price ?? existing.base_price,
        image_url: dto.image_url ?? existing.image_url,
        is_veg: dto.is_veg !== undefined ? dto.is_veg : existing.is_veg,
        is_spicy: dto.is_spicy !== undefined ? dto.is_spicy : existing.is_spicy,
        is_available: dto.is_available !== undefined ? dto.is_available : existing.is_available,
      },
      include: {
        category: { select: { id: true, name: true, badge_text: true } },
        sizes: true,
        options: true,
      },
    });

    this.logger.log(`Updated menu item '${updated.name}'`);
    return updated;
  }

  async updateAvailability(id: string, dto: UpdateAvailabilityDto): Promise<FullMenuItem> {
    const existing = await this.prisma.menuItem.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Menu item with ID '${id}' not found`);
    }

    return this.prisma.menuItem.update({
      where: { id },
      data: {
        is_available: dto.is_available,
      },
      include: {
        category: { select: { id: true, name: true, badge_text: true } },
        sizes: true,
        options: true,
      },
    });
  }

  async deleteItem(idOrName: string): Promise<{ message: string }> {
    const existing = await this.prisma.menuItem.findFirst({
      where: {
        OR: [
          { id: idOrName },
          { name: { equals: idOrName, mode: 'insensitive' } },
          { name: { contains: idOrName, mode: 'insensitive' } },
        ],
      },
    });

    if (!existing) {
      throw new NotFoundException(`Menu item '${idOrName}' not found`);
    }

    // Safely unlink any existing order items
    await this.prisma.orderItem.updateMany({
      where: { menu_item_id: existing.id },
      data: { menu_item_id: null },
    });

    // Cascade delete sizes and options
    await this.prisma.menuItemSize.deleteMany({
      where: { menu_item_id: existing.id },
    });
    await this.prisma.menuItemOption.deleteMany({
      where: { menu_item_id: existing.id },
    });

    await this.prisma.menuItem.delete({
      where: { id: existing.id },
    });

    this.logger.log(`Deleted menu item '${existing.name}' (${existing.id})`);
    return { message: `Menu item '${existing.name}' deleted successfully` };
  }
}
