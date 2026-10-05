import 'package:flutter/material.dart';
import '../../models/models.dart';

class ReceiptDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currency = settings.currencySymbol;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 750),
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
              // Dialog Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    const Row(
                      children: [
                        Icon(Icons.receipt_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Payment Receipt',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Scrollable Printable Receipt Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Store Branding
                      Text(
                        settings.businessName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.branchName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      Text(
                        settings.address,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Tel: ${settings.phone}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),

                      // Dotted Divider
                      _dottedDivider(),
                      const SizedBox(height: 8),

                      // Metadata Rows
                      _metaRow('INVOICE #', sale.invoiceNo),
                      _metaRow('DATE / TIME', sale.createdAt),
                      _metaRow('CASHIER', 'Admin Cashier'),
                      _metaRow('CUSTOMER', sale.customerName),
                      _metaRow('PAYMENT', sale.paymentMethod.toUpperCase()),
                      const SizedBox(height: 8),

                      _dottedDivider(),
                      const SizedBox(height: 8),

                      // Items Table Header
                      const Row(
                        children: [
                          Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 6),

                      // Item Rows
                      if (sale.items != null)
                        for (final item in sale.items!) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '$currency${item.unitPrice.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '$currency${item.subtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                      const SizedBox(height: 10),
                      _dottedDivider(),
                      const SizedBox(height: 8),

                      // Totals section
                      _calcRow('Subtotal', '$currency${sale.subtotal.toStringAsFixed(2)}'),
                      if (sale.discount > 0) _calcRow('Order Discount', '-$currency${sale.discount.toStringAsFixed(2)}'),
                      if (sale.taxAmount > 0) _calcRow('Tax (${sale.taxRate}%)', '+$currency${sale.taxAmount.toStringAsFixed(2)}'),
                      if (sale.shipping > 0) _calcRow('Shipping', '+$currency${sale.shipping.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      const Divider(height: 1, thickness: 1.5, color: Color(0xFF0F172A)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL AMOUNT',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '$currency${sale.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _dottedDivider(),
                      const SizedBox(height: 8),

                      _calcRow('Amount Paid', '$currency${sale.paidAmount.toStringAsFixed(2)}'),
                      if (tenderedAmount > 0) _calcRow('Tendered', '$currency${tenderedAmount.toStringAsFixed(2)}'),
                      if (changeReturn > 0) _calcRow('Change Return', '$currency${changeReturn.toStringAsFixed(2)}', isBold: true),
                      if (sale.dueAmount > 0) _calcRow('Balance Due', '$currency${sale.dueAmount.toStringAsFixed(2)}', isBold: true),

                      const SizedBox(height: 18),

                      // Simulated Barcode
                      Container(
                        height: 36,
                        width: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            40,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.2),
                              width: (index % 3 == 0 || index % 5 == 0) ? 2.5 : 1.2,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.invoiceNo,
                        style: const TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),

                      // Footer Note
                      Text(
                        settings.receiptFooter,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Controls
              Container(
                padding: const EdgeInsets.all(16),
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
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF004EEB)),
                          foregroundColor: const Color(0xFF004EEB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sent print job to default thermal printer (80mm)'),
                              backgroundColor: Color(0xFF10B981),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.bold)),
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
