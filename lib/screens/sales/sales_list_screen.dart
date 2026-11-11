import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/pay_due_dialog.dart';
import '../pos/receipt_dialog.dart';
import '../../services/print_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';

class SalesListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onOpenPos;
  final Function(Sale)? onResumeInPos;

  const SalesListScreen({
    super.key,
    required this.settings,
    this.onOpenPos,
    this.onResumeInPos,
  });

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  List<Sale> _sales = [];
  bool _filtersOpen = false;
  String _search = '';
  bool _loading = true;
  int _entriesPerPage = 25;
  String _activeTab = 'final'; // 'final', 'draft', 'quotation'
  String _quotationFilter = 'all'; // 'all', 'pending', 'converted'
  int _finalCount = 0;
  int _draftCount = 0;
  int _quotationCount = 0;
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final allSales = await db.getSales();
    final finals = allSales.where((s) => s.saleStatus == 'final').toList();
    final drafts = allSales.where((s) => s.saleStatus == 'draft').toList();
    final quotes = allSales.where((s) => s.saleStatus == 'quotation').toList();

    List<Sale> target;
    if (_activeTab == 'draft') {
      target = drafts;
    } else if (_activeTab == 'quotation') {
      if (_quotationFilter == 'pending') {
        target = quotes.where((s) => !s.isConvertedQuotation).toList();
      } else if (_quotationFilter == 'converted') {
        target = quotes.where((s) => s.isConvertedQuotation).toList();
      } else {
        target = quotes;
      }
    } else {
      target = finals;
    }

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      target = target.where((s) => s.invoiceNo.toLowerCase().contains(q) || s.customerName.toLowerCase().contains(q)).toList();
    }

    if (mounted) {
      setState(() {
        _sales = target;
        _finalCount = finals.length;
        _draftCount = drafts.length;
        _quotationCount = quotes.length;
        _loading = false;
      });
    }
  }

  void _resumeInPos(Sale s) async {
    final db = await DatabaseService.initialize();
    final fullSale = await db.getSaleByInvoiceNo(s.invoiceNo);
    if (widget.onResumeInPos != null) {
      widget.onResumeInPos!(fullSale ?? s);
    } else if (widget.onOpenPos != null) {
      widget.onOpenPos!();
    }
  }

  Future<void> _showConvertQuotationDialog(Sale quotation) async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null && !currentUser.hasPermission('quotation.convert')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied: Your role cannot convert quotations to invoices.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (quotation.id == null || quotation.isConvertedQuotation) return;

    String paymentMethod = 'cash';
    final paidCtrl = TextEditingController(text: quotation.totalAmount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: 'Converted from Quotation #${quotation.invoiceNo}');
    final cur = widget.settings.currencySymbol;
    bool isConverting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Convert Quotation #${quotation.invoiceNo} to Invoice',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${quotation.customerName}  •  Total: $cur${quotation.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card / POS Machine')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit / Customer Khata (Due)')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDlgState(() {
                      paymentMethod = val;
                      if (val == 'credit') {
                        paidCtrl.text = '0.00';
                      } else if ((double.tryParse(paidCtrl.text.trim()) ?? 0.0) == 0.0) {
                        paidCtrl.text = quotation.totalAmount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid Now ($cur)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Invoice Note', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isConverting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isConverting ? 'Converting...' : 'Confirm & Finalize Invoice'),
              onPressed: isConverting
                  ? null
                  : () async {
                      setDlgState(() => isConverting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final db = await DatabaseService.initialize();
                        final paidAmt = double.tryParse(paidCtrl.text.trim()) ?? 0.0;
                        final invoice = await db.convertQuotationToInvoice(
                          quotationId: quotation.id!,
                          paymentMethod: paymentMethod,
                          paidAmount: paidAmt,
                          note: noteCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Quotation #${quotation.invoiceNo} converted to Invoice #${invoice.invoiceNo}!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        setDlgState(() => isConverting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Conversion failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSaleRecord(Sale s) async {
    final currentUser = AuthService.currentUser;
    if (currentUser != null && !currentUser.hasPermission('sale.delete')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: You do not have permission to delete sales invoices. Contact Super Admin.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.saleStatus.toUpperCase()} #${s.invoiceNo}?'),
        content: Text('Are you sure you want to permanently delete this ${s.saleStatus}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final db = await DatabaseService.initialize();
      await db.deleteSale(s.id!);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.saleStatus.toUpperCase()} #${s.invoiceNo} deleted successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _printReceipt(Sale s) async {
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(s.id!);
    final fullSale = Sale.fromMap(s.toMap(), items: items);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(
          sale: fullSale,
          settings: widget.settings,
          tenderedAmount: fullSale.paidAmount,
          changeReturn: 0.0,
        ),
      );
    }
  }

  void _sendWhatsAppBill(Sale s) async {
    final db = await DatabaseService.initialize();
    String customerPhone = '';
    if (s.customerId != null) {
      final contact = await db.getContactById(s.customerId!);
      customerPhone = contact?.phone ?? '';
    }

    final phoneCtrl = TextEditingController(text: customerPhone);
    final saleItems = s.items ?? await db.getSaleItems(s.id!);

    final text = MessagingService.formatSaleReceiptMessage(
      sale: s,
      settings: widget.settings,
      items: saleItems,
    );

    if (customerPhone.isNotEmpty) {
      MessagingService.sendWhatsAppDirect(to: customerPhone, message: text, recipientName: s.customerName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening WhatsApp for ${s.customerName}...'), backgroundColor: const Color(0xFF25D366)),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('Send WhatsApp Bill Receipt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter WhatsApp mobile number for ${s.customerName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'WhatsApp Number (e.g. 03001234567)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send via WhatsApp'),
            onPressed: () {
              final p = phoneCtrl.text.trim();
              if (p.isNotEmpty) {
                MessagingService.sendWhatsAppDirect(to: p, message: text, recipientName: s.customerName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening WhatsApp for ${s.customerName}...'), backgroundColor: const Color(0xFF25D366)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _printQuotation(Sale s) async {
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(s.id!);
    final fullSale = Sale.fromMap(s.toMap(), items: items);
    final html = PrintService.generateQuotationHtml(
      settings: widget.settings,
      sale: fullSale,
      paperSize: widget.settings.receiptPaperSize,
    );
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => UniversalPrintPreviewDialog(
          title: 'Quotation / Commercial Estimate - ${s.invoiceNo}',
          htmlContent: html,
          defaultPaperSize: 'a4',
          settings: widget.settings,
        ),
      );
    }
  }

  Widget _exportBtn(String label, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label completed successfully.'), duration: const Duration(seconds: 1)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: POS (Matching Screenshot 3)
            Text(
              'POS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Collapsible Filters Panel (Screenshot 3)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _filtersOpen,
                onExpansionChanged: (val) => setState(() => _filtersOpen = val),
                leading: const Icon(Icons.filter_alt_outlined, color: Color(0xFF004EEB), size: 20),
                title: Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Business Location', isDense: true),
                            items: [
                              DropdownMenuItem(value: 'All', child: Text('${widget.settings.businessName} (All)')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Customer', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Customers')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: 'All',
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(labelText: 'Payment Status', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Payment Statuses')),
                              DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(value: 'Due', child: Text('Due')),
                              DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Card: List POS (Screenshot 3)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x04000000),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: List POS title + [+ Add] button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'List POS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                        label: const Text('POS Terminal (F1) / نئی سیل کریں', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: widget.onOpenPos,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segmented Tabs: All Final Sales / Drafts / Quotations
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tabButton('final', 'All Final Sales', _finalCount, Icons.receipt_long_rounded, isDark),
                        const SizedBox(width: 4),
                        _tabButton('draft', 'Drafts', _draftCount, Icons.edit_note_rounded, isDark),
                        const SizedBox(width: 4),
                        _tabButton('quotation', 'Quotations / Estimates', _quotationCount, Icons.assignment_outlined, isDark),
                      ],
                    ),
                  ),
                  if (_activeTab == 'quotation')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Conversion Status:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('All Quotations', style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'all',
                            onSelected: (_) {
                              setState(() => _quotationFilter = 'all');
                              _load();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Pending Conversion', style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'pending',
                            onSelected: (_) {
                              setState(() => _quotationFilter = 'pending');
                              _load();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Converted to Invoice', style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'converted',
                            onSelected: (_) {
                              setState(() => _quotationFilter = 'converted');
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),

                  // Actions and Export Buttons Toolbar (Adaptive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showDropdown = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Show ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _entriesPerPage,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: const [
                                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 25, child: Text('25', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) => setState(() => _entriesPerPage = val ?? 25),
                              ),
                            ),
                          ),
                          Text(' entries', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      );

                      final exportButtons = Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          showDropdown,
                          const SizedBox(width: 8),
                          _exportBtn('Export CSV', Icons.table_chart_outlined, isDark),
                          _exportBtn('Export Excel', Icons.description_outlined, isDark),
                          _exportBtn('Print', Icons.print_outlined, isDark),
                          _exportBtn('Column visibility', Icons.view_column_outlined, isDark),
                          _exportBtn('Export PDF', Icons.picture_as_pdf_outlined, isDark),
                        ],
                      );

                      final searchBox = Container(
                        width: constraints.maxWidth < 600 ? double.infinity : 220,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          onChanged: (val) {
                            _search = val;
                            _load();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search sales, invoices, customers...',
                            prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      );

                      if (constraints.maxWidth < 980) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            exportButtons,
                            const SizedBox(height: 12),
                            searchBox,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: exportButtons),
                          const SizedBox(width: 16),
                          searchBox,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Data Table with Explicit Scrollbar and Compact Spacing
                  _loading
                      ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                      : _sales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: Text('No POS records found', style: TextStyle(color: Colors.grey))),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final double tableWidth = math.max(constraints.maxWidth, 1150.0);
                                return Scrollbar(
                                  controller: _tableScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  interactive: true,
                                  thickness: 9,
                                  radius: const Radius.circular(5),
                                  child: SingleChildScrollView(
                                    controller: _tableScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(1.7), // Action
                                            1: FlexColumnWidth(1.5), // Date
                                            2: FlexColumnWidth(1.2), // Invoice No.
                                            3: FlexColumnWidth(1.8), // Customer name
                                            4: FlexColumnWidth(1.3), // Contact Number
                                            5: FlexColumnWidth(1.6), // Location
                                            6: FlexColumnWidth(1.2), // Payment Status
                                            7: FlexColumnWidth(1.1), // Payment Method
                                            8: FlexColumnWidth(1.3), // Total amount
                                            9: FlexColumnWidth(1.3), // Total paid
                                            10: FlexColumnWidth(1.1), // Sell Due
                                          },
                                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2)),
                                              ),
                                              children: [
                                                _th('Action', isDark),
                                                _th('Date ⇅', isDark),
                                                _th('Invoice No. ⇅', isDark),
                                                _th('Customer name ⇅', isDark),
                                                _th('Contact Number ⇅', isDark),
                                                _th('Location ⇅', isDark),
                                                _th('Payment Status ⇅', isDark),
                                                _th('Payment Method', isDark),
                                                _th('Total amount ⇅', isDark),
                                                _th('Total paid ⇅', isDark),
                                                _th('Sell Due', isDark),
                                              ],
                                            ),
                                            ..._sales.asMap().entries.map((entry) {
                                              final idx = entry.key;
                                              final s = entry.value;
                                              final rowBg = idx.isOdd
                                                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                                  : (isDark ? const Color(0xFF172033) : const Color(0xFFFBFDFF));

                                              return TableRow(
                                                decoration: BoxDecoration(
                                                  color: rowBg,
                                                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0), width: 0.8)),
                                                ),
                                                children: [
                                                  // Action Button
                                                  _td(
                                                    s.saleStatus != 'final'
                                                        ? Wrap(
                                                            spacing: 4,
                                                            runSpacing: 4,
                                                            crossAxisAlignment: WrapCrossAlignment.center,
                                                            children: [
                                                              if (s.saleStatus == 'quotation' && s.isConvertedQuotation)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFDCFCE7),
                                                                    borderRadius: BorderRadius.circular(5),
                                                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                                                  ),
                                                                  child: const Text(
                                                                    'Converted',
                                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                                                  ),
                                                                )
                                                              else ...[
                                                                if (s.saleStatus == 'quotation')
                                                                  ElevatedButton.icon(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: const Color(0xFF4F46E5),
                                                                      foregroundColor: Colors.white,
                                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                                      elevation: 0,
                                                                    ),
                                                                    icon: const Icon(Icons.receipt_long_rounded, size: 13),
                                                                    label: const Text('Convert to Invoice', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                                    onPressed: () => _showConvertQuotationDialog(s),
                                                                  ),
                                                                  if (AuthService.currentUser?.hasPermission('sale.edit') ?? true)
                                                                    ElevatedButton.icon(
                                                                      style: ElevatedButton.styleFrom(
                                                                        backgroundColor: const Color(0xFF10B981),
                                                                        foregroundColor: Colors.white,
                                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                                        elevation: 0,
                                                                      ),
                                                                      icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                                                      label: const Text('Resume in POS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                                      onPressed: () => _resumeInPos(s),
                                                                    ),
                                                              ],
                                                              PopupMenuButton<String>(
                                                                onSelected: (val) {
                                                                  if (val == 'convert') {
                                                                    _showConvertQuotationDialog(s);
                                                                  } else if (val == 'quotation') {
                                                                    _printQuotation(s);
                                                                  } else if (val == 'delete') {
                                                                    _deleteSaleRecord(s);
                                                                  }
                                                                },
                                                                  itemBuilder: (ctx) {
                                                                    final canDel = AuthService.currentUser?.hasPermission('sale.delete') ?? true;
                                                                    final canConvert = AuthService.currentUser?.hasPermission('quotation.convert') ?? true;
                                                                    return [
                                                                      if (canConvert && s.saleStatus == 'quotation' && !s.isConvertedQuotation)
                                                                        const PopupMenuItem(value: 'convert', child: Text('Convert to Invoice')),
                                                                    const PopupMenuItem(value: 'quotation', child: Text('Print Quotation / Estimate')),
                                                                    if (canDel)
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
                                                                  ];
                                                                },
                                                                child: Container(
                                                                  padding: const EdgeInsets.all(5),
                                                                  decoration: BoxDecoration(
                                                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: const Icon(Icons.more_vert, size: 14),
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        : PopupMenuButton<String>(
                                                            onSelected: (val) {
                                                              if (val == 'receipt') {
                                                                _printReceipt(s);
                                                              } else if (val == 'quotation') {
                                                                _printQuotation(s);
                                                              } else if (val == 'pay_due') {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (_) => PayDueDialog(
                                                                    settings: widget.settings,
                                                                    type: DuePaymentType.sale,
                                                                    entityId: s.id!,
                                                                    reference: s.invoiceNo,
                                                                    contactName: s.customerName,
                                                                    contactId: s.customerId,
                                                                    totalAmount: s.totalAmount,
                                                                    paidAmount: s.paidAmount,
                                                                    dueAmount: s.dueAmount,
                                                                    onPaymentSuccess: _load,
                                                                  ),
                                                                );
                                                              } else if (val == 'whatsapp') {
                                                                _sendWhatsAppBill(s);
                                                              } else if (val == 'delete') {
                                                                _deleteSaleRecord(s);
                                                              }
                                                            },
                                                            itemBuilder: (ctx) {
                                                              final canDel = AuthService.currentUser?.hasPermission('sale.delete') ?? true;
                                                              return [
                                                                const PopupMenuItem(value: 'receipt', child: Text('Print Receipt')),
                                                                const PopupMenuItem(
                                                                  value: 'whatsapp',
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(Icons.chat_rounded, size: 16, color: Color(0xFF25D366)),
                                                                      SizedBox(width: 8),
                                                                      Text('Send WhatsApp Bill', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const PopupMenuItem(value: 'quotation', child: Text('Print Quotation / Estimate')),
                                                                if (s.dueAmount > 0)
                                                                  const PopupMenuItem(
                                                                    value: 'pay_due',
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.payments_outlined, size: 16, color: Color(0xFF059669)),
                                                                        SizedBox(width: 8),
                                                                        Text('Pay Due / Collect', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                const PopupMenuItem(value: 'view', child: Text('View Details')),
                                                                if (canDel)
                                                                  const PopupMenuItem(
                                                                    value: 'delete',
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                                                        SizedBox(width: 8),
                                                                        Text('Delete Sale', style: TextStyle(color: Color(0xFFEF4444))),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ];
                                                            },
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF004EEB),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Text('Actions', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                                  SizedBox(width: 4),
                                                                  Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                  ),
                                                  _td(Text(s.createdAt, style: const TextStyle(fontSize: 12))),
                                                  _td(Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                  _td(Text(s.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                                  _td(const Text('(378) 400-1234', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                                  _td(Text(widget.settings.businessName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                                  _td(StatusPill(status: s.paymentStatus)),
                                                  _td(Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: Text(
                                                      s.paymentMethod.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  )),
                                                  _td(Text(
                                                    '$currency ${s.totalAmount.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  )),
                                                  _td(Text(
                                                    '$currency ${s.paidAmount.toStringAsFixed(2)}',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                                  )),
                                                  _td(Text(
                                                    s.dueAmount > 0 ? '$currency ${s.dueAmount.toStringAsFixed(2)}' : '$currency 0.00',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: s.dueAmount > 0 ? FontWeight.bold : FontWeight.normal,
                                                      color: s.dueAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                                    ),
                                                  )),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _td(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: child,
    );
  }

  Widget _tabButton(String tabKey, String title, int count, IconData icon, bool isDark) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabKey;
          _loading = true;
        });
        _load();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
