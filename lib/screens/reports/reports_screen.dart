import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/print_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/ai_assistant_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';
import '../pos/pos_power_dialogs.dart';
import '../products/product_detail_dialog.dart';

class ReportsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ReportsScreen({super.key, required this.settings});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  String _dateFilter = 'month'; // 'today', 'yesterday', 'week', 'month', 'year', 'custom'
  DateTime? _startDate;
  DateTime? _endDate;

  Map<String, dynamic> _report = {};
  Map<String, dynamic> _quotationStats = {};
  List<Product> _lowStock = [];
  List<ActivityLogEntry> _activityLogs = [];
  String _activityEntityFilter = 'All';
  String _activityActionFilter = 'All';
  final TextEditingController _activitySearchCtrl = TextEditingController();

  // Register Shifts State
  List<Map<String, dynamic>> _registerReports = [];
  String _registerStatusFilter = 'all'; // 'all', 'open', 'closed'
  final TextEditingController _registerSearchCtrl = TextEditingController();

  // Stock Expiry State
  List<Map<String, dynamic>> _stockExpiryReports = [];
  String _stockExpiryFilter = 'all'; // 'all', 'expired', '30_days', '60_days', '90_days'
  final TextEditingController _stockExpirySearchCtrl = TextEditingController();

  // Trending Products State
  String _trendingSort = 'qty'; // 'qty' or 'rev'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
    _applyFilter('month');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activitySearchCtrl.dispose();
    _registerSearchCtrl.dispose();
    _stockExpirySearchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(String filter) {
    _dateFilter = filter;
    final now = DateTime.now();

    if (filter == 'today') {
      _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (filter == 'yesterday') {
      final y = now.subtract(const Duration(days: 1));
      _startDate = DateTime(y.year, y.month, y.day, 0, 0, 0);
      _endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
    } else if (filter == 'week') {
      _startDate = now.subtract(const Duration(days: 7));
      _endDate = now;
    } else if (filter == 'month') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (filter == 'year') {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    }

    _load();
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
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await DatabaseService.initialize();

    final rep = await db.getComprehensiveBusinessReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    final ls = await db.getLowStockProducts();
    final regRep = await db.getRegisterReport(
      startDate: _startDate,
      endDate: _endDate,
      status: _registerStatusFilter,
      cashierName: _registerSearchCtrl.text.trim(),
    );
    final expRep = await db.getStockExpiryReport(
      filter: _stockExpiryFilter,
      searchQuery: _stockExpirySearchCtrl.text.trim(),
    );
    final qStats = await db.getQuotationConversionStats();
    final actLogs = await db.getActivityLogs(
      limit: 200,
      entityType: _activityEntityFilter,
      action: _activityActionFilter,
      search: _activitySearchCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _report = rep;
        _quotationStats = qStats;
        _lowStock = ls;
        _registerReports = regRep;
        _stockExpiryReports = expRep;
        _activityLogs = actLogs;
        _loading = false;
      });
    }
  }

  Future<void> _reloadActivityLogs() async {
    final db = await DatabaseService.initialize();
    final actLogs = await db.getActivityLogs(
      limit: 200,
      entityType: _activityEntityFilter,
      action: _activityActionFilter,
      search: _activitySearchCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _activityLogs = actLogs);
    }
  }

  Future<void> _reloadRegisters() async {
    final db = await DatabaseService.initialize();
    final regRep = await db.getRegisterReport(
      startDate: _startDate,
      endDate: _endDate,
      status: _registerStatusFilter,
      cashierName: _registerSearchCtrl.text.trim(),
    );
    if (mounted) setState(() => _registerReports = regRep);
  }

  Future<void> _reloadStockExpiry() async {
    final db = await DatabaseService.initialize();
    final expRep = await db.getStockExpiryReport(
      filter: _stockExpiryFilter,
      searchQuery: _stockExpirySearchCtrl.text.trim(),
    );
    if (mounted) setState(() => _stockExpiryReports = expRep);
  }

  String _formatPeriod() {
    final df = DateFormat('dd MMM yyyy');
    if (_dateFilter == 'today') return 'Today (${df.format(DateTime.now())})';
    if (_dateFilter == 'yesterday') return 'Yesterday';
    if (_dateFilter == 'week') return 'Last 7 Days';
    if (_dateFilter == 'month') return 'This Month (${DateFormat('MMMM yyyy').format(DateTime.now())})';
    if (_dateFilter == 'year') return 'This Financial Year (${DateTime.now().year})';
    if (_dateFilter == 'custom' && _startDate != null && _endDate != null) {
      return '${df.format(_startDate!)} to ${df.format(_endDate!)}';
    }
    return 'All Records';
  }

  void _copyFullReportSummary() {
    final cur = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    buffer.writeln('==============================================');
    buffer.writeln('${widget.settings.businessName.isNotEmpty ? widget.settings.businessName : "SMART POS"} - BUSINESS REPORT');
    buffer.writeln('Period: ${_formatPeriod()}');
    buffer.writeln('Generated On: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('==============================================');

    buffer.writeln('1. FINANCIAL PROFIT & LOSS:');
    buffer.writeln('Gross Sales: $cur${(_report['totalSales'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Cost of Goods Sold (COGS): $cur${(_report['cogs'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Gross Profit: $cur${(_report['grossProfit'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Operating Expenses: $cur${(_report['totalExpenses'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('NET PROFIT: $cur${(_report['netProfit'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------------');

    buffer.writeln('2. PURCHASES & INVENTORY:');
    buffer.writeln('Total Purchases: $cur${(_report['totalPurchases'] as double? ?? 0.0).toStringAsFixed(2)}');
    final sv = _report['stockValuation'] as Map<String, dynamic>? ?? {};
    buffer.writeln('Stock Valuation (Cost): $cur${(sv['stockValueCost'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Stock Valuation (Retail): $cur${(sv['stockValueRetail'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Potential Stock Margin: $cur${(sv['potentialProfit'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------------');

    buffer.writeln('3. TAX SUMMARY:');
    buffer.writeln('Output Tax (Sales): $cur${(_report['outputTax'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Input Tax (Purchases): $cur${(_report['inputTax'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Net Tax Payable: $cur${(_report['netTaxPayable'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('----------------------------------------------');

    buffer.writeln('4. RECEIVABLES & PAYABLES:');
    buffer.writeln('Total Customer Dues (Receivable): $cur${(_report['totalCustomerDue'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('Total Supplier Dues (Payable): $cur${(_report['totalSupplierPayable'] as double? ?? 0.0).toStringAsFixed(2)}');
    buffer.writeln('==============================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comprehensive Business Report copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _printExecutiveReport() {
    final periodStr = _startDate != null && _endDate != null
        ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} to ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
        : 'All-Time Financial Statement';
    final html = PrintService.generateReportHtml(
      settings: widget.settings,
      reportData: _report,
      period: periodStr,
      paperSize: widget.settings.receiptPaperSize,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Executive Financial & Business Report',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
        pdfGenerator: (_) => _buildExecutiveReportPdfBytes(),
      ),
    );
  }

  Future<Uint8List> _buildExecutiveReportPdfBytes() {
    final cur = widget.settings.currencySymbol;
    final periodStr = _startDate != null && _endDate != null
        ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} to ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
        : 'All-Time Financial Statement';
    final totalSales = (_report['totalSales'] as double?) ?? 0.0;
    final cogs = (_report['cogs'] as double?) ?? 0.0;
    final gross = (_report['grossProfit'] as double?) ?? 0.0;
    final expenses = (_report['totalExpenses'] as double?) ?? 0.0;
    final net = (_report['netProfit'] as double?) ?? 0.0;
    final purchases = (_report['totalPurchases'] as double?) ?? 0.0;
    final canProfit = AuthService.currentUser?.hasPermission('report.view_profit') ?? true;
    final canCost = AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true;

    return PdfExportService.generateReportPdf(
      title: 'Executive Financial & Business Report',
      subtitle: 'Period: $periodStr',
      settings: widget.settings,
      summaryMetrics: {
        'Total Sales': '$cur${totalSales.toStringAsFixed(2)}',
        'Total Purchases': '$cur${purchases.toStringAsFixed(2)}',
        'Expenses': '$cur${expenses.toStringAsFixed(2)}',
        'Net Profit': canProfit ? '$cur${net.toStringAsFixed(2)}' : 'Restricted',
      },
      headers: const ['Metric / Ledger Account', 'Amount'],
      rows: [
        ['Total Final Sales Revenue', '$cur${totalSales.toStringAsFixed(2)}'],
        ['Cost of Goods Sold (COGS)', canCost ? '$cur${cogs.toStringAsFixed(2)}' : 'Restricted'],
        ['Gross Profit', canProfit ? '$cur${gross.toStringAsFixed(2)}' : 'Restricted'],
        ['Total Operating Expenses', '$cur${expenses.toStringAsFixed(2)}'],
        ['Net Business Profit', canProfit ? '$cur${net.toStringAsFixed(2)}' : 'Restricted'],
        ['Total Purchases', '$cur${purchases.toStringAsFixed(2)}'],
        ['Customer Receivables (Due)', '$cur${((_report['totalCustomerDue'] as double?) ?? 0.0).toStringAsFixed(2)}'],
        ['Supplier Payables (Due)', '$cur${((_report['totalSupplierPayable'] as double?) ?? 0.0).toStringAsFixed(2)}'],
      ],
    );
  }

  Future<void> _exportExecutiveReportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await _buildExecutiveReportPdfBytes();
    final file = await PdfExportService.savePdfFile(bytes, 'Executive_Business_Report');
    await PdfExportService.openPdfFile(file);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Report PDF exported & opened: ${file.path}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _printRegisterReport() {
    final periodStr = _startDate != null && _endDate != null
        ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} to ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
        : 'All-Time Shifts';
    final html = PrintService.generateRegisterReportHtml(
      registers: _registerReports,
      settings: widget.settings,
      period: periodStr,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Cash Register Shifts Audit Report',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  void _printStockExpiryReport() {
    final html = PrintService.generateStockExpiryReportHtml(
      expiryItems: _stockExpiryReports,
      settings: widget.settings,
      filterLabel: _stockExpiryFilter,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Stock Expiry & Batch Traceability Report',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  void _showAiReportAnalysisModal() {
    bool analyzing = true;
    String aiResponse = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (analyzing && aiResponse.isEmpty) {
            AiAssistantService.explainBusinessReports(
              report: _report,
              expiries: _stockExpiryReports,
              lowStock: _lowStock,
              settings: widget.settings,
            ).then((res) {
              if (ctx.mounted) {
                setDlgState(() {
                  analyzing = false;
                  aiResponse = res;
                });
              }
            }).catchError((err) {
              if (ctx.mounted) {
                setDlgState(() {
                  analyzing = false;
                  aiResponse = 'Analysis error: $err';
                });
              }
            });
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7C3AED), size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Business Intelligence & Advisory',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Powered by Google Gemini / OpenAI - Executive Analysis in Roman Urdu',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              height: 480,
              child: analyzing
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF7C3AED)),
                          SizedBox(height: 16),
                          Text(
                            'AI is analyzing your store sales, margins, expenses, and batch expirations...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text('Generating executive Roman Urdu summary and strategic advice...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: SelectableText(
                          aiResponse,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
            ),
            actions: [
              if (!analyzing && aiResponse.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy to Clipboard'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: aiResponse));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('AI Summary copied to clipboard!'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalSales = (_report['totalSales'] as double?) ?? 0.0;
    final netProfit = (_report['netProfit'] as double?) ?? 0.0;
    final totalPurchases = (_report['totalPurchases'] as double?) ?? 0.0;
    final stockVal = _report['stockValuation'] as Map<String, dynamic>? ?? {};
    final stockCost = (stockVal['stockValueCost'] as double?) ?? 0.0;

    final user = AuthService.currentUser;
    if (user != null && !user.hasPermission('report.view')) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account does not have permission to view Business Intelligence, Profit/Loss, and Sales Reports. Please contact your Super Administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.analytics_rounded, color: Color(0xFF4F46E5), size: 28),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Business Intelligence & Advanced ERP Reports',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Multi-dimensional business analytics: Profit & Loss, Purchases, Sales, Taxes, Dues, and Stock Valuation.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF4F46E5),
                      onPressed: _load,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Ask AI Business Advisor', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAiReportAnalysisModal,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Executive Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _printExecutiveReport,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text('Export PDF Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _exportExecutiveReportPdf,
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                      label: const Text('Export / Copy Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _copyFullReportSummary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Date Range Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Text(
                    'Period: ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF334155)),
                  ),
                  const SizedBox(width: 6),
                  _filterBtn('today', 'Today'),
                  const SizedBox(width: 6),
                  _filterBtn('yesterday', 'Yesterday'),
                  const SizedBox(width: 6),
                  _filterBtn('week', 'Last 7 Days'),
                  const SizedBox(width: 6),
                  _filterBtn('month', 'This Month'),
                  const SizedBox(width: 6),
                  _filterBtn('year', 'This Year'),
                  const SizedBox(width: 6),
                  _filterBtn('custom', _dateFilter == 'custom' ? _formatPeriod() : 'Custom Date', isCustom: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatPeriod(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Top KPI Metric Cards
            Row(
              children: [
                _topKpi('TOTAL SALES REVENUE', '$cur${totalSales.toStringAsFixed(2)}', '${_report['invoiceCount'] ?? 0} Invoices', const Color(0xFF4F46E5), Icons.point_of_sale_rounded, isDark),
                const SizedBox(width: 14),
                _topKpi(
                  'NET PROFIT / LOSS',
                  (user?.hasPermission('report.view_profit') ?? true)
                      ? '$cur${netProfit.toStringAsFixed(2)}'
                      : 'Restricted',
                  (user?.hasPermission('report.view_profit') ?? true)
                      ? 'Gross Margin: $cur${((_report['grossProfit'] as double?) ?? 0.0).toStringAsFixed(2)}'
                      : 'Requires report.view_profit',
                  netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  Icons.trending_up_rounded,
                  isDark,
                ),
                const SizedBox(width: 14),
                _topKpi('TOTAL PURCHASES', '$cur${totalPurchases.toStringAsFixed(2)}', '${_report['poCount'] ?? 0} Purchase Orders', const Color(0xFFF59E0B), Icons.shopping_cart_checkout_rounded, isDark),
                const SizedBox(width: 14),
                _topKpi(
                  'INVENTORY ASSET VALUE',
                  (user?.hasPermission('report.view_cost_price') ?? true)
                      ? '$cur${stockCost.toStringAsFixed(2)}'
                      : 'Restricted',
                  '${(stockVal['totalQuantity'] as num?)?.toInt() ?? 0} Total Units',
                  const Color(0xFF0284C7),
                  Icons.inventory_2_rounded,
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Tab Bar (9 Multi-Dimensional Executive Reports)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Profit & Loss Statement'),
                Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Purchase & Sale Report'),
                Tab(icon: Icon(Icons.point_of_sale_rounded), text: 'Cash Register Shifts'),
                Tab(icon: Icon(Icons.event_busy_rounded), text: 'Stock Expiry & Batches'),
                Tab(icon: Icon(Icons.star_rounded), text: 'Trending Top Products'),
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock Valuation & Audit'),
                Tab(icon: Icon(Icons.pie_chart_outline_rounded), text: 'Expense Breakdown'),
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Tax / GST Report'),
                Tab(icon: Icon(Icons.people_alt_outlined), text: 'Customer & Supplier Dues'),
                Tab(icon: Icon(Icons.history_edu_rounded), text: 'Activity Log'),
              ],
            ),
            const SizedBox(height: 16),

            // 5. Tab Views
            _loading
                ? const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
                : SizedBox(
                    height: 640,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Profit & Loss Statement
                        _buildProfitAndLossTab(cur, isDark),

                        // Tab 2: Purchase & Sale Comparison
                        _buildPurchaseAndSaleTab(cur, isDark),

                        // Tab 3: Cash Register Shifts (Phase 5.1)
                        _buildRegisterShiftTab(cur, isDark),

                        // Tab 4: Stock Expiry & Batches (Phase 5.2)
                        _buildStockExpiryTab(cur, isDark),

                        // Tab 5: Trending Top Products (Phase 5.3)
                        _buildTrendingProductsTab(cur, isDark),

                        // Tab 6: Stock Valuation
                        _buildStockValuationTab(cur, isDark),

                        // Tab 7: Expense Breakdown
                        _buildExpenseBreakdownTab(cur, isDark),

                        // Tab 8: Tax Report
                        _buildTaxReportTab(cur, isDark),

                        // Tab 9: Customer & Supplier Dues
                        _buildContactDuesTab(cur, isDark),

                        // Tab 10: Activity Log / Audit Trail
                        _buildActivityLogTab(isDark),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _filterBtn(String id, String label, {bool isCustom = false}) {
    final isSelected = _dateFilter == id;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (isCustom) {
          _selectCustomDateRange();
        } else {
          _applyFilter(id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _topKpi(String label, String value, String sub, Color color, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 3),
                  Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== TAB 1: PROFIT & LOSS =====================
  Widget _buildProfitAndLossTab(String cur, bool isDark) {
    final canViewProfit = AuthService.currentUser?.hasPermission('report.view_profit') ?? true;
    final canViewCost = AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true;
    if (!canViewProfit) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Profit & Loss Statement is restricted. Requires "report.view_profit" permission.',
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final totalSales = (_report['totalSales'] as double?) ?? 0.0;
    final cogs = (_report['cogs'] as double?) ?? 0.0;
    final grossProfit = (_report['grossProfit'] as double?) ?? 0.0;
    final totalExpenses = (_report['totalExpenses'] as double?) ?? 0.0;
    final recovered = (_report['recoveredAmount'] as double?) ?? 0.0;
    final netProfit = (_report['netProfit'] as double?) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Comprehensive Profit & Loss Statement (${_formatPeriod()})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Accrual & Cash Integrated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _reportRow('Gross Sales Revenue (Final Invoices)', '$cur${totalSales.toStringAsFixed(2)}', isHeader: true),
          const Divider(),
          _reportRow(
            'Cost of Goods Sold (COGS based on purchase cost)',
            canViewCost ? '($cur${cogs.toStringAsFixed(2)})' : 'Restricted',
            color: Colors.red,
          ),
          const Divider(),
          _reportRow('Gross Profit (Revenue - COGS)', '$cur${grossProfit.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
          const Divider(),
          _reportRow('Total Operating Expenses', '($cur${totalExpenses.toStringAsFixed(2)})', color: Colors.red),
          const Divider(),
          _reportRow('Stock Adjustment Recoveries', '+$cur${recovered.toStringAsFixed(2)}', color: const Color(0xFF0284C7)),
          const Divider(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: netProfit >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: netProfit >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NET BUSINESS PROFIT / OPERATING MARGIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: netProfit >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B))),
                    const SizedBox(height: 2),
                    Text('Net Margin: ${totalSales > 0 ? ((netProfit / totalSales) * 100).toStringAsFixed(1) : "0.0"}%', style: TextStyle(fontSize: 11, color: netProfit >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C))),
                  ],
                ),
                Text(
                  '$cur${netProfit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: netProfit >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== TAB 2: PURCHASE & SALE =====================
  Widget _buildPurchaseAndSaleTab(String cur, bool isDark) {
    final totalSales = (_report['totalSales'] as double?) ?? 0.0;
    final paidSales = (_report['totalPaidSales'] as double?) ?? 0.0;
    final dueSales = (_report['totalDueSales'] as double?) ?? 0.0;

    final totalPurchases = (_report['totalPurchases'] as double?) ?? 0.0;
    final paidPurchases = (_report['totalPaidPurchases'] as double?) ?? 0.0;
    final duePurchases = (_report['totalDuePurchases'] as double?) ?? 0.0;

    final netTradeDifference = totalSales - totalPurchases;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Purchase & Sale Comparative Report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              // Sales Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SALES BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      const SizedBox(height: 12),
                      _miniPnl('Total Invoiced Sales', '$cur${totalSales.toStringAsFixed(2)}', isBold: true),
                      _miniPnl('Received / Paid Amount', '$cur${paidSales.toStringAsFixed(2)}', color: const Color(0xFF10B981)),
                      _miniPnl('Outstanding Sales Due', '$cur${dueSales.toStringAsFixed(2)}', color: const Color(0xFFEF4444)),
                      _miniPnl('Total Invoice Count', '${_report['invoiceCount'] ?? 0} invoices'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Purchases Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PURCHASES BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      const SizedBox(height: 12),
                      _miniPnl('Total Purchases (Stock)', '$cur${totalPurchases.toStringAsFixed(2)}', isBold: true),
                      _miniPnl('Paid to Suppliers', '$cur${paidPurchases.toStringAsFixed(2)}', color: const Color(0xFF10B981)),
                      _miniPnl('Supplier Due Payable', '$cur${duePurchases.toStringAsFixed(2)}', color: const Color(0xFFEF4444)),
                      _miniPnl('Total Purchase Orders', '${_report['poCount'] ?? 0} orders'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _reportRow('Sales vs Purchase Net Trade Difference', '$cur${netTradeDifference.toStringAsFixed(2)}', isBold: true, color: netTradeDifference >= 0 ? const Color(0xFF10B981) : Colors.red),
          const Divider(),
          _reportRow('Outstanding Trade Receivables (Customer Dues)', '$cur${dueSales.toStringAsFixed(2)}', color: const Color(0xFFEF4444)),
          const Divider(),
          _reportRow('Outstanding Trade Payables (Supplier Dues)', '$cur${duePurchases.toStringAsFixed(2)}', color: const Color(0xFFEF4444)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUOTATION -> INVOICE CONVERSION FUNNEL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _kpiBox('Total Quotations', '${_quotationStats['totalQuotations'] ?? 0}', const Color(0xFF0F172A)),
                    const SizedBox(width: 12),
                    _kpiBox('Converted Invoices', '${_quotationStats['convertedQuotations'] ?? 0}', const Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    _kpiBox('Pending Quotes', '${_quotationStats['pendingQuotations'] ?? 0}', const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _kpiBox(
                      'Conversion Rate',
                      '${((_quotationStats['conversionRate'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}%',
                      const Color(0xFF4F46E5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== TAB 3: CASH REGISTER & SHIFT AUDIT (PHASE 5.1) =====================
  Widget _buildRegisterShiftTab(String cur, bool isDark) {
    double totalCash = 0.0;
    double totalCard = 0.0;
    double totalClosing = 0.0;
    double totalVariance = 0.0;
    int openCount = 0;

    for (final r in _registerReports) {
      final status = (r['status'] as String?) ?? 'closed';
      final cash = (r['total_sales_cash'] as num?)?.toDouble() ?? 0.0;
      final card = (r['total_sales_card'] as num?)?.toDouble() ?? 0.0;
      final other = (r['total_sales_other'] as num?)?.toDouble() ?? 0.0;
      final closing = (r['closing_amount'] as num?)?.toDouble() ?? 0.0;
      final diff = (r['difference'] as num?)?.toDouble() ?? 0.0;

      totalCash += cash;
      totalCard += (card + other);
      if (status == 'open') {
        openCount++;
      } else {
        totalClosing += closing;
        totalVariance += diff;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header & Print
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cash Register Sessions & Shift Reconciliation Audit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('Auditing cashier shifts, drawer cash floats, and discrepancy reconciliation in ${_formatPeriod()}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print Shift Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _printRegisterReport,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: KPI Mini Cards
          Row(
            children: [
              _kpiBox('Total Shifts Audited', '${_registerReports.length} Shifts', const Color(0xFF4F46E5)),
              const SizedBox(width: 12),
              _kpiBox('Active Open Shifts', '$openCount Active', openCount > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B)),
              const SizedBox(width: 12),
              _kpiBox('Total Cash Sales', '$cur${totalCash.toStringAsFixed(2)}', const Color(0xFF047857)),
              const SizedBox(width: 12),
              _kpiBox('Total Digital / Card', '$cur${totalCard.toStringAsFixed(2)}', const Color(0xFF0284C7)),
              const SizedBox(width: 12),
              _kpiBox('Net Cash Variance', '${totalVariance >= 0 ? '+' : ''}$cur${totalVariance.toStringAsFixed(2)}', totalVariance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 14),

          // Row 3: Filter & Search Bar
          Row(
            children: [
              _statusChip('all', 'All Shifts (${_registerReports.length})', _registerStatusFilter == 'all', (val) {
                setState(() => _registerStatusFilter = val);
                _reloadRegisters();
              }),
              const SizedBox(width: 8),
              _statusChip('open', 'Open Shifts ($openCount)', _registerStatusFilter == 'open', (val) {
                setState(() => _registerStatusFilter = val);
                _reloadRegisters();
              }),
              const SizedBox(width: 8),
              _statusChip('closed', 'Closed Shifts (${_registerReports.length - openCount})', _registerStatusFilter == 'closed', (val) {
                setState(() => _registerStatusFilter = val);
                _reloadRegisters();
              }),
              const Spacer(),
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: _registerSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search Cashier Name...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _reloadRegisters(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Data Table
          Expanded(
            child: _registerReports.isEmpty
                ? const Center(child: Text('No cash register shifts logged for this period.'))
                : SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('# SHIFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('CASHIER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('SHIFT STARTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('SHIFT CLOSED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('OPENING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('CASH SALES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('CARD / OTHER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('TOTAL SALES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('COUNTED CASH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('VARIANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                        rows: _registerReports.map((r) {
                          final id = r['id'] ?? 0;
                          final cashier = (r['cashier_name'] as String?) ?? 'Unknown';
                          final status = (r['status'] as String?) ?? 'closed';
                          final openedAt = (r['opened_at'] as String?) ?? '-';
                          final closedAt = (r['closed_at'] as String?) ?? (status == 'open' ? 'Active' : '-');
                          final opening = (r['opening_amount'] as num?)?.toDouble() ?? 0.0;
                          final cash = (r['total_sales_cash'] as num?)?.toDouble() ?? 0.0;
                          final card = (r['total_sales_card'] as num?)?.toDouble() ?? 0.0;
                          final other = (r['total_sales_other'] as num?)?.toDouble() ?? 0.0;
                          final totalSales = (r['total_sales'] as num?)?.toDouble() ?? (cash + card + other);
                          final closing = (r['closing_amount'] as num?)?.toDouble() ?? 0.0;
                          final diff = (r['difference'] as num?)?.toDouble() ?? 0.0;

                          return DataRow(
                            cells: [
                              DataCell(Text('#$id', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                              DataCell(Text(cashier, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status == 'open' ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: status == 'open' ? const Color(0xFF047857) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(openedAt, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(closedAt, style: const TextStyle(fontSize: 11))),
                              DataCell(Text('$cur${opening.toStringAsFixed(2)}')),
                              DataCell(Text('$cur${cash.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold))),
                              DataCell(Text('$cur${(card + other).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF1E40AF)))),
                              DataCell(Text('$cur${totalSales.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900))),
                              DataCell(Text(status == 'closed' ? '$cur${closing.toStringAsFixed(2)}' : '--', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(
                                status == 'open'
                                    ? const Text('--')
                                    : Text(
                                        diff == 0.0
                                            ? 'Match'
                                            : (diff > 0 ? '+$cur${diff.toStringAsFixed(2)}' : '-$cur${(-diff).toStringAsFixed(2)}'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: diff == 0.0 ? const Color(0xFF10B981) : (diff > 0 ? const Color(0xFF047857) : const Color(0xFFEF4444)),
                                        ),
                                      ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'View Shift Z-Report / Reconciliation',
                                  icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF4F46E5)),
                                  onPressed: () => _showShiftZReport(r),
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
    );
  }

  // ===================== TAB 4: STOCK EXPIRY & BATCHES (PHASE 5.2) =====================
  Widget _buildStockExpiryTab(String cur, bool isDark) {
    int expiredCount = 0;
    int criticalCount = 0;
    int warningCount = 0;
    double costAtRisk = 0.0;

    for (final item in _stockExpiryReports) {
      final days = item['days_remaining'] as int?;
      final cost = (item['stock_value_cost'] as num?)?.toDouble() ?? 0.0;
      if (days != null) {
        if (days < 0) {
          expiredCount++;
          costAtRisk += cost;
        } else if (days <= 30) {
          criticalCount++;
          costAtRisk += cost;
        } else if (days <= 60) {
          warningCount++;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Expiry & Batch Traceability Report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('Track batches, expiry dates, and quarantined items with potential financial loss at risk.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print Expiry List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _printStockExpiryReport,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KPI Cards
          Row(
            children: [
              _kpiBox('Already Expired', '$expiredCount Products', const Color(0xFFDC2626)),
              const SizedBox(width: 12),
              _kpiBox('Expiring in ≤ 30 Days', '$criticalCount Products', const Color(0xFFEA580C)),
              const SizedBox(width: 12),
              _kpiBox('Expiring in 31-60 Days', '$warningCount Products', const Color(0xFFCA8A04)),
              const SizedBox(width: 12),
              _kpiBox('Cost Value at Risk', '$cur${costAtRisk.toStringAsFixed(2)}', const Color(0xFFDC2626)),
              const SizedBox(width: 12),
              _kpiBox('Monitored Batches', '${_stockExpiryReports.length} Items', const Color(0xFF0284C7)),
            ],
          ),
          const SizedBox(height: 14),

          // Filter bar
          Row(
            children: [
              _statusChip('all', 'All Tracked (${_stockExpiryReports.length})', _stockExpiryFilter == 'all', (val) {
                setState(() => _stockExpiryFilter = val);
                _reloadStockExpiry();
              }),
              const SizedBox(width: 6),
              _statusChip('expired', 'Already Expired', _stockExpiryFilter == 'expired', (val) {
                setState(() => _stockExpiryFilter = val);
                _reloadStockExpiry();
              }),
              const SizedBox(width: 6),
              _statusChip('30_days', 'Expiring in 30 Days', _stockExpiryFilter == '30_days', (val) {
                setState(() => _stockExpiryFilter = val);
                _reloadStockExpiry();
              }),
              const SizedBox(width: 6),
              _statusChip('60_days', 'Expiring in 60 Days', _stockExpiryFilter == '60_days', (val) {
                setState(() => _stockExpiryFilter = val);
                _reloadStockExpiry();
              }),
              const SizedBox(width: 6),
              _statusChip('90_days', 'Expiring in 90 Days', _stockExpiryFilter == '90_days', (val) {
                setState(() => _stockExpiryFilter = val);
                _reloadStockExpiry();
              }),
              const Spacer(),
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: _stockExpirySearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search Product, SKU, Batch...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _reloadStockExpiry(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table
          Expanded(
            child: _stockExpiryReports.isEmpty
                ? const Center(child: Text('No products matching expiry filter.'))
                : SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('SKU / BARCODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('PRODUCT NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('BATCH #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('EXPIRY DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('STATUS / DAYS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('STOCK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('UNIT COST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('COST AT RISK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                        rows: _stockExpiryReports.map((item) {
                          final pId = item['product_id'] as int? ?? 0;
                          final sku = (item['sku'] as String?) ?? '-';
                          final name = (item['product_name'] as String?) ?? 'Product';
                          final category = (item['category_name'] as String?) ?? 'General';
                          final batch = (item['batch_number'] as String?) ?? '-';
                          final exp = (item['expiry_date'] as String?) ?? '-';
                          final days = item['days_remaining'] as int?;
                          final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0.0;
                          final cost = (item['purchase_price'] as num?)?.toDouble() ?? 0.0;
                          final costAtRisk = (item['stock_value_cost'] as num?)?.toDouble() ?? (qty * cost);

                          Widget badge;
                          if (days == null) {
                            badge = const Text('--');
                          } else if (days < 0) {
                            badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFCA5A5))),
                              child: Text('EXPIRED (${-days}d ago)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            );
                          } else if (days <= 30) {
                            badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFDBA74))),
                              child: Text('CRITICAL ($days days)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                            );
                          } else if (days <= 60) {
                            badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFFDE047))),
                              child: Text('WARNING ($days days)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFCA8A04))),
                            );
                          } else {
                            badge = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFA7F3D0))),
                              child: Text('VALID ($days days)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            );
                          }

                          return DataRow(
                            cells: [
                              DataCell(Text(sku, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                              DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(category, style: const TextStyle(fontSize: 11))),
                              DataCell(Text(batch, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                              DataCell(Text(exp, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(badge),
                              DataCell(Text('${qty.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(
                                (AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true)
                                    ? '$cur${cost.toStringAsFixed(2)}'
                                    : 'Restricted',
                              )),
                              DataCell(Text(
                                (AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true)
                                    ? '$cur${costAtRisk.toStringAsFixed(2)}'
                                    : 'Restricted',
                                style: TextStyle(fontWeight: FontWeight.w900, color: (days != null && days <= 30) ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                              )),
                              DataCell(
                                IconButton(
                                  tooltip: 'View Product Details',
                                  icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF4F46E5)),
                                  onPressed: () => _viewProductDetails(pId),
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
    );
  }

  // ===================== TAB 5: TRENDING TOP PRODUCTS (ENHANCED PHASE 5.3) =====================
  Widget _buildTrendingProductsTab(String cur, bool isDark) {
    final rawList = List<Map<String, dynamic>>.from(_report['topSellingProducts'] as List<dynamic>? ?? []);

    // Sort according to _trendingSort
    if (_trendingSort == 'rev') {
      rawList.sort((a, b) {
        final revA = (a['revenue'] as num?)?.toDouble() ?? 0.0;
        final revB = (b['revenue'] as num?)?.toDouble() ?? 0.0;
        return revB.compareTo(revA);
      });
    } else {
      rawList.sort((a, b) {
        final qtyA = (a['quantity'] as num?)?.toDouble() ?? 0.0;
        final qtyB = (b['quantity'] as num?)?.toDouble() ?? 0.0;
        return qtyB.compareTo(qtyA);
      });
    }

    final maxVal = rawList.isEmpty
        ? 1.0
        : (_trendingSort == 'rev'
            ? ((rawList.first['revenue'] as num?)?.toDouble() ?? 1.0)
            : ((rawList.first['quantity'] as num?)?.toDouble() ?? 1.0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Selling & Trending Products Analysis', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text('Ranked performance in ${_formatPeriod()}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              // Segmented sorting toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _toggleBtn('qty', 'By Units Sold (Volume)', _trendingSort == 'qty', (val) => setState(() => _trendingSort = val)),
                    _toggleBtn('rev', 'By Revenue (Rs)', _trendingSort == 'rev', (val) => setState(() => _trendingSort = val)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: rawList.isEmpty
                ? const Center(child: Text('No sales records found for this period.'))
                : SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(label: Text('# RANK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('PRODUCT NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('SKU / BARCODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(label: Text('MARKET SHARE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('QUANTITY SOLD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          DataColumn(numeric: true, label: Text('TOTAL REVENUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                        rows: List.generate(rawList.length, (idx) {
                          final item = rawList[idx];
                          final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                          final rev = (item['revenue'] as num?)?.toDouble() ?? 0.0;
                          final currentVal = _trendingSort == 'rev' ? rev : qty;
                          final pct = maxVal > 0 ? (currentVal / maxVal).clamp(0.0, 1.0) : 0.0;

                          Color rankColor = isDark ? Colors.white38 : Colors.grey;
                          if (idx == 0) rankColor = const Color(0xFFF59E0B); // Gold
                          else if (idx == 1) rankColor = const Color(0xFF94A3B8); // Silver
                          else if (idx == 2) rankColor = const Color(0xFFD97706); // Bronze

                          return DataRow(
                            cells: [
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: rankColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: idx < 3 ? rankColor : (isDark ? Colors.white70 : Colors.black87)),
                                  ),
                                ),
                              ),
                              DataCell(Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(item['sku'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                              DataCell(
                                SizedBox(
                                  width: 140,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          valueColor: AlwaysStoppedAnimation<Color>(idx == 0 ? const Color(0xFF10B981) : const Color(0xFF4F46E5)),
                                          minHeight: 6,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text('${(pct * 100).toStringAsFixed(1)}% of top seller', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(Text('${qty.toInt()} units', style: TextStyle(fontWeight: FontWeight.bold, color: _trendingSort == 'qty' ? const Color(0xFF4F46E5) : null))),
                              DataCell(Text('$cur${rev.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: _trendingSort == 'rev' ? const Color(0xFF10B981) : null))),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showShiftZReport(Map<String, dynamic> r) {
    final reg = CashRegister.fromMap(r);
    showDialog(
      context: context,
      builder: (_) => RegisterReportDialog(
        isZReport: reg.status == 'closed',
        register: reg,
        settings: widget.settings,
        actualCash: reg.closingAmount > 0 ? reg.closingAmount : null,
        closeNote: reg.note,
      ),
    );
  }

  Future<void> _viewProductDetails(int productId) async {
    final db = await DatabaseService.initialize();
    final p = await db.getProductById(productId);
    if (p != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => ProductDetailDialog(
          product: p,
          settings: widget.settings,
        ),
      );
    }
  }

  Widget _statusChip(String val, String label, bool isSelected, Function(String) onSelect) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onSelect(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _toggleBtn(String val, String label, bool isSelected, Function(String) onSelect) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onSelect(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ===================== TAB 4: STOCK VALUATION & AUDIT =====================
  Widget _buildStockValuationTab(String cur, bool isDark) {
    final canViewCost = AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true;
    final canViewProfit = AuthService.currentUser?.hasPermission('report.view_profit') ?? true;
    final sv = _report['stockValuation'] as Map<String, dynamic>? ?? {};
    final totalUnits = (sv['totalQuantity'] as num?)?.toDouble() ?? 0.0;
    final stockCost = (sv['stockValueCost'] as double?) ?? 0.0;
    final stockRetail = (sv['stockValueRetail'] as double?) ?? 0.0;
    final potentialProfit = (sv['potentialProfit'] as double?) ?? 0.0;
    final costLabel = canViewCost ? '$cur${stockCost.toStringAsFixed(2)}' : 'Restricted';
    final profitLabel = canViewProfit ? '$cur${potentialProfit.toStringAsFixed(2)}' : 'Restricted';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Valuation & Stock Audit Report', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _kpiBox('Total Stock Units', '${totalUnits.toInt()} units', const Color(0xFF004EEB)),
              const SizedBox(width: 12),
              _kpiBox('Stock Value by Cost', costLabel, const Color(0xFF64748B)),
              const SizedBox(width: 12),
              _kpiBox('Stock Value by Retail', '$cur${stockRetail.toStringAsFixed(2)}', const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _kpiBox('Potential Retail Margin', profitLabel, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 24),
          _reportRow('Inventory Valuation at Purchase Price (Asset)', costLabel, isHeader: true),
          const Divider(),
          _reportRow('Projected Realizable Value at Selling Price', '$cur${stockRetail.toStringAsFixed(2)}', isHeader: true),
          const Divider(),
          _reportRow('Estimated Unrealized Gross Margin', profitLabel, isBold: true, color: const Color(0xFF10B981)),
          const Divider(),
          _reportRow(
            'Margin Return on Inventory Investment',
            (canViewCost && canViewProfit)
                ? '${stockCost > 0 ? ((potentialProfit / stockCost) * 100).toStringAsFixed(1) : "0.0"}%'
                : 'Restricted',
          ),
          const Divider(),
          _reportRow('Products with Low Stock Alerts', '${_lowStock.length} items', color: _lowStock.isNotEmpty ? Colors.red : Colors.green),
        ],
      ),
    );
  }

  // ===================== TAB 5: EXPENSE BREAKDOWN =====================
  Widget _buildExpenseBreakdownTab(String cur, bool isDark) {
    final expList = _report['expenseCategories'] as List<dynamic>? ?? [];
    final totalExpenses = (_report['totalExpenses'] as double?) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Operating Expenses by Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('Total Expenses: $cur${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: expList.isEmpty
                ? const Center(child: Text('No expense records logged for this period.'))
                : ListView.separated(
                    itemCount: expList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = expList[idx] as Map<String, dynamic>;
                      final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                      final count = item['count'] as int? ?? 0;
                      final pct = totalExpenses > 0 ? (amt / totalExpenses) * 100 : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.money_off_rounded, color: Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['category'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text('$count vouchers  •  ${pct.toStringAsFixed(1)}% of total expenses', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            Text(
                              '$cur${amt.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===================== TAB 6: TAX / GST REPORT =====================
  Widget _buildTaxReportTab(String cur, bool isDark) {
    final outputTax = (_report['outputTax'] as double?) ?? 0.0;
    final inputTax = (_report['inputTax'] as double?) ?? 0.0;
    final netTaxPayable = (_report['netTaxPayable'] as double?) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tax / Sales Tax / VAT Summary', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _reportRow('Output Tax (Sales Tax Collected from Customers)', '$cur${outputTax.toStringAsFixed(2)}', isHeader: true),
          const Divider(),
          _reportRow('Input Tax (Sales Tax Paid on Supplier Purchases)', '($cur${inputTax.toStringAsFixed(2)})', color: const Color(0xFF10B981)),
          const Divider(),
          _reportRow('Net Tax Payable to Tax Authorities (Output - Input)', '$cur${netTaxPayable.toStringAsFixed(2)}', isBold: true, color: netTaxPayable >= 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Net Tax Payable is calculated according to standard tax regulations (Output Tax on Sales minus Input Tax credit on Purchases).',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== TAB 7: CONTACT DUES =====================
  Widget _buildContactDuesTab(String cur, bool isDark) {
    final custDue = (_report['totalCustomerDue'] as double?) ?? 0.0;
    final suppDue = (_report['totalSupplierPayable'] as double?) ?? 0.0;
    final topDebtors = _report['topDebtors'] as List<dynamic>? ?? [];
    final topCreditors = _report['topCreditors'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Debtors
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Top Customer Debtors (Receivables)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    Text('Total: $cur${custDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: topDebtors.isEmpty
                      ? const Center(child: Text('No outstanding customer receivables.'))
                      : ListView.separated(
                          itemCount: topDebtors.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final d = topDebtors[idx] as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(d['phone'] as String, style: const TextStyle(fontSize: 11)),
                              trailing: Text('$cur${(d['balance'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Supplier Creditors
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Top Supplier Creditors (Payables)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    Text('Total: $cur${suppDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: topCreditors.isEmpty
                      ? const Center(child: Text('No outstanding supplier payables.'))
                      : ListView.separated(
                          itemCount: topCreditors.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final c = topCreditors[idx] as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c['phone'] as String, style: const TextStyle(fontSize: 11)),
                              trailing: Text('$cur${(c['balance'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEF4444))),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String title, String val, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            val,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPnl(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _kpiBox(String title, String val, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogTab(bool isDark) {
    final canViewAudit = AuthService.currentUser?.hasPermission('report.view_audit_log') ?? true;
    if (!canViewAudit) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 42, color: Color(0xFFDC2626)),
              SizedBox(height: 10),
              Text('Access Restricted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Permission "report.view_audit_log" is required to inspect system audit trails.'),
            ],
          ),
        ),
      );
    }

    Color actionColor(String action) {
      switch (action.toLowerCase()) {
        case 'created':
          return const Color(0xFF10B981);
        case 'deleted':
          return const Color(0xFFEF4444);
        default:
          return const Color(0xFF3B82F6);
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Activity & Audit Trail', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(
                    'Immutable CRUD history across sales, quotations, products, contacts, roles, and settings (${_activityLogs.length} records)',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                onPressed: _reloadActivityLogs,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _activityEntityFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Entity Filter', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Entities', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'sale', child: Text('Sales', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'quotation', child: Text('Quotations', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'product', child: Text('Products', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'purchase', child: Text('Purchases', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'contact', child: Text('Contacts', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'customer_group', child: Text('Customer Groups', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'tax_group', child: Text('Tax Groups', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'user', child: Text('Users', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'role', child: Text('Roles & RBAC', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'business_settings', child: Text('Settings', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _activityEntityFilter = val);
                    _reloadActivityLogs();
                  },
                ),
              ),
              SizedBox(
                width: 185,
                child: DropdownButtonFormField<String>(
                  initialValue: _activityActionFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Action Filter', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Actions', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'created', child: Text('Created', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'updated', child: Text('Updated', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _activityActionFilter = val);
                    _reloadActivityLogs();
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _activitySearchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search actor / values',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reloadActivityLogs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _activityLogs.isEmpty
                ? const Center(
                    child: Text('No activity records matching filter.', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : ListView.separated(
                    itemCount: _activityLogs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, idx) {
                      final entry = _activityLogs[idx];
                      final badgeCol = actionColor(entry.action);
                      return ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeCol.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.action.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeCol),
                          ),
                        ),
                        title: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${entry.entityType}${entry.entityId != null ? " #${entry.entityId}" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'by ${entry.userName}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          entry.newValues ?? entry.oldValues ?? entry.createdAt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              entry.createdAt.length > 16 ? entry.createdAt.substring(0, 16) : entry.createdAt,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            if ((entry.oldValues != null && entry.oldValues!.isNotEmpty) ||
                                (entry.newValues != null && entry.newValues!.isNotEmpty))
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      title: Text(
                                        '${entry.action.toUpperCase()} ${entry.entityType} #${entry.entityId ?? ""}',
                                      ),
                                      content: SizedBox(
                                        width: 460,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Actor: ${entry.userName} (${entry.createdAt})'),
                                              const SizedBox(height: 10),
                                              if (entry.oldValues != null && entry.oldValues!.isNotEmpty) ...[
                                                const Text('Old Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                                                SelectableText(entry.oldValues!),
                                                const SizedBox(height: 8),
                                              ],
                                              if (entry.newValues != null && entry.newValues!.isNotEmpty) ...[
                                                const Text('New Values:', style: TextStyle(fontWeight: FontWeight.bold)),
                                                SelectableText(entry.newValues!),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dCtx),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Inspect Diff', style: TextStyle(fontSize: 11.5)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
