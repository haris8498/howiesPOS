-- AlterTable
ALTER TABLE "daily_calculations" ADD COLUMN IF NOT EXISTS "cash_refunds_total" DECIMAL(12,2) NOT NULL DEFAULT 0.00;
