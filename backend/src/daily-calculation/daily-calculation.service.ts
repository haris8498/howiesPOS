import { RealtimeGateway } from '../realtime/realtime.gateway';
import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException, Optional } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SubmitDailyCalculationDto } from './dto/submit-daily-calculation.dto';
import { StartSessionDto } from './dto/start-session.dto';
import { QueryDailyCalculationDto } from './dto/query-daily-calculation.dto';

@Injectable()
export class DailyCalculationService {
  private readonly logger = new Logger(DailyCalculationService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Optional() private readonly realtimeGateway?: RealtimeGateway,
  ) {}

  /**
   * Sessions are strictly closed by manual cashier submission.
   * Auto-closing at midnight is disabled per business rules (shifts remain active across days until explicitly closed).
   */
  async autoCloseStaleSessions() {
    // Disabled: A shift remains ACTIVE until explicitly closed by cashier/manager,
    // even if it spans midnight or multiple days.
    return;
  }

  /**
   * Get active shift session for Cashier and persistent change cash baseline
   */
  async getActiveSession(cashierId?: string, terminalId?: string, restaurantId?: string) {
    await this.autoCloseStaleSessions();

    const whereClause: any = { status: 'ACTIVE' };
    if (terminalId) whereClause.terminal_id = terminalId;
    if (restaurantId) whereClause.restaurant_id = restaurantId;

    const session = await this.prisma.dailyCalculation.findFirst({
      where: whereClause,
      orderBy: { created_at: 'desc' },
      include: { expense_items: true },
    });

    // Find the latest recorded baseline change cash in database
    const lastHistoricalRecord = await this.prisma.dailyCalculation.findFirst({
      where: cashierId ? { cashier_id: cashierId } : {},
      orderBy: { created_at: 'desc' },
    });

    const persistentBaseline = Number(
      lastHistoricalRecord?.total_change_cash || lastHistoricalRecord?.starting_cash || 0
    );

    if (!session) {
      return {
        has_active_session: false,
        session: null,
        total_change_cash: persistentBaseline,
        starting_cash: persistentBaseline,
        previous_float: persistentBaseline,
      };
    }

    const currentTotalChange = Number(session.total_change_cash || session.starting_cash || persistentBaseline);

    const shiftDateObj = new Date(session.date || session.created_at);
    const localYear = shiftDateObj.getFullYear();
    const localMonth = String(shiftDateObj.getMonth() + 1).padStart(2, '0');
    const localDate = String(shiftDateObj.getDate()).padStart(2, '0');
    const shiftDateFormatted = `${localYear}-${localMonth}-${localDate}`;

    return {
      has_active_session: true,
      session,
      shift_date: shiftDateFormatted,
      opened_at: session.created_at,
      status: 'OPEN',
      total_change_cash: currentTotalChange,
      starting_cash: Number(session.starting_cash || currentTotalChange),
      previous_float: persistentBaseline,
    };
  }

