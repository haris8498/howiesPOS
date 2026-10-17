# Hungry Howie's — Implementation-Ready Database Schema

**System:** Hungry Howie's Restaurant Management & POS System  
**Database Engine:** PostgreSQL 15+ / 16+ (Extensions: `pgcrypto` or `uuid-ossp`)  
**ORM Framework:** Prisma ORM 5.x / 6.x (NestJS Backend Compatible)  
**Frontend Client:** Flutter Desktop, Tablet & Web POS  
**Architecture Scope:** Single-Branch Dedicated POS Architecture  
**Source of Truth:** [`DATABASE_ARCHITECTURE.md`](./DATABASE_ARCHITECTURE.md) (25 Normalized Tables)

---

## Table of Contents
1. [Schema Overview & Conventions](#1-schema-overview--conventions)
2. [PostgreSQL DDL Implementation (`schema.sql`)](#2-postgresql-ddl-implementation)
   - [Extensions & Enums](#21-extensions--custom-enum-types)
   - [Auth & Access Control](#22-authentication--access-control)
   - [Staff & Payroll](#23-staff--payroll)
   - [Floor & Table Management](#24-floor--table-management)
   - [Menu Catalog, Variants & Modifiers](#25-menu-catalog-variants--modifiers)
   - [Deals & Packages](#26-deals--packages)
   - [Customers & Delivery Addresses](#27-customers--delivery-addresses)
   - [Orders, Items & Modifiers](#28-orders-line-items--modifiers)
   - [Delivery & Dispatch Details](#29-delivery--dispatch-details)
   - [Payment & Multi-Tender Settlement](#210-payments--multi-tender-settlement)
   - [Suppliers, Inventory & Stock Transactions](#211-suppliers-inventory--stock-transactions)
   - [Recipes & Bill of Materials](#212-recipes--bill-of-materials)
   - [Operational Expenses](#213-operational-expenses)
   - [Restaurant Settings](#214-restaurant-settings)
   - [Indexes & Performance Optimizations](#215-indexes--performance-optimizations)
   - [Default Initial Data Seed](#216-default-initial-data-seed)
3. [Prisma Schema Specification (`schema.prisma`)](#3-prisma-schema-specification)

---

## 1. Schema Overview & Conventions

- **Primary Keys:** `VARCHAR(36)` containing UUID v4 identifiers (`gen_random_uuid()` in PostgreSQL, `@default(uuid())` in Prisma).
- **Monetary Quantities:** `DECIMAL(10, 2)` or `DECIMAL(12, 2)` for prices, subtotals, tax, discounts, wages, and expenses to eliminate floating-point rounding errors.
- **Inventory Balances:** `DECIMAL(12, 3)` with 3-decimal precision to accurately handle fractional metric units (`kg`, `g`, `ltr`, `ml`).
- **Timestamps:** `TIMESTAMPTZ` (`TIMESTAMP WITH TIME ZONE`) for precise audit times, kitchen order durations, and rider dispatch ETAs.
- **Foreign Key Actions:**
  - Cascades (`ON DELETE CASCADE`) are applied on owned composition records (`order_items`, `order_item_modifiers`, `customer_addresses`, `role_permissions`, `recipe_ingredients`, `menu_item_variants`, `menu_item_modifiers`, `delivery_details`).
  - Restricts (`ON DELETE RESTRICT`) protect financial transactions (`payments`, `stock_transactions`, `expenses`, `orders`).
  - Set Nulls (`ON DELETE SET NULL`) preserve historical orders if optional references (`table_id`, `customer_id`, `supplier_id`) are altered.

---

## 2. PostgreSQL DDL Implementation

```sql
-- ===========================================================================
-- HUNGRY HOWIE'S RESTAURANT MANAGEMENT & POS SYSTEM
-- Complete Implementation-Ready PostgreSQL DDL Script
-- Tables: 25 | Architecture: 3NF Normalized Single-Branch POS
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 2.1 EXTENSIONS & CUSTOM ENUM TYPES
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
-- 2.2 AUTHENTICATION & ACCESS CONTROL
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
-- 2.3 STAFF & PAYROLL
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
-- 2.4 FLOOR & TABLE MANAGEMENT
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
-- 2.5 MENU CATALOG, VARIANTS & MODIFIERS
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
    name VARCHAR(50) NOT NULL, -- 'Regular', 'Large', 'Jumbo'
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
-- 2.6 DEALS & PACKAGES
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
-- 2.7 CUSTOMERS & DELIVERY ADDRESSES
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
-- 2.8 ORDERS, LINE ITEMS & MODIFIERS
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
-- 2.9 DELIVERY & DISPATCH DETAILS
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
-- 2.10 PAYMENTS & MULTI-TENDER SETTLEMENT
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
-- 2.11 SUPPLIERS, INVENTORY & STOCK TRANSACTIONS
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
    unit VARCHAR(20) NOT NULL DEFAULT 'kg', -- 'kg', 'g', 'ltr', 'ml', 'pcs'
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
    transaction_type VARCHAR(20) NOT NULL, -- 'STOCK_IN', 'STOCK_OUT', 'WASTAGE', 'RECIPE_DEDUCTION'
    quantity DECIMAL(12, 3) NOT NULL,
    cost_per_unit DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (cost_per_unit >= 0.00),
    total_cost DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (total_cost >= 0.00),
    reference_order_id VARCHAR(36),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 2.12 RECIPES & BILL OF MATERIALS (BOM)
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
-- 2.13 OPERATIONAL EXPENSES
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
-- 2.14 RESTAURANT SETTINGS
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
-- 2.15 INDEXES & PERFORMANCE OPTIMIZATIONS
-- ---------------------------------------------------------------------------

-- Authentication & Users
CREATE INDEX idx_users_role_id ON users(role_id);
CREATE INDEX idx_users_username ON users(username);

-- Staff & Payroll
CREATE INDEX idx_staff_user_id ON staff(user_id);
CREATE INDEX idx_payroll_staff_month ON payroll_records(staff_id, payroll_month);
CREATE INDEX idx_payroll_status ON payroll_records(payment_status);

-- Tables & Floor
CREATE INDEX idx_tables_status ON restaurant_tables(status);

-- Catalog
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_variants_menu_item ON menu_item_variants(menu_item_id);
CREATE INDEX idx_modifiers_menu_item ON menu_item_modifiers(menu_item_id);

-- Customers
CREATE INDEX idx_customers_phone ON customers(phone);
CREATE INDEX idx_customer_addresses_customer ON customer_addresses(customer_id);

-- Orders (Primary High-Volume Queries)
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_type ON orders(order_type);
CREATE INDEX idx_orders_cashier ON orders(cashier_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_table ON orders(table_id);

-- Order Items & Modifiers
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_menu_item ON order_items(menu_item_id);
CREATE INDEX idx_order_item_modifiers_item ON order_item_modifiers(order_item_id);

-- Delivery & Dispatch
CREATE INDEX idx_delivery_rider ON delivery_details(rider_id);
CREATE INDEX idx_delivery_status ON delivery_details(delivery_status);

-- Payments
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_paid_at ON payments(paid_at DESC);

-- Inventory & Stock Ledger
CREATE INDEX idx_inventory_category ON inventory_items(category_id);
CREATE INDEX idx_inventory_supplier ON inventory_items(supplier_id);
CREATE INDEX idx_stock_trans_item_date ON stock_transactions(inventory_item_id, created_at DESC);
CREATE INDEX idx_stock_trans_type ON stock_transactions(transaction_type);

-- Recipes & BOM
CREATE INDEX idx_recipes_menu_item ON recipe_ingredients(menu_item_id);

-- Expenses
CREATE INDEX idx_expenses_date ON expenses(expense_date DESC);
CREATE INDEX idx_expenses_category ON expenses(category);

-- ---------------------------------------------------------------------------
-- 2.16 DEFAULT INITIAL DATA SEED
-- ---------------------------------------------------------------------------

-- Roles
INSERT INTO roles (id, name, description) VALUES
('role-owner', 'owner', 'Full unrestricted ownership access across all modules'),
('role-manager', 'manager', 'Store management, staff, inventory and financial oversight'),
('role-cashier', 'cashier', 'Point of sale, ordering, and billing operations')
ON CONFLICT (name) DO NOTHING;

-- Manager Module Permissions
INSERT INTO role_permissions (role_id, module_key, can_view, can_create, can_edit, can_delete) VALUES
('role-manager', 'pos', true, true, true, false),
('role-manager', 'tables', true, true, true, true),
('role-manager', 'menu', true, true, true, true),
('role-manager', 'inventory', true, true, true, false),
('role-manager', 'expenses', true, true, true, false),
('role-manager', 'reports', true, false, false, false),
('role-manager', 'staff', true, true, true, false),
('role-cashier', 'pos', true, true, false, false),
('role-cashier', 'tables', true, false, false, false),
('role-cashier', 'menu', true, false, false, false),
('role-cashier', 'inventory', false, false, false, false),
('role-cashier', 'expenses', false, false, false, false),
('role-cashier', 'reports', false, false, false, false),
('role-cashier', 'staff', false, false, false, false)
ON CONFLICT (role_id, module_key) DO NOTHING;

-- Default Owner User (Password: admin123 hashed via bcrypt)
INSERT INTO users (id, role_id, username, password_hash, full_name, phone, is_active) VALUES
('user-owner-default', 'role-owner', 'owner', '$2b$10$w3V8Pqy3H8q/q4Iqvz4szeK6uYwYkIuSg1WjIqG8Gq9F6w7X0.m12', 'System Owner', '+92 300 1112233', true)
ON CONFLICT (username) DO NOTHING;

-- Restaurant Singleton Settings
INSERT INTO restaurant_settings (id, restaurant_name, phone, address, tax_rate_percent, default_delivery_charge, receipt_footer_msg) VALUES
('default', 'Hungry Howie''s Pizza', '+92 300 0000000', 'Centaurus Mall, Islamabad', 5.00, 150.00, 'Thank you for dining at Hungry Howie''s!')
ON CONFLICT (id) DO NOTHING;
```

---

## 3. Prisma Schema Specification

```prisma
// ===========================================================================
// HUNGRY HOWIE'S RESTAURANT MANAGEMENT & POS SYSTEM
// Complete Production-Ready Prisma Schema (schema.prisma)
// Compatible with NestJS Backend & PostgreSQL 15+/16+
// ===========================================================================

generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// ---------------------------------------------------------------------------
// 1. AUTHENTICATION & ACCESS CONTROL
// ---------------------------------------------------------------------------

model Role {
  id          String           @id @default(uuid()) @db.VarChar(36)
  name        String           @unique @db.VarChar(50)
  description String?          @db.VarChar(255)
  createdAt   DateTime         @default(now()) @map("created_at") @db.Timestamptz
  users       User[]
  permissions RolePermission[]

  @@map("roles")
}

model RolePermission {
  id         String   @id @default(uuid()) @db.VarChar(36)
  roleId     String   @map("role_id") @db.VarChar(36)
  moduleKey  String   @map("module_key") @db.VarChar(50)
  canView    Boolean  @default(true) @map("can_view")
  canCreate  Boolean  @default(false) @map("can_create")
  canEdit    Boolean  @default(false) @map("can_edit")
  canDelete  Boolean  @default(false) @map("can_delete")
  role       Role     @relation(fields: [roleId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@unique([roleId, moduleKey])
  @@map("role_permissions")
}

model User {
  id                String             @id @default(uuid()) @db.VarChar(36)
  roleId            String             @map("role_id") @db.VarChar(36)
  username          String             @unique @db.VarChar(50)
  passwordHash      String             @map("password_hash") @db.VarChar(255)
  fullName          String             @map("full_name") @db.VarChar(100)
  phone             String?            @db.VarChar(20)
  isActive          Boolean            @default(true) @map("is_active")
  createdAt         DateTime           @default(now()) @map("created_at") @db.Timestamptz
  updatedAt         DateTime           @updatedAt @map("updated_at") @db.Timestamptz
  role              Role               @relation(fields: [roleId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  staffProfile      Staff?
  ordersCreated     Order[]
  paymentsReceived  Payment[]
  stockTransactions StockTransaction[]
  expensesRecorded  Expense[]

  @@index([roleId])
  @@map("users")
}

// ---------------------------------------------------------------------------
// 2. STAFF & PAYROLL
// ---------------------------------------------------------------------------

model Staff {
  id              String          @id @default(uuid()) @db.VarChar(36)
  userId          String?         @unique @map("user_id") @db.VarChar(36)
  name            String          @db.VarChar(100)
  designation     String          @db.VarChar(50)
  phone           String          @unique @db.VarChar(20)
  email           String?         @db.VarChar(100)
  monthlySalary   Decimal         @default(0.00) @map("monthly_salary") @db.Decimal(12, 2)
  hourlyRate      Decimal         @default(0.00) @map("hourly_rate") @db.Decimal(10, 2)
  isClockedIn     Boolean         @default(false) @map("is_clocked_in")
  joiningDate     DateTime        @default(now()) @map("joining_date") @db.Date
  isActive        Boolean         @default(true) @map("is_active")
  createdAt       DateTime        @default(now()) @map("created_at") @db.Timestamptz
  user            User?           @relation(fields: [userId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  payrolls        PayrollRecord[]
  deliveriesRider DeliveryDetail[]

  @@map("staff")
}

model PayrollRecord {
  id            String    @id @default(uuid()) @db.VarChar(36)
  staffId       String    @map("staff_id") @db.VarChar(36)
  payrollMonth  String    @map("payroll_month") @db.VarChar(7)
  baseSalary    Decimal   @default(0.00) @map("base_salary") @db.Decimal(12, 2)
  allowances    Decimal   @default(0.00) @db.Decimal(12, 2)
  deductions    Decimal   @default(0.00) @db.Decimal(12, 2)
  netSalary     Decimal   @default(0.00) @map("net_salary") @db.Decimal(12, 2)
  paymentStatus String    @default("UNPAID") @map("payment_status") @db.VarChar(20)
  paidAt        DateTime? @map("paid_at") @db.Timestamptz
  paymentMethod String?   @map("payment_method") @db.VarChar(30)
  notes         String?   @db.Text
  staff         Staff     @relation(fields: [staffId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@unique([staffId, payrollMonth])
  @@index([staffId, payrollMonth])
  @@index([paymentStatus])
  @@map("payroll_records")
}

// ---------------------------------------------------------------------------
// 3. FLOOR & TABLES
// ---------------------------------------------------------------------------

model RestaurantTable {
  id              String   @id @default(uuid()) @db.VarChar(36)
  tableNumber     String   @unique @map("table_number") @db.VarChar(20)
  section         String   @default("Hall") @db.VarChar(50)
  seatingCapacity Int      @default(4) @map("seating_capacity")
  status          String   @default("AVAILABLE") @db.VarChar(20)
  activeOrderId   String?  @map("active_order_id") @db.VarChar(36)
  createdAt       DateTime @default(now()) @map("created_at") @db.Timestamptz
  orders          Order[]

  @@index([status])
  @@map("restaurant_tables")
}

// ---------------------------------------------------------------------------
// 4. MENU CATALOG, VARIANTS, MODIFIERS & DEALS
// ---------------------------------------------------------------------------

model Category {
  id        String     @id @default(uuid()) @db.VarChar(36)
  name      String     @unique @db.VarChar(100)
  sortOrder Int        @default(0) @map("sort_order")
  isActive  Boolean    @default(true) @map("is_active")
  items     MenuItem[]

  @@map("categories")
}

model MenuItem {
  id          String              @id @default(uuid()) @db.VarChar(36)
  categoryId  String              @map("category_id") @db.VarChar(36)
  name        String              @db.VarChar(150)
  description String?             @db.Text
  basePrice   Decimal             @default(0.00) @map("base_price") @db.Decimal(10, 2)
  imageUrl    String?             @map("image_url") @db.VarChar(255)
  isAvailable Boolean             @default(true) @map("is_available")
  createdAt   DateTime            @default(now()) @map("created_at") @db.Timestamptz
  category    Category            @relation(fields: [categoryId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  variants    MenuItemVariant[]
  modifiers   MenuItemModifier[]
  recipes     RecipeIngredient[]
  orderItems  OrderItem[]

  @@index([categoryId])
  @@map("menu_items")
}

model MenuItemVariant {
  id         String   @id @default(uuid()) @db.VarChar(36)
  menuItemId String   @map("menu_item_id") @db.VarChar(36)
  name       String   @db.VarChar(50)
  price      Decimal  @default(0.00) @db.Decimal(10, 2)
  isDefault  Boolean  @default(false) @map("is_default")
  menuItem   MenuItem @relation(fields: [menuItemId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@unique([menuItemId, name])
  @@index([menuItemId])
  @@map("menu_item_variants")
}

model MenuItemModifier {
  id            String   @id @default(uuid()) @db.VarChar(36)
  menuItemId    String   @map("menu_item_id") @db.VarChar(36)
  name          String   @db.VarChar(100)
  modifierGroup String   @default("Customization") @map("modifier_group") @db.VarChar(50)
  price         Decimal  @default(0.00) @db.Decimal(10, 2)
  isAvailable   Boolean  @default(true) @map("is_available")
  menuItem      MenuItem @relation(fields: [menuItemId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@index([menuItemId])
  @@map("menu_item_modifiers")
}

model Deal {
  id            String      @id @default(uuid()) @db.VarChar(36)
  name          String      @unique @db.VarChar(150)
  description   String?     @db.Text
  price         Decimal     @default(0.00) @db.Decimal(10, 2)
  includedItems Json        @default("[]") @map("included_items")
  isActive      Boolean     @default(true) @map("is_active")
  createdAt     DateTime    @default(now()) @map("created_at") @db.Timestamptz
  orderItems    OrderItem[]

  @@map("deals")
}

// ---------------------------------------------------------------------------
// 5. CUSTOMERS & SAVED ADDRESSES
// ---------------------------------------------------------------------------

model Customer {
  id        String            @id @default(uuid()) @db.VarChar(36)
  name      String            @db.VarChar(100)
  phone     String            @unique @db.VarChar(20)
  email     String?           @db.VarChar(100)
  createdAt DateTime          @default(now()) @map("created_at") @db.Timestamptz
  addresses CustomerAddress[]
  orders    Order[]

  @@index([phone])
  @@map("customers")
}

model CustomerAddress {
  id          String   @id @default(uuid()) @db.VarChar(36)
  customerId  String   @map("customer_id") @db.VarChar(36)
  addressLine String   @map("address_line") @db.Text
  cityArea    String   @map("city_area") @db.VarChar(100)
  isDefault   Boolean  @default(false) @map("is_default")
  customer    Customer @relation(fields: [customerId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@index([customerId])
  @@map("customer_addresses")
}

// ---------------------------------------------------------------------------
// 6. ORDERS, LINE ITEMS, DELIVERIES & PAYMENTS
// ---------------------------------------------------------------------------

model Order {
  id                 String           @id @default(uuid()) @db.VarChar(36)
  orderNumber        String           @unique @map("order_number") @db.VarChar(30)
  orderType          String           @default("DINE_IN") @map("order_type") @db.VarChar(20)
  status             String           @default("PENDING") @db.VarChar(20)
  tableId            String?          @map("table_id") @db.VarChar(36)
  customerId         String?          @map("customer_id") @db.VarChar(36)
  cashierId          String           @map("cashier_id") @db.VarChar(36)
  tokenNumber        Int?             @map("token_number")
  subtotal           Decimal          @default(0.00) @db.Decimal(12, 2)
  deliveryFee        Decimal          @default(0.00) @map("delivery_fee") @db.Decimal(10, 2)
  discountAmount     Decimal          @default(0.00) @map("discount_amount") @db.Decimal(10, 2)
  taxAmount          Decimal          @default(0.00) @map("tax_amount") @db.Decimal(10, 2)
  grandTotal         Decimal          @default(0.00) @map("grand_total") @db.Decimal(12, 2)
  cookingTimeMinutes Int?             @default(25) @map("cooking_time_minutes")
  orderNotes         String?          @map("order_notes") @db.Text
  createdAt          DateTime         @default(now()) @map("created_at") @db.Timestamptz
  completedAt        DateTime?        @map("completed_at") @db.Timestamptz
  table              RestaurantTable? @relation(fields: [tableId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  customer           Customer?        @relation(fields: [customerId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  cashier            User             @relation(fields: [cashierId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  items              OrderItem[]
  deliveryDetails    DeliveryDetail?
  payments           Payment[]

  @@index([createdAt(sort: Desc)])
  @@index([status])
  @@index([orderType])
  @@index([cashierId])
  @@index([customerId])
  @@index([tableId])
  @@map("orders")
}

model OrderItem {
  id         String              @id @default(uuid()) @db.VarChar(36)
  orderId    String              @map("order_id") @db.VarChar(36)
  menuItemId String?             @map("menu_item_id") @db.VarChar(36)
  dealId     String?             @map("deal_id") @db.VarChar(36)
  itemName   String              @map("item_name") @db.VarChar(150)
  sizeName   String?             @map("size_name") @db.VarChar(50)
  unitPrice  Decimal             @map("unit_price") @db.Decimal(10, 2)
  quantity   Int                 @default(1)
  totalPrice Decimal             @map("total_price") @db.Decimal(12, 2)
  order      Order               @relation(fields: [orderId], references: [id], onDelete: Cascade, onUpdate: Cascade)
  menuItem   MenuItem?           @relation(fields: [menuItemId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  deal       Deal?               @relation(fields: [dealId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  modifiers  OrderItemModifier[]

  @@index([orderId])
  @@index([menuItemId])
  @@map("order_items")
}

model OrderItemModifier {
  id           String    @id @default(uuid()) @db.VarChar(36)
  orderItemId  String    @map("order_item_id") @db.VarChar(36)
  modifierName String    @map("modifier_name") @db.VarChar(100)
  unitPrice    Decimal   @map("unit_price") @db.Decimal(10, 2)
  quantity     Int       @default(1)
  totalPrice   Decimal   @map("total_price") @db.Decimal(10, 2)
  orderItem    OrderItem @relation(fields: [orderItemId], references: [id], onDelete: Cascade, onUpdate: Cascade)

  @@index([orderItemId])
  @@map("order_item_modifiers")
}

model DeliveryDetail {
  id                  String    @id @default(uuid()) @db.VarChar(36)
  orderId             String    @unique @map("order_id") @db.VarChar(36)
  riderId             String?   @map("rider_id") @db.VarChar(36)
  deliveryAddress     String    @map("delivery_address") @db.Text
  cityZone            String?   @map("city_zone") @db.VarChar(100)
  deliveryStatus      String    @default("PENDING") @map("delivery_status") @db.VarChar(20)
  dispatchTimeMinutes Int?      @default(30) @map("dispatch_time_minutes")
  assignedAt          DateTime? @map("assigned_at") @db.Timestamptz
  dispatchedAt        DateTime? @map("dispatched_at") @db.Timestamptz
  deliveredAt         DateTime? @map("delivered_at") @db.Timestamptz
  order               Order     @relation(fields: [orderId], references: [id], onDelete: Cascade, onUpdate: Cascade)
  rider               Staff?    @relation(fields: [riderId], references: [id], onDelete: SetNull, onUpdate: Cascade)

  @@index([riderId])
  @@index([deliveryStatus])
  @@map("delivery_details")
}

model Payment {
  id             String   @id @default(uuid()) @db.VarChar(36)
  orderId        String   @map("order_id") @db.VarChar(36)
  cashierId      String   @map("cashier_id") @db.VarChar(36)
  amountPaid     Decimal  @default(0.00) @map("amount_paid") @db.Decimal(12, 2)
  amountReceived Decimal  @default(0.00) @map("amount_received") @db.Decimal(12, 2)
  returnChange   Decimal  @default(0.00) @map("return_change") @db.Decimal(12, 2)
  paymentMethod  String   @default("Cash") @map("payment_method") @db.VarChar(30)
  paymentStatus  String   @default("PAID") @map("payment_status") @db.VarChar(20)
  transactionRef String?  @map("transaction_ref") @db.VarChar(100)
  paidAt         DateTime @default(now()) @map("paid_at") @db.Timestamptz
  order          Order    @relation(fields: [orderId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  cashier        User     @relation(fields: [cashierId], references: [id], onDelete: Restrict, onUpdate: Cascade)

  @@index([orderId])
  @@index([paidAt(sort: Desc)])
  @@map("payments")
}

// ---------------------------------------------------------------------------
// 7. INVENTORY, SUPPLIERS & RECIPES
// ---------------------------------------------------------------------------

model Supplier {
  id                String             @id @default(uuid()) @db.VarChar(36)
  name              String             @unique @db.VarChar(150)
  contactPerson     String?            @map("contact_person") @db.VarChar(100)
  phone             String?            @db.VarChar(20)
  email             String?            @db.VarChar(100)
  address           String?            @db.Text
  createdAt         DateTime           @default(now()) @map("created_at") @db.Timestamptz
  items             InventoryItem[]
  stockTransactions StockTransaction[]

  @@map("suppliers")
}

model InventoryCategory {
  id    String          @id @default(uuid()) @db.VarChar(36)
  name  String          @unique @db.VarChar(100)
  items InventoryItem[]

  @@map("inventory_categories")
}

model InventoryItem {
  id           String             @id @default(uuid()) @db.VarChar(36)
  categoryId   String             @map("category_id") @db.VarChar(36)
  supplierId   String?            @map("supplier_id") @db.VarChar(36)
  name         String             @unique @db.VarChar(150)
  unit         String             @default("kg") @db.VarChar(20)
  currentStock Decimal            @default(0.000) @map("current_stock") @db.Decimal(12, 3)
  minThreshold Decimal            @default(5.000) @map("min_threshold") @db.Decimal(12, 3)
  costPerUnit  Decimal            @default(0.00) @map("cost_per_unit") @db.Decimal(10, 2)
  updatedAt    DateTime           @updatedAt @map("updated_at") @db.Timestamptz
  category     InventoryCategory  @relation(fields: [categoryId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  supplier     Supplier?          @relation(fields: [supplierId], references: [id], onDelete: SetNull, onUpdate: Cascade)
  transactions StockTransaction[]
  recipes      RecipeIngredient[]

  @@index([categoryId])
  @@index([supplierId])
  @@map("inventory_items")
}

model StockTransaction {
  id               String        @id @default(uuid()) @db.VarChar(36)
  inventoryItemId  String        @map("inventory_item_id") @db.VarChar(36)
  userId           String        @map("user_id") @db.VarChar(36)
  supplierId       String?       @map("supplier_id") @db.VarChar(36)
  transactionType  String        @map("transaction_type") @db.VarChar(20)
  quantity         Decimal       @db.Decimal(12, 3)
  costPerUnit      Decimal       @default(0.00) @map("cost_per_unit") @db.Decimal(10, 2)
  totalCost        Decimal       @default(0.00) @map("total_cost") @db.Decimal(12, 2)
  referenceOrderId String?       @map("reference_order_id") @db.VarChar(36)
  notes            String?       @db.Text
  createdAt        DateTime      @default(now()) @map("created_at") @db.Timestamptz
  inventoryItem    InventoryItem @relation(fields: [inventoryItemId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  user             User          @relation(fields: [userId], references: [id], onDelete: Restrict, onUpdate: Cascade)
  supplier         Supplier?     @relation(fields: [supplierId], references: [id], onDelete: SetNull, onUpdate: Cascade)

  @@index([inventoryItemId, createdAt(sort: Desc)])
  @@index([transactionType])
  @@map("stock_transactions")
}

model RecipeIngredient {
  id               String        @id @default(uuid()) @db.VarChar(36)
  menuItemId       String        @map("menu_item_id") @db.VarChar(36)
  inventoryItemId  String        @map("inventory_item_id") @db.VarChar(36)
  quantityRequired Decimal       @map("quantity_required") @db.Decimal(10, 3)
  menuItem         MenuItem      @relation(fields: [menuItemId], references: [id], onDelete: Cascade, onUpdate: Cascade)
  inventoryItem    InventoryItem @relation(fields: [inventoryItemId], references: [id], onDelete: Restrict, onUpdate: Cascade)

  @@unique([menuItemId, inventoryItemId])
  @@index([menuItemId])
  @@map("recipe_ingredients")
}

// ---------------------------------------------------------------------------
// 8. EXPENSES & RESTAURANT SETTINGS
// ---------------------------------------------------------------------------

model Expense {
  id            String   @id @default(uuid()) @db.VarChar(36)
  userId        String   @map("user_id") @db.VarChar(36)
  category      String   @default("General") @db.VarChar(50)
  description   String   @db.VarChar(255)
  amount        Decimal  @db.Decimal(12, 2)
  paymentMethod String   @default("Cash") @map("payment_method") @db.VarChar(30)
  expenseDate   DateTime @default(now()) @map("expense_date") @db.Date
  createdAt     DateTime @default(now()) @map("created_at") @db.Timestamptz
  recordedBy    User     @relation(fields: [userId], references: [id], onDelete: Restrict, onUpdate: Cascade)

  @@index([expenseDate(sort: Desc)])
  @@index([category])
  @@map("expenses")
}

model RestaurantSettings {
  id                    String   @id @default("default") @db.VarChar(36)
  restaurantName        String   @default("Hungry Howie's Pizza") @map("restaurant_name") @db.VarChar(100)
  phone                 String   @default("+92 300 0000000") @db.VarChar(20)
  address               String   @default("Centaurus Mall, Islamabad") @db.Text
  taxRatePercent        Decimal  @default(5.00) @map("tax_rate_percent") @db.Decimal(5, 2)
  defaultDeliveryCharge Decimal  @default(150.00) @map("default_delivery_charge") @db.Decimal(10, 2)
  receiptFooterMsg      String?  @default("Thank you for choosing Hungry Howie's!") @map("receipt_footer_msg") @db.Text
  updatedAt             DateTime @updatedAt @map("updated_at") @db.Timestamptz

  @@map("restaurant_settings")
}
```
