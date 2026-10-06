import 'package:flutter/material.dart';

class UltimateSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final bool isCollapsed;

  const UltimateSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.isCollapsed,
  });

  @override
  State<UltimateSidebar> createState() => _UltimateSidebarState();
}

class _UltimateSidebarState extends State<UltimateSidebar> {
  final TextEditingController _menuSearchCtrl = TextEditingController();
  String _filter = '';

  // Expandable sections
  bool _productsExpanded = false;
  bool _sellExpanded = false;

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
                  color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
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
            } else {
              widget.onSelect(index);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: const Color(0xFFC7D2FE), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                    ),
                  ),
                ),
                if (hasSubmenu)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                    size: 16,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
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
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: widget.isCollapsed ? 64 : 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
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
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _menuSearchCtrl,
                  style: const TextStyle(fontSize: 12),
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

          // Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _sectionHeader('OVERVIEW'),
                _navItem(icon: Icons.dashboard_outlined, title: 'Home', index: 0),

                _sectionHeader('INVENTORY & SALES'),
                // Products (with dropdown submenus)
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
                  _subItem(title: 'Categories & Brands', index: 3),
                ],

                // Sell / POS (with dropdown submenus)
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
                ],

                _navItem(icon: Icons.shopping_bag_outlined, title: 'Purchases', index: 5),
                _navItem(icon: Icons.sync_alt_rounded, title: 'Stock Transfers', index: 13),
                _navItem(icon: Icons.tune_rounded, title: 'Stock Adjustment', index: 14),

                _sectionHeader('FINANCE & ACCOUNTS'),
                _navItem(icon: Icons.receipt_long_outlined, title: 'Expenses', index: 8),
                _navItem(icon: Icons.account_balance_outlined, title: 'Payment Accounts', index: 15),
                _navItem(icon: Icons.analytics_outlined, title: 'Reports', index: 9),

                _sectionHeader('PEOPLE & SETTINGS'),
                _navItem(icon: Icons.people_outline, title: 'Contacts', index: 6),
                _navItem(icon: Icons.badge_outlined, title: 'User Management', index: 12),
                _navItem(icon: Icons.notifications_none_outlined, title: 'Notification Templates', index: 16),
                _navItem(icon: Icons.settings_outlined, title: 'Settings', index: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
