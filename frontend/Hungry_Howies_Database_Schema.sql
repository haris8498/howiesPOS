-- ===========================================================================
-- HUNGRY HOWIE'S RESTAURANT MANAGEMENT & POS SYSTEM
-- Complete Implementation-Ready PostgreSQL DDL Script
-- Tables: 25 | Architecture: 3NF Normalized Single-Branch POS
-- Source of Truth: DATABASE_ARCHITECTURE.md
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. EXTENSIONS & CUSTOM ENUM TYPES
-- ---------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE order_type_enum AS ENUM (
    'DINE_IN',
    'TAKEAWAY',
    'DELIVERY',
    'ONLINE'
);

CREATE TYPE order_status_enum AS ENUM (
    'PENDING',
    'PREPARING',
    'READY',
    'DISPATCHED',
    'DELIVERED',
    'COMPLETED',
    'CANCELLED'
);

CREATE TYPE table_status_enum AS ENUM (
    'AVAILABLE',
    'OCCUPIED',
    'RESERVED',
    'DIRTY'
);

CREATE TYPE delivery_status_enum AS ENUM (
    'PENDING',
    'ASSIGNED',
    'PICKED_UP',
    'DELIVERED',
    'CANCELLED'
);

CREATE TYPE payment_status_enum AS ENUM (
    'PAID',
    'UNPAID',
    'REFUNDED',
    'CANCELLED'
);

CREATE TYPE stock_transaction_type_enum AS ENUM (
    'STOCK_IN',
    'STOCK_OUT',
    'WASTAGE',
    'RECIPE_DEDUCTION',
    'RETURN_TO_SUPPLIER'
);

-- ---------------------------------------------------------------------------
-- 2. AUTHENTICATION & ACCESS CONTROL
-- ---------------------------------------------------------------------------

