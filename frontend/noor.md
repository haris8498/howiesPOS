# Hungry Howie's POS - Relational Database Schema Documentation

> **Document Version:** 1.0 (Final Validated Specification)  
> **Source:** Reverse-engineered strictly from Flutter/Dart UI screens, widgets, dialogs, and models.  
> **Scope:** Minimal relational database schema with zero speculative entities or unused fields.  
> **Target System:** Hungry Howie's Point-of-Sale (POS), Kitchen Display (KDS), Dispatch, Inventory, and Store Operations.

---

## 1. Schema Overview & Architecture

This database schema has been derived directly from the application's frontend presentation layer. Every entity, attribute, data type, primary key, foreign key, and constraint maps 1:1 to visible user interfaces, entry forms, data filters, KPI counters, and operational workflows.

### Entity Catalog (20 Tables)

| # | Entity / Table Name | Functional Domain | Primary Purpose |
| :-: | :--- | :--- | :--- |
| 1 | `store_settings` | Configuration | Global store identity, tax rates, and service charge settings |
| 2 | `staff_users` | Authentication | System login credentials, security roles, and credential updates |
| 3 | `role_permissions` | Security & RBAC | Granular permission matrix per role and functional module |
| 4 | `staff_members` | HR & Payroll | Employee records, shift scheduling, duty clock-in, and payroll |
| 5 | `customers` | CRM & Loyalty | Customer profiles, delivery addresses, order counts, and loyalty points |
| 6 | `restaurant_tables` | Floor Plan | Dine-in tables, seating capacity, zones, and live occupancy status |
| 7 | `menu_categories` | Catalog | Menu food and drink categories with badges and icons |
| 8 | `menu_items` | Catalog | Food products with base prices, dietary tags, and availability |
| 9 | `menu_item_sizes` | Catalog | Variant size tiers (Small, Medium, Large, Family) with price overrides |
| 10 | `menu_item_options` | Catalog | Customizations (crusts, buns, flavors, extra toppings) with surcharges |
| 11 | `deals` | Promotions | Combo meal packages, discounted bundles, and promotional banners |
| 12 | `deal_components` | Promotions | Individual item components and quantities bundled inside deals |
| 13 | `orders` | Sales & Billing | Unified transaction record for Dine-In, Takeaway, Delivery, and Online |
| 14 | `order_items` | Sales & Billing | Line items purchased with size, crust, toppings, notes, and pricing |
| 15 | `delivery_riders` | Fleet Tracking | Courier fleet profiles, shift status, active deliveries, and ratings |
| 16 | `delivery_zones` | Logistics | Geographical delivery sectors with fixed fees and transit estimates |
| 17 | `delivery_dispatches`| Logistics | Active delivery dispatches connecting orders, couriers, and zones |
| 18 | `inventory_items` | Stock Control | Raw ingredient catalog, current stock, reorder levels, and unit costs |
| 19 | `stock_movements` | Stock Control | Inventory ledger for restocks, kitchen usage, wastage, and deductions |
| 20 | `expenses` | Finance & P&L | Store operating expenses categorized by date and recorded by staff |

---

## 2. Table Relationships & Cardinality

### Relationship Summary

* **`staff_users` 1 : N `role_permissions`**  
  Each role configured in `staff_users` maps to multiple granular module permissions in `role_permissions`.
* **`staff_users` 1 : 0..1 `staff_members`**  
  A login user account optionally links to an employee HR profile (`staff_members.user_id` -> `staff_users.id`).
* **`staff_members` 1 : N `orders`**  
  Staff members act as waitstaff or cashiers processing customer transactions (`orders.waiter_name` or staff reference).
* **`staff_members` 1 : N `expenses`**  
  Store managers record operational expenditure logs (`expenses.recorded_by`).
* **`customers` 1 : N `orders`**  
  A registered customer profile can be linked to multiple Dine-In, Takeaway, or Delivery transactions (`orders.customer_id` -> `customers.id`).
* **`restaurant_tables` 1 : N `orders`**  
  A restaurant table hosts orders over time, with one active order at any given time (`orders.table_id` -> `restaurant_tables.id`).
* **`menu_categories` 1 : N `menu_items`**  
  Every product category contains multiple menu items (`menu_items.category_id` -> `menu_categories.id`).
* **`menu_items` 1 : N `menu_item_sizes`**  
  A menu item can have multiple size variants (`menu_item_sizes.menu_item_id` -> `menu_items.id`).
* **`menu_items` 1 : N `menu_item_options`**  
  A menu item can offer selectable crusts, buns, flavors, or extra toppings (`menu_item_options.menu_item_id` -> `menu_items.id`).
* **`menu_items` 1 : N `order_items`**  
  Products serve as the template for individual line items added to order tickets (`order_items.menu_item_id` -> `menu_items.id`).
