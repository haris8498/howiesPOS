import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { AuthenticatedUser, AuthLoginData } from './interfaces/jwt-payload.interface';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ApiResponse } from '../common/types/api-response.type';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() loginDto: LoginDto): Promise<ApiResponse<AuthLoginData>> {
    const data = await this.authService.login(loginDto);
    return {
      success: true,
      message: 'Login successful',
      data,
    };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getProfile(
    @CurrentUser() user: AuthenticatedUser,
  ): Promise<ApiResponse<AuthenticatedUser>> {
    return {
      success: true,
      data: user,
    };
  }
}
