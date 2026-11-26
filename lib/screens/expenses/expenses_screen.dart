import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p_path;
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../utils/currency_formatter.dart';
import 'add_expense_screen.dart';

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
  String _statusFilter = 'all'; // 'all', 'paid', 'partial', 'due'

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

  Future<void> _openAddExpense([Expense? expenseToEdit]) async {
    final perm = expenseToEdit == null ? 'expense.add' : 'expense.edit';
    if (!(AuthService.currentUser?.hasPermission(perm) ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PosLocalization.tr(
              'Access Denied: You do not have permission for this action.')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }
    final res = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          settings: widget.settings,
          expenseToEdit: expenseToEdit,
        ),
      ),
    );
    if (res != null && mounted) {
      await _load();
    }
  }

  Future<void> _confirmDelete(Expense e) async {
    if (e.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(PosLocalization.tr('Delete Expense?')),
        content: Text(
            'Are you sure you want to delete "${e.title.isNotEmpty ? e.title : e.category}" (${e.refNo})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(PosLocalization.tr('Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(PosLocalization.tr('Delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      final db = await DatabaseService.initialize();
      await db.deleteExpense(e.id!);
      await _load();
    }
  }

  Future<void> _showAddPaymentDialog(Expense e) async {
    if (e.id == null || e.dueAmount <= 0) return;
    final cur = '${widget.settings.currencySymbol} ';
    final amountCtrl =
        TextEditingController(text: e.dueAmount.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    String method = 'Cash';
    DateTime paidOn = DateTime.now();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Add Payment • ${e.refNo}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remaining Due: ${CurrencyFormatter.exact(e.dueAmount, currency: cur)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: cur,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const ['Cash', 'Bank Transfer', 'Card / POS', 'Cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => method = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Payment Note',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(PosLocalization.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt <= 0 || amt > e.dueAmount + 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid payment amount.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      setDlgState(() => saving = true);
                      final db = await DatabaseService.initialize();
                      await db.recordExpensePayment(
                        expenseId: e.id!,
                        amount: amt,
                        paymentMethod: method.toLowerCase(),
                        paidOn:
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(paidOn),
                        note: noteCtrl.text.trim(),
                        accountName:
                            method == 'Cash' ? 'Cash Register' : method,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white),
              child: Text(PosLocalization.tr('Save Payment')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseDetails(Expense e) async {
    final db = await DatabaseService.initialize();
    final payments = e.id != null
        ? await db.getExpensePayments(e.id!)
        : <Map<String, dynamic>>[];
    final cur = '${widget.settings.currencySymbol} ';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Expense Details • ${e.refNo}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.title.isNotEmpty) _detailRow('Title', e.title),
                _detailRow(
                    'Category',
                    e.subCategory.isNotEmpty
                        ? '${e.category} • ${e.subCategory}'
                        : e.category),
                _detailRow('Date', e.date),
                if (e.paymentTo.isNotEmpty)
                  _detailRow('Payment To', e.paymentTo),
                if (e.expenseForUser.isNotEmpty)
                  _detailRow('Expense For (Staff)', e.expenseForUser),
                if (e.contactName.isNotEmpty)
                  _detailRow('Contact', e.contactName),
                if (e.taxName.isNotEmpty)
                  _detailRow('Tax', '${e.taxName} (${e.taxRate}%)'),
                _detailRow('Total Amount',
                    CurrencyFormatter.exact(e.amount, currency: cur)),
                _detailRow('Total Paid',
                    CurrencyFormatter.exact(e.paidAmount, currency: cur)),
                _detailRow('Payment Due',
                    CurrencyFormatter.exact(e.dueAmount, currency: cur)),
                _detailRow('Status', e.paymentStatus.toUpperCase()),
                if (e.isRefund) _detailRow('Refund', 'Yes'),
                if (e.isRecurring)
                  _detailRow('Recurring',
                      'Every ${e.recurringInterval} ${e.recurringUnit}'),
                if (e.documentPath.isNotEmpty)
                  _detailRow('Document', p_path.basename(e.documentPath)),
                if (e.note.isNotEmpty) _detailRow('Note', e.note),
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Payment History:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...payments.map((p) {
                    final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${p['transaction_date'] ?? ''} — ${CurrencyFormatter.exact(amt, currency: cur)} (${(p['payment_method'] ?? 'cash').toString().toUpperCase()})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(PosLocalization.tr('Close'))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = '${widget.settings.currencySymbol} ';
    final totalExpenses = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalPaid = _expenses.fold(0.0, (sum, e) => sum + e.paidAmount);
    final totalDue = _expenses.fold(0.0, (sum, e) => sum + e.dueAmount);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filtered = _expenses.where((e) {
      if (_statusFilter != 'all' && e.paymentStatus != _statusFilter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.refNo.toLowerCase().contains(q) ||
          e.title.toLowerCase().contains(q) ||
          e.paymentTo.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PosLocalization.tr('Store Expenses'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PosLocalization.tr(
                            'Track operational store costs, rent, electricity bills, and petty expenses.'),
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (AuthService.currentUser?.hasPermission('expense.add') ??
                    true)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(PosLocalization.tr('Add Expense'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _openAddExpense(),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Stat Cards
            Row(
              children: [
                _statPill(
                  label: 'Total Logged Expenses',
                  value: CurrencyFormatter.exact(totalExpenses, currency: cur),
                  color: const Color(0xFFDC2626),
                  icon: Icons.receipt_long_rounded,
                  iconBg: isDark
                      ? const Color(0xFF450A0A)
                      : const Color(0xFFFEF2F2),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                ),
                const SizedBox(width: 14),
                _statPill(
                  label: 'Total Paid',
                  value: CurrencyFormatter.exact(totalPaid, currency: cur),
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_circle_outline_rounded,
                  iconBg: isDark
                      ? const Color(0xFF052E16)
                      : const Color(0xFFF0FDF4),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textSecondary: textSecondary,
                ),
                const SizedBox(width: 14),
                _statPill(
                  label: 'Payment Due',
                  value: CurrencyFormatter.exact(totalDue, currency: cur),
                  color: const Color(0xFFD97706),
                  icon: Icons.pending_actions_rounded,
                  iconBg: isDark
                      ? const Color(0xFF451A03)
                      : const Color(0xFFFFFBEB),
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
                  iconBg: isDark
                      ? const Color(0xFF1E1B4B)
                      : const Color(0xFFEEF2FF),
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
                            onChanged: (val) =>
                                setState(() => _searchQuery = val.trim()),
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: PosLocalization.tr(
                                  'Search by Ref No, title, category, payment to or note...'),
                              hintStyle: const TextStyle(
                                  fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search,
                                  size: 17, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 9),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('Payment: All')),
                              DropdownMenuItem(
                                  value: 'paid', child: Text('Paid')),
                              DropdownMenuItem(
                                  value: 'partial', child: Text('Partial')),
                              DropdownMenuItem(
                                  value: 'due', child: Text('Due')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _statusFilter = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textSecondary),
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
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF4F46E5))),
                          )
                        : filtered.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                      PosLocalization.tr(
                                          'No expense records found matching criteria.'),
                                      style: TextStyle(color: textSecondary)),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth:
                                          MediaQuery.of(context).size.width -
                                              340,
                                    ),
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                          isDark
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFFF8FAFC)),
                                      headingTextStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF475569),
                                        fontSize: 12,
                                      ),
                                      dataRowMinHeight: 52,
                                      dataRowMaxHeight: 60,
                                      columns: [
                                        const DataColumn(label: Text('DATE')),
                                        DataColumn(
                                            label: Text(
                                                PosLocalization.tr('REF NO'))),
                                        DataColumn(
                                            label: Text(PosLocalization.tr(
                                                'TITLE / CATEGORY'))),
                                        const DataColumn(
                                            label: Text('PAYMENT TO / FOR')),
                                        const DataColumn(
                                            label: Text('PAYMENT STATUS')),
                                        DataColumn(
                                            label: Text(PosLocalization.tr(
                                                'TOTAL AMOUNT'))),
                                        const DataColumn(
                                            label: Text('PAYMENT DUE')),
                                        const DataColumn(
                                            label: Text('ACTIONS')),
                                      ],
                                      rows: filtered.map((e) {
                                        final payee = e.paymentTo.isNotEmpty
                                            ? e.paymentTo
                                            : (e.contactName.isNotEmpty
                                                ? e.contactName
                                                : (e.expenseForUser.isNotEmpty
                                                    ? e.expenseForUser
                                                    : '-'));
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(e.date,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: textSecondary))),
                                            DataCell(
                                              Text(
                                                e.refNo,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFA5B4FC)
                                                        : const Color(
                                                            0xFF4F46E5)),
                                              ),
                                            ),
                                            DataCell(
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (e.title.isNotEmpty)
                                                    Text(e.title,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12.5,
                                                            color:
                                                                textPrimary)),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF334155)
                                                          : const Color(
                                                              0xFFF1F5F9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                    ),
                                                    child: Text(
                                                      e.subCategory.isNotEmpty
                                                          ? '${e.category} • ${e.subCategory}'
                                                          : e.category,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFFE2E8F0)
                                                              : const Color(
                                                                  0xFF334155)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(payee,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: textPrimary))),
                                            DataCell(
                                                _statusBadge(e.paymentStatus)),
                                            DataCell(
                                              Text(
                                                CurrencyFormatter.exact(
                                                    e.amount,
                                                    currency: cur),
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFF87171)
                                                        : const Color(
                                                            0xFFDC2626)),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                e.dueAmount > 0
                                                    ? CurrencyFormatter.exact(
                                                        e.dueAmount,
                                                        currency: cur)
                                                    : '-',
                                                style: TextStyle(
                                                  fontWeight: e.dueAmount > 0
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                  color: e.dueAmount > 0
                                                      ? const Color(0xFFDC2626)
                                                      : textSecondary,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                                _buildActionsMenu(e, isDark)),
                                          ],
                                        );
                                      }).toList(),
                                    ),
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

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'partial':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      default:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildActionsMenu(Expense e, bool isDark) {
    return PopupMenuButton<String>(
      tooltip: PosLocalization.tr('Actions'),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (action) {
        switch (action) {
          case 'view':
            _showExpenseDetails(e);
            break;
          case 'edit':
            _openAddExpense(e);
            break;
          case 'pay':
            _showAddPaymentDialog(e);
            break;
          case 'delete':
            _confirmDelete(e);
            break;
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Edit Expense'),
            ],
          ),
        ),
        if (e.dueAmount > 0)
          const PopupMenuItem(
            value: 'pay',
            child: Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Text('Add Payment',
                    style: TextStyle(
                        color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF0284C7).withValues(alpha: 0.65),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PosLocalization.tr('Actions'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: Color(0xFF0284C7),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PosLocalization.tr(label),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
