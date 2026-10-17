import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { AuthLoginData, JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async login(loginDto: LoginDto): Promise<AuthLoginData> {
    const trimmedUsername = loginDto.username.trim();
    const user = await this.prisma.staffUser.findFirst({
      where: {
        username: {
          equals: trimmedUsername,
          mode: 'insensitive',
        },
      },
    });

    if (!user) {
      this.logger.warn(`Failed login attempt for unknown username`);
      throw new UnauthorizedException('Invalid username or password');
    }

    if (user.is_active === false) {
      this.logger.warn(`Login attempt for deactivated user: ${loginDto.username}`);
      throw new UnauthorizedException('This user account has been deactivated');
    }

    const isPasswordValid = await argon2.verify(user.password_hash, loginDto.password);

    if (!isPasswordValid) {
      this.logger.warn(`Invalid password for user: ${loginDto.username}`);
      throw new UnauthorizedException('Invalid username or password');
    }

    const payload: JwtPayload = {
      sub: user.id,
      username: user.username,
      role: user.role,
    };

    const accessToken = this.jwtService.sign(payload);

    return {
      accessToken,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        is_default: user.is_default,
      },
    };
  }

  async hashPassword(password: string): Promise<string> {
    return argon2.hash(password);
  }

  async verifyPassword(hash: string, plain: string): Promise<boolean> {
    return argon2.verify(hash, plain);
  }
}
