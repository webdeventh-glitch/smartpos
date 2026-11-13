/// Granular RBAC permission descriptor.
class AppPermission {
  final String key;
  final String label;
  final String category;

  const AppPermission({
    required this.key,
    required this.label,
    required this.category,
  });
}

/// Canonical RBAC role stored in SQLite `roles` and `role_permissions`.
class AppRole {
  final int? id;
  final String name;
  final String displayName;
  final String description;
  final bool isSystem;
  final List<String> permissions;
  final String? createdAt;

  const AppRole({
    this.id,
    required this.name,
    required this.displayName,
    this.description = '',
    this.isSystem = false,
    this.permissions = const [],
    this.createdAt,
  });

  AppRole copyWith({
    int? id,
    String? name,
    String? displayName,
    String? description,
    bool? isSystem,
    List<String>? permissions,
    String? createdAt,
  }) =>
      AppRole(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        description: description ?? this.description,
        isSystem: isSystem ?? this.isSystem,
        permissions: permissions ?? this.permissions,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'display_name': displayName,
        'description': description,
        'is_system': isSystem ? 1 : 0,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory AppRole.fromMap(
    Map<String, dynamic> map, {
    List<String> permissions = const [],
  }) =>
      AppRole(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        displayName:
            map['display_name'] as String? ?? (map['name'] as String? ?? ''),
        description: map['description'] as String? ?? '',
        isSystem: (map['is_system'] as int? ?? 0) == 1,
        permissions: permissions,
        createdAt: map['created_at'] as String?,
      );
}

/// 40+ Granular Permissions Matrix modeled after UltimatePOS RBAC.
class PermissionCatalog {
  PermissionCatalog._();

