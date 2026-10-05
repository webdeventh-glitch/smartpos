import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'quick_customer_dialog.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'parked_sales_dialog.dart';
import 'register_details_dialog.dart';
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

  // Search & Catalog
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Category> _categories = [];
  List<Brand> _brands = [];
  int? _selectedCategoryId;
  int? _selectedBrandId;
  bool _filterFeatured = false;
  List<Product> _products = [];
  bool _loadingCatalog = true;

  // Calculation parameters
  double _orderDiscount = 0.0;
  final double _orderTax = 0.0;
  double _shippingCharge = 0.0;

  // Parked bills count
  int _parkedCount = 0;

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

    if (mounted) {
      setState(() {
        _customers = customers;
        _selectedCustomer = customers.isNotEmpty ? customers.first : null;
        _categories = categories;
        _brands = brands;
        _products = products;
        _parkedCount = parked.length;
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _filterProducts({int? categoryId, int? brandId, String? search}) async {
    final db = await _dbFuture;
    final filtered = await db.getProducts(categoryId: categoryId, search: search);
    if (mounted) {
      setState(() => _products = filtered);
    }
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
        ));
      }
    });
  }

  void _onBarcodeSubmitted(String code) async {
    if (code.trim().isEmpty) return;
    final db = await _dbFuture;
    final product = await db.getProductByCode(code.trim());
    if (product != null) {
      _addToCart(product);
      _searchController.clear();
      _searchFocusNode.requestFocus();
    } else {
      _filterProducts(categoryId: _selectedCategoryId, brandId: _selectedBrandId, search: code.trim());
    }
  }

  // Calculations
  double get _subtotal => _cart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _grandTotal => (_subtotal - _orderDiscount + _orderTax + _shippingCharge).clamp(0.0, double.infinity);
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
      discount: _orderDiscount,
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

    final completedSale = await db.createSale(sale: sale, items: List.from(_cart));

    if (mounted) {
      setState(() {
        _cart.clear();
        _orderDiscount = 0.0;
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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PaymentModal(
        grandTotal: _grandTotal,
        currencySymbol: widget.settings.currencySymbol,
        customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      ),
    );

    if (result != null) {
      _processCheckout(
        paymentMethod: result['method'] as String,
        paidAmount: result['paidAmount'] as double,
        tendered: result['tendered'] as double,
        changeReturn: result['change'] as double,
        paymentStatus: result['paymentStatus'] as String,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel & Clear Cart?'),
        content: const Text('Are you sure you want to discard all items in the current order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cart.clear());
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

  void _showShortcutsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Ultimate POS Keyboard Shortcuts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shortcutRow('F1', 'Keyboard Shortcuts Help Modal'),
              _shortcutRow('F2', 'Quick Cash Pay (Instant Complete)'),
              _shortcutRow('F4', 'Suspend / Park Current Sale Order'),
              _shortcutRow('F6', 'Add / Select Customer'),
              _shortcutRow('F7', 'Multiple / Split Pay Modal'),
              _shortcutRow('F8', 'Cancel Sale / Clear Cart'),
              _shortcutRow('F9', 'Open Calculator'),
              _shortcutRow('F10', 'Register Details & Session'),
              _shortcutRow('Esc', 'Focus Barcode Scanner / Search Input'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            alignment: Alignment.center,
            child: Text(key, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0038B8), fontSize: 13)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _topIconBtn({required IconData icon, required VoidCallback onTap, Color? color, String? tooltip}) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 16, color: color ?? const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final nowTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsDialog,
        const SingleActivator(LogicalKeyboardKey.f2): _quickCashCheckout,
        const SingleActivator(LogicalKeyboardKey.f4): _suspendSale,
        const SingleActivator(LogicalKeyboardKey.f6): _openQuickCustomerModal,
        const SingleActivator(LogicalKeyboardKey.f7): _openPaymentModal,
        const SingleActivator(LogicalKeyboardKey.f8): _clearCart,
        const SingleActivator(LogicalKeyboardKey.f9): () {
          showDialog(context: context, builder: (_) => const CalculatorDialog());
        },
        const SingleActivator(LogicalKeyboardKey.f10): () {
          showDialog(context: context, builder: (_) => RegisterDetailsDialog(settings: widget.settings));
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Column(
        children: [
          // ================= SCREENSHOT 2: TOP POS BAR =================
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Location: Awesome Shop
                Row(
                  children: [
                    const Text('Location: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(widget.settings.businessName, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  ],
                ),
                const SizedBox(width: 14),

                // Purple Date & Time Pill: 10/05/2026 06:50 🖩
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

                const Spacer(),

                // Header Action icons matching Screenshot 2:
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
                  color: const Color(0xFF004EEB),
                  tooltip: 'Back to Dashboard',
                ),

                // [ ↶ ] Undo / Clear
                _topIconBtn(
                  icon: Icons.undo,
                  onTap: _clearCart,
                  tooltip: 'Reset Order',
                ),

                // [ || ] Pause / Suspend bills drawer
                _topIconBtn(
                  icon: Icons.pause,
                  onTap: _openParkedSales,
                  tooltip: 'Suspended Bills ($_parkedCount)',
                ),

                // [ 💼 ] Register Details (Green icon)
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
                ),

                // [ ⌧ ] Close
                _topIconBtn(
                  icon: Icons.highlight_off,
                  onTap: _clearCart,
                  color: const Color(0xFFEF4444),
                  tooltip: 'Cancel Order',
                ),

                // [ 🖩 ] Calculator
                _topIconBtn(
                  icon: Icons.calculate_outlined,
                  onTap: () => showDialog(context: context, builder: (_) => const CalculatorDialog()),
                  color: const Color(0xFF004EEB),
                  tooltip: 'Calculator',
                ),

                // [ ⛶ ] Fullscreen
                _topIconBtn(
                  icon: Icons.fullscreen,
                  onTap: () {},
                  tooltip: 'Fullscreen Toggle',
                ),

                // [ 🖥️ ] Screen
                _topIconBtn(
                  icon: Icons.desktop_windows_outlined,
                  onTap: () {},
                  tooltip: 'Customer Facing Display',
                ),
                const SizedBox(width: 6),

                // [ + Add Expense ]
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {},
                ),
                const SizedBox(width: 6),

                // [ ⌨ Shortcuts F1 ]
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
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
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Row 1: Customer selector + Add Customer + Credit + Search Product
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              // Customer Dropdown: Walk-In ...
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<Contact>(
                                        value: _selectedCustomer,
                                        isDense: true,
                                        items: _customers.map((c) {
                                          return DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c.name,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (c) => setState(() => _selectedCustomer = c),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),

                              // [ + ] Quick Add Customer blue button
                              InkWell(
                                onTap: () {
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
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004EEB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // [ 💰 ] Customer Balance Due indicator
                              InkWell(
                                onTap: () {},
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: const Icon(Icons.payments_outlined, color: Color(0xFF004EEB), size: 18),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Search product / barcode input
                              Expanded(
                                child: Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    onSubmitted: _onBarcodeSubmitted,
                                    onChanged: (val) => _filterProducts(categoryId: _selectedCategoryId, brandId: _selectedBrandId, search: val),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Enter Product name / SKU / Scan bar code',
                                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Blue [ + ]
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF004EEB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),

                        // Cart Table Header (Matching Screenshot 2)
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: const Row(
                            children: [
                              SizedBox(width: 20, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              Expanded(flex: 5, child: Text('PRODUCT ℹ️', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                              Expanded(flex: 3, child: Text('QUANTITY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              Expanded(flex: 3, child: Text('PRICE INC. TAX', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              Expanded(flex: 2, child: Text('SUBTOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                              SizedBox(width: 36),
                            ],
                          ),
                        ),

                        // Cart Rows List
                        Expanded(
                          child: _cart.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shopping_cart_outlined, size: 54, color: Color(0xFFCBD5E1)),
                                      SizedBox(height: 10),
                                      Text('No products in cart', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      SizedBox(height: 4),
                                      Text('Scan barcode or select products on the right', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _cart.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      child: Row(
                                        children: [
                                          // Index #
                                          SizedBox(width: 20, child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                                          // Thumbnail image
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: const Icon(Icons.laptop_chromebook, size: 20, color: Color(0xFF004EEB)),
                                          ),
                                          const SizedBox(width: 10),

                                          // Product Name (Blue) + SKU & Stock
                                          Expanded(
                                            flex: 5,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.product.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004EEB)),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${item.product.sku} • ${item.product.brandName} • ${item.product.stockQuantity.toInt()} Pc(s)',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                                                          } else {
                                                            _cart.removeAt(index);
                                                          }
                                                        });
                                                      },
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEE2E2),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text('-', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: Text(
                                                        item.quantity.toStringAsFixed(2),
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                    ),
                                                    // [+] Green button
                                                    InkWell(
                                                      onTap: () => setState(() => item.quantity += 1),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFDCFCE7),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text('+', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 16)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(item.product.unit, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                              ],
                                            ),
                                          ),

                                          // Price Inc. Tax input field
                                          Expanded(
                                            flex: 3,
                                            child: Center(
                                              child: Container(
                                                width: 80,
                                                height: 32,
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  item.unitPrice.toStringAsFixed(2),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
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

                        // ================= CART BOTTOM SUMMARY BAR (Screenshot 2) =================
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0FDF4), // Mint soft green tint
                            border: Border(top: BorderSide(color: Color(0xFFBBF7D0))),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _summaryBlock('ITEMS', _totalQuantity.toStringAsFixed(2)),
                                      const SizedBox(width: 14),
                                      _summaryBlock('SUBTOTAL', '$currency ${_subtotal.toStringAsFixed(2)}'),
                                      const SizedBox(width: 14),
                                      _summaryBlock('DISCOUNT(-)', '$currency ${_orderDiscount.toStringAsFixed(2)}', isEditable: true, onEdit: () {
                                        setState(() => _orderDiscount = _orderDiscount == 0 ? 10.0 : 0.0);
                                      }),
                                      const SizedBox(width: 14),
                                      _summaryBlock('ORDER TAX(+)', '$currency ${_orderTax.toStringAsFixed(2)}', isEditable: true),
                                      const SizedBox(width: 14),
                                      _summaryBlock('SHIPPING(+)', '$currency ${_shippingCharge.toStringAsFixed(2)}', isEditable: true),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Big Green TOTAL PAYABLE Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'TOTAL PAYABLE',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 0.8),
                                    ),
                                    Text(
                                      _grandTotal.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ================= BOTTOM ACTIONS ROW (Screenshot 2) =================
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // [ ✖ Cancel ]
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

                                // [ 📝 Draft ]
                                _bottomOutlineBtn(icon: Icons.edit_note, label: 'Draft', onTap: _saveQuotation),

                                // [ 📋 Quotation ]
                                _bottomOutlineBtn(icon: Icons.assignment_outlined, label: 'Quotation', onTap: _saveQuotation),

                                // [ ⏸ Suspend ]
                                _bottomOutlineBtn(icon: Icons.pause, label: 'Suspend', color: const Color(0xFFD97706), onTap: _suspendSale),

                                // [ 💳 Credit Sale ]
                                _bottomOutlineBtn(icon: Icons.check, label: 'Credit Sale', onTap: _quickCreditCheckout),

                                // [ 💳 Card ]
                                _bottomOutlineBtn(icon: Icons.credit_card, label: 'Card', color: const Color(0xFFEC4899), onTap: _quickCardCheckout),
                                const SizedBox(width: 8),

                                // [ 💵 Multiple Pay ]
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B), // Dark Navy
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.payments_outlined, size: 16),
                                  label: const Text('Multiple Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                  onPressed: _cart.isEmpty ? null : _openPaymentModal,
                                ),
                                const SizedBox(width: 8),

                                // [ 💵 Cash ]
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981), // Emerald Green
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.money, size: 16),
                                  label: const Text('Cash', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                  onPressed: _cart.isEmpty ? null : _quickCashCheckout,
                                ),
                                const SizedBox(width: 12),

                                // [ 🕒 Recent Transactions ]
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B6DF0), // Purple/Blue Pill
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

                // ================= RIGHT: PRODUCT CATALOG GRID (Screenshot 2) =================
                Expanded(
                  flex: 5,
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Pills: Category (7), Brands (15), Featured Products
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                            _filterBtn(
                              icon: Icons.grid_view_outlined,
                              label: 'Category',
                              count: _categories.length,
                              isSelected: _selectedCategoryId != null,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = _selectedCategoryId == null ? (_categories.isNotEmpty ? _categories.first.id : null) : null;
                                });
                                _filterProducts(categoryId: _selectedCategoryId);
                              },
                            ),
                            const SizedBox(width: 8),
                            _filterBtn(
                              icon: Icons.branding_watermark_outlined,
                              label: 'Brands',
                              count: _brands.length,
                              isSelected: _selectedBrandId != null,
                              onTap: () {
                                setState(() {
                                  _selectedBrandId = _selectedBrandId == null ? (_brands.isNotEmpty ? _brands.first.id : null) : null;
                                });
                                _filterProducts(brandId: _selectedBrandId);
                              },
                            ),
                            const SizedBox(width: 8),
                            _filterBtn(
                              icon: Icons.star_border,
                              label: 'Featured Products',
                              count: null,
                              isSelected: _filterFeatured,
                              onTap: () => setState(() => _filterFeatured = !_filterFeatured),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                        // 4-Column Product Grid (Matching Screenshot 2)
                        Expanded(
                          child: _loadingCatalog
                              ? const Center(child: CircularProgressIndicator())
                              : _products.isEmpty
                                  ? const Center(child: Text('No products found', style: TextStyle(color: Colors.grey)))
                                  : GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio: 0.85,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                      itemCount: _products.length,
                                      itemBuilder: (context, index) {
                                        final p = _products[index];
                                        return Material(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          elevation: 0,
                                          child: InkWell(
                                            onTap: () => _addToCart(p),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  // Thumbnail Graphic
                                                  Expanded(
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.inventory_2_outlined,
                                                        size: 40,
                                                        color: const Color(0xFF004EEB).withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),

                                                  // Product Title
                                                  Text(
                                                    p.name,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),

                                                  // SKU: (AS0017-1)
                                                  Text(
                                                    '(${p.sku})',
                                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                  ),
                                                  const SizedBox(height: 4),

                                                  // Stock subtext: 30.00 Pc(s) In stock
                                                  Text(
                                                    '${p.stockQuantity.toInt()}.00 ${p.unit}(s) In stock',
                                                    style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                                    textAlign: TextAlign.center,
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
        ],
      ),
    ),
    ),
    );
  }

  Widget _summaryBlock(String label, String value, {bool isEditable = false, VoidCallback? onEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            if (isEditable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onEdit,
                child: const Icon(Icons.edit, size: 10, color: Color(0xFF004EEB)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _bottomOutlineBtn({required IconData icon, required String label, Color? color, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          foregroundColor: color ?? const Color(0xFF1E293B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 15, color: color ?? const Color(0xFF64748B)),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }

  Widget _filterBtn({required IconData icon, required String label, int? count, bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEBF3FE) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF004EEB) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF004EEB) : const Color(0xFF1E293B))),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF004EEB) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF64748B)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
