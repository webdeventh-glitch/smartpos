import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Fiscal compliance standards supported by SmartPOS.
enum FiscalComplianceMode {
  none,
  zatca, // Kingdom of Saudi Arabia (ZATCA Fatoorah Phase 1 & 2 TLV QR)
  fbr, // Federal Board of Revenue (Pakistan Digital Invoicing USIN & QR)
}

/// Service providing cryptographic Tag-Length-Value (TLV) QR encoding for Saudi Arabia ZATCA
/// and Unique System Invoice Number (USIN) verification QR codes for Pakistan FBR.
class FiscalEInvoiceService {
  /// Encodes a TLV component: Tag (1 byte) + Length (1 byte) + Value (UTF-8 bytes).
  static Uint8List _encodeTlvComponent(int tag, String value) {
    final valueBytes = utf8.encode(value);
    final length = valueBytes.length;
    final buffer = BytesBuilder(copy: false);
    buffer.addByte(tag);
    buffer.addByte(length);
    buffer.add(valueBytes);
    return buffer.toBytes();
  }

  /// Generates the official Saudi Arabia ZATCA Phase 1 & 2 compliant Base64 TLV string.
  /// Standard tags:
  /// Tag 1: Seller's Name
  /// Tag 2: VAT Registration Number (15 digits)
  /// Tag 3: Invoice Timestamp (ISO 8601 UTC / formatted)
  /// Tag 4: Invoice Total Amount (inclusive of VAT)
  /// Tag 5: Total VAT Amount
  static String generateZatcaTlvBase64({
    required String sellerName,
    required String vatNumber,
    required DateTime timestamp,
    required double totalAmount,
    required double vatAmount,
  }) {
    final cleanName =
        sellerName.trim().isNotEmpty ? sellerName.trim() : 'SmartPOS Merchant';
    final cleanVat =
        vatNumber.trim().isNotEmpty ? vatNumber.trim() : '300000000000003';
    final isoTimestamp =
        DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(timestamp.toUtc());
    final totalStr = totalAmount.toStringAsFixed(2);
    final vatStr = vatAmount.toStringAsFixed(2);

    final builder = BytesBuilder(copy: false);
    builder.add(_encodeTlvComponent(1, cleanName));
    builder.add(_encodeTlvComponent(2, cleanVat));
    builder.add(_encodeTlvComponent(3, isoTimestamp));
    builder.add(_encodeTlvComponent(4, totalStr));
    builder.add(_encodeTlvComponent(5, vatStr));

    return base64Encode(builder.toBytes());
  }

  /// Generates a Pakistan FBR Unique System Invoice Number (USIN).
  /// Format: <POS_ID><YYYYMMDDHHmmss><CLEAN_INV_NO>
  static String generateFbrUsin({
    required String posId,
    required String invoiceNo,
    required DateTime timestamp,
  }) {
    final cleanPos = posId.trim().isNotEmpty ? posId.trim() : '100001';
    final tsStr = DateFormat('yyyyMMddHHmmss').format(timestamp);
    final cleanInv = invoiceNo.replaceAll(RegExp(r'\D'), '');
    final suffix = cleanInv.isNotEmpty ? cleanInv : '1';
    return '$cleanPos$tsStr$suffix';
  }

  /// Generates an FBR digital verification QR URL payload.
  static String generateFbrQrPayload({
    required String posId,
    required String usin,
    required double totalAmount,
    required double salesTax,
    required DateTime timestamp,
  }) {
    final cleanPos = posId.trim().isNotEmpty ? posId.trim() : '100001';
    final total = totalAmount.toStringAsFixed(2);
    final tax = salesTax.toStringAsFixed(2);
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    return 'https://verify.fbr.gov.pk/verify?usin=$usin&pos=$cleanPos&amt=$total&tax=$tax&dt=${Uri.encodeComponent(ts)}';
  }

  /// Resolves the fiscal compliance mode from BusinessSettings.
  static FiscalComplianceMode resolveMode(BusinessSettings settings) {
    final mode = (settings.fiscalComplianceMode).toLowerCase().trim();
    if (mode == 'zatca' || mode == 'saudi' || mode == 'ksa') {
      return FiscalComplianceMode.zatca;
    }
    if (mode == 'fbr' || mode == 'pakistan' || mode == 'pk') {
      return FiscalComplianceMode.fbr;
    }
    return FiscalComplianceMode.none;
  }

  /// Computes the appropriate QR code payload for a given sale according to active fiscal policy.
  static String getQrPayloadForSale({
    required Sale sale,
    required BusinessSettings settings,
  }) {
    final mode = resolveMode(settings);
    final timestamp = DateTime.tryParse(sale.createdAt) ?? DateTime.now();

    switch (mode) {
      case FiscalComplianceMode.zatca:
        final vatNum = settings.zatcaVatNumber.isNotEmpty
            ? settings.zatcaVatNumber
            : settings.taxNumber;
        return generateZatcaTlvBase64(
          sellerName: settings.businessName,
          vatNumber: vatNum,
          timestamp: timestamp,
          totalAmount: sale.totalAmount,
          vatAmount: sale.taxAmount,
        );

      case FiscalComplianceMode.fbr:
        final posId =
            settings.fbrPosId.isNotEmpty ? settings.fbrPosId : '100001';
        final usin = generateFbrUsin(
          posId: posId,
          invoiceNo: sale.invoiceNo,
          timestamp: timestamp,
        );
        return generateFbrQrPayload(
          posId: posId,
          usin: usin,
          totalAmount: sale.totalAmount,
          salesTax: sale.taxAmount,
          timestamp: timestamp,
        );

      case FiscalComplianceMode.none:
        return 'INV:${sale.invoiceNo}|TOTAL:${sale.totalAmount.toStringAsFixed(2)}|DATE:${sale.createdAt}';
    }
  }

  /// Returns compliance header text for receipt printout.
  static String? getComplianceReceiptHeader(BusinessSettings settings) {
    final mode = resolveMode(settings);
    switch (mode) {
      case FiscalComplianceMode.zatca:
        return 'فاتورة ضريبية - SIMPLIFIED TAX INVOICE';
      case FiscalComplianceMode.fbr:
        return 'FBR DIGITAL FISCAL INVOICE';
      case FiscalComplianceMode.none:
        return null;
    }
  }

  /// Returns compliance footer lines for receipt printout.
  static List<String> getComplianceReceiptFooter({
    required Sale sale,
    required BusinessSettings settings,
  }) {
    final mode = resolveMode(settings);
    final lines = <String>[];
    final timestamp = DateTime.tryParse(sale.createdAt) ?? DateTime.now();

    switch (mode) {
      case FiscalComplianceMode.zatca:
        final vatNum = settings.zatcaVatNumber.isNotEmpty
            ? settings.zatcaVatNumber
            : settings.taxNumber;
        lines.add('ZATCA VAT Reg #: $vatNum');
        lines.add('Scan QR code with ZATCA App to verify');
        break;

      case FiscalComplianceMode.fbr:
        final posId =
            settings.fbrPosId.isNotEmpty ? settings.fbrPosId : '100001';
        final usin = generateFbrUsin(
          posId: posId,
          invoiceNo: sale.invoiceNo,
          timestamp: timestamp,
        );
        lines.add('FBR POS ID: $posId');
        lines.add('FBR Invoice USIN:');
        lines.add(usin);
        lines.add('Verify via FBR Asaan Tax App');
        break;

      case FiscalComplianceMode.none:
        break;
    }
    return lines;
  }
}
