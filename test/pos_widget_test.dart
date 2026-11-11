import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('smartpos_pos_widget_');
    db = await DatabaseService.initialize(
      customPath: p.join(tempDir.path, 'test.db'),
    );
    await db.addProduct(
      Product(
        name: 'Calpol Syrup 60ml',
        sku: 'CAL-60',
        barcode: '896999111222',
        purchasePrice: 90.0,
        sellingPrice: 120.0,
        stockQuantity: 35.0,
      ),
    );
  });

  tearDown(() async {
    await db.db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('PosTerminalScreen renders catalog and payment controls',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(
      businessName: 'SmartPOS Terminal Test',
      currencySymbol: 'Rs',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PosTerminalScreen(settings: settings),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Multiple Pay'), findsOneWidget);
    expect(find.text('TOTAL PAYABLE'), findsOneWidget);
    expect(find.textContaining('Calpol Syrup 60ml'), findsWidgets);
  });
}
