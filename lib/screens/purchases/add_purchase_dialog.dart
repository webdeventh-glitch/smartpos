import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'product_search_dialog.dart';

class AddPurchaseDialog extends StatefulWidget {
  final VoidCallback onPurchaseSaved;

  const AddPurchaseDialog({super.key, required this.onPurchaseSaved});

  @override
  State<AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _PurchaseLineItem {
  final Product product;
  double quantity;
  double purchasePrice;
  double profitMarginPercent;
  double sellingPrice;

  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final TextEditingController marginCtrl;
  final TextEditingController sellingCtrl;

  _PurchaseLineItem({
    required this.product,
    this.quantity = 1,
    required this.purchasePrice,
    required this.profitMarginPercent,
    required this.sellingPrice,
  })  : qtyCtrl = TextEditingController(text: quantity.toInt().toString()),
        costCtrl = TextEditingController(text: purchasePrice.toStringAsFixed(2)),
        marginCtrl = TextEditingController(text: profitMarginPercent.toStringAsFixed(1)),
        sellingCtrl = TextEditingController(text: sellingPrice.toStringAsFixed(2));

  double get subtotal => quantity * purchasePrice;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
    marginCtrl.dispose();
    sellingCtrl.dispose();
  }
}

class _AddPurchaseDialogState extends State<AddPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();

  Contact? _selectedSupplier;
  BusinessLocation? _selectedLocation;
  List<Contact> _suppliers = [];
  List<Product> _allProducts = [];
  List<BusinessLocation> _locations = [];

  final List<_PurchaseLineItem> _lineItems = [];

  String _status = 'received';
  String _paymentMethod = 'cash';
  bool _loading = true;
  bool _isSaving = false;
  BusinessSettings? _settings;

  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _barcodeSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    _paidController.dispose();
    _noteController.dispose();
    _barcodeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final db = await DatabaseService.initialize();
    final sups = await db.getContacts(type: 'supplier');
    final prods = await db.getProducts();
    final locs = await db.getBusinessLocations();
    final settings = await db.getBusinessSettings();

    if (mounted) {
      setState(() {
        _suppliers = sups;
        _allProducts = prods;
        _locations = locs;
        _settings = settings;
        if (locs.isNotEmpty) _selectedLocation = locs.first;
        if (sups.isNotEmpty) _selectedSupplier = sups.first;
        _loading = false;
      });
    }
  }

  double get _totalBillAmount => _lineItems.fold(0.0, (sum, it) => sum + it.subtotal);
  double get _totalUnitsCount => _lineItems.fold(0.0, (sum, it) => sum + it.quantity);

  void _recalcPaidAmount({bool forceFull = false}) {
    if (forceFull || _paidController.text.trim().isEmpty) {
      _paidController.text = _totalBillAmount.toStringAsFixed(2);
    }
  }

  void _addProductToBill(Product p) {
    // Check if item already exists in line items
    final existingIndex = _lineItems.indexWhere((it) => it.product.id == p.id);
    if (existingIndex >= 0) {
      setState(() {
        final it = _lineItems[existingIndex];
        it.quantity += 1;
        it.qtyCtrl.text = it.quantity.toInt().toString();
        _recalcPaidAmount(forceFull: true);
      });
      return;
    }

    final cost = p.purchasePrice > 0 ? p.purchasePrice : 100.0;
    final selling = p.sellingPrice > 0 ? p.sellingPrice : 125.0;
    final margin = cost > 0 ? ((selling - cost) / cost) * 100 : 25.0;

    final item = _PurchaseLineItem(
      product: p,
      quantity: 1,
      purchasePrice: cost,
      profitMarginPercent: margin,
      sellingPrice: selling,
    );

    setState(() {
      _lineItems.add(item);
      _recalcPaidAmount(forceFull: true);
    });
  }

  void _openProductCatalog() {
    showDialog(
      context: context,
      builder: (ctx) => ProductSearchDialog(
        products: _allProducts,
        selectedProduct: null,
        currencySymbol: _settings?.currencySymbol ?? 'Rs',
        onProductSelected: (p) => _addProductToBill(p),
      ),
    );
  }

  void _onQuickSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return;

    try {
      final match = _allProducts.firstWhere(
        (p) =>
            p.barcode.toLowerCase() == clean ||
            p.sku.toLowerCase() == clean ||
            p.name.toLowerCase().contains(clean),
      );
      _addProductToBill(match);
      _barcodeSearchCtrl.clear();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product matched: "$query"'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _onCostChanged(_PurchaseLineItem item, String val) {
    final cost = double.tryParse(val.trim()) ?? 0.0;
    item.purchasePrice = cost;
    if (cost > 0 && item.profitMarginPercent > 0) {
      final selling = cost * (1 + (item.profitMarginPercent / 100));
      item.sellingPrice = selling;
      item.sellingCtrl.text = selling.toStringAsFixed(2);
    }
    setState(() => _recalcPaidAmount(forceFull: true));
  }

  void _onMarginChanged(_PurchaseLineItem item, String val) {
    final margin = double.tryParse(val.trim()) ?? 0.0;
    item.profitMarginPercent = margin;
    if (item.purchasePrice > 0) {
      final selling = item.purchasePrice * (1 + (margin / 100));
      item.sellingPrice = selling;
      item.sellingCtrl.text = selling.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onSellingChanged(_PurchaseLineItem item, String val) {
    final selling = double.tryParse(val.trim()) ?? 0.0;
    item.sellingPrice = selling;
    if (item.purchasePrice > 0 && selling > item.purchasePrice) {
      final margin = ((selling - item.purchasePrice) / item.purchasePrice) * 100;
      item.profitMarginPercent = margin;
      item.marginCtrl.text = margin.toStringAsFixed(1);
    }
    setState(() {});
  }

  void _onQuantityChanged(_PurchaseLineItem item, String val) {
    final qty = double.tryParse(val.trim()) ?? 1.0;
    item.quantity = qty;
    setState(() => _recalcPaidAmount(forceFull: true));
  }

  Future<void> _savePurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supplier.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product item to the purchase bill.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final refNo = await db.generateNextPurchaseRef();
      final total = _totalBillAmount;
      final paid = double.tryParse(_paidController.text.trim()) ?? total;
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final paymentStatus = paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'due');

      final itemsPayload = _lineItems.map((it) {
        return {
          'product_id': it.product.id,
          'product_name': it.product.name,
          'quantity': it.quantity,
          'purchase_price': it.purchasePrice,
          'profit_margin': it.profitMarginPercent,
          'selling_price': it.sellingPrice,
          'subtotal': it.subtotal,
        };
      }).toList();

      final purchase = Purchase(
        refNo: refNo,
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        locationId: _selectedLocation?.id ?? 1,
        locationName: _selectedLocation?.name ?? 'Main Branch HQ',
        totalAmount: total,
        paidAmount: paid,
        status: _status,
        paymentStatus: paymentStatus,
        createdAt: now,
        note: _noteController.text.trim(),
        itemsJson: jsonEncode(itemsPayload),
      );

      await db.createPurchase(purchase: purchase, items: itemsPayload);

      widget.onPurchaseSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase Bill $refNo recorded successfully (${_lineItems.length} items restocked).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save purchase: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = _settings?.currencySymbol ?? 'Rs';

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgHeader = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inputDeco = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    );

    final total = _totalBillAmount;
    final paid = double.tryParse(_paidController.text.trim()) ?? total;
    final due = total > paid ? total - paid : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: Container(
          width: 1040,
          constraints: const BoxConstraints(maxHeight: 840),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: _loading
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: bgHeader,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF4F46E5), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Purchase Invoice (Restock Products)',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Add multiple products to restock, compute profit margins, and update supplier payable khata.',
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Meta Information (Supplier, Location, Status)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            // Supplier Selection
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Supplier *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<Contact>(
                                    dropdownColor: cardBg,
                                    decoration: inputDeco,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    initialValue: _selectedSupplier,
                                    items: _suppliers
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text('${s.name} ${s.balance > 0 ? "(Due: $currency${s.balance.toStringAsFixed(0)})" : ""}',
                                                  style: TextStyle(fontSize: 13, color: textPrimary)),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedSupplier = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Location
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Receiving Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<BusinessLocation>(
                                    dropdownColor: cardBg,
                                    decoration: inputDeco,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    initialValue: _selectedLocation,
                                    items: _locations
                                        .map((loc) => DropdownMenuItem(
                                              value: loc,
                                              child: Text(loc.name, style: TextStyle(fontSize: 13, color: textPrimary)),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedLocation = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Status
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    dropdownColor: cardBg,
                                    decoration: inputDeco,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    initialValue: _status,
                                    items: const [
                                      DropdownMenuItem(value: 'received', child: Text('Received (Restock)')),
                                      DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                                      DropdownMenuItem(value: 'ordered', child: Text('Ordered')),
                                    ],
                                    onChanged: (val) => setState(() => _status = val ?? 'received'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Product Search / Barcode Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: bgHeader,
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeSearchCtrl,
                                onSubmitted: _onQuickSearch,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Enter Product Name, SKU, or Scan Barcode to add to purchase...',
                                  hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.list_alt_rounded, size: 16),
                              label: const Text('Browse Products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _openProductCatalog,
                            ),
                          ],
                        ),
                      ),

                      // Multi-Item Purchase Grid
                      Expanded(
                        child: _lineItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text('No products added yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                                    const SizedBox(height: 4),
                                    Text('Scan barcode or click "Browse Products" above to add items.', style: TextStyle(fontSize: 12, color: textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _lineItems.length,
                                itemBuilder: (context, index) {
                                  final it = _lineItems[index];

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: borderColor)),
                                      color: index % 2 == 0 ? Colors.transparent : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Index
                                        SizedBox(
                                          width: 26,
                                          child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textSecondary)),
                                        ),

                                        // Product Details
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(it.product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text('SKU: ${it.product.sku} • Stock: ${it.product.stockQuantity.toInt()}', style: TextStyle(fontSize: 11, color: textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Purchase Cost
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Cost Price', style: TextStyle(fontSize: 10, color: textSecondary)),
                                              const SizedBox(height: 2),
                                              TextField(
                                                controller: it.costCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (val) => _onCostChanged(it, val),
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                                decoration: inputDeco.copyWith(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Margin %
                                        SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Margin %', style: TextStyle(fontSize: 10, color: textSecondary)),
                                              const SizedBox(height: 2),
                                              TextField(
                                                controller: it.marginCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (val) => _onMarginChanged(it, val),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                decoration: inputDeco.copyWith(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Selling Price
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Sale Price', style: TextStyle(fontSize: 10, color: textSecondary)),
                                              const SizedBox(height: 2),
                                              TextField(
                                                controller: it.sellingCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (val) => _onSellingChanged(it, val),
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                                decoration: inputDeco.copyWith(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Quantity
                                        SizedBox(
                                          width: 80,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Restock Qty', style: TextStyle(fontSize: 10, color: textSecondary)),
                                              const SizedBox(height: 2),
                                              TextField(
                                                controller: it.qtyCtrl,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                onChanged: (val) => _onQuantityChanged(it, val),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                                decoration: inputDeco.copyWith(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Subtotal
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('Line Total', style: TextStyle(fontSize: 10, color: textSecondary)),
                                              const SizedBox(height: 4),
                                              Text('$currency${it.subtotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textPrimary)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Delete Row
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          onPressed: () {
                                            setState(() {
                                              it.dispose();
                                              _lineItems.removeAt(index);
                                              _recalcPaidAmount(forceFull: true);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Bottom Payment & Settlement Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: bgHeader,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            // Bill Summary Stats
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Total Items: ${_lineItems.length} (${_totalUnitsCount.toInt()} Units)', style: TextStyle(fontSize: 12, color: textSecondary)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Text('BILL TOTAL: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('$currency${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF4F46E5))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Payment Mode & Paid Amount
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  // Paid Amount Input
                                  SizedBox(
                                    width: 130,
                                    child: TextField(
                                      controller: _paidController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setState(() {}),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: inputDeco.copyWith(
                                        labelText: 'Paid Amount',
                                        labelStyle: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quick 0 / Full Paid Buttons
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () {
                                      setState(() => _paidController.text = total.toStringAsFixed(2));
                                    },
                                    child: const Text('Full Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 4),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: () {
                                      setState(() => _paidController.text = '0.00');
                                    },
                                    child: const Text('Full Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ),
                                  const SizedBox(width: 12),

                                  // Due Indicator
                                  if (due > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Due: $currency${due.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Save Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_rounded, size: 18),
                              label: const Text('Save Purchase Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: _isSaving ? null : _savePurchase,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
