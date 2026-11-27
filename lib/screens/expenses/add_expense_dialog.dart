import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/searchable_select_dialog.dart';
import 'add_expense_screen.dart';

class AddExpenseDialog extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onExpenseAdded;

  const AddExpenseDialog({
    super.key,
    required this.settings,
    this.onExpenseAdded,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _paymentToCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _paidCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String _selectedCategory = 'Store Rent';
  String _paymentMethod = 'Cash';
  bool _isSaving = false;
  bool _paidEditedManually = false;

  final List<String> _categories = [
    'Store Rent',
    'Electricity & Utilities',
    'Salaries & Wages',
    'Staff Meal & Refreshments',
    'Delivery & Courier',
    'Packaging & Bags',
    'Medical Waste Disposal',
    'Store Maintenance',
    'Office Supplies & Stationery',
    'Rent',
    'Miscellaneous Expense',
  ];

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Card / POS',
    'Cheque',
  ];

  @override
  void initState() {
    super.initState();
    _refCtrl.text = 'EXP-${DateTime.now().millisecondsSinceEpoch % 100000}';
    _loadSavedCategories();
  }

  Future<void> _loadSavedCategories() async {
    try {
      final db = await DatabaseService.initialize();
      final saved = await db.getExpenseCategories();
      if (mounted) {
        setState(() {
          for (final c in saved) {
            if (!_categories.contains(c)) _categories.add(c);
          }
          _categories.sort();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _paymentToCtrl.dispose();
    _amountCtrl.dispose();
    _paidCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptAddCategory() async {
    final ctrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(PosLocalization.tr('Add Expense Category',
            settings: widget.settings)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                  PosLocalization.tr('Cancel', settings: widget.settings))),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: Text(PosLocalization.tr('Add', settings: widget.settings)),
          ),
        ],
      ),
    );
    if (added != null && mounted) {
      final db = await DatabaseService.initialize();
      await db.addExpenseCategory(added);
      if (mounted) {
        setState(() {
          if (!_categories.contains(added)) {
            _categories.add(added);
            _categories.sort();
          }
          _selectedCategory = added;
        });
      }
    }
  }

  Future<void> _openFullForm() async {
    final nav = Navigator.of(context);
    nav.pop();
    final res = await nav.push<dynamic>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(settings: widget.settings),
      ),
    );
    if (res != null) {
      widget.onExpenseAdded?.call();
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PosLocalization.tr(
                'Please enter a valid expense amount greater than 0')),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final paid =
        (double.tryParse(_paidCtrl.text.trim()) ?? amount).clamp(0.0, amount);

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final cur = '${widget.settings.currencySymbol} ';

      await db.addExpense(
        Expense(
          title: _titleCtrl.text.trim(),
          paymentTo: _paymentToCtrl.text.trim(),
          category: _selectedCategory,
          amount: amount,
          paidAmount: paid,
          refNo: _refCtrl.text.trim().isNotEmpty
              ? _refCtrl.text.trim()
              : 'EXP-${DateTime.now().millisecondsSinceEpoch % 100000}',
          note: _noteCtrl.text.trim(),
          date: now,
          paymentMethod: _paymentMethod.toLowerCase(),
        ),
        accountName:
            _paymentMethod == 'Cash' ? 'Cash Register' : _paymentMethod,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Expense of ${CurrencyFormatter.exact(amount, currency: cur)} ($_selectedCategory) recorded successfully!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onExpenseAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to record expense: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = '${widget.settings.currencySymbol} ';

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final total = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidCtrl.text.trim()) ?? 0.0;
    final due = (total - paid) > 0 ? (total - paid) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black54 : const Color(0x1F000000),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF450A0A)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF7F1D1D)
                                  : const Color(0xFFFECACA)),
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: Color(0xFFDC2626), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PosLocalization.tr('Add Quick Expense'),
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              PosLocalization.tr(
                                  'Quick entry or switch to Full Form for recurring & tax'),
                              style: TextStyle(
                                  fontSize: 11.5, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openFullForm,
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Full Form',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 20, color: textSecondary),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),

                // Dialog Body Form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              label: 'Expense Title',
                              ctrl: _titleCtrl,
                              hint: 'e.g. Tea, Rent, Bill',
                              isDark: isDark,
                              inputBg: inputBg,
                              inputBorder: inputBorder,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _textField(
                              label: 'Payment To',
                              ctrl: _paymentToCtrl,
                              hint: 'e.g. Owner / Vendor',
                              isDark: isDark,
                              inputBg: inputBg,
                              inputBorder: inputBorder,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      SearchableDropdownField<String>(
                        label: 'Expense Category',
                        isRequired: true,
                        selectedItem: _selectedCategory,
                        items: _categories,
                        labelBuilder: (c) => c,
                        placeholder: 'Select Category',
                        searchHint: 'Search expense category...',
                        prefixIcon: Icons.category_outlined,
                        onAdd: _promptAddCategory,
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Amount, Paid Now & Payment Method Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(PosLocalization.tr('Total Amount *'),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  onChanged: (val) {
                                    if (!_paidEditedManually) {
                                      _paidCtrl.text = val;
                                    }
                                    setState(() {});
                                  },
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary),
                                  decoration: _deco(
                                    inputBg: inputBg,
                                    inputBorder: inputBorder,
                                    hint: '0.00',
                                    prefixText: cur,
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
                                Text(PosLocalization.tr('Paid Now'),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _paidCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  onChanged: (_) {
                                    _paidEditedManually = true;
                                    setState(() {});
                                  },
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary),
                                  decoration: _deco(
                                    inputBg: inputBg,
                                    inputBorder: inputBorder,
                                    hint: '0.00',
                                    prefixText: cur,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SearchableDropdownField<String>(
                              label: 'Payment Method',
                              selectedItem: _paymentMethod,
                              items: _paymentMethods,
                              labelBuilder: (m) => m,
                              placeholder: 'Cash',
                              searchHint: 'Search method...',
                              prefixIcon: Icons.payments_outlined,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _paymentMethod = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (due > 0) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Payment Due: ${CurrencyFormatter.exact(due, currency: cur)}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      _textField(
                        label: 'Reference / Voucher No.',
                        ctrl: _refCtrl,
                        hint: 'EXP-1001',
                        isDark: isDark,
                        inputBg: inputBg,
                        inputBorder: inputBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 14),

                      _textField(
                        label: 'Note / Remarks',
                        ctrl: _noteCtrl,
                        hint:
                            'Enter expense details (e.g. Paid for tea & snacks)...',
                        maxLines: 2,
                        isDark: isDark,
                        inputBg: inputBg,
                        inputBorder: inputBorder,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  decoration: BoxDecoration(
                    color: headerBg,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: Text(PosLocalization.tr('Cancel'),
                            style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSaving ? null : _saveExpense,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          _isSaving
                              ? PosLocalization.tr('Saving...')
                              : PosLocalization.tr('Save Expense'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
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

  Widget _textField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required Color textPrimary,
    required Color textSecondary,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PosLocalization.tr(label),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration:
              _deco(inputBg: inputBg, inputBorder: inputBorder, hint: hint),
        ),
      ],
    );
  }

  InputDecoration _deco({
    required Color inputBg,
    required Color inputBorder,
    String? hint,
    String? prefixText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: inputBg,
      hintText: hint,
      prefixText: prefixText,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: inputBorder),
      ),
    );
  }
}
