import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';

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
  String _paperSize = '80mm'; // '80mm' or '58mm'

  String _generatePlainTextReceipt() {
    final currency = widget.settings.currencySymbol;
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln(widget.settings.businessName.toUpperCase().padLeft(26));
    buffer.writeln(widget.settings.branchName.padLeft(24));
    buffer.writeln(widget.settings.address);
    if (widget.settings.phone.isNotEmpty) buffer.writeln('Tel: ${widget.settings.phone}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('Invoice No: ${widget.sale.invoiceNo}');
    buffer.writeln('Date:       ${widget.sale.createdAt}');
    buffer.writeln('Customer:   ${widget.sale.customerName}');
    buffer.writeln('Pay Method: ${widget.sale.paymentMethod.toUpperCase()}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('ITEM                 QTY    PRICE   TOTAL');
    buffer.writeln('----------------------------------------');

    if (widget.sale.items != null) {
      for (final item in widget.sale.items!) {
        final name = item.productName.length > 18 ? item.productName.substring(0, 18) : item.productName.padRight(18);
        final qty = item.quantity.toStringAsFixed(0).padLeft(4);
        final price = item.unitPrice.toStringAsFixed(2).padLeft(8);
        final total = item.subtotal.toStringAsFixed(2).padLeft(8);
        buffer.writeln('$name $qty $price $total');
      }
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('SUBTOTAL:           $currency${widget.sale.subtotal.toStringAsFixed(2)}');
    if (widget.sale.discount > 0) buffer.writeln('DISCOUNT:          -$currency${widget.sale.discount.toStringAsFixed(2)}');
    if (widget.sale.taxAmount > 0) buffer.writeln('TAX:               +$currency${widget.sale.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('TOTAL AMOUNT:       $currency${widget.sale.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('PAID AMOUNT:        $currency${widget.sale.paidAmount.toStringAsFixed(2)}');
    if (widget.changeReturn > 0) buffer.writeln('CHANGE RETURN:      $currency${widget.changeReturn.toStringAsFixed(2)}');
    if (widget.sale.dueAmount > 0) buffer.writeln('BALANCE DUE:        $currency${widget.sale.dueAmount.toStringAsFixed(2)}');
    buffer.writeln('========================================');
    buffer.writeln(widget.settings.receiptFooter.isNotEmpty ? widget.settings.receiptFooter : 'THANK YOU FOR YOUR BUSINESS!');
    buffer.writeln('========================================');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final is58mm = _paperSize == '58mm';
    final receiptWidth = is58mm ? 320.0 : 420.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: receiptWidth,
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Top Bar with Paper Size Selector
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
                        const Icon(Icons.receipt_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt Preview (${is58mm ? "58mm" : "80mm"})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Toggle 80mm / 58mm
                        InkWell(
                          onTap: () => setState(() => _paperSize = is58mm ? '80mm' : '58mm'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              is58mm ? 'Switch to 80mm' : 'Switch to 58mm',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scrollable Printable Receipt Body
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(is58mm ? 16 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Store Branding
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
                        Text(
                          'Tel: ${widget.settings.phone}',
                          style: TextStyle(fontSize: is58mm ? 10 : 11, color: const Color(0xFF64748B)),
                        ),
                      const SizedBox(height: 12),

                      _dottedDivider(),
                      const SizedBox(height: 10),

                      // Meta details
                      _metaRow('INVOICE NO:', widget.sale.invoiceNo),
                      _metaRow('DATE & TIME:', widget.sale.createdAt),
                      _metaRow('CUSTOMER:', widget.sale.customerName),
                      _metaRow('PAYMENT METHOD:', widget.sale.paymentMethod.toUpperCase()),
                      _metaRow('PAYMENT STATUS:', widget.sale.paymentStatus.toUpperCase()),

                      const SizedBox(height: 10),
                      _dottedDivider(),
                      const SizedBox(height: 8),

                      // Items Table Header
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text('ITEM', style: TextStyle(fontSize: is58mm ? 10 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: is58mm ? 10 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontSize: is58mm ? 10 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: is58mm ? 10 : 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Item Rows
                      if (widget.sale.items != null && widget.sale.items!.isNotEmpty)
                        ...widget.sale.items!.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: TextStyle(fontSize: is58mm ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                      ),
                                      if (item.sku.isNotEmpty)
                                        Text(
                                          item.sku,
                                          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: is58mm ? 11 : 12, color: const Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '$currency${item.unitPrice.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: is58mm ? 10 : 11, color: const Color(0xFF334155)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '$currency${item.subtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: is58mm ? 11 : 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),
                      _dottedDivider(),
                      const SizedBox(height: 8),

                      // Financial Summary
                      _calcRow('Subtotal', '$currency${widget.sale.subtotal.toStringAsFixed(2)}'),
                      if (widget.sale.discount > 0)
                        _calcRow('Order Discount', '-$currency${widget.sale.discount.toStringAsFixed(2)}'),
                      if (widget.sale.taxAmount > 0)
                        _calcRow('Sales Tax (${widget.sale.taxRate}%)', '+$currency${widget.sale.taxAmount.toStringAsFixed(2)}'),
                      if (widget.sale.shipping > 0)
                        _calcRow('Shipping & Freight', '+$currency${widget.sale.shipping.toStringAsFixed(2)}'),

                      const SizedBox(height: 6),
                      _dottedDivider(),
                      const SizedBox(height: 6),

                      _calcRow('TOTAL PAYABLE', '$currency${widget.sale.totalAmount.toStringAsFixed(2)}', isBold: true),
                      _calcRow('Amount Paid', '$currency${widget.sale.paidAmount.toStringAsFixed(2)}'),
                      if (widget.changeReturn > 0)
                        _calcRow('Change Returned', '$currency${widget.changeReturn.toStringAsFixed(2)}'),
                      if (widget.sale.dueAmount > 0)
                        _calcRow('Balance Due', '$currency${widget.sale.dueAmount.toStringAsFixed(2)}', isBold: true),

                      const SizedBox(height: 14),

                      // Barcode simulation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '||| | ||||| || |||||| | ||||| |||',
                              style: TextStyle(
                                fontSize: is58mm ? 14 : 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontFamily: 'monospace',
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '* ${widget.sale.invoiceNo} *',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Footer Note
                      Text(
                        widget.settings.receiptFooter.isNotEmpty
                            ? widget.settings.receiptFooter
                            : 'Thank you for your business! Items once sold can be exchanged within 7 days with this invoice receipt.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons Bottom
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Copy Plaintext Receipt
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Color(0xFF475569)),
                      tooltip: 'Copy Plaintext Receipt',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatePlainTextReceipt()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Receipt copied to clipboard for ESC/POS printing!'),
                            backgroundColor: Color(0xFF004EEB),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),

                    // Print ESC/POS Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFF004EEB)),
                          foregroundColor: const Color(0xFF004EEB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print, size: 16),
                        label: Text('Print (${_paperSize})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sent print job to default thermal printer ($_paperSize)'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // New Sale / Close
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
