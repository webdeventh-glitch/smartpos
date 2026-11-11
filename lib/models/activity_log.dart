import 'dart:convert';
import '../services/app_logger.dart';

/// Activity trail record stored in `activity_log` for automated CRUD auditing.
class ActivityLogEntry {
  final int? id;
  final int? userId;
  final String userName;
  final String action; // 'created', 'updated', 'deleted'
  final String entityType; // 'product', 'sale', 'purchase', 'contact', etc.
  final int? entityId;
  final String oldValues;
  final String newValues;
  final String ipAddress;
  final String createdAt;

  const ActivityLogEntry({
    this.id,
    this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    this.entityId,
    this.oldValues = '',
    this.newValues = '',
    this.ipAddress = '127.0.0.1',
    required this.createdAt,
  });

  Map<String, dynamic>? get parsedOldValues => _decodeJson(oldValues);
  Map<String, dynamic>? get parsedNewValues => _decodeJson(newValues);

  static Map<String, dynamic>? _decodeJson(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {'value': decoded};
    } catch (e, st) {
      AppLogger.warning('ActivityLogEntry', 'Invalid JSON payload in activity_log', e, st);
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'user_name': userName,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_values': oldValues,
        'new_values': newValues,
        'ip_address': ipAddress,
        'created_at': createdAt,
      };

  factory ActivityLogEntry.fromMap(Map<String, dynamic> map) => ActivityLogEntry(
        id: map['id'] as int?,
        userId: map['user_id'] as int?,
        userName: map['user_name'] as String? ?? 'System',
        action: map['action'] as String? ?? '',
        entityType: map['entity_type'] as String? ?? '',
        entityId: (map['entity_id'] as num?)?.toInt(),
        oldValues: map['old_values'] as String? ?? '',
        newValues: map['new_values'] as String? ?? '',
        ipAddress: map['ip_address'] as String? ?? '127.0.0.1',
        createdAt: map['created_at'] as String? ?? '',
      );
}

