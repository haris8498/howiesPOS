import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionsService } from './permissions.service';

describe('PermissionsService', () => {
  let service: PermissionsService;
  let prisma: PrismaService;

  const mockPermissions = [
    {
      id: 'mod_tables',
      role: 'manager',
      module_name: 'Tables',
      action_name: 'Allow Access to Tables Module',
      description: 'Access tables',
      is_granted: true,
      is_sensitive: false,
    },
    {
      id: 'menu_delete',
      role: 'manager',
      module_name: 'Menu Catalog',
      action_name: 'Delete Menu Items',
      description: 'Delete dishes',
      is_granted: false,
      is_sensitive: true,
    },
  ];

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PermissionsService,
        {
          provide: PrismaService,
          useValue: {
            rolePermission: {
              findFirst: jest.fn().mockImplementation(({ where }) => {
                const found = mockPermissions.find(
                  (p) =>
                    (where.role === undefined || p.role === where.role) &&
                    (where.module_name === undefined || (where.module_name?.in ? where.module_name.in.includes(p.module_name) : p.module_name === where.module_name)) &&
                    (where.action_name === undefined || (where.action_name?.in ? where.action_name.in.includes(p.action_name) : p.action_name === where.action_name)) &&
                    (where.is_granted === undefined || p.is_granted === where.is_granted),
                );
                return Promise.resolve(found || null);
              }),
              findMany: jest.fn().mockResolvedValue(mockPermissions),
              findUnique: jest.fn().mockImplementation(({ where: { id } }) => {
                const found = mockPermissions.find((p) => p.id === id);
                return Promise.resolve(found || null);
              }),
              count: jest.fn().mockResolvedValue(mockPermissions.length),
              create: jest.fn().mockImplementation(({ data }) => Promise.resolve(data)),
              update: jest.fn().mockImplementation(({ where: { id }, data }) => {
                const existing = mockPermissions.find((p) => p.id === id);
                if (!existing) return Promise.resolve(null);
                return Promise.resolve({ ...existing, ...data });
              }),
              updateMany: jest.fn().mockResolvedValue({ count: 1 }),
              upsert: jest.fn().mockResolvedValue(mockPermissions[0]),
            },
          },
        },
      ],
    }).compile();

    service = module.get<PermissionsService>(PermissionsService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should allow owner unrestricted access for any module/action', async () => {
    const result = await service.hasPermission('owner', 'NonExistentModule', 'AnyAction');
    expect(result).toBe(true);
  });

  it('should return true when role has granted permission', async () => {
    const result = await service.hasPermission(
      'manager',
      'Tables',
      'Allow Access to Tables Module',
    );
    expect(result).toBe(true);
  });

  it('should return false when permission is not granted', async () => {
    const result = await service.hasPermission('manager', 'Menu Catalog', 'Delete Menu Items');
    expect(result).toBe(false);
  });

  it('should return false when permission record does not exist', async () => {
    const result = await service.hasPermission('cashier', 'Reports', 'Export PDF');
    expect(result).toBe(false);
  });

  it('should toggle a permission successfully', async () => {
    const result = await service.togglePermission('menu_delete');
    expect(result.is_granted).toBe(true);
  });

  it('should throw NotFoundException if permission to toggle does not exist', async () => {
    await expect(service.togglePermission('invalid_id')).rejects.toThrow(NotFoundException);
  });

  it('should apply STRICT preset and revoke sensitive permissions', async () => {
    const result = await service.applyPreset('manager', 'STRICT');
    expect(prisma.rolePermission.updateMany).toHaveBeenCalledWith({
      where: { role: 'manager', is_sensitive: true },
      data: { is_granted: false },
    });
    expect(result).toBeDefined();
  });

  it('should apply FULL preset and grant all permissions', async () => {
    const result = await service.applyPreset('manager', 'FULL');
    expect(prisma.rolePermission.updateMany).toHaveBeenCalledWith({
      where: { role: 'manager' },
      data: { is_granted: true },
    });
    expect(result).toBeDefined();
  });
});
