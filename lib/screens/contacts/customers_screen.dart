import 'package:flutter/material.dart';
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
