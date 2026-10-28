import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'quick_customer_dialog.dart';
import 'customer_search_dialog.dart';
import '../expenses/add_expense_dialog.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'parked_sales_dialog.dart';
import 'register_details_dialog.dart';
import 'pos_power_dialogs.dart';
import '../../widgets/calculator_dialog.dart';

class PosTerminalScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onBackToDashboard;

  const PosTerminalScreen({
    super.key,
    required this.settings,
    this.onBackToDashboard,
  });

  @override
  State<PosTerminalScreen> createState() => _PosTerminalScreenState();
}

class _PosTerminalScreenState extends State<PosTerminalScreen> {
  late Future<DatabaseService> _dbFuture;

  // Cart State
  final List<CartItem> _cart = [];
  Contact? _selectedCustomer;
  List<Contact> _customers = [];

  // Industry Mode Extensions
  String _diningMode = 'Dine-In'; // 'Dine-In', 'Takeaway', 'Delivery'
  String _selectedTable = 'Table 1';
  String _assignedWaiter = 'Waiter 1';
  bool _isQuotationMode = false;

  // Search & Catalog
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Category> _categories = [];
  List<Brand> _brands = [];
  int? _selectedCategoryId;
  int? _selectedBrandId;
  bool _filterFeatured = false;
  List<Product> _allProducts = [];
  List<Product> _products = [];
  bool _loadingCatalog = true;
  bool _isGridView = true; // Switchable layout: Grid vs List view

  // Calculation parameters
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  double _discountValue = 0.0;
  double _orderTax = 0.0;
  double _shippingCharge = 0.0;

  // Parked bills count
  int _parkedCount = 0;

  // Wholesale vs Retail Counter Pricing Tier
  bool _isWholesaleMode = false;
  final double _wholesaleDiscountPercent = 10.0;

  @override
  void initState() {
    super.initState();
    _dbFuture = DatabaseService.initialize();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = await _dbFuture;
    final customers = await db.getContacts(type: 'customer');
    final categories = await db.getCategories();
    final brands = await db.getBrands();
    final products = await db.getProducts();
    final parked = await db.getParkedSales();

    Contact? defaultCust;
    try {
      defaultCust = customers.firstWhere((c) => c.name.toLowerCase().contains('walk-in') || c.name.toLowerCase().contains('walk in'));
    } catch (_) {
      defaultCust = customers.isNotEmpty ? customers.first : null;
    }

    if (mounted) {
      setState(() {
        _customers = customers;
        _selectedCustomer = defaultCust;
        _categories = categories;
        _brands = brands;
        _allProducts = products;
        _products = products;
        _parkedCount = parked.length;
        _loadingCatalog = false;
      });
    }
  }

