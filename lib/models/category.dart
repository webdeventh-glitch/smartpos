/// Category representation
class Category {
  final int? id;
  final String name;
  final String code;
  final String? description;
  final int? parentId;

  Category(
      {this.id,
      required this.name,
      required this.code,
      this.description,
      this.parentId});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'code': code,
        'description': description ?? '',
        'parent_id': parentId,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        description: map['description'] as String?,
        parentId: map['parent_id'] as int?,
      );
}
