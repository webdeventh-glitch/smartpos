import 'package:flutter/material.dart';
import '../models/models.dart';
import '../navigation/app_routes.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../utils/currency_formatter.dart';

class _CommandDestination {
  final AppRoute route;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final bool superAdminOnly;
  final String? requiredModule;

  const _CommandDestination({
    required this.route,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.keywords = const [],
    this.superAdminOnly = false,
    this.requiredModule,
  });
}

/// Global Ctrl+K Command Palette allowing instant jump to any screen, product, or customer.
class QuickCommandPaletteDialog extends StatefulWidget {
  final BusinessSettings settings;
  final ValueChanged<AppRoute> onNavigateToRoute;
  final VoidCallback onOpenPos;
  final ValueChanged<Product>? onEditProduct;

  const QuickCommandPaletteDialog({
    super.key,
    required this.settings,
    required this.onNavigateToRoute,
    required this.onOpenPos,
    this.onEditProduct,
  });

  static Future<void> show(
    BuildContext context, {
    required BusinessSettings settings,
    required ValueChanged<AppRoute> onNavigateToRoute,
    required VoidCallback onOpenPos,
    ValueChanged<Product>? onEditProduct,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QuickCommandPaletteDialog(
        settings: settings,
        onNavigateToRoute: onNavigateToRoute,
        onOpenPos: onOpenPos,
        onEditProduct: onEditProduct,
      ),
    );
  }

  @override
  State<QuickCommandPaletteDialog> createState() =>
      _QuickCommandPaletteDialogState();
}

class _QuickCommandPaletteDialogState extends State<QuickCommandPaletteDialog> {
  final TextEditingController _queryCtrl = TextEditingController();
  List<Product> _matchedProducts = [];
  List<Contact> _matchedContacts = [];
  bool _searchingDb = false;