  async startSession(dto: StartSessionDto, cashierInfo?: { id?: string; username?: string }) {
    const cashierId = dto.cashier_id || cashierInfo?.id || 'cashier-1';
    const cashierName = dto.cashier_name || cashierInfo?.username || 'Cashier';

    // 1. Fetch latest baseline float from history
    const lastHistoricalRecord = await this.prisma.dailyCalculation.findFirst({
      where: { cashier_id: cashierId },
      orderBy: { created_at: 'desc' },
    });

    const baselineFloat = Number(
      lastHistoricalRecord?.total_change_cash || lastHistoricalRecord?.starting_cash || 0
    );

    // 2. Determine the new total change cash
    let effectiveStartingCash: number;
    const inputAmount = Number(dto.adjustment_amount !== undefined ? dto.adjustment_amount : dto.starting_cash || 0);

    if (dto.adjustment_type === 'ADD') {
      effectiveStartingCash = baselineFloat + Math.abs(inputAmount);
    } else if (dto.adjustment_type === 'SUBTRACT') {
      effectiveStartingCash = Math.max(0, baselineFloat - Math.abs(inputAmount));
    } else if (dto.adjustment_type === 'SET') {
      effectiveStartingCash = Math.max(0, inputAmount);
    } else {
      if (inputAmount === 0 && baselineFloat > 0) {
        effectiveStartingCash = baselineFloat;
      } else {
        effectiveStartingCash = inputAmount;
      }
    }

    const restaurantId = dto.restaurant_id || 'default';
    const terminalId = dto.terminal_id ? String(dto.terminal_id) : '1';

    // 3. Rule 1: Only ONE active shift per terminal at a time (SYNC-005)
    const existing = await this.prisma.dailyCalculation.findFirst({
      where: {
        restaurant_id: restaurantId,
        terminal_id: terminalId,
        status: 'ACTIVE',
      },
      orderBy: { created_at: 'desc' },
    });

    if (existing) {
      if (dto.is_adjustment === true) {
        const updated = await this.prisma.dailyCalculation.update({
          where: { id: existing.id },
          data: {
            starting_cash: new Prisma.Decimal(effectiveStartingCash),
            total_change_cash: new Prisma.Decimal(effectiveStartingCash),
            opening_float: new Prisma.Decimal(effectiveStartingCash),
          },
          include: { expense_items: true },
        });

        this.logger.log(`Updated rolling starting cash to PKR ${effectiveStartingCash} for active session ${existing.id}`);
        return {
          has_active_session: true,
          session: updated,
          total_change_cash: Number(updated.total_change_cash),
          starting_cash: Number(updated.starting_cash),
        };
      }

      // Reject duplicate/concurrent active shifts
      throw new ConflictException({
        success: false,
        message: `An active shift already exists on terminal ${terminalId}. Close the current shift before opening a new shift.`,
        activeShift: {
          id: existing.id,
          shiftDate: existing.date,
          shift_name: existing.shift_name,
          cashier_id: existing.cashier_id,
          cashier_name: existing.cashier_name,
          openedAt: existing.created_at,
          status: existing.status,
        },
      });
    }

    // 4. Compute restaurant local start calendar date (Rule 3: shift date is based on start date)
    const now = new Date();
    const shiftDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);

