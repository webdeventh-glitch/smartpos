import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/messaging_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/data_table_pagination_bar.dart';
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
  List<BusinessLocation> _locations = [];
  List<Contact> _customers = [];
  Map<int, String> _locationNamesById = {};
  Map<int, String> _customerPhonesById = {};
  int? _selectedLocationId;
  int? _selectedCustomerId;
  String _selectedPaymentStatus = 'All';
  bool _showContactCol = true;
  bool _showLocationCol = true;
  bool _showMethodCol = true;
  bool _showPaidCol = true;
  bool _showDueCol = true;
  bool _filtersOpen = false;
  String _search = '';
  bool _loading = true;
  int _currentPage = 1;
  int _entriesPerPage = 25;
  int _totalFilteredCount = 0;
  String _activeTab = 'final'; // 'final', 'draft', 'quotation'
  String _quotationFilter = 'all'; // 'all', 'pending', 'converted'
  int _finalCount = 0;
  int _draftCount = 0;
  int _quotationCount = 0;
  Timer? _searchDebounce;
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshTabCounts = true}) async {
    final db = await DatabaseService.initialize();
    var paged = await db.getSalesPaged(
      status: _activeTab,
      search: _search,
      conversionFilter: _activeTab == 'quotation' ? _quotationFilter : 'all',
      locationId: _selectedLocationId,
      customerId: _selectedCustomerId,
      paymentStatus: _selectedPaymentStatus,
      page: _currentPage,
      pageSize: _entriesPerPage,
    );
    if (paged.items.isEmpty &&
        paged.totalCount > 0 &&
        _currentPage > paged.totalPages) {
      _currentPage = paged.totalPages;
      paged = await db.getSalesPaged(
        status: _activeTab,
        search: _search,
        conversionFilter: _activeTab == 'quotation' ? _quotationFilter : 'all',
        locationId: _selectedLocationId,
        customerId: _selectedCustomerId,
        paymentStatus: _selectedPaymentStatus,
        page: _currentPage,
        pageSize: _entriesPerPage,
      );
    }

    Map<String, int>? tabCounts;
    if (refreshTabCounts) {
      tabCounts = await db.getSalesTabCounts();
    }
    final locs =
        _locations.isEmpty ? await db.getBusinessLocations() : _locations;
    final custs = _customers.isEmpty
        ? await db.getContacts(type: 'customer')
        : _customers;

    if (mounted) {
      setState(() {
        _sales = paged.items;
        _totalFilteredCount = paged.totalCount;
        _locations = locs;
        _customers = custs;
        _locationNamesById = {
          for (final l in locs)
            if (l.id != null) l.id!: l.name,
        };
        _customerPhonesById = {
          for (final c in custs)
            if (c.id != null && c.phone.trim().isNotEmpty) c.id!: c.phone,
        };
        if (tabCounts != null) {
          _finalCount = tabCounts['final'] ?? 0;
          _draftCount = tabCounts['draft'] ?? 0;
          _quotationCount = tabCounts['quotation'] ?? 0;
        }
        _loading = false;
      });
    }
  }

  bool _isEditWindowLocked(Sale s) {
    if (s.saleStatus != 'final') return false;
    final editDays = widget.settings.transactionEditDays;
    if (editDays <= 0) return false;
    final created = DateTime.tryParse(s.createdAt.replaceFirst(' ', 'T'));
    if (created == null) return false;
    return DateTime.now().difference(created).inDays > editDays;
  }

  void _resumeInPos(Sale s) async {
    if (_isEditWindowLocked(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locked: Transaction edit limit (${widget.settings.transactionEditDays} days) expired for #${s.invoiceNo}.',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }
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
    if (currentUser != null &&
        !currentUser.hasPermission('quotation.convert')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Permission denied: Your role cannot convert quotations to invoices.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (quotation.id == null || quotation.isConvertedQuotation) return;

    String paymentMethod = 'cash';
    final paidCtrl =
        TextEditingController(text: quotation.totalAmount.toStringAsFixed(2));
    final noteCtrl = TextEditingController(
        text: 'Converted from Quotation #${quotation.invoiceNo}');
    final cur = widget.settings.currencySymbol;
    bool isConverting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Convert Quotation #${quotation.invoiceNo} to Invoice',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                      labelText: 'Payment Method', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'card', child: Text('Card / POS Machine')),
                    DropdownMenuItem(
                        value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(
                        value: 'credit',
                        child: Text('Credit / Customer Khata (Due)')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDlgState(() {
                      paymentMethod = val;
                      if (val == 'credit') {
                        paidCtrl.text = '0.00';
                      } else if ((double.tryParse(paidCtrl.text.trim()) ??
                              0.0) ==
                          0.0) {
                        paidCtrl.text =
                            quotation.totalAmount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid Now ($cur)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Invoice Note', isDense: true),
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
              label: Text(isConverting
                  ? 'Converting...'
                  : 'Confirm & Finalize Invoice'),
              onPressed: isConverting
                  ? null
                  : () async {
                      setDlgState(() => isConverting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final db = await DatabaseService.initialize();
                        final paidAmt =
                            double.tryParse(paidCtrl.text.trim()) ?? 0.0;
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
                            SnackBar(
                                content: Text('Conversion failed: $e'),
                                backgroundColor: Colors.red),
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
          content: Text(
              'Access Denied: You do not have permission to delete sales invoices. Contact Super Admin.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_isEditWindowLocked(s)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locked: Transaction edit limit (${widget.settings.transactionEditDays} days) expired for #${s.invoiceNo}.',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.saleStatus.toUpperCase()} #${s.invoiceNo}?'),
        content: Text(
            'Are you sure you want to permanently delete this ${s.saleStatus}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final db = await DatabaseService.initialize();
        await db.deleteSale(s.id!);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${s.saleStatus.toUpperCase()} #${s.invoiceNo} deleted successfully.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  Future<void> _showSaleDetailsDialog(Sale s) async {
    final db = await DatabaseService.initialize();
    final items = s.id != null ? await db.getSaleItems(s.id!) : <SaleItem>[];
    if (!mounted) return;
    final currency = widget.settings.currencySymbol;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFF004EEB)),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Invoice #${s.invoiceNo} • ${s.customerName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Date: ${s.createdAt} • Method: ${s.paymentMethod.toUpperCase()} • Status: ${s.paymentStatus.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Note: ${s.note}',
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic)),
                ],
                const Divider(height: 20),
                if (items.isEmpty)
                  const Text('No line items found for this transaction.',
                      style: TextStyle(color: Colors.grey))
                else
                  ...items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${it.productName}${(it.variationName ?? '').isNotEmpty ? ' (${it.variationName})' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Text(
                                '${it.quantity} x $currency${it.unitPrice.toStringAsFixed(2)}  ',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            Text('$currency${it.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        'Subtotal: $currency${s.subtotal.toStringAsFixed(2)} • Discount: $currency${s.discount.toStringAsFixed(2)} • Tax: $currency${s.taxAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total: $currency${s.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900)),
                    Text(
                        'Paid: $currency${s.paidAmount.toStringAsFixed(2)} • Due: $currency${s.dueAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: s.dueAmount > 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF059669))),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Receipt'),
            onPressed: () {
              Navigator.pop(ctx);
              _printReceipt(s);
            },
          ),
        ],
      ),
    );
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
      MessagingService.sendWhatsAppDirect(
          to: customerPhone, message: text, recipientName: s.customerName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Opening WhatsApp for ${s.customerName}...'),
              backgroundColor: const Color(0xFF25D366)),
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
              decoration: const InputDecoration(
                  labelText: 'WhatsApp Number (e.g. 03001234567)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send via WhatsApp'),
            onPressed: () {
              final p = phoneCtrl.text.trim();
              if (p.isNotEmpty) {
                MessagingService.sendWhatsAppDirect(
                    to: p, message: text, recipientName: s.customerName);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Opening WhatsApp for ${s.customerName}...'),
                      backgroundColor: const Color(0xFF25D366)),
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
    final layout = await db.getDefaultInvoiceLayout();
    final prodImages = await db.getProductImagePathsByIds(
      items.map((i) => i.productId).whereType<int>(),
    );
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
          pdfGenerator: (paper) => PdfExportService.generateSalePdf(
            sale: fullSale,
            settings: widget.settings,
            layout: layout,
            paperSizeOverride: paper,
            productImagePathsById: prodImages,
          ),
        ),
      );
    }
  }

  Future<void> _exportSalePdf(Sale s, {bool email = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final db = await DatabaseService.initialize();
    final items = await db.getSaleItems(s.id!);
    final fullSale = Sale.fromMap(s.toMap(), items: items);
    final layout = await db.getDefaultInvoiceLayout();
    final prodImages = await db.getProductImagePathsByIds(
      items.map((i) => i.productId).whereType<int>(),
    );
    final bytes = await PdfExportService.generateSalePdf(
      sale: fullSale,
      settings: widget.settings,
      layout: layout,
      paperSizeOverride: 'a4',
      productImagePathsById: prodImages,
    );
    final prefix = s.isQuotation ? 'Quotation' : 'Invoice';
    if (email) {
      String recipientEmail = '';
      if (s.customerId != null) {
        final cust = await db.getContactById(s.customerId!);
        recipientEmail = cust?.email ?? '';
      }
      final saved = await PdfExportService.emailPdfInvoice(
        bytes: bytes,
        baseName: '${prefix}_${s.invoiceNo}',
        recipientEmail: recipientEmail,
        subject: '${widget.settings.businessName} - $prefix #${s.invoiceNo}',
        body:
            'Dear ${s.customerName},\n\nPlease find attached your $prefix #${s.invoiceNo} for ${widget.settings.currencySymbol}${s.totalAmount.toStringAsFixed(2)}.\n\nRegards,\n${widget.settings.businessName}',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Email draft launched! PDF saved: ${saved.path}'),
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
    } else {
      final saved =
          await PdfExportService.savePdfFile(bytes, '${prefix}_${s.invoiceNo}');
      await PdfExportService.openPdfFile(saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$prefix PDF saved & opened: ${saved.path}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _exportSalesCsv({bool isExcel = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_sales.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No sales records to export.'),
          backgroundColor: Colors.orange));
      return;
    }
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final buf = StringBuffer()
      ..writeln(
          'Date,Invoice No,Customer,Contact Number,Location,Payment Status,Payment Method,Total,Paid,Due');
    for (final s in _sales) {
      final phone = _customerPhonesById[s.customerId] ?? '';
      final loc =
          _locationNamesById[s.locationId] ?? widget.settings.businessName;
      buf.writeln([
        esc(s.createdAt),
        esc(s.invoiceNo),
        esc(s.customerName),
        esc(phone),
        esc(loc),
        esc(s.paymentStatus),
        esc(s.paymentMethod),
        s.totalAmount.toStringAsFixed(2),
        s.paidAmount.toStringAsFixed(2),
        s.dueAmount.toStringAsFixed(2),
      ].join(','));
    }
    final dir = await Directory.systemTemp.createTemp('smartpos_export_');
    final file = File(
        '${dir.path}${Platform.pathSeparator}sales_${_activeTab}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buf.toString());
    await PdfExportService.openPdfFile(file);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            '${isExcel ? 'Excel-ready CSV' : 'CSV'} exported: ${file.path}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _exportSalesListPdf({bool previewPrint = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_sales.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No sales records to export.'),
          backgroundColor: Colors.orange));
      return;
    }
    final currency = widget.settings.currencySymbol;
    final headers = <String>[
      'Date',
      'Invoice',
      'Customer',
      'Status',
      'Method',
      'Total',
      'Paid',
      'Due'
    ];
    final rows = _sales
        .map((s) => <String>[
              s.createdAt,
              s.invoiceNo,
              s.customerName,
              s.paymentStatus.toUpperCase(),
              s.paymentMethod.toUpperCase(),
              '$currency${s.totalAmount.toStringAsFixed(2)}',
              '$currency${s.paidAmount.toStringAsFixed(2)}',
              '$currency${s.dueAmount.toStringAsFixed(2)}',
            ])
        .toList();
    final totalSum = _sales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
    final dueSum = _sales.fold<double>(0.0, (sum, s) => sum + s.dueAmount);

    if (previewPrint && mounted) {
      final htmlBuf = StringBuffer()
        ..write('<h2>Sales Register (${_activeTab.toUpperCase()})</h2>')
        ..write(
            '<table border="1" cellspacing="0" cellpadding="6" width="100%">')
        ..write('<tr>${headers.map((h) => '<th>$h</th>').join()}</tr>');
      for (final r in rows) {
        htmlBuf.write('<tr>${r.map((c) => '<td>$c</td>').join()}</tr>');
      }
      htmlBuf.write('</table>');
      showDialog(
        context: context,
        builder: (_) => UniversalPrintPreviewDialog(
          title: 'Sales Register (${_activeTab.toUpperCase()})',
          htmlContent: htmlBuf.toString(),
          defaultPaperSize: 'a4',
          settings: widget.settings,
          pdfGenerator: (_) => PdfExportService.generateReportPdf(
            title: 'Sales List Report (${_activeTab.toUpperCase()})',
            subtitle:
                '${widget.settings.businessName} • ${_sales.length} invoices',
            headers: headers,
            rows: rows,
            settings: widget.settings,
            summaryMetrics: {
              'Invoices': '${_sales.length}',
              'Total Sales': '$currency${totalSum.toStringAsFixed(2)}',
              'Total Due': '$currency${dueSum.toStringAsFixed(2)}',
            },
          ),
        ),
      );
      return;
    }

    final bytes = await PdfExportService.generateReportPdf(
      title: 'Sales List Report (${_activeTab.toUpperCase()})',
      subtitle: '${widget.settings.businessName} • ${_sales.length} invoices',
      headers: headers,
      rows: rows,
      settings: widget.settings,
      summaryMetrics: {
        'Invoices': '${_sales.length}',
        'Total Sales': '$currency${totalSum.toStringAsFixed(2)}',
        'Total Due': '$currency${dueSum.toStringAsFixed(2)}',
      },
    );
    final saved =
        await PdfExportService.savePdfFile(bytes, 'Sales_List_${_activeTab}');
    await PdfExportService.openPdfFile(saved);
    messenger.showSnackBar(
      SnackBar(
        content: Text('PDF saved & opened: ${saved.path}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _openColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Column Visibility',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                dense: true,
                title: const Text('Contact Number'),
                value: _showContactCol,
                onChanged: (v) {
                  setDlgState(() => _showContactCol = v ?? true);
                  setState(() {});
                },
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Location'),
                value: _showLocationCol,
                onChanged: (v) {
                  setDlgState(() => _showLocationCol = v ?? true);
                  setState(() {});
                },
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Payment Method'),
                value: _showMethodCol,
                onChanged: (v) {
                  setDlgState(() => _showMethodCol = v ?? true);
                  setState(() {});
                },
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Total Paid'),
                value: _showPaidCol,
                onChanged: (v) {
                  setDlgState(() => _showPaidCol = v ?? true);
                  setState(() {});
                },
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Sell Due'),
                value: _showDueCol,
                onChanged: (v) {
                  setDlgState(() => _showDueCol = v ?? true);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  Widget _exportBtn(
      String label, IconData icon, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon,
            size: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        label: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                initiallyExpanded: _filtersOpen,
                onExpansionChanged: (val) => setState(() => _filtersOpen = val),
                leading: const Icon(Icons.filter_alt_outlined,
                    color: Color(0xFF004EEB), size: 20),
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
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedLocationId,
                            dropdownColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(
                                labelText: 'Business Location', isDense: true),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('All Locations')),
                              ..._locations.map(
                                (loc) => DropdownMenuItem<int?>(
                                  value: loc.id,
                                  child: Text(loc.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedLocationId = val;
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _selectedCustomerId,
                            dropdownColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(
                                labelText: 'Customer', isDense: true),
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('All Customers')),
                              ..._customers.map(
                                (cust) => DropdownMenuItem<int?>(
                                  value: cust.id,
                                  child: Text(cust.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedCustomerId = val;
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedPaymentStatus,
                            dropdownColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            decoration: const InputDecoration(
                                labelText: 'Payment Status', isDense: true),
                            items: const [
                              DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All Payment Statuses')),
                              DropdownMenuItem(
                                  value: 'Paid', child: Text('Paid')),
                              DropdownMenuItem(
                                  value: 'Due', child: Text('Due')),
                              DropdownMenuItem(
                                  value: 'Partial', child: Text('Partial')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedPaymentStatus = val ?? 'All';
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
                            },
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
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0x04000000),
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
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                        label: const Text('POS Terminal (F1) / نئی سیل کریں',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
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
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tabButton('final', 'All Final Sales', _finalCount,
                            Icons.receipt_long_rounded, isDark),
                        const SizedBox(width: 4),
                        _tabButton('draft', 'Drafts', _draftCount,
                            Icons.edit_note_rounded, isDark),
                        const SizedBox(width: 4),
                        _tabButton('quotation', 'Quotations / Estimates',
                            _quotationCount, Icons.assignment_outlined, isDark),
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
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('All Quotations',
                                style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'all',
                            onSelected: (_) {
                              setState(() {
                                _quotationFilter = 'all';
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Pending Conversion',
                                style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'pending',
                            onSelected: (_) {
                              setState(() {
                                _quotationFilter = 'pending';
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Converted to Invoice',
                                style: TextStyle(fontSize: 11.5)),
                            selected: _quotationFilter == 'converted',
                            onSelected: (_) {
                              setState(() {
                                _quotationFilter = 'converted';
                                _currentPage = 1;
                              });
                              _load(refreshTabCounts: false);
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
                          Text('Show ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _entriesPerPage,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                      value: 10,
                                      child: Text('10',
                                          style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(
                                      value: 25,
                                      child: Text('25',
                                          style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(
                                      value: 50,
                                      child: Text('50',
                                          style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _entriesPerPage = val ?? 25;
                                    _currentPage = 1;
                                  });
                                  _load(refreshTabCounts: false);
                                },
                              ),
                            ),
                          ),
                          Text(' entries',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                        ],
                      );

                      final exportButtons = Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          showDropdown,
                          const SizedBox(width: 8),
                          _exportBtn('Export CSV', Icons.table_chart_outlined,
                              isDark, () => _exportSalesCsv()),
                          _exportBtn('Export Excel', Icons.description_outlined,
                              isDark, () => _exportSalesCsv(isExcel: true)),
                          _exportBtn('Print', Icons.print_outlined, isDark,
                              () => _exportSalesListPdf(previewPrint: true)),
                          _exportBtn(
                              'Column visibility',
                              Icons.view_column_outlined,
                              isDark,
                              _openColumnVisibilityDialog),
                          _exportBtn(
                              'Export PDF',
                              Icons.picture_as_pdf_outlined,
                              isDark,
                              () => _exportSalesListPdf()),
                        ],
                      );

                      final searchBox = Container(
                        width:
                            constraints.maxWidth < 600 ? double.infinity : 220,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          onChanged: (val) {
                            _search = val;
                            _currentPage = 1;
                            _searchDebounce?.cancel();
                            if (Platform.environment
                                .containsKey('FLUTTER_TEST')) {
                              _load(refreshTabCounts: false);
                            } else {
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 220),
                                () => _load(refreshTabCounts: false),
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search sales, invoices, customers...',
                            prefixIcon: Icon(Icons.search,
                                size: 16, color: Color(0xFF94A3B8)),
                            hintStyle: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
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
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()))
                      : _sales.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                  child: Text('No POS records found',
                                      style: TextStyle(color: Colors.grey))),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final double tableWidth =
                                    math.max(constraints.maxWidth, 1150.0);
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
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Table(
                                          columnWidths: () {
                                            final colWidths =
                                                <int, TableColumnWidth>{
                                              0: const FlexColumnWidth(
                                                  1.7), // Action
                                              1: const FlexColumnWidth(
                                                  1.5), // Date
                                              2: const FlexColumnWidth(
                                                  1.2), // Invoice No.
                                              3: const FlexColumnWidth(
                                                  1.8), // Customer name
                                            };
                                            int cIdx = 4;
                                            if (_showContactCol)
                                              colWidths[cIdx++] =
                                                  const FlexColumnWidth(1.3);
                                            if (_showLocationCol)
                                              colWidths[cIdx++] =
                                                  const FlexColumnWidth(1.6);
                                            colWidths[cIdx++] =
                                                const FlexColumnWidth(
                                                    1.2); // Payment Status
                                            if (_showMethodCol)
                                              colWidths[cIdx++] =
                                                  const FlexColumnWidth(1.1);
                                            colWidths[cIdx++] =
                                                const FlexColumnWidth(
                                                    1.3); // Total amount
                                            if (_showPaidCol)
                                              colWidths[cIdx++] =
                                                  const FlexColumnWidth(1.3);
                                            if (_showDueCol)
                                              colWidths[cIdx++] =
                                                  const FlexColumnWidth(1.1);
                                            return colWidths;
                                          }(),
                                          defaultVerticalAlignment:
                                              TableCellVerticalAlignment.middle,
                                          children: [
                                            TableRow(
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFFF8FAFC),
                                                border: Border(
                                                    bottom: BorderSide(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF334155)
                                                            : const Color(
                                                                0xFFE2E8F0),
                                                        width: 1.2)),
                                              ),
                                              children: [
                                                _th('Action', isDark),
                                                _th('Date ⇅', isDark),
                                                _th('Invoice No. ⇅', isDark),
                                                _th('Customer name ⇅', isDark),
                                                if (_showContactCol)
                                                  _th('Contact Number ⇅',
                                                      isDark),
                                                if (_showLocationCol)
                                                  _th('Location ⇅', isDark),
                                                _th('Payment Status ⇅', isDark),
                                                if (_showMethodCol)
                                                  _th('Payment Method', isDark),
                                                _th('Total amount ⇅', isDark),
                                                if (_showPaidCol)
                                                  _th('Total paid ⇅', isDark),
                                                if (_showDueCol)
                                                  _th('Sell Due', isDark),
                                              ],
                                            ),
                                            ..._sales
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final s = entry.value;
                                              final rowBg = idx.isOdd
                                                  ? (isDark
                                                      ? const Color(0xFF1E293B)
                                                      : Colors.white)
                                                  : (isDark
                                                      ? const Color(0xFF172033)
                                                      : const Color(
                                                          0xFFFBFDFF));

                                              return TableRow(
                                                decoration: BoxDecoration(
                                                  color: rowBg,
                                                  border: Border(
                                                      bottom: BorderSide(
                                                          color: isDark
                                                              ? const Color(
                                                                      0xFF334155)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.6)
                                                              : const Color(
                                                                  0xFFE2E8F0),
                                                          width: 0.8)),
                                                ),
                                                children: [
                                                  // Action Button
                                                  _td(
                                                    s.saleStatus != 'final'
                                                        ? Wrap(
                                                            spacing: 4,
                                                            runSpacing: 4,
                                                            crossAxisAlignment:
                                                                WrapCrossAlignment
                                                                    .center,
                                                            children: [
                                                              if (s.saleStatus ==
                                                                      'quotation' &&
                                                                  s.isConvertedQuotation)
                                                                Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: const Color(
                                                                        0xFFDCFCE7),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(5),
                                                                    border: Border.all(
                                                                        color: const Color(
                                                                            0xFF86EFAC)),
                                                                  ),
                                                                  child:
                                                                      const Text(
                                                                    'Converted',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: Color(
                                                                            0xFF15803D)),
                                                                  ),
                                                                )
                                                              else ...[
                                                                if (s.saleStatus ==
                                                                    'quotation')
                                                                  ElevatedButton
                                                                      .icon(
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          const Color(
                                                                              0xFF4F46E5),
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              6),
                                                                      shape: RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(6)),
                                                                      elevation:
                                                                          0,
                                                                    ),
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .receipt_long_rounded,
                                                                        size:
                                                                            13),
                                                                    label: const Text(
                                                                        'Convert to Invoice',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                10.5,
                                                                            fontWeight:
                                                                                FontWeight.bold)),
                                                                    onPressed: () =>
                                                                        _showConvertQuotationDialog(
                                                                            s),
                                                                  ),
                                                                if (AuthService
                                                                        .currentUser
                                                                        ?.hasPermission(
                                                                            'sale.edit') ??
                                                                    true)
                                                                  ElevatedButton
                                                                      .icon(
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          const Color(
                                                                              0xFF10B981),
                                                                      foregroundColor:
                                                                          Colors
                                                                              .white,
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              6),
                                                                      shape: RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(6)),
                                                                      elevation:
                                                                          0,
                                                                    ),
                                                                    icon: const Icon(
                                                                        Icons
                                                                            .play_arrow_rounded,
                                                                        size:
                                                                            14),
                                                                    label: const Text(
                                                                        'Resume in POS',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                10.5,
                                                                            fontWeight:
                                                                                FontWeight.bold)),
                                                                    onPressed: () =>
                                                                        _resumeInPos(
                                                                            s),
                                                                  ),
                                                              ],
                                                              PopupMenuButton<
                                                                  String>(
                                                                onSelected:
                                                                    (val) {
                                                                  if (val ==
                                                                      'convert') {
                                                                    _showConvertQuotationDialog(
                                                                        s);
                                                                  } else if (val ==
                                                                      'quotation') {
                                                                    _printQuotation(
                                                                        s);
                                                                  } else if (val ==
                                                                      'pdf') {
                                                                    _exportSalePdf(
                                                                        s);
                                                                  } else if (val ==
                                                                      'email') {
                                                                    _exportSalePdf(
                                                                        s,
                                                                        email:
                                                                            true);
                                                                  } else if (val ==
                                                                      'delete') {
                                                                    _deleteSaleRecord(
                                                                        s);
                                                                  }
                                                                },
                                                                itemBuilder:
                                                                    (ctx) {
                                                                  final canDel =
                                                                      AuthService
                                                                              .currentUser
                                                                              ?.hasPermission('sale.delete') ??
                                                                          true;
                                                                  final canConvert =
                                                                      AuthService
                                                                              .currentUser
                                                                              ?.hasPermission('quotation.convert') ??
                                                                          true;
                                                                  return [
                                                                    if (canConvert &&
                                                                        s.saleStatus ==
                                                                            'quotation' &&
                                                                        !s
                                                                            .isConvertedQuotation)
                                                                      const PopupMenuItem(
                                                                          value:
                                                                              'convert',
                                                                          child:
                                                                              Text('Convert to Invoice')),
                                                                    const PopupMenuItem(
                                                                        value:
                                                                            'quotation',
                                                                        child: Text(
                                                                            'Print Quotation / Estimate')),
                                                                    const PopupMenuItem(
                                                                        value:
                                                                            'pdf',
                                                                        child: Text(
                                                                            'Export PDF')),
                                                                    const PopupMenuItem(
                                                                        value:
                                                                            'email',
                                                                        child: Text(
                                                                            'Email PDF')),
                                                                    if (canDel)
                                                                      const PopupMenuItem(
                                                                        value:
                                                                            'delete',
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            Icon(Icons.delete_outline,
                                                                                size: 16,
                                                                                color: Color(0xFFEF4444)),
                                                                            SizedBox(width: 8),
                                                                            Text('Delete',
                                                                                style: TextStyle(color: Color(0xFFEF4444))),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                  ];
                                                                },
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          5),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF334155)
                                                                        : const Color(
                                                                            0xFFE2E8F0),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(4),
                                                                  ),
                                                                  child: const Icon(
                                                                      Icons
                                                                          .more_vert,
                                                                      size: 14),
                                                                ),
                                                              ),
                                                            ],
                                                          )
                                                        : PopupMenuButton<
                                                            String>(
                                                            onSelected: (val) {
                                                              if (val ==
                                                                  'receipt') {
                                                                _printReceipt(
                                                                    s);
                                                              } else if (val ==
                                                                  'quotation') {
                                                                _printQuotation(
                                                                    s);
                                                              } else if (val ==
                                                                  'pay_due') {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder: (_) =>
                                                                      PayDueDialog(
                                                                    settings: widget
                                                                        .settings,
                                                                    type: DuePaymentType
                                                                        .sale,
                                                                    entityId:
                                                                        s.id!,
                                                                    reference: s
                                                                        .invoiceNo,
                                                                    contactName:
                                                                        s.customerName,
                                                                    contactId: s
                                                                        .customerId,
                                                                    totalAmount:
                                                                        s.totalAmount,
                                                                    paidAmount:
                                                                        s.paidAmount,
                                                                    dueAmount: s
                                                                        .dueAmount,
                                                                    onPaymentSuccess:
                                                                        _load,
                                                                  ),
                                                                );
                                                              } else if (val ==
                                                                  'whatsapp') {
                                                                _sendWhatsAppBill(
                                                                    s);
                                                              } else if (val ==
                                                                  'pdf') {
                                                                _exportSalePdf(
                                                                    s);
                                                              } else if (val ==
                                                                  'email') {
                                                                _exportSalePdf(
                                                                    s,
                                                                    email:
                                                                        true);
                                                              } else if (val ==
                                                                  'view') {
                                                                _showSaleDetailsDialog(
                                                                    s);
                                                              } else if (val ==
                                                                  'delete') {
                                                                _deleteSaleRecord(
                                                                    s);
                                                              }
                                                            },
                                                            itemBuilder: (ctx) {
                                                              final canDel = AuthService
                                                                      .currentUser
                                                                      ?.hasPermission(
                                                                          'sale.delete') ??
                                                                  true;
                                                              return [
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'receipt',
                                                                    child: Text(
                                                                        'Print Receipt')),
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'pdf',
                                                                    child: Text(
                                                                        'Export PDF Invoice')),
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'email',
                                                                    child: Text(
                                                                        'Email PDF Invoice')),
                                                                const PopupMenuItem(
                                                                  value:
                                                                      'whatsapp',
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .chat_rounded,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              Color(0xFF25D366)),
                                                                      SizedBox(
                                                                          width:
                                                                              8),
                                                                      Text(
                                                                          'Send WhatsApp Bill',
                                                                          style: TextStyle(
                                                                              color: Color(0xFF25D366),
                                                                              fontWeight: FontWeight.bold)),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'quotation',
                                                                    child: Text(
                                                                        'Print Quotation / Estimate')),
                                                                if (s.dueAmount >
                                                                    0)
                                                                  const PopupMenuItem(
                                                                    value:
                                                                        'pay_due',
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                            Icons
                                                                                .payments_outlined,
                                                                            size:
                                                                                16,
                                                                            color:
                                                                                Color(0xFF059669)),
                                                                        SizedBox(
                                                                            width:
                                                                                8),
                                                                        Text(
                                                                            'Pay Due / Collect',
                                                                            style:
                                                                                TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                const PopupMenuItem(
                                                                    value:
                                                                        'view',
                                                                    child: Text(
                                                                        'View Details')),
                                                                if (canDel)
                                                                  const PopupMenuItem(
                                                                    value:
                                                                        'delete',
                                                                    child: Row(
                                                                      children: [
                                                                        Icon(
                                                                            Icons
                                                                                .delete_outline,
                                                                            size:
                                                                                16,
                                                                            color:
                                                                                Color(0xFFEF4444)),
                                                                        SizedBox(
                                                                            width:
                                                                                8),
                                                                        Text(
                                                                            'Delete Sale',
                                                                            style:
                                                                                TextStyle(color: Color(0xFFEF4444))),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ];
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFF004EEB),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: const Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                      'Actions',
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.bold)),
                                                                  SizedBox(
                                                                      width: 4),
                                                                  Icon(
                                                                      Icons
                                                                          .arrow_drop_down,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 16),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                  ),
                                                  _td(Text(s.createdAt,
                                                      style: const TextStyle(
                                                          fontSize: 12))),
                                                  _td(Text(s.invoiceNo,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12))),
                                                  _td(Text(s.customerName,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                                  if (_showContactCol)
                                                    _td(Text(
                                                      _customerPhonesById[
                                                              s.customerId] ??
                                                          '—',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                              0xFF64748B)),
                                                    )),
                                                  if (_showLocationCol)
                                                    _td(Text(
                                                      _locationNamesById[
                                                              s.locationId] ??
                                                          widget.settings
                                                              .businessName,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )),
                                                  _td(StatusPill(
                                                      status: s.paymentStatus)),
                                                  if (_showMethodCol)
                                                    _td(Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF0F172A)
                                                            : const Color(
                                                                0xFFF1F5F9),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF334155)
                                                                : const Color(
                                                                    0xFFE2E8F0)),
                                                      ),
                                                      child: Text(
                                                        s.paymentMethod
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF94A3B8)
                                                              : const Color(
                                                                  0xFF475569),
                                                        ),
                                                      ),
                                                    )),
                                                  _td(Text(
                                                    '$currency ${s.totalAmount.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF0F172A),
                                                    ),
                                                  )),
                                                  if (_showPaidCol)
                                                    _td(Text(
                                                      '$currency ${s.paidAmount.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF059669)),
                                                    )),
                                                  if (_showDueCol)
                                                    _td(Text(
                                                      s.dueAmount > 0
                                                          ? '$currency ${s.dueAmount.toStringAsFixed(2)}'
                                                          : '$currency 0.00',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: s
                                                                    .dueAmount >
                                                                0
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: s.dueAmount > 0
                                                            ? const Color(
                                                                0xFFEF4444)
                                                            : const Color(
                                                                0xFF94A3B8),
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
                  if (!_loading && _sales.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DataTablePaginationBar(
                      currentPage: _currentPage,
                      pageSize: _entriesPerPage,
                      totalItems: _totalFilteredCount,
                      pageSizeOptions: const [10, 25, 50],
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                        _load(refreshTabCounts: false);
                      },
                      onPageSizeChanged: (newSize) {
                        setState(() {
                          _entriesPerPage = newSize;
                          _currentPage = 1;
                        });
                        _load(refreshTabCounts: false);
                      },
                    ),
                  ],
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

  Widget _tabButton(
      String tabKey, String title, int count, IconData icon, bool isDark) {
    final isSelected = _activeTab == tabKey;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabKey;
          _currentPage = 1;
          _loading = true;
        });
        _load(refreshTabCounts: false);
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
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
