import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SalesReturnScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SalesReturnScreen({super.key, required this.settings});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final ScrollController _hScrollController = ScrollController();
  List<SaleReturn> _returns = [];
  List<Contact> _customers = [];
  List<Product> _products = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final rets = await db.getSaleReturns();
    final custs = await db.getContacts(type: 'customer');
    final prods = await db.getProducts();

    if (mounted) {
      setState(() {
        _returns = rets;
        _customers = custs;
        _products = prods;
        _loading = false;
      });
    }
  }

  Future<void> _openAddReturnDialog() async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextSaleReturnRef();

    final invoiceCtrl = TextEditingController(text: 'INV-1001');
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '100.00');
    final reasonCtrl = TextEditingController(text: 'Expired / Customer Return');

    Contact? selectedCustomer = _customers.isNotEmpty ? _customers.first : null;
    Product? selectedProduct = _products.isNotEmpty ? _products.first : null;
    String refundMethod = 'cash'; // 'cash', 'credit_note'

    if (selectedProduct != null) {
      priceCtrl.text = selectedProduct.sellingPrice.toStringAsFixed(2);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
          final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
          final total = qty * price;
          final currency = widget.settings.currencySymbol;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 580,
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
                                'Record Sales Return',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Ref: $nextRef (Restocks inventory automatically)',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Customer Name *', isDark),
                            DropdownButtonFormField<Contact>(
                              value: selectedCustomer,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true),
                              items: _customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setDlgState(() => selectedCustomer = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Original Invoice No *', isDark),
                            TextFormField(controller: invoiceCtrl, decoration: const InputDecoration(isDense: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _label('Select Product to Return *', isDark),
                  DropdownButtonFormField<Product>(
                    value: selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: _products.take(100).map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.batchNumber ?? "No Batch"}) - Stock: ${p.stockQuantity}'))).toList(),
                    onChanged: (v) {
                      setDlgState(() {
                        selectedProduct = v;
                        if (v != null) priceCtrl.text = v.sellingPrice.toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Return Quantity *', isDark),
                            TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Refund Unit Price *', isDark),
                            TextFormField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(prefixText: '$currency ', isDense: true),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Refund Mode', isDark),
                            DropdownButtonFormField<String>(
                              value: refundMethod,
                              decoration: const InputDecoration(isDense: true),
                              items: const [
                                DropdownMenuItem(value: 'cash', child: Text('Cash Refund')),
                                DropdownMenuItem(value: 'credit_note', child: Text('Credit Note (Ledger)')),
                              ],
                              onChanged: (v) => setDlgState(() => refundMethod = v ?? 'cash'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _label('Reason for Return', isDark),
                  TextFormField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'e.g. Near expiry, broken seal, client overorder', isDense: true)),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Refund Value:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                        Text('$currency${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm Return & Restock', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (selectedProduct == null || qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select a valid product and quantity'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          final sr = SaleReturn(
                            returnNo: nextRef,
                            invoiceNo: invoiceCtrl.text.trim(),
                            customerId: selectedCustomer?.id,
                            customerName: selectedCustomer?.name ?? 'Walk-in Customer',
                            date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                            totalAmount: total,
                            refundAmount: total,
                            paymentMethod: refundMethod,
                            reason: reasonCtrl.text.trim(),
                            items: [
                              SaleReturnItem(
                                returnId: 0,
                                productId: selectedProduct!.id ?? 1,
                                productName: selectedProduct!.name,
                                sku: selectedProduct!.sku,
                                batchNumber: selectedProduct!.batchNumber ?? '',
                                quantity: qty,
                                unitPrice: price,
                                subtotal: total,
                              ),
                            ],
                          );

                          await db.addSaleReturn(sr);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Sales return $nextRef recorded and stock updated!'), backgroundColor: const Color(0xFF10B981)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalRefunded = _returns.fold(0.0, (sum, r) => sum + r.refundAmount);

    final filtered = _returns.where((r) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return r.returnNo.toLowerCase().contains(q) ||
          r.invoiceNo.toLowerCase().contains(q) ||
          r.customerName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Returns & Customer Refunds',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage returned medications, damaged stock restock, and customer balance adjustments',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Sales Return', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddReturnDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top KPI Strip
            Row(
              children: [
                _kpiCard('TOTAL RETURNS', '${_returns.length}', Icons.assignment_return_rounded, const Color(0xFFDC2626), isDark),
                const SizedBox(width: 14),
                _kpiCard('REFUNDED VALUE', '$currency${totalRefunded.toStringAsFixed(2)}', Icons.payments_rounded, const Color(0xFFD97706), isDark),
                const SizedBox(width: 14),
                _kpiCard('RESTOCKED ITEMS', '${_returns.fold(0, (s, r) => s + r.items.length)}', Icons.inventory_2_rounded, const Color(0xFF10B981), isDark),
              ],
            ),
            const SizedBox(height: 20),

            // Search Toolbar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search by return reference, original invoice no, or customer name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Data Table with Interactive Scrollbar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No sales return records found.')),
                        )
                      : Scrollbar(
                          controller: _hScrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hScrollController,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 22,
                              horizontalMargin: 16,
                              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              columns: const [
                                DataColumn(label: Text('RETURN REF', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('ORIGINAL INVOICE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('REFUND AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('REFUND METHOD', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('REASON', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((r) {
                                return DataRow(cells: [
                                  DataCell(Text(r.returnNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)))),
                                  DataCell(Text(r.date.split(' ').first)),
                                  DataCell(Text(r.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                                  DataCell(Text(r.customerName)),
                                  DataCell(Text('${r.items.length} items')),
                                  DataCell(Text('$currency${r.refundAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: r.paymentMethod == 'cash' ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        r.paymentMethod.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: r.paymentMethod == 'cash' ? const Color(0xFF16A34A) : const Color(0xFF4338CA),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(r.reason.isNotEmpty ? r.reason : '-', style: const TextStyle(fontSize: 12))),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String val, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
