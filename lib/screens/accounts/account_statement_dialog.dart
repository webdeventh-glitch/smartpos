import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AccountStatementDialog extends StatefulWidget {
  final PaymentAccount account;
  final BusinessSettings settings;
  final VoidCallback? onAccountUpdated;

  const AccountStatementDialog({
    super.key,
    required this.account,
    required this.settings,
    this.onAccountUpdated,
  });

  @override
  State<AccountStatementDialog> createState() => _AccountStatementDialogState();
}

class _AccountStatementDialogState extends State<AccountStatementDialog> {
  bool _loading = true;
  String _dateFilter = 'all'; // 'all', 'month', '30days', 'today', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;

  double _openingBalance = 0.0;
  double _totalInflow = 0.0;
  double _totalOutflow = 0.0;
  double _closingBalance = 0.0;
  List<LedgerEntry> _entries = [];
  PaymentAccount? _currentAccount;

  @override
  void initState() {
    super.initState();
    _currentAccount = widget.account;
    _loadStatement();
  }

  Future<void> _loadStatement() async {
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

    final res = await db.getPaymentAccountStatement(
      accountId: widget.account.id!,
      accountName: widget.account.name,
      startDate: start,
      endDate: end,
    );

    // Refresh current account details
    final refreshedAccs = await db.getPaymentAccounts();
    final updated = refreshedAccs.where((a) => a.id == widget.account.id).firstOrNull;

    if (mounted) {
      setState(() {
        _openingBalance = res['openingBalance'] as double? ?? 0.0;
        _totalInflow = res['totalInflow'] as double? ?? 0.0;
        _totalOutflow = res['totalOutflow'] as double? ?? 0.0;
        _closingBalance = res['closingBalance'] as double? ?? 0.0;
        _entries = res['entries'] as List<LedgerEntry>? ?? [];
        if (updated != null) {
          _currentAccount = updated;
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
    _loadStatement();
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _dateFilter = 'custom';
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadStatement();
    }
  }

  void _copyStatementToClipboard() {
    final cur = widget.settings.currencySymbol;
    final acc = _currentAccount ?? widget.account;
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('ACCOUNT STATEMENT / PASSBOOK');
    buffer.writeln('Account: ${acc.name} (${acc.accountType.toUpperCase()})');
    if (acc.accountNumber.isNotEmpty) {
      buffer.writeln('A/C No: ${acc.accountNumber}');
    }
    buffer.writeln('Statement Period: ${_formatPeriod()}');
    buffer.writeln('Opening Balance: $cur${_openingBalance.toStringAsFixed(2)}');
    buffer.writeln('Total Inflows (Deposits): $cur${_totalInflow.toStringAsFixed(2)}');
    buffer.writeln('Total Outflows (Withdrawals): $cur${_totalOutflow.toStringAsFixed(2)}');
    buffer.writeln('Closing Balance: $cur${_closingBalance.toStringAsFixed(2)}');
    buffer.writeln('========================================');
    buffer.writeln('DATE\tREF #\tDESCRIPTION\tDEBIT (IN)\tCREDIT (OUT)\tBALANCE');

    for (final e in _entries) {
      final date = e.date.length >= 10 ? e.date.substring(0, 10) : e.date;
      final dr = e.debit > 0 ? '$cur${e.debit.toStringAsFixed(2)}' : '-';
      final cr = e.credit > 0 ? '$cur${e.credit.toStringAsFixed(2)}' : '-';
      final bal = '$cur${e.runningBalance.toStringAsFixed(2)}';
      buffer.writeln('$date\t${e.refNo}\t${e.description}\t$dr\t$cr\t$bal');
    }
    buffer.writeln('========================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account statement copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  String _formatPeriod() {
    final df = DateFormat('dd MMM yyyy');
    if (_dateFilter == 'today') return 'Today (${df.format(DateTime.now())})';
    if (_dateFilter == 'month') return 'This Month (${DateFormat('MMMM yyyy').format(DateTime.now())})';
    if (_dateFilter == '30days') return 'Last 30 Days';
    if (_dateFilter == 'custom' && _startDate != null && _endDate != null) {
      return '${df.format(_startDate!)} to ${df.format(_endDate!)}';
    }
    return 'All Records';
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.settings.currencySymbol;
    final acc = _currentAccount ?? widget.account;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCash = acc.accountType.toLowerCase() == 'cash';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 1050,
        height: 720,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Header Bar
            _buildHeader(acc, cur, isDark, isCash),

            // 2. Filter & Actions Toolbar
            _buildToolbar(isDark),

            // 3. KPI Summary Cards
            _buildKpiSummary(cur, isDark),

            // 4. Ledger Data Table
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildEntriesTable(cur, isDark),
            ),

            // 5. Footer
            _buildFooter(cur, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PaymentAccount acc, String cur, bool isDark, bool isCash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isCash ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCash ? Icons.point_of_sale_rounded : Icons.account_balance_rounded,
              color: isCash ? const Color(0xFF059669) : const Color(0xFF0284C7),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      acc.name,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isCash ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isCash ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        acc.accountType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCash ? const Color(0xFF059669) : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  acc.accountNumber.isNotEmpty
                      ? 'A/C Number: ${acc.accountNumber}  •  ${acc.note.isNotEmpty ? acc.note : "Bank & Liquid Asset Passbook"}'
                      : 'Liquid Cash Drawer & Float Account',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, size: 22),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : const Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF243247) : const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          _filterChip('all', 'All Time', Icons.all_inclusive_rounded),
          const SizedBox(width: 6),
          _filterChip('today', 'Today', Icons.today_rounded),
          const SizedBox(width: 6),
          _filterChip('month', 'This Month', Icons.calendar_view_month_rounded),
          const SizedBox(width: 6),
          _filterChip('30days', 'Last 30 Days', Icons.history_rounded),
          const SizedBox(width: 6),
          _filterChip('custom', _dateFilter == 'custom' ? _formatPeriod() : 'Custom Range', Icons.date_range_rounded,
              isCustomPicker: true),
          const Spacer(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: const Text('Copy Statement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: _copyStatementToClipboard,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, IconData icon, {bool isCustomPicker = false}) {
    final isSelected = _dateFilter == id;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        if (isCustomPicker) {
          _selectCustomDateRange();
        } else {
          _applyDateFilter(id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSummary(String cur, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _kpiItem(
            'OPENING BALANCE',
            '$cur${_openingBalance.toStringAsFixed(2)}',
            const Color(0xFF64748B),
            Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(width: 14),
          _kpiItem(
            'TOTAL INFLOW (DEPOSITS)',
            '+$cur${_totalInflow.toStringAsFixed(2)}',
            const Color(0xFF10B981),
            Icons.arrow_downward_rounded,
          ),
          const SizedBox(width: 14),
          _kpiItem(
            'TOTAL OUTFLOW (WITHDRAWALS)',
            '-$cur${_totalOutflow.toStringAsFixed(2)}',
            const Color(0xFFEF4444),
            Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 14),
          _kpiItem(
            'CURRENT CLOSING BALANCE',
            '$cur${_closingBalance.toStringAsFixed(2)}',
            const Color(0xFF0284C7),
            Icons.check_circle_outline_rounded,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _kpiItem(String title, String value, Color color, IconData icon, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlight ? color.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            'No transactions recorded for this period',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inflows and outflows for this account will appear here.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesTable(String cur, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF131D31) : const Color(0xFFF1F5F9)),
          horizontalMargin: 20,
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(label: Text('REF / VOUCHER #', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(label: Text('DESCRIPTION / PARTICULARS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(label: Text('METHOD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(numeric: true, label: Text('DEBIT (INFLOW)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(numeric: true, label: Text('CREDIT (OUTFLOW)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
            DataColumn(numeric: true, label: Text('BALANCE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
          ],
          rows: _entries.map((e) {
            final isDr = e.debit > 0;
            final isCr = e.credit > 0;

            return DataRow(
              cells: [
                DataCell(Text(
                  e.date.length >= 16 ? e.date.substring(0, 16) : e.date,
                  style: const TextStyle(fontSize: 12),
                )),
                DataCell(Text(
                  e.refNo.isNotEmpty ? e.refNo : '-',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                )),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      e.description,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                )),
                DataCell(Text(
                  isDr ? '+$cur${e.debit.toStringAsFixed(2)}' : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isDr ? FontWeight.bold : FontWeight.normal,
                    color: isDr ? const Color(0xFF10B981) : Colors.grey,
                  ),
                )),
                DataCell(Text(
                  isCr ? '-$cur${e.credit.toStringAsFixed(2)}' : '-',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCr ? FontWeight.bold : FontWeight.normal,
                    color: isCr ? const Color(0xFFEF4444) : Colors.grey,
                  ),
                )),
                DataCell(Text(
                  '$cur${e.runningBalance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFooter(String cur, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_entries.length} transaction entries  •  Standard Double-Entry Ledger Passbook',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close Passbook', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
