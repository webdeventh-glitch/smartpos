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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Tooltip(
          message: title,
          child: InkWell(
            onTap: () => widget.onSelect(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEBF3FE) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF334155),
                  ),
                ),
              ),
              if (hasSubmenu)
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  size: 16,
                  color: const Color(0xFF94A3B8),
                ),
            ],
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
      padding: const EdgeInsets.only(left: 36, right: 10, top: 2, bottom: 2),
      child: InkWell(
        onTap: () => widget.onSelect(index),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF3FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF475569),
            ),
          ),
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
          // Search menu... input (Screenshot 1 top left)
          if (!widget.isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
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
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
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
                _navItem(icon: Icons.home_outlined, title: 'Home', index: 0),
                _navItem(icon: Icons.group_outlined, title: 'User Management', index: 12, hasSubmenu: true),
                _navItem(icon: Icons.contacts_outlined, title: 'Contacts', index: 6, hasSubmenu: true),

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
                  _subItem(title: 'Categories', index: 3),
                  _subItem(title: 'Units & Brands', index: 3),
                ],

                _navItem(icon: Icons.arrow_downward_outlined, title: 'Purchases', index: 5, hasSubmenu: true),

                // Sell / POS (with dropdown submenus)
                _navItem(
                  icon: Icons.arrow_upward_outlined,
                  title: 'Sell',
                  index: 4,
                  hasSubmenu: true,
                  isExpanded: _sellExpanded,
                  onToggleSubmenu: () => setState(() => _sellExpanded = !_sellExpanded),
                ),
                if (!widget.isCollapsed && _sellExpanded) ...[
                  _subItem(title: 'All Sales', index: 4),
                  _subItem(title: 'POS Terminal', index: 1),
                  _subItem(title: 'Drafts', index: 4),
                  _subItem(title: 'Quotations', index: 4),
                ],

                _navItem(icon: Icons.local_shipping_outlined, title: 'Stock Transfers', index: 13, hasSubmenu: true),
                _navItem(icon: Icons.balance_outlined, title: 'Stock Adjustment', index: 14, hasSubmenu: true),
                _navItem(icon: Icons.attach_money_outlined, title: 'Expenses', index: 8, hasSubmenu: true),
                _navItem(icon: Icons.account_balance_outlined, title: 'Payment Accounts', index: 15, hasSubmenu: true),
                _navItem(icon: Icons.bar_chart_outlined, title: 'Reports', index: 9, hasSubmenu: true),
                _navItem(icon: Icons.mail_outline, title: 'Notification Templates', index: 16),
                _navItem(icon: Icons.settings_outlined, title: 'Settings', index: 10, hasSubmenu: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
