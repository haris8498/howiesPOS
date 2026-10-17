import { ConflictException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { MenuItemSize } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSizeDto, UpdateSizeDto } from '../dto/size.dto';

@Injectable()
export class SizesService {
  private readonly logger = new Logger(SizesService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listSizesByItem(menuItemId: string): Promise<MenuItemSize[]> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: menuItemId },
    });

    if (!item) {
      throw new NotFoundException(`Menu item with ID '${menuItemId}' not found`);
    }

    return this.prisma.menuItemSize.findMany({
      where: { menu_item_id: menuItemId },
      orderBy: { price: 'asc' },
    });
  }

  async createSize(menuItemId: string, dto: CreateSizeDto): Promise<MenuItemSize> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: menuItemId },
    });

    if (!item) {
      throw new NotFoundException(`Menu item with ID '${menuItemId}' not found`);
    }

    const existingSize = await this.prisma.menuItemSize.findFirst({
      where: {
        menu_item_id: menuItemId,
        size_name: { equals: dto.size_name, mode: 'insensitive' },
      },
    });

    if (existingSize) {
      throw new ConflictException(`Size '${dto.size_name}' already exists for this menu item`);
    }

    const created = await this.prisma.menuItemSize.create({
      data: {
        menu_item_id: menuItemId,
        size_name: dto.size_name,
        price: dto.price,
      },
    });

    this.logger.log(`Added size tier '${created.size_name}' for item '${item.name}'`);
    return created;
  }

  async updateSize(id: string, dto: UpdateSizeDto): Promise<MenuItemSize> {
    const existing = await this.prisma.menuItemSize.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Size with ID '${id}' not found`);
    }

    if (dto.size_name && dto.size_name !== existing.size_name) {
      const duplicate = await this.prisma.menuItemSize.findFirst({
        where: {
          menu_item_id: existing.menu_item_id,
          size_name: { equals: dto.size_name, mode: 'insensitive' },
          NOT: { id },
        },
      });

      if (duplicate) {
        throw new ConflictException(`Size '${dto.size_name}' already exists for this menu item`);
      }
    }

    const updated = await this.prisma.menuItemSize.update({
      where: { id },
      data: {
        size_name: dto.size_name ?? existing.size_name,
        price: dto.price ?? existing.price,
      },
    });

    this.logger.log(`Updated size '${updated.size_name}' (${id})`);
    return updated;
  }

  async deleteSize(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.menuItemSize.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Size with ID '${id}' not found`);
    }

    await this.prisma.menuItemSize.delete({
      where: { id },
    });

    this.logger.log(`Deleted size tier '${existing.size_name}' (${id})`);
    return { message: `Size tier '${existing.size_name}' deleted successfully` };
  }
}
