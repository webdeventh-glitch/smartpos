/// Brand representation
class Brand {
  final int? id;
  final String name;
  final String? description;

  Brand({this.id, required this.name, this.description});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description ?? '',
      };

  factory Brand.fromMap(Map<String, dynamic> map) => Brand(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
      );
}
