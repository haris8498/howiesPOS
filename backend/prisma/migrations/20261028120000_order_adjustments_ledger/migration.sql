-- Migration: 20261028120000_order_adjustments_ledger
-- Description: Supervisor-authorized refund/void adjustments audit ledger per #13 follow-up

-- 1. Create order_adjustments table
CREATE TABLE IF NOT EXISTS "order_adjustments" (
  "id" VARCHAR(36) NOT NULL,
  "order_id" VARCHAR(36) NOT NULL,
  "type" VARCHAR(30) NOT NULL DEFAULT 'REFUND',
  "amount" DECIMAL(10, 2) NOT NULL,
  "reason" TEXT NOT NULL,
  "refund_method" VARCHAR(30) NOT NULL,
  "supervisor_id" VARCHAR(36) NOT NULL,
  "cashier_id" VARCHAR(36),
  "device_id" VARCHAR(50),
  "shift_id" VARCHAR(36),
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "order_adjustments_pkey" PRIMARY KEY ("id")
);

-- 2. Foreign key for order_adjustments
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'order_adjustments_order_id_fkey'
  ) THEN
    ALTER TABLE "order_adjustments"
    ADD CONSTRAINT "order_adjustments_order_id_fkey"
    FOREIGN KEY ("order_id") REFERENCES "orders"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- 3. Indexes for order_adjustments
CREATE INDEX IF NOT EXISTS "order_adjustments_order_id_idx" ON "order_adjustments" ("order_id");
CREATE INDEX IF NOT EXISTS "order_adjustments_supervisor_id_idx" ON "order_adjustments" ("supervisor_id");
CREATE INDEX IF NOT EXISTS "order_adjustments_shift_id_idx" ON "order_adjustments" ("shift_id");
