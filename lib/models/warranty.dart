/// Warranty in Smart POS
class Warranty {
  final int? id;
  final String name;
  final String description;
  final int duration;
  final String durationType; // 'days', 'months', 'years'

  Warranty({
    this.id,
    required this.name,
    this.description = '',
    required this.duration,
    this.durationType = 'months',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'duration': duration,
        'duration_type': durationType,
      };

  factory Warranty.fromMap(Map<String, dynamic> map) => Warranty(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        duration: map['duration'] as int? ?? 12,
        durationType: map['duration_type'] as String? ?? 'months',
      );
}
