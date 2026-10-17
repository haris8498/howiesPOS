-- DropForeignKey
ALTER TABLE "delivery_dispatches" DROP CONSTRAINT "delivery_dispatches_order_id_fkey";

-- DropForeignKey
ALTER TABLE "orders" DROP CONSTRAINT "orders_customer_id_fkey";

-- DropForeignKey
ALTER TABLE "orders" DROP CONSTRAINT "orders_table_id_fkey";

-- DropIndex
DROP INDEX "delivery_dispatches_order_id_key";

-- AlterTable
ALTER TABLE "delivery_dispatches" DROP COLUMN "order_id",
ADD COLUMN     "online_order_detail_id" VARCHAR(36) NOT NULL;

-- AlterTable
ALTER TABLE "orders" DROP COLUMN "customer_id",
DROP COLUMN "customer_name",
DROP COLUMN "customer_phone",
DROP COLUMN "delivery_address",
DROP COLUMN "delivery_fee",
DROP COLUMN "guest_count",
DROP COLUMN "order_source",
DROP COLUMN "payment_method",
DROP COLUMN "table_id",
DROP COLUMN "token_number",
DROP COLUMN "waiter_name",
ADD COLUMN     "discount_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
ADD COLUMN     "tax_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00;

-- CreateTable
CREATE TABLE "online_order_details" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "order_source" VARCHAR(30) NOT NULL DEFAULT 'POS',
    "customer_id" VARCHAR(36),
    "customer_name" VARCHAR(100) NOT NULL,
    "customer_phone" VARCHAR(30) NOT NULL,
    "delivery_address" TEXT NOT NULL,
    "delivery_fee" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "estimated_delivery_at" TIMESTAMP,
    "platform_order_ref" VARCHAR(100),
    "special_instructions" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "online_order_details_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "takeaway_order_details" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "token_number" VARCHAR(20) NOT NULL,
    "customer_id" VARCHAR(36),
    "customer_name" VARCHAR(100) NOT NULL DEFAULT 'Walk-in Customer',
    "customer_phone" VARCHAR(30) NOT NULL DEFAULT '',
    "pickup_notes" TEXT NOT NULL DEFAULT '',
    "served_by" VARCHAR(50) NOT NULL DEFAULT 'Cashier',

    CONSTRAINT "takeaway_order_details_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dine_in_order_details" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "table_id" VARCHAR(36) NOT NULL,
    "guest_count" INTEGER NOT NULL DEFAULT 1,
    "waiter_name" VARCHAR(50) NOT NULL DEFAULT 'Cashier',
    "seating_notes" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "dine_in_order_details_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "online_order_details_order_id_key" ON "online_order_details"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "takeaway_order_details_order_id_key" ON "takeaway_order_details"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "takeaway_order_details_token_number_key" ON "takeaway_order_details"("token_number");

-- CreateIndex
CREATE UNIQUE INDEX "dine_in_order_details_order_id_key" ON "dine_in_order_details"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_dispatches_online_order_detail_id_key" ON "delivery_dispatches"("online_order_detail_id");

-- AddForeignKey
ALTER TABLE "online_order_details" ADD CONSTRAINT "online_order_details_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "online_order_details" ADD CONSTRAINT "online_order_details_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "takeaway_order_details" ADD CONSTRAINT "takeaway_order_details_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "takeaway_order_details" ADD CONSTRAINT "takeaway_order_details_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dine_in_order_details" ADD CONSTRAINT "dine_in_order_details_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dine_in_order_details" ADD CONSTRAINT "dine_in_order_details_table_id_fkey" FOREIGN KEY ("table_id") REFERENCES "restaurant_tables"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_online_order_detail_id_fkey" FOREIGN KEY ("online_order_detail_id") REFERENCES "online_order_details"("id") ON DELETE CASCADE ON UPDATE CASCADE;