-- Table 1: roles
CREATE TABLE roles (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 2: role_permissions (Powers Manager Rights UI)
CREATE TABLE role_permissions (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    role_id VARCHAR(36) NOT NULL REFERENCES roles(id) ON DELETE CASCADE ON UPDATE CASCADE,
    module_key VARCHAR(50) NOT NULL,
    can_view BOOLEAN NOT NULL DEFAULT TRUE,
    can_create BOOLEAN NOT NULL DEFAULT FALSE,
    can_edit BOOLEAN NOT NULL DEFAULT FALSE,
    can_delete BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_role_module UNIQUE (role_id, module_key)
);

-- Table 3: users
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    role_id VARCHAR(36) NOT NULL REFERENCES roles(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 3. STAFF & PAYROLL
-- ---------------------------------------------------------------------------

-- Table 4: staff
CREATE TABLE staff (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(36) UNIQUE REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    name VARCHAR(100) NOT NULL,
    designation VARCHAR(50) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100),
    monthly_salary DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (monthly_salary >= 0.00),
    hourly_rate DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (hourly_rate >= 0.00),
    is_clocked_in BOOLEAN NOT NULL DEFAULT FALSE,
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 5: payroll_records
CREATE TABLE payroll_records (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    staff_id VARCHAR(36) NOT NULL REFERENCES staff(id) ON DELETE CASCADE ON UPDATE CASCADE,
    payroll_month VARCHAR(7) NOT NULL, -- Format 'YYYY-MM'
    base_salary DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (base_salary >= 0.00),
    allowances DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (allowances >= 0.00),
    deductions DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (deductions >= 0.00),
    net_salary DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'UNPAID',
    paid_at TIMESTAMPTZ,
    payment_method VARCHAR(30),
    notes TEXT,
    CONSTRAINT uq_staff_payroll_month UNIQUE (staff_id, payroll_month)
);

-- ---------------------------------------------------------------------------
-- 4. FLOOR & TABLE MANAGEMENT
-- ---------------------------------------------------------------------------

-- Table 6: restaurant_tables
CREATE TABLE restaurant_tables (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    table_number VARCHAR(20) NOT NULL UNIQUE,
    section VARCHAR(50) NOT NULL DEFAULT 'Hall',
    seating_capacity INT NOT NULL DEFAULT 4 CHECK (seating_capacity > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    active_order_id VARCHAR(36),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 5. MENU CATALOG, VARIANTS & MODIFIERS
-- ---------------------------------------------------------------------------

-- Table 7: categories
CREATE TABLE categories (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(100) NOT NULL UNIQUE,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Table 8: menu_items
CREATE TABLE menu_items (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    category_id VARCHAR(36) NOT NULL REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    base_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (base_price >= 0.00),
    image_url VARCHAR(255),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 9: menu_item_variants (Sizes: Regular, Large, Jumbo)
CREATE TABLE menu_item_variants (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    menu_item_id VARCHAR(36) NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    name VARCHAR(50) NOT NULL,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (price >= 0.00),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_item_variant UNIQUE (menu_item_id, name)
);

-- Table 10: menu_item_modifiers (Crusts, Extra Toppings, Dips, Sauces)
CREATE TABLE menu_item_modifiers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    menu_item_id VARCHAR(36) NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    name VARCHAR(100) NOT NULL,
    modifier_group VARCHAR(50) NOT NULL DEFAULT 'Customization',
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (price >= 0.00),
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- 6. DEALS & PACKAGES
-- ---------------------------------------------------------------------------

-- Table 11: deals
CREATE TABLE deals (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (price >= 0.00),
    included_items JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 7. CUSTOMERS & DELIVERY ADDRESSES
-- ---------------------------------------------------------------------------

-- Table 12: customers
CREATE TABLE customers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 13: customer_addresses
CREATE TABLE customer_addresses (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    customer_id VARCHAR(36) NOT NULL REFERENCES customers(id) ON DELETE CASCADE ON UPDATE CASCADE,
    address_line TEXT NOT NULL,
    city_area VARCHAR(100) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------------------
-- 8. ORDERS, LINE ITEMS & MODIFIERS
-- ---------------------------------------------------------------------------

-- Table 14: orders (Unified Central Order Engine)
CREATE TABLE orders (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_number VARCHAR(30) NOT NULL UNIQUE,
    order_type VARCHAR(20) NOT NULL DEFAULT 'DINE_IN',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    table_id VARCHAR(36) REFERENCES restaurant_tables(id) ON DELETE SET NULL ON UPDATE CASCADE,
    customer_id VARCHAR(36) REFERENCES customers(id) ON DELETE SET NULL ON UPDATE CASCADE,
    cashier_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    token_number INT,
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0.00),
    delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0.00),
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0.00),
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (tax_amount >= 0.00),
    grand_total DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (grand_total >= 0.00),
    cooking_time_minutes INT DEFAULT 25 CHECK (cooking_time_minutes >= 0),
    order_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Table 15: order_items
CREATE TABLE order_items (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id VARCHAR(36) NOT NULL REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    menu_item_id VARCHAR(36) REFERENCES menu_items(id) ON DELETE SET NULL ON UPDATE CASCADE,
    deal_id VARCHAR(36) REFERENCES deals(id) ON DELETE SET NULL ON UPDATE CASCADE,
    item_name VARCHAR(150) NOT NULL,
    size_name VARCHAR(50),
    unit_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (unit_price >= 0.00),
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    total_price DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_price >= 0.00)
);

-- Table 16: order_item_modifiers
CREATE TABLE order_item_modifiers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_item_id VARCHAR(36) NOT NULL REFERENCES order_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    modifier_name VARCHAR(100) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (unit_price >= 0.00),
    quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    total_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (total_price >= 0.00)
);

-- ---------------------------------------------------------------------------
-- 9. DELIVERY & DISPATCH DETAILS
-- ---------------------------------------------------------------------------

-- Table 17: delivery_details (1:1 Extension for Delivery & Dispatch Orders)
CREATE TABLE delivery_details (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id VARCHAR(36) NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
    rider_id VARCHAR(36) REFERENCES staff(id) ON DELETE SET NULL ON UPDATE CASCADE,
    delivery_address TEXT NOT NULL,
    city_zone VARCHAR(100),
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    dispatch_time_minutes INT DEFAULT 30 CHECK (dispatch_time_minutes >= 0),
    assigned_at TIMESTAMPTZ,
    dispatched_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ
);

-- ---------------------------------------------------------------------------
-- 10. PAYMENTS & MULTI-TENDER SETTLEMENT
-- ---------------------------------------------------------------------------

-- Table 18: payments
CREATE TABLE payments (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    order_id VARCHAR(36) NOT NULL REFERENCES orders(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    cashier_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (amount_paid >= 0.00),
    amount_received DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (amount_received >= 0.00),
    return_change DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (return_change >= 0.00),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash',
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PAID',
    transaction_ref VARCHAR(100),
    paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 11. SUPPLIERS, INVENTORY & STOCK TRANSACTIONS
-- ---------------------------------------------------------------------------

-- Table 19: suppliers
CREATE TABLE suppliers (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(150) NOT NULL UNIQUE,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 20: inventory_categories
CREATE TABLE inventory_categories (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name VARCHAR(100) NOT NULL UNIQUE
);

-- Table 21: inventory_items
CREATE TABLE inventory_items (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    category_id VARCHAR(36) NOT NULL REFERENCES inventory_categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    supplier_id VARCHAR(36) REFERENCES suppliers(id) ON DELETE SET NULL ON UPDATE CASCADE,
    name VARCHAR(150) NOT NULL UNIQUE,
    unit VARCHAR(20) NOT NULL DEFAULT 'kg',
    current_stock DECIMAL(12, 3) NOT NULL DEFAULT 0.000,
    min_threshold DECIMAL(12, 3) NOT NULL DEFAULT 5.000 CHECK (min_threshold >= 0.000),
    cost_per_unit DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (cost_per_unit >= 0.00),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table 22: stock_transactions (Audit Movement Ledger)
CREATE TABLE stock_transactions (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    inventory_item_id VARCHAR(36) NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    supplier_id VARCHAR(36) REFERENCES suppliers(id) ON DELETE SET NULL ON UPDATE CASCADE,
    transaction_type VARCHAR(20) NOT NULL,
    quantity DECIMAL(12, 3) NOT NULL,
    cost_per_unit DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (cost_per_unit >= 0.00),
    total_cost DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_cost >= 0.00),
    reference_order_id VARCHAR(36),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 12. RECIPES & BILL OF MATERIALS (BOM)
-- ---------------------------------------------------------------------------

-- Table 23: recipe_ingredients
CREATE TABLE recipe_ingredients (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    menu_item_id VARCHAR(36) NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    inventory_item_id VARCHAR(36) NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    quantity_required DECIMAL(10, 3) NOT NULL CHECK (quantity_required > 0.000),
    CONSTRAINT uq_recipe_ingredient UNIQUE (menu_item_id, inventory_item_id)
);

-- ---------------------------------------------------------------------------
-- 13. OPERATIONAL EXPENSES
-- ---------------------------------------------------------------------------

-- Table 24: expenses
CREATE TABLE expenses (
    id VARCHAR(36) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    category VARCHAR(50) NOT NULL DEFAULT 'General',
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0.00),
    payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash',
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 14. RESTAURANT SETTINGS
-- ---------------------------------------------------------------------------

-- Table 25: restaurant_settings (Singleton Configuration Record)
CREATE TABLE restaurant_settings (
    id VARCHAR(36) PRIMARY KEY DEFAULT 'default',
    restaurant_name VARCHAR(100) NOT NULL DEFAULT 'Hungry Howie''s Pizza',
    phone VARCHAR(20) NOT NULL DEFAULT '+92 300 0000000',
    address TEXT NOT NULL DEFAULT 'Centaurus Mall, Islamabad',
    tax_rate_percent DECIMAL(5, 2) NOT NULL DEFAULT 5.00 CHECK (tax_rate_percent >= 0.00),
    default_delivery_charge DECIMAL(10, 2) NOT NULL DEFAULT 150.00 CHECK (default_delivery_charge >= 0.00),
    receipt_footer_msg TEXT DEFAULT 'Thank you for choosing Hungry Howie''s!',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 15. INDEXES & PERFORMANCE OPTIMIZATIONS
-- ---------------------------------------------------------------------------

CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_staff_user_id ON staff(user_id);
CREATE INDEX idx_payroll_staff_month ON payroll_records(staff_id, payroll_month);
CREATE INDEX idx_payroll_status ON payroll_records(payment_status);
CREATE INDEX idx_tables_status ON restaurant_tables(status);
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_variants_menu_item ON menu_item_variants(menu_item_id);
CREATE INDEX idx_modifiers_menu_item ON menu_item_modifiers(menu_item_id);
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customer_addresses_customer ON customer_addresses(customer_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_type ON orders(order_type);
CREATE INDEX idx_orders_cashier ON orders(cashier_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_table ON orders(table_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_menu_item ON order_items(menu_item_id);
CREATE INDEX idx_order_item_modifiers_item ON order_item_modifiers(order_item_id);
CREATE INDEX idx_delivery_rider ON delivery_details(rider_id);
CREATE INDEX idx_delivery_status ON delivery_details(delivery_status);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_paid_at ON payments(paid_at DESC);
CREATE INDEX idx_inventory_category ON inventory_items(category_id);
CREATE INDEX idx_inventory_supplier ON inventory_items(supplier_id);
CREATE INDEX idx_stock_trans_item_date ON stock_transactions(inventory_item_id, created_at DESC);
CREATE INDEX idx_stock_trans_type ON stock_transactions(transaction_type);
CREATE INDEX idx_recipes_menu_item ON recipe_ingredients(menu_item_id);
CREATE INDEX idx_expenses_date ON expenses(expense_date DESC);
CREATE INDEX idx_expenses_category ON expenses(category);
