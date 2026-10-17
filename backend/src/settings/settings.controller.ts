import { Body, Controller, Get, Patch, Put, UseGuards } from '@nestjs/common';
import { StoreSetting } from '@prisma/client';
import { SettingsService } from './settings.service';
import { UpdateSettingsDto } from './dto/update-settings.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('settings')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class SettingsController {
  constructor(private readonly settingsService: SettingsService) {}

  @Get()
  async getSettings(): Promise<ApiResponse<StoreSetting>> {
    const data = await this.settingsService.getSettings();
    return {
      success: true,
      data,
    };
  }

  @Patch()
  async updateSettings(@Body() dto: UpdateSettingsDto): Promise<ApiResponse<StoreSetting>> {
    const data = await this.settingsService.updateSettings(dto);
    return {
      success: true,
      message: 'Store settings updated successfully',
      data,
    };
  }

  @Put()
  async replaceSettings(@Body() dto: UpdateSettingsDto): Promise<ApiResponse<StoreSetting>> {
    const data = await this.settingsService.updateSettings(dto);
    return {
      success: true,
      message: 'Store settings updated successfully',
      data,
    };
  }
}
