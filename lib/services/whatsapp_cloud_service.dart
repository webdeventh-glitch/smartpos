import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'app_logger.dart';
import 'database_service.dart';
import 'messaging_service.dart';

/// Meta WhatsApp Cloud API direct dispatcher service.
/// Sends digital invoices and business notifications without opening external browser tabs.
class WhatsAppCloudService {
  static const String _graphApiBase = 'https://graph.facebook.com/v18.0';

  /// Sends a direct message via Meta WhatsApp Business Cloud API.
  /// If credentials are missing or the API returns an error, it falls back to desktop WhatsApp URL.
  static Future<bool> sendMessage({
    required String to,
    required String text,
    String? tokenOverride,
    String? phoneIdOverride,
    String recipientName = 'Customer',
    http.Client? httpClient,
  }) async {
    final db = await DatabaseService.initialize();
    final settings = await db.getBusinessSettings();
    if (!settings.isModuleEnabled(BusinessSettings.moduleMessaging)) {
      AppLogger.info('WhatsAppCloudService',
          'WhatsApp dispatch skipped: SMS & WhatsApp module disabled.');
      return false;
    }

    final cleanPhone =
        MessagingService.formatPhoneNumber(to, international: true);
    final token = (tokenOverride ?? settings.whatsappCloudToken).trim();
    final phoneId = (phoneIdOverride ?? settings.whatsappPhoneNumberId).trim();

    // If Cloud API credentials are not provided, gracefully fall back to web/desktop link
    if (token.isEmpty || phoneId.isEmpty) {
      AppLogger.info('WhatsAppCloudService',
          'Cloud credentials unset; falling back to direct link');
      return await MessagingService.sendWhatsAppDirect(
        to: cleanPhone,
        message: text,
        recipientName: recipientName,
      );
    }

    final url = Uri.parse('$_graphApiBase/$phoneId/messages');
    final payload = {
      'messaging_product': 'whatsapp',
      'recipient_type': 'individual',
      'to': cleanPhone,
      'type': 'text',
      'text': {'preview_url': false, 'body': text},
    };

    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final isSuccess =
          response.statusCode == 200 || response.statusCode == 201;

      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'whatsapp_cloud',
        messageBody: text,
        status: isSuccess ? 'sent' : 'failed',
        gatewayName: 'Meta WhatsApp Cloud API',
        errorDetails: isSuccess
            ? 'Delivered via Graph API'
            : 'HTTP ${response.statusCode}: ${response.body}',
        createdAt: DateTime.now().toIso8601String(),
      ));

      if (isSuccess) {
        return true;
      } else {
        AppLogger.warning('WhatsAppCloudService',
            'Cloud API failed; trying fallback link', response.body);
        return await MessagingService.sendWhatsAppDirect(
          to: cleanPhone,
          message: text,
          recipientName: recipientName,
        );
      }
    } catch (e, st) {
      AppLogger.error('WhatsAppCloudService',
          'Exception sending WhatsApp Cloud message', e, st);
      // Fallback
      return await MessagingService.sendWhatsAppDirect(
        to: cleanPhone,
        message: text,
        recipientName: recipientName,
      );
    }
  }

  /// Formats and dispatches a comprehensive digital sales receipt to the customer's WhatsApp.
  static Future<bool> sendSaleReceipt({
    required Sale sale,
    required BusinessSettings settings,
    required String customerPhone,
    String? customerName,
  }) async {
    final cleanPhone = customerPhone.trim();
    if (cleanPhone.isEmpty) return false;

    final cur = settings.currencySymbol;
    final buffer = StringBuffer();
    buffer
        .writeln('🧾 *SALES RECEIPT — ${settings.businessName.toUpperCase()}*');
    if (settings.receiptHeaderTagline.isNotEmpty) {
      buffer.writeln('_${settings.receiptHeaderTagline}_');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Invoice #:* ${sale.invoiceNo}');
    buffer.writeln('*Date:* ${sale.createdAt}');
    if (customerName != null && customerName.isNotEmpty) {
      buffer.writeln('*Customer:* $customerName');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Purchased Items:*');

    for (final item in sale.items ?? <SaleItem>[]) {
      buffer.writeln(
          '• ${item.quantity.toInt()}x ${item.productName} — $cur${item.subtotal.toStringAsFixed(2)}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('*Subtotal:* $cur${sale.subtotal.toStringAsFixed(2)}');

    if (sale.discount > 0) {
      buffer.writeln('*Discount:* -$cur${sale.discount.toStringAsFixed(2)}');
    }

    if (sale.taxAmount > 0) {
      buffer.writeln('*Tax:* +$cur${sale.taxAmount.toStringAsFixed(2)}');
    }

    buffer
        .writeln('*Grand Total:* *$cur${sale.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln('*Payment Method:* ${sale.paymentMethod.toUpperCase()}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (settings.receiptReturnPolicy.isNotEmpty) {
      buffer.writeln(settings.receiptReturnPolicy);
    }

    buffer.writeln('\n_Thank you for your business! 🙏_');

    return await sendMessage(
      to: cleanPhone,
      text: buffer.toString(),
      recipientName: customerName ?? 'Valued Customer',
    );
  }
}
