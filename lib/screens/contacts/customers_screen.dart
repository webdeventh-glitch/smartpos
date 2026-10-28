import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../pos/quick_customer_dialog.dart';
import 'contact_ledger_dialog.dart';
import 'payment_reminder_dialog.dart';
import '../../services/print_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';

class CustomersScreen extends StatefulWidget {
  final BusinessSettings settings;

  const CustomersScreen({super.key, required this.settings});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Contact> _customers = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'defaulters', 'over_limit', 'clear'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  Widget _fieldLabel(String label, {bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }

  Future<void> _openPayDueDialog(Contact customer) async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextPaymentRef();
    final amountCtrl = TextEditingController(text: customer.balance.toStringAsFixed(2));
    final noteCtrl = TextEditingController();
    String paymentMethod = 'cash';

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
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
                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.payments_rounded, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receive Due Payment',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Customer: ${customer.name}',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                      splashRadius: 18,
                    ),
                  ],
                ),
                Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                // Outstanding Due Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Outstanding Balance Due:',
                        style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B), fontSize: 13),
                      ),
                      Text(
                        '${widget.settings.currencySymbol}${customer.balance.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626), fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                _fieldLabel('Amount Received (${widget.settings.currencySymbol}) *', isDark: isDark),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded, size: 18),
                    hintText: '0.00',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Method
                _fieldLabel('Payment Method *', isDark: isDark),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash in Hand')),
                    DropdownMenuItem(value: 'card', child: Text('Debit / Credit Card')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / Online')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque Payment')),
                  ],
                  onChanged: (val) => setDlgState(() => paymentMethod = val ?? 'cash'),
                ),
                const SizedBox(height: 14),

                // Note
                _fieldLabel('Payment Note / Ref No', isDark: isDark),
                TextField(
                  controller: noteCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cleared invoice balance, Bank Slip #...',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (amt <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid received amount!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        final payment = ContactPayment(
                          contactId: customer.id!,
                          contactName: customer.name,
                          paymentType: 'receive',
                          amount: amt,
                          paymentMethod: paymentMethod,
                          date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                          refNo: nextRef,
                          note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : 'Due payment collected',
                        );

                        await db.addContactPayment(payment);

                        Navigator.pop(ctx);
                        _load();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Collected ${widget.settings.currencySymbol}${amt.toStringAsFixed(2)} from ${customer.name}!'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
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

  Future<void> _openLedgerDialog(Contact customer) async {
    showDialog(
      context: context,
      builder: (_) => ContactLedgerDialog(
        contact: customer,
        contactType: 'customer',
        settings: widget.settings,
        onPaymentRecorded: () => _load(),
      ),
    );
  }

  void _openReminderDialog(Contact customer) {
    showDialog(
      context: context,
      builder: (_) => PaymentReminderDialog(
        contact: customer,
        settings: widget.settings,
      ),
    );
  }

  void _printDefaultersSheet(List<Contact> defaulters) {
    final listToPrint = defaulters.isNotEmpty ? defaulters : _customers.where((c) => c.balance > 0).toList();
    final html = PrintService.generateDefaultersListHtml(
      settings: widget.settings,
      defaulters: listToPrint,
      paperSize: widget.settings.receiptPaperSize,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Outstanding Dues & Defaulters Recovery Sheet',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    // Defaulters analysis
    final defaulters = _customers.where((c) => c.balance > 0).toList();
    final overLimit = _customers.where((c) => c.creditLimit > 0 && c.balance > c.creditLimit).toList();
    final cleared = _customers.where((c) => c.balance <= 0).toList();
    final totalReceivable = defaulters.fold(0.0, (sum, c) => sum + c.balance);

    // Apply Filter & Search
    final displayedCustomers = _customers.where((c) {
      if (_filter == 'defaulters' && c.balance <= 0) return false;
      if (_filter == 'over_limit' && (c.creditLimit <= 0 || c.balance <= c.creditLimit)) return false;
      if (_filter == 'clear' && c.balance > 0) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchPhone = c.phone.toLowerCase().contains(q);
        final matchBiz = c.businessName?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchPhone && !matchBiz) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customers & Defaulters Khata Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track customer accounts, overdue defaulters, send WhatsApp & SMS reminders, and collect dues.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text('Print Defaulters Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _printDefaultersSheet(defaulters),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 20),
                      label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _openAddCustomer,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 4 KPI Summary Cards
            Row(
              children: [
                _mini('Total Customers', '${_customers.length}', const Color(0xFF4F46E5), isDark: isDark),
                const SizedBox(width: 12),
                _mini('Defaulters (Pending Due)', '${defaulters.length} customers', const Color(0xFFEF4444), isDark: isDark),
                const SizedBox(width: 12),
                _mini('Total Overdue Receivables', '$currency${totalReceivable.toStringAsFixed(2)}', const Color(0xFFDC2626), isDark: isDark),
                const SizedBox(width: 12),
                _mini('Credit Limit Exceeded', '${overLimit.length} accounts', const Color(0xFFF59E0B), isDark: isDark),
              ],
            ),
            const SizedBox(height: 18),

            // Search and Defaulter Filter Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Filter Chips
                  _filterChip('all', 'All (${_customers.length})', isDark),
                  const SizedBox(width: 8),
                  _filterChip('defaulters', '🚨 Defaulters / Dues (${defaulters.length})', isDark, isHighlight: true),
                  const SizedBox(width: 8),
                  _filterChip('over_limit', '⚠️ Limit Exceeded (${overLimit.length})', isDark),
                  const SizedBox(width: 8),
                  _filterChip('clear', '✓ Zero Balance (${cleared.length})', isDark),

                  const Spacer(),

                  // Search Box
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search by name, phone...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Customers Table
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : displayedCustomers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                const SizedBox(height: 10),
                                Text(
                                  _filter == 'defaulters' ? 'Great news! No defaulters found.' : 'No customers match the selected criteria.',
                                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                fontSize: 12,
                              ),
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(label: Text('CUSTOMER NAME')),
                                DataColumn(label: Text('BUSINESS')),
                                DataColumn(label: Text('PHONE')),
                                DataColumn(label: Text('CREDIT LIMIT')),
                                DataColumn(label: Text('CURRENT DUE')),
                                DataColumn(label: Text('ACTIONS & REMINDERS')),
                              ],
                              rows: displayedCustomers.map((c) {
                                final isOverLimit = c.creditLimit > 0 && c.balance > c.creditLimit;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: c.balance > 0
                                                ? const Color(0xFFFEE2E2)
                                                : (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF)),
                                            child: Text(
                                              c.name.isNotEmpty ? c.name[0] : 'C',
                                              style: TextStyle(
                                                color: c.balance > 0 ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                c.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (isOverLimit)
                                                const Text(
                                                  'Exceeded Limit!',
                                                  style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(
                                      c.businessName?.isNotEmpty == true ? c.businessName! : '-',
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                    )),
                                    DataCell(Text(
                                      c.phone.isNotEmpty ? c.phone : '-',
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                    )),
                                    DataCell(Text(
                                      '$currency${c.creditLimit.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.black87),
                                    )),
                                    DataCell(Text(
                                      c.balance > 0 ? '$currency${c.balance.toStringAsFixed(2)}' : '$currency 0.00',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: c.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      ),
                                    )),
                                    DataCell(
                                      Row(
                                        children: [
                                          // Pay Due
                                          if (c.balance > 0) ...[
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF059669),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.attach_money, size: 14),
                                              label: const Text('Pay Due', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () => _openPayDueDialog(c),
                                            ),
                                            const SizedBox(width: 6),

                                            // WhatsApp / SMS Reminder
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 13),
                                              label: const Text('Reminder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: () => _openReminderDialog(c),
                                            ),
                                            const SizedBox(width: 6),
                                          ],

                                          // Khata Ledger
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                              side: BorderSide(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 14),
                                            label: const Text('Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            onPressed: () => _openLedgerDialog(c),
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

  Widget _filterChip(String id, String label, bool isDark, {bool isHighlight = false}) {
    final isSelected = _filter == id;
    final color = isHighlight ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : (isHighlight ? const Color(0xFFEF4444).withValues(alpha: 0.1) : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isHighlight ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isHighlight ? const Color(0xFFDC2626) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color color, {required bool isDark}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
