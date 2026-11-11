/// Tax Rate representation in Smart POS (Single or Tax Group)
class TaxRate {
  final int? id;
  final String name;
  final double amount;
  final bool isTaxGroup;

  TaxRate({
    this.id,
    required this.name,
    required this.amount,
    this.isTaxGroup = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'amount': amount,
        'is_tax_group': isTaxGroup ? 1 : 0,
      };

  factory TaxRate.fromMap(Map<String, dynamic> map) => TaxRate(
        id: map['id'] as int?,
        name: map['name'] as String,
        amount: (map['amount'] as num).toDouble(),
        isTaxGroup: (map['is_tax_group'] as int? ?? 0) == 1,
      );
}
