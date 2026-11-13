/// Sales Commission Agent domain model backed by `commission_agents` table.
class CommissionAgent {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final double commissionPercent;
  final bool isActive;
  final String notes;
  final String createdAt;

  const CommissionAgent({
    this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.commissionPercent = 2.0,
    this.isActive = true,
    this.notes = '',
    required this.createdAt,
  });

  CommissionAgent copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? commissionPercent,
    bool? isActive,
    String? notes,
    String? createdAt,
  }) =>
      CommissionAgent(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        commissionPercent: commissionPercent ?? this.commissionPercent,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'commission_percent': commissionPercent,
        'is_active': isActive ? 1 : 0,
        'notes': notes,
        'created_at': createdAt,
      };

  factory CommissionAgent.fromMap(Map<String, dynamic> map) => CommissionAgent(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        address: map['address'] as String? ?? '',
        commissionPercent:
            (map['commission_percent'] as num?)?.toDouble() ?? 0.0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        notes: map['notes'] as String? ?? '',
        createdAt: map['created_at'] as String? ?? '',
      );
}