* **`deals` 1 : N `deal_components`**  
  A combo package aggregates multiple product components (`deal_components.deal_id` -> `deals.id`).
* **`orders` 1 : N `order_items`**  
  An order consists of one or more line items (`order_items.order_id` -> `orders.id`).
* **`orders` 1 : 0..1 `delivery_dispatches`**  
  Orders with delivery fulfillment link to a single dispatch record (`delivery_dispatches.order_id` -> `orders.id`).
* **`delivery_riders` 1 : N `delivery_dispatches`**  
  A delivery courier is assigned multiple customer dispatches over their shift (`delivery_dispatches.rider_id` -> `delivery_riders.id`).
* **`delivery_zones` 1 : N `delivery_dispatches`**  
  Delivery runs are grouped into configured geographic zones (`delivery_dispatches.zone_id` -> `delivery_zones.id`).
* **`inventory_items` 1 : N `stock_movements`**  
  Each inventory ingredient tracks its consumption, restock, and wastage history (`stock_movements.item_id` -> `inventory_items.id`).

---

## 3. Detailed Table Specifications

---

### Table: `store_settings`
* **Purpose:** Stores the single-row global configuration for the restaurant branch, including brand details, outlet code, contact number, and tax/service charge rates.
* **UI Source:** `features/settings/settings_screen.dart`, `shared/widgets/top_app_bar.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID/Fixed identifier) |
| `chain_name` | VARCHAR(100) | - | No | `'Hungry Howie''s'` | Brand chain name displayed on headers and receipts |
| `branch_code` | VARCHAR(50) | - | No | `'Branch #402'` | Unique branch outlet identifier |
| `branch_name` | VARCHAR(100) | - | No | `'Metro Central Outlet'` | Branch display name |
| `store_phone` | VARCHAR(30) | - | No | - | Official contact phone number |
| `sales_tax_rate` | DECIMAL(5,2) | - | No | `8.50` | Default sales tax percentage rate |
| `dine_in_service_charge_rate` | DECIMAL(5,2) | - | No | `5.00` | Dine-in service charge percentage rate |
| `updated_at` | TIMESTAMP | - | No | `CURRENT_TIMESTAMP` | Last updated timestamp |

* **Relationships:** None (Singleton configuration table).

---

### Table: `staff_users`
* **Purpose:** Manages authentication credentials, system access roles, and audit tracking for user account updates.
* **UI Source:** `features/auth/login_screen.dart`, `features/passwords/password_management_screen.dart`, `data/auth_repository.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `username` | VARCHAR(50) | - | No | - | Unique login username; UNIQUE constraint |
| `email` | VARCHAR(100) | - | No | - | User contact email |
| `password_hash` | VARCHAR(255) | - | No | - | Hashed credential password string |
| `role` | VARCHAR(20) | - | No | - | Role enum: `'owner'`, `'manager'`, `'cashier'` |
| `is_default` | BOOLEAN | - | No | `FALSE` | Indicates system-seeded credential |
| `last_updated` | TIMESTAMP | - | No | `CURRENT_TIMESTAMP` | Timestamp of latest password/role change |
| `updated_by` | VARCHAR(50) | - | No | `'Super Admin'` | Username of the administrator modifying record |

* **Relationships:**
  * One-to-One / Zero-to-One with `staff_members` (`staff_members.user_id` -> `staff_users.id`).
  * Role mapping with `role_permissions` (`role_permissions.role` matches `staff_users.role`).

---

