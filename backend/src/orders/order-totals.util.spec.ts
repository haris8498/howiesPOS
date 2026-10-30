import {
  recalculateOrderTotals,
  round,
  RecalculateOrderTotalsInput,
} from './order-totals.util';

/**
 * Formula directly transcribed from OrdersService.cancelOrderItem (orders.service.ts ~L1638-1650).
 * Used as the gold standard parity reference in this spec to guard against drifting.
 */
function cancelOrderItemFormula(
  order: {
    discount_percentage?: number | string | null;
    tax_amount?: number | string | null;
    subtotal: number | string;
    online_detail?: { delivery_fee?: number | string | null } | null;
  },
  activeItemsSubtotal: number,
) {
  const roundLocal = (val: number): number =>
    Math.round((val + Number.EPSILON) * 100) / 100;

  const subtotal = roundLocal(activeItemsSubtotal);
  const discountPercentage = Number(order.discount_percentage || 0);
  const discountAmount = roundLocal((subtotal * discountPercentage) / 100);
  const taxableAmount = Math.max(0, subtotal - discountAmount);

  const currentTax = Number(order.tax_amount || 0);
  const prevSubtotal = Number(order.subtotal) || 1;
  const taxRate = prevSubtotal > 0 ? currentTax / prevSubtotal : 0;
  const newTax = roundLocal(taxableAmount * taxRate);

  const deliveryFee = Number(order.online_detail?.delivery_fee || 0);
  const grandTotal = roundLocal(taxableAmount + newTax + deliveryFee);

  return {
    discountAmount,
    taxAmount: newTax,
    grandTotal,
  };
}

