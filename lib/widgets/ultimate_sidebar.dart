import 'package:flutter/material.dart';
import '../models/models.dart';

class SmartSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isCollapsed;
  final BusinessSettings? settings;

  const SmartSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.isCollapsed,
    this.settings,
  });

  @override
  State<SmartSidebar> createState() => _SmartSidebarState();
}

/// Backward compatibility alias
typedef UltimateSidebar = SmartSidebar;

class _SmartSidebarState extends State<SmartSidebar> {
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _filter = '';

  // Expandable sections
  bool _productsExpanded = false;
  bool _sellExpanded = false;
  bool _industryExpanded = false;

  bool _isModEnabled(String key) {
    if (widget.settings == null) return true;
    return widget.settings!.isModuleEnabled(key);
  }

  @override
  void dispose() {
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  Widget _navItem({
    required IconData icon,
    required String title,
    required int index,
    bool hasSubmenu = false,
    bool isExpanded = false,
    VoidCallback? onToggleSubmenu,
  }) {
    if (_filter.isNotEmpty && !title.toLowerCase().contains(_filter)) {
      return const SizedBox.shrink();
    }
    final isSelected = widget.selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Tooltip(
          message: title,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => widget.onSelect(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (hasSubmenu && onToggleSubmenu != null) {
              onToggleSubmenu();
              widget.onSelect(index);
            } else {
              widget.onSelect(index);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? const Color(0xFFE0E7FF) : const Color(0xFF4F46E5))
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ),
                ),
                if (hasSubmenu)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                    size: 16,
                    color: isSelected
                        ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subItem({required String title, required int index}) {
    if (_filter.isNotEmpty && !title.toLowerCase().contains(_filter)) {
      return const SizedBox.shrink();
    }
    final isSelected = widget.selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 10, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelect(index),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? const Color(0xFFE0E7FF) : const Color(0xFF4F46E5))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    if (widget.isCollapsed || _filter.isNotEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final s = widget.settings;
    if (s != null) {
      if (s.isRestaurant) return _buildRestaurantNavigation();
      if (s.isPharmacy) return _buildPharmacyNavigation();
      if (s.isSupermarket) return _buildSupermarketNavigation();
      if (s.isRepair) return _buildRepairNavigation();
      if (s.isHotel) return _buildHotelNavigation();
      if (s.isGym) return _buildGymNavigation();
    }
    return _buildDefaultModularNavigation();
  }

  List<Widget> _buildRestaurantNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('DINING & KITCHEN'),
      _navItem(icon: Icons.table_restaurant_rounded, title: 'Tables & Floor Plan', index: 29),
      _navItem(icon: Icons.soup_kitchen_rounded, title: 'Live KOT Queue', index: 29),
      _navItem(icon: Icons.receipt_outlined, title: 'Dining Orders & Bills', index: 4),
      if (_isModEnabled(BusinessSettings.moduleReturns))
        _navItem(icon: Icons.assignment_return_outlined, title: 'Order Voids & Returns', index: 25),

      _sectionHeader('MENU & RECIPES'),
      _navItem(
        icon: Icons.restaurant_menu_rounded,
        title: 'Menu Dishes',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'All Dishes', index: 2),
        _subItem(title: 'Add New Dish', index: 11),
        _subItem(title: 'Menu Categories', index: 3),
        _subItem(title: 'Price Groups / Portions', index: 22),
      ],
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Kitchen Raw Stock (Purchases)', index: 5),
      if (_isModEnabled(BusinessSettings.moduleStockTransfers))
        _navItem(icon: Icons.sync_alt_rounded, title: 'Stock Transfers', index: 13),
      _navItem(icon: Icons.tune_rounded, title: 'Stock Waste / Adjustment', index: 14),

      _sectionHeader('STAFF & MANAGEMENT'),
      _navItem(icon: Icons.badge_outlined, title: 'Waiters & Kitchen Staff', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Restaurant Expenses', index: 8),
      _navItem(icon: Icons.analytics_outlined, title: 'Sales & Revenue Reports', index: 9),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Restaurant Settings', index: 10),
    ];
  }

  List<Widget> _buildPharmacyNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('DISPENSING & SALES'),
      _navItem(
        icon: Icons.point_of_sale_outlined,
        title: 'Dispensing POS',
        index: 4,
        hasSubmenu: true,
        isExpanded: _sellExpanded,
        onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
      ),
      if (!widget.isCollapsed && _sellExpanded) ...[
        _subItem(title: 'Pharmacy Terminal (F1)', index: 1),
        _subItem(title: 'Sales & Wholesale Invoices', index: 4),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Medicine Returns', index: 25),
      ],

