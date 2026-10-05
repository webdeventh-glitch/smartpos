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
    return null;
  }

  Future<int> addProduct(Product product) async {
    return await db.insert('products', product.toMap());
  }

  Future<int> insertProduct(Product product) => addProduct(product);

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

  // Expenses
  Future<List<Expense>> getExpenses() async {
    final rows = await db.query('expenses', orderBy: 'id DESC');
    return rows.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    return await db.insert('expenses', expense.toMap());
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
