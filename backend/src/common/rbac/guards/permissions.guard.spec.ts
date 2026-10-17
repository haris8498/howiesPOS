import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Test, TestingModule } from '@nestjs/testing';
import { PermissionsService } from '../../../permissions/permissions.service';
import { PermissionsGuard } from './permissions.guard';

describe('PermissionsGuard', () => {
  let guard: PermissionsGuard;
  let reflector: Reflector;
  let permissionsService: PermissionsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PermissionsGuard,
        {
          provide: Reflector,
          useValue: {
            getAllAndOverride: jest.fn(),
          },
        },
        {
          provide: PermissionsService,
          useValue: {
            hasPermission: jest.fn(),
          },
        },
      ],
    }).compile();

    guard = module.get<PermissionsGuard>(PermissionsGuard);
    reflector = module.get<Reflector>(Reflector);
    permissionsService = module.get<PermissionsService>(PermissionsService);
  });

  const createMockContext = (
    user?: { id: string; role: string },
    body?: Record<string, unknown>,
  ): ExecutionContext => {
    return {
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: jest.fn().mockReturnValue({
        getRequest: jest.fn().mockReturnValue({
          user,
          body,
        }),
      }),
    } as unknown as ExecutionContext;
  };

  it('should be defined', () => {
    expect(guard).toBeDefined();
  });

  it('should allow access if route has no @RequirePermission metadata', async () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(undefined);
    const context = createMockContext({ id: 'u1', role: 'cashier' });

    const result = await guard.canActivate(context);
    expect(result).toBe(true);
  });

  it('should throw ForbiddenException if user is not attached to request', async () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue({
      moduleName: 'Orders',
      actionName: 'Create Order',
    });
    const context = createMockContext(undefined);

    await expect(guard.canActivate(context)).rejects.toThrow(ForbiddenException);
  });

  it('should allow request when user role has permission granted', async () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue({
      moduleName: 'Orders',
      actionName: 'Create Order',
    });
    jest.spyOn(permissionsService, 'hasPermission').mockResolvedValue(true);

    const context = createMockContext({ id: 'u1', role: 'manager' });
    const result = await guard.canActivate(context);

    expect(result).toBe(true);
    expect(permissionsService.hasPermission).toHaveBeenCalledWith(
      'manager',
      'Orders',
      'Create Order',
    );
  });

  it('should deny request (403) when user role permission is false', async () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue({
      moduleName: 'Staff Permissions',
      actionName: 'Manage Rights',
    });
    jest.spyOn(permissionsService, 'hasPermission').mockResolvedValue(false);

    const context = createMockContext({ id: 'u2', role: 'cashier' });

    await expect(guard.canActivate(context)).rejects.toThrow(ForbiddenException);
  });

  it('should strictly use authenticated user role and ignore fake role in request body', async () => {
    jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue({
      moduleName: 'Reports',
      actionName: 'Export PDF',
    });
    jest.spyOn(permissionsService, 'hasPermission').mockResolvedValue(false);

    // Client attempts to spoof role as 'owner' in request body
    const context = createMockContext({ id: 'u3', role: 'cashier' }, { role: 'owner' });

    await expect(guard.canActivate(context)).rejects.toThrow(ForbiddenException);
    expect(permissionsService.hasPermission).toHaveBeenCalledWith(
      'cashier',
      'Reports',
      'Export PDF',
    );
  });
});
