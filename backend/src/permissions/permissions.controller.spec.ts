import { Test, TestingModule } from '@nestjs/testing';
import { PermissionsController } from './permissions.controller';
import { PermissionsService } from './permissions.service';
import { RolePermission } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';

describe('PermissionsController', () => {
  let controller: PermissionsController;
  let service: PermissionsService;

  const mockPermission: RolePermission = {
    id: 'mod_tables',
    role: 'manager',
    module_name: 'Tables',
    action_name: 'Allow Access to Tables Module',
    description: 'Floor tables',
    is_granted: true,
    is_sensitive: false,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PermissionsController],
      providers: [
        {
          provide: PermissionsService,
          useValue: {
            getPermissionsByRole: jest.fn().mockResolvedValue([mockPermission]),
            togglePermission: jest.fn().mockResolvedValue({
              ...mockPermission,
              is_granted: false,
            }),
            updatePermission: jest.fn().mockResolvedValue({
              ...mockPermission,
              is_granted: true,
            }),
            applyPreset: jest.fn().mockResolvedValue([mockPermission]),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<PermissionsController>(PermissionsController);
    service = module.get<PermissionsService>(PermissionsService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('GET /permissions/role/:role should return permissions list', async () => {
    const response = await controller.getPermissionsByRole('manager');
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
    expect(response.data?.[0].id).toBe('mod_tables');
    expect(service.getPermissionsByRole).toHaveBeenCalledWith('manager');
  });

  it('PATCH /permissions/:id/toggle should toggle permission status', async () => {
    const response = await controller.togglePermission('mod_tables');
    expect(response.success).toBe(true);
    expect(response.message).toBe('Permission toggled successfully');
    expect(response.data?.is_granted).toBe(false);
  });

  it('PATCH /permissions/:id should update permission status', async () => {
    const response = await controller.updatePermission('mod_tables', { is_granted: true });
    expect(response.success).toBe(true);
    expect(response.message).toBe('Permission updated successfully');
    expect(response.data?.is_granted).toBe(true);
  });

  it('POST /permissions/presets should apply preset to role', async () => {
    const response = await controller.applyPreset({ role: 'manager', preset: 'STRICT' });
    expect(response.success).toBe(true);
    expect(response.message).toContain("Preset 'STRICT' applied successfully");
  });
});
