import { ConflictException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { MenuCategory } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateCategoryDto, UpdateCategoryDto } from '../dto/category.dto';

@Injectable()
export class CategoriesService {
  private readonly logger = new Logger(CategoriesService.name);

  constructor(private readonly prisma: PrismaService) {}

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
    return { message: `Category '${existing.name}' deleted successfully` };
  }
}