### Table: `role_permissions`
* **Purpose:** Defines granular access control permissions for POS screens, modules, and administrative actions per role.
* **UI Source:** `features/rights/rights_screen.dart`, `domain/models/role_rights_model.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(50) | PK | No | - | Primary key (e.g. `'perm_mgr_tables'`) |
| `role` | VARCHAR(20) | - | No | - | Target role: `'manager'`, `'cashier'` |
| `module_name` | VARCHAR(50) | - | No | - | Target module (Tables, Menu, Stock, Users, Reports, etc.) |
| `action_name` | VARCHAR(100) | - | No | - | Specific action (e.g. `'Edit Floor Plan'`, `'Delete Table'`) |
| `description` | VARCHAR(255) | - | No | - | Explanatory description shown in the permissions matrix |
| `is_granted` | BOOLEAN | - | No | `FALSE` | Permission status toggle |
| `is_sensitive` | BOOLEAN | - | No | `FALSE` | Flag indicating high-security action |

* **Relationships:**
  * Many-to-One logical mapping to `staff_users.role`.

---

### Table: `staff_members`
* **Purpose:** Stores comprehensive HR employee details, assigned work shifts, attendance clock-in records, and monthly payroll settlement.
* **UI Source:** `features/staff/staff_screen.dart`, `domain/models/staff_model.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key / Employee ID (e.g. `'USR-1001'`) |
| `user_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `staff_users(id)`; UNIQUE |
| `full_name` | VARCHAR(100) | - | No | - | Full legal employee name |
| `email` | VARCHAR(100) | - | No | - | Employee contact email |
| `phone` | VARCHAR(30) | - | No | - | Contact phone number |
| `role` | VARCHAR(20) | - | No | - | Operational role: `'owner'`, `'manager'`, `'cashier'` |
| `status` | VARCHAR(30) | - | No | `'Active'` | Employment status: `'Active'`, `'Inactive'` |
| `joining_date` | DATE | - | No | - | Official employment joining date |
| `assigned_shift` | VARCHAR(50) | - | No | `'Morning Shift'` | Assigned work shift schedule |
| `monthly_salary` | DECIMAL(10,2) | - | No | `65000.00` | Base monthly salary amount |
| `hourly_rate` | DECIMAL(10,2) | - | No | `406.00` | Hourly rate equivalent (~monthly_salary / 160) |
| `allowance` | DECIMAL(10,2) | - | No | `0.00` | Monthly additional allowances |
| `deductions` | DECIMAL(10,2) | - | No | `0.00` | Monthly payroll deductions |
| `is_clocked_in` | BOOLEAN | - | No | `FALSE` | Current shift attendance status toggle |
| `clock_in_time` | TIMESTAMP | - | Yes | `NULL` | Timestamp of current active clock-in |
| `is_salary_paid` | BOOLEAN | - | No | `FALSE` | Monthly salary payout settlement flag |
| `salary_paid_date` | TIMESTAMP | - | Yes | `NULL` | Timestamp when monthly salary was settled |

* **Relationships:**
  * Foreign key: `user_id` -> `staff_users(id)`.

---

### Table: `customers`
* **Purpose:** Stores customer directory records, delivery addresses, birthday dates for promotional discounts, and lifetime loyalty rewards tracking.
* **UI Source:** `features/customers/customers_screen.dart`, `domain/models/customer_model.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID/Customer code) |
| `full_name` | VARCHAR(100) | - | No | - | Customer full name |
| `phone` | VARCHAR(30) | - | No | - | Phone number; UNIQUE constraint |
| `email` | VARCHAR(100) | - | No | `''` | Optional customer email address |
| `address` | TEXT | - | No | `''` | Saved delivery street address |
| `birth_date` | DATE | - | Yes | `NULL` | Birth date (triggers Birthday 20% discount badge) |
| `loyalty_points` | INT | - | No | `0` | Loyalty point balance (10 pts per Rs 100 spent) |
| `total_orders_count` | INT | - | No | `0` | Lifetime count of completed orders |
| `total_spent` | DECIMAL(10,2) | - | No | `0.00` | Lifetime cumulative spend in Rs |
| `special_notes` | TEXT | - | No | `''` | Dietary preferences, allergies, or special notes |

* **Relationships:**
  * One-to-Many with `orders` (`orders.customer_id` -> `customers.id`).

---

### Table: `restaurant_tables`
* **Purpose:** Tracks dine-in dining tables, seating chair capacity, dining floor sections, active order links, and live reservation/occupancy timers.
* **UI Source:** `features/tables/tables_screen.dart`, `domain/models/restaurant_table.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `table_number` | VARCHAR(20) | - | No | - | Unique table code (e.g. `'T-01'`, `'VIP-01'`); UNIQUE |
| `name` | VARCHAR(50) | - | No | - | Display name (e.g. `'Table T-01'`) |
| `capacity` | INT | - | No | `4` | Number of seating chairs |
| `section` | VARCHAR(50) | - | No | `'Hall'` | Floor zone (`'Hall'`, `'Family Hall'`, `'Office'`, etc.) |
| `status` | VARCHAR(20) | - | No | `'available'` | Table status: `'available'`, `'occupied'`, `'reserved'` |
| `current_customer_count` | INT | - | No | `0` | Number of seated diners |
| `current_bill_amount` | DECIMAL(10,2) | - | No | `0.00` | Running unpaid bill total on table |
| `occupied_since` | TIMESTAMP | - | Yes | `NULL` | Timestamp when table was marked occupied |
| `active_order_id` | VARCHAR(36) | - | Yes | `NULL` | Reference to currently active order |
| `reserved_customer_name` | VARCHAR(100) | - | Yes | `NULL` | Name of customer holding reservation |
| `reservation_time` | TIMESTAMP | - | Yes | `NULL` | Scheduled reservation timestamp |

* **Relationships:**
  * One-to-Many with `orders` (`orders.table_id` -> `restaurant_tables.id`).

---

### Table: `menu_categories`
* **Purpose:** Classifies food and drink items into visual categories with display badges, banner image paths, and navigation icons.
* **UI Source:** `features/menu/menu_screen.dart`, `domain/models/menu_item.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Category key/ID (e.g. `'pizza'`, `'burger'`, `'dessert'`) |
| `name` | VARCHAR(50) | - | No | - | Category display title (e.g. `'Pizza'`, `'Burger'`) |
| `badge_text` | VARCHAR(30) | - | No | `'Category'` | Promotional or UI tag badge |
| `image_path` | VARCHAR(255) | - | No | `''` | Category banner asset image path |
| `description` | TEXT | - | No | `''` | Description of the category |
| `icon_name` | VARCHAR(50) | - | No | `'fastfood'` | Material icon identifier for tabs |

