import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';

describe('AuthService', () => {
  let authService: AuthService;

  const mockStaffUser = {
    id: 'user-uuid-123',
    username: 'admin',
    email: 'admin@hungryhowies.com',
    password_hash: '',
    role: 'manager',
    is_default: true,
    last_updated: new Date(),
    updated_by: 'Super Admin',
  };

  beforeAll(async () => {
    mockStaffUser.password_hash = await argon2.hash('admin123', {
      type: argon2.argon2id,
      memoryCost: 19456,
      timeCost: 2,
      parallelism: 1,
    });
  }, 15000);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        PasswordService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string, defaultValue?: unknown) => {
              if (key === 'ARGON2_MEMORY_COST') return 19456;
              if (key === 'ARGON2_TIME_COST') return 2;
              if (key === 'ARGON2_PARALLELISM') return 1;
              return defaultValue;
            }),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            staffUser: {
              findUnique: jest.fn().mockImplementation(({ where: { username } }) => {
                if (username && username.toLowerCase() === 'admin') {
                  return Promise.resolve(mockStaffUser);
                }
                return Promise.resolve(null);
              }),
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const username =
                  typeof where?.username === 'string' ? where.username : where?.username?.equals;
                if (username && username.toLowerCase() === 'admin') {
                  return Promise.resolve(mockStaffUser);
                }
                return Promise.resolve(null);
              }),
              update: jest.fn().mockResolvedValue(mockStaffUser),
            },
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('mock-jwt-token-xyz'),
          },
        },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
  });

  it('should be defined', () => {
    expect(authService).toBeDefined();
  });

  it('should successfully authenticate valid credentials and return JWT token', async () => {
    const result = await authService.login({
      username: 'admin',
      password: 'admin123',
    });

    expect(result).toBeDefined();
    expect(result.accessToken).toBe('mock-jwt-token-xyz');
    expect(result.user.id).toBe('user-uuid-123');
    expect(result.user.username).toBe('admin');
    expect(result.user.role).toBe('manager');
  });

  it('should throw UnauthorizedException for unknown username', async () => {
    await expect(
      authService.login({
        username: 'unknown_user',
        password: 'password123',
      }),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('should throw UnauthorizedException for incorrect password', async () => {
    await expect(
      authService.login({
        username: 'admin',
        password: 'wrong_password',
      }),
    ).rejects.toThrow(UnauthorizedException);
  });
});
