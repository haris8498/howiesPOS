import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;

  const mockLoginResult = {
    accessToken: 'mock-jwt-token-123',
    user: {
      id: 'usr-1',
      username: 'manager_howie',
      email: 'manager@hungryhowies.com',
      role: 'manager',
      is_default: false,
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            login: jest.fn().mockResolvedValue(mockLoginResult),
          },
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('POST /auth/login should return login response with accessToken', async () => {
    const response = await controller.login({
      username: 'manager_howie',
      password: 'password123',
    });

    expect(response.success).toBe(true);
    expect(response.message).toBe('Login successful');
    expect(response.data?.accessToken).toBe('mock-jwt-token-123');
    expect(response.data?.user.username).toBe('manager_howie');
  });

  it('GET /auth/me should return authenticated user profile', async () => {
    const response = await controller.getProfile(mockLoginResult.user);

    expect(response.success).toBe(true);
    expect(response.data).toEqual(mockLoginResult.user);
  });
});
