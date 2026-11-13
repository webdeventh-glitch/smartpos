/// Sale item record in SQLite
class SaleItem {
  final int? id;
  final int saleId;
  final int? productId;
  final int? variationId;
  final String? variationName;
  final String productName;
  final String sku;
  final double unitPrice;
  final double quantity;
  final double fulfilledQuantity;
  final double discount;
  final double subtotal;
  final String? batchNumber;
  final String? expiryDate;
  final double bonusQuantity;
  final double packDiscount;
  final String? unitName;
  final double unitMultiplier;
  final String discountType; // 'fixed' or 'percentage'
  final double discountValue;
  final double taxAmount;
  final String? taxName;

  SaleItem({
    this.id,
    required this.saleId,
    this.productId,
    this.variationId,
    this.variationName,
    required this.productName,
    required this.sku,
    required this.unitPrice,
    required this.quantity,
    this.fulfilledQuantity = 0.0,
    this.discount = 0.0,
    required this.subtotal,
    this.batchNumber,
    this.expiryDate,
    this.bonusQuantity = 0.0,
    this.packDiscount = 0.0,
    this.unitName,
    this.unitMultiplier = 1.0,
    this.discountType = 'fixed',
    double? discountValue,
    this.taxAmount = 0.0,
    this.taxName,
  }) : discountValue =
            discountValue ?? (packDiscount > 0 ? packDiscount : discount);

  String get displayName =>
      (variationName != null && variationName!.trim().isNotEmpty)
          ? '$productName ($variationName)'
          : productName;

  double get packValue => unitPrice * quantity;
  double get remainingQuantity =>
      (quantity - fulfilledQuantity).clamp(0.0, double.infinity);

  double get resolvedDiscountAmount {
    if (discount > 0) return discount;
    if (discountType == 'percentage') {
      final pct = discountValue > 0 ? discountValue : packDiscount;
      return (packValue * pct / 100.0).clamp(0.0, packValue);
    }
    return discountValue.clamp(0.0, packValue);
  }

  String formatDiscountTag(String currency) {
    final amt = resolvedDiscountAmount;
    if (amt <= 0) return '';
    if (discountType == 'percentage') {
      final pct = discountValue > 0 ? discountValue : packDiscount;
      if (pct > 0) {
        final pctStr = pct == pct.roundToDouble()
            ? pct.toStringAsFixed(0)
            : pct.toStringAsFixed(1);
        return '-$pctStr% (-$currency${amt.toStringAsFixed(2)})';
      }
    }
    return '-$currency${amt.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sale_id': saleId,
        'product_id': productId,
        'variation_id': variationId,
        'variation_name': variationName ?? '',
        'product_name': productName,
        'sku': sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'fulfilled_quantity': fulfilledQuantity,
        'discount': discount,
        'subtotal': subtotal,
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
        'unit_name': unitName,
        'unit_multiplier': unitMultiplier,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_amount': taxAmount,
        'tax_name': taxName ?? '',
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    final discAmt = (map['discount'] as num?)?.toDouble() ?? 0.0;
    final packDisc = (map['pack_discount'] as num?)?.toDouble() ?? 0.0;
    final rawType = map['discount_type'] as String?;
    final resolvedType = (rawType != null && rawType.isNotEmpty)
        ? rawType
        : (packDisc > 0 ? 'percentage' : 'fixed');
    final resolvedVal = (map['discount_value'] as num?)?.toDouble() ??
        (resolvedType == 'percentage' ? packDisc : discAmt);
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int?,
      variationId: map['variation_id'] as int?,
      variationName: (map['variation_name'] as String?)?.isNotEmpty == true
          ? map['variation_name'] as String
          : null,
      productName: map['product_name'] as String,
      sku: map['sku'] as String? ?? '',
      unitPrice: (map['unit_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      fulfilledQuantity: (map['fulfilled_quantity'] as num?)?.toDouble() ?? 0.0,
      discount: discAmt,
      subtotal: (map['subtotal'] as num).toDouble(),
      batchNumber: map['batch_number'] as String?,
      expiryDate: map['expiry_date'] as String?,
      bonusQuantity: (map['bonus_quantity'] as num?)?.toDouble() ?? 0.0,
      packDiscount: packDisc,
      unitName: map['unit_name'] as String?,
      unitMultiplier: (map['unit_multiplier'] as num?)?.toDouble() ?? 1.0,
      discountType: resolvedType,
      discountValue: resolvedVal,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      taxName: map['tax_name'] as String?,
    );
  }
}
