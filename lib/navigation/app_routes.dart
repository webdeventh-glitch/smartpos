/// Strongly-typed application routes replacing magic integer indices across
/// `MainShell`, `SmartSidebar`, `DashboardScreen`, and `BusinessModulesHubScreen`.
enum AppRoute {
  dashboard(0, '/dashboard', 'Dashboard'),
  posTerminal(1, '/pos', 'POS Terminal'),
  productsList(2, '/products', 'Products'),
  categories(3, '/categories', 'Categories'),
  salesList(4, '/sales', 'Sales'),
  purchasesList(5, '/purchases', 'Purchases'),
  customers(6, '/customers', 'Customers'),
  suppliers(7, '/suppliers', 'Suppliers'),
  expenses(8, '/expenses', 'Expenses'),
  reports(9, '/reports', 'Reports'),
  settings(10, '/settings', 'Settings'),
  addProduct(11, '/products/add', 'Add Product'),
  userManagement(12, '/users', 'User Management'),
  stockTransfers(13, '/stock-transfers', 'Stock Transfers'),
  stockAdjustments(14, '/stock-adjustments', 'Stock Adjustments'),
  paymentAccounts(15, '/payment-accounts', 'Payment Accounts'),
  notificationTemplates(16, '/notifications', 'Notification Templates'),
  printLabels(17, '/print-labels', 'Print Labels'),
  variationTemplates(18, '/variations', 'Variations'),
  units(19, '/units', 'Units'),
  brands(20, '/brands', 'Brands'),
  warranties(21, '/warranties', 'Warranties'),
  sellingPriceGroups(22, '/selling-price-groups', 'Selling Price Groups'),
  importProducts(23, '/products/import', 'Import Products'),
  inventoryAudit(24, '/inventory-audit', 'Inventory Audit'),
  salesReturn(25, '/sales/return', 'Sales Return'),
  purchaseReturn(26, '/purchases/return', 'Purchase Return'),
  annualClosing(27, '/annual-closing', 'Annual Closing'),
  businessModulesHub(28, '/modules', 'Business Modules'),
  restaurantCafe(29, '/modules/restaurant', 'Restaurant & Cafe'),
  repairService(30, '/modules/repair', 'Repair & Service'),
  hotelManagement(31, '/modules/hotel', 'Hotel Management'),
  gymFitness(32, '/modules/gym', 'Gym & Fitness'),
  manufacturing(33, '/modules/manufacturing', 'Manufacturing'),
  wooCommerceSync(34, '/modules/woocommerce', 'WooCommerce Sync'),
  hrmEmployee(35, '/modules/hrm', 'HRM & Employees'),
  accountingCrm(36, '/modules/accounting-crm', 'Accounting & CRM'),
  fruitMandi(37, '/modules/fruit-mandi', 'Fruit & Vegetable Mandi'),
  poultryBusiness(38, '/modules/poultry', 'Poultry Business'),
  moduleSettings(39, '/modules/settings', 'Module Settings'),
  cloudSync(40, '/cloud-sync', 'Cloud Sync'),
  addPurchase(41, '/purchases/add', 'Add Purchase'),
  salesOrders(42, '/sales/orders', 'Sales Orders'),
  purchaseOrders(43, '/purchases/orders', 'Purchase Orders'),
  chequeManagement(44, '/cheques', 'Cheques'),
  commissionAgents(45, '/commission-agents', 'Commission Agents'),
  discountRules(46, '/discounts', 'Discount Rules');

  final int tabIndex;
  final String routePath;
  final String label;

  const AppRoute(this.tabIndex, this.routePath, this.label);

  /// Look up a typed route by its legacy integer index; defaults to [dashboard].
  static AppRoute fromIndex(int index) {
    for (final route in values) {
      if (route.tabIndex == index) return route;
    }
    return AppRoute.dashboard;
  }

  /// Look up a typed route by its URL-style path; defaults to [dashboard].
  static AppRoute fromPath(String path) {
    final normalized = path.trim().toLowerCase();
    for (final route in values) {
      if (route.routePath.toLowerCase() == normalized) return route;
    }
    return AppRoute.dashboard;
  }

  /// Default landing workspace for the POS shortcut / F1 hotkey based on business type.
  static AppRoute defaultPosWorkspaceForBusinessType(String businessType) {
    switch (businessType) {
      case 'restaurant':
        return AppRoute.restaurantCafe;
      case 'repair':
        return AppRoute.repairService;
      case 'hotel':
        return AppRoute.hotelManagement;
      case 'gym':
        return AppRoute.gymFitness;
      default:
        return AppRoute.posTerminal;
    }
  }
}

