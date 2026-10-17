import { Test, TestingModule } from '@nestjs/testing';
import { Prisma, StoreSetting } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from './settings.service';

describe('SettingsService', () => {
  let service: SettingsService;

  const mockSettings: StoreSetting = {
    id: 'setting-1',
    chain_name: "Hungry Howie's",
    branch_code: 'Branch #402',
    branch_name: 'Metro Central Outlet',
    store_phone: '+1 (800) 555-HOWIE',
    updated_at: new Date('2026-09-26T12:00:00Z'),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SettingsService,
        {
          provide: PrismaService,
          useValue: {
            storeSetting: {
              findFirst: jest.fn().mockResolvedValue(mockSettings),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'setting-new',
                  updated_at: new Date(),
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockSettings,
                  ...data,
                  updated_at: new Date(),
                }),
              ),
            },
            $transaction: jest.fn().mockImplementation(async (callback) => {
              return callback({
                storeSetting: {
                  findFirst: jest.fn().mockResolvedValue(mockSettings),
                  create: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      id: 'setting-new',
                      updated_at: new Date(),
                      ...data,
                    }),
                  ),
                  update: jest.fn().mockImplementation(({ data }) =>
                    Promise.resolve({
                      ...mockSettings,
                      ...data,
                      updated_at: new Date(),
                    }),
                  ),
                },
              });
            }),
          },
        },
      ],
    }).compile();

    service = module.get<SettingsService>(SettingsService);
  });

  it('should get existing store settings', async () => {
    const settings = await service.getSettings();
    expect(settings).toBeDefined();
    expect(settings.chain_name).toBe("Hungry Howie's");
    expect(settings.branch_code).toBe('Branch #402');
  });

  it('should initialize default store settings when none exist', async () => {
    const moduleWithEmptyDb: TestingModule = await Test.createTestingModule({
      providers: [
        SettingsService,
        {
          provide: PrismaService,
          useValue: {
            storeSetting: {
              findFirst: jest.fn().mockResolvedValue(null),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'setting-default',
                  updated_at: new Date(),
                  ...data,
                }),
              ),
            },
          },
        },
      ],
    }).compile();

    const emptyDbService = moduleWithEmptyDb.get<SettingsService>(SettingsService);
    const settings = await emptyDbService.getSettings();
    expect(settings.id).toBe('setting-default');
    expect(settings.chain_name).toBe("Hungry Howie's");
  });

  it('should update store settings', async () => {
    const updated = await service.updateSettings({
      branch_name: 'Downtown Main Branch',
    });
    expect(updated.branch_name).toBe('Downtown Main Branch');
  });
});
