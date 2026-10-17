import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { OptionsService } from './options.service';

describe('OptionsService', () => {
  let service: OptionsService;

  const mockItem = {
    id: 'item-1',
    name: 'Pepperoni Pizza',
  };

  const mockOption = {
    id: 'opt-1',
    menu_item_id: 'item-1',
    option_type: 'crust',
    option_name: 'Stuffed Crust',
    additional_price: new Prisma.Decimal(250.0),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OptionsService,
        {
          provide: PrismaService,
          useValue: {
            menuItem: {
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'item-1') return Promise.resolve(mockItem);
                return Promise.resolve(null);
              }),
            },
            menuItemOption: {
              findMany: jest.fn().mockResolvedValue([mockOption]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'opt-1') return Promise.resolve(mockOption);
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'opt-new',
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockOption,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockOption),
            },
          },
        },
      ],
    }).compile();

    service = module.get<OptionsService>(OptionsService);
  });

  it('should list options for an item', async () => {
    const result = await service.listOptionsByItem('item-1');
    expect(result).toHaveLength(1);
    expect(result[0].option_name).toBe('Stuffed Crust');
  });

  it('should throw NotFoundException if item does not exist when listing options', async () => {
    await expect(service.listOptionsByItem('non-existing')).rejects.toThrow(NotFoundException);
  });

  it('should create option for an item', async () => {
    const result = await service.createOption('item-1', {
      option_type: 'crust',
      option_name: 'Thin Crust',
      additional_price: 150.0,
    });
    expect(result.option_name).toBe('Thin Crust');
  });

  it('should update option', async () => {
    const result = await service.updateOption('opt-1', {
      additional_price: 300.0,
    });
    expect(result).toBeDefined();
  });

  it('should delete option', async () => {
    const result = await service.deleteOption('opt-1');
    expect(result.message).toContain('deleted successfully');
  });
});
