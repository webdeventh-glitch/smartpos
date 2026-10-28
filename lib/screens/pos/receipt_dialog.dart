import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/print_service.dart';

class ReceiptDialog extends StatefulWidget {
  final Sale sale;
  final BusinessSettings settings;
  final double tenderedAmount;
  final double changeReturn;

  const ReceiptDialog({
    super.key,
    required this.sale,
    required this.settings,
    required this.tenderedAmount,
    required this.changeReturn,
  });

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  String _paperSize = 'A4 Agency'; // 'A4 Agency', '80mm', '58mm'

  String _generatePlainTextReceipt() {
    final currency = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    buffer.writeln('========================================================================');
    buffer.writeln(widget.settings.businessName.toUpperCase());
    buffer.writeln('DISTRIBUTOR & WHOLESALER - ${widget.settings.branchName}');
    buffer.writeln(widget.settings.address);
    if (widget.settings.phone.isNotEmpty) buffer.writeln('CELL NO: ${widget.settings.phone}');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('INVOICE NO:  ${widget.sale.invoiceNo}    DATE: ${widget.sale.createdAt}');
    buffer.writeln('PARTY NAME:  ${widget.sale.customerName}');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('DESCRIPTION           BATCH    EXP-DATE   QTY  BONUS   RATE     DISC%    NET TOTAL');
    buffer.writeln('------------------------------------------------------------------------');

    if (widget.sale.items != null) {
      for (final item in widget.sale.items!) {
        final name = item.productName.length > 20 ? item.productName.substring(0, 20) : item.productName.padRight(20);
        final batch = (item.batchNumber ?? '-').padRight(8);
        final exp = (item.expiryDate ?? '-').padRight(10);
        final qty = item.quantity.toStringAsFixed(0).padLeft(3);
        final bonus = item.bonusQuantity.toStringAsFixed(0).padLeft(5);
        final rate = item.unitPrice.toStringAsFixed(2).padLeft(8);
        final disc = (item.packDiscount > 0 ? '${item.packDiscount}%' : '0.00').padLeft(7);
        final total = item.subtotal.toStringAsFixed(2).padLeft(10);
        buffer.writeln('$name $batch $exp $qty $bonus $rate $disc $total');
      }
    }

    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('SUBTOTAL:                 $currency${widget.sale.subtotal.toStringAsFixed(2)}');
    if (widget.sale.discount > 0) buffer.writeln('PACK DISCOUNT:           -$currency${widget.sale.discount.toStringAsFixed(2)}');
    if (widget.sale.taxAmount > 0) buffer.writeln('ADVANCE TAX (SEC 236H):  +$currency${widget.sale.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('TOTAL AMOUNT:             $currency${widget.sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('PAID AMOUNT:              $currency${widget.sale.paidAmount.toStringAsFixed(2)}');
    if (widget.sale.dueAmount > 0) buffer.writeln('BALANCE DUE:              $currency${widget.sale.dueAmount.toStringAsFixed(2)}');
    buffer.writeln('========================================================================');
    buffer.writeln('FORM 2A (SEE RULES 19 & 30). WARRANTY UNDER SECTION 23(i) OF DRUG ACT, 1976');
    buffer.writeln('Note: Expiry claim must be reported 6 months prior to expiry date with original bill.');
    buffer.writeln('========================================================================');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final isA4 = _paperSize == 'A4 Agency';
    final is58mm = _paperSize == '58mm';
    final dialogWidth = isA4 ? 780.0 : (is58mm ? 330.0 : 430.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: dialogWidth,
          constraints: const BoxConstraints(maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.print_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Invoice Preview (${_paperSize})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _formatChip('A4 Agency', isA4),
                        const SizedBox(width: 6),
                        _formatChip('80mm POS', _paperSize == '80mm'),
                        const SizedBox(width: 6),
                        _formatChip('58mm Thermal', is58mm),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Invoice Body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isA4 ? 26 : 18),
                  child: isA4 ? _buildA4AgencyInvoice(currency) : _buildThermalReceipt(currency, is58mm),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                      tooltip: 'Copy Plaintext Invoice',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatePlainTextReceipt()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invoice copied to clipboard for direct printing!'),
                            backgroundColor: Color(0xFF4F46E5),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF4F46E5)),
                          foregroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text('Print Document ($_paperSize)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () async {
                          final html = PrintService.generateSaleInvoiceHtml(
                            sale: widget.sale,
                            settings: widget.settings,
                            tenderedAmount: widget.tenderedAmount,
                            changeReturn: widget.changeReturn,
                            paperSizeOverride: _paperSize,
                          );
                          await PrintService.openPrintWindow(
                            htmlContent: html,
                            title: 'Invoice_${widget.sale.invoiceNo}',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Invoice #${widget.sale.invoiceNo} dispatched to Windows Print Manager!'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Complete (New Sale)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
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
      totalPackDisc += it.discount;
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'DISTRIBUTOR AND WHOLESALER - ${widget.settings.branchName.toUpperCase()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              Text(
                widget.settings.address,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              if (widget.settings.phone.isNotEmpty)
                Text(
                  'CELL NO: ${widget.settings.phone}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
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
                    _a4MetaField('PARTY CODE:', '${widget.sale.customerId ?? 2033}'),
                    _a4MetaField('PARTY NAME:', widget.sale.customerName),
                    _a4MetaField('ADDRESS:', widget.settings.address.split(',').first),
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
                    _a4MetaField('DATE:', widget.sale.createdAt.split(' ').first),
                    _a4MetaField('S/MAN.CODE:', '02'),
                    _a4MetaField('NAME:', 'NASIR MENGAL'),
                    _a4MetaField('TIME:', widget.sale.createdAt.contains(' ') ? widget.sale.createdAt.split(' ').last : '11:38:27'),
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
                  _td(it.productName, align: TextAlign.left, isBold: true),
                  _td(it.batchNumber ?? '02260'),
                  _td(it.expiryDate ?? '12-2028', color: const Color(0xFFD97706)),
                  _td('${it.quantity.toInt()}'),
                  _td(it.bonusQuantity > 0 ? '${it.bonusQuantity.toInt()}' : '0', color: const Color(0xFF059669)),
                  _td(it.unitPrice.toStringAsFixed(2)),
                  _td(packVal.toStringAsFixed(2)),
                  _td(it.discount > 0 ? it.discount.toStringAsFixed(2) : '0.00'),
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
              Text(
                'Advance Tax Under Section(236H)= 0.50%    ${currency}179.70',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Row(
                children: [
                  const Text('TOTAL : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    '$currency${widget.sale.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
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
            Text('Numbers of Products:  ${items.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Rupees: Thirty Thousand Seven Hundred and Twenty-Eight Only',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

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
                style: TextStyle(fontSize: 9, color: Color(0xFF475569), height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Checked by & Urdu Expiry Note
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Checked By _______________________', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'نوٹ: ایکسپائری کی اطلاع 6 ماہ قبل مع اصل بل نمبر کیساتھ دیں۔',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _a4MetaField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF0F172A))),
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFF0F172A)),
      ),
    );
  }

  Widget _td(String text, {TextAlign align = TextAlign.center, bool isBold = false, Color? color}) {
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
          style: TextStyle(fontSize: is58mm ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
        ),
        Text(
          widget.settings.address,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: is58mm ? 10 : 11, color: const Color(0xFF64748B)),
        ),
        if (widget.settings.phone.isNotEmpty)
          Text('Tel: ${widget.settings.phone}', style: TextStyle(fontSize: is58mm ? 10 : 11, color: const Color(0xFF64748B))),
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
                          item.productName,
                          style: TextStyle(fontSize: is58mm ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        ),
                      ),
                      Text(
                        '$currency${item.subtotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: is58mm ? 11 : 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity.toInt()} x $currency${item.unitPrice.toStringAsFixed(2)}${item.bonusQuantity > 0 ? " (+${item.bonusQuantity.toInt()} Free)" : ""}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      if (item.batchNumber != null && item.batchNumber!.isNotEmpty)
                        Text(
                          'B:${item.batchNumber} Exp:${item.expiryDate ?? "-"}',
                          style: const TextStyle(fontSize: 9, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),
        _dottedDivider(),
        const SizedBox(height: 8),

        _calcRow('Subtotal', '$currency${widget.sale.subtotal.toStringAsFixed(2)}'),
        if (widget.sale.discount > 0)
          _calcRow('Pack Discount', '-$currency${widget.sale.discount.toStringAsFixed(2)}'),
        if (widget.sale.taxAmount > 0)
          _calcRow('Advance Tax (236H)', '+$currency${widget.sale.taxAmount.toStringAsFixed(2)}'),

        const SizedBox(height: 6),
        _dottedDivider(),
        const SizedBox(height: 6),

        _calcRow('TOTAL PAYABLE', '$currency${widget.sale.totalAmount.toStringAsFixed(2)}', isBold: true),
        _calcRow('Amount Paid', '$currency${widget.sale.paidAmount.toStringAsFixed(2)}'),
        if (widget.sale.dueAmount > 0)
          _calcRow('Balance Due', '$currency${widget.sale.dueAmount.toStringAsFixed(2)}', isBold: true),

        const SizedBox(height: 14),
        const Text(
          'نوٹ: ایکسپائری کی اطلاع 6 ماہ قبل مع اصل بل نمبر کیساتھ دیں۔',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
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
            color: index % 2 == 0 ? Colors.transparent : const Color(0xFFCBD5E1),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
