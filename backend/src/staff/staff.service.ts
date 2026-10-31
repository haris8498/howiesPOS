import { RealtimeGateway } from '../realtime/realtime.gateway';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { Prisma, StaffMember } from '@prisma/client';
import { PasswordService } from '../auth/password.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStaffDto } from './dto/create-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { QueryStaffDto } from './dto/query-staff.dto';
import { AuthenticatedUser } from '../auth/interfaces/jwt-payload.interface';

export interface StaffMemberWithUser extends StaffMember {
  user?: {
    id: string;
    username: string;
    role: string;
    is_default: boolean;
  } | null;
}

export interface StaffStats {
  totalCount: number;
  totalMonthlyPayroll: number;
  paidCount: number;
  paidPayroll: number;
  pendingCount: number;
  pendingPayroll: number;
}

@Injectable()
export class StaffService {
  private readonly logger = new Logger(StaffService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwordService: PasswordService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  async listStaff(query?: QueryStaffDto): Promise<StaffMemberWithUser[]> {
    const where: Prisma.StaffMemberWhereInput = {};

    if (query?.role) {
      where.role = query.role;
    }

    if (query?.status) {
      where.status = query.status;
    }

    if (query?.search) {
      const search = query.search.trim();
      where.OR = [
        { full_name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search, mode: 'insensitive' } },
        { role: { contains: search, mode: 'insensitive' } },
      ];
    }

    let targetMonthYear: string | undefined = query?.month_year?.trim();
    let targetYear: number | undefined;
    let targetMonth: number | undefined;

    if (targetMonthYear) {
      if (/^\d{4}-\d{2}$/.test(targetMonthYear)) {
        const [y, m] = targetMonthYear.split('-');
        targetMonthYear = `${m}-${y}`;
        targetYear = parseInt(y, 10);
        targetMonth = parseInt(m, 10);
      } else if (/^\d{2}-\d{4}$/.test(targetMonthYear)) {
        const [m, y] = targetMonthYear.split('-');
        targetYear = parseInt(y, 10);
        targetMonth = parseInt(m, 10);
      }
    }

    if (targetYear !== undefined && targetMonth !== undefined) {
      // 1. End of target month (e.g. 2026-10-31T23:59:59.999Z)
      const endOfTargetMonth = new Date(Date.UTC(targetYear, targetMonth, 0, 23, 59, 59, 999));

      where.AND = [
        // Employee must have joined on or before this month's end
        {
          joining_date: {
            lte: endOfTargetMonth,
          },
        },
        // Employee must NOT have left before this month (leaving_date is null OR after this month's end)
        {
          OR: [{ leaving_date: null }, { leaving_date: { gt: endOfTargetMonth } }],
        } as any,
      ];
    } else if (!query?.status) {
      where.status = 'Active';
    }

    const staffList = await this.prisma.staffMember.findMany({
      where,
      include: {
        user: {
          select: {
            id: true,
            username: true,
            role: true,
            is_default: true,
          },
        },
        payslips: targetMonthYear
          ? {
              where: { month_year: targetMonthYear },
            }
          : false,
      },
      orderBy: { full_name: 'asc' },
    });

    if (targetMonthYear) {
      let mapped = staffList.map((staff) => {
        const payslip = staff.payslips && staff.payslips.length > 0 ? staff.payslips[0] : null;
        const isPaid = payslip ? payslip.status.toLowerCase() === 'paid' : false;
        const paidDate = payslip ? payslip.paid_at : null;

        return {
          ...staff,
          is_salary_paid: isPaid,
          salary_paid_date: paidDate,
        };
      });

      if (query?.is_salary_paid !== undefined) {
        mapped = mapped.filter((s) => s.is_salary_paid === query.is_salary_paid);
      }

      return mapped;
    }

    if (query?.is_salary_paid !== undefined) {
      return staffList.filter((s) => s.is_salary_paid === query.is_salary_paid);
    }

    return staffList;
  }

  async getStaffStats(monthYearInput?: string): Promise<StaffStats> {
    const allStaff = await this.listStaff(
      monthYearInput ? { month_year: monthYearInput } : undefined,
    );

    const totalCount = allStaff.length;

    let totalMonthlyPayroll = 0;
    let paidPayroll = 0;
    let pendingPayroll = 0;
    let paidCount = 0;
    let pendingCount = 0;

    for (const staff of allStaff) {
      const salary = Number(staff.monthly_salary);
      const netSalary = salary;

      totalMonthlyPayroll += netSalary;

      if (staff.is_salary_paid) {
        paidCount++;
        paidPayroll += netSalary;
      } else {
        pendingCount++;
        pendingPayroll += netSalary;
      }
    }

    return {
      totalCount,
      totalMonthlyPayroll,
      paidCount,
      paidPayroll,
      pendingCount,
      pendingPayroll,
    };
  }

