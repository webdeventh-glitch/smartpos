import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/pay_due_dialog.dart';
import 'add_purchase_dialog.dart';
import 'purchase_receipt_dialog.dart';

class PurchasesListScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PurchasesListScreen({super.key, required this.settings});

  @override
  State<PurchasesListScreen> createState() => _PurchasesListScreenState();
}

class _PurchasesListScreenState extends State<PurchasesListScreen> {
  List<Purchase> _purchases = [];
  bool _loading = true;
  final ScrollController _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalPurchases = _purchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalDue = _purchases.fold(0.0, (sum, p) => sum + p.dueAmount);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchases & Restocking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage incoming supplier shipments, purchase invoices, and vendor payables.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _openAddPurchase,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Purchases', '$currency${totalPurchases.toStringAsFixed(2)}', const Color(0xFF4F46E5), isDark: isDark),
                const SizedBox(width: 14),
                _mini('Total Payables Due', '$currency${totalDue.toStringAsFixed(2)}', const Color(0xFFEF4444), isDark: isDark),
                const SizedBox(width: 14),
                _mini('Purchase Orders', '${_purchases.length} orders', const Color(0xFF10B981), isDark: isDark),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))))
                  : _purchases.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No purchase records yet.',
                              style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey),
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Scrollbar(
                            controller: _hScroll,
                            thumbVisibility: true,
                            trackVisibility: true,
                            thickness: 9,
                            radius: const Radius.circular(5),
                            child: SingleChildScrollView(
                              controller: _hScroll,
                              scrollDirection: Axis.horizontal,
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: DataTable(
                                  columnSpacing: 22,
                                  horizontalMargin: 16,
                                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  headingTextStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    fontSize: 12,
                                  ),
                                  dataRowMinHeight: 50,
                                  dataRowMaxHeight: 56,
                                  columns: const [
                                    DataColumn(label: Text('REF NO')),
                                    DataColumn(label: Text('DATE')),
                                    DataColumn(label: Text('LOCATION')),
                                    DataColumn(label: Text('SUPPLIER')),
                                    DataColumn(label: Text('STATUS')),
                                    DataColumn(label: Text('PAYMENT')),
                                    DataColumn(label: Text('TOTAL AMOUNT')),
                                    DataColumn(label: Text('PAID AMOUNT')),
                                    DataColumn(label: Text('BALANCE DUE')),
                                    DataColumn(label: Text('ACTIONS')),
                                  ],
                                  rows: _purchases.map((p) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(
                                          p.refNo,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                          ),
                                        )),
                                        DataCell(Text(
                                          p.createdAt,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        )),
                                        DataCell(Text(
                                          p.locationName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                          ),
                                        )),
                                        DataCell(Text(
                                          p.supplierName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        )),
                                        DataCell(StatusPill(status: p.status)),
                                        DataCell(StatusPill(status: p.paymentStatus)),
                                        DataCell(Text(
                                          '$currency${p.totalAmount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        )),
                                        DataCell(Text(
                                          '$currency${p.paidAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                        )),
                                        DataCell(Text(
                                          p.dueAmount > 0 ? '$currency${p.dueAmount.toStringAsFixed(2)}' : '-',
                                          style: TextStyle(
                                            color: p.dueAmount > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF64748B) : Colors.grey),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (p.dueAmount > 0)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.payments_outlined,
                                                    size: 18,
                                                    color: Color(0xFF059669),
                                                  ),
                                                  tooltip: 'Pay Supplier Due',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) => PayDueDialog(
                                                        settings: widget.settings,
                                                        type: DuePaymentType.purchase,
                                                        entityId: p.id!,
                                                        reference: p.referenceNo,
                                                        contactName: p.supplierName,
                                                        contactId: p.supplierId,
                                                        totalAmount: p.totalAmount,
                                                        paidAmount: p.paidAmount,
                                                        dueAmount: p.dueAmount,
                                                        onPaymentSuccess: _load,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.print_outlined,
                                                  size: 18,
                                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF004EEB),
                                                ),
                                                tooltip: 'Print Purchase Receipt',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => PurchaseReceiptDialog(
                                                      purchase: p,
                                                      settings: widget.settings,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color color, {required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