  static const List<_CommandDestination> _destinations = [
    _CommandDestination(
      route: AppRoute.posTerminal,
      title: 'POS Terminal / Billing Counter',
      subtitle: 'Fast barcode billing, cash drawer, KOT & receipts',
      icon: Icons.point_of_sale_rounded,
      keywords: ['pos', 'sale', 'bill', 'checkout', 'counter', 'cashier'],
    ),
    _CommandDestination(
      route: AppRoute.dashboard,
      title: 'Dashboard / Home Overview',
      subtitle: 'Today sales, profit summary & pending orders',
      icon: Icons.dashboard_rounded,
      keywords: ['home', 'overview', 'stats'],
    ),
    _CommandDestination(
      route: AppRoute.productsList,
      title: 'Products & Stock List',
      subtitle: 'Browse inventory, edit prices, duplicate & view stock history',
      icon: Icons.inventory_2_outlined,
      keywords: ['items', 'catalog', 'sku', 'stock', 'price'],
    ),
    _CommandDestination(
      route: AppRoute.addProduct,
      title: 'Add New Product',
      subtitle: 'Create single or variable item with barcode & units',
      icon: Icons.add_box_outlined,
      keywords: ['new item', 'create product'],
    ),
    _CommandDestination(
      route: AppRoute.salesList,
      title: 'Sales & Invoices / Quotations',
      subtitle: 'Invoices, estimates/quotations & delivery challans',
      icon: Icons.receipt_long_rounded,
      keywords: ['invoice', 'quotation', 'estimate', 'challan'],
    ),
    _CommandDestination(
      route: AppRoute.purchasesList,
      title: 'Purchases / Stock In',
      subtitle: 'Supplier bills, batch/expiry intake & stock ledger',
      icon: Icons.shopping_bag_outlined,
      keywords: ['grn', 'stock in', 'supplier bill'],
    ),
    _CommandDestination(
      route: AppRoute.addPurchase,
      title: 'Add New Purchase',
      subtitle: 'Receive stock from supplier with batch & expiry',
      icon: Icons.add_shopping_cart_rounded,
      keywords: ['new purchase', 'receive stock'],
    ),
    _CommandDestination(
      route: AppRoute.customers,
      title: 'Customers & Khata Ledger',
      subtitle: 'Customer receivables, credit limits & payment recovery',
      icon: Icons.people_outline,
      keywords: ['udhaar', 'khata', 'receivable', 'client'],
    ),
    _CommandDestination(
      route: AppRoute.suppliers,
      title: 'Suppliers & Payables',
      subtitle: 'Distributor accounts, balances & supplier payments',
      icon: Icons.local_shipping_outlined,
      keywords: ['vendor', 'distributor', 'company'],
    ),
    _CommandDestination(
      route: AppRoute.expenses,
      title: 'Expenses',
      subtitle: 'Daily shop rent, electricity, salaries & misc costs',
      icon: Icons.money_off_csred_outlined,
      keywords: ['kharcha', 'bills', 'petty cash'],
      requiredModule: BusinessSettings.moduleExpenses,
    ),
    _CommandDestination(
      route: AppRoute.units,
      title: 'Units of Measure',
      subtitle: 'Pieces, Dozen, Kg, Gram, Coil, Box multipliers',
      icon: Icons.straighten_rounded,
      keywords: ['kg', 'pc', 'box', 'dozen', 'packing'],
    ),
    _CommandDestination(
      route: AppRoute.categories,
      title: 'Categories',
      subtitle: 'Organize products into departments & groups',
      icon: Icons.category_outlined,
    ),
    _CommandDestination(
      route: AppRoute.brands,
      title: 'Brands / Companies',
      subtitle: 'Manage manufacturers & product brands',
      icon: Icons.branding_watermark_outlined,
    ),
    _CommandDestination(
      route: AppRoute.printLabels,
      title: 'Print Barcode Labels',
      subtitle: 'Generate sticker barcode tags with price & SKU',
      icon: Icons.qr_code_2_rounded,
      keywords: ['sticker', 'barcode', 'tag'],
      requiredModule: BusinessSettings.modulePrintLabels,
    ),
    _CommandDestination(
      route: AppRoute.stockTransfers,
      title: 'Stock Transfers',
      subtitle: 'Move inventory between branches & warehouses',
      icon: Icons.swap_horiz_rounded,
      requiredModule: BusinessSettings.moduleStockTransfers,
    ),
    _CommandDestination(
      route: AppRoute.stockAdjustments,
      title: 'Stock Adjustments / Wastage',
      subtitle: 'Record damaged, spoiled or manual stock adjustments',
      icon: Icons.tune_rounded,
      keywords: ['spoilage', 'damage', 'wastage'],
      requiredModule: BusinessSettings.moduleStockAudit,
    ),
    _CommandDestination(
      route: AppRoute.inventoryAudit,
      title: 'Stock & Expiry Audit',
      subtitle: 'Check near-expiry medicines/items & physical stock count',
      icon: Icons.fact_check_outlined,
      keywords: ['expiry', 'batch', 'audit'],
      requiredModule: BusinessSettings.moduleStockAudit,
    ),
    _CommandDestination(
      route: AppRoute.salesReturn,
      title: 'Sales Returns',
      subtitle: 'Process customer refunds & return items to stock',
      icon: Icons.assignment_return_outlined,
      requiredModule: BusinessSettings.moduleReturns,
    ),
    _CommandDestination(
      route: AppRoute.purchaseReturn,
      title: 'Purchase Returns',
      subtitle: 'Return expired or defective stock to suppliers',
      icon: Icons.keyboard_return_rounded,
      requiredModule: BusinessSettings.moduleReturns,
    ),
    _CommandDestination(
      route: AppRoute.paymentAccounts,
      title: 'Payment Accounts / Bank & Cash',
      subtitle: 'Cash, JazzCash, EasyPaisa, Bank balances & transfers',
      icon: Icons.account_balance_outlined,
      keywords: ['bank', 'jazzcash', 'easypaisa'],
      requiredModule: BusinessSettings.moduleAccountingCrm,
    ),
    _CommandDestination(
      route: AppRoute.restaurantCafe,
      title: 'Restaurant Tables & KOT',
      subtitle: 'Dining tables, kitchen display & dine-in orders',
      icon: Icons.restaurant_rounded,
      keywords: ['table', 'kot', 'kitchen', 'dine'],
      requiredModule: BusinessSettings.moduleRestaurant,
    ),
    _CommandDestination(
      route: AppRoute.manufacturing,
      title: 'Manufacturing / Bakery BOM',
      subtitle: 'Recipes, raw material deduction & production batches',
      icon: Icons.precision_manufacturing_rounded,
      keywords: ['bakery', 'recipe', 'bom', 'production'],
      requiredModule: BusinessSettings.moduleManufacturing,
    ),
    _CommandDestination(
      route: AppRoute.repairService,
      title: 'Repair & Solar Service Jobs',
      subtitle: 'Job sheets, technician tracking & warranty repairs',
      icon: Icons.build_circle_outlined,
      keywords: ['solar', 'warranty', 'repair', 'service'],
      requiredModule: BusinessSettings.moduleRepair,
    ),
    _CommandDestination(
      route: AppRoute.reports,
      title: 'Business & Financial Reports',
      subtitle: 'Profit & Loss, Tax, Stock Valuation & Sales analytics',
      icon: Icons.analytics_outlined,
      keywords: ['profit', 'loss', 'tax', 'ledger', 'p&l'],
      superAdminOnly: true,
      requiredModule: BusinessSettings.moduleReporting,
    ),
    _CommandDestination(
      route: AppRoute.settings,
      title: 'System & Store Settings',
      subtitle: 'Printers, Tax rates, Invoice layout, Backups & Modules',
      icon: Icons.settings_outlined,
      keywords: ['printer', 'backup', 'tax', 'modules'],
      superAdminOnly: true,
    ),
  ];

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _matchedProducts = [];
        _matchedContacts = [];
        _searchingDb = false;
      });
      return;
    }

    setState(() => _searchingDb = true);
    try {
      final db = await DatabaseService.initialize();
      final prods = (await db.getProductsPaged(
        search: q,
        page: 1,
        pageSize: 6,
        includeTotalCount: false,
      ))
          .items;
      final contacts = await db.getContacts(search: q);
      if (mounted && _queryCtrl.text.trim() == q) {
        setState(() {
          _matchedProducts = prods;
          _matchedContacts = contacts.take(5).toList();
          _searchingDb = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchingDb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthService.currentUser;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final q = _queryCtrl.text.trim().toLowerCase();
    final currency = widget.settings.currencySymbol;

    final filteredRoutes = _destinations.where((d) {
      if (d.superAdminOnly && !isSuperAdmin) return false;
      if (d.requiredModule != null &&
          !widget.settings.isModuleEnabled(d.requiredModule!)) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.title.toLowerCase().contains(q) ||
          d.subtitle.toLowerCase().contains(q) ||
          d.keywords.any((k) => k.contains(q));
    }).take(q.isEmpty ? 8 : 6);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                controller: _queryCtrl,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText:
                      'Jump to any screen, search product, SKU, or customer...',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF4F46E5)),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchingDb)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ESC',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                children: [
                  if (_matchedProducts.isNotEmpty) ...[
                    _sectionTitle('Products (${_matchedProducts.length})'),
                    ..._matchedProducts.map((p) => ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFFEEF2FF),
                            child: Icon(Icons.inventory_2_outlined,
                                size: 16, color: Color(0xFF4F46E5)),
                          ),
                          title: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              'SKU: ${p.sku} • Stock: ${p.stockQuantity.toStringAsFixed(1)} ${p.unit}'),
                          trailing: Text(
                            CurrencyFormatter.compact(p.sellingPrice,
                                currency: '$currency '),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669)),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.onEditProduct != null) {
                              widget.onEditProduct!(p);
                            } else {
                              widget.onNavigateToRoute(AppRoute.productsList);
                            }
                          },
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (_matchedContacts.isNotEmpty) ...[
                    _sectionTitle(
                        'Customers & Suppliers (${_matchedContacts.length})'),
                    ..._matchedContacts.map((c) => ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: c.type == 'supplier'
                                ? const Color(0xFFFFEDD5)
                                : const Color(0xFFECFDF5),
                            child: Icon(
                              c.type == 'supplier'
                                  ? Icons.local_shipping_outlined
                                  : Icons.person_outline,
                              size: 16,
                              color: c.type == 'supplier'
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFF059669),
                            ),
                          ),
                          title: Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${c.type.toUpperCase()} • ${c.phone.isEmpty ? "No Phone" : c.phone}'),
                          trailing: Text(
                            CurrencyFormatter.compact(c.balance,
                                currency: '$currency '),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: c.balance > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onNavigateToRoute(c.type == 'supplier'
                                ? AppRoute.suppliers
                                : AppRoute.customers);
                          },
                        )),
                    const SizedBox(height: 8),
                  ],
                  _sectionTitle(
                      q.isEmpty ? 'Quick Actions' : 'Screens & Pages'),
                  ...filteredRoutes.map((d) => ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(d.icon,
                              size: 17, color: const Color(0xFF4F46E5)),
                        ),
                        title: Text(d.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Text(d.subtitle,
                            style: const TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          if (d.route == AppRoute.posTerminal) {
                            widget.onOpenPos();
                          } else {
                            widget.onNavigateToRoute(d.route);
                          }
                        },
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