describe('order-totals.util', () => {
  describe('Parity with OrdersService.cancelOrderItem formula', () => {
    it('matches cancelOrderItem formula for 1 of 2 items cancelled', () => {
      // Order with 2 items @ $20.00 each = $40.00 subtotal, 10% discount, 5% tax ($1.80), $5.00 delivery fee
      const unitPrice = 20.0;
      const initialQty = 2;
      const initialSubtotal = unitPrice * initialQty; // 40.00
      const order = {
        subtotal: initialSubtotal,
        discount_percentage: 10,
        tax_amount: 1.8,
        online_detail: { delivery_fee: 5.0 },
      };

      // 1 item cancelled, 1 remaining active
      const remainingQty = 1;
      const activeSubtotal = unitPrice * remainingQty; // 20.00

      const expected = cancelOrderItemFormula(order, activeSubtotal);
      const actual = recalculateOrderTotals({
        subtotal: activeSubtotal,
        discountPercentage: order.discount_percentage,
        taxAmount: order.tax_amount,
        prevSubtotal: order.subtotal,
        deliveryFee: order.online_detail.delivery_fee,
      });

      expect(actual).toEqual(expected);
      expect(actual).toEqual({
        discountAmount: 2.0,
        taxAmount: 0.81,
        grandTotal: 23.81,
      });
    });

    it('matches cancelOrderItem formula for 1 of 3 items cancelled', () => {
      // Order with 3 items @ $15.50 each = $46.50 subtotal, 15% discount, 8% tax ($3.16), no delivery fee
      const unitPrice = 15.5;
      const initialQty = 3;
      const initialSubtotal = round(unitPrice * initialQty); // 46.50
      const order = {
        subtotal: initialSubtotal,
        discount_percentage: 15,
        tax_amount: 3.16,
        online_detail: null,
      };

      // 1 item cancelled, 2 remaining active
      const remainingQty = 2;
      const activeSubtotal = round(unitPrice * remainingQty); // 31.00

      const expected = cancelOrderItemFormula(order, activeSubtotal);
      const actual = recalculateOrderTotals({
        subtotal: activeSubtotal,
        discountPercentage: order.discount_percentage,
        taxAmount: order.tax_amount,
        prevSubtotal: order.subtotal,
        deliveryFee: 0,
      });

      expect(actual).toEqual(expected);
    });

    it('matches cancelOrderItem formula for 2 of 5 items cancelled', () => {
      // Order with 5 items @ $12.30 each = $61.50 subtotal, 20% discount, 6% tax ($2.95), $3.50 delivery fee
      const unitPrice = 12.3;
      const initialQty = 5;
      const initialSubtotal = round(unitPrice * initialQty); // 61.50
      const order = {
        subtotal: initialSubtotal,
        discount_percentage: 20,
        tax_amount: 2.95,
        online_detail: { delivery_fee: 3.5 },
      };

      // 2 items cancelled, 3 remaining active
      const remainingQty = 3;
      const activeSubtotal = round(unitPrice * remainingQty); // 36.90

      const expected = cancelOrderItemFormula(order, activeSubtotal);
      const actual = recalculateOrderTotals({
        subtotal: activeSubtotal,
        discountPercentage: order.discount_percentage,
        taxAmount: order.tax_amount,
        prevSubtotal: order.subtotal,
        deliveryFee: order.online_detail.delivery_fee,
      });

      expect(actual).toEqual(expected);
    });

    it('matches cancelOrderItem formula for full quantity cancelled (all items voided)', () => {
      // Order with 2 items @ $25.00 each = $50.00 subtotal, 10% discount, tax $4.50, $4.00 delivery fee
      const unitPrice = 25.0;
      const initialQty = 2;
      const initialSubtotal = unitPrice * initialQty; // 50.00
      const order = {
        subtotal: initialSubtotal,
        discount_percentage: 10,
        tax_amount: 4.5,
        online_detail: { delivery_fee: 4.0 },
      };

      // All items cancelled => 0 active items
      const activeSubtotal = 0;

      const expected = cancelOrderItemFormula(order, activeSubtotal);
      const actual = recalculateOrderTotals({
        subtotal: activeSubtotal,
        discountPercentage: order.discount_percentage,
        taxAmount: order.tax_amount,
        prevSubtotal: order.subtotal,
        deliveryFee: order.online_detail.delivery_fee,
      });

      expect(actual).toEqual(expected);
      expect(actual).toEqual({
        discountAmount: 0,
        taxAmount: 0,
        grandTotal: 4.0, // delivery fee preserved as per orders.service cancelOrderItem
      });
    });
  });

  describe('Edge cases and signature flexibility', () => {
    it('preserves flat discount_amount when discount_percentage is 0', () => {
      const result = recalculateOrderTotals({
        subtotal: 50,
        discountPercentage: 0,
        discountAmount: 10,
        taxAmount: 4,
        prevSubtotal: 80,
        deliveryFee: 0,
      });

      expect(result.discountAmount).toBe(10);
      expect(result.taxAmount).toBe(round(40 * (4 / 80))); // 40 * 0.05 = 2.0
      expect(result.grandTotal).toBe(42);
    });

    it('clamps taxable amount to 0 when discount exceeds subtotal', () => {
      const result = recalculateOrderTotals({
        subtotal: 20,
        discountPercentage: 0,
        discountAmount: 30,
        taxAmount: 5,
        prevSubtotal: 50,
        deliveryFee: 2,
      });

      expect(result.discountAmount).toBe(30);
      expect(result.taxAmount).toBe(0);
      expect(result.grandTotal).toBe(2); // 0 + 0 + 2 delivery fee
    });

    it('supports positional arguments identically to object arguments', () => {
      const fromObj = recalculateOrderTotals({
        subtotal: 100,
        discountPercentage: 10,
        discountAmount: 0,
        taxAmount: 9,
        prevSubtotal: 150,
        deliveryFee: 5,
      });

      const fromPos = recalculateOrderTotals(100, 10, 0, 9, 150, 5);

      expect(fromPos).toEqual(fromObj);
    });

    it('safely handles missing/zero prevSubtotal without division by zero', () => {
      const result = recalculateOrderTotals({
        subtotal: 50,
        discountPercentage: 0,
        discountAmount: 0,
        taxAmount: 0,
        prevSubtotal: 0,
        deliveryFee: 0,
      });

      expect(result.taxAmount).toBe(0);
      expect(result.grandTotal).toBe(50);
    });
  });
});
