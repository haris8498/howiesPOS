-- Migration: 20261027140000_soft_delete_dining_tables
-- Description: Add soft delete columns (is_deleted, deleted_at, deleted_by) to restaurant_tables, and replace global table_number unique constraint with partial unique index where is_deleted = false.

-- 1. Add soft-delete columns if missing
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "is_deleted" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP;
ALTER TABLE "restaurant_tables" ADD COLUMN IF NOT EXISTS "deleted_by" VARCHAR(100);

-- Backfill any existing NULLs to false
UPDATE "restaurant_tables" SET "is_deleted" = false WHERE "is_deleted" IS NULL;

-- 2. Drop existing global unique index/constraint on table_number
ALTER TABLE "restaurant_tables" DROP CONSTRAINT IF EXISTS "restaurant_tables_table_number_key";
DROP INDEX IF EXISTS "restaurant_tables_table_number_key";

-- 3. Create partial unique index allowing table_number reuse after soft delete
CREATE UNIQUE INDEX IF NOT EXISTS "restaurant_tables_table_number_active_key"
ON "restaurant_tables" ("table_number")
WHERE "is_deleted" = false;

-- 4. Create index on is_deleted for query performance
CREATE INDEX IF NOT EXISTS "restaurant_tables_is_deleted_idx"
ON "restaurant_tables" ("is_deleted");
