import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService db;
  late String testDbPath;

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('smartpos_multibiz_test_');
    testDbPath = '${tempDir.path}${Platform.pathSeparator}test_smartpos.db';
    db = await DatabaseService.initialize(customPath: testDbPath);
  });

  tearDownAll(() async {
    try {
      final file = File(testDbPath);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  });

  group('Primary Central Database Engine (Admin Choice) & SQLite Sync Buffer', () {
    test('BusinessSettings supports MySQL as primary database with SQLite local sync', () {
      final s = BusinessSettings(
        primaryDbType: 'mysql',
        dbHost: '192.168.1.100',
        dbPort: 3306,
        dbName: 'smartpos_central',
        dbUser: 'root',
        dbPassword: 'secretpassword',
      );

      expect(s.isMySql, isTrue);
      expect(s.isPostgreSql, isFalse);
      expect(s.isSqlitePrimary, isFalse);
      expect(s.dbPort, equals(3306));

      final map = s.toMap();
      expect(map['primary_db_type'], equals('mysql'));

      final fromDb = BusinessSettings.fromMap(map);
      expect(fromDb.primaryDbType, equals('mysql'));
      expect(fromDb.isMySql, isTrue);
      expect(fromDb.dbHost, equals('192.168.1.100'));
    });

    test('BusinessSettings supports PostgreSQL as primary database', () {
      final s = BusinessSettings(
        primaryDbType: 'postgresql',
        dbHost: 'db.company.com',
        dbPort: 5432,
        dbName: 'smartpos_pg',
        dbUser: 'postgres',
      );

      expect(s.isMySql, isFalse);
      expect(s.isPostgreSql, isTrue);
      expect(s.isSqlitePrimary, isFalse);
      expect(s.dbPort, equals(5432));

      final copy = s.copyWith(primaryDbType: 'sqlite');
      expect(copy.isSqlitePrimary, isTrue);
    });

    test('Saving and reading primary_db_type in DatabaseService table', () async {
      var settings = await db.getBusinessSettings();
      expect(settings, isNotNull);

      final updated = settings.copyWith(
        primaryDbType: 'postgresql',
        dbHost: '10.0.0.5',
        dbPort: 5432,
        dbName: 'pos_main',
      );
      await db.updateBusinessSettings(updated);

      final reloaded = await db.getBusinessSettings();
      expect(reloaded.primaryDbType, equals('postgresql'));
      expect(reloaded.isPostgreSql, isTrue);
      expect(reloaded.dbHost, equals('10.0.0.5'));
    });
  });

  group('Multi-Business Testing: Seeding, Purge & Factory Reset Clean Slate', () {
    test('Seed Mobile & Electronics shop with IMEI serial tracking', () async {
      await db.seedInitialDataForBusinessType(businessType: 'mobile');

      final products = await db.getProducts();
      expect(products.isNotEmpty, isTrue);
      expect(products.any((p) => p.name.contains('Samsung Galaxy') || p.name.contains('iPhone')), isTrue);

      // Verify IMEI serial batch tracking
      final serials = await db.db.query('product_serials_batches');
      expect(serials.isNotEmpty, isTrue);
      expect(serials.any((s) => s['serial_number_1'] != null && s['serial_number_1'].toString().isNotEmpty), isTrue);
    });

    test('Complete Data Purge removes products and serials but preserves settings', () async {
      final beforePurge = await db.getProducts();
      expect(beforePurge.isNotEmpty, isTrue);

      await db.purgeAllBusinessData();

      final afterProducts = await db.getProducts();
      expect(afterProducts.isEmpty, isTrue);

      final afterCustomers = await db.getCustomers();
      expect(afterCustomers.isEmpty, isTrue);

      final afterSales = await db.getSales();
      expect(afterSales.isEmpty, isTrue);

      final afterSerials = await db.db.query('product_serials_batches');
      expect(afterSerials.isEmpty, isTrue);

      // Settings and structure still intact
      final settings = await db.getBusinessSettings();
      expect(settings, isNotNull);
    });

    test('Seed Solar & Inverter Systems with bundled BOM package', () async {
      await db.seedInitialDataForBusinessType(businessType: 'solar');

      final products = await db.getProducts();
      expect(products.isNotEmpty, isTrue);
      expect(products.any((p) => p.name.contains('Longi Solar') || p.name.contains('Inverter')), isTrue);

      // Verify BOM bundle packages
      final bundles = await db.db.query('product_bundles');
      expect(bundles.isNotEmpty, isTrue);
      expect(bundles.any((b) => b['sub_product_name'].toString().contains('Longi Hi-MO') || b['sub_product_name'].toString().contains('Inverex')), isTrue);
    });

    test('Factory Reset for New Business wipes everything and resets is_configured to 0', () async {
      final resetSettings = await db.factoryResetForNewBusiness();
      expect(resetSettings.isConfigured, isFalse);

      final products = await db.getProducts();
      expect(products.isEmpty, isTrue);

      final bundles = await db.db.query('product_bundles');
      expect(bundles.isEmpty, isTrue);

      // Super Administrator account must be created and ready for fresh setup
      final users = await db.getUsers();
      expect(users.isNotEmpty, isTrue);
      expect(users.any((u) => u.username == 'superadmin'), isTrue);
    });
  });
}
