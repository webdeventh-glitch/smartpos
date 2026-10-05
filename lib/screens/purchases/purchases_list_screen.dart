import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import 'add_purchase_dialog.dart';

class PurchasesListScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PurchasesListScreen({super.key, required this.settings});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  List<Purchase> _purchases = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getPurchases();
    if (mounted) {
      setState(() {
        _purchases = list;
        _loading = false;
      });
    }
  }

  void _openAddPurchase() {
    showDialog(
      context: context,
      builder: (_) => AddPurchaseDialog(onPurchaseSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalPurchases = _purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalDue = _purchases.fold(0.0, (sum, p) => sum + p.dueAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Purchases & Restocking',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage incoming supplier shipments, purchase invoices, and vendor payables.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004EEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Purchase', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddPurchase,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Purchases', '$currency${totalPurchases.toStringAsFixed(2)}', const Color(0xFF004EEB)),
                const SizedBox(width: 14),
                _mini('Total Payables Due', '$currency${totalDue.toStringAsFixed(2)}', const Color(0xFFEF4444)),
                const SizedBox(width: 14),
                _mini('Purchase Orders', '${_purchases.length} orders', const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _purchases.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No purchase records yet.', style: TextStyle(color: Colors.grey))),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('REF NO')),
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('SUPPLIER')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('PAYMENT')),
                              DataColumn(label: Text('TOTAL AMOUNT')),
                              DataColumn(label: Text('PAID AMOUNT')),
                              DataColumn(label: Text('BALANCE DUE')),
                            ],
                            rows: _purchases.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(p.refNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                                  DataCell(Text(p.createdAt, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                  DataCell(Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(StatusPill(status: p.status)),
                                  DataCell(StatusPill(status: p.paymentStatus)),
                                  DataCell(Text('$currency${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900))),
                                  DataCell(Text('$currency${p.paidAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                                  DataCell(Text(
                                    p.dueAmount > 0 ? '$currency${p.dueAmount.toStringAsFixed(2)}' : '-',
                                    style: TextStyle(color: p.dueAmount > 0 ? const Color(0xFFEF4444) : Colors.grey, fontWeight: FontWeight.bold),
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
