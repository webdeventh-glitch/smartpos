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
  }) {
    final cur = settings.currencySymbol;
    final paperSize = (paperSizeOverride ?? settings.receiptPaperSize).toLowerCase();
    final isA4 = paperSize == 'a4' || paperSize == 'a4 agency';
    final is58mm = paperSize == '58mm';
    final pageSizeCss = isA4 ? 'A4 portrait' : (is58mm ? '58mm auto' : '80mm auto');
    final maxWidthCss = isA4 ? '780px' : (is58mm ? '48mm' : '72mm');
    final fontSizeCss = isA4 ? '13px' : (is58mm ? '10px' : '12px');

    final itemsHtml = StringBuffer();
    if (sale.items != null) {
      for (int i = 0; i < sale.items!.length; i++) {
        final item = sale.items![i];
        if (isA4) {
          itemsHtml.writeln('''
            <tr>
              <td style="text-align:center;">${i + 1}</td>
              <td style="font-weight:bold;">${_escape(item.productName)}</td>
              <td>${_escape(item.batchNumber ?? '-')}</td>
              <td>${_escape(item.expiryDate ?? '-')}</td>
              <td style="text-align:center;">${item.quantity.toStringAsFixed(0)}</td>
              <td style="text-align:right;">$cur${item.unitPrice.toStringAsFixed(2)}</td>
              <td style="text-align:right;">${item.packDiscount > 0 ? '${item.packDiscount}%' : '-'}</td>
              <td style="text-align:right; font-weight:bold;">$cur${item.subtotal.toStringAsFixed(2)}</td>
            </tr>
          ''');
        } else {
          // Thermal Slip Layout
          itemsHtml.writeln('''
            <tr style="border-bottom: 1px dashed #ccc;">
              <td colspan="4" style="padding-top: 4px; font-weight: bold;">${_escape(item.productName)}</td>
            </tr>
            <tr style="border-bottom: 1px dotted #ddd;">
              <td style="padding-bottom: 4px;">${item.quantity.toStringAsFixed(0)} x $cur${item.unitPrice.toStringAsFixed(2)}</td>
              <td style="padding-bottom: 4px; text-align:center;">${item.batchNumber != null && item.batchNumber!.isNotEmpty ? 'B:${item.batchNumber}' : ''}</td>
              <td style="padding-bottom: 4px; text-align:right;">${item.packDiscount > 0 ? '-${item.packDiscount}%' : ''}</td>
              <td style="padding-bottom: 4px; text-align:right; font-weight: bold;">$cur${item.subtotal.toStringAsFixed(2)}</td>
            </tr>
          ''');
        }
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
        itemsHtml.writeln('''
          <tr>
            <td style="text-align:center; padding: 6px;">${i + 1}</td>
            <td style="padding: 6px; font-weight:bold;">${_escape(item.productName)}</td>
            <td style="text-align:center; padding: 6px;">${item.quantity.toStringAsFixed(0)}</td>
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
