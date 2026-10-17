import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { SizesController } from './sizes.controller';
import { SizesService } from './sizes.service';
import { PermissionsService } from '../../permissions/permissions.service';

describe('SizesController', () => {
  let controller: SizesController;

  const mockSize = {
    id: 'size-1',
    menu_item_id: 'item-1',
    size_name: 'Medium',
    price: new Prisma.Decimal(1199.0),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [SizesController],
      providers: [
        {
          provide: SizesService,
          useValue: {
            listSizesByItem: jest.fn().mockResolvedValue([mockSize]),
            createSize: jest.fn().mockResolvedValue(mockSize),
            updateSize: jest.fn().mockResolvedValue(mockSize),
            deleteSize: jest.fn().mockResolvedValue({ message: 'Size deleted' }),
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

    controller = module.get<SizesController>(SizesController);
  });

  it('should list sizes for item', async () => {
    const result = await controller.listSizesByItem('item-1');
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
  });

  it('should create size', async () => {
    const result = await controller.createSize('item-1', {
      size_name: 'Medium',
      price: 1199.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item size added successfully');
  });

  it('should update size', async () => {
    const result = await controller.updateSize('size-1', {
      price: 1249.0,
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Menu item size updated successfully');
  });

  it('should delete size', async () => {
    const result = await controller.deleteSize('size-1');
    expect(result.success).toBe(true);
  });
});
