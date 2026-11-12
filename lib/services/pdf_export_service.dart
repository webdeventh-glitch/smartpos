import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'app_logger.dart';
import 'number_to_words_service.dart';

/// Generates vector PDF documents for Sales, Quotations, Purchases, and Reports,
/// respecting customizable [InvoiceLayout] templates, plus file export & email handoff.
class PdfExportService {
  PdfExportService._();

  static String _safeText(String input) {
    final buf = StringBuffer();
    for (final code in input.runes) {
      if (code >= 32 && code <= 126) {
        buf.writeCharCode(code);
      } else if (code == 10 || code == 13 || code == 9) {
        buf.writeCharCode(code);
      } else {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  static PdfColor _parseHexColor(String hex, {PdfColor fallback = PdfColors.blueGrey900}) {
    final clean = hex.trim().replaceFirst('#', '');
    if (clean.length == 6 || clean.length == 8) {
      try {
        final full = clean.length == 6 ? 'FF$clean' : clean;
        return PdfColor.fromInt(int.parse(full, radix: 16));
      } catch (e, st) {
        AppLogger.warning('PdfExportService', 'Invalid hex color "$hex"', e, st);
      }
    }
    return fallback;
  }

  static PdfPageFormat _resolvePageFormat({
    required String paperSize,
    required String orientation,
  }) {
    final size = paperSize.toLowerCase();
    if (size == '58mm' || size == '58mm thermal') return PdfPageFormat.roll57;
    if (size == '80mm' || size == '80mm pos') return PdfPageFormat.roll80;
    if (orientation.toLowerCase() == 'landscape') {
      return PdfPageFormat.a4.landscape;
    }
    return PdfPageFormat.a4;
  }

  static pw.MemoryImage? _tryLoadImage(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return null;
    try {
      final f = File(clean);
      if (!f.existsSync()) return null;
      final lower = clean.toLowerCase();
      if (!(lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg'))) {
        return null;
      }
      final data = f.readAsBytesSync();
      if (data.isEmpty) return null;
      return pw.MemoryImage(data);
    } catch (e, st) {
      AppLogger.warning('PdfExportService', 'Failed reading image "$clean"', e, st);
      return null;
    }
  }

  /// Generates a Sales Invoice or Quotation PDF following [layout] & [settings].
  static Future<Uint8List> generateSalePdf({
    required Sale sale,
    required BusinessSettings settings,
    InvoiceLayout? layout,
    String? paperSizeOverride,
    double? customerPreviousBalance,
    Map<int, String>? productImagePathsById,
  }) async {
    final activeLayout = layout ?? InvoiceLayout.fromBusinessSettings(settings);
    final paperSize = paperSizeOverride ?? activeLayout.paperSize;
    final pageFormat = _resolvePageFormat(
      paperSize: paperSize,
      orientation: activeLayout.paperOrientation,
    );
    final isThermalRoll =
        paperSize.toLowerCase().contains('58mm') || paperSize.toLowerCase().contains('80mm');
    final accent = _parseHexColor(activeLayout.highlightColor);
    final cur = _safeText(settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs');
    final baseFont = activeLayout.fontSize.clamp(7.5, 14.0).toDouble();
    final logoImg = activeLayout.showLogo ? _tryLoadImage(settings.logoPath) : null;

    final doc = pw.Document();

    final headingText = sale.isQuotation
        ? 'QUOTATION / ESTIMATE'
        : _safeText(
            activeLayout.invoiceHeading.isNotEmpty
                ? activeLayout.invoiceHeading
                : 'TAX INVOICE',
          );

    pw.Widget buildHeader() {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImg != null) ...[
                      pw.Container(
                        width: isThermalRoll ? 34 : 52,
                        height: isThermalRoll ? 34 : 52,
                        child: pw.Image(logoImg, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (activeLayout.showBusinessName)
                            pw.Text(
                              _safeText(settings.businessName.toUpperCase()),
                              style: pw.TextStyle(
                                fontSize: isThermalRoll ? baseFont + 2 : baseFont + 6,
                                fontWeight: pw.FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          if (settings.branchName.isNotEmpty)
                            pw.Text(
                              _safeText(settings.branchName),
                              style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold),
                            ),
                          if (activeLayout.showAddress && settings.address.isNotEmpty)
                            pw.Text(_safeText(settings.address), style: pw.TextStyle(fontSize: baseFont - 1)),
                          if (activeLayout.showPhone && settings.phone.isNotEmpty)
                            pw.Text(_safeText('Tel: ${settings.phone}'), style: pw.TextStyle(fontSize: baseFont - 1)),
                          if (activeLayout.showEmail && settings.email.isNotEmpty)
                            pw.Text(_safeText('Email: ${settings.email}'), style: pw.TextStyle(fontSize: baseFont - 1)),
                          if (activeLayout.showTaxNumber && settings.taxNumber.isNotEmpty)
                            pw.Text(_safeText('NTN / Tax ID: ${settings.taxNumber}'), style: pw.TextStyle(fontSize: baseFont - 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  headingText,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isThermalRoll ? baseFont : baseFont + 2,
                  ),
                ),
              ),
            ],
          ),
          if (activeLayout.headerText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              _safeText(activeLayout.headerText),
              style: pw.TextStyle(fontSize: baseFont - 0.5, fontStyle: pw.FontStyle.italic),
            ),
          ],
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _safeText('Invoice #: ${sale.invoiceNo}'),
                      style: pw.TextStyle(fontSize: baseFont, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      _safeText('Customer: ${sale.customerName}'),
                      style: pw.TextStyle(fontSize: baseFont - 0.5),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _safeText('Date: ${sale.createdAt}'),
                      style: pw.TextStyle(fontSize: baseFont - 0.5),
                    ),
                    pw.Text(
                      _safeText('Status: ${sale.saleStatus.toUpperCase()} | ${sale.paymentMethod.toUpperCase()}'),
                      style: pw.TextStyle(fontSize: baseFont - 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    final items = sale.items ?? const <SaleItem>[];

    pw.Widget buildItemsTable() {
      final showSku = !isThermalRoll && activeLayout.showSku;
      final showBatch = !isThermalRoll && activeLayout.showBatch;
      final showExpiry = !isThermalRoll && activeLayout.showExpiry;
      final showImg = !isThermalRoll && activeLayout.showImage;

      final headers = <String>[
        if (showImg) 'Img',
        'Item Description',
        if (showSku) 'SKU',
        if (showBatch) 'Batch',
        if (showExpiry) 'Expiry',
        'Qty',
        'Rate',
        'Disc',
        'Total',
      ];

      final tableRows = <pw.TableRow>[
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: baseFont - 0.5,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ];

      for (int idx = 0; idx < items.length; idx++) {
        final it = items[idx];
        final qtyStr = it.quantity % 1 == 0
            ? it.quantity.toInt().toString()
            : it.quantity.toStringAsFixed(2);
        final img = showImg && productImagePathsById != null
            ? _tryLoadImage(productImagePathsById[it.productId] ?? '')
            : null;

        pw.Widget cell(String text, {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) =>
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: pw.Text(
                _safeText(text),
                textAlign: align,
                style: pw.TextStyle(
                  fontSize: baseFont - 0.8,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            );

        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: idx.isOdd ? PdfColors.grey50 : PdfColors.white,
            ),
            children: [
              if (showImg)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: img != null
                      ? pw.Image(img, width: 20, height: 20, fit: pw.BoxFit.cover)
                      : pw.Text('-', style: pw.TextStyle(fontSize: baseFont - 1)),
                ),
              cell(
                it.displayName +
                    (activeLayout.showBrand ? '' : ''),
                bold: true,
              ),
              if (showSku) cell(it.sku.isEmpty ? '-' : it.sku),
              if (showBatch) cell(it.batchNumber ?? '-'),
              if (showExpiry) cell(it.expiryDate ?? '-'),
              cell(qtyStr, align: pw.TextAlign.right),
              cell(it.unitPrice.toStringAsFixed(2), align: pw.TextAlign.right),
              cell(
                it.resolvedDiscountAmount > 0
                    ? it.formatDiscountTag(cur)
                    : '0.00',
                align: pw.TextAlign.right,
              ),
              cell(it.subtotal.toStringAsFixed(2), align: pw.TextAlign.right, bold: true),
            ],
          ),
        );
      }

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
        children: tableRows,
      );
    }

    pw.Widget buildSummaryAndFooter() {
      final words = activeLayout.showTotalInWords
          ? NumberToWordsService.convert(
              sale.totalAmount,
              language: 'en',
              currencySymbol: cur,
              currencyCode: settings.currencyCode,
            )
          : '';

      pw.Widget totalLine(String label, String val, {bool bold = false}) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _safeText(label),
                  style: pw.TextStyle(
                    fontSize: baseFont,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
                pw.Text(
                  _safeText(val),
                  style: pw.TextStyle(
                    fontSize: baseFont,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
          );

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (words.isNotEmpty)
                      pw.Text(
                        _safeText('In Words: $words'),
                        style: pw.TextStyle(fontSize: baseFont - 1, fontStyle: pw.FontStyle.italic),
                      ),
                    if (activeLayout.showCustomerBalance &&
                        customerPreviousBalance != null &&
                        customerPreviousBalance > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _safeText(
                          'Previous Khata Balance: $cur ${customerPreviousBalance.toStringAsFixed(2)}',
                        ),
                        style: pw.TextStyle(fontSize: baseFont - 0.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                    if (activeLayout.showQrCode) ...[
                      pw.SizedBox(height: 8),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'INV:${sale.invoiceNo}|TOTAL:${sale.totalAmount.toStringAsFixed(2)}',
                        width: isThermalRoll ? 48 : 58,
                        height: isThermalRoll ? 48 : 58,
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: isThermalRoll ? 130 : 210,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    totalLine(activeLayout.subTotalLabel, '$cur ${sale.subtotal.toStringAsFixed(2)}'),
                    if (sale.discount > 0)
                      totalLine(activeLayout.discountLabel, '-$cur ${sale.discount.toStringAsFixed(2)}'),
                    if (sale.taxAmount > 0) ...[
                      for (final entry in sale.taxBreakdownMap.entries)
                        totalLine(entry.key, '+$cur ${entry.value.toStringAsFixed(2)}'),
                      totalLine(activeLayout.taxLabel, '+$cur ${sale.taxAmount.toStringAsFixed(2)}'),
                    ],
                    pw.Divider(),
                    totalLine(
                      activeLayout.totalLabel,
                      '$cur ${sale.totalAmount.toStringAsFixed(2)}',
                      bold: true,
                    ),
                    totalLine('Paid', '$cur ${sale.paidAmount.toStringAsFixed(2)}'),
                    if (sale.dueAmount > 0)
                      totalLine('Balance Due', '$cur ${sale.dueAmount.toStringAsFixed(2)}', bold: true),
                  ],
                ),
              ),
            ],
          ),
          if (activeLayout.showBarcode && sale.invoiceNo.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: _safeText(sale.invoiceNo),
                width: isThermalRoll ? 130 : 180,
                height: 32,
                drawText: true,
              ),
            ),
          ],
          if (activeLayout.termsText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              _safeText('Terms & Conditions: ${activeLayout.termsText}'),
              style: pw.TextStyle(fontSize: baseFont - 1.2, color: PdfColors.grey700),
            ),
          ],
          if (activeLayout.showSignature && !isThermalRoll) ...[
            pw.SizedBox(height: 22),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 0.8, color: PdfColors.grey600),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _safeText(activeLayout.signatureLabel),
                      style: pw.TextStyle(fontSize: baseFont - 1),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (activeLayout.footerText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                _safeText(activeLayout.footerText),
                style: pw.TextStyle(fontSize: baseFont - 0.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ],
      );
    }

    if (isThermalRoll) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              buildHeader(),
              pw.SizedBox(height: 8),
              buildItemsTable(),
              buildSummaryAndFooter(),
            ],
          ),
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          build: (_) => [
            buildHeader(),
            pw.SizedBox(height: 12),
            buildItemsTable(),
            buildSummaryAndFooter(),
          ],
        ),
      );
    }

    return doc.save();
  }

  /// Generates a Quotation PDF wrapper around [generateSalePdf].
  static Future<Uint8List> generateQuotationPdf({
    required Sale quotation,
    required BusinessSettings settings,
    InvoiceLayout? layout,
  }) =>
      generateSalePdf(
        sale: quotation,
        settings: settings,
        layout: layout,
        paperSizeOverride: 'a4',
      );

  /// Generates an A4 Purchase Order / Goods Receipt PDF.
  static Future<Uint8List> generatePurchasePdf({
    required Purchase purchase,
    required BusinessSettings settings,
  }) async {
    final doc = pw.Document();
    final cur = _safeText(settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs');
    final logoImg = settings.showLogoOnReceipt ? _tryLoadImage(settings.logoPath) : null;
    final items = purchase.getItems();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  if (logoImg != null) ...[
                    pw.Image(logoImg, width: 48, height: 48),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _safeText(settings.businessName.toUpperCase()),
                        style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(_safeText('Branch: ${purchase.locationName}'), style: const pw.TextStyle(fontSize: 10)),
                      if (settings.phone.isNotEmpty)
                        pw.Text(_safeText('Tel: ${settings.phone}'), style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: PdfColors.indigo900,
                child: pw.Text(
                  'PURCHASE VOUCHER / GRN',
                  style: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_safeText('PO / Ref No: ${purchase.refNo}'), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text(_safeText('Supplier: ${purchase.supplierName}'), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(_safeText('Date: ${purchase.createdAt}'), style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(_safeText('Status: ${purchase.status.toUpperCase()} | Pay: ${purchase.paymentStatus.toUpperCase()}'), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Product', 'Qty', 'Unit Cost', 'Subtotal'],
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            data: items.map((it) {
              final qty = (it['quantity'] as num?)?.toDouble() ?? 1.0;
              final cost = (it['purchase_price'] as num?)?.toDouble() ??
                  (it['unit_cost'] as num?)?.toDouble() ??
                  0.0;
              final sub = (it['subtotal'] as num?)?.toDouble() ?? (qty * cost);
              return [
                _safeText((it['product_name'] ?? 'Product').toString()),
                qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2),
                '$cur ${cost.toStringAsFixed(2)}',
                '$cur ${sub.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Purchase:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('$cur ${purchase.totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Paid Amount:', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('$cur ${purchase.paidAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  if (purchase.dueAmount > 0) ...[
                    pw.SizedBox(height: 3),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Payable Due:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('$cur ${purchase.dueAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Generates a multi-page A4 Business Report PDF from structured tabular rows & KPIs.
  static Future<Uint8List> generateReportPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required BusinessSettings settings,
    Map<String, String>? summaryMetrics,
  }) async {
    final doc = pw.Document();
    final logoImg = settings.showLogoOnReceipt ? _tryLoadImage(settings.logoPath) : null;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  if (logoImg != null) ...[
                    pw.Image(logoImg, width: 42, height: 42),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _safeText(settings.businessName.toUpperCase()),
                        style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(_safeText(title), style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.Text(_safeText(subtitle), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Text(
                'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          if (summaryMetrics != null && summaryMetrics.isNotEmpty) ...[
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summaryMetrics.entries
                  .map(
                    (e) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_safeText(e.key), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(_safeText(e.value), style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 12),
          ],
          pw.TableHelper.fromTextArray(
            headers: headers.map(_safeText).toList(),
            data: rows.map((r) => r.map(_safeText).toList()).toList(),
            headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Saves PDF bytes to the user Downloads folder (or [directoryOverride] in tests).
  static Future<File> savePdfFile(
    Uint8List bytes,
    String baseName, {
    Directory? directoryOverride,
  }) async {
    Directory targetDir;
    if (directoryOverride != null) {
      targetDir = directoryOverride;
    } else {
      final userProfile = Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
      final dl = Directory('$userProfile\\Downloads');
      targetDir = dl.existsSync() ? dl : Directory.systemTemp;
    }
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final cleanBase = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final outFile = File('${targetDir.path}${Platform.pathSeparator}${cleanBase}_$stamp.pdf');
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile;
  }

  /// Opens saved PDF using the OS default PDF handler (Edge/Adobe/Preview) for instant print/view.
  static Future<bool> openPdfFile(File file) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '', file.path]);
        return true;
      }
      await Process.run('open', [file.path]);
      return true;
    } catch (e, st) {
      AppLogger.warning('PdfExportService', 'Failed opening PDF file "${file.path}"', e, st);
      return false;
    }
  }

  /// Exports [bytes] to a PDF file and opens the user's default mail client with prefilled
  /// invoice details (`mailto:`) plus saved file path for quick attachment.
  static Future<File> emailPdfInvoice({
    required Uint8List bytes,
    required String baseName,
    String recipientEmail = '',
    required String subject,
    required String body,
    Directory? directoryOverride,
  }) async {
    final savedFile = await savePdfFile(
      bytes,
      baseName,
      directoryOverride: directoryOverride,
    );
    final enrichedBody =
        '$body\n\n---\nPDF Invoice Saved At:\n${savedFile.path}\n(Please attach this generated PDF file before sending.)';
    final uri = Uri(
      scheme: 'mailto',
      path: recipientEmail.trim(),
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(enrichedBody)}',
    );
    try {
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '', uri.toString()]);
      }
    } catch (e, st) {
      AppLogger.warning('PdfExportService', 'Failed opening mailto client', e, st);
    }
    return savedFile;
  }
}
