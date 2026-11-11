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
    tempDir = Directory.systemTemp.createTempSync('smartpos_pos_repo_');
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

  test(
      'createSale handles unit multipliers and partial customer dues atomically',
      () async {
    final custId = await db.addContact(
      Contact(type: 'customer', name: 'Ali Traders', balance: 0.0),
    );
    final prodId = await db.addProduct(
      Product(
        name: 'Amoxicillin Syrup',
        sku: 'AMOX-100',
        barcode: '896100200300',
        unit: 'Bottle',
        purchasePrice: 100.0,
        sellingPrice: 150.0,
        stockQuantity: 40.0,
      ),
    );
    final prod = (await db.getProductById(prodId))!;

    final cartItem = CartItem(
      product: prod,
      quantity: 2.0,
      unitPrice: 1500.0,
      selectedUnitName: 'Pack (10)',
      unitMultiplier: 10.0,
    );

    final invNo = await db.generateNextInvoiceNo();
    final created = await db.createSale(
      sale: Sale(
        invoiceNo: invNo,
        customerId: custId,
        customerName: 'Ali Traders',
        subtotal: 3000.0,
        totalAmount: 3000.0,
        paidAmount: 1000.0,
        paymentMethod: 'cash',
        paymentStatus: 'partial',
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      ),
      items: [cartItem],
    );

    // 2 packs * 10 multiplier = 20 bottles deducted from 40
    expect((await db.getProductById(prodId))!.stockQuantity, 20.0);

    // Due 2000 added to customer balance
    final custAfterSale = (await db.getContacts(type: 'customer'))
        .firstWhere((c) => c.id == custId);
    expect(custAfterSale.balance, 2000.0);

    // Settle remaining 2000
    await db.settleSalePayment(
      saleId: created.id!,
      amountPaid: 2000.0,
      paymentMethod: 'bank_transfer',
    );
    final settledSale = await db.getSaleByInvoiceNo(invNo);
    expect(settledSale!.paymentStatus, 'paid');
    expect(settledSale.paidAmount, 3000.0);

    final custAfterSettle = (await db.getContacts(type: 'customer'))
        .firstWhere((c) => c.id == custId);
    expect(custAfterSettle.balance, 0.0);
  });
}
