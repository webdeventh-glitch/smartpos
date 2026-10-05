import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';

class DatabaseService {
  final Database db;
  DatabaseService(this.db);

  static DatabaseService? _instance;

  static Future<DatabaseService> initialize({String? customPath}) async {
    if (_instance != null) return _instance!;

    sqfliteFfiInit();
    String dbPath = customPath ?? '';
    if (dbPath.isEmpty) {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.current.path;
      final folder = Directory(p.join(base, 'UltimatePOS'));
      await folder.create(recursive: true);
      dbPath = p.join(folder.path, 'ultimate_pos.db');
    }

    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedInitialData(db);
        },
        onOpen: (db) async {
          await _ensureSchemaUpdates(db);
        },
      ),
    );

    _instance = DatabaseService(db);
    return _instance!;
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

    // Seed sample transfer if empty
    final trRes = await db.rawQuery('SELECT COUNT(*) as c FROM stock_transfers');
    if (((trRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('stock_transfers', {
        'ref_no': 'ST-2026-001',
        'from_location_id': 1,
        'from_location_name': 'Main Branch HQ',
        'to_location_id': 2,
        'to_location_name': 'Downtown Warehouse & Depot',
        'status': 'completed',
        'shipping_charges': 15.0,
        'final_total': 450.0,
        'date': '2026-10-04 11:30:00',
        'note': 'Inter-branch rebalance',
        'items_json': '[{"product_id":1,"product_name":"Wireless Mouse","sku":"ACC-001","quantity":10.0,"unit_price":25.0}]',
      });
      await db.insert('stock_transfers', {
        'ref_no': 'ST-2026-002',
        'from_location_id': 2,
        'from_location_name': 'Downtown Warehouse & Depot',
        'to_location_id': 1,
        'to_location_name': 'Main Branch HQ',
        'status': 'in_transit',
        'shipping_charges': 25.0,
        'final_total': 1200.0,
        'date': '2026-10-05 09:15:00',
        'note': 'Restock shipment for weekend surge',
        'items_json': '[{"product_id":2,"product_name":"Mechanical Keyboard","sku":"ACC-002","quantity":15.0,"unit_price":80.0}]',
      });
    }

    // Seed sample adjustments if empty
    final adjRes = await db.rawQuery('SELECT COUNT(*) as c FROM stock_adjustments');
    if (((adjRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('stock_adjustments', {
        'ref_no': 'ADJ-2026-001',
        'location_id': 1,
        'location_name': 'Main Branch HQ',
        'adjustment_type': 'normal',
        'total_amount': 85.0,
        'recovered_amount': 0.0,
        'reason': 'Water leakage damage in aisle 3',
        'date': '2026-10-04 15:45:00',
        'items_json': '[{"product_id":1,"product_name":"Wireless Mouse","sku":"ACC-001","quantity":3.0,"unit_price":25.0}]',
      });
      await db.insert('stock_adjustments', {
        'ref_no': 'ADJ-2026-002',
        'location_id': 1,
        'location_name': 'Main Branch HQ',
        'adjustment_type': 'abnormal',
        'total_amount': 160.0,
        'recovered_amount': 50.0,
        'reason': 'Quarterly audit discrepancy reconciliation',
        'date': '2026-10-05 14:00:00',
        'items_json': '[{"product_id":2,"product_name":"Mechanical Keyboard","sku":"ACC-002","quantity":2.0,"unit_price":80.0}]',
      });
    }

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

    // Seed default accounts if empty
    final accRes = await db.rawQuery('SELECT COUNT(*) as c FROM payment_accounts');
    if (((accRes.first['c'] as int?) ?? 0) == 0) {
      await db.insert('payment_accounts', {
        'name': 'Main Store Cash Drawer',
        'account_number': 'CASH-001',
        'account_type': 'cash',
        'opening_balance': 1500.0,
        'current_balance': 1500.0,
        'note': 'Front counter cash register',
      });
      await db.insert('payment_accounts', {
        'name': 'Business Operating Bank Account',
        'account_number': 'PK89MEZN001234567890',
        'account_type': 'bank',
        'opening_balance': 25000.0,
        'current_balance': 25000.0,
        'note': 'Meezan Bank Corporate Account',
      });
      await db.insert('payment_accounts', {
        'name': 'POS Card Merchant Terminal',
        'account_number': 'STRIPE-TERM-01',
        'account_type': 'pos_terminal',
        'opening_balance': 5400.0,
        'current_balance': 5400.0,
        'note': 'Credit / Debit card settlement account',
      });
    }
  }

  static Future<void> _createTables(Database db) async {
    // 1. Business Settings
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
        receipt_footer TEXT
      )
    ''');

    // 2. Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL,
        description TEXT
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
        image_color TEXT
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
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        tax_rate REAL DEFAULT 0.0,
        shipping REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'cash',
        payment_status TEXT DEFAULT 'paid',
        sale_status TEXT DEFAULT 'final',
        note TEXT,
        created_at TEXT NOT NULL
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
        note TEXT
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
      CREATE TABLE IF NOT EXISTS parked_sales (
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
      )
    ''');

    // 13. Tax Rates
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tax_rates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_tax_group INTEGER DEFAULT 0
      )
    ''');

    // 14. Invoice Schemes
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
      )
    ''');
  }

  static Future<void> _seedInitialData(Database db) async {
    // 1. Settings
    final settings = BusinessSettings();
    await db.insert('business_settings', settings.toMap());

    // 2. Categories
    final categories = [
      {'name': 'Beverages', 'code': 'BEV', 'description': 'Cold drinks, juices & water'},
      {'name': 'Groceries', 'code': 'GROC', 'description': 'Daily essentials and packaged foods'},
      {'name': 'Electronics', 'code': 'ELEC', 'description': 'Gadgets, accessories & batteries'},
      {'name': 'Apparel', 'code': 'APP', 'description': 'Shirts, footwear & wear'},
      {'name': 'Personal Care', 'code': 'CARE', 'description': 'Hygiene, soap & shampoo'},
    ];
    for (var cat in categories) {
      await db.insert('categories', cat);
    }

    // 3. Brands
    final brands = [
      {'name': 'Coca Cola Co.', 'description': 'Soft drinks'},
      {'name': 'Nestle', 'description': 'Food and drinks'},
      {'name': 'Samsung', 'description': 'Consumer electronics'},
      {'name': 'Apple', 'description': 'Computers and tech'},
      {'name': 'Unilever', 'description': 'Consumer goods'},
    ];
    for (var b in brands) {
      await db.insert('brands', b);
    }

    // 4. Products
    final products = [
      {
        'name': 'Coca Cola Can 330ml',
        'sku': 'BEV-001',
        'barcode': '5449000000996',
        'category_id': 1,
        'category_name': 'Beverages',
        'brand_id': 1,
        'brand_name': 'Coca Cola Co.',
        'unit': 'Can',
        'purchase_price': 1.10,
        'selling_price': 1.75,
        'stock_quantity': 140.0,
        'alert_quantity': 20.0,
        'image_color': '#EF4444',
      },
      {
        'name': 'Nestle Pure Life Water 1.5L',
        'sku': 'BEV-002',
        'barcode': '7613031589123',
        'category_id': 1,
        'category_name': 'Beverages',
        'brand_id': 2,
        'brand_name': 'Nestle',
        'unit': 'Bottle',
        'purchase_price': 0.60,
        'selling_price': 1.20,
        'stock_quantity': 85.0,
        'alert_quantity': 15.0,
        'image_color': '#3B82F6',
      },
      {
        'name': 'Organic Whole Grain Oats 1kg',
        'sku': 'GROC-001',
        'barcode': '8901030382918',
        'category_id': 2,
        'category_name': 'Groceries',
        'brand_id': 2,
        'brand_name': 'Nestle',
        'unit': 'Pack',
        'purchase_price': 3.20,
        'selling_price': 5.50,
        'stock_quantity': 42.0,
        'alert_quantity': 10.0,
        'image_color': '#F59E0B',
      },
      {
        'name': 'Basmati Rice Premium 5kg',
        'sku': 'GROC-002',
        'barcode': '8901234567890',
        'category_id': 2,
        'category_name': 'Groceries',
        'brand_id': 5,
        'brand_name': 'Unilever',
        'unit': 'Bag',
        'purchase_price': 12.00,
        'selling_price': 17.50,
        'stock_quantity': 18.0,
        'alert_quantity': 5.0,
        'image_color': '#10B981',
      },
      {
        'name': 'Samsung Fast Wall Charger 25W',
        'sku': 'ELEC-001',
        'barcode': '8806091234567',
        'category_id': 3,
        'category_name': 'Electronics',
        'brand_id': 3,
        'brand_name': 'Samsung',
        'unit': 'Pc',
        'purchase_price': 14.50,
        'selling_price': 24.99,
        'stock_quantity': 25.0,
        'alert_quantity': 5.0,
        'image_color': '#6366F1',
      },
      {
        'name': 'Apple USB-C Lightning Cable 1m',
        'sku': 'ELEC-002',
        'barcode': '194252056891',
        'category_id': 3,
        'category_name': 'Electronics',
        'brand_id': 4,
        'brand_name': 'Apple',
        'unit': 'Pc',
        'purchase_price': 12.00,
        'selling_price': 19.99,
        'stock_quantity': 4.0, // Low stock on purpose for alert display!
        'alert_quantity': 8.0,
        'image_color': '#8B5CF6',
      },
      {
        'name': 'Wireless Bluetooth Earbuds Pro',
        'sku': 'ELEC-003',
        'barcode': '8809988776655',
        'category_id': 3,
        'category_name': 'Electronics',
        'brand_id': 3,
        'brand_name': 'Samsung',
        'unit': 'Box',
        'purchase_price': 38.00,
        'selling_price': 59.99,
        'stock_quantity': 12.0,
        'alert_quantity': 4.0,
        'image_color': '#EC4899',
      },
      {
        'name': 'Classic Polo T-Shirt Navy M',
        'sku': 'APP-001',
        'barcode': '9901122334455',
        'category_id': 4,
        'category_name': 'Apparel',
        'brand_id': 5,
        'brand_name': 'Unilever',
        'unit': 'Pc',
        'purchase_price': 9.00,
        'selling_price': 18.00,
        'stock_quantity': 30.0,
        'alert_quantity': 6.0,
        'image_color': '#0284C7',
      },
      {
        'name': 'Dove Deep Moisture Body Wash 500ml',
        'sku': 'CARE-001',
        'barcode': '8717163012345',
        'category_id': 5,
        'category_name': 'Personal Care',
        'brand_id': 5,
        'brand_name': 'Unilever',
        'unit': 'Bottle',
        'purchase_price': 4.20,
        'selling_price': 7.99,
        'stock_quantity': 3.0, // Low stock alert!
        'alert_quantity': 6.0,
        'image_color': '#14B8A6',
      },
      {
        'name': 'Nescafe Gold Blend Coffee 200g',
        'sku': 'GROC-003',
        'barcode': '7613035889912',
        'category_id': 2,
        'category_name': 'Groceries',
        'brand_id': 2,
        'brand_name': 'Nestle',
        'unit': 'Jar',
        'purchase_price': 7.50,
        'selling_price': 12.49,
        'stock_quantity': 35.0,
        'alert_quantity': 8.0,
        'image_color': '#D97706',
      },
    ];

    for (var p in products) {
      await db.insert('products', p);
    }

    // 5. Contacts (Customers & Suppliers)
    final contacts = [
      {
        'type': 'customer',
        'name': 'Walk-in Customer',
        'business_name': '',
        'phone': 'N/A',
        'email': '',
        'address': 'Local counter',
        'balance': 0.0,
        'credit_limit': 0.0,
      },
      {
        'type': 'customer',
        'name': 'John Doe',
        'business_name': 'JD Enterprises',
        'phone': '+1 (555) 234-5678',
        'email': 'john.doe@example.com',
        'address': '742 Evergreen Terrace, Springfield',
        'balance': 45.50,
        'credit_limit': 500.0,
      },
      {
        'type': 'customer',
        'name': 'Sarah Connor',
        'business_name': 'Cyberdyne Systems',
        'phone': '+1 (555) 876-5432',
        'email': 'sarah@cyberdyne.org',
        'address': '101 Cyber Way, Los Angeles',
        'balance': 0.0,
        'credit_limit': 1500.0,
      },
      {
        'type': 'supplier',
        'name': 'Beverage Hub Logistics',
        'business_name': 'Beverage Hub Dist. LLC',
        'phone': '+1 (800) 443-2211',
        'email': 'orders@beveragehub.com',
        'address': 'Industrial Sector 9, Chicago',
        'balance': 240.0,
        'credit_limit': 10000.0,
      },
      {
        'type': 'supplier',
        'name': 'Premier Electronics Depot',
        'business_name': 'PED Distribution Inc',
        'phone': '+1 (888) 998-1122',
        'email': 'sales@peddistribution.com',
        'address': 'Warehouse Row, Dallas',
        'balance': 520.0,
        'credit_limit': 20000.0,
      },
    ];
    for (var c in contacts) {
      await db.insert('contacts', c);
    }

    // 6. Expenses
    final now = DateTime.now();
    final f = DateFormat('yyyy-MM-dd HH:mm:ss');
    final expenses = [
      {
        'category': 'Store Rent',
        'amount': 1200.00,
        'ref_no': 'EXP-2026-001',
        'note': 'Monthly shop lease payment',
        'date': f.format(now.subtract(const Duration(days: 3))),
      },
      {
        'category': 'Utilities & Power',
        'amount': 340.50,
        'ref_no': 'EXP-2026-002',
        'note': 'Electricity and high-speed internet',
        'date': f.format(now.subtract(const Duration(days: 2))),
      },
      {
        'category': 'Staff Refreshments',
        'amount': 45.00,
        'ref_no': 'EXP-2026-003',
        'note': 'Coffee, tea & snacks for team',
        'date': f.format(now.subtract(const Duration(days: 1))),
      },
    ];
    for (var exp in expenses) {
      await db.insert('expenses', exp);
    }

    // 7. Seed Cash Register
    await db.insert('cash_registers', {
      'cashier_name': 'Admin Cashier',
      'opening_amount': 250.00,
      'closing_amount': 0.0,
      'total_sales_cash': 148.50,
      'total_sales_card': 79.98,
      'total_sales_other': 0.0,
      'status': 'open',
      'opened_at': f.format(now.subtract(const Duration(hours: 6))),
      'closed_at': null,
      'note': 'Shift 1 Morning Terminal',
    });

    // 8. Seed Sample Sales & Items
    final sale1Id = await db.insert('sales', {
      'invoice_no': 'INV-1001',
      'customer_id': 1,
      'customer_name': 'Walk-in Customer',
      'subtotal': 48.48,
      'discount': 0.0,
      'tax_amount': 2.42,
      'tax_rate': 5.0,
      'shipping': 0.0,
      'total_amount': 50.90,
      'paid_amount': 50.90,
      'payment_method': 'cash',
      'payment_status': 'paid',
      'sale_status': 'final',
      'note': 'Counter retail sale',
      'created_at': f.format(now.subtract(const Duration(hours: 4))),
    });

    await db.insert('sale_items', {
      'sale_id': sale1Id,
      'product_id': 1,
      'product_name': 'Coca Cola Can 330ml',
      'sku': 'BEV-001',
      'unit_price': 1.75,
      'quantity': 2.0,
      'discount': 0.0,
      'subtotal': 3.50,
    });
    await db.insert('sale_items', {
      'sale_id': sale1Id,
      'product_id': 5,
      'product_name': 'Samsung Fast Wall Charger 25W',
      'sku': 'ELEC-001',
      'unit_price': 24.99,
      'quantity': 1.0,
      'discount': 0.0,
      'subtotal': 24.99,
    });
    await db.insert('sale_items', {
      'sale_id': sale1Id,
      'product_id': 8,
      'product_name': 'Classic Polo T-Shirt Navy M',
      'sku': 'APP-001',
      'unit_price': 18.00,
      'quantity': 1.0,
      'discount': 0.0,
      'subtotal': 18.00,
    });

    final sale2Id = await db.insert('sales', {
      'invoice_no': 'INV-1002',
      'customer_id': 2,
      'customer_name': 'John Doe',
      'subtotal': 89.97,
      'discount': 5.00,
      'tax_amount': 4.25,
      'tax_rate': 5.0,
      'shipping': 5.00,
      'total_amount': 94.22,
      'paid_amount': 94.22,
      'payment_method': 'card',
      'payment_status': 'paid',
      'sale_status': 'final',
      'note': 'Order with delivery',
      'created_at': f.format(now.subtract(const Duration(hours: 2))),
    });

    await db.insert('sale_items', {
      'sale_id': sale2Id,
      'product_id': 7,
      'product_name': 'Wireless Bluetooth Earbuds Pro',
      'sku': 'ELEC-003',
      'unit_price': 59.99,
      'quantity': 1.0,
      'discount': 5.00,
      'subtotal': 54.99,
    });
    await db.insert('sale_items', {
      'sale_id': sale2Id,
      'product_id': 4,
      'product_name': 'Basmati Rice Premium 5kg',
      'sku': 'GROC-002',
      'unit_price': 17.50,
      'quantity': 2.0,
      'discount': 0.0,
      'subtotal': 35.00,
    });

    // 9. Seed Purchases
    await db.insert('purchases', {
      'ref_no': 'PO-2026-001',
      'supplier_id': 4,
      'supplier_name': 'Beverage Hub Logistics',
      'total_amount': 450.00,
      'paid_amount': 450.00,
      'status': 'received',
      'payment_status': 'paid',
      'created_at': f.format(now.subtract(const Duration(days: 4))),
      'note': 'Stock restock for drinks and juices',
    });

    await db.insert('purchases', {
      'ref_no': 'PO-2026-002',
      'supplier_id': 5,
      'supplier_name': 'Premier Electronics Depot',
      'total_amount': 1200.00,
      'paid_amount': 680.00,
      'status': 'received',
      'payment_status': 'partial',
      'created_at': f.format(now.subtract(const Duration(days: 2))),
      'note': 'Fast chargers and cables shipment',
    });
  }

  // ===================== CRUD OPERATIONS =====================

  // Settings
  Future<BusinessSettings> getBusinessSettings() async {
    final rows = await db.query('business_settings', limit: 1);
    if (rows.isNotEmpty) return BusinessSettings.fromMap(rows.first);
    return BusinessSettings();
  }

  Future<void> updateBusinessSettings(BusinessSettings settings) async {
    await db.update('business_settings', settings.toMap(),
        where: 'id = ?', whereArgs: [settings.id]);
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

  // Warranties
  Future<List<Warranty>> getWarranties() async {
    final rows = await db.query('warranties', orderBy: 'duration ASC');
    return rows.map((r) => Warranty.fromMap(r)).toList();
  }

  Future<int> addWarranty(Warranty warranty) async {
    return await db.insert('warranties', warranty.toMap());
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

  // Products
  Future<List<Product>> getProducts({int? categoryId, String? search}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (categoryId != null && search != null && search.isNotEmpty) {
      where = 'category_id = ? AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)';
      whereArgs = [categoryId, '%$search%', '%$search%', '%$search%'];
    } else if (categoryId != null) {
      where = 'category_id = ?';
      whereArgs = [categoryId];
    } else if (search != null && search.isNotEmpty) {
      where = 'name LIKE ? OR sku LIKE ? OR barcode LIKE ?';
      whereArgs = ['%$search%', '%$search%', '%$search%'];
    }

    final rows = await db.query('products',
        where: where, whereArgs: whereArgs, orderBy: 'name ASC');
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
    return await db.insert('products', product.toMap());
  }

  Future<int> insertProduct(Product product) => addProduct(product);

  Future<Product?> getProductById(int id) async {
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final vars = await getProductVariations(id);
    return Product.fromMap(rows.first, variations: vars);
  }

  Future<int> updateProduct(Product product) async {
    return await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
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

  Future<List<Brand>> getBrands() async {
    final rows = await db.query('brands', orderBy: 'name ASC');
    return rows.map((e) => Brand.fromMap(e)).toList();
  }

  Future<int> addBrand(Brand brand) async {
    return await db.insert('brands', brand.toMap());
  }

  Future<int> insertBrand(Brand brand) => addBrand(brand);

  // Contacts
  Future<List<Contact>> getContacts({String? type}) async {
    final where = type != null ? 'type = ?' : null;
    final whereArgs = type != null ? [type] : null;
    final rows = await db.query('contacts',
        where: where, whereArgs: whereArgs, orderBy: 'name ASC');
    return rows.map((e) => Contact.fromMap(e)).toList();
  }

  Future<int> addContact(Contact contact) async {
    return await db.insert('contacts', contact.toMap());
  }

  Future<int> updateContact(Contact contact) async {
    return await db.update('contacts', contact.toMap(),
        where: 'id = ?', whereArgs: [contact.id]);
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
  }) async {
    return await db.transaction((txn) async {
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
}