* **Relationships:**
  * One-to-Many with `menu_items` (`menu_items.category_id` -> `menu_categories.id`).

---

### Table: `menu_items`
* **Purpose:** Core catalog of restaurant products, containing base prices, dietary tags (vegetarian, spicy), image paths, and catalog visibility.
* **UI Source:** `features/menu/menu_screen.dart`, `domain/models/menu_item.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID/Product Code) |
| `category_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `menu_categories(id)` |
| `name` | VARCHAR(100) | - | No | - | Product title (e.g. `'Howie Special Pizza'`) |
| `description` | TEXT | - | No | `''` | Item ingredient and preparation description |
| `base_price` | DECIMAL(10,2) | - | No | - | Default regular catalog price in Rs |
| `image_url` | VARCHAR(255) | - | No | `''` | Asset path or remote image URL |
| `is_veg` | BOOLEAN | - | No | `FALSE` | Vegetarian dietary indicator |
| `is_spicy` | BOOLEAN | - | No | `FALSE` | Spicy chili indicator |
| `is_available` | BOOLEAN | - | No | `TRUE` | In-stock visibility flag |

* **Relationships:**
  * Foreign key: `category_id` -> `menu_categories(id)`.
  * One-to-Many with `menu_item_sizes` (`menu_item_sizes.menu_item_id` -> `menu_items.id`).
  * One-to-Many with `menu_item_options` (`menu_item_options.menu_item_id` -> `menu_items.id`).
  * One-to-Many with `order_items` (`order_items.menu_item_id` -> `menu_items.id`).

---

### Table: `menu_item_sizes`
* **Purpose:** Represents multi-size pricing tiers for menu items (Small, Medium, Large, Family) with distinct prices.
* **UI Source:** `features/menu/menu_screen.dart`, `shared/widgets/order_customization_dialog.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `menu_item_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `menu_items(id)` ON DELETE CASCADE |
| `size_name` | VARCHAR(30) | - | No | - | Size identifier (`'Small'`, `'Medium'`, `'Large'`, `'Family'`) |
| `price` | DECIMAL(10,2) | - | No | - | Specific price for this size tier in Rs |

* **Relationships:**
  * Foreign key: `menu_item_id` -> `menu_items(id)` ON DELETE CASCADE.

---

### Table: `menu_item_options`
* **Purpose:** Stores product customizations such as pizza crusts, burger buns, seasoning flavors, and extra toppings with price surcharges.
* **UI Source:** `features/menu/menu_screen.dart`, `features/pos/pos_screen.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `menu_item_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `menu_items(id)` ON DELETE CASCADE |
| `option_type` | VARCHAR(30) | - | No | - | Category: `'crust'`, `'bun'`, `'flavor'`, `'topping'` |
| `option_name` | VARCHAR(50) | - | No | - | Option name (e.g. `'Butter Cheese'`, `'Extra Pepperoni'`) |
| `additional_price` | DECIMAL(10,2) | - | No | `0.00` | Extra price surcharge added to line item |

* **Relationships:**
  * Foreign key: `menu_item_id` -> `menu_items(id)` ON DELETE CASCADE.

---

### Table: `deals`
* **Purpose:** Configures promotional combo packages, bundle pricing, strikethrough original prices, and promotional banners.
* **UI Source:** `features/menu/menu_screen.dart` (Deals section), `domain/models/menu_item.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID/Deal Code) |
| `title` | VARCHAR(100) | - | No | - | Deal title (e.g. `'Family Feast Combo'`) |
| `subtitle` | VARCHAR(150) | - | No | `''` | Promotional summary text |
| `deal_price` | DECIMAL(10,2) | - | No | - | Special package price in Rs |
| `original_price` | DECIMAL(10,2) | - | Yes | `NULL` | Reference strikethrough regular price |
| `badge_text` | VARCHAR(30) | - | No | `'EXCLUSIVE DEAL'` | Promotional badge label |
| `image_path` | VARCHAR(255) | - | No | `''` | Promotional banner image path |
| `description` | TEXT | - | No | `''` | Detailed package description |
| `is_available` | BOOLEAN | - | No | `TRUE` | Deal availability toggle |

* **Relationships:**
  * One-to-Many with `deal_components` (`deal_components.deal_id` -> `deals.id`).

---

### Table: `deal_components`
* **Purpose:** Itemizes individual food and beverage components comprising a promotional bundle.
* **UI Source:** `features/menu/menu_screen.dart`, `domain/models/menu_item.dart` (`DealComponent`)

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `deal_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `deals(id)` ON DELETE CASCADE |
| `item_name` | VARCHAR(100) | - | No | - | Component item name (e.g. `'Family Pizza'`) |
| `category` | VARCHAR(50) | - | No | - | Component category (`'Pizza'`, `'Broast'`, `'Drink'`) |
| `quantity` | VARCHAR(20) | - | No | `'1x'` | Quantity string descriptor (e.g. `'2x'`, `'4 pcs'`) |

