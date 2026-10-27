-- Migration: 20261027160000_table_seating_overflow
-- Description: Add virtual overflow table support (is_overflow, parent_table_id, overflow_suffix) to restaurant_tables

-- 1. Add additive columns to restaurant_tables
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "is_overflow" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "parent_table_id" VARCHAR(36);
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "overflow_suffix" VARCHAR(10);

-- Backfill any existing NULLs to false
UPDATE "restaurant_tables" SET "is_overflow" = false WHERE "is_overflow" IS NULL;

-- 2. Foreign key for self-relation
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'restaurant_tables_parent_table_id_fkey'
  ) THEN
    ALTER TABLE "restaurant_tables"
    ADD CONSTRAINT "restaurant_tables_parent_table_id_fkey"
    FOREIGN KEY ("parent_table_id") REFERENCES "restaurant_tables"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

-- 3. Indexes for overflow queries
CREATE INDEX IF NOT EXISTS "restaurant_tables_parent_table_id_idx" ON "restaurant_tables" ("parent_table_id");
CREATE INDEX IF NOT EXISTS "restaurant_tables_is_overflow_idx" ON "restaurant_tables" ("is_overflow");
