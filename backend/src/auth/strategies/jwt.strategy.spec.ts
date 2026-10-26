import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtStrategy } from './jwt.strategy';
import { PrismaService } from '../../prisma/prisma.service';

describe('JwtStrategy (SYNC-007: Deactivated staff account rejection)', () => {
  let strategy: JwtStrategy;
  let mockPrisma: any;
  let mockConfigService: any;

  beforeEach(() => {
    mockConfigService = {
      get: jest.fn().mockImplementation((key: string) => {
        if (key === 'JWT_SECRET') return 'test-jwt-secret-key-1234567890';
        return null;
      }),
    };

    mockPrisma = {
      staffUser: {
        findUnique: jest.fn(),
      },
    };

    strategy = new JwtStrategy(
      mockConfigService as ConfigService,
      mockPrisma as PrismaService,
    );
  });

  it('should validate and return active user', async () => {
    mockPrisma.staffUser.findUnique.mockResolvedValue({
      id: 'usr-1',
      username: 'cashier1',
      role: 'cashier',
      is_default: false,
      is_active: true,
    });

    const user = await strategy.validate({
      sub: 'usr-1',
      username: 'cashier1',
      role: 'cashier',
    });

    expect(user).toEqual({
      id: 'usr-1',
      username: 'cashier1',
      role: 'cashier',
      is_default: false,
    });
  });

  it('should throw UnauthorizedException if user does not exist', async () => {
    mockPrisma.staffUser.findUnique.mockResolvedValue(null);

    await expect(
      strategy.validate({
        sub: 'non-existent',
        username: 'ghost',
        role: 'cashier',
      }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('SYNC-007: should immediately throw UnauthorizedException if staff user is deactivated (is_active: false)', async () => {
    mockPrisma.staffUser.findUnique.mockResolvedValue({
      id: 'usr-fired',
      username: 'fired_cashier',
      role: 'cashier',
      is_default: false,
      is_active: false,
    });

    await expect(
      strategy.validate({
        sub: 'usr-fired',
        username: 'fired_cashier',
        role: 'cashier',
      }),
    ).rejects.toThrow(new UnauthorizedException('User account is deactivated'));
  });
});