* **Relationships:**
  * Foreign key: `deal_id` -> `deals(id)` ON DELETE CASCADE.

---

### Table: `orders`
* **Purpose:** Unified operational order entity consolidating Dine-In, Takeaway, Delivery, and Online Orders into a single transactional table.
* **UI Source:** `features/pos/pos_screen.dart`, `features/takeaway/takeaway_screen.dart`, `features/online_orders/online_orders_screen.dart`, `features/kitchen/kitchen_screen.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `order_number` | VARCHAR(30) | - | No | - | Formatted order code (`'ORD-1001'`, `'HH-1420'`); UNIQUE |
| `token_number` | VARCHAR(20) | - | Yes | `NULL` | Takeaway pickup token code (e.g. `'TK-42'`) |
| `order_type` | VARCHAR(20) | - | No | - | Enum: `'dineIn'`, `'takeAway'`, `'delivery'`, `'quickOrder'` |
| `order_source` | VARCHAR(30) | - | No | `'Direct POS'` | Source: `'Direct POS'`, `'Online Orders'`, `'Direct Delivery'` |
| `status` | VARCHAR(30) | - | No | `'newOrder'` | `'newOrder'`, `'accepted'`, `'preparing'`, `'ready'`, `'served'`, `'completed'`, `'cancelled'`, `'rejected'` |
| `table_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `restaurant_tables(id)` (Dine-In) |
| `guest_count` | INT | - | No | `1` | Guest seating count for dine-in tables |
| `waiter_name` | VARCHAR(50) | - | No | `'Cashier'` | Name of staff member who processed the order |
| `customer_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `customers(id)` |
| `customer_name` | VARCHAR(100) | - | Yes | `NULL` | Customer contact name |
| `customer_phone` | VARCHAR(30) | - | Yes | `NULL` | Customer contact phone number |
| `delivery_address` | TEXT | - | Yes | `NULL` | Street delivery address for delivery orders |
| `subtotal` | DECIMAL(10,2) | - | No | `0.00` | Sum of order line items before adjustments |
| `discount_amount` | DECIMAL(10,2) | - | No | `0.00` | Total discount amount deducted |
| `tax_percentage` | DECIMAL(5,2) | - | No | `8.50` | Sales tax rate percentage applied |
| `tax_amount` | DECIMAL(10,2) | - | No | `0.00` | Calculated sales tax in Rs |
| `service_charge_percentage` | DECIMAL(5,2) | - | No | `0.00` | Dine-in service charge rate percentage applied |
| `service_charge_amount` | DECIMAL(10,2) | - | No | `0.00` | Calculated service charge in Rs |
| `delivery_fee` | DECIMAL(10,2) | - | No | `0.00` | Shipping / delivery fee in Rs |
| `grand_total` | DECIMAL(10,2) | - | No | - | Net payable invoice amount in Rs |
| `payment_status` | VARCHAR(20) | - | No | `'UNPAID'` | Payment state: `'UNPAID'`, `'PAID'` |
| `payment_method` | VARCHAR(30) | - | Yes | `NULL` | `'cash'`, `'card'`, `'bank_transfer'`, `'Tender Settled'` |
| `is_paid` | BOOLEAN | - | No | `FALSE` | Boolean payment settled indicator |
| `is_held` | BOOLEAN | - | No | `FALSE` | True if order was held in POS cart |
| `kitchen_ticket_sent` | BOOLEAN | - | No | `FALSE` | True if Kitchen Order Ticket (KOT) was printed |
| `kitchen_note` | TEXT | - | Yes | `NULL` | Special cooking / kitchen notes |
| `rejection_reason` | TEXT | - | Yes | `NULL` | Reason for rejection (Online Orders) |
| `cooking_time_minutes` | INT | - | Yes | `NULL` | Target kitchen preparation duration |
| `estimated_ready_at` | TIMESTAMP | - | Yes | `NULL` | Target food ready timestamp |
| `created_at` | TIMESTAMP | - | No | `CURRENT_TIMESTAMP` | Order placement timestamp |

* **Relationships:**
  * Foreign key: `table_id` -> `restaurant_tables(id)`.
  * Foreign key: `customer_id` -> `customers(id)`.
  * One-to-Many with `order_items` (`order_items.order_id` -> `orders.id` ON DELETE CASCADE).
  * One-to-One / Zero-to-One with `delivery_dispatches` (`delivery_dispatches.order_id` -> `orders.id`).

---

### Table: `order_items`
* **Purpose:** Line items attached to orders, recording chosen size, crust, extra toppings, quantity, snapshot price, and custom kitchen notes.
* **UI Source:** `features/pos/pos_screen.dart`, `features/online_orders/online_orders_screen.dart`, `features/kitchen/kitchen_screen.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `order_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `orders(id)` ON DELETE CASCADE |
| `menu_item_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `menu_items(id)` |
| `item_name` | VARCHAR(100) | - | No | - | Snapshot product title at time of order |
| `quantity` | INT | - | No | `1` | Quantity ordered |
| `selected_size` | VARCHAR(30) | - | No | `'Regular'` | Selected size tier (`'Small'`, `'Medium'`, `'Large'`, `'Family'`) |
| `selected_crust` | VARCHAR(50) | - | No | `'Original'` | Selected crust/bun option |
| `extra_toppings` | TEXT | - | No | `''` | Serialized or comma-separated extra toppings list |
| `unit_price` | DECIMAL(10,2) | - | No | - | Unit price charged per item |
| `total_price` | DECIMAL(10,2) | - | No | - | Line total (`unit_price * quantity`) |
| `notes` | TEXT | - | No | `''` | Item-specific kitchen instructions |