      _sectionHeader('MEDICINES & INVENTORY'),
      _navItem(
        icon: Icons.medication_outlined,
        title: 'Medicines',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'Medicines Catalog', index: 2),
        _subItem(title: 'Add Medicine', index: 11),
        _subItem(title: 'Salt Formulations', index: 3),
        _subItem(title: 'Pharma Companies / Brands', index: 20),
        _subItem(title: 'Print Expiry / Strip Labels', index: 17),
        _subItem(title: 'Units / Strip Packs', index: 19),
        _subItem(title: 'Price Groups (Trade/Retail)', index: 22),
      ],
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Medicine Purchases', index: 5),
      if (_isModEnabled(BusinessSettings.moduleReturns))
        _navItem(icon: Icons.keyboard_return_rounded, title: 'Purchase Returns (Debit)', index: 26),
      if (_isModEnabled(BusinessSettings.moduleStockAudit))
        _navItem(icon: Icons.fact_check_outlined, title: 'Batch & Expiry Audit', index: 24),
      if (_isModEnabled(BusinessSettings.moduleStockTransfers))
        _navItem(icon: Icons.sync_alt_rounded, title: 'Branch Stock Transfers', index: 13),
      _navItem(icon: Icons.tune_rounded, title: 'Stock Adjustments', index: 14),

      _sectionHeader('PHARMA NETWORK & FINANCE'),
      _navItem(icon: Icons.local_hospital_outlined, title: 'Pharmacies & Clinics (Clients)', index: 6),
      _navItem(icon: Icons.local_shipping_outlined, title: 'Distributors & Suppliers', index: 7),
      _navItem(icon: Icons.badge_outlined, title: 'Salesmen & Operators', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Agency Expenses', index: 8),
      _navItem(icon: Icons.account_balance_outlined, title: 'Payment Accounts', index: 15),
      _navItem(icon: Icons.analytics_outlined, title: 'Tax & Sales Reports', index: 9),
      if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
        _navItem(icon: Icons.account_balance_wallet_rounded, title: 'Annual Fiscal Closing', index: 27),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Pharmacy & Drug License Settings', index: 10),
    ];
  }

  List<Widget> _buildSupermarketNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('CHECKOUT & BILLING'),
      _navItem(
        icon: Icons.point_of_sale_outlined,
        title: 'Checkout Counter',
        index: 4,
        hasSubmenu: true,
        isExpanded: _sellExpanded,
        onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
      ),
      if (!widget.isCollapsed && _sellExpanded) ...[
        _subItem(title: 'Rapid Barcode POS (F1)', index: 1),
        _subItem(title: 'Cashier Sales Orders', index: 4),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Customer Returns', index: 25),
      ],

      _sectionHeader('GROCERY & INVENTORY'),
      _navItem(
        icon: Icons.inventory_2_outlined,
        title: 'FMCG Products',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'Products List', index: 2),
        _subItem(title: 'Add Product', index: 11),
        _subItem(title: 'Print Shelf Labels', index: 17),
        _subItem(title: 'Grocery Categories', index: 3),
        _subItem(title: 'FMCG Brands', index: 20),
        _subItem(title: 'Selling Price Groups', index: 22),
      ],
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Wholesale Purchases', index: 5),
      if (_isModEnabled(BusinessSettings.moduleStockTransfers))
        _navItem(icon: Icons.sync_alt_rounded, title: 'Stock Transfers', index: 13),
      _navItem(icon: Icons.tune_rounded, title: 'Stock Adjustments', index: 14),

      _sectionHeader('PEOPLE & FINANCE'),
      _navItem(icon: Icons.people_outline, title: 'Loyalty Customers', index: 6),
      _navItem(icon: Icons.local_shipping_outlined, title: 'Vendors & Suppliers', index: 7),
      _navItem(icon: Icons.badge_outlined, title: 'Cashiers & Staff', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Expenses', index: 8),
      _navItem(icon: Icons.analytics_outlined, title: 'Reports', index: 9),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Store Settings', index: 10),
    ];
  }

  List<Widget> _buildRepairNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('REPAIR OPERATIONS'),
      _navItem(icon: Icons.build_circle_outlined, title: 'Diagnostics & Job Sheets', index: 30),
      _navItem(icon: Icons.point_of_sale_outlined, title: 'Service Billing POS', index: 1),
      _navItem(icon: Icons.receipt_outlined, title: 'Invoices & Device History', index: 4),

      _sectionHeader('SPARE PARTS & STOCK'),
      _navItem(
        icon: Icons.inventory_2_outlined,
        title: 'Spare Parts',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'Parts List', index: 2),
        _subItem(title: 'Add Spare Part', index: 11),
        _subItem(title: 'Categories', index: 3),
      ],
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Parts Purchases', index: 5),

      _sectionHeader('PEOPLE & ACCOUNTS'),
      _navItem(icon: Icons.people_outline, title: 'Device Owners', index: 6),
      _navItem(icon: Icons.badge_outlined, title: 'Technicians', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Expenses', index: 8),
      _navItem(icon: Icons.analytics_outlined, title: 'Reports', index: 9),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Service Settings', index: 10),
    ];
  }

  List<Widget> _buildHotelNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('FRONT DESK & ROOMS'),
      _navItem(icon: Icons.hotel_rounded, title: 'Room Grid & Check-In', index: 31),
      _navItem(icon: Icons.room_service_outlined, title: 'Room Service Billing', index: 1),
      _navItem(icon: Icons.receipt_outlined, title: 'Folio Invoices & Billings', index: 4),

      _sectionHeader('AMENITIES & INVENTORY'),
      _navItem(icon: Icons.inventory_2_outlined, title: 'Amenities & Mini-Bar', index: 2),
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Hotel Purchases & Linen', index: 5),

      _sectionHeader('GUESTS & STAFF'),
      _navItem(icon: Icons.people_outline, title: 'Guests Register', index: 6),
      _navItem(icon: Icons.badge_outlined, title: 'Staff Management', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Hotel Expenses', index: 8),
      _navItem(icon: Icons.analytics_outlined, title: 'Occupancy Reports', index: 9),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Hotel Settings', index: 10),
    ];
  }

  List<Widget> _buildGymNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('MEMBERSHIP & CHECK-IN'),
      _navItem(icon: Icons.fitness_center_rounded, title: 'Member Directory & Biometrics', index: 32),
      _navItem(icon: Icons.point_of_sale_outlined, title: 'Supplements POS', index: 1),
      _navItem(icon: Icons.receipt_outlined, title: 'Dues & Subscription Billing', index: 4),

      _sectionHeader('SUPPLEMENTS & MERCHANDISE'),
      _navItem(icon: Icons.inventory_2_outlined, title: 'Supplements Catalog', index: 2),
      _navItem(icon: Icons.shopping_bag_outlined, title: 'Purchases & Supplies', index: 5),

      _sectionHeader('COACHES & ADMIN'),
      _navItem(icon: Icons.people_outline, title: 'Members', index: 6),
      _navItem(icon: Icons.badge_outlined, title: 'Coaches & Trainers', index: 12),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Gym Expenses', index: 8),
      _navItem(icon: Icons.analytics_outlined, title: 'Retention Reports', index: 9),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.settings_outlined, title: 'Gym Club Settings', index: 10),
    ];
  }

  List<Widget> _buildDefaultModularNavigation() {
    return [
      _sectionHeader('OVERVIEW'),
      _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

      _sectionHeader('INVENTORY & SALES'),
      _navItem(
        icon: Icons.inventory_2_outlined,
        title: 'Products',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'List Products', index: 2),
        _subItem(title: 'Add Product', index: 11),
        _subItem(title: 'Print Labels', index: 17),
        if (_isModEnabled(BusinessSettings.moduleVariations))
          _subItem(title: 'Variations', index: 18),
        _subItem(title: 'Import Products', index: 23),
        _subItem(title: 'Selling Price Group', index: 22),
        _subItem(title: 'Units', index: 19),
        _subItem(title: 'Categories', index: 3),
        _subItem(title: 'Brands', index: 20),
        _subItem(title: 'Warranties', index: 21),
      ],

      _navItem(
        icon: Icons.point_of_sale_outlined,
        title: 'Sell',
        index: 4,
        hasSubmenu: true,
        isExpanded: _sellExpanded,
        onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
      ),
      if (!widget.isCollapsed && _sellExpanded) ...[
        _subItem(title: 'POS Terminal (F1)', index: 1),
        _subItem(title: 'All Sales Orders', index: 4),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Sales Returns (Credit Notes)', index: 25),
      ],

      _navItem(icon: Icons.shopping_bag_outlined, title: 'Purchases', index: 5),
      if (_isModEnabled(BusinessSettings.moduleReturns))
        _navItem(icon: Icons.keyboard_return_rounded, title: 'Purchase Returns (Debit Notes)', index: 26),
      if (_isModEnabled(BusinessSettings.moduleStockAudit))
        _navItem(icon: Icons.fact_check_outlined, title: 'Stock & Expiry Audit', index: 24),
      if (_isModEnabled(BusinessSettings.moduleStockTransfers))
        _navItem(icon: Icons.sync_alt_rounded, title: 'Stock Transfers', index: 13),
      _navItem(icon: Icons.tune_rounded, title: 'Stock Adjustment', index: 14),

      if (widget.settings?.hasAnyIndustryModuleEnabled == true) ...[
        _sectionHeader('INDUSTRY MODULES'),
        _navItem(
          icon: Icons.hub_rounded,
          title: 'Industry Hub',
          index: 28,
          hasSubmenu: true,
          isExpanded: _industryExpanded,
          onToggleSubmenu: () => setState(() => _industryExpanded = !_industryExpanded),
        ),
        if (!widget.isCollapsed && _industryExpanded) ...[
          _subItem(title: 'All Modules Hub', index: 28),
          if (_isModEnabled(BusinessSettings.moduleRestaurant))
            _subItem(title: '️ Restaurant / Cafe', index: 29),
          if (_isModEnabled(BusinessSettings.moduleRepair))
            _subItem(title: 'Repair Shop / Service', index: 30),
          if (_isModEnabled(BusinessSettings.moduleHotel))
            _subItem(title: 'Hotel Management', index: 31),
          if (_isModEnabled(BusinessSettings.moduleGym))
            _subItem(title: '️ Gym & Fitness Center', index: 32),
          if (_isModEnabled(BusinessSettings.moduleManufacturing))
            _subItem(title: 'Manufacturing / BOM', index: 33),
          if (_isModEnabled(BusinessSettings.moduleWooCommerce))
            _subItem(title: 'Online Store (Woo)', index: 34),
          if (_isModEnabled(BusinessSettings.moduleHrm))
            _subItem(title: 'HR & Employee (Payroll)', index: 35),
          if (_isModEnabled(BusinessSettings.moduleAccountingCrm))
            _subItem(title: 'Accounting & Ledgers', index: 36),
          if (_isModEnabled(BusinessSettings.moduleFruitMandi))
            _subItem(title: 'Fruit Mandi (Arhat)', index: 37),
          if (_isModEnabled(BusinessSettings.modulePoultry))
            _subItem(title: 'Poultry Farm & Trading', index: 38),
        ],
      ],

      _sectionHeader('FINANCE & ACCOUNTS'),
      if (_isModEnabled(BusinessSettings.moduleExpenses))
        _navItem(icon: Icons.receipt_long_outlined, title: 'Expenses', index: 8),
      _navItem(icon: Icons.account_balance_outlined, title: 'Payment Accounts', index: 15),
      _navItem(icon: Icons.analytics_outlined, title: 'Reports', index: 9),
      if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
        _navItem(icon: Icons.account_balance_wallet_rounded, title: 'Annual Fiscal Closing', index: 27),

      _sectionHeader('PEOPLE & SETTINGS'),
      _navItem(icon: Icons.people_outline, title: 'Contacts', index: 6),
      _navItem(icon: Icons.badge_outlined, title: 'User Management', index: 12),
      _navItem(icon: Icons.notifications_none_outlined, title: 'Notification Templates', index: 16),
      _navItem(icon: Icons.dashboard_customize_outlined, title: 'Modular Features', index: 39),
      _navItem(icon: Icons.cloud_sync_outlined, title: 'Cloud & MySQL Sync', index: 40),
      _navItem(icon: Icons.settings_outlined, title: 'Settings', index: 10),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: widget.isCollapsed ? 64 : 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          // Search menu... input
          if (!widget.isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _menuSearchCtrl,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  onChanged: (val) => setState(() => _filter = val.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search menu...',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ),

          // Dynamic Menu Items List by Industry Persona
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _buildMenuItems(),
            ),
          ),
        ],
      ),
    );
  }
}
