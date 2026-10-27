-- Migration: 20261027150000_order_line_item_ledger
-- Description: Additive migration for append-only order line-item ledger (SYNC-032 / D-05)

-- 1. Add ledger columns to order_items
ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "voided_at" TIMESTAMP;
ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "voided_by" VARCHAR(50);
ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "supersedes_item_id" VARCHAR(36);
ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "created_by_device_id" VARCHAR(50);
ALTER TABLE "order_items" ADD COLUMN IF NOT EXISTS "client_created_at" TIMESTAMP;

-- 2. Backfill existing cancelled items: set voided_at = cancelled_at where is_cancelled = true and voided_at is NULL
UPDATE "order_items"
SET "voided_at" = COALESCE("cancelled_at", NOW()),
    "voided_by" = "cancelled_by"
WHERE "is_cancelled" = true AND "voided_at" IS NULL;

-- 3. Create indexes for efficient ledger queries and supersedes traversal
CREATE INDEX IF NOT EXISTS "order_items_order_id_idx" ON "order_items" ("order_id");
CREATE INDEX IF NOT EXISTS "order_items_voided_at_idx" ON "order_items" ("voided_at");
CREATE INDEX IF NOT EXISTS "order_items_supersedes_item_id_idx" ON "order_items" ("supersedes_item_id");