* **Relationships:**
  * Foreign key: `order_id` -> `orders(id)` ON DELETE CASCADE.
  * Foreign key: `menu_item_id` -> `menu_items(id)`.

---

### Table: `delivery_riders`
* **Purpose:** Manages the courier fleet, on-duty status, active assignments in flight, delivery speed statistics, and customer ratings.
* **UI Source:** `features/delivery/delivery_screen.dart`, `domain/models/delivery_model.dart` (`DeliveryRider`)

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key / Rider ID (e.g. `'RDR-01'`) |
| `name` | VARCHAR(100) | - | No | - | Rider full legal name |
| `phone` | VARCHAR(30) | - | No | - | Contact phone number; UNIQUE |
| `is_available` | BOOLEAN | - | No | `TRUE` | Ready for new dispatch assignment |
| `is_clocked_in` | BOOLEAN | - | No | `TRUE` | On-duty shift toggle |
| `active_deliveries_count` | INT | - | No | `0` | Count of orders currently in transit |
| `total_completed_deliveries` | INT | - | No | `0` | Lifetime completed trips |
| `avg_delivery_time_mins` | DECIMAL(5,2) | - | No | `22.50` | Average transit duration in minutes |
| `rating` | DECIMAL(3,2) | - | No | `5.00` | Performance customer rating (e.g. 4.80) |

* **Relationships:**
  * One-to-Many with `delivery_dispatches` (`delivery_dispatches.rider_id` -> `delivery_riders.id`).

---

### Table: `delivery_zones`
* **Purpose:** Geographical delivery sectors configured with standard delivery fees and estimated transit durations.
* **UI Source:** `features/delivery/delivery_screen.dart`, `domain/models/delivery_model.dart` (`DeliveryZone`)

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (e.g. `'ZONE-01'`) |
| `zone_name` | VARCHAR(100) | - | No | - | Zone label (e.g. `'Downtown Metro (Zone 1)'`); UNIQUE |
| `delivery_fee` | DECIMAL(10,2) | - | No | `150.00` | Fixed delivery charge in Rs |
| `estimated_time_mins` | INT | - | No | `30` | Expected shipping duration in minutes |

* **Relationships:**
  * One-to-Many with `delivery_dispatches` (`delivery_dispatches.zone_id` -> `delivery_zones.id`).

---

