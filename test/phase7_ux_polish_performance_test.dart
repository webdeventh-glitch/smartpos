import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/providers/providers.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_schema.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/keyboard_shortcuts_service.dart';
import 'package:desktop_starter/services/theme_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';
import 'package:desktop_starter/widgets/skeleton_loader.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    ThemeService.setTouchFriendly(false);
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase7_');
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
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
      'v7 to v8 schema migration adds Phase 7 columns and 5 performance indexes',
      () async {
    final dbPath = p.join(tempDir.path, 'upgrade_v7_v8.db');
    final raw = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await DatabaseSchema.createTables(db);
          await DatabaseSchema.seedInitialData(db);
          await DatabaseSchema.runMigrations(db, fromVersion: 0, toVersion: 7);
        },
      ),
    );
    await raw.close();

    final upgraded = await DatabaseService.initialize(customPath: dbPath);
    try {
      upgraded.invalidateReportCache();
      expect(
          await upgraded.db.getVersion(), DatabaseService.currentSchemaVersion);
      final migrations =
          await upgraded.db.query('schema_migrations', orderBy: 'version ASC');
      expect(migrations.map((m) => m['version']).toList(),
          [2, 3, 4, 5, 6, 7, 8, 9, 10]);

      final prodCols =
          (await upgraded.db.rawQuery('PRAGMA table_info(products)'))
              .map((r) => r['name'])
              .toSet();
      expect(prodCols.contains('is_featured'), isTrue);

      final bizCols =
          (await upgraded.db.rawQuery('PRAGMA table_info(business_settings)'))
              .map((r) => r['name'])
              .toSet();
      expect(
        bizCols.containsAll(['touch_friendly_mode', 'keyboard_shortcuts_json']),
        isTrue,
      );

      final syncCols =
          (await upgraded.db.rawQuery('PRAGMA table_info(sync_queue)'))
              .map((r) => r['name'])
              .toSet();
      expect(
        syncCols.containsAll(['entity_updated_at', 'conflict_resolution']),
        isTrue,
      );

      final indexRows = await upgraded.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      final indexNames = indexRows.map((r) => r['name']).toSet();
      expect(
        indexNames.containsAll([
          'idx_products_featured',
          'idx_sales_created_status',
          'idx_purchases_status_created',
          'idx_sync_queue_status',
          'idx_sale_items_prod',
        ]),
        isTrue,
      );
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Step 7.1 & 7.5: dashboard metrics filter by date range and cache with explicit invalidation',
      () async {
    final dbPath = p.join(tempDir.path, 'dash_date_cache.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      db.invalidateReportCache();
      await db.db.insert('sales', {
        'invoice_no': 'INV-JAN-01',
        'customer_name': 'Walk-in Customer',
        'total_amount': 500.0,
        'paid_amount': 500.0,
        'payment_method': 'cash',
        'sale_status': 'final',
        'created_at': '2026-01-10T11:30:00',
      });
      await db.db.insert('sales', {
        'invoice_no': 'INV-FEB-01',
        'customer_name': 'Walk-in Customer',
        'total_amount': 1200.0,
        'paid_amount': 1200.0,
        'payment_method': 'card',
        'sale_status': 'final',
        'created_at': '2026-02-15T15:45:00',
      });

      final febMetrics = await db.getDashboardMetrics(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
      );
      expect(febMetrics['totalSales'], closeTo(1200.0, 0.01));

      final janMetrics = await db.getDashboardMetrics(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 31),
      );
      expect(janMetrics['totalSales'], closeTo(500.0, 0.01));

      // Insert directly without cache clear -> cached Feb value remains 1200.0
      await db.db.insert('sales', {
        'invoice_no': 'INV-FEB-02',
        'customer_name': 'Walk-in Customer',
        'total_amount': 300.0,
        'paid_amount': 300.0,
        'payment_method': 'cash',
        'sale_status': 'final',
        'created_at': '2026-02-28T21:10:00',
      });
      final cachedFeb = await db.getDashboardMetrics(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
      );
      expect(cachedFeb['totalSales'], closeTo(1200.0, 0.01));

      // Clear / forceRefresh returns updated total 1500.0
      db.invalidateReportCache();
      final freshFeb = await db.getDashboardMetrics(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
      );
      expect(freshFeb['totalSales'], closeTo(1500.0, 0.01));

      final payBreakdown = await db.getPaymentMethodBreakdown(
        startDate: DateTime(2026, 2, 1),
        endDate: DateTime(2026, 2, 28),
      );
      expect(payBreakdown['CARD'], closeTo(1200.0, 0.01));
      expect(payBreakdown['CASH'], closeTo(300.0, 0.01));
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Step 7.2: Product.isFeatured persists and filters accurately in SQL & CatalogState',
      () async {
    final dbPath = p.join(tempDir.path, 'featured_filter.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      for (int i = 1; i <= 6; i++) {
        await db.addProduct(
          Product(
            name: 'Item $i',
            sku: 'SKU-$i',
            barcode: '8900000$i',
            purchasePrice: 50,
            sellingPrice: 80,
            stockQuantity: 10,
            isFeatured: i == 2 || i == 6,
          ),
        );
      }

      final featuredPage = await db.getProductsPaged(featuredOnly: true);
      expect(featuredPage.items.length, 2);
      expect(featuredPage.items.every((p) => p.isFeatured), isTrue);
      expect(
        featuredPage.items.map((p) => p.sku).toSet(),
        {'SKU-2', 'SKU-6'},
      );

      final allPage = await db.getProductsPaged(pageSize: 20);
      final filteredCatalog =
          CatalogState(products: allPage.items).filter(featuredOnly: true);
      expect(filteredCatalog.map((p) => p.sku).toSet(), {'SKU-2', 'SKU-6'});
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Step 7.3 & 7.4: KeyboardShortcutsService & TouchFriendlyMode settings persist cleanly',
      () async {
    final dbPath = p.join(tempDir.path, 'settings_phase7.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final defaults = KeyboardShortcutsService.resolveBindings('');
      expect(defaults['help'], 'F1');
      expect(defaults['quickCash'], 'F2');

      final customized = Map<String, String>.from(defaults)
        ..['quickCash'] = 'F11'
        ..['multiPay'] = 'F12';
      final encoded = KeyboardShortcutsService.encodeBindings(customized);

      final current = await db.getBusinessSettings();
      await db.updateBusinessSettings(
        current.copyWith(
          touchFriendlyMode: true,
          keyboardShortcutsJson: encoded,
        ),
      );

      final reloaded = await db.getBusinessSettings();
      expect(reloaded.touchFriendlyMode, isTrue);
      final decoded = KeyboardShortcutsService.resolveBindings(
          reloaded.keyboardShortcutsJson);
      expect(decoded['quickCash'], 'F11');
      expect(decoded['multiPay'], 'F12');
      expect(
        KeyboardShortcutsService.parseFunctionKey('F11'),
        LogicalKeyboardKey.f11,
      );

      ThemeService.setTouchFriendly(true);
      expect(
        ThemeService.lightTheme.materialTapTargetSize,
        MaterialTapTargetSize.padded,
      );
      expect(ThemeService.lightTheme.visualDensity, VisualDensity.standard);

      ThemeService.setTouchFriendly(false);
      expect(
        ThemeService.lightTheme.materialTapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Step 7.6: SyncRepository.resolveSyncConflict applies Last-Write-Wins with immutable audit trail',
      () async {
    final dbPath = p.join(tempDir.path, 'sync_lww.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final remoteWin = await db.resolveSyncConflict(
        entityType: 'product',
        entityId: '101',
        localRecord: {'name': 'Panadol', 'selling_price': 45.0},
        remoteRecord: {'name': 'Panadol Extra', 'selling_price': 55.0},
        localUpdatedAt: '2026-11-12T10:00:00',
        remoteUpdatedAt: '2026-11-12T10:05:00',
      );
      expect(remoteWin['winner'], 'remote_won');
      expect((remoteWin['record'] as Map)['selling_price'], 55.0);

      final localWin = await db.resolveSyncConflict(
        entityType: 'sale',
        entityId: '202',
        localRecord: {'invoice_number': 'INV-202', 'total_amount': 990.0},
        remoteRecord: {'invoice_number': 'INV-202', 'total_amount': 800.0},
        localUpdatedAt: '2026-11-12T11:30:00',
        remoteUpdatedAt: '2026-11-12T11:00:00',
      );
      expect(localWin['winner'], 'local_won');
      expect((localWin['record'] as Map)['total_amount'], 990.0);

      final syncRows = await db.db.query(
        'sync_queue',
        where: "action = 'conflict_resolved'",
        orderBy: 'id ASC',
      );
      expect(syncRows.length, 2);
      expect(syncRows.first['conflict_resolution'], 'remote_won');
      expect(syncRows.last['conflict_resolution'], 'local_won');

      final auditRows = await db.db.query(
        'activity_log',
        where: "action = 'conflict_resolved'",
      );
      expect(auditRows.length, 2);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  testWidgets('Step 7.5: Skeleton loaders render without errors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                DashboardSkeletonView(),
                TableSkeletonView(rowCount: 3),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(DashboardSkeletonView), findsOneWidget);
    expect(find.byType(TableSkeletonView), findsOneWidget);
  });

  testWidgets(
      'Step 7.4: PosTerminalScreen switches to compact tablet Catalog/Cart tabs at 1024x768',
      (tester) async {
    final dbPath = p.join(tempDir.path, 'pos_tablet_1024.db');
    await tester.runAsync(() async {
      final db = await DatabaseService.initialize(customPath: dbPath);
      await db.addProduct(
        Product(
          name: 'Tablet Test Panadol',
          sku: 'TAB-001',
          barcode: '777888999000',
          purchasePrice: 30,
          sellingPrice: 50,
          stockQuantity: 25,
          isFeatured: true,
        ),
      );
    });

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PosTerminalScreen(
              settings: BusinessSettings(
                businessName: 'Tablet Test Store',
                currencySymbol: 'Rs',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    });
    await tester.pump();

    expect(find.textContaining('Catalog ('), findsOneWidget);
    expect(find.textContaining('Cart ('), findsOneWidget);
    expect(find.textContaining('Tablet Test Panadol'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(() async {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    });
  });
}
