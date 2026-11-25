import 'package:flutter/material.dart';
import '../models/models.dart';
import '../navigation/app_routes.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'about_developer_dialog.dart';

class SmartSidebar extends StatefulWidget {
  final AppRoute selectedRoute;
  final ValueChanged<AppRoute> onSelect;
  final bool isCollapsed;
  final BusinessSettings? settings;

  const SmartSidebar({
    super.key,
    required this.selectedRoute,
    required this.onSelect,
    required this.isCollapsed,
    this.settings,
  });

  @override
  State<SmartSidebar> createState() => _SmartSidebarState();
}

class _SmartSidebarState extends State<SmartSidebar> {
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _filter = '';

  // Expandable sections matching Smart POS structure
  bool _userMgmtExpanded = false;
  bool _contactsExpanded = false;
  bool _productsExpanded = false;
  bool _purchasesExpanded = false;
  bool _sellExpanded = false;
  bool _transfersExpanded = false;
  bool _adjustmentsExpanded = false;
  bool _expensesExpanded = false;
  bool _reportsExpanded = false;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncActiveSection(widget.selectedRoute);
  }

  @override
  void didUpdateWidget(SmartSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRoute != widget.selectedRoute) {
      _syncActiveSection(widget.selectedRoute);
    }
  }

  void _syncActiveSection(AppRoute route) {
    if (route == AppRoute.userManagement) {
      _userMgmtExpanded = true;
    } else if (route == AppRoute.customers || route == AppRoute.suppliers) {
      _contactsExpanded = true;
    } else if (const [
      AppRoute.productsList,
      AppRoute.categories,
      AppRoute.addProduct,
      AppRoute.printLabels,
      AppRoute.variationTemplates,
      AppRoute.units,
      AppRoute.brands,
      AppRoute.warranties,
      AppRoute.sellingPriceGroups,
      AppRoute.importProducts,
      AppRoute.discountRules
    ].contains(route)) {
      _productsExpanded = true;
    } else if (const [
      AppRoute.purchasesList,
      AppRoute.purchaseReturn,
      AppRoute.addPurchase,
      AppRoute.purchaseOrders
    ].contains(route)) {
      _purchasesExpanded = true;
    } else if (const [
      AppRoute.posTerminal,
      AppRoute.salesList,
      AppRoute.salesReturn,
      AppRoute.salesOrders,
      AppRoute.commissionAgents
    ].contains(route)) {
      _sellExpanded = true;
    } else if (route == AppRoute.stockTransfers) {
      _transfersExpanded = true;
    } else if (route == AppRoute.stockAdjustments) {
      _adjustmentsExpanded = true;
    } else if (route == AppRoute.expenses) {
      _expensesExpanded = true;
    } else if (const [AppRoute.reports, AppRoute.inventoryAudit]
        .contains(route)) {
      _reportsExpanded = true;
    } else if (const [
      AppRoute.settings,
      AppRoute.paymentAccounts,
      AppRoute.chequeManagement,
      AppRoute.annualClosing,
      AppRoute.moduleSettings,
      AppRoute.cloudSync
    ].contains(route)) {
      _settingsExpanded = true;
    }
  }

  bool _isModEnabled(String key) {
    if (widget.settings == null) return true;
    final s = widget.settings!;
    if (s.isConfigured && !s.isModuleAllowedForInstalledBusiness(key)) {
      return false;
    }
    return s.isModuleEnabled(key);
  }

  @override
  void dispose() {
    _menuSearchCtrl.dispose();
    super.dispose();
  }

  Widget _sectionHeader(String title) {
    if (widget.isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      );
    }
    if (_filter.isNotEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localized =
        PosLocalization.trPrimary(title, settings: widget.settings);
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 12, top: 16, bottom: 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              localized.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.6)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayTitle(String title) =>
      PosLocalization.trPrimary(title, settings: widget.settings);

  String? _getLocalizedSubtitle(String title) =>
      PosLocalization.trSecondary(title, settings: widget.settings);

  Widget _navItem({
    required IconData icon,
    required String title,
    required AppRoute route,
    bool hasSubmenu = false,
    bool isExpanded = false,
    bool isActiveParent = false,
    String? badgeText,
    Color? badgeColor,
    VoidCallback? onToggleSubmenu,
    VoidCallback? onTapDirect,
  }) {
    final displayTitle = _getDisplayTitle(title);
    final activeSubtitle = _getLocalizedSubtitle(title);
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        displayTitle.toLowerCase().contains(_filter) ||
        (activeSubtitle != null &&
            activeSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.selectedRoute == route || isActiveParent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeIcon =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final inactiveIcon =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Tooltip(
          message: activeSubtitle != null && activeSubtitle.isNotEmpty
              ? '$title ($activeSubtitle)'
              : title,
          preferBelow: false,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (hasSubmenu && onToggleSubmenu != null) {
                  onToggleSubmenu();
                }
                if (onTapDirect != null) {
                  onTapDirect();
                } else {
                  widget.onSelect(route);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFC7D2FE),
                          width: 1)
                      : null,
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon,
                          size: 21,
                          color: isSelected ? activeIcon : inactiveIcon),
                      if (badgeText != null)
                        Positioned(
                          top: -3,
                          right: -5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: badgeColor ?? const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
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
              if (onTapDirect != null) {
                onTapDirect();
              }
            } else {
              widget.onSelect(route);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
                          : const Color(0xFFC7D2FE),
                      width: 1)
                  : null,
            ),
            child: Row(
              children: [
                // Active indicator pill on left edge
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: activeIcon,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )
                else
                  const SizedBox(width: 4),

                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? activeIcon : inactiveIcon,
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? activeText : inactiveText,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (activeSubtitle != null && activeSubtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            activeSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF6366F1))
                                  : (isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (badgeText != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                if (hasSubmenu)
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: isSelected ? activeIcon : const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subItem({
    required String title,
    required AppRoute route,
    VoidCallback? onTapCustom,
  }) {
    final displayTitle = _getDisplayTitle(title);
    final activeSubtitle = _getLocalizedSubtitle(title);
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        displayTitle.toLowerCase().contains(_filter) ||
        (activeSubtitle != null &&
            activeSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.selectedRoute == route;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeDot =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final inactiveDot =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Padding(
      padding:
          const EdgeInsets.only(left: 28, right: 10, top: 1.5, bottom: 1.5),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: activeSubtitle != null && activeSubtitle.isNotEmpty
              ? '$title ($activeSubtitle)'
              : title,
          waitDuration: const Duration(milliseconds: 350),
          child: InkWell(
            onTap: onTapCustom ?? () => widget.onSelect(route),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: isSelected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Connecting Guide Dot
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? activeDot : inactiveDot,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? activeText : inactiveText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final user = AuthService.currentUser;
    bool can(String perm) => user?.hasPermission(perm) ?? true;
    final canPos = can('pos.access');
    final canProducts = can('product.view');
    final canAddProduct = can('product.create');
    final canPrintLabels = can('product.print_labels');
    final canSales = can('sale.view');
    final canReturns = can('sale.return');
    final canPurchases = can('purchase.view') || can('purchase.create');
    final canAddPurchase = can('purchase.create');
    final canExpenses = can('expense.view') || can('expense.add');
    final canInventory = can('inventory.transfer') ||
        can('inventory.adjust') ||
        can('inventory.audit') ||
        can('inventory.manage');
    final canReports = can('report.view');
    final canKhata = can('customer.view') ||
        can('customer.manage') ||
        can('supplier.manage') ||
        can('contact.khata_payment');
    final canManageUsers = can('user.manage') || can('role.manage');
    final canSettings = can('settings.manage');

    // Check if parent sections are active
    final isProductsActive = const [
      AppRoute.productsList,
      AppRoute.categories,
      AppRoute.addProduct,
      AppRoute.printLabels,
      AppRoute.variationTemplates,
      AppRoute.units,
      AppRoute.brands,
      AppRoute.warranties,
      AppRoute.sellingPriceGroups,
      AppRoute.importProducts,
      AppRoute.discountRules
    ].contains(widget.selectedRoute);
    final isPurchasesActive = const [
      AppRoute.purchasesList,
      AppRoute.purchaseReturn,
      AppRoute.addPurchase,
      AppRoute.purchaseOrders
    ].contains(widget.selectedRoute);
    final isSellActive = const [
      AppRoute.posTerminal,
      AppRoute.salesList,
      AppRoute.salesReturn,
      AppRoute.salesOrders,
      AppRoute.commissionAgents
    ].contains(widget.selectedRoute);
    final isContactsActive = const [AppRoute.customers, AppRoute.suppliers]
        .contains(widget.selectedRoute);
    final isTransfersActive = widget.selectedRoute == AppRoute.stockTransfers;
    final isAdjustmentsActive =
        widget.selectedRoute == AppRoute.stockAdjustments;
    final isExpensesActive = widget.selectedRoute == AppRoute.expenses;
    final isReportsActive = const [AppRoute.reports, AppRoute.inventoryAudit]
        .contains(widget.selectedRoute);
    final isSettingsActive = const [
      AppRoute.settings,
      AppRoute.paymentAccounts,
      AppRoute.chequeManagement,
      AppRoute.annualClosing,
      AppRoute.moduleSettings,
      AppRoute.cloudSync
    ].contains(widget.selectedRoute);
    final hasDirectModuleItems =
        _isModEnabled(BusinessSettings.moduleRestaurant) ||
            _isModEnabled(BusinessSettings.moduleRepair) ||
            _isModEnabled(BusinessSettings.moduleHotel) ||
            _isModEnabled(BusinessSettings.moduleGym) ||
            _isModEnabled(BusinessSettings.moduleManufacturing) ||
            _isModEnabled(BusinessSettings.moduleWooCommerce) ||
            _isModEnabled(BusinessSettings.moduleHrm) ||
            _isModEnabled(BusinessSettings.moduleAccountingCrm) ||
            _isModEnabled(BusinessSettings.moduleFruitMandi) ||
            _isModEnabled(BusinessSettings.modulePoultry);

    return [
      // ==========================================
      // SECTION 1: OVERVIEW & COUNTER
      // ==========================================
      _sectionHeader('Dashboard & Counter'),

      // 1. Home (Dashboard)
      _navItem(
        icon: Icons.dashboard_outlined,
        title: 'Home',
        route: AppRoute.dashboard,
      ),

      // POS Terminal Quick Link
      if (canPos)
        _navItem(
          icon: Icons.point_of_sale_rounded,
          title: 'POS Terminal (F1)',
          badgeText: 'F1',
          badgeColor: const Color(0xFF10B981),
          route: AppRoute.posTerminal,
        ),

      // ==========================================
      // SECTION 2: INVENTORY & CATALOG
      // ==========================================
      if (canProducts || canInventory) ...[
        _sectionHeader('Inventory & Products'),

        // 4. Products
        if (canProducts) ...[
          _navItem(
            icon: Icons.inventory_2_outlined,
            title: 'Products',
            route: AppRoute.productsList,
            hasSubmenu: true,
            isExpanded: _productsExpanded,
            isActiveParent: isProductsActive,
            onToggleSubmenu: () =>
                setState(() => _productsExpanded = !_productsExpanded),
            onTapDirect: () => widget.onSelect(AppRoute.productsList),
          ),
          if (!widget.isCollapsed && _productsExpanded) ...[
            _subItem(title: 'List Products', route: AppRoute.productsList),
            if (canAddProduct)
              _subItem(title: 'Add Product', route: AppRoute.addProduct),
            if (canPrintLabels &&
                _isModEnabled(BusinessSettings.modulePrintLabels))
              _subItem(title: 'Print Labels', route: AppRoute.printLabels),
            if (_isModEnabled(BusinessSettings.moduleVariations))
              _subItem(title: 'Variations', route: AppRoute.variationTemplates),
            if (canAddProduct &&
                _isModEnabled(BusinessSettings.modulePrintLabels))
              _subItem(
                  title: 'Import Products', route: AppRoute.importProducts),
            if (canSettings &&
                _isModEnabled(BusinessSettings.moduleWholesaleTools))
              _subItem(
                  title: 'Price Groups', route: AppRoute.sellingPriceGroups),
            if ((canSettings || canAddProduct) &&
                _isModEnabled(BusinessSettings.moduleWholesaleTools))
              _subItem(title: 'Discount Rules', route: AppRoute.discountRules),
            _subItem(title: 'Units', route: AppRoute.units),
            _subItem(title: 'Categories', route: AppRoute.categories),
            _subItem(title: 'Brands', route: AppRoute.brands),
            _subItem(title: 'Warranties', route: AppRoute.warranties),
          ],
        ],
      ],

      // Stock Transfers
      if (canInventory &&
          _isModEnabled(BusinessSettings.moduleStockTransfers)) ...[
        _navItem(
          icon: Icons.local_shipping_outlined,
          title: 'Stock Transfers',
          route: AppRoute.stockTransfers,
          hasSubmenu: true,
          isExpanded: _transfersExpanded,
          isActiveParent: isTransfersActive,
          onToggleSubmenu: () =>
              setState(() => _transfersExpanded = !_transfersExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.stockTransfers),
        ),
        if (!widget.isCollapsed && _transfersExpanded) ...[
          _subItem(title: 'List Transfers', route: AppRoute.stockTransfers),
          _subItem(title: 'Add Transfer', route: AppRoute.stockTransfers),
        ],
      ],

      // Stock Adjustment
      if (canInventory && _isModEnabled(BusinessSettings.moduleStockAudit)) ...[
        _navItem(
          icon: Icons.tune_outlined,
          title: 'Stock Adjustment',
          route: AppRoute.stockAdjustments,
          hasSubmenu: true,
          isExpanded: _adjustmentsExpanded,
          isActiveParent: isAdjustmentsActive,
          onToggleSubmenu: () =>
              setState(() => _adjustmentsExpanded = !_adjustmentsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.stockAdjustments),
        ),
        if (!widget.isCollapsed && _adjustmentsExpanded) ...[
          _subItem(title: 'Adjustments List', route: AppRoute.stockAdjustments),
          _subItem(title: 'Add Adjustment', route: AppRoute.stockAdjustments),
        ],
      ],

      // ==========================================
      // SECTION 3: SALES & PURCHASES
      // ==========================================
      if (canSales || canPos || canPurchases || canExpenses)
        _sectionHeader('Sales & Purchases'),

      // Sell
      if (canSales || canPos) ...[
        _navItem(
          icon: Icons.receipt_long_outlined,
          title: 'Sell',
          route: AppRoute.salesList,
          hasSubmenu: true,
          isExpanded: _sellExpanded,
          isActiveParent: isSellActive,
          onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.salesList),
        ),
        if (!widget.isCollapsed && _sellExpanded) ...[
          if (canSales) _subItem(title: 'All Sales', route: AppRoute.salesList),
          if (canSales && _isModEnabled(BusinessSettings.moduleWholesaleTools))
            _subItem(title: 'Sales Orders', route: AppRoute.salesOrders),
          if (canSales && _isModEnabled(BusinessSettings.moduleWholesaleTools))
            _subItem(
                title: 'Commission Agents', route: AppRoute.commissionAgents),
          if (canPos)
            _subItem(title: 'POS Terminal', route: AppRoute.posTerminal),
          if (canSales) _subItem(title: 'List POS', route: AppRoute.salesList),
          if (canReturns && _isModEnabled(BusinessSettings.moduleReturns))
            _subItem(title: 'Sales Return', route: AppRoute.salesReturn),
        ],
      ],

      // Purchases
      if (canPurchases) ...[
        _navItem(
          icon: Icons.shopping_cart_outlined,
          title: 'Purchases',
          route: AppRoute.purchasesList,
          hasSubmenu: true,
          isExpanded: _purchasesExpanded,
          isActiveParent: isPurchasesActive,
          onToggleSubmenu: () =>
              setState(() => _purchasesExpanded = !_purchasesExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.purchasesList),
        ),
        if (!widget.isCollapsed && _purchasesExpanded) ...[
          _subItem(title: 'Purchases List', route: AppRoute.purchasesList),
          if (_isModEnabled(BusinessSettings.moduleWholesaleTools))
            _subItem(title: 'Purchase Orders', route: AppRoute.purchaseOrders),
          if (canAddPurchase)
            _subItem(title: 'Add Purchase', route: AppRoute.addPurchase),
          if (canAddPurchase && _isModEnabled(BusinessSettings.moduleReturns))
            _subItem(title: 'Purchase Return', route: AppRoute.purchaseReturn),
        ],
      ],

      // Expenses
      if (canExpenses && _isModEnabled(BusinessSettings.moduleExpenses)) ...[
        _navItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Expenses',
          route: AppRoute.expenses,
          hasSubmenu: true,
          isExpanded: _expensesExpanded,
          isActiveParent: isExpensesActive,
          onToggleSubmenu: () =>
              setState(() => _expensesExpanded = !_expensesExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.expenses),
        ),
        if (!widget.isCollapsed && _expensesExpanded) ...[
          _subItem(title: 'List Expenses', route: AppRoute.expenses),
          _subItem(title: 'Add Expense', route: AppRoute.expenses),
        ],
      ],

      // ==========================================
      // SECTION 4: CONTACTS & ACCOUNTS
      // ==========================================
      _sectionHeader('Contacts & Khata'),

      // Contacts
      if (canKhata)
        _navItem(
          icon: Icons.people_alt_outlined,
          title: 'Contacts & Khata',
          route: AppRoute.customers,
          hasSubmenu: true,
          isExpanded: _contactsExpanded,
          isActiveParent: isContactsActive,
          onToggleSubmenu: () =>
              setState(() => _contactsExpanded = !_contactsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.customers),
        ),
      if (!widget.isCollapsed && _contactsExpanded && canKhata) ...[
        _subItem(title: 'Customers', route: AppRoute.customers),
        _subItem(title: 'Suppliers', route: AppRoute.suppliers),
        _subItem(title: 'Customer Groups', route: AppRoute.customers),
      ],

      if (canSettings &&
          _isModEnabled(BusinessSettings.moduleAccountingCrm)) ...[
        _navItem(
          icon: Icons.account_balance_outlined,
          title: 'Cheques & Clearing',
          route: AppRoute.chequeManagement,
        ),
      ],

      // User Management
      if (canManageUsers)
        _navItem(
          icon: Icons.manage_accounts_outlined,
          title: 'User Management',
          route: AppRoute.userManagement,
          hasSubmenu: true,
          isExpanded: _userMgmtExpanded,
          isActiveParent: widget.selectedRoute == AppRoute.userManagement,
          onToggleSubmenu: () =>
              setState(() => _userMgmtExpanded = !_userMgmtExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.userManagement),
        ),
      if (!widget.isCollapsed && _userMgmtExpanded && canManageUsers) ...[
        _subItem(title: 'Users', route: AppRoute.userManagement),
        _subItem(title: 'Roles & Permissions', route: AppRoute.userManagement),
      ],

      // ==========================================
      // SECTION 5: INTELLIGENCE & AUDIT
      // ==========================================
      _sectionHeader('Reports & Audit'),

      // Reports
      if (canReports && _isModEnabled(BusinessSettings.moduleReporting)) ...[
        _navItem(
          icon: Icons.analytics_outlined,
          title: 'Reports',
          route: AppRoute.reports,
          hasSubmenu: true,
          isExpanded: _reportsExpanded,
          isActiveParent: isReportsActive,
          onToggleSubmenu: () =>
              setState(() => _reportsExpanded = !_reportsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.reports),
        ),
        if (!widget.isCollapsed && _reportsExpanded) ...[
          _subItem(title: 'Profit / Loss Report', route: AppRoute.reports),
          _subItem(title: 'Purchase & Sale', route: AppRoute.reports),
          if (_isModEnabled(BusinessSettings.moduleFiscalTax))
            _subItem(title: 'Tax Report', route: AppRoute.reports),
          _subItem(title: 'Contact Dues', route: AppRoute.reports),
          if (_isModEnabled(BusinessSettings.moduleStockAudit))
            _subItem(
                title: 'Stock & Expiry Audit', route: AppRoute.inventoryAudit),
          _subItem(title: 'Trending Products', route: AppRoute.reports),
        ],
      ] else if (canReports &&
          _isModEnabled(BusinessSettings.moduleStockAudit)) ...[
        _navItem(
          icon: Icons.fact_check_outlined,
          title: 'Stock & Expiry Audit',
          route: AppRoute.inventoryAudit,
        ),
      ],

      // Notification Templates
      if (_isModEnabled(BusinessSettings.moduleMessaging))
        _navItem(
          icon: Icons.mark_email_read_outlined,
          title: 'SMS & WhatsApp Alerts',
          route: AppRoute.notificationTemplates,
        ),

      // ==========================================
      // SECTION 6: SYSTEM PREFERENCES
      // ==========================================
      _sectionHeader('System Settings'),

      if (canSettings) ...[
        _navItem(
          icon: Icons.settings_suggest_outlined,
          title: 'Settings',
          route: AppRoute.settings,
          hasSubmenu: true,
          isExpanded: _settingsExpanded,
          isActiveParent: isSettingsActive,
          onToggleSubmenu: () =>
              setState(() => _settingsExpanded = !_settingsExpanded),
          onTapDirect: () => widget.onSelect(AppRoute.settings),
        ),
        if (!widget.isCollapsed && _settingsExpanded) ...[
          _subItem(title: 'Business Settings', route: AppRoute.settings),
          if (_isModEnabled(BusinessSettings.moduleAccountingCrm))
            _subItem(
                title: 'Payment Accounts', route: AppRoute.paymentAccounts),
          if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
            _subItem(
                title: 'Annual Fiscal Closing', route: AppRoute.annualClosing),
          if (_isModEnabled(BusinessSettings.moduleCloudSync))
            _subItem(title: 'Cloud & MySQL Sync', route: AppRoute.cloudSync),
          _subItem(title: 'Modular Features', route: AppRoute.moduleSettings),
          _subItem(
            title: 'About Developer & Support',
            route: AppRoute.settings,
            onTapCustom: () =>
                AboutDeveloperDialog.show(context, settings: widget.settings),
          ),
        ],
      ],

      // ==========================================
      // SECTION 7: INSTALLED BUSINESS MODULES (CLIENT-SCOPED)
      // ==========================================
      if (hasDirectModuleItems) ...[
        _sectionHeader('Business Operations'),
        if (_isModEnabled(BusinessSettings.moduleRestaurant))
          _navItem(
            icon: Icons.restaurant_rounded,
            title: 'Restaurant / Cafe',
            route: AppRoute.restaurantCafe,
            isActiveParent: widget.selectedRoute == AppRoute.restaurantCafe,
          ),
        if (_isModEnabled(BusinessSettings.moduleRepair))
          _navItem(
            icon: Icons.build_circle_outlined,
            title: 'Repair Shop / Service',
            route: AppRoute.repairService,
            isActiveParent: widget.selectedRoute == AppRoute.repairService,
          ),
        if (_isModEnabled(BusinessSettings.moduleHotel))
          _navItem(
            icon: Icons.hotel_outlined,
            title: 'Hotel Management',
            route: AppRoute.hotelManagement,
            isActiveParent: widget.selectedRoute == AppRoute.hotelManagement,
          ),
        if (_isModEnabled(BusinessSettings.moduleGym))
          _navItem(
            icon: Icons.fitness_center_rounded,
            title: 'Gym & Fitness Center',
            route: AppRoute.gymFitness,
            isActiveParent: widget.selectedRoute == AppRoute.gymFitness,
          ),
        if (_isModEnabled(BusinessSettings.moduleManufacturing))
          _navItem(
            icon: Icons.precision_manufacturing_outlined,
            title: 'Manufacturing / BOM',
            route: AppRoute.manufacturing,
            isActiveParent: widget.selectedRoute == AppRoute.manufacturing,
          ),
        if (_isModEnabled(BusinessSettings.moduleFruitMandi))
          _navItem(
            icon: Icons.agriculture_outlined,
            title: 'Fruit Mandi (Arhat)',
            route: AppRoute.fruitMandi,
            isActiveParent: widget.selectedRoute == AppRoute.fruitMandi,
          ),
        if (_isModEnabled(BusinessSettings.modulePoultry))
          _navItem(
            icon: Icons.egg_outlined,
            title: 'Poultry Farm & Trading',
            route: AppRoute.poultryBusiness,
            isActiveParent: widget.selectedRoute == AppRoute.poultryBusiness,
          ),
        if (_isModEnabled(BusinessSettings.moduleWooCommerce))
          _navItem(
            icon: Icons.shopping_bag_outlined,
            title: 'Online Store (Woo)',
            route: AppRoute.wooCommerceSync,
            isActiveParent: widget.selectedRoute == AppRoute.wooCommerceSync,
          ),
        if (_isModEnabled(BusinessSettings.moduleHrm))
          _navItem(
            icon: Icons.badge_outlined,
            title: 'HR & Employee (Payroll)',
            route: AppRoute.hrmEmployee,
            isActiveParent: widget.selectedRoute == AppRoute.hrmEmployee,
          ),
        if (_isModEnabled(BusinessSettings.moduleAccountingCrm))
          _navItem(
            icon: Icons.account_balance_outlined,
            title: 'Accounting & Ledgers',
            route: AppRoute.accountingCrm,
            isActiveParent: widget.selectedRoute == AppRoute.accountingCrm,
          ),
      ],

      const SizedBox(height: 24),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.currentUser;
    final userName = user?.name ?? 'Admin User';
    final userRole = user?.role ?? 'Superadmin';
    final branchName = widget.settings?.branchName ?? 'Main Branch HQ';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: widget.isCollapsed ? 68 : 252,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Search Box (Only when expanded)
          if (!widget.isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _menuSearchCtrl,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onChanged: (val) =>
                      setState(() => _filter = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: PosLocalization.tr('Search menu...',
                        settings: widget.settings),
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () {
                              _menuSearchCtrl.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),

          // 2. High-Impact Fast Checkout Terminal Action Pill
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 8 : 12,
              vertical: 6,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onSelect(AppRoute.posTerminal),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: widget.isCollapsed
                      ? const Center(
                          child: Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 22),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  PosLocalization.tr('POS Terminal',
                                      settings: widget.settings),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'F1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),

          // 3. Navigation Items Scrollable Tree
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _buildMenuItems(),
            ),
          ),

          // 4. Sleek Profile & Active Branch Footer Card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 8 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: widget.isCollapsed
                ? Tooltip(
                    message:
                        '$userName ($userRole)\n$branchName\n● Smart POS Live',
                    preferBelow: false,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF4F46E5),
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: -1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    branchName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: PosLocalization.tr(
                            'About Developer & Support (Webdeventh)',
                            settings: widget.settings),
                        child: InkWell(
                          onTap: () => AboutDeveloperDialog.show(context,
                              settings: widget.settings),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 10, color: Color(0xFF4F46E5)),
                                SizedBox(width: 3),
                                Text(
                                  'v1.1',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
