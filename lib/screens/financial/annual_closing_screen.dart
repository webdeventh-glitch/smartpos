import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class AnnualClosingScreen extends StatefulWidget {
  final BusinessSettings settings;

  const AnnualClosingScreen({super.key, required this.settings});

  @override
  State<AnnualClosingScreen> createState() => _AnnualClosingScreenState();
}

class _AnnualClosingScreenState extends State<AnnualClosingScreen> {
  final ScrollController _hScrollController = ScrollController();
  List<FinancialYear> _closedYears = [];
  bool _loading = true;

  // Current Year Audit Preview
  double _currSales = 0.0;
  double _currPurchases = 0.0;
  double _currExpenses = 0.0;
  double _currStockVal = 0.0;
  double _currReceivables = 0.0;
  double _currPayables = 0.0;
  int _ordersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = await DatabaseService.initialize();
    final years = await db.getFinancialYears();

    // Calculate real metrics from active database
    final sales = await db.getSales();
    final purchases = await db.getPurchases();
    final expenses = await db.getExpenses();
    final products = await db.getProducts();
    final customers = await db.getContacts(type: 'customer');
    final suppliers = await db.getContacts(type: 'supplier');

    double sTotal = 0.0;
    for (final s in sales) {
      if (s.saleStatus == 'final') sTotal += s.totalAmount;
    }

    double pTotal = 0.0;
    for (final p in purchases) {
      pTotal += p.finalTotal;
    }

    double eTotal = 0.0;
    for (final e in expenses) {
      eTotal += e.amount;
    }

    double stockVal = 0.0;
    for (final prd in products) {
      stockVal += (prd.stockQuantity * prd.purchasePrice);
    }

    double recv = 0.0;
    for (final c in customers) {
      if (c.balance > 0) recv += c.balance;
    }

    double pay = 0.0;
    for (final sup in suppliers) {
      if (sup.balance > 0) pay += sup.balance;
    }

    if (mounted) {
      setState(() {
        _closedYears = years;
        _currSales = sTotal;
        _currPurchases = pTotal;
        _currExpenses = eTotal;
        _currStockVal = stockVal;
        _currReceivables = recv;
        _currPayables = pay;
        _ordersCount = sales.length;
        _loading = false;
      });
    }
  }

  Future<void> _performAnnualClosing() async {
    final netProfit = _currSales - _currPurchases - _currExpenses;
    final currency = widget.settings.currencySymbol;
    final currentYear = DateTime.now().year;
    final yearTitle = 'Fiscal Year $currentYear';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Annual Year Closing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to execute Annual Fiscal Closing for $yearTitle?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  _confirmRow('Annual Revenue:', '$currency${_currSales.toStringAsFixed(2)}'),
                  _confirmRow('Operating Profit:', '$currency${netProfit.toStringAsFixed(2)}'),
                  _confirmRow('Closing Stock Valuation:', '$currency${_currStockVal.toStringAsFixed(2)}'),
                  _confirmRow('Receivables Carried Forward:', '$currency${_currReceivables.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• All ending balances will be locked and carried forward as opening balances for the new fiscal year.\n• A permanent audit certificate will be recorded in the system database.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Execute Closing', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = await DatabaseService.initialize();
    final currentUser = AuthService.currentUser?.name ?? 'Irfan Khan (SuperAdmin)';

    final fy = FinancialYear(
      yearTitle: yearTitle,
      startDate: widget.settings.startDate,
      endDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
      closingDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      totalSales: _currSales,
      totalPurchases: _currPurchases,
      totalExpenses: _currExpenses,
      netProfit: netProfit,
      stockValuation: _currStockVal,
      receivables: _currReceivables,
      payables: _currPayables,
      closedBy: currentUser,
      status: 'closed',
      notes: 'Formally closed by $currentUser. Balances successfully carried forward to FY ${currentYear + 1}.',
    );

    await db.closeFinancialYear(fy);
    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Annual fiscal year closing for $yearTitle completed successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _confirmRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final netProfit = _currSales - _currPurchases - _currExpenses;

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
                      'Annual Financial Closing & Fiscal Year Audit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Close fiscal years, snapshot balance sheets, carry forward ledgers, and audit agency books',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.lock_clock_rounded, size: 18),
                  label: const Text('Execute Annual Closing', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _performAnnualClosing,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Active Fiscal Year Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF1E1B4B), Color(0xFF1E293B)]
                      : const [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Fiscal Year: ${DateTime.now().year} (Open)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Fiscal Cycle: ${widget.settings.startDate} to ${DateFormat("dd/MM/yyyy").format(DateTime.now())} • Accounting Method: ${widget.settings.stockAccountingMethod}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20)),
                        child: const Text('● LIVE LEDGER AUDIT', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  // 6 Core Metrics Grid
                  Row(
                    children: [
                      _gridBox('ANNUAL REVENUE', '$currency${_currSales.toStringAsFixed(2)}', const Color(0xFF059669), isDark),
                      const SizedBox(width: 12),
                      _gridBox('PURCHASES & COGS', '$currency${_currPurchases.toStringAsFixed(2)}', const Color(0xFF2563EB), isDark),
                      const SizedBox(width: 12),
                      _gridBox('OVERHEAD EXPENSES', '$currency${_currExpenses.toStringAsFixed(2)}', const Color(0xFFDC2626), isDark),
                      const SizedBox(width: 12),
                      _gridBox('NET OPERATING PROFIT', '$currency${netProfit.toStringAsFixed(2)}', netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _gridBox('CLOSING INVENTORY VALUATION', '$currency${_currStockVal.toStringAsFixed(2)}', const Color(0xFF7C3AED), isDark),
                      const SizedBox(width: 12),
                      _gridBox('CUSTOMER RECEIVABLES', '$currency${_currReceivables.toStringAsFixed(2)}', const Color(0xFFD97706), isDark),
                      const SizedBox(width: 12),
                      _gridBox('SUPPLIER PAYABLES', '$currency${_currPayables.toStringAsFixed(2)}', const Color(0xFFEA580C), isDark),
                      const SizedBox(width: 12),
                      _gridBox('PROCESSED INVOICES', '$_ordersCount Invoices', const Color(0xFF475569), isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Historical Closed Years Table
            Text(
              'Historical Closed Fiscal Years & Audit Log',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _closedYears.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No previous financial years closed yet. Execute Annual Closing above to lock your first audit record.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
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
                                DataColumn(label: Text('FISCAL YEAR', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('START DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CLOSING DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('FINAL SALES', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('NET PROFIT', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('STOCK VALUE', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('RECEIVABLES C/F', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('CLOSED BY', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _closedYears.map((fy) {
                                return DataRow(cells: [
                                  DataCell(Text(fy.yearTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                                  DataCell(Text(fy.startDate)),
                                  DataCell(Text(fy.endDate)),
                                  DataCell(Text('$currency${fy.totalSales.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(
                                    '$currency${fy.netProfit.toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.w900, color: fy.netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                                  )),
                                  DataCell(Text('$currency${fy.stockValuation.toStringAsFixed(2)}')),
                                  DataCell(Text('$currency${fy.receivables.toStringAsFixed(2)}')),
                                  DataCell(Text(fy.closedBy)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('LOCKED & CLOSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    ),
                                  ),
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

  Widget _gridBox(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
