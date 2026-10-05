import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class PaymentAccountsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PaymentAccountsScreen({super.key, required this.settings});

  @override
  State<PaymentAccountsScreen> createState() => _PaymentAccountsScreenState();
}

class _PaymentAccountsScreenState extends State<PaymentAccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PaymentAccount> _accounts = [];
  List<AccountTransfer> _transfers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final accs = await db.getPaymentAccounts();
    final trfs = await db.getAccountTransfers();
    if (mounted) {
      setState(() {
        _accounts = accs;
        _transfers = trfs;
        _loading = false;
      });
    }
  }

  Future<void> _showAddAccountDialog() async {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0.00');
    final noteCtrl = TextEditingController();
    String type = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFF004EEB)),
              SizedBox(width: 8),
              Text('Add Payment Account', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name*', isDense: true)),
                  const SizedBox(height: 12),
                  TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Account Number / IBAN', isDense: true)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Account Type*', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash Drawer / Register')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Operating Account')),
                      DropdownMenuItem(value: 'pos_terminal', child: Text('POS Merchant Terminal / Gateway')),
                    ],
                    onChanged: (val) => setDlgState(() => type = val ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance (${widget.settings.currencySymbol})*',
                      isDense: true,
                      prefixText: '${widget.settings.currencySymbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Account Description / Note', isDense: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;

                final db = await DatabaseService.initialize();
                await db.addPaymentAccount(PaymentAccount(
                  name: name,
                  accountNumber: numCtrl.text.trim(),
                  accountType: type,
                  openingBalance: bal,
                  currentBalance: bal,
                  note: noteCtrl.text.trim(),
                ));

                Navigator.pop(ctx);
                _load();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment account "$name" created successfully!'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              },
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferFundsDialog() async {
    if (_accounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 payment accounts are required to transfer funds.')),
      );
      return;
    }

    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextAccountTransferRef();

    PaymentAccount fromAcc = _accounts.first;
    PaymentAccount toAcc = _accounts[1];
    final amountCtrl = TextEditingController(text: '500.00');
    final noteCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('Transfer Funds Between Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<PaymentAccount>(
                    initialValue: fromAcc,
                    decoration: const InputDecoration(labelText: 'From Account (Source)*', isDense: true),
                    items: _accounts
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text('${a.name} (${widget.settings.currencySymbol}${a.currentBalance.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (val) => setDlgState(() => fromAcc = val ?? fromAcc),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<PaymentAccount>(
                    initialValue: toAcc,
                    decoration: const InputDecoration(labelText: 'To Account (Destination)*', isDense: true),
                    items: _accounts
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text('${a.name} (${widget.settings.currencySymbol}${a.currentBalance.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (val) => setDlgState(() => toAcc = val ?? toAcc),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount (${widget.settings.currencySymbol})*',
                      isDense: true,
                      prefixText: '${widget.settings.currencySymbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Reference Note / Reason', isDense: true)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              onPressed: () async {
                if (fromAcc.id == toAcc.id) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Source and destination accounts cannot be the same!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                final transfer = AccountTransfer(
                  fromAccountId: fromAcc.id!,
                  fromAccountName: fromAcc.name,
                  toAccountId: toAcc.id!,
                  toAccountName: toAcc.name,
                  amount: amount,
                  date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                  refNo: nextRef,
                  note: noteCtrl.text.trim(),
                );

                await db.transferAccountFunds(transfer);
                Navigator.pop(ctx);
                _load();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Transferred ${widget.settings.currencySymbol}${amount.toStringAsFixed(2)} from ${fromAcc.name} to ${toAcc.name}!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Transfer Funds'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalFunds = _accounts.fold(0.0, (sum, a) => sum + a.currentBalance);

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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Accounts & Banking',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Manage cash drawers, bank accounts, POS merchant terminals, and double-entry transfers.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004EEB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddAccountDialog,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Transfer Funds', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showTransferFundsDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Liquid Assets', '$currency${totalFunds.toStringAsFixed(2)}', const Color(0xFF004EEB)),
                const SizedBox(width: 14),
                _mini('Active Accounts', '${_accounts.length}', const Color(0xFF10B981)),
                const SizedBox(width: 14),
                _mini('Inter-Account Transfers', '${_transfers.length}', const Color(0xFF6366F1)),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF004EEB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF004EEB),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Payment Accounts'),
                Tab(icon: Icon(Icons.history_outlined), text: 'Transfer History'),
              ],
            ),
            const SizedBox(height: 16),

            _loading
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                : SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Accounts List
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _accounts.isEmpty
                              ? const Center(child: Text('No payment accounts configured yet.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('ACCOUNT NAME', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('ACCOUNT / IBAN', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('OPENING BALANCE', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('CURRENT BALANCE', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('NOTE', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _accounts.map((a) {
                                      final isCash = a.accountType == 'cash';
                                      return DataRow(cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              Icon(
                                                isCash ? Icons.money : (a.accountType == 'pos_terminal' ? Icons.credit_card : Icons.account_balance),
                                                size: 16,
                                                color: isCash ? const Color(0xFF10B981) : const Color(0xFF004EEB),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(a.accountType.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                        DataCell(Text(a.accountNumber.isNotEmpty ? a.accountNumber : '-', style: const TextStyle(fontSize: 12))),
                                        DataCell(Text('$currency${a.openingBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                        DataCell(Text(
                                          '$currency${a.currentBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13),
                                        )),
                                        DataCell(Text(a.note.isNotEmpty ? a.note : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                        ),

                        // Tab 2: Transfers History
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _transfers.isEmpty
                              ? const Center(child: Text('No fund transfers recorded yet.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('REF NO', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('FROM ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('TO ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('AMOUNT TRANSFERRED', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('NOTE', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _transfers.map((t) {
                                      return DataRow(cells: [
                                        DataCell(Text(t.date.split(' ').first)),
                                        DataCell(Text(t.refNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                                        DataCell(Text(t.fromAccountName, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
                                        DataCell(Text(t.toAccountName, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                                        DataCell(Text('$currency${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900))),
                                        DataCell(Text(t.note.isNotEmpty ? t.note : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ],
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
