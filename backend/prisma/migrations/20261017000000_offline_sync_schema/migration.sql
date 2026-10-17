-- AlterTable
ALTER TABLE "customers" ADD COLUMN     "deleted_at" TIMESTAMP,
ADD COLUMN     "is_deleted" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "restaurant_tables" ADD COLUMN     "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "version" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "menu_items" ADD COLUMN     "deleted_at" TIMESTAMP,
ADD COLUMN     "is_deleted" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "version" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "daily_calculations" ADD COLUMN     "cash_variance" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
ADD COLUMN     "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "variance_reason" VARCHAR(255),
ADD COLUMN     "version" INTEGER NOT NULL DEFAULT 1;

-- CreateTable
CREATE TABLE "processed_operations" (
    "operation_id" VARCHAR(36) NOT NULL,
    "device_id" VARCHAR(50) NOT NULL,
    "entity_type" VARCHAR(50) NOT NULL,
    "entity_id" VARCHAR(36) NOT NULL,
    "request_hash" VARCHAR(64) NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'PROCESSING',
    "response_payload" JSONB,
    "http_status" INTEGER NOT NULL DEFAULT 200,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP,

    CONSTRAINT "processed_operations_pkey" PRIMARY KEY ("operation_id")
);

-- CreateTable
CREATE TABLE "system_change_logs" (
    "global_sequence" BIGSERIAL NOT NULL,
    "entity_type" VARCHAR(50) NOT NULL,
    "entity_id" VARCHAR(36) NOT NULL,
    "operation" VARCHAR(20) NOT NULL,
    "record_version" INTEGER NOT NULL DEFAULT 1,
    "is_deleted" BOOLEAN NOT NULL DEFAULT false,
    "payload" JSONB NOT NULL,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "system_change_logs_pkey" PRIMARY KEY ("global_sequence")
);

-- CreateIndex
CREATE INDEX "processed_operations_device_id_created_at_idx" ON "processed_operations"("device_id", "created_at");

-- CreateIndex
CREATE INDEX "processed_operations_entity_type_entity_id_idx" ON "processed_operations"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "system_change_logs_global_sequence_idx" ON "system_change_logs"("global_sequence");

-- CreateIndex
CREATE INDEX "system_change_logs_entity_type_entity_id_idx" ON "system_change_logs"("entity_type", "entity_id");