  /// Blazing Fast In-Memory Product Filter (0ms delay across 2,500+ items)
  void _applyProductFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _products = _allProducts.where((p) {
        if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) return false;
        if (_selectedBrandId != null && p.brandId != _selectedBrandId) return false;
        if (_filterFeatured && ((p.id ?? 0) % 5 != 0)) return false;
        if (q.isNotEmpty) {
          final nameMatch = p.name.toLowerCase().contains(q);
          final skuMatch = p.sku.toLowerCase().contains(q);
          final barcodeMatch = p.barcode.toLowerCase().contains(q);
          final batchMatch = p.batchNumber != null && p.batchNumber!.toLowerCase().contains(q);
          if (!nameMatch && !skuMatch && !barcodeMatch && !batchMatch) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _filterProducts({int? categoryId, int? brandId, String? search}) async {
    _selectedCategoryId = categoryId;
    _selectedBrandId = brandId;
    _applyProductFilter();
  }

  void _toggleProductLayout() {
    setState(() {
      _isGridView = !_isGridView;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isGridView ? Icons.grid_view_rounded : Icons.format_list_bulleted_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              _isGridView ? 'Switched to Grid View [F5]' : 'Switched to List View [F5]',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        width: 270,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCategoryFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.grid_view_outlined, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text('Filter by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                                   const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textSecondary),
              onPressed: () => Navigator.pop(ctx),
              splashRadius: 16,
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Color(0xFF4F46E5)),
                title: Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                trailing: _selectedCategoryId == null ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20) : null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  _applyProductFilter();
                  Navigator.pop(ctx);
                },
              ),
              Divider(height: 1, color: borderColor),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSel = _selectedCategoryId == cat.id;
                    return ListTile(
                      title: Text(cat.name, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: textPrimary)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20) : null,
                      onTap: () {
                        setState(() => _selectedCategoryId = cat.id);
                        _applyProductFilter();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBrandFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            const Icon(Icons.branding_watermark_outlined, color: Color(0xFF4F46E5), size: 20),
            const SizedBox(width: 8),
            Text('Filter by Brand', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                                   const SizedBox(width: 16),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: textSecondary),
              onPressed: () => Navigator.pop(ctx),
              splashRadius: 16,
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Color(0xFF4F46E5)),
                title: Text('All Brands', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                trailing: _selectedBrandId == null ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20) : null,
                onTap: () {
                  setState(() => _selectedBrandId = null);
                  _applyProductFilter();
                  Navigator.pop(ctx);
                },
              ),
              Divider(height: 1, color: borderColor),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _brands.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                  itemBuilder: (_, i) {
                    final b = _brands[i];
                    final isSel = _selectedBrandId == b.id;
                    return ListTile(
                      title: Text(b.name, style: TextStyle(fontSize: 13, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: textPrimary)),
                      trailing: isSel ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20) : null,
                      onTap: () {
                        setState(() => _selectedBrandId = b.id);
                        _applyProductFilter();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDiscountDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add products to cart before applying discount.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUser = AuthService.currentUser;
    final canGiveDiscount = currentUser?.canGiveDiscount ?? (currentUser?.isAdmin ?? true);
    final maxDiscPercent = currentUser?.maxDiscountPercent ?? ((currentUser?.isAdmin == true) ? 100.0 : 5.0);

    if (!canGiveDiscount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission Denied: Discounting is disabled for this salesman account by the Owner.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    String tempType = _discountType;
    final controller = TextEditingController(
      text: _discountValue > 0 ? (_discountValue.truncateToDouble() == _discountValue ? _discountValue.toInt().toString() : _discountValue.toString()) : '',
    );
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final inputVal = double.tryParse(controller.text.trim()) ?? 0.0;
          double calcDiscAmt = 0.0;
          if (tempType == 'percentage') {
            calcDiscAmt = (_subtotal * (inputVal / 100.0)).clamp(0.0, _subtotal);
          } else {
            calcDiscAmt = inputVal.clamp(0.0, _subtotal);
          }
          final newTotal = (_subtotal - calcDiscAmt + _orderTax + _shippingCharge).clamp(0.0, double.infinity);

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.discount_outlined, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 10),
                Text('Order Discount System', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                                   const SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 16,
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discount Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: 8),

                  // Segmented Switcher: [ % Percentage ] [ Fixed Amount ]
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: inputBorder),
                    ),
                    child: Row(
                      children: [
                        // Percentage Button
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() => tempType = 'percentage'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tempType == 'percentage' ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: tempType == 'percentage'
                                    ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.percent, size: 14, color: tempType == 'percentage' ? Colors.white : textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Percentage (%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tempType == 'percentage' ? Colors.white : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Fixed Amount Button
                        Expanded(
                          child: InkWell(
                            onTap: () => setDlgState(() => tempType = 'fixed'),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tempType == 'fixed' ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: tempType == 'fixed'
                                    ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.payments_outlined, size: 14, color: tempType == 'fixed' ? Colors.white : textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fixed ($currency)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: tempType == 'fixed' ? Colors.white : textSecondary,
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
                  const SizedBox(height: 14),

                  // Discount Value Input Field
                  Text(
                    tempType == 'percentage' ? 'Enter Percentage Rate (%)' : 'Enter Fixed Discount Amount ($currency)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14, color: textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBg,
                      prefixIcon: Icon(
                        tempType == 'percentage' ? Icons.percent : Icons.attach_money,
                        size: 18,
                        color: const Color(0xFF4F46E5),
                      ),
                      suffixText: tempType == 'percentage' ? '%' : currency,
                      suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: textSecondary),
                      hintText: tempType == 'percentage' ? 'e.g. 10' : 'e.g. 150',
                      hintStyle: TextStyle(color: textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Quick Preset Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tempType == 'percentage'
                        ? [
                            _presetChip('0%', 0, controller, setDlgState, isDark),
                            _presetChip('5%', 5, controller, setDlgState, isDark),
                            _presetChip('10%', 10, controller, setDlgState, isDark),
                            _presetChip('15%', 15, controller, setDlgState, isDark),
                            _presetChip('20%', 20, controller, setDlgState, isDark),
                            _presetChip('25%', 25, controller, setDlgState, isDark),
                            _presetChip('50%', 50, controller, setDlgState, isDark),
                          ]
                        : [
                            _presetChip('Clear', 0, controller, setDlgState, isDark),
                            _presetChip('50', 50, controller, setDlgState, isDark),
                            _presetChip('100', 100, controller, setDlgState, isDark),
                            _presetChip('200', 200, controller, setDlgState, isDark),
                            _presetChip('500', 500, controller, setDlgState, isDark),
                            _presetChip('1000', 1000, controller, setDlgState, isDark),
                          ],
                  ),
                  const SizedBox(height: 14),

                  // Live Calculation Preview Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: subtleBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal:', style: TextStyle(fontSize: 12, color: textSecondary)),
                            Text('$currency ${_subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${tempType == 'percentage' ? '${inputVal.toStringAsFixed(0)}%' : 'Fixed'}):',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                            ),
                            Text('- $currency ${calcDiscAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                          ],
                        ),
                        Divider(height: 12, color: borderColor),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('New Total Payable:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            Text('$currency ${newTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _discountValue = 0.0;
                    _discountType = 'fixed';
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Discount removed.'),
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF475569),
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
                child: const Text('Clear Discount', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final parsed = double.tryParse(controller.text.trim()) ?? 0.0;

                  if (tempType == 'percentage' && parsed > maxDiscPercent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Limit Exceeded: Maximum authorized discount for this salesman is ${maxDiscPercent.toStringAsFixed(0)}%!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (tempType == 'fixed' && _subtotal > 0) {
                    final effectivePct = (parsed / _subtotal) * 100.0;
                    if (effectivePct > maxDiscPercent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fixed discount exceeds your maximum authorized rate of ${maxDiscPercent.toStringAsFixed(0)}%!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  setState(() {
                    _discountType = tempType;
                    _discountValue = parsed;
                  });
                  Navigator.pop(ctx);

                  final saved = _calculatedDiscount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _discountValue > 0
                            ? 'Discount applied: $currency ${saved.toStringAsFixed(2)} saved!'
                            : 'Discount updated.',
                      ),
                      backgroundColor: const Color(0xFF16A34A),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _presetChip(String label, double val, TextEditingController c, StateSetter setDlgState, [bool isDark = false]) {
    return InkWell(
      onTap: () {
        setDlgState(() {
          c.text = val > 0 ? (val.truncateToDouble() == val ? val.toInt().toString() : val.toString()) : '';
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))),
      ),
    );
  }

  void _toggleWholesaleMode() {
    setState(() {
      _isWholesaleMode = !_isWholesaleMode;
      for (final item in _cart) {
        if (_isWholesaleMode) {
          if (item.packDiscount == 0.0) {
            item.packDiscount = _wholesaleDiscountPercent;
          }
        } else {
          if (item.packDiscount == _wholesaleDiscountPercent) {
            item.packDiscount = 0.0;
          }
        }
      }
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isWholesaleMode ? Icons.inventory_2_rounded : Icons.storefront_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isWholesaleMode
                    ? 'Wholesale Tier Mode: Activated (${_wholesaleDiscountPercent.toInt()}% Bulk Markdown / ہول سیل ریٹ فعال)'
                    : 'Retail Mode: Activated (معمول کا ریٹیل ریٹ فعال)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: _isWholesaleMode ? const Color(0xFF0891B2) : const Color(0xFF1E293B),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openCustomProductDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'Pc';
    final currency = widget.settings.currencySymbol;

    final commonUnits = ['Pc', 'Kg', 'Ltr', 'Mtr', 'Box', 'Ctn', 'Pkt', 'Bag', 'Dzn', 'Sq Ft', 'Roll'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x1F4F46E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Open / Custom Item (اوپن آئٹم)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      Text(
                        'Sell uncataloged walk-in item, loose weight, cut or service directly',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item Description / Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Loose Sugar, Cut Iron 10m, Labor Charge, Custom Part',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit Price ($currency) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantity (Decimals OK) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 14, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: '1.0',
                                  hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick decimal quantity presets
                    Row(
                      children: [
                        Text('Quick Qty: ', style: TextStyle(fontSize: 11, color: textSecondary)),
                        Wrap(
                          spacing: 5,
                          children: [0.25, 0.5, 1.0, 1.5, 2.5, 5.0].map((q) {
                            return InkWell(
                              onTap: () {
                                qtyCtrl.text = q == q.toInt() ? q.toInt().toString() : q.toString();
                                setDlgState(() {});
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: borderColor, width: 0.8),
                                ),
                                child: Text(
                                  q == q.toInt() ? q.toInt().toString() : q.toString(),
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text('Measurement Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: commonUnits.map((u) {
                        final isSel = selectedUnit == u;
                        return InkWell(
                          onTap: () => setDlgState(() => selectedUnit = u),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              u,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : textPrimary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an item description.')),
                    );
                    return;
                  }
                  if (price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid price.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final customProduct = Product(
                    id: null,
                    name: name,
                    sku: 'OPEN-${DateTime.now().millisecondsSinceEpoch % 100000}',
                    barcode: '',
                    unit: selectedUnit,
                    purchasePrice: price,
                    sellingPrice: price,
                    stockQuantity: 9999.0,
                  );
                  setState(() {
                    _cart.add(CartItem(
                      product: customProduct,
                      quantity: qty,
                      unitPrice: price,
                      packDiscount: _isWholesaleMode ? _wholesaleDiscountPercent : 0.0,
                    ));
                  });
                },
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openQuantityDialog(CartItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final initialQty = item.quantity == item.quantity.toInt()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final qtyCtrl = TextEditingController(text: initialQty);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final curQty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
          final totalVal = curQty * item.unitPrice;

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.scale_rounded, color: Color(0xFF4F46E5), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Adjust Quantity / Weight',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                ),
                                Text(
                                  'مقدار یا وزن درج کریں • ${item.product.name}',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20, color: textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product & Current Unit
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Unit of Measure', style: TextStyle(fontSize: 10, color: textSecondary)),
                              Text(item.product.unit.isNotEmpty ? item.product.unit : 'Standard Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Rate / Unit', style: TextStyle(fontSize: 10, color: textSecondary)),
                              Text('${widget.settings.currencySymbol} ${item.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Direct input field
                    Text('Enter Exact Quantity (Decimals allowed e.g. 1.5, 0.75, 2.25)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: qtyCtrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: inputBg,
                        suffixText: item.product.unit,
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Quick decimal & fraction presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        {'label': '0.25 (Pao)', 'val': 0.25},
                        {'label': '0.50 (Aadha)', 'val': 0.50},
                        {'label': '0.75 (3 Pao)', 'val': 0.75},
                        {'label': '1.0', 'val': 1.0},
                        {'label': '1.5', 'val': 1.5},
                        {'label': '2.0', 'val': 2.0},
                        {'label': '2.5 (Suit)', 'val': 2.5},
                        {'label': '5.0 (Dhari)', 'val': 5.0},
                        {'label': '10.0', 'val': 10.0},
                        {'label': '40.0 (Mann)', 'val': 40.0},
                      ].map((p) {
                        return InkWell(
                          onTap: () {
                            qtyCtrl.text = p['val'].toString();
                            setDlgState(() {});
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              p['label'] as String,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Total Calculation Preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Calculated Line Total:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textPrimary)),
                          Text(
                            '${widget.settings.currencySymbol} ${totalVal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: TextStyle(color: textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            final newQty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
                            if (newQty <= 0) {
                              setState(() => _cart.removeAt(index));
                            } else {
                              setState(() => item.quantity = newQty);
                            }
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Apply Quantity'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final currentUser = AuthService.currentUser;
    final canEditPrice = currentUser?.canEditPrice ?? (currentUser?.isAdmin ?? false);
    final canGiveDiscount = currentUser?.canGiveDiscount ?? (currentUser?.isAdmin ?? true);
    final maxDiscPercent = currentUser?.maxDiscountPercent ?? ((currentUser?.isAdmin == true) ? 100.0 : 5.0);

    String lineDiscType = item.packDiscount > 0 ? 'percentage' : 'fixed';
    final priceCtrl = TextEditingController(text: item.unitPrice.toStringAsFixed(2));
    final discCtrl = TextEditingController(
      text: item.packDiscount > 0
          ? (item.packDiscount.truncateToDouble() == item.packDiscount ? item.packDiscount.toInt().toString() : item.packDiscount.toString())
          : (item.discount > 0 ? (item.discount.truncateToDouble() == item.discount ? item.discount.toInt().toString() : item.discount.toString()) : ''),
    );
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final curUnitPrice = double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
          final curDiscVal = double.tryParse(discCtrl.text.trim()) ?? 0.0;
          final packVal = curUnitPrice * item.quantity;
          double lineDiscAmt = 0.0;
          if (lineDiscType == 'percentage') {
            lineDiscAmt = (packVal * (curDiscVal / 100.0)).clamp(0.0, packVal);
          } else {
            lineDiscAmt = curDiscVal.clamp(0.0, packVal);
          }
          final lineSubtotal = packVal - lineDiscAmt;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Item Pricing: ${item.product.name}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 16,
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Price
                  Row(
                    children: [
                      Text('Unit Price ($currency)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                                   const SizedBox(width: 16),
                      if (!canEditPrice)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 10, color: Color(0xFFD97706)),
                              SizedBox(width: 3),
                              Text('Locked by Owner', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    readOnly: !canEditPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14, color: !canEditPrice ? const Color(0xFF94A3B8) : textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: !canEditPrice ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)) : inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),

                  if (!canGiveDiscount) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Discounts are restricted for this account by the Business Owner.',
                              style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Discount Type
                    Row(
                      children: [
                        Text('Discount Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                                   const SizedBox(width: 16),
                        Text('Max Limit: ${maxDiscPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 34,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => lineDiscType = 'percentage'),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: lineDiscType == 'percentage' ? const Color(0xFF4F46E5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Percentage (%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lineDiscType == 'percentage' ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => lineDiscType = 'fixed'),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: lineDiscType == 'fixed' ? const Color(0xFF4F46E5) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Fixed ($currency)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: lineDiscType == 'fixed' ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Discount Value
                    Text(
                      lineDiscType == 'percentage' ? 'Discount Rate (%)' : 'Discount Amount ($currency)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: discCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 14, color: textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                        suffixText: lineDiscType == 'percentage' ? '%' : currency,
                        suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: textSecondary),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Preview
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: subtleBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Line Subtotal (${item.quantity.toInt()} ${item.product.unit}):', style: TextStyle(fontSize: 12, color: textSecondary)),
                        Text('$currency ${lineSubtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    item.discount = 0.0;
                    item.packDiscount = 0.0;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Clear Discount', style: TextStyle(color: Color(0xFFEF4444))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                onPressed: () {
                  final newPrice = double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
                  final newDisc = double.tryParse(discCtrl.text.trim()) ?? 0.0;

                  if (newPrice != item.unitPrice && !canEditPrice) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permission Denied: Changing unit prices is not authorized for this salesman account.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (newDisc > 0 && !canGiveDiscount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Permission Denied: Discounts are disabled for this account.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (lineDiscType == 'percentage' && newDisc > maxDiscPercent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Limit Exceeded: Maximum authorized discount is ${maxDiscPercent.toStringAsFixed(0)}%!'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  if (lineDiscType == 'fixed' && item.unitPrice > 0) {
                    final effective = (newDisc / (item.unitPrice * item.quantity)) * 100.0;
                    if (effective > maxDiscPercent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fixed discount exceeds maximum allowed rate of ${maxDiscPercent.toStringAsFixed(0)}%!'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                  }

                  setState(() {
                    item.unitPrice = newPrice;
                    if (lineDiscType == 'percentage') {
                      item.packDiscount = newDisc;
                      item.discount = 0.0;
                    } else {
                      item.discount = newDisc;
                      item.packDiscount = 0.0;
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Update Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showOrderTaxDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final controller = TextEditingController(text: _orderTax > 0 ? _orderTax.toString() : '');
    final currency = widget.settings.currencySymbol;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Order Tax', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Tax Amount:', style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                prefixText: '$currency ',
                prefixStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _orderTax = 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _orderTax = double.tryParse(controller.text.trim()) ?? 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showShippingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final controller = TextEditingController(text: _shippingCharge > 0 ? _shippingCharge.toString() : '');
    final currency = widget.settings.currencySymbol;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Shipping & Delivery Charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Delivery / Shipping Charge:', style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 14, color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBg,
                prefixText: '$currency ',
                prefixStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _shippingCharge = 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _shippingCharge = double.tryParse(controller.text.trim()) ?? 0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product) {
    if (product.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is OUT OF STOCK!'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        _cart[index].quantity += 1.0;
      } else {
        _cart.add(CartItem(
          product: product,
          quantity: 1.0,
          unitPrice: product.sellingPrice,
          packDiscount: _isWholesaleMode ? _wholesaleDiscountPercent : 0.0,
        ));
      }
    });
  }

  void _addToCartWithQuantity(Product product, double qty) {
    if (product.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is OUT OF STOCK!'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id && item.unitPrice == product.sellingPrice);
      if (index >= 0) {
        _cart[index].quantity += qty;
      } else {
        _cart.add(CartItem(
          product: product,
          quantity: qty,
          unitPrice: product.sellingPrice,
          packDiscount: _isWholesaleMode ? _wholesaleDiscountPercent : 0.0,
        ));
      }
    });
  }

  void _onBarcodeSubmitted(String code) async {
    final trimmed = code.trim().toLowerCase();
    if (trimmed.isEmpty) return;

    // 0. Electronic Weight-Scale Barcode Parsing (EAN-13 prefix '20' or '02')
    if (trimmed.length == 13 && (trimmed.startsWith('20') || trimmed.startsWith('02'))) {
      final itemCode = trimmed.substring(2, 7);
      final weightGrams = int.tryParse(trimmed.substring(7, 12)) ?? 0;
      final weightKg = weightGrams > 0 ? (weightGrams / 1000.0) : 1.0;

      Product? scaleItem;
      try {
        scaleItem = _allProducts.firstWhere(
          (p) => p.sku.toLowerCase().contains(itemCode) || p.barcode.toLowerCase().contains(itemCode),
        );
      } catch (_) {}

      if (scaleItem != null) {
        _addToCartWithQuantity(scaleItem, weightKg);
        _searchController.clear();
        _applyProductFilter();
        _searchFocusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weight-Scale parsed: ${scaleItem.name} — ${weightKg.toStringAsFixed(3)} kg'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return;
      }
    }

    // 1. In-memory exact lookup
    Product? matched;
    try {
      matched = _allProducts.firstWhere(
        (p) => (p.barcode.toLowerCase() == trimmed) || (p.sku.toLowerCase() == trimmed),
      );
    } catch (_) {}

    if (matched != null) {
      _addToCart(matched);
      _searchController.clear();
      _applyProductFilter();
      _searchFocusNode.requestFocus();
      return;
    }

    // 2. Fallback to database lookup
    final db = await _dbFuture;
    final product = await db.getProductByCode(code.trim());
    if (product != null) {
      _addToCart(product);
      _searchController.clear();
      _applyProductFilter();
      _searchFocusNode.requestFocus();
    } else {
      _applyProductFilter();
    }
  }

  // Industry POS Extensions
  void _openKotDialog() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add food items first.'), backgroundColor: Colors.orange),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => KotTicketDialog(
        table: _selectedTable,
        waiter: _assignedWaiter,
        diningMode: _diningMode,
        items: List.from(_cart),
        settings: widget.settings,
      ),
    );
  }

  void _openSolarBundleDialog() {
    showDialog(
      context: context,
      builder: (_) => SolarBundleDialog(
        settings: widget.settings,
        products: _allProducts,
        onBundleSelected: (bundleItems) {
          setState(() {
            _cart.addAll(bundleItems);
          });
        },
      ),
    );
  }

  void _openImeiModal() {
    showDialog(
      context: context,
      builder: (_) => ImeiPickerDialog(
        product: _cart.isNotEmpty ? _cart.last.product : Product(
          name: 'Mobile Phone Device',
          sku: 'MOB-GEN',
          barcode: 'MOB-GEN',
          purchasePrice: 40000.0,
          sellingPrice: 50000.0,
          stockQuantity: 10.0,
        ),
        serials: const [],
        onSerialSelected: (imei) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attached IMEI/Serial: $imei to sale invoice!'), backgroundColor: const Color(0xFF4F46E5)),
          );
        },
      ),
    );
  }

  // Calculations
  double get _calculatedDiscount {
    double d = 0.0;
    if (_discountType == 'percentage') {
      d = (_subtotal * (_discountValue / 100.0));
    } else {
      d = _discountValue;
    }
    return d.clamp(0.0, _subtotal);
  }

  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _grandTotal => (_subtotal - _calculatedDiscount + _orderTax + _shippingCharge).clamp(0.0, double.infinity);
  double get _totalQuantity => _cart.fold(0.0, (sum, item) => sum + item.quantity);

  // Checkout Actions
  Future<void> _processCheckout({
    required String paymentMethod,
    required double paidAmount,
    required double tendered,
    required double changeReturn,
    required String paymentStatus,
    String saleStatus = 'final',
    String note = '',
    List<Map<String, dynamic>>? splitTenders,
  }) async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to cart before checkout!'), backgroundColor: Colors.orange),
      );
      return;
    }

    final db = await _dbFuture;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final invoiceNo = await db.generateNextInvoiceNo();

    final sale = Sale(
      invoiceNo: invoiceNo,
      customerId: _selectedCustomer?.id,
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      subtotal: _subtotal,
      discount: _calculatedDiscount,
      taxAmount: _orderTax,
      taxRate: widget.settings.defaultTaxRate,
      shipping: _shippingCharge,
      totalAmount: _grandTotal,
      paidAmount: paidAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      saleStatus: saleStatus,
      note: note,
      createdAt: now,
    );

    final completedSale = await db.createSale(
      sale: sale,
      items: List.from(_cart),
      splitTenders: splitTenders,
    );

    if (mounted) {
      setState(() {
        _cart.clear();
        _discountValue = 0.0;
        _discountType = 'fixed';
        _orderTax = 0.0;
        _shippingCharge = 0.0;
      });
      _loadInitialData();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReceiptDialog(
          sale: completedSale,
          settings: widget.settings,
          tenderedAmount: tendered,
          changeReturn: changeReturn,
        ),
      );
    }
  }

  void _quickCashCheckout() {
    _processCheckout(
      paymentMethod: 'cash',
      paidAmount: _grandTotal,
      tendered: _grandTotal,
      changeReturn: 0.0,
      paymentStatus: 'paid',
    );
  }

  void _quickCardCheckout() {
    _processCheckout(
      paymentMethod: 'card',
      paidAmount: _grandTotal,
      tendered: _grandTotal,
      changeReturn: 0.0,
      paymentStatus: 'paid',
    );
  }

  void _quickCreditCheckout() {
    final isWalkIn = _selectedCustomer == null || _selectedCustomer!.id == null;
    if (isWalkIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Strict Walk-in Rule: Credit checkout is strictly restricted to registered account holders. Please select or add a customer account.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    _processCheckout(
      paymentMethod: 'credit',
      paidAmount: 0.0,
      tendered: 0.0,
      changeReturn: 0.0,
      paymentStatus: 'due',
      note: 'Credit sale (balance due on account)',
    );
  }

  void _openPaymentModal() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add products first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final isWalkIn = _selectedCustomer == null || _selectedCustomer!.id == null;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PaymentModal(
        grandTotal: _grandTotal,
        currencySymbol: widget.settings.currencySymbol,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
        isWalkIn: isWalkIn,
        customerCreditLimit: _selectedCustomer?.creditLimit ?? 0.0,
        customerCurrentBalance: _selectedCustomer?.balance ?? 0.0,
      ),
    );

    if (result != null) {
      final splitTenders = (result['splitTenders'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      _processCheckout(
        paymentMethod: result['method'] as String,
        paidAmount: result['paidAmount'] as double,
        tendered: result['tendered'] as double,
        changeReturn: result['change'] as double,
        paymentStatus: result['paymentStatus'] as String,
        splitTenders: splitTenders.isNotEmpty ? splitTenders : null,
        note: result['note'] as String,
      );
    }
  }

  Future<void> _suspendSale() async {
    if (_cart.isEmpty) return;
    final db = await _dbFuture;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final itemsMap = _cart.map((e) => e.toSavedStateMap()).toList();
    final parked = ParkedSale(
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      note: 'Held at ${DateFormat('hh:mm a').format(DateTime.now())}',
      total: _grandTotal,
      createdAt: now,
      itemsJson: jsonEncode(itemsMap),
    );

    await db.parkSale(parked);
    final allParked = await db.getParkedSales();

    setState(() {
      _cart.clear();
      _parkedCount = allParked.length;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale suspended (${allParked.length} held). Next customer can be served.'),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
    }
  }

  void _openParkedSales() {
    showDialog(
      context: context,
      builder: (_) => ParkedSalesDialog(
        onResumeSale: (parked) {
          setState(() {
            _cart.clear();
            _cart.addAll(parked.getItems());
            final foundCust = _customers.where((c) => c.name == parked.customerName);
            if (foundCust.isNotEmpty) _selectedCustomer = foundCust.first;
          });
          _dbFuture.then((db) => db.getParkedSales()).then((list) {
            if (mounted) setState(() => _parkedCount = list.length);
          });
        },
      ),
    );
  }

  void _saveQuotation() {
    _processCheckout(
      paymentMethod: 'none',
      paidAmount: 0.0,
      tendered: 0.0,
      changeReturn: 0.0,
      paymentStatus: 'due',
      saleStatus: 'quotation',
      note: 'Quotation estimate only',
    );
  }

  void _clearCart() {
    if (_cart.isEmpty) return;

    final currentUser = AuthService.currentUser;
    final canDeleteSale = currentUser?.canDeleteSale ?? (currentUser?.isAdmin ?? true);

    if (!canDeleteSale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission Denied: Discarding active carts requires Manager or Owner authorization.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Cancel & Clear Cart?', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to discard all items in the current order?', style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('No, Keep', style: TextStyle(color: textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _cart.clear();
                _discountValue = 0.0;
                _discountType = 'fixed';
                _orderTax = 0.0;
                _shippingCharge = 0.0;
              });
            },
            child: const Text('Yes, Clear Cart'),
          ),
        ],
      ),
    );
  }

  void _openQuickCustomerModal() {
    showDialog(
      context: context,
      builder: (_) => QuickCustomerDialog(
        onCustomerAdded: (newCustomer) {
          setState(() {
            _customers.add(newCustomer);
            _selectedCustomer = newCustomer;
          });
        },
      ),
    );
  }

  void _openCustomerSearchModal() {
    showDialog(
      context: context,
      builder: (_) => CustomerSearchDialog(
        customers: _customers,
        selectedCustomer: _selectedCustomer,
        currencySymbol: widget.settings.currencySymbol,
        onCustomerSelected: (c) {
          setState(() => _selectedCustomer = c);
        },
      ),
    );
  }

  void _resetToWalkInCustomer() {
    Contact? walkIn;
    try {
      walkIn = _customers.firstWhere((c) => c.name.toLowerCase().contains('walk-in') || c.name.toLowerCase().contains('walk in'));
    } catch (_) {
      walkIn = _customers.isNotEmpty ? _customers.first : null;
    }
    if (walkIn != null) {
      setState(() => _selectedCustomer = walkIn);
    }
  }

  void _showShortcutsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: cardBg,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.keyboard_rounded, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'POS Terminal Shortcuts',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textPrimary),
                          ),
                          Text(
                            'Quick keyboard hotkeys for rapid cashier operation',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                    splashRadius: 18,
                  ),
                ],
              ),
              Divider(height: 24, color: borderColor),

              _shortcutRow('F1', 'Keyboard Shortcuts Help Modal', isDark),
              _shortcutRow('F2', 'Quick Cash Pay (Instant Complete)', isDark),
              _shortcutRow('F3', 'Live Customer Search (Name, Phone, Medical Store)', isDark),
              _shortcutRow('F4', 'Suspend / Park Current Sale Order', isDark),
              _shortcutRow('F5', 'Toggle Product View (Grid / List)', isDark),
              _shortcutRow('F6', 'Add New Customer (Quick Modal)', isDark),
              _shortcutRow('F7', 'Multiple / Split Pay Modal', isDark),
              _shortcutRow('F8', 'Cancel Sale / Clear Cart', isDark),
              _shortcutRow('F9', 'Open Calculator', isDark),
              _shortcutRow('F10', 'Register Details & Session', isDark),
              _shortcutRow('Esc', 'Focus Barcode Scanner / Search Input', isDark),

              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutRow(String key, String description, [bool isDark = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
            ),
            alignment: Alignment.center,
            child: Text(key, style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), fontSize: 12)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(description, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _topIconBtn({required IconData icon, required VoidCallback onTap, Color? color, String? tooltip, bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 16, color: color ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final nowTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final screenBg = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9);
    final subtleBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsDialog,
        const SingleActivator(LogicalKeyboardKey.f2): _quickCashCheckout,
        const SingleActivator(LogicalKeyboardKey.f3): _openCustomerSearchModal,
        const SingleActivator(LogicalKeyboardKey.f4): _suspendSale,
        const SingleActivator(LogicalKeyboardKey.f5): _toggleProductLayout,
        const SingleActivator(LogicalKeyboardKey.f6): _openQuickCustomerModal,
        const SingleActivator(LogicalKeyboardKey.f7): _openPaymentModal,
        const SingleActivator(LogicalKeyboardKey.f8): _clearCart,
        const SingleActivator(LogicalKeyboardKey.f9): () {
          showDialog(context: context, builder: (_) => const CalculatorDialog());
        },
        const SingleActivator(LogicalKeyboardKey.f10): () {
          showDialog(context: context, builder: (_) => RegisterDetailsDialog(settings: widget.settings));
        },
        const SingleActivator(LogicalKeyboardKey.f11): _openCustomProductDialog,
        const SingleActivator(LogicalKeyboardKey.f12): _toggleWholesaleMode,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: screenBg,
          body: Column(
            children: [
              // ================= TOP POS BAR =================
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    // Location: Awesome Shop
                    Row(
                      children: [
                        Text('Location: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text(widget.settings.businessName, style: TextStyle(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Date & Time Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B6DF0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nowTime, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          const Icon(Icons.calculate_outlined, color: Colors.white, size: 14),
                        ],
                      ),
                    ),

                    // Industry Presets Quick Action Bar
                    if (widget.settings.isRestaurantEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          foregroundColor: const Color(0xFFEA580C),
                        ),
                        icon: const Icon(Icons.restaurant_menu_rounded, size: 14),
                        label: Text('$_diningMode: $_selectedTable', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            if (_diningMode == 'Dine-In') {
                              _diningMode = 'Takeaway';
                            } else if (_diningMode == 'Takeaway') {
                              _diningMode = 'Delivery';
                            } else {
                              _diningMode = 'Dine-In';
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 14),
                        label: const Text('KOT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openKotDialog,
                      ),
                    ],

                    if (widget.settings.isSolarHardwareEnabled) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.wb_sunny_rounded, size: 14),
                        label: const Text('Solar BOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openSolarBundleDialog,
                      ),
                    ],

                    if (widget.settings.isMobileElectronicsEnabled) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                          foregroundColor: const Color(0xFF4F46E5),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                        label: const Text('IMEI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _openImeiModal,
                      ),
                    ],

                                   const SizedBox(width: 16),

                    // Header Action icons:
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // [ < ] Back
                            _topIconBtn(
                              icon: Icons.chevron_left,
                              onTap: () {
                                if (widget.onBackToDashboard != null) {
                                  widget.onBackToDashboard!();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Back to Dashboard',
                              isDark: isDark,
                            ),

                            // [ ↶ ] Undo / Clear
                            _topIconBtn(
                              icon: Icons.undo,
                              onTap: _clearCart,
                              tooltip: 'Reset Order',
                              isDark: isDark,
                            ),

                            // [ || ] Pause / Suspend bills drawer
                            _topIconBtn(
                              icon: Icons.pause,
                              onTap: _openParkedSales,
                              tooltip: 'Suspended Bills ($_parkedCount)',
                              isDark: isDark,
                            ),

                            // [ ] Register Details (Green icon)
                            _topIconBtn(
                              icon: Icons.work_outline,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => RegisterDetailsDialog(settings: widget.settings),
                                );
                              },
                              color: const Color(0xFF10B981),
                              tooltip: 'Cash Register Details',
                              isDark: isDark,
                            ),

                            // [ ⌧ ] Close
                            _topIconBtn(
                              icon: Icons.highlight_off,
                              onTap: _clearCart,
                              color: const Color(0xFFEF4444),
                              tooltip: 'Cancel Order',
                              isDark: isDark,
                            ),

                            // [ ] Calculator
                            _topIconBtn(
                              icon: Icons.calculate_outlined,
                              onTap: () => showDialog(context: context, builder: (_) => const CalculatorDialog()),
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Calculator',
                              isDark: isDark,
                            ),

                            // [ ] Fullscreen
                            _topIconBtn(
                              icon: Icons.fullscreen,
                              onTap: () {},
                              tooltip: 'Fullscreen Toggle',
                              isDark: isDark,
                            ),

                            // [ ️ ] Screen
                            _topIconBtn(
                              icon: Icons.desktop_windows_outlined,
                              onTap: () {},
                              tooltip: 'Customer Facing Display',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),

                            // [ ⊞ / ] Toggle Grid / List Layout
                            _topIconBtn(
                              icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                              onTap: _toggleProductLayout,
                              tooltip: _isGridView ? 'Switch to List View [F5]' : 'Switch to Grid View [F5]',
                              color: const Color(0xFF4F46E5),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 6),

                            // [ + Add Expense ]
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                foregroundColor: textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Add Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddExpenseDialog(
                                    settings: widget.settings,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),

                            // [ ⌨ Shortcuts F1 ]
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.keyboard_outlined, size: 14),
                              label: const Text('Shortcuts [F1]', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _showShortcutsDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= MAIN TERMINAL SPLIT LAYOUT =================
              Expanded(
                child: Row(
                  children: [
                    // ================= LEFT: ORDER CART & CHECKOUT =================
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: cardBg,
                        child: Column(
                          children: [
                            // Row 1: Customer selector + Add Customer + Credit + Search Product
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: borderColor)),
                              ),
                              child: Row(
                                children: [
                                  // Customer Selector with Live Search (F3)
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: inputBorder),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: _openCustomerSearchModal,
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF4F46E5)),
                                                const SizedBox(width: 6),
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 140),
                                                  child: Text(
                                                    _selectedCustomer?.name ?? 'Walk-in Customer',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Dedicated "Search (F3)" badge button
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.search, size: 12, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Search (F3)',
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.arrow_drop_down, size: 18, color: textSecondary),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (_selectedCustomer != null && !_selectedCustomer!.name.toLowerCase().contains('walk-in')) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Tooltip(
                                              message: 'Reset to Walk-in Customer',
                                              child: InkWell(
                                                onTap: _resetToWalkInCustomer,
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close, size: 13, color: Color(0xFFDC2626)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // [ + ] Quick Add Customer blue button
                                  Tooltip(
                                    message: 'Add New Customer (F6)',
                                    child: InkWell(
                                      onTap: _openQuickCustomerModal,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // [ ] Customer Balance Due indicator
                                  Tooltip(
                                    message: 'Customer Outstanding Due & Ledger',
                                    child: InkWell(
                                      onTap: () {
                                        if (_selectedCustomer != null) {
                                          final due = _selectedCustomer!.balance;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Customer: ${_selectedCustomer!.name} | Outstanding Due: ${widget.settings.currencySymbol} ${due.toStringAsFixed(2)}',
                                              ),
                                              backgroundColor: due > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                        ),
                                        child: Icon(Icons.payments_outlined, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Search product / barcode input
                                  Expanded(
                                    child: Container(
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: inputBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: inputBorder),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        onSubmitted: _onBarcodeSubmitted,
                                        onChanged: (val) => _applyProductFilter(),
                                        style: TextStyle(fontSize: 13, color: textPrimary),
                                        decoration: InputDecoration(
                                          hintText: 'Enter Product name / SKU / Scan bar code',
                                          hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                                          prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Blue [ + ] -> Add Open / Custom Item on the fly
                                  Tooltip(
                                    message: 'Add Open / Custom Item (F11 / اوپن پراڈکٹ)',
                                    child: InkWell(
                                      onTap: _openCustomProductDialog,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Universal POS Bar: Wholesale/Retail Mode Toggle + Open Item Quick Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                border: Border(
                                  top: BorderSide(color: borderColor, width: 0.8),
                                  bottom: BorderSide(color: borderColor, width: 0.8),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  // Retail / Wholesale Pill Toggle
                                  InkWell(
                                    onTap: _toggleWholesaleMode,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isWholesaleMode
                                            ? const Color(0xFF0891B2)
                                            : (isDark ? const Color(0xFF334155) : Colors.white),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _isWholesaleMode
                                              ? const Color(0xFF0891B2)
                                              : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isWholesaleMode ? Icons.inventory_2_rounded : Icons.storefront_rounded,
                                            size: 14,
                                            color: _isWholesaleMode ? Colors.white : (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isWholesaleMode ? '📦 Wholesale Tier (Active)' : '🛒 Retail Mode (F12)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _isWholesaleMode ? Colors.white : textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // "+ Custom / Open Item" Pill
                                  InkWell(
                                    onTap: _openCustomProductDialog,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 5),
                                          Text(
                                            '+ Custom Item (اوپن آئٹم)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                   const SizedBox(width: 16),

                                  // Universal Tag / Flexible Units Hint
                                  Text(
                                    'Multi-Unit & Decimal Scale Enabled',
                                    style: TextStyle(fontSize: 10, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),

                            // Cart Table Header
                            Container(
                              color: subtleBg,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(width: 20, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                  Expanded(flex: 5, child: Text('PRODUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)))),
                                  Expanded(flex: 3, child: Text('QUANTITY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                  Expanded(flex: 3, child: Text('PRICE INC. TAX', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                  Expanded(flex: 2, child: Text('SUBTOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                                  const SizedBox(width: 36),
                                ],
                              ),
                            ),

                            // Cart Rows List
                            Expanded(
                              child: _cart.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.shopping_cart_outlined, size: 54, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                          const SizedBox(height: 10),
                                          Text('No products in cart', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text('Scan barcode or select products on the right', style: TextStyle(color: textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: _cart.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                      itemBuilder: (context, index) {
                                        final item = _cart[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          child: Row(
                                            children: [
                                              // Index #
                                              SizedBox(width: 20, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: textSecondary))),

                                              // Thumbnail image
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: borderColor),
                                                ),
                                                child: Icon(Icons.inventory_2_outlined, size: 18, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                              ),
                                              const SizedBox(width: 10),

                                              // Product Name (Dark) + SKU & Stock + Batch & Expiry
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.product.name,
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 2,
                                                      children: [
                                                        Text(
                                                          '${item.product.sku} • ${item.product.stockQuantity.toInt()} left',
                                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                                        ),
                                                        if (item.batchNumber != null && item.batchNumber!.isNotEmpty)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                                              borderRadius: BorderRadius.circular(3),
                                                              border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                                            ),
                                                            child: Text(
                                                              'Batch: ${item.batchNumber}',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                                            ),
                                                          ),
                                                        if (item.expiryDate != null && item.expiryDate!.isNotEmpty)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                                                              borderRadius: BorderRadius.circular(3),
                                                              border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                                                            ),
                                                            child: Text(
                                                              'Exp: ${item.expiryDate}',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                                                            ),
                                                          ),
                                                        if (item.bonusQuantity > 0)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF052E16) : const Color(0xFFECFDF5),
                                                              borderRadius: BorderRadius.circular(3),
                                                              border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0)),
                                                            ),
                                                            child: Text(
                                                              '+Bonus: ${item.bonusQuantity.toInt()}',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
                                                            ),
                                                          ),
                                                        if (item.calculatedDiscount > 0)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                                                              borderRadius: BorderRadius.circular(3),
                                                              border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                                                            ),
                                                            child: Text(
                                                              item.packDiscount > 0
                                                                  ? 'Disc: ${item.packDiscount.toStringAsFixed(0)}% (-$currency ${item.calculatedDiscount.toStringAsFixed(2)})'
                                                                  : 'Disc: -$currency ${item.calculatedDiscount.toStringAsFixed(2)}',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Quantity Stepper: [-] 1.00 [+] Pieces
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // [-] Red button
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              if (item.quantity > 1) {
                                                                item.quantity -= 1;
                                                              } else if (item.quantity > 0.25) {
                                                                item.quantity -= 0.25;
                                                              } else {
                                                                _cart.removeAt(index);
                                                              }
                                                            });
                                                          },
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text('-', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                                          child: InkWell(
                                                            onTap: () => _openQuantityDialog(item, index),
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                                borderRadius: BorderRadius.circular(4),
                                                                border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), width: 0.8),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text(
                                                                    item.quantity == item.quantity.toInt()
                                                                        ? item.quantity.toInt().toString()
                                                                        : item.quantity.toStringAsFixed(widget.settings.quantityPrecision > 0 ? widget.settings.quantityPrecision : 2),
                                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                                                  ),
                                                                  const SizedBox(width: 3),
                                                                  Icon(Icons.edit_note_rounded, size: 13, color: textSecondary),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        // [+] Green button
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              if (item.quantity < 1 && item.quantity >= 0.25) {
                                                                item.quantity += 0.25;
                                                              } else {
                                                                item.quantity += 1;
                                                              }
                                                            });
                                                          },
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text('+', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 16)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(item.product.unit, style: TextStyle(fontSize: 10, color: textSecondary)),
                                                  ],
                                                ),
                                              ),

                                              // Price Inc. Tax input field (Click to edit price / item discount)
                                              Expanded(
                                                flex: 3,
                                                child: Center(
                                                  child: Tooltip(
                                                    message: 'Click to edit item price or discount',
                                                    child: InkWell(
                                                      onTap: () => _showItemDiscountDialog(item, index),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        width: 86,
                                                        height: 32,
                                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                                        decoration: BoxDecoration(
                                                          color: inputBg,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: item.calculatedDiscount > 0 ? const Color(0xFFEF4444) : inputBorder),
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              item.unitPrice.toStringAsFixed(2),
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                                color: item.calculatedDiscount > 0 ? const Color(0xFFEF4444) : textPrimary,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Icon(Icons.edit, size: 10, color: textSecondary),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // Subtotal
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '$currency ${item.subtotal.toStringAsFixed(2)}',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                                ),
                                              ),

                                              // Trash Red button
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                                onPressed: () => setState(() => _cart.removeAt(index)),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            // ================= CART BOTTOM SUMMARY BAR =================
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                                border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFBBF7D0))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _summaryBlock('ITEMS', _totalQuantity.toStringAsFixed(2), isDark: isDark),
                                          const SizedBox(width: 14),
                                          _summaryBlock('SUBTOTAL', '$currency ${_subtotal.toStringAsFixed(2)}', isDark: isDark),
                                          const SizedBox(width: 14),
                                          _summaryBlock(
                                            'DISCOUNT(-)',
                                            _discountValue <= 0
                                                ? '$currency 0.00'
                                                : (_discountType == 'percentage'
                                                    ? '${_discountValue.toStringAsFixed(_discountValue.truncateToDouble() == _discountValue ? 0 : 2)}% ($currency ${_calculatedDiscount.toStringAsFixed(2)})'
                                                    : '$currency ${_calculatedDiscount.toStringAsFixed(2)}'),
                                            isEditable: true,
                                            onEdit: _showOrderDiscountDialog,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(width: 14),
                                          _summaryBlock('ORDER TAX(+)', '$currency ${_orderTax.toStringAsFixed(2)}', isEditable: true, onEdit: _showOrderTaxDialog, isDark: isDark),
                                          const SizedBox(width: 14),
                                          _summaryBlock('SHIPPING(+)', '$currency ${_shippingCharge.toStringAsFixed(2)}', isEditable: true, onEdit: _showShippingDialog, isDark: isDark),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Big Green TOTAL PAYABLE Box
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF064E3B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'TOTAL PAYABLE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          _grandTotal.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ================= BOTTOM ACTIONS ROW =================
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                border: Border(top: BorderSide(color: borderColor)),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    // [ Cancel ]
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFEF4444)),
                                        foregroundColor: const Color(0xFFEF4444),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: _cart.isEmpty ? null : _clearCart,
                                    ),
                                    const SizedBox(width: 8),

                                    // [ Draft ]
                                    _bottomOutlineBtn(icon: Icons.edit_note, label: 'Draft', onTap: _saveQuotation, isDark: isDark),

                                    // [ Quotation ]
                                    _bottomOutlineBtn(icon: Icons.assignment_outlined, label: 'Quotation', onTap: _saveQuotation, isDark: isDark),

                                    // [ ⏸ Suspend ]
                                    _bottomOutlineBtn(icon: Icons.pause, label: 'Suspend', color: const Color(0xFFD97706), onTap: _suspendSale, isDark: isDark),

                                    // [ Credit Sale ]
                                    _bottomOutlineBtn(icon: Icons.check, label: 'Credit Sale', onTap: _quickCreditCheckout, isDark: isDark),

                                    // [ Card ]
                                    _bottomOutlineBtn(icon: Icons.credit_card, label: 'Card', color: const Color(0xFFEC4899), onTap: _quickCardCheckout, isDark: isDark),
                                    const SizedBox(width: 8),

                                    // [ Multiple Pay ]
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.payments_outlined, size: 16),
                                      label: const Text('Multiple Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                      onPressed: _cart.isEmpty ? null : _openPaymentModal,
                                    ),
                                    const SizedBox(width: 8),

                                    // [ Cash ]
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.money, size: 16),
                                      label: const Text('Cash', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                      onPressed: _cart.isEmpty ? null : _quickCashCheckout,
                                    ),
                                    const SizedBox(width: 12),

                                    // [ Recent Transactions ]
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5B6DF0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      icon: const Icon(Icons.access_time_rounded, size: 16),
                                      label: const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ================= RIGHT: PRODUCT CATALOG GRID =================
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: subtleBg,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Filter Pills & View Layout Switcher (Grid vs List)
                            Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _filterBtn(
                                          icon: Icons.grid_view_outlined,
                                          label: _selectedCategoryId != null
                                              ? 'Category: ${_categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => Category(name: 'Category', code: '')).name}'
                                              : 'Category',
                                          count: _selectedCategoryId != null ? null : _categories.length,
                                          isSelected: _selectedCategoryId != null,
                                          onTap: _showCategoryFilterDialog,
                                          onClear: _selectedCategoryId != null
                                              ? () {
                                                  setState(() => _selectedCategoryId = null);
                                                  _applyProductFilter();
                                                }
                                              : null,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 8),
                                        _filterBtn(
                                          icon: Icons.branding_watermark_outlined,
                                          label: _selectedBrandId != null
                                              ? 'Brand: ${_brands.firstWhere((b) => b.id == _selectedBrandId, orElse: () => Brand(name: 'Brand')).name}'
                                              : 'Brands',
                                          count: _selectedBrandId != null ? null : _brands.length,
                                          isSelected: _selectedBrandId != null,
                                          onTap: _showBrandFilterDialog,
                                          onClear: _selectedBrandId != null
                                              ? () {
                                                  setState(() => _selectedBrandId = null);
                                                  _applyProductFilter();
                                                }
                                              : null,
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 8),
                                        _filterBtn(
                                          icon: Icons.star_border,
                                          label: 'Featured Products',
                                          count: null,
                                          isSelected: _filterFeatured,
                                          onTap: () {
                                            setState(() => _filterFeatured = !_filterFeatured);
                                            _applyProductFilter();
                                          },
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Segmented Layout Switcher: [ ⊞ Grid ] [ List ]
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: inputBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Grid View Button
                                      Tooltip(
                                        message: 'Grid View [F5]',
                                        child: InkWell(
                                          onTap: () {
                                            if (!_isGridView) {
                                              _toggleProductLayout();
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _isGridView ? const Color(0xFF4F46E5) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: _isGridView
                                                  ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.grid_view_rounded,
                                                  size: 15,
                                                  color: _isGridView ? Colors.white : textSecondary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Grid',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _isGridView ? Colors.white : textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),

                                      // List View Button
                                      Tooltip(
                                        message: 'List View [F5]',
                                        child: InkWell(
                                          onTap: () {
                                            if (_isGridView) {
                                              _toggleProductLayout();
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: !_isGridView ? const Color(0xFF4F46E5) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: !_isGridView
                                                  ? [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.format_list_bulleted_rounded,
                                                  size: 16,
                                                  color: !_isGridView ? Colors.white : textSecondary,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'List',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: !_isGridView ? Colors.white : textSecondary,
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
                            const SizedBox(height: 12),

                            // Switchable Product Layout: Grid OR List View
                            Expanded(
                              child: _loadingCatalog
                                  ? const Center(child: CircularProgressIndicator())
                                  : _products.isEmpty
                                      ? Center(child: Text('No products found matching criteria', style: TextStyle(color: textSecondary)))
                                      : _isGridView
                                          ? GridView.builder(
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 4,
                                                childAspectRatio: 0.80,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 10,
                                              ),
                                              itemCount: _products.length,
                                              itemBuilder: (context, index) {
                                                final p = _products[index];
                                                final currency = widget.settings.currencySymbol;
                                                final isOutOfStock = p.isOutOfStock;
                                                final isLowStock = !isOutOfStock && p.stockQuantity <= 5;

                                                return Material(
                                                  color: cardBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                  elevation: 0,
                                                  child: InkWell(
                                                    onTap: () => _addToCart(p),
                                                    borderRadius: BorderRadius.circular(8),
                                                    hoverColor: const Color(0xFF4F46E5).withOpacity(0.04),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: borderColor),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          // Top Row: Stock Badge & Unit
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: isOutOfStock
                                                                      ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                                                                      : (isLowStock
                                                                          ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                                                                          : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7))),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: Text(
                                                                  isOutOfStock
                                                                      ? 'Out of stock'
                                                                      : '${p.stockQuantity.toInt()} in stock',
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: isOutOfStock
                                                                        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                                                        : (isLowStock
                                                                            ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706))
                                                                            : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A))),
                                                                  ),
                                                                ),
                                                              ),
                                                              if (p.unit.isNotEmpty)
                                                                Text(
                                                                  p.unit,
                                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSecondary),
                                                                ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),

                                                          // Thumbnail Graphic
                                                          Expanded(
                                                            child: Center(
                                                              child: Container(
                                                                padding: const EdgeInsets.all(8),
                                                                decoration: BoxDecoration(
                                                                  color: subtleBg,
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Icon(
                                                                  Icons.inventory_2_outlined,
                                                                  size: 32,
                                                                  color: const Color(0xFF4F46E5).withOpacity(0.85),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),

                                                          // Product Title
                                                          Text(
                                                            p.name,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                              color: textPrimary,
                                                              height: 1.2,
                                                            ),
                                                            textAlign: TextAlign.center,
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 2),

                                                          // SKU: (SKU-001)
                                                          Text(
                                                            '(${p.sku})',
                                                            style: TextStyle(fontSize: 10, color: textSecondary),
                                                            textAlign: TextAlign.center,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 6),

                                                          // Price & Add Button Row
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w900,
                                                                    color: textPrimary,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                              Container(
                                                                width: 22,
                                                                height: 22,
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF4F46E5),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : ListView.separated(
                                              itemCount: _products.length,
                                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                                              itemBuilder: (context, index) {
                                                final p = _products[index];
                                                final currency = widget.settings.currencySymbol;
                                                final isOutOfStock = p.isOutOfStock;
                                                final isLowStock = !isOutOfStock && p.stockQuantity <= 5;

                                                return Material(
                                                  color: cardBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: InkWell(
                                                    onTap: () => _addToCart(p),
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: borderColor),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 36,
                                                            height: 36,
                                                            decoration: BoxDecoration(
                                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2FF),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: const Icon(
                                                              Icons.medication_outlined,
                                                              color: Color(0xFF4F46E5),
                                                              size: 20,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  p.name,
                                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Row(
                                                                  children: [
                                                                    Text('SKU: ${p.sku}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                                                    if (p.unit.isNotEmpty) ...[
                                                                      const SizedBox(width: 8),
                                                                      Text('• Unit: ${p.unit}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                                                    ],
                                                                    if (p.batchNumber != null && p.batchNumber!.isNotEmpty) ...[
                                                                      const SizedBox(width: 8),
                                                                      Text('• Batch: ${p.batchNumber}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Stock Status Pill
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: isOutOfStock
                                                                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                                                                  : (isLowStock
                                                                      ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7))
                                                                      : (isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7))),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              isOutOfStock
                                                                  ? 'Out of stock'
                                                                  : '${p.stockQuantity.toInt()} in stock',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: isOutOfStock
                                                                    ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                                                    : (isLowStock
                                                                        ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706))
                                                                        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A))),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 14),
                                                          // Price
                                                          Text(
                                                            '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          // Add Button
                                                          Container(
                                                            width: 28,
                                                            height: 28,
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF4F46E5),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= SPEED SHORTCUTS FOOTER BAR =================
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _shortcutPill('F1', 'Search / Barcode Focus', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F2', 'Cash Checkout', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F3', 'Customer', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F4', 'Hold Bill', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F7', 'Partial / Split Pay', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F8', 'Reset Order', isDark),
                      const SizedBox(width: 10),
                      _shortcutPill('F10', 'Shift Reconciliation', isDark),
                      const SizedBox(width: 24),
                      Text(
                        'Smart POS Engine • Multi-Industry',
                        style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutPill(String keyLabel, String actionLabel, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          actionLabel,
          style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _summaryBlock(String label, String value, {bool isEditable = false, VoidCallback? onEdit, bool isDark = false}) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary)),
            if (isEditable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 10, color: Color(0xFF4F46E5)),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
      ],
    );

    if (isEditable && onEdit != null) {
      return InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _bottomOutlineBtn({required IconData icon, required String label, Color? color, VoidCallback? onTap, bool isDark = false}) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          foregroundColor: color ?? textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 15, color: color ?? iconColor),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }

  Widget _filterBtn({
    required IconData icon,
    required String label,
    int? count,
    bool isSelected = false,
    VoidCallback? onTap,
    VoidCallback? onClear,
    bool isDark = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF)) : cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)) : textSecondary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)) : textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
              ),
            ],
            if (isSelected && onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 12, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
