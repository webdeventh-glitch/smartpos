import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'payment_reminder_dialog.dart';

class ContactLedgerDialog extends StatefulWidget {
  final Contact contact;
  final String contactType; // 'customer' or 'supplier'
  final BusinessSettings settings;
  final VoidCallback? onPaymentRecorded;

  const ContactLedgerDialog({
    super.key,
    required this.contact,
    required this.contactType,
    required this.settings,
    this.onPaymentRecorded,
  });

  @override
  State<ContactLedgerDialog> createState() => _ContactLedgerDialogState();
}

class _ContactLedgerDialogState extends State<ContactLedgerDialog> {
  bool _loading = true;
  String _dateFilter = 'all'; // 'all', 'month', '30days', 'today', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;

  double _openingBalance = 0.0;
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  double _closingBalance = 0.0;
  List<LedgerEntry> _entries = [];
  Contact? _updatedContact;

  @override
  void initState() {
    super.initState();
    _updatedContact = widget.contact;
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _loading = true);
    final db = await DatabaseService.initialize();

    DateTime? start = _startDate;
    DateTime? end = _endDate;

    final now = DateTime.now();
    if (_dateFilter == 'today') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_dateFilter == 'month') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (_dateFilter == '30days') {
      start = now.subtract(const Duration(days: 30));
      end = now;
    }

    final res = await db.getContactLedger(
      contactId: widget.contact.id!,
      contactType: widget.contactType,
      startDate: start,
      endDate: end,
    );

    if (mounted) {
      setState(() {
        _openingBalance = res['openingBalance'] as double? ?? 0.0;
        _totalDebit = res['totalDebit'] as double? ?? 0.0;
        _totalCredit = res['totalCredit'] as double? ?? 0.0;
        _closingBalance = res['closingBalance'] as double? ?? 0.0;
        _entries = res['entries'] as List<LedgerEntry>? ?? [];
        if (res['contact'] != null) {
          _updatedContact = res['contact'] as Contact;
        }
        _loading = false;
      });
    }
  }

  void _applyDateFilter(String filter) {
    setState(() {
      _dateFilter = filter;
      if (filter != 'custom') {
        _startDate = null;
        _endDate = null;
      }
    });
    _loadLedger();
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = 'custom';
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadLedger();
    }
  }

  void _copyStatementToClipboard() {
    final cur = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    final isCustomer = widget.contactType.toLowerCase() == 'customer';
    final contact = _updatedContact ?? widget.contact;

    buffer.writeln('========================================');
    buffer.writeln('${widget.settings.businessName.toUpperCase()} - ACCOUNT STATEMENT');
    buffer.writeln('========================================');
    buffer.writeln('${isCustomer ? "Customer" : "Supplier"}: ${contact.name}');
    if (contact.phone.isNotEmpty) buffer.writeln('Phone: ${contact.phone}');
    buffer.writeln('Generated: ${DateFormat("dd-MMM-yyyy HH:mm").format(DateTime.now())}');
    buffer.writeln('Period: ${_dateFilter.toUpperCase()}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Opening Balance: $cur${_openingBalance.toStringAsFixed(2)}');
    buffer.writeln('Total Debits (Dr): $cur${_totalDebit.toStringAsFixed(2)}');
    buffer.writeln('Total Credits (Cr): $cur${_totalCredit.toStringAsFixed(2)}');
    buffer.writeln('Current Closing Balance: $cur${_closingBalance.toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('TRANSACTIONS:');
    for (final e in _entries) {
      final drStr = e.debit > 0 ? "Dr: $cur${e.debit.toStringAsFixed(2)}" : "";
      final crStr = e.credit > 0 ? "Cr: $cur${e.credit.toStringAsFixed(2)}" : "";
      buffer.writeln('${e.date.split(" ").first} | ${e.refNo} | ${e.description} | $drStr $crStr | Bal: $cur${e.runningBalance.toStringAsFixed(2)}');
    }
    buffer.writeln('========================================');
    buffer.writeln('Thank you for your business!');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account statement copied to clipboard! Ready to share via WhatsApp or print.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  Future<void> _openQuickPaymentModal() async {
    final isCustomer = widget.contactType.toLowerCase() == 'customer';
    final contact = _updatedContact ?? widget.contact;
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextPaymentRef();
    final amountCtrl = TextEditingController(text: contact.balance > 0 ? contact.balance.toStringAsFixed(2) : '0.00');
    final noteCtrl = TextEditingController();
    String paymentMethod = 'cash';

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isCustomer ? 'Receive Customer Payment' : 'Pay Supplier',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Party: ${contact.name}',
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Payment Amount (${widget.settings.currencySymbol})*',
                  prefixText: '${widget.settings.currencySymbol} ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Payment Method*', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash Till')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / Online')),
                  DropdownMenuItem(value: 'card', child: Text('Card / POS Terminal')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Reference / Note', hintText: 'Receipt # or Cheque #', border: OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0) return;

                final payment = ContactPayment(
                  contactId: contact.id!,
                  contactName: contact.name,
                  paymentType: isCustomer ? 'receive' : 'pay',
                  amount: amt,
                  paymentMethod: paymentMethod,
                  date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                  refNo: nextRef,
                  note: noteCtrl.text.trim(),
                );

                await db.addContactPayment(payment);
                Navigator.pop(ctx);
                _loadLedger();
                widget.onPaymentRecorded?.call();
              },
              child: const Text('Save Payment & Update Khata'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final isCustomer = widget.contactType.toLowerCase() == 'customer';
    final contact = _updatedContact ?? widget.contact;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1040,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCustomer ? Icons.receipt_long_rounded : Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF4F46E5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${contact.name} - Account Ledger',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCustomer ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCustomer ? 'CUSTOMER KHATA' : 'SUPPLIER PAYABLE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomer ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone: ${contact.phone.isNotEmpty ? contact.phone : "N/A"}  |  Address: ${contact.address.isNotEmpty ? contact.address : "Main Market"}',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Copy / Share Statement'),
                      onPressed: _copyStatementToClipboard,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.payments_rounded, size: 16),
                      label: Text(isCustomer ? 'Receive Payment' : 'Pay Supplier'),
                      onPressed: _openQuickPaymentModal,
                    ),
                    if (isCustomer && (_closingBalance > 0 || contact.balance > 0)) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 15),
                        label: const Text('WhatsApp Reminder'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PaymentReminderDialog(
                              contact: _updatedContact ?? widget.contact,
                              settings: widget.settings,
                              specificDue: _closingBalance > 0 ? _closingBalance : null,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Date Filters Row
            Row(
              children: [
                const Text('Period: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _filterChip('All Time', 'all', isDark),
                const SizedBox(width: 6),
                _filterChip('Today', 'today', isDark),
                const SizedBox(width: 6),
                _filterChip('This Month', 'month', isDark),
                const SizedBox(width: 6),
                _filterChip('Last 30 Days', '30days', isDark),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                      color: _dateFilter == 'custom' ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  icon: const Icon(Icons.date_range, size: 14),
                  label: Text(_dateFilter == 'custom' && _startDate != null
                      ? '${DateFormat("dd MMM").format(_startDate!)} - ${DateFormat("dd MMM").format(_endDate!)}'
                      : 'Custom Range'),
                  onPressed: _selectCustomDateRange,
                ),
                const Spacer(),
                Text(
                  'Entries: ${_entries.length}',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Summary KPI Cards (Opening, Total Debit, Total Credit, Closing Balance)
            Row(
              children: [
                _kpiCard(
                  title: 'Opening Balance',
                  amount: _openingBalance,
                  currency: cur,
                  subtitle: 'Carried forward from previous period',
                  color: const Color(0xFF64748B),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  title: isCustomer ? 'Total Invoices / Billed (Dr)' : 'Total Purchases (Cr)',
                  amount: isCustomer ? _totalDebit : _totalCredit,
                  currency: cur,
                  subtitle: isCustomer ? 'Total merchandise billed' : 'Total inventory received',
                  color: const Color(0xFF4F46E5),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  title: isCustomer ? 'Total Paid / Recoveries (Cr)' : 'Total Payments Made (Dr)',
                  amount: isCustomer ? _totalCredit : _totalDebit,
                  currency: cur,
                  subtitle: isCustomer ? 'Cash & bank settlements' : 'Payments disbursed',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _kpiCard(
                  title: 'Net Closing Balance',
                  amount: _closingBalance,
                  currency: cur,
                  subtitle: _closingBalance > 0
                      ? (isCustomer ? 'Amount Customer Owes You' : 'Amount You Owe Supplier')
                      : 'Account Balanced / Cleared',
                  color: _closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  isDark: isDark,
                  isHighlight: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ledger DataTable
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                const SizedBox(height: 8),
                                Text('No ledger entries recorded for this period.', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFEDE9FE)),
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('REF / INVOICE #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('NARRATION / DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('DEBIT (DR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('CREDIT (CR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  DataColumn(label: Text('RUNNING BALANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                                rows: _entries.map((e) {
                                  final isDebit = e.debit > 0;
                                  final isCredit = e.credit > 0;
                                  return DataRow(cells: [
                                    DataCell(Text(e.date.length > 16 ? e.date.substring(0, 16) : e.date, style: const TextStyle(fontSize: 11))),
                                    DataCell(_typeBadge(e.transactionType, isDark)),
                                    DataCell(Text(e.refNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4F46E5)))),
                                    DataCell(Text(e.description, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                    DataCell(Text(
                                      isDebit ? '$cur${e.debit.toStringAsFixed(2)}' : '-',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isDebit ? FontWeight.bold : FontWeight.normal,
                                        color: isDebit ? const Color(0xFF4338CA) : Colors.grey,
                                      ),
                                    )),
                                    DataCell(Text(
                                      isCredit ? '$cur${e.credit.toStringAsFixed(2)}' : '-',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isCredit ? FontWeight.bold : FontWeight.normal,
                                        color: isCredit ? const Color(0xFF059669) : Colors.grey,
                                      ),
                                    )),
                                    DataCell(Text(
                                      '$cur${e.runningBalance.toStringAsFixed(2)} ${e.runningBalance > 0 ? "Dr" : "Cr"}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        color: e.runningBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                      ),
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final selected = _dateFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A))),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      onSelected: (_) => _applyDateFilter(value),
    );
  }

  Widget _kpiCard({
    required String title,
    required double amount,
    required String currency,
    required String subtitle,
    required Color color,
    required bool isDark,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlight
              ? color.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isHighlight ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(
              '$currency${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type, bool isDark) {
    Color bg = const Color(0xFFEEF2FF);
    Color fg = const Color(0xFF4F46E5);
    String label = type.toUpperCase().replaceAll('_', ' ');

    if (type.contains('payment')) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (type.contains('return')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (type.contains('purchase')) {
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
