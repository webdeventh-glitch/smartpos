import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/pdf_export_service.dart';
import '../../services/print_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/number_to_words_service.dart';
import '../../services/localization_service.dart';

class ReceiptDialog extends StatefulWidget {
  final Sale sale;
  final BusinessSettings settings;
  final double tenderedAmount;
  final double changeReturn;
  final double? customerPreviousBalance;

  const ReceiptDialog({
    super.key,
    required this.sale,
    required this.settings,
    required this.tenderedAmount,
    required this.changeReturn,
    this.customerPreviousBalance,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  late String _paperSize;

  @override
  void initState() {
    super.initState();
    final name = widget.sale.customerName.toLowerCase().trim();
    final isWalkIn = name.contains('walk-in') ||
        name.contains('walk in') ||
        name == 'cash customer' ||
        name.contains('walkin');
    // Retail counter walk-in defaults to 80mm POS slip; Registered account holder defaults to A4 Agency invoice
    _paperSize = isWalkIn ? '80mm POS' : 'A4 Agency';
  }

  String _numberToWords(double amount) {
    return NumberToWordsService.convert(
      amount,
      language: widget.settings.totalInWordsLanguage,
      currencySymbol: widget.settings.currencySymbol,
      currencyCode: widget.settings.currencyCode,
    );
  }

  String _generateWhatsAppInvoiceText() {
    final currency = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('*${widget.settings.businessName.toUpperCase()}*');
    buffer.writeln('Branch: ${widget.settings.branchName}');
    if (widget.settings.phone.isNotEmpty)
      buffer.writeln('Tel: ${widget.settings.phone}');
    buffer.writeln('========================================');
    buffer.writeln('*INVOICE:* ${widget.sale.invoiceNo}');
    buffer.writeln('Date: ${widget.sale.createdAt}');
    buffer.writeln('Customer: ${widget.sale.customerName}');
    buffer.writeln('Payment: ${widget.sale.paymentMethod.toUpperCase()}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('*ITEMS / PARTICULARS:*');
    if (widget.sale.items != null) {
      for (int i = 0; i < widget.sale.items!.length; i++) {
        final item = widget.sale.items![i];
        final qtyStr =
            item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2);
        final unitStr = (item.unitName != null && item.unitName!.isNotEmpty)
            ? ' ${item.unitName}'
            : '';
        buffer.writeln('${i + 1}. *${item.displayName}*');
        buffer.writeln(
            '    $qtyStr$unitStr x $currency${item.unitPrice.toStringAsFixed(2)} = *$currency${item.subtotal.toStringAsFixed(2)}*');
        if (item.resolvedDiscountAmount > 0) {
          buffer.writeln('    Disc: ${item.formatDiscountTag(currency)}');
        }
      }
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln(
        'Subtotal: $currency${widget.sale.subtotal.toStringAsFixed(2)}');
    if (widget.sale.discount > 0) {
      buffer.writeln(
          'Discount: -$currency${widget.sale.discount.toStringAsFixed(2)}');
    }
    if (widget.sale.taxAmount > 0) {
      buffer.writeln(
          'Tax: +$currency${widget.sale.taxAmount.toStringAsFixed(2)}');
      for (final entry in widget.sale.taxBreakdownMap.entries) {
        buffer.writeln(
            '  • ${entry.key}: +$currency${entry.value.toStringAsFixed(2)}');
      }
    }
    buffer.writeln(
        '*TOTAL PAYABLE: $currency${widget.sale.totalAmount.toStringAsFixed(2)}*');
    buffer.writeln(
        'Amount Paid: $currency${widget.sale.paidAmount.toStringAsFixed(2)}');
    if (widget.sale.dueAmount > 0) {
      buffer.writeln(
          '*Balance Due: $currency${widget.sale.dueAmount.toStringAsFixed(2)}*');
    }
    buffer.writeln('========================================');
    buffer.writeln('Thank you for your business.');
    buffer.writeln('========================================');
    return buffer.toString();
  }

  void _showWhatsAppModal() {
    final phoneCtrl = TextEditingController();
    final message = _generateWhatsAppInvoiceText();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const FaIcon(FontAwesomeIcons.whatsapp,
                                  color: Color(0xFF25D366), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Send Invoice via WhatsApp',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Invoice #${widget.sale.invoiceNo} • ${widget.sale.customerName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Customer WhatsApp Number *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 03001234567 or 923001234567',
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.phone_iphone_rounded,
                          size: 18, color: Color(0xFF25D366)),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Message Preview',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        message,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4F46E5),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('Copy Bill Text',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('WhatsApp bill copied to clipboard!'),
                              backgroundColor: Color(0xFF4F46E5),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                        label: const Text('Send via WhatsApp',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          var phone =
                              phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                          if (phone.startsWith('0')) {
                            phone = '92${phone.substring(1)}';
                          } else if (phone.length == 10) {
                            phone = '92$phone';
                          }
                          final encoded = Uri.encodeComponent(message);
                          final url = 'https://wa.me/$phone?text=$encoded';
                          try {
                            if (Platform.isWindows) {
                              Process.run('cmd', ['/c', 'start', '', url]);
                            }
                          } catch (e, st) {
                            AppLogger.warning('ReceiptDialog',
                                'Failed launching WhatsApp link', e, st);
                          }
                          Clipboard.setData(ClipboardData(text: message));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('WhatsApp launched & bill copied!'),
                              backgroundColor: Color(0xFF10B981),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _generatePlainTextReceipt() {
    final currency = widget.settings.currencySymbol;
    final isPharma = widget.settings.isPharmacy;
    final isRest = widget.settings.isRestaurant;
    final buffer = StringBuffer();
    buffer.writeln(
        '========================================================================');
    buffer.writeln(widget.settings.businessName.toUpperCase());
    if (isPharma) {
      buffer
          .writeln('DISTRIBUTOR & WHOLESALER - ${widget.settings.branchName}');
    } else if (isRest) {
      buffer.writeln('RESTAURANT & CAFE - ${widget.settings.branchName}');
    } else {
      buffer.writeln('RETAIL & POINT OF SALE - ${widget.settings.branchName}');
    }
    buffer.writeln(widget.settings.address);
    if (widget.settings.phone.isNotEmpty)
      buffer.writeln('CELL NO: ${widget.settings.phone}');
    buffer.writeln(
        '------------------------------------------------------------------------');
    buffer.writeln(
        'INVOICE NO:  ${widget.sale.invoiceNo}    DATE: ${widget.sale.createdAt}');
    buffer.writeln(
        'CUSTOMER:    ${widget.sale.customerName}    PAY: ${widget.sale.paymentMethod.toUpperCase()}');
    buffer.writeln(
        '------------------------------------------------------------------------');

    if (isPharma) {
      buffer.writeln(
          'DESCRIPTION           BATCH    EXP-DATE   QTY  BONUS   RATE     DISC%    NET TOTAL');
      buffer.writeln(
          '------------------------------------------------------------------------');
      if (widget.sale.items != null) {
        for (final item in widget.sale.items!) {
          final name = item.displayName.length > 20
              ? item.displayName.substring(0, 20)
              : item.displayName.padRight(20);
          final batch = (item.batchNumber ?? '-').padRight(8);
          final exp = (item.expiryDate ?? '-').padRight(10);
          final qty = item.quantity.toStringAsFixed(0).padLeft(3);
          final bonus = item.bonusQuantity.toStringAsFixed(0).padLeft(5);
          final rate = item.unitPrice.toStringAsFixed(2).padLeft(8);
          final pctDisc = item.discountType == 'percentage'
              ? (item.discountValue > 0
                  ? item.discountValue
                  : item.packDiscount)
              : item.packDiscount;
          final disc = (pctDisc > 0
                  ? '${pctDisc.toStringAsFixed(pctDisc == pctDisc.roundToDouble() ? 0 : 1)}%'
                  : (item.resolvedDiscountAmount > 0
                      ? item.resolvedDiscountAmount.toStringAsFixed(2)
                      : '0.00'))
              .padLeft(7);
          final total = item.subtotal.toStringAsFixed(2).padLeft(10);
          buffer.writeln('$name $batch $exp $qty $bonus $rate $disc $total');
        }
      }
    } else {
      buffer.writeln(
          'ITEM DESCRIPTION                       QTY    UNIT PRICE     DISC       TOTAL');
      buffer.writeln(
          '------------------------------------------------------------------------');
      if (widget.sale.items != null) {
        for (final item in widget.sale.items!) {
          final name = item.displayName.length > 35
              ? item.displayName.substring(0, 35)
              : item.displayName.padRight(35);
          final qty = item.quantity.toStringAsFixed(0).padLeft(5);
          final rate = item.unitPrice.toStringAsFixed(2).padLeft(13);
          final disc = (item.resolvedDiscountAmount > 0
                  ? item.resolvedDiscountAmount.toStringAsFixed(2)
                  : '-')
              .padLeft(9);
          final total = item.subtotal.toStringAsFixed(2).padLeft(11);
          buffer.writeln('$name $qty $rate $disc $total');
        }
      }
    }

    buffer.writeln(
        '------------------------------------------------------------------------');
    buffer.writeln(
        'SUBTOTAL:                 $currency${widget.sale.subtotal.toStringAsFixed(2)}');
    if (widget.sale.discount > 0) {
      buffer.writeln(
          '${isPharma ? "PACK DISCOUNT:" : "DISCOUNT:     "}           -$currency${widget.sale.discount.toStringAsFixed(2)}');
    }
    if (widget.sale.taxAmount > 0) {
      buffer.writeln(
          '${isPharma ? "ADVANCE TAX (SEC 236H):" : "TAX:                   "}  +$currency${widget.sale.taxAmount.toStringAsFixed(2)}');
      for (final entry in widget.sale.taxBreakdownMap.entries) {
        buffer.writeln(
            '  ${entry.key.padRight(24)} +$currency${entry.value.toStringAsFixed(2)}');
      }
    }
    buffer.writeln(
        'TOTAL AMOUNT:             $currency${widget.sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln(
        'PAID AMOUNT:              $currency${widget.sale.paidAmount.toStringAsFixed(2)}');
    if (widget.sale.dueAmount > 0)
      buffer.writeln(
          'BALANCE DUE:              $currency${widget.sale.dueAmount.toStringAsFixed(2)}');
    buffer.writeln(
        '========================================================================');
    if (isPharma) {
      buffer.writeln(
          'FORM 2A (SEE RULES 19 & 30). WARRANTY UNDER SECTION 23(i) OF DRUG ACT, 1976');
      buffer.writeln(
          'Note: Expiry claim must be reported 6 months prior to expiry date with original bill.');
    } else {
      buffer.writeln(
          'Thank you for shopping with us! Please retain this receipt for returns/exchange.');
    }
    buffer.writeln(
        '========================================================================');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isA4 = _paperSize == 'A4 Agency' || _paperSize == 'A4';
    final is58mm = _paperSize == '58mm Thermal' || _paperSize == '58mm';
    final double dialogWidth = isA4
        ? math.min(screenWidth * 0.95, 920.0)
        : math.min(screenWidth * 0.95, 760.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: math.min(screenHeight * 0.92, 860.0),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.transparent),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top control bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Invoice Preview ($_paperSize)',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _formatChip('A4 Agency', isA4),
                    const SizedBox(width: 6),
                    _formatChip('80mm POS',
                        _paperSize == '80mm POS' || _paperSize == '80mm'),
                    const SizedBox(width: 6),
                    _formatChip('58mm Thermal', is58mm),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Invoice Body with clean background and paper card
              Flexible(
                child: Container(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isA4 ? 20 : 16,
                      vertical: 16,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: isA4 ? 760.0 : (is58mm ? 300.0 : 380.0),
                          padding: EdgeInsets.all(isA4 ? 22 : 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isA4
                              ? _buildA4AgencyInvoice(currency)
                              : _buildThermalReceipt(currency, is58mm),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                      top: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0))),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, actionConstraints) {
                    final isNarrow = actionConstraints.maxWidth < 620;
                    final isUltraNarrow = actionConstraints.maxWidth < 460;

                    final whatsappBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 12 : 16, vertical: 10),
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 15),
                      label: Text(
                        isUltraNarrow ? 'WA' : 'WhatsApp',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: _showWhatsAppModal,
                    );

                    final printBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 12 : 16, vertical: 10),
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: Text(
                        isUltraNarrow ? 'Print' : 'Print ($_paperSize)',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () async {
                        final html = PrintService.generateSaleInvoiceHtml(
                          sale: widget.sale,
                          settings: widget.settings,
                          tenderedAmount: widget.tenderedAmount,
                          changeReturn: widget.changeReturn,
                          paperSizeOverride: _paperSize,
                          customerPreviousBalance:
                              widget.customerPreviousBalance,
                        );
                        await PrintService.openPrintWindow(
                          htmlContent: html,
                          title: 'Invoice_${widget.sale.invoiceNo}',
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Invoice #${widget.sale.invoiceNo} dispatched to Windows Print Manager!'),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );

                    final completeBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(isUltraNarrow ? 70 : 110, 42),
                        padding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 12 : 16, vertical: 10),
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(
                        isUltraNarrow
                            ? PosLocalization.tr('Done',
                                settings: widget.settings)
                            : (isNarrow
                                ? PosLocalization.tr('Done',
                                    settings: widget.settings)
                                : PosLocalization.tr('Complete (New Sale)',
                                    settings: widget.settings)),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    );

                    final copyBtn = IconButton(
                      icon: Icon(Icons.copy,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569)),
                      tooltip: 'Copy Plaintext Invoice',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _generatePlainTextReceipt()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Invoice copied to clipboard for direct printing!'),
                            backgroundColor: Color(0xFF4F46E5),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    );

                    final thermalBtn = IconButton(
                      icon: const Icon(Icons.receipt_long_rounded,
                          size: 18, color: Color(0xFF7C3AED)),
                      tooltip: 'Direct ESC/POS Thermal Print',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final printed =
                              await ThermalPrinterService.printSaleReceipt(
                            sale: widget.sale,
                            settings: widget.settings,
                            tenderedAmount: widget.tenderedAmount,
                            changeReturn: widget.changeReturn,
                            customerPreviousBalance:
                                widget.customerPreviousBalance,
                          );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                printed
                                    ? 'Receipt #${widget.sale.invoiceNo} sent to ESC/POS thermal printer!'
                                    : 'No ESC/POS thermal printer configured. Configure one in Settings -> Printing.',
                              ),
                              backgroundColor: printed
                                  ? const Color(0xFF10B981)
                                  : Colors.orange,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Thermal print failed: $e'),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                    );

                    final pdfBtn = IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          size: 18, color: Color(0xFFDC2626)),
                      tooltip: 'Export PDF Invoice',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final db = await DatabaseService.initialize();
                        final layout = await db.getDefaultInvoiceLayout();
                        final prodImages = await db.getProductImagePathsByIds(
                          (widget.sale.items ?? const <SaleItem>[])
                              .map((i) => i.productId)
                              .whereType<int>(),
                        );
                        final paperOverride = _paperSize.contains('58')
                            ? '58mm'
                            : (_paperSize.contains('80') ? '80mm' : 'a4');
                        final bytes = await PdfExportService.generateSalePdf(
                          sale: widget.sale,
                          settings: widget.settings,
                          layout: layout,
                          paperSizeOverride: paperOverride,
                          customerPreviousBalance:
                              widget.customerPreviousBalance,
                          productImagePathsById: prodImages,
                        );
                        final file = await PdfExportService.savePdfFile(
                          bytes,
                          'Invoice_${widget.sale.invoiceNo}',
                        );
                        await PdfExportService.openPdfFile(file);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('PDF saved & opened: ${file.path}'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                    );

                    final emailBtn = IconButton(
                      icon: const Icon(Icons.email_outlined,
                          size: 18, color: Color(0xFF0284C7)),
                      tooltip: 'Email PDF Invoice',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final db = await DatabaseService.initialize();
                        final layout = await db.getDefaultInvoiceLayout();
                        final prodImages = await db.getProductImagePathsByIds(
                          (widget.sale.items ?? const <SaleItem>[])
                              .map((i) => i.productId)
                              .whereType<int>(),
                        );
                        String recipientEmail = '';
                        if (widget.sale.customerId != null) {
                          final cust =
                              await db.getContactById(widget.sale.customerId!);
                          recipientEmail = cust?.email ?? '';
                        }
                        final bytes = await PdfExportService.generateSalePdf(
                          sale: widget.sale,
                          settings: widget.settings,
                          layout: layout,
                          paperSizeOverride: 'a4',
                          customerPreviousBalance:
                              widget.customerPreviousBalance,
                          productImagePathsById: prodImages,
                        );
                        final savedFile =
                            await PdfExportService.emailPdfInvoice(
                          bytes: bytes,
                          baseName: 'Invoice_${widget.sale.invoiceNo}',
                          recipientEmail: recipientEmail,
                          subject:
                              '${widget.settings.businessName} - Invoice #${widget.sale.invoiceNo}',
                          body:
                              'Dear ${widget.sale.customerName},\n\nPlease find attached your invoice #${widget.sale.invoiceNo} for ${widget.settings.currencySymbol}${widget.sale.totalAmount.toStringAsFixed(2)}.\n\nThank you for your business!\n${widget.settings.businessName}',
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                'Email draft opened! PDF saved at: ${savedFile.path}'),
                            backgroundColor: const Color(0xFF0284C7),
                          ),
                        );
                      },
                    );

