import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { PermissionsService } from '../permissions/permissions.service';

describe('UsersController', () => {
  let controller: UsersController;

  const mockSafeUser = {
    id: 'u-1',
    username: 'storemanager',
    role: 'manager',
    is_default: true,
    last_updated: new Date(),
    updated_by: 'Super Admin',
  };

  const mockActor = {
    id: 'admin-id',
    username: 'superadmin',
    role: 'owner',
    is_default: true,
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            listUsers: jest.fn().mockResolvedValue([mockSafeUser]),
            getUserById: jest.fn().mockResolvedValue(mockSafeUser),
            createUser: jest.fn().mockResolvedValue(mockSafeUser),
            updateUser: jest.fn().mockResolvedValue(mockSafeUser),
            updatePassword: jest
              .fn()
              .mockResolvedValue({ message: 'Password updated successfully' }),
            deleteUser: jest.fn().mockResolvedValue({ message: 'User deleted successfully' }),
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

    controller = module.get<UsersController>(UsersController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('GET /users should return users list', async () => {
    const response = await controller.listUsers();
    expect(response.success).toBe(true);
    expect(response.data).toHaveLength(1);
    expect(response.data?.[0].username).toBe('storemanager');
  });

  it('POST /users should create user', async () => {
    const response = await controller.createUser(
      {
        username: 'storemanager',
        password: 'password123',
        role: 'manager',
      },
      mockActor,
    );

    expect(response.success).toBe(true);
    expect(response.message).toContain('created successfully');
  });

  it('PATCH /users/:id/password should update password', async () => {
    const response = await controller.updatePassword(
      'u-1',
      { new_password: 'newPassword123' },
      mockActor,
    );

    expect(response.success).toBe(true);
    expect(response.message).toBe('Password updated successfully');
  });

  it('DELETE /users/:id should delete user', async () => {
    const response = await controller.deleteUser('u-1');
    expect(response.success).toBe(true);
    expect(response.message).toBe('User deleted successfully');
  });
});
