import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/pdf_export_service.dart';

/// UltimatePOS-inspired multi-template Invoice Layout Customizer (Step 4.3).
/// Supports header branding, column toggles (SKU/Brand/Image/Batch/Expiry/Warranty),
/// footer/terms/signatures, font sizes, orientation, and sample PDF export.
class InvoiceLayoutsManager extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings) onSettingsUpdated;

  const InvoiceLayoutsManager({
    super.key,
    required this.settings,
    required this.onSettingsUpdated,
  });

  @override
  State<InvoiceLayoutsManager> createState() => _InvoiceLayoutsManagerState();
}

class _InvoiceLayoutsManagerState extends State<InvoiceLayoutsManager> {
  List<InvoiceLayout> _layouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    try {
      final db = await DatabaseService.initialize();
      final rows = await db.getInvoiceLayouts();
      if (mounted) {
        setState(() {
          _layouts = rows;
        });
      }
    } catch (e, st) {
      AppLogger.warning('InvoiceLayoutsManager', 'Failed loading layouts', e, st);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openLayoutEditor([InvoiceLayout? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String design = existing?.design ?? 'detailed';
    String paperSize = existing?.paperSize ?? 'a4';
    String orientation = existing?.paperOrientation ?? 'portrait';
    double fontSize = existing?.fontSize ?? 10.0;
    String highlightColor = existing?.highlightColor ?? '#0F172A';

    final headingCtrl = TextEditingController(text: existing?.invoiceHeading ?? 'TAX INVOICE');
    final headerTextCtrl = TextEditingController(text: existing?.headerText ?? '');
    final subLabelCtrl = TextEditingController(text: existing?.subTotalLabel ?? 'Subtotal');
    final discLabelCtrl = TextEditingController(text: existing?.discountLabel ?? 'Discount');
    final taxLabelCtrl = TextEditingController(text: existing?.taxLabel ?? 'Tax');
    final totalLabelCtrl = TextEditingController(text: existing?.totalLabel ?? 'Grand Total');
    final footerCtrl = TextEditingController(text: existing?.footerText ?? 'Thank you for shopping with us!');
    final termsCtrl = TextEditingController(
      text: existing?.termsText ??
          'Goods once sold can only be exchanged within 7 days with original receipt.',
    );
    final signCtrl = TextEditingController(text: existing?.signatureLabel ?? 'Authorized Signature');

    bool showLogo = existing?.showLogo ?? true;
    bool showBizName = existing?.showBusinessName ?? true;
    bool showAddress = existing?.showAddress ?? true;
    bool showPhone = existing?.showPhone ?? true;
    bool showEmail = existing?.showEmail ?? true;
    bool showTaxNo = existing?.showTaxNumber ?? true;

    bool showSku = existing?.showSku ?? true;
    bool showBrand = existing?.showBrand ?? true;
    bool showImage = existing?.showImage ?? false;
    bool showExpiry = existing?.showExpiry ?? true;
    bool showBatch = existing?.showBatch ?? true;
    bool showWarranty = existing?.showWarranty ?? true;

    bool showBarcode = existing?.showBarcode ?? true;
    bool showQr = existing?.showQrCode ?? true;
    bool showBalance = existing?.showCustomerBalance ?? true;
    bool showSignature = existing?.showSignature ?? true;
    bool showWords = existing?.showTotalInWords ?? true;
    bool isDefault = existing?.isDefault ?? false;

    const swatches = ['#0F172A', '#1E40AF', '#047857', '#7C3AED', '#B91C1C'];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.view_quilt_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 8),
              Text(existing == null ? 'Create Invoice Layout Template' : 'Edit Layout: ${existing.name}'),
            ],
          ),
          content: SizedBox(
            width: 680,
            height: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Template Name *',
                            hintText: 'e.g. Wholesale A4, Counter 80mm',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: design,
                          decoration: const InputDecoration(
                            labelText: 'Design Style',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'detailed', child: Text('Detailed')),
                            DropdownMenuItem(value: 'classic', child: Text('Classic')),
                            DropdownMenuItem(value: 'elegant', child: Text('Elegant')),
                            DropdownMenuItem(value: 'slim', child: Text('Slim')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => design = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: paperSize,
                          decoration: const InputDecoration(
                            labelText: 'Paper Size',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'a4', child: Text('A4 Sheet')),
                            DropdownMenuItem(value: '80mm', child: Text('80mm Thermal')),
                            DropdownMenuItem(value: '58mm', child: Text('58mm Thermal')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => paperSize = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: orientation,
                          decoration: const InputDecoration(
                            labelText: 'Orientation',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                            DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlgState(() => orientation = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          initialValue: fontSize,
                          decoration: const InputDecoration(
                            labelText: 'Font Size',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: const [8.5, 9.0, 10.0, 11.0, 12.0]
                              .map((s) => DropdownMenuItem(value: s, child: Text('${s.toStringAsFixed(1)} pt')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => fontSize = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Accent Color:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                      const SizedBox(width: 10),
                      for (final hex in swatches)
                        GestureDetector(
                          onTap: () => setDlgState(() => highlightColor = hex),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: highlightColor == hex ? Colors.amber : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: headingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Invoice Heading',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: headerTextCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Top Header Text / Tagline',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: subLabelCtrl,
                          decoration: const InputDecoration(labelText: 'Subtotal Label', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: discLabelCtrl,
                          decoration: const InputDecoration(labelText: 'Discount Label', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: taxLabelCtrl,
                          decoration: const InputDecoration(labelText: 'Tax Label', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: totalLabelCtrl,
                          decoration: const InputDecoration(labelText: 'Total Label', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Header Fields Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: const Text('Logo'), selected: showLogo, onSelected: (v) => setDlgState(() => showLogo = v)),
                      FilterChip(label: const Text('Business Name'), selected: showBizName, onSelected: (v) => setDlgState(() => showBizName = v)),
                      FilterChip(label: const Text('Address'), selected: showAddress, onSelected: (v) => setDlgState(() => showAddress = v)),
                      FilterChip(label: const Text('Phone'), selected: showPhone, onSelected: (v) => setDlgState(() => showPhone = v)),
                      FilterChip(label: const Text('Email'), selected: showEmail, onSelected: (v) => setDlgState(() => showEmail = v)),
                      FilterChip(label: const Text('Tax / NTN'), selected: showTaxNo, onSelected: (v) => setDlgState(() => showTaxNo = v)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Product Table Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: const Text('SKU / Code'), selected: showSku, onSelected: (v) => setDlgState(() => showSku = v)),
                      FilterChip(label: const Text('Brand'), selected: showBrand, onSelected: (v) => setDlgState(() => showBrand = v)),
                      FilterChip(label: const Text('Product Image'), selected: showImage, onSelected: (v) => setDlgState(() => showImage = v)),
                      FilterChip(label: const Text('Batch No.'), selected: showBatch, onSelected: (v) => setDlgState(() => showBatch = v)),
                      FilterChip(label: const Text('Expiry Date'), selected: showExpiry, onSelected: (v) => setDlgState(() => showExpiry = v)),
                      FilterChip(label: const Text('Warranty'), selected: showWarranty, onSelected: (v) => setDlgState(() => showWarranty = v)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Totals, QR & Footer Elements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: const Text('Barcode'), selected: showBarcode, onSelected: (v) => setDlgState(() => showBarcode = v)),
                      FilterChip(label: const Text('QR Code'), selected: showQr, onSelected: (v) => setDlgState(() => showQr = v)),
                      FilterChip(label: const Text('Customer Khata Balance'), selected: showBalance, onSelected: (v) => setDlgState(() => showBalance = v)),
                      FilterChip(label: const Text('Amount in Words'), selected: showWords, onSelected: (v) => setDlgState(() => showWords = v)),
                      FilterChip(label: const Text('Signature Line'), selected: showSignature, onSelected: (v) => setDlgState(() => showSignature = v)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: termsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Terms & Return Policy', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: footerCtrl,
                          decoration: const InputDecoration(labelText: 'Footer Message', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: signCtrl,
                          decoration: const InputDecoration(labelText: 'Signature Label', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Set as Active Default Store Layout'),
                    value: isDefault,
                    onChanged: (v) => setDlgState(() => isDefault = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              icon: const Icon(Icons.save_rounded, size: 17),
              label: const Text('Save Template'),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final layout = InvoiceLayout(
                  id: existing?.id,
                  name: nameCtrl.text.trim(),
                  design: design,
                  paperSize: paperSize,
                  paperOrientation: orientation,
                  fontSize: fontSize,
                  highlightColor: highlightColor,
                  invoiceHeading: headingCtrl.text.trim(),
                  headerText: headerTextCtrl.text.trim(),
                  subTotalLabel: subLabelCtrl.text.trim(),
                  discountLabel: discLabelCtrl.text.trim(),
                  taxLabel: taxLabelCtrl.text.trim(),
                  totalLabel: totalLabelCtrl.text.trim(),
                  footerText: footerCtrl.text.trim(),
                  termsText: termsCtrl.text.trim(),
                  signatureLabel: signCtrl.text.trim(),
                  showLogo: showLogo,
                  showBusinessName: showBizName,
                  showAddress: showAddress,
                  showPhone: showPhone,
                  showEmail: showEmail,
                  showTaxNumber: showTaxNo,
                  showSku: showSku,
                  showBrand: showBrand,
                  showImage: showImage,
                  showExpiry: showExpiry,
                  showBatch: showBatch,
                  showWarranty: showWarranty,
                  showBarcode: showBarcode,
                  showQrCode: showQr,
                  showCustomerBalance: showBalance,
                  showSignature: showSignature,
                  showTotalInWords: showWords,
                  isDefault: isDefault,
                );
                final db = await DatabaseService.initialize();
                final id = await db.saveInvoiceLayout(layout);
                if (isDefault) {
                  final nextSettings = widget.settings.copyWith(
                    defaultInvoiceLayoutId: id,
                    receiptPaperSize: paperSize,
                    invoiceLayoutDesign: design,
                    showSkuOnInvoice: showSku,
                    showBrandOnInvoice: showBrand,
                    showBatchOnInvoice: showBatch,
                    showExpiryOnInvoice: showExpiry,
                    showWarrantyOnInvoice: showWarranty,
                    showLogoOnReceipt: showLogo,
                    showQrOnReceipt: showQr,
                    showBarcodeOnReceipt: showBarcode,
                    showCustomerBalanceOnReceipt: showBalance,
                    showTotalInWords: showWords,
                    invoiceHeading: headingCtrl.text.trim(),
                  );
                  await db.updateBusinessSettings(nextSettings);
                  widget.onSettingsUpdated(nextSettings);
                }
                await _loadLayouts();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSamplePdf(InvoiceLayout layout) async {
    final messenger = ScaffoldMessenger.of(context);
    final sample = Sale(
      invoiceNo: 'SAMPLE-INV-101',
      customerName: 'Muhammad Tariq',
      subtotal: 1500,
      discount: 100,
      taxAmount: 70,
      totalAmount: 1470,
      paidAmount: 1470,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      createdAt: DateTime.now().toString().substring(0, 19),
      items: [
        SaleItem(
          saleId: 0,
          productId: 1,
          productName: 'Sample Retail Item',
          sku: 'SKU-101',
          quantity: 2,
          unitPrice: 750,
          discountValue: 50,
          subtotal: 1450,
          batchNumber: 'B-2026',
          expiryDate: '12/2027',
        ),
      ],
    );
    final bytes = await PdfExportService.generateSalePdf(
      sale: sample,
      settings: widget.settings,
      layout: layout,
    );
    final file = await PdfExportService.savePdfFile(bytes, 'Sample_${layout.name}');
    await PdfExportService.openPdfFile(file);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Sample PDF generated: ${file.path}'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.collections_bookmark_rounded, color: Color(0xFF4F46E5), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Invoice Layout Templates (Multi-Template)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Manage multiple UltimatePOS-style InvoiceLayouts with custom headers, columns, fonts & orientation.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Layout Template'),
                onPressed: () => _openLayoutEditor(),
              ),
            ],
          ),
          const Divider(height: 22),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            Column(
              children: _layouts.map((layout) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: layout.isDefault ? const Color(0xFF4F46E5) : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  layout.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                if (layout.isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Default Template',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${layout.design.toUpperCase()} • ${layout.paperSize.toUpperCase()} (${layout.paperOrientation}) • ${layout.fontSize.toStringAsFixed(1)}pt'
                              '${layout.showSku ? ' • SKU' : ''}${layout.showBrand ? ' • Brand' : ''}${layout.showImage ? ' • Img' : ''}${layout.showBatch ? ' • Batch' : ''}${layout.showExpiry ? ' • Exp' : ''}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 15, color: Color(0xFFDC2626)),
                        label: const Text('Sample PDF', style: TextStyle(fontSize: 11.5)),
                        onPressed: () => _exportSamplePdf(layout),
                      ),
                      const SizedBox(width: 6),
                      if (!layout.isDefault && layout.id != null)
                        TextButton(
                          onPressed: () async {
                            final db = await DatabaseService.initialize();
                            await db.setDefaultInvoiceLayout(layout.id!);
                            final next = widget.settings.copyWith(defaultInvoiceLayoutId: layout.id);
                            await db.updateBusinessSettings(next);
                            widget.onSettingsUpdated(next);
                            _loadLayouts();
                          },
                          child: const Text('Set Default', style: TextStyle(fontSize: 11.5)),
                        ),
                      IconButton(
                        tooltip: 'Edit Layout',
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                        onPressed: () => _openLayoutEditor(layout),
                      ),
                      if (!layout.isDefault)
                        IconButton(
                          tooltip: 'Delete Layout',
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          onPressed: () async {
                            if (layout.id == null) return;
                            final db = await DatabaseService.initialize();
                            await db.deleteInvoiceLayout(layout.id!);
                            _loadLayouts();
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

