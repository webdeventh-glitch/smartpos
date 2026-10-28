import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AccountingCrmScreen extends StatefulWidget {
  final BusinessSettings settings;

  const AccountingCrmScreen({super.key, required this.settings});

  @override
  State<AccountingCrmScreen> createState() => _AccountingCrmScreenState();
}

class _AccountingCrmScreenState extends State<AccountingCrmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;

  Map<String, dynamic> _trialBalance = {};
  List<Map<String, dynamic>> _chartOfAccounts = [];
  List<Map<String, dynamic>> _journalEntries = [];
  List<PaymentAccount> _paymentAccounts = [];

  final List<String> _commonDebitAccounts = [
    'Cash in Hand (Main Drawer)',
    'Accounts Receivable (Customers Khata)',
    'Inventory Asset',
    'Shop Rent & Utilities',
    'Salaries & Wages',
    'Office Supplies & Maintenance',
    'Advertising & Marketing',
    'Bank Charges & Fees',
  ];

  final List<String> _commonCreditAccounts = [
    'Cash in Hand (Main Drawer)',
    'Accounts Payable (Suppliers Khata)',
    'Sales Revenue (Gross)',
    'Owner Equity / Capital',
    'Short Term Loans',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseService.initialize();
      final tb = await db.getFinancialTrialBalance();
      final jvs = await db.getJournalVouchers();
      final pAccounts = await db.getPaymentAccounts();

      final List<Map<String, dynamic>> coa = [];

      // 1001: Cash in Hand
      coa.add({
        'code': '1001',
        'name': 'Cash in Hand (Active Drawers)',
        'type': 'Asset',
        'balance': tb['cashInHand'] as double? ?? 0.0,
      });

      // 1002+: Payment accounts / banks
      int bankCode = 1002;
      for (final acc in pAccounts) {
        if (acc.accountType != 'cash') {
          coa.add({
            'code': '$bankCode',
            'name': '${acc.name} (${acc.accountNumber.isNotEmpty ? acc.accountNumber : "Bank"})',
            'type': 'Asset',
            'balance': acc.currentBalance,
          });
          bankCode++;
        }
      }

      // 1010: Accounts Receivable
      coa.add({
        'code': '1010',
        'name': 'Accounts Receivable (Customers Khata)',
        'type': 'Asset',
        'balance': tb['accountsReceivable'] as double? ?? 0.0,
      });

      // 1020: Inventory Asset
      coa.add({
        'code': '1020',
        'name': 'Merchandise Inventory Valuation',
        'type': 'Asset',
        'balance': tb['inventoryValuation'] as double? ?? 0.0,
      });

      // 2001: Accounts Payable
      coa.add({
        'code': '2001',
        'name': 'Accounts Payable (Suppliers Khata)',
        'type': 'Liability',
        'balance': tb['accountsPayable'] as double? ?? 0.0,
      });

      // 3001: Owner Equity
      coa.add({
        'code': '3001',
        'name': 'Owner Equity / Retained Earnings',
        'type': 'Equity',
        'balance': tb['ownerEquity'] as double? ?? 0.0,
      });

      // 4001: Sales Revenue
      coa.add({
        'code': '4001',
        'name': 'Sales Revenue (Gross)',
        'type': 'Revenue',
        'balance': tb['salesRevenue'] as double? ?? 0.0,
      });

      // 5001: Cost of Goods Sold
      coa.add({
        'code': '5001',
        'name': 'Cost of Goods Sold (Purchases)',
        'type': 'Expense',
        'balance': tb['costOfGoods'] as double? ?? 0.0,
      });

      // 5002: Operating & Store Expenses
      coa.add({
        'code': '5002',
        'name': 'Store Operating & General Expenses',
        'type': 'Expense',
        'balance': tb['operatingExpenses'] as double? ?? 0.0,
      });

      if (mounted) {
        setState(() {
          _trialBalance = tb;
          _chartOfAccounts = coa;
          _journalEntries = jvs;
          _paymentAccounts = pAccounts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAddJournalModal() {
    final narrCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController(text: 'JV-${DateTime.now().millisecondsSinceEpoch % 100000}');

    // Build selectable lists including bank accounts
    final List<String> debitOptions = [
      ..._commonDebitAccounts,
      ..._paymentAccounts.map((a) => a.name),
    ];
    final List<String> creditOptions = [
      ..._commonCreditAccounts,
      ..._paymentAccounts.map((a) => a.name),
    ];

    String debitAcc = debitOptions.contains('Shop Rent & Utilities') ? 'Shop Rent & Utilities' : debitOptions.first;
    String creditAcc = creditOptions.contains('Cash in Hand (Main Drawer)') ? 'Cash in Hand (Main Drawer)' : creditOptions.first;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4338CA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4338CA), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'Post Journal Voucher (Double-Entry)',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voucher Reference #',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: refCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Debit Account (Increase in Asset / Expense)*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: debitAcc,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: debitOptions.toSet().map((acc) => DropdownMenuItem(value: acc, child: Text(acc, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setDlgState(() => debitAcc = val ?? debitAcc),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Credit Account (Decrease in Asset / Increase in Liability / Equity)*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: creditAcc,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: creditOptions.toSet().map((acc) => DropdownMenuItem(value: acc, child: Text(acc, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setDlgState(() => creditAcc = val ?? creditAcc),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Amount ($currency)*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: '$currency ',
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Narration / Description*',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: narrCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Paid shop rent via cash drawer',
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Post Journal Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final narration = narrCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final refNo = refCtrl.text.trim();

                if (narration.isEmpty || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid narration and amount!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                if (debitAcc == creditAcc) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debit and Credit accounts must be different!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final db = await DatabaseService.initialize();
                await db.addJournalVoucher(
                  narration: narration,
                  debitAccount: debitAcc,
                  creditAccount: creditAcc,
                  amount: amt,
                  refNo: refNo.isNotEmpty ? refNo : null,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Voucher $refNo posted successfully! Dr $debitAcc / Cr $creditAcc'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final totalAssets = _trialBalance['totalAssets'] as double? ?? 0.0;
    final totalLiabilities = _trialBalance['totalLiabilities'] as double? ?? 0.0;
    final ownerEquity = _trialBalance['ownerEquity'] as double? ?? 0.0;
    final netProfit = _trialBalance['netProfit'] as double? ?? 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: Color(0xFF4338CA), size: 22),
            const SizedBox(width: 10),
            Text(
              'Accounting & Double-Entry Financial Ledger',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF4338CA),
          indicatorColor: const Color(0xFF4338CA),
          indicatorWeight: 3,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_rounded, size: 18), text: 'Live Chart of Accounts'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Journal Vouchers Register'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Ledger',
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF4338CA),
            onPressed: _loadData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 6),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showAddJournalModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Journal Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Trial Balance & Accounting Equation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D31) : Colors.white,
                    border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      _kpiEquationCard('TOTAL ASSETS', '$currency${totalAssets.toStringAsFixed(2)}', const Color(0xFF10B981), isDark),
                      const SizedBox(width: 12),
                      _kpiEquationCard('TOTAL LIABILITIES', '$currency${totalLiabilities.toStringAsFixed(2)}', const Color(0xFFEF4444), isDark),
                      const SizedBox(width: 12),
                      _kpiEquationCard('OWNER EQUITY', '$currency${ownerEquity.toStringAsFixed(2)}', const Color(0xFF3B82F6), isDark),
                      const SizedBox(width: 12),
                      _kpiEquationCard('NET PROFIT / LOSS', '$currency${netProfit.toStringAsFixed(2)}', netProfit >= 0 ? const Color(0xFF059669) : Colors.red, isDark),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'A = L + E Verified',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Tab 1: Live Chart of Accounts
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                            columns: [
                              DataColumn(label: Text('CODE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                              DataColumn(label: Text('ACCOUNT HEAD', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                              DataColumn(label: Text('CLASSIFICATION', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                              DataColumn(numeric: true, label: Text('NET BALANCE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                            ],
                            rows: _chartOfAccounts.map((a) {
                              final type = a['type'] as String;
                              Color typeColor = const Color(0xFF3B82F6);
                              if (type == 'Asset') typeColor = const Color(0xFF10B981);
                              if (type == 'Liability') typeColor = const Color(0xFFEF4444);
                              if (type == 'Revenue') typeColor = const Color(0xFF8B5CF6);
                              if (type == 'Expense') typeColor = const Color(0xFFF97316);

                              return DataRow(
                                cells: [
                                  DataCell(Text(a['code'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                  DataCell(Text(a['name'] as String, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: typeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                                    ),
                                  ),
                                  DataCell(Text(
                                    '$currency${(a['balance'] as double).toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      // Tab 2: Journal Vouchers Register
                      _journalEntries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No journal vouchers posted yet',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Click "New Journal Voucher" above to post double-entry vouchers.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _journalEntries.length,
                                itemBuilder: (context, idx) {
                                  final jv = _journalEntries[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF4338CA).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    jv['voucherNo'] as String,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(jv['date'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                              ],
                                            ),
                                            Text(
                                              '$currency${(jv['amount'] as double).toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          jv['narration'] as String,
                                          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Debit (Dr): ${jv['debitAcc']}  •  Credit (Cr): ${jv['creditAcc']}',
                                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _kpiEquationCard(String title, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
