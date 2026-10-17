-- CreateTable
CREATE TABLE "store_settings" (
    "id" VARCHAR(36) NOT NULL,
    "chain_name" VARCHAR(100) NOT NULL DEFAULT 'Hungry Howie''s',
    "branch_code" VARCHAR(50) NOT NULL DEFAULT 'Branch #402',
    "branch_name" VARCHAR(100) NOT NULL DEFAULT 'Metro Central Outlet',
    "store_phone" VARCHAR(30) NOT NULL,
    "sales_tax_rate" DECIMAL(5,2) NOT NULL DEFAULT 8.50,
    "dine_in_service_charge_rate" DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    "updated_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "store_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_users" (
    "id" VARCHAR(36) NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "email" VARCHAR(100) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" VARCHAR(20) NOT NULL,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "last_updated" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_by" VARCHAR(50) NOT NULL DEFAULT 'Super Admin',

    CONSTRAINT "staff_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "id" VARCHAR(50) NOT NULL,
    "role" VARCHAR(20) NOT NULL,
    "module_name" VARCHAR(50) NOT NULL,
    "action_name" VARCHAR(100) NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "is_granted" BOOLEAN NOT NULL DEFAULT false,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_members" (
    "id" VARCHAR(36) NOT NULL,
    "user_id" VARCHAR(36),
    "full_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(30) NOT NULL,
    "role" VARCHAR(20) NOT NULL,
    "status" VARCHAR(30) NOT NULL DEFAULT 'Active',
    "joining_date" DATE NOT NULL,
    "assigned_shift" VARCHAR(50) NOT NULL DEFAULT 'Morning Shift',
    "monthly_salary" DECIMAL(10,2) NOT NULL DEFAULT 65000.00,
    "hourly_rate" DECIMAL(10,2) NOT NULL DEFAULT 406.00,
    "allowance" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "deductions" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "is_clocked_in" BOOLEAN NOT NULL DEFAULT false,
    "clock_in_time" TIMESTAMP,
    "is_salary_paid" BOOLEAN NOT NULL DEFAULT false,
    "salary_paid_date" TIMESTAMP,

    CONSTRAINT "staff_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" VARCHAR(36) NOT NULL,
    "full_name" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(30) NOT NULL,
    "email" VARCHAR(100) NOT NULL DEFAULT '',
    "address" TEXT NOT NULL DEFAULT '',
    "birth_date" DATE,
    "loyalty_points" INTEGER NOT NULL DEFAULT 0,
    "total_orders_count" INTEGER NOT NULL DEFAULT 0,
    "total_spent" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "special_notes" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "restaurant_tables" (
    "id" VARCHAR(36) NOT NULL,
    "table_number" VARCHAR(20) NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "capacity" INTEGER NOT NULL DEFAULT 4,
    "section" VARCHAR(50) NOT NULL DEFAULT 'Hall',
    "status" VARCHAR(20) NOT NULL DEFAULT 'available',
    "current_customer_count" INTEGER NOT NULL DEFAULT 0,
    "current_bill_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "occupied_since" TIMESTAMP,
    "active_order_id" VARCHAR(36),
    "reserved_customer_name" VARCHAR(100),
    "reservation_time" TIMESTAMP,

    CONSTRAINT "restaurant_tables_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_categories" (
    "id" VARCHAR(36) NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "badge_text" VARCHAR(30) NOT NULL DEFAULT 'Category',
    "image_path" VARCHAR(255) NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "icon_name" VARCHAR(50) NOT NULL DEFAULT 'fastfood',

    CONSTRAINT "menu_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_items" (
    "id" VARCHAR(36) NOT NULL,
    "category_id" VARCHAR(36) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "base_price" DECIMAL(10,2) NOT NULL,
    "image_url" VARCHAR(255) NOT NULL DEFAULT '',
    "is_veg" BOOLEAN NOT NULL DEFAULT false,
    "is_spicy" BOOLEAN NOT NULL DEFAULT false,
    "is_available" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "menu_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_item_sizes" (
    "id" VARCHAR(36) NOT NULL,
    "menu_item_id" VARCHAR(36) NOT NULL,
    "size_name" VARCHAR(30) NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,

    CONSTRAINT "menu_item_sizes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "menu_item_options" (
    "id" VARCHAR(36) NOT NULL,
    "menu_item_id" VARCHAR(36) NOT NULL,
    "option_type" VARCHAR(30) NOT NULL,
    "option_name" VARCHAR(50) NOT NULL,
    "additional_price" DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    CONSTRAINT "menu_item_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deals" (
    "id" VARCHAR(36) NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "subtitle" VARCHAR(150) NOT NULL DEFAULT '',
    "deal_price" DECIMAL(10,2) NOT NULL,
    "original_price" DECIMAL(10,2),
    "badge_text" VARCHAR(30) NOT NULL DEFAULT 'EXCLUSIVE DEAL',
    "image_path" VARCHAR(255) NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "is_available" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "deals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deal_components" (
    "id" VARCHAR(36) NOT NULL,
    "deal_id" VARCHAR(36) NOT NULL,
    "item_name" VARCHAR(100) NOT NULL,
    "category" VARCHAR(50) NOT NULL,
    "quantity" VARCHAR(20) NOT NULL DEFAULT '1x',

    CONSTRAINT "deal_components_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" VARCHAR(36) NOT NULL,
    "order_number" VARCHAR(30) NOT NULL,
    "token_number" VARCHAR(20),
    "order_type" VARCHAR(20) NOT NULL,
    "order_source" VARCHAR(30) NOT NULL DEFAULT 'Direct POS',
    "status" VARCHAR(30) NOT NULL DEFAULT 'newOrder',
    "table_id" VARCHAR(36),
    "guest_count" INTEGER NOT NULL DEFAULT 1,
    "waiter_name" VARCHAR(50) NOT NULL DEFAULT 'Cashier',
    "customer_id" VARCHAR(36),
    "customer_name" VARCHAR(100),
    "customer_phone" VARCHAR(30),
    "delivery_address" TEXT,
    "subtotal" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "discount_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "tax_percentage" DECIMAL(5,2) NOT NULL DEFAULT 8.50,
    "tax_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "service_charge_percentage" DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    "service_charge_amount" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "delivery_fee" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "grand_total" DECIMAL(10,2) NOT NULL,
    "payment_status" VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    "payment_method" VARCHAR(30),
    "is_paid" BOOLEAN NOT NULL DEFAULT false,
    "is_held" BOOLEAN NOT NULL DEFAULT false,
    "kitchen_ticket_sent" BOOLEAN NOT NULL DEFAULT false,
    "kitchen_note" TEXT,
    "rejection_reason" TEXT,
    "cooking_time_minutes" INTEGER,
    "estimated_ready_at" TIMESTAMP,
    "created_at" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "menu_item_id" VARCHAR(36),
    "item_name" VARCHAR(100) NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "selected_size" VARCHAR(30) NOT NULL DEFAULT 'Regular',
    "selected_crust" VARCHAR(50) NOT NULL DEFAULT 'Original',
    "extra_toppings" TEXT NOT NULL DEFAULT '',
    "unit_price" DECIMAL(10,2) NOT NULL,
    "total_price" DECIMAL(10,2) NOT NULL,
    "notes" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_riders" (
    "id" VARCHAR(36) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(30) NOT NULL,
    "is_available" BOOLEAN NOT NULL DEFAULT true,
    "is_clocked_in" BOOLEAN NOT NULL DEFAULT true,
    "active_deliveries_count" INTEGER NOT NULL DEFAULT 0,
    "total_completed_deliveries" INTEGER NOT NULL DEFAULT 0,
    "avg_delivery_time_mins" DECIMAL(5,2) NOT NULL DEFAULT 22.50,
    "rating" DECIMAL(3,2) NOT NULL DEFAULT 5.00,

    CONSTRAINT "delivery_riders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_zones" (
    "id" VARCHAR(36) NOT NULL,
    "zone_name" VARCHAR(100) NOT NULL,
    "delivery_fee" DECIMAL(10,2) NOT NULL DEFAULT 150.00,
    "estimated_time_mins" INTEGER NOT NULL DEFAULT 30,

    CONSTRAINT "delivery_zones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_dispatches" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "rider_id" VARCHAR(36),
    "zone_id" VARCHAR(36),
    "dispatch_status" VARCHAR(30) NOT NULL DEFAULT 'pending',
    "estimated_delivery_time" TIMESTAMP NOT NULL,
    "dispatched_at" TIMESTAMP,
    "delivered_at" TIMESTAMP,

    CONSTRAINT "delivery_dispatches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_items" (
    "id" VARCHAR(36) NOT NULL,
    "sku_code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "category" VARCHAR(50) NOT NULL DEFAULT 'General',
    "initial_stock" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "used_stock" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "current_stock" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "min_threshold" DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    "unit" VARCHAR(20) NOT NULL DEFAULT 'kg',
    "cost_per_unit" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "supplier_name" VARCHAR(100) NOT NULL DEFAULT 'Central Depot',
    "last_restocked_date" TIMESTAMP,

    CONSTRAINT "inventory_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_movements" (
    "id" VARCHAR(36) NOT NULL,
    "item_id" VARCHAR(36) NOT NULL,
    "item_name" VARCHAR(100) NOT NULL,
    "movement_type" VARCHAR(30) NOT NULL,
    "quantity" DECIMAL(10,2) NOT NULL,
    "unit" VARCHAR(20) NOT NULL,
    "reason" VARCHAR(255) NOT NULL,
    "timestamp" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "cost_impact" DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" VARCHAR(36) NOT NULL,
    "title" VARCHAR(150) NOT NULL,
    "category" VARCHAR(50) NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "date" DATE NOT NULL,
    "recorded_by" VARCHAR(100) NOT NULL DEFAULT 'Store Manager',
    "note" TEXT NOT NULL DEFAULT '',

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "staff_users_username_key" ON "staff_users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "staff_members_user_id_key" ON "staff_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "customers_phone_key" ON "customers"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "restaurant_tables_table_number_key" ON "restaurant_tables"("table_number");

-- CreateIndex
CREATE UNIQUE INDEX "orders_order_number_key" ON "orders"("order_number");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_riders_phone_key" ON "delivery_riders"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_zones_zone_name_key" ON "delivery_zones"("zone_name");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_dispatches_order_id_key" ON "delivery_dispatches"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_items_sku_code_key" ON "inventory_items"("sku_code");

-- AddForeignKey
ALTER TABLE "staff_members" ADD CONSTRAINT "staff_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "staff_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_items" ADD CONSTRAINT "menu_items_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "menu_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_item_sizes" ADD CONSTRAINT "menu_item_sizes_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "menu_item_options" ADD CONSTRAINT "menu_item_options_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "deal_components" ADD CONSTRAINT "deal_components_deal_id_fkey" FOREIGN KEY ("deal_id") REFERENCES "deals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_table_id_fkey" FOREIGN KEY ("table_id") REFERENCES "restaurant_tables"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_rider_id_fkey" FOREIGN KEY ("rider_id") REFERENCES "delivery_riders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_zone_id_fkey" FOREIGN KEY ("zone_id") REFERENCES "delivery_zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "inventory_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
