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
    tempDir = Directory.systemTemp.createTempSync('smartpos_docs_test_');
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

  test('sales & purchase documents persist line items and filter by status/search', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Basmati Rice 5kg',
        sku: 'RICE-5K',
        barcode: '896500112233',
        purchasePrice: 1200.0,
        sellingPrice: 1600.0,
        stockQuantity: 50.0,
      ),
    );
    final prod = (await db.getProductById(prodId))!;

    await db.createSale(
      sale: Sale(
        invoiceNo: 'INV-DOC-100',
        customerName: 'Zainab Mart',
        subtotal: 3200.0,
        totalAmount: 3200.0,
        paidAmount: 3200.0,
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [CartItem(product: prod, quantity: 2.0, unitPrice: 1600.0)],
    );

    await db.createSale(
      sale: Sale(
        invoiceNo: 'QT-DOC-101',
        customerName: 'Quotation Client',
        subtotal: 1600.0,
        totalAmount: 1600.0,
        paidAmount: 0.0,
        saleStatus: 'quotation',
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [CartItem(product: prod, quantity: 1.0, unitPrice: 1600.0)],
    );

    final finalSales = await db.getSales(status: 'final');
    expect(finalSales.any((s) => s.invoiceNo == 'INV-DOC-100'), isTrue);
    expect(finalSales.any((s) => s.invoiceNo == 'QT-DOC-101'), isFalse);

    final searched = await db.getSales(search: 'Zainab');
    expect(searched.length, 1);

    final loadedByInv = await db.getSaleByInvoiceNo('INV-DOC-100');
    expect(loadedByInv, isNotNull);
    final items = await db.getSaleItems(loadedByInv!.id!);
    expect(items.length, 1);
    expect(items.first.quantity, 2.0);
  });

  test('deleteSale reverts final sale stock deduction cleanly', () async {
    final prodId = await db.addProduct(
      Product(
        name: 'Green Tea Box',
        sku: 'TEA-01',
        barcode: '896500112299',
        purchasePrice: 200.0,
        sellingPrice: 300.0,
        stockQuantity: 25.0,
      ),
    );
    final prod = (await db.getProductById(prodId))!;

    final sale = await db.createSale(
      sale: Sale(
        invoiceNo: 'INV-DEL-01',
        customerName: 'Walk-in Customer',
        subtotal: 1500.0,
        totalAmount: 1500.0,
        paidAmount: 1500.0,
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [CartItem(product: prod, quantity: 5.0, unitPrice: 300.0)],
    );

    expect((await db.getProductById(prodId))!.stockQuantity, 20.0);

    await db.deleteSale(sale.id!);
    expect((await db.getProductById(prodId))!.stockQuantity, 25.0);
  });
}
