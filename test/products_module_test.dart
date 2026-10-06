import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/screens/products/brands_screen.dart';
import 'package:desktop_starter/screens/products/units_screen.dart';
import 'package:desktop_starter/screens/products/variation_templates_screen.dart';
import 'package:desktop_starter/screens/products/warranties_screen.dart';
import 'package:desktop_starter/screens/products/selling_price_groups_screen.dart';
import 'package:desktop_starter/screens/products/import_products_screen.dart';
import 'package:desktop_starter/screens/products/print_labels_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Products Module: Complete CRUD for Variations, Units, Brands, Price Groups, Warranties', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_products_mod_test_');
    final dbPath = '${tempDir.path}/test_products_mod.db';
    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Variation Templates
    final templates = await dbService.getVariationTemplates();
    expect(templates.isNotEmpty, isTrue);
    final newTempId = await dbService.addVariationTemplate(
      VariationTemplate(name: 'Shoe Size', values: ['US 8', 'US 9', 'US 10']),
    );
    expect(newTempId, isNonZero);
    final fetchedTemp = await dbService.getVariationTemplates();
    expect(fetchedTemp.any((t) => t.name == 'Shoe Size'), isTrue);

    // 2. Units
    final newUnitId = await dbService.addUnit(
      Unit(actualName: 'Carton', shortName: 'Ctn', allowDecimal: false, baseUnitMultiplier: 24.0),
    );
    expect(newUnitId, isNonZero);
    final units = await dbService.getUnits();
    expect(units.any((u) => u.shortName == 'Ctn'), isTrue);

    // 3. Brands
    final newBrandId = await dbService.addBrand(
      Brand(name: 'Apple Inc', description: 'Premium Electronics'),
    );
    expect(newBrandId, isNonZero);
    final brands = await dbService.getBrands();
    expect(brands.any((b) => b.name == 'Apple Inc'), isTrue);

    // 4. Selling Price Groups
    final newPgId = await dbService.addSellingPriceGroup(
      SellingPriceGroup(name: 'Corporate Partner Price', description: '10% flat rebate'),
    );
    expect(newPgId, isNonZero);
    final pgs = await dbService.getSellingPriceGroups();
    expect(pgs.any((p) => p.name == 'Corporate Partner Price'), isTrue);

    // 5. Warranties
    final newWarId = await dbService.addWarranty(
      Warranty(name: '2 Years Extended AppleCare', duration: 24, durationType: 'months'),
    );
    expect(newWarId, isNonZero);
    final warranties = await dbService.getWarranties();
    expect(warranties.any((w) => w.name == '2 Years Extended AppleCare'), isTrue);

    // 6. Variable Product Create and Update with Variations
    final product = Product(
      name: 'MacBook Pro 14"',
      sku: 'MAC-14-PRO',
      barcode: 'MAC-14-PRO',
      type: 'variable',
      categoryName: 'Electronics',
      brandName: 'Apple Inc',
      purchasePrice: 1500.0,
      sellingPrice: 1999.0,
      stockQuantity: 20.0,
      unit: 'Pc',
      warranty: '2 Years Extended AppleCare',
    );

    final initialVars = [
      ProductVariation(
        name: '512GB SSD Space Gray',
        subSku: 'MAC-14-512',
        purchasePrice: 1500.0,
        sellingPrice: 1999.0,
        stockQuantity: 12.0,
      ),
      ProductVariation(
        name: '1TB SSD Silver',
        subSku: 'MAC-14-1TB',
        purchasePrice: 1700.0,
        sellingPrice: 2299.0,
        stockQuantity: 8.0,
      ),
    ];

    final prodId = await dbService.addProductWithVariations(product, initialVars);
    expect(prodId, isNonZero);

    final loadedProd = await dbService.getProductById(prodId);
    expect(loadedProd, isNotNull);
    expect(loadedProd!.variations!.length, equals(2));

    // Update with new variation
    final updatedVars = [
      ...initialVars,
      ProductVariation(
        name: '2TB SSD Max',
        subSku: 'MAC-14-2TB',
        purchasePrice: 2100.0,
        sellingPrice: 2799.0,
        stockQuantity: 5.0,
      ),
    ];

    await dbService.updateProductWithVariations(
      loadedProd.copyWith(name: 'MacBook Pro 14" M3 Pro'),
      updatedVars,
    );

    final reloadedProd = await dbService.getProductById(prodId);
    expect(reloadedProd!.name, equals('MacBook Pro 14" M3 Pro'));
    expect(reloadedProd.variations!.length, equals(3));
    expect(reloadedProd.variations!.any((v) => v.subSku == 'MAC-14-2TB'), isTrue);
  });

  testWidgets('Products Module: Screens render cleanly without exceptions', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.runAsync(() async {
      await DatabaseService.initialize(customPath: inMemoryDatabasePath);
    });

    final settings = BusinessSettings();

    // 1. Brands Screen
    await tester.pumpWidget(MaterialApp(home: BrandsScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Brands Management'), findsOneWidget);
    expect(find.text('Add Brand'), findsOneWidget);

    // 2. Units Screen
    await tester.pumpWidget(MaterialApp(home: UnitsScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Units of Measure'), findsOneWidget);
    expect(find.text('Add Unit'), findsOneWidget);

    // 3. Variation Templates Screen
    await tester.pumpWidget(MaterialApp(home: VariationTemplatesScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Variation Templates'), findsOneWidget);
    expect(find.text('Add Template'), findsOneWidget);

    // 4. Warranties Screen
    await tester.pumpWidget(MaterialApp(home: WarrantiesScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Warranties & Guarantees'), findsOneWidget);
    expect(find.text('Add Warranty'), findsOneWidget);

    // 5. Selling Price Groups Screen
    await tester.pumpWidget(MaterialApp(home: SellingPriceGroupsScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Selling Price Groups'), findsOneWidget);
    expect(find.text('Add Price Group'), findsOneWidget);

    // 6. Import Products Screen
    await tester.pumpWidget(MaterialApp(home: ImportProductsScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Import Products'), findsOneWidget);
    expect(find.text('Instructions & Column Mapping'), findsOneWidget);

    // 7. Print Labels Screen
    await tester.pumpWidget(MaterialApp(home: PrintLabelsScreen(settings: settings)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.text('Print Barcode Labels'), findsOneWidget);
    expect(find.text('Sheet / Roll Layout'), findsOneWidget);
  });
}
