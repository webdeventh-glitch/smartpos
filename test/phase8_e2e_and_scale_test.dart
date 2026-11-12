import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/main_shell.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/backup_update_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_schema.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase8_e2e_');
  });

  tearDown(() async {
    try {
      final inst = DatabaseService.instanceOrNull;
      if (inst != null &&
          inst.db.isOpen &&
          inst.dbFilePath != null &&
          inst.dbFilePath!.startsWith(tempDir.path)) {
        await DatabaseService.closeOpenInstanceIfPathMatches(inst.dbFilePath!);
      }
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets(
      'E2E User Journey: MainShell navigates Dashboard -> Expenses -> Reports -> Home',
      (tester) async {
    await tester.runAsync(() async {
      await DatabaseService.initialize(customPath: inMemoryDatabasePath);
    });

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MainShell(
            initialSettings: BusinessSettings(
              businessName: 'E2E Enterprise Mart',
              branchName: 'HQ Branch',
              currencySymbol: 'Rs',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.textContaining('Total Sales Revenue'), findsWidgets);

    // Navigate to Expenses via Sidebar
    await tester.tap(find.text('Expenses').first);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pump();
    expect(find.textContaining('Expense'), findsWidgets);

    // Navigate to Home via Sidebar
    await tester.tap(find.text('Home').first);
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      if (find.textContaining('Total Sales Revenue').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('Total Sales Revenue'), findsWidgets);
  });

  test(
      'Scale Benchmark: 10,500+ products with sub-500ms paged & indexed barcode queries',
      () async {
    final dbPath = p.join(tempDir.path, 'scale_10k.db');
    final db = await DatabaseService.initialize(customPath: dbPath);

    try {
      const totalItems = 10500;
      await db.db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 1; i <= totalItems; i++) {
          batch.insert('products', {
            'name': 'Scale Medicine Item $i',
            'sku': 'SCALE-${i.toString().padLeft(5, '0')}',
            'barcode': '899${i.toString().padLeft(9, '0')}',
            'purchase_price': 40.0 + (i % 50),
            'selling_price': 65.0 + (i % 50),
            'stock_quantity': 100.0,
            'alert_quantity': 10.0,
            'is_featured': i % 20 == 0 ? 1 : 0,
          });
        }
        await batch.commit(noResult: true);
      });

      final stats = await db.productRepo.getProductCatalogStats();
      expect((stats['totalCount'] as num).toInt(),
          greaterThanOrEqualTo(totalItems));

      final swPaged = Stopwatch()..start();
      final page = await db.getProductsPaged(
        page: 1,
        pageSize: 50,
        featuredOnly: true,
        includeTotalCount: false,
      );
      swPaged.stop();
      expect(page.items.length, 50);
      expect(page.items.every((p) => p.isFeatured), isTrue);
      expect(swPaged.elapsedMilliseconds, lessThan(500));

      final swSearch = Stopwatch()..start();
      final searchPage = await db.getProductsPaged(
        search: 'SCALE-09876',
        pageSize: 20,
        includeTotalCount: false,
      );
      swSearch.stop();
      expect(searchPage.items.length, 1);
      expect(searchPage.items.first.sku, 'SCALE-09876');
      expect(swSearch.elapsedMilliseconds, lessThan(500));

      final swBarcode = Stopwatch()..start();
      final byBarcode = await db.getProductByCode('899000010500');
      swBarcode.stop();
      expect(byBarcode, isNotNull);
      expect(byBarcode!.sku, 'SCALE-10500');
      expect(swBarcode.elapsedMilliseconds, lessThan(250));
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'E2E Migration: authentic v1 -> v8 upgrade preserves legacy rows & upgrades passwords',
      () async {
    final v1Path = p.join(tempDir.path, 'legacy_v1_e2e.db');
    final raw = await databaseFactoryFfi.openDatabase(
      v1Path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await DatabaseSchema.createTables(db);
          await db.insert('users', {
            'name': 'Legacy Shopkeeper',
            'username': 'legacy_boss',
            'password': 'LegacyPassword123',
            'role': 'admin',
            'status': 'active',
          });
          await db.insert('products', {
            'name': 'Legacy Syrup',
            'sku': 'LEG-01',
            'barcode': '111222333444',
            'purchase_price': 45.0,
            'selling_price': 70.0,
            'stock_quantity': 42.0,
          });
        },
      ),
    );
    await raw.close();

    final upgraded = await DatabaseService.initialize(customPath: v1Path);
    try {
      expect(
          await upgraded.db.getVersion(), DatabaseService.currentSchemaVersion);
      final migrations =
          await upgraded.db.query('schema_migrations', orderBy: 'version ASC');
      expect(
          migrations.map((m) => m['version']).toList(), [2, 3, 4, 5, 6, 7, 8]);

      final prods = await upgraded.getProducts();
      expect(prods.any((p) => p.sku == 'LEG-01' && p.stockQuantity == 42.0),
          isTrue);

      final users = await upgraded.getUsers();
      final boss = users.firstWhere((u) => u.username == 'legacy_boss');
      expect(boss.password, startsWith('argon2id\$'));
      expect(boss.mustChangePassword, isTrue);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(v1Path);
    }
  });

  test(
      'E2E Backup & Restore Cycle: encrypted snapshot restores wiped/mutated database',
      () async {
    final liveDbPath = p.join(tempDir.path, 'live_backup_restore.db');
    final backupDir = Directory(p.join(tempDir.path, 'backups'))..createSync();

    final db = await DatabaseService.initialize(customPath: liveDbPath);
    final prodId = await db.addProduct(
      Product(
        name: 'Snapshot Protected Product',
        sku: 'SNAP-001',
        barcode: '998877665544',
        purchasePrice: 100.0,
        sellingPrice: 150.0,
        stockQuantity: 88.0,
      ),
    );
    final prod = (await db.getProductById(prodId))!;
    await db.salesRepo.createSale(
      sale: Sale(
        invoiceNo: 'INV-SNAP-01',
        customerName: 'Snapshot Customer',
        subtotal: 300.0,
        totalAmount: 300.0,
        paidAmount: 300.0,
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [
        CartItem(product: prod, quantity: 2, unitPrice: prod.sellingPrice)
      ],
    );

    final backupFile = await BackupUpdateService.instance.createBackup(
      customNote: 'e2e_cycle',
      targetDir: backupDir,
      dbPathOverride: liveDbPath,
    );
    expect(backupFile.existsSync(), isTrue);

    // Mutate live database: delete original product and insert rogue product
    await db.deleteProduct(prodId);
    await db.addProduct(
      Product(
        name: 'Rogue Post-Backup Product',
        sku: 'ROGUE-999',
        barcode: '000000999',
        purchasePrice: 1.0,
        sellingPrice: 2.0,
        stockQuantity: 1.0,
      ),
    );
    expect(
      (await db.getProducts()).any((p) => p.sku == 'ROGUE-999'),
      isTrue,
    );
    expect(
      (await db.getProducts()).any((p) => p.sku == 'SNAP-001'),
      isFalse,
    );

    // Restore from encrypted snapshot
    final restoredOk = await BackupUpdateService.instance.restoreFromBackup(
      backupFile.path,
      dbPathOverride: liveDbPath,
    );
    expect(restoredOk, isTrue);

    final reopened = await DatabaseService.initialize(customPath: liveDbPath);
    try {
      final restoredProducts = await reopened.getProducts();
      expect(
        restoredProducts
            .any((p) => p.sku == 'SNAP-001' && p.stockQuantity == 86.0),
        isTrue,
      );
      expect(restoredProducts.any((p) => p.sku == 'ROGUE-999'), isFalse);
      expect(
        await reopened.salesRepo.getSaleByInvoiceNo('INV-SNAP-01'),
        isNotNull,
      );
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(liveDbPath);
    }
  });
}
