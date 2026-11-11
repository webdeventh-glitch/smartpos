import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

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
    tempDir = Directory.systemTemp.createTempSync('smartpos_inv_test_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('purchase received increments stock, ordered waits until received', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Sugar 1kg',
        sku: 'SUG-1K',
        barcode: '896001001001',
        purchasePrice: 120.0,
        sellingPrice: 150.0,
        stockQuantity: 10.0,
      ),
    );

    final orderedId = await db.createPurchase(
      purchase: Purchase(
        refNo: 'PO-TEST-001',
        supplierName: 'Metro Wholesale',
        totalAmount: 2400.0,
        paidAmount: 0.0,
        status: 'ordered',
        paymentStatus: 'due',
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [
        {
          'product_id': prodId,
          'product_name': 'Sugar 1kg',
          'quantity': 20.0,
          'purchase_price': 120.0,
          'selling_price': 155.0,
        },
      ],
    );

    expect((await db.getProductById(prodId))!.stockQuantity, 10.0);

    await db.updatePurchaseStatus(orderedId, 'received');
    final afterReceive = await db.getProductById(prodId);
    expect(afterReceive!.stockQuantity, 30.0);
  });

  test('stock adjustment deducts stock and updates valuation report', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Cooking Oil 5L',
        sku: 'OIL-5L',
        barcode: '896001002002',
        purchasePrice: 2000.0,
        sellingPrice: 2500.0,
        stockQuantity: 12.0,
      ),
    );

    await db.createStockAdjustment(
      StockAdjustment(
        refNo: 'ADJ-TEST-01',
        adjustmentType: 'abnormal',
        totalAmount: 4000.0,
        reason: 'Damaged cartons',
        date: DateTime.now().toIso8601String(),
        itemsJson: jsonEncode([
          StockAdjustmentItem(
            productId: prodId,
            productName: 'Cooking Oil 5L',
            sku: 'OIL-5L',
            quantity: 2.0,
            unitPrice: 2000.0,
          ).toMap(),
        ]),
      ),
    );

    final afterAdj = await db.getProductById(prodId);
    expect(afterAdj!.stockQuantity, 10.0);

    final valuation = await db.getStockValuationReport();
    expect((valuation['stockValueRetail'] as num).toDouble(), greaterThanOrEqualTo(25000.0));
  });
}
