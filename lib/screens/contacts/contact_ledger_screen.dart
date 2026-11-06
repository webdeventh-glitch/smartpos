import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/print_service.dart';
import 'payment_reminder_dialog.dart';

class ContactLedgerScreen extends StatefulWidget {
  final Contact contact;
  final String contactType; // 'customer' or 'supplier'
  final BusinessSettings settings;
  final VoidCallback? onPaymentRecorded;

  const ContactLedgerScreen({
    super.key,
    required this.contact,
    required this.contactType,
    required this.settings,
    this.onPaymentRecorded,
  });

  @override
  State<ContactLedgerScreen> createState() => _ContactLedgerScreenState();
}

class _ContactLedgerScreenState extends State<ContactLedgerScreen> {
  bool _loading = true;
  String _dateFilter = 'all'; // 'all', 'today', 'month', '30days', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  double _openingBalance = 0.0;
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  double _closingBalance = 0.0;
  List<LedgerEntry> _entries = [];
  Contact? _updatedContact;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updatedContact = widget.contact;
    _loadLedger();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  String _getPeriodLabel() {
    if (_dateFilter == 'today') return 'Today (آج کا کھاتہ)';
    if (_dateFilter == 'month') return 'This Month (موجودہ مہینہ)';
    if (_dateFilter == '30days') return 'Last 30 Days (گزشتہ 30 دن)';
    if (_dateFilter == 'custom' && _startDate != null && _endDate != null) {
      return '${DateFormat("dd MMM yyyy").format(_startDate!)} to ${DateFormat("dd MMM yyyy").format(_endDate!)}';
    }
    return 'All Time (مکمل ریکارڈ)';
  }

  void _printOfficialLedger() {
    final contact = _updatedContact ?? widget.contact;
    final html = PrintService.generateOfficialLedgerHtml(
      settings: widget.settings,
      contact: contact,
      contactType: widget.contactType,
      openingBalance: _openingBalance,
      totalDebit: _totalDebit,
      totalCredit: _totalCredit,
      closingBalance: _closingBalance,
      entries: _filteredEntries,
      periodText: _getPeriodLabel(),
    );

    PrintService.openPrintWindow(
      htmlContent: html,
      title: '${contact.name}_Official_Ledger',
    );
  }

