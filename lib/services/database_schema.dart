import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'auth_service.dart';

/// Owns SQLite schema creation, versioned migrations, and initial baseline seeding.
class DatabaseSchema {
  DatabaseSchema._();

  static Future<bool> tableExists(DatabaseExecutor db, String table) =>
      _tableExists(db, table);

  static Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _columnExists(DatabaseExecutor db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((col) => col['name'] == column);
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    if (!await _tableExists(db, table)) {
      AppLogger.warning(
        'DatabaseMigration',
        'Skipping column $table.$column because table "$table" does not exist.',
      );
      return;
    }
    if (!await _columnExists(db, table, column)) {
      AppLogger.info('DatabaseMigration', 'Adding column $table.$column ($definition)');
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<void> _ensureIndex(
    Database db,
    String indexName,
    String table,
    String columns,
  ) async {
    if (!await _tableExists(db, table)) return;
    await db.execute('CREATE INDEX IF NOT EXISTS $indexName ON $table($columns)');
  }

  static Future<void> ensureMigrationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TEXT NOT NULL
      );
    ''');
  }

  static Future<void> _recordMigration(Database db, int version, String name) async {
    await ensureMigrationTable(db);
    await db.insert(
      'schema_migrations',
      {
        'version': version,
        'name': name,
        'applied_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    AppLogger.info('DatabaseMigration', 'Applied schema migration v$version: $name');
  }

  static Future<void> runMigrations(
    Database db, {
    required int fromVersion,
    required int toVersion,
  }) async {
    await ensureMigrationTable(db);
    if (fromVersion < 2 && toVersion >= 2) {
      await _ensureSchemaUpdates(db);
      await _recordMigration(db, 2, 'parity_tables_columns_and_indexes');
    } else if (fromVersion == 0) {
      await _ensureSchemaUpdates(db);
      await _recordMigration(db, 2, 'parity_tables_columns_and_indexes');
    }
    if (fromVersion < 3 && toVersion >= 3) {
      await _applyV3SecurityMigrations(db);
      await _recordMigration(db, 3, 'auth_hardening_and_encryption_schema');
    }
    if (fromVersion < 4 && toVersion >= 4) {
      await _applyV4Phase3Migrations(db);
      await _recordMigration(
        db,
        4,
        'phase3_item_discounts_tax_groups_customer_groups_rbac_activity_log',
      );
    }
    if (fromVersion < 5 && toVersion >= 5) {
      await _applyV5Phase4Migrations(db);
      await _recordMigration(
        db,
        5,
        'phase4_printers_and_invoice_layouts',
      );
    }
    if (fromVersion < 6 && toVersion >= 6) {
      await _applyV6Phase5Migrations(db);
      await _recordMigration(
        db,
        6,
        'phase5_product_images_variations_and_pagination',
      );
    }
  }

  static Future<void> _applyV6Phase5Migrations(Database db) async {
    await _addColumnIfMissing(db, 'products', 'category_id', 'INTEGER');
    await _addColumnIfMissing(db, 'products', 'brand_id', 'INTEGER');
    await _addColumnIfMissing(db, 'products', 'stock_quantity', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'products', 'image_color', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'image_path', 'TEXT');
    await _addColumnIfMissing(db, 'variations', 'product_id', 'INTEGER');
    await _addColumnIfMissing(db, 'variations', 'sub_sku', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'variation_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sale_items', 'variation_name', 'TEXT');
    await _addColumnIfMissing(db, 'sale_return_items', 'variation_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sale_return_items', 'variation_name', 'TEXT');

    // Move legacy filesystem paths previously saved into image_color into image_path.
    if (await _tableExists(db, 'products') &&
        await _columnExists(db, 'products', 'image_color')) {
      await db.execute('''
        UPDATE products
        SET image_path = image_color,
            image_color = '#004EEB'
        WHERE (image_path IS NULL OR TRIM(image_path) = '')
          AND image_color IS NOT NULL
          AND TRIM(image_color) != ''
          AND TRIM(image_color) NOT LIKE '#%'
      ''');
    }

    // Indexes for 50k+ cursor/paged catalog queries and fast variation lookups.
    await _ensureIndex(db, 'idx_products_name_id', 'products', 'name COLLATE NOCASE, id');
    await _ensureIndex(db, 'idx_products_cat_name', 'products', 'category_id, name COLLATE NOCASE, id');
    await _ensureIndex(db, 'idx_products_brand_name', 'products', 'brand_id, name COLLATE NOCASE, id');
    await _ensureIndex(db, 'idx_products_stock', 'products', 'stock_quantity');
    await _ensureIndex(db, 'idx_variations_prod', 'variations', 'product_id, id');
    await _ensureIndex(db, 'idx_variations_subsku', 'variations', 'sub_sku');
    await _ensureIndex(db, 'idx_sales_status_id', 'sales', 'sale_status, id DESC');
    await _ensureIndex(db, 'idx_purchases_id', 'purchases', 'id DESC');
    await _ensureIndex(db, 'idx_contacts_type_name', 'contacts', 'type, name COLLATE NOCASE, id');
  }

  static Future<void> _applyV4Phase3Migrations(Database db) async {
    // 1. Step 3.1: Explicit item-level discount & tax fields on sale_items
    await _addColumnIfMissing(db, 'sale_items', 'discount_type', "TEXT DEFAULT 'fixed'");
    await _addColumnIfMissing(db, 'sale_items', 'discount_value', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'sale_items', 'tax_amount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'sale_items', 'tax_name', 'TEXT');

    // 2. Step 3.2: Tax Groups table & product/sale tax links
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sub_tax_ids TEXT NOT NULL DEFAULT '[]',
        is_compound INTEGER DEFAULT 0,
        effective_rate REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');
    await _addColumnIfMissing(db, 'products', 'tax_rate_id', 'INTEGER');
    await _addColumnIfMissing(db, 'products', 'tax_group_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sales', 'tax_group_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sales', 'tax_breakdown_json', "TEXT DEFAULT ''");

    // 3. Step 3.3: Customer Groups & contact group link
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        amount REAL DEFAULT 0.0,
        price_calculation_type TEXT DEFAULT 'percentage',
        selling_price_group_id INTEGER,
        created_at TEXT
      )
    ''');
    await _addColumnIfMissing(db, 'contacts', 'customer_group_id', 'INTEGER');

    // 4. Step 3.4: Quotation -> Invoice tracking columns
    await _addColumnIfMissing(db, 'sales', 'converted_from_quotation_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sales', 'converted_to_sale_id', 'INTEGER');

    // 5. Step 3.5: Normalized RBAC roles & role_permissions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        description TEXT DEFAULT '',
        is_system INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role_id INTEGER NOT NULL,
        permission_key TEXT NOT NULL,
        UNIQUE(role_id, permission_key),
        FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');
    await _addColumnIfMissing(db, 'users', 'role_id', 'INTEGER');

    // 6. Step 3.6: Automated CRUD Activity Log table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await _ensureIndex(db, 'idx_act_entity', 'activity_log', 'entity_type, entity_id');
    await _ensureIndex(db, 'idx_act_date', 'activity_log', 'created_at');

