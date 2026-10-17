# Hungry Howie's POS — Database Tables & Storage Guide

This document describes all tables present in the database, their purpose, and exactly what data is stored in each table.

---

## 1. Store & Configuration

### `store_settings`
- **Purpose:** Stores singleton branch and restaurant configuration.
- **What is stored:**
  - Restaurant chain name (`chain_name`, e.g., "Hungry Howie's")
  - Branch identifier code (`branch_code`, e.g., "Branch #402")
  - Branch location address (`branch_name`, e.g., "Near UOG Gate # 2...")
  - Official store phone number (`store_phone`)
  - Last configuration update timestamp

---

## 2. Authentication & Authorization

### `staff_users`
- **Purpose:** Stores login credentials for all staff members who access the POS system.
- **What is stored:**
  - Login username (`username`)
  - Encrypted password hash (`password_hash`) and plain text fallback (`plain_password`)
  - Assigned user role (`role`: `admin`, `manager`, `cashier`, `kitchen`, `rider`)
  - Default account flag (`is_default`)
  - Audit fields (`last_updated`, `updated_by`)

### `role_permissions`
- **Purpose:** Role-Based Access Control (RBAC) permission matrix.
- **What is stored:**
  - Target role (`role`: `Admin`, `Manager`, `Cashier`, `Kitchen`, `Rider`)
  - Target system module (`module_name`: POS, Orders, Menu, Tables, Inventory, HR, Reports, etc.)
  - Specific action name (`action_name`: create, view, edit, delete, refund, print)
  - Permission status (`is_granted`: true/false)
  - Sensitivity flag (`is_sensitive`) and human description

---

## 3. Human Resources & Payroll

### `staff_members`
- **Purpose:** Complete HR employee profile for restaurant staff.
- **What is stored:**
  - Link to system login user account (`user_id`)
  - Full name (`full_name`) and phone number (`phone`)
  - Designation/Role (`role`)
  - Employment status (`status`: Active, On Leave, Inactive)
  - Joining date (`joining_date`) and assigned work shift (`assigned_shift`)
  - Monthly base salary (`monthly_salary`) and hourly wage rate (`hourly_rate`)
  - Current month salary disbursement status (`is_salary_paid`, `salary_paid_date`)

### `payslips`
- **Purpose:** Historical monthly payroll payment vouchers and salary slips.
- **What is stored:**
  - Link to staff member (`staff_id`)
  - Month and year cycle (`month_year`, e.g., "October 2026")
  - Base salary and calculated net pay (`base_salary`, `net_pay`)
  - Payment status (`status`: Pending, Paid) and date paid (`paid_at`)

---

## 4. Customers & Loyalty (CRM)

### `customers`
- **Purpose:** Customer relationship directory and loyalty tracking.
- **What is stored:**
  - Full name (`full_name`), phone number (`phone`), email, and delivery address
  - Date of birth (`birth_date`)
  - Accumulated loyalty rewards points (`loyalty_points`)
  - Lifetime statistics: total number of orders placed (`total_orders_count`) and total money spent (`total_spent`)
  - Special preferences or allergy notes (`special_notes`)

---

## 5. Restaurant Floor Plan & Tables

### `floor_zones`
- **Purpose:** Floor areas or dining sections inside the restaurant.
- **What is stored:**
  - Zone / Section name (`name`, e.g., "Ground Floor", "First Floor", "Outdoor Terrace", "VIP Lounge")

### `restaurant_tables`
- **Purpose:** Physical dine-in tables and their real-time seating states.
- **What is stored:**
  - Table number code (`table_number`, e.g., "T-01", "T-12") and display name (`name`)
  - Guest seating capacity (`capacity`)
  - Link to floor zone (`zone_id`) and section name
  - Real-time status (`status`: `available`, `occupied`, `reserved`, `billed`)
  - Seated guest headcount (`current_customer_count`)
  - Running unpaid bill amount (`current_bill_amount`)
  - Occupancy start timestamp (`occupied_since`)
  - Currently active order ID (`active_order_id`)
  - Customer reservation name and scheduled arrival time (`reserved_customer_name`, `reservation_time`)

