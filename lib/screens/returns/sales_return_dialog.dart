import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SalesReturnDialog extends StatefulWidget {
  final BusinessSettings settings;
  final Sale? initialSale;
  final VoidCallback onReturnSuccess;

  const SalesReturnDialog({
    super.key,
    required this.settings,
    this.initialSale,
    required this.onReturnSuccess,
  });

  @override
  State<SalesReturnDialog> createState() => _SalesReturnDialogState();
}

class _ReturnItemSelection {
  final SaleItem saleItem;
  bool selected;
  double returnQty;

  _ReturnItemSelection({
    required this.saleItem,
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

  // Mode: 0 = From Invoice, 1 = Manual Entry
  int _mode = 0;

  // Manual Mode fields
  Contact? _manualCustomer;
  Product? _manualProduct;
  final TextEditingController _manualInvoiceNoCtrl = TextEditingController(text: 'INV-1001');
  final TextEditingController _manualQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _manualPriceCtrl = TextEditingController(text: '0.00');

  // Common fields
  String _refundMethod = 'cash'; // 'cash', 'credit_note', 'bank'
  final TextEditingController _reasonCtrl = TextEditingController(text: 'Customer Return');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _invoiceSearchCtrl.dispose();
    _manualInvoiceNoCtrl.dispose();
    _manualQtyCtrl.dispose();
    _manualPriceCtrl.dispose();
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

    setState(() {
      _nextRef = ref;
      _recentSales = sales;
      _customers = custs;
      _allProducts = prods;
      _manualCustomer = custs.isNotEmpty ? custs.first : null;
      _manualProduct = prods.isNotEmpty ? prods.first : null;
      if (_manualProduct != null) {
        _manualPriceCtrl.text = _manualProduct!.sellingPrice.toStringAsFixed(2);
      }
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

    if (!mounted) return;

    setState(() {
      _selectedSale = sale;
      _invoiceSearchCtrl.text = sale.invoiceNo;
      _itemSelections = items.map((i) {
        return _ReturnItemSelection(
          saleItem: i,
          selected: true,
          returnQty: i.quantity,
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
        sel.selected = selectAll;
        if (selectAll) {
          sel.returnQty = sel.saleItem.quantity;
        }
      }
    });
  }

  double get _totalRefundAmount {
    if (_mode == 0) {
      return _itemSelections
          .where((s) => s.selected)
          .fold(0.0, (sum, s) => sum + s.subtotal);
    } else {
      final q = double.tryParse(_manualQtyCtrl.text.trim()) ?? 0.0;
      final p = double.tryParse(_manualPriceCtrl.text.trim()) ?? 0.0;
      return q * p;
    }
  }

  int get _selectedItemsCount {
    if (_mode == 0) {
      return _itemSelections.where((s) => s.selected).length;
    } else {
      return 1;
    }
  }

  Future<void> _submitReturn() async {
    final total = _totalRefundAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product with quantity > 0 to return.'),
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
          returnItems.add(
            SaleReturnItem(
              returnId: 0,
              productId: sel.saleItem.productId ?? 0,
              productName: sel.saleItem.productName,
              sku: sel.saleItem.sku,
              batchNumber: sel.saleItem.batchNumber ?? '',
              quantity: sel.returnQty,
              unitPrice: sel.saleItem.unitPrice,
              subtotal: sel.subtotal,
            ),
          );
        }
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

      await db.addSaleReturn(sr);
    } else {
      if (_manualProduct == null) return;
      final qty = double.tryParse(_manualQtyCtrl.text.trim()) ?? 1.0;
      final price = double.tryParse(_manualPriceCtrl.text.trim()) ?? 0.0;

      returnItems.add(
        SaleReturnItem(
          returnId: 0,
          productId: _manualProduct!.id ?? 0,
          productName: _manualProduct!.name,
          sku: _manualProduct!.sku,
          batchNumber: _manualProduct!.batchNumber ?? '',
          quantity: qty,
          unitPrice: price,
          subtotal: total,
        ),
      );

      final sr = SaleReturn(
        returnNo: _nextRef,
        invoiceNo: _manualInvoiceNoCtrl.text.trim(),
        customerId: _manualCustomer?.id,
        customerName: _manualCustomer?.name ?? 'Walk-in Customer',
        date: nowStr,
        totalAmount: total,
        refundAmount: total,
        paymentMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
        items: returnItems,
      );

      await db.addSaleReturn(sr);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onReturnSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales return $_nextRef processed successfully! Items restocked into inventory.'),
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
                      border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
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
                              child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFDC2626), size: 22),
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
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ref: $_nextRef • Return entire bill or selected products',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _mode = 0),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _mode == 0 ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: _mode == 0
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 16,
                                      color: _mode == 0 ? const Color(0xFF004EEB) : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'From Sale Bill / Invoice (Recommended)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _mode == 0 ? FontWeight.bold : FontWeight.normal,
                                        color: _mode == 0
                                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _mode == 1 ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: _mode == 1
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                      color: _mode == 1 ? const Color(0xFF004EEB) : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Manual Return (No Invoice)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _mode == 1 ? FontWeight.bold : FontWeight.normal,
                                        color: _mode == 1
                                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
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
                      child: _mode == 0 ? _buildInvoiceReturnContent(isDark, currency) : _buildManualReturnContent(isDark, currency),
                    ),
                  ),

                  // Bottom Action & Refund Summary Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
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
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),

