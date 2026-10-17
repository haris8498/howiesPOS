import { Test, TestingModule } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('CustomersController', () => {
  let controller: CustomersController;

  const mockCustomer = {
    id: 'cust-1',
    full_name: 'Robert Miller',
    phone: '+1 (555) 234-5678',
    email: 'robert.m@gmail.com',
    address: '742 Evergreen Terrace, Branchville',
    birth_date: new Date('1990-05-15'),
    loyalty_points: 340,
    total_orders_count: 18,
    total_spent: new Prisma.Decimal(412.5),
    special_notes: 'VIP customer',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [CustomersController],
      providers: [
        {
          provide: CustomersService,
          useValue: {
            listCustomers: jest.fn().mockResolvedValue([mockCustomer]),
            getCustomerById: jest.fn().mockResolvedValue(mockCustomer),
            createCustomer: jest.fn().mockResolvedValue(mockCustomer),
            updateCustomer: jest.fn().mockResolvedValue(mockCustomer),
            deleteCustomer: jest.fn().mockResolvedValue({ message: 'Customer deleted' }),
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

    controller = module.get<CustomersController>(CustomersController);
  });

  it('should list customers', async () => {
    const result = await controller.listCustomers({});
    expect(result.success).toBe(true);
    expect(result.data).toHaveLength(1);
    expect(result.data?.[0].full_name).toBe('Robert Miller');
  });

  it('should get customer by id', async () => {
    const result = await controller.getCustomerById('cust-1');
    expect(result.success).toBe(true);
    expect(result.data?.id).toBe('cust-1');
  });

  it('should create customer', async () => {
    const result = await controller.createCustomer({
      full_name: 'Robert Miller',
      phone: '+1 (555) 234-5678',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Customer created successfully');
  });

  it('should update customer', async () => {
    const result = await controller.updateCustomer('cust-1', {
      full_name: 'Robert M. Miller',
    });
    expect(result.success).toBe(true);
    expect(result.message).toBe('Customer updated successfully');
  });

  it('should delete customer', async () => {
    const result = await controller.deleteCustomer('cust-1');
    expect(result.success).toBe(true);
    expect(result.message).toBe('Customer deleted');
  });
});
