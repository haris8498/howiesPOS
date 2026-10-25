import { RealtimeGateway } from '../realtime/realtime.gateway';
import { Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { RolePermission } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  INITIAL_CASHIER_PERMISSIONS,
  INITIAL_MANAGER_PERMISSIONS,
} from '../common/rbac/constants/permissions.constants';
import { PresetType } from '../common/rbac/types/permission.types';

@Injectable()
export class PermissionsService {
  private readonly logger = new Logger(PermissionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async hasPermission(role: string, moduleName: string, actionName: string): Promise<boolean> {
    const normalizedRole = (role || '').toLowerCase().trim();

    // Owner and Admin roles have unrestricted authority across all modules
    if (
      normalizedRole === 'owner' ||
      normalizedRole === 'super admin' ||
      normalizedRole === 'admin'
    ) {
      return true;
    }

    const actionCandidates = [actionName];
    const moduleCandidates = [moduleName];

    if (moduleName === 'Users' || moduleName === 'Staff') {
      moduleCandidates.push('Users', 'Staff');
      if (actionName.includes('Allow Access to Users') || actionName.includes('Payroll') || actionName.includes('Allow Access')) {
        actionCandidates.push('Allow Access to Users', 'Allow Access to Users & Payroll Module');
      }
      if (actionName.includes('Register New Store Users') || actionName.includes('Add Users') || actionName.includes('Add')) {
        actionCandidates.push('Add Users', 'Register New Store Users');
      }
      if (actionName.includes('Edit Users') || actionName.includes('Edit')) {
        actionCandidates.push('Edit Users', 'Register New Store Users');
      }
      if (actionName.includes('Delete Users') || actionName.includes('Delete')) {
        actionCandidates.push('Delete Users', 'Register New Store Users');
      }
      if (actionName.includes('Salary') || actionName.includes('Disburse')) {
        actionCandidates.push('Mark Salary Paid', 'Mark Salary Paid (Disburse)');
      }
    } else if (moduleName === 'Menu Catalog' || moduleName === 'Menu') {
      moduleCandidates.push('Menu Catalog', 'Menu');
      if (actionName.includes('Allow Access') || actionName.includes('Catalog Module')) {
        actionCandidates.push('Allow Access to Menu Catalog', 'Allow Access to Menu Catalog Module');
      }
      if (actionName.includes('Add') || actionName.includes('Edit')) {
        actionCandidates.push('Add Menu Catalog', 'Edit Menu Catalog', 'Add & Edit Menu Items & Prices');
      }
      if (actionName.includes('Delete')) {
        actionCandidates.push('Delete Menu Catalog', 'Delete Menu Items');
      }
    } else if (moduleName === 'Tables') {
      if (actionName.includes('Allow Access')) {
        actionCandidates.push('Allow Access to Tables');
      }
      if (actionName.includes('Add')) {
        actionCandidates.push('Add Tables');
      }
      if (actionName.includes('Edit')) {
        actionCandidates.push('Edit Tables');
      }
      if (actionName.includes('Delete')) {
        actionCandidates.push('Delete Tables');
      }
    } else if (moduleName === 'Expenses') {
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Expenses');
      if (actionName.includes('Add')) actionCandidates.push('Add Expenses');
      if (actionName.includes('Edit')) actionCandidates.push('Edit Expenses');
      if (actionName.includes('Delete')) actionCandidates.push('Delete Expenses');
    } else if (moduleName === 'Stock In / Out' || moduleName === 'Inventory') {
      moduleCandidates.push('Stock In / Out', 'Inventory');
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Stock In / Out', 'Allow Access to Stock Catalog');
      if (actionName.includes('In')) actionCandidates.push('Perform Stock In');
      if (actionName.includes('Out') || actionName.includes('Wastage')) actionCandidates.push('Perform Stock Out');
    } else if (moduleName === 'Stock Catalog' || moduleName === 'Stock') {
      moduleCandidates.push('Stock Catalog', 'Stock');
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Stock Catalog');
      if (actionName.includes('Add')) actionCandidates.push('Add Stock Catalog');
      if (actionName.includes('Edit')) actionCandidates.push('Edit Stock Catalog');
      if (actionName.includes('Delete')) actionCandidates.push('Delete Stock Catalog');
    } else if (moduleName === 'Reports') {
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Reports');
      if (actionName.includes('Export')) actionCandidates.push('Export Reports');
    } else if (moduleName === 'Delivery Tracking' || moduleName === 'Delivery') {
      moduleCandidates.push('Delivery Tracking', 'Delivery');
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Delivery');
      if (actionName.includes('Assign')) actionCandidates.push('Assign Riders');
    } else if (moduleName === 'Takeaway Counter' || moduleName === 'Takeaway') {
      moduleCandidates.push('Takeaway Counter', 'Takeaway');
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Takeaway');
      if (actionName.includes('Create')) actionCandidates.push('Create Takeaway Orders');
    } else if (moduleName === 'Online Orders') {
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Online Orders');
      if (actionName.includes('Accept') || actionName.includes('Reject')) actionCandidates.push('Accept/Reject Orders');
    } else if (moduleName === 'Daily Calculation') {
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Daily Calculation');
    } else if (moduleName === 'Data Sync') {
      if (actionName.includes('Allow Access')) actionCandidates.push('Allow Access to Data Sync');
    } else if (moduleName === 'Staff Permissions' || moduleName === 'Rights') {
      moduleCandidates.push('Staff Permissions', 'Rights');
      actionCandidates.push('Allow Access to Staff Permissions Portal', 'Allow Access to Staff Permissions');
    }

    let permission = await this.prisma.rolePermission.findFirst({
      where: {
        role: normalizedRole,
        module_name: { in: moduleCandidates },
        action_name: { in: actionCandidates },
        is_granted: true,
      },
    });

    if (!permission) {
      const count = await this.prisma.rolePermission.count({
        where: { role: normalizedRole },
      });
      if (count === 0) {
        await this.seedDefaultsForRole(normalizedRole);
        permission = await this.prisma.rolePermission.findFirst({
          where: {
            role: normalizedRole,
            module_name: { in: moduleCandidates },
            action_name: { in: actionCandidates },
            is_granted: true,
          },
        });
      }
    }

    return !!permission;
  }

  async getPermissionsByRole(role: string): Promise<RolePermission[]> {
    const normalizedRole = (role || '').toLowerCase().trim();
    
    await this.ensureDefaultsExist(normalizedRole);

    const permissions = await this.prisma.rolePermission.findMany({
      where: { role: normalizedRole },
      orderBy: { id: 'asc' },
    });

    return permissions;
  }

  private async ensureDefaultsExist(role: string): Promise<void> {
    const defaultList =
      role === 'manager'
        ? INITIAL_MANAGER_PERMISSIONS
        : role === 'cashier'
        ? INITIAL_CASHIER_PERMISSIONS
        : [];

    for (const def of defaultList) {
      const exists = await this.prisma.rolePermission.findUnique({
        where: { id: def.id },
      });
      if (!exists) {
        await this.prisma.rolePermission.create({
          data: {
            id: def.id,
            role: def.role,
            module_name: def.module_name,
            action_name: def.action_name,
            description: def.description,
            is_granted: def.is_granted,
            is_sensitive: def.is_sensitive,
          },
        });
      }
    }
  }

  async togglePermission(id: string): Promise<RolePermission> {
    const existing = await this.prisma.rolePermission.findUnique({
      where: { id },
    });

    if (!existing) {
      const allDefaults = [...INITIAL_MANAGER_PERMISSIONS, ...INITIAL_CASHIER_PERMISSIONS];
      const def = allDefaults.find((d) => d.id === id);
      if (def) {
        return this.prisma.rolePermission.create({
          data: {
            id: def.id,
            role: def.role,
            module_name: def.module_name,
            action_name: def.action_name,
            description: def.description,
            is_granted: !def.is_granted,
            is_sensitive: def.is_sensitive,
          },
        });
      }
      throw new NotFoundException(`Permission with ID '${id}' not found`);
    }

    return this.prisma.rolePermission.update({
      where: { id },
      data: {
        is_granted: !existing.is_granted,
      },
    });
  }

  async updatePermission(id: string, isGranted: boolean): Promise<RolePermission> {
    const existing = await this.prisma.rolePermission.findUnique({
      where: { id },
    });

    if (!existing) {
      const allDefaults = [...INITIAL_MANAGER_PERMISSIONS, ...INITIAL_CASHIER_PERMISSIONS];
      const def = allDefaults.find((d) => d.id === id);
      if (def) {
        return this.prisma.rolePermission.create({
          data: {
            id: def.id,
            role: def.role,
            module_name: def.module_name,
            action_name: def.action_name,
            description: def.description,
            is_granted: isGranted,
            is_sensitive: def.is_sensitive,
          },
        });
      }
      throw new NotFoundException(`Permission with ID '${id}' not found`);
    }

    return this.prisma.rolePermission.update({
      where: { id },
      data: {
        is_granted: isGranted,
      },
    });
  }

  async applyPreset(role: 'manager' | 'cashier', preset: PresetType): Promise<RolePermission[]> {
    if (preset === 'STRICT') {
      // Revoke all sensitive permissions
      await this.prisma.rolePermission.updateMany({
        where: {
          role,
          is_sensitive: true,
        },
        data: {
          is_granted: false,
        },
      });
    } else if (preset === 'FULL') {
      // Grant all permissions
      await this.prisma.rolePermission.updateMany({
        where: {
          role,
        },
        data: {
          is_granted: true,
        },
      });
    } else if (preset === 'DEFAULT') {
      // Reset to defaults
      await this.resetToDefault(role);
    }

    return this.getPermissionsByRole(role);
  }

  private async resetToDefault(role: 'manager' | 'cashier'): Promise<void> {
    const defaultList =
      role === 'manager' ? INITIAL_MANAGER_PERMISSIONS : INITIAL_CASHIER_PERMISSIONS;

    for (const def of defaultList) {
      await this.prisma.rolePermission.upsert({
        where: { id: def.id },
        update: {
          role: def.role,
          module_name: def.module_name,
          action_name: def.action_name,
          description: def.description,
          is_granted: def.is_granted,
          is_sensitive: def.is_sensitive,
        },
        create: {
          id: def.id,
          role: def.role,
          module_name: def.module_name,
          action_name: def.action_name,
          description: def.description,
          is_granted: def.is_granted,
          is_sensitive: def.is_sensitive,
        },
      });
    }
  }

  private async seedDefaultsForRole(role: string): Promise<void> {
    if (role === 'manager') {
      await this.resetToDefault('manager');
    } else if (role === 'cashier') {
      await this.resetToDefault('cashier');
    }
  }
}
