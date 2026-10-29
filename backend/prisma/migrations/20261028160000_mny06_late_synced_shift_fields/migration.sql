-- AlterTable
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "late_synced_cash_total" DECIMAL(12,2) NOT NULL DEFAULT 0.00;
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "late_synced_order_count" INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "is_late_synced" BOOLEAN NOT NULL DEFAULT false;