---

## 6. Menu Catalog, Pricing & Deals

### `menu_categories`
- **Purpose:** Food and beverage category classifications.
- **What is stored:**
  - Unique category ID (`id`, e.g., "pizza", "biryani", "burgers", "beverages")
  - Display name (`name`, e.g., "Pakistani Karahi", "Pizza", "Biryani")
  - Badge text (`badge_text`, e.g., "Karahi & Handi", "Exclusive")
  - Category cover image URL or local asset path (`image_path`)
  - Category description and Material icon identifier (`icon_name`)

### `menu_items`
- **Purpose:** Base food items and recipes available on the menu.
- **What is stored:**
  - Link to parent category (`category_id`)
  - Food item title (`name`) and detailed culinary description (`description`)
  - Default base price (`base_price`)
  - Product image path or image URL (`image_url`)
  - Dietary tags: Vegetarian (`is_veg`), Spicy (`is_spicy`)
  - Menu availability status (`is_available`: true/false)

### `menu_item_sizes`
- **Purpose:** Tiered portion sizes and price overrides for a menu item.
- **What is stored:**
  - Link to menu item (`menu_item_id`)
  - Size name (`size_name`, e.g., "Small", "Medium", "Large", "Half", "Full", "Single")
  - Price for this specific size (`price`)

### `menu_item_options`
- **Purpose:** Add-ons, crust selections, spice levels, and customizations.
- **What is stored:**
  - Link to menu item (`menu_item_id`)
  - Option category type (`option_type`, e.g., "Crust", "Flavor", "Dip", "Topping")
  - Option name (`option_name`, e.g., "Stuffed Crust", "Garlic Mayo Dip", "Extra Cheese")
  - Additional surcharge price (`additional_price`)

### `deals`
- **Purpose:** Fixed-price combo meals and promotional packages.
- **What is stored:**
  - Promotional deal title (`title`, e.g., "Couple Deal", "Family Feast")
  - Subtitle tagline (`subtitle`)
  - Bundle discounted price (`deal_price`) and original price before discount (`original_price`)
  - Badge text, deal image path, description, and availability status (`is_available`)

### `deal_components`
- **Purpose:** Items bundled inside a promotional deal.
- **What is stored:**
  - Link to parent deal (`deal_id`)
  - Item name (`item_name`, e.g., "1x Large Pizza", "2x 500ml Cold Drink")
  - Category name (`category`)
  - Quantity string (`quantity`, e.g., "1x", "2x")

---

## 7. Orders & Specific Order Channels

### `orders`
- **Purpose:** Master parent order record holding universal billing, kitchen state, and sync status.
- **What is stored:**
  - System order number (`order_number`, e.g., "ORD-1002")
  - Order type channel (`order_type`: `online`, `takeaway`, `dineIn`)
  - Current status (`status`: `newOrder`, `preparing`, `ready`, `dispatched`, `completed`, `cancelled`)
  - Universal financial ledger:
    - Subtotal (`subtotal`)
    - Discount percentage and amount (`discount_percentage`, `discount_amount`)
    - Sales tax (`tax_amount`)
    - Grand total bill (`grand_total`)
    - Payment status (`payment_status`: `UNPAID`, `PAID`, `PARTIAL`)
    - Paid flag (`is_paid`) and held order flag (`is_held`)
  - Kitchen lifecycle:
    - KOT printed/sent flag (`kitchen_ticket_sent`)
    - Cooking time estimate in minutes (`cooking_time_minutes`)
    - Estimated ready time (`estimated_ready_at`)
    - Order cancellation/rejection reason (`rejection_reason`)
  - Offline / Cloud Sync fields:
    - Synchronization status (`sync_status`: `synced`, `pending`, `failed`)
    - Local SQLite order ID and device terminal identifier (`local_sqlite_id`, `device_id`)
    - Date and time order was placed (`created_at`)

