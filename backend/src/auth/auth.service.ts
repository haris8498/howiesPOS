import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { AuthLoginData, JwtPayload } from './interfaces/jwt-payload.interface';
import { PasswordService } from './password.service';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly passwordService: PasswordService,
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

    const isPasswordValid = await this.passwordService.verify(
      user.password_hash,
      loginDto.password,
    );

    if (!isPasswordValid) {
      this.logger.warn(`Invalid password for user: ${loginDto.username}`);
      throw new UnauthorizedException('Invalid username or password');
    }

    // Transparently upgrade legacy or wrapped hashes to Argon2id on successful authentication
    if (this.passwordService.needsRehash(user.password_hash)) {
      try {
        const upgradedHash = await this.passwordService.hash(loginDto.password);
        await this.prisma.staffUser.update({
          where: { id: user.id },
          data: {
            password_hash: upgradedHash,
            plain_password: user.plain_password ?? loginDto.password,
          },
        });
        this.logger.log(
          `Transparently upgraded password hash to Argon2id for user '${user.username}'`,
        );
      } catch (upgradeErr: unknown) {
        this.logger.error(
          `Failed to transparently upgrade password hash for user '${user.username}': ${(upgradeErr as Error)?.message ?? upgradeErr}`,
        );
      }
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
    return this.passwordService.hash(password);
  }

  async verifyPassword(hash: string, plain: string): Promise<boolean> {
    return this.passwordService.verify(hash, plain);
  }
}
