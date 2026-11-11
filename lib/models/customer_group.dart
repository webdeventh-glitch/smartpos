/// Customer Group model supporting percentage or price-group tiered pricing.
class CustomerGroup {
  final int? id;
  final String name;
  final double amount;
  final String priceCalculationType; // 'percentage' or 'selling_price_group'
  final int? sellingPriceGroupId;
  final String? createdAt;

  const CustomerGroup({
    this.id,
    required this.name,
    this.amount = 0.0,
    this.priceCalculationType = 'percentage',
    this.sellingPriceGroupId,
    this.createdAt,
  });

  /// Applies customer group tiered pricing to a base selling price.
  ///
  /// For `'selling_price_group'`, prefers [sellingPriceGroupPrice] when supplied.
  /// For `'percentage'`, adjusts [basePrice] by `amount%` (negative = discount, positive = markup).
  double applyPricing(double basePrice, {double? sellingPriceGroupPrice}) {
    if (priceCalculationType == 'selling_price_group' &&
        sellingPriceGroupPrice != null &&
        sellingPriceGroupPrice > 0) {
      return double.parse(sellingPriceGroupPrice.toStringAsFixed(2));
    }
    final adjusted = basePrice * (1.0 + (amount / 100.0));
    return double.parse(
      (adjusted < 0.0 ? 0.0 : adjusted).toStringAsFixed(2),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'price_calculation_type': priceCalculationType,
        'selling_price_group_id': sellingPriceGroupId,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory CustomerGroup.fromMap(Map<String, dynamic> map) => CustomerGroup(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        priceCalculationType:
            map['price_calculation_type'] as String? ?? 'percentage',
        sellingPriceGroupId: map['selling_price_group_id'] as int?,
        createdAt: map['created_at'] as String?,
      );
}

