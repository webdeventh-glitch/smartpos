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
    tempDir = Directory.systemTemp.createTempSync('smartpos_ret_repo_');
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

  test('addSaleReturn restocks returned quantities and persists return lines', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Brufen Tablets',
        sku: 'BRU-400',
        barcode: '896200300400',
        purchasePrice: 80.0,
        sellingPrice: 100.0,
        stockQuantity: 10.0,
      ),
    );

    final refNo = await db.generateNextSaleReturnRef();
    expect(refNo, startsWith('SR-'));

    final srId = await db.addSaleReturn(
      SaleReturn(
        returnNo: refNo,
        invoiceNo: 'INV-9001',
        customerName: 'Walk-in Customer',
        date: DateTime.now().toIso8601String(),
        totalAmount: 300.0,
        refundAmount: 300.0,
        items: [
          SaleReturnItem(
            returnId: 0,
            productId: prodId,
            productName: 'Brufen Tablets',
            sku: 'BRU-400',
            quantity: 3.0,
            unitPrice: 100.0,
            subtotal: 300.0,
          ),
        ],
      ),
    );

    expect(srId, greaterThan(0));
    expect((await db.getProductById(prodId))!.stockQuantity, 13.0);

    final returns = await db.getSaleReturns();
    expect(returns.any((r) => r.returnNo == refNo && r.items.length == 1), isTrue);
  });

  test('addPurchaseReturn deducts returned stock cleanly', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Disprin Strip',
        sku: 'DISP-10',
        barcode: '896200300500',
        purchasePrice: 30.0,
        sellingPrice: 45.0,
        stockQuantity: 25.0,
      ),
    );

    final prRef = await db.generateNextPurchaseReturnRef();
    expect(prRef, startsWith('PR-'));

    await db.addPurchaseReturn(
      PurchaseReturn(
        returnNo: prRef,
        purchaseRef: 'PO-2026-001',
        supplierName: 'Getz Distributor',
        date: DateTime.now().toIso8601String(),
        totalAmount: 150.0,
        refundAmount: 150.0,
        items: [
          PurchaseReturnItem(
            returnId: 0,
            productId: prodId,
            productName: 'Disprin Strip',
            sku: 'DISP-10',
            quantity: 5.0,
            unitPrice: 30.0,
            subtotal: 150.0,
          ),
        ],
      ),
    );

    expect((await db.getProductById(prodId))!.stockQuantity, 20.0);
    final list = await db.getPurchaseReturns();
    expect(list.any((r) => r.returnNo == prRef), isTrue);
  });
}
