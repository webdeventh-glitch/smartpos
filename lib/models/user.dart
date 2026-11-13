import 'model_helpers.dart';
import 'rbac.dart';

/// User & Authorization Model
class User {
  final int? id;
  final String name;
  final String username;
  final String password;
  final String email;
  final String role; // 'superadmin', 'admin', 'manager', 'salesman', 'cashier'
  final int? roleId;
  final String status; // 'active', 'inactive'
  final int branchId;
  final String branchName;
  final String phone;

  // Granular Operational Authorization Matrix
  final bool canEditPrice; // Can change unit selling price on POS counter
  final bool canGiveDiscount; // Can apply discounts on sales
  final double maxDiscountPercent; // Maximum discount allowed (e.g. 5.0%)
  final bool
      canViewCostPrice; // Can view product purchase/cost prices & profit margins
  final bool canDeleteSale; // Can void or delete past sales invoices
  final bool
      canProcessReturn; // Can accept customer returns & issue cash refunds
  final bool canAccessKhata; // Can access customer credit ledger & khata
  final bool canAccessInventory; // Can manage stock transfers & adjustments
  final bool canAccessReports; // Can view sales and profit/loss reports
  final bool
      canAccessSettings; // Can modify store configuration & business settings
  final bool canManageUsers; // Can create or modify salesman authorizations
  final String permissions; // Raw comma-separated string for custom permissions
  final bool mustChangePassword;
  final int failedLoginAttempts;
  final String? lockedUntil;
  final String? passwordChangedAt;

  User({
    this.id,
    required this.name,
    required this.username,
    required this.password,
    this.email = '',
    this.role = 'salesman',
    this.roleId,
    this.status = 'active',
    this.branchId = 1,
    this.branchName = 'Main Branch HQ',
    this.phone = '',
    this.canEditPrice = false,
    this.canGiveDiscount = true,
    this.maxDiscountPercent = 5.0,
    this.canViewCostPrice = false,
    this.canDeleteSale = false,
    this.canProcessReturn = false,
    this.canAccessKhata = true,
    this.canAccessInventory = false,
    this.canAccessReports = false,
    this.canAccessSettings = false,
    this.canManageUsers = false,
    this.permissions = '',
    this.mustChangePassword = false,
    this.failedLoginAttempts = 0,
    this.lockedUntil,
    this.passwordChangedAt,
  });

  bool get isSuperAdmin =>
      role.toLowerCase() == 'superadmin' || role.toLowerCase() == 'owner';
  bool get isAdmin => isSuperAdmin || role.toLowerCase() == 'admin';
  bool get isManager =>
      role.toLowerCase() == 'manager' || role.toLowerCase() == 'store manager';
  bool get isSalesman => role.toLowerCase() == 'salesman';
  bool get isCashier => role.toLowerCase() == 'cashier';

  /// Permission checker: Super Admin can always view cost price
  bool get canViewCostPriceEffective => isSuperAdmin || canViewCostPrice;

  static const Map<String, List<String>> _permissionAliases = {
    'sales.delete': ['sale.delete', 'delete_sale'],
    'sale.delete': ['sales.delete', 'delete_sale'],
    'delete_sale': ['sale.delete', 'sales.delete'],
    'sales.returns': ['sale.return', 'process_return'],
    'sale.return': ['sales.returns', 'process_return'],
    'process_return': ['sale.return', 'sales.returns'],
    'products.view_cost': ['report.view_cost_price', 'view_cost_price'],
    'report.view_cost_price': ['products.view_cost', 'view_cost_price'],
    'view_cost_price': ['report.view_cost_price', 'products.view_cost'],
    'reports.view': ['report.view', 'access_reports'],
    'report.view': ['reports.view', 'access_reports'],
    'access_reports': ['report.view', 'reports.view'],
    'contacts.khata': ['contact.khata_payment', 'access_khata'],
    'contact.khata_payment': ['contacts.khata', 'access_khata'],
    'access_khata': ['contact.khata_payment', 'contacts.khata'],
    'users.manage': ['user.manage', 'manage_users'],
    'user.manage': ['users.manage', 'manage_users'],
    'manage_users': ['user.manage', 'users.manage'],
    'inventory.manage': [
      'inventory.adjust',
      'inventory.transfer',
      'inventory.audit',
      'access_inventory'
    ],
    'access_inventory': [
      'inventory.manage',
      'inventory.adjust',
      'inventory.transfer',
      'inventory.audit'
    ],
    'access_settings': ['settings.manage'],
    'edit_price': ['pos.edit_price'],
    'give_discount': ['pos.give_discount'],
  };