    // 5. Create new ACTIVE session with cumulative rolling baseline float
    try {
      const created = await this.prisma.dailyCalculation.create({
        data: {
          date: shiftDate,
          restaurant_id: restaurantId,
          terminal_id: terminalId,
          shift_name: dto.shift_name || 'General Shift',
          cashier_id: cashierId,
          cashier_name: cashierName,
          starting_cash: new Prisma.Decimal(effectiveStartingCash),
          total_change_cash: new Prisma.Decimal(effectiveStartingCash),
          opening_float: new Prisma.Decimal(effectiveStartingCash),
          status: 'ACTIVE',
        },
        include: { expense_items: true },
      });

      this.logger.log(`Opened new shift session for ${cashierName} (Shift Date: ${shiftDate.toISOString().split('T')[0]})`);
      this.realtimeGateway?.emitShiftStarted(created as any);
      return {
        has_active_session: true,
        session: created,
        total_change_cash: Number(created.total_change_cash),
        starting_cash: Number(created.starting_cash),
      };
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictException({
          success: false,
          message: 'An active shift already exists. Close the current shift before opening a new shift.',
        });
      }
      throw err;
    }
  }

  private async resolveShiftTimeWindow(dateString?: string, cashierId?: string) {
    const now = new Date();
    let startOfDay: Date;
    let endOfDay: Date;

    const activeSessionInfo = await this.getActiveSession(cashierId);

    if (activeSessionInfo.has_active_session && activeSessionInfo.session) {
      // RULE 3 & 4: Shift date is strictly based on START DATE
      const sessionDate = new Date(activeSessionInfo.session.date || activeSessionInfo.session.created_at);
      startOfDay = new Date(sessionDate.getFullYear(), sessionDate.getMonth(), sessionDate.getDate(), 0, 0, 0, 0);
      endOfDay = new Date(Math.max(now.getTime(), new Date(sessionDate.getFullYear(), sessionDate.getMonth(), sessionDate.getDate(), 23, 59, 59, 999).getTime()));
      const sessionStart = new Date(activeSessionInfo.session.created_at || activeSessionInfo.session.date);
      const queryStartTime = sessionStart;
      const queryEndTime = new Date(Math.max(now.getTime() + 60000, endOfDay.getTime()));
      return { startOfDay, endOfDay, queryStartTime, queryEndTime, activeSessionInfo };
    }

    if (dateString) {
      const parts = dateString.split('-');
      if (parts.length === 3) {
        const y = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10) - 1;
        const d = parseInt(parts[2], 10);
        startOfDay = new Date(y, m, d, 0, 0, 0, 0);
        endOfDay = new Date(y, m, d, 23, 59, 59, 999);
      } else {
        const targetDate = new Date(dateString);
        startOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
        endOfDay = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);
      }
    } else {
      startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    }

    const queryStartTime = startOfDay;
    const queryEndTime = endOfDay;
    return { startOfDay, endOfDay, queryStartTime, queryEndTime, activeSessionInfo };
  }

  async getLiveSummary(dateString?: string, cashierId?: string) {
    const { startOfDay, queryStartTime, queryEndTime, activeSessionInfo } =
      await this.resolveShiftTimeWindow(dateString, cashierId);

    // If there is NO active session (shift has been closed and next shift hasn't started yet):
    // return 0 for live calculation so counter is completely clean!
    if (!activeSessionInfo.has_active_session || !activeSessionInfo.session) {
      return {
        date: dateString || new Date().toISOString(),
        total_gross_sales: 0,
        total_cash_sales: 0,
        total_card_sales: 0,
        total_online_sales: 0,
        total_discounts: 0,
        total_tax: 0,
        total_orders_count: 0,
        dine_in_count: 0,
        takeaway_count: 0,
        online_count: 0,
        starting_cash: activeSessionInfo.starting_cash || 0,
        total_change_cash: activeSessionInfo.total_change_cash || 0,
        has_active_session: false,
      };
    }

    const activeSessionId = activeSessionInfo.session.id;

    // Fetch all non-cancelled orders completed/placed during this active shift
    const orders = await this.prisma.order.findMany({
      where: {
        OR: [
          { shift_id: activeSessionId },
          {
            shift_id: null,
            created_at: {
              gte: queryStartTime,
              lte: queryEndTime,
            },
          },
        ],
        status: { notIn: ['cancelled', 'rejected'] },
      },
      include: {
        payments: true,
      },
    });

    let totalGrossSales = 0;
    let totalCashSales = 0;
    let totalCardSales = 0;
    let totalOnlineSales = 0;
    let totalDiscounts = 0;
    let totalTax = 0;
    let dineInCount = 0;
    let takeawayCount = 0;
    let onlineCount = 0;

    for (const ord of orders) {
      const gTotal = Number(ord.grand_total || 0);
      totalGrossSales += gTotal;
      totalDiscounts += Number(ord.discount_amount || 0);
      totalTax += Number(ord.tax_amount || 0);

      const type = (ord.order_type || '').toLowerCase();
      if (type.includes('dine')) dineInCount++;
      else if (type.includes('takeaway')) takeawayCount++;
      else onlineCount++;

      // Aggregate payment breakdown per order
      if (ord.payments && ord.payments.length > 0) {
        let orderPaidSum = 0;
        for (const p of ord.payments) {
          const amt = Number(p.amount || 0);
          orderPaidSum += amt;
          const method = (p.payment_method || '').toLowerCase();
          if (method === 'cash') {
            totalCashSales += amt;
          } else if (method === 'card' || method === 'credit' || method === 'debit') {
            totalCardSales += amt;
          } else {
            totalOnlineSales += amt;
          }
        }
        if (orderPaidSum < gTotal) {
          totalCashSales += (gTotal - orderPaidSum);
        }
      } else {
        // Default unitemized tender is Cash
        totalCashSales += gTotal;
      }
    }

    const startingCash = activeSessionInfo.starting_cash || 0;
    const totalChangeCash = activeSessionInfo.total_change_cash || startingCash;

    const shiftDateObj = activeSessionInfo.session
      ? new Date(activeSessionInfo.session.date || activeSessionInfo.session.created_at)
      : startOfDay;
    const localYear = shiftDateObj.getFullYear();
    const localMonth = String(shiftDateObj.getMonth() + 1).padStart(2, '0');
    const localDate = String(shiftDateObj.getDate()).padStart(2, '0');
    const dateFormatted = `${localYear}-${localMonth}-${localDate}`;

    return {
      date: dateFormatted,
      shift_date: dateFormatted,
      opened_at: activeSessionInfo.session?.created_at || null,
      status: activeSessionInfo.has_active_session ? 'OPEN' : 'CLOSED',
      starting_cash: startingCash,
      total_change_cash: totalChangeCash,
      has_active_session: activeSessionInfo.has_active_session,
      shift_id: activeSessionInfo.session?.id || null,
      session_id: activeSessionInfo.session?.id || null,
      total_gross_sales: Number(totalGrossSales.toFixed(2)),
      total_cash_sales: Number(totalCashSales.toFixed(2)),
      total_card_sales: Number(totalCardSales.toFixed(2)),
      total_online_sales: Number(totalOnlineSales.toFixed(2)),
      total_discounts: Number(totalDiscounts.toFixed(2)),
      total_tax: Number(totalTax.toFixed(2)),
      total_orders_count: orders.length,
      dine_in_count: dineInCount,
      takeaway_count: takeawayCount,
      online_count: onlineCount,
    };
  }

  /**
   * Submit Daily Calculation & Execute Atomic Store Shift Closing
   */
  async submitDailyCalculation(dto: SubmitDailyCalculationDto, cashierInfo?: { id?: string; username?: string }) {
    const cashierId = dto.cashier_id || cashierInfo?.id || 'cashier-1';
    const cashierName = dto.cashier_name || cashierInfo?.username || 'Cashier';

    // 1. Identify active shift to close
    const targetShiftId = dto.shift_id || dto.id;
    const activeSession = targetShiftId
      ? await this.prisma.dailyCalculation.findUnique({
          where: { id: targetShiftId },
        })
      : await this.prisma.dailyCalculation.findFirst({
          where: { status: 'ACTIVE' },
          orderBy: { created_at: 'desc' },
        });

    if (!activeSession) {
      throw new NotFoundException('No active shift session found to close.');
    }

    const sessionStartTime = new Date(activeSession.created_at || activeSession.date);

    // 2. Rule 2: Guard - Prevent shift closure while ANY unresolved or pending order exists belonging to this shift
    const unresolvedOrders = await this.prisma.order.findMany({
      where: {
        AND: [
          {
            OR: [
              { shift_id: activeSession.id },
              {
                shift_id: null,
                created_at: { gte: sessionStartTime },
              },
            ],
          },
          {
            OR: [
              { status: { in: ['newOrder', 'pending', 'confirmed', 'preparing', 'ready', 'served', 'accepted', 'in_progress'] } },
              { is_paid: false, status: { notIn: ['cancelled', 'rejected'] } },
            ],
          },
        ],
      },
      select: {
        id: true,
        order_number: true,
        order_type: true,
        status: true,
        is_paid: true,
        grand_total: true,
        created_at: true,
      },
      orderBy: { created_at: 'asc' },
    });

    if (unresolvedOrders.length > 0) {
      if (dto.force_close === true || dto.auto_resolve_pending === true) {
        this.logger.warn(`Force close requested: Auto-resolving ${unresolvedOrders.length} pending order(s) for shift ${activeSession.id}`);
        for (const o of unresolvedOrders) {
          await this.prisma.order.update({
            where: { id: o.id },
            data: {
              status: o.is_paid ? 'completed' : 'cancelled',
              shift_id: activeSession.id,
            },
          });
        }
      } else {
        const orderDetails = unresolvedOrders
          .map((o) => `#${o.order_number} (${o.order_type}, status: ${o.status}, paid: ${o.is_paid ? 'YES' : 'NO'})`)
          .join(', ');
        throw new ConflictException({
          success: false,
          message: `Cannot close this shift because there are pending orders. Please complete or resolve all pending orders before closing the shift.`,
          pendingOrders: unresolvedOrders.length,
          pending_orders_count: unresolvedOrders.length,
          orders: unresolvedOrders.map((o) => ({
            id: o.id,
            order_number: o.order_number,
            order_type: o.order_type,
            status: o.status,
            is_paid: o.is_paid,
            grand_total: Number(o.grand_total),
            created_at: o.created_at,
          })),
        });
      }
    }

    // Guard: Prevent shift closure if any delivery dispatches in this shift remain active in transit
    const activeDispatches = await this.prisma.deliveryDispatch.findMany({
      where: {
        dispatch_status: { in: ['pending', 'assigned', 'picked_up', 'on_the_way'] },
        online_order_detail: {
          order: {
            OR: [
              { shift_id: activeSession.id },
              {
                shift_id: null,
                created_at: { gte: sessionStartTime },
              },
            ],
            status: { notIn: ['cancelled', 'rejected'] },
          },
        },
      },
      include: {
        online_order_detail: {
          include: { order: true },
        },
      },
    });

    if (activeDispatches.length > 0) {
      if (dto.force_close === true || dto.auto_resolve_pending === true) {
        this.logger.warn(`Force close requested: Auto-resolving ${activeDispatches.length} active delivery dispatch(es) for shift ${activeSession.id}`);
        for (const d of activeDispatches) {
          await this.prisma.deliveryDispatch.update({
            where: { id: d.id },
            data: { dispatch_status: 'delivered' },
          });
        }
      } else {
        const dispatchDetails = activeDispatches
          .map((d) => `#${d.online_order_detail?.order?.order_number || d.id} (status: ${d.dispatch_status})`)
          .join(', ');
        throw new ConflictException({
          success: false,
          message: `Cannot close shift: ${activeDispatches.length} delivery dispatch(es) remain active: ${dispatchDetails}. Please mark dispatches delivered or resolved before closing the shift.`,
          pendingOrders: activeDispatches.length,
          pending_orders_count: activeDispatches.length,
        });
      }
    }

    const live = await this.getLiveSummary(dto.date, cashierId);

    const startingCash = Number(dto.starting_cash !== undefined ? dto.starting_cash : (dto.opening_float !== undefined ? dto.opening_float : (live.starting_cash || 0)));
    const cashSubmitted = Number(dto.cash_submitted !== undefined ? dto.cash_submitted : (dto.total_cash_submitted !== undefined ? dto.total_cash_submitted : 0));
    const totalCash = Number(dto.total_cash !== undefined ? dto.total_cash : 0);
    const cashSkimming = Number(dto.cash_skimming !== undefined ? dto.cash_skimming : 0);

    // Sum expense items
    const expenseItems = dto.expense_items || [];
    let totalExpenses = 0;
    for (const item of expenseItems) {
      totalExpenses += Number(item.amount || 0);
    }

    // Validation: Cash Skimming and Expenses are independent cash drawer deductions
    // Expected drawer cash is calculated as startingCash + cashSales - cashSkimming - totalExpenses

    const submittedAmount = dto.total_cash !== undefined
      ? Number(dto.total_cash)
      : (dto.total_cash_submitted !== undefined ? Number(dto.total_cash_submitted) : Number(dto.cash_submitted || 0));
    const expectedSubmitted = Math.max(0, live.total_cash_sales - totalExpenses);
    const expectedCounted = startingCash + live.total_cash_sales;

    const expectedCash = startingCash + live.total_cash_sales - cashSkimming - totalExpenses;
    const variance = dto.cash_variance !== undefined
      ? Number(dto.cash_variance)
      : (submittedAmount - expectedSubmitted);
    const cashVariance = dto.cash_variance !== undefined
      ? Number(dto.cash_variance)
      : (dto.actual_cash_counted !== undefined
          ? Number(dto.actual_cash_counted) - expectedCounted
          : (cashSubmitted - expectedCounted));

    // Execute within Prisma atomic transaction
    const result = await this.prisma.$transaction(async (tx) => {
      // Synchronize final expense items
      await tx.dailyExpenseItem.deleteMany({
        where: { calculation_id: activeSession.id },
      });

      if (expenseItems.length > 0) {
        await tx.dailyExpenseItem.createMany({
          data: expenseItems.map((exp) => ({
            calculation_id: activeSession.id,
            item_name: exp.item_name,
            category: exp.category || 'Kitchen Supplies',
            amount: new Prisma.Decimal(Number(exp.amount || 0)),
            receipt_number: exp.receipt_number || null,
            notes: exp.notes || null,
          })),
        });
      }

      // Rule 3 & 4: Shift date is strictly based on START DATE. Never overwrite with closing date!
      const calculation = await tx.dailyCalculation.update({
        where: { id: activeSession.id },
        data: {
          date: activeSession.date,
          shift_name: dto.shift_name || activeSession.shift_name || 'Full Day',
          cashier_name: activeSession.cashier_name,
          closed_by_id: cashierId,
          closed_by_name: cashierName,
          starting_cash: new Prisma.Decimal(startingCash),
          total_change_cash: new Prisma.Decimal(live.total_change_cash),
          cash_submitted: new Prisma.Decimal(cashSubmitted),
          total_cash: new Prisma.Decimal(totalCash),
          cash_skimming: new Prisma.Decimal(cashSkimming),
          total_gross_sales: new Prisma.Decimal(live.total_gross_sales),
          total_cash_sales: new Prisma.Decimal(live.total_cash_sales),
          total_card_sales: new Prisma.Decimal(live.total_card_sales),
          total_online_sales: new Prisma.Decimal(live.total_online_sales),
          total_discounts: new Prisma.Decimal(live.total_discounts),
          total_tax: new Prisma.Decimal(live.total_tax),
          total_orders_count: live.total_orders_count,
          dine_in_count: live.dine_in_count,
          takeaway_count: live.takeaway_count,
          online_count: live.online_count,
          opening_float: new Prisma.Decimal(startingCash),
          total_cash_submitted: new Prisma.Decimal(cashSubmitted),
          total_cash_expenses: new Prisma.Decimal(totalExpenses),
          expected_cash_in_hand: new Prisma.Decimal(expectedCash),
          variance_amount: new Prisma.Decimal(variance),
          cash_variance: new Prisma.Decimal(cashVariance),
          variance_reason: dto.variance_reason || null,
          status: 'CLOSED',
          closing_notes: dto.closing_notes || null,
          version: { increment: 1 },
          submitted_at: new Date(),
        },
        include: { expense_items: true },
      });

      // Permanently stamp any orders that were created during this shift
      await tx.order.updateMany({
        where: {
          OR: [
            { shift_id: activeSession.id },
            {
              shift_id: null,
              created_at: {
                gte: sessionStartTime,
                lte: new Date(),
              },
            },
          ],
        },
        data: {
          shift_id: activeSession.id,
        },
      });

      // Mirror each cash expense into global expenses table for audit
      for (const exp of expenseItems) {
        await tx.expense.create({
          data: {
            title: `[Daily Close] ${exp.item_name}`,
            category: exp.category || 'Store Supplies',
            amount: new Prisma.Decimal(Number(exp.amount || 0)),
            date: activeSession.date,
            recorded_by: cashierName,
          },
        });
      }

      // Note: Restaurant tables are NOT automatically reset to available upon shift close.
      // Active table occupations, reservations, and orders persist across shifts until explicitly cleared by staff.

      // Reset riders active counts
      await tx.deliveryRider.updateMany({
        data: {
          is_available: true,
          active_deliveries_count: 0,
        },
      });

      return calculation;
    });

    this.logger.log(`Shift closed & submitted successfully by ${cashierName}. Table states preserved.`);
    this.realtimeGateway?.emitShiftClosed(result as any);
    return result;
  }

  async getHistory(query: QueryDailyCalculationDto) {
    const where: Prisma.DailyCalculationWhereInput = {};

    await this.autoCloseStaleSessions();

    if (query.startDate && query.endDate) {
      const [sy, sm, sd] = query.startDate.split('-').map(Number);
      const [ey, em, ed] = query.endDate.split('-').map(Number);
      where.date = {
        gte: new Date(Date.UTC(sy, sm - 1, sd, 0, 0, 0, 0)),
        lte: new Date(Date.UTC(ey, em - 1, ed, 23, 59, 59, 999)),
      };
    } else if (query.startDate) {
      const [sy, sm, sd] = query.startDate.split('-').map(Number);
      where.date = {
        gte: new Date(Date.UTC(sy, sm - 1, sd, 0, 0, 0, 0)),
      };
    }

    if (query.cashierId) {
      where.cashier_id = query.cashierId;
    }

    if (query.status) {
      where.status = query.status;
    }

    const records = await this.prisma.dailyCalculation.findMany({
      where,
      include: {
        expense_items: true,
      },
      orderBy: [
        { date: 'desc' },
        { created_at: 'desc' },
      ],
    });

    // For any ACTIVE session today, dynamically populate its current live figures
    for (const rec of records) {
      if (rec.status === 'ACTIVE') {
        const dStr = rec.date.toISOString().split('T')[0];
        const live = await this.getLiveSummary(dStr, rec.cashier_id);
        rec.total_gross_sales = new Prisma.Decimal(live.total_gross_sales);
        rec.total_cash_sales = new Prisma.Decimal(live.total_cash_sales);
        rec.total_card_sales = new Prisma.Decimal(live.total_card_sales);
        rec.total_online_sales = new Prisma.Decimal(live.total_online_sales);
        rec.total_discounts = new Prisma.Decimal(live.total_discounts);
        rec.total_tax = new Prisma.Decimal(live.total_tax);
        rec.total_orders_count = live.total_orders_count;
        rec.dine_in_count = live.dine_in_count;
        rec.takeaway_count = live.takeaway_count;
        rec.online_count = live.online_count;
      }
    }

    return records;
  }

  /**
   * Get single calculation by ID
   */
  async getById(id: string) {
    const calculation = await this.prisma.dailyCalculation.findUnique({
      where: { id },
      include: {
        expense_items: true,
      },
    });

    if (!calculation) {
      throw new NotFoundException(`Daily calculation with ID ${id} not found`);
    }

    return calculation;
  }

  /**
   * Add an expense item directly to active session in PostgreSQL database
   */
  async addExpenseItemToActiveSession(dto: {
    item_name: string;
    category?: string;
    amount: number;
    receipt_number?: string;
    notes?: string;
    cashier_id?: string;
  }) {
    let activeSession = await this.prisma.dailyCalculation.findFirst({
      where: {
        status: 'ACTIVE',
        ...(dto.cashier_id ? { cashier_id: dto.cashier_id } : {}),
      },
      orderBy: { created_at: 'desc' },
    });

    if (!activeSession) {
      activeSession = await this.prisma.dailyCalculation.create({
        data: {
          date: new Date(),
          shift_name: 'General Shift',
          cashier_id: dto.cashier_id || 'cashier-1',
          cashier_name: 'Cashier',
          status: 'ACTIVE',
        },
      });
    }

    const item = await this.prisma.dailyExpenseItem.create({
      data: {
        calculation_id: activeSession.id,
        item_name: dto.item_name,
        category: dto.category || 'Kitchen Supplies',
        amount: new Prisma.Decimal(dto.amount),
        receipt_number: dto.receipt_number || null,
        notes: dto.notes || null,
      },
    });

    return item;
  }

  /**
   * Delete an expense item from active session in database
   */
  async deleteExpenseItemFromActiveSession(expenseId: string) {
    return this.prisma.dailyExpenseItem.deleteMany({
      where: { id: expenseId },
    });
  }
}

