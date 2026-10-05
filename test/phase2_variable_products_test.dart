import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 2: Variable Products, Variations, Units, and Sub-SKU Lookup', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase2_test_');
    final dbPath = '${tempDir.path}/test_phase2.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Units verification
    final units = await dbService.getUnits();
    expect(units.isNotEmpty, isTrue);
    expect(units.any((u) => u.shortName == 'Pc' || u.shortName == 'Box'), isTrue);

    // 2. Warranties verification
    final warranties = await dbService.getWarranties();
    expect(warranties.isNotEmpty, isTrue);
    expect(warranties.any((w) => w.duration == 12), isTrue);

    // 3. Selling Price Groups verification
    final priceGroups = await dbService.getSellingPriceGroups();
    expect(priceGroups.isNotEmpty, isTrue);
    expect(priceGroups.any((pg) => pg.name.contains('Wholesale')), isTrue);

    // 4. Create Variable Product with 3 variations
    final varProduct = Product(
      name: 'Nike Dry-Fit Running T-Shirt',
      sku: 'APP-VAR-001',
      barcode: 'APP-VAR-001',
      type: 'variable',
      categoryName: 'Apparel',
      brandName: 'Nike',
      purchasePrice: 15.0,
      sellingPrice: 29.99,
      stockQuantity: 45.0,
      unit: 'Pc',
      warranty: '6 Months Limited Warranty',
    );

    final variations = [
      ProductVariation(
        name: 'Small (S)',
        subSku: 'APP-VAR-001-S',
        purchasePrice: 15.0,
        sellingPrice: 29.99,
        stockQuantity: 10.0,
      ),
      ProductVariation(
        name: 'Medium (M)',
        subSku: 'APP-VAR-001-M',
        purchasePrice: 15.0,
        sellingPrice: 29.99,
        stockQuantity: 20.0,
      ),
      ProductVariation(
        name: 'Large (L)',
        subSku: 'APP-VAR-001-L',
        purchasePrice: 16.5,
        sellingPrice: 32.99,
        stockQuantity: 15.0,
      ),
    ];

    final createdProdId = await dbService.addProductWithVariations(varProduct, variations);
    expect(createdProdId, greaterThan(0));

    // 5. Verify variations retrieval
    final retrievedVars = await dbService.getProductVariations(createdProdId);
    expect(retrievedVars.length, equals(3));
    expect(retrievedVars[0].subSku, equals('APP-VAR-001-S'));
    expect(retrievedVars[2].sellingPrice, equals(32.99));

    // 6. Test POS Scanner Sub-SKU Lookup
    final scannedVar = await dbService.getProductByCode('APP-VAR-001-L');
    expect(scannedVar, isNotNull);
    expect(scannedVar!.name, contains('Large (L)'));
    expect(scannedVar.sellingPrice, equals(32.99));
    expect(scannedVar.sku, equals('APP-VAR-001-L'));

    // Clean up
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
