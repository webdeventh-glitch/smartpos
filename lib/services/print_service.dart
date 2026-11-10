import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PrintService {
  /// Opens Windows print dialog via an optimized, print-ready HTML page
  static Future<bool> openPrintWindow({
    required String htmlContent,
    required String title,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final cleanTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final tempFile = File('${tempDir.path}\\smartpos_${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.html');
      await tempFile.writeAsString(htmlContent);

      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', '', tempFile.path]);
        return true;
      } else {
        // Fallback for other platforms
        await Process.run('open', [tempFile.path]);
        return true;
      }
    } catch (e) {
      debugPrint('[PrintService] Error opening print window: $e');
      return false;
    }
  }

  /// Copies receipt or document text to clipboard
  static Future<void> copyToClipboard(String text, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Document content copied to clipboard!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Saves HTML document to Downloads folder
  static Future<void> saveHtmlToFile(String htmlContent, String baseName, BuildContext context) async {
    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public';
      final downloadDir = Directory('$userProfile\\Downloads');
      final targetDir = await downloadDir.exists() ? downloadDir : Directory(userProfile);
      final fileName = '${baseName}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.html';
      final file = File('${targetDir.path}\\$fileName');
      await file.writeAsString(htmlContent);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved to: ${file.path}'),
            backgroundColor: const Color(0xFF4F46E5),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ================= 1. BILL / THERMAL SALES INVOICE =================
  static String generateSaleInvoiceHtml({
    required Sale sale,
    required BusinessSettings settings,
    double tenderedAmount = 0.0,
    double changeReturn = 0.0,
    String? paperSizeOverride,
    double? customerPreviousBalance,
  }) {
    final cur = settings.currencySymbol;
    final paperSize = (paperSizeOverride ?? settings.receiptPaperSize).toLowerCase();
    final isA4 = paperSize == 'a4' || paperSize == 'a4 agency';
    if (isA4) {
      return generateA4AgencyInvoiceHtml(
        sale: sale,
        settings: settings,
        customerPreviousBalance: customerPreviousBalance,
      );
    }
    final is58mm = paperSize == '58mm';
    final pageSizeCss = is58mm ? '58mm auto' : '80mm auto';
    final maxWidthCss = is58mm ? '48mm' : '72mm';
    final fontSizeCss = is58mm ? '10px' : '12px';

    final itemsHtml = StringBuffer();
    if (sale.items != null) {
      for (int i = 0; i < sale.items!.length; i++) {
        final item = sale.items![i];
        final qStr = item.quantity == item.quantity.toInt()
            ? item.quantity.toInt().toString()
            : item.quantity.toStringAsFixed(2);
        final uLabel = item.unitName != null && item.unitName!.isNotEmpty ? ' ${item.unitName}' : '';
        // Thermal Slip Layout
        itemsHtml.writeln('''
          <tr style="border-bottom: 1px dashed #ccc;">
            <td colspan="4" style="padding-top: 4px; font-weight: bold;">${_escape(item.productName)}</td>
          </tr>
          <tr style="border-bottom: 1px dotted #ddd;">
            <td style="padding-bottom: 4px;">$qStr$uLabel x $cur${item.unitPrice.toStringAsFixed(2)}</td>
            <td style="padding-bottom: 4px; text-align:center;">${item.batchNumber != null && item.batchNumber!.isNotEmpty ? 'B:${item.batchNumber}' : ''}</td>
            <td style="padding-bottom: 4px; text-align:right;">${item.packDiscount > 0 ? '-${item.packDiscount}%' : ''}</td>
            <td style="padding-bottom: 4px; text-align:right; font-weight: bold;">$cur${item.subtotal.toStringAsFixed(2)}</td>
          </tr>
        ''');
      }
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invoice - ${sale.invoiceNo}</title>
  <style>
    @page {
      size: $pageSizeCss;
      margin: 4mm;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 0;
      color: #000;
      background: #fff;
      font-size: $fontSizeCss;
      line-height: 1.35;
    }
    .ticket {
      max-width: $maxWidthCss;
      margin: 0 auto;
      padding: 2mm;
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    .title { font-size: ${isA4 ? '22px' : '16px'}; font-weight: 900; letter-spacing: 0.5px; margin: 0; }
    .subtitle { font-size: 11px; color: #333; margin: 2px 0 6px 0; }
    .divider { border-top: 1px dashed #000; margin: 6px 0; }
    .double-divider { border-top: 2px solid #000; margin: 6px 0; }
    table { width: 100%; border-collapse: collapse; font-size: inherit; }
    th { border-bottom: 1px solid #000; padding: 4px; font-weight: bold; text-align: left; }
    td { padding: 3px 2px; }
    .totals-row td { padding: 2px 0; }
    .grand-total { font-size: ${isA4 ? '18px' : '15px'}; font-weight: 900; }
    .barcode-box { text-align: center; margin: 10px 0 4px 0; letter-spacing: 4px; font-family: monospace; font-size: 14px; }
    .footer-note { font-size: 10px; text-align: center; margin-top: 8px; color: #444; }
    @media print {
      body { margin: 0; }
      .no-print { display: none !important; }
    }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.print(); }, 250);
    });
  </script>
</head>
<body>
  <div class="ticket">
    <!-- Header -->
    <div class="text-center">
      <div class="title">${_escape(settings.businessName.toUpperCase())}</div>
      ${settings.receiptHeaderTagline.isNotEmpty ? '<div class="subtitle">' + _escape(settings.receiptHeaderTagline) + '</div>' : ''}
      <div style="font-size: 11px;">${_escape(settings.branchName)} &bull; ${_escape(settings.address)}</div>
      ${settings.phone.isNotEmpty ? '<div style="font-size: 11px;">Ph: ' + _escape(settings.phone) + '</div>' : ''}
      ${settings.taxNumber.isNotEmpty ? '<div style="font-size: 11px; font-weight: bold;">NTN / GST: ' + _escape(settings.taxNumber) + '</div>' : ''}
    </div>

    ${settings.receiptHeaderNote.isNotEmpty ? '<div class="text-center" style="font-size: 11px; font-style: italic; margin-top: 4px;">' + _escape(settings.receiptHeaderNote) + '</div>' : ''}

    <div class="divider"></div>

    <!-- Invoice Meta Information -->
    <table>
      <tr>
        <td><strong>INVOICE #:</strong> ${_escape(sale.invoiceNo)}</td>
        <td class="text-right"><strong>DATE:</strong> ${_formatDateTime(sale.createdAt)}</td>
      </tr>
      <tr>
        <td><strong>CUSTOMER:</strong> ${_escape(sale.customerName)}</td>
        <td class="text-right"><strong>MODE:</strong> ${_escape(sale.paymentMethod.toUpperCase())}</td>
      </tr>
      ${settings.showCashierNameOnReceipt && sale.userName != null ? '<tr><td colspan="2"><strong>CASHIER:</strong> ' + _escape(sale.userName!) + '</td></tr>' : ''}
    </table>

    <div class="divider"></div>

    <!-- Itemized List Table -->
    <table>
      ${isA4 ? '''
        <thead>
          <tr>
            <th style="width: 28px; text-align:center;">#</th>
            <th>Item Description</th>
            <th>Batch</th>
            <th>Expiry</th>
            <th style="text-align:center;">Qty</th>
            <th style="text-align:right;">Rate</th>
            <th style="text-align:right;">Disc</th>
            <th style="text-align:right;">Total</th>
          </tr>
        </thead>
      ''' : '''
        <thead>
          <tr>
            <th colspan="2">Item</th>
            <th style="text-align:right;">Disc</th>
            <th style="text-align:right;">Total</th>
          </tr>
        </thead>
      '''}
      <tbody>
        $itemsHtml
      </tbody>
    </table>

    <div class="divider"></div>

    <!-- Calculation Totals -->
    <table class="totals-row">
      <tr>
        <td>Gross Subtotal:</td>
        <td class="text-right bold">$cur${sale.subtotal.toStringAsFixed(2)}</td>
      </tr>
      ${sale.discount > 0 ? '''
      <tr>
        <td>Bill Discount:</td>
        <td class="text-right bold" style="color: #dc2626;">-$cur${sale.discount.toStringAsFixed(2)}</td>
      </tr>
      ''' : ''}
      ${settings.showTaxBreakdownOnReceipt && sale.taxAmount > 0 ? '''
      <tr>
        <td>Taxes / GST:</td>
        <td class="text-right bold">+$cur${sale.taxAmount.toStringAsFixed(2)}</td>
      </tr>
      ''' : ''}
      <tr class="grand-total">
        <td style="border-top: 1px solid #000; border-bottom: 2px solid #000; padding: 4px 0;">NET AMOUNT DUE:</td>
        <td class="text-right" style="border-top: 1px solid #000; border-bottom: 2px solid #000; padding: 4px 0;">$cur${sale.totalAmount.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td style="padding-top: 4px;">Amount Tendered / Paid:</td>
        <td class="text-right bold" style="padding-top: 4px;">$cur${(tenderedAmount > 0 ? tenderedAmount : sale.paidAmount).toStringAsFixed(2)}</td>
      </tr>
      ${changeReturn > 0 ? '''
      <tr>
        <td>Change Returned:</td>
        <td class="text-right bold">$cur${changeReturn.toStringAsFixed(2)}</td>
      </tr>
      ''' : ''}
      ${sale.note != null && sale.note!.contains('Foreign') ? '''
      <tr>
        <td colspan="2" style="font-size: 9.5px; color: #374151; font-style: italic; padding: 2px 0; border-top: 1px dashed #ccc;">${_escape(sale.note!)}</td>
      </tr>
      ''' : ''}
      ${settings.showCustomerBalanceOnReceipt && sale.dueAmount > 0 ? '''
      <tr style="color: #b91c1c; font-weight: bold;">
        <td>CURRENT BILL DUE:</td>
        <td class="text-right">$cur${sale.dueAmount.toStringAsFixed(2)}</td>
      </tr>
      ''' : ''}
    </table>

    <!-- Barcode & QR Code simulation -->
    ${settings.showBarcodeOnReceipt ? '''
      <div class="barcode-box">
        <div style="display:inline-block; border-left: 2px solid #000; border-right: 2px solid #000; padding: 2px 8px; font-weight:bold;">
          ||| |||| | ||||| ||| || ||||
        </div>
        <div style="font-size: 10px; letter-spacing: 1px;">*${_escape(sale.invoiceNo)}*</div>
      </div>
    ''' : ''}

    <div class="double-divider"></div>

    <!-- Return Policy & Footer Notice -->
    <div class="footer-note">
      ${settings.receiptReturnPolicy.isNotEmpty ? '<div>' + _escape(settings.receiptReturnPolicy) + '</div>' : ''}
      ${settings.receiptFooter.isNotEmpty ? '<div style="margin-top: 4px; font-weight: bold;">' + _escape(settings.receiptFooter) + '</div>' : ''}
      <div style="margin-top: 4px; font-size: 9px; color: #888;">Generated by Smart POS Enterprise System</div>
    </div>
  </div>
</body>
</html>
''';
  }

  // ================= 2. QUOTATION / ESTIMATE DOCUMENT =================
  static String generateQuotationHtml({
    Sale? quotation,
    Sale? sale,
    required BusinessSettings settings,
    String validDays = '15',
    String? paperSize,
    String? paperSizeOverride,
  }) {
    final effectiveQuotation = quotation ?? sale!;
    final cur = settings.currencySymbol;
    final itemsHtml = StringBuffer();
    if (effectiveQuotation.items != null) {
      for (int i = 0; i < effectiveQuotation.items!.length; i++) {
        final item = effectiveQuotation.items![i];
        final qStr = item.quantity == item.quantity.toInt()
            ? item.quantity.toInt().toString()
            : item.quantity.toStringAsFixed(2);
        final uLabel = item.unitName != null && item.unitName!.isNotEmpty ? ' ${item.unitName}' : '';
        itemsHtml.writeln('''
          <tr>
            <td style="text-align:center; padding: 6px;">${i + 1}</td>
            <td style="padding: 6px; font-weight:bold;">${_escape(item.productName)}</td>
            <td style="text-align:center; padding: 6px;">$qStr$uLabel</td>
            <td style="text-align:right; padding: 6px;">$cur${item.unitPrice.toStringAsFixed(2)}</td>
            <td style="text-align:right; padding: 6px;">${item.packDiscount > 0 ? '${item.packDiscount}%' : '-'}</td>
            <td style="text-align:right; padding: 6px; font-weight:bold;">$cur${item.subtotal.toStringAsFixed(2)}</td>
          </tr>
        ''');
      }
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Quotation - ${effectiveQuotation.invoiceNo}</title>
  <style>
    @page { size: A4 portrait; margin: 12mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 13px; color: #1e293b; line-height: 1.4; }
    .box { border: 1px solid #cbd5e1; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #f1f5f9; padding: 8px 6px; text-align: left; font-size: 12px; border-bottom: 2px solid #94a3b8; }
    td { border-bottom: 1px solid #e2e8f0; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    @media print { body { margin: 0; } }
  </style>
  <script>
    window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });
  </script>
</head>
<body>
  <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #4f46e5; padding-bottom: 14px; margin-bottom: 16px;">
    <div>
      <h1 style="margin: 0; font-size: 24px; color: #4f46e5;">${_escape(settings.businessName.toUpperCase())}</h1>
      <div style="font-size: 13px; color: #475569;">${_escape(settings.branchName)} &bull; ${_escape(settings.address)}</div>
      <div style="font-size: 13px; color: #475569;">Contact: ${_escape(settings.phone)} | Email: ${_escape(settings.email)}</div>
      ${settings.taxNumber.isNotEmpty ? '<div style="font-size: 12px; font-weight: bold;">NTN / Tax ID: ${_escape(settings.taxNumber)}</div>' : ''}
    </div>
    <div style="text-align: right;">
      <div style="font-size: 22px; font-weight: 900; color: #0f172a; letter-spacing: 1px;">COMMERCIAL QUOTATION</div>
      <div style="font-size: 14px; font-weight: bold; color: #4f46e5; margin-top: 4px;">REF: ${_escape(effectiveQuotation.invoiceNo)}</div>
      <div style="font-size: 12px; color: #64748b;">DATE: ${_formatDateTime(effectiveQuotation.createdAt)}</div>
      <div style="font-size: 12px; color: #b91c1c; font-weight: bold; margin-top: 2px;">VALIDITY: $validDays Days</div>
    </div>
  </div>

  <div class="box" style="background: #f8fafc;">
    <strong>PROSPECTIVE CLIENT / PARTY DETAILS:</strong>
    <div style="font-size: 16px; font-weight: bold; color: #0f172a; margin-top: 4px;">${_escape(effectiveQuotation.customerName)}</div>
    <div style="font-size: 12px; color: #64748b;">Quotation status: Formal Estimate &bull; Currency: ${_escape(settings.currencyCode)}</div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 35px; text-align: center;">S#</th>
        <th>Product Description & Specification</th>
        <th style="width: 70px; text-align: center;">Quantity</th>
        <th style="width: 110px; text-align: right;">Quoted Rate</th>
        <th style="width: 80px; text-align: right;">Disc %</th>
        <th style="width: 120px; text-align: right;">Total ($cur)</th>
      </tr>
    </thead>
    <tbody>
      $itemsHtml
    </tbody>
  </table>

  <div style="display: flex; justify-content: flex-end; margin-top: 16px;">
    <table style="width: 320px; font-size: 14px;">
      <tr>
        <td>Subtotal:</td>
        <td class="text-right bold">$cur${effectiveQuotation.subtotal.toStringAsFixed(2)}</td>
      </tr>
      ${effectiveQuotation.discount > 0 ? '<tr><td>Discount:</td><td class="text-right bold" style="color:#dc2626;">-$cur${effectiveQuotation.discount.toStringAsFixed(2)}</td></tr>' : ''}
      ${effectiveQuotation.taxAmount > 0 ? '<tr><td>Estimated Taxes:</td><td class="text-right bold">+$cur${effectiveQuotation.taxAmount.toStringAsFixed(2)}</td></tr>' : ''}
      <tr style="font-size: 16px; font-weight: 900; border-top: 2px solid #0f172a;">
        <td style="padding: 8px 0;">NET QUOTED TOTAL:</td>
        <td class="text-right" style="padding: 8px 0; color: #4f46e5;">$cur${effectiveQuotation.totalAmount.toStringAsFixed(2)}</td>
      </tr>
    </table>
  </div>

  <div style="margin-top: 36px; padding: 12px; border-left: 4px solid #4f46e5; background: #f8fafc; font-size: 11px; color: #475569;">
    <strong>TERMS & CONDITIONS OF QUOTATION:</strong><br>
    1. The prices quoted above are valid for $validDays days from the date of issue.<br>
    2. Delivery schedule and stock allocation will be finalized upon formal purchase order confirmation.<br>
    3. Payment terms as agreed upon invoice generation. This document constitutes a formal price estimate and is not a tax invoice.
  </div>

  <div style="margin-top: 60px; display: flex; justify-content: space-between;">
    <div style="text-align: center; width: 220px; border-top: 1px solid #000; padding-top: 6px; font-size: 12px; font-weight: bold;">
      Client Acceptance & Stamp
    </div>
    <div style="text-align: center; width: 220px; border-top: 1px solid #000; padding-top: 6px; font-size: 12px; font-weight: bold;">
      Authorized Signatory (${_escape(settings.businessName)})
    </div>
  </div>
</body>
</html>
''';
  }

  // ================= 3. PRICE LIST / PRODUCT CATALOG =================
  static String generatePriceListHtml({
    required List<Product> products,
    required BusinessSettings settings,
    String? categoryFilter,
    String? paperSize,
    String? paperSizeOverride,
  }) {
    final cur = settings.currencySymbol;
    final rowsHtml = StringBuffer();

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final inStock = p.stockQuantity > 0;
      rowsHtml.writeln('''
        <tr style="background: ${i % 2 == 0 ? '#ffffff' : '#f8fafc'};">
          <td style="text-align:center; padding: 6px 4px;">${i + 1}</td>
          <td style="font-weight: bold; padding: 6px 8px;">${_escape(p.name)}</td>
          <td style="padding: 6px 8px; color: #475569;">${_escape(p.categoryName)}</td>
          <td style="padding: 6px 8px; font-family: monospace;">${_escape(p.sku.isNotEmpty ? p.sku : p.barcode)}</td>
          <td style="text-align:center; padding: 6px 4px;">${_escape(p.unit)}</td>
          <td style="text-align:right; padding: 6px 8px; font-weight: bold; color: #0284c7;">$cur${p.purchasePrice.toStringAsFixed(2)}</td>
          <td style="text-align:right; padding: 6px 8px; font-weight: 900; color: #059669;">$cur${p.sellingPrice.toStringAsFixed(2)}</td>
          <td style="text-align:center; padding: 6px 4px;">
            <span style="display:inline-block; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold; background: ${inStock ? '#dcfce7' : '#fee2e2'}; color: ${inStock ? '#166534' : '#991b1b'};">
              ${inStock ? '${p.stockQuantity.toStringAsFixed(0)} in stock' : 'Out of stock'}
            </span>
          </td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Price List - ${settings.businessName}</title>
  <style>
    @page { size: A4 portrait; margin: 10mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 12px; color: #1e293b; margin: 0; padding: 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th { background: #0f172a; color: #ffffff; padding: 8px 6px; text-align: left; font-size: 11px; }
    td { border-bottom: 1px solid #e2e8f0; font-size: 11.5px; }
    .text-right { text-align: right; }
    @media print { body { margin: 0; } }
  </style>
  <script>
    window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });
  </script>
</head>
<body>
  <div style="display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 3px solid #0f172a; padding-bottom: 8px;">
    <div>
      <h2 style="margin: 0; font-size: 20px; color: #0f172a;">${_escape(settings.businessName.toUpperCase())}</h2>
      <div style="font-size: 12px; color: #64748b;">${_escape(settings.branchName)} &bull; Official Product Rate Card & Price Catalog</div>
    </div>
    <div style="text-align: right; font-size: 11px;">
      <div><strong>TOTAL ITEMS:</strong> ${products.length}</div>
      ${categoryFilter != null ? '<div><strong>CATEGORY:</strong> ' + _escape(categoryFilter) + '</div>' : ''}
      <div><strong>DATE:</strong> ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 30px; text-align: center;">S#</th>
        <th>Product Name</th>
        <th style="width: 100px;">Category</th>
        <th style="width: 110px;">Code / SKU</th>
        <th style="width: 45px; text-align: center;">Unit</th>
        <th style="width: 90px; text-align: right;">Cost Price</th>
        <th style="width: 95px; text-align: right;">Retail Price</th>
        <th style="width: 90px; text-align: center;">Availability</th>
      </tr>
    </thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>

  <div style="margin-top: 20px; font-size: 10px; color: #888; text-align: center; border-top: 1px solid #e2e8f0; padding-top: 8px;">
    Prices and inventory stock are subject to commercial change without prior notice. Generated by Smart POS Enterprise.
  </div>
</body>
</html>
''';
  }

  // ================= 4. DEFAULTERS / DUES RECOVERY SHEET =================
  static String generateDefaultersListHtml({
    required List<Contact> defaulters,
    required BusinessSettings settings,
    String? paperSize,
    String? paperSizeOverride,
  }) {
    final cur = settings.currencySymbol;
    final rowsHtml = StringBuffer();
    double grandTotalDues = 0.0;

    for (int i = 0; i < defaulters.length; i++) {
      final c = defaulters[i];
      final due = c.balance > 0 ? c.balance : 0.0;
      grandTotalDues += due;
      rowsHtml.writeln('''
        <tr style="background: ${i % 2 == 0 ? '#ffffff' : '#fff5f5'};">
          <td style="text-align:center; padding: 8px 4px;">${i + 1}</td>
          <td style="font-weight: bold; padding: 8px;">
            ${_escape(c.name)}
            ${c.businessName != null && c.businessName!.isNotEmpty ? '<br><span style="font-size: 10px; color: #64748b;">Shop: ' + _escape(c.businessName!) + '</span>' : ''}
          </td>
          <td style="padding: 8px; font-family: monospace;">${_escape(c.phone.isNotEmpty ? c.phone : '-')}</td>
          <td style="padding: 8px; font-size: 11px; color: #475569;">${_escape(c.address.isNotEmpty ? c.address : '-')}</td>
          <td style="text-align:right; padding: 8px; color: #64748b;">$cur${c.creditLimit.toStringAsFixed(2)}</td>
          <td style="text-align:right; padding: 8px; font-weight: 900; color: #dc2626; font-size: 13px;">$cur${due.toStringAsFixed(2)}</td>
          <td style="border-left: 1px solid #e2e8f0; width: 140px; padding: 4px;"></td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Defaulters Recovery Sheet - ${settings.businessName}</title>
  <style>
    @page { size: A4 landscape; margin: 10mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 12px; color: #1e293b; margin: 0; padding: 0; }
    table { width: 100%; border-collapse: collapse; margin-top: 12px; }
    th { background: #991b1b; color: #ffffff; padding: 8px 6px; text-align: left; font-size: 11.5px; }
    td { border-bottom: 1px solid #fee2e2; }
    .text-right { text-align: right; }
    @media print { body { margin: 0; } }
  </style>
  <script>
    window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });
  </script>
</head>
<body>
  <div style="display: flex; justify-content: space-between; align-items: flex-end; border-bottom: 3px solid #991b1b; padding-bottom: 8px;">
    <div>
      <h2 style="margin: 0; font-size: 20px; color: #991b1b;">${_escape(settings.businessName.toUpperCase())}</h2>
      <div style="font-size: 13px; font-weight: bold; color: #0f172a;">CREDIT DEFAULTERS & OUTSTANDING RECEIVABLES RECOVERY SHEET</div>
      <div style="font-size: 11px; color: #64748b;">Branch: ${_escape(settings.branchName)} &bull; Contact: ${_escape(settings.phone)}</div>
    </div>
    <div style="text-align: right;">
      <div style="font-size: 14px; font-weight: 900; color: #dc2626;">TOTAL OVERDUE: $cur${grandTotalDues.toStringAsFixed(2)}</div>
      <div style="font-size: 12px; font-weight: bold;">TOTAL DEFAULTERS: ${defaulters.length} Accounts</div>
      <div style="font-size: 11px; color: #64748b;">GENERATED: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 30px; text-align: center;">S#</th>
        <th style="width: 200px;">Customer / Business Name</th>
        <th style="width: 130px;">Phone Number</th>
        <th>Address / Location</th>
        <th style="width: 100px; text-align: right;">Credit Limit</th>
        <th style="width: 120px; text-align: right;">Overdue Due</th>
        <th style="width: 140px; text-align: center;">Recovery Agent Notes / Sign</th>
      </tr>
    </thead>
    <tbody>
      $rowsHtml
    </tbody>
  </table>

  <div style="margin-top: 30px; display: flex; justify-content: space-between; font-size: 12px; font-weight: bold;">
    <div>Recovery Officer Signature: _______________________</div>
    <div>Accounts Manager Verification: _______________________</div>
  </div>
</body>
</html>
''';
  }

  // ================= 5. EXECUTIVE BUSINESS REPORT =================
  static String generateReportHtml({
    String? title,
    required Map<String, dynamic> reportData,
    required BusinessSettings settings,
    String dateRange = '',
    String? period,
    String? paperSize,
    String? paperSizeOverride,
  }) {
    final effectiveTitle = title ?? 'Executive Financial & Business Report';
    final effectiveDateRange = dateRange.isNotEmpty ? dateRange : (period ?? '');
    final cur = settings.currencySymbol;
    final totalSales = (reportData['totalSales'] as num?)?.toDouble() ?? 0.0;
    final netSales = (reportData['netSales'] as num?)?.toDouble() ?? totalSales;
    final totalPurchases = (reportData['totalPurchases'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (reportData['totalExpenses'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = (reportData['grossProfit'] as num?)?.toDouble() ?? 0.0;
    final netProfit = (reportData['netProfit'] as num?)?.toDouble() ?? 0.0;
    final totalReceivable = (reportData['totalReceivable'] as num?)?.toDouble() ?? 0.0;
    final totalPayable = (reportData['totalPayable'] as num?)?.toDouble() ?? 0.0;
    final totalStockCost = (reportData['totalStockCost'] as num?)?.toDouble() ?? 0.0;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$effectiveTitle - ${settings.businessName}</title>
  <style>
    @page { size: A4 portrait; margin: 12mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 12.5px; color: #1e293b; margin: 0; padding: 0; line-height: 1.4; }
    .grid { display: flex; flex-wrap: wrap; gap: 12px; margin: 16px 0; }
    .card { flex: 1; min-width: 140px; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 8px; padding: 12px; }
    .card-title { font-size: 10.5px; font-weight: bold; color: #64748b; text-transform: uppercase; }
    .card-val { font-size: 18px; font-weight: 900; margin-top: 4px; }
    table { width: 100%; border-collapse: collapse; margin-top: 14px; }
    th { background: #0f172a; color: #fff; padding: 8px; text-align: left; font-size: 11px; }
    td { padding: 8px; border-bottom: 1px solid #e2e8f0; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    @media print { body { margin: 0; } }
  </style>
  <script>
    window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });
  </script>
</head>
<body>
  <div style="border-bottom: 3px solid #4f46e5; padding-bottom: 10px; display: flex; justify-content: space-between; align-items: flex-end;">
    <div>
      <h2 style="margin: 0; font-size: 22px; color: #4f46e5;">${_escape(settings.businessName.toUpperCase())}</h2>
      <div style="font-size: 15px; font-weight: 900; color: #0f172a; margin-top: 2px;">$effectiveTitle</div>
      <div style="font-size: 11.5px; color: #64748b;">${_escape(settings.branchName)} &bull; Date Period: ${effectiveDateRange.isNotEmpty ? effectiveDateRange : 'All-Time Analytics'}</div>
    </div>
    <div style="text-align: right; font-size: 11px; color: #64748b;">
      <div>Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}</div>
      <div>Software: Smart POS Enterprise ERP</div>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-title">Net Sales Revenue</div>
      <div class="card-val" style="color: #059669;">$cur${netSales.toStringAsFixed(2)}</div>
    </div>
    <div class="card">
      <div class="card-title">Total Purchases (Stock)</div>
      <div class="card-val" style="color: #0284c7;">$cur${totalPurchases.toStringAsFixed(2)}</div>
    </div>
    <div class="card">
      <div class="card-title">Operating Expenses</div>
      <div class="card-val" style="color: #dc2626;">$cur${totalExpenses.toStringAsFixed(2)}</div>
    </div>
    <div class="card">
      <div class="card-title">Net Profit Margin</div>
      <div class="card-val" style="color: ${netProfit >= 0 ? '#10b981' : '#ef4444'};">$cur${netProfit.toStringAsFixed(2)}</div>
    </div>
  </div>

  <h3 style="margin: 18px 0 6px 0; font-size: 14px; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px;">Executive Financial Statement</h3>
  <table>
    <thead>
      <tr>
        <th>Accounting Line Item</th>
        <th style="width: 150px; text-align: right;">Amount ($cur)</th>
        <th style="width: 250px;">Commercial Impact</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="bold">Gross Sales Invoices</td>
        <td class="text-right bold">$cur${totalSales.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Customer orders dispatched</td>
      </tr>
      <tr>
        <td class="bold">Cost of Goods Sold (COGS)</td>
        <td class="text-right bold" style="color:#0284c7;">$cur${((reportData['totalCogs'] as num?)?.toDouble() ?? (totalSales - grossProfit)).toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Acquisition cost of sold inventory</td>
      </tr>
      <tr style="background:#f8fafc;">
        <td class="bold">Gross Profit</td>
        <td class="text-right bold" style="color:#059669;">$cur${grossProfit.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Gross Trading Margin</td>
      </tr>
      <tr>
        <td class="bold">Operating Overhead Expenses</td>
        <td class="text-right bold" style="color:#dc2626;">$cur${totalExpenses.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Rent, salaries, bills & transport</td>
      </tr>
      <tr style="background:#ecfdf5; font-size: 14px; border-top: 2px solid #059669; border-bottom: 2px solid #059669;">
        <td class="bold">NET BUSINESS PROFIT</td>
        <td class="text-right bold" style="color:#059669;">$cur${netProfit.toStringAsFixed(2)}</td>
        <td class="bold" style="color:#059669;">Net Retained Earnings</td>
      </tr>
      <tr>
        <td class="bold">Inventory Asset Valuation</td>
        <td class="text-right bold">$cur${totalStockCost.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Current asset value in warehouse</td>
      </tr>
      <tr>
        <td class="bold">Customer Dues (Receivables / Khata)</td>
        <td class="text-right bold" style="color:#dc2626;">$cur${totalReceivable.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Outstanding receivables to be collected</td>
      </tr>
      <tr>
        <td class="bold">Supplier Dues (Payables)</td>
        <td class="text-right bold" style="color:#d97706;">$cur${totalPayable.toStringAsFixed(2)}</td>
        <td style="color:#64748b;">Vendor liabilities payable</td>
      </tr>
    </tbody>
  </table>

  <div style="margin-top: 40px; display: flex; justify-content: space-between; font-size: 11.5px; border-top: 1px solid #cbd5e1; padding-top: 10px;">
    <div>Report compiled for: ${_escape(settings.businessName)}</div>
    <div>Certified by: Commercial Operations</div>
  </div>
</body>
</html>
''';
  }

  /// Converts numeric amounts into Pakistani English Rupee words (Crore, Lakh, Thousand)
  static String numberToWords(double amount) {
    if (amount <= 0) return 'Zero';
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertBelowThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return units[n];
      if (n < 100) return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${units[n % 10]}' : ''}';
      return '${units[n ~/ 100]} Hundred${n % 100 != 0 ? ' and ${convertBelowThousand(n % 100)}' : ''}';
    }

    int intPart = amount.floor();
    if (intPart == 0) return 'Zero';

    final parts = <String>[];
    if (intPart >= 10000000) {
      parts.add('${convertBelowThousand(intPart ~/ 10000000)} Crore');
      intPart %= 10000000;
    }
    if (intPart >= 100000) {
      parts.add('${convertBelowThousand(intPart ~/ 100000)} Lakh');
      intPart %= 100000;
    }
    if (intPart >= 1000) {
      parts.add('${convertBelowThousand(intPart ~/ 1000)} Thousand');
      intPart %= 1000;
    }
    if (intPart > 0) {
      parts.add(convertBelowThousand(intPart));
    }
    return '${parts.join(' ')} Only';
  }

  /// Full 9-Column Boxed A4 Agency Invoice (Pixel-perfect match with Preview dialog)
  static String generateA4AgencyInvoiceHtml({
    required Sale sale,
    required BusinessSettings settings,
    double? customerPreviousBalance,
  }) {
    final cur = settings.currencySymbol;
    final items = sale.items ?? [];
    final itemsHtml = StringBuffer();
    final showBatch = settings.showBatchOnInvoice;
    final showExpiry = settings.showExpiryOnInvoice;
    final showBrand = settings.showBrandOnInvoice;
    final showSku = settings.showSkuOnInvoice;
    final showWarranty = settings.showWarrantyOnInvoice;
    final showWords = settings.showTotalInWords;

    for (var it in items) {
      final packVal = it.unitPrice * it.quantity;
      final discVal = it.discount > 0 ? it.discount : (it.packDiscount > 0 ? (packVal * it.packDiscount / 100) : 0.0);
      final qStr = it.quantity == it.quantity.toInt()
          ? it.quantity.toInt().toString()
          : it.quantity.toStringAsFixed(2);
      final uLabel = it.unitName != null && it.unitName!.isNotEmpty ? ' ${it.unitName}' : '';

      String itemDesc = _escape(it.productName);
      if (showSku && it.sku.isNotEmpty) {
        itemDesc += '<br><small style="color: #64748b; font-size: 9.5px;">SKU: ${_escape(it.sku)}</small>';
      }

      final batchText = (it.batchNumber != null && it.batchNumber!.isNotEmpty) ? _escape(it.batchNumber!) : '-';
      final expText = (it.expiryDate != null && it.expiryDate!.isNotEmpty) ? _escape(it.expiryDate!) : '-';

      itemsHtml.writeln('''
        <tr>
          <td style="border: 1px solid #000; padding: 4px 6px; font-weight: bold; text-align: left;">$itemDesc</td>
          ${showBatch ? '<td style="border: 1px solid #000; padding: 4px; text-align: center;">$batchText</td>' : ''}
          ${showExpiry ? '<td style="border: 1px solid #000; padding: 4px; text-align: center; color: #d97706; font-weight: bold;">$expText</td>' : ''}
          <td style="border: 1px solid #000; padding: 4px; text-align: center;">$qStr$uLabel</td>
          <td style="border: 1px solid #000; padding: 4px; text-align: center; color: #059669; font-weight: bold;">${it.bonusQuantity > 0 ? it.bonusQuantity.toInt() : 0}</td>
          <td style="border: 1px solid #000; padding: 4px; text-align: right;">${it.unitPrice.toStringAsFixed(2)}</td>
          <td style="border: 1px solid #000; padding: 4px; text-align: right;">${packVal.toStringAsFixed(2)}</td>
          <td style="border: 1px solid #000; padding: 4px; text-align: right;">${discVal > 0 ? discVal.toStringAsFixed(2) : '0.00'}</td>
          <td style="border: 1px solid #000; padding: 4px; text-align: right; font-weight: bold;">${it.subtotal.toStringAsFixed(2)}</td>
        </tr>
      ''');
    }

    final dateStr = sale.createdAt.split(' ').first;
    final timeStr = sale.createdAt.contains(' ') ? sale.createdAt.split(' ').last : '11:38:27';
    final isWalkIn = sale.customerName.toLowerCase().contains('walk-in') ||
        sale.customerName.toLowerCase().contains('walk in') ||
        sale.customerName.toLowerCase() == 'cash customer' ||
        sale.customerName.toLowerCase().contains('walkin');

    final prevBal = customerPreviousBalance ?? 0.0;
    final currentBill = sale.totalAmount;
    final paidToday = sale.paidAmount;
    final netClosing = prevBal + currentBill - paidToday;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Invoice - ${sale.invoiceNo}</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 8mm 10mm;
    }
    body {
      font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
      margin: 0;
      padding: 0;
      color: #000;
      background: #fff;
      font-size: 11px;
      line-height: 1.3;
    }
    .a4-container {
      width: 100%;
      max-width: 780px;
      margin: 0 auto;
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    .biz-header {
      text-align: center;
      margin-bottom: 8px;
    }
    .biz-title {
      font-size: 22px;
      font-weight: 900;
      letter-spacing: 0.5px;
      margin: 0;
      text-transform: uppercase;
      color: #0f172a;
    }
    .biz-sub {
      font-size: 11px;
      font-weight: bold;
      color: #334155;
      margin-top: 2px;
    }
    .biz-meta {
      font-size: 11px;
      color: #64748b;
    }
    .biz-cell {
      font-size: 11px;
      font-weight: 600;
      color: #334155;
    }
    .meta-box {
      border: 1.2px solid #000;
      padding: 8px 10px;
      margin: 10px 0;
      display: flex;
      justify-content: space-between;
    }
    .meta-col {
      width: 48%;
    }
    .meta-row {
      display: flex;
      margin-bottom: 3px;
      font-size: 11px;
    }
    .meta-label {
      width: 100px;
      font-weight: bold;
      color: #000;
    }
    .meta-val {
      flex: 1;
      color: #000;
    }
    table.a4-table {
      width: 100%;
      border-collapse: collapse;
      border: 1px solid #000;
      font-size: 11px;
    }
    table.a4-table th {
      border: 1px solid #000;
      background-color: #f1f5f9;
      padding: 5px 3px;
      font-weight: bold;
      font-size: 10.5px;
      text-align: center;
    }
    .subtotals-bar {
      border-left: 1px solid #000;
      border-right: 1px solid #000;
      border-bottom: 1px solid #000;
      padding: 6px 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-weight: bold;
      font-size: 11px;
    }
    .words-bar {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      margin: 8px 0;
    }
    .ledger-box {
      border: 1px solid #000;
      background-color: #f8fafc;
      padding: 6px 10px;
      margin: 8px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .ledger-item {
      display: flex;
      flex-direction: column;
    }
    .ledger-label {
      font-size: 9.5px;
      font-weight: bold;
      color: #475569;
    }
    .ledger-val {
      font-size: 12px;
      font-weight: 900;
      color: #0f172a;
    }
    .ledger-val.highlight {
      color: #dc2626;
    }
    .warranty-box {
      border: 1px solid #cbd5e1;
      background-color: #f8fafc;
      padding: 6px 8px;
      margin: 8px 0;
      font-size: 9px;
      color: #475569;
      line-height: 1.35;
      border-radius: 4px;
    }
    .footer-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 14px;
      font-size: 11px;
      font-weight: 600;
    }
    .urdu-notice {
      color: #b91c1c;
      font-weight: bold;
      font-size: 12px;
      direction: rtl;
    }
    @media print {
      body { margin: 0; }
      .no-print { display: none !important; }
    }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.print(); }, 250);
    });
  </script>
</head>
<body>
  <div class="a4-container">
    <!-- Header -->
    <div class="biz-header">
      <div class="biz-title">${_escape(settings.businessName.toUpperCase())}</div>
      <div class="biz-sub">${_escape(settings.invoiceHeading.toUpperCase())} &bull; ${_escape(settings.branchName.toUpperCase())}</div>
      <div class="biz-meta">${_escape(settings.address)}</div>
      ${settings.phone.isNotEmpty ? '<div class="biz-cell">CELL NO: ' + _escape(settings.phone) + (settings.taxNumber.isNotEmpty ? ' &bull; NTN/GST: ' + _escape(settings.taxNumber) : '') + '</div>' : ''}
    </div>

    <!-- Boxed Party and Invoice Info -->
    <div class="meta-box">
      <div class="meta-col">
        <div class="meta-row"><span class="meta-label">INVOICE NO:</span><span class="meta-val">${_escape(sale.invoiceNo)}</span></div>
        <div class="meta-row"><span class="meta-label">PARTY CODE:</span><span class="meta-val">${sale.customerId ?? 1}</span></div>
        <div class="meta-row"><span class="meta-label">PARTY NAME:</span><span class="meta-val bold">${_escape(sale.customerName)}</span></div>
        <div class="meta-row"><span class="meta-label">ADDRESS:</span><span class="meta-val">${_escape(settings.address.split(',').first)}</span></div>
      </div>
      <div class="meta-col">
        <div class="meta-row"><span class="meta-label">DATE:</span><span class="meta-val">${_escape(dateStr)}</span></div>
        <div class="meta-row"><span class="meta-label">CASHIER / S.MAN:</span><span class="meta-val bold">${_escape(sale.userName ?? 'Admin Counter')}</span></div>
        <div class="meta-row"><span class="meta-label">TIME:</span><span class="meta-val">${_escape(timeStr)}</span></div>
      </div>
    </div>

    <!-- Products Table -->
    <table class="a4-table">
      <thead>
        <tr>
          <th style="text-align: left; padding-left: 6px;">DESCRIPTION</th>
          ${showBatch ? '<th style="width: 10%;">BATCH</th>' : ''}
          ${showExpiry ? '<th style="width: 11%;">EXP-DATE</th>' : ''}
          <th style="width: 7%;">QTY</th>
          <th style="width: 7%;">BONUS</th>
          <th style="width: 10%; text-align: right;">RATE+GST</th>
          <th style="width: 10%; text-align: right;">PACK VALUE</th>
          <th style="width: 8%; text-align: right;">PACK DISC</th>
          <th style="width: 10%; text-align: right; padding-right: 6px;">NET TOTAL</th>
        </tr>
      </thead>
      <tbody>
        $itemsHtml
      </tbody>
    </table>

    <!-- Subtotals Row -->
    <div class="subtotals-bar">
      <div>
        ${sale.taxAmount > 0 ? (settings.isPharmacy ? 'Advance Tax Under Section(236H)= 0.50% &nbsp;&nbsp;&nbsp; $cur' + sale.taxAmount.toStringAsFixed(2) : 'Tax Amount: $cur' + sale.taxAmount.toStringAsFixed(2)) : 'Tax: Exempt (0.00%)'}
      </div>
      <div>
        TOTAL : <span style="font-size: 13px; font-weight: 900;">$cur${sale.totalAmount.toStringAsFixed(2)}</span>
      </div>
    </div>

    <!-- Numbers of Products & Amount in Words -->
    <div class="words-bar">
      <div class="bold">Numbers of Products: &nbsp;${items.length}</div>
      ${showWords ? '<div style="font-style: italic;">Amount in Words: ' + numberToWords(sale.totalAmount) + '</div>' : ''}
    </div>

    ${(!isWalkIn && settings.showCustomerBalanceOnReceipt) ? '''
    <!-- Customer Khata Ledger Summary -->
    <div class="ledger-box">
      <div class="ledger-item">
        <span class="ledger-label">PREVIOUS BALANCE (پچھلا بقایا)</span>
        <span class="ledger-val">$cur${prevBal.toStringAsFixed(2)}</span>
      </div>
      <div class="ledger-item">
        <span class="ledger-label">CURRENT INVOICE (موجودہ بل)</span>
        <span class="ledger-val">$cur${currentBill.toStringAsFixed(2)}</span>
      </div>
      <div class="ledger-item">
        <span class="ledger-label">RECEIVED TODAY (آج وصولی)</span>
        <span class="ledger-val">$cur${paidToday.toStringAsFixed(2)}</span>
      </div>
      <div class="ledger-item">
        <span class="ledger-label">NET CLOSING KHATA (کل واجب الادا)</span>
        <span class="ledger-val highlight">$cur${netClosing.toStringAsFixed(2)}</span>
      </div>
    </div>
    ''' : ''}

    <!-- Warranty Section -->
    ${showWarranty ? (settings.isPharmacy ? '''
    <div class="warranty-box">
      <strong>WARRANTY :-</strong><br>
      FORM 2A (SEE RULES 19 &amp; 30). WARRANTY UNDER SECTION 23(i) OF DRUG ACT, 1976.<br>
      I am being a resident of Pakistan carrying on business at ${_escape(settings.address.split(',').first)}. Do hereby give this warranty that the drug contained in this invoice, described as sold by us do not contravene in any way the provision of section 23 of the Drug Act, 1976.<br>
      <em>Note: This Warranty does not apply to Unani, Homeopathic, Bio Chemic, System of Medicine, Herbal and General Item.</em>
    </div>
    ''' : '''
    <div class="warranty-box">
      <strong>TERMS &amp; CONDITIONS :-</strong><br>
      1. Goods once sold can be exchanged within 7 days upon presentation of original bill.<br>
      2. Altered, damaged, or clearance items are non-refundable.
    </div>
    ''') : ''}

    <!-- Signatures and Urdu Notice -->
    <div class="footer-bar">
      <div>Checked By _______________________</div>
      <div class="urdu-notice">نوٹ: ایکسپائری کی اطلاع 6 ماہ قبل مع اصل بل نمبر کیساتھ دیں۔</div>
    </div>
  </div>
</body>
</html>
    ''';
  }

  /// Generates Official A4 Account Ledger Statement for Customers and Suppliers
  static String generateOfficialLedgerHtml({
    required BusinessSettings settings,
    required Contact contact,
    required String contactType,
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
    required List<LedgerEntry> entries,
    required String periodText,
  }) {
    final cur = settings.currencySymbol;
    final isCustomer = contactType.toLowerCase() == 'customer';
    final nowFormatted = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());

    final statusText = closingBalance > 0
        ? (isCustomer ? 'Net Receivable / واجب الادا (Customer Owes)' : 'Net Payable / واجب الادا (You Owe Supplier)')
        : (closingBalance < 0 ? 'Advance Balance / پیشگی جمع' : 'Balanced / Cleared (کھاتہ بے باق)');

    final statusColor = closingBalance > 0 ? '#dc2626' : (closingBalance < 0 ? '#059669' : '#0f172a');

    final rowsHtml = StringBuffer();
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final isDebit = e.debit > 0;
      final isCredit = e.credit > 0;
      final dateClean = e.date.length > 16 ? e.date.substring(0, 16) : e.date;
      final balType = e.runningBalance > 0
          ? (isCustomer ? "Dr (واجب)" : "Cr (واجب)")
          : (e.runningBalance < 0 ? "Adv (جمع)" : "Nil");
      final balColor = e.runningBalance > 0 ? "#dc2626" : (e.runningBalance < 0 ? "#059669" : "#334155");

      String typeLabel = e.transactionType.toUpperCase().replaceAll('_', ' ');
      if (e.transactionType.contains('payment')) {
        typeLabel = 'PAYMENT / وصولی';
      } else if (e.transactionType.contains('sale')) {
        typeLabel = 'INVOICE / بل';
      } else if (e.transactionType.contains('purchase')) {
        typeLabel = 'PURCHASE / خریداری';
      } else if (e.transactionType.contains('return')) {
        typeLabel = 'RETURN / واپسی';
      }

      rowsHtml.writeln('''
      <tr>
        <td style="text-align: center; font-size: 10px;">\${i + 1}</td>
        <td style="font-size: 10px; white-space: nowrap;">\$dateClean</td>
        <td style="font-weight: bold; color: #4338ca; font-size: 10.5px;">\${_escape(e.refNo)}</td>
        <td style="font-size: 10px; font-weight: 600;">\$typeLabel</td>
        <td style="font-size: 10px;">\${_escape(e.description)}</td>
        <td style="text-align: right; font-weight: bold; color: \${isDebit ? '#1e40af' : '#94a3b8'}; font-size: 10.5px;">\${isDebit ? '\$cur\${e.debit.toStringAsFixed(2)}' : '-'}</td>
        <td style="text-align: right; font-weight: bold; color: \${isCredit ? '#047857' : '#94a3b8'}; font-size: 10.5px;">\${isCredit ? '\$cur\${e.credit.toStringAsFixed(2)}' : '-'}</td>
        <td style="text-align: right; font-weight: 900; color: \$balColor; font-size: 11px;">\$cur\${e.runningBalance.abs().toStringAsFixed(2)} <span style="font-size: 9px; font-weight: bold;">\$balType</span></td>
      </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>\${_escape(contact.name)} - Official Ledger Statement</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 10mm 10mm 12mm 10mm;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 11px;
      line-height: 1.35;
      color: #0f172a;
      margin: 0;
      padding: 0;
      background: #fff;
    }
    .ledger-container {
      max-width: 100%;
      margin: 0 auto;
    }
    .header-table {
      width: 100%;
      border-bottom: 2px solid #0f172a;
      padding-bottom: 8px;
      margin-bottom: 10px;
    }
    .biz-title {
      font-size: 20px;
      font-weight: 900;
      letter-spacing: 0.5px;
      color: #0f172a;
      text-transform: uppercase;
    }
    .biz-sub {
      font-size: 10.5px;
      color: #475569;
      font-weight: 600;
    }
    .doc-badge {
      display: inline-block;
      background: #0f172a;
      color: #fff;
      padding: 4px 10px;
      font-weight: 800;
      font-size: 12px;
      letter-spacing: 0.8px;
      border-radius: 4px;
      text-transform: uppercase;
    }
    .party-card {
      border: 1px solid #000;
      background: #f8fafc;
      padding: 10px 14px;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
    }
    .party-col {
      flex: 1;
    }
    .party-name {
      font-size: 15px;
      font-weight: 900;
      color: #0f172a;
    }
    .meta-line {
      font-size: 10px;
      color: #334155;
      margin-top: 2px;
    }
    .summary-grid {
      display: flex;
      gap: 10px;
      margin-bottom: 12px;
    }
    .summary-box {
      flex: 1;
      border: 1px solid #cbd5e1;
      background: #fff;
      padding: 8px 10px;
      border-radius: 4px;
    }
    .summary-box.highlight {
      border: 2px solid \$statusColor;
      background: #fef2f2;
    }
    .summary-label {
      font-size: 9px;
      font-weight: bold;
      color: #64748b;
      text-transform: uppercase;
    }
    .summary-val {
      font-size: 14px;
      font-weight: 900;
      color: #0f172a;
      margin-top: 3px;
    }
    .summary-val.highlight {
      color: \$statusColor;
    }
    table.ledger-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 6px;
    }
    table.ledger-table th {
      background-color: #0f172a;
      color: #ffffff;
      font-size: 9.5px;
      font-weight: bold;
      text-transform: uppercase;
      padding: 6px 5px;
      border: 1px solid #0f172a;
    }
    table.ledger-table td {
      padding: 5px 5px;
      border: 1px solid #cbd5e1;
      font-size: 10px;
    }
    table.ledger-table tr:nth-child(even) {
      background-color: #f8fafc;
    }
    .totals-row td {
      background-color: #f1f5f9 !important;
      font-weight: 900;
      border-top: 2px solid #0f172a !important;
      border-bottom: 2px solid #0f172a !important;
    }
    .sign-row {
      display: flex;
      justify-content: space-between;
      margin-top: 30px;
      padding-top: 10px;
    }
    .sign-box {
      width: 28%;
      text-align: center;
      border-top: 1px dashed #475569;
      padding-top: 6px;
      font-size: 9.5px;
      font-weight: bold;
      color: #334155;
    }
    .notice-box {
      margin-top: 14px;
      padding: 6px 10px;
      background: #f8fafc;
      border: 1px solid #cbd5e1;
      font-size: 9px;
      color: #475569;
      display: flex;
      justify-content: space-between;
    }
  </style>
</head>
<body>
  <div class="ledger-container">
    <table class="header-table">
      <tr>
        <td style="vertical-align: top;">
          <div class="biz-title">\${_escape(settings.businessName)}</div>
          <div class="biz-sub">\${_escape(settings.businessType.toUpperCase())} &bull; MAIN BRANCH HQ</div>
          <div class="biz-sub">Cell / WhatsApp: +92 300 1234567 &bull; Commercial Market</div>
        </td>
        <td style="text-align: right; vertical-align: top;">
          <div class="doc-badge">OFFICIAL ACCOUNT STATEMENT</div>
          <div style="font-size: 10px; color: #64748b; margin-top: 5px; font-weight: 600;">Statement Period: \${_escape(periodText)}</div>
          <div style="font-size: 10px; color: #64748b; font-weight: 600;">Printed: \$nowFormatted</div>
        </td>
      </tr>
    </table>

    <div class="party-card">
      <div class="party-col">
        <div style="font-size: 9.5px; font-weight: bold; color: #4338ca; text-transform: uppercase;">\${isCustomer ? "CUSTOMER / کھاتہ دار گاہک" : "SUPPLIER / وینڈر یا سپلائر"}</div>
        <div class="party-name">\${_escape(contact.name)}</div>
        <div class="meta-line"><strong>Business:</strong> \${_escape((contact.businessName != null && contact.businessName!.isNotEmpty) ? contact.businessName! : "N/A")}</div>
        <div class="meta-line"><strong>Phone / Mobile:</strong> \${_escape(contact.phone.isNotEmpty ? contact.phone : "N/A")}</div>
        <div class="meta-line"><strong>Address:</strong> \${_escape(contact.address.isNotEmpty ? contact.address : "Main City Market")}</div>
      </div>
      <div class="party-col" style="text-align: right;">
        <div style="font-size: 9.5px; font-weight: bold; color: #64748b; text-transform: uppercase;">ACCOUNT STATUS &bull; کھاتہ کی حیثیت</div>
        <div style="font-size: 13px; font-weight: 900; color: \$statusColor; margin-top: 3px;">\$statusText</div>
        <div class="meta-line" style="margin-top: 5px;"><strong>Credit Limit:</strong> \$cur\${contact.creditLimit.toStringAsFixed(2)}</div>
        <div class="meta-line"><strong>Party Code / ID:</strong> #CON-\${contact.id ?? 1}</div>
      </div>
    </div>

    <!-- 4 Summary KPI Boxes -->
    <div class="summary-grid">
      <div class="summary-box">
        <div class="summary-label">Opening Balance / سابقہ بقایا</div>
        <div class="summary-val">\$cur\${openingBalance.toStringAsFixed(2)}</div>
      </div>
      <div class="summary-box">
        <div class="summary-label">\${isCustomer ? "Total Invoices (Dr) / بنام کل مال" : "Total Purchases (Cr) / کل خریداری"}</div>
        <div class="summary-val" style="color: #1e40af;">\$cur\${(isCustomer ? totalDebit : totalCredit).toStringAsFixed(2)}</div>
      </div>
      <div class="summary-box">
        <div class="summary-label">\${isCustomer ? "Total Received (Cr) / جمع کل وصولی" : "Total Payments (Dr) / کل ادا شدہ"}</div>
        <div class="summary-val" style="color: #047857;">\$cur\${(isCustomer ? totalCredit : totalDebit).toStringAsFixed(2)}</div>
      </div>
      <div class="summary-box highlight">
        <div class="summary-label" style="color: \$statusColor;">Net Closing Balance / خالص بقایا رقم</div>
        <div class="summary-val highlight">\$cur\${closingBalance.toStringAsFixed(2)}</div>
      </div>
    </div>

    <!-- Ledger Table -->
    <table class="ledger-table">
      <thead>
        <tr>
          <th style="width: 25px; text-align: center;">#</th>
          <th style="width: 105px;">Date &amp; Time / تاریخ</th>
          <th style="width: 85px;">Ref # / واؤچر</th>
          <th style="width: 80px;">Type / قسم</th>
          <th>Narration &amp; Details / مال کی تفصیل</th>
          <th style="width: 85px; text-align: right;">Debit (Dr) / بنام</th>
          <th style="width: 85px; text-align: right;">Credit (Cr) / جمع</th>
          <th style="width: 100px; text-align: right;">Balance / بقایا</th>
        </tr>
      </thead>
      <tbody>
        \${entries.isEmpty ? '<tr><td colspan="8" style="text-align: center; padding: 20px; color: #64748b;">No ledger records found for this period.</td></tr>' : rowsHtml.toString()}
        <tr class="totals-row">
          <td colspan="5" style="text-align: right; padding-right: 12px;">TOTALS / کل میزان:</td>
          <td style="text-align: right; color: #1e40af;">\$cur\${totalDebit.toStringAsFixed(2)}</td>
          <td style="text-align: right; color: #047857;">\$cur\${totalCredit.toStringAsFixed(2)}</td>
          <td style="text-align: right; color: \$statusColor;">\$cur\${closingBalance.toStringAsFixed(2)}</td>
        </tr>
      </tbody>
    </table>

    <!-- Notice -->
    <div class="notice-box">
      <div>Note: This is an official computer-generated account statement. Any discrepancy must be reported within 7 days.</div>
      <div style="direction: rtl; font-weight: bold;">نوٹ: یہ کمپیوٹر کا تیار کردہ سرکاری کھاتہ ہے۔ کسی بھی غلطی کی صورت میں 7 یوم کے اندر مطلع فرمائیں۔</div>
    </div>

    <!-- Signatures -->
    <div class="sign-row">
      <div class="sign-box">Prepared By (تیار کنندہ / اکاؤنٹنٹ)</div>
      <div class="sign-box">Audited &amp; Verified By (تصدیق کنندہ)</div>
      <div class="sign-box">Customer / Party Signature (دستخط کھاتہ دار)</div>
    </div>
  </div>
</body>
</html>
    ''';
  }

  // ================= 8. CASH REGISTER & SHIFT AUDIT REPORT =================
  static String generateRegisterReportHtml({
    required List<Map<String, dynamic>> registers,
    required BusinessSettings settings,
    String period = '',
  }) {
    final cur = settings.currencySymbol;
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    double totalOpening = 0.0;
    double totalCash = 0.0;
    double totalCard = 0.0;
    double totalClosing = 0.0;
    double totalVariance = 0.0;

    final rowsHtml = StringBuffer();
    for (int i = 0; i < registers.length; i++) {
      final r = registers[i];
      final id = r['id'] ?? (i + 1);
      final cashier = _escape((r['cashier_name'] as String?) ?? 'Unknown');
      final status = (r['status'] as String?) ?? 'closed';
      final openedAt = _formatDateTime(r['opened_at'] as String?);
      final closedAt = status == 'open' ? 'Active Shift' : _formatDateTime(r['closed_at'] as String?);
      final opening = (r['opening_amount'] as num?)?.toDouble() ?? 0.0;
      final cash = (r['total_sales_cash'] as num?)?.toDouble() ?? 0.0;
      final card = (r['total_sales_card'] as num?)?.toDouble() ?? 0.0;
      final other = (r['total_sales_other'] as num?)?.toDouble() ?? 0.0;
      final totalSales = (r['total_sales'] as num?)?.toDouble() ?? (cash + card + other);
      final closing = (r['closing_amount'] as num?)?.toDouble() ?? 0.0;
      final diff = (r['difference'] as num?)?.toDouble() ?? (status == 'closed' ? (closing - (opening + cash)) : 0.0);

      totalOpening += opening;
      totalCash += cash;
      totalCard += (card + other);
      if (status == 'closed') {
        totalClosing += closing;
        totalVariance += diff;
      }

      final statusBadge = status == 'open'
          ? '<span style="background: #ecfdf5; color: #047857; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #a7f3d0;">OPEN</span>'
          : '<span style="background: #f1f5f9; color: #475569; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #cbd5e1;">CLOSED</span>';

      final diffText = status == 'open'
          ? '--'
          : (diff == 0.0
              ? '<span style="color: #047857; font-weight: bold;">Exact Match</span>'
              : (diff > 0
                  ? '<span style="color: #047857; font-weight: bold;">+$cur${diff.toStringAsFixed(2)} Surplus</span>'
                  : '<span style="color: #dc2626; font-weight: bold;">-$cur${(-diff).toStringAsFixed(2)} Shortage</span>'));

      rowsHtml.writeln('''
        <tr>
          <td style="text-align: center;">#$id</td>
          <td class="bold">$cashier</td>
          <td style="text-align: center;">$statusBadge</td>
          <td>$openedAt</td>
          <td>$closedAt</td>
          <td class="text-right">$cur${opening.toStringAsFixed(2)}</td>
          <td class="text-right">$cur${cash.toStringAsFixed(2)}</td>
          <td class="text-right">$cur${(card + other).toStringAsFixed(2)}</td>
          <td class="text-right bold">$cur${totalSales.toStringAsFixed(2)}</td>
          <td class="text-right">${status == 'closed' ? '$cur${closing.toStringAsFixed(2)}' : '--'}</td>
          <td class="text-right">$diffText</td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Cash Register Shifts Audit Report - ${settings.businessName}</title>
  <style>
    @page { size: A4 landscape; margin: 10mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 11px; color: #0f172a; margin: 0; padding: 0; }
    .header { text-align: center; margin-bottom: 14px; border-bottom: 2px solid #0f172a; padding-bottom: 8px; }
    .title { font-size: 18px; font-weight: 900; text-transform: uppercase; color: #1e3a8a; }
    .subtitle { font-size: 11px; color: #475569; margin-top: 3px; }
    .kpi-row { display: flex; gap: 10px; margin-bottom: 14px; }
    .kpi-card { flex: 1; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 12px; }
    .kpi-title { font-size: 9.5px; font-weight: bold; color: #64748b; text-transform: uppercase; }
    .kpi-val { font-size: 15px; font-weight: 900; color: #0f172a; margin-top: 2px; }
    table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    th { background: #1e3a8a; color: #fff; padding: 6px 8px; font-size: 10px; text-align: left; }
    td { padding: 6px 8px; border-bottom: 1px solid #e2e8f0; font-size: 10.5px; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    .totals-row td { background: #f1f5f9; font-weight: 900; border-top: 2px solid #0f172a; border-bottom: 2px solid #0f172a; }
    @media print { body { margin: 0; } }
  </style>
  <script>window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });</script>
</head>
<body>
  <div class="header">
    <div class="title">${settings.businessName} - CASH REGISTER &amp; SHIFT REPORT</div>
    <div class="subtitle">Location: ${settings.branchName} &bull; Period: ${period.isNotEmpty ? period : 'All Shifts'} &bull; Generated: $now</div>
  </div>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="kpi-title">Total Shifts Audited</div>
      <div class="kpi-val">${registers.length} Shifts</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Total Cash Sales</div>
      <div class="kpi-val" style="color: #047857;">$cur${totalCash.toStringAsFixed(2)}</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Total Card / Digital Sales</div>
      <div class="kpi-val" style="color: #1e40af;">$cur${totalCard.toStringAsFixed(2)}</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Total Counted Cash</div>
      <div class="kpi-val">$cur${totalClosing.toStringAsFixed(2)}</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Net Cash Variance</div>
      <div class="kpi-val" style="color: ${totalVariance >= 0 ? '#047857' : '#dc2626'};">${totalVariance >= 0 ? '+' : ''}$cur${totalVariance.toStringAsFixed(2)}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 50px; text-align: center;">Shift #</th>
        <th>Cashier Name</th>
        <th style="width: 70px; text-align: center;">Status</th>
        <th>Shift Opened</th>
        <th>Shift Closed</th>
        <th class="text-right">Opening Float</th>
        <th class="text-right">Cash Sales</th>
        <th class="text-right">Card/Other</th>
        <th class="text-right">Total Sales</th>
        <th class="text-right">Closing Cash</th>
        <th class="text-right">Discrepancy</th>
      </tr>
    </thead>
    <tbody>
      ${rowsHtml.toString()}
      <tr class="totals-row">
        <td colspan="5" style="text-align: right;">GRAND TOTALS:</td>
        <td class="text-right">$cur${totalOpening.toStringAsFixed(2)}</td>
        <td class="text-right" style="color: #047857;">$cur${totalCash.toStringAsFixed(2)}</td>
        <td class="text-right" style="color: #1e40af;">$cur${totalCard.toStringAsFixed(2)}</td>
        <td class="text-right">$cur${(totalCash + totalCard).toStringAsFixed(2)}</td>
        <td class="text-right">$cur${totalClosing.toStringAsFixed(2)}</td>
        <td class="text-right" style="color: ${totalVariance >= 0 ? '#047857' : '#dc2626'};">${totalVariance >= 0 ? '+' : ''}$cur${totalVariance.toStringAsFixed(2)}</td>
      </tr>
    </tbody>
  </table>
</body>
</html>
    ''';
  }

  // ================= 9. STOCK EXPIRY & BATCH AUDIT REPORT =================
  static String generateStockExpiryReportHtml({
    required List<Map<String, dynamic>> expiryItems,
    required BusinessSettings settings,
    String filterLabel = 'All Monitored Stock',
  }) {
    final cur = settings.currencySymbol;
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    int expiredCount = 0;
    int criticalCount = 0;
    double totalCostRisk = 0.0;
    double totalRetailRisk = 0.0;

    final rowsHtml = StringBuffer();
    for (int i = 0; i < expiryItems.length; i++) {
      final item = expiryItems[i];
      final sku = _escape((item['sku'] as String?) ?? '-');
      final name = _escape((item['product_name'] as String?) ?? 'Product');
      final category = _escape((item['category_name'] as String?) ?? 'General');
      final batch = _escape((item['batch_number'] as String?) ?? '-');
      final expDate = (item['expiry_date'] as String?) ?? '-';
      final days = item['days_remaining'] as int?;
      final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (item['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final costVal = (item['stock_value_cost'] as num?)?.toDouble() ?? (qty * cost);
      final retailVal = (item['stock_value_retail'] as num?)?.toDouble() ?? 0.0;

      totalCostRisk += costVal;
      totalRetailRisk += retailVal;

      String badge;
      if (days == null) {
        badge = '<span style="color: #64748b;">Not Set</span>';
      } else if (days < 0) {
        expiredCount++;
        badge = '<span style="background: #fef2f2; color: #dc2626; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #fecaca;">EXPIRED (${-days}d ago)</span>';
      } else if (days <= 30) {
        criticalCount++;
        badge = '<span style="background: #fff7ed; color: #ea580c; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #fed7aa;">CRITICAL ($days days left)</span>';
      } else if (days <= 60) {
        badge = '<span style="background: #fefce8; color: #ca8a04; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #fef08a;">WARNING ($days days)</span>';
      } else {
        badge = '<span style="background: #ecfdf5; color: #047857; font-weight: bold; padding: 2px 6px; border-radius: 4px; border: 1px solid #a7f3d0;">VALID ($days days)</span>';
      }

      rowsHtml.writeln('''
        <tr>
          <td style="font-family: monospace;">$sku</td>
          <td class="bold">$name</td>
          <td>$category</td>
          <td style="font-family: monospace;">$batch</td>
          <td class="bold">$expDate</td>
          <td style="text-align: center;">$badge</td>
          <td class="text-right bold">${qty.toInt()}</td>
          <td class="text-right">$cur${cost.toStringAsFixed(2)}</td>
          <td class="text-right bold" style="color: #dc2626;">$cur${costVal.toStringAsFixed(2)}</td>
        </tr>
      ''');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Stock Expiry &amp; Batch Traceability Report - ${settings.businessName}</title>
  <style>
    @page { size: A4 landscape; margin: 10mm; }
    body { font-family: 'Segoe UI', Tahoma, sans-serif; font-size: 11px; color: #0f172a; margin: 0; padding: 0; }
    .header { text-align: center; margin-bottom: 14px; border-bottom: 2px solid #dc2626; padding-bottom: 8px; }
    .title { font-size: 18px; font-weight: 900; text-transform: uppercase; color: #991b1b; }
    .subtitle { font-size: 11px; color: #475569; margin-top: 3px; }
    .kpi-row { display: flex; gap: 10px; margin-bottom: 14px; }
    .kpi-card { flex: 1; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 12px; }
    .kpi-title { font-size: 9.5px; font-weight: bold; color: #64748b; text-transform: uppercase; }
    .kpi-val { font-size: 15px; font-weight: 900; color: #0f172a; margin-top: 2px; }
    table { width: 100%; border-collapse: collapse; margin-top: 8px; }
    th { background: #991b1b; color: #fff; padding: 6px 8px; font-size: 10px; text-align: left; }
    td { padding: 6px 8px; border-bottom: 1px solid #e2e8f0; font-size: 10.5px; }
    .text-right { text-align: right; }
    .bold { font-weight: bold; }
    .totals-row td { background: #fef2f2; font-weight: 900; border-top: 2px solid #991b1b; border-bottom: 2px solid #991b1b; }
    @media print { body { margin: 0; } }
  </style>
  <script>window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });</script>
</head>
<body>
  <div class="header">
    <div class="title">${settings.businessName} - STOCK EXPIRY &amp; BATCH REPORT</div>
    <div class="subtitle">Location: ${settings.branchName} &bull; Filter: $filterLabel &bull; Generated: $now</div>
  </div>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="kpi-title">Total Monitored Items</div>
      <div class="kpi-val">${expiryItems.length} Products</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Already Expired Stock</div>
      <div class="kpi-val" style="color: #dc2626;">$expiredCount Items</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Expiring in &le; 30 Days</div>
      <div class="kpi-val" style="color: #ea580c;">$criticalCount Items</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-title">Total Cost Value at Risk</div>
      <div class="kpi-val" style="color: #dc2626;">$cur${totalCostRisk.toStringAsFixed(2)}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 80px;">SKU / Code</th>
        <th>Product Name</th>
        <th>Category</th>
        <th style="width: 80px;">Batch #</th>
        <th style="width: 80px;">Expiry Date</th>
        <th style="width: 130px; text-align: center;">Status / Days</th>
        <th class="text-right" style="width: 60px;">Stock</th>
        <th class="text-right" style="width: 80px;">Cost Price</th>
        <th class="text-right" style="width: 95px;">Cost at Risk</th>
      </tr>
    </thead>
    <tbody>
      ${rowsHtml.toString()}
      <tr class="totals-row">
        <td colspan="6" style="text-align: right;">TOTAL RISK VALUE:</td>
        <td class="text-right">${expiryItems.fold<double>(0.0, (acc, item) => acc + ((item['stock_quantity'] as num?)?.toDouble() ?? 0.0)).toInt()}</td>
        <td class="text-right">--</td>
        <td class="text-right" style="color: #dc2626;">$cur${totalCostRisk.toStringAsFixed(2)}</td>
      </tr>
    </tbody>
  </table>
</body>
</html>
    ''';
  }

  // ================= 8. PRODUCT SPECIFICATION & DETAIL SHEET =================
  static String generateProductDetailHtml({
    required Product product,
    required BusinessSettings settings,
    List<ProductVariation> variations = const [],
    double totalSold = 0.0,
    double totalTransferred = 0.0,
    double totalAdjusted = 0.0,
    bool canViewCost = true,
  }) {
    final cur = settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs';
    final p = product;
    final margin = p.purchasePrice > 0
        ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100)
        : 0.0;
    final locationName = settings.businessName.isNotEmpty ? settings.businessName : 'Main Branch HQ';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Product Details - ${_escape(p.name)}</title>
  <style>
    @page { size: A4 portrait; margin: 12mm; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; font-size: 12px; color: #1e293b; margin: 0; padding: 0; line-height: 1.4; }
    .header { border-bottom: 2px solid #10b981; padding-bottom: 12px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: flex-start; }
    .title { font-size: 20px; font-weight: 800; color: #0f172a; margin: 0; }
    .subtitle { font-size: 12px; color: #64748b; margin-top: 4px; }
    .meta-box { display: flex; justify-content: space-between; gap: 20px; margin-bottom: 20px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px; }
    .meta-col { flex: 1; }
    .meta-row { margin-bottom: 6px; font-size: 12px; }
    .meta-label { font-weight: 700; color: #0f172a; }
    .meta-val { color: #475569; }
    table { width: 100%; border-collapse: collapse; margin-top: 14px; margin-bottom: 22px; }
    th { background: #10b981; color: #ffffff; padding: 8px 10px; font-size: 11px; text-align: left; font-weight: 700; }
    td { padding: 8px 10px; border: 1px solid #e2e8f0; font-size: 11.5px; }
    .section-title { font-size: 14px; font-weight: 700; color: #0f172a; margin-top: 16px; margin-bottom: 6px; }
    .text-right { text-align: right; }
    .bold { font-weight: 700; }
    @media print { body { margin: 0; } }
  </style>
  <script>
    window.addEventListener('load', function() { setTimeout(function() { window.print(); }, 250); });
  </script>
</head>
<body>
  <div class="header">
    <div>
      <h1 class="title">${_escape(p.name)}</h1>
      <div class="subtitle">${_escape(settings.businessName)} • Product Specification Sheet</div>
    </div>
    <div style="text-align: right; font-size: 11px; color: #64748b;">
      <div>Printed: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}</div>
      <div>Status: Active</div>
    </div>
  </div>

  <div class="meta-box">
    <div class="meta-col">
      <div class="meta-row"><span class="meta-label">SKU:</span> <span class="meta-val">${_escape(p.sku)}</span></div>
      <div class="meta-row"><span class="meta-label">Brand:</span> <span class="meta-val">${_escape(p.brandName.isNotEmpty ? p.brandName : 'Standard')}</span></div>
      <div class="meta-row"><span class="meta-label">Unit:</span> <span class="meta-val">${_escape(p.unit)}</span></div>
      <div class="meta-row"><span class="meta-label">Barcode Type:</span> <span class="meta-val">${_escape(p.barcodeType)}</span></div>
      <div class="meta-row"><span class="meta-label">Available in locations:</span> <span class="meta-val">${_escape(locationName)}</span></div>
    </div>
    <div class="meta-col">
      <div class="meta-row"><span class="meta-label">Category:</span> <span class="meta-val">${_escape(p.categoryName)}</span></div>
      <div class="meta-row"><span class="meta-label">Sub category:</span> <span class="meta-val">None</span></div>
      <div class="meta-row"><span class="meta-label">Manage Stock?:</span> <span class="meta-val">Yes</span></div>
      <div class="meta-row"><span class="meta-label">Alert quantity:</span> <span class="meta-val">${p.alertQuantity.toStringAsFixed(4)}</span></div>
    </div>
    <div class="meta-col">
      <div class="meta-row"><span class="meta-label">Expires in:</span> <span class="meta-val">${_escape(p.expiryDate?.isNotEmpty == true ? p.expiryDate! : 'Not Applicable')}</span></div>
      <div class="meta-row"><span class="meta-label">Applicable Tax:</span> <span class="meta-val">None</span></div>
      <div class="meta-row"><span class="meta-label">Selling Price Tax Type:</span> <span class="meta-val">Exclusive</span></div>
      <div class="meta-row"><span class="meta-label">Product Type:</span> <span class="meta-val">${p.isVariable ? 'Variable' : 'Single'}</span></div>
    </div>
  </div>

  <div class="section-title">Pricing & Margins</div>
  <table>
    <thead>
      <tr>
        <th>Default Purchase Price (Exc. tax)</th>
        <th>Default Purchase Price (Inc. tax)</th>
        <th>x Margin(%)</th>
        <th>Default Selling Price (Exc. tax)</th>
        <th>Default Selling Price (Inc. tax)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${canViewCost ? '$cur ' + p.purchasePrice.toStringAsFixed(2) : '••••••'}</td>
        <td>${canViewCost ? '$cur ' + p.purchasePrice.toStringAsFixed(2) : '••••••'}</td>
        <td>${canViewCost ? margin.toStringAsFixed(2) + '%' : '••••••'}</td>
        <td class="bold">$cur ${p.sellingPrice.toStringAsFixed(2)}</td>
        <td class="bold">$cur ${p.sellingPrice.toStringAsFixed(2)}</td>
      </tr>
      ${variations.map((v) {
        final vMargin = v.purchasePrice > 0 ? (((v.sellingPrice - v.purchasePrice) / v.purchasePrice) * 100) : 0.0;
        return '''
        <tr>
          <td>${canViewCost ? '$cur ' + v.purchasePrice.toStringAsFixed(2) : '••••••'}</td>
          <td>${canViewCost ? '$cur ' + v.purchasePrice.toStringAsFixed(2) : '••••••'}</td>
          <td>${canViewCost ? vMargin.toStringAsFixed(2) + '%' : '••••••'}</td>
          <td class="bold">$cur ${v.sellingPrice.toStringAsFixed(2)}</td>
          <td class="bold">$cur ${v.sellingPrice.toStringAsFixed(2)}</td>
        </tr>
        ''';
      }).join()}
    </tbody>
  </table>

  <div class="section-title">Product Stock Details</div>
  <table>
    <thead>
      <tr>
        <th>SKU</th>
        <th>Product</th>
        <th>Location</th>
        <th>Unit Price</th>
        <th>Current stock</th>
        <th>Current Stock Value</th>
        <th>Total unit sold</th>
        <th>Total Unit Transfered</th>
        <th>Total Unit Adjusted</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${_escape(p.sku)}</td>
        <td class="bold">${_escape(p.name)}</td>
        <td>${_escape(locationName)}</td>
        <td>$cur ${p.sellingPrice.toStringAsFixed(2)}</td>
        <td class="bold">${p.stockQuantity.toStringAsFixed(2)} ${p.unit}</td>
        <td class="bold">$cur ${(p.stockQuantity * p.sellingPrice).toStringAsFixed(2)}</td>
        <td>${totalSold.toStringAsFixed(2)} ${p.unit}</td>
        <td>${totalTransferred.toStringAsFixed(2)} ${p.unit}</td>
        <td>${totalAdjusted.toStringAsFixed(2)} ${p.unit}</td>
      </tr>
      ${variations.map((v) {
        return '''
        <tr>
          <td>${_escape(v.subSku)}</td>
          <td class="bold">${_escape(p.name)} - ${_escape(v.name)}</td>
          <td>${_escape(locationName)}</td>
          <td>$cur ${v.sellingPrice.toStringAsFixed(2)}</td>
          <td class="bold">${v.stockQuantity.toStringAsFixed(2)} ${p.unit}</td>
          <td class="bold">$cur ${(v.stockQuantity * v.sellingPrice).toStringAsFixed(2)}</td>
          <td>0.00 ${p.unit}</td>
          <td>0.00 ${p.unit}</td>
          <td>0.00 ${p.unit}</td>
        </tr>
        ''';
      }).join()}
    </tbody>
  </table>
</body>
</html>
''';
  }

  static String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return DateFormat('dd/MM/yyyy, hh:mm a').format(DateTime.now());
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd/MM/yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }
}
