import { RealtimeGateway } from '../realtime/realtime.gateway';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { AuthenticatedUser } from '../auth/interfaces/jwt-payload.interface';
import { PasswordService } from '../auth/password.service';

export interface SafeUser {
  id: string;
  username: string;
  role: string;
  is_default: boolean;
  plain_password?: string | null;
  last_updated: Date;
  updated_by: string;
  staff_member?: {
    id: string;
    full_name: string;
    phone: string;
    assigned_shift: string;
  } | null;
}

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwordService: PasswordService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async listUsers(): Promise<SafeUser[]> {
    return this.prisma.staffUser.findMany({
      where: { is_active: true },
      select: {
        id: true,
        username: true,
        role: true,
        is_default: true,
        plain_password: true,
        last_updated: true,
        updated_by: true,
        staff_member: {
          select: {
            id: true,
            full_name: true,
            phone: true,
            assigned_shift: true,
          },
        },
      },
      orderBy: { username: 'asc' },
    });
  }

  async getUserById(id: string): Promise<SafeUser> {
    const user = await this.prisma.staffUser.findUnique({
      where: { id },
      select: {
        id: true,
        username: true,
        role: true,
        is_default: true,
        plain_password: true,
        last_updated: true,
        updated_by: true,
        staff_member: {
          select: {
            id: true,
            full_name: true,
            phone: true,
            assigned_shift: true,
          },
        },
      },
    });

    if (!user) {
      throw new NotFoundException(`User with ID '${id}' not found`);
    }

    return user;
  }

  async createUser(dto: CreateUserDto, actor: AuthenticatedUser): Promise<SafeUser> {
    const existing = await this.prisma.staffUser.findUnique({
      where: { username: dto.username },
    });

    if (existing) {
      throw new ConflictException(`Username '${dto.username}' is already taken`);
    }

    const passwordHash = await this.passwordService.hash(dto.password);

    const created = await this.prisma.staffUser.create({
      data: {
        username: dto.username.trim(),
        password_hash: passwordHash,
        plain_password: dto.password ? dto.password.trim() : null,
        role: dto.role,
        is_default: dto.is_default ?? false,
        updated_by: actor.username,
      },
      select: {
        id: true,
        username: true,
        role: true,
        is_default: true,
        plain_password: true,
        last_updated: true,
        updated_by: true,
        staff_member: {
          select: {
            id: true,
            full_name: true,
            phone: true,
            assigned_shift: true,
          },
        },
      },
    });

    // Also auto-create a StaffMember profile for HR & shift management
    try {
      await this.prisma.staffMember.create({
        data: {
          user_id: created.id,
          full_name: dto.full_name || dto.username.trim(),
          phone: dto.phone || '0300-0000000',
          role: dto.role,
          joining_date: new Date(),
          assigned_shift: dto.role === 'cashier' ? 'Evening Shift' : 'Morning Shift',
          monthly_salary: dto.role === 'manager' ? 65000 : 35000,
          hourly_rate: dto.role === 'manager' ? 406 : 218,
        },
      });
    } catch (staffErr: unknown) {
      this.logger.warn(
        `Could not create associated staff member for user '${created.username}': ${(staffErr as Error)?.message ?? staffErr}`,
      );
    }

    this.logger.log(`Created new staff user '${created.username}' with role '${created.role}'`);
    return created;
  }

  async updateUser(id: string, dto: UpdateUserDto, actor: AuthenticatedUser): Promise<SafeUser> {
    let existing = await this.prisma.staffUser.findUnique({
      where: { id },
    });

    if (!existing) {
      existing = await this.prisma.staffUser.findFirst({
        where: {
          username: {
            equals: id.trim(),
            mode: 'insensitive',
          },
        },
      });
    }

    if (!existing) {
      throw new NotFoundException(`User with ID or Username '${id}' not found`);
    }

    if (dto.username && dto.username.trim().toLowerCase() !== existing.username.toLowerCase()) {
      const usernameExists = await this.prisma.staffUser.findFirst({
        where: {
          username: {
            equals: dto.username.trim(),
            mode: 'insensitive',
          },
          id: { not: existing.id },
        },
      });
      if (usernameExists) {
        throw new ConflictException(`Username '${dto.username}' is already taken`);
      }
    }

    if (existing.role === 'owner' && dto.role && dto.role !== 'owner') {
      throw new BadRequestException('Cannot change the role of an owner account');
    }

    let passwordHash: string | undefined;
    if (dto.password && dto.password.trim().length > 0) {
      passwordHash = await this.passwordService.hash(dto.password.trim());
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const res = await tx.staffUser.update({
        where: { id: existing.id },
        data: {
          username: dto.username ? dto.username.trim() : existing.username,
          role: dto.role ?? existing.role,
          ...(passwordHash
            ? {
                password_hash: passwordHash,
                plain_password: dto.password ? dto.password.trim() : existing.plain_password,
              }
            : {}),
          updated_by: actor.username,
        },
        select: {
          id: true,
          username: true,
          role: true,
          is_default: true,
          plain_password: true,
          last_updated: true,
          updated_by: true,
          staff_member: {
            select: {
              id: true,
              full_name: true,
              phone: true,
              assigned_shift: true,
            },
          },
        },
      });

      if (res.staff_member) {
        const staffUpdates: Prisma.StaffMemberUpdateInput = {};
        if (dto.role) staffUpdates.role = dto.role;
        if (dto.full_name) staffUpdates.full_name = dto.full_name.trim();
        if (dto.phone) staffUpdates.phone = dto.phone.trim();
        if (Object.keys(staffUpdates).length > 0) {
          await tx.staffMember.update({
            where: { id: res.staff_member.id },
            data: staffUpdates,
          });
        }
      }

      return res;
    });

    this.logger.log(`Updated staff user '${updated.username}' (role: ${updated.role})`);
    return updated;
  }

  async updatePassword(
    id: string,
    newPassword: string,
    actor: AuthenticatedUser,
  ): Promise<{ message: string }> {
    let existing = await this.prisma.staffUser.findUnique({
      where: { id },
    });

    if (!existing) {
      existing = await this.prisma.staffUser.findFirst({
        where: {
          username: {
            equals: id.trim(),
            mode: 'insensitive',
          },
        },
      });
    }

    if (!existing) {
      throw new NotFoundException(`User with ID or Username '${id}' not found`);
    }

    const passwordHash = await this.passwordService.hash(newPassword.trim());

    await this.prisma.staffUser.update({
      where: { id: existing.id },
      data: {
        password_hash: passwordHash,
        plain_password: newPassword.trim(),
        updated_by: actor.username,
      },
    });

    this.logger.log(
      `Password updated for staff user '${existing.username}' by '${actor.username}'`,
    );
    return { message: 'Password updated successfully' };
  }

  async deleteUser(id: string): Promise<{ message: string }> {
    let existing = await this.prisma.staffUser.findUnique({
      where: { id },
      include: {
        staff_member: true,
      },
    });

    if (!existing) {
      existing = await this.prisma.staffUser.findFirst({
        where: {
          username: {
            equals: id.trim(),
            mode: 'insensitive',
          },
        },
        include: {
          staff_member: true,
        },
      });
    }

    if (!existing) {
      throw new NotFoundException(`User with ID or Username '${id}' not found`);
    }

    const now = new Date();

    // Preserve past records: mark staff_member leaving_date = now & status = 'Inactive', and mark staff_user is_active = false
    await this.prisma.$transaction(async (tx) => {
      if (existing.staff_member) {
        await tx.staffMember.update({
          where: { id: existing.staff_member.id },
          data: {
            status: 'Inactive',
            leaving_date: now,
          },
        });
      }

      await tx.staffUser.update({
        where: { id: existing.id },
        data: {
          is_active: false,
        },
      });
    });

    this.logger.log(
      `Deactivated staff user '${existing.username}' (effective: ${now.toISOString()})`,
    );
    return {
      message: `Staff user '${existing.username}' deleted effective from current month onward`,
    };
  }
}
