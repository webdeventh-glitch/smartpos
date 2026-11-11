/// Selling Price Group in Smart POS
class SellingPriceGroup {
  final int? id;
  final String name; // e.g. "Wholesale Price", "VIP Retail", "Distributor"
  final String description;
  final bool isActive;

  SellingPriceGroup({
    this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'is_active': isActive ? 1 : 0,
      };

  factory SellingPriceGroup.fromMap(Map<String, dynamic> map) =>
      SellingPriceGroup(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}
