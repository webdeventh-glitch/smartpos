import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../models/models.dart';
import 'database_service.dart';

class MySqlService {
  static final ValueNotifier<bool> isMySqlOnline = ValueNotifier<bool>(false);
  static final ValueNotifier<String> connectionStatus = ValueNotifier<String>('Disconnected');

  /// Test connection to MySQL server with authentication credentials
  static Future<Map<String, dynamic>> testConnection({
    required String host,
    required int port,
    required String user,
    required String password,
    String? databaseName,
  }) async {
    MySQLConnection? conn;
    try {
      final sw = Stopwatch()..start();
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: (databaseName != null && databaseName.isNotEmpty) ? databaseName : null,
        secure: false,
      );
      await conn.connect();
      sw.stop();
      isMySqlOnline.value = true;
      connectionStatus.value = 'Connected ($host:$port)';
      return {
        'success': true,
        'latencyMs': sw.elapsedMilliseconds,
        'message': 'Connected to MySQL server successfully (${sw.elapsedMilliseconds}ms)!',
      };
    } catch (e) {
      isMySqlOnline.value = false;
      connectionStatus.value = 'Offline ($e)';
      String errorMsg = e.toString();
      if (errorMsg.contains('1045')) {
        if (password.isNotEmpty) {
          errorMsg += '\nHint: Laragon/XAMPP users: Default "root" user has NO password. Clear/empty the DB Password field and try again. Alternatively, use username "smartpos" with password "smartpos123".';
        } else {
          errorMsg += '\nHint: Access denied with empty password. If you have set a MySQL root password, please enter it in the DB Password field. Or use username "smartpos" with password "smartpos123".';
        }
      }
      return {
        'success': false,
        'latencyMs': 0,
        'message': 'MySQL Connection Failed: $errorMsg',
      };
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  /// Automatically provisions the MySQL database and creates all required enterprise tables
  static Future<Map<String, dynamic>> initializeDatabaseAndTables({
    required String host,
    required int port,
    required String user,
    required String password,
    required String databaseName,
    BusinessSettings? initialSettings,
    User? initialAdminUser,
  }) async {
    MySQLConnection? conn;
    try {
      final safeDbName = databaseName.trim().isEmpty ? 'smartpos' : databaseName.trim();

      // Step 1: Connect to server without database to create target DB if missing
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        secure: false,
      );
      await conn.connect();

      await conn.execute(
        'CREATE DATABASE IF NOT EXISTS `$safeDbName` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci',
      );
      await conn.close();

      // Step 2: Connect directly to the newly created / existing database
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // Step 3: Run table migrations
      await _createTables(conn);

      // Step 4: Seed initial business settings and admin user if provided
      if (initialSettings != null) {
        await _seedSettings(conn, initialSettings);
      }
      if (initialAdminUser != null) {
        await _seedAdminUser(conn, initialAdminUser);
      }

      isMySqlOnline.value = true;
      connectionStatus.value = 'Active ($safeDbName @ $host:$port)';

      return {
        'success': true,
        'message': 'Database "$safeDbName" and all tables successfully initialized in MySQL!',
      };
    } catch (e) {
      isMySqlOnline.value = false;
      connectionStatus.value = 'Failed ($e)';
      debugPrint('MySqlService initializeDatabaseAndTables error: $e');
      String errorMsg = e.toString();
      if (errorMsg.contains('1045')) {
        if (password.isNotEmpty) {
          errorMsg += '\nHint: Laragon/XAMPP users: Default "root" user has NO password. Clear/empty the DB Password field and try again. Alternatively, use username "smartpos" with password "smartpos123".';
        } else {
          errorMsg += '\nHint: Access denied with empty password. If you have set a MySQL root password, please enter it in the DB Password field. Or use username "smartpos" with password "smartpos123".';
        }
      }
      return {
        'success': false,
        'message': 'MySQL Initialization Failed: $errorMsg',
      };
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  /// Connect and synchronize pending offline SQLite records into MySQL
  static Future<void> connectAndSync({
    required BusinessSettings settings,
    required DatabaseService localDb,
  }) async {
    if (!settings.isMySql) return;

    MySQLConnection? conn;
    try {
      final safeDbName = settings.dbName.trim().isNotEmpty ? settings.dbName.trim() : 'smartpos';
      conn = await MySQLConnection.createConnection(
        host: settings.dbHost.isNotEmpty ? settings.dbHost : '127.0.0.1',
        port: settings.dbPort > 0 ? settings.dbPort : 3306,
        userName: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
        password: settings.dbPassword,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();
      isMySqlOnline.value = true;
      connectionStatus.value = 'Connected ($safeDbName)';

      // Auto-flush pending sync queue
      await flushPendingQueue(conn, localDb);
    } catch (e) {
      isMySqlOnline.value = false;
      connectionStatus.value = 'Offline ($e)';
      debugPrint('MySqlService background connectAndSync notice: $e');
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  /// Pushes any pending sync queue items from SQLite into MySQL
  static Future<int> flushPendingQueue(MySQLConnection conn, DatabaseService localDb) async {
    final pendingItems = await localDb.getPendingSyncItems(limit: 100);
    if (pendingItems.isEmpty) return 0;

    final syncedIds = <int>[];
    for (final item in pendingItems) {
      try {
        final id = item['id'] as int;
        final entityType = item['entity_type'] as String;
        final payloadJson = item['payload_json'] as String? ?? '{}';
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

        await _applyPayloadToMySql(conn, entityType, payload);
        syncedIds.add(id);
      } catch (e) {
        debugPrint('Failed to sync item ${item['id']} to MySQL: $e');
      }
    }

    if (syncedIds.isNotEmpty) {
      await localDb.markSyncItemsDone(syncedIds);
    }
    return syncedIds.length;
  }

  /// Push a live single entity change directly to MySQL, or leave it in SQLite queue
  static Future<void> pushSingleEntity({
    required BusinessSettings settings,
    required String entityType,
    required Map<String, dynamic> payload,
  }) async {
    if (!settings.isMySql) return;

    MySQLConnection? conn;
    try {
      final safeDbName = settings.dbName.trim().isNotEmpty ? settings.dbName.trim() : 'smartpos';
      conn = await MySQLConnection.createConnection(
        host: settings.dbHost.isNotEmpty ? settings.dbHost : '127.0.0.1',
        port: settings.dbPort > 0 ? settings.dbPort : 3306,
        userName: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
        password: settings.dbPassword,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();
      await _applyPayloadToMySql(conn, entityType, payload);
      isMySqlOnline.value = true;
    } catch (e) {
      debugPrint('Direct MySQL push for $entityType queued to offline buffer: $e');
      isMySqlOnline.value = false;
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  static Future<void> _applyPayloadToMySql(
    MySQLConnection conn,
    String entityType,
    Map<String, dynamic> payload,
  ) async {
    switch (entityType) {
      case 'product':
        await conn.execute('''
          INSERT INTO `products` (
            `sku`, `barcode`, `name`, `category_name`, `brand_name`, `unit`,
            `purchase_price`, `selling_price`, `stock_quantity`, `alert_quantity`,
            `batch_number`, `expiry_date`, `pack_size`, `bonus_qty`
          ) VALUES (
            :sku, :barcode, :name, :category, :brand, :unit,
            :purchasePrice, :sellingPrice, :stockQty, :alertQty,
            :batch, :expiry, :packSize, :bonusQty
          ) ON DUPLICATE KEY UPDATE
            `name` = VALUES(`name`),
            `purchase_price` = VALUES(`purchase_price`),
            `selling_price` = VALUES(`selling_price`),
            `stock_quantity` = VALUES(`stock_quantity`),
            `alert_quantity` = VALUES(`alert_quantity`),
            `batch_number` = VALUES(`batch_number`),
            `expiry_date` = VALUES(`expiry_date`),
            `pack_size` = VALUES(`pack_size`),
            `updated_at` = NOW();
        ''', {
          'sku': payload['sku'] ?? '',
          'barcode': payload['barcode'] ?? '',
          'name': payload['name'] ?? '',
          'category': payload['category_name'] ?? 'General',
          'brand': payload['brand_name'] ?? 'Standard',
          'unit': payload['unit'] ?? 'Pc',
          'purchasePrice': (payload['purchase_price'] as num?)?.toDouble() ?? 0.0,
          'sellingPrice': (payload['selling_price'] as num?)?.toDouble() ?? 0.0,
          'stockQty': (payload['stock_quantity'] as num?)?.toDouble() ?? 0.0,
          'alertQty': (payload['alert_quantity'] as num?)?.toDouble() ?? 5.0,
          'batch': payload['batch_number'] ?? '',
          'expiry': payload['expiry_date'] ?? '',
          'packSize': (payload['pack_size'] as num?)?.toDouble() ?? 1.0,
          'bonusQty': (payload['bonus_qty'] as num?)?.toDouble() ?? 0.0,
        });
        break;

      case 'sale':
        final saleData = payload['sale'] as Map<String, dynamic>? ?? payload;
        final res = await conn.execute('''
          INSERT INTO `sales` (
            `invoice_no`, `customer_name`, `subtotal`, `discount`, `tax_amount`,
            `total_amount`, `paid_amount`, `payment_method`, `payment_status`, `sale_status`, `note`
          ) VALUES (
            :invNo, :custName, :subtotal, :discount, :tax,
            :total, :paid, :payMethod, :payStatus, :saleStatus, :note
          ) ON DUPLICATE KEY UPDATE
            `total_amount` = VALUES(`total_amount`),
            `paid_amount` = VALUES(`paid_amount`),
            `payment_status` = VALUES(`payment_status`),
            `updated_at` = NOW();
        ''', {
          'invNo': saleData['invoice_no'] ?? '',
          'custName': saleData['customer_name'] ?? 'Walk-in Customer',
          'subtotal': (saleData['subtotal'] as num?)?.toDouble() ?? 0.0,
          'discount': (saleData['discount'] as num?)?.toDouble() ?? 0.0,
          'tax': (saleData['tax_amount'] as num?)?.toDouble() ?? 0.0,
          'total': (saleData['total_amount'] as num?)?.toDouble() ?? 0.0,
          'paid': (saleData['paid_amount'] as num?)?.toDouble() ?? 0.0,
          'payMethod': saleData['payment_method'] ?? 'cash',
          'payStatus': saleData['payment_status'] ?? 'paid',
          'saleStatus': saleData['sale_status'] ?? 'final',
          'note': saleData['note'] ?? '',
        });

        final saleId = res.lastInsertID > BigInt.zero ? res.lastInsertID.toInt() : (saleData['id'] ?? 1);
        final items = payload['items'] as List<dynamic>?;
        if (items != null) {
          for (final rawItem in items) {
            final item = rawItem as Map<String, dynamic>;
            await conn.execute('''
              INSERT INTO `sale_items` (
                `sale_id`, `product_name`, `sku`, `batch_number`, `quantity`, `unit_price`, `subtotal`
              ) VALUES (
                :saleId, :pName, :sku, :batch, :qty, :price, :subtotal
              );
            ''', {
              'saleId': saleId,
              'pName': item['product_name'] ?? '',
              'sku': item['sku'] ?? '',
              'batch': item['batch_number'] ?? '',
              'qty': (item['quantity'] as num?)?.toDouble() ?? 1.0,
              'price': (item['unit_price'] as num?)?.toDouble() ?? 0.0,
              'subtotal': (item['subtotal'] as num?)?.toDouble() ?? 0.0,
            });

            // Decrement MySQL stock quantity
            if (item['sku'] != null && (item['sku'] as String).isNotEmpty) {
              await conn.execute('''
                UPDATE `products` SET `stock_quantity` = `stock_quantity` - :qty WHERE `sku` = :sku;
              ''', {
                'qty': (item['quantity'] as num?)?.toDouble() ?? 1.0,
                'sku': item['sku'],
              });
            }
          }
        }
        break;

      case 'contact':
        await conn.execute('''
          INSERT INTO `contacts` (
            `type`, `name`, `business_name`, `phone`, `email`, `address`, `balance`
          ) VALUES (
            :type, :name, :bizName, :phone, :email, :addr, :balance
          ) ON DUPLICATE KEY UPDATE
            `name` = VALUES(`name`),
            `business_name` = VALUES(`business_name`),
            `phone` = VALUES(`phone`),
            `balance` = VALUES(`balance`),
            `updated_at` = NOW();
        ''', {
          'type': payload['type'] ?? 'customer',
          'name': payload['name'] ?? '',
          'bizName': payload['business_name'] ?? '',
          'phone': payload['phone'] ?? '',
          'email': payload['email'] ?? '',
          'addr': payload['address'] ?? '',
          'balance': (payload['balance'] as num?)?.toDouble() ?? 0.0,
        });
        break;

      case 'purchase':
        final purchaseData = payload['purchase'] as Map<String, dynamic>? ?? payload;
        await conn.execute('''
          INSERT INTO `purchases` (
            `ref_no`, `supplier_name`, `status`, `payment_status`, `total_amount`, `paid_amount`, `notes`
          ) VALUES (
            :refNo, :suppName, :status, :payStatus, :total, :paid, :notes
          ) ON DUPLICATE KEY UPDATE
            `total_amount` = VALUES(`total_amount`),
            `paid_amount` = VALUES(`paid_amount`),
            `updated_at` = NOW();
        ''', {
          'refNo': purchaseData['ref_no'] ?? '',
          'suppName': purchaseData['supplier_name'] ?? 'Supplier',
          'status': purchaseData['status'] ?? 'received',
          'payStatus': purchaseData['payment_status'] ?? 'paid',
          'total': (purchaseData['total_amount'] as num?)?.toDouble() ?? 0.0,
          'paid': (purchaseData['paid_amount'] as num?)?.toDouble() ?? 0.0,
          'notes': purchaseData['notes'] ?? '',
        });
        break;

      default:
        break;
    }
  }

  /// Seeds realistic initial commercial catalog into MySQL tables
  static Future<void> seedStarterDataToMySql({
    required String host,
    required int port,
    required String user,
    required String password,
    required String databaseName,
    required String businessType,
  }) async {
    MySQLConnection? conn;
    try {
      final safeDbName = databaseName.trim().isEmpty ? 'smartpos' : databaseName.trim();
      conn = await MySQLConnection.createConnection(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // Seed categories
      await conn.execute('''
        INSERT IGNORE INTO `categories` (`name`, `code`, `description`) VALUES
        ('Antibiotics & Medications', 'CAT-MED', 'Prescription pharmaceutical drugs'),
        ('OTC Medicines', 'CAT-OTC', 'Over the counter healthcare products'),
        ('General Merchandise', 'CAT-GEN', 'Everyday store goods');
      ''');

      // Seed brands
      await conn.execute('''
        INSERT IGNORE INTO `brands` (`name`, `description`) VALUES
        ('GSK', 'GlaxoSmithKline Pharmaceuticals'),
        ('Abbott', 'Abbott Healthcare'),
        ('Getz Pharma', 'Getz Formulations');
      ''');

      // Seed units
      await conn.execute('''
        INSERT IGNORE INTO `units` (`actual_name`, `short_name`, `allow_decimal`, `base_unit_multiplier`) VALUES
        ('Piece', 'Pc', 0, 1.00),
        ('Box', 'Box', 0, 10.00),
        ('Strip', 'Strip', 0, 1.00);
      ''');

      // Seed starter products
      await conn.execute('''
        INSERT IGNORE INTO `products` (
          `sku`, `barcode`, `name`, `category_name`, `brand_name`, `unit`,
          `purchase_price`, `selling_price`, `stock_quantity`, `alert_quantity`,
          `batch_number`, `expiry_date`, `pack_size`
        ) VALUES
        ('MED-PAN-500', '896400010011', 'Panadol 500mg Tablets (Box of 200)', 'OTC Medicines', 'GSK', 'Box', 480.00, 600.00, 50.00, 10.00, 'B-9281', '2027-12-31', 1.0),
        ('MED-AUG-625', '896400010022', 'Augmentin 625mg Tablets', 'Antibiotics & Medications', 'GSK', 'Strip', 210.00, 260.00, 80.00, 15.00, 'B-4819', '2028-06-30', 1.0),
        ('MED-DIS-300', '896400010033', 'Disprin Soluble 300mg', 'OTC Medicines', 'Reckitt', 'Strip', 45.00, 60.00, 120.00, 20.00, 'B-7712', '2027-09-30', 1.0),
        ('MED-BRU-400', '896400010044', 'Brufen 400mg Tablets', 'Antibiotics & Medications', 'Abbott', 'Box', 180.00, 230.00, 65.00, 12.00, 'B-3321', '2027-11-30', 1.0);
      ''');

      // Seed starter walk-in customer
      await conn.execute('''
        INSERT IGNORE INTO `contacts` (`type`, `name`, `business_name`, `phone`, `email`, `balance`)
        VALUES ('customer', 'Walk-in Customer', 'Cash Retail Customer', '+92 300 0000000', 'walkin@smartpos.com', 0.00);
      ''');

      debugPrint('MySqlService starter catalog seeded successfully!');
    } catch (e) {
      debugPrint('Failed to seed starter data to MySQL: $e');
    } finally {
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  static Future<void> _createTables(MySQLConnection conn) async {
    // 1. business_locations
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `business_locations` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `location_id` VARCHAR(50) NOT NULL UNIQUE,
        `name` VARCHAR(150) NOT NULL,
        `landmark` VARCHAR(255) NULL,
        `city` VARCHAR(100) NULL,
        `state` VARCHAR(100) NULL,
        `country` VARCHAR(100) DEFAULT 'Pakistan',
        `zip_code` VARCHAR(20) NULL,
        `mobile` VARCHAR(50) NULL,
        `email` VARCHAR(100) NULL,
        `invoice_scheme` VARCHAR(50) DEFAULT 'INV-',
        `is_active` TINYINT(1) DEFAULT 1,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 2. business_settings
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `business_settings` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `business_name` VARCHAR(200) NOT NULL DEFAULT 'Smart POS Enterprise',
        `branch_name` VARCHAR(200) NOT NULL DEFAULT 'Main Branch HQ',
        `currency_symbol` VARCHAR(10) NOT NULL DEFAULT 'Rs',
        `currency_code` VARCHAR(10) NOT NULL DEFAULT 'PKR',
        `default_tax_rate` DECIMAL(5,2) DEFAULT 0.00,
        `phone` VARCHAR(50) NULL,
        `email` VARCHAR(100) NULL,
        `address` TEXT NULL,
        `invoice_prefix` VARCHAR(20) DEFAULT 'INV-',
        `receipt_footer` TEXT NULL,
        `purchase_key` VARCHAR(100) NULL,
        `business_type` VARCHAR(50) DEFAULT 'general',
        `sync_mode` VARCHAR(20) DEFAULT 'offline',
        `enabled_modules` TEXT NULL,
        `primary_db_type` VARCHAR(50) DEFAULT 'mysql',
        `db_host` VARCHAR(150) DEFAULT 'localhost',
        `db_port` INT DEFAULT 3306,
        `db_name` VARCHAR(100) DEFAULT 'smartpos',
        `db_user` VARCHAR(100) DEFAULT 'root',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 3. categories
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `categories` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL UNIQUE,
        `code` VARCHAR(50) NOT NULL,
        `description` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 4. brands
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `brands` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL UNIQUE,
        `description` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 5. units
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `units` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `actual_name` VARCHAR(100) NOT NULL,
        `short_name` VARCHAR(50) NOT NULL,
        `allow_decimal` TINYINT(1) DEFAULT 0,
        `base_unit_id` INT UNSIGNED NULL,
        `base_unit_multiplier` DECIMAL(10,2) DEFAULT 1.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 6. products
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `products` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `branch_id` INT UNSIGNED DEFAULT 1,
        `sku` VARCHAR(100) NOT NULL UNIQUE,
        `barcode` VARCHAR(100) NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `category_name` VARCHAR(150) NULL,
        `brand_name` VARCHAR(150) NULL,
        `unit` VARCHAR(50) DEFAULT 'Pc',
        `purchase_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `selling_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `stock_quantity` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `alert_quantity` DECIMAL(12,2) DEFAULT 5.00,
        `batch_number` VARCHAR(100) DEFAULT '',
        `expiry_date` VARCHAR(50) DEFAULT '',
        `pack_size` DECIMAL(10,2) DEFAULT 1.00,
        `bonus_qty` DECIMAL(10,2) DEFAULT 0.00,
        `is_synced` TINYINT(1) DEFAULT 1,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_prod_barcode` (`barcode`),
        INDEX `idx_prod_name` (`name`)
      ) ENGINE=InnoDB;
    ''');

    // 7. contacts
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `contacts` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `type` ENUM('customer', 'supplier', 'both') NOT NULL DEFAULT 'customer',
        `name` VARCHAR(200) NOT NULL,
        `business_name` VARCHAR(200) NULL,
        `phone` VARCHAR(50) NULL,
        `email` VARCHAR(100) NULL,
        `address` TEXT NULL,
        `balance` DECIMAL(12,2) DEFAULT 0.00,
        `credit_limit` DECIMAL(12,2) DEFAULT 50000.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_contact_type` (`type`),
        INDEX `idx_contact_phone` (`phone`)
      ) ENGINE=InnoDB;
    ''');

    // 8. sales
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sales` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `branch_id` INT UNSIGNED DEFAULT 1,
        `invoice_no` VARCHAR(100) NOT NULL UNIQUE,
        `customer_id` INT UNSIGNED NULL,
        `customer_name` VARCHAR(200) NOT NULL DEFAULT 'Walk-in Customer',
        `subtotal` DECIMAL(12,2) NOT NULL,
        `discount` DECIMAL(12,2) DEFAULT 0.00,
        `tax_amount` DECIMAL(12,2) DEFAULT 0.00,
        `tax_rate` DECIMAL(5,2) DEFAULT 0.00,
        `shipping` DECIMAL(12,2) DEFAULT 0.00,
        `total_amount` DECIMAL(12,2) NOT NULL,
        `paid_amount` DECIMAL(12,2) NOT NULL,
        `payment_method` VARCHAR(50) DEFAULT 'cash',
        `payment_status` VARCHAR(50) DEFAULT 'paid',
        `sale_status` VARCHAR(50) DEFAULT 'final',
        `note` TEXT NULL,
        `synced_from_device` VARCHAR(100) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_sales_inv` (`invoice_no`),
        INDEX `idx_sales_created` (`created_at`)
      ) ENGINE=InnoDB;
    ''');

    // 9. sale_items
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sale_items` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `sale_id` INT UNSIGNED NOT NULL,
        `product_id` INT UNSIGNED NULL,
        `product_name` VARCHAR(255) NOT NULL,
        `sku` VARCHAR(100) NULL,
        `batch_number` VARCHAR(100) NULL,
        `quantity` DECIMAL(10,2) NOT NULL,
        `unit_price` DECIMAL(12,2) NOT NULL,
        `subtotal` DECIMAL(12,2) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_sale_item_sale` (`sale_id`)
      ) ENGINE=InnoDB;
    ''');

    // 10. purchases
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `purchases` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `branch_id` INT UNSIGNED DEFAULT 1,
        `ref_no` VARCHAR(100) NOT NULL UNIQUE,
        `supplier_id` INT UNSIGNED NULL,
        `supplier_name` VARCHAR(200) NOT NULL DEFAULT 'Supplier',
        `status` VARCHAR(50) DEFAULT 'received',
        `payment_status` VARCHAR(50) DEFAULT 'paid',
        `total_amount` DECIMAL(12,2) NOT NULL,
        `paid_amount` DECIMAL(12,2) NOT NULL,
        `notes` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 11. users
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `users` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `username` VARCHAR(100) NOT NULL UNIQUE,
        `password` VARCHAR(255) NOT NULL,
        `email` VARCHAR(150) NULL,
        `phone` VARCHAR(50) NULL,
        `role` VARCHAR(50) DEFAULT 'cashier',
        `status` VARCHAR(20) DEFAULT 'active',
        `branch_id` INT UNSIGNED DEFAULT 1,
        `branch_name` VARCHAR(150) DEFAULT 'Main Branch HQ',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 12. payment_transactions
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `payment_transactions` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `transaction_type` VARCHAR(50) NOT NULL,
        `parent_id` INT UNSIGNED NULL,
        `contact_id` INT UNSIGNED NULL,
        `contact_name` VARCHAR(200) NOT NULL,
        `payment_method` VARCHAR(50) DEFAULT 'cash',
        `amount` DECIMAL(12,2) NOT NULL,
        `account_name` VARCHAR(100) DEFAULT 'Cash Till',
        `transaction_date` VARCHAR(50) NULL,
        `ref_no` VARCHAR(100) NULL,
        `note` TEXT NULL,
        `created_by` VARCHAR(100) DEFAULT 'Cashier',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 13. sync_queue
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sync_queue` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `entity_type` VARCHAR(50) NOT NULL,
        `entity_id` VARCHAR(100) NOT NULL,
        `action` VARCHAR(50) NOT NULL,
        `payload_json` LONGTEXT NULL,
        `status` VARCHAR(20) DEFAULT 'pending',
        `retry_count` INT DEFAULT 0,
        `last_error` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        `synced_at` VARCHAR(50) NULL
      ) ENGINE=InnoDB;
    ''');

    // 14. sync_logs
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sync_logs` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `branch_id` INT UNSIGNED DEFAULT 1,
        `direction` ENUM('push', 'pull') NOT NULL,
        `entity_type` VARCHAR(50) NOT NULL,
        `entity_id` VARCHAR(100) NOT NULL,
        `action` VARCHAR(50) NOT NULL,
        `status` ENUM('success', 'failed') NOT NULL,
        `payload` JSON NULL,
        `error_message` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');
  }

  static Future<void> _seedSettings(MySQLConnection conn, BusinessSettings s) async {
    try {
      await conn.execute('''
        INSERT INTO `business_settings` (
          `id`, `business_name`, `branch_name`, `currency_symbol`, `currency_code`,
          `default_tax_rate`, `phone`, `email`, `address`, `invoice_prefix`,
          `receipt_footer`, `purchase_key`, `business_type`, `sync_mode`, `enabled_modules`,
          `primary_db_type`, `db_host`, `db_port`, `db_name`, `db_user`
        ) VALUES (
          1, :bizName, :branchName, :curSym, :curCode,
          :taxRate, :phone, :email, :addr, :invPrefix,
          :rcptFooter, :licKey, :bizType, :syncMode, :mods,
          :dbType, :dbHost, :dbPort, :dbName, :dbUser
        ) ON DUPLICATE KEY UPDATE
          `business_name` = VALUES(`business_name`),
          `branch_name` = VALUES(`branch_name`),
          `currency_symbol` = VALUES(`currency_symbol`),
          `currency_code` = VALUES(`currency_code`),
          `business_type` = VALUES(`business_type`),
          `primary_db_type` = VALUES(`primary_db_type`),
          `db_host` = VALUES(`db_host`),
          `db_port` = VALUES(`db_port`),
          `db_name` = VALUES(`db_name`),
          `db_user` = VALUES(`db_user`),
          `updated_at` = NOW();
      ''', {
        'bizName': s.businessName,
        'branchName': s.branchName,
        'curSym': s.currencySymbol,
        'curCode': s.currencyCode,
        'taxRate': s.defaultTaxRate,
        'phone': s.phone,
        'email': s.email,
        'addr': s.address,
        'invPrefix': s.invoicePrefix,
        'rcptFooter': s.receiptFooter,
        'licKey': s.purchaseKey,
        'bizType': s.businessType,
        'syncMode': s.syncMode,
        'mods': s.enabledModules,
        'dbType': s.primaryDbType,
        'dbHost': s.dbHost,
        'dbPort': s.dbPort,
        'dbName': s.dbName,
        'dbUser': s.dbUser,
      });
    } catch (e) {
      debugPrint('Failed to seed business settings to MySQL: $e');
    }
  }

  static Future<void> _seedAdminUser(MySQLConnection conn, User user) async {
    try {
      await conn.execute('''
        INSERT INTO `users` (
          `name`, `username`, `password`, `email`, `phone`, `role`, `status`, `branch_id`, `branch_name`
        ) VALUES (
          :name, :username, :password, :email, :phone, :role, :status, :branchId, :branchName
        ) ON DUPLICATE KEY UPDATE
          `password` = VALUES(`password`),
          `email` = VALUES(`email`),
          `updated_at` = NOW();
      ''', {
        'name': user.name,
        'username': user.username,
        'password': user.password,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'status': user.status,
        'branchId': user.branchId,
        'branchName': user.branchName,
      });
    } catch (e) {
      debugPrint('Failed to seed admin user to MySQL: $e');
    }
  }
}
