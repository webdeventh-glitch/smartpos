import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/screens/dashboard/dashboard_screen.dart';
import 'package:desktop_starter/screens/products/products_list_screen.dart';
import 'package:desktop_starter/screens/purchases/add_purchase_screen.dart';
import 'package:desktop_starter/widgets/about_developer_dialog.dart';
import 'package:desktop_starter/widgets/native_print_dialog.dart';
import 'package:desktop_starter/widgets/smart_app_bar.dart';
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

    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('Multiple Pay'), findsOneWidget);
    expect(find.text('TOTAL PAYABLE'), findsOneWidget);
    expect(find.textContaining('Calpol Syrup 60ml'), findsWidgets);
  });

  testWidgets(
      'Quantity dialog rejects decimals for non-decimal unit on field and shows stock error at top',
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

    // Add product (default unit Pieces has allowDecimal = false) to cart.
    await tester.tap(find.textContaining('Calpol Syrup 60ml').first);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Open Adjust Quantity dialog via cart qty badge.
    await tester.tap(find.byIcon(Icons.edit_note_rounded).first);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.text('Apply Quantity'), findsOneWidget);

    // Entering decimal 4.4 on Pieces shows field-level error immediately and blocks Apply.
    final dialogField = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogField, '4.4');
    await tester.pump();

    expect(
        find.textContaining('Decimal values are not allowed'), findsOneWidget);
    await tester.tap(find.text('Apply Quantity'));
    await tester.pump();
    expect(find.text('Apply Quantity'), findsOneWidget);

    // Entering whole quantity above available stock (35) shows general stock error inside dialog.
    await tester.enterText(dialogField, '50');
    await tester.pump();
    await tester.tap(find.text('Apply Quantity'));
    await tester.pump();
    expect(find.textContaining('Insufficient stock'), findsOneWidget);
    expect(find.text('Apply Quantity'), findsOneWidget);
  });

  testWidgets(
      'Shortcuts and +/- symbols render as independent badges even in Urdu primary language',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final urduSettings = BusinessSettings(
      businessName: 'SmartPOS Urdu Test',
      currencySymbol: 'Rs',
      primaryLanguage: 'ur',
      enableSecondaryLanguage: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PosTerminalScreen(settings: urduSettings),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Pure Urdu labels render on buttons/summary
    expect(find.text('نقد وصولی'), findsOneWidget);
    expect(find.text('رعایت'), findsOneWidget);
    expect(find.text('ٹیکس'), findsOneWidget);
    expect(find.text('حالیہ سیلز'), findsWidgets);

    // Independent button/field shortcut and symbol badges still render
    expect(find.text('F2'), findsWidgets);
    expect(find.text('F4'), findsWidgets);
    expect(find.text('F7'), findsWidgets);
    expect(find.text('F8'), findsWidgets);
    expect(find.text('F9'), findsWidgets);
    expect(find.text('F12'), findsOneWidget);
    expect(find.text('Esc'), findsWidgets);
    expect(find.text('(-)'), findsOneWidget);
    expect(find.text('(+)'), findsWidgets);
  });

  testWidgets('AboutDeveloperDialog renders without overflow in bilingual mode',
      (tester) async {
    tester.view.physicalSize = const Size(900, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bilingualSettings = BusinessSettings(
      businessName: 'SmartPOS Bilingual Test',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AboutDeveloperDialog(settings: bilingualSettings),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.textContaining('View Error Logs'), findsOneWidget);
    expect(find.textContaining('Copy Diagnostic Info for Support'),
        findsOneWidget);
    expect(find.textContaining('Close'), findsOneWidget);
  });

  testWidgets(
      'ProductsListScreen renders without overflow in bilingual mode and has single Stock label',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await db.addProduct(
        Product(
          name: 'Inverext Invertor 6kw',
          sku: 'SOL-3610',
          barcode: 'PRD-2811',
          unit: 'Pieces (Pc)',
          purchasePrice: 700000.0,
          sellingPrice: 750000.0,
          stockQuantity: 0.0,
        ),
      );
      await db.addProduct(
        Product(
          name: 'Longi 750 watt A grade',
          sku: 'COM-2311',
          barcode: 'PRD-3288',
          unit: 'Pieces (Pc)',
          purchasePrice: 20000.0,
          sellingPrice: 23375.0,
          stockQuantity: 164.0,
        ),
      );
    });

    final bilingualSettings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductsListScreen(settings: bilingualSettings),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('+ Stock'), findsNothing);
    expect(find.text('Stock'), findsWidgets);
  });

  testWidgets(
      'NativePrintDialog renders without overflow at 1280x720 in bilingual mode',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bilingualSettings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativePrintDialog(
            title: 'Invoice_INV-1007',
            htmlContent: '<html><body><h1>Test</h1></body></html>',
            settings: bilingualSettings,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
  });

  testWidgets(
      'Bilingual PosTerminalScreen renders Grid and List views without overflow at 1280x720',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await db.addProduct(
        Product(
          name: 'Solar Hybrid Inverter 6kw',
          sku: 'SOL-3610',
          barcode: 'PRD-2811',
          unit: 'Pieces (Pc)',
          purchasePrice: 700000.0,
          sellingPrice: 750000.0,
          stockQuantity: 0.0,
        ),
      );
      await db.addProduct(
        Product(
          name: 'Longi 750 watt A grade',
          sku: 'COM-2311',
          barcode: 'PRD-3288',
          unit: 'Pieces (Pc)',
          purchasePrice: 20000.0,
          sellingPrice: 23375.0,
          stockQuantity: 164.0,
        ),
      );
      await db.addProduct(
        Product(
          name: 'Solex 6kv Hybrid Invertor',
          sku: 'COM-6735',
          barcode: 'PRD-7297',
          unit: 'Carton (Ctn)',
          purchasePrice: 120000.0,
          sellingPrice: 132000.0,
          stockQuantity: 12.0,
        ),
      );
    });

    final bilingualSettings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PosTerminalScreen(settings: bilingualSettings),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    final listBtn = find.text('List (لسٹ)');
    if (listBtn.evaluate().isNotEmpty) {
      await tester.tap(listBtn.first);
      await tester.pump();
    }

    // Also verify sidebar-adjusted 1024x720 width (inside MainShell)
    tester.view.physicalSize = const Size(1024, 720);
    await tester.pump();
  });

  testWidgets(
      'SmartAppBar shows cash amount once in bilingual mode without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await db.openRegister('Cashier', 3154000.0);
    });

    final bilingualSettings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
      primaryLanguage: 'en',
      enableSecondaryLanguage: true,
      secondaryLanguage: 'ur',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SmartAppBar(
            onOpenPos: () {},
            onOpenRegisterDetails: () {},
            onToggleSidebar: () {},
            settings: bilingualSettings,
            onOpenQuickSearch: () {},
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      if (find.textContaining('3,154,000.00').evaluate().isNotEmpty) {
        break;
      }
    }

    final cashFinder = find.textContaining('3,154,000.00');
    expect(cashFinder, findsOneWidget);
    final cashText = tester.widget<Text>(cashFinder).data ?? '';
    expect(cashText, startsWith('Cash ('));
    expect(cashText, endsWith(': Rs 3,154,000.00'));
    expect('3,154,000.00'.allMatches(cashText).length, 1);

    // Narrower viewport check
    tester.view.physicalSize = const Size(1024, 720);
    await tester.pump();
  });

  testWidgets(
      'AddPurchaseScreen uses searchable Supplier/Location dropdowns and live POS-style product search',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await db.addContact(Contact(
          type: 'supplier',
          name: 'Inverex Solar Power Systems HQ',
          phone: '+92 21 111 468 373'));
      await db.addContact(
          Contact(type: 'supplier', name: 'Longi Official Distributor'));
      await db.addContact(Contact(type: 'supplier', name: 'Jinko Energy'));
      await db.addContact(Contact(
          type: 'supplier',
          name: 'Trina Solar Wholesale',
          phone: '0300-1234567'));
      await db.addProduct(
        Product(
          name: 'Longi 750 watt A grade',
          sku: 'COM-2311',
          barcode: 'PRD-3288',
          purchasePrice: 20000.0,
          sellingPrice: 23375.0,
          stockQuantity: 10.0,
        ),
      );
      await db.addProduct(
        Product(
          name: 'Solar Gel Battery 200Ah',
          sku: 'BAT-200',
          barcode: 'PRD-BAT200',
          purchasePrice: 45000.0,
          sellingPrice: 52000.0,
          stockQuantity: 5.0,
          isExpirable: true,
        ),
      );
    });

    final settings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddPurchaseScreen(
          settings: settings,
          onPurchaseSaved: () {},
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    // Open searchable Supplier dropdown, search for "Trina", and select it
    await tester
        .tap(find.textContaining('Inverex Solar Power Systems HQ').first);
    await tester.pump();
    final supplierSearch = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Search supplier') ?? false),
    );
    expect(supplierSearch, findsOneWidget);
    await tester.enterText(supplierSearch, 'Trina');
    await tester.pump();
    await tester.tap(find.text('Trina Solar Wholesale').last);
    await tester.pump();
    expect(find.text('Trina Solar Wholesale'), findsOneWidget);

    // Type "login" (common typo for "Longi") into product search -> live dropdown appears
    final productSearch = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Enter Product name / SKU') ??
              false),
    );
    expect(productSearch, findsOneWidget);
    await tester.enterText(productSearch, 'login');
    await tester.pump();

    final dropdownMatch = find.text('Longi 750 watt A grade');
    expect(dropdownMatch, findsOneWidget);
    expect(
      tester.getTopLeft(dropdownMatch).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(productSearch).dy),
    );
    await tester.tap(dropdownMatch);
    await tester.pump();

    // Product is added to purchase line items table; non-expirable hides Set Expiry
    expect(
        find.text('No products added to purchase invoice yet'), findsNothing);
    expect(find.text('Longi 750 watt A grade'), findsWidgets);
    expect(find.text('Set Expiry'), findsNothing);

    // Expirable product shows Set Expiry button
    await tester.enterText(productSearch, 'Battery');
    await tester.pump();
    await tester.tap(find.text('Solar Gel Battery 200Ah'));
    await tester.pump();
    expect(find.text('Set Expiry'), findsOneWidget);
  });

  testWidgets(
      'DashboardScreen renders cleanly without RenderFlex overflow at 1024x720 and 1280x720',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await db.addProduct(
        Product(
          name: 'Low Stock Solar Panel 550W',
          sku: 'SOL-LOW-1',
          barcode: '888000111',
          purchasePrice: 18000.0,
          sellingPrice: 22000.0,
          stockQuantity: 2.0,
          alertQuantity: 5.0,
        ),
      );
    });

    final settings = BusinessSettings(
      businessName: 'Alhamd Solar Agency',
      currencySymbol: 'Rs',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            settings: settings,
            onNavigateToPos: () {},
            onNavigateToRoute: (_) {},
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    tester.view.physicalSize = const Size(1280, 720);
    await tester.pump();

    // Also test bilingual mode on DashboardScreen
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardScreen(
            settings: BusinessSettings(
              businessName: 'Alhamd Solar Agency',
              currencySymbol: 'Rs',
              primaryLanguage: 'en',
              enableSecondaryLanguage: true,
              secondaryLanguage: 'ur',
            ),
            onNavigateToPos: () {},
            onNavigateToRoute: (_) {},
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
  });
}
