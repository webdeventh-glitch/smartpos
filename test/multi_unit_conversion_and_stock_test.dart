import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Multi-Unit & Sub-Unit Engine Tests', () {
    late DatabaseService db;
    late String testDbPath;

    setUp(() async {
      testDbPath = '${Directory.systemTemp.path}/test_multi_units_${DateTime.now().microsecondsSinceEpoch}.db';
      db = await DatabaseService.initialize(customPath: testDbPath);
    });

    tearDown(() async {
      try {
        final f = File(testDbPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    });

    test('1. Database returns correct sub-units for Pharma, Grocery and Discrete items', () async {
      // Pharma item: Tablet
      final tabProd = Product(
        name: 'Panadol 500mg Tab',
        sku: 'PAN-500',
        barcode: 'PAN-500',
        unit: 'Tablet',
        purchasePrice: 4.0,
        sellingPrice: 5.0,
        stockQuantity: 1000.0,
      );
      final tabUnits = await db.getConversionUnitsForProduct(tabProd);
      expect(tabUnits.isNotEmpty, isTrue);
      expect(tabUnits.first.actualName, 'Tablet');
      expect(tabUnits.first.baseUnitMultiplier, 1.0);
      expect(tabUnits.any((u) => u.actualName.contains('Strip')), isTrue);
      expect(tabUnits.any((u) => u.actualName.contains('Box')), isTrue);

      // Grocery item: Grams
      final sugarProd = Product(
        name: 'White Sugar',
        sku: 'SUGAR-01',
        barcode: 'SUGAR-01',
        unit: 'Gram',
        purchasePrice: 0.10,
        sellingPrice: 0.15,
        stockQuantity: 50000.0,
      );
      final sugarUnits = await db.getConversionUnitsForProduct(sugarProd);
      expect(sugarUnits.any((u) => u.actualName.contains('Pao')), isTrue);
      expect(sugarUnits.any((u) => u.actualName.contains('Kilogram')), isTrue);
      expect(sugarUnits.any((u) => u.actualName.contains('Mann')), isTrue);
    });

    test('2. CartItem changes unit and recalculates price correctly', () {
      final tabProd = Product(
        name: 'Arinac Forte',
        sku: 'ARN-01',
        barcode: 'ARN-01',
        unit: 'Tablet',
        purchasePrice: 6.0,
        sellingPrice: 8.65,
        stockQuantity: 500.0,
      );

      final item = CartItem(
        product: tabProd,
        quantity: 2.0,
        unitPrice: tabProd.sellingPrice,
      );

      // Default is 2 Tablets @ 8.65 each = 17.30
      expect(item.selectedUnitName, 'Tablet');
      expect(item.unitMultiplier, 1.0);
      expect(item.subtotal, 17.30);

      // Switch to Strip (10 Tabs)
      item.changeUnit('Strip (10 Tabs)', 10.0);
      expect(item.selectedUnitName, 'Strip (10 Tabs)');
      expect(item.unitMultiplier, 10.0);
      expect(item.unitPrice, 86.50);
      expect(item.subtotal, 173.00); // 2 Strips * 86.50 = 173.00

      // Switch to Box (100 Tabs)
      item.changeUnit('Box (100 Tabs)', 100.0);
      expect(item.selectedUnitName, 'Box (100 Tabs)');
      expect(item.unitMultiplier, 100.0);
      expect(item.unitPrice, 865.00);
      expect(item.subtotal, 1730.00); // 2 Boxes * 865.00 = 1730.00
    });

    test('3. Stock deduction deducts accurate base unit quantity from inventory', () async {
      final pId = await db.insertProduct(Product(
        name: 'Disprin Soluble',
        sku: 'DSP-01',
        barcode: 'DSP-01',
        unit: 'Tablet',
        purchasePrice: 2.0,
        sellingPrice: 3.0,
        stockQuantity: 500.0,
      ));

      final product = (await db.getProducts()).firstWhere((p) => p.id == pId);

      // Cashier sells 2 Boxes (where 1 box = 100 Tabs)
      final cartItem = CartItem(
        product: product,
        quantity: 2.0,
        unitPrice: 3.0,
      );
      cartItem.changeUnit('Box (100 Tabs)', 100.0);

      final sale = Sale(
        invoiceNo: 'INV-TEST-001',
        customerName: 'Walk-In Customer',
        subtotal: cartItem.subtotal,
        discount: 0.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        shipping: 0.0,
        totalAmount: cartItem.subtotal,
        paidAmount: cartItem.subtotal,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: DateTime.now().toString(),
      );

      await db.createSale(sale: sale, items: [cartItem]);

      // Stock should have decreased by 2 * 100 = 200 tablets (from 500 to 300)
      final updatedProduct = (await db.getProducts()).firstWhere((p) => p.id == pId);
      expect(updatedProduct.stockQuantity, 300.0);
    });
  });
}
