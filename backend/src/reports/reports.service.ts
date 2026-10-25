import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { QueryReportDto } from './dto/query-report.dto';

export interface ReportSummaryResult {
  totalRevenue: number;
  totalCashSales: number;
  totalCardSales: number;
  totalOnlineSales: number;
  totalSubtotal: number;
  totalDiscount: number;
  totalTax: number;
  totalOrders: number;
  totalUnitsSold: number;
  avgItemPrice: number;
  topCategory: string;
  totalExpenses: number;
  netProfit: number;
  dateRange: {
    startDate: string;
    endDate: string;
    period: string;
  };
}

export interface ProductReportResult {
  productName: string;
  category: string;
  unitPrice: number;
  unitsSold: number;
  totalRevenue: number;
  image_url?: string;
  imagePath?: string;
}

export interface OrderTypeStatsResult {
  orderType: string;
  orderCount: number;
  totalRevenue: number;
  percentage: number;
}

export interface CancelledOrderResult {
  id: string;
  orderNumber: string;
  orderType: string;
  tableOrDetails: string;
  customerName: string;
  cancelledItems: {
    itemName: string;
    quantity: number;
    unitPrice: number;
    totalPrice: number;
    cancelReason?: string | null;
    cancelledAt?: string | null;
  }[];
  activeItems: { itemName: string; quantity: number; unitPrice: number; totalPrice: number }[];
  grandTotal: number;
  cancelledValue: number;
  createdAt: string;
  cancelledAt: string | null;
}

export interface CategoryStatsResult {
  category: string;
  unitsSold: number;
  totalRevenue: number;
  percentage: number;
}

export interface DailySalesTrendResult {
  date: string;
  orderCount: number;
  totalRevenue: number;
}

@Injectable()
export class ReportsService {
  private readonly logger = new Logger(ReportsService.name);

  constructor(private readonly prisma: PrismaService) {}

  private round(val: number): number {
    return Math.round((val + Number.EPSILON) * 100) / 100;
  }

