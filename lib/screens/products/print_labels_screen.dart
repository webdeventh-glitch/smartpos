import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';

class PrintLabelsScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Product? initialProduct;

  const PrintLabelsScreen(
      {super.key, required this.settings, this.initialProduct});

  @override
  State<PrintLabelsScreen> createState() => _PrintLabelsScreenState();
}

class _PrintLabelsScreenState extends State<PrintLabelsScreen> {
  List<Product> _allProducts = [];
  final Map<int, int> _selectedProductQuantities = {};

  // Print Settings
  String _paperSize = 'Continuous Roll (50mm x 25mm)';
  double _customWidthMm = 50.0;
  double _customHeightMm = 25.0;
  bool _showBusinessName = true;
  bool _showProductName = true;
  bool _showPrice = true;
  bool _showBarcodeNumber = true;
  bool _showExpiryDate = false;
  bool _showBatchNo = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final list = await db.getProducts();
    if (mounted) {
      setState(() {
        _allProducts = list;
        if (widget.initialProduct != null &&
            widget.initialProduct!.id != null) {
          _selectedProductQuantities[widget.initialProduct!.id!] = 4;
        } else if (list.isNotEmpty) {
          _selectedProductQuantities[list.first.id!] = 4;
        }
      });
    }
  }

  void _addProductToPrint(Product p) {
    if (p.id == null) return;
    setState(() {
      _selectedProductQuantities[p.id!] =
          (_selectedProductQuantities[p.id!] ?? 0) + 1;
    });
  }

  void _removeProductFromPrint(int id) {
    setState(() {
      _selectedProductQuantities.remove(id);
    });
  }

  Widget _buildBarcodeVisual(String code) {
    final safeCode = code.trim().isEmpty ? '000000' : code.trim();
    final barcodeData =
        pw.Barcode.code128().make(safeCode, width: 170, height: 38);
    return Container(
      height: 38,
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: CustomPaint(
        painter: _RealBarcodePainter(barcodeData),
      ),
    );
  }

  Future<Uint8List> _generateLabelsPdf(
    List<Product> selectedProducts,
    String paperSize,
  ) async {
    final doc = pw.Document();
    final currency = widget.settings.currencySymbol;
    final expanded = <Product>[];
    for (final p in selectedProducts) {
      final qty = _selectedProductQuantities[p.id] ?? 0;
      for (int i = 0; i < qty; i++) {
        expanded.add(p);
      }
    }

    final bool isRoll = _paperSize.contains('Roll') ||
        _paperSize.contains('Custom') ||
        _paperSize.contains('Jewelry');

    if (isRoll) {
      double widthMm = 50.0;
      double heightMm = 25.0;

      if (_paperSize.contains('38mm x 25mm')) {
        widthMm = 38.0;
        heightMm = 25.0;
      } else if (_paperSize.contains('40mm x 30mm')) {
        widthMm = 40.0;
        heightMm = 30.0;
      } else if (_paperSize.contains('100mm x 50mm')) {
        widthMm = 100.0;
        heightMm = 50.0;
      } else if (_paperSize.contains('38mm x 15mm')) {
        widthMm = 38.0;
        heightMm = 15.0;
      } else if (_paperSize.contains('Custom')) {
        widthMm = _customWidthMm > 10 ? _customWidthMm : 50.0;
        heightMm = _customHeightMm > 10 ? _customHeightMm : 25.0;
      }

      final pageFormat = PdfPageFormat(
        widthMm * PdfPageFormat.mm,
        heightMm * PdfPageFormat.mm,
        marginAll: 1.5 * PdfPageFormat.mm,
      );

      for (final p in expanded) {
        final code = p.barcode.trim().isEmpty ? p.sku : p.barcode.trim();
        final barcodeH = (heightMm * 0.40).clamp(10.0, 32.0);
        final barcodeW = (widthMm * 0.82).clamp(24.0, 220.0);
        final fontSizeName = (heightMm < 20 || widthMm < 40) ? 6.0 : 8.0;

        doc.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (_) => pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (_showBusinessName && heightMm >= 22)
                    pw.Text(
                      widget.settings.businessName,
                      style: const pw.TextStyle(
                          fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                      maxLines: 1,
                    ),
                  if (_showProductName)
                    pw.Text(
                      p.name,
                      style: pw.TextStyle(
                          fontSize: fontSizeName,
                          fontWeight: pw.FontWeight.bold),
                      maxLines: 1,
                    ),
                  pw.SizedBox(height: 1),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: code,
                    width: barcodeW,
                    height: barcodeH,
                    drawText: _showBarcodeNumber,
                    textStyle: const pw.TextStyle(fontSize: 6),
                  ),
                  if (_showPrice) ...[
                    pw.SizedBox(height: 1),
                    pw.Text(
                      '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: fontSizeName + 0.5,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                  if (_showExpiryDate &&
                      p.expiryDate != null &&
                      p.expiryDate!.isNotEmpty) ...[
                    pw.Text(
                      'EXP: ${p.expiryDate}',
                      style: const pw.TextStyle(fontSize: 5.5),
                    ),
                  ],
                  if (_showBatchNo &&
                      p.batchNumber != null &&
                      p.batchNumber!.isNotEmpty) ...[
                    pw.Text(
                      'BATCH: ${p.batchNumber}',
                      style: const pw.TextStyle(fontSize: 5.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }
      return doc.save();
    }

    // A4 Sheet Layout (24, 30, or 40 labels per A4 sheet)
    final int cols = _paperSize.contains('40') ? 4 : 3;
    final int perPage =
        _paperSize.contains('40') ? 40 : (_paperSize.contains('30') ? 30 : 24);
    final chunks = <List<Product>>[];
    for (int i = 0; i < expanded.length; i += perPage) {
      chunks.add(expanded.sublist(
          i, (i + perPage) > expanded.length ? expanded.length : i + perPage));
    }

    for (final pageItems in chunks) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (_) => pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pageItems.map((p) {
              final code = p.barcode.trim().isEmpty ? p.sku : p.barcode.trim();
              return pw.Container(
                width:
                    (PdfPageFormat.a4.availableWidth - ((cols - 1) * 8)) / cols,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    if (_showBusinessName)
                      pw.Text(
                        widget.settings.businessName,
                        style: const pw.TextStyle(
                            fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                    if (_showProductName)
                      pw.Text(
                        p.name,
                        style: const pw.TextStyle(
                            fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                    pw.SizedBox(height: 2),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: code,
                      width: 130,
                      height: 26,
                      drawText: _showBarcodeNumber,
                      textStyle: const pw.TextStyle(fontSize: 6.5),
                    ),
                    if (_showPrice) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '$currency ${p.sellingPrice.toStringAsFixed(2)}',
                        style: const pw.TextStyle(
                            fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                    if (_showExpiryDate &&
                        p.expiryDate != null &&
                        p.expiryDate!.isNotEmpty) ...[
                      pw.Text('EXP: ${p.expiryDate}',
                          style: const pw.TextStyle(fontSize: 6)),
                    ],
                    if (_showBatchNo &&
                        p.batchNumber != null &&
                        p.batchNumber!.isNotEmpty) ...[
                      pw.Text('BATCH: ${p.batchNumber}',
                          style: const pw.TextStyle(fontSize: 6)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final selectedProducts = _allProducts
        .where((p) => _selectedProductQuantities.containsKey(p.id))
        .toList();
    final totalLabelsToPrint =
        _selectedProductQuantities.values.fold(0, (sum, q) => sum + q);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Print Barcode Labels',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate and print custom barcode sticker labels for shelf placement and stock tagging.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text('Print $totalLabelsToPrint Labels',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: totalLabelsToPrint == 0
                      ? null
                      : () async {
                          final summary = selectedProducts
                              .map((p) =>
                                  '${_selectedProductQuantities[p.id]}x ${p.name} [${p.barcode}] - $currency${p.sellingPrice.toStringAsFixed(2)}')
                              .join('\n');
                          await showDialog(
                            context: context,
                            builder: (_) => UniversalPrintPreviewDialog(
                              title:
                                  'Barcode Labels Sheet ($totalLabelsToPrint labels)',
                              plainTextContent:
                                  'BARCODE LABELS PRINT JOB\nPaper: $_paperSize\nTotal Labels: $totalLabelsToPrint\n\n$summary',
                              settings: widget.settings,
                              defaultPaperSize: 'a4',
                              pdfGenerator: (paper) =>
                                  _generateLabelsPdf(selectedProducts, paper),
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Two Columns: Select Products & Label Settings
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Selected Products Queue
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Products in Print Queue',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        // Product Search & Add Dropdown
                        Autocomplete<Product>(
                          displayStringForOption: (p) => '${p.name} (${p.sku})',
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Product>.empty();
                            }
                            return _allProducts.where((p) =>
                                p.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase()) ||
                                p.sku.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase()) ||
                                p.barcode.contains(textEditingValue.text));
                          },
                          onSelected: (p) => _addProductToPrint(p),
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText:
                                    'Search product to add to print queue...',
                                hintStyle: const TextStyle(
                                    fontSize: 13, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search,
                                    size: 18, color: Color(0xFF94A3B8)),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0))),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        if (selectedProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: const Text(
                                'No products selected. Search above to add items.',
                                style: TextStyle(
                                    color: Color(0xFF94A3B8), fontSize: 13)),
                          )
                        else
                          Column(
                            children: selectedProducts.map((p) {
                              final qty = _selectedProductQuantities[p.id] ?? 1;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)),
                                          Text(
                                              'SKU: ${p.sku}  •  $currency${p.sellingPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 18,
                                              color: Color(0xFF64748B)),
                                          onPressed: qty > 1
                                              ? () => setState(() =>
                                                  _selectedProductQuantities[
                                                      p.id!] = qty - 1)
                                              : () => _removeProductFromPrint(
                                                  p.id!),
                                        ),
                                        Container(
                                          width: 36,
                                          alignment: Alignment.center,
                                          child: Text('$qty',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 18,
                                              color: Color(0xFF4F46E5)),
                                          onPressed: () => setState(() =>
                                              _selectedProductQuantities[
                                                  p.id!] = qty + 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Color(0xFFDC2626)),
                                          onPressed: () =>
                                              _removeProductFromPrint(p.id!),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                // Right Column: Label Format & Fields Settings
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Label Information & Format',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        const Text('Sheet / Roll Layout',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _paperSize,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          items: [
                            'Continuous Roll (50mm x 25mm)',
                            '38mm x 25mm (Thermal Roll)',
                            '40mm x 30mm (Thermal Roll)',
                            '100mm x 50mm (Shipping Roll)',
                            'Jewelry Tag (38mm x 15mm)',
                            'Custom Roll (mm)',
                            '24 Labels per Sheet (A4)',
                            '30 Labels per Sheet (A4)',
                            '40 Labels per Sheet (A4)',
                          ]
                              .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paperSize = val);
                          },
                        ),
                        if (_paperSize == 'Custom Roll (mm)') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      _customWidthMm.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Width (mm)',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final val = double.tryParse(v);
                                    if (val != null && val > 0) {
                                      setState(() => _customWidthMm = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue:
                                      _customHeightMm.toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Height (mm)',
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final val = double.tryParse(v);
                                    if (val != null && val > 0) {
                                      setState(() => _customHeightMm = val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Text('Fields to Print on Label',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Business Name',
                                    style: TextStyle(fontSize: 13)),
                                value: _showBusinessName,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(
                                    () => _showBusinessName = v ?? true),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Product Name & Unit',
                                    style: TextStyle(fontSize: 13)),
                                value: _showProductName,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(
                                    () => _showProductName = v ?? true),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text(
                                    'Show Retail Price (Inc. Tax)',
                                    style: TextStyle(fontSize: 13)),
                                value: _showPrice,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) =>
                                    setState(() => _showPrice = v ?? true),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Numeric Barcode / SKU',
                                    style: TextStyle(fontSize: 13)),
                                value: _showBarcodeNumber,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(
                                    () => _showBarcodeNumber = v ?? true),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Expiry Date',
                                    style: TextStyle(fontSize: 13)),
                                value: _showExpiryDate,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(
                                    () => _showExpiryDate = v ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                              CheckboxListTile(
                                dense: true,
                                title: const Text('Show Batch / Lot No',
                                    style: TextStyle(fontSize: 13)),
                                value: _showBatchNo,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) =>
                                    setState(() => _showBatchNo = v ?? false),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Section: Live Printable Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview_rounded,
                              size: 20, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 8),
                          Text(
                            'Live Print Preview ($_paperSize)',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalLabelsToPrint Sticker Labels to print',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (totalLabelsToPrint == 0)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text(
                          'Add items above to preview printable barcode labels.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: selectedProducts.expand((p) {
                        final qty = _selectedProductQuantities[p.id] ?? 0;
                        return List.generate(qty, (index) {
                          return Container(
                            width: 210,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.18)),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x04000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_showBusinessName)
                                  Text(
                                    widget.settings.businessName,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (_showProductName)
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                _buildBarcodeVisual(p.barcode),
                                const SizedBox(height: 2),
                                if (_showBarcodeNumber)
                                  Text(
                                    p.barcode,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold),
                                  ),
                                if (_showPrice) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Price: $currency${p.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A)),
                                  ),
                                ],
                                if (_showExpiryDate &&
                                    p.expiryDate != null &&
                                    p.expiryDate!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'EXP: ${p.expiryDate}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626)),
                                  ),
                                ],
                                if (_showBatchNo &&
                                    p.batchNumber != null &&
                                    p.batchNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    'BATCH: ${p.batchNumber}',
                                    style: const TextStyle(
                                        fontSize: 9, color: Color(0xFF475569)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        });
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealBarcodePainter extends CustomPainter {
  final Iterable<pw.BarcodeElement> elements;
  const _RealBarcodePainter(this.elements);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    for (final e in elements) {
      if (e is pw.BarcodeBar && e.black) {
        canvas.drawRect(
          Rect.fromLTWH(e.left, e.top, e.width, e.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RealBarcodePainter oldDelegate) =>
      oldDelegate.elements != elements;
}