    await _seedPhase3BaselineData(db);
  }

  static Future<void> _seedPhase3BaselineData(DatabaseExecutor db) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      // Fix legacy wrong-signed default seeds from pre-Phase3 builds so discounts are negative.
      await db.rawUpdate(
        "UPDATE customer_groups SET amount = -10.0 WHERE name = 'Wholesale Clients (10% Tier)' AND amount = 10.0",
      );
      await db.rawUpdate(
        "UPDATE customer_groups SET amount = -5.0 WHERE name = 'VIP Club Members (5% Tier)' AND amount = 5.0",
      );
      final cgCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM customer_groups');
      if (((cgCountRes.first['c'] as int?) ?? 0) == 0) {
        await db.insert('customer_groups', {
          'name': 'Retail Customer',
          'amount': 0.0,
          'price_calculation_type': 'percentage',
          'created_at': nowIso,
        });
        await db.insert('customer_groups', {
          'name': 'Wholesale Tier (-10%)',
          'amount': -10.0,
          'price_calculation_type': 'percentage',
          'created_at': nowIso,
        });
        await db.insert('customer_groups', {
          'name': 'VIP Preferred (-15%)',
          'amount': -15.0,
          'price_calculation_type': 'percentage',
          'created_at': nowIso,
        });
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseSchema', 'Skipped default customer_groups seed', e, st);
    }

    try {
      final roleCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM roles');
      if (((roleCountRes.first['c'] as int?) ?? 0) == 0) {
        const roleMeta = [
          ('superadmin', 'Super Admin / Owner', 'Unrestricted system owner privileges'),
          ('admin', 'Administrator', 'Full store & accounting management'),
          ('manager', 'Store Manager', 'Daily operations, inventory, reports & shift control'),
          ('salesman', 'Salesman', 'POS billing, quotations, customers & limited discounts'),
          ('cashier', 'Cashier', 'Counter checkout & register shift control'),
        ];
        for (final entry in roleMeta) {
          final roleId = await db.insert('roles', {
            'name': entry.$1,
            'display_name': entry.$2,
            'description': entry.$3,
            'is_system': 1,
            'created_at': nowIso,
          });
          for (final permKey in PermissionCatalog.defaultPermissionsForRole(entry.$1)) {
            await db.insert(
              'role_permissions',
              {'role_id': roleId, 'permission_key': permKey},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseSchema', 'Skipped default RBAC roles seed', e, st);
    }
  }

  static Future<void> _applyV5Phase4Migrations(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS receipt_printers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        connection_type TEXT DEFAULT 'network',
        capability_profile TEXT DEFAULT 'default',
        paper_width TEXT DEFAULT '80mm',
        char_per_line INTEGER DEFAULT 48,
        ip_address TEXT DEFAULT '192.168.1.100',
        port INTEGER DEFAULT 9100,
        windows_printer_path TEXT DEFAULT '',
        is_default INTEGER DEFAULT 0,
        is_kot_printer INTEGER DEFAULT 0,
        auto_cut INTEGER DEFAULT 1,
        open_cash_drawer INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_layouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        design TEXT DEFAULT 'detailed',
        paper_size TEXT DEFAULT 'a4',
        paper_orientation TEXT DEFAULT 'portrait',
        font_size REAL DEFAULT 10.0,
        highlight_color TEXT DEFAULT '#0F172A',
        invoice_heading TEXT DEFAULT 'TAX INVOICE',
        header_text TEXT DEFAULT '',
        sub_total_label TEXT DEFAULT 'Subtotal',
        discount_label TEXT DEFAULT 'Discount',
        tax_label TEXT DEFAULT 'Tax',
        total_label TEXT DEFAULT 'Grand Total',
        footer_text TEXT DEFAULT 'Thank you for shopping with us!',
        terms_text TEXT DEFAULT 'Goods once sold can only be exchanged within 7 days with original receipt.',
        signature_label TEXT DEFAULT 'Authorized Signature',
        show_logo INTEGER DEFAULT 1,
        show_business_name INTEGER DEFAULT 1,
        show_address INTEGER DEFAULT 1,
        show_phone INTEGER DEFAULT 1,
        show_email INTEGER DEFAULT 1,
        show_tax_number INTEGER DEFAULT 1,
        show_sku INTEGER DEFAULT 1,
        show_brand INTEGER DEFAULT 1,
        show_image INTEGER DEFAULT 0,
        show_expiry INTEGER DEFAULT 1,
        show_batch INTEGER DEFAULT 1,
        show_warranty INTEGER DEFAULT 1,
        show_barcode INTEGER DEFAULT 1,
        show_qr_code INTEGER DEFAULT 1,
        show_customer_balance INTEGER DEFAULT 1,
        show_signature INTEGER DEFAULT 1,
        show_total_in_words INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await _addColumnIfMissing(db, 'invoice_layouts', 'design', "TEXT DEFAULT 'detailed'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'paper_size', "TEXT DEFAULT 'a4'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'paper_orientation', "TEXT DEFAULT 'portrait'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'font_size', 'REAL DEFAULT 10.0');
    await _addColumnIfMissing(db, 'invoice_layouts', 'highlight_color', "TEXT DEFAULT '#0F172A'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'invoice_heading', "TEXT DEFAULT 'TAX INVOICE'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'header_text', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'invoice_layouts', 'sub_total_label', "TEXT DEFAULT 'Subtotal'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'discount_label', "TEXT DEFAULT 'Discount'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'tax_label', "TEXT DEFAULT 'Tax'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'total_label', "TEXT DEFAULT 'Grand Total'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'footer_text', "TEXT DEFAULT 'Thank you for shopping with us!'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'terms_text', "TEXT DEFAULT 'Goods once sold can only be exchanged within 7 days with original receipt.'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'signature_label', "TEXT DEFAULT 'Authorized Signature'");
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_logo', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_business_name', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_address', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_phone', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_email', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_tax_number', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_sku', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_brand', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_image', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_expiry', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_batch', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_warranty', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_barcode', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_qr_code', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_customer_balance', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_signature', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'show_total_in_words', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'invoice_layouts', 'is_default', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'invoice_layouts', 'created_at', 'TEXT');

    await _addColumnIfMissing(db, 'business_settings', 'auto_print_receipt', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'business_settings', 'auto_print_kot', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'business_settings', 'default_printer_id', 'INTEGER');
    await _addColumnIfMissing(db, 'business_settings', 'default_invoice_layout_id', 'INTEGER');

    try {
      final nowIso = DateTime.now().toIso8601String();
      final hasDefaultRows = await db.query('invoice_layouts', where: 'is_default = 1', limit: 1);
      final starterTemplates = [
        InvoiceLayout(
          name: 'Detailed A4 Agency',
          design: 'detailed',
          paperSize: 'a4',
          showBatch: true,
          showExpiry: true,
          showWarranty: true,
          isDefault: hasDefaultRows.isEmpty,
          createdAt: nowIso,
        ),
        InvoiceLayout(
          name: 'Classic A4 Retail',
          design: 'classic',
          paperSize: 'a4',
          highlightColor: '#1E40AF',
          showBatch: false,
          showExpiry: false,
          showWarranty: false,
          isDefault: false,
          createdAt: nowIso,
        ),
        InvoiceLayout(
          name: '80mm Counter Thermal',
          design: 'slim',
          paperSize: '80mm',
          fontSize: 9.0,
          showImage: false,
          showSignature: false,
          isDefault: false,
          createdAt: nowIso,
        ),
      ];
      for (final tpl in starterTemplates) {
        final exists = await db.query(
          'invoice_layouts',
          where: 'name = ?',
          whereArgs: [tpl.name],
          limit: 1,
        );
        if (exists.isEmpty) {
          await db.insert('invoice_layouts', tpl.toMap());
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseSchema', 'Skipped default invoice_layouts seed', e, st);
    }
  }

  static Future<void> _applyV3SecurityMigrations(Database db) async {
    await _addColumnIfMissing(db, 'users', 'must_change_password', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'failed_login_attempts', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'locked_until', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'password_changed_at', 'TEXT');
    await _addColumnIfMissing(
      db,
      'business_settings',
      'session_timeout_minutes',
      'INTEGER DEFAULT 480',
    );
  }

  /// Automatically upgrades any legacy plaintext passwords stored in `users`
  /// to Argon2id hashes and flags them for mandatory password rotation.
  static Future<void> migrateLegacyPlaintextPasswords(Database db) async {
    if (!await _tableExists(db, 'users')) return;
    final rows = await db.query('users');
    int upgraded = 0;
    for (final row in rows) {
      final id = row['id'] as int?;
      final pass = (row['password'] as String? ?? '').trim();
      if (id == null || pass.isEmpty) continue;
      if (!pass.startsWith('argon2id\$') && !pass.startsWith('sha256\$')) {
        final hashed = AuthService.hashPassword(pass);
        await db.update(
          'users',
          {
            'password': hashed,
            'must_change_password': 1,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        upgraded++;
      }
    }
    if (upgraded > 0) {
      AppLogger.info(
        'DatabaseMigration',
        'Migrated $upgraded legacy plaintext user password(s) to Argon2id with forced password rotation.',
      );
    }
  }

  /// One-time consolidation from legacy `SimpleStock/stock.db` into `SmartPOS/smart_pos.db`.
  static Future<void> importLegacySimpleStockIfPresent(
    Database db,
    String targetDbPath,
  ) async {
    if (targetDbPath == inMemoryDatabasePath ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) return;
    final legacyFile = File(p.join(base, 'SimpleStock', 'stock.db'));
    if (!legacyFile.existsSync()) return;

    final prodCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM products');
    final prodCount = (prodCountRes.first['c'] as int?) ?? 0;
    if (prodCount > 0) return;

    Database? legacyDb;
    try {
      legacyDb = await databaseFactoryFfi.openDatabase(
        legacyFile.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      if (!await _tableExists(legacyDb, 'products')) return;
      final legacyProducts = await legacyDb.query('products');
      if (legacyProducts.isEmpty) return;

      int imported = 0;
      await db.transaction((txn) async {
        for (final row in legacyProducts) {
          final sku = (row['sku'] as String? ?? '').trim();
          final name = (row['name'] as String? ?? '').trim();
          if (sku.isEmpty || name.isEmpty) continue;
          final priceCents = (row['price'] as num?)?.toDouble() ?? 0.0;
          final costCents = (row['cost'] as num?)?.toDouble() ?? 0.0;
          final qty = (row['quantity'] as num?)?.toDouble() ?? 0.0;
          final minQty = (row['minimum'] as num?)?.toDouble() ?? 5.0;
          final barcode = (row['barcode'] as String? ?? '').trim();
          await txn.insert(
            'products',
            {
              'name': name,
              'sku': sku,
              'barcode': barcode.isNotEmpty ? barcode : sku,
              'category_name': (row['category'] as String? ?? '').trim(),
              'purchase_price': costCents / 100.0,
              'selling_price': priceCents / 100.0,
              'stock_quantity': qty,
              'alert_quantity': minQty,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          imported++;
        }
      });
      if (imported > 0) {
        AppLogger.info(
          'DatabaseMigration',
          'Imported $imported product(s) from legacy SimpleStock database into SmartPOS.',
        );
      }
    } catch (e, st) {
      AppLogger.warning(
        'DatabaseMigration',
        'Legacy SimpleStock import skipped due to error',
        e,
        st,
      );
    } finally {
      await legacyDb?.close();
    }
  }

  static Future<void> _ensureSchemaUpdates(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        landmark TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        zip_code TEXT,
        mobile TEXT,
        email TEXT,
        invoice_scheme TEXT,
        is_active INTEGER DEFAULT 1
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_tax_group INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_schemes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        scheme_type TEXT DEFAULT 'blank',
        prefix TEXT DEFAULT 'INV-',
        start_number INTEGER DEFAULT 1,
        invoice_count INTEGER DEFAULT 0,
        total_digits INTEGER DEFAULT 4,
        is_default INTEGER DEFAULT 0
      );
    ''');

    // Ensure default location if empty
    final locRes = await db.rawQuery('SELECT COUNT(*) as c FROM business_locations');
    final locCount = (locRes.first['c'] as int?) ?? 0;
    if (locCount == 0) {
      await db.insert('business_locations', {
        'name': 'Main Branch HQ',
        'location_id': 'BL0001',
        'landmark': 'Central Plaza',
        'city': 'Lahore',
        'state': 'Punjab',
        'country': 'Pakistan',
        'zip_code': '54000',
        'mobile': '+92 (300) 000-0000',
        'email': 'hq@smartpos.com',
        'invoice_scheme': 'INV-',
        'is_active': 1,
      });
      await db.insert('business_locations', {
        'name': 'Warehouse & Depot',
        'location_id': 'BL0002',
        'landmark': 'Industrial Estate Sector 4',
        'city': 'Lahore',
        'state': 'Punjab',
        'country': 'Pakistan',
        'zip_code': '54000',
        'mobile': '+92 (300) 000-0001',
        'email': 'warehouse@smartpos.com',
        'invoice_scheme': 'WH-',
        'is_active': 1,
      });
    }

    // Ensure default tax rates if empty
    final taxRes = await db.rawQuery('SELECT COUNT(*) as c FROM tax_rates');
    final taxCount = (taxRes.first['c'] as int?) ?? 0;
    if (taxCount == 0) {
      await db.insert('tax_rates', {'name': 'No Tax (0%)', 'amount': 0.0, 'is_tax_group': 0});
      await db.insert('tax_rates', {'name': 'Standard VAT (5%)', 'amount': 5.0, 'is_tax_group': 0});
      await db.insert('tax_rates', {'name': 'GST / Sales Tax (15%)', 'amount': 15.0, 'is_tax_group': 0});
    }

    // Ensure default invoice schemes if empty
    final schemeRes = await db.rawQuery('SELECT COUNT(*) as c FROM invoice_schemes');
    final schemeCount = (schemeRes.first['c'] as int?) ?? 0;
    if (schemeCount == 0) {
      await db.insert('invoice_schemes', {
        'name': 'Default Format (INV-XXXX)',
        'scheme_type': 'blank',
        'prefix': 'INV-',
        'start_number': 1001,
        'invoice_count': 2,
        'total_digits': 4,
        'is_default': 1,
      });
      await db.insert('invoice_schemes', {
        'name': 'Yearly Format (INV-YYYY-XXXX)',
        'scheme_type': 'year',
        'prefix': 'INV-',
        'start_number': 1,
        'invoice_count': 0,
        'total_digits': 4,
        'is_default': 0,
      });
    }

    // Phase 2: Units, Variations, Price Groups, Warranties
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actual_name TEXT NOT NULL,
        short_name TEXT NOT NULL,
        allow_decimal INTEGER DEFAULT 0,
        base_unit_id INTEGER,
        base_unit_multiplier REAL DEFAULT 1.0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS variations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sub_sku TEXT NOT NULL,
        purchase_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        stock_quantity REAL DEFAULT 0.0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS selling_price_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER DEFAULT 1
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warranties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        duration INTEGER NOT NULL,
        duration_type TEXT DEFAULT 'months'
      );
    ''');

    // Variation Templates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS variation_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        values_json TEXT NOT NULL
      );
    ''');

    // SMS Gateways Table (Zong, Ufone, Jazz, Telenor, Twilio, Generic REST)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_gateways (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        provider TEXT NOT NULL,
        api_url TEXT NOT NULL,
        api_key TEXT,
        api_secret TEXT,
        sender_id TEXT,
        http_method TEXT DEFAULT 'POST',
        payload_format TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    // Message Logs (SMS & WhatsApp outgoing delivery tracker)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipient_name TEXT,
        phone_number TEXT NOT NULL,
        channel TEXT NOT NULL,
        message_body TEXT NOT NULL,
        status TEXT NOT NULL,
        gateway_name TEXT,
        error_details TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // AI Assistant Settings (BYO Google Gemini / OpenAI key)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT DEFAULT 'gemini',
        api_key TEXT,
        model_name TEXT DEFAULT 'gemini-1.5-flash',
        is_enabled INTEGER DEFAULT 1,
        preferred_language TEXT DEFAULT 'roman_urdu',
        system_prompt TEXT
      );
    ''');

    // Seed default Pakistan SMS Gateways if empty
    final gwCount = await db.rawQuery('SELECT COUNT(*) as c FROM sms_gateways');
    if (((gwCount.first['c'] as int?) ?? 0) == 0) {
      await db.insert('sms_gateways', {
        'name': 'Zong Corporate Branded SMS',
        'provider': 'zong',
        'api_url': 'https://api.domain.com/sms/send',
        'api_key': '',
        'api_secret': '',
        'sender_id': 'SMARTPOS',
        'http_method': 'POST',
        'payload_format': '{"to":"{to}","message":"{message}","mask":"{mask}"}',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('sms_gateways', {
        'name': 'Generic Pakistan REST SMS API',
        'provider': 'generic_http',
        'api_url': 'https://sendpk.com/api/sms.php?username={key}&password={secret}&sender={mask}&mobile={to}&message={message}',
        'api_key': '',
        'api_secret': '',
        'sender_id': 'SMARTPOS',
        'http_method': 'GET',
        'payload_format': '',
        'is_active': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Seed default AI settings if empty
    final aiCount = await db.rawQuery('SELECT COUNT(*) as c FROM ai_settings');
    if (((aiCount.first['c'] as int?) ?? 0) == 0) {
      await db.insert('ai_settings', {
        'provider': 'gemini',
        'api_key': '',
        'model_name': 'gemini-1.5-flash',
        'is_enabled': 1,
        'preferred_language': 'roman_urdu',
        'system_prompt': 'Aap Smart POS ke AI Business Advisor hain. Shop owner ko unke store ke sales, profit, stock aur products ka behtareen mashwara Roman Urdu me dein.',
      });
    }

    // Add optional columns to products, categories, and sale_items tables if missing
    await _addColumnIfMissing(db, 'products', 'type', "TEXT DEFAULT 'single'");
    await _addColumnIfMissing(db, 'products', 'barcode_type', "TEXT DEFAULT 'Code 128'");
    await _addColumnIfMissing(db, 'products', 'warranty', 'TEXT');
    await _addColumnIfMissing(db, 'categories', 'parent_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sale_items', 'unit_name', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'unit_multiplier', 'REAL DEFAULT 1.0');

    // Seed default variation templates if empty
    final varTempRes = await db.rawQuery('SELECT COUNT(*) as c FROM variation_templates');
    if (((varTempRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('variation_templates', {
        'name': 'Size',
        'values_json': jsonEncode(['S', 'M', 'L', 'XL', 'XXL']),
      });
      await db.insert('variation_templates', {
        'name': 'Color',
        'values_json': jsonEncode(['Black', 'White', 'Navy Blue', 'Crimson Red', 'Olive Green']),
      });
      await db.insert('variation_templates', {
        'name': 'Storage Capacity',
        'values_json': jsonEncode(['64GB', '128GB', '256GB', '512GB']),
      });
    }

    // Seed units if empty
    final unitRes = await db.rawQuery('SELECT COUNT(*) as c FROM units');
    if (((unitRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('units', {'actual_name': 'Pieces', 'short_name': 'Pc', 'allow_decimal': 0});
      await db.insert('units', {'actual_name': 'Box (12 Pcs)', 'short_name': 'Box', 'allow_decimal': 0, 'base_unit_multiplier': 12.0});
      await db.insert('units', {'actual_name': 'Kilograms', 'short_name': 'Kg', 'allow_decimal': 1});
      await db.insert('units', {'actual_name': 'Liters', 'short_name': 'Ltr', 'allow_decimal': 1});
    }

    // Seed price groups if empty
    final pgRes = await db.rawQuery('SELECT COUNT(*) as c FROM selling_price_groups');
    if (((pgRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('selling_price_groups', {'name': 'Retail Price', 'description': 'Standard Walk-in customer price', 'is_active': 1});
      await db.insert('selling_price_groups', {'name': 'Wholesale Price', 'description': 'Bulk purchase price with 15% margin', 'is_active': 1});
      await db.insert('selling_price_groups', {'name': 'Special VIP Price', 'description': 'Preferred loyal customer price', 'is_active': 1});
    }

    // Seed warranties if empty
    final warRes = await db.rawQuery('SELECT COUNT(*) as c FROM warranties');
    if (((warRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('warranties', {'name': '1 Year Standard Warranty', 'description': 'Full replacement & parts warranty', 'duration': 12, 'duration_type': 'months'});
      await db.insert('warranties', {'name': '6 Months Limited Warranty', 'description': 'Hardware warranty only', 'duration': 6, 'duration_type': 'months'});
      await db.insert('warranties', {'name': 'No Warranty', 'description': 'Consumables & fresh food', 'duration': 0, 'duration_type': 'days'});
    }

    // Phase 4: Stock Transfers & Adjustments
    await _addColumnIfMissing(db, 'purchases', 'location_id', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'purchases', 'location_name', "TEXT DEFAULT 'Main Branch HQ'");
    await _addColumnIfMissing(db, 'purchases', 'items_json', "TEXT DEFAULT '[]'");
    await _addColumnIfMissing(db, 'purchases', 'discount_type', "TEXT DEFAULT 'none'");
    await _addColumnIfMissing(db, 'purchases', 'discount_amount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'purchases', 'tax_rate', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'purchases', 'tax_amount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'purchases', 'shipping_charges', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'purchases', 'shipping_details', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'purchases', 'additional_expenses', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'purchases', 'payment_method', "TEXT DEFAULT 'cash'");
    await _addColumnIfMissing(db, 'purchases', 'payment_account_id', 'INTEGER');
    await _addColumnIfMissing(db, 'purchases', 'payment_note', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'purchases', 'pay_term_number', 'INTEGER');
    await _addColumnIfMissing(db, 'purchases', 'pay_term_type', "TEXT DEFAULT 'days'");
    await _addColumnIfMissing(db, 'purchases', 'document_path', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'purchases', 'purchase_date', "TEXT DEFAULT ''");

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        from_location_id INTEGER NOT NULL,
        from_location_name TEXT NOT NULL,
        to_location_id INTEGER NOT NULL,
        to_location_name TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        shipping_charges REAL DEFAULT 0.0,
        final_total REAL DEFAULT 0.0,
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        location_id INTEGER NOT NULL,
        location_name TEXT NOT NULL,
        adjustment_type TEXT DEFAULT 'normal',
        total_amount REAL DEFAULT 0.0,
        recovered_amount REAL DEFAULT 0.0,
        reason TEXT,
        date TEXT NOT NULL,
        items_json TEXT NOT NULL
      );
    ''');

// Lazimi: stock_transfers and stock_adjustments created cleanly without demo records

    // Phase 5: Contact Payments (Ledger & Due Payments)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contact_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL,
        contact_name TEXT NOT NULL,
        payment_type TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT,
        document_path TEXT
      );
    ''');
    await _addColumnIfMissing(db, 'contact_payments', 'document_path', 'TEXT');

    // Phase 1: Expenses Payment Method column
    await _addColumnIfMissing(db, 'expenses', 'payment_method', "TEXT DEFAULT 'cash'");

    // Phase 6: Payment Accounts & Double-entry Transfers
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_number TEXT,
        account_type TEXT DEFAULT 'bank',
        opening_balance REAL DEFAULT 0.0,
        current_balance REAL DEFAULT 0.0,
        note TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account_id INTEGER NOT NULL,
        from_account_name TEXT NOT NULL,
        to_account_id INTEGER NOT NULL,
        to_account_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT
      );
    ''');

    // Seed default cash drawer and primary bank account with 0 balance if empty
    final accRes = await db.rawQuery('SELECT COUNT(*) as c FROM payment_accounts');
    if (((accRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('payment_accounts', {
        'name': 'Main Store Cash Drawer',
        'account_number': 'CASH-001',
        'account_type': 'cash',
        'opening_balance': 0.0,
        'current_balance': 0.0,
        'note': 'Default Till / Front Counter Drawer',
      });
      await db.insert('payment_accounts', {
        'name': 'Primary Bank Account',
        'account_number': 'BANK-001',
        'account_type': 'bank',
        'opening_balance': 0.0,
        'current_balance': 0.0,
        'note': 'Main business bank account',
      });
    }

    // Ensure cash_registers table exists for minimal/legacy upgrades
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_name TEXT NOT NULL,
        opening_amount REAL NOT NULL,
        closing_amount REAL DEFAULT 0.0,
        total_sales_cash REAL DEFAULT 0.0,
        total_sales_card REAL DEFAULT 0.0,
        total_sales_other REAL DEFAULT 0.0,
        status TEXT DEFAULT 'open',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        note TEXT
      );
    ''');

    // Seed default open cash register if empty
    final regCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM cash_registers');
    if (((regCountRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('cash_registers', {
        'cashier_name': 'Super Administrator',
        'opening_amount': 0.0,
        'closing_amount': 0.0,
        'total_sales_cash': 0.0,
        'total_sales_card': 0.0,
        'total_sales_other': 0.0,
        'status': 'open',
        'opened_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'closed_at': null,
        'note': 'Initial till register',
      });
    }    // Phase: Users, Returns, Sync, Financial Years & Industry Tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        email TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        branch_id INTEGER DEFAULT 1,
        branch_name TEXT DEFAULT 'Main Branch HQ',
        phone TEXT
      );
    ''');

    // Setup Wizard creates the sole initial Super Admin; never seed plaintext default passwords here.

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        sale_id INTEGER NOT NULL,
        invoice_no TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        refund_amount REAL NOT NULL,
        refund_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        purchase_id INTEGER NOT NULL,
        purchase_ref TEXT NOT NULL,
        supplier_id INTEGER,
        supplier_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        refund_amount REAL NOT NULL,
        refund_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        closed_at TEXT NOT NULL,
        closed_by TEXT NOT NULL,
        total_sales REAL DEFAULT 0.0,
        total_purchases REAL DEFAULT 0.0,
        total_expenses REAL DEFAULT 0.0,
        net_profit REAL DEFAULT 0.0,
        closing_stock_value REAL DEFAULT 0.0,
        carried_forward_balance REAL DEFAULT 0.0,
        status TEXT DEFAULT 'closed',
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        variation_id INTEGER,
        variation_name TEXT,
        product_name TEXT NOT NULL,
        sku TEXT,
        batch_number TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY(return_id) REFERENCES sale_returns(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT,
        batch_number TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY(return_id) REFERENCES purchase_returns(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        payload TEXT,
        status TEXT DEFAULT 'pending',
        attempts INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        section TEXT DEFAULT 'Main Dining',
        capacity INTEGER DEFAULT 4,
        status TEXT DEFAULT 'vacant',
        order_total REAL DEFAULT 0.0,
        kot_time TEXT,
        guests INTEGER DEFAULT 0,
        current_order_id TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_kot_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kot_no TEXT NOT NULL,
        table_name TEXT NOT NULL,
        order_type TEXT DEFAULT 'Dine-In',
        items TEXT NOT NULL,
        status TEXT DEFAULT 'Cooking',
        time TEXT,
        server_name TEXT,
        items_json TEXT,
        created_at TEXT,
        special_notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS gym_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        plan TEXT,
        fee REAL DEFAULT 0.0,
        locker TEXT,
        trainer TEXT,
        expiry_date TEXT,
        days_left INTEGER DEFAULT 30,
        status TEXT DEFAULT 'Active',
        created_at TEXT,
        start_date TEXT,
        end_date TEXT,
        fee_status TEXT,
        locker_no TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS hotel_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room TEXT NOT NULL,
        type TEXT NOT NULL,
        floor TEXT,
        rate REAL DEFAULT 0.0,
        status TEXT DEFAULT 'available',
        guest TEXT,
        nights INTEGER DEFAULT 0,
        check_in TEXT,
        room_service REAL DEFAULT 0.0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repair_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_no TEXT NOT NULL,
        customer TEXT NOT NULL,
        device TEXT NOT NULL,
        phone TEXT,
        imei TEXT,
        fault TEXT,
        issue TEXT,
        technician TEXT,
        est_cost REAL DEFAULT 0.0,
        estimated_cost REAL DEFAULT 0.0,
        advance REAL DEFAULT 0.0,
        status TEXT DEFAULT 'Diagnosing',
        created_at TEXT,
        date TEXT
      );
    ''');

    // Structured schema column checks (replaces silent try-catch ALTER TABLE blocks)
    await _addColumnIfMissing(db, 'business_settings', 'is_configured', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'business_settings', 'business_type', "TEXT DEFAULT 'general'");
    await _addColumnIfMissing(db, 'business_settings', 'enabled_modules', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'trial_start_date', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'sync_enabled', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'business_settings', 'sync_mode', "TEXT DEFAULT 'offline'");
    await _addColumnIfMissing(db, 'business_settings', 'sync_server_url', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'sync_api_key', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'sync_branch_id', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'login_banner_url', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_headline', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_subheadline', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_primary_color', 'TEXT');

    await _addColumnIfMissing(db, 'products', 'batch_number', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'expiry_date', 'TEXT');
    await _addColumnIfMissing(db, 'products', 'bonus_qty', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'products', 'pack_size', 'REAL DEFAULT 1.0');
    await _addColumnIfMissing(db, 'products', 'rack_location', 'TEXT');

    await _addColumnIfMissing(db, 'sale_items', 'batch_number', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'expiry_date', 'TEXT');
    await _addColumnIfMissing(db, 'sync_queue', 'payload_json', 'TEXT');
    await _addColumnIfMissing(db, 'sync_queue', 'retry_count', 'INTEGER DEFAULT 0');

    await _addColumnIfMissing(db, 'restaurant_tables', 'order_total', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'restaurant_tables', 'kot_time', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_tables', 'guests', 'INTEGER DEFAULT 0');

    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'order_type', "TEXT DEFAULT 'Dine-In'");
    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'items', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'time', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'server_name', "TEXT DEFAULT 'Captain'");
    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'items_json', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_kot_orders', 'special_notes', 'TEXT');

    await _addColumnIfMissing(db, 'gym_members', 'member_id', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'status', "TEXT DEFAULT 'Active'");
    await _addColumnIfMissing(db, 'gym_members', 'phone', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'plan', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'fee', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'gym_members', 'locker', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'trainer', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'expiry_date', 'TEXT');
    await _addColumnIfMissing(db, 'gym_members', 'days_left', 'INTEGER DEFAULT 30');
    await _addColumnIfMissing(db, 'gym_members', 'created_at', 'TEXT');

    await _addColumnIfMissing(db, 'hotel_rooms', 'floor', 'TEXT');
    await _addColumnIfMissing(db, 'hotel_rooms', 'nights', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'hotel_rooms', 'check_in', 'TEXT');
    await _addColumnIfMissing(db, 'hotel_rooms', 'room_service', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'hotel_rooms', 'guest', 'TEXT');
    await _addColumnIfMissing(db, 'hotel_rooms', 'rate', 'REAL DEFAULT 0.0');

    await _addColumnIfMissing(db, 'repair_jobs', 'imei', 'TEXT');
    await _addColumnIfMissing(db, 'repair_jobs', 'fault', 'TEXT');
    await _addColumnIfMissing(db, 'repair_jobs', 'technician', 'TEXT');
    await _addColumnIfMissing(db, 'repair_jobs', 'est_cost', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'repair_jobs', 'advance', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'repair_jobs', 'date', 'TEXT');

    await _addColumnIfMissing(db, 'users', 'branch_id', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'users', 'branch_name', "TEXT DEFAULT 'Main Branch HQ'");
    await _addColumnIfMissing(db, 'users', 'phone', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'can_edit_price', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_give_discount', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'users', 'max_discount_percent', 'REAL DEFAULT 5.0');
    await _addColumnIfMissing(db, 'users', 'can_view_cost_price', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_delete_sale', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_process_return', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_access_khata', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'users', 'can_access_inventory', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_access_reports', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_access_settings', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'can_manage_users', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'permissions', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'users', 'must_change_password', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'failed_login_attempts', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'users', 'locked_until', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'password_changed_at', 'TEXT');

    await _addColumnIfMissing(db, 'sales', 'discount_amount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'sales', 'due_amount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'sales', 'cash_register_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sale_items', 'bonus_quantity', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'sale_items', 'pack_discount', 'REAL DEFAULT 0.0');
    await _addColumnIfMissing(db, 'business_settings', 'primary_db_type', "TEXT DEFAULT 'mysql'");

    // Phase: Payment Transactions (Split Payments & Ledger Recoveries)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT NOT NULL,
        parent_id INTEGER,
        contact_id INTEGER,
        contact_name TEXT NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        amount REAL NOT NULL,
        account_id INTEGER,
        account_name TEXT DEFAULT 'Cash Till',
        transaction_date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT,
        created_by TEXT DEFAULT 'Cashier',
        created_at TEXT NOT NULL
      );
    ''');

    // Phase: Product Serials & Batches (IMEI tracking, FIFO Expiry)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_serials_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT,
        serial_number_1 TEXT,
        serial_number_2 TEXT,
        batch_number TEXT,
        manufacturing_date TEXT,
        expiry_date TEXT,
        warranty_months INTEGER DEFAULT 0,
        warranty_expiry_date TEXT,
        status TEXT DEFAULT 'in_stock',
        purchase_id INTEGER,
        sale_id INTEGER,
        location_id INTEGER DEFAULT 1,
        purchase_price REAL DEFAULT 0.0,
        selling_price REAL DEFAULT 0.0,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // Phase: Composite / Bundle Products (Solar System Packages & BOM)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_product_id INTEGER NOT NULL,
        sub_product_id INTEGER NOT NULL,
        sub_product_name TEXT NOT NULL,
        sub_sku TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_price REAL NOT NULL DEFAULT 0.0,
        is_optional INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        notes TEXT
      );
    ''');

    // Phase: POS & System Audit Trail Logs
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        details TEXT,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        timestamp TEXT NOT NULL
      );
    ''');

    // Extra Column Migrations for Smart POS Enterprise Ecosystem
    await _addColumnIfMissing(db, 'business_settings', 'tax_number', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'hardware_id', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'deployment_mode', "TEXT DEFAULT 'offline_server'");
    await _addColumnIfMissing(db, 'business_settings', 'server_host', "TEXT DEFAULT '127.0.0.1'");
    await _addColumnIfMissing(db, 'business_settings', 'server_port', 'INTEGER DEFAULT 8080');
    await _addColumnIfMissing(db, 'business_settings', 'primary_db_type', "TEXT DEFAULT 'mysql'");
    await _addColumnIfMissing(db, 'business_settings', 'db_host', "TEXT DEFAULT 'localhost'");
    await _addColumnIfMissing(db, 'business_settings', 'db_port', 'INTEGER DEFAULT 3306');
    await _addColumnIfMissing(db, 'business_settings', 'db_name', "TEXT DEFAULT 'smartpos'");
    await _addColumnIfMissing(db, 'business_settings', 'db_user', "TEXT DEFAULT 'root'");
    await _addColumnIfMissing(db, 'business_settings', 'db_password', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'industry_presets', "TEXT DEFAULT 'retail_supermarket'");
    await _addColumnIfMissing(db, 'business_settings', 'sync_mode', "TEXT DEFAULT 'offline'");
    await _addColumnIfMissing(db, 'business_settings', 'sync_server_url', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'sync_api_key', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'sync_branch_id', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'sync_auto_interval_minutes', 'INTEGER DEFAULT 5');
    await _addColumnIfMissing(db, 'business_settings', 'last_sync_timestamp', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_banner_path', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_side_title', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'login_side_subtitle', 'TEXT');
    await _addColumnIfMissing(db, 'business_settings', 'receipt_paper_size', "TEXT DEFAULT '80mm'");
    await _addColumnIfMissing(db, 'business_settings', 'receipt_header_tagline', "TEXT DEFAULT 'Wholesale & Retail Distributor'");
    await _addColumnIfMissing(db, 'business_settings', 'receipt_header_note', "TEXT DEFAULT 'Welcome to our store!'");
    await _addColumnIfMissing(db, 'business_settings', 'receipt_return_policy', "TEXT DEFAULT 'Goods once sold can only be exchanged within 7 days with original receipt.'");
    await _addColumnIfMissing(db, 'business_settings', 'show_logo_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_barcode_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_qr_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_customer_balance_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_tax_breakdown_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_cashier_name_on_receipt', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'invoice_print_copies', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'multi_currency_enabled', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'exchange_rates_json', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'business_settings', 'custom_rates_json', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'business_settings', 'last_rates_sync', "TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'business_settings', 'invoice_layout_design', "TEXT DEFAULT 'detailed'");
    await _addColumnIfMissing(db, 'business_settings', 'show_batch_on_invoice', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_expiry_on_invoice', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_brand_on_invoice', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_sku_on_invoice', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_warranty_on_invoice', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'show_total_in_words', 'INTEGER DEFAULT 1');
    await _addColumnIfMissing(db, 'business_settings', 'total_in_words_language', "TEXT DEFAULT 'ur'");
    await _addColumnIfMissing(db, 'business_settings', 'enable_secondary_language', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'business_settings', 'secondary_language', "TEXT DEFAULT 'ur'");
    await _addColumnIfMissing(db, 'business_settings', 'invoice_heading', "TEXT DEFAULT 'TAX INVOICE'");
    await _addColumnIfMissing(db, 'business_settings', 'session_timeout_minutes', 'INTEGER DEFAULT 480');
    await db.execute("UPDATE business_settings SET sync_branch_id = 1 WHERE sync_branch_id IS NULL OR sync_branch_id = ''");

    await _addColumnIfMissing(db, 'sales', 'sale_type', "TEXT DEFAULT 'final'");
    await _addColumnIfMissing(db, 'sales', 'project_name', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'project_address', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'delivery_mode', "TEXT DEFAULT 'counter'");
    await _addColumnIfMissing(db, 'sales', 'table_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sales', 'table_name', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'waiter_id', 'INTEGER');
    await _addColumnIfMissing(db, 'sales', 'waiter_name', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'warranty_summary', 'TEXT');
    await _addColumnIfMissing(db, 'sales', 'user_name', 'TEXT');

    await _addColumnIfMissing(db, 'contacts', 'tax_number', 'TEXT');
    await _addColumnIfMissing(db, 'contacts', 'is_default_walk_in', 'INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'contacts', 'loyalty_points', 'REAL DEFAULT 0.0');

    await _addColumnIfMissing(db, 'restaurant_tables', 'waiter_name', 'TEXT');
    await _addColumnIfMissing(db, 'restaurant_tables', 'waiter_id', 'INTEGER');
    await _addColumnIfMissing(db, 'restaurant_tables', 'current_sale_id', 'INTEGER');

    // Ledger & Accounting Performance Indexes for smooth and fast queries
    await _ensureIndex(db, 'idx_pt_contact', 'payment_transactions', 'contact_id');
    await _ensureIndex(db, 'idx_pt_date', 'payment_transactions', 'transaction_date');
    await _ensureIndex(db, 'idx_pt_account', 'payment_transactions', 'account_id');
    await _ensureIndex(db, 'idx_sales_cust', 'sales', 'customer_id');
    await _ensureIndex(db, 'idx_sales_date', 'sales', 'created_at');
    await _ensureIndex(db, 'idx_pur_supp', 'purchases', 'supplier_id');
    await _ensureIndex(db, 'idx_cp_contact', 'contact_payments', 'contact_id');

    // Seed Restaurant Tables if empty

    final tableCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM restaurant_tables');
    if (((tableCountRes.first['c'] as int?) ?? 0) == 0) {
      final initialTables = [
        {'name': 'Table 1', 'section': 'Main Dining', 'capacity': 4, 'status': 'occupied', 'order_total': 2450.0, 'kot_time': '15 mins ago', 'guests': 3},
        {'name': 'Table 2', 'section': 'Main Dining', 'capacity': 2, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
        {'name': 'Table 3', 'section': 'Main Dining', 'capacity': 4, 'status': 'billed', 'order_total': 4100.0, 'kot_time': '35 mins ago', 'guests': 4},
        {'name': 'Table 4', 'section': 'Main Dining', 'capacity': 6, 'status': 'occupied', 'order_total': 6850.0, 'kot_time': '8 mins ago', 'guests': 5},
        {'name': 'Lounge VIP 1', 'section': 'VIP Family Hall', 'capacity': 8, 'status': 'occupied', 'order_total': 12400.0, 'kot_time': '22 mins ago', 'guests': 7},
        {'name': 'Lounge VIP 2', 'section': 'VIP Family Hall', 'capacity': 10, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
        {'name': 'Terrace T-1', 'section': 'Rooftop Terrace', 'capacity': 4, 'status': 'vacant', 'order_total': 0.0, 'kot_time': '', 'guests': 0},
        {'name': 'Terrace T-2', 'section': 'Rooftop Terrace', 'capacity': 4, 'status': 'occupied', 'order_total': 3200.0, 'kot_time': '5 mins ago', 'guests': 2},
      ];
      for (final t in initialTables) {
        await db.insert('restaurant_tables', t);
      }
    }

    // Seed Restaurant KOT Orders if empty
    try {
      final kotCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM restaurant_kot_orders');
      if (((kotCountRes.first['c'] as int?) ?? 0) == 0) {
        final initialKot = [
          {'kot_no': 'KOT-1048', 'table_name': 'Table 1', 'order_type': 'Dine-In', 'items': '1x Chicken Karahi, 4x Naan, 2x Mint Margarita', 'status': 'Cooking', 'time': '7:42 PM', 'server_name': 'Captain Ali'},
          {'kot_no': 'KOT-1049', 'table_name': 'Lounge VIP 1', 'order_type': 'Dine-In', 'items': '2x Mutton Handi, 1x Biryani Special, 8x Roti, 1x Salad', 'status': 'Ready to Serve', 'time': '7:48 PM', 'server_name': 'Waiter Bilal'},
          {'kot_no': 'KOT-1050', 'table_name': 'Counter 2', 'order_type': 'Takeaway', 'items': '3x Zinger Burgers, 2x Jumbo Fries, 3x Drinks', 'status': 'Preparing', 'time': '7:55 PM', 'server_name': 'Cashier 1'},
          {'kot_no': 'KOT-1051', 'table_name': 'Online Rider', 'order_type': 'Delivery', 'items': '1x Large Pizza, 10x Wings, 1x Garlic Dip', 'status': 'Dispatched', 'time': '7:30 PM', 'server_name': 'Delivery Dispatcher'},
        ];
        for (final k in initialKot) {
          await db.insert('restaurant_kot_orders', k);
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseMigration', 'Failed seeding restaurant_kot_orders', e, st);
    }

    // Seed Gym Members if empty
    try {
      final gymCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM gym_members');
      if (((gymCountRes.first['c'] as int?) ?? 0) == 0) {
        final gymMembersList = [
          {
            'member_id': 'GYM-101',
            'name': 'Ali Raza',
            'phone': '+92 300 1234567',
            'plan': 'Gold Membership (Annual)',
            'fee': 35000.0,
            'locker': 'L-14',
            'trainer': 'Coach Bilal (Bodybuilding)',
            'expiry_date': '15 Dec 2026',
            'days_left': 55,
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-102',
            'name': 'Usman Shahid',
            'phone': '+92 321 8882233',
            'plan': 'Silver Plan (Monthly)',
            'fee': 4000.0,
            'locker': 'L-08',
            'trainer': 'General Floor',
            'expiry_date': '23 Oct 2026',
            'days_left': 2,
            'status': 'Expiring Soon',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-103',
            'name': 'Faisal Qureshi',
            'phone': '+92 333 5556677',
            'plan': 'Quarterly Plan (3-Months)',
            'fee': 10500.0,
            'locker': 'L-22',
            'trainer': 'Coach Rehan (Crossfit)',
            'expiry_date': '10 Oct 2026',
            'days_left': -11,
            'status': 'Expired',
            'created_at': DateTime.now().toIso8601String(),
          },
          {
            'member_id': 'GYM-104',
            'name': 'Kamran Akmal',
            'phone': '+92 312 4443322',
            'plan': 'Personal Training Pro',
            'fee': 18000.0,
            'locker': 'L-02',
            'trainer': 'Master Coach Tariq',
            'expiry_date': '05 Nov 2026',
            'days_left': 15,
            'status': 'Active',
            'created_at': DateTime.now().toIso8601String(),
          },
        ];
        for (final m in gymMembersList) {
          await db.insert('gym_members', m);
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseMigration', 'Failed seeding gym_members', e, st);
    }

    // Seed Hotel Rooms if empty
    try {
      final hotelCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM hotel_rooms');
      if (((hotelCountRes.first['c'] as int?) ?? 0) == 0) {
        final initialRooms = [
          {'room': '101', 'type': 'Standard Single', 'floor': '1st Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Hamza Ali (CNIC: 35201-1234567-1)', 'nights': 2, 'check_in': '20 Oct', 'room_service': 1200.0},
          {'room': '102', 'type': 'Standard Double', 'floor': '1st Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '103', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'occupied', 'guest': 'Dr. Sajjad Malik', 'nights': 3, 'check_in': '19 Oct', 'room_service': 3450.0},
          {'room': '104', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'cleaning', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '201', 'type': 'Presidential Suite', 'floor': '2nd Floor', 'rate': 18000.0, 'status': 'occupied', 'guest': 'Mr. & Mrs. Mansoor', 'nights': 1, 'check_in': '21 Oct', 'room_service': 2800.0},
          {'room': '202', 'type': 'Standard Double', 'floor': '2nd Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '203', 'type': 'Family 2-Bedroom', 'floor': '2nd Floor', 'rate': 12000.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '204', 'type': 'Standard Single', 'floor': '2nd Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Tariq Jameel', 'nights': 2, 'check_in': '20 Oct', 'room_service': 450.0},
        ];
        for (final r in initialRooms) {
          await db.insert('hotel_rooms', r);
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseMigration', 'Failed seeding hotel_rooms', e, st);
    }

    // Seed Repair Jobs if empty
    try {
      final repairCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM repair_jobs');
      if (((repairCountRes.first['c'] as int?) ?? 0) == 0) {
        final initialJobs = [
          {
            'job_no': 'JOB-9021',
            'customer': 'Asad Mehmood (+92 301 5551234)',
            'device': 'Samsung Galaxy S22 Ultra',
            'imei': '352948109283741',
            'fault': 'Cracked AMOLED screen replacement & battery overhaul',
            'technician': 'Kashif Ali',
            'est_cost': 24500.0,
            'advance': 5000.0,
            'status': 'Diagnosing',
            'date': '21 Oct 2026',
          },
          {
            'job_no': 'JOB-9022',
            'customer': 'Zeeshan Tariq (+92 333 4448899)',
            'device': 'Dell Latitude 5420 Laptop',
            'imei': 'SN: 8F2K9M2',
            'fault': 'Motherboard charging IC short, no power turning on',
            'technician': 'Farhan Tech',
            'est_cost': 8500.0,
            'advance': 2000.0,
            'status': 'Waiting for Parts',
            'date': '20 Oct 2026',
          },
        ];
        for (final j in initialJobs) {
          await db.insert('repair_jobs', j);
        }
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseMigration', 'Failed seeding repair_jobs', e, st);
    }

    // Phase 12: Advanced Enterprise Feature Parity Enhancements
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL DEFAULT 0.0,
        price_calculation_type TEXT DEFAULT 'percentage',
        selling_price_group_id INTEGER,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_denominations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cash_register_id INTEGER,
        d5000 INTEGER DEFAULT 0,
        d1000 INTEGER DEFAULT 0,
        d500 INTEGER DEFAULT 0,
        d100 INTEGER DEFAULT 0,
        d50 INTEGER DEFAULT 0,
        d20 INTEGER DEFAULT 0,
        d10 INTEGER DEFAULT 0,
        d5 INTEGER DEFAULT 0,
        d2 INTEGER DEFAULT 0,
        d1 INTEGER DEFAULT 0,
        total_amount REAL DEFAULT 0.0,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_racks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_location_id INTEGER DEFAULT 1,
        product_id INTEGER NOT NULL,
        rack TEXT,
        row TEXT,
        position TEXT,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS types_of_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        location_id INTEGER DEFAULT 1,
        packing_charge_type TEXT DEFAULT 'fixed',
        packing_charge REAL DEFAULT 0.0,
        enable_custom_fields INTEGER DEFAULT 0,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_layouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        header_text TEXT,
        footer_text TEXT,
        show_logo INTEGER DEFAULT 1,
        show_tax INTEGER DEFAULT 1,
        show_customer INTEGER DEFAULT 1,
        show_barcode INTEGER DEFAULT 1,
        paper_width TEXT DEFAULT '80mm',
        is_default INTEGER DEFAULT 1,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        discount_type TEXT DEFAULT 'percentage',
        discount_amount REAL DEFAULT 0.0,
        starts_at TEXT,
        ends_at TEXT,
        brand_id INTEGER,
        category_id INTEGER,
        location_id INTEGER,
        priority INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_and_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        notable_id INTEGER NOT NULL,
        notable_type TEXT NOT NULL,
        heading TEXT NOT NULL,
        description TEXT,
        media_path TEXT,
        created_at TEXT
      );
    ''');

    // Seed customer groups if empty (canonical discount tiers are seeded in _seedPhase3BaselineData).

    // Seed types of services if empty
    try {
      final tosCount = await db.rawQuery('SELECT COUNT(*) as c FROM types_of_services');
      if (((tosCount.first['c'] as int?) ?? 0) == 0) {
        await db.insert('types_of_services', {'name': 'Dine-In', 'description': 'In-store counter / dining table service', 'packing_charge': 0.0});
        await db.insert('types_of_services', {'name': 'Takeaway / Parcel', 'description': 'Customer parcel pickup', 'packing_charge': 20.0});
        await db.insert('types_of_services', {'name': 'Home Delivery', 'description': 'Rider / Courier home delivery', 'packing_charge': 150.0});
      }
    } catch (e, st) {
      AppLogger.warning('DatabaseMigration', 'Failed seeding types_of_services', e, st);
    }

    // Canonical starter invoice layouts are seeded in _applyV5Phase4Migrations.
  }

  static Future<void> createTables(Database db) async {
    // 1. Business Settings (Full 39 columns matching BusinessSettings.toMap())
    await db.execute('''
      CREATE TABLE business_settings (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL,
        branch_name TEXT NOT NULL,
        currency_symbol TEXT NOT NULL,
        currency_code TEXT NOT NULL,
        default_tax_rate REAL NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        invoice_prefix TEXT,
        receipt_footer TEXT,
        purchase_key TEXT,
        business_type TEXT DEFAULT 'general',
        drug_license_no TEXT,
        dl_warrantor TEXT,
        time_zone TEXT,
        currency_placement TEXT,
        financial_year_start_month TEXT,
        stock_accounting_method TEXT,
        transaction_edit_days INTEGER DEFAULT 30,
        date_format TEXT,
        time_format TEXT,
        currency_precision INTEGER DEFAULT 2,
        quantity_precision INTEGER DEFAULT 2,
        default_profit_percent REAL DEFAULT 25.0,
        start_date TEXT,
        is_configured INTEGER DEFAULT 0,
        logo_path TEXT,
        trial_start_date TEXT,
        enabled_modules TEXT,
        sync_mode TEXT DEFAULT 'offline',
        sync_server_url TEXT,
        sync_api_key TEXT,
        sync_branch_id INTEGER DEFAULT 1,
        sync_auto_interval_minutes INTEGER DEFAULT 5,
        last_sync_timestamp TEXT,
        login_banner_path TEXT,
        login_side_title TEXT,
        login_side_subtitle TEXT,
        tax_number TEXT,
        hardware_id TEXT,
        deployment_mode TEXT DEFAULT 'offline_server',
        server_host TEXT DEFAULT '127.0.0.1',
        server_port INTEGER DEFAULT 8080,
        primary_db_type TEXT DEFAULT 'mysql',
        db_host TEXT DEFAULT 'localhost',
        db_port INTEGER DEFAULT 3306,
        db_name TEXT DEFAULT 'smartpos',
        db_user TEXT DEFAULT 'root',
        db_password TEXT,
        industry_presets TEXT DEFAULT 'retail_supermarket',
        receipt_paper_size TEXT DEFAULT '80mm',
        receipt_header_tagline TEXT DEFAULT 'Wholesale & Retail Distributor',
        receipt_header_note TEXT DEFAULT 'Welcome to our store!',
        receipt_return_policy TEXT DEFAULT 'Goods once sold can only be exchanged within 7 days with original receipt.',
        show_logo_on_receipt INTEGER DEFAULT 1,
        show_barcode_on_receipt INTEGER DEFAULT 1,
        show_qr_on_receipt INTEGER DEFAULT 1,
        show_customer_balance_on_receipt INTEGER DEFAULT 1,
        show_tax_breakdown_on_receipt INTEGER DEFAULT 1,
        show_cashier_name_on_receipt INTEGER DEFAULT 1,
        invoice_print_copies INTEGER DEFAULT 1,
        multi_currency_enabled INTEGER DEFAULT 1,
        exchange_rates_json TEXT DEFAULT '',
        custom_rates_json TEXT DEFAULT '',
        last_rates_sync TEXT DEFAULT '',
        invoice_layout_design TEXT DEFAULT 'detailed',
        show_batch_on_invoice INTEGER DEFAULT 1,
        show_expiry_on_invoice INTEGER DEFAULT 1,
        show_brand_on_invoice INTEGER DEFAULT 1,
        show_sku_on_invoice INTEGER DEFAULT 1,
        show_warranty_on_invoice INTEGER DEFAULT 1,
        show_total_in_words INTEGER DEFAULT 1,
        total_in_words_language TEXT DEFAULT 'ur',
        enable_secondary_language INTEGER DEFAULT 0,
        secondary_language TEXT DEFAULT 'ur',
        invoice_heading TEXT DEFAULT 'TAX INVOICE',
        session_timeout_minutes INTEGER DEFAULT 480,
        auto_print_receipt INTEGER DEFAULT 0,
        auto_print_kot INTEGER DEFAULT 0,
        default_printer_id INTEGER,
        default_invoice_layout_id INTEGER
      )
    ''');

    // 2. Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL,
        description TEXT,
        parent_id INTEGER
      )
    ''');

    // 3. Brands
    await db.execute('''
      CREATE TABLE brands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT
      )
    ''');

    // 4. Products
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE COLLATE NOCASE,
        barcode TEXT NOT NULL UNIQUE COLLATE NOCASE,
        category_id INTEGER,
        category_name TEXT,
        brand_id INTEGER,
        brand_name TEXT,
        unit TEXT DEFAULT 'Pc',
        purchase_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        stock_quantity REAL NOT NULL,
        alert_quantity REAL DEFAULT 5.0,
        image_color TEXT,
        image_path TEXT,
        type TEXT DEFAULT 'single',
        barcode_type TEXT DEFAULT 'Code 128',
        warranty TEXT,
        batch_number TEXT,
        expiry_date TEXT,
        bonus_qty REAL DEFAULT 0.0,
        pack_size REAL DEFAULT 1.0,
        rack_location TEXT,
        tax_rate_id INTEGER,
        tax_group_id INTEGER
      )
    ''');

    // 5. Contacts (Customers & Suppliers)
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        business_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        balance REAL DEFAULT 0.0,
        credit_limit REAL DEFAULT 1000.0,
        loyalty_points REAL DEFAULT 0.0,
        customer_group_id INTEGER
      )
    ''');

    // 6. Sales
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        subtotal REAL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        discount_amount REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        tax_rate REAL DEFAULT 0.0,
        shipping REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        due_amount REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'cash',
        payment_status TEXT DEFAULT 'paid',
        sale_status TEXT DEFAULT 'final',
        note TEXT,
        created_at TEXT NOT NULL,
        cash_register_id INTEGER,
        user_name TEXT,
        converted_from_quotation_id INTEGER,
        converted_to_sale_id INTEGER,
        tax_group_id INTEGER,
        tax_breakdown_json TEXT DEFAULT ''
      )
    ''');

    // 7. Sale Items
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        variation_id INTEGER,
        variation_name TEXT,
        product_name TEXT NOT NULL,
        sku TEXT,
        unit_price REAL NOT NULL,
        quantity REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        subtotal REAL NOT NULL,
        batch_number TEXT,
        expiry_date TEXT,
        bonus_quantity REAL DEFAULT 0.0,
        pack_discount REAL DEFAULT 0.0,
        unit_name TEXT,
        unit_multiplier REAL DEFAULT 1.0,
        discount_type TEXT DEFAULT 'fixed',
        discount_value REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        tax_name TEXT,
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');

    // 8. Purchases
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        supplier_id INTEGER,
        supplier_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        status TEXT DEFAULT 'received',
        payment_status TEXT DEFAULT 'paid',
        created_at TEXT NOT NULL,
        note TEXT,
        location_id INTEGER DEFAULT 1,
        location_name TEXT DEFAULT 'Main Branch HQ',
        items_json TEXT DEFAULT '[]',
        discount_type TEXT DEFAULT 'none',
        discount_amount REAL DEFAULT 0.0,
        tax_rate REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        shipping_charges REAL DEFAULT 0.0,
        shipping_details TEXT DEFAULT '',
        additional_expenses REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'cash',
        payment_account_id INTEGER,
        payment_note TEXT DEFAULT '',
        pay_term_number INTEGER,
        pay_term_type TEXT DEFAULT 'days',
        document_path TEXT DEFAULT '',
        purchase_date TEXT DEFAULT ''
      )
    ''');

    // 9. Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        ref_no TEXT,
        note TEXT,
        date TEXT NOT NULL,
        payment_method TEXT DEFAULT 'cash'
      )
    ''');

    // 10. Cash Registers
    await db.execute('''
      CREATE TABLE cash_registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_name TEXT NOT NULL,
        opening_amount REAL NOT NULL,
        closing_amount REAL DEFAULT 0.0,
        total_sales_cash REAL DEFAULT 0.0,
        total_sales_card REAL DEFAULT 0.0,
        total_sales_other REAL DEFAULT 0.0,
        status TEXT DEFAULT 'open',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        note TEXT
      )
    ''');

    // 11. Parked / Held Sales
    await db.execute('''
      CREATE TABLE parked_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        note TEXT,
        total REAL NOT NULL,
        created_at TEXT NOT NULL,
        items_json TEXT NOT NULL
      )
    ''');

    // 12. Business Locations (Multi-store / Warehouse)
    await db.execute('''
      CREATE TABLE business_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location_id TEXT NOT NULL,
        landmark TEXT,
        city TEXT,
        state TEXT,
        country TEXT,
        zip_code TEXT,
        mobile TEXT,
        email TEXT,
        invoice_scheme TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // 13. Tax Rates
    await db.execute('''
      CREATE TABLE tax_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_tax_group INTEGER DEFAULT 0
      )
    ''');

    // 14. Invoice Schemes
    await db.execute('''
      CREATE TABLE invoice_schemes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        scheme_type TEXT DEFAULT 'blank',
        prefix TEXT DEFAULT 'INV-',
        start_number INTEGER DEFAULT 1,
        invoice_count INTEGER DEFAULT 0,
        total_digits INTEGER DEFAULT 4,
        is_default INTEGER DEFAULT 0
      )
    ''');

    // 15. Units
    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actual_name TEXT NOT NULL,
        short_name TEXT NOT NULL,
        allow_decimal INTEGER DEFAULT 0,
        base_unit_id INTEGER,
        base_unit_multiplier REAL DEFAULT 1.0
      )
    ''');

    // 16. Variations
    await db.execute('''
      CREATE TABLE variations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sub_sku TEXT NOT NULL,
        purchase_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        stock_quantity REAL DEFAULT 0.0
      )
    ''');

    // 17. Selling Price Groups
    await db.execute('''
      CREATE TABLE selling_price_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // 18. Warranties
    await db.execute('''
      CREATE TABLE warranties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        duration INTEGER NOT NULL,
        duration_type TEXT DEFAULT 'months'
      )
    ''');

    // 19. Variation Templates
    await db.execute('''
      CREATE TABLE variation_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        values_json TEXT NOT NULL
      )
    ''');

    // 20. Stock Transfers
    await db.execute('''
      CREATE TABLE stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        from_location_id INTEGER NOT NULL,
        from_location_name TEXT NOT NULL,
        to_location_id INTEGER NOT NULL,
        to_location_name TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        shipping_charges REAL DEFAULT 0.0,
        final_total REAL DEFAULT 0.0,
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      )
    ''');

    // 21. Stock Adjustments
    await db.execute('''
      CREATE TABLE stock_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        location_id INTEGER NOT NULL,
        location_name TEXT NOT NULL,
        adjustment_type TEXT DEFAULT 'normal',
        total_amount REAL DEFAULT 0.0,
        recovered_amount REAL DEFAULT 0.0,
        reason TEXT,
        date TEXT NOT NULL,
        items_json TEXT NOT NULL
      )
    ''');

    // 22. Contact Payments
    await db.execute('''
      CREATE TABLE contact_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER NOT NULL,
        contact_name TEXT NOT NULL,
        payment_type TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT,
        document_path TEXT
      )
    ''');

    // 23. Payment Accounts
    await db.execute('''
      CREATE TABLE payment_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        account_number TEXT,
        account_type TEXT DEFAULT 'bank',
        opening_balance REAL DEFAULT 0.0,
        current_balance REAL DEFAULT 0.0,
        note TEXT
      )
    ''');

    // 24. Account Transfers
    await db.execute('''
      CREATE TABLE account_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_account_id INTEGER NOT NULL,
        from_account_name TEXT NOT NULL,
        to_account_id INTEGER NOT NULL,
        to_account_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT
      )
    ''');

    // 25. Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        email TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        branch_id INTEGER DEFAULT 1,
        branch_name TEXT DEFAULT 'Main Branch HQ',
        phone TEXT,
        can_edit_price INTEGER DEFAULT 0,
        can_give_discount INTEGER DEFAULT 1,
        max_discount_percent REAL DEFAULT 5.0,
        can_view_cost_price INTEGER DEFAULT 0,
        can_delete_sale INTEGER DEFAULT 0,
        can_process_return INTEGER DEFAULT 0,
        can_access_khata INTEGER DEFAULT 1,
        can_access_inventory INTEGER DEFAULT 0,
        can_access_reports INTEGER DEFAULT 0,
        can_access_settings INTEGER DEFAULT 0,
        can_manage_users INTEGER DEFAULT 0,
        permissions TEXT DEFAULT '',
        role_id INTEGER,
        must_change_password INTEGER DEFAULT 0,
        failed_login_attempts INTEGER DEFAULT 0,
        locked_until TEXT,
        password_changed_at TEXT
      )
    ''');

    // 26. Sale Returns
    await db.execute('''
      CREATE TABLE sale_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        sale_id INTEGER NOT NULL,
        invoice_no TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        refund_amount REAL NOT NULL,
        refund_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      )
    ''');

    // 27. Sale Return Items
    await db.execute('''
      CREATE TABLE sale_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        variation_id INTEGER,
        variation_name TEXT,
        product_name TEXT NOT NULL,
        sku TEXT,
        batch_number TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY(return_id) REFERENCES sale_returns(id) ON DELETE CASCADE
      )
    ''');

    // 28. Purchase Returns
    await db.execute('''
      CREATE TABLE purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_no TEXT NOT NULL UNIQUE,
        purchase_id INTEGER NOT NULL,
        purchase_ref TEXT NOT NULL,
        supplier_id INTEGER,
        supplier_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        refund_amount REAL NOT NULL,
        refund_method TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'completed',
        date TEXT NOT NULL,
        note TEXT,
        items_json TEXT NOT NULL
      )
    ''');

    // 29. Purchase Return Items
    await db.execute('''
      CREATE TABLE purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT,
        batch_number TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY(return_id) REFERENCES purchase_returns(id) ON DELETE CASCADE
      )
    ''');

    // 30. Financial Years
    await db.execute('''
      CREATE TABLE financial_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        closed_at TEXT NOT NULL,
        closed_by TEXT NOT NULL,
        total_sales REAL DEFAULT 0.0,
        total_purchases REAL DEFAULT 0.0,
        total_expenses REAL DEFAULT 0.0,
        net_profit REAL DEFAULT 0.0,
        closing_stock_value REAL DEFAULT 0.0,
        carried_forward_balance REAL DEFAULT 0.0,
        status TEXT DEFAULT 'closed',
        notes TEXT
      )
    ''');

    // 31. Sync Queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        payload TEXT,
        status TEXT DEFAULT 'pending',
        attempts INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // 32. Restaurant Tables
    await db.execute('''
      CREATE TABLE restaurant_tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        section TEXT DEFAULT 'Main Dining',
        capacity INTEGER DEFAULT 4,
        status TEXT DEFAULT 'vacant',
        order_total REAL DEFAULT 0.0,
        kot_time TEXT,
        guests INTEGER DEFAULT 0,
        current_order_id TEXT
      )
    ''');

    // 33. Restaurant KOT Orders
    await db.execute('''
      CREATE TABLE restaurant_kot_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kot_no TEXT NOT NULL,
        table_name TEXT NOT NULL,
        order_type TEXT DEFAULT 'Dine-In',
        items TEXT NOT NULL,
        status TEXT DEFAULT 'Cooking',
        time TEXT,
        server_name TEXT,
        items_json TEXT,
        created_at TEXT,
        special_notes TEXT
      )
    ''');

    // 34. Gym Members
    await db.execute('''
      CREATE TABLE gym_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        plan TEXT,
        fee REAL DEFAULT 0.0,
        locker TEXT,
        trainer TEXT,
        expiry_date TEXT,
        days_left INTEGER DEFAULT 30,
        status TEXT DEFAULT 'Active',
        created_at TEXT,
        start_date TEXT,
        end_date TEXT,
        fee_status TEXT,
        locker_no TEXT
      )
    ''');

    // 35. Hotel Rooms
    await db.execute('''
      CREATE TABLE hotel_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room TEXT NOT NULL,
        type TEXT NOT NULL,
        floor TEXT,
        rate REAL DEFAULT 0.0,
        status TEXT DEFAULT 'available',
        guest TEXT,
        nights INTEGER DEFAULT 0,
        check_in TEXT,
        room_service REAL DEFAULT 0.0
      )
    ''');

    // 36. Repair Jobs
    await db.execute('''
      CREATE TABLE repair_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_no TEXT NOT NULL,
        customer TEXT NOT NULL,
        device TEXT NOT NULL,
        phone TEXT,
        imei TEXT,
        fault TEXT,
        issue TEXT,
        technician TEXT,
        est_cost REAL DEFAULT 0.0,
        estimated_cost REAL DEFAULT 0.0,
        advance REAL DEFAULT 0.0,
        status TEXT DEFAULT 'Diagnosing',
        created_at TEXT,
        date TEXT
      )
    ''');

    // 37. Payment Transactions (Split Payments & Due Settlements)
    await db.execute('''
      CREATE TABLE payment_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT NOT NULL,
        parent_id INTEGER,
        contact_id INTEGER,
        contact_name TEXT NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        amount REAL NOT NULL,
        account_id INTEGER,
        account_name TEXT DEFAULT 'Cash Till',
        transaction_date TEXT NOT NULL,
        ref_no TEXT,
        note TEXT,
        created_by TEXT DEFAULT 'Cashier',
        created_at TEXT NOT NULL
      )
    ''');

    // 38. Product Serials & Batches (IMEI tracking, FIFO Expiry)
    await db.execute('''
      CREATE TABLE product_serials_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        sku TEXT,
        serial_number_1 TEXT,
        serial_number_2 TEXT,
        batch_number TEXT,
        manufacturing_date TEXT,
        expiry_date TEXT,
        warranty_months INTEGER DEFAULT 0,
        warranty_expiry_date TEXT,
        status TEXT DEFAULT 'in_stock',
        purchase_id INTEGER,
        sale_id INTEGER,
        location_id INTEGER DEFAULT 1,
        purchase_price REAL DEFAULT 0.0,
        selling_price REAL DEFAULT 0.0,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 39. Composite / Bundle Products (Solar System Packages & BOM)
    await db.execute('''
      CREATE TABLE product_bundles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_product_id INTEGER NOT NULL,
        sub_product_id INTEGER NOT NULL,
        sub_product_name TEXT NOT NULL,
        sub_sku TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_price REAL NOT NULL DEFAULT 0.0,
        is_optional INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        notes TEXT
      )
    ''');

    // 40. POS & System Audit Trail Logs
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        details TEXT,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        timestamp TEXT NOT NULL
      )
    ''');

    // 41. Tax Groups
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sub_tax_ids TEXT NOT NULL DEFAULT '[]',
        is_compound INTEGER DEFAULT 0,
        effective_rate REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // 42. Customer Groups
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        amount REAL DEFAULT 0.0,
        price_calculation_type TEXT DEFAULT 'percentage',
        selling_price_group_id INTEGER,
        created_at TEXT
      )
    ''');

    // 43. RBAC Roles & Role Permissions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        description TEXT DEFAULT '',
        is_system INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS role_permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role_id INTEGER NOT NULL,
        permission_key TEXT NOT NULL,
        UNIQUE(role_id, permission_key),
        FOREIGN KEY(role_id) REFERENCES roles(id) ON DELETE CASCADE
      )
    ''');

    // 44. Structured Activity Log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }


    static Future<void> seedInitialData(Database db) async {
    // 1. Settings (Pure Lazimi Foundation with isConfigured: false so Setup Wizard launches)
    final settings = BusinessSettings(
      businessName: 'Smart POS System',
      businessType: 'general',
      isConfigured: false,
    );
    await db.insert('business_settings', settings.toMap());

    // 2. Initial Super Admin is intentionally NOT seeded with a hardcoded password;
    // SetupWizardScreen creates the sole initial Super Admin with a user-chosen strong password.

    // 3. Default Location
    await db.insert('business_locations', {
      'name': 'Main Branch HQ',
      'location_id': 'BL0001',
      'landmark': 'Central Plaza',
      'city': 'Lahore',
      'state': 'Punjab',
      'country': 'Pakistan',
      'zip_code': '54000',
      'mobile': '+92 (300) 000-0000',
      'email': 'hq@smartpos.com',
      'invoice_scheme': 'INV-',
      'is_active': 1,
    });

    // 4. Default Tax Rates
    await db.insert('tax_rates', {'name': 'No Tax (0%)', 'amount': 0.0, 'is_tax_group': 0});
    await db.insert('tax_rates', {'name': 'Standard VAT (5%)', 'amount': 5.0, 'is_tax_group': 0});
    await db.insert('tax_rates', {'name': 'GST / Sales Tax (15%)', 'amount': 15.0, 'is_tax_group': 0});

    // 5. Default Invoice Scheme
    await db.insert('invoice_schemes', {
      'name': 'Default Format (INV-XXXX)',
      'scheme_type': 'blank',
      'prefix': 'INV-',
      'start_number': 1001,
      'invoice_count': 0,
      'total_digits': 4,
      'is_default': 1,
    });

    // 6. Standard Units
    await db.insert('units', {'actual_name': 'Pieces', 'short_name': 'Pc', 'allow_decimal': 0});
    await db.insert('units', {'actual_name': 'Box (12 Pcs)', 'short_name': 'Box', 'allow_decimal': 0, 'base_unit_multiplier': 12.0});
    await db.insert('units', {'actual_name': 'Kilograms', 'short_name': 'Kg', 'allow_decimal': 1});
    await db.insert('units', {'actual_name': 'Liters', 'short_name': 'Ltr', 'allow_decimal': 1});

    // 7. Standard Selling Price Groups
    await db.insert('selling_price_groups', {'name': 'Retail Price', 'description': 'Standard Walk-in customer price', 'is_active': 1});
    await db.insert('selling_price_groups', {'name': 'Wholesale Price', 'description': 'Bulk purchase price', 'is_active': 1});
    await db.insert('selling_price_groups', {'name': 'Special VIP Price', 'description': 'Preferred loyal customer price', 'is_active': 1});

    // 8. Standard Payment Accounts with 0 balance
    await db.insert('payment_accounts', {
      'name': 'Main Store Cash Drawer',
      'account_number': 'CASH-001',
      'account_type': 'cash',
      'opening_balance': 0.0,
      'current_balance': 0.0,
      'note': 'Front counter cash register',
    });
    await db.insert('payment_accounts', {
      'name': 'Primary Bank Account',
      'account_number': 'BANK-001',
      'account_type': 'bank',
      'opening_balance': 0.0,
      'current_balance': 0.0,
      'note': 'Main operating bank account',
    });

    // 9. Standard Cash Register (Open)
    await db.insert('cash_registers', {
      'cashier_name': 'Super Administrator',
      'opening_amount': 0.0,
      'closing_amount': 0.0,
      'total_sales_cash': 0.0,
      'total_sales_card': 0.0,
      'total_sales_other': 0.0,
      'status': 'open',
      'opened_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'closed_at': null,
      'note': 'Initial till register',
    });

    // 10. Standard Walk-in Customer
    await db.insert('contacts', {
      'type': 'customer',
      'name': 'Walk-in Customer',
      'business_name': '',
      'phone': 'N/A',
      'email': '',
      'address': 'Local counter',
      'balance': 0.0,
      'credit_limit': 0.0,
    });

    // Zero demo products, zero demo sales, zero demo purchases, zero demo expenses!
    // Software starts 100% clean unless admin opts in to demo seeding!
  }
}
