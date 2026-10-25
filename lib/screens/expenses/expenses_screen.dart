import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'add_expense_dialog.dart';

class ExpensesScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ExpensesScreen({super.key, required this.settings});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;
  String _searchQuery = '';

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
    showDialog(
      context: context,
      builder: (ctx) => AddExpenseDialog(
        settings: widget.settings,
        onExpenseAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalExpenses = _expenses.fold(0.0, (sum, e) => sum + e.amount);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filtered = _expenses.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.refNo.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Expenses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track operational store costs, rent, electricity bills, and petty expenses.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: _openAddExpense,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Stat Cards
            Row(
              children: [
                _statPill(
                  label: 'Total Logged Expenses',
                  value: '$currency${totalExpenses.toStringAsFixed(2)}',
                  color: const Color(0xFFDC2626),
                  icon: Icons.receipt_long_rounded,
                  iconBg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                ),
                const SizedBox(width: 14),
                _statPill(
                  label: 'Expense Records',
                  value: '${_expenses.length} entries',
                  color: const Color(0xFF4F46E5),
                  icon: Icons.format_list_bulleted_rounded,
                  iconBg: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar & Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search by Ref No, category or note...',
                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 9),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${filtered.length} Results',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Data Table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                          )
                        : filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text('No expense records found matching criteria.', style: TextStyle(color: textSecondary)),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      fontSize: 12,
                                    ),
                                    dataRowMinHeight: 52,
                                    dataRowMaxHeight: 56,
                                    columns: const [
                                      DataColumn(label: Text('DATE')),
                                      DataColumn(label: Text('REF NO')),
                                      DataColumn(label: Text('CATEGORY')),
                                      DataColumn(label: Text('AMOUNT')),
                                      DataColumn(label: Text('NOTE')),
                                    ],
                                    rows: filtered.map((e) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(e.date, style: TextStyle(fontSize: 12, color: textSecondary))),
                                          DataCell(
                                            Text(
                                              e.refNo,
                                              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                e.category,
                                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '$currency${e.amount.toStringAsFixed(2)}',
                                              style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                            ),
                                          ),
                                          DataCell(Text(e.note.isNotEmpty ? e.note : '-', style: TextStyle(fontSize: 12, color: textPrimary))),
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
          ],
        ),
      ),
    );
  }

  Widget _statPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required Color iconBg,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textSecondary,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
