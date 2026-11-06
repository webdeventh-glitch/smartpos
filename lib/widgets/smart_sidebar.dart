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

  Widget _sectionHeader(String title) {
    if (widget.isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
      );
    }
    if (_filter.isNotEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 12, top: 16, bottom: 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String title,
    String? urduSubtitle,
    required int index,
    bool hasSubmenu = false,
    bool isExpanded = false,
    bool isActiveParent = false,
    String? badgeText,
    Color? badgeColor,
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

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeIcon = isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final inactiveIcon = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: Tooltip(
          message: '$title ${urduSubtitle != null ? "($urduSubtitle)" : ""}',
          preferBelow: false,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFC7D2FE), width: 1)
                      : null,
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 21, color: isSelected ? activeIcon : inactiveIcon),
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
              widget.onSelect(index);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFC7D2FE), width: 1)
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? activeText : inactiveText,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (urduSubtitle != null && urduSubtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            urduSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF6366F1))
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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

    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final activeText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final activeDot = isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F46E5);
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final inactiveDot = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 10, top: 1.5, bottom: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelect(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeText : inactiveText,
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
      // ==========================================
      // SECTION 1: OVERVIEW & COUNTER
      // ==========================================
      _sectionHeader('Dashboard & Counter'),

      // 1. Home (Dashboard)
      _navItem(
        icon: Icons.dashboard_outlined,
        title: 'Home',
        urduSubtitle: 'مرکزی ڈیش بورڈ',
        index: 0,
      ),

      // POS Terminal Quick Link
      _navItem(
        icon: Icons.point_of_sale_rounded,
        title: 'POS Terminal (F1)',
        urduSubtitle: 'فوری کاؤنٹر سیل',
        badgeText: 'F1',
        badgeColor: const Color(0xFF10B981),
        index: 1,
      ),

      // ==========================================
      // SECTION 2: INVENTORY & CATALOG
      // ==========================================
      _sectionHeader('Inventory & Products'),

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
        if (canInventory) _subItem(title: 'Add Product (نیا پروڈکٹ)', index: 11),
        _subItem(title: 'Print Labels (بارکوڈ لیبلز)', index: 17),
        if (_isModEnabled(BusinessSettings.moduleVariations))
          _subItem(title: 'Variations (ویرینٹس)', index: 18),
        if (canInventory) _subItem(title: 'Import Products (امپورٹ)', index: 23),
        if (canSettings) _subItem(title: 'Price Groups (قیمت گروپس)', index: 22),
        _subItem(title: 'Units (پیمائش کے یونٹس)', index: 19),
        _subItem(title: 'Categories (کیٹیگریز)', index: 3),
        _subItem(title: 'Brands (برانڈز)', index: 20),
        _subItem(title: 'Warranties (وارنٹیز)', index: 21),
      ],

      // Stock Transfers
      if (canInventory && _isModEnabled(BusinessSettings.moduleStockTransfers)) ...[
        _navItem(
          icon: Icons.local_shipping_outlined,
          title: 'Stock Transfers',
          urduSubtitle: 'برانچ ٹرانسفر',
          index: 13,
          hasSubmenu: true,
          isExpanded: _transfersExpanded,
          isActiveParent: isTransfersActive,
          onToggleSubmenu: () => setState(() => _transfersExpanded = !_transfersExpanded),
          onTapDirect: () => widget.onSelect(13),
        ),
        if (!widget.isCollapsed && _transfersExpanded) ...[
          _subItem(title: 'List Transfers (تمام ٹرانسفرز)', index: 13),
          _subItem(title: 'Add Transfer (نیا ٹرانسفر بھیجیں)', index: 13),
        ],
      ],

      // Stock Adjustment
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
          _subItem(title: 'Adjustments List (لسٹ)', index: 14),
          _subItem(title: 'Add Adjustment (نیا اندراج)', index: 14),
        ],
      ],

      // ==========================================
      // SECTION 3: SALES & PURCHASES
      // ==========================================
      _sectionHeader('Sales & Purchases'),

      // Sell
      _navItem(
        icon: Icons.receipt_long_outlined,
        title: 'Sell',
        urduSubtitle: 'فروخت اور بلنگ',
        index: 4,
        hasSubmenu: true,
        isExpanded: _sellExpanded,
        isActiveParent: isSellActive,
        onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
        onTapDirect: () => widget.onSelect(4),
      ),
      if (!widget.isCollapsed && _sellExpanded) ...[
        _subItem(title: 'All Sales (تمام بلز)', index: 4),
        _subItem(title: 'POS Terminal (کاؤنٹر سیل)', index: 1),
        _subItem(title: 'List POS (پی او ایس انوائسز)', index: 4),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Sales Return (سیلز واپسی)', index: 25),
      ],

      // Purchases
      _navItem(
        icon: Icons.shopping_cart_outlined,
        title: 'Purchases',
        urduSubtitle: 'خریداری / مال انورڈ',
        index: 5,
        hasSubmenu: true,
        isExpanded: _purchasesExpanded,
        isActiveParent: isPurchasesActive,
        onToggleSubmenu: () => setState(() => _purchasesExpanded = !_purchasesExpanded),
        onTapDirect: () => widget.onSelect(5),
      ),
      if (!widget.isCollapsed && _purchasesExpanded) ...[
        _subItem(title: 'Purchases List (خریداری لسٹ)', index: 5),
        _subItem(title: 'Add Purchase (نئی خریداری درج کریں)', index: 5),
        if (_isModEnabled(BusinessSettings.moduleReturns))
          _subItem(title: 'Purchase Return (خریداری واپسی)', index: 26),
      ],

      // Expenses
      if (_isModEnabled(BusinessSettings.moduleExpenses)) ...[
        _navItem(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Expenses',
          urduSubtitle: 'دکان و پیٹی کیش اخراجات',
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

      // ==========================================
      // SECTION 4: CONTACTS & ACCOUNTS
      // ==========================================
      _sectionHeader('Contacts & Khata'),

      // Contacts
      if (canKhata)
        _navItem(
          icon: Icons.people_alt_outlined,
          title: 'Contacts & Khata',
          urduSubtitle: 'گاہک، سپلائر اور کھاتہ',
          index: 6,
          hasSubmenu: true,
          isExpanded: _contactsExpanded,
          isActiveParent: isContactsActive,
          onToggleSubmenu: () => setState(() => _contactsExpanded = !_contactsExpanded),
          onTapDirect: () => widget.onSelect(6),
        ),
      if (!widget.isCollapsed && _contactsExpanded && canKhata) ...[
        _subItem(title: 'Customers (گاہک / کسٹمرز)', index: 6),
        _subItem(title: 'Suppliers (سپلائرز / وینڈرز)', index: 7),
        _subItem(title: 'Customer Groups (کسٹمر گروپس)', index: 6),
      ],

      // User Management
      if (canManageUsers)
        _navItem(
          icon: Icons.manage_accounts_outlined,
          title: 'User Management',
          urduSubtitle: 'صارفین اور اختیارات',
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
      ],

      // ==========================================
      // SECTION 5: INTELLIGENCE & AUDIT
      // ==========================================
      _sectionHeader('Reports & Audit'),

      // Reports
      if (canReports) ...[
        _navItem(
          icon: Icons.analytics_outlined,
          title: 'Reports',
          urduSubtitle: 'نفع نقصان اور مالیاتی رپورٹس',
          index: 9,
          hasSubmenu: true,
          isExpanded: _reportsExpanded,
          isActiveParent: isReportsActive,
          onToggleSubmenu: () => setState(() => _reportsExpanded = !_reportsExpanded),
          onTapDirect: () => widget.onSelect(9),
        ),
        if (!widget.isCollapsed && _reportsExpanded) ...[
          _subItem(title: 'Profit / Loss Report (نفع نقصان)', index: 9),
          _subItem(title: 'Purchase & Sale (خرید و فروخت)', index: 9),
          _subItem(title: 'Tax Report (ٹیکس رپورٹ)', index: 9),
          _subItem(title: 'Contact Dues (کھاتہ بقایا جات)', index: 9),
          if (_isModEnabled(BusinessSettings.moduleStockAudit))
            _subItem(title: 'Stock & Expiry Audit (سٹاک و ایکسپائری)', index: 24),
          _subItem(title: 'Trending Products (زیادہ بکنے والا مال)', index: 9),
        ],
      ],

      // Notification Templates
      _navItem(
        icon: Icons.mark_email_read_outlined,
        title: 'SMS & WhatsApp Alerts',
        urduSubtitle: 'اطلاعات کے ٹیمپلیٹس',
        index: 16,
      ),

      // ==========================================
      // SECTION 6: SYSTEM PREFERENCES
      // ==========================================
      _sectionHeader('System Settings'),

      if (canSettings) ...[
        _navItem(
          icon: Icons.settings_suggest_outlined,
          title: 'Settings',
          urduSubtitle: 'سسٹم، برانچ و کلاؤڈ کنفیگریشن',
          index: 10,
          hasSubmenu: true,
          isExpanded: _settingsExpanded,
          isActiveParent: isSettingsActive,
          onToggleSubmenu: () => setState(() => _settingsExpanded = !_settingsExpanded),
          onTapDirect: () => widget.onSelect(10),
        ),
        if (!widget.isCollapsed && _settingsExpanded) ...[
          _subItem(title: 'Business Settings (کاروباری معلومات)', index: 10),
          _subItem(title: 'Payment Accounts (بینک و کیش)', index: 15),
          if (_isModEnabled(BusinessSettings.moduleFiscalClosing))
            _subItem(title: 'Annual Fiscal Closing (سالانہ کلوزنگ)', index: 27),
          _subItem(title: 'Cloud & MySQL Sync (کلاؤڈ سنک)', index: 40),
          _subItem(title: 'Modular Features (ماڈیولز آن/آف)', index: 39),
        ],
      ],

      // ==========================================
      // SECTION 7: SPECIALIZED INDUSTRY MODULES
      // ==========================================
      if (widget.settings?.hasAnyIndustryModuleEnabled == true) ...[
        _sectionHeader('Specialized Industry Modules'),
        _navItem(
          icon: Icons.widgets_outlined,
          title: 'Industry Modules',
          urduSubtitle: 'خصوصی ورٹیکل ماڈیولز',
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  controller: _menuSearchCtrl,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onChanged: (val) => setState(() => _filter = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search menu...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
                onTap: () => widget.onSelect(1), // POS Terminal (Index 1)
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
                          child: Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'POS Terminal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: widget.isCollapsed
                ? Tooltip(
                    message: '$userName ($userRole)\n$branchName\n● Smart POS Live',
                    preferBelow: false,
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF4F46E5),
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                border: Border.all(color: Colors.white, width: 1.5),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v1.0',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