### Table: `delivery_dispatches`
* **Purpose:** Tracks delivery dispatches, linking customer orders to riders, zones, transit stages, and dispatch timestamps.
* **UI Source:** `features/delivery/delivery_screen.dart`, `domain/models/delivery_model.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `order_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `orders(id)`; UNIQUE |
| `rider_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `delivery_riders(id)` |
| `zone_id` | VARCHAR(36) | FK | Yes | `NULL` | Foreign key referencing `delivery_zones(id)` |
| `dispatch_status` | VARCHAR(30) | - | No | `'pending'` | `'pending'`, `'readyForDispatch'`, `'outForDelivery'`, `'delivered'`, `'cancelled'` |
| `estimated_delivery_time` | TIMESTAMP | - | No | - | Expected delivery arrival time |
| `dispatched_at` | TIMESTAMP | - | Yes | `NULL` | Timestamp when courier departed store |
| `delivered_at` | TIMESTAMP | - | Yes | `NULL` | Timestamp when delivery was completed |

* **Relationships:**
  * Foreign key: `order_id` -> `orders(id)` ON DELETE CASCADE; UNIQUE constraint enforces 1:1.
  * Foreign key: `rider_id` -> `delivery_riders(id)`.
  * Foreign key: `zone_id` -> `delivery_zones(id)`.

---

### Table: `inventory_items`
* **Purpose:** Raw material and ingredient inventory ledger, tracking on-hand stock, reorder alert thresholds, measurement units, and cost per unit.
* **UI Source:** `features/stock/stock_screen.dart`, `domain/models/inventory_item.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `sku_code` | VARCHAR(50) | - | No | - | Unique stock SKU code (e.g. `'SKU-101'`); UNIQUE |
| `name` | VARCHAR(100) | - | No | - | Item name (e.g. `'Mozzarella Cheese'`) |
| `category` | VARCHAR(50) | - | No | `'General'` | Category (`'Dairy'`, `'Meat'`, `'Bakery'`, `'Produce'`, `'Packaging'`, etc.) |
| `initial_stock` | DECIMAL(10,2) | - | No | `0.00` | Baseline opening stock quantity |
| `used_stock` | DECIMAL(10,2) | - | No | `0.00` | Cumulative consumed quantity |
| `current_stock` | DECIMAL(10,2) | - | No | `0.00` | Current balance on hand |
| `min_threshold` | DECIMAL(10,2) | - | No | `10.00` | Minimum stock reorder trigger level |
| `unit` | VARCHAR(20) | - | No | `'kg'` | Measurement unit (`'kg'`, `'lbs'`, `'liters'`, `'units'`, `'boxes'`) |
| `cost_per_unit` | DECIMAL(10,2) | - | No | `0.00` | Cost price per unit in Rs |
| `supplier_name` | VARCHAR(100) | - | No | `'Central Depot'` | Primary vendor or warehouse |
| `last_restocked_date` | TIMESTAMP | - | Yes | `NULL` | Timestamp of latest stock shipment |

* **Relationships:**
  * One-to-Many with `stock_movements` (`stock_movements.item_id` -> `inventory_items.id`).

---

### Table: `stock_movements`
* **Purpose:** Audit ledger recording all stock movements: shipments received, kitchen usage prep, spoiled wastage, and POS auto-deductions.
* **UI Source:** `features/stock/stock_in_out_screen.dart`, `domain/models/inventory_item.dart` (`StockMovement`)

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `item_id` | VARCHAR(36) | FK | No | - | Foreign key referencing `inventory_items(id)` |
| `item_name` | VARCHAR(100) | - | No | - | Snapshot item name at time of transaction |
| `movement_type` | VARCHAR(30) | - | No | - | `'stockIn'`, `'stockOut'`, `'wastage'`, `'saleAutoDeduction'` |
| `quantity` | DECIMAL(10,2) | - | No | - | Quantity adjusted (positive or negative) |
| `unit` | VARCHAR(20) | - | No | - | Unit of measurement |
| `reason` | VARCHAR(255) | - | No | - | Reason memo (e.g. `'Restock from supplier'`, `'Kitchen Prep'`, `'Damaged'`) |
| `timestamp` | TIMESTAMP | - | No | `CURRENT_TIMESTAMP` | Transaction timestamp |
| `cost_impact` | DECIMAL(10,2) | - | No | `0.00` | Financial impact in Rs (`quantity * cost_per_unit`) |

* **Relationships:**
  * Foreign key: `item_id` -> `inventory_items(id)`.

---

### Table: `expenses`
* **Purpose:** Tracks operational expenses with date filters, category classification, amount in Rs, and staff auditor attribution.
* **UI Source:** `features/expenses/expenses_screen.dart`, `domain/models/expense_model.dart`

| Column Name | Data Type | Key | Nullable | Default Value | Constraints & Description |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `id` | VARCHAR(36) | PK | No | - | Primary key (UUID) |
| `title` | VARCHAR(150) | - | No | - | Expense description (e.g. `'Store Electricity Bill'`) |
| `category` | VARCHAR(50) | - | No | - | Category: `'utilities'`, `'staffSalaries'`, `'stockPurchases'`, `'maintenance'`, `'marketing'`, `'miscellaneous'` |
| `amount` | DECIMAL(10,2) | - | No | - | Expense total in Rs |
| `date` | DATE | - | No | - | Incurred expense date |
| `recorded_by` | VARCHAR(100) | - | No | `'Store Manager'` | Staff user who entered the transaction |
| `note` | TEXT | - | No | `''` | Additional notes or receipt memo |

