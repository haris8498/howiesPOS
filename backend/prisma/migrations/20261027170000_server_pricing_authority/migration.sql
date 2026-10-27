-- Migration: 20261027170000_server_pricing_authority
-- Description: Server-authoritative pricing fields (pricing_status, client_reported_total, approved_by_manager_id) and immutable audit tables (discount_audits, pricing_audits) per D-03 / SYNC-016 / BCK-02

-- 1. Add pricing authority columns to orders table
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "pricing_status" VARCHAR(30) NOT NULL DEFAULT 'VERIFIED';
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "client_reported_total" DECIMAL(10, 2);
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "approved_by_manager_id" VARCHAR(36);

-- Backfill NULL pricing_status
UPDATE "orders" SET "pricing_status" = 'VERIFIED' WHERE "pricing_status" IS NULL;

-- 2. Create discount_audits table (immutable manager approval log)
CREATE TABLE IF NOT EXISTS "discount_audits" (
  "id" VARCHAR(36) NOT NULL,
  "order_id" VARCHAR(36) NOT NULL,
  "amount" DECIMAL(10, 2) NOT NULL,
  "percent" DECIMAL(5, 2),
  "discount_type" VARCHAR(30) NOT NULL DEFAULT 'PERCENTAGE',
  "reason" TEXT,
  "cashier_id" VARCHAR(36),
  "approved_by" VARCHAR(36) NOT NULL,
  "device_id" VARCHAR(50),
  "source" VARCHAR(20) NOT NULL DEFAULT 'ONLINE',
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "discount_audits_pkey" PRIMARY KEY ("id")
);

-- Foreign key for discount_audits
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'discount_audits_order_id_fkey'
  ) THEN
    ALTER TABLE "discount_audits"
    ADD CONSTRAINT "discount_audits_order_id_fkey"
    FOREIGN KEY ("order_id") REFERENCES "orders"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- Indexes for discount_audits
CREATE INDEX IF NOT EXISTS "discount_audits_order_id_idx" ON "discount_audits" ("order_id");
CREATE INDEX IF NOT EXISTS "discount_audits_approved_by_idx" ON "discount_audits" ("approved_by");

-- 3. Create pricing_audits table (price discrepancy and mismatch log)
CREATE TABLE IF NOT EXISTS "pricing_audits" (
  "id" VARCHAR(36) NOT NULL,
  "order_id" VARCHAR(36) NOT NULL,
  "client_grand_total" DECIMAL(10, 2) NOT NULL,
  "server_grand_total" DECIMAL(10, 2) NOT NULL,
  "client_subtotal" DECIMAL(10, 2),
  "server_subtotal" DECIMAL(10, 2),
  "tolerance" DECIMAL(10, 2) NOT NULL,
  "difference" DECIMAL(10, 2) NOT NULL,
  "pricing_status" VARCHAR(30) NOT NULL,
  "line_discrepancies" JSONB,
  "source" VARCHAR(20) NOT NULL DEFAULT 'OFFLINE',
  "device_id" VARCHAR(50),
  "notes" TEXT,
  "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "pricing_audits_pkey" PRIMARY KEY ("id")
);

-- Foreign key for pricing_audits
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pricing_audits_order_id_fkey'
  ) THEN
    ALTER TABLE "pricing_audits"
    ADD CONSTRAINT "pricing_audits_order_id_fkey"
    FOREIGN KEY ("order_id") REFERENCES "orders"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

-- Indexes for pricing_audits
CREATE INDEX IF NOT EXISTS "pricing_audits_order_id_idx" ON "pricing_audits" ("order_id");
CREATE INDEX IF NOT EXISTS "pricing_audits_pricing_status_idx" ON "pricing_audits" ("pricing_status");
