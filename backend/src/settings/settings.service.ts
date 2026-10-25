import { RealtimeGateway } from '../realtime/realtime.gateway';
import { Injectable, Logger, Optional } from '@nestjs/common';
import { Prisma, StoreSetting } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateSettingsDto } from './dto/update-settings.dto';

@Injectable()
export class SettingsService {
  private readonly logger = new Logger(SettingsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async getSettings(): Promise<StoreSetting> {
    let settings = await this.prisma.storeSetting.findFirst();

    if (!settings) {
      settings = await this.initializeDefaultSettings();
    }

    return settings;
  }

  async updateSettings(dto: UpdateSettingsDto): Promise<StoreSetting> {
    return this.prisma.$transaction(async (tx) => {
      let settings = await tx.storeSetting.findFirst();

      if (!settings) {
        settings = await tx.storeSetting.create({
          data: {
            chain_name: dto.chain_name?.trim() || "Hungry Howie's",
            branch_code: dto.branch_code?.trim() || 'Branch #402',
            branch_name: dto.branch_name?.trim() || 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
            store_phone: dto.store_phone?.trim() || '+1 (800) 555-HOWIE',
          },
        });
        return settings;
      }

      const data: Prisma.StoreSettingUpdateInput = {};

      if (dto.chain_name !== undefined) data.chain_name = dto.chain_name.trim();
      if (dto.branch_code !== undefined) data.branch_code = dto.branch_code.trim();
      if (dto.branch_name !== undefined) data.branch_name = dto.branch_name.trim();
      if (dto.store_phone !== undefined) data.store_phone = dto.store_phone.trim();

      data.updated_at = new Date();

      return tx.storeSetting.update({
        where: { id: settings.id },
        data,
      });
    });
  }

  private async initializeDefaultSettings(): Promise<StoreSetting> {
    this.logger.log('Initializing single-row default store settings');
    return this.prisma.storeSetting.create({
      data: {
        chain_name: "Hungry Howie's",
        branch_code: 'Branch #402',
        branch_name: 'Near UOG Gate # 2 Nawaz Sharif Medical College Gujrat.',
        store_phone: '+1 (800) 555-HOWIE',
      },
    });
  }
}