* **Relationships:**
  * Logical reference to `staff_members.full_name` or `staff_users.username` via `recorded_by`.

---

## 4. UI-to-Database Traceability Matrix

The table below confirms the 1:1 mapping between each Flutter screen/widget and its corresponding database entities:

| UI Screen & File Location | Primary Database Entities Involved | Key UI Interactions & Data Flows |
| :--- | :--- | :--- |
| **LoginScreen** (`features/auth/login_screen.dart`) | `staff_users` | Credential validation, password check, role routing |
| **PasswordManagementScreen** (`features/passwords/`) | `staff_users` | Add user, reset password, update role, delete user |
| **RightsScreen** (`features/rights/rights_screen.dart`) | `role_permissions` | View/toggle role rights, sensitive action warnings, preset reset |
| **StaffScreen** (`features/staff/staff_screen.dart`) | `staff_members`, `staff_users` | Add employee, duty clock-in toggle, settle salary payslip |
| **CustomersScreen** (`features/customers/`) | `customers`, `orders` | Customer search, birthday badge, loyalty points accumulation |
| **TablesScreen** (`features/tables/tables_screen.dart`)| `restaurant_tables`, `orders` | Floor plan view, table seating, status change, bill viewing |
| **MenuScreen** (`features/menu/menu_screen.dart`) | `menu_categories`, `menu_items`, `menu_item_sizes`, `menu_item_options`, `deals`, `deal_components` | Product browsing, category filtering, deals showcase, size/crust customizer |
| **PosScreen** (`features/pos/pos_screen.dart`) | `orders`, `order_items`, `restaurant_tables`, `customers`, `menu_items` | Cart management, hold orders, KOT print, dine-in bill settlement |
| **TakeawayScreen** (`features/takeaway/`) | `orders`, `order_items` | Token generation, pickup status updates, counter cashout |
| **OnlineOrdersScreen** (`features/online_orders/`) | `orders`, `order_items`, `delivery_dispatches` | Online order acceptance/rejection, cooking timer, dispatch creation |
| **DeliveryScreen** (`features/delivery/`) | `delivery_dispatches`, `delivery_riders`, `delivery_zones`, `orders` | Rider assignment, zone routing, transit status tracking, rider ratings |
| **StockScreen** (`features/stock/stock_screen.dart`)| `inventory_items` | Stock balance table, low-stock threshold alerts, restock dates |
| **StockInOutScreen** (`features/stock/stock_in_out_screen.dart`) | `stock_movements`, `inventory_items` | Manual stock in/out adjustments, wastage recording, cost calculation |
| **ExpensesScreen** (`features/expenses/`) | `expenses` | Expense log, date range filters, P&L category aggregation |
| **SettingsScreen** (`features/settings/`) | `store_settings` | Branch details update, tax rate & service charge rate editing |
| **KitchenScreen** (`features/kitchen/kitchen_screen.dart`) | `orders`, `order_items` | Real-time KDS display, order status workflow (preparing, ready, served) |
| **ReportsScreen** (`features/reports/reports_screen.dart`) | `orders`, `order_items`, `expenses` | Executive sales reports, product sales rankings, profit aggregations |

---

## 5. Architectural & Design Decisions

1. **Unified `orders` Entity:**
   * Takeaway orders, Dine-In orders, Direct Deliveries, and Online Orders share identical invoicing rules, tax and service calculations, line items, and kitchen preparation workflows.
   * Rather than maintaining redundant `takeaway_orders`, `online_orders`, and `pos_orders` tables, a single `orders` table with discriminators (`order_type` and `order_source`) prevents schema fragmentation while preserving variant-specific attributes (such as `token_number` and `rejection_reason`).

2. **Decoupled Delivery Dispatch:**
   * Delivery workflows (courier assignment, zone allocation, dispatch transit stages) are separated into `delivery_dispatches`. This isolates delivery telemetry from dine-in or takeaway transactions, maintaining a clean 1:1 relationship between an order and its optional delivery tracking record.

3. **Multi-Size Variant & Customization Hierarchy:**
   * Instead of flattening all sizes and toppings into text strings inside `menu_items`, `menu_item_sizes` and `menu_item_options` provide normalized price tiers. When an order is placed, line items in `order_items` capture an immutable price snapshot (`unit_price`, `total_price`, `selected_size`, `selected_crust`, `extra_toppings`) to ensure historical accounting integrity even if catalog prices change later.

4. **KDS & Reporting Derived from Core Transactions:**
   * The Kitchen Display System (KDS) and Sales Reports screens do not require separate database tables. The KDS queries active records from `orders` and `order_items` based on order status, while Reports perform real-time aggregations directly against completed orders and expenses.
