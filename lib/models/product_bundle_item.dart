/// Composite / Bundle Product Bill of Materials (BOM) Item for Solar & Systems
class ProductBundleItem {
  final int? id;
  final int parentProductId;
  final int subProductId;
  final String subProductName;
  final String subSku;
  final double quantity;
  final double unitPrice;
  final bool isOptional;
  final int sortOrder;
  final String notes;

  ProductBundleItem({
    this.id,
    required this.parentProductId,
    required this.subProductId,
    required this.subProductName,
    this.subSku = '',
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    this.isOptional = false,
    this.sortOrder = 0,
    this.notes = '',
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'parent_product_id': parentProductId,
        'sub_product_id': subProductId,
        'sub_product_name': subProductName,
        'sub_sku': subSku,
        'quantity': quantity,
        'unit_price': unitPrice,
        'is_optional': isOptional ? 1 : 0,
        'sort_order': sortOrder,
        'notes': notes,
      };

  factory ProductBundleItem.fromMap(Map<String, dynamic> map) =>
      ProductBundleItem(
        id: map['id'] as int?,
        parentProductId: map['parent_product_id'] as int? ?? 0,
        subProductId: map['sub_product_id'] as int? ?? 0,
        subProductName: map['sub_product_name'] as String? ?? '',
        subSku: map['sub_sku'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        isOptional: (map['is_optional'] as int? ?? 0) == 1,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
        notes: map['notes'] as String? ?? '',
      );
}
