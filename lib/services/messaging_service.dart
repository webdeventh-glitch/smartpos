import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';

class MessagingService {
  /// Cleans and formats phone numbers for Pakistani networks (or international format)
  static String formatPhoneNumber(String raw, {bool international = true}) {
    // Strip non-digits
    String digits = raw.replaceAll(RegExp(r'\D'), '');

    if (international) {
      if (digits.startsWith('03') && digits.length == 11) {
        return '92${digits.substring(1)}';
      } else if (digits.startsWith('3') && digits.length == 10) {
        return '92$digits';
      } else if (digits.startsWith('0092')) {
        return digits.substring(2);
      }
      return digits;
    } else {
      if (digits.startsWith('923') && digits.length == 12) {
        return '0${digits.substring(2)}';
      }
      return digits;
    }
  }

  /// Sends an SMS via the configured active gateway in the database
  static Future<bool> sendSms({
    required String to,
    required String message,
    String recipientName = 'Customer',
    SmsGateway? gatewayOverride,
  }) async {
    final db = await DatabaseService.initialize();
    final cleanPhone = formatPhoneNumber(to);
    final gateway = gatewayOverride ?? await db.getActiveSmsGateway();

    if (gateway == null || gateway.apiUrl.trim().isEmpty) {
      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'sms',
        messageBody: message,
        status: 'failed',
        gatewayName: 'None',
        errorDetails: 'No active SMS gateway configured in Settings.',
        createdAt: DateTime.now().toIso8601String(),
      ));
      return false;
    }

    try {
      final method = gateway.httpMethod.toUpperCase();
      final mask = gateway.senderId.isNotEmpty ? gateway.senderId : 'SMARTPOS';

      String url = gateway.apiUrl
          .replaceAll('{to}', Uri.encodeComponent(cleanPhone))
          .replaceAll('{mobile}', Uri.encodeComponent(cleanPhone))
          .replaceAll('{message}', Uri.encodeComponent(message))
          .replaceAll('{text}', Uri.encodeComponent(message))
          .replaceAll('{mask}', Uri.encodeComponent(mask))
          .replaceAll('{sender}', Uri.encodeComponent(mask))
          .replaceAll('{key}', Uri.encodeComponent(gateway.apiKey))
          .replaceAll('{secret}', Uri.encodeComponent(gateway.apiSecret));

      http.Response response;

      if (method == 'GET') {
        response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      } else {
        // POST request
        Map<String, String> headers = {'Content-Type': 'application/json'};
        if (gateway.apiKey.isNotEmpty && gateway.provider == 'twilio') {
          final credentials = base64Encode(utf8.encode('${gateway.apiKey}:${gateway.apiSecret}'));
          headers['Authorization'] = 'Basic $credentials';
        }

        String body = gateway.payloadFormat.isNotEmpty
            ? gateway.payloadFormat
                .replaceAll('{to}', cleanPhone)
                .replaceAll('{message}', message)
                .replaceAll('{mask}', mask)
                .replaceAll('{key}', gateway.apiKey)
            : jsonEncode({
                'to': cleanPhone,
                'message': message,
                'sender': mask,
                'api_key': gateway.apiKey,
              });

        response = await http
            .post(Uri.parse(url), headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      }

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'sms',
        messageBody: message,
        status: isSuccess ? 'sent' : 'failed',
        gatewayName: gateway.name,
        errorDetails: isSuccess ? 'HTTP ${response.statusCode}' : 'Error ${response.statusCode}: ${response.body}',
        createdAt: DateTime.now().toIso8601String(),
      ));

      return isSuccess;
    } catch (e) {
      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'sms',
        messageBody: message,
        status: 'failed',
        gatewayName: gateway.name,
        errorDetails: e.toString(),
        createdAt: DateTime.now().toIso8601String(),
      ));
      return false;
    }
  }

  /// Opens WhatsApp Desktop or WhatsApp Web with pre-formatted message
  static Future<bool> sendWhatsAppDirect({
    required String to,
    required String message,
    String recipientName = 'Customer',
  }) async {
    final cleanPhone = formatPhoneNumber(to);
    final encodedMsg = Uri.encodeComponent(message);
    final waUrl = 'https://wa.me/$cleanPhone?text=$encodedMsg';

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', waUrl]);
      } else {
        await Process.run('open', [waUrl]);
      }

      final db = await DatabaseService.initialize();
      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'whatsapp',
        messageBody: message,
        status: 'sent',
        gatewayName: 'WhatsApp Web/Desktop',
        errorDetails: 'Dispatched via WhatsApp link',
        createdAt: DateTime.now().toIso8601String(),
      ));

      return true;
    } catch (e) {
      final db = await DatabaseService.initialize();
      await db.addMessageLog(MessageLog(
        recipientName: recipientName,
        phoneNumber: cleanPhone,
        channel: 'whatsapp',
        messageBody: message,
        status: 'failed',
        gatewayName: 'WhatsApp Web/Desktop',
        errorDetails: e.toString(),
        createdAt: DateTime.now().toIso8601String(),
      ));
      return false;
    }
  }

  /// Sends a bulk marketing or notification campaign to a list of contacts
  static Future<Map<String, dynamic>> sendBulkSms({
    required List<Map<String, dynamic>> contacts,
    required String messageTemplate,
    required String businessName,
    Function(int sent, int total)? onProgress,
  }) async {
    int successful = 0;
    int failed = 0;
    final total = contacts.length;

    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final name = contact['name'] as String? ?? 'Valued Customer';
      final phone = contact['phone'] as String? ?? '';
      final due = (contact['due'] as num?)?.toDouble() ?? 0.0;

      if (phone.trim().isEmpty) {
        failed++;
        continue;
      }

      final text = messageTemplate
          .replaceAll('{customer_name}', name)
          .replaceAll('{business_name}', businessName)
          .replaceAll('{due_amount}', due.toStringAsFixed(2));

      final ok = await sendSms(to: phone, message: text, recipientName: name);
      if (ok) {
        successful++;
      } else {
        failed++;
      }

      if (onProgress != null) {
        onProgress(i + 1, total);
      }

      // Brief delay to prevent network rate throttling
      await Future.delayed(const Duration(milliseconds: 150));
    }

    return {
      'total': total,
      'successful': successful,
      'failed': failed,
    };
  }

  /// Formats a complete, professional sale receipt text for WhatsApp or SMS
  static String formatSaleReceiptMessage({
    required Sale sale,
    required BusinessSettings settings,
    List<SaleItem>? items,
  }) {
    final currency = settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs';
    final buffer = StringBuffer();

    buffer.writeln('Receipt from ${settings.businessName}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Invoice #: ${sale.invoiceNo}');
    buffer.writeln('Date: ${sale.createdAt}');
    buffer.writeln('Customer: ${sale.customerName}');
    buffer.writeln('--------------------------------');

    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        buffer.writeln('${item.productName} x ${item.quantity.toStringAsFixed(0)} = $currency ${(item.unitPrice * item.quantity).toStringAsFixed(2)}');
      }
      buffer.writeln('--------------------------------');
    }

    buffer.writeln('Subtotal: $currency ${sale.subtotal.toStringAsFixed(2)}');
    if (sale.discount > 0) {
      buffer.writeln('Discount: $currency ${sale.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('Total Amount: $currency ${sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Paid Amount: $currency ${sale.paidAmount.toStringAsFixed(2)}');
    if (sale.dueAmount > 0) {
      buffer.writeln('Pending Due: $currency ${sale.dueAmount.toStringAsFixed(2)}');
    }
    buffer.writeln('Payment: ${sale.paymentMethod.toUpperCase()} (${sale.paymentStatus.toUpperCase()})');
    buffer.writeln('--------------------------------');
    buffer.writeln('Thank you for your business! ${settings.phone}');

    return buffer.toString();
  }

  /// Formats an overdue payment reminder message for customer ledger
  static String formatDuePaymentReminder({
    required String customerName,
    required double dueAmount,
    required BusinessSettings settings,
    String? invoiceNo,
  }) {
    final currency = settings.currencySymbol.isNotEmpty ? settings.currencySymbol : 'Rs';
    final invPart = invoiceNo != null ? ' regarding invoice #$invoiceNo' : '';

    return 'Dear $customerName, this is a gentle reminder from ${settings.businessName}$invPart. '
        'Your pending balance is $currency ${dueAmount.toStringAsFixed(2)}. '
        'Kindly settle your payment at your earliest convenience. Thank you! Contact: ${settings.phone}';
  }
}

