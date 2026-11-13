import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'base_repository.dart';

/// Manages user accounts, RBAC roles/permissions, and structured audit/activity logs.
class AuthRepository extends BaseRepository {
  const AuthRepository([super.dbService]);

  // ===================== USERS & AUTH =====================
  Future<List<User>> getUsers() async {
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map((r) => User.fromMap(r)).toList();
  }

  Future<int> addUser(User user, {bool replaceExisting = false}) async {
    final cleanUsername = user.username.trim();
    if (cleanUsername.isEmpty) {
      throw ArgumentError('Username cannot be empty.');
    }
    final existing = await db.query(
      'users',
      where: 'LOWER(username) = ?',
      whereArgs: [cleanUsername.toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if (!replaceExisting) {
        throw StateError('Username "$cleanUsername" already exists.');
      }
      final existingId = existing.first['id'] as int;
      final map = user.toMap();
      map['id'] = existingId;
      await db.update('users', map, where: 'id = ?', whereArgs: [existingId]);
      return existingId;
    }
    final id = await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
    await recordActivity(
      action: 'created',
      entityType: 'user',
      entityId: id,
      newValues: {
        'username': user.username,
        'name': user.name,
        'role': user.role
      },
    );
    return id;
  }

  Future<void> updateUser(User user) async {
    if (user.id != null) {
      await db
          .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
      await recordActivity(
        action: 'updated',
        entityType: 'user',
        entityId: user.id,
        newValues: {
          'username': user.username,
          'name': user.name,
          'role': user.role,
          'status': user.status
        },
      );
    }
  }

  Future<void> deleteUser(int id) async {
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    await recordActivity(
      action: 'deleted',
      entityType: 'user',
      entityId: id,
    );
  }

  // ===================== RBAC ROLES & PERMISSIONS =====================

  Future<List<AppRole>> getRoles() async {
    final roleRows = await db.query('roles', orderBy: 'is_system DESC, id ASC');
    final permRows = await db.query('role_permissions');
    final permsByRole = <int, List<String>>{};
    for (final pRow in permRows) {
      final rid = pRow['role_id'] as int?;
      final key = pRow['permission_key'] as String?;
      if (rid != null && key != null) {
        permsByRole.putIfAbsent(rid, () => <String>[]).add(key);
      }
    }
    return roleRows
        .map((r) => AppRole.fromMap(
              r,
              permissions: permsByRole[r['id'] as int?] ?? const [],
            ))
        .toList();
  }

  Future<AppRole?> getRoleByName(String name) async {
    final rows = await db.query(
      'roles',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final rid = rows.first['id'] as int;
    final perms = await getRolePermissions(rid);
    return AppRole.fromMap(rows.first, permissions: perms);
  }

  Future<List<String>> getRolePermissions(int roleId) async {
    final rows = await db.query(
      'role_permissions',
      where: 'role_id = ?',
      whereArgs: [roleId],
      orderBy: 'permission_key ASC',
    );
    return rows
        .map((r) => r['permission_key'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<int> saveRole(AppRole role) async {
    final id = await db.transaction((txn) async {
      int roleId;
      final normalizedName =
          role.name.trim().toLowerCase().replaceAll(' ', '_');
      if (role.id != null) {
        await txn.update(
          'roles',
          {
            'name': normalizedName,
            'display_name': role.displayName,
            'description': role.description,
          },
          where: 'id = ?',
          whereArgs: [role.id],
        );
        roleId = role.id!;
      } else {
        final existing = await txn.query(
          'roles',
          where: 'LOWER(name) = ?',
          whereArgs: [normalizedName],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          roleId = existing.first['id'] as int;
          await txn.update(
            'roles',
            {
              'display_name': role.displayName,
              'description': role.description,
            },
            where: 'id = ?',
            whereArgs: [roleId],
          );
        } else {
          roleId = await txn.insert('roles', {
            'name': normalizedName,
            'display_name': role.displayName,
            'description': role.description,
            'is_system': role.isSystem ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      await txn.delete('role_permissions',
          where: 'role_id = ?', whereArgs: [roleId]);
      for (final permKey in role.permissions.toSet()) {
        await txn.insert(
          'role_permissions',
          {'role_id': roleId, 'permission_key': permKey},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return roleId;
    });

    await recordActivity(
      action: role.id == null ? 'created' : 'updated',
      entityType: 'role',
      entityId: id,
      newValues: {
        'name': role.name,
        'display_name': role.displayName,
        'permissions_count': role.permissions.length,
      },
    );
    return id;
  }

  Future<void> setRolePermissions(
      int roleId, List<String> permissionKeys) async {
    await db.transaction((txn) async {
      await txn.delete('role_permissions',
          where: 'role_id = ?', whereArgs: [roleId]);
      for (final key in permissionKeys.toSet()) {
        await txn.insert(
          'role_permissions',
          {'role_id': roleId, 'permission_key': key},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    await recordActivity(
      action: 'updated',
      entityType: 'role_permissions',
      entityId: roleId,
      newValues: {'permissions': permissionKeys},
    );
  }

  Future<bool> deleteRole(int roleId) async {
    final rows =
        await db.query('roles', where: 'id = ?', whereArgs: [roleId], limit: 1);
    if (rows.isEmpty) return false;
    if ((rows.first['is_system'] as int? ?? 0) == 1) {
      throw StateError('System default roles cannot be deleted.');
    }
    await db
        .delete('role_permissions', where: 'role_id = ?', whereArgs: [roleId]);
    await db.delete('roles', where: 'id = ?', whereArgs: [roleId]);
    await recordActivity(
        action: 'deleted', entityType: 'role', entityId: roleId);
    return true;
  }

  /// Resolves DB `role_permissions` merged with any per-user CSV overrides on [user].
  Future<List<String>> getEffectivePermissionsForUser(User user) async {
    if (user.isSuperAdmin || user.isAdmin) {
      return PermissionCatalog.allKeys;
    }
    final perms = <String>{};
    AppRole? dbRole;
    if (user.roleId != null) {
      final rows = await db.query('roles',
          where: 'id = ?', whereArgs: [user.roleId], limit: 1);
      if (rows.isNotEmpty) {
        final list = await getRolePermissions(user.roleId!);
        dbRole = AppRole.fromMap(rows.first, permissions: list);
      }
    }
    dbRole ??= await getRoleByName(user.role);
    if (dbRole != null) {
      perms.addAll(dbRole.permissions.map((e) => e.trim().toLowerCase()));
    } else {
      perms.addAll(PermissionCatalog.defaultPermissionsForRole(user.role));
    }

    final rawTokens = user.permissions
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasCachedRbacBlob = rawTokens.contains('__rbac__');

    for (final clean in rawTokens) {
      if (clean == '__rbac__') continue;
      if (clean.startsWith('+') && clean.length > 1) {
        perms.add(clean.substring(1));
      } else if (clean.startsWith('-') && clean.length > 1) {
        perms.remove(clean.substring(1));
      } else if (!hasCachedRbacBlob) {
        // Only treat bare tokens as custom per-user grants when not part of a resolved __rbac__ cache.
        perms.add(clean);
      }
    }
    return perms.toList()..sort();
  }

  // ===================== ACTIVITY LOG & LEGACY AUDIT LOGGING =====================

  Future<int> logActivity({
    required String action,
    required String entityType,
    int? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? userName,
    int? userId,
    String ipAddress = '127.0.0.1',
    DatabaseExecutor? txn,
  }) async {
    final activeUser = AuthService.currentUser;
    final resolvedUserId = userId ?? activeUser?.id;
    final resolvedUserName = (userName != null && userName.isNotEmpty)
        ? userName
        : (activeUser != null
            ? (activeUser.name.isNotEmpty
                ? activeUser.name
                : activeUser.username)
            : 'System');
    final nowIso = DateTime.now().toIso8601String();
    final executor = txn ?? db;

    return await executor.insert('activity_log', {
      'user_id': resolvedUserId,
      'user_name': resolvedUserName,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'old_values': oldValues != null ? jsonEncode(oldValues) : '',
      'new_values': newValues != null ? jsonEncode(newValues) : '',
      'ip_address': ipAddress,
      'created_at': nowIso,
    });
  }

  Future<List<ActivityLogEntry>> getActivityLogs({
    int limit = 200,
    String? entityType,
    String? action,
    String? search,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (entityType != null && entityType.isNotEmpty && entityType != 'All') {
      conditions.add('entity_type = ?');
      args.add(entityType);
    }
    if (action != null && action.isNotEmpty && action != 'All') {
      conditions.add('action = ?');
      args.add(action);
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      conditions.add(
          '(user_name LIKE ? OR entity_type LIKE ? OR new_values LIKE ? OR old_values LIKE ?)');
      args.addAll([q, q, q, q]);
    }

    final rows = await db.query(
      'activity_log',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map((r) => ActivityLogEntry.fromMap(r)).toList();
  }

  Future<int> logAuditAction({
    required String action,
    required String entityType,
    String? entityId,
    int? userId,
    required String userName,
    String? details,
    String? oldValues,
    String? newValues,
    String? ipAddress,
  }) async {
    final entry = AuditLog(
      action: action,
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      userName: userName,
      details: details ?? '',
      oldValues: oldValues ?? '',
      newValues: newValues ?? '',
      ipAddress: ipAddress ?? '127.0.0.1',
      timestamp: DateTime.now().toIso8601String(),
    );
    return await db.insert('audit_logs', entry.toMap());
  }

  Future<List<AuditLog>> getAuditLogs(
      {int limit = 100, String? entityType}) async {
    final where = entityType != null ? 'entity_type = ?' : null;
    final whereArgs = entityType != null ? [entityType] : null;
    final res = await db.query(
      'audit_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
      limit: limit,
    );
    return res.map((m) => AuditLog.fromMap(m)).toList();
  }
}