### `online_order_details`
- **Purpose:** 1-to-1 extension table for Delivery orders (POS delivery, Website, Mobile App).
- **What is stored:**
  - Foreign key to master order (`order_id`)
  - Ordering platform source (`order_source`: `POS`, `Website`, `MobileApp`)
  - Customer reference link (`customer_id`)
  - Customer name and contact number (`customer_name`, `customer_phone`)
  - Full drop-off delivery address (`delivery_address`)
  - Delivery charge (`delivery_fee`)

### `takeaway_order_details`
- **Purpose:** 1-to-1 extension table for Counter Pickup / Takeaway orders.
- **What is stored:**
  - Foreign key to master order (`order_id`)
  - Counter token number (`token_number`, e.g., "TK-05")
  - Optional customer reference link (`customer_id`)
  - Customer name (`customer_name`, default: "Walk-in Customer") and phone number (`customer_phone`)
  - Cashier name who punched the order (`served_by`)

### `dine_in_order_details`
- **Purpose:** 1-to-1 extension table for Table Dine-In service.
- **What is stored:**
  - Foreign key to master order (`order_id`)
  - Foreign key to assigned restaurant table (`table_id`)
  - Number of dining guests (`guest_count`)
  - Waiter or server assigned (`waiter_name`)
  - Dine-in specific service tax (`dine_in_tax`)

---

## 8. Line Items & Payments

### `order_items`
- **Purpose:** Individual dishes and beverages ordered in an order.
- **What is stored:**
  - Link to parent order (`order_id`)
  - Link to original menu item (`menu_item_id`)
  - Captured item name (`item_name`)
  - Order quantity (`quantity`)
  - Selected size (`selected_size`, e.g., "Large", "Regular")
  - Selected crust or cooking preference (`selected_crust`)
  - Extra toppings string (`extra_toppings`)
  - Price per unit (`unit_price`) and item line total (`total_price`)
  - Cooking instructions or customer notes (`notes`)
  - Item cancellation audit trail:
    - Cancelled flag (`is_cancelled`)
    - Timestamp (`cancelled_at`), reason (`cancel_reason`), and authorized staff (`cancelled_by`)

### `order_payments`
- **Purpose:** Multi-tender and split-payment transaction records.
- **What is stored:**
  - Link to parent order (`order_id`)
  - Payment method (`payment_method`: `cash`, `card`, `bankTransfer`, `other`)
  - Paid amount (`amount`)
  - Cash tendered and change returned (`tendered_amount`, `change_returned`)
  - Electronic transaction ID (`transaction_reference`)
  - Last 4 digits of card (`card_last_four`) and bank name (`bank_name`)
  - Settlement status (`payment_status`: `COMPLETED`, `REFUNDED`)
  - Cashier name who received the payment (`received_by`) and timestamp (`created_at`)

---

## 9. Delivery Fleet & Dispatches

### `delivery_riders`
- **Purpose:** Restaurant delivery rider fleet directory.
- **What is stored:**
  - Rider name (`name`) and phone number (`phone`)
  - On-duty shift status (`is_clocked_in`) and availability (`is_available`)
  - Current active deliveries count (`active_deliveries_count`)
  - Historical completed deliveries count (`total_completed_deliveries`)
  - Average trip duration (`avg_delivery_time_mins`) and customer rating (`rating`)

### `delivery_dispatches`
- **Purpose:** Real-time dispatch and trip tracking for delivery orders.
- **What is stored:**
  - Link to online order detail (`online_order_detail_id`)
  - Assigned rider link (`rider_id`)
  - Dispatch progress status (`dispatch_status`: `pending`, `assigned`, `on_the_way`, `delivered`, `failed`)
  - Target estimated delivery time (`estimated_delivery_time`)
  - Actual departure timestamp (`dispatched_at`)
  - Actual delivery completion timestamp (`delivered_at`)

---

## 10. Inventory & Stock Management

### `inventory_items`
- **Purpose:** Raw materials, food ingredients, packaging, and store supplies.
- **What is stored:**
  - Unique SKU code (`sku_code`, e.g., "ING-CHEESE-01")
  - Item name (`name`, e.g., "Mozzarella Cheese", "Pizza Boxes", "Chicken Breast")
  - Category (`category`, e.g., "Dairy", "Meat", "Packaging")
  - Initial stock, consumed stock, and real-time remaining stock (`initial_stock`, `used_stock`, `current_stock`)
  - Low stock warning threshold (`min_threshold`)
  - Unit of measurement (`unit`: kg, liters, packets, pieces)
  - Unit purchase cost (`cost_per_unit`)
  - Supplier vendor name (`supplier_name`)
  - Last purchase/restock date (`last_restocked_date`)