  bool _matchesExplicitSet(Set<String> explicit, String key) {
    if (explicit.contains(key)) return true;
    final aliases = _permissionAliases[key];
    if (aliases != null) {
      for (final alias in aliases) {
        if (explicit.contains(alias)) return true;
      }
    }
    return false;
  }

  /// Permission checker: Owner & Admin bypass all restrictions.
  /// Checks explicit [permissions] CSV (when populated from RBAC DB), legacy
  /// capability flags, and default role matrix.
  bool hasPermission(String perm) {
    if (isSuperAdmin || isAdmin) return true;
    final key = perm.toLowerCase().trim();
    final explicit = permissions
        .split(',')
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toSet();
    if (explicit.isNotEmpty) {
      // When DB-synced RBAC permissions are loaded, enforce them strictly
      // so role revocations take effect instead of being bypassed by legacy defaults.
      if (explicit.contains('__rbac__')) {
        return _matchesExplicitSet(explicit, key);
      }
      if (_matchesExplicitSet(explicit, key)) return true;
    }

    if (_checkLegacyBooleanFlag(key)) return true;
    if (explicit.isEmpty) {
      final defaults =
          PermissionCatalog.defaultPermissionsForRole(role).toSet();
      return _matchesExplicitSet(defaults, key);
    }
    return false;
  }

  bool _checkLegacyBooleanFlag(String key) {
    switch (key) {
      case 'pos.edit_price':
      case 'edit_price':
        return canEditPrice;
      case 'pos.give_discount':
      case 'give_discount':
        return canGiveDiscount;
      case 'products.view_cost':
      case 'report.view_cost_price':
      case 'view_cost_price':
        return canViewCostPrice;
      case 'sales.delete':
      case 'sale.delete':
      case 'delete_sale':
        return canDeleteSale;
      case 'sales.returns':
      case 'sale.return':
      case 'process_return':
        return canProcessReturn;
      case 'contacts.khata':
      case 'contact.khata_payment':
      case 'access_khata':
        return canAccessKhata;
      case 'inventory.manage':
      case 'inventory.transfer':
      case 'inventory.adjust':
      case 'inventory.audit':
      case 'access_inventory':
        return canAccessInventory;
      case 'reports.view':
      case 'report.view':
      case 'report.view_profit':
      case 'access_reports':
        return canAccessReports;
      case 'report.view_audit_log':
        return canAccessReports || isManager;
      case 'settings.manage':
      case 'access_settings':
        return canAccessSettings;
      case 'users.manage':
      case 'user.manage':
      case 'manage_users':
        return canManageUsers;
      default:
        return false;
    }
  }

