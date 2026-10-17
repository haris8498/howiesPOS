import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { MenuItemOption } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateOptionDto, UpdateOptionDto } from '../dto/option.dto';

@Injectable()
export class OptionsService {
  private readonly logger = new Logger(OptionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async listOptionsByItem(menuItemId: string): Promise<MenuItemOption[]> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: menuItemId },
    });

    if (!item) {
      throw new NotFoundException(`Menu item with ID '${menuItemId}' not found`);
    }

    return this.prisma.menuItemOption.findMany({
      where: { menu_item_id: menuItemId },
      orderBy: { option_name: 'asc' },
    });
  }

  async createOption(menuItemId: string, dto: CreateOptionDto): Promise<MenuItemOption> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: menuItemId },
    });

    if (!item) {
      throw new NotFoundException(`Menu item with ID '${menuItemId}' not found`);
    }

    const created = await this.prisma.menuItemOption.create({
      data: {
        menu_item_id: menuItemId,
        option_type: dto.option_type,
        option_name: dto.option_name,
        additional_price: dto.additional_price ?? 0.0,
      },
    });

    this.logger.log(
      `Added option '${created.option_name}' (${created.option_type}) for item '${item.name}'`,
    );
    return created;
  }

  async updateOption(id: string, dto: UpdateOptionDto): Promise<MenuItemOption> {
    const existing = await this.prisma.menuItemOption.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Option with ID '${id}' not found`);
    }

    const updated = await this.prisma.menuItemOption.update({
      where: { id },
      data: {
        option_type: dto.option_type ?? existing.option_type,
        option_name: dto.option_name ?? existing.option_name,
        additional_price: dto.additional_price ?? existing.additional_price,
      },
    });

    this.logger.log(`Updated option '${updated.option_name}' (${id})`);
    return updated;
  }

  async deleteOption(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.menuItemOption.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Option with ID '${id}' not found`);
    }

    await this.prisma.menuItemOption.delete({
      where: { id },
    });

    this.logger.log(`Deleted option '${existing.option_name}' (${id})`);
    return { message: `Option '${existing.option_name}' deleted successfully` };
  }
}
