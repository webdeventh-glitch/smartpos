import 'package:flutter/foundation.dart' hide Category;
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'mysql_service.dart';

class DatabaseService {
  final Database db;
  DatabaseService(this.db);

  static DatabaseService? _instance;
  static DatabaseService get instance =>
      _instance ?? (throw StateError('DatabaseService not initialized. Call initialize() first.'));
  static VoidCallback? onSyncQueueUpdated;

  static Future<DatabaseService> initialize({String? customPath}) async {
    if (customPath == null && _instance != null && _instance!.db.isOpen) return _instance!;

    sqfliteFfiInit();
    String dbPath = customPath ?? '';
    if (dbPath.isEmpty) {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      final folder = Directory(p.join(base, 'SmartPOS'));
      await folder.create(recursive: true);
      dbPath = p.join(folder.path, 'smart_pos.db');
    }

    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedInitialData(db);
          await _ensureSchemaUpdates(db);
        },
        onOpen: (db) async {
          await _ensureSchemaUpdates(db);
        },
      ),
    );

    _instance = DatabaseService(db);
    return _instance!;
  }

  /// Public method to safely trigger schema updates and migrations during online/offline patching
  Future<void> ensureSchemaMigration() => _ensureSchemaUpdates(db);

  /// Triggers background synchronization of queued records into MySQL
  void triggerAsyncMySqlSync() {
    getBusinessSettings().then((s) {
      if (s.isMySql) {
        MySqlService.connectAndSync(settings: s, localDb: this);
      }
    }).catchError((_) {});
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
        'landmark': 'Near Central Plaza',
        'city': 'New York',
        'state': 'NY',
        'country': 'USA',
        'zip_code': '10001',
        'mobile': '+1 (800) 555-0199',
        'email': 'hq@ultimatepos.com',
        'invoice_scheme': 'INV-',
        'is_active': 1,
      });
      await db.insert('business_locations', {
        'name': 'Downtown Warehouse & Depot',
        'location_id': 'BL0002',
        'landmark': 'Industrial Park Sector 4',
        'city': 'New York',
        'state': 'NY',
        'country': 'USA',
        'zip_code': '10013',
        'mobile': '+1 (800) 555-0188',
        'email': 'warehouse@ultimatepos.com',
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

    // Add optional columns to products table if missing
    try {
      await db.execute("ALTER TABLE products ADD COLUMN type TEXT DEFAULT 'single'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE products ADD COLUMN barcode_type TEXT DEFAULT 'Code 128'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE products ADD COLUMN warranty TEXT");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE categories ADD COLUMN parent_id INTEGER");
    } catch (_) {}

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
    try {
      await db.execute("ALTER TABLE purchases ADD COLUMN location_id INTEGER DEFAULT 1");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE purchases ADD COLUMN location_name TEXT DEFAULT 'Main Branch HQ'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE purchases ADD COLUMN items_json TEXT DEFAULT '[]'");
    } catch (_) {}

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
        note TEXT
      );
    ''');

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

    // Ensure default Superadmin in users table if empty
    final userCountRes = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    if (((userCountRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('users', {
        'name': 'Super Administrator',
        'username': 'superadmin',
        'password': 'password',
        'role': 'superadmin',
        'email': 'admin@smartpos.com',
        'status': 'active',
      });
    }

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

    // Schema column migrations in try-catch
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN is_configured INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN business_type TEXT DEFAULT 'general'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN enabled_modules TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN trial_start_date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_enabled INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_mode TEXT DEFAULT 'offline'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_server_url TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_api_key TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_branch_id INTEGER DEFAULT 1"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_banner_url TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_headline TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_subheadline TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_primary_color TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN batch_number TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN expiry_date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN bonus_qty REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN pack_size REAL DEFAULT 1.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE products ADD COLUMN rack_location TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sale_items ADD COLUMN batch_number TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sale_items ADD COLUMN expiry_date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sync_queue ADD COLUMN payload_json TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN order_total REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN kot_time TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN guests INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN order_type TEXT DEFAULT 'Dine-In'"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN items TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN time TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN server_name TEXT DEFAULT 'Captain'"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN items_json TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_kot_orders ADD COLUMN special_notes TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN member_id TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN status TEXT DEFAULT 'Active'"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN phone TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN plan TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN fee REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN locker TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN trainer TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN expiry_date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN days_left INTEGER DEFAULT 30"); } catch (_) {}
    try { await db.execute("ALTER TABLE gym_members ADD COLUMN created_at TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN floor TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN nights INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN check_in TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN room_service REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN guest TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE hotel_rooms ADD COLUMN rate REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN imei TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN fault TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN technician TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN est_cost REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN advance REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN advance REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE repair_jobs ADD COLUMN date TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN branch_id INTEGER DEFAULT 1"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN branch_name TEXT DEFAULT 'Main Branch HQ'"); } catch (_) {}
    try { await db.execute("ALTER TABLE users ADD COLUMN phone TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN discount_amount REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN due_amount REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN cash_register_id INTEGER"); } catch (_) {}
    try { await db.execute("ALTER TABLE sale_items ADD COLUMN bonus_quantity REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE sale_items ADD COLUMN pack_discount REAL DEFAULT 0.0"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN primary_db_type TEXT DEFAULT 'mysql'"); } catch (_) {}

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
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN tax_number TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN hardware_id TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN deployment_mode TEXT DEFAULT 'offline_server'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN server_host TEXT DEFAULT '127.0.0.1'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN server_port INTEGER DEFAULT 8080"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN primary_db_type TEXT DEFAULT 'mysql'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN db_host TEXT DEFAULT 'localhost'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN db_port INTEGER DEFAULT 3306"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN db_name TEXT DEFAULT 'smartpos'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN db_user TEXT DEFAULT 'root'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN db_password TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN industry_presets TEXT DEFAULT 'retail_supermarket'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_mode TEXT DEFAULT 'offline'"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_server_url TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_api_key TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_branch_id INTEGER DEFAULT 1"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN sync_auto_interval_minutes INTEGER DEFAULT 5"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN last_sync_timestamp TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_banner_path TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_side_title TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE business_settings ADD COLUMN login_side_subtitle TEXT"); } catch (_) {}
    try { await db.execute("UPDATE business_settings SET sync_branch_id = 1 WHERE sync_branch_id IS NULL OR sync_branch_id = ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN sale_type TEXT DEFAULT 'final'"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN project_name TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN project_address TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN delivery_mode TEXT DEFAULT 'counter'"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN table_id INTEGER"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN table_name TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN waiter_id INTEGER"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN waiter_name TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE sales ADD COLUMN warranty_summary TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE contacts ADD COLUMN tax_number TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE contacts ADD COLUMN is_default_walk_in INTEGER DEFAULT 0"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN waiter_name TEXT"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN waiter_id INTEGER"); } catch (_) {}
    try { await db.execute("ALTER TABLE restaurant_tables ADD COLUMN current_sale_id INTEGER"); } catch (_) {}

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
          try {
            await db.insert('restaurant_kot_orders', k);
          } catch (_) {}
        }
      }
    } catch (_) {}

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
          try {
            await db.insert('gym_members', m);
          } catch (_) {}
        }
      }
    } catch (_) {}

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
          try {
            await db.insert('hotel_rooms', r);
          } catch (_) {}
        }
      }
    } catch (_) {}

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
          try {
            await db.insert('repair_jobs', j);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> _createTables(Database db) async {
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
        industry_presets TEXT DEFAULT 'retail_supermarket'
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
        type TEXT DEFAULT 'single',
        barcode_type TEXT DEFAULT 'Code 128',
        warranty TEXT,
        batch_number TEXT,
        expiry_date TEXT,
        bonus_qty REAL DEFAULT 0.0,
        pack_size REAL DEFAULT 1.0,
        rack_location TEXT
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
        credit_limit REAL DEFAULT 1000.0
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
        cash_register_id INTEGER
      )
    ''');

    // 7. Sale Items
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
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
        items_json TEXT DEFAULT '[]'
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
        date TEXT NOT NULL
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
        note TEXT
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
        phone TEXT
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
  }


    static Future<void> _seedInitialData(Database db) async {
    // 1. Settings (Pure Lazimi Foundation with isConfigured: false so Setup Wizard launches)
    final settings = BusinessSettings(
      businessName: 'Smart POS System',
      businessType: 'general',
      isConfigured: false,
    );
    await db.insert('business_settings', settings.toMap());

    // 2. Default Super Administrator
    await db.insert('users', {
      'name': 'Super Administrator',
      'username': 'superadmin',
      'password': 'password',
      'role': 'superadmin',
      'email': 'admin@smartpos.com',
      'status': 'active',
    });

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

  // ===================== CRUD OPERATIONS =====================

  // Settings
  Future<BusinessSettings> getBusinessSettings() async {
    final rows = await db.query('business_settings', limit: 1);
    if (rows.isNotEmpty) return BusinessSettings.fromMap(rows.first);
    return BusinessSettings();
  }

  Future<void> updateBusinessSettings(BusinessSettings settings) async {
    final existing = await getBusinessSettings();
    final map = settings.toMap();
    if (existing.isConfigured && existing.businessType.isNotEmpty && settings.businessType != existing.businessType) {
      map['business_type'] = existing.businessType;
    }
    await db.update('business_settings', map, where: 'id = ?', whereArgs: [settings.id]);
    triggerAsyncMySqlSync();
  }

  // Business Locations
  Future<List<BusinessLocation>> getBusinessLocations() async {
    final rows = await db.query('business_locations', orderBy: 'id ASC');
    return rows.map((r) => BusinessLocation.fromMap(r)).toList();
  }

  Future<int> addBusinessLocation(BusinessLocation location) async {
    return await db.insert('business_locations', location.toMap());
  }

  Future<void> updateBusinessLocation(BusinessLocation location) async {
    if (location.id != null) {
      await db.update('business_locations', location.toMap(),
          where: 'id = ?', whereArgs: [location.id]);
    }
  }

  Future<void> deleteBusinessLocation(int id) async {
    await db.delete('business_locations', where: 'id = ?', whereArgs: [id]);
  }

  // Tax Rates
  Future<List<TaxRate>> getTaxRates() async {
    final rows = await db.query('tax_rates', orderBy: 'amount ASC');
    return rows.map((r) => TaxRate.fromMap(r)).toList();
  }

  Future<int> addTaxRate(TaxRate taxRate) async {
    return await db.insert('tax_rates', taxRate.toMap());
  }

  Future<void> deleteTaxRate(int id) async {
    await db.delete('tax_rates', where: 'id = ?', whereArgs: [id]);
  }

  // Invoice Schemes
  Future<List<InvoiceScheme>> getInvoiceSchemes() async {
    final rows = await db.query('invoice_schemes', orderBy: 'id ASC');
    return rows.map((r) => InvoiceScheme.fromMap(r)).toList();
  }

  Future<int> addInvoiceScheme(InvoiceScheme scheme) async {
    return await db.insert('invoice_schemes', scheme.toMap());
  }

  Future<void> updateInvoiceScheme(InvoiceScheme scheme) async {
    if (scheme.id != null) {
      await db.update('invoice_schemes', scheme.toMap(),
          where: 'id = ?', whereArgs: [scheme.id]);
    }
  }

  Future<void> deleteInvoiceScheme(int id) async {
    await db.delete('invoice_schemes', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> generateNextInvoiceNumber({int? schemeId}) async {
    List<Map<String, dynamic>> schemes;
    if (schemeId != null) {
      schemes = await db.query('invoice_schemes', where: 'id = ?', whereArgs: [schemeId], limit: 1);
    } else {
      schemes = await db.query('invoice_schemes', where: 'is_default = 1', limit: 1);
    }
    if (schemes.isEmpty) {
      schemes = await db.query('invoice_schemes', limit: 1);
    }

    if (schemes.isNotEmpty) {
      final s = InvoiceScheme.fromMap(schemes.first);
      final nextNumber = s.startNumber + s.invoiceCount;
      final padded = nextNumber.toString().padLeft(s.totalDigits, '0');
      final code = s.schemeType == 'year' ? '${s.prefix}${DateTime.now().year}-$padded' : '${s.prefix}$padded';
      // Increment count
      await db.rawUpdate('UPDATE invoice_schemes SET invoice_count = invoice_count + 1 WHERE id = ?', [s.id]);
      return code;
    }
    return 'INV-${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  // Units
  Future<List<Unit>> getUnits() async {
    final rows = await db.query('units', orderBy: 'actual_name ASC');
    return rows.map((r) => Unit.fromMap(r)).toList();
  }

  Future<int> addUnit(Unit unit) async {
    return await db.insert('units', unit.toMap());
  }

  Future<int> updateUnit(Unit unit) async {
    if (unit.id == null) return 0;
    return await db.update('units', unit.toMap(), where: 'id = ?', whereArgs: [unit.id]);
  }

  Future<void> deleteUnit(int id) async {
    await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  // Selling Price Groups
  Future<List<SellingPriceGroup>> getSellingPriceGroups() async {
    final rows = await db.query('selling_price_groups', orderBy: 'id ASC');
    return rows.map((r) => SellingPriceGroup.fromMap(r)).toList();
  }

  Future<int> addSellingPriceGroup(SellingPriceGroup group) async {
    return await db.insert('selling_price_groups', group.toMap());
  }

  Future<int> updateSellingPriceGroup(SellingPriceGroup group) async {
    if (group.id == null) return 0;
    return await db.update('selling_price_groups', group.toMap(), where: 'id = ?', whereArgs: [group.id]);
  }

  Future<void> deleteSellingPriceGroup(int id) async {
    await db.delete('selling_price_groups', where: 'id = ?', whereArgs: [id]);
  }

  // Warranties
  Future<List<Warranty>> getWarranties() async {
    final rows = await db.query('warranties', orderBy: 'duration ASC');
    return rows.map((r) => Warranty.fromMap(r)).toList();
  }

  Future<int> addWarranty(Warranty warranty) async {
    return await db.insert('warranties', warranty.toMap());
  }

  Future<int> updateWarranty(Warranty warranty) async {
    if (warranty.id == null) return 0;
    return await db.update('warranties', warranty.toMap(), where: 'id = ?', whereArgs: [warranty.id]);
  }

  Future<void> deleteWarranty(int id) async {
    await db.delete('warranties', where: 'id = ?', whereArgs: [id]);
  }

  // Variation Templates
  Future<List<VariationTemplate>> getVariationTemplates() async {
    final rows = await db.query('variation_templates', orderBy: 'name ASC');
    return rows.map((r) => VariationTemplate.fromMap(r)).toList();
  }

  Future<int> addVariationTemplate(VariationTemplate template) async {
    return await db.insert('variation_templates', template.toMap());
  }

  Future<int> updateVariationTemplate(VariationTemplate template) async {
    if (template.id == null) return 0;
    return await db.update('variation_templates', template.toMap(), where: 'id = ?', whereArgs: [template.id]);
  }

  Future<void> deleteVariationTemplate(int id) async {
    await db.delete('variation_templates', where: 'id = ?', whereArgs: [id]);
  }

  // Product Variations
  Future<List<ProductVariation>> getProductVariations(int productId) async {
    final rows = await db.query('variations', where: 'product_id = ?', whereArgs: [productId]);
    return rows.map((r) => ProductVariation.fromMap(r)).toList();
  }

  Future<int> addProductWithVariations(Product product, List<ProductVariation> variations) async {
    return await db.transaction((txn) async {
      final prodId = await txn.insert('products', product.toMap());
      for (var v in variations) {
        await txn.insert('variations', v.toMap(prodId));
      }
      return prodId;
    });
  }

  Future<void> updateProductWithVariations(Product product, List<ProductVariation> variations) async {
    await db.transaction((txn) async {
      await txn.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
      await txn.delete('variations', where: 'product_id = ?', whereArgs: [product.id]);
      for (var v in variations) {
        await txn.insert('variations', v.toMap(product.id!));
      }
    });
  }

  // Products
  Future<List<Product>> getProducts({int? categoryId, int? brandId, String? search}) async {
    final List<String> conditions = [];
    final List<dynamic> whereArgs = [];

    if (categoryId != null) {
      conditions.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    if (brandId != null) {
      conditions.add('brand_id = ?');
      whereArgs.add(brandId);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query('products',
        where: where, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: 'name ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductByCode(String code) async {
    final clean = code.trim();
    final rows = await db.query('products',
        where: 'sku = ? COLLATE NOCASE OR barcode = ? COLLATE NOCASE',
        whereArgs: [clean, clean],
        limit: 1);
    if (rows.isNotEmpty) return Product.fromMap(rows.first);

    // Variation Sub-SKU Lookup
    final varRows = await db.query('variations',
        where: 'sub_sku = ? COLLATE NOCASE',
        whereArgs: [clean],
        limit: 1);
    if (varRows.isNotEmpty) {
      final v = ProductVariation.fromMap(varRows.first);
      final prodRows = await db.query('products', where: 'id = ?', whereArgs: [v.productId], limit: 1);
      if (prodRows.isNotEmpty) {
        final p = Product.fromMap(prodRows.first);
        return p.copyWith(
          name: '${p.name} (${v.name})',
          sku: v.subSku,
          barcode: v.subSku,
          purchasePrice: v.purchasePrice,
          sellingPrice: v.sellingPrice,
          stockQuantity: v.stockQuantity,
        );
      }
    }
    return null;
  }

  Future<int> addProduct(Product product) async {
    final id = await db.insert('products', product.toMap());
    final pMap = product.toMap()..['id'] = id;
    await queueSyncItem(
      entityType: 'product',
      entityId: id.toString(),
      action: 'create',
      payload: pMap,
    );
    triggerAsyncMySqlSync();
    return id;
  }

  Future<int> insertProduct(Product product) => addProduct(product);

  Future<Product?> getProductById(int id) async {
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final vars = await getProductVariations(id);
    return Product.fromMap(rows.first, variations: vars);
  }

  Future<int> updateProduct(Product product) async {
    final res = await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
    await queueSyncItem(
      entityType: 'product',
      entityId: (product.id ?? 0).toString(),
      action: 'update',
      payload: product.toMap(),
    );
    triggerAsyncMySqlSync();
    return res;
  }

  Future<int> deleteProduct(int id) async {
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getLowStockProducts() async {
    final rows = await db.query('products',
        where: 'stock_quantity <= alert_quantity',
        orderBy: 'stock_quantity ASC');
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  // Categories & Brands
  Future<List<Category>> getCategories() async {
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> addCategory(Category cat) async {
    return await db.insert('categories', cat.toMap());
  }

  Future<int> insertCategory(Category cat) => addCategory(cat);

  Future<int> updateCategory(Category cat) async {
    if (cat.id == null) return 0;
    return await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<int> deleteCategory(int id) async {
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Brand>> getBrands() async {
    final rows = await db.query('brands', orderBy: 'name ASC');
    return rows.map((e) => Brand.fromMap(e)).toList();
  }

  Future<int> addBrand(Brand brand) async {
    return await db.insert('brands', brand.toMap());
  }

  Future<int> insertBrand(Brand brand) => addBrand(brand);

  Future<int> updateBrand(Brand brand) async {
    if (brand.id == null) return 0;
    return await db.update('brands', brand.toMap(), where: 'id = ?', whereArgs: [brand.id]);
  }

  Future<int> deleteBrand(int id) async {
    return await db.delete('brands', where: 'id = ?', whereArgs: [id]);
  }

  // Contacts
  Future<List<Contact>> getContacts({String? type, String? search}) async {
    final List<String> conditions = [];
    final List<dynamic> whereArgs = [];

    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(name LIKE ? OR mobile LIKE ?)');
      whereArgs.addAll(['%$search%', '%$search%']);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query('contacts',
        where: where, whereArgs: whereArgs.isNotEmpty ? whereArgs : null, orderBy: 'name ASC');
    return rows.map((e) => Contact.fromMap(e)).toList();
  }

  Future<int> deleteContact(int id) async {
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addContact(Contact contact) async {
    final id = await db.insert('contacts', contact.toMap());
    final cMap = contact.toMap()..['id'] = id;
    await queueSyncItem(
      entityType: 'contact',
      entityId: id.toString(),
      action: 'create',
      payload: cMap,
    );
    triggerAsyncMySqlSync();
    return id;
  }

  Future<int> updateContact(Contact contact) async {
    final res = await db.update('contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
    await queueSyncItem(
      entityType: 'contact',
      entityId: (contact.id ?? 0).toString(),
      action: 'update',
      payload: contact.toMap(),
    );
    triggerAsyncMySqlSync();
    return res;
  }

  Future<Contact?> getContactById(int id) async {
    final rows = await db.query('contacts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) return Contact.fromMap(rows.first);
    return null;
  }

  // POS & Sales
  Future<String> generateNextInvoiceNo() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM sales');
    final maxId = (rows.first['max_id'] as int?) ?? 1000;
    return 'INV-${maxId + 1}';
  }

  Future<Sale> createSale({
    required Sale sale,
    required List<CartItem> items,
    List<Map<String, dynamic>>? splitTenders,
  }) async {
    final createdSale = await db.transaction((txn) async {
      // 1. Insert Sale record
      final saleId = await txn.insert('sales', sale.toMap());

      // 2. Insert items and decrement stock
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(saleId));

        if (sale.saleStatus == 'final' && item.product.id != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.product.id],
          );
        }
      }

      // 3. Update customer balance if partial or due
      if (sale.customerId != null && sale.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [sale.dueAmount, sale.customerId],
        );
      }

      // 4. Update Cash register sales if final
      if (sale.saleStatus == 'final') {
        if (splitTenders != null && splitTenders.isNotEmpty) {
          for (final st in splitTenders) {
            final amt = (st['amount'] as num?)?.toDouble() ?? 0.0;
            final m = (st['method'] as String?)?.toLowerCase() ?? 'cash';
            if (amt > 0) {
              if (m == 'cash') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
                  [amt],
                );
              } else if (m == 'card') {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
                  [amt],
                );
              } else {
                await txn.rawUpdate(
                  'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
                  [amt],
                );
              }
            }
          }
        } else {
          if (sale.paymentMethod == 'cash') {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else if (sale.paymentMethod == 'card') {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          } else {
            await txn.rawUpdate(
              'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
              [sale.paidAmount],
            );
          }
        }
      }

      // 5. Record Payment Transactions Ledger
      final nowStr = DateTime.now().toIso8601String();
      if (splitTenders != null && splitTenders.isNotEmpty) {
        for (final st in splitTenders) {
          final amt = (st['amount'] as num?)?.toDouble() ?? 0.0;
          if (amt > 0) {
            final m = st['method'] as String? ?? 'cash';
            await txn.insert('payment_transactions', {
              'transaction_type': 'sale',
              'parent_id': saleId,
              'contact_id': sale.customerId,
              'contact_name': sale.customerName,
              'payment_method': m,
              'amount': amt,
              'account_name': (m == 'cash') ? 'Cash Register' : 'Main Bank Account',
              'transaction_date': sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
              'ref_no': sale.invoiceNo,
              'note': sale.note,
              'created_by': 'Cashier',
              'created_at': nowStr,
            });
          }
        }
      } else if (sale.paidAmount > 0) {
        await txn.insert('payment_transactions', {
          'transaction_type': 'sale',
          'parent_id': saleId,
          'contact_id': sale.customerId,
          'contact_name': sale.customerName,
          'payment_method': sale.paymentMethod,
          'amount': sale.paidAmount,
          'account_name': (sale.paymentMethod == 'cash') ? 'Cash Register' : 'Main Bank Account',
          'transaction_date': sale.createdAt.isNotEmpty ? sale.createdAt : nowStr,
          'ref_no': sale.invoiceNo,
          'note': sale.note,
          'created_by': 'Cashier',
          'created_at': nowStr,
        });
      }

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'sale',
        'entity_id': saleId.toString(),
        'action': 'create',
        'payload_json': jsonEncode({
          'sale': sale.toMap()..['id'] = saleId,
          'items': items.map((i) => i.toMap(saleId)).toList(),
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': nowStr,
      });

      return Sale(
        id: saleId,
        invoiceNo: sale.invoiceNo,
        customerId: sale.customerId,
        customerName: sale.customerName,
        subtotal: sale.subtotal,
        discount: sale.discount,
        taxAmount: sale.taxAmount,
        taxRate: sale.taxRate,
        shipping: sale.shipping,
        totalAmount: sale.totalAmount,
        paidAmount: sale.paidAmount,
        paymentMethod: sale.paymentMethod,
        paymentStatus: sale.paymentStatus,
        saleStatus: sale.saleStatus,
        note: sale.note,
        createdAt: sale.createdAt,
        items: items
            .map((e) => SaleItem(
                  saleId: saleId,
                  productId: e.product.id,
                  productName: e.product.name,
                  sku: e.product.sku,
                  unitPrice: e.unitPrice,
                  quantity: e.quantity,
                  discount: e.discount,
                  subtotal: e.subtotal,
                ))
            .toList(),
      );
    });
    triggerAsyncMySqlSync();
    return createdSale;
  }

  Future<List<Sale>> getSales({String? status, String? search}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (status != null && status != 'all') {
      where = 'sale_status = ?';
      whereArgs = [status];
    }

    if (search != null && search.isNotEmpty) {
      const searchCond = '(invoice_no LIKE ? OR customer_name LIKE ?)';
      final searchParams = ['%$search%', '%$search%'];
      if (where != null) {
        where = '$where AND $searchCond';
        whereArgs!.addAll(searchParams);
      } else {
        where = searchCond;
        whereArgs = searchParams;
      }
    }

    final rows =
        await db.query('sales', where: where, whereArgs: whereArgs, orderBy: 'id DESC');
    return rows.map((e) => Sale.fromMap(e)).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final rows = await db.query('sale_items',
        where: 'sale_id = ?', whereArgs: [saleId]);
    return rows.map((e) => SaleItem.fromMap(e)).toList();
  }

  /// Settle partial / due sales payment and update customer balance ledger
  Future<void> settleSalePayment({
    required int saleId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) async {
    await db.transaction((txn) async {
      final saleRows = await txn.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (saleRows.isEmpty) throw Exception('Sale #$saleId not found');
      final sale = Sale.fromMap(saleRows.first);

      final newPaidAmount = sale.paidAmount + amountPaid;
      final newStatus = newPaidAmount >= sale.totalAmount ? 'paid' : 'partial';

      await txn.update(
        'sales',
        {
          'paid_amount': newPaidAmount,
          'payment_status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // Deduct recovered payment from customer's due ledger
      if (sale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [amountPaid, sale.customerId],
        );
      }

      // Record in payment_transactions table
      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': 'sale',
        'parent_id': saleId,
        'contact_id': sale.customerId,
        'contact_name': sale.customerName,
        'payment_method': paymentMethod,
        'amount': amountPaid,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': refNo.isNotEmpty ? refNo : 'REC-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty ? note : 'Ledger due recovery for ${sale.invoiceNo}',
        'created_by': createdBy,
        'created_at': nowStr,
      });

      // Update cash register if cash
      if (paymentMethod == 'cash') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
          [amountPaid],
        );
      } else if (paymentMethod == 'card') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_card = total_sales_card + ? WHERE status = \'open\'',
          [amountPaid],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_other = total_sales_other + ? WHERE status = \'open\'',
          [amountPaid],
        );
      }
    });
  }

  /// Settle purchase balance due to supplier and update supplier balance ledger
  Future<void> settlePurchasePayment({
    required int purchaseId,
    required double amountPaid,
    required String paymentMethod,
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query('purchases', where: 'id = ?', whereArgs: [purchaseId], limit: 1);
      if (rows.isEmpty) throw Exception('Purchase #$purchaseId not found');
      final purchase = Purchase.fromMap(rows.first);

      final newPaidAmount = purchase.paidAmount + amountPaid;
      final newStatus = newPaidAmount >= purchase.totalAmount ? 'paid' : 'partial';

      await txn.update(
        'purchases',
        {
          'paid_amount': newPaidAmount,
          'payment_status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      // Deduct paid installment from supplier's payable ledger
      if (purchase.supplierId != null) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [amountPaid, purchase.supplierId],
        );
      }

      // Record in payment_transactions table
      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': 'purchase',
        'parent_id': purchaseId,
        'contact_id': purchase.supplierId,
        'contact_name': purchase.supplierName,
        'payment_method': paymentMethod,
        'amount': amountPaid,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': refNo.isNotEmpty ? refNo : 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty ? note : 'Supplier installment payment for ${purchase.referenceNo}',
        'created_by': createdBy,
        'created_at': nowStr,
      });
    });
  }

  /// Direct customer or supplier ledger payment recording
  Future<void> recordContactPayment({
    required int contactId,
    required double amount,
    required String paymentMethod,
    String transactionType = 'customer_payment',
    String accountName = 'Cash Register',
    String refNo = '',
    String note = '',
    String createdBy = 'Cashier',
  }) async {
    await db.transaction((txn) async {
      final rows = await txn.query('contacts', where: 'id = ?', whereArgs: [contactId], limit: 1);
      if (rows.isEmpty) throw Exception('Contact #$contactId not found');
      final contact = Contact.fromMap(rows.first);

      // Reduce contact balance
      await txn.rawUpdate(
        'UPDATE contacts SET balance = balance - ? WHERE id = ?',
        [amount, contactId],
      );

      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': transactionType,
        'parent_id': 0,
        'contact_id': contactId,
        'contact_name': contact.name,
        'payment_method': paymentMethod,
        'amount': amount,
        'account_name': accountName,
        'transaction_date': nowStr,
        'ref_no': refNo.isNotEmpty ? refNo : 'REC-${DateTime.now().millisecondsSinceEpoch}',
        'note': note.isNotEmpty ? note : 'Direct ledger settlement for ${contact.name}',
        'created_by': createdBy,
        'created_at': nowStr,
      });
    });
  }

  // Parked / Suspended Sales
  Future<int> parkSale(ParkedSale parked) async {
    return await db.insert('parked_sales', parked.toMap());
  }

  Future<List<ParkedSale>> getParkedSales() async {
    final rows = await db.query('parked_sales', orderBy: 'id DESC');
    return rows.map((e) => ParkedSale.fromMap(e)).toList();
  }

  Future<int> deleteParkedSale(int id) async {
    return await db.delete('parked_sales', where: 'id = ?', whereArgs: [id]);
  }

  // Purchases
  Future<String> generateNextPurchaseRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM purchases');
    final maxId = (rows.first['max_id'] as int?) ?? 100;
    return 'PO-2026-${maxId + 1}';
  }

  Future<int> createPurchase({
    required Purchase purchase,
    required List<Map<String, dynamic>> items,
  }) async {
    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', purchase.toMap());

      for (var item in items) {
        final productId = item['product_id'] as int?;
        final qty = (item['quantity'] as num).toDouble();
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [qty, productId],
          );
        }
      }

      if (purchase.supplierId != null && purchase.dueAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance + ? WHERE id = ?',
          [purchase.dueAmount, purchase.supplierId],
        );
      }

      return purchaseId;
    });
  }

  Future<List<Purchase>> getPurchases() async {
    final rows = await db.query('purchases', orderBy: 'id DESC');
    return rows.map((e) => Purchase.fromMap(e)).toList();
  }

  // Stock Transfers
  Future<String> generateNextTransferRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM stock_transfers');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'ST-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<StockTransfer>> getStockTransfers() async {
    final rows = await db.query('stock_transfers', orderBy: 'id DESC');
    return rows.map((e) => StockTransfer.fromMap(e)).toList();
  }

  Future<int> createStockTransfer(StockTransfer transfer) async {
    return await db.transaction((txn) async {
      final transferId = await txn.insert('stock_transfers', transfer.toMap());
      if (transfer.status == 'completed') {
        for (final item in transfer.getItems()) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
        }
      }
      return transferId;
    });
  }

  Future<int> deleteStockTransfer(int id) async {
    return await db.delete('stock_transfers', where: 'id = ?', whereArgs: [id]);
  }

  // Stock Adjustments
  Future<String> generateNextAdjustmentRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM stock_adjustments');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'ADJ-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<StockAdjustment>> getStockAdjustments() async {
    final rows = await db.query('stock_adjustments', orderBy: 'id DESC');
    return rows.map((e) => StockAdjustment.fromMap(e)).toList();
  }

  Future<int> createStockAdjustment(StockAdjustment adjustment) async {
    return await db.transaction((txn) async {
      final adjId = await txn.insert('stock_adjustments', adjustment.toMap());
      for (final item in adjustment.getItems()) {
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return adjId;
    });
  }

  Future<int> deleteStockAdjustment(int id) async {
    return await db.delete('stock_adjustments', where: 'id = ?', whereArgs: [id]);
  }

  // Contact Payments & Due Collections
  Future<String> generateNextPaymentRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM contact_payments');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'PAY-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<int> addContactPayment(ContactPayment payment) async {
    return await db.transaction((txn) async {
      final paymentId = await txn.insert('contact_payments', payment.toMap());

      // Deduct paid amount from contact's outstanding due balance
      await txn.rawUpdate(
        'UPDATE contacts SET balance = balance - ? WHERE id = ?',
        [payment.amount, payment.contactId],
      );

      // If customer paid due in cash, update active register total cash
      if (payment.paymentType == 'receive' && payment.paymentMethod == 'cash') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = \'open\'',
          [payment.amount],
        );
      }

      // Record in payment_transactions table for unified ledger history
      final nowStr = DateTime.now().toIso8601String();
      await txn.insert('payment_transactions', {
        'transaction_type': payment.paymentType == 'receive' ? 'customer_payment' : 'supplier_payment',
        'parent_id': paymentId,
        'contact_id': payment.contactId,
        'contact_name': payment.contactName,
        'payment_method': payment.paymentMethod,
        'amount': payment.amount,
        'account_name': (payment.paymentMethod == 'cash') ? 'Cash Register' : 'Main Bank Account',
        'transaction_date': payment.date.isNotEmpty ? payment.date : nowStr,
        'ref_no': payment.refNo,
        'note': payment.note,
        'created_by': 'Cashier',
        'created_at': nowStr,
      });

      return paymentId;
    });
  }

  Future<List<ContactPayment>> getContactPayments(int contactId) async {
    final rows = await db.query(
      'contact_payments',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'id DESC',
    );
    return rows.map((e) => ContactPayment.fromMap(e)).toList();
  }

  // Expenses
  Future<List<Expense>> getExpenses() async {
    final rows = await db.query('expenses', orderBy: 'id DESC');
    return rows.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return await db.insert('expenses', expense.toMap());
  }

  // Payment Accounts & Fund Transfers
  Future<String> generateNextAccountTransferRef() async {
    final rows = await db.rawQuery('SELECT MAX(id) as max_id FROM account_transfers');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'TRF-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<PaymentAccount>> getPaymentAccounts() async {
    final rows = await db.query('payment_accounts', orderBy: 'id ASC');
    return rows.map((e) => PaymentAccount.fromMap(e)).toList();
  }

  Future<int> addPaymentAccount(PaymentAccount account) async {
    return await db.insert('payment_accounts', account.toMap());
  }

  Future<List<AccountTransfer>> getAccountTransfers() async {
    final rows = await db.query('account_transfers', orderBy: 'id DESC');
    return rows.map((e) => AccountTransfer.fromMap(e)).toList();
  }

  Future<int> transferAccountFunds(AccountTransfer transfer) async {
    return await db.transaction((txn) async {
      final transferId = await txn.insert('account_transfers', transfer.toMap());

      // Deduct from sender account
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
        [transfer.amount, transfer.fromAccountId],
      );

      // Add to receiver account
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE id = ?',
        [transfer.amount, transfer.toAccountId],
      );

      return transferId;
    });
  }

  // Cash Register
  Future<CashRegister?> getActiveRegister() async {
    final rows = await db.query('cash_registers',
        where: 'status = ?', whereArgs: ['open'], limit: 1);
    if (rows.isNotEmpty) return CashRegister.fromMap(rows.first);
    return null;
  }

  Future<void> openRegister(String cashierName, double openingAmount) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await db.insert('cash_registers', {
      'cashier_name': cashierName,
      'opening_amount': openingAmount,
      'closing_amount': 0.0,
      'total_sales_cash': 0.0,
      'total_sales_card': 0.0,
      'total_sales_other': 0.0,
      'status': 'open',
      'opened_at': now,
      'closed_at': null,
      'note': '',
    });
  }

  Future<void> closeRegister(int id, double closingAmount, String note) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await db.update(
      'cash_registers',
      {
        'closing_amount': closingAmount,
        'status': 'closed',
        'closed_at': now,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Dashboard Aggregates
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    // Total Sales & Invoice Due
    final salesResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_invoices,
        SUM(total_amount) as total_sales,
        SUM(total_amount - paid_amount) as total_invoice_due
      FROM sales WHERE sale_status = 'final'
    ''');

    // Total Purchases & Purchase Due
    final purchaseResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_purchases_count,
        SUM(total_amount) as total_purchases,
        SUM(total_amount - paid_amount) as total_purchase_due
      FROM purchases
    ''');

    // Total Expenses
    final expenseResult = await db.rawQuery('''
      SELECT SUM(amount) as total_expenses FROM expenses
    ''');

    // Product Count & Low Stock Count
    final productResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_products,
        SUM(CASE WHEN stock_quantity <= alert_quantity THEN 1 ELSE 0 END) as low_stock_count
      FROM products
    ''');

    // Customer & Supplier count
    final contactResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'customer' THEN 1 ELSE 0 END) as customer_count,
        SUM(CASE WHEN type = 'supplier' THEN 1 ELSE 0 END) as supplier_count
      FROM contacts
    ''');

    final totalSales = (salesResult.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final invoiceDue = (salesResult.first['total_invoice_due'] as num?)?.toDouble() ?? 0.0;
    final totalPurchases = (purchaseResult.first['total_purchases'] as num?)?.toDouble() ?? 0.0;
    final purchaseDue = (purchaseResult.first['total_purchase_due'] as num?)?.toDouble() ?? 0.0;
    final totalExpenses = (expenseResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final totalProducts = (productResult.first['total_products'] as int?) ?? 0;
    final lowStockCount = (productResult.first['low_stock_count'] as int?) ?? 0;
    final customerCount = (contactResult.first['customer_count'] as int?) ?? 0;
    final supplierCount = (contactResult.first['supplier_count'] as int?) ?? 0;

    return {
      'totalSales': totalSales,
      'invoiceDue': invoiceDue,
      'totalPurchases': totalPurchases,
      'purchaseDue': purchaseDue,
      'totalExpenses': totalExpenses,
      'netProfit': totalSales - (totalPurchases * 0.7) - totalExpenses,
      'totalProducts': totalProducts,
      'lowStockCount': lowStockCount,
      'customerCount': customerCount,
      'supplierCount': supplierCount,
    };
  }

  // Phase 7: Profit & Loss and Stock Valuation Reports
  Future<Map<String, dynamic>> getProfitAndLossReport() async {
    final salesRes = await db.rawQuery("SELECT SUM(total_amount) as total_sales FROM sales WHERE sale_status = 'final'");
    final cogsRes = await db.rawQuery("SELECT SUM(si.quantity * p.purchase_price) as cogs FROM sale_items si JOIN products p ON si.product_id = p.id");
    final expRes = await db.rawQuery("SELECT SUM(amount) as total_expenses FROM expenses");
    final adjRecoveryRes = await db.rawQuery("SELECT SUM(recovered_amount) as total_recovered FROM stock_adjustments");

    final totalSales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;
    final cogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? (totalSales * 0.6);
    final totalExpenses = (expRes.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    final recoveredAmount = (adjRecoveryRes.first['total_recovered'] as num?)?.toDouble() ?? 0.0;

    final grossProfit = totalSales - cogs;
    final netProfit = grossProfit - totalExpenses + recoveredAmount;

    return {
      'totalSales': totalSales,
      'cogs': cogs,
      'grossProfit': grossProfit,
      'totalExpenses': totalExpenses,
      'recoveredAmount': recoveredAmount,
      'netProfit': netProfit,
    };
  }

  Future<Map<String, dynamic>> getStockValuationReport() async {
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_items,
        SUM(stock_quantity) as total_quantity,
        SUM(stock_quantity * purchase_price) as stock_value_cost,
        SUM(stock_quantity * selling_price) as stock_value_retail
      FROM products
    ''');

    final totalItems = (res.first['total_items'] as int?) ?? 0;
    final totalQuantity = (res.first['total_quantity'] as num?)?.toDouble() ?? 0.0;
    final stockValueCost = (res.first['stock_value_cost'] as num?)?.toDouble() ?? 0.0;
    final stockValueRetail = (res.first['stock_value_retail'] as num?)?.toDouble() ?? 0.0;
    final potentialProfit = stockValueRetail - stockValueCost;

    return {
      'totalItems': totalItems,
      'totalQuantity': totalQuantity,
      'stockValueCost': stockValueCost,
      'stockValueRetail': stockValueRetail,
      'potentialProfit': potentialProfit,
    };
  }

  // Dead Stock & Expiring Products
  Future<List<Product>> getDeadStockProducts({int daysThreshold = 30}) async {
    final query = '''
      SELECT p.* FROM products p
      WHERE p.stock_quantity > 0
      AND p.id NOT IN (
        SELECT DISTINCT si.product_id FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE datetime(s.created_at) >= datetime('now', '-$daysThreshold days')
      )
      ORDER BY p.stock_quantity DESC
    ''';
    final rows = await db.rawQuery(query);
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> getExpiringProducts({int monthsAhead = 6}) async {
    final all = await getProducts();
    final now = DateTime.now();
    final targetLimit = DateTime(now.year, now.month + monthsAhead, now.day);

    final expiring = <Product>[];
    for (final p in all) {
      if (p.expiryDate != null && p.expiryDate!.trim().isNotEmpty) {
        final expStr = p.expiryDate!.trim();
        DateTime? expDate;
        if (expStr.contains('-')) {
          final parts = expStr.split('-');
          if (parts.length == 2) {
            final p1 = int.tryParse(parts[0]);
            final p2 = int.tryParse(parts[1]);
            if (p1 != null && p2 != null) {
              if (p1 > 12) {
                expDate = DateTime(p1, p2, 28);
              } else {
                expDate = DateTime(p2, p1, 28);
              }
            }
          } else if (parts.length == 3) {
            final y = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final d = int.tryParse(parts[2]);
            if (y != null && m != null && d != null) {
              expDate = DateTime(y, m, d);
            }
          }
        }
        if (expDate != null && expDate.isBefore(targetLimit)) {
          expiring.add(p);
        }
      }
    }
    return expiring;
  }

  // Customer & Supplier shortcuts
  Future<List<Contact>> getCustomers() async => getContacts(type: 'customer');
  Future<List<Contact>> getSuppliers() async => getContacts(type: 'supplier');

  // Restaurant Tables CRUD
  Future<List<Map<String, dynamic>>> getRestaurantTables({String? section}) async {
    final where = (section != null && section != 'All') ? 'section = ?' : null;
    final whereArgs = (section != null && section != 'All') ? [section] : null;
    return await db.query('restaurant_tables', where: where, whereArgs: whereArgs, orderBy: 'id ASC');
  }

  Future<int> addRestaurantTable(Map<String, dynamic> table) async {
    return await db.insert('restaurant_tables', table);
  }

  Future<int> updateRestaurantTable(int id, Map<String, dynamic> table) async {
    return await db.update('restaurant_tables', table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRestaurantTable(int id) async {
    return await db.delete('restaurant_tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRestaurantKotOrders() async {
    return await db.query('restaurant_kot_orders', orderBy: 'id DESC');
  }

  Future<int> addRestaurantKotOrder(Map<String, dynamic> order) async {
    return await db.insert('restaurant_kot_orders', order);
  }

  Future<int> updateRestaurantKotStatus(int id, String status) async {
    return await db.update('restaurant_kot_orders', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRestaurantKotOrder(int id) async {
    return await db.delete('restaurant_kot_orders', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== MODULAR INITIAL DATA SEEDER BY BUSINESS TYPE =====================

  /// Modular Initial Catalog Seeder based strictly on chosen business type
  Future<Map<String, int>> seedInitialDataForBusinessType({
    required String businessType,
    int? pharmacyProductTarget,
  }) async {
    final type = businessType.toLowerCase().trim();
    if (type == 'pharmacy') {
      if (pharmacyProductTarget != null && pharmacyProductTarget > 50) {
        return await seedMedicineAgencyData(
          productTarget: pharmacyProductTarget,
          customerTarget: 1500,
          supplierTarget: 100,
          salesmanTarget: 15,
        );
      }

      final stopwatch = Stopwatch()..start();
      int productsCount = 0;
      int categoriesCount = 0;
      int contactsCount = 0;

      await db.transaction((txn) async {
        final pharmaCategories = [
          'Antibiotics & Anti-Infectives',
          'Analgesics & Pain Relief',
          'Antipyretics & Cold Preparations',
          'Cardiovascular & Neuro',
          'Gastrointestinal & Antiulcerants',
          'Vitamins & Nutraceuticals',
        ];

        for (final cat in pharmaCategories) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          categoriesCount++;
        }

        final pharmaProducts = [
          {
            'name': 'Panadol 500mg Tab',
            'sku': 'MED-001',
            'barcode': '890103000001',
            'category_name': 'Antipyretics & Cold Preparations',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Box (200s)',
            'purchase_price': 498.0,
            'selling_price': 597.6,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'image_color': '#10B981',
            'batch_number': 'BAT-2025-101',
            'expiry_date': '02-2026',
            'bonus_qty': 0.0,
            'pack_size': 200.0,
          },
          {
            'name': 'Amoxil 500mg Cap',
            'sku': 'MED-002',
            'barcode': '890103000002',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Box (100s)',
            'purchase_price': 740.0,
            'selling_price': 890.0,
            'stock_quantity': 40.0,
            'alert_quantity': 10.0,
            'image_color': '#3B82F6',
            'batch_number': 'BAT-2025-102',
            'expiry_date': '04-2026',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Brufen 400mg Tab',
            'sku': 'MED-003',
            'barcode': '890103000003',
            'category_name': 'Analgesics & Pain Relief',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Box (300s)',
            'purchase_price': 1100.0,
            'selling_price': 1320.0,
            'stock_quantity': 35.0,
            'alert_quantity': 10.0,
            'image_color': '#F59E0B',
            'batch_number': 'BRU-9901',
            'expiry_date': '06-2026',
            'bonus_qty': 0.0,
            'pack_size': 300.0,
          },
          {
            'name': 'Augmentin 625mg Tab',
            'sku': 'MED-004',
            'barcode': '890103000004',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Pack (14s)',
            'purchase_price': 380.0,
            'selling_price': 460.0,
            'stock_quantity': 60.0,
            'alert_quantity': 15.0,
            'image_color': '#6366F1',
            'batch_number': 'AUG-4421',
            'expiry_date': '12-2027',
            'bonus_qty': 0.0,
            'pack_size': 14.0,
          },
          {
            'name': 'Risek 20mg Cap',
            'sku': 'MED-005',
            'barcode': '890103000005',
            'category_name': 'Gastrointestinal & Antiulcerants',
            'brand_name': 'Getz Pharma',
            'unit': 'Pack (14s)',
            'purchase_price': 320.0,
            'selling_price': 390.0,
            'stock_quantity': 45.0,
            'alert_quantity': 10.0,
            'image_color': '#059669',
            'batch_number': 'RSK-3110',
            'expiry_date': '11-2027',
            'bonus_qty': 0.0,
            'pack_size': 14.0,
          },
          {
            'name': 'Disprin 300mg Soluble Tab',
            'sku': 'MED-006',
            'barcode': '890103000006',
            'category_name': 'Analgesics & Pain Relief',
            'brand_name': 'Reckitt',
            'unit': 'Box (100s)',
            'purchase_price': 180.0,
            'selling_price': 220.0,
            'stock_quantity': 80.0,
            'alert_quantity': 20.0,
            'image_color': '#DC2626',
            'batch_number': 'DSP-1029',
            'expiry_date': '01-2028',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Arinac Forte Tab',
            'sku': 'MED-007',
            'barcode': '890103000007',
            'category_name': 'Antipyretics & Cold Preparations',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Box (100s)',
            'purchase_price': 720.0,
            'selling_price': 865.0,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'image_color': '#D97706',
            'batch_number': 'ARN-7890',
            'expiry_date': '08-2027',
            'bonus_qty': 0.0,
            'pack_size': 100.0,
          },
          {
            'name': 'Softin 10mg Tab',
            'sku': 'MED-008',
            'barcode': '890103000008',
            'category_name': 'Cardiovascular & Neuro',
            'brand_name': 'Searle Pakistan',
            'unit': 'Pack (10s)',
            'purchase_price': 150.0,
            'selling_price': 190.0,
            'stock_quantity': 55.0,
            'alert_quantity': 10.0,
            'image_color': '#2563EB',
            'batch_number': 'SFT-2291',
            'expiry_date': '03-2028',
            'bonus_qty': 0.0,
            'pack_size': 10.0,
          },
          {
            'name': 'Surbex Z Zinc Multivitamin',
            'sku': 'MED-009',
            'barcode': '890103000009',
            'category_name': 'Vitamins & Nutraceuticals',
            'brand_name': 'Abbott Laboratories',
            'unit': 'Bottle (30s)',
            'purchase_price': 390.0,
            'selling_price': 475.0,
            'stock_quantity': 40.0,
            'alert_quantity': 8.0,
            'image_color': '#7C3AED',
            'batch_number': 'SBX-8812',
            'expiry_date': '05-2028',
            'bonus_qty': 0.0,
            'pack_size': 30.0,
          },
          {
            'name': 'Polyfax Skin Ointment 20g',
            'sku': 'MED-010',
            'barcode': '890103000010',
            'category_name': 'Antibiotics & Anti-Infectives',
            'brand_name': 'GSK (GlaxoSmithKline)',
            'unit': 'Tube',
            'purchase_price': 75.0,
            'selling_price': 95.0,
            'stock_quantity': 65.0,
            'alert_quantity': 12.0,
            'image_color': '#0D9488',
            'batch_number': 'PFX-5543',
            'expiry_date': '09-2027',
            'bonus_qty': 0.0,
            'pack_size': 1.0,
          },
        ];

        for (final p in pharmaProducts) {
          await txn.insert('products', p, conflictAlgorithm: ConflictAlgorithm.replace);
          productsCount++;
        }

        final pharmaContacts = [
          {'name': 'GSK Distribution Hub', 'phone': '+92 300 1110001', 'type': 'supplier'},
          {'name': 'Abbott Wholesale Depot', 'phone': '+92 300 2220002', 'type': 'supplier'},
          {'name': 'Getz Pharma Agency', 'phone': '+92 300 3330003', 'type': 'supplier'},
          {'name': 'Al-Shafa Hospital Pharmacy', 'phone': '+92 300 4440004', 'type': 'customer'},
          {'name': 'Care Chemist & Clinic', 'phone': '+92 300 5550005', 'type': 'customer'},
        ];

        for (final c in pharmaContacts) {
          await txn.insert('contacts', {
            'name': c['name'],
            'phone': c['phone'],
            'type': c['type'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          contactsCount++;
        }
      });

      stopwatch.stop();
      return {
        'products': productsCount,
        'categories': categoriesCount,
        'contacts': contactsCount,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      };
    }

    final stopwatch = Stopwatch()..start();
    int productsCount = 0;
    int categoriesCount = 0;
    int contactsCount = 0;

    await db.transaction((txn) async {
      if (type == 'restaurant' || type == 'cafe') {
        final restaurantCategories = [
          'Appetizers & Starters',
          'Fast Food & Burgers',
          'Pizzas & Pastas',
          'Desi Karahi & BBQ',
          'Continental & Steaks',
          'Beverages & Mocktails',
          'Desserts & Sweets',
        ];

        for (final cat in restaurantCategories) {
          final code = cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Menu Section',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final menuItems = [
          {'name': 'Crispy Zinger Burger', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 320.0, 'sale': 550.0, 'sku': 'BUR-001'},
          {'name': 'Beef Gourmet Cheeseburger', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 420.0, 'sale': 690.0, 'sku': 'BUR-002'},
          {'name': 'Chicken Karahi Special Full', 'cat': 'Desi Karahi & BBQ', 'unit': 'Kg', 'cost': 1100.0, 'sale': 1850.0, 'sku': 'KRH-001'},
          {'name': 'Chicken Karahi Special Half', 'cat': 'Desi Karahi & BBQ', 'unit': 'Half', 'cost': 600.0, 'sale': 990.0, 'sku': 'KRH-002'},
          {'name': 'Chicken Malai Boti (8 Pcs)', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 300.0, 'sale': 520.0, 'sku': 'BBQ-001'},
          {'name': 'Beef Seekh Kabab (4 Pcs)', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 280.0, 'sale': 480.0, 'sku': 'BBQ-002'},
          {'name': 'Chicken Tikka Boti', 'cat': 'Desi Karahi & BBQ', 'unit': 'Plate', 'cost': 240.0, 'sale': 420.0, 'sku': 'BBQ-003'},
          {'name': 'Fajita Passion Pizza Large 13"', 'cat': 'Pizzas & Pastas', 'unit': 'Pc', 'cost': 850.0, 'sale': 1650.0, 'sku': 'PIZ-001'},
          {'name': 'Chicken Alfredo Fettuccine', 'cat': 'Pizzas & Pastas', 'unit': 'Plate', 'cost': 480.0, 'sale': 890.0, 'sku': 'PAS-001'},
          {'name': 'Club Sandwich with Fries', 'cat': 'Fast Food & Burgers', 'unit': 'Pc', 'cost': 340.0, 'sale': 620.0, 'sku': 'SND-001'},
          {'name': 'Grilled Chicken Steak (Mushroom Sauce)', 'cat': 'Continental & Steaks', 'unit': 'Plate', 'cost': 780.0, 'sale': 1450.0, 'sku': 'STK-001'},
          {'name': 'Crispy Chicken Wings (6 Pcs)', 'cat': 'Appetizers & Starters', 'unit': 'Plate', 'cost': 240.0, 'sale': 450.0, 'sku': 'APP-001'},
          {'name': 'Mint Margarita Cooler', 'cat': 'Beverages & Mocktails', 'unit': 'Glass', 'cost': 85.0, 'sale': 280.0, 'sku': 'BEV-001'},
          {'name': 'Fresh Lime Soda', 'cat': 'Beverages & Mocktails', 'unit': 'Glass', 'cost': 50.0, 'sale': 180.0, 'sku': 'BEV-002'},
          {'name': 'Hot Cappuccino', 'cat': 'Beverages & Mocktails', 'unit': 'Cup', 'cost': 110.0, 'sale': 350.0, 'sku': 'BEV-003'},
          {'name': 'Molten Lava Cake with Ice Cream', 'cat': 'Desserts & Sweets', 'unit': 'Plate', 'cost': 220.0, 'sale': 550.0, 'sku': 'DES-001'},
          {'name': 'Roghani Naan', 'cat': 'Desi Karahi & BBQ', 'unit': 'Pc', 'cost': 25.0, 'sale': 60.0, 'sku': 'NAN-001'},
          {'name': 'Mineral Water 1.5L', 'cat': 'Beverages & Mocktails', 'unit': 'Bottle', 'cost': 70.0, 'sale': 120.0, 'sku': 'BEV-004'},
        ];

        for (final m in menuItems) {
          await txn.insert('products', {
            'name': m['name'] as String,
            'sku': m['sku'] as String,
            'barcode': m['sku'] as String,
            'category_name': m['cat'] as String,
            'unit': m['unit'] as String,
            'brand_name': 'In-House Kitchen',
            'purchase_price': m['cost'] as double,
            'selling_price': m['sale'] as double,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        // Seed 8 Restaurant Dining Tables
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
          await txn.insert('restaurant_tables', t);
        }

        // Seed 4 Restaurant Testing KOT Tickets
        try {
          final initialKot = [
            {'kot_no': 'KOT-1048', 'table_name': 'Table 1', 'order_type': 'Dine-In', 'items': '1x Chicken Karahi, 4x Naan, 2x Mint Margarita', 'status': 'Cooking', 'time': '7:42 PM', 'server_name': 'Captain Ali'},
            {'kot_no': 'KOT-1049', 'table_name': 'Lounge VIP 1', 'order_type': 'Dine-In', 'items': '2x Mutton Handi, 1x Biryani Special, 8x Roti, 1x Salad', 'status': 'Ready to Serve', 'time': '7:48 PM', 'server_name': 'Waiter Bilal'},
            {'kot_no': 'KOT-1050', 'table_name': 'Counter 2', 'order_type': 'Takeaway', 'items': '3x Zinger Burgers, 2x Jumbo Fries, 3x Drinks', 'status': 'Preparing', 'time': '7:55 PM', 'server_name': 'Cashier 1'},
            {'kot_no': 'KOT-1051', 'table_name': 'Online Rider', 'order_type': 'Delivery', 'items': '1x Large Pizza, 10x Wings, 1x Garlic Dip', 'status': 'Dispatched', 'time': '7:30 PM', 'server_name': 'Delivery Dispatcher'},
          ];
          for (final k in initialKot) {
            try {
              await txn.insert('restaurant_kot_orders', k);
            } catch (_) {}
          }
        } catch (_) {}

        final restaurantSuppliers = [
          {'name': 'Al-Madina Meat & Poultry Supplier', 'phone': '+92 300 1112233', 'type': 'supplier'},
          {'name': 'Fresh Farm Dairy & Cheese Co.', 'phone': '+92 321 4445566', 'type': 'supplier'},
          {'name': 'Metro Cash & Carry (Raw Ingredients)', 'phone': '+92 333 7778899', 'type': 'supplier'},
          {'name': 'Walk-in Table Diner', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final c in restaurantSuppliers) {
          await txn.insert('contacts', {
            'type': c['type'],
            'name': c['name'],
            'phone': c['phone'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          });
          contactsCount++;
        }
      } else if (type == 'supermarket') {
        final supermarketCats = [
          'Beverages & Soft Drinks',
          'Snacks, Confectionery & Biscuits',
          'Dairy, Eggs & Bakery',
          'Grains, Flour & Cooking Essentials',
          'Household Cleaning & Personal Care',
        ];
        for (final cat in supermarketCats) {
          final code = cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat FMCG Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final supermarketItems = [
          {'name': 'Tapal Danedar Tea 400g', 'cat': 'Beverages & Soft Drinks', 'brand': 'Tapal', 'unit': 'Pack', 'cost': 540.0, 'sale': 620.0, 'sku': '8961011001'},
          {'name': 'Dalda Cooking Oil 1 Litre', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Dalda', 'unit': 'Pouch', 'cost': 480.0, 'sale': 540.0, 'sku': '8961011002'},
          {'name': 'Olpers Milk 1000ml Tetra Pack', 'cat': 'Dairy, Eggs & Bakery', 'brand': 'Engro', 'unit': 'Pack', 'cost': 245.0, 'sale': 280.0, 'sku': '8961011003'},
          {'name': 'Lipton Yellow Label Tea 380g', 'cat': 'Beverages & Soft Drinks', 'brand': 'Unilever', 'unit': 'Pack', 'cost': 510.0, 'sale': 590.0, 'sku': '8961011004'},
          {'name': 'Super Basmati Kernel Rice 5kg', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Guard', 'unit': 'Bag', 'cost': 1550.0, 'sale': 1850.0, 'sku': '8961011005'},
          {'name': 'National Tomato Ketchup 800g Pouch', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'National', 'unit': 'Pouch', 'cost': 340.0, 'sale': 410.0, 'sku': '8961011006'},
          {'name': 'Shan Bombay Biryani Masala 50g', 'cat': 'Grains, Flour & Cooking Essentials', 'brand': 'Shan', 'unit': 'Box', 'cost': 90.0, 'sale': 110.0, 'sku': '8961011007'},
          {'name': 'Pepsi 1.5 Litre Bottle', 'cat': 'Beverages & Soft Drinks', 'brand': 'PepsiCo', 'unit': 'Bottle', 'cost': 145.0, 'sale': 180.0, 'sku': '8961011008'},
          {'name': 'Coca-Cola 1.5 Litre Bottle', 'cat': 'Beverages & Soft Drinks', 'brand': 'Coca-Cola', 'unit': 'Bottle', 'cost': 145.0, 'sale': 180.0, 'sku': '8961011009'},
          {'name': 'Lays Masala Chips Large 65g', 'cat': 'Snacks, Confectionery & Biscuits', 'brand': 'Lays', 'unit': 'Pack', 'cost': 55.0, 'sale': 70.0, 'sku': '8961011010'},
          {'name': 'Head & Shoulders Shampoo 360ml', 'cat': 'Household Cleaning & Personal Care', 'brand': 'P&G', 'unit': 'Bottle', 'cost': 560.0, 'sale': 680.0, 'sku': '8961011011'},
          {'name': 'Surf Excel Detergent Powder 1kg', 'cat': 'Household Cleaning & Personal Care', 'brand': 'Unilever', 'unit': 'Pack', 'cost': 430.0, 'sale': 520.0, 'sku': '8961011012'},
          {'name': 'Dettol Original Soap 125g Pack of 3', 'cat': 'Household Cleaning & Personal Care', 'brand': 'Reckitt', 'unit': 'Pack', 'cost': 310.0, 'sale': 380.0, 'sku': '8961011013'},
        ];

        for (final item in supermarketItems) {
          await txn.insert('products', {
            'name': item['name'] as String,
            'sku': item['sku'] as String,
            'barcode': item['sku'] as String,
            'category_name': item['cat'] as String,
            'brand_name': item['brand'] as String,
            'unit': item['unit'] as String,
            'purchase_price': item['cost'] as double,
            'selling_price': item['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 20.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        final supermarketVendors = [
          {'name': 'Unilever Pakistan Distribution Network', 'phone': '+92 21 111 222 333', 'type': 'supplier'},
          {'name': 'Nestle Pakistan Wholesale', 'phone': '+92 42 111 637 853', 'type': 'supplier'},
          {'name': 'PepsiCo Beverages Regional Hub', 'phone': '+92 51 444 5555', 'type': 'supplier'},
          {'name': 'General Walk-in Shopper', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final v in supermarketVendors) {
          await txn.insert('contacts', {
            'type': v['type'],
            'name': v['name'],
            'phone': v['phone'],
            'balance': 0.0,
            'credit_limit': 500000.0,
          });
          contactsCount++;
        }
      } else if (type == 'repair' || type == 'service') {
        final repairCats = [
          'Mobile Diagnostics & Parts',
          'Laptop & Motherboard Chip-Level',
          'Electronics & Gaming Consoles',
          'Software, OS & Data Recovery',
        ];
        for (final cat in repairCats) {
          await txn.insert('categories', {
            'name': cat,
            'code': cat.substring(0, 3).toUpperCase(),
            'description': '$cat Service Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final repairParts = [
          {'name': 'Samsung Super AMOLED Display Panel', 'sku': 'REP-DISP-01', 'cat': 'Mobile Diagnostics & Parts', 'cost': 12000.0, 'sale': 18500.0},
          {'name': '5000mAh Lithium Polymer Battery Pack', 'sku': 'REP-BATT-02', 'cat': 'Mobile Diagnostics & Parts', 'cost': 1800.0, 'sale': 3500.0},
          {'name': 'Laptop Type-C Power IC & Charging MOSFET', 'sku': 'REP-CHG-03', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 1500.0, 'sale': 4500.0},
          {'name': 'NVMe M.2 512GB High-Speed SSD', 'sku': 'REP-SSD-04', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 5500.0, 'sale': 8000.0},
          {'name': 'CPU & GPU Arctic Thermal Paste Overhaul Service', 'sku': 'REP-SRV-05', 'cat': 'Laptop & Motherboard Chip-Level', 'cost': 300.0, 'sale': 1500.0},
        ];
        for (final rp in repairParts) {
          await txn.insert('products', {
            'name': rp['name'] as String,
            'sku': rp['sku'] as String,
            'barcode': rp['sku'] as String,
            'category_name': rp['cat'] as String,
            'brand_name': 'Original Replacement',
            'unit': 'Pc',
            'purchase_price': rp['cost'] as double,
            'selling_price': rp['sale'] as double,
            'stock_quantity': 25.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }

        // Seed 2 Sample Repair Diagnostic Jobs
        final sampleJobs = [
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
        for (final j in sampleJobs) {
          await txn.insert('repair_jobs', j);
        }

        final repairContacts = [
          {'name': 'Metro Mobile Spare Parts Wholesale', 'phone': '+92 300 8881122', 'type': 'supplier'},
          {'name': 'Laptop Chipsets & Component Importers', 'phone': '+92 321 7773344', 'type': 'supplier'},
          {'name': 'Walk-in Repair Client', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final rc in repairContacts) {
          await txn.insert('contacts', {
            'type': rc['type'],
            'name': rc['name'],
            'phone': rc['phone'],
            'balance': 0.0,
            'credit_limit': 100000.0,
          });
          contactsCount++;
        }
      } else if (type == 'hotel') {
        // Hotel Rooms Inventory
        final sampleRooms = [
          {'room': '101', 'type': 'Standard Single', 'floor': '1st Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Hamza Ali (CNIC: 35201-1234567-1)', 'nights': 2, 'check_in': '20 Oct', 'room_service': 1200.0},
          {'room': '102', 'type': 'Standard Double', 'floor': '1st Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '103', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'occupied', 'guest': 'Dr. Sajjad Malik', 'nights': 3, 'check_in': '19 Oct', 'room_service': 3450.0},
          {'room': '104', 'type': 'Executive Deluxe', 'floor': '1st Floor', 'rate': 9500.0, 'status': 'cleaning', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '201', 'type': 'Presidential Suite', 'floor': '2nd Floor', 'rate': 18000.0, 'status': 'occupied', 'guest': 'Mr. & Mrs. Mansoor', 'nights': 1, 'check_in': '21 Oct', 'room_service': 2800.0},
          {'room': '202', 'type': 'Standard Double', 'floor': '2nd Floor', 'rate': 6500.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '203', 'type': 'Family 2-Bedroom', 'floor': '2nd Floor', 'rate': 12000.0, 'status': 'available', 'guest': '', 'nights': 0, 'check_in': '', 'room_service': 0.0},
          {'room': '204', 'type': 'Standard Single', 'floor': '2nd Floor', 'rate': 4500.0, 'status': 'occupied', 'guest': 'Tariq Jameel', 'nights': 2, 'check_in': '20 Oct', 'room_service': 450.0},
        ];
        for (final r in sampleRooms) {
          await txn.insert('hotel_rooms', r);
        }

        final hotelServices = [
          {'name': 'Continental Breakfast Platter', 'sku': 'HTL-BKT-01', 'cost': 350.0, 'sale': 850.0},
          {'name': 'Executive Laundry & Dry Clean Service', 'sku': 'HTL-LND-02', 'cost': 150.0, 'sale': 450.0},
          {'name': 'Airport VIP Shuttle Dispatch', 'sku': 'HTL-SHT-03', 'cost': 800.0, 'sale': 2500.0},
        ];
        for (final hs in hotelServices) {
          await txn.insert('products', {
            'name': hs['name'] as String,
            'sku': hs['sku'] as String,
            'barcode': hs['sku'] as String,
            'category_name': 'Room Service & Hospitality',
            'brand_name': 'Hotel In-House',
            'unit': 'Service',
            'purchase_price': hs['cost'] as double,
            'selling_price': hs['sale'] as double,
            'stock_quantity': 100.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }
      } else if (type == 'gym') {
        // Seed Gym Members
        final sampleGymMembers = [
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
        for (final gm in sampleGymMembers) {
          await txn.insert('gym_members', gm);
        }

        final gymProducts = [
          {'name': 'Whey Protein Isolate 2kg Chocolate', 'sku': 'GYM-PROT-01', 'cost': 12000.0, 'sale': 16500.0},
          {'name': 'Pre-Workout Energy Booster 30 Servings', 'sku': 'GYM-PRE-02', 'cost': 4500.0, 'sale': 6800.0},
          {'name': 'BCAA Hydration Electrolytes 400g', 'sku': 'GYM-BCAA-03', 'cost': 3200.0, 'sale': 4900.0},
          {'name': 'Stainless Steel Shaker Bottle 700ml', 'sku': 'GYM-SHK-04', 'cost': 850.0, 'sale': 1500.0},
        ];
        for (final gp in gymProducts) {
          await txn.insert('products', {
            'name': gp['name'] as String,
            'sku': gp['sku'] as String,
            'barcode': gp['sku'] as String,
            'category_name': 'Fitness Supplements & Nutrition',
            'brand_name': 'Optimum Performance',
            'unit': 'Tub',
            'purchase_price': gp['cost'] as double,
            'selling_price': gp['sale'] as double,
            'stock_quantity': 20.0,
            'alert_quantity': 4.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }
      } else if (type == 'mobile' || type == 'electronics') {
        final mobileCats = [
          'Smartphones & Flagships',
          'Tablets & iPads',
          'Audio & TWS Earbuds',
          'Fast Chargers & Cables',
          'Protective Glass & Covers',
        ];
        for (final cat in mobileCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final mobileProducts = [
          {'name': 'Apple iPhone 15 Pro Max 256GB', 'cat': 'Smartphones & Flagships', 'brand': 'Apple', 'unit': 'Unit', 'cost': 385000.0, 'sale': 425000.0, 'sku': 'IPH-15PM-256', 'barcode': '195949012345'},
          {'name': 'Samsung Galaxy S24 Ultra 512GB', 'cat': 'Smartphones & Flagships', 'brand': 'Samsung', 'unit': 'Unit', 'cost': 350000.0, 'sale': 389000.0, 'sku': 'SAM-S24U-512', 'barcode': '880609501234'},
          {'name': 'Xiaomi Redmi Note 13 8GB/256GB', 'cat': 'Smartphones & Flagships', 'brand': 'Xiaomi', 'unit': 'Unit', 'cost': 48000.0, 'sale': 54999.0, 'sku': 'RED-N13-256', 'barcode': '694181270123'},
          {'name': 'Apple AirPods Pro (2nd Gen) USB-C', 'cat': 'Audio & TWS Earbuds', 'brand': 'Apple', 'unit': 'Box', 'cost': 62000.0, 'sale': 72000.0, 'sku': 'APP-AIRPOD-P2', 'barcode': '195949567890'},
          {'name': 'Anker 65W GaN III Fast Charger', 'cat': 'Fast Chargers & Cables', 'brand': 'Anker', 'unit': 'Pc', 'cost': 8500.0, 'sale': 11500.0, 'sku': 'ANK-65W-GAN', 'barcode': '084806101234'},
          {'name': 'Baseus 100W PD Type-C Fast Cable', 'cat': 'Fast Chargers & Cables', 'brand': 'Baseus', 'unit': 'Pc', 'cost': 1200.0, 'sale': 2200.0, 'sku': 'BAS-TC-100W', 'barcode': '695315620123'},
        ];

        int iphoneId = 0;
        int samsungId = 0;

        for (final mp in mobileProducts) {
          final pid = await txn.insert('products', {
            'name': mp['name'] as String,
            'sku': mp['sku'] as String,
            'barcode': mp['barcode'] as String,
            'category_name': mp['cat'] as String,
            'brand_name': mp['brand'] as String,
            'unit': mp['unit'] as String,
            'purchase_price': mp['cost'] as double,
            'selling_price': mp['sale'] as double,
            'stock_quantity': 15.0,
            'alert_quantity': 3.0,
            'pack_size': 1.0,
          });
          productsCount++;
          if (mp['sku'] == 'IPH-15PM-256') iphoneId = pid;
          if (mp['sku'] == 'SAM-S24U-512') samsungId = pid;
        }

        // Seed sample IMEI tracking records in product_serials_batches
        if (iphoneId > 0) {
          await txn.insert('product_serials_batches', {
            'product_id': iphoneId,
            'product_name': 'Apple iPhone 15 Pro Max 256GB',
            'sku': 'IPH-15PM-256',
            'serial_number_1': '352948109283741',
            'serial_number_2': '352948109283742',
            'warranty_months': 12,
            'warranty_expiry_date': '2027-10-23',
            'status': 'in_stock',
            'purchase_price': 385000.0,
            'selling_price': 425000.0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
        if (samsungId > 0) {
          await txn.insert('product_serials_batches', {
            'product_id': samsungId,
            'product_name': 'Samsung Galaxy S24 Ultra 512GB',
            'sku': 'SAM-S24U-512',
            'serial_number_1': '867302058192019',
            'serial_number_2': '867302058192020',
            'warranty_months': 12,
            'warranty_expiry_date': '2027-10-23',
            'status': 'in_stock',
            'purchase_price': 350000.0,
            'selling_price': 389000.0,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        final mobileVendors = [
          {'name': 'Airlink Communication Official Dist.', 'phone': '+92 42 111 247 546', 'type': 'supplier'},
          {'name': 'CoreCell Telecom Importers', 'phone': '+92 21 358 1111', 'type': 'supplier'},
          {'name': 'Walk-in Mobile Customer', 'phone': '+92 300 0000000', 'type': 'customer'},
        ];
        for (final v in mobileVendors) {
          await txn.insert('contacts', {
            'type': v['type'],
            'name': v['name'],
            'phone': v['phone'],
            'balance': 0.0,
            'credit_limit': 1000000.0,
          });
          contactsCount++;
        }
      } else if (type == 'solar' || type == 'solar_hardware') {
        final solarCats = [
          'Tier-1 Solar Panels',
          'Solar Hybrid Inverters',
          'Deep Cycle Batteries',
          'DC Breakers & Protection',
          'Solar Cables & Connectors',
          'Complete Solar Bundles',
        ];
        for (final cat in solarCats) {
          final code = cat.substring(0, 3).toUpperCase();
          await txn.insert('categories', {
            'name': cat,
            'code': code,
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }

        final solarProducts = [
          {'name': 'Longi Hi-MO 6 585W Mono Perc Panel', 'cat': 'Tier-1 Solar Panels', 'brand': 'Longi', 'unit': 'Panel', 'cost': 18500.0, 'sale': 22500.0, 'sku': 'SOL-LONGI-585', 'barcode': 'SOL585001'},
          {'name': 'Canadian Solar 550W TopCon Bifacial', 'cat': 'Tier-1 Solar Panels', 'brand': 'Canadian Solar', 'unit': 'Panel', 'cost': 17200.0, 'sale': 21000.0, 'sku': 'SOL-CAN-550', 'barcode': 'SOL550002'},
          {'name': 'Inverex Nitrox 6kW Hybrid IP65 Inverter', 'cat': 'Solar Hybrid Inverters', 'brand': 'Inverex', 'unit': 'Unit', 'cost': 265000.0, 'sale': 295000.0, 'sku': 'INV-NITROX-6K', 'barcode': 'INV600001'},
          {'name': 'Knox Krypton 3.2kW Solar Inverter', 'cat': 'Solar Hybrid Inverters', 'brand': 'Knox', 'unit': 'Unit', 'cost': 110000.0, 'sale': 125000.0, 'sku': 'INV-KNOX-32K', 'barcode': 'INV320002'},
          {'name': 'Phoenix TX-1800 Tall Tubular Battery', 'cat': 'Deep Cycle Batteries', 'brand': 'Phoenix', 'unit': 'Unit', 'cost': 45000.0, 'sale': 53000.0, 'sku': 'BAT-PHOENIX-1800', 'barcode': 'BAT180001'},
          {'name': 'Narada 48V 100Ah Lithium LiFePO4', 'cat': 'Deep Cycle Batteries', 'brand': 'Narada', 'unit': 'Unit', 'cost': 320000.0, 'sale': 365000.0, 'sku': 'BAT-NARADA-LFP', 'barcode': 'BAT4810002'},
          {'name': 'Pakistan Cables 6mm Pure Copper DC Cable', 'cat': 'Solar Cables & Connectors', 'brand': 'Pakistan Cables', 'unit': 'Meter', 'cost': 280.0, 'sale': 360.0, 'sku': 'CBL-SOLAR-6MM', 'barcode': 'CBL6MM001'},
          {'name': 'MC4 Solar Connectors Male/Female Pair', 'cat': 'Solar Cables & Connectors', 'brand': 'Staubli', 'unit': 'Pair', 'cost': 120.0, 'sale': 250.0, 'sku': 'ACC-MC4-PAIR', 'barcode': 'MC4000001'},
          {'name': '6kW Complete Net-Metering Solar Package', 'cat': 'Complete Solar Bundles', 'brand': 'Smart POS Solar', 'unit': 'Package', 'cost': 650000.0, 'sale': 780000.0, 'sku': 'BND-SOLAR-6KW', 'barcode': 'BND6KW001'},
        ];

        int panelId = 0;
        int inverterId = 0;
        int batteryId = 0;
        int bundleId = 0;

        for (final sp in solarProducts) {
          final pid = await txn.insert('products', {
            'name': sp['name'] as String,
            'sku': sp['sku'] as String,
            'barcode': sp['barcode'] as String,
            'category_name': sp['cat'] as String,
            'brand_name': sp['brand'] as String,
            'unit': sp['unit'] as String,
            'purchase_price': sp['cost'] as double,
            'selling_price': sp['sale'] as double,
            'stock_quantity': 25.0,
            'alert_quantity': 5.0,
            'pack_size': 1.0,
          });
          productsCount++;
          if (sp['sku'] == 'SOL-LONGI-585') panelId = pid;
          if (sp['sku'] == 'INV-NITROX-6K') inverterId = pid;
          if (sp['sku'] == 'BAT-PHOENIX-1800') batteryId = pid;
          if (sp['sku'] == 'BND-SOLAR-6KW') bundleId = pid;
        }

        // Seed bundle bill-of-materials in product_bundles
        if (bundleId > 0 && panelId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': panelId,
            'sub_product_name': 'Longi Hi-MO 6 585W Mono Perc Panel',
            'sub_sku': 'SOL-LONGI-585',
            'quantity': 10.0,
            'unit_price': 18500.0,
          });
        }
        if (bundleId > 0 && inverterId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': inverterId,
            'sub_product_name': 'Inverex Nitrox 6kW Hybrid IP65 Inverter',
            'sub_sku': 'INV-NITROX-6K',
            'quantity': 1.0,
            'unit_price': 265000.0,
          });
        }
        if (bundleId > 0 && batteryId > 0) {
          await txn.insert('product_bundles', {
            'parent_product_id': bundleId,
            'sub_product_id': batteryId,
            'sub_product_name': 'Phoenix TX-1800 Tall Tubular Battery',
            'sub_sku': 'BAT-PHOENIX-1800',
            'quantity': 4.0,
            'unit_price': 45000.0,
          });
        }

        final solarVendors = [
          {'name': 'Inverex Solar Power Systems HQ', 'phone': '+92 21 111 468 373', 'type': 'supplier'},
          {'name': 'Longi Solar Pakistan Central Warehouse', 'phone': '+92 42 357 8888', 'type': 'supplier'},
          {'name': 'Green Energy Solutions EPC Contractor', 'phone': '+92 300 5558899', 'type': 'customer'},
        ];
        for (final sv in solarVendors) {
          await txn.insert('contacts', {
            'type': sv['type'],
            'name': sv['name'],
            'phone': sv['phone'],
            'balance': 0.0,
            'credit_limit': 2000000.0,
          });
          contactsCount++;
        }
      } else {
        // General Store / Retail
        final generalCats = ['General Merchandise', 'Accessories', 'Beverages', 'Stationery'];
        for (final cat in generalCats) {
          await txn.insert('categories', {
            'name': cat,
            'code': cat.substring(0, 3).toUpperCase(),
            'description': '$cat Category',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          categoriesCount++;
        }
        final generalProducts = [
          {'name': 'Standard Retail Product A', 'sku': 'GEN-001', 'cat': 'General Merchandise', 'cost': 150.0, 'sale': 220.0},
          {'name': 'Standard Retail Product B', 'sku': 'GEN-002', 'cat': 'General Merchandise', 'cost': 350.0, 'sale': 480.0},
          {'name': 'Executive Ball Pen Pack', 'sku': 'GEN-003', 'cat': 'Stationery', 'cost': 80.0, 'sale': 120.0},
        ];
        for (final gp in generalProducts) {
          await txn.insert('products', {
            'name': gp['name'] as String,
            'sku': gp['sku'] as String,
            'barcode': gp['sku'] as String,
            'category_name': gp['cat'] as String,
            'brand_name': 'General',
            'unit': 'Pc',
            'purchase_price': gp['cost'] as double,
            'selling_price': gp['sale'] as double,
            'stock_quantity': 50.0,
            'alert_quantity': 10.0,
            'pack_size': 1.0,
          });
          productsCount++;
        }
      }
    });    stopwatch.stop();
    return {
      'products': productsCount,
      'categories': categoriesCount,
      'contacts': contactsCount,
      'elapsedMs': stopwatch.elapsedMilliseconds,
    };
  }

// Dashboard Enhanced Analytics
  Future<List<Map<String, dynamic>>> getDailySalesTrend({int days = 7}) async {
    final now = DateTime.now();
    final List<Map<String, dynamic>> results = [];

    final rows = await db.rawQuery('''
      SELECT 
        substr(created_at, 1, 10) as date_str,
        COUNT(*) as order_count,
        SUM(total_amount) as total_revenue
      FROM sales
      WHERE sale_status = 'final'
      GROUP BY substr(created_at, 1, 10)
    ''');

    final Map<String, Map<String, dynamic>> byDate = {};
    for (final r in rows) {
      final d = r['date_str'] as String?;
      if (d != null) byDate[d] = r;
    }

    final df = DateFormat('yyyy-MM-dd');
    for (int i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = df.format(day);
      if (byDate.containsKey(key)) {
        results.add({
          'date': key,
          'dayLabel': DateFormat('E d').format(day),
          'orderCount': (byDate[key]!['order_count'] as int?) ?? 0,
          'revenue': (byDate[key]!['total_revenue'] as num?)?.toDouble() ?? 0.0,
        });
      } else {
        results.add({
          'date': key,
          'dayLabel': DateFormat('E d').format(day),
          'orderCount': 0,
          'revenue': 0.0,
        });
      }
    }

    return results;
  }

  Future<Map<String, double>> getPaymentMethodBreakdown() async {
    final rows = await db.rawQuery('''
      SELECT 
        payment_method,
        SUM(total_amount) as total_amount
      FROM sales
      WHERE sale_status = 'final'
      GROUP BY payment_method
    ''');

    final Map<String, double> result = {};
    for (final r in rows) {
      final rawMethod = (r['payment_method'] as String?)?.trim();
      final method = (rawMethod != null && rawMethod.isNotEmpty) ? rawMethod.toUpperCase() : 'CASH';
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      result[method] = (result[method] ?? 0.0) + total;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 5}) async {
    final rows = await db.rawQuery('''
      SELECT 
        si.product_name,
        SUM(si.quantity) as total_qty,
        SUM(si.subtotal) as total_revenue
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.sale_status = 'final'
      GROUP BY si.product_id, si.product_name
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [limit]);

    return rows.map((r) => {
      'name': (r['product_name'] as String?) ?? 'Unknown Item',
      'qty': (r['total_qty'] as num?)?.toDouble() ?? 0.0,
      'revenue': (r['total_revenue'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }

  Future<Map<String, dynamic>> getTodaySalesMetrics() async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await db.rawQuery('''
      SELECT 
        COUNT(*) as today_orders,
        SUM(total_amount) as today_sales,
        SUM(paid_amount) as today_cash
      FROM sales
      WHERE sale_status = 'final' AND substr(created_at, 1, 10) = ?
    ''', [todayStr]);

    final orders = (res.first['today_orders'] as int?) ?? 0;
    final sales = (res.first['today_sales'] as num?)?.toDouble() ?? 0.0;
    final cash = (res.first['today_cash'] as num?)?.toDouble() ?? 0.0;

    return {
      'todayOrders': orders,
      'todaySales': sales,
      'todayCash': cash,
    };
  }

// ===================== USERS & AUTH =====================
  Future<List<User>> getUsers() async {
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map((r) => User.fromMap(r)).toList();
  }

  Future<int> addUser(User user) async {
    return await db.insert('users', user.toMap());
  }

  Future<void> updateUser(User user) async {
    if (user.id != null) {
      await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
    }
  }

  Future<void> deleteUser(int id) async {
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== SALES RETURNS =====================
  Future<List<SaleReturn>> getSaleReturns() async {
    final rows = await db.query('sale_returns', orderBy: 'id DESC');
    final List<SaleReturn> list = [];
    for (final r in rows) {
      final retId = r['id'] as int;
      final itemRows = await db.query('sale_return_items', where: 'return_id = ?', whereArgs: [retId]);
      final items = itemRows.map((ir) => SaleReturnItem.fromMap(ir)).toList();
      list.add(SaleReturn.fromMap(r, items: items));
    }
    return list;
  }

  Future<String> generateNextSaleReturnRef() async {
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM sale_returns');
    final count = ((res.first['c'] as int?) ?? 0) + 1;
    return 'SR-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  Future<int> addSaleReturn(SaleReturn sr) async {
    return await db.transaction((txn) async {
      final id = await txn.insert('sale_returns', sr.toMap());
      for (final item in sr.items) {
        final itemMap = item.toMap();
        itemMap['return_id'] = id;
        await txn.insert('sale_return_items', itemMap);

        // Restock returned product
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // If customer balance adjustment
      if (sr.customerId != null && sr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [sr.refundAmount, sr.customerId],
        );
      }
      return id;
    });
  }

  // ===================== PURCHASE RETURNS =====================
  Future<List<PurchaseReturn>> getPurchaseReturns() async {
    final rows = await db.query('purchase_returns', orderBy: 'id DESC');
    final List<PurchaseReturn> list = [];
    for (final r in rows) {
      final retId = r['id'] as int;
      final itemRows = await db.query('purchase_return_items', where: 'return_id = ?', whereArgs: [retId]);
      final items = itemRows.map((ir) => PurchaseReturnItem.fromMap(ir)).toList();
      list.add(PurchaseReturn.fromMap(r, items: items));
    }
    return list;
  }

  Future<String> generateNextPurchaseReturnRef() async {
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM purchase_returns');
    final count = ((res.first['c'] as int?) ?? 0) + 1;
    return 'PR-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
  }

  Future<int> addPurchaseReturn(PurchaseReturn pr) async {
    return await db.transaction((txn) async {
      final id = await txn.insert('purchase_returns', pr.toMap());
      for (final item in pr.items) {
        final itemMap = item.toMap();
        itemMap['return_id'] = id;
        await txn.insert('purchase_return_items', itemMap);

        // Deduct returned quantity from stock
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = MAX(0, stock_quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // Deduct payable to supplier
      if (pr.supplierId != null && pr.refundAmount > 0) {
        await txn.rawUpdate(
          'UPDATE contacts SET balance = balance - ? WHERE id = ?',
          [pr.refundAmount, pr.supplierId],
        );
      }
      return id;
    });
  }

  // ===================== ANNUAL CLOSING =====================
  Future<List<FinancialYear>> getFinancialYears() async {
    final rows = await db.query('financial_years', orderBy: 'id DESC');
    return rows.map((r) => FinancialYear.fromMap(r)).toList();
  }

  Future<int> closeFinancialYear(FinancialYear fy) async {
    return await db.transaction((txn) async {
      final id = await txn.insert('financial_years', fy.toMap());

      // Advance start_date in business settings
      final nextYear = DateTime.now().year + 1;
      await txn.rawUpdate(
        "UPDATE business_settings SET start_date = '01/01/$nextYear'",
      );
      return id;
    });
  }

  // ===================== PURGE & MEDICINE DATA SEEDING =====================
  Future<void> purgeAllBusinessData() async {
    try {
      await db.execute('PRAGMA foreign_keys = OFF;');
    } catch (_) {}

    await db.transaction((txn) async {
      final tables = [
        'sale_return_items',
        'sale_returns',
        'purchase_return_items',
        'purchase_returns',
        'sale_items',
        'sales',
        'purchase_items',
        'purchases',
        'payment_transactions',
        'product_serials_batches',
        'product_bundles',
        'variations',
        'products',
        'expenses',
        'stock_transfers',
        'stock_adjustments',
        'contact_payments',
        'account_transfers',
        'contacts',
        'categories',
        'brands',
        'units',
        'tax_rates',
        'restaurant_kot_orders',
        'restaurant_tables',
        'gym_members',
        'hotel_rooms',
        'repair_jobs',
        'cash_registers',
        'audit_logs',
        'sync_queue',
        'discounts',
        'warranty_claims',
        'printer_configs',
      ];
      for (final table in tables) {
        try {
          await txn.delete(table);
        } catch (_) {}
      }
      try {
        await txn.delete('sqlite_sequence');
      } catch (_) {}
    });

    try {
      await db.execute('PRAGMA foreign_keys = ON;');
    } catch (_) {}

    onSyncQueueUpdated?.call();
  }

  /// Complete Factory Reset: Wipes all business data, resets settings to unconfigured,
  /// and prepares system for a clean relaunch of SetupWizardScreen for testing new businesses.
  Future<BusinessSettings> factoryResetForNewBusiness() async {
    await purgeAllBusinessData();

    final resetSettings = BusinessSettings(
      id: 1,
      businessName: 'Smart POS System',
      branchName: 'Main Branch HQ',
      currencySymbol: 'Rs',
      currencyCode: 'PKR',
      defaultTaxRate: 5.0,
      phone: '',
      email: '',
      address: '',
      invoicePrefix: 'INV-',
      receiptFooter: '',
      purchaseKey: '',
      businessType: 'general',
      isConfigured: false,
      industryPresets: '',
      enabledModules: '',
      primaryDbType: 'mysql',
      dbHost: 'localhost',
      dbPort: 3306,
      dbName: 'smartpos',
      dbUser: 'root',
      dbPassword: '',
      syncMode: 'offline',
    );
    await updateBusinessSettings(resetSettings);

    try {
      final existingUsers = await getUsers();
      if (existingUsers.isEmpty) {
        await addUser(User(
          name: 'Super Administrator',
          username: 'superadmin',
          password: AuthService.hashPassword('password'),
          email: 'admin@smartpos.com',
          role: 'superadmin',
          status: 'active',
          branchId: 1,
          branchName: 'Main Branch HQ',
        ));
      }
    } catch (_) {}

    return resetSettings;
  }

  /// Bulk Seed 2,500 Medicines, 1,500 Customers, 100 Suppliers, 15 Salesmen
  Future<Map<String, int>> seedMedicineAgencyData({
    int productTarget = 2500,
    int customerTarget = 1500,
    int supplierTarget = 100,
    int salesmanTarget = 15,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Medicine Companies / Brands (Pharma Manufacturers)
    final pharmaBrands = [
      'Getz Pharma', 'Searle Pakistan', 'Abbott Laboratories', 'GSK Pakistan',
      'Ferozsons Laboratories', 'Sami Pharmaceuticals', 'Hilton Pharma',
      'Martin Dow Marker', 'Highnoon Laboratories', 'Bosch Pharmaceuticals',
      'Barrett Hodgson', 'Atco Laboratories', 'Sanofi-Aventis', 'Pfizer',
      'Novartis', 'Bayer HealthCare', 'CCL Pharmaceuticals', 'PharmEvo',
      'Macter International', 'Horizon Pharmaceuticals', 'Platinum Pharmaceuticals',
      'Shaigan Pharmaceuticals', 'Genix Pharma', 'Werrick Pharmaceuticals',
      'Zafa Pharmaceuticals', 'AGP Limited', 'Standpharm Pakistan',
      'Scotmann Pharmaceuticals', 'Brooks Pharma', 'Aspin Pharma'
    ];

    // 2. Medicine Categories & Salt Formulations
    final pharmaCategories = [
      'Antibiotics & Antimicrobials',
      'Analgesics, Pain & NSAIDs',
      'Antipyretics & Cold Preparations',
      'Cardiovascular & Antihypertensives',
      'Gastrointestinal & Antiulcerants',
      'Antidiabetic & Endocrinology',
      'Antihistamines & Anti-allergic',
      'Respiratory, Asthma & Inhalers',
      'Vitamins, Minerals & Supplements',
      'Dermatological & Topical Creams',
      'Ophthalmic & ENT Drops',
      'Neuro-Psychiatric & Sedatives',
      'Injectables & IV Infusions',
      'Pediatric Syrups & Drops',
      'Medical Disposables & Surgical'
    ];

    final medicineBases = [
      {'name': 'Panadol 500mg Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (200s)', 'cost': 600.0, 'sale': 720.0, 'pack': 200.0},
      {'name': 'Panadol Extra Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (100s)', 'cost': 450.0, 'sale': 540.0, 'pack': 100.0},
      {'name': 'Augmentin 625mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (14s)', 'cost': 380.0, 'sale': 460.0, 'pack': 14.0},
      {'name': 'Augmentin 1g Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (14s)', 'cost': 580.0, 'sale': 695.0, 'pack': 14.0},
      {'name': 'Augmentin 156mg Syrup 60ml', 'cat': 'Pediatric Syrups & Drops', 'unit': 'Bottle', 'cost': 160.0, 'sale': 195.0, 'pack': 1.0},
      {'name': 'Brufen 400mg Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (300s)', 'cost': 1100.0, 'sale': 1320.0, 'pack': 300.0},
      {'name': 'Brufen DS Syrup 120ml', 'cat': 'Pediatric Syrups & Drops', 'unit': 'Bottle', 'cost': 95.0, 'sale': 118.0, 'pack': 1.0},
      {'name': 'Flygal 400mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Box (200s)', 'cost': 520.0, 'sale': 640.0, 'pack': 200.0},
      {'name': 'Risek 20mg Cap (Omeprazole)', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Pack (14s)', 'cost': 320.0, 'sale': 390.0, 'pack': 14.0},
      {'name': 'Risek 40mg Cap (Omeprazole)', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Pack (14s)', 'cost': 540.0, 'sale': 650.0, 'pack': 14.0},
      {'name': 'Risek 40mg IV Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Vial', 'cost': 390.0, 'sale': 480.0, 'pack': 1.0},
      {'name': 'Arinac 200/30mg Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (100s)', 'cost': 480.0, 'sale': 580.0, 'pack': 100.0},
      {'name': 'Arinac Forte Tab', 'cat': 'Antipyretics & Cold Preparations', 'unit': 'Box (100s)', 'cost': 720.0, 'sale': 865.0, 'pack': 100.0},
      {'name': 'Cac-1000 Plus Effervescent Tab', 'cat': 'Vitamins, Minerals & Supplements', 'unit': 'Tube (10s)', 'cost': 240.0, 'sale': 295.0, 'pack': 10.0},
      {'name': 'Surbex-Z High Potency Tab', 'cat': 'Vitamins, Minerals & Supplements', 'unit': 'Bottle (30s)', 'cost': 390.0, 'sale': 475.0, 'pack': 30.0},
      {'name': 'Rigix 10mg Tab (Cetirizine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (30s)', 'cost': 180.0, 'sale': 225.0, 'pack': 30.0},
      {'name': 'T-Day 5mg Tab (Levocetirizine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (10s)', 'cost': 140.0, 'sale': 175.0, 'pack': 10.0},
      {'name': 'Gravinate 50mg Tab', 'cat': 'Gastrointestinal & Antiulcerants', 'unit': 'Box (100s)', 'cost': 310.0, 'sale': 380.0, 'pack': 100.0},
      {'name': 'Amoxil 500mg Cap', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Box (100s)', 'cost': 740.0, 'sale': 890.0, 'pack': 100.0},
      {'name': 'Ciproxin 500mg Tab', 'cat': 'Antibiotics & Antimicrobials', 'unit': 'Pack (10s)', 'cost': 320.0, 'sale': 395.0, 'pack': 10.0},
      {'name': 'Loprin 75mg Tab (Aspirin)', 'cat': 'Cardiovascular & Antihypertensives', 'unit': 'Box (30s)', 'cost': 95.0, 'sale': 120.0, 'pack': 30.0},
      {'name': 'Norvasc 5mg Tab (Amlodipine)', 'cat': 'Cardiovascular & Antihypertensives', 'unit': 'Pack (30s)', 'cost': 450.0, 'sale': 540.0, 'pack': 30.0},
      {'name': 'Softin 10mg Tab (Loratadine)', 'cat': 'Antihistamines & Anti-allergic', 'unit': 'Pack (10s)', 'cost': 150.0, 'sale': 185.0, 'pack': 10.0},
      {'name': 'Ponstan 500mg Forte Tab', 'cat': 'Analgesics, Pain & NSAIDs', 'unit': 'Box (250s)', 'cost': 850.0, 'sale': 1050.0, 'pack': 250.0},
      {'name': 'Xanax 0.5mg Tab (Alprazolam)', 'cat': 'Neuro-Psychiatric & Sedatives', 'unit': 'Pack (30s)', 'cost': 260.0, 'sale': 320.0, 'pack': 30.0},
      {'name': 'Lexotanil 3mg Tab (Bromazepam)', 'cat': 'Neuro-Psychiatric & Sedatives', 'unit': 'Pack (30s)', 'cost': 310.0, 'sale': 380.0, 'pack': 30.0},
      {'name': 'Betnesol Oral Drops 15ml', 'cat': 'Ophthalmic & ENT Drops', 'unit': 'Bottle', 'cost': 75.0, 'sale': 95.0, 'pack': 1.0},
      {'name': 'Polyfax Eye Ointment 6g', 'cat': 'Ophthalmic & ENT Drops', 'unit': 'Tube', 'cost': 85.0, 'sale': 105.0, 'pack': 1.0},
      {'name': 'Polyfax Plus Skin Ointment 20g', 'cat': 'Dermatological & Topical Creams', 'unit': 'Tube', 'cost': 140.0, 'sale': 175.0, 'pack': 1.0},
      {'name': 'Fucidin Cream 15g', 'cat': 'Dermatological & Topical Creams', 'unit': 'Tube', 'cost': 220.0, 'sale': 270.0, 'pack': 1.0},
      {'name': 'Ventolin Inhaler 100mcg', 'cat': 'Respiratory, Asthma & Inhalers', 'unit': 'Inhaler', 'cost': 380.0, 'sale': 460.0, 'pack': 1.0},
      {'name': 'Seretide Evohaler 25/125mcg', 'cat': 'Respiratory, Asthma & Inhalers', 'unit': 'Inhaler', 'cost': 1350.0, 'sale': 1620.0, 'pack': 1.0},
      {'name': 'Glucophage 500mg Tab', 'cat': 'Antidiabetic & Endocrinology', 'unit': 'Box (50s)', 'cost': 290.0, 'sale': 355.0, 'pack': 50.0},
      {'name': 'Getformin 850mg Tab', 'cat': 'Antidiabetic & Endocrinology', 'unit': 'Box (30s)', 'cost': 210.0, 'sale': 260.0, 'pack': 30.0},
      {'name': 'Gravibinan 1ml Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Ampoule', 'cost': 340.0, 'sale': 420.0, 'pack': 1.0},
      {'name': 'Neurobion 3ml Inj', 'cat': 'Injectables & IV Infusions', 'unit': 'Ampoule', 'cost': 110.0, 'sale': 138.0, 'pack': 1.0},
      {'name': 'Clexane 40mg Prefilled Syringe', 'cat': 'Injectables & IV Infusions', 'unit': 'Syringe', 'cost': 1150.0, 'sale': 1390.0, 'pack': 1.0},
      {'name': 'IV Cannula 20G / 22G / 24G', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (50s)', 'cost': 1200.0, 'sale': 1550.0, 'pack': 50.0},
      {'name': 'Disposable Syringes 5ml BD', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (100s)', 'cost': 850.0, 'sale': 1100.0, 'pack': 100.0},
      {'name': 'Surgical Face Masks 3-Ply', 'cat': 'Medical Disposables & Surgical', 'unit': 'Box (50s)', 'cost': 220.0, 'sale': 300.0, 'pack': 50.0},
    ];

    final colors = ['#004EEB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4', '#EC4899', '#3B82F6'];

    // Execute in transaction
    await db.transaction((txn) async {
      // 0. Seed Categories
      for (final cat in pharmaCategories) {
        await txn.insert('categories', {
          'name': cat,
          'code': cat.length >= 3 ? cat.substring(0, 3).toUpperCase() : cat.toUpperCase(),
          'description': '$cat Category',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // A. Seed 100 Suppliers (Pharma Distributors)
      final supplierCities = ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Peshawar', 'Multan', 'Faisalabad', 'Hyderabad'];
      for (int i = 1; i <= supplierTarget; i++) {
        final bName = pharmaBrands[(i - 1) % pharmaBrands.length];
        final city = supplierCities[(i - 1) % supplierCities.length];
        await txn.insert('contacts', {
          'type': 'supplier',
          'name': 'Distributor Rep $i (${bName.split(" ").first})',
          'business_name': '$bName Distribution Network Ltd',
          'phone': '+92 321 000${(1000 + i)}',
          'email': 'supply$i@${bName.toLowerCase().replaceAll(" ", "").replaceAll("-", "")}.com',
          'address': 'Plot ${10 + i}, Medicine Wholesale Market, $city',
          'credit_limit': 500000.0,
          'balance': (i % 3 == 0) ? (15000.0 + (i * 1200.0)) : 0.0,
        });
      }

      // B. Seed 1,500 Customers (Pharmacies, Hospitals, Clinics)
      final pharmacyTypes = ['Medical Store & Pharmacy', 'Community Pharmacy', 'Hospital Pharmacy', 'General Clinic', 'Care Chemist'];
      const batchSize = 300;
      for (int b = 0; b < customerTarget; b += batchSize) {
        final batch = txn.batch();
        final end = (b + batchSize < customerTarget) ? b + batchSize : customerTarget;
        for (int i = b + 1; i <= end; i++) {
          final pType = pharmacyTypes[(i - 1) % pharmacyTypes.length];
          final city = supplierCities[(i - 1) % supplierCities.length];
          final due = (i % 4 == 0) ? (2500.0 + (i * 35.0)) : 0.0;
          batch.insert('contacts', {
            'type': 'customer',
            'name': 'Client Pharmacy #$i',
            'business_name': 'Al-Shafa $pType #$i',
            'phone': '+92 300 999${(1000 + i)}',
            'email': 'pharmacy$i@gmail.com',
            'address': 'Shop ${5 + (i % 80)}, Main Market, $city',
            'credit_limit': 50000.0,
            'balance': due,
          });
        }
        await batch.commit(noResult: true);
      }

      // C. Seed 2,500 Products (Pharmaceutical Catalog with generic variants, dosages & expiries)
      for (int b = 0; b < productTarget; b += batchSize) {
        final batch = txn.batch();
        final end = (b + batchSize < productTarget) ? b + batchSize : productTarget;
        for (int i = b + 1; i <= end; i++) {
          final base = medicineBases[(i - 1) % medicineBases.length];
          final brand = pharmaBrands[(i - 1) % pharmaBrands.length];
          final color = colors[i % colors.length];
          final sku = 'MED-${i.toString().padLeft(5, "0")}';
          final barcode = '8964000${i.toString().padLeft(6, "0")}';
          final batchNo = 'BAT-${2024 + (i % 3)}-${(100 + (i % 900))}';

          // Expiry dates between 2025 and 2028
          final expMonth = ((i % 12) + 1).toString().padLeft(2, '0');
          final expYear = (2025 + (i % 4)).toString();
          final expiryStr = '$expMonth-$expYear';

          final baseCost = (base['cost'] as double) * (0.8 + ((i % 15) * 0.03));
          final baseSale = (base['sale'] as double) * (0.8 + ((i % 15) * 0.03));

          final nameSuffix = (i > medicineBases.length) ? ' [Dosage #$i]' : '';

          batch.insert('products', {
            'name': '${base['name']}$nameSuffix',
            'sku': sku,
            'barcode': barcode,
            'category_name': base['cat'] as String,
            'brand_name': brand,
            'unit': base['unit'] as String,
            'purchase_price': double.parse(baseCost.toStringAsFixed(2)),
            'selling_price': double.parse(baseSale.toStringAsFixed(2)),
            'stock_quantity': 50.0 + (i % 250),
            'alert_quantity': 15.0,
            'image_color': color,
            'batch_number': batchNo,
            'expiry_date': expiryStr,
            'bonus_qty': (i % 10 == 0) ? 1.0 : 0.0,
            'pack_size': base['pack'] as double,
          });
        }
        await batch.commit(noResult: true);
      }

      // D. Seed 15 Salesmen if not already present
      for (int i = 1; i <= salesmanTarget; i++) {
        final existing = await txn.rawQuery("SELECT id FROM users WHERE username = 'salesman$i'");
        if (existing.isEmpty) {
          await txn.insert('users', {
            'name': 'Field Salesman #$i',
            'username': 'salesman$i',
            'password': 'password',
            'email': 'salesman$i@smartpos.com',
            'role': 'salesman',
            'status': 'active',
            'branch_id': 1,
            'branch_name': 'Main Branch HQ',
            'phone': '+92 311 00000${i.toString().padLeft(2, '0')}',
          });
        }
      }
    });

    stopwatch.stop();
    return {
      'products': productTarget,
      'customers': customerTarget,
      'suppliers': supplierTarget,
      'salesmen': salesmanTarget,
      'elapsedMs': stopwatch.elapsedMilliseconds,
    };
  }

  /// High Performance Transaction Batch Generator for load testing
  Future<Map<String, dynamic>> benchmarkTransactions({int count = 10000}) async {
    final stopwatch = Stopwatch()..start();
    final f = DateFormat('yyyy-MM-dd HH:mm:ss');
    final now = DateTime.now();

    final customers = await db.query('contacts', where: "type = 'customer'", limit: 50);
    final products = await db.query('products', limit: 50);

    if (products.isEmpty) {
      return {
        'count': 0,
        'transactions_inserted': 0,
        'elapsedMs': 0,
        'elapsed_ms': 0,
        'speedPerSec': 0,
        'transactions_per_sec': 0,
      };
    }

    const batchSize = 1000;
    int insertedSales = 0;

    await db.transaction((txn) async {
      for (int b = 0; b < count; b += batchSize) {
        final saleBatch = txn.batch();
        final currentChunk = (b + batchSize < count) ? batchSize : (count - b);

        for (int i = 0; i < currentChunk; i++) {
          final globalIndex = b + i + 1;
          final cust = customers.isNotEmpty ? customers[globalIndex % customers.length] : null;
          final prod = products[globalIndex % products.length];

          final qty = 1.0 + (globalIndex % 4);
          final price = (prod['selling_price'] as num?)?.toDouble() ?? 100.0;
          final total = qty * price;
          final dateStr = f.format(now.subtract(Duration(minutes: globalIndex * 2)));

          saleBatch.insert('sales', {
            'invoice_no': 'LOAD-${100000 + globalIndex}',
            'customer_id': cust?['id'] ?? 1,
            'customer_name': cust?['name'] ?? 'Walk-in Customer',
            'total_amount': total,
            'tax_amount': 0.0,
            'discount_amount': 0.0,
            'paid_amount': total,
            'due_amount': 0.0,
            'payment_status': 'paid',
            'payment_method': (globalIndex % 2 == 0) ? 'cash' : 'card',
            'sale_status': 'final',
            'created_at': dateStr,
            'cash_register_id': 1,
          });
        }
        await saleBatch.commit(noResult: true);
        insertedSales += currentChunk;
      }
    });

    stopwatch.stop();
    final speed = insertedSales / (stopwatch.elapsedMilliseconds / 1000.0);

    return {
      'count': insertedSales,
      'transactions_inserted': insertedSales,
      'elapsedMs': stopwatch.elapsedMilliseconds,
      'elapsed_ms': stopwatch.elapsedMilliseconds,
      'speedPerSec': speed.round(),
      'transactions_per_sec': speed.round(),
    };
  }

// ===================== SYNC QUEUE OPERATIONS (MYSQL & LARAVEL) =====================

  Future<int> queueSyncItem({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    return await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload_json': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 100}) async {
    return await db.query(
      'sync_queue',
      where: "status = 'pending'",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markSyncItemsDone(List<int> ids) async {
    if (ids.isEmpty) return;
    final nowIso = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'sync_queue',
        {'status': 'synced', 'synced_at': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSyncItemFailed(int id, String error) async {
    await db.execute('''
      UPDATE sync_queue 
      SET status = 'failed', 
          retry_count = retry_count + 1, 
          last_error = ? 
      WHERE id = ?
    ''', [error, id]);
  }

  Future<int> getPendingSyncCount() async {
    final res = await db.rawQuery("SELECT COUNT(*) as c FROM sync_queue WHERE status = 'pending'");
    return (res.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentSyncLogs({int limit = 50}) async {
    return await db.query(
      'sync_queue',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<void> clearCompletedSyncLogs() async {
    await db.delete('sync_queue', where: "status = 'synced'");
  }

// ===================== INDUSTRY MODULE OPERATIONS (DYNAMIC SQLITE) =====================

  // Gym & Fitness Members
  Future<List<Map<String, dynamic>>> getGymMembers({String? status}) async {
    final where = (status != null && status != 'All') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'All') ? [status] : null;
    return await db.query(
      'gym_members',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> addGymMember(Map<String, dynamic> member) async {
    return await db.insert('gym_members', member);
  }

  Future<int> updateGymMember(int id, Map<String, dynamic> member) async {
    return await db.update('gym_members', member, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGymMember(int id) async {
    return await db.delete('gym_members', where: 'id = ?', whereArgs: [id]);
  }

  // Hotel & Guest Rooms
  Future<List<Map<String, dynamic>>> getHotelRooms({String? status}) async {
    final where = (status != null && status != 'all') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'all') ? [status] : null;
    return await db.query(
      'hotel_rooms',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'room ASC',
    );
  }

  Future<int> addHotelRoom(Map<String, dynamic> room) async {
    return await db.insert('hotel_rooms', room);
  }

  Future<int> updateHotelRoom(int id, Map<String, dynamic> room) async {
    return await db.update('hotel_rooms', room, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHotelRoom(int id) async {
    return await db.delete('hotel_rooms', where: 'id = ?', whereArgs: [id]);
  }

  // Repair & Service Jobs
  Future<List<Map<String, dynamic>>> getRepairJobs({String? status}) async {
    final where = (status != null && status != 'All') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'All') ? [status] : null;
    return await db.query(
      'repair_jobs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> addRepairJob(Map<String, dynamic> job) async {
    return await db.insert('repair_jobs', job);
  }

  Future<int> updateRepairJob(int id, Map<String, dynamic> job) async {
    return await db.update('repair_jobs', job, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRepairJob(int id) async {
    return await db.delete('repair_jobs', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== PAYMENT TRANSACTIONS (SPLIT & DUE RECOVERIES) =====================

  Future<int> addPaymentTransaction(PaymentTransaction transaction) async {
    final id = await db.insert('payment_transactions', transaction.toMap());
    try {
      await queueSyncItem(
        entityType: 'payment_transaction',
        entityId: id.toString(),
        action: 'create',
        payload: transaction.toMap(),
      );
    } catch (_) {}
    return id;
  }

  Future<List<PaymentTransaction>> getPaymentTransactionsForSale(int saleId) async {
    final res = await db.query(
      'payment_transactions',
      where: "transaction_type = 'sale' AND parent_id = ?",
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<List<PaymentTransaction>> getPaymentTransactionsForPurchase(int purchaseId) async {
    final res = await db.query(
      'payment_transactions',
      where: "transaction_type = 'purchase' AND parent_id = ?",
      whereArgs: [purchaseId],
      orderBy: 'id ASC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<List<PaymentTransaction>> getPaymentTransactionsForContact(int contactId) async {
    final res = await db.query(
      'payment_transactions',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'id DESC',
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<List<PaymentTransaction>> getAllPaymentTransactions({int limit = 100}) async {
    final res = await db.query(
      'payment_transactions',
      orderBy: 'id DESC',
      limit: limit,
    );
    return res.map((m) => PaymentTransaction.fromMap(m)).toList();
  }

  Future<int> deletePaymentTransaction(int id) async {
    return await db.delete('payment_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== SERIAL NUMBERS & BATCHES (IMEI / EXPIRY FIFO) =====================

  Future<int> addProductSerialBatch(ProductSerialBatch item) async {
    return await db.insert('product_serials_batches', item.toMap());
  }

  Future<List<ProductSerialBatch>> getProductSerialsBatches(int productId, {String? status}) async {
    final where = (status != null && status != 'All')
        ? 'product_id = ? AND status = ?'
        : 'product_id = ?';
    final whereArgs = (status != null && status != 'All')
        ? [productId, status]
        : [productId];

    final res = await db.query(
      'product_serials_batches',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id ASC',
    );
    return res.map((m) => ProductSerialBatch.fromMap(m)).toList();
  }

  Future<ProductSerialBatch?> getProductSerialByImei(String imei) async {
    final clean = imei.trim();
    if (clean.isEmpty) return null;
    final res = await db.query(
      'product_serials_batches',
      where: 'serial_number_1 = ? OR serial_number_2 = ?',
      whereArgs: [clean, clean],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return ProductSerialBatch.fromMap(res.first);
  }

  Future<List<ProductSerialBatch>> getActiveBatchesForProduct(int productId) async {
    final res = await db.query(
      'product_serials_batches',
      where: "product_id = ? AND status = 'in_stock'",
      whereArgs: [productId],
      orderBy: 'expiry_date ASC, id ASC',
    );
    return res.map((m) => ProductSerialBatch.fromMap(m)).toList();
  }

  Future<void> updateProductSerialStatus(int id, String status, {int? saleId, int? purchaseId}) async {
    final updates = <String, dynamic>{'status': status};
    if (saleId != null) updates['sale_id'] = saleId;
    if (purchaseId != null) updates['purchase_id'] = purchaseId;
    await db.update('product_serials_batches', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProductSerialBatch(int id) async {
    return await db.delete('product_serials_batches', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== PRODUCT BUNDLES & SYSTEM PACKAGES (SOLAR BOM) =====================

  Future<int> addProductBundleItem(ProductBundleItem item) async {
    return await db.insert('product_bundles', item.toMap());
  }

  Future<List<ProductBundleItem>> getBundleItems(int parentProductId) async {
    final res = await db.query(
      'product_bundles',
      where: 'parent_product_id = ?',
      whereArgs: [parentProductId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return res.map((m) => ProductBundleItem.fromMap(m)).toList();
  }

  Future<void> saveBundleItems(int parentProductId, List<ProductBundleItem> items) async {
    await db.transaction((txn) async {
      await txn.delete('product_bundles', where: 'parent_product_id = ?', whereArgs: [parentProductId]);
      for (final itm in items) {
        await txn.insert('product_bundles', itm.toMap());
      }
    });
  }

  Future<int> deleteBundleItem(int id) async {
    return await db.delete('product_bundles', where: 'id = ?', whereArgs: [id]);
  }

  // ===================== AUDIT LOGGING =====================

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

  Future<List<AuditLog>> getAuditLogs({int limit = 100, String? entityType}) async {
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

  Future<int> updateRestaurantTableStatus(
    int id,
    String status, {
    double? orderTotal,
    String? kotTime,
    String? waiterName,
    int? waiterId,
    int? currentSaleId,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (orderTotal != null) updates['order_total'] = orderTotal;
    if (kotTime != null) updates['kot_time'] = kotTime;
    if (waiterName != null) updates['waiter_name'] = waiterName;
    if (waiterId != null) updates['waiter_id'] = waiterId;
    if (currentSaleId != null) updates['current_sale_id'] = currentSaleId;
    return await db.update('restaurant_tables', updates, where: 'id = ?', whereArgs: [id]);
  }


  // ===================== CONTACT LEDGER & WALK-IN HELPERS =====================

  Future<void> updateContactBalance(int contactId, double deltaAmount) async {
    await db.rawUpdate('''
      UPDATE contacts 
      SET balance = balance + ? 
      WHERE id = ?
    ''', [deltaAmount, contactId]);
  }

  Future<bool> isWalkInCustomer(int? customerId) async {
    if (customerId == null) return true;
    final res = await db.query('contacts', where: 'id = ?', whereArgs: [customerId], limit: 1);
    if (res.isEmpty) return true;
    final name = (res.first['name'] as String? ?? '').toLowerCase();
    final isWalkIn = (res.first['is_default_walk_in'] as int? ?? 0) == 1;
    return isWalkIn || name.contains('walk-in') || name.contains('walk in');
  }

  /// Reset business configuration to trigger first-time installation wizard on next launch
  Future<void> resetToFreshInstallation() async {
    await db.execute("UPDATE business_settings SET is_configured = 0");
  }
}

