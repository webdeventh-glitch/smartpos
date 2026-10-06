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

  Widget _fieldLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddAccountDialog() async {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0.00');
    final noteCtrl = TextEditingController();
    String type = 'bank';
    final currency = widget.settings.currencySymbol;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 480,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add Payment Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            SizedBox(height: 2),
                            Text('Register a bank account, cash drawer or merchant terminal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Account Name', isRequired: true),
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'e.g. Meezan Main Operating, Cash Drawer',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Account Number / IBAN'),
                      TextField(
                        controller: numCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. PK36MEZN000123456789',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Account Type', isRequired: true),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash Drawer / Register', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'bank', child: Text('Bank Operating Account', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'pos_terminal', child: Text('POS Merchant Terminal / Gateway', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) => setDlgState(() => type = val ?? type),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Opening Balance ($currency)', isRequired: true),
                      TextField(
                        controller: balCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixText: '$currency ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Description / Note'),
                      TextField(
                        controller: noteCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Additional account details...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Save Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final currency = widget.settings.currencySymbol;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transfer Funds Between Accounts', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            SizedBox(height: 2),
                            Text('Double-entry bookkeeping between drawers and banks', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('From Account (Source)', isRequired: true),
                      DropdownButtonFormField<PaymentAccount>(
                        initialValue: fromAcc,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: _accounts
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.name} ($currency${a.currentBalance.toStringAsFixed(2)})', style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (val) => setDlgState(() => fromAcc = val ?? fromAcc),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('To Account (Destination)', isRequired: true),
                      DropdownButtonFormField<PaymentAccount>(
                        initialValue: toAcc,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        items: _accounts
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text('${a.name} ($currency${a.currentBalance.toStringAsFixed(2)})', style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (val) => setDlgState(() => toAcc = val ?? toAcc),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Transfer Amount ($currency)', isRequired: true),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixText: '$currency ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _fieldLabel('Reference Note / Reason'),
                      TextField(
                        controller: noteCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Daily cash register deposit to bank...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.sync_alt_rounded, size: 18),
                        label: const Text('Transfer Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                content: Text('Transferred $currency${amount.toStringAsFixed(2)} from ${fromAcc.name} to ${toAcc.name}!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddAccountDialog,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
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
                _mini('Total Liquid Assets', '$currency${totalFunds.toStringAsFixed(2)}', const Color(0xFF4F46E5)),
                const SizedBox(width: 14),
                _mini('Active Accounts', '${_accounts.length}', const Color(0xFF10B981)),
                const SizedBox(width: 14),
                _mini('Inter-Account Transfers', '${_transfers.length}', const Color(0xFF7C3AED)),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
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
