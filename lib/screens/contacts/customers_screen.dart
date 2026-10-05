import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../pos/quick_customer_dialog.dart';

class CustomersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const CustomersScreen({super.key, required this.settings});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Contact> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getContacts(type: 'customer');
    if (mounted) {
      setState(() {
        _customers = list;
        _loading = false;
      });
    }
  }

  void _openAddCustomer() {
    showDialog(
      context: context,
      builder: (_) => QuickCustomerDialog(
        onCustomerAdded: (_) => _load(),
      ),
    );
  }

  Future<void> _openPayDueDialog(Contact customer) async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextPaymentRef();
    final amountCtrl = TextEditingController(text: customer.balance.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    String paymentMethod = 'cash';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('Receive Due Payment: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Current Outstanding Due:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                      Text(
                        '${widget.settings.currencySymbol}${customer.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (${widget.settings.currencySymbol})*',
                    isDense: true,
                    prefixText: '${widget.settings.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method*', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card / POS Terminal')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Payment Reference / Note', hintText: 'e.g. Receipt # or Online Txn ID', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                final payment = ContactPayment(
                  contactId: customer.id!,
                  contactName: customer.name,
                  paymentType: 'receive',
                  amount: amount,
                  paymentMethod: paymentMethod,
                  date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                  refNo: nextRef,
                  note: noteCtrl.text.trim(),
                );

                await db.addContactPayment(payment);
                Navigator.pop(ctx);
                _load();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Received ${widget.settings.currencySymbol}${amount.toStringAsFixed(2)} from ${customer.name}! Balance updated.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLedgerDialog(Contact customer) async {
    final db = await DatabaseService.initialize();
    final allSales = await db.getSales(search: customer.name);
    final payments = await db.getContactPayments(customer.id!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF004EEB)),
            const SizedBox(width: 8),
            Text('Account Ledger: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Credit Limit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('${widget.settings.currencySymbol}${customer.creditLimit.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Total Invoices', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('${allSales.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Current Balance Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '${widget.settings.currencySymbol}${customer.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: customer.balance > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text('Invoices & Payment Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),

              Expanded(
                child: (allSales.isEmpty && payments.isEmpty)
                    ? const Center(child: Text('No transaction records found for this customer.'))
                    : ListView(
                        children: [
                          ...allSales.map((s) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.shopping_cart_checkout, color: Color(0xFF004EEB), size: 20),
                                title: Text('${s.invoiceNo} (${s.paymentStatus.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(s.createdAt),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${widget.settings.currencySymbol}${s.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (s.dueAmount > 0)
                                      Text('Due: ${widget.settings.currencySymbol}${s.dueAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              )),
                          ...payments.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                title: Text('Payment: ${p.refNo} (${p.paymentMethod.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${p.date} ${p.note.isNotEmpty ? "- ${p.note}" : ""}'),
                                trailing: Text(
                                  '- ${widget.settings.currencySymbol}${p.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                                ),
                              )),
                        ],
                      ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalReceivable = _customers.fold(0.0, (sum, c) => sum + c.balance);

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
                      'Customers Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage retail customers, wholesale client accounts, balances, and credit limits.',
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
                  icon: const Icon(Icons.person_add, size: 20),
                  label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddCustomer,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Customers', '${_customers.length}', const Color(0xFF004EEB)),
                const SizedBox(width: 14),
                _mini('Total Receivables Due', '$currency${totalReceivable.toStringAsFixed(2)}', const Color(0xFFEF4444)),
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
                  : _customers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No customers registered yet.', style: TextStyle(color: Colors.grey))),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(label: Text('CUSTOMER NAME')),
                                DataColumn(label: Text('BUSINESS')),
                                DataColumn(label: Text('PHONE')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('ADDRESS')),
                                DataColumn(label: Text('CREDIT LIMIT')),
                                DataColumn(label: Text('CURRENT DUE')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: _customers.map((c) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(0xFFEFF6FF),
                                            child: Text(
                                              c.name.isNotEmpty ? c.name[0] : 'C',
                                              style: const TextStyle(color: Color(0xFF004EEB), fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(c.businessName?.isNotEmpty == true ? c.businessName! : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(c.phone.isNotEmpty ? c.phone : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(c.email.isNotEmpty ? c.email : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(c.address.isNotEmpty ? c.address : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text('$currency${c.creditLimit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(
                                      c.balance > 0 ? '$currency${c.balance.toStringAsFixed(2)}' : '$currency 0.00',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: c.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        children: [
                                          if (c.balance > 0) ...[
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.attach_money, size: 14),
                                              label: const Text('Pay Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () => _openPayDueDialog(c),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF004EEB),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 14),
                                            label: const Text('Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            onPressed: () => _openLedgerDialog(c),
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
