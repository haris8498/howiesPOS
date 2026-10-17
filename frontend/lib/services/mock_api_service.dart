import '../domain/models/menu_item.dart';
import '../domain/models/restaurant_table.dart';
import '../domain/models/inventory_item.dart';
import '../domain/models/staff_model.dart';
import '../domain/models/customer_model.dart';
import '../domain/models/expense_model.dart';
import '../domain/models/delivery_model.dart';
import '../domain/models/user_role.dart';

class MockApiService {
  static List<MenuItem> getInitialMenuItems() {
    return const [
      // --- PIZZA CATEGORY ---
      MenuItem(
        id: 'p1',
        name: 'Howie Special Pizza',
        category: 'Pizza',
        description: 'Pepperoni, ham, mushrooms, green peppers & onions with Butter Cheese crust.',
        basePrice: 14.99,
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
        availableCrustsOrBuns: ['Original', 'Butter Cheese', 'Garlic Herb', 'Cajun', 'Ranch'],
      ),
      MenuItem(
        id: 'p2',
        name: 'Meat Eaters Pizza',
        category: 'Pizza',
        description: 'Loaded with pepperoni, ham, Italian sausage & ground beef with Cajun crust.',
        basePrice: 16.99,
        imageUrl: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?auto=format&fit=crop&w=400&q=80',
        isSpicy: true,
        availableCrustsOrBuns: ['Original', 'Butter Cheese', 'Cajun'],
      ),
      MenuItem(
        id: 'p3',
        name: 'Chicken Bacon Ranch Pizza',
        category: 'Pizza',
        description: 'Grilled chicken, bacon, mozzarella & creamy ranch sauce.',
        basePrice: 15.99,
        imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=400&q=80',
      ),

      // --- BURGERS CATEGORY ---
      MenuItem(
        id: 'b1',
        name: 'Howie Angus Cheeseburger',
        category: 'Burgers',
        description: '100% Angus beef patty, cheddar cheese, crisp lettuce & house sauce on toasted Sesame Bun.',
        basePrice: 11.49,
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80',
        availableSizes: ['Single Patty', 'Double Patty'],
        availableCrustsOrBuns: ['Sesame Bun', 'Brioche Bun', 'Gluten Free Bun'],
      ),
      MenuItem(
        id: 'b2',
        name: 'Spicy Buffalo Chicken Burger',
        category: 'Burgers',
        description: 'Crispy fried chicken breast dipped in buffalo hot sauce with cool mayo.',
        basePrice: 10.99,
        imageUrl: 'https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?auto=format&fit=crop&w=400&q=80',
        isSpicy: true,
        availableCrustsOrBuns: ['Brioche Bun', 'Sesame Bun'],
      ),

      // --- DEALS CATEGORY ---
      MenuItem(
        id: 'd0',
        name: 'EXCLUSIVE DEALS (Pizza+Biryani+Panini+Shakes+Bottle)',
        category: 'Deals',
        description: '1 Large Pizza + 1 Chicken Biryani + 1 Panini + 2 Ice Shakes + 1.5L Bottle.',
        basePrice: 2499.0,
        imageUrl: 'assets/images/image.jpg',
      ),
      MenuItem(
        id: 'd1',
        name: 'Family Feast Combo Deal',
        category: 'Deals',
        description: '2 Family Size Pizzas + 4 Crispy Dajjaj Broast + 1 Loaded Fries + 1.5L Coke Bottle.',
        basePrice: 3299.0,
        imageUrl: 'assets/images/Special.png',
      ),
      MenuItem(
        id: 'd2',
        name: 'Duo Craver Pack',
        category: 'Deals',
        description: '2 Gourmet Beef or Chicken Burgers + 1 Large Garlic Mayo Fries + 2 Cold Drinks.',
        basePrice: 1649.0,
        imageUrl: 'assets/images/beef_burger_hero.jpg',
      ),
      MenuItem(
        id: 'd3',
        name: 'Midnight Craving Deal',
        category: 'Deals',
        description: '1 Large Classic Pizza + 1 Cheesy Panini Sandwich + 2 Soft Drinks.',
        basePrice: 1999.0,
        imageUrl: 'assets/images/Pizza.png',
      ),
      MenuItem(
        id: 'd4',
        name: 'Student Saver Deal',
        category: 'Deals',
        description: '1 Zinger Burger + 1 Plain Fries + 1 Cold Drink.',
        basePrice: 749.0,
        imageUrl: 'assets/images/chicken_burger_hero.jpg',
      ),

      // --- FRIES CATEGORY ---
      MenuItem(
        id: 'f1',
        name: 'Crispy Seasoned Cajun Fries',
        category: 'Fries',
        description: 'Golden crispy French fries coated in signature Cajun seasoning.',
        basePrice: 4.99,
        imageUrl: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=400&q=80',
        isVeg: true,
        isSpicy: true,
      ),

      // --- DRINKS CATEGORY ---
      MenuItem(
        id: 'dr1',
        name: '2L Cold Pepsi Bottle',
        category: 'Drinks',
        description: 'Ice cold 2-Liter Pepsi Cola bottle.',
        basePrice: 3.99,
        imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=400&q=80',
        isVeg: true,
      ),

      // --- DESSERTS CATEGORY ---
      MenuItem(
        id: 'ds1',
        name: 'Cinnamon Howie Brownie Cookie',
        category: 'Desserts',
        description: 'Warm chocolate chip cookie topped with sweet cinnamon icing.',
        basePrice: 6.49,
        imageUrl: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=400&q=80',
        isVeg: true,
      ),

      // --- ADDONS CATEGORY ---
      MenuItem(
        id: 'ad1',
        name: 'Extra Mozzarella Cheese Dip',
        category: 'Addons',
        description: 'Creamy melted mozzarella garlic dipping sauce cup.',
        basePrice: 1.50,
        imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?auto=format&fit=crop&w=400&q=80',
        isVeg: true,
      ),
    ];
  }

