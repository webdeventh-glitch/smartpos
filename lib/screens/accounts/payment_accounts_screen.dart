import 'package:flutter/material.dart';
import '../../models/models.dart';

class PaymentAccountsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PaymentAccountsScreen({super.key, required this.settings});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen> {
  final List<Map<String, dynamic>> _accounts = [
    {
      'name': 'Cash Register Drawer #1',
      'accountNumber': 'CASH-REG-01',
      'type': 'Cash in Hand',
      'balance': 1250.00,
      'status': 'Active',
    },
    {
      'name': 'Primary Business Bank',
      'accountNumber': 'ACC-9821-4402',
      'type': 'Bank Account',
      'balance': 24500.00,
      'status': 'Active',
    },
    {
      'name': 'Card POS Terminal Gateway',
      'accountNumber': 'STRIPE-POS-89',
      'type': 'POS Terminal / Merchant',
      'balance': 8340.50,
      'status': 'Active',
    },
  ];

  void _showAddAccountDialog() {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0.00');
    String type = 'Bank Account';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Payment Account', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name*')),
                const SizedBox(height: 12),
                TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Account Number / Identifier*')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(value: 'Cash in Hand', child: Text('Cash in Hand')),
                    DropdownMenuItem(value: 'Bank Account', child: Text('Bank Account')),
                    DropdownMenuItem(value: 'POS Terminal / Merchant', child: Text('POS Terminal / Merchant')),
                  ],
                  onChanged: (val) => setDlgState(() => type = val ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Opening Balance (${widget.settings.currencySymbol})'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _accounts.add({
                      'name': nameCtrl.text.trim(),
                      'accountNumber': numCtrl.text.trim(),
                      'type': type,
                      'balance': double.tryParse(balCtrl.text.trim()) ?? 0.0,
                      'status': 'Active',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalBalance = _accounts.fold(0.0, (sum, a) => sum + (a['balance'] as double));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  children: const [
                    Text('Payment Accounts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Manage cash drawers, bank accounts, POS card gateways, and general ledger balances.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004EEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.account_balance, size: 18),
                  label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showAddAccountDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total Liquidity Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF004EEB), Color(0xFF0284C7)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Cash & Liquidity Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('$currency${totalBalance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Account Number', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Account Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Current Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _accounts.map((a) {
                  return DataRow(cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF004EEB)),
                            tooltip: 'Transfer Fund',
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long, size: 18, color: Color(0xFF64748B)),
                            tooltip: 'Account Book',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(a['accountNumber'])),
                    DataCell(Text(a['type'])),
                    DataCell(Text('$currency${(a['balance'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                        child: Text(a['status'],
                            style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