                    return SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [copyBtn, thermalBtn, pdfBtn, emailBtn],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [whatsappBtn, printBtn, completeBtn],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatChip(String title, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _paperSize = title),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Builds Medication / Solar / Agency A4 Invoice Matching Customer's Bill
  Widget _buildA4AgencyInvoice(String currency) {
    final items = widget.sale.items ?? [];
    double totalPackValue = 0.0;
    double totalPackDisc = 0.0;

    for (var it in items) {
      totalPackValue += (it.unitPrice * it.quantity);
      totalPackDisc += it.resolvedDiscountAmount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (Dinar Medicine Agency Style)
        Center(
          child: Column(
            children: [
              Text(
                widget.settings.businessName.toUpperCase(),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'DISTRIBUTOR AND WHOLESALER - ${widget.settings.branchName.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155)),
              ),
              Text(
                widget.settings.address,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (widget.settings.phone.isNotEmpty)
                Text(
                  'CELL NO: ${widget.settings.phone}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Double Border Box for Invoice & Party Metadata
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _a4MetaField('INVOICE NO:', widget.sale.invoiceNo),
                    _a4MetaField(
                        'PARTY CODE:', '${widget.sale.customerId ?? 2033}'),
                    _a4MetaField('PARTY NAME:', widget.sale.customerName),
                    _a4MetaField(
                        'ADDRESS:', widget.settings.address.split(',').first),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Right Column
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _a4MetaField(
                        'DATE:', widget.sale.createdAt.split(' ').first),
                    _a4MetaField('S/MAN.CODE:', '02'),
                    _a4MetaField('NAME:', 'NASIR MENGAL'),
                    _a4MetaField(
                        'TIME:',
                        widget.sale.createdAt.contains(' ')
                            ? widget.sale.createdAt.split(' ').last
                            : '11:38:27'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Product Items Table matching Dinar Medicine Agency
        Table(
          border: TableBorder.all(color: Colors.black, width: 1.0),
          columnWidths: const {
            0: FlexColumnWidth(4.5), // DESCRIPTION
            1: FlexColumnWidth(2.0), // BATCH
            2: FlexColumnWidth(2.0), // EXP-DATE
            3: FlexColumnWidth(1.2), // QTY
            4: FlexColumnWidth(1.4), // BONUS
            5: FlexColumnWidth(2.2), // RATE+GST
            6: FlexColumnWidth(2.4), // PACK VALUE
            7: FlexColumnWidth(1.8), // PACK DISC
            8: FlexColumnWidth(2.4), // NET TOTAL
          },
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: [
                _th('DESCRIPTION'),
                _th('BATCH'),
                _th('EXP-DATE'),
                _th('QTY'),
                _th('BONUS'),
                _th('RATE+GST'),
                _th('PACK VALUE'),
                _th('PACK DISC'),
                _th('NET TOTAL'),
              ],
            ),
            // Item Rows
            ...items.map((it) {
              final packVal = it.unitPrice * it.quantity;
              return TableRow(
                children: [
                  _td(it.displayName, align: TextAlign.left, isBold: true),
                  _td(it.batchNumber ?? '02260'),
                  _td(it.expiryDate ?? '12-2028',
                      color: const Color(0xFFD97706)),
                  _td('${it.quantity.toInt()}'),
                  _td(
                      it.bonusQuantity > 0
                          ? '${it.bonusQuantity.toInt()}'
                          : '0',
                      color: const Color(0xFF059669)),
                  _td(it.unitPrice.toStringAsFixed(2)),
                  _td(packVal.toStringAsFixed(2)),
                  _td(
                    it.resolvedDiscountAmount > 0
                        ? (it.discountType == 'percentage' &&
                                it.discountValue > 0
                            ? '${it.resolvedDiscountAmount.toStringAsFixed(2)} (${it.discountValue.toStringAsFixed(it.discountValue == it.discountValue.roundToDouble() ? 0 : 1)}%)'
                            : it.resolvedDiscountAmount.toStringAsFixed(2))
                        : '0.00',
                  ),
                  _td(it.subtotal.toStringAsFixed(2), isBold: true),
                ],
              );
            }),
          ],
        ),

        // Subtotals & Tax Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.black),
              right: BorderSide(color: Colors.black),
              bottom: BorderSide(color: Colors.black),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.sale.taxAmount > 0
                      ? (widget.sale.taxBreakdownMap.isNotEmpty
                          ? 'Taxes (${widget.sale.taxBreakdownMap.entries.map((e) => '${e.key}: $currency${e.value.toStringAsFixed(2)}').join(' + ')}) = $currency${widget.sale.taxAmount.toStringAsFixed(2)}'
                          : (widget.settings.isPharmacy
                              ? 'Advance Tax Under Section(236H)= 0.50%    $currency${widget.sale.taxAmount.toStringAsFixed(2)}'
                              : 'Tax Amount: $currency${widget.sale.taxAmount.toStringAsFixed(2)}'))
                      : 'Tax: Exempt (0.00%)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  const Text('TOTAL : ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    '$currency${widget.sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Numbers of products & Rupees in words
        Row(
          children: [
            Text('Numbers of Products:  ${items.length}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Amount in Words: ${_numberToWords(widget.sale.totalAmount)}',
                style:
                    const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Customer Khata Ledger Box for Regular Account Customers
        if (!widget.sale.customerName.toLowerCase().contains('walk-in') &&
            !widget.sale.customerName.toLowerCase().contains('walk in') &&
            !widget.sale.customerName.toLowerCase().contains('walkin')) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: Colors.black, width: 1.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ledgerItem(
                  PosLocalization.tr('PREVIOUS BALANCE',
                      settings: widget.settings),
                  '$currency${(widget.customerPreviousBalance ?? 0.0).toStringAsFixed(2)}',
                ),
                _ledgerItem(
                  PosLocalization.tr('CURRENT INVOICE',
                      settings: widget.settings),
                  '$currency${widget.sale.totalAmount.toStringAsFixed(2)}',
                ),
                _ledgerItem(
                  PosLocalization.tr('RECEIVED TODAY',
                      settings: widget.settings),
                  '$currency${widget.sale.paidAmount.toStringAsFixed(2)}',
                ),
                _ledgerItem(
                  PosLocalization.tr('NET CLOSING KHATA',
                      settings: widget.settings),
                  '$currency${((widget.customerPreviousBalance ?? 0.0) + widget.sale.totalAmount - widget.sale.paidAmount).toStringAsFixed(2)}',
                  isBoldRed: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (widget.settings.isPharmacy) ...[
          // Legal Warranty Section (Form 2A Drug Act 1976)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'WARRANTY :-',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                SizedBox(height: 2),
                Text(
                  'FORM 2A (SEE RULES 19 & 30). WARRANTY UNDER SECTION 23(i) OF DRUG ACT, 1976.\n'
                  'I am being a resident of Pakistan carrying on business at Khuzdar. Do hereby give this warranty that the drug contained in this invoice, described as sold by us do not contravene in any way the provision of section 23 of the Drug Act, 1976.\n'
                  'Note: This Warranty does not apply to Unani, Homeopathic, Bio Chemic, System of Medicine, Herbal and General Item.',
                  style: TextStyle(
                      fontSize: 9, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Checked By _______________________',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Directionality(
                textDirection: PosLocalization.textDirection(
                    widget.settings.activePrimaryLanguage),
                child: Text(
                  PosLocalization.tr(
                    'Note: Report expiries with original bill.',
                    settings: widget.settings,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.settings.isSecondaryLanguageAllowed &&
                            !widget.settings.enableSecondaryLanguage
                        ? 10
                        : 11,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TERMS & CONDITIONS :-',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  '1. Goods once sold can be exchanged within 7 days upon presentation of original bill.\n'
                  '2. Altered, damaged, or clearance sale items are non-refundable.\n'
                  '3. Thank you for choosing ${widget.settings.businessName}!',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Authorized Signature: _______________________',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Text('Customer Receipt Copy',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF4F46E5))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _ledgerItem(String label, String value, {bool isBoldRed = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color:
                  isBoldRed ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _a4MetaField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF334155))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _th(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 9.5,
            color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _td(String text,
      {TextAlign align = TextAlign.center, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? const Color(0xFF1E293B),
        ),
      ),
    );
  }

  /// Builds Thermal Receipt (80mm / 58mm)
  Widget _buildThermalReceipt(String currency, bool is58mm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.settings.businessName.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: is58mm ? 16 : 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.settings.branchName,
          style: TextStyle(
              fontSize: is58mm ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569)),
        ),
        Text(
          widget.settings.address,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: is58mm ? 10 : 11, color: const Color(0xFF64748B)),
        ),
        if (widget.settings.phone.isNotEmpty)
          Text('Tel: ${widget.settings.phone}',
              style: TextStyle(
                  fontSize: is58mm ? 10 : 11, color: const Color(0xFF64748B))),
        const SizedBox(height: 12),
        _dottedDivider(),
        const SizedBox(height: 10),

        _metaRow('INVOICE NO:', widget.sale.invoiceNo),
        _metaRow('DATE & TIME:', widget.sale.createdAt),
        _metaRow('CUSTOMER:', widget.sale.customerName),
        _metaRow('PAY METHOD:', widget.sale.paymentMethod.toUpperCase()),
        const SizedBox(height: 10),
        _dottedDivider(),
        const SizedBox(height: 8),

        // Items List
        if (widget.sale.items != null)
          ...widget.sale.items!.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: TextStyle(
                              fontSize: is58mm ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        '$currency${item.subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: is58mm ? 11 : 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity.toInt()} x $currency${item.unitPrice.toStringAsFixed(2)}${item.bonusQuantity > 0 ? " (+${item.bonusQuantity.toInt()} Free)" : ""}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      if (item.batchNumber != null &&
                          item.batchNumber!.isNotEmpty)
                        Text(
                          'B:${item.batchNumber} Exp:${item.expiryDate ?? "-"}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFFD97706),
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  if (item.resolvedDiscountAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        'Item Disc: ${item.formatDiscountTag(currency)}',
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),
        _dottedDivider(),
        const SizedBox(height: 8),

        _calcRow(
            'Subtotal', '$currency${widget.sale.subtotal.toStringAsFixed(2)}'),
        if (widget.sale.discount > 0)
          _calcRow(widget.settings.isPharmacy ? 'Pack Discount' : 'Discount',
              '-$currency${widget.sale.discount.toStringAsFixed(2)}'),
        if (widget.sale.taxAmount > 0) ...[
          if (widget.sale.taxBreakdownMap.isNotEmpty) ...[
            for (final entry in widget.sale.taxBreakdownMap.entries)
              _calcRow(
                  entry.key, '+$currency${entry.value.toStringAsFixed(2)}'),
          ],
          _calcRow(
              widget.settings.isPharmacy ? 'Advance Tax (236H)' : 'Total Tax',
              '+$currency${widget.sale.taxAmount.toStringAsFixed(2)}'),
        ],

        const SizedBox(height: 6),
        _dottedDivider(),
        const SizedBox(height: 6),

        _calcRow('TOTAL PAYABLE',
            '$currency${widget.sale.totalAmount.toStringAsFixed(2)}',
            isBold: true),
        _calcRow('Amount Paid',
            '$currency${widget.sale.paidAmount.toStringAsFixed(2)}'),
        if (widget.sale.dueAmount > 0)
          _calcRow('Balance Due',
              '$currency${widget.sale.dueAmount.toStringAsFixed(2)}',
              isBold: true),

        if (widget.settings.isPharmacy) ...[
          const SizedBox(height: 14),
          Text(
            PosLocalization.tr('Note: Report expiries with original bill.',
                settings: widget.settings),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB91C1C)),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Text(
            PosLocalization.tr(
              'Thank you for shopping with us! Please retain this receipt for returns/exchange.',
              settings: widget.settings,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569)),
          ),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B))),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dottedDivider() {
    return Row(
      children: List.generate(
        35,
        (index) => Expanded(
          child: Container(
            color:
                index % 2 == 0 ? Colors.transparent : const Color(0xFFCBD5E1),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
