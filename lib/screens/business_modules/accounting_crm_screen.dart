import 'package:flutter/material.dart';
import '../../models/models.dart';

class AccountingCrmScreen extends StatefulWidget {
  final BusinessSettings settings;

  const AccountingCrmScreen({super.key, required this.settings});

  @override
  State<AccountingCrmScreen> createState() => _AccountingCrmScreenState();
}

class _AccountingCrmScreenState extends State<AccountingCrmScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final List<Map<String, dynamic>> _chartOfAccounts = [
    {'code': '1001', 'name': 'Cash in Hand (Main Drawer)', 'type': 'Asset', 'balance': 185400.0},
    {'code': '1002', 'name': 'Meezan Bank Current Account', 'type': 'Asset', 'balance': 642000.0},
    {'code': '1003', 'name': 'Accounts Receivable (Customers Khata)', 'type': 'Asset', 'balance': 312500.0},
    {'code': '2001', 'name': 'Accounts Payable (Suppliers)', 'type': 'Liability', 'balance': 240000.0},
    {'code': '2002', 'name': 'Short Term Loans', 'type': 'Liability', 'balance': 100000.0},
    {'code': '3001', 'name': 'Owner Equity / Capital', 'type': 'Equity', 'balance': 800000.0},
    {'code': '4001', 'name': 'Sales Revenue (Gross)', 'type': 'Revenue', 'balance': 1450000.0},
    {'code': '5001', 'name': 'Cost of Goods Sold (COGS)', 'type': 'Expense', 'balance': 980000.0},
    {'code': '5002', 'name': 'Shop Rent & Utilities', 'type': 'Expense', 'balance': 85000.0},
  ];

  final List<Map<String, dynamic>> _journalEntries = [
    {
      'voucherNo': 'JV-2041',
      'date': '21 Oct 2026',
      'narration': 'Cash deposited into Meezan Bank Current Account',
      'debitAcc': 'Meezan Bank Current Account',
      'creditAcc': 'Cash in Hand (Main Drawer)',
      'amount': 50000.0,
    },
    {
      'voucherNo': 'JV-2042',
      'date': '20 Oct 2026',
      'narration': 'Shop electricity & internet bill payment for October',
      'debitAcc': 'Shop Rent & Utilities',
      'creditAcc': 'Cash in Hand (Main Drawer)',
      'amount': 22500.0,
    },
    {
      'voucherNo': 'JV-2043',
      'date': '19 Oct 2026',
      'narration': 'Payment received from wholesale customer against Invoice #402',
      'debitAcc': 'Cash in Hand (Main Drawer)',
      'creditAcc': 'Accounts Receivable (Customers Khata)',
      'amount': 85000.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddJournalModal() {
    final narrCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String debitAcc = 'Shop Rent & Utilities';
    String creditAcc = 'Cash in Hand (Main Drawer)';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('New Journal Voucher (Double-Entry)', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: narrCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Narration / Description*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Voucher Amount*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
              onPressed: () {
                if (narrCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _journalEntries.insert(0, {
                      'voucherNo': 'JV-${2044 + _journalEntries.length}',
                      'date': 'Today',
                      'narration': narrCtrl.text.trim(),
                      'debitAcc': debitAcc,
                      'creditAcc': creditAcc,
                      'amount': double.tryParse(amountCtrl.text) ?? 1000.0,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Post Voucher'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

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
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.account_tree_rounded, size: 18), text: 'Chart of Accounts'),
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Journal Vouchers Register'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
              onPressed: _showAddJournalModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Journal Voucher'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Chart of Accounts
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
                  DataColumn(label: Text('ACCOUNT NAME', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                  DataColumn(label: Text('TYPE / CLASSIFICATION', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                  DataColumn(label: Text('CURRENT BALANCE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
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
                      DataCell(Text('$currency${(a['balance'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Tab 2: Journal Vouchers
          SingleChildScrollView(
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
                                child: Text(jv['voucherNo'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
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
                        'Debit: ${jv['debitAcc']}  |  Credit: ${jv['creditAcc']}',
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
    );
  }
}
