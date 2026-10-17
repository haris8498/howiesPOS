import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_METADATA_KEY } from '../constants/permissions.constants';
import { RequiredPermission } from '../types/permission.types';
import { PermissionsService } from '../../../permissions/permissions.service';
import { AuthenticatedUser } from '../../../auth/interfaces/jwt-payload.interface';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly permissionsService: PermissionsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermission = this.reflector.getAllAndOverride<RequiredPermission | undefined>(
      PERMISSIONS_METADATA_KEY,
      [context.getHandler(), context.getClass()],
    );

    // If no specific permission is required on the route, allow access
    if (!requiredPermission) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user as AuthenticatedUser | undefined;

    if (!user || !user.role) {
      throw new ForbiddenException('User is not authenticated or missing role');
    }

    const normalizedRole = user.role.toLowerCase().trim();
    if (
      normalizedRole === 'owner' ||
      normalizedRole === 'superadmin' ||
      normalizedRole === 'super admin' ||
      normalizedRole === 'admin'
    ) {
      return true;
    }

    const hasPermission = await this.permissionsService.hasPermission(
      user.role,
      requiredPermission.moduleName,
      requiredPermission.actionName,
    );

    if (!hasPermission) {
      throw new ForbiddenException('You do not have permission to perform this action.');
    }

    return true;
  }
}