### `stock_movements`
- **Purpose:** Inventory transaction ledger and audit log.
- **What is stored:**
  - Link to inventory item (`item_id`) and item name (`item_name`)
  - Movement type (`movement_type`: `RESTOCK`, `CONSUMPTION`, `WASTAGE`, `RETURN`, `ADJUSTMENT`)
  - Quantity changed (`quantity`) and measurement unit (`unit`)
  - Reason / explanation (`reason`)
  - Financial cost impact (`cost_impact`)
  - Timestamp of movement (`timestamp`)

---

## 11. Store Expenses & Operating Costs

### `expenses`
- **Purpose:** General store operational expenses.
- **What is stored:**
  - Expense title (`title`, e.g., "Electricity Bill", "Kitchen Equipment Repair", "Cleaning Supplies")
  - Category classification (`category`, e.g., "Utilities", "Maintenance", "Supplies", "Marketing")
  - Amount in PKR (`amount`)
  - Date incurred (`date`)
  - Staff who recorded the expense (`recorded_by`)

---

## 12. Daily Calculations & Register Shift Closures

### `daily_calculations`
- **Purpose:** End-of-day register closure, cashier shift reconciliations, and cash skimming audit.
- **What is stored:**
  - Business date (`date`) and shift name (`shift_name`)
  - Cashier ID and cashier name (`cashier_id`, `cashier_name`)
  - Automated system totals:
    - Gross sales (`total_gross_sales`)
    - Cash sales (`total_cash_sales`), card sales (`total_card_sales`), and online sales (`total_online_sales`)
    - Total discounts given (`total_discounts`) and tax collected (`total_tax`)
    - Total orders breakdown: Dine-in count, Takeaway count, Online count (`total_orders_count`, `dine_in_count`, `takeaway_count`, `online_count`)
  - Cash drawer ledger:
    - Opening float / Starting change cash (`opening_float`, `starting_cash`, `total_change_cash`)
    - Cash submitted by cashier (`cash_submitted`, `total_cash`)
    - Skimmed cash dropped into safe (`cash_skimming`)
    - Shift cash expenses paid out (`total_cash_expenses`)
  - Cash variance calculation:
    - Expected cash in drawer (`expected_cash_in_hand`)
    - Shortage or excess variance (`variance_amount`)
  - Register status (`status`: `ACTIVE`, `CLOSED`) and manager closing notes (`closing_notes`)

### `daily_expense_items`
- **Purpose:** Line-item receipts for cash paid out directly from the register drawer during a shift.
- **What is stored:**
  - Link to daily calculation record (`calculation_id`)
  - Expense description (`item_name`, e.g., "Ice bag purchase", "Bike fuel")
  - Category (`category`)
  - Cash amount paid (`amount`)
  - Vendor receipt voucher number (`receipt_number`)
  - Additional notes and timestamp (`notes`, `created_at`)

---

## 13. Data Synchronization & Offline Resilience

### `data_sync_logs`
- **Purpose:** Audit log tracking bi-directional synchronization between local offline SQLite and cloud PostgreSQL.
- **What is stored:**
  - Reference order ID and number (`order_id`, `order_number`)
  - Synchronization entity type (`sync_type`: `ORDER`, `EXPENSE`, `TABLE`, `INVENTORY`)
  - Sync status (`sync_status`: `synced`, `pending`, `failed`)
  - Origin database (`source_storage`: "SQLite Local") and destination database (`target_storage`: "PostgreSQL Cloud")
  - POS terminal hardware ID (`device_id`)
  - Timestamp of sync (`synced_at`, `created_at`)
  - Error diagnostic details if sync failed (`error_message`)
  - Complete JSON snapshot of synced payload (`payload_json`)