  async resolveDateRangeAsync(dto: QueryReportDto): Promise<{
    start: Date;
    end: Date;
    periodLabel: string;
    shiftId?: string;
    isClosedAndEmpty?: boolean;
  }> {
    const now = new Date();
    const rawStart = dto.startDate || dto.start_date;
    const rawEnd = dto.endDate || dto.end_date;
    const p = dto.period ? dto.period.toLowerCase().replace(/[\s_-]/g, '') : '';

    // If explicit custom date range provided, respect it
    if (rawStart || rawEnd) {
      return this.resolveDateRange(dto);
    }

    // For Active Shift / Live Cashier reports: Calculate strictly from Opening Time until Closing Time
    if (p === 'current_shift' || p === 'shift' || p === 'today') {
      // 1. Check if there is an active session in dailyCalculation
      const activeSession = this.prisma.dailyCalculation
        ? await this.prisma.dailyCalculation.findFirst({
            where: {
              status: 'ACTIVE',
            },
            orderBy: { created_at: 'desc' },
          })
        : null;

      if (activeSession) {
        const openingTime = new Date(activeSession.created_at || activeSession.date);
        const end = new Date(Math.max(now.getTime(), new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime()));
        return {
          start: openingTime,
          end,
          periodLabel: 'Today (Live Shift)',
          shiftId: activeSession.id,
        };
      }

      if (p === 'current_shift' || p === 'shift') {
        return {
          start: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0),
          end: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999),
          periodLabel: 'Today (Shift Closed)',
          isClosedAndEmpty: true,
        };
      }
    }

    return this.resolveDateRange(dto);
  }

  private buildOrderWhere(
    scope: { start: Date; end: Date; shiftId?: string; isClosedAndEmpty?: boolean },
    extraWhere: Prisma.OrderWhereInput = {},
  ): Prisma.OrderWhereInput {
    if (scope.isClosedAndEmpty) {
      return { id: '__NONE_CLOSED_SHIFT__' };
    }

    const conditions: Prisma.OrderWhereInput[] = [];

    if (scope.shiftId) {
      const startOfDay = new Date(
        scope.start.getFullYear(),
        scope.start.getMonth(),
        scope.start.getDate(),
        0,
        0,
        0,
        0,
      );
      const effectiveStart = scope.start < startOfDay ? scope.start : startOfDay;
      conditions.push({
        OR: [
          { shift_id: scope.shiftId },
          {
            shift_id: null,
            created_at: {
              gte: effectiveStart,
              lte: scope.end,
            },
          },
          {
            created_at: {
              gte: effectiveStart,
              lte: scope.end,
            },
          },
        ],
      } as any);
    } else {
      const utcStart = new Date(
        Date.UTC(scope.start.getFullYear(), scope.start.getMonth(), scope.start.getDate(), 0, 0, 0, 0),
      );
      const utcEnd = new Date(
        Date.UTC(scope.end.getFullYear(), scope.end.getMonth(), scope.end.getDate(), 23, 59, 59, 999),
      );

      conditions.push({
        OR: [
          {
            daily_calculation: {
              OR: [
                { date: { gte: utcStart, lte: utcEnd } },
                { date: { gte: scope.start, lte: scope.end } },
                { created_at: { gte: scope.start, lte: scope.end } },
              ],
            },
          } as any,
          {
            shift_id: null,
            created_at: {
              gte: scope.start,
              lte: scope.end,
            },
          } as any,
          {
            created_at: {
              gte: scope.start,
              lte: scope.end,
            },
          },
        ],
      });
    }

    if (Object.keys(extraWhere).length > 0) {
      conditions.push(extraWhere);
    }

    return conditions.length === 1 ? conditions[0] : { AND: conditions };
  }

  private emptyReportSummary(periodLabel: string, start: Date, end: Date): ReportSummaryResult {
    return {
      totalRevenue: 0,
      totalCashSales: 0,
      totalCardSales: 0,
      totalOnlineSales: 0,
      totalSubtotal: 0,
      totalDiscount: 0,
      totalTax: 0,
      totalOrders: 0,
      totalUnitsSold: 0,
      avgItemPrice: 0,
      topCategory: 'N/A',
      totalExpenses: 0,
      netProfit: 0,
      dateRange: {
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        period: periodLabel,
      },
    };
  }

  resolveDateRange(dto: QueryReportDto): { start: Date; end: Date; periodLabel: string } {
    const now = new Date();
    let start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0); // Default This Month
    let end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
    let periodLabel = 'This Month';

    const rawStart = dto.startDate || dto.start_date;
    const rawEnd = dto.endDate || dto.end_date;

    if (rawStart || rawEnd) {
      if (rawStart) {
        const cleanStart = rawStart.includes('T') ? rawStart.split('T')[0] : rawStart;
        const parts = cleanStart.split(/[-/]/).map(Number);
        if (parts.length >= 3 && !isNaN(parts[0]) && !isNaN(parts[1]) && !isNaN(parts[2])) {
          start = new Date(parts[0], parts[1] - 1, parts[2], 0, 0, 0, 0);
        } else {
          const s = new Date(rawStart);
          if (isNaN(s.getTime())) {
            throw new BadRequestException('Invalid startDate format');
          }
          start = new Date(s.getFullYear(), s.getMonth(), s.getDate(), 0, 0, 0, 0);
        }
      }
      if (rawEnd) {
        const cleanEnd = rawEnd.includes('T') ? rawEnd.split('T')[0] : rawEnd;
        const parts = cleanEnd.split(/[-/]/).map(Number);
        if (parts.length >= 3 && !isNaN(parts[0]) && !isNaN(parts[1]) && !isNaN(parts[2])) {
          end = new Date(parts[0], parts[1] - 1, parts[2], 23, 59, 59, 999);
        } else {
          const e = new Date(rawEnd);
          if (isNaN(e.getTime())) {
            throw new BadRequestException('Invalid endDate format');
          }
          end = new Date(e.getFullYear(), e.getMonth(), e.getDate(), 23, 59, 59, 999);
        }
      } else if (rawStart) {
        end = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 23, 59, 59, 999);
      }
      if (start > end) {
        throw new BadRequestException('startDate cannot be after endDate');
      }
      periodLabel = 'Custom Date';
    } else if (dto.period) {
      const p = dto.period.toLowerCase().replace(/[\s_-]/g, '');
      if (p === 'today') {
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
        end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
        periodLabel = 'Today';
      } else if (p === 'yesterday') {
        const yesterday = new Date(now);
        yesterday.setDate(now.getDate() - 1);
        start = new Date(
          yesterday.getFullYear(),
          yesterday.getMonth(),
          yesterday.getDate(),
          0,
          0,
          0,
          0,
        );
        end = new Date(
          yesterday.getFullYear(),
          yesterday.getMonth(),
          yesterday.getDate(),
          23,
          59,
          59,
          999,
        );
        periodLabel = 'Yesterday';
      } else if (p === 'thisweek' || p === 'week') {
        const day = now.getDay();
        const diff = now.getDate() - day + (day === 0 ? -6 : 1); // Monday start
        start = new Date(now.getFullYear(), now.getMonth(), diff, 0, 0, 0, 0);
        end = new Date(now.getFullYear(), now.getMonth(), diff + 6, 23, 59, 59, 999);
        periodLabel = 'This Week';
      } else if (p === 'lastmonth') {
        start = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
        end = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
        periodLabel = 'Last Month';
      } else if (p === 'thisyear' || p === 'year') {
        start = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
        end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
        periodLabel = 'This Year';
      } else if (p === 'lastyear') {
        start = new Date(now.getFullYear() - 1, 0, 1, 0, 0, 0, 0);
        end = new Date(now.getFullYear() - 1, 11, 31, 23, 59, 59, 999);
        periodLabel = 'Last Year';
      } else {
        // default This Month
        start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
        end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
        periodLabel = 'This Month';
      }
    }

    return { start, end, periodLabel };
  }

  async getSummary(query: QueryReportDto = {}): Promise<ReportSummaryResult> {
    const scope = await this.resolveDateRangeAsync(query);
    const { start, end, periodLabel } = scope;
    if (scope.isClosedAndEmpty) {
      return this.emptyReportSummary(periodLabel, start, end);
    }

    const orderWhere = this.buildOrderWhere(scope, {
      status: {
        notIn: ['cancelled', 'rejected'],
      },
    });

    const effectiveOrderType = query.orderType || query.order_type;
    if (effectiveOrderType && effectiveOrderType !== 'All' && effectiveOrderType !== 'all') {
      orderWhere.order_type = effectiveOrderType;
    }

    // 1. Order aggregations
    const orders = await this.prisma.order.findMany({
      where: orderWhere,
      include: {
        order_items: {
          include: {
            menu_item: {
              include: {
                category: true,
              },
            },
          },
        },
        dine_in_detail: true,
        payments: true,
      },
    });

    const totalOrders = orders.length;
    const totalSubtotal = this.round(
      orders.reduce((sum, ord) => sum + Number(ord.subtotal || 0), 0),
    );
    const totalDiscount = this.round(
      orders.reduce((sum, ord) => sum + Number(ord.discount_amount || 0), 0),
    );
    const totalTax = this.round(
      orders.reduce((sum, ord) => {
        const tAmount = Number(ord.tax_amount || 0);
        const dineTax = Number(ord.dine_in_detail?.dine_in_tax || 0);
        return sum + (tAmount > 0 ? tAmount : dineTax);
      }, 0),
    );
    const totalRevenue = this.round(
      orders.reduce((sum, ord) => sum + Number(ord.grand_total || 0), 0),
    );

    let totalCashSales = 0;
    let totalCardSales = 0;
    let totalOnlineSales = 0;

    for (const ord of orders) {
      const gTotal = Number(ord.grand_total || 0);
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
        totalCashSales += gTotal;
      }
    }

    let totalUnitsSold = 0;
    let totalItemValue = 0;
    const categoryCounts: Record<string, number> = {};

    for (const ord of orders) {
      for (const item of ord.order_items) {
        if (!item.is_cancelled) {
          totalUnitsSold += item.quantity;
          totalItemValue += Number(item.total_price);
          const cat = item.menu_item?.category?.name || 'General';
          categoryCounts[cat] = (categoryCounts[cat] || 0) + item.quantity;
        }
      }
    }

    const avgItemPrice = totalUnitsSold > 0 ? this.round(totalItemValue / totalUnitsSold) : 0;

    // 2. Real Expense aggregations from database for matching period
    const honorExpenses = await this.prisma.expense.findMany({
      where: {
        date: {
          gte: start,
          lte: end,
        },
      },
    });

    const dailyExpenses = this.prisma.dailyExpenseItem
      ? await this.prisma.dailyExpenseItem.findMany({
          where: {
            created_at: {
              gte: start,
              lte: end,
            },
          },
        })
      : [];

    const totalHonorAmt = honorExpenses.reduce((sum, exp) => sum + Number(exp.amount), 0);
    const totalDailyAmt = dailyExpenses.reduce((sum, exp) => sum + Number(exp.amount), 0);
    const totalExpenses = this.round(totalHonorAmt + totalDailyAmt);

    const netProfit = this.round(totalRevenue - totalExpenses);

    // Determine Top Category dynamically from real order items
    let topCategory = 'None';
    let maxUnits = 0;
    for (const [cat, units] of Object.entries(categoryCounts)) {
      if (units > maxUnits) {
        maxUnits = units;
        topCategory = cat;
      }
    }

    return {
      totalRevenue,
      totalCashSales: this.round(totalCashSales),
      totalCardSales: this.round(totalCardSales),
      totalOnlineSales: this.round(totalOnlineSales),
      totalSubtotal,
      totalDiscount,
      totalTax,
      totalOrders,
      totalUnitsSold,
      avgItemPrice,
      topCategory,
      totalExpenses,
      netProfit,
      dateRange: {
        startDate: start.toISOString(),
        endDate: end.toISOString(),
        period: periodLabel,
      },
    };
  }

  async getProductPerformance(query: QueryReportDto = {}): Promise<ProductReportResult[]> {
    const scope = await this.resolveDateRangeAsync(query);
    if (scope.isClosedAndEmpty) {
      return [];
    }

    const orderWhere = this.buildOrderWhere(scope, {
      status: {
        notIn: ['cancelled', 'rejected'],
      },
    });

    const effectiveOrderType = query.orderType || query.order_type;
    if (effectiveOrderType && effectiveOrderType !== 'All' && effectiveOrderType !== 'all') {
      orderWhere.order_type = effectiveOrderType;
    }

    const items = await this.prisma.orderItem.findMany({
      where: {
        order: orderWhere,
        is_cancelled: false,
      },
      include: {
        menu_item: {
          include: {
            category: true,
          },
        },
      },
    });

    const productMap = new Map<
      string,
      {
        productName: string;
        category: string;
        unitPrice: number;
        unitsSold: number;
        totalRevenue: number;
        image_url: string;
        imagePath: string;
      }
    >();

    for (const item of items) {
      const key = item.item_name;
      const categoryName = item.menu_item?.category?.name || 'General';
      const itemImageUrl = item.menu_item?.image_url || '';
      const existing = productMap.get(key);

      if (existing) {
        existing.unitsSold += item.quantity;
        existing.totalRevenue = this.round(existing.totalRevenue + Number(item.total_price));
        if (!existing.image_url && itemImageUrl) {
          existing.image_url = itemImageUrl;
          existing.imagePath = itemImageUrl;
        }
      } else {
        productMap.set(key, {
          productName: item.item_name,
          category: categoryName,
          unitPrice: Number(item.unit_price),
          unitsSold: item.quantity,
          totalRevenue: Number(item.total_price),
          image_url: itemImageUrl,
          imagePath: itemImageUrl,
        });
      }
    }

    let results = Array.from(productMap.values()).sort((a, b) => b.totalRevenue - a.totalRevenue);

    if (query.category && query.category !== 'All Categories') {
      results = results.filter((p) =>
        p.category.toLowerCase().includes(query.category!.toLowerCase()),
      );
    }

    if (query.search) {
      results = results.filter((p) =>
        p.productName.toLowerCase().includes(query.search!.toLowerCase()),
      );
    }

    return results;
  }

  async getCancelledOrders(query: QueryReportDto = {}): Promise<CancelledOrderResult[]> {
    const scope = await this.resolveDateRangeAsync(query);
    if (scope.isClosedAndEmpty) {
      return [];
    }

    let orderWhere: Prisma.OrderWhereInput;

    if (scope.shiftId) {
      const startOfDay = new Date(
        scope.start.getFullYear(),
        scope.start.getMonth(),
        scope.start.getDate(),
        0,
        0,
        0,
        0,
      );
      const effectiveStart = scope.start < startOfDay ? scope.start : startOfDay;
      orderWhere = {
        AND: [
          {
            OR: [
              { status: { in: ['cancelled', 'rejected'] } },
              { order_items: { some: { is_cancelled: true } } },
            ],
          },
          {
            OR: [
              { shift_id: scope.shiftId },
              {
                shift_id: null,
                created_at: {
                  gte: effectiveStart,
                  lte: scope.end,
                },
              },
              {
                created_at: {
                  gte: effectiveStart,
                  lte: scope.end,
                },
              },
            ],
          },
        ],
      } as any;
    } else {
      const { start, end } = scope;
      const utcStart = new Date(
        Date.UTC(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0),
      );
      const utcEnd = new Date(
        Date.UTC(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 999),
      );

      orderWhere = {
        AND: [
          {
            OR: [
              { status: { in: ['cancelled', 'rejected'] } },
              { order_items: { some: { is_cancelled: true } } },
            ],
          },
          {
            OR: [
              {
                order_items: {
                  some: {
                    is_cancelled: true,
                    cancelled_at: {
                      gte: start,
                      lte: end,
                    },
                  },
                },
              },
              {
                daily_calculation: {
                  OR: [
                    { date: { gte: utcStart, lte: utcEnd } },
                    { date: { gte: start, lte: end } },
                    { created_at: { gte: start, lte: end } },
                  ],
                },
              } as any,
              {
                shift_id: null,
                created_at: {
                  gte: start,
                  lte: end,
                },
              } as any,
              {
                created_at: {
                  gte: start,
                  lte: end,
                },
              },
            ],
          },
        ],
      };
    }

    // Fetch orders that either have status cancelled OR have at least one cancelled item
    const orders = await this.prisma.order.findMany({
      where: orderWhere,
      include: {
        order_items: true,
        dine_in_detail: {
          include: {
            table: true,
          },
        },
        takeaway_detail: true,
        online_detail: true,
      },
      orderBy: { created_at: 'desc' },
    });

    return orders.map((ord) => {
      // Resolve display name & table
      let orderType = 'Dine-In';
      let tableOrDetails = 'Main Hall';
      let customerName = 'Table Guest';

      if (ord.order_type === 'dineIn' || ord.order_type === 'dine_in') {
        orderType = 'Dine-In';
        tableOrDetails = ord.dine_in_detail?.table?.name || 'Table Guest';
      } else if (ord.order_type === 'takeaway') {
        orderType = 'Takeaway';
        tableOrDetails = `Token #${ord.takeaway_detail?.token_number || ord.order_number}`;
        customerName = ord.takeaway_detail?.customer_name || 'Walk-in Guest';
      } else if (ord.order_type === 'online' || ord.order_type === 'delivery') {
        orderType = 'Delivery';
        tableOrDetails = ord.online_detail?.delivery_address || 'Direct Delivery';
        customerName = ord.online_detail?.customer_name || 'Delivery Customer';
      }

      let cancelledItems = ord.order_items
        .filter((i) => i.is_cancelled)
        .map((i) => ({
          itemName: i.item_name,
          quantity: i.quantity,
          unitPrice: Number(i.unit_price),
          totalPrice: Number(i.total_price),
          cancelReason: i.cancel_reason,
          cancelledAt: i.cancelled_at ? i.cancelled_at.toISOString() : null,
        }));

      let activeItems = ord.order_items
        .filter((i) => !i.is_cancelled)
        .map((i) => ({
          itemName: i.item_name,
          quantity: i.quantity,
          unitPrice: Number(i.unit_price),
          totalPrice: Number(i.total_price),
        }));

      // If whole order was cancelled or rejected and no items had individual flag set
      if ((ord.status === 'cancelled' || ord.status === 'rejected') && cancelledItems.length === 0) {
        cancelledItems = activeItems.map((i) => ({
          ...i,
          cancelReason: ord.rejection_reason || 'Order Cancelled',
          cancelledAt: ord.created_at.toISOString(),
        }));
        activeItems = [];
      }

      let cancelledValue = this.round(
        cancelledItems.reduce((s, i) => s + i.totalPrice, 0),
      );
      if ((ord.status === 'cancelled' || ord.status === 'rejected') && cancelledValue === 0) {
        cancelledValue = Number(ord.grand_total);
      }

      const firstCancelledItem = ord.order_items.find((i) => i.is_cancelled && i.cancelled_at);
      const cancelledAt = firstCancelledItem?.cancelled_at
        ? firstCancelledItem.cancelled_at.toISOString()
        : (ord.status === 'cancelled' || ord.status === 'rejected' ? ord.created_at.toISOString() : null);

      return {
        id: ord.id,
        orderNumber: ord.order_number,
        orderType,
        tableOrDetails,
        customerName,
        cancelledItems,
        activeItems,
        grandTotal: Number(ord.grand_total),
        cancelledValue,
        createdAt: ord.created_at.toISOString(),
        cancelledAt,
      };
    });
  }

  async getOrderTypeStats(query: QueryReportDto = {}): Promise<OrderTypeStatsResult[]> {
    const scope = await this.resolveDateRangeAsync(query);
    if (scope.isClosedAndEmpty) {
      return [];
    }

    const orderWhere = this.buildOrderWhere(scope, {
      status: {
        notIn: ['cancelled', 'rejected'],
      },
    });

    const orders = await this.prisma.order.findMany({
      where: orderWhere,
    });

    const totalRevenueAll = orders.reduce((sum, o) => sum + Number(o.grand_total), 0);
    const typeMap = new Map<string, { count: number; revenue: number }>();

    for (const ord of orders) {
      const type = ord.order_type;
      const existing = typeMap.get(type) || { count: 0, revenue: 0 };
      existing.count += 1;
      existing.revenue = this.round(existing.revenue + Number(ord.grand_total));
      typeMap.set(type, existing);
    }

    return Array.from(typeMap.entries()).map(([orderType, stats]) => ({
      orderType,
      orderCount: stats.count,
      totalRevenue: stats.revenue,
      percentage: totalRevenueAll > 0 ? this.round((stats.revenue / totalRevenueAll) * 100) : 0,
    }));
  }

  async getDailySalesTrend(query: QueryReportDto = {}): Promise<DailySalesTrendResult[]> {
    const scope = await this.resolveDateRangeAsync(query);
    if (scope.isClosedAndEmpty) {
      return [];
    }

    const orderWhere = this.buildOrderWhere(scope, {
      status: {
        notIn: ['cancelled', 'rejected'],
      },
    });

    const orders = await this.prisma.order.findMany({
      where: orderWhere,
      orderBy: { created_at: 'asc' },
    });

    const dayMap = new Map<string, { count: number; revenue: number }>();

    for (const ord of orders) {
      const dateKey = ord.created_at.toISOString().split('T')[0];
      const existing = dayMap.get(dateKey) || { count: 0, revenue: 0 };
      existing.count += 1;
      existing.revenue = this.round(existing.revenue + Number(ord.grand_total));
      dayMap.set(dateKey, existing);
    }

    return Array.from(dayMap.entries()).map(([date, stats]) => ({
      date,
      orderCount: stats.count,
      totalRevenue: stats.revenue,
    }));
  }
}