  void _copyStatementToClipboard() {
    final cur = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    final isCustomer = widget.contactType.toLowerCase() == 'customer';
    final contact = _updatedContact ?? widget.contact;

    buffer.writeln('========================================');
    buffer.writeln('${widget.settings.businessName.toUpperCase()} - OFFICIAL KHATA STATEMENT');
    buffer.writeln('========================================');
    buffer.writeln('${isCustomer ? "Customer (گاہک)" : "Supplier (سپلائر)"}: ${contact.name}');
    if (contact.phone.isNotEmpty) buffer.writeln('Phone: ${contact.phone}');
    buffer.writeln('Period: ${_getPeriodLabel()}');
    buffer.writeln('Generated: ${DateFormat("dd-MMM-yyyy HH:mm").format(DateTime.now())}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Opening Balance (سابقہ بقایا): $cur${_openingBalance.toStringAsFixed(2)}');
    buffer.writeln('Total Billed / Debit (بنام کل مال Dr): $cur${_totalDebit.toStringAsFixed(2)}');
    buffer.writeln('Total Paid / Credit (جمع کل وصولیاں Cr): $cur${_totalCredit.toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('NET CLOSING KHATA (خالص بقیہ رقم): $cur${_closingBalance.toStringAsFixed(2)} ${_closingBalance > 0 ? "(واجب الادا)" : "(کلیئر)"}');
    buffer.writeln('========================================');
    buffer.writeln('TRANSACTIONS / تفصیل کھاتہ:');
    for (final e in _filteredEntries) {
      final drStr = e.debit > 0 ? "Dr: $cur${e.debit.toStringAsFixed(2)}" : "";
      final crStr = e.credit > 0 ? "Cr: $cur${e.credit.toStringAsFixed(2)}" : "";
      buffer.writeln('${e.date.split(" ").first} | ${e.refNo} | ${e.description} | $drStr $crStr | Bal: $cur${e.runningBalance.toStringAsFixed(2)}');
    }
    buffer.writeln('========================================');
    buffer.writeln('Thank you for your business! شکریہ');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account statement copied to clipboard! Ready to share via WhatsApp or SMS.'),
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
            isCustomer ? 'Receive Customer Payment / گاہک سے رقم وصول کریں' : 'Pay Supplier / سپلائر کو ادائیگی کریں',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Party: ${contact.name}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                  DropdownMenuItem(value: 'cash', child: Text('Cash Till / کیش دراز')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / بینک ٹرانسفر')),
                  DropdownMenuItem(value: 'card', child: Text('Card / POS Machine')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque / چیک')),
                ],
                onChanged: (val) => setDlgState(() => paymentMethod = val ?? paymentMethod),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  labelText: 'Reference / Note (تفصیل یا رسید نمبر)',
                  hintText: 'Receipt #, Bank Slip #, or Cheque #',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel / منسوخ', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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

  Future<void> _viewInvoiceDetails(String invoiceNo) async {
    final db = await DatabaseService.initialize();
    final sale = await db.getSaleByInvoiceNo(invoiceNo);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;

    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Details for invoice $invoiceNo could not be loaded.')),
      );
      return;
    }

    final items = sale.items ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Invoice: ${sale.invoiceNo}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            Text(
              sale.createdAt.length > 16 ? sale.createdAt.substring(0, 16) : sale.createdAt,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${sale.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Divider(height: 20),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        children: const [
                          Padding(padding: EdgeInsets.all(6), child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                      ...items.map((it) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text(it.productName, style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(it.quantity.toString(), style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('$cur${it.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('$cur${it.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          )),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Method: ${sale.paymentMethod.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                  Text('Total: $cur${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print A4 Invoice'),
            onPressed: () {
              Navigator.pop(ctx);
              final invoiceHtml = PrintService.generateA4AgencyInvoiceHtml(
                sale: sale,
                settings: widget.settings,
                customerPreviousBalance: _closingBalance,
              );
              PrintService.openPrintWindow(htmlContent: invoiceHtml, title: 'Invoice_${sale.invoiceNo}');
            },
          ),
        ],
      ),
    );
  }

  List<LedgerEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase().trim();
    return _entries.where((e) {
      return e.refNo.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q) ||
          e.transactionType.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cur = widget.settings.currencySymbol;
    final isCustomer = widget.contactType.toLowerCase() == 'customer';
    final contact = _updatedContact ?? widget.contact;

    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          tooltip: 'Back to ${isCustomer ? "Customers" : "Suppliers"}',
          onPressed: () {
            widget.onPaymentRecorded?.call();
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isCustomer ? const Color(0xFFEDE9FE) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCustomer ? Icons.account_box_rounded : Icons.local_shipping_rounded,
                color: isCustomer ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${contact.name} - Official Account Ledger',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCustomer ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCustomer ? 'CUSTOMER KHATA / کسٹمر کھاتہ' : 'SUPPLIER PAYABLE / سپلائر کھاتہ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCustomer ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${widget.settings.businessName} • Official Financial Ledger Book (سرکاری کھاتہ رجسٹر)',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Copy Statement
          IconButton(
            tooltip: 'Copy Statement / کھاتہ کاپی کریں',
            icon: const Icon(Icons.content_copy_rounded, size: 20),
            onPressed: _copyStatementToClipboard,
          ),
          // WhatsApp Statement
          if (isCustomer && (_closingBalance > 0 || contact.balance > 0))
            IconButton(
              tooltip: 'Send WhatsApp Reminder / واٹس ایپ میسج',
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: Color(0xFF10B981)),
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
          // Print Official A4 Ledger
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.print_rounded, size: 17),
              label: const Text('Print Official A4 Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _printOfficialLedger,
            ),
          ),
          // Receive Payment / Pay Supplier
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.payments_rounded, size: 17),
              label: Text(
                isCustomer ? '+ Receive Payment (رقم وصول کریں)' : '+ Pay Supplier (ادائیگی کریں)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: _openQuickPaymentModal,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Party Profile & Khata Status Banner Card
            _buildPartyProfileBanner(contact, isCustomer, isDark, cur, textPrimary, textSecondary, borderColor),
            const SizedBox(height: 16),

            // 2. Summary 4 Big KPI Cards (Full Width)
            _buildKpiSummaryCards(isCustomer, isDark, cur),
            const SizedBox(height: 16),

            // 3. Official Date Filter & Live Search Toolbar
            _buildFilterAndSearchToolbar(isDark, borderColor, textPrimary, textSecondary),
            const SizedBox(height: 16),

            // 4. Official Full-Width Ledger Table
            _buildLedgerDataTable(isCustomer, isDark, cur, textPrimary, textSecondary, borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyProfileBanner(
    Contact contact,
    bool isCustomer,
    bool isDark,
    String cur,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isDue = _closingBalance > 0;
    final isClear = _closingBalance == 0;
    final isAdvance = _closingBalance < 0;

    final statusBg = isDue
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : (isClear
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
            : (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF)));

    final statusBorder = isDue
        ? const Color(0xFFFCA5A5)
        : (isClear ? const Color(0xFF6EE7B7) : const Color(0xFFA5B4FC));

    final statusColor = isDue
        ? const Color(0xFFDC2626)
        : (isClear ? const Color(0xFF059669) : const Color(0xFF4F46E5));

    final statusHeading = isDue
        ? (isCustomer ? '⚠️ واجب الادا رقم (Customer Due Balance): $cur${_closingBalance.toStringAsFixed(2)}' : '⚠️ واجب الادا ادائیگی (Supplier Payable): $cur${_closingBalance.toStringAsFixed(2)}')
        : (isClear
            ? '✅ کھاتہ بالکل بے باق ہے (Zero Balance / Account Completely Cleared)'
            : '💰 پیشگی رقم جمع ہے (Advance Credit Balance): $cur${_closingBalance.abs().toStringAsFixed(2)}');

    final statusDesc = isDue
        ? (isCustomer ? 'یہ رقم گاہک کے ذمہ واجب الادا ہے، فوری وصولی کریں۔' : 'یہ رقم سپلائر کو ادا کرنی ہے۔')
        : (isClear ? 'تمام بل اور وصولیاں برابر ہیں، کوئی رقم واجب الادا نہیں۔' : 'پارٹی کے پاس پیشگی رقم جمع ہے۔ آئندہ خریداری پر ایڈجسٹ ہوگی۔');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: isCustomer ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                child: Text(
                  contact.name.isNotEmpty ? contact.name.substring(0, 1).toUpperCase() : 'C',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              // Party Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          contact.name,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textPrimary),
                        ),
                        if (contact.businessName != null && contact.businessName!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              contact.businessName!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_outlined, size: 15, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              contact.phone.isNotEmpty ? contact.phone : 'No Phone Recorded',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 15, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              contact.address.isNotEmpty ? contact.address : 'Main City Market',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.credit_card_outlined, size: 15, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Credit Limit (حد قرضہ): $cur${contact.creditLimit.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tag_rounded, size: 15, color: textSecondary),
                            const SizedBox(width: 4),
                            Text('Code: #CON-${contact.id ?? 1}', style: TextStyle(fontSize: 12, color: textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Clear Layman Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusHeading,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusDesc,
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.history_edu_rounded, size: 15),
                  label: const Text('Copy WhatsApp Statement'),
                  onPressed: _copyStatementToClipboard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCards(bool isCustomer, bool isDark, String cur) {
    return Row(
      children: [
        _kpiStatCard(
          titleUrdu: 'سابقہ بقایا رقم',
          titleEng: 'Opening Balance',
          amount: _openingBalance,
          cur: cur,
          subtitle: 'Carried forward from previous period (سابقہ ادوار کا بقیہ)',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF64748B),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _kpiStatCard(
          titleUrdu: isCustomer ? 'بنام / کل مالیت (انوائسز)' : 'کل مال خریداری (انوائسز)',
          titleEng: isCustomer ? 'Total Invoices / Billed (Dr)' : 'Total Purchases (Cr)',
          amount: isCustomer ? _totalDebit : _totalCredit,
          cur: cur,
          subtitle: isCustomer ? 'Total merchandise billed (کل مال کی قیمت)' : 'Total inventory received',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _kpiStatCard(
          titleUrdu: isCustomer ? 'جمع / کل موصول شدہ رقم' : 'کل ادا شدہ رقم',
          titleEng: isCustomer ? 'Total Paid / Recoveries (Cr)' : 'Total Payments Made (Dr)',
          amount: isCustomer ? _totalCredit : _totalDebit,
          cur: cur,
          subtitle: isCustomer ? 'Cash & bank settlements (موصول شدہ نقد و بینک)' : 'Payments disbursed',
          icon: Icons.price_check_rounded,
          color: const Color(0xFF10B981),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _kpiStatCard(
          titleUrdu: 'خالص واجب الادا بقایا',
          titleEng: 'Net Closing Balance',
          amount: _closingBalance,
          cur: cur,
          subtitle: _closingBalance > 0
              ? (isCustomer ? 'Amount Customer Owes You (واجب الوصول)' : 'Amount You Owe Supplier (واجب الادا)')
              : 'Account Cleared (کھاتہ بے باق)',
          icon: Icons.account_balance_rounded,
          color: _closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF059669),
          isDark: isDark,
          isHighlight: true,
        ),
      ],
    );
  }

  Widget _kpiStatCard({
    required String titleUrdu,
    required String titleEng,
    required double amount,
    required String cur,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isHighlight = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isHighlight ? color.withValues(alpha: isDark ? 0.2 : 0.08) : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlight ? color : borderColor,
            width: isHighlight ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleUrdu,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isHighlight ? color : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),
                      Text(
                        titleEng,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$cur${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isHighlight ? color : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchToolbar(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Text('Period (مدت):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _filterChoiceChip('All Time (مکمل)', 'all', isDark),
          const SizedBox(width: 6),
          _filterChoiceChip('Today (آج)', 'today', isDark),
          const SizedBox(width: 6),
          _filterChoiceChip('This Month (یہ مہینہ)', 'month', isDark),
          const SizedBox(width: 6),
          _filterChoiceChip('Last 30 Days (30 دن)', '30days', isDark),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(
                color: _dateFilter == 'custom' ? const Color(0xFF4F46E5) : borderColor,
              ),
            ),
            icon: const Icon(Icons.date_range_rounded, size: 14),
            label: Text(
              _dateFilter == 'custom' && _startDate != null
                  ? '${DateFormat("dd MMM").format(_startDate!)} - ${DateFormat("dd MMM").format(_endDate!)}'
                  : 'Custom Range (تاریخ منتخب کریں)',
              style: const TextStyle(fontSize: 11),
            ),
            onPressed: _selectCustomDateRange,
          ),
          const Spacer(),
          // Search Box
          SizedBox(
            width: 260,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 12, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search Inv #, Ref # or details...',
                hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_filteredEntries.length} Transactions',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChoiceChip(String label, String value, bool isDark) {
    final selected = _dateFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A))),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      onSelected: (_) => _applyDateFilter(value),
    );
  }

  Widget _buildLedgerDataTable(
    bool isCustomer,
    bool isDark,
    String cur,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_loading) {
      return Container(
        height: 350,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading official account transactions...'),
          ],
        ),
      );
    }

    final entries = _filteredEntries;

    if (entries.isEmpty) {
      return Container(
        height: 350,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: textSecondary),
            const SizedBox(height: 12),
            Text(
              'No ledger entries found for this period.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'اس منتخب مدت میں کوئی لین دین یا بل ریکارڈ نہیں ہے۔',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Record Payment / نئی وصولی درج کریں'),
              onPressed: _openQuickPaymentModal,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table Header Bar with Explanation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDE9FE),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Text(
                    'OFFICIAL LEDGER TRANSACTIONS REGISTER (کھاتہ رجسٹر مکمل تفصیلات)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF312E81),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'All figures in Pakistani Rupee ($cur)',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),

            // DataTable
            LayoutBuilder(
              builder: (context, constraints) {
                final double tableWidth = math.max(constraints.maxWidth, 1050.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 52,
                      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      columnSpacing: 0,
                      columns: const [
                        DataColumn(columnWidth: FlexColumnWidth(0.5), label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.6), label: Text('DATE & TIME / تاریخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.4), label: Text('TYPE / قسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.4), label: Text('REF / INVOICE #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(2.8), label: Text('NARRATION & DETAILS / مال کی تفصیل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.3), label: Text('DEBIT / بنام Dr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.3), label: Text('CREDIT / جمع Cr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(1.6), label: Text('RUNNING BALANCE / بقیہ کھاتہ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(columnWidth: FlexColumnWidth(0.8), label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                  rows: entries.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final e = entry.value;
                    final isDebit = e.debit > 0;
                    final isCredit = e.credit > 0;
                    final isInvoice = e.transactionType.contains('sale') || e.transactionType.contains('purchase');

                    final balType = e.runningBalance > 0
                        ? (isCustomer ? "Dr (واجب)" : "Cr (واجب)")
                        : (e.runningBalance < 0 ? "Adv (جمع)" : "Cleared");

                    final balColor = e.runningBalance > 0
                        ? const Color(0xFFDC2626)
                        : (e.runningBalance < 0 ? const Color(0xFF059669) : textSecondary);

                    return DataRow(
                      cells: [
                        DataCell(Text(idx.toString(), style: TextStyle(fontSize: 11, color: textSecondary))),
                        DataCell(
                          Text(
                            e.date.length > 16 ? e.date.substring(0, 16) : e.date,
                            style: TextStyle(fontSize: 11, color: textPrimary),
                          ),
                        ),
                        DataCell(_typeBadge(e.transactionType, isDark)),
                        DataCell(
                          InkWell(
                            onTap: isInvoice ? () => _viewInvoiceDetails(e.refNo) : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  e.refNo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isInvoice ? const Color(0xFF4F46E5) : textPrimary,
                                    decoration: isInvoice ? TextDecoration.underline : TextDecoration.none,
                                  ),
                                ),
                                if (isInvoice) ...[
                                  const SizedBox(width: 3),
                                  const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF4F46E5)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 240,
                            child: Text(
                              e.description,
                              style: TextStyle(fontSize: 11, color: textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            isDebit ? '$cur${e.debit.toStringAsFixed(2)}' : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isDebit ? FontWeight.bold : FontWeight.normal,
                              color: isDebit ? const Color(0xFF1E40AF) : Colors.grey,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            isCredit ? '$cur${e.credit.toStringAsFixed(2)}' : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isCredit ? FontWeight.bold : FontWeight.normal,
                              color: isCredit ? const Color(0xFF059669) : Colors.grey,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$cur${e.runningBalance.abs().toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: balColor),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: balColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  balType,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: balColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          isInvoice
                              ? IconButton(
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF4F46E5)),
                                  tooltip: 'View Invoice Items',
                                  onPressed: () => _viewInvoiceDetails(e.refNo),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),

            // Footer Totals Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: borderColor, width: 1.5)),
              ),
              child: Row(
                children: [
                  const Text('GRAND TOTALS (کل میزان کھاتہ):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  Text(
                    'Total Debit (Dr): $cur${_totalDebit.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Total Credit (Cr): $cur${_totalCredit.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _closingBalance > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Net Balance: $cur${_closingBalance.toStringAsFixed(2)} ${_closingBalance > 0 ? "(واجب الادا)" : "(بے باق)"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: _closingBalance > 0 ? const Color(0xFFDC2626) : const Color(0xFF065F46),
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

  Widget _typeBadge(String type, bool isDark) {
    Color bg = const Color(0xFFEEF2FF);
    Color fg = const Color(0xFF4F46E5);
    String label = type.toUpperCase().replaceAll('_', ' ');

    if (type.contains('payment')) {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
      label = 'PAYMENT / وصولی';
    } else if (type.contains('return')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'RETURN / واپسی';
    } else if (type.contains('purchase')) {
      bg = const Color(0xFFE0E7FF);
      fg = const Color(0xFF3730A3);
      label = 'PURCHASE / خریداری';
    } else if (type.contains('sale')) {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF4338CA);
      label = 'INVOICE / بل';
    } else if (type.contains('opening')) {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      label = 'OPENING / سابقہ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
