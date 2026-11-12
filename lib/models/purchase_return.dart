import 'dart:convert';

/// Purchase Return Model
class PurchaseReturn {
  final int? id;
  final String returnNo;
  final int? purchaseId;
  final String purchaseRef;
  final int? supplierId;
  final String supplierName;
  final String date;
  final double totalAmount;
  final double refundAmount;
  final String status;
  final String reason;
  final String note;
  final List<PurchaseReturnItem> items;

  PurchaseReturn({
    this.id,
    required this.returnNo,
    this.purchaseId,
    required this.purchaseRef,
    this.supplierId,
    required this.supplierName,
    required this.date,
    required this.totalAmount,
    required this.refundAmount,
    this.status = 'completed',
    this.reason = 'Near Expiry / Damaged',
    this.note = '',
    this.items = const [],
  });

  String get refNo => returnNo;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'ref_no': returnNo,
        'purchase_id': purchaseId ?? 0,
        'purchase_ref': purchaseRef,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'date': date,
        'total_amount': totalAmount,
        'refund_amount': refundAmount,
        'refund_method': 'cash',
        'status': status,
        'reason': reason,
        'note': note,
        'items_json': jsonEncode(items.map((i) => i.toMap()).toList()),
      };

  factory PurchaseReturn.fromMap(Map<String, dynamic> map,
          {List<PurchaseReturnItem> items = const []}) =>
      PurchaseReturn(
        id: map['id'] as int?,
        returnNo: (map['return_no'] ?? map['ref_no']) as String? ?? '',
        purchaseId: map['purchase_id'] as int?,
        purchaseRef: map['purchase_ref'] as String? ?? '',
        supplierId: map['supplier_id'] as int?,
        supplierName: map['supplier_name'] as String? ?? '',
        date: map['date'] as String? ?? '',
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        refundAmount: (map['refund_amount'] as num?)?.toDouble() ?? 0.0,
        status: map['status'] as String? ?? 'completed',
        reason: map['reason'] as String? ?? '',
        note: map['note'] as String? ?? '',
        items: items,
      );
}

class PurchaseReturnItem {
  final int? id;
  final int returnId;
  final int productId;
  final String productName;
  final String sku;
  final String batchNumber;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  PurchaseReturnItem({
    this.id,
    required this.returnId,
    required this.productId,
    required this.productName,
    this.sku = '',
    this.batchNumber = '',
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'return_id': returnId,
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'batch_number': batchNumber,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };

  factory PurchaseReturnItem.fromMap(Map<String, dynamic> map) =>
      PurchaseReturnItem(
        id: map['id'] as int?,
        returnId: map['return_id'] as int? ?? 0,
        productId: map['product_id'] as int? ?? 0,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        batchNumber: map['batch_number'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      );
}
