import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/returns/sales_return_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('smartpos_ret_widget_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
    final prodId = await db.addProduct(
      Product(
        name: 'Augmentin 625mg',
        sku: 'AUG-625',
        barcode: '896111333444',
        purchasePrice: 200.0,
        sellingPrice: 260.0,
        stockQuantity: 10.0,
      ),
    );
    await db.addSaleReturn(
      SaleReturn(
        returnNo: 'SR-WIDGET-01',
        invoiceNo: 'INV-WIDGET-99',
        customerName: 'Bilal Ahmed',
        date: DateTime.now().toIso8601String(),
        totalAmount: 520.0,
        refundAmount: 520.0,
        items: [
          SaleReturnItem(
            returnId: 0,
            productId: prodId,
            productName: 'Augmentin 625mg',
            sku: 'AUG-625',
            quantity: 2.0,
            unitPrice: 260.0,
            subtotal: 520.0,
          ),
        ],
      ),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('SalesReturnScreen displays persisted sale return entries',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(
      businessName: 'SmartPOS Returns Test',
      currencySymbol: 'Rs',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesReturnScreen(settings: settings),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('SR-WIDGET-01'), findsWidgets);
    expect(find.textContaining('Bilal Ahmed'), findsWidgets);
  });
}
