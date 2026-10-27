import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';
import { PrismaService } from '../prisma/prisma.service';
import { SyncPullService } from '../sync/sync-pull.service';
import { ChangeLogService } from '../sync/change-log.service';

describe('Credential Sanitization and Hash Masking Security (SEC-05, SEC-07)', () => {
  let usersService: UsersService;
  let authService: AuthService;
  let syncPullService: SyncPullService;
  let passwordService: PasswordService;

  const mockDbStaffUser = {
    id: 'u-secret-1',
    username: 'storecashier',
    password_hash: '$argon2id$v=19$m=19456,t=2,p=1$secret_hash_value',
    plain_password: 'ShouldNeverBeReturned',
    role: 'cashier',
    is_default: false,
    is_active: true,
    last_updated: new Date(),
    updated_by: 'Super Admin',
    staff_member: {
      id: 'sm-1',
      full_name: 'Test Cashier',
      phone: '0300-1111111',
      assigned_shift: 'Morning Shift',
    },
  };

  const mockPrisma = {
    staffUser: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    staffMember: {
      create: jest.fn(),
      update: jest.fn(),
    },
    storeSetting: { findMany: jest.fn().mockResolvedValue([]) },
    rolePermission: { findMany: jest.fn().mockResolvedValue([]) },
    menuCategory: { findMany: jest.fn().mockResolvedValue([]) },
    menuItem: { findMany: jest.fn().mockResolvedValue([]) },
    menuItemSize: { findMany: jest.fn().mockResolvedValue([]) },
    menuItemOption: { findMany: jest.fn().mockResolvedValue([]) },
    deal: { findMany: jest.fn().mockResolvedValue([]) },
    floorZone: { findMany: jest.fn().mockResolvedValue([]) },
    restaurantTable: { findMany: jest.fn().mockResolvedValue([]) },
    deliveryRider: { findMany: jest.fn().mockResolvedValue([]) },
    dailyCalculation: { findFirst: jest.fn().mockResolvedValue(null) },
    order: { findMany: jest.fn().mockResolvedValue([]) },
    systemChangeLog: { findMany: jest.fn().mockResolvedValue([]) },
    $transaction: jest.fn().mockImplementation((cb) => cb(mockPrisma)),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        AuthService,
        PasswordService,
        SyncPullService,
        {
          provide: ChangeLogService,
          useValue: {
            getMaxSequence: jest.fn().mockResolvedValue(10),
          },
        },
        { provide: PrismaService, useValue: mockPrisma },
        {
          provide: JwtService,
          useValue: { sign: jest.fn(() => 'jwt-token-val') },
        },
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

    usersService = module.get<UsersService>(UsersService);
    authService = module.get<AuthService>(AuthService);
    syncPullService = module.get<SyncPullService>(SyncPullService);
    passwordService = module.get<PasswordService>(PasswordService);

    jest.clearAllMocks();
  });

  describe('UsersService sanitization', () => {
    it('listUsers() must never select or return password_hash or plain_password', async () => {
      mockPrisma.staffUser.findMany.mockImplementation(({ select }) => {
        expect(select.password_hash).toBeUndefined();
        expect(select.plain_password).toBeUndefined();
        const safe = { ...mockDbStaffUser };
        delete (safe as Record<string, unknown>).password_hash;
        delete (safe as Record<string, unknown>).plain_password;
        return Promise.resolve([safe]);
      });

      const users = await usersService.listUsers();
      expect(users).toHaveLength(1);
      const userObj = users[0] as Record<string, unknown>;
      expect(userObj.password_hash).toBeUndefined();
      expect(userObj.plain_password).toBeUndefined();
      expect(userObj.password).toBeUndefined();
    });

    it('getUserById() must never select or return password_hash or plain_password', async () => {
      mockPrisma.staffUser.findUnique.mockImplementation(({ select }) => {
        expect(select.password_hash).toBeUndefined();
        expect(select.plain_password).toBeUndefined();
        const safe = { ...mockDbStaffUser };
        delete (safe as Record<string, unknown>).password_hash;
        delete (safe as Record<string, unknown>).plain_password;
        return Promise.resolve(safe);
      });

      const user = await usersService.getUserById('u-secret-1');
      const userObj = user as Record<string, unknown>;
      expect(userObj.password_hash).toBeUndefined();
      expect(userObj.plain_password).toBeUndefined();
      expect(userObj.password).toBeUndefined();
    });

    it('createUser() must never return password_hash or plain_password in response', async () => {
      mockPrisma.staffUser.findUnique.mockResolvedValue(null);
      mockPrisma.staffUser.create.mockImplementation(({ select, data }) => {
        expect(select.password_hash).toBeUndefined();
        expect(select.plain_password).toBeUndefined();
        expect(data.plain_password).toBeNull();
        const safe = { ...mockDbStaffUser, id: 'u-created', username: data.username };
        delete (safe as Record<string, unknown>).password_hash;
        delete (safe as Record<string, unknown>).plain_password;
        return Promise.resolve(safe);
      });

      const created = await usersService.createUser(
        { username: 'newuser', password: 'SecretPassword123!', role: 'cashier' },
        { id: 'admin-id', username: 'admin', role: 'owner', is_default: true },
      );

      const createdObj = created as Record<string, unknown>;
      expect(createdObj.password_hash).toBeUndefined();
      expect(createdObj.plain_password).toBeUndefined();
      expect(createdObj.password).toBeUndefined();
    });

    it('updateUser() must never return password_hash or plain_password in response', async () => {
      mockPrisma.staffUser.findUnique.mockResolvedValue(mockDbStaffUser);
      mockPrisma.staffUser.update.mockImplementation(({ select, data }) => {
        expect(select.password_hash).toBeUndefined();
        expect(select.plain_password).toBeUndefined();
        if (data.password_hash) {
          expect(data.plain_password).toBeNull();
        }
        const safe = { ...mockDbStaffUser, ...data };
        delete (safe as Record<string, unknown>).password_hash;
        delete (safe as Record<string, unknown>).plain_password;
        return Promise.resolve(safe);
      });

      const updated = await usersService.updateUser(
        'u-secret-1',
        { password: 'NewSecretPassword!' },
        { id: 'admin-id', username: 'admin', role: 'owner', is_default: true },
      );

      const updatedObj = updated as Record<string, unknown>;
      expect(updatedObj.password_hash).toBeUndefined();
      expect(updatedObj.plain_password).toBeUndefined();
      expect(updatedObj.password).toBeUndefined();
    });
  });

  describe('AuthService sanitization', () => {
    it('login() response must never contain password_hash or plain_password', async () => {
      const validHash = await passwordService.hash('Secret123!');
      mockPrisma.staffUser.findFirst.mockResolvedValue({
        ...mockDbStaffUser,
        password_hash: validHash,
      });

      const response = await authService.login({
        username: 'storecashier',
        password: 'Secret123!',
      });

      expect(response.accessToken).toBeDefined();
      const userResponse = response.user as Record<string, unknown>;
      expect(userResponse.password_hash).toBeUndefined();
      expect(userResponse.plain_password).toBeUndefined();
      expect(userResponse.password).toBeUndefined();
      expect((response as Record<string, unknown>).password_hash).toBeUndefined();
      expect((response as Record<string, unknown>).plain_password).toBeUndefined();
    });
  });

  describe('SyncPullService sanitization', () => {
    it('getBootstrapData() must never select or return password_hash or plain_password in staff_users payload', async () => {
      mockPrisma.staffUser.findMany.mockImplementation(({ select }) => {
        expect(select.password_hash).toBeUndefined();
        expect(select.plain_password).toBeUndefined();
        return Promise.resolve([
          {
            id: 'u-1',
            username: 'cashier1',
            role: 'cashier',
            is_default: false,
            is_active: true,
            last_updated: new Date(),
            updated_by: 'Super Admin',
          },
        ]);
      });

      const bootstrapResult = await syncPullService.getBootstrapData();
      const staffUsers = bootstrapResult.staff_users || [];
      expect(staffUsers.length).toBeGreaterThan(0);

      for (const su of staffUsers) {
        const anyUser = su as Record<string, unknown>;
        expect(anyUser.password_hash).toBeUndefined();
        expect(anyUser.plain_password).toBeUndefined();
        expect(anyUser.password).toBeUndefined();
      }
    });
  });
});
