import 'dart:convert';

/// Sales Return Model
class SaleReturn {
  final int? id;
  final String returnNo;
  final int? saleId;
  final String invoiceNo;
  final int? customerId;
  final String customerName;
  final String date;
  final double totalAmount;
  final double refundAmount;
  final String refundStatus; // 'completed', 'pending'
  final String paymentMethod; // 'cash', 'credit_note', 'bank'
  final String reason;
  final String note;
  final String createdBy;
  final List<SaleReturnItem> items;

  SaleReturn({
    this.id,
    required this.returnNo,
    this.saleId,
    required this.invoiceNo,
    this.customerId,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.refundAmount,
    this.refundStatus = 'completed',
    this.paymentMethod = 'cash',
    this.reason = 'Customer Return',
    this.note = '',
    this.createdBy = 'Admin',
    this.items = const [],
  });

  String get refNo => returnNo;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': returnNo,
        'sale_id': saleId ?? 0,
        'invoice_no': invoiceNo,
        'customer_id': customerId,
        'customer_name': customerName,
        'date': date,
        'total_amount': totalAmount,
        'refund_amount': refundAmount,
        'status': refundStatus,
        'refund_method': paymentMethod,
        'reason': reason,
        'note': note,
        'created_by': createdBy,
        'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      };

  factory SaleReturn.fromMap(Map<String, dynamic> map,
          {List<SaleReturnItem> items = const []}) =>
      SaleReturn(
        id: map['id'] as int?,
        returnNo: (map['return_no'] ?? map['ref_no']) as String? ?? '',
        saleId: map['sale_id'] as int?,
        invoiceNo: map['invoice_no'] as String? ?? '',
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0.0,
        refundStatus:
            (map['refund_status'] ?? map['status']) as String? ?? 'completed',
        paymentMethod:
            (map['payment_method'] ?? map['refund_method']) as String? ??
                'cash',
        reason: map['reason'] as String? ?? '',
        note: map['note'] as String? ?? '',
        createdBy: map['created_by'] as String? ?? 'Admin',
        items: items,
      );
}

class SaleReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final int? variationId;
  final String? variationName;
  final String productName;
  final String sku;
  final String batchNumber;
  final double quantity;
  final double unitMultiplier;
  final double unitPrice;
  final double subtotal;
  final bool isDamaged;
  final String destination; // 'active' or 'damaged'

  SaleReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    this.variationId,
    this.variationName,
    required this.productName,
    this.sku = '',
    this.batchNumber = '',
    required this.quantity,
    this.unitMultiplier = 1.0,
    required this.unitPrice,
    required this.subtotal,
    this.isDamaged = false,
    this.destination = 'active',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_id': returnId,
        'product_id': productId,
        if (variationId != null) 'variation_id': variationId,
        if (variationName != null && variationName!.isNotEmpty)
          'variation_name': variationName,
        'product_name': productName,
        'sku': sku,
        'batch_number': batchNumber,
        'quantity': quantity,
        'unit_multiplier': unitMultiplier,
        'unit_price': unitPrice,
        'subtotal': subtotal,
        'is_damaged': isDamaged ? 1 : 0,
        'destination': destination,
      };

  factory SaleReturnItem.fromMap(Map<String, dynamic> map) => SaleReturnItem(
        id: map['id'] as int?,
        returnId: map['return_id'] as int? ?? 0,
        productId: map['product_id'] as int? ?? 0,
        variationId: map['variation_id'] as int?,
        variationName: (map['variation_name'] as String?)?.isNotEmpty == true
            ? map['variation_name'] as String
            : null,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unitMultiplier: (map['unit_multiplier'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
        isDamaged: (map['is_damaged'] == 1 || map['is_damaged'] == true),
        destination: map['destination'] as String? ??
            ((map['is_damaged'] == 1 || map['is_damaged'] == true)
                ? 'damaged'
                : 'active'),
      );
}
