import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { OptionsController } from './options.controller';
import { OptionsService } from './options.service';
import { PermissionsService } from '../../permissions/permissions.service';

describe('OptionsController', () => {
  let controller: OptionsController;

  const mockOption = {
    id: 'opt-1',
    menu_item_id: 'item-1',
    option_type: 'crust',
    option_name: 'Stuffed Crust',
    additional_price: new Prisma.Decimal(250.0),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OptionsController],
      providers: [
        {
          provide: OptionsService,
          useValue: {
            listOptionsByItem: jest.fn().mockResolvedValue([mockOption]),
            createOption: jest.fn().mockResolvedValue(mockOption),
            updateOption: jest.fn().mockResolvedValue(mockOption),
            deleteOption: jest.fn().mockResolvedValue({ message: 'Option deleted' }),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn().mockResolvedValue(true),
          },
        },
      ],
    }).compile();

    controller = module.get<OptionsController>(OptionsController);
  });

  it('should list options for item', async () => {
    const result = await controller.listOptionsByItem('item-1');
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
  });

  it('should create option', async () => {
    const result = await controller.createOption('item-1', {
      option_type: 'crust',
      option_name: 'Stuffed Crust',
      additional_price: 250.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item option added successfully');
  });

  it('should update option', async () => {
    const result = await controller.updateOption('opt-1', {
      additional_price: 300.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item option updated successfully');
  });

  it('should delete option', async () => {
    const result = await controller.deleteOption('opt-1');
    expect(result.success).toBe(true);
  });
});
