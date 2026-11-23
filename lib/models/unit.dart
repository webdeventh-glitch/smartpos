/// Unit representation in Smart POS (with sub-unit multipliers and categories)
class Unit {
  final int? id;
  final String actualName;
  final String shortName;
  final bool allowDecimal;
  final int? baseUnitId;
  final double baseUnitMultiplier;
  final String category; // 'count', 'weight', 'volume', 'length', 'time'

  Unit({
    this.id,
    required this.actualName,
    required this.shortName,
    this.allowDecimal = false,
    this.baseUnitId,
    this.baseUnitMultiplier = 1.0,
    this.category = 'count',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'actual_name': actualName,
        'short_name': shortName,
        'allow_decimal': allowDecimal ? 1 : 0,
        'base_unit_id': baseUnitId,
        'base_unit_multiplier': baseUnitMultiplier,
        'category': category,
      };

  factory Unit.fromMap(Map<String, dynamic> map) => Unit(
        id: map['id'] as int?,
        actualName: map['actual_name'] as String,
        shortName: map['short_name'] as String,
        allowDecimal: (map['allow_decimal'] as int? ?? 0) == 1,
        baseUnitId: map['base_unit_id'] as int?,
        baseUnitMultiplier:
            (map['base_unit_multiplier'] as num?)?.toDouble() ?? 1.0,
        category: map['category'] as String? ?? 'count',
      );
}
