import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { SettingsController } from './settings.controller';
import { SettingsService } from './settings.service';
import { PermissionsGuard } from '../common/rbac/guards/permissions.guard';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';

describe('SettingsController', () => {
  let controller: SettingsController;

  const mockSettings = {
    id: 'setting-1',
    chain_name: "Hungry Howie's",
    branch_code: 'Branch #402',
    branch_name: 'Metro Central Outlet',
    store_phone: '+1 (800) 555-HOWIE',
    updated_at: new Date('2026-09-26T12:00:00Z'),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [SettingsController],
      providers: [
        {
          provide: SettingsService,
          useValue: {
            getSettings: jest.fn().mockResolvedValue(mockSettings),
            updateSettings: jest.fn().mockResolvedValue({
              ...mockSettings,
              branch_name: 'Downtown Main Branch',
            }),
          },
        },
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({ canActivate: () => true })
      .overrideGuard(PermissionsGuard)
      .useValue({ canActivate: () => true })
      .compile();

    controller = module.get<SettingsController>(SettingsController);
  });

  it('should return store settings', async () => {
    const response = await controller.getSettings();
    expect(response.success).toBe(true);
    expect(response.data!.chain_name).toBe("Hungry Howie's");
  });

  it('should update store settings via PATCH', async () => {
    const response = await controller.updateSettings({
      branch_name: 'Downtown Main Branch',
    });
    expect(response.success).toBe(true);
    expect(response.data!.branch_name).toBe('Downtown Main Branch');
  });

  it('should replace store settings via PUT', async () => {
    const response = await controller.replaceSettings({
      branch_name: 'Downtown Main Branch',
    });
    expect(response.success).toBe(true);
    expect(response.data!.branch_name).toBe('Downtown Main Branch');
  });
});
