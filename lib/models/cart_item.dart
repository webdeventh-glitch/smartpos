import 'product.dart';
import 'sale_item.dart';

/// Single item in POS Cart / Sale Invoice
class CartItem {
  final Product product;
  final int? variationId;
  final String? variationName;
  double quantity;
  double unitPrice;
  double discount; // amount in currency
  String? batchNumber;
  String? expiryDate;
  double bonusQuantity;
  double packDiscount; // percentage or fixed
  String? selectedUnitName;
  double unitMultiplier;
  final double basePrice;
  String discountType; // 'fixed' or 'percentage'
  double discountValue;
  double taxAmount;
  String? taxName;

  CartItem({
    required this.product,
    this.variationId,
    this.variationName,
    double? basePrice,
    this.quantity = 1.0,
    required this.unitPrice,
    this.discount = 0.0,
    this.batchNumber,
    this.expiryDate,
    this.bonusQuantity = 0.0,
    this.packDiscount = 0.0,
    this.selectedUnitName,
    this.unitMultiplier = 1.0,
    String? discountType,
    double? discountValue,
    this.taxAmount = 0.0,
    this.taxName,
  })  : basePrice = basePrice ?? product.sellingPrice,
        discountType =
            discountType ?? (packDiscount > 0 ? 'percentage' : 'fixed'),
        discountValue =
            discountValue ?? (packDiscount > 0 ? packDiscount : discount) {
    batchNumber ??= product.batchNumber;
    expiryDate ??= product.expiryDate;
    selectedUnitName ??= product.unit;
    if (this.discountType == 'percentage' &&
        this.discountValue > 0 &&
        packDiscount == 0) {
      packDiscount = this.discountValue;
    } else if (this.discountType == 'fixed' &&
        this.discountValue > 0 &&
        discount == 0) {
      discount = this.discountValue;
    }
  }

  void setItemDiscount(String type, double value) {
    final sanitized = value < 0.0 ? 0.0 : value;
    discountType = type == 'percentage' ? 'percentage' : 'fixed';
    discountValue = sanitized;
    if (discountType == 'percentage') {
      packDiscount = sanitized;
      discount = 0.0;
    } else {
      discount = sanitized;
      packDiscount = 0.0;
    }
  }

  void changeUnit(String newUnitName, double multiplier) {
    selectedUnitName = newUnitName;
    unitMultiplier = multiplier > 0 ? multiplier : 1.0;
    unitPrice = basePrice * unitMultiplier;
  }

  String get displayName =>
      (variationName != null && variationName!.trim().isNotEmpty)
          ? '${product.name} ($variationName)'
          : product.name;

  double get subtotal =>
      (packValue - calculatedDiscount).clamp(0.0, double.infinity);

  double get packValue => unitPrice * quantity;

  double get calculatedDiscount {
    final pct = discountType == 'percentage'
        ? (discountValue > 0 ? discountValue : packDiscount)
        : packDiscount;
    final fixedAmt = discountType == 'fixed'
        ? (discountValue > 0 ? discountValue : discount)
        : discount;
    final total = (pct > 0 ? (packValue * pct) / 100.0 : 0.0) + fixedAmt;
    return total.clamp(0.0, packValue);
  }

  Map<String, dynamic> toMap(int saleId) => {
        'sale_id': saleId,
        'product_id': product.id,
        'variation_id': variationId,
        'variation_name': variationName ?? '',
        'product_name': product.name,
        'sku': product.sku,
        'unit_price': unitPrice,
        'quantity': quantity,
        'discount': calculatedDiscount,
        'subtotal': subtotal,
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
        'unit_name': selectedUnitName ?? product.unit,
        'unit_multiplier': unitMultiplier,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_amount': taxAmount,
        'tax_name': taxName ?? '',
      };

  Map<String, dynamic> toSavedStateMap() => {
        'product': product.toMap(),
        'variation_id': variationId,
        'variation_name': variationName ?? '',
        'base_price': basePrice,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount': discount,
        'batch_number': batchNumber ?? '',
        'expiry_date': expiryDate ?? '',
        'bonus_quantity': bonusQuantity,
        'pack_discount': packDiscount,
        'selected_unit_name': selectedUnitName,
        'unit_multiplier': unitMultiplier,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_amount': taxAmount,
        'tax_name': taxName ?? '',
      };

  factory CartItem.fromSavedStateMap(Map<String, dynamic> map) => CartItem(
        product: Product.fromMap(map['product'] as Map<String, dynamic>),
        variationId: map['variation_id'] as int?,
        variationName: (map['variation_name'] as String?)?.isNotEmpty == true
            ? map['variation_name'] as String
            : null,
        basePrice: (map['base_price'] as num?)?.toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
        batchNumber: map['batch_number'] as String?,
        expiryDate: map['expiry_date'] as String?,
        bonusQuantity: (map['bonus_quantity'] as num?)?.toDouble() ?? 0.0,
        packDiscount: (map['pack_discount'] as num?)?.toDouble() ?? 0.0,
        selectedUnitName: map['selected_unit_name'] as String?,
        unitMultiplier: (map['unit_multiplier'] as num?)?.toDouble() ?? 1.0,
        discountType: map['discount_type'] as String?,
        discountValue: (map['discount_value'] as num?)?.toDouble(),
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
        taxName: map['tax_name'] as String?,
      );

  CartItem clone() => CartItem(
        product: product,
        variationId: variationId,
        variationName: variationName,
        basePrice: basePrice,
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        bonusQuantity: bonusQuantity,
        packDiscount: packDiscount,
        selectedUnitName: selectedUnitName,
        unitMultiplier: unitMultiplier,
        discountType: discountType,
        discountValue: discountValue,
        taxAmount: taxAmount,
        taxName: taxName,
      );

  factory CartItem.fromSaleItem(SaleItem item, [Product? product]) {
    final prod = product ??
        Product(
          id: item.productId,
          name: item.productName,
          sku: item.sku,
          barcode: item.sku,
          sellingPrice: item.unitPrice,
          purchasePrice: 0.0,
          stockQuantity: 999.0,
          unit: item.unitName ?? 'Pc',
          batchNumber: item.batchNumber,
          expiryDate: item.expiryDate,
        );
    return CartItem(
      product: prod,
      variationId: item.variationId,
      variationName: item.variationName,
      basePrice: item.unitPrice,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      discount: item.discountType == 'fixed' ? item.discount : 0.0,
      batchNumber: item.batchNumber,
      expiryDate: item.expiryDate,
      bonusQuantity: item.bonusQuantity,
      packDiscount: item.packDiscount,
      selectedUnitName: item.unitName,
      unitMultiplier: item.unitMultiplier > 0 ? item.unitMultiplier : 1.0,
      discountType: item.discountType,
      discountValue: item.discountValue,
      taxAmount: item.taxAmount,
      taxName: item.taxName,
    );
  }
}
