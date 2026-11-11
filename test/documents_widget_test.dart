import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/products/products_list_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('smartpos_prod_widget_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
    await db.addProduct(
      Product(
        name: 'Paracetamol 500mg',
        sku: 'PARA-500',
        barcode: '896400100500',
        purchasePrice: 40.0,
        sellingPrice: 60.0,
        stockQuantity: 120.0,
      ),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ProductsListScreen displays DatabaseService products cleanly', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(
      businessName: 'SmartPOS Clinic Pharmacy',
      currencySymbol: 'Rs',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductsListScreen(settings: settings),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('Paracetamol 500mg'), findsWidgets);
    expect(find.textContaining('PARA-500'), findsWidgets);
  });
}
