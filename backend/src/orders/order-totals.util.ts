/**
 * Pure order totals calculation helper.
 * Extracted to ensure identical math between OrdersService.cancelOrderItem
 * and OrderHandler.handleItemVoid (Wave 7b #39).
 */

export interface RecalculateOrderTotalsInput {
  subtotal: number;
  discountPercentage?: number | string | null;
  discountAmount?: number | string | null;
  taxAmount?: number | string | null;
  prevSubtotal?: number | string | null;
  deliveryFee?: number | string | null;
}

export interface RecalculatedOrderTotals {
  discountAmount: number;
  taxAmount: number;
  grandTotal: number;
}

export function round(val: number): number {
  return Math.round((val + Number.EPSILON) * 100) / 100;
}

/**
 * Recalculates discountAmount, taxAmount, and grandTotal given active items subtotal
 * and existing order financial parameters.
 */
export function recalculateOrderTotals(
  params: RecalculateOrderTotalsInput,
): RecalculatedOrderTotals;
export function recalculateOrderTotals(
  subtotal: number,
  discountPercentage?: number | string | null,
  discountAmount?: number | string | null,
  taxAmount?: number | string | null,
  prevSubtotal?: number | string | null,
  deliveryFee?: number | string | null,
): RecalculatedOrderTotals;
export function recalculateOrderTotals(
  subtotalOrParams: number | RecalculateOrderTotalsInput,
  argDiscountPercentage?: number | string | null,
  argDiscountAmount?: number | string | null,
  argTaxAmount?: number | string | null,
  argPrevSubtotal?: number | string | null,
  argDeliveryFee?: number | string | null,
): RecalculatedOrderTotals {
  let subtotal: number;
  let discountPercentage: number | string | null | undefined;
  let discountAmount: number | string | null | undefined;
  let taxAmount: number | string | null | undefined;
  let prevSubtotal: number | string | null | undefined;
  let deliveryFee: number | string | null | undefined;

  if (typeof subtotalOrParams === 'object' && subtotalOrParams !== null) {
    subtotal = subtotalOrParams.subtotal;
    discountPercentage = subtotalOrParams.discountPercentage;
    discountAmount = subtotalOrParams.discountAmount;
    taxAmount = subtotalOrParams.taxAmount;
    prevSubtotal = subtotalOrParams.prevSubtotal;
    deliveryFee = subtotalOrParams.deliveryFee;
  } else {
    subtotal = subtotalOrParams;
    discountPercentage = argDiscountPercentage;
    discountAmount = argDiscountAmount;
    taxAmount = argTaxAmount;
    prevSubtotal = argPrevSubtotal;
    deliveryFee = argDeliveryFee;
  }

  const sub = Number(subtotal) || 0;
  const discPct = Number(discountPercentage || 0);
  const calculatedDiscount =
    discPct > 0
      ? round((sub * discPct) / 100)
      : Number(discountAmount || 0);

  const taxableAmount = Math.max(0, sub - calculatedDiscount);

  const currentTax = Number(taxAmount || 0);
  const prevSub = Number(prevSubtotal) || 1;
  const taxRate = prevSub > 0 ? currentTax / prevSub : 0;
  const recalculatedTax = round(taxableAmount * taxRate);

  const fee = Number(deliveryFee || 0);
  const grandTotal = round(taxableAmount + recalculatedTax + fee);

  return {
    discountAmount: calculatedDiscount,
    taxAmount: recalculatedTax,
    grandTotal,
  };
}