  static const List<AppPermission> all = [
    // Products & Catalog (6)
    AppPermission(
        key: 'product.view',
        label: 'View Products Catalog',
        category: 'Products'),
    AppPermission(
        key: 'product.create', label: 'Create Products', category: 'Products'),
    AppPermission(
        key: 'product.edit',
        label: 'Edit Products & Pricing',
        category: 'Products'),
    AppPermission(
        key: 'product.delete', label: 'Delete Products', category: 'Products'),
    AppPermission(
        key: 'product.import',
        label: 'Import Bulk Products (CSV/Excel)',
        category: 'Products'),
    AppPermission(
        key: 'product.print_labels',
        label: 'Print Barcode Labels',
        category: 'Products'),

    // POS & Sales (11)
    AppPermission(
        key: 'pos.access',
        label: 'Access POS Checkout Terminal',
        category: 'POS & Sales'),
    AppPermission(
        key: 'sale.view',
        label: 'View Sales Invoices',
        category: 'POS & Sales'),
    AppPermission(
        key: 'sale.create',
        label: 'Create Sales / Checkout',
        category: 'POS & Sales'),
    AppPermission(
        key: 'sale.edit',
        label: 'Edit / Resume Sales',
        category: 'POS & Sales'),
    AppPermission(
        key: 'sale.delete',
        label: 'Void / Delete Sales Invoices',
        category: 'POS & Sales'),
    AppPermission(
        key: 'sale.return',
        label: 'Process Sales Returns & Refunds',
        category: 'POS & Sales'),
    AppPermission(
        key: 'quotation.manage',
        label: 'Create & Manage Quotations',
        category: 'POS & Sales'),
    AppPermission(
        key: 'quotation.convert',
        label: 'Convert Quotation to Final Invoice',
        category: 'POS & Sales'),
    AppPermission(
        key: 'pos.give_discount',
        label: 'Apply Line & Order Discounts',
        category: 'POS & Sales'),
    AppPermission(
        key: 'pos.edit_price',
        label: 'Override Selling Price on POS Counter',
        category: 'POS & Sales'),
    AppPermission(
        key: 'pos.register_manage',
        label: 'Open / Close Cash Register Shift',
        category: 'POS & Sales'),

    // Purchases (5)
    AppPermission(
        key: 'purchase.view',
        label: 'View Purchases & Orders',
        category: 'Purchases'),
    AppPermission(
        key: 'purchase.create',
        label: 'Create Purchases & GRNs',
        category: 'Purchases'),
    AppPermission(
        key: 'purchase.edit',
        label: 'Update Purchase Status',
        category: 'Purchases'),
    AppPermission(
        key: 'purchase.delete',
        label: 'Delete Purchase Records',
        category: 'Purchases'),
    AppPermission(
        key: 'purchase.return',
        label: 'Process Purchase Returns',
        category: 'Purchases'),

    // Contacts & Khata (5)
    AppPermission(
        key: 'customer.view', label: 'View Customers', category: 'Contacts'),
    AppPermission(
        key: 'customer.manage',
        label: 'Add / Edit Customers & Customer Groups',
        category: 'Contacts'),
    AppPermission(
        key: 'supplier.view', label: 'View Suppliers', category: 'Contacts'),
    AppPermission(
        key: 'supplier.manage',
        label: 'Add / Edit Suppliers',
        category: 'Contacts'),
    AppPermission(
        key: 'contact.khata_payment',
        label: 'Record Khata / Due Payments',
        category: 'Contacts'),

    // Expenses & Accounts (3)
    AppPermission(
        key: 'expense.view', label: 'View Expenses', category: 'Finance'),
    AppPermission(
        key: 'expense.add',
        label: 'Add / Record Expenses',
        category: 'Finance'),
    AppPermission(
        key: 'account.manage',
        label: 'Manage Payment Accounts & Transfers',
        category: 'Finance'),

    // Inventory Control (3)
    AppPermission(
        key: 'inventory.transfer',
        label: 'Manage Stock Transfers',
        category: 'Inventory'),
    AppPermission(
        key: 'inventory.adjust',
        label: 'Perform Stock Adjustments',
        category: 'Inventory'),
    AppPermission(
        key: 'inventory.audit',
        label: 'Perform Stock & Expiry Audits',
        category: 'Inventory'),

    // Reports & Audit (4)
    AppPermission(
        key: 'report.view',
        label: 'Access Business Intelligence Reports',
        category: 'Reports'),
    AppPermission(
        key: 'report.view_profit',
        label: 'View Profit & Loss / Margin Data',
        category: 'Reports'),
    AppPermission(
        key: 'report.view_cost_price',
        label: 'View Purchase Cost Prices',
        category: 'Reports'),
    AppPermission(
        key: 'report.view_audit_log',
        label: 'View System Activity & Audit Log',
        category: 'Reports'),

    // Administration (4)
    AppPermission(
        key: 'settings.manage',
        label: 'Manage Store, Tax & Cloud Settings',
        category: 'Admin'),
    AppPermission(
        key: 'user.manage', label: 'Manage Staff Accounts', category: 'Admin'),
    AppPermission(
        key: 'role.manage',
        label: 'Manage Roles & Permissions Matrix',
        category: 'Admin'),
    AppPermission(
        key: 'fiscal.close',
        label: 'Run Annual Fiscal Year Closing',
        category: 'Admin'),
  ];

  static List<String> get allKeys => all.map((p) => p.key).toList();

  static List<String> defaultPermissionsForRole(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'superadmin':
      case 'owner':
      case 'admin':
        return allKeys;
      case 'manager':
        return all
            .where((p) => p.key != 'role.manage' && p.key != 'fiscal.close')
            .map((p) => p.key)
            .toList();
      case 'salesman':
        return const [
          'product.view',
          'product.print_labels',
          'pos.access',
          'sale.view',
          'sale.create',
          'sale.edit',
          'quotation.manage',
          'quotation.convert',
          'pos.give_discount',
          'pos.register_manage',
          'customer.view',
          'customer.manage',
          'contact.khata_payment',
          'expense.view',
        ];
      case 'cashier':
      default:
        return const [
          'product.view',
          'pos.access',
          'sale.view',
          'sale.create',
          'pos.register_manage',
          'customer.view',
        ];
    }
  }
}
