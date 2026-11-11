/// Product Variation for Variable Products (Smart POS `variations`)
class ProductVariation {
  final int? id;
  final int? productId;
  final String name; // e.g. "Small", "Medium", "Large" or "Red / XL"
  final String subSku;
  final double purchasePrice;
  final double sellingPrice;
  final double stockQuantity;

  ProductVariation({
    this.id,
    this.productId,
    required this.name,
    required this.subSku,
    required this.purchasePrice,
    required this.sellingPrice,
    this.stockQuantity = 0.0,
  });

  Map<String, dynamic> toMap(int? prodId) => {
        if (id != null) 'id': id,
        'product_id': prodId ?? productId,
        'name': name,
        'sub_sku': subSku,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'stock_quantity': stockQuantity,
      };

  factory ProductVariation.fromMap(Map<String, dynamic> map) =>
      ProductVariation(
        id: map['id'] as int?,
        productId: map['product_id'] as int?,
        name: map['name'] as String,
        subSku: map['sub_sku'] as String? ?? '',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
        sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      );
}
