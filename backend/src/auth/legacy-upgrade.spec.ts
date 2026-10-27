import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AuthService Legacy Upgrade Integration', () => {
  let authService: AuthService;
  let passwordService: PasswordService;

  const legacyPlain = 'LegacySecret123!';
  const legacySha256Hex = crypto.createHash('sha256').update(legacyPlain).digest('hex');

  const mockStaffUser = {
    id: 'user-uuid-1',
    username: 'legacyuser',
    password_hash: legacySha256Hex,
    plain_password: 'LegacySecret123!',
    role: 'cashier',
    is_default: false,
    is_active: true,
  };

  const mockPrisma = {
    staffUser: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
  };

  const mockJwtService = {
    sign: jest.fn(() => 'mock-jwt-token'),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        PasswordService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwtService },
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
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    passwordService = module.get<PasswordService>(PasswordService);

    jest.clearAllMocks();
  });

  it('should transparently rehash legacy SHA-256 user to Argon2id and clear plain_password on login', async () => {
    mockPrisma.staffUser.findFirst.mockResolvedValue({ ...mockStaffUser });
    mockPrisma.staffUser.update.mockResolvedValue({ ...mockStaffUser });

    const result = await authService.login({
      username: 'legacyuser',
      password: legacyPlain,
    });

    expect(result).toBeDefined();
    expect(result.accessToken).toBe('mock-jwt-token');
    expect(result.user.username).toBe('legacyuser');

    // Verify transparent rehash in DB
    expect(mockPrisma.staffUser.update).toHaveBeenCalledTimes(1);
    const updateCall = mockPrisma.staffUser.update.mock.calls[0][0];
    expect(updateCall.where).toEqual({ id: 'user-uuid-1' });
    expect(updateCall.data.password_hash.startsWith('$argon2id$')).toBe(true);
    expect(updateCall.data.plain_password).toBeNull();
  });

  it('should transparently unwrap-upgrade wrapped legacy hash (argon2id-wrap$) on login', async () => {
    const wrappedHash = await passwordService.wrapLegacyHash(legacySha256Hex);
    mockPrisma.staffUser.findFirst.mockResolvedValue({
      ...mockStaffUser,
      password_hash: wrappedHash,
      plain_password: null,
    });
    mockPrisma.staffUser.update.mockResolvedValue({ ...mockStaffUser });

    const result = await authService.login({
      username: 'legacyuser',
      password: legacyPlain,
    });

    expect(result).toBeDefined();
    expect(result.accessToken).toBe('mock-jwt-token');

    // Verify upgraded from wrapped to native Argon2id
    expect(mockPrisma.staffUser.update).toHaveBeenCalledTimes(1);
    const updateCall = mockPrisma.staffUser.update.mock.calls[0][0];
    expect(updateCall.data.password_hash.startsWith('$argon2id$')).toBe(true);
    expect(updateCall.data.password_hash.startsWith('argon2id-wrap$')).toBe(false);
    expect(updateCall.data.plain_password).toBeNull();
  });

  it('should NOT update password_hash if already valid Argon2id with matching params', async () => {
    const modernHash = await passwordService.hash(legacyPlain);
    mockPrisma.staffUser.findFirst.mockResolvedValue({
      ...mockStaffUser,
      password_hash: modernHash,
      plain_password: null,
    });

    const result = await authService.login({
      username: 'legacyuser',
      password: legacyPlain,
    });

    expect(result).toBeDefined();
    expect(mockPrisma.staffUser.update).not.toHaveBeenCalled();
  });

  it('should reject wrong password and NOT update database', async () => {
    mockPrisma.staffUser.findFirst.mockResolvedValue({ ...mockStaffUser });

    await expect(
      authService.login({
        username: 'legacyuser',
        password: 'IncorrectPassword',
      }),
    ).rejects.toThrow(UnauthorizedException);

    expect(mockPrisma.staffUser.update).not.toHaveBeenCalled();
  });
});