                        // Action Buttons
                        Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Confirm Return & Restock', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: _searchAndSelectInvoice,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      backgroundColor: const Color(0xFF004EEB),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _searchAndSelectInvoice(_invoiceSearchCtrl.text),
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
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF004EEB)),
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
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Text(
                  'Bill Total: $currency ${_selectedSale!.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF004EEB)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.select_all_rounded, size: 14),
                    label: const Text('Return Full Bill (Pura Bill)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _selectAllItems(true),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _selectAllItems(false),
                    child: const Text('Clear All', style: TextStyle(fontSize: 11)),
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
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 40, child: Text('Return', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 4, child: Text('Product / Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Sold Qty & Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Center(child: Text('Return Quantity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Refund Subtotal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Table Rows
                ..._itemSelections.map((sel) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel.selected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : (isDark ? Colors.black26 : const Color(0xFFF8FAFC)),
                      border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: sel.selected,
                            activeColor: const Color(0xFFDC2626),
                            onChanged: (val) {
                              setState(() {
                                sel.selected = val ?? false;
                                if (sel.selected && sel.returnQty == 0) {
                                  sel.returnQty = sel.saleItem.quantity;
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
                                  color: sel.selected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.grey,
                                ),
                              ),
                              if (sel.saleItem.batchNumber != null && sel.saleItem.batchNumber!.isNotEmpty)
                                Text(
                                  'Batch: ${sel.saleItem.batchNumber}',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                color: sel.selected && sel.returnQty > 1 ? const Color(0xFFDC2626) : Colors.grey,
                                onPressed: sel.selected && sel.returnQty > 1
                                    ? () => setState(() => sel.returnQty--)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(4),
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                ),
                                child: Text(
                                  '${sel.returnQty.toStringAsFixed(0)} / ${sel.saleItem.quantity.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: sel.selected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.grey,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                color: sel.selected && sel.returnQty < sel.saleItem.quantity ? const Color(0xFF10B981) : Colors.grey,
                                onPressed: sel.selected && sel.returnQty < sel.saleItem.quantity
                                    ? () => setState(() => sel.returnQty++)
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
                              sel.selected ? '$currency ${sel.subtotal.toStringAsFixed(2)}' : '$currency 0.00',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: sel.selected ? const Color(0xFFDC2626) : Colors.grey,
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
            child: Center(child: Text('No invoice selected. Please pick or search an invoice above.')),
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
              child: DropdownButtonFormField<Contact>(
                initialValue: _manualCustomer,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Customer *', isDense: true),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _manualCustomer = v),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _manualInvoiceNoCtrl,
                decoration: const InputDecoration(labelText: 'Original Invoice No *', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        DropdownButtonFormField<Product>(
          initialValue: _manualProduct,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Select Product to Return *', isDense: true),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: _allProducts.take(150).map((p) {
            return DropdownMenuItem(
              value: p,
              child: Text('${p.name} (${p.batchNumber ?? "No Batch"}) - Stock: ${p.stockQuantity}'),
            );
          }).toList(),
          onChanged: (p) {
            setState(() {
              _manualProduct = p;
              if (p != null) {
                _manualPriceCtrl.text = p.sellingPrice.toStringAsFixed(2);
              }
            });
          },
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _manualQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Return Quantity *', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _manualPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Refund Unit Price *', prefixText: '$currency ', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
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
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _refundMethod,
                  decoration: const InputDecoration(labelText: 'Refund Payment Mode', isDense: true),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash Refund (Paid Out)')),
                    DropdownMenuItem(value: 'credit_note', child: Text('Credit Note (Customer Balance)')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank / Digital Transfer')),
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
          color: isSelected ? const Color(0xFF004EEB) : Colors.grey.withValues(alpha: 0.15),
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
