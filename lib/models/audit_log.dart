/// Audit Trail Record for Critical POS and Administrative Events
class AuditLog {
  final int? id;
  final String
      action; // 'item_deleted', 'price_override', 'bill_voided', 'sale_return', 'settings_changed', etc.
  final String
      entityType; // 'sale', 'purchase', 'product', 'contact', 'settings', 'auth'
  final String? entityId;
  final int? userId;
  final String userName;
  final String details;
  final String oldValues;
  final String newValues;
  final String ipAddress;
  final String timestamp;

  AuditLog({
    this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    this.userId,
    required this.userName,
    this.details = '',
    this.oldValues = '',
    this.newValues = '',
    this.ipAddress = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'user_id': userId,
        'user_name': userName,
        'details': details,
        'old_values': oldValues,
        'new_values': newValues,
        'ip_address': ipAddress,
        'timestamp': timestamp,
      };

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id'] as int?,
        action: map['action'] as String? ?? '',
        entityType: map['entity_type'] as String? ?? '',
        entityId: map['entity_id'] as String?,
        userId: map['user_id'] as int?,
        userName: map['user_name'] as String? ?? 'System',
        details: map['details'] as String? ?? '',
        oldValues: map['old_values'] as String? ?? '',
        newValues: map['new_values'] as String? ?? '',
        ipAddress: map['ip_address'] as String? ?? '',
        timestamp: map['timestamp'] as String? ?? '',
      );
}
