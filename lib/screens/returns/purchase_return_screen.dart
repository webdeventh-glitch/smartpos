import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class PurchaseReturnScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PurchaseReturnScreen({super.key, required this.settings});

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  final ScrollController _hScrollController = ScrollController();
  List<PurchaseReturn> _returns = [];
  List<Contact> _suppliers = [];
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
    final rets = await db.getPurchaseReturns();
    final supps = await db.getContacts(type: 'supplier');
    final prods = await db.getProducts();

    if (mounted) {
      setState(() {
        _returns = rets;
        _suppliers = supps;
        _products = prods;
        _loading = false;
      });
    }
  }

  Future<void> _openAddReturnDialog() async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextPurchaseReturnRef();

    final purchaseRefCtrl = TextEditingController(text: 'PO-2026-001');
    final qtyCtrl = TextEditingController(text: '5');
    final priceCtrl = TextEditingController(text: '100.00');
    final reasonCtrl = TextEditingController(text: 'Near Expiry / Distributor Return');

    Contact? selectedSupplier = _suppliers.isNotEmpty ? _suppliers.first : null;
    Product? selectedProduct = _products.isNotEmpty ? _products.first : null;

    if (selectedProduct != null) {
      priceCtrl.text = selectedProduct.purchasePrice.toStringAsFixed(2);
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.outbox_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Debit Note / Purchase Return',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Ref: $nextRef (Returns stock to vendor & reduces payables)',
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
                            _label('Supplier / Distributor *', isDark),
                            DropdownButtonFormField<Contact>(
                              value: selectedSupplier,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true),
                              items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setDlgState(() => selectedSupplier = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Purchase Bill / PO Reference *', isDark),
                            TextFormField(controller: purchaseRefCtrl, decoration: const InputDecoration(isDense: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _label('Select Medicine / Item to Return *', isDark),
                  DropdownButtonFormField<Product>(
                    value: selectedProduct,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: _products.take(100).map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.batchNumber ?? "No Batch"} - Exp: ${p.expiryDate ?? "N/A"}) - Stock: ${p.stockQuantity}'))).toList(),
                    onChanged: (v) {
                      setDlgState(() {
                        selectedProduct = v;
                        if (v != null) priceCtrl.text = v.purchasePrice.toStringAsFixed(2);
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
                            _label('Purchase Unit Cost *', isDark),
                            TextFormField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(prefixText: '$currency ', isDense: true),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _label('Return Reason / Damage Report', isDark),
                  TextFormField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'e.g. Near expiry medicine returned to manufacturer', isDense: true)),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Debit Note Value:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                        Text('$currency${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2563EB))),
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
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm Purchase Return', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (selectedProduct == null || qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select product and quantity'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          if (qty > selectedProduct!.stockQuantity) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Cannot return more than current stock (${selectedProduct!.stockQuantity})'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          final pr = PurchaseReturn(
                            returnNo: nextRef,
                            purchaseRef: purchaseRefCtrl.text.trim(),
                            supplierId: selectedSupplier?.id,
                            supplierName: selectedSupplier?.name ?? 'Standard Distributor',
                            date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                            totalAmount: total,
                            refundAmount: total,
                            reason: reasonCtrl.text.trim(),
                            items: [
                              PurchaseReturnItem(
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

                          await db.addPurchaseReturn(pr);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Debit note $nextRef issued and vendor balance reduced!'), backgroundColor: const Color(0xFF10B981)),
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
    final totalRecovered = _returns.fold(0.0, (sum, r) => sum + r.refundAmount);

    final filtered = _returns.where((r) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return r.returnNo.toLowerCase().contains(q) ||
          r.purchaseRef.toLowerCase().contains(q) ||
          r.supplierName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Returns & Debit Notes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Return near-expiry, damaged or recall medicines back to distributors and debit vendor balance',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Purchase Return', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddReturnDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top KPI Strip
            Row(
              children: [
                _kpiCard('TOTAL DEBIT NOTES', '${_returns.length}', Icons.outbox_rounded, const Color(0xFF2563EB), isDark),
                const SizedBox(width: 14),
                _kpiCard('VENDOR RECOVERED VALUE', '$currency${totalRecovered.toStringAsFixed(2)}', Icons.account_balance_wallet_rounded, const Color(0xFF059669), isDark),
                const SizedBox(width: 14),
                _kpiCard('TOTAL DEDUCTED ITEMS', '${_returns.fold(0, (s, r) => s + r.items.length)}', Icons.inventory_2_rounded, const Color(0xFF7C3AED), isDark),
              ],
            ),
            const SizedBox(height: 20),

            // Search
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
                  hintText: 'Search by debit note reference, purchase bill no, or supplier name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Table
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
                          child: Center(child: Text('No purchase return records recorded yet.')),
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
                                DataColumn(label: Text('DEBIT NOTE REF', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('PURCHASE BILL', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('DISTRIBUTOR / VENDOR', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('ITEMS RETURNED', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('DEBIT AMOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('REASON', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((r) {
                                return DataRow(cells: [
                                  DataCell(Text(r.returnNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                                  DataCell(Text(r.date.split(' ').first)),
                                  DataCell(Text(r.purchaseRef, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                                  DataCell(Text(r.supplierName)),
                                  DataCell(Text('${r.items.length} items')),
                                  DataCell(Text('$currency${r.refundAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        r.status.toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
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
