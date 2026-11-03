import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

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
  bool _industryExpanded = false;

  @override
  void initState() {
    super.initState();
    _syncActiveSection(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(SmartSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _syncActiveSection(widget.selectedIndex);
    }
  }

  void _syncActiveSection(int index) {
    if (index == 12) {
      _userMgmtExpanded = true;
    } else if (index == 6 || index == 7) {
      _contactsExpanded = true;
    } else if ([2, 3, 11, 17, 18, 19, 20, 21, 22, 23].contains(index)) {
      _productsExpanded = true;
    } else if ([5, 26].contains(index)) {
      _purchasesExpanded = true;
    } else if ([1, 4, 25].contains(index)) {
      _sellExpanded = true;
    } else if (index == 13) {
      _transfersExpanded = true;
    } else if (index == 14) {
      _adjustmentsExpanded = true;
    } else if (index == 8) {
      _expensesExpanded = true;
    } else if ([9, 24].contains(index)) {
      _reportsExpanded = true;
    } else if ([10, 15, 27, 39, 40].contains(index)) {
      _settingsExpanded = true;
    } else if (index >= 28 && index <= 38) {
      _industryExpanded = true;
    }
  }

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
    String? urduSubtitle,
    required int index,
    bool hasSubmenu = false,
    bool isExpanded = false,
    bool isActiveParent = false,
    VoidCallback? onToggleSubmenu,
    VoidCallback? onTapDirect,
  }) {
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        (urduSubtitle != null && urduSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
      return const SizedBox.shrink();
    }

    final isSelected = widget.selectedIndex == index || isActiveParent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Tooltip(
          message: '$title ${urduSubtitle ?? ''}',
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
                  widget.onSelect(index);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F0FE))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1A73E8))
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
              if (onTapDirect != null) {
                onTapDirect();
              }
            } else {
              widget.onSelect(index);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F0FE))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFC7D2FE), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1A73E8))
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
                          ? (isDark ? Colors.white : const Color(0xFF1A73E8))
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                    ),
                  ),
                ),
                if (hasSubmenu)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_left_rounded,
                    size: 16,
                    color: isSelected
                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1A73E8))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
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
    String? urduSubtitle,
    required int index,
  }) {
    final matchesFilter = _filter.isEmpty ||
        title.toLowerCase().contains(_filter) ||
        (urduSubtitle != null && urduSubtitle.toLowerCase().contains(_filter));

    if (!matchesFilter) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFE8F0FE))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1A73E8))
                        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF1A73E8))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems() {
    final user = AuthService.currentUser;
    final isAdm = user == null || user.isAdmin;
    final canInventory = isAdm || user.canAccessInventory;
    final canReports = isAdm || user.canAccessReports;
    final canKhata = isAdm || user.canAccessKhata;
    final canManageUsers = isAdm || user.canManageUsers;
    final canSettings = isAdm || user.canAccessSettings;

    // Check if parent sections are active
    final isProductsActive = [2, 3, 11, 17, 18, 19, 20, 21, 22, 23].contains(widget.selectedIndex);
    final isPurchasesActive = [5, 26].contains(widget.selectedIndex);
    final isSellActive = [1, 4, 25].contains(widget.selectedIndex);
    final isContactsActive = [6, 7].contains(widget.selectedIndex);
    final isTransfersActive = widget.selectedIndex == 13;
    final isAdjustmentsActive = widget.selectedIndex == 14;
    final isExpensesActive = widget.selectedIndex == 8;
    final isReportsActive = [9, 24].contains(widget.selectedIndex);
    final isSettingsActive = [10, 15, 27, 39, 40].contains(widget.selectedIndex);
    final isIndustryActive = widget.selectedIndex >= 28 && widget.selectedIndex <= 38;

    return [
      // 1. Home (Dashboard)
      _navItem(
        icon: Icons.home_outlined,
        title: 'Home',
        urduSubtitle: 'ڈیش بورڈ',
        index: 0,
      ),

      // 2. User Management
      if (canManageUsers)
        _navItem(
          icon: Icons.group_outlined,
          title: 'User Management',
          urduSubtitle: 'صارفین',
          index: 12,
          hasSubmenu: true,
          isExpanded: _userMgmtExpanded,
          isActiveParent: widget.selectedIndex == 12,
          onToggleSubmenu: () => setState(() => _userMgmtExpanded = !_userMgmtExpanded),
          onTapDirect: () => widget.onSelect(12),
        ),
      if (!widget.isCollapsed && _userMgmtExpanded && canManageUsers) ...[
        _subItem(title: 'Users (صارفین کی فہرست)', index: 12),
        _subItem(title: 'Roles & Permissions (اختیارات)', index: 12),
        _subItem(title: 'Sales Commission Agents', index: 12),
      ],

      // 3. Contacts (Suppliers & Customers)
      if (canKhata)
        _navItem(
          icon: Icons.contacts_outlined,
          title: 'Contacts',
          urduSubtitle: 'کھاتہ اور پارٹیز',
          index: 6,
          hasSubmenu: true,
          isExpanded: _contactsExpanded,
          isActiveParent: isContactsActive,
          onToggleSubmenu: () => setState(() => _contactsExpanded = !_contactsExpanded),
          onTapDirect: () => widget.onSelect(7),
        ),
      if (!widget.isCollapsed && _contactsExpanded && canKhata) ...[
        _subItem(title: 'Suppliers (سپلائرز / وینڈرز)', index: 7),
        _subItem(title: 'Customers (گاہک / کسٹمرز)', index: 6),
        _subItem(title: 'Customer Groups (کسٹمر گروپس)', index: 6),
      ],

      // 4. Products
      _navItem(
        icon: Icons.inventory_2_outlined,
        title: 'Products',
        urduSubtitle: 'پروڈکٹس اور سٹاک',
        index: 2,
        hasSubmenu: true,
        isExpanded: _productsExpanded,
        isActiveParent: isProductsActive,
        onToggleSubmenu: () => setState(() => _productsExpanded = !_productsExpanded),
        onTapDirect: () => widget.onSelect(2),
      ),
      if (!widget.isCollapsed && _productsExpanded) ...[
        _subItem(title: 'List Products (پروڈکٹس لسٹ)', index: 2),
        if (canInventory) _subItem(title: 'Add Product (نیا پروڈکٹ شامل کریں)', index: 11),
        _subItem(title: 'Print Labels (بارکوڈ لیبل پرنٹنگ)', index: 17),
        if (_isModEnabled(BusinessSettings.moduleVariations))
          _subItem(title: 'Variations (ویرینٹس)', index: 18),
        if (canInventory) _subItem(title: 'Import Products (پروڈکٹس امپورٹ)', index: 23),
        if (canSettings) _subItem(title: 'Selling Price Group (قیمت کے گروپس)', index: 22),
        _subItem(title: 'Units (پیمائش کے یونٹس)', index: 19),
        _subItem(title: 'Categories (کیٹیگریز)', index: 3),
        _subItem(title: 'Brands (برانڈز)', index: 20),
        _subItem(title: 'Warranties (وارنٹیز)', index: 21),
      ],

      // 5. Purchases
      _navItem(
        icon: Icons.arrow_circle_down_outlined,
        title: 'Purchases',
        urduSubtitle: 'خریداری / سٹاک ان',
        index: 5,
        hasSubmenu: true,
        isExpanded: _purchasesExpanded,
        isActiveParent: isPurchasesActive,
        onToggleSubmenu: () => setState(() => _purchasesExpanded = !_purchasesExpanded),
        onTapDirect: () => widget.onSelect(5),
      ),
      if (!widget.isCollapsed && _purchasesExpanded) ...[
        _subItem(title: 'List Purchases (خریداریوں کی لسٹ)', index: 5),
        _subItem(title: 'Add Purchase (نئی خریداری درج کریں)', index: 5),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Purchase Return (خریداری واپسی)', index: 26),
      ],

      // 6. Sell
      _navItem(
        icon: Icons.arrow_circle_up_outlined,
        title: 'Sell',
        urduSubtitle: 'سیل / بلنگ',
        index: 4,
        hasSubmenu: true,
        isExpanded: _sellExpanded,
        isActiveParent: isSellActive,
        onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
        onTapDirect: () => widget.onSelect(4),
      ),
      if (!widget.isCollapsed && _sellExpanded) ...[
        _subItem(title: 'All Sales (تمام سیل انوائسز)', index: 4),
        _subItem(title: 'POS Terminal (F1) (فوری کاؤنٹر سیل)', index: 1),
        _subItem(title: 'List POS (پی او ایس بلز)', index: 4),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Sales Return (سیلز ریٹرن)', index: 25),
      ],

      // 7. Stock Transfers
      if (canInventory && _isModEnabled(BusinessSettings.moduleStockTransfers)) ...[
        _navItem(
          icon: Icons.local_shipping_outlined,
          title: 'Stock Transfers',
          urduSubtitle: 'برانچوں میں ٹرانسفر',
          index: 13,
          hasSubmenu: true,
          isExpanded: _transfersExpanded,
          isActiveParent: isTransfersActive,
          onToggleSubmenu: () => setState(() => _transfersExpanded = !_transfersExpanded),
          onTapDirect: () => widget.onSelect(13),
        ),
        if (!widget.isCollapsed && _transfersExpanded) ...[
          _subItem(title: 'List Stock Transfers (تمام ٹرانسفرز)', index: 13),
          _subItem(title: 'Add Stock Transfer (نیا ٹرانسفر بھیجیں)', index: 13),
        ],
      ],

      // 8. Stock Adjustment
      if (canInventory) ...[
        _navItem(
          icon: Icons.tune_outlined,
          title: 'Stock Adjustment',
          urduSubtitle: 'سٹاک درستگی / ضیاع',
          index: 14,
          hasSubmenu: true,
          isExpanded: _adjustmentsExpanded,
          isActiveParent: isAdjustmentsActive,
          onToggleSubmenu: () => setState(() => _adjustmentsExpanded = !_adjustmentsExpanded),
          onTapDirect: () => widget.onSelect(14),
        ),
        if (!widget.isCollapsed && _adjustmentsExpanded) ...[
          _subItem(title: 'List Stock Adjustments (ایڈجسٹمنٹ لسٹ)', index: 14),
          _subItem(title: 'Add Stock Adjustment (سٹاک درست کریں)', index: 14),
        ],
      ],

      // 9. Expenses
      if (_isModEnabled(BusinessSettings.moduleExpenses)) ...[
        _navItem(
          icon: Icons.attach_money_rounded,
          title: 'Expenses',
          urduSubtitle: 'دکان کے اخراجات',
          index: 8,
          hasSubmenu: true,
          isExpanded: _expensesExpanded,
          isActiveParent: isExpensesActive,
          onToggleSubmenu: () => setState(() => _expensesExpanded = !_expensesExpanded),
          onTapDirect: () => widget.onSelect(8),
        ),
        if (!widget.isCollapsed && _expensesExpanded) ...[
          _subItem(title: 'List Expenses (تمام اخراجات)', index: 8),
          _subItem(title: 'Add Expense (نیا خرچہ شامل کریں)', index: 8),
        ],
      ],

      // 10. Reports
      if (canReports) ...[
        _navItem(
          icon: Icons.assessment_outlined,
          title: 'Reports',
          urduSubtitle: 'کاروباری رپورٹس',
          index: 9,
          hasSubmenu: true,
          isExpanded: _reportsExpanded,
          isActiveParent: isReportsActive,
          onToggleSubmenu: () => setState(() => _reportsExpanded = !_reportsExpanded),
          onTapDirect: () => widget.onSelect(9),
        ),
        if (!widget.isCollapsed && _reportsExpanded) ...[
          _subItem(title: 'Profit / Loss Report (نفع و نقصان رپورٹ)', index: 9),
          _subItem(title: 'Purchase & Sale (خرید و فروخت رپورٹ)', index: 9),
          _subItem(title: 'Tax Report (ٹیکس رپورٹ)', index: 9),
          _subItem(title: 'Supplier & Customer Report (کھاتہ رپورٹ)', index: 9),
          if (_isModEnabled(BusinessSettings.moduleStockAudit))
            _subItem(title: 'Stock & Expiry Audit (سٹاک و ایکسپائری آڈٹ)', index: 24),
          _subItem(title: 'Trending Products (زیادہ بکنے والا مال)', index: 9),
        ],
      ],

      // 11. Notification Templates
      _navItem(
        icon: Icons.mail_outline_rounded,
        title: 'Notification Templates',
        urduSubtitle: 'اطلاعات کے ٹیمپلیٹس',
        index: 16,
      ),

      // 12. Settings
      if (canSettings) ...[
        _navItem(
          icon: Icons.settings_outlined,
          title: 'Settings',
          urduSubtitle: 'سسٹم سیٹنگز',
          index: 10,
          hasSubmenu: true,
          isExpanded: _settingsExpanded,
          isActiveParent: isSettingsActive,
          onToggleSubmenu: () => setState(() => _settingsExpanded = !_settingsExpanded),
          onTapDirect: () => widget.onSelect(10),
        ),
        if (!widget.isCollapsed && _settingsExpanded) ...[
          _subItem(title: 'Business Settings (کاروباری سیٹنگز)', index: 10),
          _subItem(title: 'Business Locations (برانچز / لوکیشنز)', index: 10),
          _subItem(title: 'Payment Accounts (بینک و کیش اکاؤنٹس)', index: 15),
          if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
            _subItem(title: 'Annual Fiscal Closing (سالانہ اختتامی کلوزنگ)', index: 27),
          _subItem(title: 'Cloud & MySQL Sync (کلاؤڈ سنک)', index: 40),
          _subItem(title: 'Modular Features (اضافی فیچرز)', index: 39),
        ],
      ],

      // 13. Industry Modules Hub (Optional for niche businesses)
      if (widget.settings?.hasAnyIndustryModuleEnabled == true) ...[
        _navItem(
          icon: Icons.widgets_outlined,
          title: 'Industry Modules',
          urduSubtitle: 'خصوصی ماڈیولز',
          index: 28,
          hasSubmenu: true,
          isExpanded: _industryExpanded,
          isActiveParent: isIndustryActive,
          onToggleSubmenu: () => setState(() => _industryExpanded = !_industryExpanded),
          onTapDirect: () => widget.onSelect(28),
        ),
        if (!widget.isCollapsed && _industryExpanded) ...[
          _subItem(title: 'All Modules Hub', index: 28),
          if (_isModEnabled(BusinessSettings.moduleRestaurant))
            _subItem(title: 'Restaurant / Cafe', index: 29),
          if (_isModEnabled(BusinessSettings.moduleRepair))
            _subItem(title: 'Repair Shop / Service', index: 30),
          if (_isModEnabled(BusinessSettings.moduleHotel))
            _subItem(title: 'Hotel Management', index: 31),
          if (_isModEnabled(BusinessSettings.moduleGym))
            _subItem(title: 'Gym & Fitness Center', index: 32),
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

          // Menu Items List matching Smart POS standard hierarchy
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
