import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ExpensesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ExpensesScreen({super.key, required this.settings});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getExpenses();
    if (mounted) {
      setState(() {
        _expenses = list;
        _loading = false;
      });
    }
  }

  void _openAddExpense() {
    final catCtrl = TextEditingController(text: 'Store Rent');
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController(text: 'EXP-${DateTime.now().millisecondsSinceEpoch % 10000}');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Store Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Expense Category *', isDense: true),
                initialValue: catCtrl.text,
                items: ['Store Rent', 'Utilities & Power', 'Staff Refreshments', 'Salaries', 'Supplies', 'Marketing', 'Maintenance']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => catCtrl.text = val ?? 'Store Rent',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Expense Amount *', prefixText: '\$ ', isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference Number', isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note / Description', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amount <= 0) return;
              final db = await DatabaseService.initialize();
              final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
              await db.addExpense(Expense(
                category: catCtrl.text,
                amount: amount,
                refNo: refCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                date: now,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save Expense'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalExpenses = _expenses.fold(0.0, (sum, e) => sum + e.amount);

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
                      'Store Expenses',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track operational store costs, rent, electricity bills, and petty expenses.',
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
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _openAddExpense,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _mini('Total Recorded Expenses', '$currency${totalExpenses.toStringAsFixed(2)}', const Color(0xFFEF4444)),
                const SizedBox(width: 14),
                _mini('Expense Entries', '${_expenses.length} records', const Color(0xFF004EEB)),
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
                  : _expenses.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No expense records logged yet.', style: TextStyle(color: Colors.grey))),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('REF NO')),
                              DataColumn(label: Text('CATEGORY')),
                              DataColumn(label: Text('AMOUNT')),
                              DataColumn(label: Text('NOTE')),
                            ],
                            rows: _expenses.map((e) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(e.date, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                  DataCell(Text(e.refNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: Text(e.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    ),
                                  ),
                                  DataCell(Text('$currency${e.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)))),
                                  DataCell(Text(e.note.isNotEmpty ? e.note : '-', style: const TextStyle(fontSize: 12))),
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
