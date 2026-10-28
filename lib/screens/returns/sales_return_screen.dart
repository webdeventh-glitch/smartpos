import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'sales_return_dialog.dart';

class SalesReturnScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SalesReturnScreen({super.key, required this.settings});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  final ScrollController _hScrollController = ScrollController();
  List<SaleReturn> _returns = [];
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

    if (mounted) {
      setState(() {
        _returns = rets;
        _loading = false;
      });
    }
  }

  void _openAddReturnDialog({Sale? sale}) {
    showDialog(
      context: context,
      builder: (_) => SalesReturnDialog(
        settings: widget.settings,
        initialSale: sale,
        onReturnSuccess: _load,
      ),
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