  async getStaffById(id: string): Promise<StaffMemberWithUser> {
    const staff = await this.prisma.staffMember.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            role: true,
            is_default: true,
          },
        },
      },
    });

    if (!staff) {
      throw new NotFoundException(`Staff member with ID '${id}' not found`);
    }

    return staff;
  }

  async createStaff(dto: CreateStaffDto, actor: AuthenticatedUser): Promise<StaffMemberWithUser> {
    // Case A: Create staff member + linked login user in a single transaction
    if (dto.create_login_account) {
      if (!dto.username || !dto.password) {
        throw new BadRequestException(
          'Username and password are required when creating a login account',
        );
      }

      const existingUser = await this.prisma.staffUser.findUnique({
        where: { username: dto.username },
      });

      if (existingUser) {
        throw new ConflictException(`Username '${dto.username}' is already taken`);
      }

      const passwordHash = await this.passwordService.hash(dto.password);

      return this.prisma.$transaction(async (tx) => {
        const user = await tx.staffUser.create({
          data: {
            username: dto.username!,
            password_hash: passwordHash,
            plain_password: dto.password ? dto.password.trim() : null,
            role: dto.role,
            is_default: false,
            updated_by: actor.username,
          },
        });

        const staff = await tx.staffMember.create({
          data: {
            user_id: user.id,
            full_name: dto.full_name,
            phone: dto.phone,
            role: dto.role,
            status: dto.status ?? 'Active',
            joining_date: dto.joining_date ? new Date(dto.joining_date) : new Date(),
            assigned_shift: dto.assigned_shift ?? 'Morning Shift',
            monthly_salary: dto.monthly_salary ?? 65000.0,
            hourly_rate: dto.hourly_rate ?? 406.0,
          },
          include: {
            user: {
              select: {
                id: true,
                username: true,
                role: true,
                is_default: true,
              },
            },
          },
        });

        this.logger.log(
          `Created staff member '${staff.full_name}' with linked user '${user.username}'`,
        );
        this.realtimeGateway?.emitStaffCreated(staff as any);
        return staff;
      });
    }

    // Case B: Link an existing user_id if provided
    if (dto.user_id) {
      const user = await this.prisma.staffUser.findUnique({
        where: { id: dto.user_id },
      });

      if (!user) {
        throw new NotFoundException(`User with ID '${dto.user_id}' not found`);
      }

      const existingLink = await this.prisma.staffMember.findUnique({
        where: { user_id: dto.user_id },
      });

      if (existingLink) {
        throw new ConflictException(
          `User '${user.username}' is already linked to staff member '${existingLink.full_name}'`,
        );
      }
    }

    // Case C: Standard staff creation
    const created = await this.prisma.staffMember.create({
      data: {
        user_id: dto.user_id,
        full_name: dto.full_name,
        phone: dto.phone,
        role: dto.role,
        status: dto.status ?? 'Active',
        joining_date: dto.joining_date ? new Date(dto.joining_date) : new Date(),
        assigned_shift: dto.assigned_shift ?? 'Morning Shift',
        monthly_salary: dto.monthly_salary ?? 65000.0,
        hourly_rate: dto.hourly_rate ?? 406.0,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            role: true,
            is_default: true,
          },
        },
      },
    });

    this.logger.log(`Created staff member '${created.full_name}'`);
    this.realtimeGateway?.emitStaffCreated(created as any);
    return created;
  }

  async updateStaff(id: string, dto: UpdateStaffDto): Promise<StaffMemberWithUser> {
    const existing = await this.prisma.staffMember.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`Staff member with ID '${id}' not found`);
    }

    if (dto.user_id && dto.user_id !== existing.user_id) {
      const user = await this.prisma.staffUser.findUnique({
        where: { id: dto.user_id },
      });

      if (!user) {
        throw new NotFoundException(`User with ID '${dto.user_id}' not found`);
      }

      const existingLink = await this.prisma.staffMember.findUnique({
        where: { user_id: dto.user_id },
      });

      if (existingLink && existingLink.id !== id) {
        throw new ConflictException(
          `User '${user.username}' is already linked to staff member '${existingLink.full_name}'`,
        );
      }
    }

    const updated = await this.prisma.staffMember.update({
      where: { id },
      data: {
        full_name: dto.full_name ?? existing.full_name,
        phone: dto.phone ?? existing.phone,
        role: dto.role ?? existing.role,
        status: dto.status ?? existing.status,
        joining_date: dto.joining_date ? new Date(dto.joining_date) : existing.joining_date,
        assigned_shift: dto.assigned_shift ?? existing.assigned_shift,
        monthly_salary: dto.monthly_salary ?? existing.monthly_salary,
        hourly_rate: dto.hourly_rate ?? existing.hourly_rate,
        user_id: dto.user_id !== undefined ? dto.user_id : existing.user_id,
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            role: true,
            is_default: true,
          },
        },
      },
    });

    // Synchronize linked login user role and status if present
    if (existing.user_id) {
      const userUpdates: Prisma.StaffUserUpdateInput = {};
      if (dto.role) {
        userUpdates.role = dto.role;
      }
      if (dto.status) {
        userUpdates.is_active = dto.status.toLowerCase() === 'active';
      }
      if (Object.keys(userUpdates).length > 0) {
        try {
          await this.prisma.staffUser.update({
            where: { id: existing.user_id },
            data: userUpdates,
          });
        } catch (err) {
          this.logger.warn(`Failed to synchronize linked login user for staff ${id}: ${err}`);
        }
      }
    }

    this.logger.log(`Updated staff member '${updated.full_name}'`);
    this.realtimeGateway?.emitStaffUpdated(updated as any);
    return updated;
  }

  async deleteStaff(id: string): Promise<{ message: string }> {
    const existing = await this.prisma.staffMember.findUnique({
      where: { id },
      include: { user: true },
    });

    if (!existing) {
      throw new NotFoundException(`Staff member with ID '${id}' not found`);
    }

    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      // 1. Mark staff member as Inactive with leaving_date = now (preserves historical payslips & vouchers)
      await tx.staffMember.update({
        where: { id },
        data: {
          status: 'Inactive',
          leaving_date: now,
        },
      } as any);

      // 2. If linked to a login user, deactivate their login account
      if (existing.user_id) {
        await tx.staffUser.update({
          where: { id: existing.user_id },
          data: {
            is_active: false,
          } as any,
        });
      }
    });

    this.logger.log(
      `Deactivated staff member '${existing.full_name}' effective from ${now.toISOString()}`,
    );
    this.realtimeGateway?.emitStaffDeleted(id);
    return {
      message: `Staff member '${existing.full_name}' deleted effective from current month onward`,
    };
  }

  async settleSalary(id: string, monthYearInput?: string): Promise<StaffMemberWithUser> {
    const staff = await this.getStaffById(id);

    const now = new Date();
    const currentMonthYear = `${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`;
    let targetMonthYear = monthYearInput?.trim() || currentMonthYear;
    if (/^\d{4}-\d{2}$/.test(targetMonthYear)) {
      const [y, m] = targetMonthYear.split('-');
      targetMonthYear = `${m}-${y}`;
    }

    const existingPayslip = await this.prisma.payslip.findFirst({
      where: {
        staff_id: id,
        month_year: targetMonthYear,
      },
    });

    if (existingPayslip && existingPayslip.status.toLowerCase() === 'paid') {
      throw new ConflictException(
        `Salary for '${staff.full_name}' is already settled for ${targetMonthYear}`,
      );
    }

    const paidDate = new Date();

    if (existingPayslip) {
      await this.prisma.payslip.update({
        where: { id: existingPayslip.id },
        data: {
          status: 'Paid',
          paid_at: paidDate,
        },
      });
    } else {
      await this.prisma.payslip.create({
        data: {
          staff_id: id,
          month_year: targetMonthYear,
          base_salary: staff.monthly_salary,
          net_pay: staff.monthly_salary,
          status: 'Paid',
          paid_at: paidDate,
        },
      });
    }

    if (targetMonthYear === currentMonthYear) {
      await this.prisma.staffMember.update({
        where: { id },
        data: {
          is_salary_paid: true,
          salary_paid_date: paidDate,
        },
      });
    }

    const updated = await this.getStaffById(id);
    return {
      ...updated,
      is_salary_paid: true,
      salary_paid_date: paidDate,
    };
  }

  async toggleSalary(id: string, monthYearInput?: string): Promise<StaffMemberWithUser> {
    const staff = await this.getStaffById(id);

    const now = new Date();
    const currentMonthYear = `${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`;
    let targetMonthYear = monthYearInput?.trim() || currentMonthYear;
    if (/^\d{4}-\d{2}$/.test(targetMonthYear)) {
      const [y, m] = targetMonthYear.split('-');
      targetMonthYear = `${m}-${y}`;
    }

    const existingPayslip = await this.prisma.payslip.findFirst({
      where: {
        staff_id: id,
        month_year: targetMonthYear,
      },
    });

    let newPaidState: boolean;
    const paidDate = new Date();

    if (existingPayslip) {
      newPaidState = existingPayslip.status.toLowerCase() !== 'paid';
      await this.prisma.payslip.update({
        where: { id: existingPayslip.id },
        data: {
          status: newPaidState ? 'Paid' : 'Pending',
          paid_at: newPaidState ? paidDate : null,
        },
      });
    } else {
      newPaidState = true;
      await this.prisma.payslip.create({
        data: {
          staff_id: id,
          month_year: targetMonthYear,
          base_salary: staff.monthly_salary,
          net_pay: staff.monthly_salary,
          status: 'Paid',
          paid_at: paidDate,
        },
      });
    }

    if (targetMonthYear === currentMonthYear) {
      await this.prisma.staffMember.update({
        where: { id },
        data: {
          is_salary_paid: newPaidState,
          salary_paid_date: newPaidState ? paidDate : null,
        },
      });
    }

    const updated = await this.getStaffById(id);
    return {
      ...updated,
      is_salary_paid: newPaidState,
      salary_paid_date: newPaidState ? paidDate : null,
    };
  }
}
