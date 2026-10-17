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
  UseGuards,
} from '@nestjs/common';
import { UsersService, SafeUser } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdatePasswordDto } from './dto/update-password.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { RequirePermission } from '../common/rbac/decorators/permissions.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { AuthenticatedUser } from '../auth/interfaces/jwt-payload.interface';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('users')
@UseGuards(JwtAuthGuard, PermissionsGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @RequirePermission('Users', 'Allow Access to Users')
  async listUsers(): Promise<ApiResponse<SafeUser[]>> {
    const data = await this.usersService.listUsers();
    return {
      success: true,
      data,
    };
  }

  @Get(':id')
  @RequirePermission('Users', 'Allow Access to Users')
  async getUserById(@Param('id') id: string): Promise<ApiResponse<SafeUser>> {
    const data = await this.usersService.getUserById(id);
    return {
      success: true,
      data,
    };
  }

  @Post()
  @RequirePermission('Users', 'Add Users')
  async createUser(
    @Body() dto: CreateUserDto,
    @CurrentUser() actor: AuthenticatedUser,
  ): Promise<ApiResponse<SafeUser>> {
    const data = await this.usersService.createUser(dto, actor);
    return {
      success: true,
      message: 'Staff user created successfully',
      data,
    };
  }

  @Patch(':id')
  @RequirePermission('Users', 'Edit Users')
  async updateUser(
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
    @CurrentUser() actor: AuthenticatedUser,
  ): Promise<ApiResponse<SafeUser>> {
    const data = await this.usersService.updateUser(id, dto, actor);
    return {
      success: true,
      message: 'Staff user updated successfully',
      data,
    };
  }

  @Patch(':id/password')
  @HttpCode(HttpStatus.OK)
  @RequirePermission('Users', 'Edit Users')
  async updatePassword(
    @Param('id') id: string,
    @Body() dto: UpdatePasswordDto,
    @CurrentUser() actor: AuthenticatedUser,
  ): Promise<ApiResponse<{ message: string }>> {
    const data = await this.usersService.updatePassword(id, dto.new_password, actor);
    return {
      success: true,
      message: data.message,
    };
  }

  @Delete(':id')
  @RequirePermission('Users', 'Delete Users')
  async deleteUser(@Param('id') id: string): Promise<ApiResponse<{ message: string }>> {
    const data = await this.usersService.deleteUser(id);
    return {
      success: true,
      message: data.message,
    };
  }
}
