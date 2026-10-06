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

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
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
        builder: (ctx, setDlgState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Receive Due Payment',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Customer: ${customer.name}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                // Outstanding Due Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Outstanding Balance Due:',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF991B1B), fontSize: 13),
                      ),
                      Text(
                        '${widget.settings.currencySymbol}${customer.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                _fieldLabel('Payment Amount (${widget.settings.currencySymbol}) *'),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '${widget.settings.currencySymbol} ',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Method
                _fieldLabel('Payment Method *'),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card / POS Terminal')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
                ),
                const SizedBox(height: 14),

                // Note
                _fieldLabel('Payment Reference / Note'),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Receipt # or Online Txn ID',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      },
                      child: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Ledger: ${customer.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Complete transaction history, sales orders, and balance settlement',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                    splashRadius: 18,
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),

              // Summary Stats Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Credit Limit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('${widget.settings.currencySymbol}${customer.creditLimit.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        const Text('Total Invoices', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('${allSales.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        const Text('Current Balance Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
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
              const SizedBox(height: 16),

              const Text('Invoices & Payment Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 8),

              SizedBox(
                height: 280,
                child: (allSales.isEmpty && payments.isEmpty)
                    ? const Center(child: Text('No transaction records found for this customer.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView(
                        children: [
                          ...allSales.map((s) => ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.shopping_cart_checkout, color: Color(0xFF4F46E5), size: 16),
                                ),
                                title: Text('${s.invoiceNo} (${s.paymentStatus.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(s.createdAt, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${widget.settings.currencySymbol}${s.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (s.dueAmount > 0)
                                      Text('Due: ${widget.settings.currencySymbol}${s.dueAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              )),
                          ...payments.map((p) => ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                                ),
                                title: Text('Payment: ${p.refNo} (${p.paymentMethod.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${p.date} ${p.note.isNotEmpty ? "- ${p.note}" : ""}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: Text(
                                  '- ${widget.settings.currencySymbol}${p.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13),
                                ),
                              )),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
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
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddCustomer,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Customers', '${_customers.length}', const Color(0xFF4F46E5)),
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
                                            backgroundColor: const Color(0xFFEEF2FF),
                                            child: Text(
                                              c.name.isNotEmpty ? c.name[0] : 'C',
                                              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
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
                                                backgroundColor: const Color(0xFF059669),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                              foregroundColor: const Color(0xFF4F46E5),
                                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
