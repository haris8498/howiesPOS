import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PayrollService {
  private readonly logger = new Logger(PayrollService.name);

  constructor(private readonly prisma: PrismaService) {}

  // Run on the 1st of every month at midnight (0 0 1 * *)
  @Cron('0 0 1 * *')
  async generateMonthlyPayslips() {
    this.logger.log('Starting automated monthly payroll generation...');
    
    try {
      // 1. Find all active staff members
      const activeStaff = await this.prisma.staffMember.findMany({
        where: { status: 'Active' },
      });

      if (activeStaff.length === 0) {
        this.logger.log('No active staff found. Skipping payroll generation.');
        return;
      }

      // 2. Generate month-year string (e.g. "09-2026")
      const now = new Date();
      const monthYear = `${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`;

      // 3. Create payslip records
      let createdCount = 0;
      for (const staff of activeStaff) {
        // Check if payslip for this month already exists to prevent duplicates
        const existingPayslip = await this.prisma.payslip.findFirst({
          where: { staff_id: staff.id, month_year: monthYear },
        });

        if (!existingPayslip) {
          await this.prisma.payslip.create({
            data: {
              staff_id: staff.id,
              month_year: monthYear,
              base_salary: staff.monthly_salary,
              net_pay: staff.monthly_salary,
              status: 'Pending',
            },
          });
          createdCount++;
        }
      }

      // 4. Update all active staff to reset their salary status for the new month
      await this.prisma.staffMember.updateMany({
        where: { status: 'Active' },
        data: {
          is_salary_paid: false,
          salary_paid_date: null,
        },
      });

      this.logger.log(`Payroll generation complete. Created ${createdCount} new payslips for ${monthYear}.`);
    } catch (error: any) {
      this.logger.error('Error generating monthly payslips', error.stack);
    }
  }
}
