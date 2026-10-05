import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SuppliersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const SuppliersScreen({super.key, required this.settings});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Contact> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getContacts(type: 'supplier');
    if (mounted) {
      setState(() {
        _suppliers = list;
        _loading = false;
      });
    }
  }

  void _openAddSupplier() {
    final nameCtrl = TextEditingController();
    final bizCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Supplier / Vendor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Contact Person *', isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: bizCtrl, decoration: const InputDecoration(labelText: 'Company / Business Name *', isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseService.initialize();
              await db.addContact(Contact(
                type: 'supplier',
                name: nameCtrl.text.trim(),
                businessName: bizCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                address: addrCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Supplier'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPaySupplierDialog(Contact supplier) async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextPaymentRef();
    final amountCtrl = TextEditingController(text: supplier.balance.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    String paymentMethod = 'bank_transfer';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.outbox, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text('Pay Supplier: ${supplier.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Current Outstanding Payable:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                      Text(
                        '${widget.settings.currencySymbol}${supplier.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1D4ED8)),
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
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash Payout')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Transfer Reference / Check No', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                final payment = ContactPayment(
                  contactId: supplier.id!,
                  contactName: supplier.name,
                  paymentType: 'pay',
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
                      content: Text('Payment of ${widget.settings.currencySymbol}${amount.toStringAsFixed(2)} to ${supplier.name} recorded!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Record Payout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupplierLedgerDialog(Contact supplier) async {
    final db = await DatabaseService.initialize();
    final allPurchases = await db.getPurchases();
    final supplierPurchases = allPurchases.where((p) => p.supplierId == supplier.id || p.supplierName == supplier.name).toList();
    final payments = await db.getContactPayments(supplier.id!);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF004EEB)),
            const SizedBox(width: 8),
            Text('Supplier Ledger: ${supplier.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        const Text('Total Purchase Orders', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('${supplierPurchases.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Current Balance Payable', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text(
                          '${widget.settings.currencySymbol}${supplier.balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: supplier.balance > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text('Purchases & Outgoing Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 6),

              Expanded(
                child: (supplierPurchases.isEmpty && payments.isEmpty)
                    ? const Center(child: Text('No transaction records found for this supplier.'))
                    : ListView(
                        children: [
                          ...supplierPurchases.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.local_shipping, color: Color(0xFF004EEB), size: 20),
                                title: Text('${p.refNo} (${p.status.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${p.createdAt} - Location: ${p.locationName}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${widget.settings.currencySymbol}${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (p.dueAmount > 0)
                                      Text('Due: ${widget.settings.currencySymbol}${p.dueAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              )),
                          ...payments.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                title: Text('Payout: ${p.refNo} (${p.paymentMethod.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final totalPayable = _suppliers.fold(0.0, (sum, s) => sum + s.balance);

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
                      'Suppliers & Vendors',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage manufacturers, product distributors, vendor invoices, and outstanding payables.',
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
                  icon: const Icon(Icons.factory, size: 20),
                  label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddSupplier,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Suppliers', '${_suppliers.length}', const Color(0xFF004EEB)),
                const SizedBox(width: 14),
                _mini('Total Payables Due', '$currency${totalPayable.toStringAsFixed(2)}', const Color(0xFFEF4444)),
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
                  : _suppliers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No suppliers recorded yet.', style: TextStyle(color: Colors.grey))),
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
                                DataColumn(label: Text('SUPPLIER')),
                                DataColumn(label: Text('BUSINESS / COMPANY')),
                                DataColumn(label: Text('PHONE')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('ADDRESS')),
                                DataColumn(label: Text('BALANCE PAYABLE')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: _suppliers.map((s) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(0xFFF3E8FF),
                                            child: Text(
                                              s.name.isNotEmpty ? s.name[0] : 'S',
                                              style: const TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(s.businessName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(s.phone.isNotEmpty ? s.phone : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(s.email.isNotEmpty ? s.email : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(s.address.isNotEmpty ? s.address : '-', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(
                                      s.balance > 0 ? '$currency${s.balance.toStringAsFixed(2)}' : '$currency 0.00',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: s.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        children: [
                                          if (s.balance > 0) ...[
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.outbox, size: 14),
                                              label: const Text('Pay Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () => _openPaySupplierDialog(s),
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
                                            onPressed: () => _openSupplierLedgerDialog(s),
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
