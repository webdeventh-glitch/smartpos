import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';

class PurchaseReceiptDialog extends StatefulWidget {
  final Purchase purchase;
  final BusinessSettings settings;

  const PurchaseReceiptDialog({
    super.key,
    required this.purchase,
    required this.settings,
  });

  @override
  State<PurchaseReceiptDialog> createState() => _PurchaseReceiptDialogState();
}

class _PurchaseReceiptDialogState extends State<PurchaseReceiptDialog> {
  String _paperSize = 'A4 Sheet'; // 'A4 Sheet', '80mm Thermal'

  String _generatePlainText() {
    final currency = widget.settings.currencySymbol;
    final p = widget.purchase;
    final items = p.getItems();
    final buffer = StringBuffer();

    buffer.writeln('========================================================================');
    buffer.writeln('                     PURCHASE VOUCHER / GOODS RECEIPT                   ');
    buffer.writeln(widget.settings.businessName.toUpperCase());
    buffer.writeln('Branch: ${p.locationName}');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('PO NUMBER:   ${p.refNo}           DATE: ${p.createdAt}');
    buffer.writeln('SUPPLIER:    ${p.supplierName}');
    buffer.writeln('STATUS:      ${p.status.toUpperCase()}      PAYMENT: ${p.paymentStatus.toUpperCase()}');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('ITEM DESCRIPTION                     QTY       UNIT COST       SUBTOTAL');
    buffer.writeln('------------------------------------------------------------------------');

    for (final item in items) {
      final name = (item['product_name'] ?? 'Product').toString();
      final pName = name.length > 32 ? name.substring(0, 32) : name.padRight(32);
      final qty = ((item['quantity'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(1).padLeft(8);
      final cost = '$currency${((item['purchase_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'.padLeft(14);
      final sub = '$currency${((item['subtotal'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'.padLeft(14);
      buffer.writeln('$pName $qty $cost $sub');
    }

    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('TOTAL PURCHASE AMOUNT:    $currency${p.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('AMOUNT PAID TO SUPPLIER:  $currency${p.paidAmount.toStringAsFixed(2)}');
    if (p.dueAmount > 0) {
      buffer.writeln('PAYABLE BALANCE DUE:      $currency${p.dueAmount.toStringAsFixed(2)}');
    }
    if (p.note.isNotEmpty) {
      buffer.writeln('NOTES: ${p.note}');
    }
    buffer.writeln('========================================================================');
    buffer.writeln('Authorized Store Receiving Officer: ___________________');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final p = widget.purchase;
    final items = p.getItems();
    final isA4 = _paperSize == 'A4 Sheet';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Container(
          width: isA4 ? 760 : 420,
          constraints: const BoxConstraints(maxHeight: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
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
              // Top control header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'Purchase Order & Goods Receipt',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    // Format selector
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          _formatBtn('A4 Sheet'),
                          _formatBtn('80mm Thermal'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Preview body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Banner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.settings.businessName.toUpperCase(),
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'INWARD STOCK RECEIPT / PURCHASE VOUCHER',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.5),
                                ),
                                Text(
                                  'Receiving Location: ${p.locationName}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p.refNo,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF166534)),
                                  ),
                                  Text(
                                    'Status: ${p.status.toUpperCase()}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFCBD5E1), thickness: 1),
                        const SizedBox(height: 12),

                        // Supplier & Date Info Grid
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SUPPLIER / VENDOR:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(p.supplierName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PURCHASE DATE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(p.createdAt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PAYMENT STATUS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.paymentStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: p.paymentStatus == 'paid' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Purchased Line Items Table
                        Table(
                          border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 1),
                          columnWidths: const {
                            0: FlexColumnWidth(4),
                            1: FlexColumnWidth(1.5),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: [
                                Padding(padding: EdgeInsets.all(8), child: Text('Product Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Qty Recv', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Cost Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                Padding(padding: EdgeInsets.all(8), child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                            ),
                            if (items.isNotEmpty)
                              ...items.map((item) {
                                final name = (item['product_name'] ?? 'Product').toString();
                                final qty = ((item['quantity'] as num?)?.toDouble() ?? 1.0).toStringAsFixed(1);
                                final cost = ((item['purchase_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                                final sub = ((item['subtotal'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                                return TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(8), child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                    Padding(padding: const EdgeInsets.all(8), child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('$currency$cost', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('$currency$sub', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                );
                              })
                            else
                              TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(8), child: Text('Standard Restock Shipment', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                  const Padding(padding: EdgeInsets.all(8), child: Text('1.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text('$currency${p.totalAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                  Padding(padding: const EdgeInsets.all(8), child: Text('$currency${p.totalAmount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Totals Summary
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 280,
                            child: Column(
                              children: [
                                _sumRow('Total Purchase Amount:', '$currency${p.totalAmount.toStringAsFixed(2)}', isBold: true),
                                const Divider(height: 12),
                                _sumRow('Paid to Supplier:', '$currency${p.paidAmount.toStringAsFixed(2)}', color: const Color(0xFF16A34A)),
                                if (p.dueAmount > 0) ...[
                                  const Divider(height: 12),
                                  _sumRow('Payable Balance Due:', '$currency${p.dueAmount.toStringAsFixed(2)}', isBold: true, color: const Color(0xFFDC2626)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (p.note.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text('Remarks / Note: ${p.note}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Receiving Officer Signature
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 30),
                                SizedBox(width: 180, child: Divider(color: Colors.black87, thickness: 1)),
                                Text('Receiving Store Officer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(height: 30),
                                SizedBox(width: 180, child: Divider(color: Colors.black87, thickness: 1)),
                                Text('Supplier Delivery Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Print Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatePlainText()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Purchase Receipt text copied to clipboard!'), backgroundColor: Color(0xFF10B981)),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Voucher Text'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0038B8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sent ${p.refNo} to thermal/A4 printer successfully!'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Purchase Voucher'),
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

  Widget _formatBtn(String title) {
    final active = _paperSize == title;
    return InkWell(
      onTap: () => setState(() => _paperSize = title),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF004EEB) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _sumRow(String label, String val, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF475569))),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? const Color(0xFF0F172A))),
      ],
    );
  }
}