  User copyWith({
    int? id,
    String? name,
    String? username,
    String? password,
    String? email,
    String? role,
    int? roleId,
    String? status,
    int? branchId,
    String? branchName,
    String? phone,
    bool? canEditPrice,
    bool? canGiveDiscount,
    double? maxDiscountPercent,
    bool? canViewCostPrice,
    bool? canDeleteSale,
    bool? canProcessReturn,
    bool? canAccessKhata,
    bool? canAccessInventory,
    bool? canAccessReports,
    bool? canAccessSettings,
    bool? canManageUsers,
    String? permissions,
    bool? mustChangePassword,
    int? failedLoginAttempts,
    String? lockedUntil,
    bool clearLockedUntil = false,
    String? passwordChangedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      email: email ?? this.email,
      role: role ?? this.role,
      roleId: roleId ?? this.roleId,
      status: status ?? this.status,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      phone: phone ?? this.phone,
      canEditPrice: canEditPrice ?? this.canEditPrice,
      canGiveDiscount: canGiveDiscount ?? this.canGiveDiscount,
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      canViewCostPrice: canViewCostPrice ?? this.canViewCostPrice,
      canDeleteSale: canDeleteSale ?? this.canDeleteSale,
      canProcessReturn: canProcessReturn ?? this.canProcessReturn,
      canAccessKhata: canAccessKhata ?? this.canAccessKhata,
      canAccessInventory: canAccessInventory ?? this.canAccessInventory,
      canAccessReports: canAccessReports ?? this.canAccessReports,
      canAccessSettings: canAccessSettings ?? this.canAccessSettings,
      canManageUsers: canManageUsers ?? this.canManageUsers,
      permissions: permissions ?? this.permissions,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'username': username,
        'password': password,
        'email': email,
        'role': role,
        if (roleId != null) 'role_id': roleId,
        'status': status,
        'branch_id': branchId,
        'branch_name': branchName,
        'phone': phone,
        'can_edit_price': canEditPrice ? 1 : 0,
        'can_give_discount': canGiveDiscount ? 1 : 0,
        'max_discount_percent': maxDiscountPercent,
        'can_view_cost_price': canViewCostPrice ? 1 : 0,
        'can_delete_sale': canDeleteSale ? 1 : 0,
        'can_process_return': canProcessReturn ? 1 : 0,
        'can_access_khata': canAccessKhata ? 1 : 0,
        'can_access_inventory': canAccessInventory ? 1 : 0,
        'can_access_reports': canAccessReports ? 1 : 0,
        'can_access_settings': canAccessSettings ? 1 : 0,
        'can_manage_users': canManageUsers ? 1 : 0,
        'permissions': permissions,
        'must_change_password': mustChangePassword ? 1 : 0,
        'failed_login_attempts': failedLoginAttempts,
        'locked_until': lockedUntil,
        'password_changed_at': passwordChangedAt,
      };

  factory User.fromMap(Map<String, dynamic> map) {
    final roleStr = (map['role'] as String? ?? 'salesman').toLowerCase();
    final isSuper = roleStr == 'superadmin' || roleStr == 'owner';
    final isAdm = isSuper || roleStr == 'admin';

    return User(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'salesman',
      roleId: map['role_id'] as int?,
      status: map['status'] as String? ?? 'active',
      branchId: map['branch_id'] as int? ?? 1,
      branchName: map['branch_name'] as String? ?? 'Main Branch HQ',
      phone: map['phone'] as String? ?? '',
      canEditPrice: (map['can_edit_price'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canGiveDiscount: (map['can_give_discount'] as int? ?? 1) == 1,
      maxDiscountPercent: (map['max_discount_percent'] as num?)?.toDouble() ??
          (isAdm ? 100.0 : 5.0),
      canViewCostPrice: isSuper ||
          (map['can_view_cost_price'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canDeleteSale: (map['can_delete_sale'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canProcessReturn:
          (map['can_process_return'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessKhata: (map['can_access_khata'] as int? ?? 1) == 1,
      canAccessInventory:
          (map['can_access_inventory'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessReports:
          (map['can_access_reports'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canAccessSettings:
          (map['can_access_settings'] as int? ?? (isAdm ? 1 : 0)) == 1,
      canManageUsers: (map['can_manage_users'] as int? ?? (isAdm ? 1 : 0)) == 1,
      permissions: map['permissions'] as String? ?? '',
      mustChangePassword: modelAsBool(map['must_change_password'], false),
      failedLoginAttempts: modelAsInt(map['failed_login_attempts'], 0),
      lockedUntil: map['locked_until'] as String?,
      passwordChangedAt: map['password_changed_at'] as String?,
    );
  }
}
