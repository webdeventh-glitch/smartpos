import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:mysql_client_plus/mysql_client_plus.dart';
import '../models/models.dart';
import 'database_service.dart';

class MySqlService {
  static final ValueNotifier<bool> isMySqlOnline = ValueNotifier<bool>(false);
  static final ValueNotifier<String> connectionStatus = ValueNotifier<String>('Disconnected');

  /// Normalizes host address so that 'localhost' or empty strings resolve directly to '127.0.0.1' on Windows
  static String normalizeHost(String host) {
    final h = host.trim();
    if (h.isEmpty || h.toLowerCase() == 'localhost') {
      return '127.0.0.1';
    }
    return h;
  }

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
      final targetHost = normalizeHost(host);
      conn = await MySQLConnection.createConnection(
        host: targetHost,
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
      DatabaseService.suppressSync = false;
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
      final targetHost = normalizeHost(host);

      // Step 1: Connect to server without database to create target DB if missing
      conn = await MySQLConnection.createConnection(
        host: targetHost,
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
        host: targetHost,
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
      DatabaseService.suppressSync = false;
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
        host: normalizeHost(settings.dbHost),
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
      DatabaseService.suppressSync = false;
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  /// Checks whether the selected MySQL database has been provisioned and configured.
  /// If tables are dropped (e.g. by user in phpMyAdmin), this returns false so the app
  /// immediately detects the uninitialized state and triggers the setup wizard.
  static Future<bool> isMySqlDatabaseConfigured(BusinessSettings settings) async {
    if (!settings.isMySql) return true;

    MySQLConnection? conn;
    try {
      final safeDbName = settings.dbName.trim().isNotEmpty ? settings.dbName.trim() : 'smartpos';
      conn = await MySQLConnection.createConnection(
        host: normalizeHost(settings.dbHost),
        port: settings.dbPort > 0 ? settings.dbPort : 3306,
        userName: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
        password: settings.dbPassword,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // Check if business_settings table exists
      final res = await conn.execute("SHOW TABLES LIKE 'business_settings'");
      if (res.rows.isEmpty) {
        isMySqlOnline.value = true;
        connectionStatus.value = 'Uninitialized (0 tables in $safeDbName)';
        return false;
      }

      final countRows = await conn.execute("SELECT id FROM `business_settings` LIMIT 1");
      if (countRows.rows.isEmpty) {
        return false;
      }

      isMySqlOnline.value = true;
      connectionStatus.value = 'Active ($safeDbName @ ${settings.dbHost})';
      return true;
    } catch (e) {
      debugPrint('MySqlService isMySqlDatabaseConfigured notice: $e');
      isMySqlOnline.value = false;
      connectionStatus.value = 'Offline ($e)';
      return false;
    } finally {
      DatabaseService.suppressSync = false;
      try {
        await conn?.close();
      } catch (_) {}
    }
  }

  /// Pulls all active records from MySQL into local SQLite database so that local cache
  /// is an exact mirror of the authoritative MySQL database.
  static Future<void> pullDataFromMySql({
    required BusinessSettings settings,
    required DatabaseService localDb,
  }) async {
    if (!settings.isMySql) return;

    MySQLConnection? conn;
    DatabaseService.suppressSync = true;
    try {
      final safeDbName = settings.dbName.trim().isNotEmpty ? settings.dbName.trim() : 'smartpos';
      conn = await MySQLConnection.createConnection(
        host: normalizeHost(settings.dbHost),
        port: settings.dbPort > 0 ? settings.dbPort : 3306,
        userName: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
        password: settings.dbPassword,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // Pull products
      try {
        final prodRes = await conn.execute("SELECT * FROM `products`");
        for (final row in prodRes.rows) {
          final m = row.assoc();
          final sku = m['sku'] ?? '';
          final barcode = m['barcode'] ?? '';
          if (sku.isEmpty && barcode.isEmpty) continue;

          final existing = await localDb.getProductByCode(sku.isNotEmpty ? sku : barcode);
          final p = Product(
            id: existing?.id,
            sku: sku,
            barcode: barcode,
            name: m['name'] ?? '',
            categoryName: m['category_name'] ?? 'General',
            brandName: m['brand_name'] ?? 'Standard',
            unit: m['unit'] ?? 'Pc',
            purchasePrice: double.tryParse(m['purchase_price']?.toString() ?? '0') ?? 0.0,
            sellingPrice: double.tryParse(m['selling_price']?.toString() ?? '0') ?? 0.0,
            stockQuantity: double.tryParse(m['stock_quantity']?.toString() ?? '0') ?? 0.0,
            alertQuantity: double.tryParse(m['alert_quantity']?.toString() ?? '5') ?? 5.0,
            batchNumber: m['batch_number'] ?? '',
            expiryDate: m['expiry_date'] ?? '',
          );
          if (existing == null) {
            await localDb.addProduct(p);
          } else {
            await localDb.updateProduct(p);
          }
        }
      } catch (_) {}

      // Pull contacts
      try {
        final contactRes = await conn.execute("SELECT * FROM `contacts`");
        for (final row in contactRes.rows) {
          final m = row.assoc();
          final name = m['name'] ?? '';
          if (name.isNotEmpty) {
            final existingContacts = await localDb.getContacts();
            if (!existingContacts.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
              await localDb.addContact(Contact(
                name: name,
                type: m['type'] ?? 'customer',
                phone: m['phone'] ?? '',
                email: m['email'] ?? '',
                address: m['address'] ?? '',
                balance: double.tryParse(m['balance']?.toString() ?? '0') ?? 0.0,
              ));
            }
          }
        }
      } catch (_) {}

      // Pull categories
      try {
        final catRes = await conn.execute("SELECT * FROM `categories`");
        for (final row in catRes.rows) {
          final m = row.assoc();
          final name = m['name'] ?? '';
          if (name.isNotEmpty) {
            final existingCats = await localDb.getCategories();
            if (!existingCats.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
              await localDb.addCategory(Category(name: name, code: m['code'] ?? '', description: m['description'] ?? ''));
            }
          }
        }
      } catch (_) {}

      // Pull users
      try {
        final userRes = await conn.execute("SELECT * FROM `users`");
        for (final row in userRes.rows) {
          final m = row.assoc();
          final username = m['username'] ?? '';
          if (username.isNotEmpty) {
            final existingUsers = await localDb.getUsers();
            if (!existingUsers.any((u) => u.username.toLowerCase() == username.toLowerCase())) {
              await localDb.addUser(User(
                name: m['name'] ?? 'User',
                username: username,
                password: m['password'] ?? '',
                email: m['email'] ?? '',
                phone: m['phone'] ?? '',
                role: m['role'] ?? 'cashier',
                status: m['status'] ?? 'active',
                branchId: int.tryParse(m['branch_id']?.toString() ?? '1') ?? 1,
                branchName: m['branch_name'] ?? 'Main Branch',
              ));
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('MySqlService pullDataFromMySql error: $e');
    } finally {
      DatabaseService.suppressSync = false;
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
      DatabaseService.suppressSync = false;
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

  /// Pushes all locally seeded categories, brands, units, contacts, and products directly to MySQL tables
  static Future<void> syncAllLocalCatalogToMySql({
    required BusinessSettings settings,
    required DatabaseService localDb,
  }) async {
    if (!settings.isMySql) return;
    MySQLConnection? conn;
    DatabaseService.suppressSync = true;
    try {
      final safeDbName = settings.dbName.trim().isNotEmpty ? settings.dbName.trim() : 'smartpos';
      final targetHost = normalizeHost(settings.dbHost);
      conn = await MySQLConnection.createConnection(
        host: targetHost,
        port: settings.dbPort > 0 ? settings.dbPort : 3306,
        userName: settings.dbUser.isNotEmpty ? settings.dbUser : 'root',
        password: settings.dbPassword,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // 1. Sync Categories
      try {
        final categories = await localDb.getCategories();
        for (final cat in categories) {
          try {
            await conn.execute('''
              INSERT INTO `categories` (`name`, `code`, `description`)
              VALUES (:name, :code, :description)
              ON DUPLICATE KEY UPDATE `code` = VALUES(`code`), `description` = VALUES(`description`)
            ''', {
              'name': cat.name,
              'code': cat.code.isNotEmpty ? cat.code : 'CAT',
              'description': cat.description ?? '',
            });
          } catch (e) {
            debugPrint('Notice syncing category ${cat.name} to MySQL: $e');
          }
        }
      } catch (e) {
        debugPrint('Category query failed during MySQL seed: $e');
      }

      // 2. Sync Brands
      try {
        final brands = await localDb.getBrands();
        for (final b in brands) {
          try {
            await conn.execute('''
              INSERT INTO `brands` (`name`, `description`)
              VALUES (:name, :desc)
              ON DUPLICATE KEY UPDATE `description` = VALUES(`description`)
            ''', {
              'name': b.name,
              'desc': b.description ?? '',
            });
          } catch (e) {
            debugPrint('Notice syncing brand ${b.name} to MySQL: $e');
          }
        }
      } catch (e) {
        debugPrint('Brand query failed during MySQL seed: $e');
      }

      // 3. Sync Units
      try {
        final units = await localDb.getUnits();
        for (final u in units) {
          try {
            final existing = await conn.execute(
              "SELECT id FROM `units` WHERE `short_name` = :short OR `actual_name` = :actual LIMIT 1",
              {'short': u.shortName, 'actual': u.actualName},
            );
            if (existing.rows.isEmpty) {
              await conn.execute('''
                INSERT INTO `units` (`actual_name`, `short_name`, `allow_decimal`, `base_unit_multiplier`)
                VALUES (:actual, :short, :allowDec, :multiplier)
              ''', {
                'actual': u.actualName,
                'short': u.shortName,
                'allowDec': u.allowDecimal ? 1 : 0,
                'multiplier': u.baseUnitMultiplier,
              });
            }
          } catch (e) {
            debugPrint('Notice syncing unit ${u.actualName} to MySQL: $e');
          }
        }
      } catch (e) {
        debugPrint('Unit query failed during MySQL seed: $e');
      }

      // 4. Sync Contacts
      try {
        final contacts = await localDb.getContacts();
        for (final c in contacts) {
          try {
            final cType = (c.type == 'supplier' || c.type == 'both') ? c.type : 'customer';
            final existing = await conn.execute(
              "SELECT id FROM `contacts` WHERE `name` = :name AND `type` = :type LIMIT 1",
              {'name': c.name, 'type': cType},
            );
            if (existing.rows.isEmpty) {
              await conn.execute('''
                INSERT INTO `contacts` (
                  `type`, `name`, `business_name`, `phone`, `email`, `address`, `balance`, `credit_limit`
                ) VALUES (
                  :type, :name, :bizName, :phone, :email, :addr, :balance, :creditLimit
                )
              ''', {
                'type': cType,
                'name': c.name,
                'bizName': c.businessName ?? '',
                'phone': c.phone,
                'email': c.email,
                'addr': c.address,
                'balance': c.balance,
                'creditLimit': c.creditLimit,
              });
            }
          } catch (e) {
            debugPrint('Notice syncing contact ${c.name} to MySQL: $e');
          }
        }
      } catch (e) {
        debugPrint('Contact query failed during MySQL seed: $e');
      }

      // 5. Sync Products
      try {
        final products = await localDb.getProducts();
        for (final p in products) {
          try {
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
                `category_name` = VALUES(`category_name`),
                `brand_name` = VALUES(`brand_name`),
                `unit` = VALUES(`unit`),
                `purchase_price` = VALUES(`purchase_price`),
                `selling_price` = VALUES(`selling_price`),
                `stock_quantity` = VALUES(`stock_quantity`),
                `alert_quantity` = VALUES(`alert_quantity`),
                `batch_number` = VALUES(`batch_number`),
                `expiry_date` = VALUES(`expiry_date`),
                `pack_size` = VALUES(`pack_size`),
                `bonus_qty` = VALUES(`bonus_qty`),
                `updated_at` = NOW()
            ''', {
              'sku': p.sku,
              'barcode': p.barcode.isNotEmpty ? p.barcode : p.sku,
              'name': p.name,
              'category': p.categoryName,
              'brand': p.brandName,
              'unit': p.unit,
              'purchasePrice': p.purchasePrice,
              'sellingPrice': p.sellingPrice,
              'stockQty': p.stockQuantity,
              'alertQty': p.alertQuantity,
              'batch': p.batchNumber ?? '',
              'expiry': p.expiryDate ?? '',
              'packSize': p.packSize,
              'bonusQty': p.bonusQty,
            });
          } catch (e) {
            debugPrint('Notice syncing product ${p.name} to MySQL: $e');
          }
        }
        debugPrint('MySqlService syncAllLocalCatalogToMySql completed: ${products.length} products synced to MySQL.');
      } catch (e) {
        debugPrint('Product query failed during MySQL seed: $e');
      }
    } catch (e) {
      debugPrint('Failed to sync local catalog to MySQL: $e');
    } finally {
      DatabaseService.suppressSync = false;
      try {
        await conn?.close();
      } catch (_) {}
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
        host: normalizeHost(host),
        port: port,
        userName: user,
        password: password,
        databaseName: safeDbName,
        secure: false,
      );
      await conn.connect();

      // Seed categories
      try {
        await conn.execute('''
          INSERT INTO `categories` (`name`, `code`, `description`) VALUES
          ('Antibiotics & Medications', 'CAT-MED', 'Prescription pharmaceutical drugs'),
          ('OTC Medicines', 'CAT-OTC', 'Over the counter healthcare products'),
          ('General Merchandise', 'CAT-GEN', 'Everyday store goods')
          ON DUPLICATE KEY UPDATE `code` = VALUES(`code`)
        ''');
      } catch (_) {}

      // Seed brands
      try {
        await conn.execute('''
          INSERT INTO `brands` (`name`, `description`) VALUES
          ('GSK', 'GlaxoSmithKline Pharmaceuticals'),
          ('Abbott', 'Abbott Healthcare'),
          ('Getz Pharma', 'Getz Formulations')
          ON DUPLICATE KEY UPDATE `description` = VALUES(`description`)
        ''');
      } catch (_) {}

      // Seed units
      try {
        await conn.execute('''
          INSERT INTO `units` (`actual_name`, `short_name`, `allow_decimal`, `base_unit_multiplier`) VALUES
          ('Piece', 'Pc', 0, 1.00),
          ('Box', 'Box', 0, 10.00),
          ('Strip', 'Strip', 0, 1.00)
        ''');
      } catch (_) {}

      // Seed starter products
      try {
        await conn.execute('''
          INSERT INTO `products` (
            `sku`, `barcode`, `name`, `category_name`, `brand_name`, `unit`,
            `purchase_price`, `selling_price`, `stock_quantity`, `alert_quantity`,
            `batch_number`, `expiry_date`, `pack_size`
          ) VALUES
          ('MED-PAN-500', '896400010011', 'Panadol 500mg Tablets (Box of 200)', 'OTC Medicines', 'GSK', 'Box', 480.00, 600.00, 50.00, 10.00, 'B-9281', '2027-12-31', 1.0),
          ('MED-AUG-625', '896400010022', 'Augmentin 625mg Tablets', 'Antibiotics & Medications', 'GSK', 'Strip', 210.00, 260.00, 80.00, 15.00, 'B-4819', '2028-06-30', 1.0),
          ('MED-DIS-300', '896400010033', 'Disprin Soluble 300mg', 'OTC Medicines', 'Reckitt', 'Strip', 45.00, 60.00, 120.00, 20.00, 'B-7712', '2027-09-30', 1.0),
          ('MED-BRU-400', '896400010044', 'Brufen 400mg Tablets', 'Antibiotics & Medications', 'Abbott', 'Box', 180.00, 230.00, 65.00, 12.00, 'B-3321', '2027-11-30', 1.0)
          ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)
        ''');
      } catch (_) {}

      // Seed starter walk-in customer
      try {
        await conn.execute('''
          INSERT INTO `contacts` (`type`, `name`, `business_name`, `phone`, `email`, `balance`)
          VALUES ('customer', 'Walk-in Customer', 'Cash Retail Customer', '+92 300 0000000', 'walkin@smartpos.com', 0.00)
        ''');
      } catch (_) {}

      debugPrint('MySqlService starter catalog seeded successfully!');
    } catch (e) {
      debugPrint('Failed to seed starter data to MySQL: $e');
    } finally {
      DatabaseService.suppressSync = false;
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
        `is_configured` TINYINT(1) DEFAULT 1,
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

    // 15. tax_rates
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `tax_rates` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `amount` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        `is_tax_group` TINYINT(1) DEFAULT 0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 16. invoice_schemes
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `invoice_schemes` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `scheme_type` VARCHAR(50) DEFAULT 'blank',
        `prefix` VARCHAR(50) DEFAULT 'INV-',
        `start_number` INT DEFAULT 1,
        `invoice_count` INT DEFAULT 0,
        `total_digits` INT DEFAULT 4,
        `is_default` TINYINT(1) DEFAULT 0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 17. selling_price_groups
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `selling_price_groups` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `description` TEXT NULL,
        `is_active` TINYINT(1) DEFAULT 1,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 18. warranties
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `warranties` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `description` TEXT NULL,
        `duration` INT NOT NULL DEFAULT 0,
        `duration_type` VARCHAR(50) DEFAULT 'months',
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 19. variation_templates
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `variation_templates` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `values_json` TEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 20. variations
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `variations` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `product_id` INT UNSIGNED NOT NULL,
        `name` VARCHAR(150) NOT NULL,
        `sub_sku` VARCHAR(100) NOT NULL,
        `purchase_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `selling_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `stock_quantity` DECIMAL(12,2) DEFAULT 0.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_var_prod` (`product_id`)
      ) ENGINE=InnoDB;
    ''');

    // 21. expenses
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `expenses` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `category` VARCHAR(150) NOT NULL,
        `amount` DECIMAL(12,2) NOT NULL,
        `ref_no` VARCHAR(100) NULL,
        `note` TEXT NULL,
        `date` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 22. cash_registers
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `cash_registers` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `cashier_name` VARCHAR(150) NOT NULL,
        `opening_amount` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `closing_amount` DECIMAL(12,2) DEFAULT 0.00,
        `total_sales_cash` DECIMAL(12,2) DEFAULT 0.00,
        `total_sales_card` DECIMAL(12,2) DEFAULT 0.00,
        `total_sales_other` DECIMAL(12,2) DEFAULT 0.00,
        `status` VARCHAR(50) DEFAULT 'open',
        `opened_at` VARCHAR(50) NOT NULL,
        `closed_at` VARCHAR(50) NULL,
        `note` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 23. parked_sales
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `parked_sales` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `customer_name` VARCHAR(200) NOT NULL,
        `note` TEXT NULL,
        `total` DECIMAL(12,2) NOT NULL,
        `created_at` VARCHAR(50) NOT NULL,
        `items_json` LONGTEXT NOT NULL
      ) ENGINE=InnoDB;
    ''');

    // 24. stock_transfers
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `stock_transfers` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_no` VARCHAR(100) NOT NULL UNIQUE,
        `from_location_id` INT UNSIGNED NOT NULL,
        `from_location_name` VARCHAR(150) NOT NULL,
        `to_location_id` INT UNSIGNED NOT NULL,
        `to_location_name` VARCHAR(150) NOT NULL,
        `status` VARCHAR(50) DEFAULT 'completed',
        `shipping_charges` DECIMAL(12,2) DEFAULT 0.00,
        `final_total` DECIMAL(12,2) DEFAULT 0.00,
        `date` VARCHAR(50) NOT NULL,
        `note` TEXT NULL,
        `items_json` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 25. stock_adjustments
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `stock_adjustments` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_no` VARCHAR(100) NOT NULL UNIQUE,
        `location_id` INT UNSIGNED NOT NULL,
        `location_name` VARCHAR(150) NOT NULL,
        `adjustment_type` VARCHAR(50) DEFAULT 'normal',
        `total_amount` DECIMAL(12,2) DEFAULT 0.00,
        `recovered_amount` DECIMAL(12,2) DEFAULT 0.00,
        `reason` TEXT NULL,
        `date` VARCHAR(50) NOT NULL,
        `items_json` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 26. contact_payments
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `contact_payments` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `contact_id` INT UNSIGNED NOT NULL,
        `contact_name` VARCHAR(200) NOT NULL,
        `payment_type` VARCHAR(50) NOT NULL,
        `amount` DECIMAL(12,2) NOT NULL,
        `payment_method` VARCHAR(50) DEFAULT 'cash',
        `date` VARCHAR(50) NOT NULL,
        `ref_no` VARCHAR(100) NULL,
        `note` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 27. payment_accounts
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `payment_accounts` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(150) NOT NULL,
        `account_number` VARCHAR(100) NULL,
        `account_type` VARCHAR(50) DEFAULT 'bank',
        `opening_balance` DECIMAL(12,2) DEFAULT 0.00,
        `current_balance` DECIMAL(12,2) DEFAULT 0.00,
        `note` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 28. account_transfers
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `account_transfers` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `from_account_id` INT UNSIGNED NOT NULL,
        `from_account_name` VARCHAR(150) NOT NULL,
        `to_account_id` INT UNSIGNED NOT NULL,
        `to_account_name` VARCHAR(150) NOT NULL,
        `amount` DECIMAL(12,2) NOT NULL,
        `date` VARCHAR(50) NOT NULL,
        `ref_no` VARCHAR(100) NULL,
        `note` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 29. sale_returns & sale_return_items
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sale_returns` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_no` VARCHAR(100) NOT NULL UNIQUE,
        `sale_id` INT UNSIGNED NOT NULL,
        `invoice_no` VARCHAR(100) NOT NULL,
        `customer_id` INT UNSIGNED NULL,
        `customer_name` VARCHAR(200) NOT NULL,
        `total_amount` DECIMAL(12,2) NOT NULL,
        `refund_amount` DECIMAL(12,2) NOT NULL,
        `refund_method` VARCHAR(50) DEFAULT 'cash',
        `status` VARCHAR(50) DEFAULT 'completed',
        `date` VARCHAR(50) NOT NULL,
        `note` TEXT NULL,
        `items_json` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `sale_return_items` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `return_id` INT UNSIGNED NOT NULL,
        `product_id` INT UNSIGNED NOT NULL,
        `product_name` VARCHAR(255) NOT NULL,
        `sku` VARCHAR(100) NULL,
        `batch_number` VARCHAR(100) NULL,
        `quantity` DECIMAL(10,2) NOT NULL,
        `unit_price` DECIMAL(12,2) NOT NULL,
        `subtotal` DECIMAL(12,2) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_sret_ret` (`return_id`)
      ) ENGINE=InnoDB;
    ''');

    // 30. purchase_returns & purchase_return_items
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `purchase_returns` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `ref_no` VARCHAR(100) NOT NULL UNIQUE,
        `purchase_id` INT UNSIGNED NOT NULL,
        `purchase_ref` VARCHAR(100) NOT NULL,
        `supplier_id` INT UNSIGNED NULL,
        `supplier_name` VARCHAR(200) NOT NULL,
        `total_amount` DECIMAL(12,2) NOT NULL,
        `refund_amount` DECIMAL(12,2) NOT NULL,
        `refund_method` VARCHAR(50) DEFAULT 'cash',
        `status` VARCHAR(50) DEFAULT 'completed',
        `date` VARCHAR(50) NOT NULL,
        `note` TEXT NULL,
        `items_json` LONGTEXT NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `purchase_return_items` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `return_id` INT UNSIGNED NOT NULL,
        `product_id` INT UNSIGNED NOT NULL,
        `product_name` VARCHAR(255) NOT NULL,
        `sku` VARCHAR(100) NULL,
        `batch_number` VARCHAR(100) NULL,
        `quantity` DECIMAL(10,2) NOT NULL,
        `unit_price` DECIMAL(12,2) NOT NULL,
        `subtotal` DECIMAL(12,2) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_pret_ret` (`return_id`)
      ) ENGINE=InnoDB;
    ''');

    // 31. financial_years
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `financial_years` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `year_name` VARCHAR(100) NOT NULL,
        `start_date` VARCHAR(50) NOT NULL,
        `end_date` VARCHAR(50) NOT NULL,
        `closed_at` VARCHAR(50) NOT NULL,
        `closed_by` VARCHAR(100) NOT NULL,
        `total_sales` DECIMAL(14,2) DEFAULT 0.00,
        `total_purchases` DECIMAL(14,2) DEFAULT 0.00,
        `total_expenses` DECIMAL(14,2) DEFAULT 0.00,
        `net_profit` DECIMAL(14,2) DEFAULT 0.00,
        `closing_stock_value` DECIMAL(14,2) DEFAULT 0.00,
        `carried_forward_balance` DECIMAL(14,2) DEFAULT 0.00,
        `status` VARCHAR(50) DEFAULT 'closed',
        `notes` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 32. restaurant_tables & kot_orders
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `restaurant_tables` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(100) NOT NULL,
        `section` VARCHAR(100) DEFAULT 'Main Dining',
        `capacity` INT DEFAULT 4,
        `status` VARCHAR(50) DEFAULT 'vacant',
        `order_total` DECIMAL(12,2) DEFAULT 0.00,
        `kot_time` VARCHAR(50) NULL,
        `guests` INT DEFAULT 0,
        `current_order_id` VARCHAR(100) NULL,
        `waiter_name` VARCHAR(100) NULL,
        `waiter_id` INT UNSIGNED NULL,
        `current_sale_id` INT UNSIGNED NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `restaurant_kot_orders` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `kot_no` VARCHAR(100) NOT NULL,
        `table_name` VARCHAR(100) NOT NULL,
        `order_type` VARCHAR(50) DEFAULT 'Dine-In',
        `items` TEXT NOT NULL,
        `status` VARCHAR(50) DEFAULT 'Cooking',
        `time` VARCHAR(50) NULL,
        `server_name` VARCHAR(100) DEFAULT 'Captain',
        `items_json` LONGTEXT NULL,
        `special_notes` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 33. gym_members
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `gym_members` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `member_id` VARCHAR(50) NULL,
        `name` VARCHAR(150) NOT NULL,
        `phone` VARCHAR(50) NULL,
        `plan` VARCHAR(100) NULL,
        `fee` DECIMAL(12,2) DEFAULT 0.00,
        `locker` VARCHAR(50) NULL,
        `trainer` VARCHAR(100) NULL,
        `expiry_date` VARCHAR(50) NULL,
        `days_left` INT DEFAULT 30,
        `status` VARCHAR(50) DEFAULT 'Active',
        `created_at` VARCHAR(50) NULL
      ) ENGINE=InnoDB;
    ''');

    // 34. hotel_rooms
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `hotel_rooms` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `room` VARCHAR(50) NOT NULL,
        `type` VARCHAR(100) NOT NULL,
        `floor` VARCHAR(50) NULL,
        `rate` DECIMAL(12,2) DEFAULT 0.00,
        `status` VARCHAR(50) DEFAULT 'available',
        `guest` VARCHAR(200) NULL,
        `nights` INT DEFAULT 0,
        `check_in` VARCHAR(50) NULL,
        `room_service` DECIMAL(12,2) DEFAULT 0.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 35. repair_jobs
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `repair_jobs` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `job_no` VARCHAR(100) NOT NULL,
        `customer` VARCHAR(200) NOT NULL,
        `device` VARCHAR(150) NOT NULL,
        `phone` VARCHAR(50) NULL,
        `imei` VARCHAR(100) NULL,
        `fault` TEXT NULL,
        `technician` VARCHAR(100) NULL,
        `est_cost` DECIMAL(12,2) DEFAULT 0.00,
        `advance` DECIMAL(12,2) DEFAULT 0.00,
        `status` VARCHAR(50) DEFAULT 'Diagnosing',
        `date` VARCHAR(50) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 36. product_serials_batches
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `product_serials_batches` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `product_id` INT UNSIGNED NOT NULL,
        `product_name` VARCHAR(255) NOT NULL,
        `sku` VARCHAR(100) NULL,
        `serial_number_1` VARCHAR(100) NULL,
        `serial_number_2` VARCHAR(100) NULL,
        `batch_number` VARCHAR(100) NULL,
        `manufacturing_date` VARCHAR(50) NULL,
        `expiry_date` VARCHAR(50) NULL,
        `warranty_months` INT DEFAULT 0,
        `warranty_expiry_date` VARCHAR(50) NULL,
        `status` VARCHAR(50) DEFAULT 'in_stock',
        `purchase_id` INT UNSIGNED NULL,
        `sale_id` INT UNSIGNED NULL,
        `location_id` INT UNSIGNED DEFAULT 1,
        `purchase_price` DECIMAL(12,2) DEFAULT 0.00,
        `selling_price` DECIMAL(12,2) DEFAULT 0.00,
        `notes` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_serial_prod` (`product_id`),
        INDEX `idx_serial_batch` (`batch_number`)
      ) ENGINE=InnoDB;
    ''');

    // 37. product_bundles
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `product_bundles` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `parent_product_id` INT UNSIGNED NOT NULL,
        `sub_product_id` INT UNSIGNED NOT NULL,
        `sub_product_name` VARCHAR(255) NOT NULL,
        `sub_sku` VARCHAR(100) NULL,
        `quantity` DECIMAL(10,2) NOT NULL DEFAULT 1.00,
        `unit_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
        `is_optional` TINYINT(1) DEFAULT 0,
        `sort_order` INT DEFAULT 0,
        `notes` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_bundle_parent` (`parent_product_id`)
      ) ENGINE=InnoDB;
    ''');

    // 38. audit_logs
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `audit_logs` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `action` VARCHAR(100) NOT NULL,
        `entity_type` VARCHAR(100) NOT NULL,
        `entity_id` VARCHAR(100) NULL,
        `user_id` INT UNSIGNED NULL,
        `user_name` VARCHAR(150) NOT NULL,
        `details` TEXT NULL,
        `old_values` LONGTEXT NULL,
        `new_values` LONGTEXT NULL,
        `ip_address` VARCHAR(50) NULL,
        `timestamp` VARCHAR(50) NOT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_audit_entity` (`entity_type`, `entity_id`)
      ) ENGINE=InnoDB;
    ''');

    // 39. customer_groups
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `customer_groups` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(191) NOT NULL,
        `amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        `price_calculation_type` VARCHAR(50) DEFAULT 'percentage',
        `selling_price_group_id` INT UNSIGNED NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 40. cash_denominations
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `cash_denominations` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `cash_register_id` INT UNSIGNED NULL,
        `d5000` INT DEFAULT 0,
        `d1000` INT DEFAULT 0,
        `d500` INT DEFAULT 0,
        `d100` INT DEFAULT 0,
        `d50` INT DEFAULT 0,
        `d20` INT DEFAULT 0,
        `d10` INT DEFAULT 0,
        `d5` INT DEFAULT 0,
        `d2` INT DEFAULT 0,
        `d1` INT DEFAULT 0,
        `total_amount` DECIMAL(12,2) DEFAULT 0.00,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 41. product_racks
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `product_racks` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `business_location_id` INT UNSIGNED DEFAULT 1,
        `product_id` INT UNSIGNED NOT NULL,
        `rack` VARCHAR(191) NULL,
        `row` VARCHAR(191) NULL,
        `position` VARCHAR(191) NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_rack_prod` (`product_id`)
      ) ENGINE=InnoDB;
    ''');

    // 42. types_of_services
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `types_of_services` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(191) NOT NULL,
        `description` TEXT NULL,
        `location_id` INT UNSIGNED DEFAULT 1,
        `packing_charge_type` VARCHAR(50) DEFAULT 'fixed',
        `packing_charge` DECIMAL(10,2) DEFAULT 0.00,
        `enable_custom_fields` TINYINT(1) DEFAULT 0,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 43. invoice_layouts
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `invoice_layouts` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(191) NOT NULL,
        `header_text` TEXT NULL,
        `footer_text` TEXT NULL,
        `show_logo` TINYINT(1) DEFAULT 1,
        `show_tax` TINYINT(1) DEFAULT 1,
        `show_customer` TINYINT(1) DEFAULT 1,
        `show_barcode` TINYINT(1) DEFAULT 1,
        `paper_width` VARCHAR(20) DEFAULT '80mm',
        `is_default` TINYINT(1) DEFAULT 1,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 44. discounts
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `discounts` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `name` VARCHAR(191) NOT NULL,
        `discount_type` VARCHAR(50) DEFAULT 'percentage',
        `discount_amount` DECIMAL(10,2) DEFAULT 0.00,
        `starts_at` VARCHAR(50) NULL,
        `ends_at` VARCHAR(50) NULL,
        `brand_id` INT UNSIGNED NULL,
        `category_id` INT UNSIGNED NULL,
        `location_id` INT UNSIGNED NULL,
        `priority` INT DEFAULT 1,
        `is_active` TINYINT(1) DEFAULT 1,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB;
    ''');

    // 45. document_and_notes
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS `document_and_notes` (
        `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        `notable_id` INT UNSIGNED NOT NULL,
        `notable_type` VARCHAR(100) NOT NULL,
        `heading` VARCHAR(191) NOT NULL,
        `description` TEXT NULL,
        `media_path` TEXT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX `idx_note_parent` (`notable_type`, `notable_id`)
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
          `primary_db_type`, `db_host`, `db_port`, `db_name`, `db_user`, `is_configured`
        ) VALUES (
          1, :bizName, :branchName, :curSym, :curCode,
          :taxRate, :phone, :email, :addr, :invPrefix,
          :rcptFooter, :licKey, :bizType, :syncMode, :mods,
          :dbType, :dbHost, :dbPort, :dbName, :dbUser, 1
        ) ON DUPLICATE KEY UPDATE
          `business_name` = VALUES(`business_name`),
          `branch_name` = VALUES(`branch_name`),
          `currency_symbol` = VALUES(`currency_symbol`),
          `currency_code` = VALUES(`currency_code`),
          `business_type` = VALUES(`business_type`),
          `is_configured` = 1,
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
