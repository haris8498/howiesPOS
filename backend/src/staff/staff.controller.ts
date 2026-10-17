import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { StaffService, StaffMemberWithUser, StaffStats } from './staff.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { QueryStaffDto } from './dto/query-staff.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/interfaces/jwt-payload.interface';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('staff')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class StaffController {
  constructor(private readonly staffService: StaffService) {}

  @Get()
  @RequirePermission('Users', 'Allow Access to Users')
  async listStaff(@Query() query: QueryStaffDto): Promise<ApiResponse<StaffMemberWithUser[]>> {
    const data = await this.staffService.listStaff(query);
    return {
      success: true,
      data,
    };
  }

  @Get('stats')
  @RequirePermission('Users', 'Allow Access to Users')
  async getStaffStats(@Query('month_year') monthYear?: string): Promise<ApiResponse<StaffStats>> {
    const data = await this.staffService.getStaffStats(monthYear);
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  @RequirePermission('Users', 'Allow Access to Users')
  async getStaffById(@Param('id') id: string): Promise<ApiResponse<StaffMemberWithUser>> {
    const data = await this.staffService.getStaffById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Users', 'Add Users')
  async createStaff(
    @Body() dto: CreateStaffDto,
    @CurrentUser() actor: AuthenticatedUser,
  ): Promise<ApiResponse<StaffMemberWithUser>> {
    const data = await this.staffService.createStaff(dto, actor);
    return {
      success: true,
      message: 'Staff member created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Users', 'Edit Users')
  async updateStaff(
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
  ): Promise<ApiResponse<StaffMemberWithUser>> {
    const data = await this.staffService.updateStaff(id, dto);
    return {
      success: true,
      message: 'Staff member updated successfully',
      data,
    };
  }

  @Delete(':id')
  @RequirePermission('Users', 'Delete Users')
  async deleteStaff(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.staffService.deleteStaff(id);
    return {
      success: true,
      message: data.message,
    };
  }

  @Post(':id/salary-settle')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('Users', 'Mark Salary Paid')
  async settleSalary(
    @Param('id') id: string,
    @Body('month_year') monthYear?: string,
  ): Promise<ApiResponse<StaffMemberWithUser>> {
    const data = await this.staffService.settleSalary(id, monthYear);
    return {
      success: true,
      message: 'Staff salary settled successfully',
      data,
    };
  }

  @Post(':id/toggle-salary')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('Users', 'Mark Salary Paid')
  async toggleSalary(
    @Param('id') id: string,
    @Body('month_year') monthYear?: string,
  ): Promise<ApiResponse<StaffMemberWithUser>> {
    const data = await this.staffService.toggleSalary(id, monthYear);
    return {
      success: true,
      message: 'Staff salary paid status toggled successfully',
      data,
    };
  }
}
