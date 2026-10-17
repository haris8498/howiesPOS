import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { PermissionsService } from './permissions.service';
import { UpdatePermissionDto } from './dto/update-permission.dto';
import { ApplyPresetDto } from './dto/apply-preset.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';
import { ApiResponse } from '../common/types/api-response.type';
import { RolePermission } from '@prisma/client';

@Controller('permissions')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class PermissionsController {
  constructor(private readonly permissionsService: PermissionsService) {}

  @Get('role/:role')
  async getPermissionsByRole(@Param('role') role: string): Promise<ApiResponse<RolePermission[]>> {
    const data = await this.permissionsService.getPermissionsByRole(role);
    return {
      success: true,
      data,
    };
  }

  @Patch(':id/toggle')
  @RequirePermission('Staff Permissions', 'Allow Access to Staff Permissions Portal')
  async togglePermission(@Param('id') id: string): Promise<ApiResponse<RolePermission>> {
    const data = await this.permissionsService.togglePermission(id);
    return {
      success: true,
      message: 'Permission toggled successfully',
      data,
    };
  }

  @Patch(':id')
  async updatePermission(
    @Param('id') id: string,
    @Body() updateDto: UpdatePermissionDto,
  ): Promise<ApiResponse<RolePermission>> {
    const data = await this.permissionsService.updatePermission(id, updateDto.is_granted);
    return {
      success: true,
      message: 'Permission updated successfully',
      data,
    };
  }

  @Post('presets')
  @HttpCode(HttpStatus.OK)
  async applyPreset(@Body() applyDto: ApplyPresetDto): Promise<ApiResponse<RolePermission[]>> {
    const data = await this.permissionsService.applyPreset(applyDto.role, applyDto.preset);
    return {
      success: true,
      message: `Preset '${applyDto.preset}' applied successfully for role '${applyDto.role}'`,
      data,
    };
  }
}