  static List<RestaurantTable> getInitialTables() {
    return const [];
  }

  static List<InventoryItem> getInitialInventory() {
    final now = DateTime.now();
    return [
      // Pakistani Beverages & Soft Drinks
      InventoryItem(id: 'inv-1', skuCode: 'PK-DRK-01', name: 'Nestlé Pure Life Water Bottle 1.5L', category: 'Beverages', initialStock: 300.0, usedStock: 180.0, currentStock: 120.0, minThreshold: 50.0, unit: 'Bottles', costPerUnit: 120.0, supplierName: 'Nestlé Pakistan', lastRestockedDate: now.subtract(const Duration(days: 1))),
      InventoryItem(id: 'inv-2', skuCode: 'PK-DRK-02', name: 'Nestlé Pure Life Water Bottle 500ml', category: 'Beverages', initialStock: 500.0, usedStock: 320.0, currentStock: 180.0, minThreshold: 80.0, unit: 'Bottles', costPerUnit: 60.0, supplierName: 'Nestlé Pakistan', lastRestockedDate: now.subtract(const Duration(days: 1))),
      InventoryItem(id: 'inv-3', skuCode: 'PK-DRK-03', name: 'Pepsi Can 250ml', category: 'Beverages', initialStock: 400.0, usedStock: 260.0, currentStock: 140.0, minThreshold: 60.0, unit: 'Cans', costPerUnit: 90.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-4', skuCode: 'PK-DRK-04', name: 'Pepsi 1.5L Bottle', category: 'Beverages', initialStock: 250.0, usedStock: 190.0, currentStock: 60.0, minThreshold: 40.0, unit: 'Bottles', costPerUnit: 220.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-5', skuCode: 'PK-DRK-05', name: '7Up Can 250ml', category: 'Beverages', initialStock: 350.0, usedStock: 210.0, currentStock: 140.0, minThreshold: 50.0, unit: 'Cans', costPerUnit: 90.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-6', skuCode: 'PK-DRK-06', name: '7Up 1.5L Bottle', category: 'Beverages', initialStock: 200.0, usedStock: 155.0, currentStock: 45.0, minThreshold: 30.0, unit: 'Bottles', costPerUnit: 220.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 3))),
      InventoryItem(id: 'inv-7', skuCode: 'PK-DRK-07', name: 'Mirinda Can 250ml', category: 'Beverages', initialStock: 200.0, usedStock: 130.0, currentStock: 70.0, minThreshold: 30.0, unit: 'Cans', costPerUnit: 90.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 3))),
      InventoryItem(id: 'inv-8', skuCode: 'PK-DRK-08', name: 'Pakola Ice Cream Soda 1.5L', category: 'Beverages', initialStock: 150.0, usedStock: 110.0, currentStock: 40.0, minThreshold: 25.0, unit: 'Bottles', costPerUnit: 210.0, supplierName: 'Mehran Bottlers Pakistan', lastRestockedDate: now.subtract(const Duration(days: 4))),
      InventoryItem(id: 'inv-9', skuCode: 'PK-DRK-09', name: 'Mountain Dew 1.5L Bottle', category: 'Beverages', initialStock: 180.0, usedStock: 145.0, currentStock: 35.0, minThreshold: 40.0, unit: 'Bottles', costPerUnit: 220.0, supplierName: 'PepsiCola PBG Pakistan', lastRestockedDate: now.subtract(const Duration(days: 2))),
      
      // Dairy & Cheese
      InventoryItem(id: 'inv-10', skuCode: 'PK-DRY-01', name: 'Mozzarella & Cheddar Cheese Blend', category: 'Dairy', initialStock: 100.0, usedStock: 75.0, currentStock: 25.0, minThreshold: 30.0, unit: 'kg', costPerUnit: 1650.0, supplierName: 'Adam’s Cheese Pakistan', lastRestockedDate: now.subtract(const Duration(days: 3))),
      InventoryItem(id: 'inv-11', skuCode: 'PK-DRY-02', name: 'Olper’s Milk 1L Pack', category: 'Dairy', initialStock: 120.0, usedStock: 80.0, currentStock: 40.0, minThreshold: 20.0, unit: 'Packs', costPerUnit: 290.0, supplierName: 'FrieslandCampina Engro', lastRestockedDate: now.subtract(const Duration(days: 1))),
      InventoryItem(id: 'inv-12', skuCode: 'PK-DRY-03', name: 'Nestlé MilkPak 1L', category: 'Dairy', initialStock: 100.0, usedStock: 65.0, currentStock: 35.0, minThreshold: 20.0, unit: 'Packs', costPerUnit: 295.0, supplierName: 'Nestlé Pakistan', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-13', skuCode: 'PK-DRY-04', name: 'Tarang Tea Whitener Pack', category: 'Dairy', initialStock: 80.0, usedStock: 50.0, currentStock: 30.0, minThreshold: 15.0, unit: 'Packs', costPerUnit: 180.0, supplierName: 'Engro Foods Pakistan', lastRestockedDate: now.subtract(const Duration(days: 4))),

      // Meats & Poultry
      InventoryItem(id: 'inv-14', skuCode: 'PK-MET-01', name: 'Fresh Boneless Chicken Breast', category: 'Poultry', initialStock: 150.0, usedStock: 110.0, currentStock: 40.0, minThreshold: 35.0, unit: 'kg', costPerUnit: 850.0, supplierName: 'K&N’s Poultry Farms', lastRestockedDate: now.subtract(const Duration(days: 1))),
      InventoryItem(id: 'inv-15', skuCode: 'PK-MET-02', name: 'Mutton Boneless Chunks', category: 'Meat', initialStock: 40.0, usedStock: 28.0, currentStock: 12.0, minThreshold: 15.0, unit: 'kg', costPerUnit: 2200.0, supplierName: 'Al-Fateh Meat Masters', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-16', skuCode: 'PK-MET-03', name: 'Fresh Beef Mince / Keema', category: 'Meat', initialStock: 60.0, usedStock: 42.0, currentStock: 18.0, minThreshold: 20.0, unit: 'kg', costPerUnit: 1400.0, supplierName: 'Al-Fateh Meat Masters', lastRestockedDate: now.subtract(const Duration(days: 2))),

      // Sauces & Condiments
      InventoryItem(id: 'inv-17', skuCode: 'PK-CND-01', name: 'Shangrila Tomato Ketchup 5kg Pouch', category: 'Sauces', initialStock: 50.0, usedStock: 30.0, currentStock: 20.0, minThreshold: 10.0, unit: 'Pouches', costPerUnit: 1250.0, supplierName: 'Shangrila Foods Pakistan', lastRestockedDate: now.subtract(const Duration(days: 5))),
      InventoryItem(id: 'inv-18', skuCode: 'PK-CND-02', name: 'Young’s Mayonnaise 5L Bucket', category: 'Sauces', initialStock: 40.0, usedStock: 25.0, currentStock: 15.0, minThreshold: 8.0, unit: 'Buckets', costPerUnit: 2450.0, supplierName: 'Young’s Food Products', lastRestockedDate: now.subtract(const Duration(days: 4))),
      InventoryItem(id: 'inv-19', skuCode: 'PK-CND-03', name: 'Garlic Mayo Dip Sauce', category: 'Sauces', initialStock: 30.0, usedStock: 18.0, currentStock: 12.0, minThreshold: 5.0, unit: 'Liters', costPerUnit: 680.0, supplierName: 'Howie House Kitchen', lastRestockedDate: now.subtract(const Duration(days: 2))),
      InventoryItem(id: 'inv-20', skuCode: 'PK-CND-04', name: 'Mint & Podina Chutney Paste', category: 'Sauces', initialStock: 25.0, usedStock: 15.0, currentStock: 10.0, minThreshold: 5.0, unit: 'kg', costPerUnit: 320.0, supplierName: 'Howie House Kitchen', lastRestockedDate: now.subtract(const Duration(days: 1))),

      // Spices & Flour / Grains
      InventoryItem(id: 'inv-21', skuCode: 'PK-SPC-01', name: 'National Tikka Boti Masala Pack', category: 'Spices', initialStock: 100.0, usedStock: 60.0, currentStock: 40.0, minThreshold: 15.0, unit: 'Packets', costPerUnit: 160.0, supplierName: 'National Foods Pakistan', lastRestockedDate: now.subtract(const Duration(days: 6))),
      InventoryItem(id: 'inv-22', skuCode: 'PK-SPC-02', name: 'Shan Special Biryani Masala Box', category: 'Spices', initialStock: 100.0, usedStock: 70.0, currentStock: 30.0, minThreshold: 15.0, unit: 'Boxes', costPerUnit: 180.0, supplierName: 'Shan Foods Pakistan', lastRestockedDate: now.subtract(const Duration(days: 6))),
      InventoryItem(id: 'inv-23', skuCode: 'PK-GRI-01', name: 'Fine Wheat Maida Flour', category: 'Grains', initialStock: 250.0, usedStock: 160.0, currentStock: 90.0, minThreshold: 40.0, unit: 'kg', costPerUnit: 140.0, supplierName: 'Punjab Flour Mills', lastRestockedDate: now.subtract(const Duration(days: 3))),
      InventoryItem(id: 'inv-24', skuCode: 'PK-GRI-02', name: 'Super Kernel Basmati Rice', category: 'Grains', initialStock: 200.0, usedStock: 130.0, currentStock: 70.0, minThreshold: 30.0, unit: 'kg', costPerUnit: 340.0, supplierName: 'Guard Basmati Rice', lastRestockedDate: now.subtract(const Duration(days: 5))),
      InventoryItem(id: 'inv-25', skuCode: 'PK-OIL-01', name: 'Dalda Cooking Oil 5L Tin', category: 'Oil & Ghee', initialStock: 30.0, usedStock: 18.0, currentStock: 12.0, minThreshold: 5.0, unit: 'Tins', costPerUnit: 2650.0, supplierName: 'Dalda Foods Pakistan', lastRestockedDate: now.subtract(const Duration(days: 4))),
      InventoryItem(id: 'inv-26', skuCode: 'PK-BEV-01', name: 'Tapal Danedar Tea 950g Pack', category: 'Tea & Coffee', initialStock: 40.0, usedStock: 25.0, currentStock: 15.0, minThreshold: 6.0, unit: 'Packs', costPerUnit: 1550.0, supplierName: 'Tapal Tea Pakistan', lastRestockedDate: now.subtract(const Duration(days: 7))),

      // Packaging & Disposables
      InventoryItem(id: 'inv-27', skuCode: 'PK-PKG-01', name: 'Disposable Chai Cups 250ml (100s)', category: 'Packaging', initialStock: 60.0, usedStock: 35.0, currentStock: 25.0, minThreshold: 10.0, unit: 'Packs', costPerUnit: 450.0, supplierName: 'PackPro Pakistan', lastRestockedDate: now.subtract(const Duration(days: 5))),
      InventoryItem(id: 'inv-28', skuCode: 'PK-PKG-02', name: 'Kraft Takeaway Paper Bags (500s)', category: 'Packaging', initialStock: 20.0, usedStock: 12.0, currentStock: 8.0, minThreshold: 3.0, unit: 'Bundles', costPerUnit: 1800.0, supplierName: 'PackPro Pakistan', lastRestockedDate: now.subtract(const Duration(days: 7))),
    ];
  }

  static List<StaffMember> getInitialStaff() {
    return [
      StaffMember(id: 'st-1', fullName: 'Alexander Pierce', phone: '+92 300 555 0199', role: UserRole.owner, hourlyRate: 45.00, assignedShift: 'Full Day Executive Shift', monthlySalary: 250000.0, isSalaryPaid: true, salaryPaidDate: DateTime.now(), status: 'Active', joiningDate: '15 Jan 2022'),
      StaffMember(id: 'st-2', fullName: 'Marcus Vance', phone: '+92 300 555 0144', role: UserRole.manager, hourlyRate: 28.50, assignedShift: 'Morning Opening Shift', monthlySalary: 120000.0, isSalaryPaid: true, salaryPaidDate: DateTime.now(), status: 'Active', joiningDate: '01 Mar 2023'),
      StaffMember(id: 'st-3', fullName: 'Elena Rostova', phone: '+92 300 555 0188', role: UserRole.cashier, hourlyRate: 16.50, assignedShift: 'Peak Evening Shift', monthlySalary: 65000.0, isSalaryPaid: true, salaryPaidDate: DateTime.now(), status: 'Active', joiningDate: '10 Jun 2023'),
      StaffMember(id: 'st-4', fullName: 'Tariq Mahmood', phone: '+92 300 555 0211', role: UserRole.cashier, hourlyRate: 22.00, assignedShift: 'Kitchen Grill & Fryer Shift', monthlySalary: 85000.0, isSalaryPaid: false, status: 'Active', joiningDate: '05 Nov 2023'),
      StaffMember(id: 'st-5', fullName: 'Dave Speedster', phone: '+92 300 555 0912', role: UserRole.cashier, hourlyRate: 15.00, assignedShift: 'Delivery Dispatch Duty', monthlySalary: 50000.0, isSalaryPaid: false, status: 'Active', joiningDate: '12 Jan 2024'),
      StaffMember(id: 'st-6', fullName: 'Chris Rider', phone: '+92 300 555 0345', role: UserRole.cashier, hourlyRate: 14.50, assignedShift: 'Night Delivery Dispatch', monthlySalary: 45000.0, isSalaryPaid: true, salaryPaidDate: DateTime.now(), status: 'Active', joiningDate: '20 Feb 2024'),
      StaffMember(id: 'st-7', fullName: 'Sarah Jenkins', phone: '+92 300 555 0411', role: UserRole.cashier, hourlyRate: 13.00, assignedShift: 'Morning Dough Prep', monthlySalary: 40000.0, isSalaryPaid: false, status: 'Active', joiningDate: '01 Apr 2024'),
    ];
  }

  static List<StockMovement> getInitialMovements() {
    final now = DateTime.now();
    return [
      StockMovement(id: 'm-1', itemId: 'inv-1', itemName: 'Nestlé Pure Life Water Bottle 1.5L', type: StockMovementType.stockIn, quantity: 300, unit: 'Bottles', reason: 'Initial Inward Restock', timestamp: now.subtract(const Duration(days: 1)), costImpact: 36000),
      StockMovement(id: 'm-2', itemId: 'inv-3', itemName: 'Pepsi Can 250ml', type: StockMovementType.stockIn, quantity: 400, unit: 'Cans', reason: 'Beverage Shipment Inward', timestamp: now.subtract(const Duration(days: 2)), costImpact: 36000),
      StockMovement(id: 'm-3', itemId: 'inv-10', itemName: 'Mozzarella & Cheddar Cheese Blend', type: StockMovementType.stockIn, quantity: 100, unit: 'kg', reason: 'Dairy Inward Restock', timestamp: now.subtract(const Duration(days: 3)), costImpact: 165000),
      StockMovement(id: 'm-4', itemId: 'inv-14', itemName: 'Fresh Boneless Chicken Breast', type: StockMovementType.stockIn, quantity: 150, unit: 'kg', reason: 'Poultry Inward Arrival', timestamp: now.subtract(const Duration(days: 1)), costImpact: 127500),
      StockMovement(id: 'm-5', itemId: 'inv-4', itemName: 'Pepsi 1.5L Bottle', type: StockMovementType.stockOut, quantity: 40, unit: 'Bottles', reason: 'Counter / Takeaway Sale Usage', timestamp: now.subtract(const Duration(hours: 5)), costImpact: 8800),
      StockMovement(id: 'm-6', itemId: 'inv-8', itemName: 'Pakola Ice Cream Soda 1.5L', type: StockMovementType.wastage, quantity: 5, unit: 'Bottles', reason: 'Leaked / Damaged Cap', timestamp: now.subtract(const Duration(hours: 8)), costImpact: 1050),
    ];
  }

  static List<CustomerModel> getInitialCustomers() {
    return [
      CustomerModel(id: 'c1', fullName: 'Robert Miller', phone: '+1 (555) 234-5678', email: 'robert.m@gmail.com', loyaltyPoints: 340, totalOrdersCount: 18, totalSpent: 412.50, address: '742 Evergreen Terrace, Branchville'),
      CustomerModel(id: 'c2', fullName: 'Sophia Martinez', phone: '+1 (555) 876-5432', email: 'sophia.m@yahoo.com', loyaltyPoints: 890, totalOrdersCount: 42, totalSpent: 980.00, birthDate: DateTime.now(), address: '124 Conch Street, Metroville'),
    ];
  }

  static List<ExpenseRecord> getInitialExpenses() {
    final now = DateTime.now();
    return [
      ExpenseRecord(id: 'ex-1', title: 'Daily Staff Lunch Payout', category: ExpenseCategory.staffSalaries, amount: 450.0, date: now, recordedBy: 'Store Manager'),
      ExpenseRecord(id: 'ex-2', title: 'Urgent Bakery Yeast & Flour Restock', category: ExpenseCategory.stockPurchases, amount: 1440.0, date: now, recordedBy: 'Alexander Pierce'),
      ExpenseRecord(id: 'ex-3', title: 'Monthly Branch Electricity Utility', category: ExpenseCategory.utilities, amount: 640.0, date: now.subtract(const Duration(days: 1)), recordedBy: 'Marcus Vance'),
      ExpenseRecord(id: 'ex-4', title: 'Weekly Cheese & Sauce Outflow', category: ExpenseCategory.stockPurchases, amount: 1250.0, date: now.subtract(const Duration(days: 2)), recordedBy: 'Alexander Pierce'),
    ];
  }

  static List<DeliveryOrder> getInitialDeliveries() {
    return const [];
  }
}
