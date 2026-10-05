import 'package:flutter/material.dart';
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
                      'Manage supplier distributors, wholesale vendors, contact info, and payables.',
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
                                ],
                              );
                            }).toList(),
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
