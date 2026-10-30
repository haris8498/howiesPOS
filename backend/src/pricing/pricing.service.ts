import {
  Injectable,
  Logger,
  ForbiddenException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { v7 as uuidv7 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { PasswordService } from '../auth/password.service';

export interface DiscountApproval {
  managerId: string;
  deviceId?: string;
  approvedAt?: string | Date;
  reason?: string;
  credential?: string; // PIN or password for online REST verification
}

export interface PricingCalculationOptions {
  clientGrandTotal?: number | Prisma.Decimal;
  clientSubtotal?: number | Prisma.Decimal;
  discountPercentage?: number | Prisma.Decimal;
  discountAmount?: number | Prisma.Decimal;
  discountReason?: string;
  discountApproval?: DiscountApproval;
  approvedByManagerId?: string;
  managerCredential?: string;
  source?: 'ONLINE' | 'OFFLINE';
  deviceId?: string;
  cashierId?: string;
  staffId?: string;
  rejectOnlineMismatch?: boolean;
  taxPercentage?: number | Prisma.Decimal;
  deliveryFee?: number | Prisma.Decimal;
  isCashierDiscount?: boolean;
  staffRole?: string;
}

export interface LineDiscrepancy {
  itemId: string;
  itemName: string;
  clientUnitPrice: Prisma.Decimal;
  catalogUnitPrice: Prisma.Decimal;
  difference: Prisma.Decimal;
  quantity: number;
}

export interface PricingCalculationResult {
  orderId: string;
  subtotal: Prisma.Decimal;
  discountPercentage: Prisma.Decimal;
  discountAmount: Prisma.Decimal;
  taxableAmount: Prisma.Decimal;
  taxAmount: Prisma.Decimal;
  dineInTax: Prisma.Decimal;
  deliveryFee: Prisma.Decimal;
  grandTotal: Prisma.Decimal;
  clientReportedTotal?: Prisma.Decimal;
  pricingStatus: 'VERIFIED' | 'MISMATCH' | 'UNAUTHORIZED_DISCOUNT';
  tolerance: Prisma.Decimal;
  difference: Prisma.Decimal;
  isWithinTolerance: boolean;
  lineDiscrepancies: LineDiscrepancy[];
  discountAuditRecord?: Prisma.DiscountAuditUncheckedCreateInput | null;
  pricingAuditRecord?: any;
}

@Injectable()
export class PricingService {
  private readonly logger = new Logger(PricingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwordService: PasswordService,
  ) {}

  /**
   * Authoritative server calculation per D-03 / SYNC-016.
   * Computes subtotal, validated discount, taxes, and grandTotal using fixed-point Decimal arithmetic.
   * Tolerates minor rounding differences (<= PRICING_ROUNDING_TOLERANCE, default 1.00).
   * Outside tolerance: persists order, sets pricingStatus = MISMATCH, logs PricingAudit.
   * Unapproved discounts: offline persists without discount + flags UNAUTHORIZED_DISCOUNT; online throws 403.
   */
  async calculate(
    orderId: string,
    tx: Prisma.TransactionClient,
    options?: PricingCalculationOptions,
  ): Promise<PricingCalculationResult> {
    const source = options?.source || 'ONLINE';

    // 1. Fetch active ledger items (D-05 invariant: voidedAt == null && is_cancelled == false)
    const activeItems = await tx.orderItem.findMany({
      where: {
        order_id: orderId,
        voidedAt: null,
        is_cancelled: false,
      },
      orderBy: {
        clientCreatedAt: 'asc',
      },
    });

    // 2. Fetch Order and details for context
    const order = await tx.order.findUnique({
      where: { id: orderId },
      include: {
        dine_in_detail: true,
        online_detail: true,
        takeaway_detail: true,
      },
    });

    if (!order) {
      throw new Error(`Order ${orderId} not found during pricing calculation`);
    }

    // 3. Line-by-line Catalog Pricing Evaluation
    const lineDiscrepancies: LineDiscrepancy[] = [];
    const lineTotals: Prisma.Decimal[] = [];

    for (const item of activeItems) {
      let catalogUnitPrice = new Prisma.Decimal(item.unit_price);

      if (item.menu_item_id) {
        const menuItem = await tx.menuItem.findUnique({
          where: { id: item.menu_item_id },
          include: {
            sizes: true,
            options: true,
          },
        });

        if (menuItem) {
          // A. Size matching
          const selectedSize = (item.selected_size || 'Regular').trim().toLowerCase();
          const matchedSize = (menuItem.sizes || []).find(
            (s) => s.size_name.trim().toLowerCase() === selectedSize,
          );

          if (matchedSize) {
            catalogUnitPrice = new Prisma.Decimal(matchedSize.price);
          } else {
            catalogUnitPrice = new Prisma.Decimal(menuItem.base_price);
          }

          // B. Extra Toppings
          if (item.extra_toppings && item.extra_toppings.trim().length > 0) {
            const requestedToppings = item.extra_toppings
              .split(',')
              .map((t) => t.trim().toLowerCase())
              .filter((t) => t.length > 0);

            for (const toppingName of requestedToppings) {
              const matchedOption = (menuItem.options || []).find(
                (o) =>
                  o.option_type.toLowerCase() === 'topping' &&
                  o.option_name.trim().toLowerCase() === toppingName,
              );
              if (matchedOption) {
                catalogUnitPrice = catalogUnitPrice.plus(matchedOption.additional_price);
              }
            }
          }

          // C. Selected Crust
          if (item.selected_crust && item.selected_crust.trim().length > 0) {
            const crustName = item.selected_crust.trim().toLowerCase();
            const matchedCrust = (menuItem.options || []).find(
              (o) =>
                o.option_type.toLowerCase() === 'crust' &&
                o.option_name.trim().toLowerCase() === crustName,
            );
            if (matchedCrust) {
              catalogUnitPrice = catalogUnitPrice.plus(matchedCrust.additional_price);
            }
          }
        }
      }

      const clientUnitPrice = new Prisma.Decimal(item.unit_price);
      if (!clientUnitPrice.equals(catalogUnitPrice)) {
        lineDiscrepancies.push({
          itemId: item.id,
          itemName: item.item_name,
          clientUnitPrice,
          catalogUnitPrice,
          difference: clientUnitPrice.minus(catalogUnitPrice).abs(),
          quantity: item.quantity,
        });
      }

      const quantity = new Prisma.Decimal(item.quantity);
      const lineTotal = catalogUnitPrice
        .times(quantity)
        .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
      lineTotals.push(lineTotal);
    }

    // 4. Authoritative Subtotal
    const subtotal = lineTotals
      .reduce((sum, lt) => sum.plus(lt), new Prisma.Decimal('0.00'))
      .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

    // 5. Manager Discount Validation (Tasks 4 & 5)
    let requestedDiscountPercentage = new Prisma.Decimal('0.00');
    if (options?.discountPercentage !== undefined) {
      requestedDiscountPercentage = new Prisma.Decimal(options.discountPercentage);
    } else if (order.discount_percentage !== undefined) {
      requestedDiscountPercentage = new Prisma.Decimal(order.discount_percentage);
    }

    let requestedDiscountAmount = new Prisma.Decimal('0.00');
    if (options?.discountAmount !== undefined) {
      requestedDiscountAmount = new Prisma.Decimal(options.discountAmount);
    } else if (order.discount_amount !== undefined) {
      requestedDiscountAmount = new Prisma.Decimal(order.discount_amount);
    }

    const hasDiscount =
      requestedDiscountPercentage.greaterThan(0) || requestedDiscountAmount.greaterThan(0);

    let effectiveDiscountAmount = new Prisma.Decimal('0.00');
    let effectiveDiscountPercentage = new Prisma.Decimal('0.00');
    let pricingStatus: 'VERIFIED' | 'MISMATCH' | 'UNAUTHORIZED_DISCOUNT' = 'VERIFIED';
    let isManagerApproved = false;
    let discountAuditRecord: Prisma.DiscountAuditUncheckedCreateInput | null = null;

    if (hasDiscount) {
      const approval = options?.discountApproval;
      const managerId =
        approval?.managerId ||
        (approval as any)?.manager_id ||
        options?.approvedByManagerId ||
        (order as any)?.approved_by_manager_id;
      const credential = options?.managerCredential || approval?.credential;

      const staffCandidateId =
        options?.cashierId ||
        (options as any)?.cashier_id ||
        options?.staffId ||
        (options as any)?.staff_id ||
        (options as any)?.user_id ||
        (options as any)?.userId ||
        (order as any)?.cashierId ||
        (order as any)?.cashier_id ||
        (order as any)?.staff_id ||
        (order as any)?.staffId ||
        (approval as any)?.cashier_id ||
        (approval as any)?.staff_id;

      let validManager: any = null;
      if (managerId) {
        validManager = await tx.staffUser.findFirst({
          where: {
            OR: [{ id: managerId }, { username: managerId }],
          },
        });
      }

      let validStaff: any = null;
      if (staffCandidateId) {
        if (validManager && (validManager.id === staffCandidateId || validManager.username === staffCandidateId)) {
          validStaff = validManager;
        } else {
          validStaff = await tx.staffUser.findFirst({
            where: {
              OR: [{ id: staffCandidateId }, { username: staffCandidateId }],
            },
          });
        }
      }

      let isApprovalAuthorized = false;
      let isCashierDiscount = false;

      // 1. Check Manager Approval
      if (validManager && validManager.is_active !== false) {
        const role = validManager.role.toLowerCase();
        if (['manager', 'admin', 'owner', 'superadmin'].includes(role)) {
          if (source === 'ONLINE' && credential) {
            isApprovalAuthorized = await this.passwordService.verify(
              credential,
              validManager.password_hash,
            );
          } else {
            // Offline sync: Flutter verified credentials locally per D-06; server validates role and active status
            isApprovalAuthorized = true;
          }
          if (isApprovalAuthorized) {
            isManagerApproved = true;
          }
        } else if (role === 'cashier') {
          // Approver provided is actually a cashier -> authorize under cashier discount policy
          if (source === 'ONLINE' && credential) {
            isApprovalAuthorized = await this.passwordService.verify(
              credential,
              validManager.password_hash,
            );
          } else {
            isApprovalAuthorized = true;
          }
          if (isApprovalAuthorized) {
            isCashierDiscount = true;
            validStaff = validManager;
            validManager = null;
          }
        }
      }

      // 2. Check Cashier Discount (Task 2: Wave 6 Issue 3 - cashiers may apply discounts without manager approval)
      if (!isApprovalAuthorized && validStaff && validStaff.is_active !== false) {
        const staffRole = validStaff.role.toLowerCase();
        if (staffRole === 'cashier') {
          if (source === 'ONLINE' && credential) {
            isApprovalAuthorized = await this.passwordService.verify(
              credential,
              validStaff.password_hash,
            );
          } else {
            isApprovalAuthorized = true;
          }
          if (isApprovalAuthorized) {
            isCashierDiscount = true;
          }
        } else if (['manager', 'admin', 'owner', 'superadmin'].includes(staffRole)) {
          if (source === 'ONLINE' && credential) {
            isApprovalAuthorized = await this.passwordService.verify(
              credential,
              validStaff.password_hash,
            );
          } else {
            isApprovalAuthorized = true;
          }
          if (isApprovalAuthorized) {
            isManagerApproved = true;
            validManager = validStaff;
          }
        } else {
          // Role is an unauthorized order-creating role (e.g. waiter, rider, kitchen)
          isApprovalAuthorized = false;
        }
      } else if (
        !isApprovalAuthorized &&
        (options?.isCashierDiscount ||
          (options as any)?.is_cashier_discount ||
          options?.staffRole === 'cashier' ||
          (options as any)?.cashierRole === 'cashier')
      ) {
        // Cashier discount without staff user in DB
        if (source === 'ONLINE' && credential) {
          isApprovalAuthorized = false;
        } else {
          isApprovalAuthorized = true;
          isCashierDiscount = true;
        }
      }

      if (isApprovalAuthorized) {
        if (requestedDiscountPercentage.greaterThan(0)) {
          effectiveDiscountAmount = subtotal
            .times(requestedDiscountPercentage)
            .dividedBy(100)
            .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
          effectiveDiscountPercentage = requestedDiscountPercentage;
        } else {
          effectiveDiscountAmount = requestedDiscountAmount;
          effectiveDiscountPercentage = subtotal.greaterThan(0)
            ? requestedDiscountAmount
                .times(100)
                .dividedBy(subtotal)
                .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP)
            : new Prisma.Decimal('0.00');
        }

        if (effectiveDiscountAmount.greaterThan(subtotal)) {
          effectiveDiscountAmount = subtotal;
        }

        // DiscountAudit staff attribution:
        // approved_by must never be null. For a cashier discount set approved_by to the same staff id used for cashier_id (the staff_id carried in the mutation).
        // If no reliable staff id is present, set cashier_id to null and approved_by to the literal 'SELF_AUTHORIZED'.
        // For a manager-approved discount keep using the manager id.
        let cashierIdForAudit: string | null = null;
        if (validStaff && validStaff.id) {
          cashierIdForAudit = String(validStaff.id).trim();
        } else if (staffCandidateId && typeof staffCandidateId === 'string' && staffCandidateId.trim().length > 0 && isCashierDiscount) {
          cashierIdForAudit = staffCandidateId.trim();
        } else {
          cashierIdForAudit = null;
        }

        let approvedByForAudit: string;
        if (isManagerApproved && (validManager || managerId)) {
          approvedByForAudit = validManager?.id || managerId;
        } else {
          // Cashier discount
          if (cashierIdForAudit) {
            approvedByForAudit = cashierIdForAudit;
          } else {
            cashierIdForAudit = null;
            approvedByForAudit = 'SELF_AUTHORIZED';
          }
        }

        discountAuditRecord = {
          id: uuidv7(),
          order_id: orderId,
          amount: effectiveDiscountAmount,
          percent: effectiveDiscountPercentage,
          discount_type: requestedDiscountPercentage.greaterThan(0) ? 'PERCENTAGE' : 'FIXED',
          reason: approval?.reason || options?.discountReason || (isCashierDiscount ? 'Cashier Discount' : 'Manager Approved Discount'),
          cashier_id: cashierIdForAudit,
          approved_by: approvedByForAudit,
          device_id: options?.deviceId || approval?.deviceId || (approval as any)?.device_id || order.device_id || null,
          source,
          created_at: new Date(),
        };
      } else {
        // Unauthorized Discount Handler per Rule 5
        if (source === 'ONLINE') {
          throw new ForbiddenException(
            'Authorization required for discounts (cashier or manager role required)',
          );
        } else {
          // Offline sync -> order persisted, discount NOT applied to authoritative total, flagged UNAUTHORIZED_DISCOUNT
          this.logger.warn(
            `[D-03] Order ${orderId} submitted with unauthorized discount (manager: ${managerId}, staff: ${staffCandidateId}) - discount nullified and flagged UNAUTHORIZED_DISCOUNT`,
          );
          effectiveDiscountAmount = new Prisma.Decimal('0.00');
          effectiveDiscountPercentage = new Prisma.Decimal('0.00');
          pricingStatus = 'UNAUTHORIZED_DISCOUNT';
        }
      }
    }

    // 6. Tax and Fee Calculation
    const taxableAmount = Prisma.Decimal.max(
      new Prisma.Decimal('0.00'),
      subtotal.minus(effectiveDiscountAmount),
    );

    let taxAmount = new Prisma.Decimal('0.00');
    if (options?.taxPercentage !== undefined) {
      taxAmount = taxableAmount
        .times(new Prisma.Decimal(options.taxPercentage))
        .dividedBy(100)
        .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
    } else if (order.tax_amount !== undefined && new Prisma.Decimal(order.tax_amount).greaterThan(0)) {
      const currentTax = new Prisma.Decimal(order.tax_amount);
      const prevSubtotal = new Prisma.Decimal(order.subtotal || 0);
      if (prevSubtotal.greaterThan(0)) {
        const taxRate = currentTax.dividedBy(prevSubtotal);
        taxAmount = taxableAmount
          .times(taxRate)
          .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
      } else {
        taxAmount = currentTax;
      }
    }

    const orderType = (order.order_type || '').toLowerCase();
    const isDineIn = orderType === 'dinein' || orderType === 'dine_in';
    const dineInTax = isDineIn ? taxAmount : new Prisma.Decimal('0.00');

    const deliveryFee = new Prisma.Decimal(
      order.online_detail?.delivery_fee ?? options?.deliveryFee ?? 0,
    );

    // 7. Authoritative Grand Total
    const serverGrandTotal = taxableAmount
      .plus(taxAmount)
      .plus(deliveryFee)
      .toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);

    // 8. Tolerance and Mismatch Evaluation (Task 2)
    const toleranceStr = process.env.PRICING_ROUNDING_TOLERANCE || '1.00';
    const tolerance = new Prisma.Decimal(toleranceStr);

    let clientTotal: Prisma.Decimal;
    if (options?.clientGrandTotal !== undefined) {
      clientTotal = new Prisma.Decimal(options.clientGrandTotal);
    } else {
      clientTotal = new Prisma.Decimal(order.grand_total);
    }

    const difference = clientTotal.minus(serverGrandTotal).abs();
    const isWithinTolerance = difference.lessThanOrEqualTo(tolerance);

    if (pricingStatus !== 'UNAUTHORIZED_DISCOUNT') {
      if (isWithinTolerance) {
        pricingStatus = 'VERIFIED';
      } else {
        pricingStatus = 'MISMATCH';
      }
    }

    if (pricingStatus === 'MISMATCH') {
      this.logger.warn(
        `[D-03] Order ${orderId} price deviation outside tolerance: client=${clientTotal.toFixed(2)}, server=${serverGrandTotal.toFixed(2)}, diff=${difference.toFixed(2)} (tolerance=${tolerance.toFixed(2)})`,
      );

      if (source === 'ONLINE' && options?.rejectOnlineMismatch) {
        throw new UnprocessableEntityException({
          message: `Price mismatch: client total (${clientTotal}) deviates from server authoritative total (${serverGrandTotal}) by ${difference} (tolerance: ${tolerance})`,
          serverGrandTotal: serverGrandTotal.toString(),
          clientGrandTotal: clientTotal.toString(),
          difference: difference.toString(),
          lineDiscrepancies,
        });
      }
    }

    // 9. Persist Audits
    if (discountAuditRecord && tx.discountAudit) {
      await tx.discountAudit.create({
        data: discountAuditRecord,
      });
    }

    let pricingAuditRecord: any = null;
    const shouldWritePricingAudit =
      pricingStatus === 'MISMATCH' ||
      pricingStatus === 'UNAUTHORIZED_DISCOUNT' ||
      lineDiscrepancies.length > 0;

    if (shouldWritePricingAudit && tx.pricingAudit) {
      const clientSubtotal = options?.clientSubtotal !== undefined
        ? new Prisma.Decimal(options.clientSubtotal)
        : new Prisma.Decimal(order.subtotal);

      pricingAuditRecord = {
        id: uuidv7(),
        order_id: orderId,
        client_grand_total: clientTotal,
        server_grand_total: serverGrandTotal,
        client_subtotal: clientSubtotal,
        server_subtotal: subtotal,
        tolerance,
        difference,
        pricing_status: pricingStatus,
        line_discrepancies: lineDiscrepancies.length > 0 ? (lineDiscrepancies as any) : undefined,
        source,
        device_id: options?.deviceId || order.device_id || null,
        notes:
          pricingStatus === 'UNAUTHORIZED_DISCOUNT'
            ? 'Discount attempted without valid manager approval; discount removed from authoritative total'
            : pricingStatus === 'MISMATCH'
            ? `Client grand total deviated by ${difference.toFixed(2)} beyond tolerance ${tolerance.toFixed(2)}`
            : 'Line item prices deviated from catalog base prices',
        created_at: new Date(),
      };

      await tx.pricingAudit.create({
        data: pricingAuditRecord,
      });
    }

    // 10. Update Order in Transaction
    await tx.order.update({
      where: { id: orderId },
      data: {
        subtotal,
        discount_percentage: effectiveDiscountPercentage,
        discount_amount: effectiveDiscountAmount,
        tax_amount: taxAmount,
        grand_total: serverGrandTotal,
        client_reported_total: clientTotal,
        pricing_status: pricingStatus,
        ...(discountAuditRecord ? { approved_by_manager_id: isManagerApproved ? discountAuditRecord.approved_by : null } : {}),
      },
    });

    if (dineInTax.greaterThan(0) && order.dine_in_detail && tx.dineInOrderDetail?.update) {
      await tx.dineInOrderDetail.update({
        where: { order_id: orderId },
        data: { dine_in_tax: dineInTax },
      }).catch(() => {});
    }

    return {
      orderId,
      subtotal,
      discountPercentage: effectiveDiscountPercentage,
      discountAmount: effectiveDiscountAmount,
      taxableAmount,
      taxAmount,
      dineInTax,
      deliveryFee,
      grandTotal: serverGrandTotal,
      clientReportedTotal: clientTotal,
      pricingStatus,
      tolerance,
      difference,
      isWithinTolerance,
      lineDiscrepancies,
      discountAuditRecord,
      pricingAuditRecord,
    };
  }

  // ---------------------------------------------------------------------------
  // READ-ONLY AUDIT QUERIES (Task 6: Immutable - No Update/Delete Endpoints)
  // ---------------------------------------------------------------------------

  async getPricingAudits(filter?: {
    order_id?: string;
    pricing_status?: string;
    source?: string;
    take?: number;
    skip?: number;
  }) {
    return this.prisma.pricingAudit.findMany({
      where: {
        ...(filter?.order_id ? { order_id: filter.order_id } : {}),
        ...(filter?.pricing_status ? { pricing_status: filter.pricing_status } : {}),
        ...(filter?.source ? { source: filter.source } : {}),
      },
      include: {
        order: {
          select: {
            order_number: true,
            status: true,
            created_at: true,
            order_type: true,
          },
        },
      },
      orderBy: { created_at: 'desc' },
      take: filter?.take ?? 50,
      skip: filter?.skip ?? 0,
    });
  }

  async getDiscountAudits(orderId?: string, take = 50, skip = 0) {
    return this.prisma.discountAudit.findMany({
      where: {
        ...(orderId ? { order_id: orderId } : {}),
      },
      include: {
        order: {
          select: {
            order_number: true,
            grand_total: true,
            created_at: true,
          },
        },
      },
      orderBy: { created_at: 'desc' },
      take,
      skip,
    });
  }
}
