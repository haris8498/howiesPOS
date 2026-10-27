import { ConflictException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from './users.service';
import { PasswordService } from '../auth/password.service';

describe('UsersService', () => {
  let service: UsersService;
  let passwordService: PasswordService;

  const mockSafeUser = {
    id: 'u-1',
    username: 'storemanager',
    role: 'manager',
    is_default: true,
    last_updated: new Date(),
    updated_by: 'Super Admin',
    staff_member: null,
  };

  const mockActor = {
    id: 'admin-id',
    username: 'superadmin',
    role: 'owner',
    is_default: true,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
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
              findMany: jest.fn().mockResolvedValue([mockSafeUser]),
              findUnique: jest.fn().mockImplementation(({ where, select }) => {
                if (where.id === 'u-1' || where.username === 'storemanager') {
                  if (select && !select.password_hash) {
                    return Promise.resolve(mockSafeUser);
                  }
                  return Promise.resolve({
                    ...mockSafeUser,
                    password_hash: '$argon2id$mockhash',
                  });
                }
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'u-new',
                  username: data.username,
                  email: data.email,
                  role: data.role,
                  is_default: data.is_default ?? false,
                  last_updated: new Date(),
                  updated_by: data.updated_by,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockSafeUser,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockSafeUser),
            },
            staffMember: {
              update: jest.fn().mockResolvedValue({}),
            },
            $transaction: jest.fn().mockImplementation((cb) =>
              cb({
                staffMember: { update: jest.fn().mockResolvedValue({}) },
                staffUser: {
                  update: jest.fn().mockResolvedValue(mockSafeUser),
                  delete: jest.fn().mockResolvedValue(mockSafeUser),
                },
              }),
            ),
          },
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    passwordService = module.get<PasswordService>(PasswordService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should list all users with safe properties', async () => {
    const users = await service.listUsers();
    expect(users).toHaveLength(1);
    expect(users[0].username).toBe('storemanager');
    expect((users[0] as unknown as Record<string, unknown>).password_hash).toBeUndefined();
    expect((users[0] as unknown as Record<string, unknown>).plain_password).toBeUndefined();
  });

  it('should get user by id', async () => {
    const user = await service.getUserById('u-1');
    expect(user.id).toBe('u-1');
    expect((user as unknown as Record<string, unknown>).password_hash).toBeUndefined();
    expect((user as unknown as Record<string, unknown>).plain_password).toBeUndefined();
  });

  it('should throw NotFoundException for invalid user id', async () => {
    await expect(service.getUserById('invalid')).rejects.toThrow(NotFoundException);
  });

  it('should create new staff user with hashed password', async () => {
    const created = await service.createUser(
      {
        username: 'newcashier',
        password: 'password123',
        role: 'cashier',
      },
      mockActor,
    );

    expect(created.username).toBe('newcashier');
    expect(created.role).toBe('cashier');
    expect((created as unknown as Record<string, unknown>).password_hash).toBeUndefined();
    expect((created as unknown as Record<string, unknown>).plain_password).toBeUndefined();
  }, 15000);

  it('should throw ConflictException if username already exists', async () => {
    await expect(
      service.createUser(
        {
          username: 'storemanager',
          password: 'password123',
          role: 'manager',
        },
        mockActor,
      ),
    ).rejects.toThrow(ConflictException);
  });

  it('should update password and hash it', async () => {
    const spyHash = jest
      .spyOn(passwordService, 'hash')
      .mockResolvedValue('newhashedpassword' as never);
    const result = await service.updatePassword('u-1', 'newSecretPass', mockActor);

    expect(result.message).toBe('Password updated successfully');
    expect(spyHash).toHaveBeenCalledWith('newSecretPass');
  });

  it('should delete user successfully', async () => {
    const result = await service.deleteUser('u-1');
    expect(result.message).toContain('deleted');
  });
});
