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

  void _openAddSupplier() {
    final nameCtrl = TextEditingController();
    final bizCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.factory_rounded, color: Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Supplier / Vendor',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Register vendor for procurement and purchase orders',
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

              _fieldLabel('Supplier Contact Person *'),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Michael Smith',
                  prefixIcon: Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              _fieldLabel('Company / Business Name *'),
              TextField(
                controller: bizCtrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Apex Wholesalers Ltd',
                  prefixIcon: Icon(Icons.business_outlined, size: 18, color: Color(0xFF64748B)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Phone Number'),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: '+1 (555) 000-0000',
                            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Email Address'),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'vendor@domain.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _fieldLabel('Physical Address / Warehouse'),
              TextField(
                controller: addrCtrl,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Street address, City',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
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
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
                    child: const Text('Save Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.outbox_rounded, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pay Supplier / Vendor',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Supplier: ${supplier.name}',
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

                // Outstanding Payable Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Outstanding Payable Due:',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E40AF), fontSize: 13),
                      ),
                      Text(
                        '${widget.settings.currencySymbol}${supplier.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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

                _fieldLabel('Payment Method *'),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'cash', child: Text('Cash Payout')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
                ),
                const SizedBox(height: 14),

                _fieldLabel('Transfer Reference / Check No'),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Bank Ref # or Cheque #',
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
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
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
                      child: const Text('Record Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

  Future<void> _openSupplierLedgerDialog(Contact supplier) async {
    final db = await DatabaseService.initialize();
    final allPurchases = await db.getPurchases();
    final supplierPurchases = allPurchases.where((p) => p.supplierId == supplier.id || p.supplierName == supplier.name).toList();
    final payments = await db.getContactPayments(supplier.id!);

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
                            'Supplier Ledger: ${supplier.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Complete procurement purchase history and outgoing payment vouchers',
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

              // Stats
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
                        const Text('Total Purchase Orders', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('${supplierPurchases.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Container(height: 30, width: 1, color: const Color(0xFFE2E8F0)),
                    Column(
                      children: [
                        const Text('Current Balance Payable', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
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
              const SizedBox(height: 16),

              const Text('Purchases & Outgoing Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(height: 8),

              SizedBox(
                height: 280,
                child: (supplierPurchases.isEmpty && payments.isEmpty)
                    ? const Center(child: Text('No transaction records found for this supplier.', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView(
                        children: [
                          ...supplierPurchases.map((p) => ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF4F46E5), size: 16),
                                ),
                                title: Text('${p.refNo} (${p.status.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${p.createdAt} - Location: ${p.locationName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${widget.settings.currencySymbol}${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (p.dueAmount > 0)
                                      Text('Due: ${widget.settings.currencySymbol}${p.dueAmount.toStringAsFixed(2)}',
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
                                title: Text('Payout: ${p.refNo} (${p.paymentMethod.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.factory_rounded, size: 20),
                  label: const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddSupplier,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Suppliers', '${_suppliers.length}', const Color(0xFF4F46E5)),
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
                                            backgroundColor: const Color(0xFFEEF2FF),
                                            child: Text(
                                              s.name.isNotEmpty ? s.name[0] : 'S',
                                              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
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
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                              foregroundColor: const Color(0xFF4F46E5),
                                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
