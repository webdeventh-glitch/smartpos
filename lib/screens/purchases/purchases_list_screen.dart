import 'dart:math' as math;
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

            LayoutBuilder(
              builder: (context, constraints) {
                final c1 = _miniCard('Total Purchases', '$currency${totalPurchases.toStringAsFixed(2)}', const Color(0xFF4F46E5), isDark: isDark);
                final c2 = _miniCard('Total Payables Due', '$currency${totalDue.toStringAsFixed(2)}', const Color(0xFFEF4444), isDark: isDark);
                final c3 = _miniCard('Purchase Orders', '${_purchases.length} orders', const Color(0xFF10B981), isDark: isDark);

                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      c1,
                      const SizedBox(height: 10),
                      c2,
                      const SizedBox(height: 10),
                      c3,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: c1),
                    const SizedBox(width: 14),
                    Expanded(child: c2),
                    const SizedBox(width: 14),
                    Expanded(child: c3),
                  ],
                );
              },
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = math.max(constraints.maxWidth, 1100.0);
                              return Scrollbar(
                                controller: _hScroll,
                                thumbVisibility: true,
                                trackVisibility: true,
                                thickness: 9,
                                radius: const Radius.circular(5),
                                child: SingleChildScrollView(
                                  controller: _hScroll,
                                  scrollDirection: Axis.horizontal,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(1.4), // REF NO
                                          1: FlexColumnWidth(1.6), // DATE
                                          2: FlexColumnWidth(1.8), // LOCATION
                                          3: FlexColumnWidth(2.0), // SUPPLIER
                                          4: FlexColumnWidth(1.2), // STATUS
                                          5: FlexColumnWidth(1.2), // PAYMENT
                                          6: FlexColumnWidth(1.4), // TOTAL AMOUNT
                                          7: FlexColumnWidth(1.4), // PAID AMOUNT
                                          8: FlexColumnWidth(1.3), // BALANCE DUE
                                          9: FlexColumnWidth(1.2), // ACTIONS
                                        },
                                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2)),
                                            ),
                                            children: [
                                              _th('REF NO', isDark),
                                              _th('DATE', isDark),
                                              _th('LOCATION', isDark),
                                              _th('SUPPLIER', isDark),
                                              _th('STATUS', isDark),
                                              _th('PAYMENT', isDark),
                                              _th('TOTAL AMOUNT', isDark),
                                              _th('PAID AMOUNT', isDark),
                                              _th('BALANCE DUE', isDark),
                                              _th('ACTIONS', isDark),
                                            ],
                                          ),
                                          ..._purchases.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final p = entry.value;
                                            final rowBg = idx.isOdd
                                                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                                : (isDark ? const Color(0xFF172033) : const Color(0xFFFBFDFF));

                                            return TableRow(
                                              decoration: BoxDecoration(
                                                color: rowBg,
                                                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0), width: 0.8)),
                                              ),
                                              children: [
                                                _td(Text(
                                                  p.refNo,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.createdAt,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.locationName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                                  ),
                                                )),
                                                _td(Text(
                                                  p.supplierName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                )),
                                                _td(StatusPill(status: p.status)),
                                                _td(StatusPill(status: p.paymentStatus)),
                                                _td(Text(
                                                  '$currency${p.totalAmount.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                )),
                                                _td(Text(
                                                  '$currency${p.paidAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                                )),
                                                _td(Text(
                                                  p.dueAmount > 0 ? '$currency${p.dueAmount.toStringAsFixed(2)}' : '-',
                                                  style: TextStyle(
                                                    color: p.dueAmount > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF64748B) : Colors.grey),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )),
                                                _td(
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
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color, {required bool isDark}) {
    return Container(
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
    );
  }

  Widget _th(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _td(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
  }
}
