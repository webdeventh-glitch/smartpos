import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/utils/currency_formatter.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Product Stock History, Bulk Price Update & Currency Formatter Tests',
      () {
    late DatabaseService dbService;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_prod_enh_');
      final dbPath = path.join(
          tempDir.path, 'test_pe_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test(
        'bulkUpdateProductPrices updates filtered category by % and fixed amount',
        () async {
      final cat1 = await dbService
          .addCategory(Category(name: 'Solar Panels', code: 'SOL'));
      final cat2 =
          await dbService.addCategory(Category(name: 'Inverters', code: 'INV'));

      final p1Id = await dbService.addProduct(Product(
        name: 'Longi 670W Panel',
        sku: 'SOL-670',
        barcode: 'SOL-670',
        categoryId: cat1,
        categoryName: 'Solar Panels',
        purchasePrice: 20000.0,
        sellingPrice: 22000.0,
        stockQuantity: 10.0,
      ));
      final p2Id = await dbService.addProduct(Product(
        name: 'Inverex 6kW Nitrox',
        sku: 'INV-6KW',
        barcode: 'INV-6KW',
        categoryId: cat2,
        categoryName: 'Inverters',
        purchasePrice: 180000.0,
        sellingPrice: 200000.0,
        stockQuantity: 5.0,
      ));

      // +10% selling price only for Solar Panels
      final countCat1 = await dbService.bulkUpdateProductPrices(
        categoryId: cat1,
        mode: 'percent',
        sellingDelta: 10.0,
      );
      expect(countCat1, 1);

      final updatedP1 = (await dbService.getProductById(p1Id))!;
      final untouchedP2 = (await dbService.getProductById(p2Id))!;
      expect(updatedP1.sellingPrice, 24200.0);
      expect(updatedP1.purchasePrice, 20000.0);
      expect(untouchedP2.sellingPrice, 200000.0);

      // Fixed decrease across all products for both selling & purchase, clamped >= 0
      final countAll = await dbService.bulkUpdateProductPrices(
        mode: 'fixed',
        sellingDelta: -200.0,
        purchaseDelta: -100.0,
        updatePurchasePrice: true,
      );
      expect(countAll, greaterThanOrEqualTo(2));

      final afterP1 = (await dbService.getProductById(p1Id))!;
      expect(afterP1.sellingPrice, 24000.0);
      expect(afterP1.purchasePrice, 19900.0);
    });

    test('getProductStockHistory returns Purchases and Sales chronologically',
        () async {
      final prodId = await dbService.addProduct(Product(
        name: 'Augmentin 625mg',
        sku: 'MED-625',
        barcode: 'MED-625',
        purchasePrice: 300.0,
        sellingPrice: 380.0,
        stockQuantity: 0.0,
      ));
      final prod = (await dbService.getProductById(prodId))!;

      await dbService.createPurchase(
        purchase: Purchase(
          refNo: 'PO-HIST-1',
          supplierName: 'GSK Distributor',
          totalAmount: 6000.0,
          paidAmount: 6000.0,
          status: 'received',
          paymentStatus: 'paid',
          createdAt: '2026-11-20T09:00:00',
        ),
        items: [
          {
            'product_id': prodId,
            'product_name': prod.name,
            'quantity': 20.0,
            'purchase_price': 300.0,
            'batch_number': 'B-99',
          }
        ],
      );

      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-HIST-1',
          customerName: 'Al-Shifa Medical',
          subtotal: 1900.0,
          totalAmount: 1900.0,
          paidAmount: 1900.0,
          saleStatus: 'final',
          paymentStatus: 'paid',
          createdAt: '2026-11-21T14:30:00',
        ),
        items: [CartItem(product: prod, quantity: 5.0, unitPrice: 380.0)],
      );

      final history = await dbService.getProductStockHistory(prodId);
      expect(history.length, 2);
      expect(history.first['type'], 'Sale');
      expect(history.first['qtyChange'], -5.0);
      expect(history.last['type'], 'Purchase');
      expect(history.last['qtyChange'], 20.0);
      expect(history.last['batch'], 'B-99');
    });

    test('CurrencyFormatter formats Lakh, Million and Billion cleanly', () {
      expect(CurrencyFormatter.compact(45000, currency: 'Rs '), 'Rs 45,000.00');
      expect(
          CurrencyFormatter.compact(550000, currency: 'Rs '), 'Rs 5.50 Lakh');
      expect(CurrencyFormatter.compact(1100000, currency: 'Rs '),
          'Rs 1.10 Million');
      expect(CurrencyFormatter.compact(2500000000, currency: 'Rs '),
          'Rs 2.50 Billion');
    });
  });
}
