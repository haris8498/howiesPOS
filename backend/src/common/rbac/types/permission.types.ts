export interface RequiredPermission {
  moduleName: string;
  actionName: string;
}

export type PresetType = 'STRICT' | 'FULL' | 'DEFAULT';

export interface PermissionStats {
  grantedCount: number;
  restrictedCount: number;
  sensitiveCount: number;
}
