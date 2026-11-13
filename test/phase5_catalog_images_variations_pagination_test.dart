import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/providers/providers.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/screens/products/products_list_screen.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/pdf_export_service.dart';
import 'package:desktop_starter/services/product_image_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';
import 'package:desktop_starter/widgets/product_thumbnail.dart';

void main() {
  late Directory tempDir;
  late DatabaseService db;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase5_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'phase5.db'),
    );
  });

  tearDown(() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    await db.db.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  File writeSamplePng(String name, int width, int height,
      {bool transparent = false}) {
    final canvas = img.Image(
      width: width,
      height: height,
      numChannels: transparent ? 4 : 3,
    );
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (transparent && x < width ~/ 2) {
          canvas.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          canvas.setPixelRgba(
              x, y, (x * 255) ~/ width, (y * 255) ~/ height, 180, 255);
        }
      }
    }
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync(img.encodePng(canvas));
    return file;
  }

  group('Phase 5 Step 5.1 - Product Images & Compression', () {
    test(
        'resizes oversized opaque images to 512px max JPEG and cleans superseded managed image',
        () async {
      final imgDir = Directory(p.join(tempDir.path, 'product_images'));
      final source = writeSamplePng('oversized_product.png', 1600, 1200);

      final savedPath1 = await ProductImageService.saveCompressedProductImage(
        source.path,
        directoryOverride: imgDir,
      );
      expect(savedPath1, isNotNull);
      expect(File(savedPath1!).existsSync(), isTrue);
      expect(p.extension(savedPath1).toLowerCase(), '.jpg');
      expect(p.dirname(savedPath1), imgDir.path);

      final decoded1 = img.decodeImage(File(savedPath1).readAsBytesSync());
      expect(decoded1, isNotNull);
      expect(decoded1!.width, 512);
      expect(decoded1.height, 384);

      final source2 =
          writeSamplePng('transparent_cutout.png', 800, 600, transparent: true);
      final savedPath2 = await ProductImageService.saveCompressedProductImage(
        source2.path,
        existingImagePath: savedPath1,
        directoryOverride: imgDir,
      );
      expect(savedPath2, isNotNull);
      expect(p.extension(savedPath2!).toLowerCase(), '.png');
      expect(File(savedPath2).existsSync(), isTrue);
      expect(File(savedPath1).existsSync(), isFalse);

      final prodId = await db.addProduct(
        Product(
          name: 'Camera Lens',
          sku: 'CAM-50',
          barcode: 'CAM-50',
          purchasePrice: 5000,
          sellingPrice: 7500,
          stockQuantity: 10,
          imageColor: '#10B981',
          imagePath: savedPath2,
        ),
      );
      final fetched = await db.getProductById(prodId);
      expect(fetched, isNotNull);
      expect(fetched!.imagePath, savedPath2);
      expect(fetched.resolvedImagePath, savedPath2);

      // Verify invoice PDF export resolves product image path for PDF image column
      final pathMap = await db.getProductImagePathsByIds([prodId]);
      expect(pathMap[prodId], savedPath2);

      final pdfBytes = await PdfExportService.generateSalePdf(
        sale: Sale(
          invoiceNo: 'INV-IMG-1',
          subtotal: 7500,
          totalAmount: 7500,
          paidAmount: 7500,
          createdAt: DateTime.now().toIso8601String(),
          items: [
            SaleItem(
              saleId: 1,
              productId: prodId,
              productName: 'Camera Lens',
              sku: 'CAM-50',
              unitPrice: 7500,
              quantity: 1,
              subtotal: 7500,
            ),
          ],
        ),
        settings:
            BusinessSettings(businessName: 'Photo Shop', currencySymbol: 'Rs'),
        layout: InvoiceLayout(name: 'With Images', showImage: true),
        productImagePathsById: pathMap,
      );
      expect(pdfBytes.length, greaterThan(500));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });

    test(
        'v5 to v6 migration adds products.image_path, sale_items variation columns, and migrates legacy image_color paths',
        () async {
      await db.db.close();
      final v5DbPath = p.join(tempDir.path, 'legacy_v5.db');
      final legacyImg = writeSamplePng('legacy_img.png', 200, 200);

      final v5Raw = await databaseFactoryFfi.openDatabase(
        v5DbPath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (rawDb, _) async {
            await rawDb.execute('''
              CREATE TABLE products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                sku TEXT NOT NULL UNIQUE,
                barcode TEXT NOT NULL UNIQUE,
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
                rack_location TEXT,
                tax_rate_id INTEGER,
                tax_group_id INTEGER
              )
            ''');
            await rawDb.execute('''
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
            await rawDb.execute('''
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
                created_at TEXT NOT NULL,
                user_name TEXT,
                converted_from_quotation_id INTEGER,
                converted_to_sale_id INTEGER,
                tax_group_id INTEGER,
                tax_breakdown_json TEXT DEFAULT ''
              )
            ''');
            await rawDb.execute('''
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
                unit_name TEXT,
                unit_multiplier REAL DEFAULT 1.0,
                discount_type TEXT DEFAULT 'fixed',
                discount_value REAL DEFAULT 0.0,
                tax_amount REAL DEFAULT 0.0,
                tax_name TEXT
              )
            ''');
            await rawDb.execute('''
              CREATE TABLE purchases (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ref_no TEXT NOT NULL UNIQUE,
                supplier_id INTEGER,
                supplier_name TEXT NOT NULL,
                total_amount REAL NOT NULL,
                paid_amount REAL NOT NULL,
                status TEXT DEFAULT 'received',
                payment_status TEXT DEFAULT 'paid',
                created_at TEXT NOT NULL
              )
            ''');
            await rawDb.execute('''
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
                loyalty_points REAL DEFAULT 0.0
              )
            ''');
            await rawDb.execute('''
              CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                username TEXT NOT NULL UNIQUE,
                password TEXT NOT NULL,
                role TEXT DEFAULT 'cashier',
                created_at TEXT
              )
            ''');
            await rawDb.execute('''
              CREATE TABLE business_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                business_name TEXT DEFAULT 'SmartPOS'
              )
            ''');
            await rawDb.execute('''
              CREATE TABLE sale_return_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                return_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                product_name TEXT NOT NULL,
                sku TEXT,
                batch_number TEXT,
                quantity REAL NOT NULL,
                unit_price REAL NOT NULL,
                subtotal REAL NOT NULL
              )
            ''');
            await rawDb.insert('products', {
              'name': 'Legacy Img Product',
              'sku': 'LEG-IMG',
              'barcode': 'LEG-IMG',
              'purchase_price': 10,
              'selling_price': 20,
              'stock_quantity': 5,
              'image_color': legacyImg.path,
            });
            await rawDb.insert('products', {
              'name': 'Hex Color Product',
              'sku': 'LEG-HEX',
              'barcode': 'LEG-HEX',
              'purchase_price': 10,
              'selling_price': 20,
              'stock_quantity': 5,
              'image_color': '#10B981',
            });
          },
        ),
      );
      await v5Raw.close();

      db = await DatabaseService.initialize(customPath: v5DbPath);
      expect(await db.db.getVersion(), DatabaseService.currentSchemaVersion);

      final imgProd = (await db.getProducts(search: 'LEG-IMG')).first;
      expect(imgProd.imagePath, legacyImg.path);
      expect(imgProd.imageColor, '#004EEB');
      expect(imgProd.resolvedImagePath, legacyImg.path);

      final hexProd = (await db.getProducts(search: 'LEG-HEX')).first;
      expect(hexProd.imagePath, isNull);
      expect(hexProd.imageColor, '#10B981');
      expect(hexProd.resolvedImagePath, isNull);

      final saleItemCols =
          await db.db.rawQuery('PRAGMA table_info(sale_items)');
      final colNames = saleItemCols.map((r) => r['name']).toSet();
      expect(colNames.containsAll(['variation_id', 'variation_name']), isTrue);

      final returnItemCols =
          await db.db.rawQuery('PRAGMA table_info(sale_return_items)');
      final returnColNames = returnItemCols.map((r) => r['name']).toSet();
      expect(returnColNames.containsAll(['variation_id', 'variation_name']),
          isTrue);
    });
  });

  group('Phase 5 Step 5.2 - Product Variations, Cart Lines & Variation Stock',
      () {
    test(
        'separates variations in CartNotifier and updates variations.stock_quantity on sales, returns, and purchases',
        () async {
      final prodId = await db.addProductWithVariations(
        Product(
          name: 'Cotton Polo Shirt',
          sku: 'POLO-01',
          barcode: 'POLO-01',
          type: 'variable',
          purchasePrice: 800,
          sellingPrice: 1200,
          stockQuantity: 23,
        ),
        [
          ProductVariation(
            productId: 0,
            name: 'Size: Medium',
            subSku: 'POLO-01-M',
            purchasePrice: 800,
            sellingPrice: 1200,
            stockQuantity: 15,
          ),
          ProductVariation(
            productId: 0,
            name: 'Size: Large',
            subSku: 'POLO-01-L',
            purchasePrice: 900,
            sellingPrice: 1500,
            stockQuantity: 8,
          ),
        ],
      );

      final product = (await db.getProductById(prodId))!;
      final variations = await db.getProductVariations(prodId);
      final medium = variations.firstWhere((v) => v.subSku == 'POLO-01-M');
      final large = variations.firstWhere((v) => v.subSku == 'POLO-01-L');

      // Direct variation sub_sku lookup returns parent Product + exact ProductVariation
      final scanMatch =
          await db.getProductWithMatchedVariationByCode('POLO-01-L');
      expect(scanMatch, isNotNull);
      expect(scanMatch!.$1.id, prodId);
      expect(scanMatch.$2?.id, large.id);

      // CartNotifier preserves separate cart lines per variation and preserves variation price under tier pricing
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cartNotifier = container.read(cartProvider.notifier);
      cartNotifier.addProduct(product, quantity: 2, variation: medium);
      cartNotifier.addProduct(product, quantity: 3, variation: large);
      cartNotifier.addProduct(product,
          quantity: 1, variation: medium); // merges with Medium only

      var cart = container.read(cartProvider);
      expect(cart.items.length, 2);
      expect(cart.items[0].variationId, medium.id);
      expect(cart.items[0].quantity, 3);
      expect(cart.items[0].unitPrice, 1200);
      expect(cart.items[0].displayName, 'Cotton Polo Shirt (Size: Medium)');
      expect(cart.items[1].variationId, large.id);
      expect(cart.items[1].quantity, 3);
      expect(cart.items[1].unitPrice, 1500);
      expect(cart.items[1].displayName, 'Cotton Polo Shirt (Size: Large)');

      cartNotifier
          .applyCustomerGroup(const CustomerGroup(name: 'VIP', amount: -10.0));
      cart = container.read(cartProvider);
      expect(cart.items[0].unitPrice, 1080.0);
      expect(cart.items[1].unitPrice, 1350.0);

      // Create sale -> deducts stock from exact variations and keeps parent synced
      final createdSale = await db.createSale(
        sale: Sale(
          invoiceNo: 'INV-VAR-1',
          subtotal: cart.subtotal,
          totalAmount: cart.subtotal,
          paidAmount: cart.subtotal,
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: cart.items,
      );

      final saleItems = await db.getSaleItems(createdSale.id!);
      expect(saleItems.length, 2);
      expect(saleItems[0].variationId, medium.id);
      expect(saleItems[1].variationId, large.id);

      final afterSaleVars = await db.getProductVariations(prodId);
      expect(afterSaleVars.firstWhere((v) => v.id == medium.id).stockQuantity,
          12.0); // 15 - 3
      expect(afterSaleVars.firstWhere((v) => v.id == large.id).stockQuantity,
          5.0); // 8 - 3
      expect((await db.getProductById(prodId))!.stockQuantity, 17.0); // 12 + 5

      // Sale Return restores specific variation stock
      await db.addSaleReturn(
        SaleReturn(
          returnNo: 'SR-VAR-1',
          saleId: createdSale.id,
          invoiceNo: createdSale.invoiceNo,
          customerName: 'Walk-in Customer',
          date: DateTime.now().toIso8601String(),
          totalAmount: 1350.0,
          refundAmount: 1350.0,
          items: [
            SaleReturnItem(
              returnId: 0,
              productId: prodId,
              variationId: large.id,
              variationName: large.name,
              productName: product.name,
              sku: large.subSku,
              quantity: 2,
              unitPrice: 1350.0,
              subtotal: 2700.0,
            ),
          ],
        ),
      );
      final afterReturnVars = await db.getProductVariations(prodId);
      expect(afterReturnVars.firstWhere((v) => v.id == large.id).stockQuantity,
          7.0); // 5 + 2
      expect((await db.getProductById(prodId))!.stockQuantity, 19.0);

      // Purchase increments variation stock when received and reverses when status changed to pending
      final purchaseId = await db.createPurchase(
        purchase: Purchase(
          refNo: 'PO-VAR-1',
          supplierName: 'Apparel Mill',
          totalAmount: 4000,
          paidAmount: 4000,
          status: 'received',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          {
            'product_id': prodId,
            'variation_id': medium.id,
            'quantity': 5,
            'purchase_price': 800.0,
            'selling_price': 1250.0,
          },
        ],
      );
      final afterPurchaseVars = await db.getProductVariations(prodId);
      expect(
          afterPurchaseVars.firstWhere((v) => v.id == medium.id).stockQuantity,
          17.0); // 12 + 5
      expect((await db.getProductById(prodId))!.stockQuantity, 24.0);

      await db.updatePurchaseStatus(purchaseId, 'pending');
      final afterRevertVars = await db.getProductVariations(prodId);
      expect(afterRevertVars.firstWhere((v) => v.id == medium.id).stockQuantity,
          12.0);
      expect((await db.getProductById(prodId))!.stockQuantity, 19.0);
    });
  });

  group('Phase 5 Step 5.3 - Server-Side Pagination & 50,000-Product Benchmark',
      () {
    test(
        'handles 50,000 products with fast cursor paging, page queries, and SQL aggregate stats',
        () async {
      await db.db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 1; i <= 50000; i++) {
          final padded = i.toString().padLeft(5, '0');
          batch.insert('products', {
            'name': 'Benchmark Item $padded',
            'sku': 'BM-$padded',
            'barcode': '89600$padded',
            'category_id': (i % 5) + 1,
            'category_name': 'General',
            'brand_id': 1,
            'brand_name': 'Standard',
            'unit': 'Pc',
            'purchase_price': 10.0,
            'selling_price': 15.0,
            'stock_quantity': i <= 500 ? 0.0 : (i <= 1500 ? 3.0 : 20.0),
            'alert_quantity': 5.0,
            'image_color': '#004EEB',
            'type': 'single',
          });
        }
        await batch.commit(noResult: true);
      });

      final swStats = Stopwatch()..start();
      final stats = await db.getProductCatalogStats();
      swStats.stop();
      expect(stats['totalCount'], 50000);
      expect(stats['outOfStockCount'], 500);
      expect(stats['lowStockCount'], 1000);
      expect(swStats.elapsedMilliseconds, lessThan(400));

      final swPage1 = Stopwatch()..start();
      final page1 = await db.getProductsPaged(page: 1, pageSize: 25);
      swPage1.stop();
      expect(page1.items.length, 25);
      expect(page1.totalCount, 50000);
      expect(page1.totalPages, 2000);
      expect(page1.hasMore, isTrue);
      expect(swPage1.elapsedMilliseconds, lessThan(400));

      // Cursor-based traversal produces contiguous unique slices
      final swCursor = Stopwatch()..start();
      final page2 = await db.getProductsPaged(
        pageSize: 25,
        cursorName: page1.nextCursorSortValue,
        cursorId: page1.nextCursorId,
        includeTotalCount: false,
      );
      final page3 = await db.getProductsPaged(
        pageSize: 25,
        cursorName: page2.nextCursorSortValue,
        cursorId: page2.nextCursorId,
        includeTotalCount: false,
      );
      swCursor.stop();
      expect(page2.items.length, 25);
      expect(page3.items.length, 25);
      expect(swCursor.elapsedMilliseconds, lessThan(250));

      final seenIds = <int>{
        ...page1.items.map((p) => p.id!),
        ...page2.items.map((p) => p.id!),
        ...page3.items.map((p) => p.id!),
      };
      expect(seenIds.length, 75);
      expect(page1.items.last.name, 'Benchmark Item 00025');
      expect(page2.items.first.name, 'Benchmark Item 00026');
      expect(page3.items.first.name, 'Benchmark Item 00051');

      final filteredPage = await db.getProductsPaged(
        search: 'BM-49995',
        stockFilter: 'in_stock',
        pageSize: 10,
      );
      expect(filteredPage.totalCount, 1);
      expect(filteredPage.items.first.sku, 'BM-49995');

      final outPage = await db.getProductsPaged(
        stockFilter: 'out_of_stock',
        page: 1,
        pageSize: 25,
      );
      expect(outPage.totalCount, 500);
    });

    test(
        'getSalesPaged, getPurchasesPaged, and getContactsPaged slice accurately on the server',
        () async {
      final now = DateTime.now().toIso8601String();
      for (var i = 1; i <= 15; i++) {
        await db.db.insert('sales', {
          'invoice_no': 'INV-PG-$i',
          'customer_name': i.isEven ? 'Alpha Client' : 'Beta Client',
          'subtotal': 100.0 * i,
          'total_amount': 100.0 * i,
          'paid_amount': 100.0 * i,
          'sale_status': i <= 12 ? 'final' : 'draft',
          'created_at': now,
        });
        await db.db.insert('purchases', {
          'ref_no': 'PO-PG-$i',
          'supplier_name': 'Supplier $i',
          'total_amount': 200.0 * i,
          'paid_amount': i <= 10 ? 200.0 * i : 0.0,
          'status': i <= 10 ? 'received' : 'pending',
          'payment_status': i <= 10 ? 'paid' : 'due',
          'created_at': now,
        });
        await db.db.insert('contacts', {
          'type': 'customer',
          'name': 'Customer ${i.toString().padLeft(2, '0')}',
          'phone': '030000000${i.toString().padLeft(2, '0')}',
          'balance': i <= 5 ? 500.0 : 0.0,
          'credit_limit': i == 1 ? 300.0 : 1000.0,
        });
      }

      final salesPage =
          await db.getSalesPaged(status: 'final', page: 2, pageSize: 5);
      expect(salesPage.totalCount, 12);
      expect(salesPage.totalPages, 3);
      expect(salesPage.items.length, 5);
      final salesCounts = await db.getSalesTabCounts();
      expect(salesCounts['final'], 12);
      expect(salesCounts['draft'], 3);

      final purchasePage = await db.getPurchasesPaged(
        status: 'pending',
        paymentStatus: 'due',
        page: 1,
        pageSize: 3,
      );
      expect(purchasePage.totalCount, 5);
      expect(purchasePage.items.length, 3);
      final purchaseStats = await db.getPurchaseSummaryStats();
      expect(purchaseStats['receivedCount'], 10);
      expect(purchaseStats['pendingCount'], 5);

      final defaultersPage = await db.getContactsPaged(
        type: 'customer',
        balanceFilter: 'defaulters',
        page: 1,
        pageSize: 3,
      );
      expect(defaultersPage.totalCount, 5);
      expect(defaultersPage.items.length, 3);
      final contactStats = await db.getContactSummaryStats(type: 'customer');
      expect(contactStats['activeDuesCount'], 5);
      expect(contactStats['overLimitCount'], 1);
    });
  });

  group(
      'Phase 5 Widget Tests - Thumbnails, Variation Popup & Server-Side Paging UI',
      () {
    testWidgets(
        'ProductsListScreen renders ProductThumbnail and loads next DB page on pagination tap',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        final imgDir = Directory(p.join(tempDir.path, 'ui_images'));
        final src = writeSamplePng('thumb_src.png', 160, 160);
        final compressedPath =
            await ProductImageService.saveCompressedProductImage(
          src.path,
          directoryOverride: imgDir,
        );

        for (var i = 1; i <= 15; i++) {
          await db.addProduct(
            Product(
              name: 'Catalog Item ${i.toString().padLeft(2, '0')}',
              sku: 'CAT-${i.toString().padLeft(2, '0')}',
              barcode: 'CAT-${i.toString().padLeft(2, '0')}',
              purchasePrice: 50,
              sellingPrice: 80,
              stockQuantity: 10,
              imagePath: i == 1 ? compressedPath : null,
            ),
          );
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductsListScreen(
              settings: BusinessSettings(
                  businessName: 'Catalog Test', currencySymbol: 'Rs'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();

      expect(find.byType(ProductThumbnail), findsWidgets);
      expect(find.text('Catalog Item 01'), findsOneWidget);
      expect(find.text('Catalog Item 11'), findsNothing);

      // Navigate to page 2 via Next Page button on DataTablePaginationBar
      await tester.ensureVisible(find.byTooltip('Next Page'));
      await tester.tap(find.byTooltip('Next Page'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();

      expect(find.text('Catalog Item 11'), findsOneWidget);
      expect(find.text('Catalog Item 01'), findsNothing);
    });

    testWidgets(
        'PosTerminalScreen opens variation selector modal for variable products and adds selected variant',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await db.addProductWithVariations(
          Product(
            name: 'Denim Jacket',
            sku: 'DNM-01',
            barcode: 'DNM-01',
            type: 'variable',
            purchasePrice: 2000,
            sellingPrice: 3200,
            stockQuantity: 12,
          ),
          [
            ProductVariation(
              productId: 0,
              name: 'Blue - M',
              subSku: 'DNM-01-BM',
              purchasePrice: 2000,
              sellingPrice: 3200,
              stockQuantity: 5,
            ),
            ProductVariation(
              productId: 0,
              name: 'Black - XL',
              subSku: 'DNM-01-BXL',
              purchasePrice: 2100,
              sellingPrice: 3600,
              stockQuantity: 7,
            ),
          ],
        );
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: PosTerminalScreen(
                settings: BusinessSettings(
                    businessName: 'POS Var Test', currencySymbol: 'Rs'),
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.text('Denim Jacket'), findsOneWidget);
      expect(find.text('VAR'), findsOneWidget);

      await tester.tap(find.text('Denim Jacket'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text('Blue - M'), findsOneWidget);
      expect(find.text('Black - XL'), findsOneWidget);

      await tester.tap(find.text('Black - XL'));
      await tester.pump();

      final cart = container.read(cartProvider);
      expect(cart.items.length, 1);
      expect(cart.items.first.variationName, 'Black - XL');
      expect(cart.items.first.unitPrice, 3600.0);
      expect(find.text('Denim Jacket (Black - XL)'), findsOneWidget);
    });
  });
}
