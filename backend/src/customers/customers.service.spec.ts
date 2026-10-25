import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { Customer, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CustomersService } from './customers.service';

describe('CustomersService', () => {
  let service: CustomersService;
  let prisma: PrismaService;

  const mockCustomer: Customer = {
    id: 'cust-1',
    full_name: 'Robert Miller',
    phone: '+1 (555) 234-5678',
    email: 'robert.m@gmail.com',
    address: '742 Evergreen Terrace, Branchville',
    birth_date: new Date('1990-05-15'),
    loyalty_points: 340,
    total_orders_count: 18,
    total_spent: new Prisma.Decimal(412.5),
    special_notes: 'VIP customer, prefers extra cheese',
    is_deleted: false,
    deleted_at: null,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CustomersService,
        {
          provide: PrismaService,
          useValue: {
            customer: {
              findMany: jest.fn().mockResolvedValue([mockCustomer]),
              findUnique: jest.fn().mockImplementation(({ where }) => {
                if (where.id === 'cust-1' || where.phone === '+1 (555) 234-5678') {
                  return Promise.resolve(mockCustomer);
                }
                return Promise.resolve(null);
              }),
              create: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  id: 'cust-new',
                  total_orders_count: 0,
                  total_spent: new Prisma.Decimal(0.0),
                  ...data,
                }),
              ),
              update: jest.fn().mockImplementation(({ data }) =>
                Promise.resolve({
                  ...mockCustomer,
                  ...data,
                }),
              ),
              delete: jest.fn().mockResolvedValue(mockCustomer),
            },
          },
        },
      ],
    }).compile();

    service = module.get<CustomersService>(CustomersService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should list all customers', async () => {
    const result = await service.listCustomers();
    expect(result).toHaveLength(1);
    expect(result[0].full_name).toBe('Robert Miller');
  });

  it('should list customers with search query', async () => {
    const result = await service.listCustomers({ search: 'Robert' });
    expect(result).toHaveLength(1);
    expect(result[0].phone).toBe('+1 (555) 234-5678');
  });

  it('should get customer by id', async () => {
    const result = await service.getCustomerById('cust-1');
    expect(result.id).toBe('cust-1');
  });

  it('should throw NotFoundException if customer not found by id', async () => {
    await expect(service.getCustomerById('unknown')).rejects.toThrow(NotFoundException);
  });

  it('should get customer by phone', async () => {
    const result = await service.getCustomerByPhone('+1 (555) 234-5678');
    expect(result?.full_name).toBe('Robert Miller');
  });

  it('should create a valid customer', async () => {
    const result = await service.createCustomer({
      full_name: 'Sophia Martinez',
      phone: '+1 (555) 876-5432',
      email: 'sophia.m@yahoo.com',
      address: '124 Conch Street',
      birth_date: '1995-08-20',
      loyalty_points: 100,
    });
    expect(result.full_name).toBe('Sophia Martinez');
    expect(result.phone).toBe('+1 (555) 876-5432');
  });

  it('should create customer with optional fields omitted', async () => {
    const result = await service.createCustomer({
      full_name: 'John Doe',
      phone: '+1 (555) 111-2222',
    });
    expect(result.full_name).toBe('John Doe');
  });

  it('should throw ConflictException if customer with phone already exists', async () => {
    await expect(
      service.createCustomer({
        full_name: 'Duplicate Phone User',
        phone: '+1 (555) 234-5678',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should update customer attributes', async () => {
    const result = await service.updateCustomer('cust-1', {
      full_name: 'Robert M. Miller',
      special_notes: 'Updated VIP notes',
    });
    expect(result.full_name).toBe('Robert M. Miller');
  });

  it('should throw ConflictException if updating phone to an already registered number', async () => {
    (prisma.customer.findUnique as jest.Mock).mockImplementation(({ where }) => {
      if (where.id === 'cust-1') return Promise.resolve(mockCustomer);
      if (where.phone === '+1 (555) 999-9999') {
        return Promise.resolve({
          ...mockCustomer,
          id: 'cust-other',
          phone: '+1 (555) 999-9999',
        });
      }
      return Promise.resolve(null);
    });

    await expect(
      service.updateCustomer('cust-1', {
        phone: '+1 (555) 999-9999',
      }),
    ).rejects.toThrow(ConflictException);
  });

  it('should delete customer without orders', async () => {
    (prisma.customer.findUnique as jest.Mock).mockResolvedValueOnce({
      ...mockCustomer,
      online_orders: [],
      takeaway_orders: [],
    });

    const result = await service.deleteCustomer('cust-1');
    expect(result.message).toContain('deleted successfully');
  });

  it('should throw ConflictException when deleting customer with existing orders', async () => {
    (prisma.customer.findUnique as jest.Mock).mockResolvedValueOnce({
      ...mockCustomer,
      online_orders: [{ id: 'order-1' }],
      takeaway_orders: [],
    });

    await expect(service.deleteCustomer('cust-1')).rejects.toThrow(ConflictException);
  });

  it('should throw NotFoundException when deleting non-existing customer', async () => {
    await expect(service.deleteCustomer('non-existing')).rejects.toThrow(NotFoundException);
  });
});
