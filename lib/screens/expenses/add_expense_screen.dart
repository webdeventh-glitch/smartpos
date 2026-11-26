import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p_path;
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../services/regional_data_service.dart';
import '../../utils/currency_formatter.dart';

/// Full-page UltimatePOS-style Add / Edit Expense screen.
class AddExpenseScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Expense? expenseToEdit;

  const AddExpenseScreen({
    super.key,
    required this.settings,
    this.expenseToEdit,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _paymentToCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final _recurringIntervalCtrl = TextEditingController(text: '1');
  final _recurringRepCtrl = TextEditingController();

  final _payAmountCtrl = TextEditingController(text: '0.00');
  final _payNoteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _pickingDoc = false;

  int _locationId = 1;
  List<BusinessLocation> _locations = [];
  List<User> _users = [];
  List<Contact> _contacts = [];
  List<TaxRate> _taxRates = [];

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

  String _selectedCategory = 'Store Rent';
  String _expenseForUser = '';
  int? _selectedContactId;
  String _selectedContactName = '';
  String _selectedTaxName = 'None';
  double _selectedTaxRate = 0.0;
  String _documentPath = '';
  bool _isRefund = false;
  bool _isRecurring = false;
  String _recurringUnit = 'Days';
  String _paymentMethod = 'Cash';

  late DateTime _expenseDate;
  late DateTime _paidOnDate;

  bool get _isEdit => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    _expenseDate = e != null
        ? (DateTime.tryParse(e.date) ?? DateTime.now())
        : DateTime.now();
    _paidOnDate = DateTime.now();

    if (e != null) {
      _locationId = e.locationId;
      _titleCtrl.text = e.title;
      _paymentToCtrl.text = e.paymentTo;
      _refCtrl.text = e.refNo;
      if (e.category.isNotEmpty && !_categories.contains(e.category)) {
        _categories.insert(0, e.category);
      }
      _selectedCategory =
          e.category.isNotEmpty ? e.category : _categories.first;
      _subCategoryCtrl.text = e.subCategory;
      _totalAmountCtrl.text = e.amount.toStringAsFixed(2);
      _noteCtrl.text = e.note;
      _expenseForUser = e.expenseForUser;
      _selectedContactId = e.contactId;
      _selectedContactName = e.contactName;
      _selectedTaxRate = e.taxRate;
      _selectedTaxName = e.taxName.isNotEmpty ? e.taxName : 'None';
      _documentPath = e.documentPath;
      _isRefund = e.isRefund;
      _isRecurring = e.isRecurring;
      _recurringIntervalCtrl.text =
          e.recurringInterval > 0 ? '${e.recurringInterval}' : '1';
      _recurringUnit = e.recurringUnit.isNotEmpty ? e.recurringUnit : 'Days';
      _recurringRepCtrl.text =
          e.recurringRepetitions != null ? '${e.recurringRepetitions}' : '';
      _payAmountCtrl.text = e.paidAmount.toStringAsFixed(2);
      _paymentMethod = _normalizeMethodLabel(e.paymentMethod);
    }

    _loadLookups();
  }

  String _normalizeMethodLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'bank':
      case 'bank transfer':
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
      case 'card / pos':
        return 'Card / POS';
      case 'cheque':
        return 'Cheque';
      default:
        return 'Cash';
    }
  }

  Future<void> _loadLookups() async {
    try {
      final db = await DatabaseService.initialize();
      final locs = await db.getBusinessLocations();
      final users = await db.getUsers();
      final contacts = await db.getContacts();
      final taxes = await db.getTaxRates();
      if (mounted) {
        setState(() {
          _locations = locs;
          if (_locations.isNotEmpty &&
              !_locations.any((l) => l.id == _locationId)) {
            _locationId = _locations.first.id ?? 1;
          }
          _users = users;
          _contacts = contacts;
          _taxRates = taxes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _paymentToCtrl.dispose();
    _refCtrl.dispose();
    _subCategoryCtrl.dispose();
    _totalAmountCtrl.dispose();
    _noteCtrl.dispose();
    _recurringIntervalCtrl.dispose();
    _recurringRepCtrl.dispose();
    _payAmountCtrl.dispose();
    _payNoteCtrl.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_totalAmountCtrl.text.trim()) ?? 0.0;

  double get _payAmount => double.tryParse(_payAmountCtrl.text.trim()) ?? 0.0;

  double get _paymentDue {
    final due = _totalAmount - _payAmount;
    return due > 0 ? due : 0.0;
  }

  Future<void> _pickDateTime({required bool isPaidOn}) async {
    final initial = isPaidOn ? _paidOnDate : _expenseDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final next = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime?.hour ?? initial.hour,
      pickedTime?.minute ?? initial.minute,
    );
    setState(() {
      if (isPaidOn) {
        _paidOnDate = next;
      } else {
        _expenseDate = next;
      }
    });
  }

  Future<void> _pickDocument() async {
    if (_pickingDoc) return;
    setState(() => _pickingDoc = true);
    try {
      final path = await NativeFileHelper.pickExpenseDocument();
      if (path != null && mounted) {
        setState(() => _documentPath = path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingDoc = false);
    }
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
      setState(() {
        if (!_categories.contains(added)) {
          _categories.add(added);
        }
        _selectedCategory = added;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final total = _totalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(PosLocalization.tr(
              'Please enter a valid expense amount greater than 0',
              settings: widget.settings)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final paid = _isEdit
        ? (widget.expenseToEdit!.paidAmount).clamp(0.0, total)
        : _payAmount.clamp(0.0, total);

    setState(() => _saving = true);
    try {
      final db = await DatabaseService.initialize();
      final ref = _refCtrl.text.trim().isNotEmpty
          ? _refCtrl.text.trim()
          : 'EXP-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_expenseDate);
      final paidOnStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(_paidOnDate);

      final exp = Expense(
        id: widget.expenseToEdit?.id,
        locationId: _locationId,
        title: _titleCtrl.text.trim(),
        paymentTo: _paymentToCtrl.text.trim(),
        category: _selectedCategory,
        subCategory: _subCategoryCtrl.text.trim(),
        amount: total,
        paidAmount: paid,
        refNo: ref,
        note: _noteCtrl.text.trim(),
        date: dateStr,
        paymentMethod: _paymentMethod.toLowerCase(),
        expenseForUser: _expenseForUser,
        contactId: _selectedContactId,
        contactName: _selectedContactName,
        taxRate: _selectedTaxRate,
        taxName: _selectedTaxName == 'None' ? '' : _selectedTaxName,
        documentPath: _documentPath,
        isRefund: _isRefund,
        isRecurring: _isRecurring,
        recurringInterval:
            _isRecurring ? (int.tryParse(_recurringIntervalCtrl.text) ?? 1) : 0,
        recurringUnit: _recurringUnit,
        recurringRepetitions:
            _isRecurring ? int.tryParse(_recurringRepCtrl.text.trim()) : null,
      );

      if (_isEdit) {
        await db.updateExpense(exp);
      } else {
        await db.addExpense(
          exp,
          paymentNote: _payNoteCtrl.text.trim(),
          accountName:
              _paymentMethod == 'Cash' ? 'Cash Register' : _paymentMethod,
        );
      }

      if (mounted) {
        Navigator.pop(context, paidOnStr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              _isEdit
                  ? 'Expense updated successfully!'
                  : 'Expense recorded (${CurrencyFormatter.exact(total, currency: '${widget.settings.currencySymbol} ')})!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cur = '${widget.settings.currencySymbol} ';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        foregroundColor: textPrimary,
        title: Text(
          PosLocalization.tr(
            _isEdit ? 'Edit Expense' : 'Add Expense',
            settings: widget.settings,
          ),
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 18, color: textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card 1: Main Expense Details
                        _card(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _gridRow([
                                _fieldBlock(
                                  'Business Location:*',
                                  DropdownButtonFormField<int>(
                                    initialValue: _locationId,
                                    isExpanded: true,
                                    decoration: _inputDeco(isDark),
                                    items: _locations.isEmpty
                                        ? [
                                            const DropdownMenuItem(
                                              value: 1,
                                              child: Text('Main Branch HQ'),
                                            )
                                          ]
                                        : _locations
                                            .map((l) => DropdownMenuItem<int>(
                                                  value: l.id ?? 1,
                                                  child: Text(l.name,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ))
                                            .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _locationId = v);
                                      }
                                    },
                                  ),
                                ),
                                _fieldBlock(
                                  'Expense Title:',
                                  TextFormField(
                                    controller: _titleCtrl,
                                    decoration: _inputDeco(isDark,
                                        hint: 'Expense Title (e.g. Rent)'),
                                  ),
                                ),
                                _fieldBlock(
                                  'Payment To:',
                                  TextFormField(
                                    controller: _paymentToCtrl,
                                    decoration: _inputDeco(isDark,
                                        hint: 'Payment To (e.g. Owner)'),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),
                              _gridRow([
                                _fieldBlock(
                                  'Expense Category:',
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedCategory,
                                          isExpanded: true,
                                          decoration: _inputDeco(isDark),
                                          items: _categories
                                              .map((c) => DropdownMenuItem(
                                                    value: c,
                                                    child: Text(c,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                  ))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) {
                                              setState(
                                                  () => _selectedCategory = v);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: 'Add Category',
                                        onPressed: _promptAddCategory,
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Color(0xFF4F46E5)),
                                      ),
                                    ],
                                  ),
                                ),
                                _fieldBlock(
                                  'Sub category:',
                                  TextFormField(
                                    controller: _subCategoryCtrl,
                                    decoration: _inputDeco(isDark,
                                        hint: 'None / Sub category'),
                                  ),
                                ),
                                _fieldBlock(
                                  'Reference No:',
                                  TextFormField(
                                    controller: _refCtrl,
                                    decoration: _inputDeco(isDark,
                                        hint: 'Leave empty to autogenerate'),
                                  ),
                                  helperText: 'Leave empty to autogenerate',
                                ),
                              ]),
                              const SizedBox(height: 16),
                              _gridRow([
                                _fieldBlock(
                                  'Date:*',
                                  InkWell(
                                    onTap: () => _pickDateTime(isPaidOn: false),
                                    child: InputDecorator(
                                      decoration: _inputDeco(isDark).copyWith(
                                        prefixIcon: const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 16),
                                      ),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(_expenseDate),
                                        style: TextStyle(
                                            fontSize: 13, color: textPrimary),
                                      ),
                                    ),
                                  ),
                                ),
                                _fieldBlock(
                                  'Expense for:',
                                  DropdownButtonFormField<String>(
                                    initialValue: _expenseForUser.isEmpty
                                        ? ''
                                        : (_users.any((u) =>
                                                u.name == _expenseForUser)
                                            ? _expenseForUser
                                            : ''),
                                    isExpanded: true,
                                    decoration: _inputDeco(isDark),
                                    items: [
                                      const DropdownMenuItem(
                                          value: '', child: Text('None')),
                                      ..._users.map((u) => DropdownMenuItem(
                                            value: u.name,
                                            child: Text(u.name,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _expenseForUser = v ?? ''),
                                  ),
                                ),
                                _fieldBlock(
                                  'Expense for contact:',
                                  DropdownButtonFormField<int?>(
                                    initialValue: _selectedContactId,
                                    isExpanded: true,
                                    decoration: _inputDeco(isDark),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('Please Select')),
                                      ..._contacts
                                          .map((c) => DropdownMenuItem<int?>(
                                                value: c.id,
                                                child: Text(
                                                  '${c.name} (${c.type})',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        _selectedContactId = v;
                                        _selectedContactName = v == null
                                            ? ''
                                            : (_contacts
                                                    .where((c) => c.id == v)
                                                    .map((c) => c.name)
                                                    .firstOrNull ??
                                                '');
                                      });
                                    },
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),
                              _gridRow([
                                _fieldBlock(
                                  'Attach Document:',
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 42,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          alignment: Alignment.centerLeft,
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: borderCol),
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                                    left: Radius.circular(6)),
                                          ),
                                          child: Text(
                                            _documentPath.isEmpty
                                                ? 'No file selected'
                                                : p_path
                                                    .basename(_documentPath),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed:
                                            _pickingDoc ? null : _pickDocument,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF0284C7),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(100, 42),
                                          shape: const RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.horizontal(
                                                    right: Radius.circular(6)),
                                          ),
                                        ),
                                        icon: const Icon(Icons.folder_open,
                                            size: 16),
                                        label: Text(
                                            _pickingDoc ? '...' : 'Browse..'),
                                      ),
                                      if (_documentPath.isNotEmpty)
                                        IconButton(
                                          tooltip: 'Remove Document',
                                          onPressed: () => setState(
                                              () => _documentPath = ''),
                                          icon: const Icon(Icons.close,
                                              size: 16, color: Colors.red),
                                        ),
                                    ],
                                  ),
                                  helperText:
                                      'Max File size: 5MB • Allowed: .pdf, .csv, .zip, .doc, .docx, .jpeg, .jpg, .png',
                                ),
                                _fieldBlock(
                                  'Applicable Tax:',
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedTaxName,
                                    isExpanded: true,
                                    decoration: _inputDeco(isDark),
                                    items: [
                                      const DropdownMenuItem(
                                          value: 'None', child: Text('None')),
                                      ..._taxRates.map((t) => DropdownMenuItem(
                                            value: t.name,
                                            child: Text(
                                                '${t.name} (${t.amount}%)',
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          )),
                                    ],
                                    onChanged: (v) {
                                      setState(() {
                                        _selectedTaxName = v ?? 'None';
                                        _selectedTaxRate = v == null ||
                                                v == 'None'
                                            ? 0.0
                                            : (_taxRates
                                                    .where((t) => t.name == v)
                                                    .map((t) => t.amount)
                                                    .firstOrNull ??
                                                0.0);
                                      });
                                    },
                                  ),
                                ),
                                _fieldBlock(
                                  'Total amount:*',
                                  TextFormField(
                                    controller: _totalAmountCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d{0,2}')),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: _inputDeco(isDark,
                                        hint: 'Total amount'),
                                    validator: (v) {
                                      final val =
                                          double.tryParse((v ?? '').trim()) ??
                                              0;
                                      if (val <= 0) {
                                        return 'Enter amount > 0';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),
                              _gridRow([
                                _fieldBlock(
                                  'Expense note:',
                                  TextFormField(
                                    controller: _noteCtrl,
                                    maxLines: 3,
                                    decoration: _inputDeco(isDark,
                                        hint: 'Enter expense notes...'),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: CheckboxListTile(
                                    value: _isRefund,
                                    onChanged: (v) =>
                                        setState(() => _isRefund = v ?? false),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      PosLocalization.tr('Is refund?',
                                          settings: widget.settings),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: textPrimary),
                                    ),
                                  ),
                                ),
                                const SizedBox.shrink(),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card 2: Recurring Settings
                        _card(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          child: _gridRow([
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: CheckboxListTile(
                                value: _isRecurring,
                                onChanged: (v) =>
                                    setState(() => _isRecurring = v ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  PosLocalization.tr('Is Recurring?',
                                      settings: widget.settings),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textPrimary),
                                ),
                              ),
                            ),
                            _fieldBlock(
                              'Recurring interval:*',
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _recurringIntervalCtrl,
                                      enabled: _isRecurring,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: _inputDeco(isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _recurringUnit,
                                      decoration: _inputDeco(isDark),
                                      items: const ['Days', 'Months', 'Years']
                                          .map((u) => DropdownMenuItem(
                                              value: u, child: Text(u)))
                                          .toList(),
                                      onChanged: _isRecurring
                                          ? (v) {
                                              if (v != null) {
                                                setState(
                                                    () => _recurringUnit = v);
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _fieldBlock(
                              'No. of Repetitions:',
                              TextFormField(
                                controller: _recurringRepCtrl,
                                enabled: _isRecurring,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: _inputDeco(isDark),
                              ),
                              helperText:
                                  'If blank expense will be generated infinite times',
                            ),
                          ]),
                        ),

                        // Card 3: Add payment (on new expense)
                        if (!_isEdit) ...[
                          const SizedBox(height: 16),
                          _card(
                            cardBg: cardBg,
                            borderCol: borderCol,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      PosLocalization.tr('Add payment',
                                          settings: widget.settings),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: textPrimary),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _payAmountCtrl.text =
                                              _totalAmount.toStringAsFixed(2);
                                        });
                                      },
                                      child: const Text('Pay Full Amount'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _fieldBlock(
                                        'Amount:*',
                                        TextFormField(
                                          controller: _payAmountCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'^\d*\.?\d{0,2}')),
                                          ],
                                          onChanged: (_) => setState(() {}),
                                          decoration:
                                              _inputDeco(isDark, hint: '0.00')
                                                  .copyWith(
                                            prefixText: cur,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _fieldBlock(
                                        'Paid on:*',
                                        InkWell(
                                          onTap: () =>
                                              _pickDateTime(isPaidOn: true),
                                          child: InputDecorator(
                                            decoration:
                                                _inputDeco(isDark).copyWith(
                                              prefixIcon: const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 16),
                                            ),
                                            child: Text(
                                              DateFormat('dd/MM/yyyy HH:mm')
                                                  .format(_paidOnDate),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: textPrimary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: 480,
                                  child: _fieldBlock(
                                    'Payment Method:*',
                                    DropdownButtonFormField<String>(
                                      initialValue: _paymentMethod,
                                      decoration: _inputDeco(isDark),
                                      items: const [
                                        'Cash',
                                        'Bank Transfer',
                                        'Card / POS',
                                        'Cheque',
                                      ]
                                          .map((m) => DropdownMenuItem(
                                              value: m, child: Text(m)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _paymentMethod = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _fieldBlock(
                                  'Payment note:',
                                  TextFormField(
                                    controller: _payNoteCtrl,
                                    maxLines: 3,
                                    decoration: _inputDeco(isDark,
                                        hint: 'Optional payment note...'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Divider(color: borderCol),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 13.5, color: textPrimary),
                                      children: [
                                        const TextSpan(
                                            text: 'Payment due: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        TextSpan(
                                          text: CurrencyFormatter.exact(
                                              _paymentDue,
                                              currency: cur),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _paymentDue > 0
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),

                        // Save Button
                        Center(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 42, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    PosLocalization.tr(
                                      _isEdit ? 'Update' : 'Save',
                                      settings: widget.settings,
                                    ),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _card({
    required Color cardBg,
    required Color borderCol,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: child,
    );
  }

  Widget _gridRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: children
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: c,
                    ))
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _fieldBlock(String label, Widget field, {String? helperText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        field,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDeco(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}
