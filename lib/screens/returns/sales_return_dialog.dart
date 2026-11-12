import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SalesReturnDialog extends StatefulWidget {
  final BusinessSettings settings;
  final Sale? initialSale;
  final int locationId;
  final VoidCallback onReturnSuccess;

  const SalesReturnDialog({
    super.key,
    required this.settings,
    this.initialSale,
    this.locationId = 1,
    required this.onReturnSuccess,
  });

  @override
  State<SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _ManualReturnEntry {
  final Product product;
  final int? variationId;
  final String variationName;
  double quantity;
  double unitPrice;

  _ManualReturnEntry({
    required this.product,
    this.variationId,
    this.variationName = '',
    this.quantity = 1.0,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;
}

class _ReturnItemSelection {
  final SaleItem saleItem;
  final double maxReturnable;
  bool selected;
  double returnQty;

  _ReturnItemSelection({
    required this.saleItem,
    required this.maxReturnable,
    this.selected = true,
    required this.returnQty,
  });

  double get subtotal => returnQty * saleItem.unitPrice;
}

class _SalesReturnDialogState extends State<SalesReturnDialog> {
  bool _loading = true;
  String _nextRef = '';
  List<Sale> _recentSales = [];
  List<Contact> _customers = [];
  List<Product> _allProducts = [];

  // Selected Sale & items
  Sale? _selectedSale;
  List<_ReturnItemSelection> _itemSelections = [];
  final TextEditingController _invoiceSearchCtrl = TextEditingController();

  // Mode: 0 = From Invoice, 1 = Direct / No-Invoice Return
  int _mode = 0;

  // Direct / No-Invoice Mode fields
  Contact? _manualCustomer; // null => Walk-in Customer
  Product? _manualProduct;
  final TextEditingController _manualInvoiceNoCtrl = TextEditingController();
  final TextEditingController _manualScanCtrl = TextEditingController();
  final List<_ManualReturnEntry> _manualReturnItems = [];

  // Common fields
  String _refundMethod = 'cash'; // 'cash', 'credit_note', 'bank'
  final TextEditingController _reasonCtrl =
      TextEditingController(text: 'Customer Return');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _invoiceSearchCtrl.dispose();
    _manualInvoiceNoCtrl.dispose();
    _manualScanCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final db = await DatabaseService.initialize();
    final ref = await db.generateNextSaleReturnRef();
    final sales = await db.getSales();
    final custs = await db.getContacts(type: 'customer');
    final prods = await db.getProducts();

    if (!mounted) return;

    final walkInCust = custs
        .where((c) =>
            c.isDefaultWalkIn || c.name.toLowerCase().contains('walk-in'))
        .cast<Contact?>()
        .firstOrNull;

    setState(() {
      _nextRef = ref;
      _recentSales = sales;
      _customers = custs;
      _allProducts = prods;
      _manualCustomer = walkInCust;
      _manualProduct = prods.isNotEmpty ? prods.first : null;
      _loading = false;
    });

    if (widget.initialSale != null) {
      _selectSale(widget.initialSale!);
    } else if (sales.isNotEmpty) {
      _selectSale(sales.first);
    }
  }

  Future<void> _selectSale(Sale sale) async {
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(sale.id!);
    final alreadyReturned = await db.getReturnedQuantitiesForSale(sale.id!);

    if (!mounted) return;

    setState(() {
      _selectedSale = sale;
      _invoiceSearchCtrl.text = sale.invoiceNo;
      _itemSelections = items.map((i) {
        final prevRet = (i.productId != null)
            ? (alreadyReturned[i.productId!] ?? 0.0)
            : 0.0;
        final remaining =
            (i.quantity - prevRet).clamp(0.0, i.quantity).toDouble();
        return _ReturnItemSelection(
          saleItem: i,
          maxReturnable: remaining,
          selected: remaining > 0,
          returnQty: remaining,
        );
      }).toList();
    });
  }

  Future<void> _searchAndSelectInvoice(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final db = await DatabaseService.initialize();
    final found = await db.getSaleByInvoiceNo(clean);

    if (found != null) {
      _selectSale(found);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No invoice found matching "$clean"'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _selectAllItems(bool selectAll) {
    setState(() {
      for (final sel in _itemSelections) {
        sel.selected = selectAll && sel.maxReturnable > 0;
        if (sel.selected) {
          sel.returnQty = sel.maxReturnable;
        }
      }
    });
  }

  void _addProductToManualBasket(
    Product product, {
    ProductVariation? variation,
    double qty = 1.0,
  }) {
    final varId = variation?.id;
    final varName = variation?.name ?? '';
    final price = variation?.sellingPrice ?? product.sellingPrice;
    setState(() {
      final existingIdx = _manualReturnItems.indexWhere(
        (e) => e.product.id == product.id && e.variationId == varId,
      );
      if (existingIdx >= 0) {
        _manualReturnItems[existingIdx].quantity += qty;
      } else {
        _manualReturnItems.add(
          _ManualReturnEntry(
            product: product,
            variationId: varId,
            variationName: varName,
            quantity: qty,
            unitPrice: price,
          ),
        );
      }
    });
  }

  Future<void> _scanOrSearchDirectReturnProduct(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    final db = await DatabaseService.initialize();
    final exactMatch = await db.getProductWithMatchedVariationByCode(q);
    if (exactMatch != null) {
      _addProductToManualBasket(exactMatch.$1, variation: exactMatch.$2);
      _manualScanCtrl.clear();
      return;
    }
    final lower = q.toLowerCase();
    final fallback = _allProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(lower) ||
              p.sku.toLowerCase().contains(lower) ||
              p.barcode.toLowerCase().contains(lower),
        )
        .cast<Product?>()
        .firstOrNull;
    if (fallback != null) {
      _addProductToManualBasket(fallback);
      _manualScanCtrl.clear();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found matching "$q".'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  double get _totalRefundAmount {
    if (_mode == 0) {
      return _itemSelections
          .where((s) => s.selected)
          .fold(0.0, (sum, s) => sum + s.subtotal);
    } else {
      return _manualReturnItems.fold(0.0, (sum, entry) => sum + entry.subtotal);
    }
  }

  int get _selectedItemsCount {
    if (_mode == 0) {
      return _itemSelections.where((s) => s.selected).length;
    } else {
      return _manualReturnItems.length;
    }
  }

  Future<void> _submitReturn() async {
    final total = _totalRefundAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select at least one product with quantity > 0 to return.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final db = await DatabaseService.initialize();
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    List<SaleReturnItem> returnItems = [];

    if (_mode == 0) {
      if (_selectedSale == null) return;
      for (final sel in _itemSelections) {
        if (sel.selected && sel.returnQty > 0) {
          final clampedQty =
              sel.returnQty.clamp(0.0, sel.maxReturnable).toDouble();
          if (clampedQty <= 0) continue;
          returnItems.add(
            SaleReturnItem(
              returnId: 0,
              productId: sel.saleItem.productId ?? 0,
              variationId: sel.saleItem.variationId,
              variationName: sel.saleItem.variationName,
              productName: sel.saleItem.productName,
              sku: sel.saleItem.sku,
              batchNumber: sel.saleItem.batchNumber ?? '',
              quantity: clampedQty,
              unitMultiplier: sel.saleItem.unitMultiplier,
              unitPrice: sel.saleItem.unitPrice,
              subtotal: clampedQty * sel.saleItem.unitPrice,
            ),
          );
        }
      }
      if (returnItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No returnable quantity remains for the selected items.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final sr = SaleReturn(
        returnNo: _nextRef,
        saleId: _selectedSale!.id,
        invoiceNo: _selectedSale!.invoiceNo,
        customerId: _selectedSale!.customerId,
        customerName: _selectedSale!.customerName,
        date: nowStr,
        totalAmount: total,
        refundAmount: total,
        paymentMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
        items: returnItems,
      );

      await db.addSaleReturn(sr, locationId: widget.locationId);
    } else {
      if (_manualReturnItems.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please scan or add at least one product to return.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final isWalkIn = _manualCustomer == null ||
          _manualCustomer!.id == null ||
          _manualCustomer!.isDefaultWalkIn ||
          _manualCustomer!.name.toLowerCase().contains('walk-in');
      if (_refundMethod == 'credit_note' && isWalkIn) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Credit Note requires a registered customer account. Select Cash/Bank refund or choose a registered customer.',
              ),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        return;
      }

      for (final entry in _manualReturnItems) {
        if (entry.quantity <= 0) continue;
        returnItems.add(
          SaleReturnItem(
            returnId: 0,
            productId: entry.product.id ?? 0,
            variationId: entry.variationId,
            variationName: entry.variationName,
            productName: entry.product.name,
            sku: entry.product.sku,
            batchNumber: entry.product.batchNumber ?? '',
            quantity: entry.quantity,
            unitPrice: entry.unitPrice,
            subtotal: entry.subtotal,
          ),
        );
      }
      if (returnItems.isEmpty) return;

      final invRef = _manualInvoiceNoCtrl.text.trim().isEmpty
          ? 'NO-INV'
          : _manualInvoiceNoCtrl.text.trim();
      final sr = SaleReturn(
        returnNo: _nextRef,
        invoiceNo: invRef,
        customerId: _manualCustomer?.id,
        customerName: _manualCustomer?.name ?? 'Walk-in Customer',
        date: nowStr,
        totalAmount: total,
        refundAmount: total,
        paymentMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
        items: returnItems,
      );

      await db.addSaleReturn(sr, locationId: widget.locationId);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onReturnSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sales return $_nextRef processed successfully! Items restocked into inventory.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalRefund = _totalRefundAmount;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 700),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.assignment_return_rounded,
                                  color: Color(0xFFDC2626), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Record Sales Return & Refund',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ref: $_nextRef • Return entire bill or selected products',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Mode Selector Segmented Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _mode = 0),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _mode == 0
                                      ? (isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: _mode == 0
                                      ? [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 4)
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: _mode == 0
                                          ? const Color(0xFF004EEB)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'From Sale Bill / Invoice (Recommended)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _mode == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _mode == 0
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _mode = 1),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _mode == 1
                                      ? (isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: _mode == 1
                                      ? [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 4)
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                      color: _mode == 1
                                          ? const Color(0xFF004EEB)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Manual Return (No Invoice)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _mode == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _mode == 1
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))
                                            : Colors.grey,
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
                  ),

                  // Scrollable Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: _mode == 0
                          ? _buildInvoiceReturnContent(isDark, currency)
                          : _buildManualReturnContent(isDark, currency),
                    ),
                  ),

                  // Bottom Action & Refund Summary Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: Border(
                          top: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Refund Totals
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL REFUND VALUE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$currency ${totalRefund.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            Text(
                              '$_selectedItemsCount items selected for return & restock',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        // Action Buttons
                        Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 18),
                              label: const Text('Confirm Return & Restock',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: totalRefund > 0 ? _submitReturn : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInvoiceReturnContent(bool isDark, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Invoice Selector Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<Sale>(
                initialValue: _selectedSale,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select Sale Bill / Invoice *',
                  isDense: true,
                  prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: _recentSales.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.invoiceNo} — ${s.customerName} ($currency ${s.totalAmount.toStringAsFixed(2)})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (sale) {
                  if (sale != null) _selectSale(sale);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _invoiceSearchCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Search Invoice No...',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: _searchAndSelectInvoice,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      backgroundColor: const Color(0xFF004EEB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        _searchAndSelectInvoice(_invoiceSearchCtrl.text),
                    child: const Text('Find', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Selected Invoice Summary Card
        if (_selectedSale != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Color(0xFF004EEB)),
                    const SizedBox(width: 6),
                    Text(
                      _selectedSale!.customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '• Date: ${_selectedSale!.createdAt}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Text(
                  'Bill Total: $currency ${_selectedSale!.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF004EEB)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pura Bill vs Selected Product Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Products on this Bill (Select products to return):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.select_all_rounded, size: 14),
                    label: const Text('Return Full Bill (Pura Bill)',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _selectAllItems(true),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _selectAllItems(false),
                    child:
                        const Text('Clear All', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Invoice Items Table
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                          width: 40,
                          child: Text('Return',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 4,
                          child: Text('Product / Item',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 2,
                          child: Text('Sold Qty & Price',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(
                          flex: 3,
                          child: Center(
                              child: Text('Return Quantity',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)))),
                      Expanded(
                          flex: 2,
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('Refund Subtotal',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Table Rows
                ..._itemSelections.map((sel) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel.selected
                          ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                          : (isDark ? Colors.black26 : const Color(0xFFF8FAFC)),
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: sel.selected,
                            activeColor: const Color(0xFFDC2626),
                            onChanged: sel.maxReturnable <= 0
                                ? null
                                : (val) {
                                    setState(() {
                                      sel.selected = val ?? false;
                                      if (sel.selected && sel.returnQty == 0) {
                                        sel.returnQty = sel.maxReturnable;
                                      }
                                    });
                                  },
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sel.saleItem.productName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: sel.selected
                                      ? (isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A))
                                      : Colors.grey,
                                ),
                              ),
                              if (sel.saleItem.batchNumber != null &&
                                  sel.saleItem.batchNumber!.isNotEmpty)
                                Text(
                                  'Batch: ${sel.saleItem.batchNumber}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${sel.saleItem.quantity} pcs @ $currency${sel.saleItem.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 18),
                                color: sel.selected && sel.returnQty > 0.5
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey,
                                onPressed: sel.selected && sel.returnQty > 0.5
                                    ? () => setState(() {
                                          final step = (sel.returnQty % 1 !=
                                                      0 ||
                                                  sel.maxReturnable % 1 != 0)
                                              ? 0.5
                                              : 1.0;
                                          sel.returnQty = (sel.returnQty - step)
                                              .clamp(0.5, sel.maxReturnable);
                                        })
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(4),
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                ),
                                child: Text(
                                  '${sel.returnQty % 1 == 0 ? sel.returnQty.toStringAsFixed(0) : sel.returnQty.toStringAsFixed(2)} / ${sel.maxReturnable % 1 == 0 ? sel.maxReturnable.toStringAsFixed(0) : sel.maxReturnable.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: sel.selected
                                        ? (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A))
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 18),
                                color: sel.selected &&
                                        sel.returnQty < sel.maxReturnable
                                    ? const Color(0xFF10B981)
                                    : Colors.grey,
                                onPressed: sel.selected &&
                                        sel.returnQty < sel.maxReturnable
                                    ? () => setState(() {
                                          final step = (sel.returnQty % 1 !=
                                                      0 ||
                                                  sel.maxReturnable % 1 != 0)
                                              ? 0.5
                                              : 1.0;
                                          sel.returnQty = (sel.returnQty + step)
                                              .clamp(0.0, sel.maxReturnable);
                                        })
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              sel.selected
                                  ? '$currency ${sel.subtotal.toStringAsFixed(2)}'
                                  : '$currency 0.00',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sel.selected
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ] else ...[
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
                child: Text(
                    'No invoice selected. Please pick or search an invoice above.')),
          ),
        ],

        const SizedBox(height: 16),
        _buildRefundDetailsSection(isDark),
      ],
    );
  }

  Widget _buildManualReturnContent(bool isDark, String currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<Contact?>(
                initialValue: _customers.contains(_manualCustomer)
                    ? _manualCustomer
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Customer (Walk-in or Registered)',
                    isDense: true),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: [
                  const DropdownMenuItem<Contact?>(
                    value: null,
                    child: Text('Walk-in Customer (No Khata)'),
                  ),
                  ..._customers.map(
                    (c) => DropdownMenuItem<Contact?>(
                      value: c,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _manualCustomer = v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _manualInvoiceNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Invoice / Slip Ref (Optional)',
                  hintText: 'Leave blank if no invoice (NO-INV)',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Fast Barcode / SKU Scanner OR Product Picker Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _manualScanCtrl,
                decoration: InputDecoration(
                  labelText: 'Scan Barcode / Type SKU & Press Enter',
                  isDense: true,
                  prefixIcon:
                      const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    tooltip: 'Find & Add to Return List',
                    onPressed: () =>
                        _scanOrSearchDirectReturnProduct(_manualScanCtrl.text),
                  ),
                ),
                onSubmitted: _scanOrSearchDirectReturnProduct,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Product>(
                      initialValue: _manualProduct,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Or Pick Product *',
                        isDense: true,
                      ),
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: _allProducts.take(150).map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.name} ($currency${p.sellingPrice.toStringAsFixed(0)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (p) => setState(() => _manualProduct = p),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004EEB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add', style: TextStyle(fontSize: 12)),
                    onPressed: _manualProduct == null
                        ? null
                        : () => _addProductToManualBasket(_manualProduct!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Multi-Item Direct Return Basket Table
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: _manualReturnItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Scan product barcode or select items above to return without an invoice.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 4,
                              child: Text('Product',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 3,
                              child: Center(
                                  child: Text('Return Qty',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)))),
                          Expanded(
                              flex: 2,
                              child: Text('Unit Price',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          Expanded(
                              flex: 2,
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('Refund',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)))),
                          SizedBox(width: 36),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ..._manualReturnItems.asMap().entries.map((mapEntry) {
                      final idx = mapEntry.key;
                      final entry = mapEntry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.variationName.isNotEmpty
                                        ? '${entry.product.name} (${entry.variationName})'
                                        : entry.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    'SKU: ${entry.product.sku}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 16),
                                    onPressed: () {
                                      setState(() {
                                        if (entry.quantity > 1) {
                                          entry.quantity -= 1.0;
                                        } else {
                                          _manualReturnItems.removeAt(idx);
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    entry.quantity % 1 == 0
                                        ? entry.quantity.toInt().toString()
                                        : entry.quantity.toStringAsFixed(2),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 16),
                                    onPressed: () =>
                                        setState(() => entry.quantity += 1.0),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue:
                                    entry.unitPrice.toStringAsFixed(2),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  prefixText: '$currency ',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                ),
                                onChanged: (v) {
                                  final parsed = double.tryParse(v.trim());
                                  if (parsed != null && parsed >= 0) {
                                    setState(() => entry.unitPrice = parsed);
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '$currency ${entry.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Color(0xFFEF4444)),
                              onPressed: () => setState(
                                  () => _manualReturnItems.removeAt(idx)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _buildRefundDetailsSection(isDark),
      ],
    );
  }

  Widget _buildRefundDetailsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _refundMethod,
                  decoration: const InputDecoration(
                      labelText: 'Refund Payment Mode', isDense: true),
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: const [
                    DropdownMenuItem(
                        value: 'cash', child: Text('Cash Refund (Paid Out)')),
                    DropdownMenuItem(
                        value: 'credit_note',
                        child: Text('Credit Note (Customer Balance)')),
                    DropdownMenuItem(
                        value: 'bank', child: Text('Bank / Digital Transfer')),
                  ],
                  onChanged: (v) => setState(() => _refundMethod = v ?? 'cash'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Return',
                    hintText: 'e.g. Expired, customer return, defective',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Reason Chips
          Wrap(
            spacing: 6,
            children: [
              _reasonChip('Customer Return'),
              _reasonChip('Defective / Damaged'),
              _reasonChip('Wrong Item Delivered'),
              _reasonChip('Near Expiry'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reasonChip(String label) {
    final isSelected = _reasonCtrl.text == label;
    return InkWell(
      onTap: () => setState(() => _reasonCtrl.text = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF004EEB)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
