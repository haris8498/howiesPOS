import { CustomDecorator, SetMetadata } from '@nestjs/common';
import { PERMISSIONS_METADATA_KEY } from '../constants/permissions.constants';
import { RequiredPermission } from '../types/permission.types';

export const RequirePermission = (
  moduleName: string,
  actionName: string,
): CustomDecorator<string> =>
  SetMetadata<string, RequiredPermission>(PERMISSIONS_METADATA_KEY, {
    moduleName,
    actionName,
  });
