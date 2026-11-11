/// Line item representation for purchase bills and supplier orders.
class PurchaseItem {
  final int? productId;
  final String productName;
  final String sku;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;
  final String? batchNumber;
  final String? manufacturingDate;
  final String? expiryDate;

  const PurchaseItem({
    this.productId,
    required this.productName,
    this.sku = '',
    required this.quantity,
    required this.purchasePrice,
    this.sellingPrice = 0.0,
    this.batchNumber,
    this.manufacturingDate,
    this.expiryDate,
  });

  double get subtotal => quantity * purchasePrice;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'sku': sku,
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        if (batchNumber != null && batchNumber!.isNotEmpty)
          'batch_number': batchNumber,
        if (manufacturingDate != null && manufacturingDate!.isNotEmpty)
          'manufacturing_date': manufacturingDate,
        if (expiryDate != null && expiryDate!.isNotEmpty)
          'expiry_date': expiryDate,
        'subtotal': subtotal,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
        productId: map['product_id'] as int?,
        productName: map['product_name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ??
            (map['unit_cost'] as num?)?.toDouble() ??
            0.0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
        batchNumber: (map['batch_number'] ?? map['lot_number'])?.toString(),
        manufacturingDate: map['manufacturing_date']?.toString(),
        expiryDate: (map['expiry_date'] ?? map['exp_date'])?.toString(),
      );
}

