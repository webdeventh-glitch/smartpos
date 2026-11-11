import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:desktop_starter/models/business_settings.dart';
import 'package:desktop_starter/models/cart_item.dart';
import 'package:desktop_starter/models/category.dart';
import 'package:desktop_starter/models/customer_group.dart';
import 'package:desktop_starter/models/expense.dart';
import 'package:desktop_starter/models/product.dart';
import 'package:desktop_starter/models/purchase_item.dart';
import 'package:desktop_starter/navigation/app_routes.dart';
import 'package:desktop_starter/providers/providers.dart';
import 'package:desktop_starter/repositories/repositories.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';
import 'package:desktop_starter/widgets/smart_sidebar.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase2_');
    dbPath = p.join(tempDir.path, 'phase2_test.db');
    dbService = await DatabaseService.initialize(customPath: dbPath);
  });

  tearDown(() async {
    await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Step 2.1: Modular Domain Models', () {
    test('Direct domain model imports match barrel exports and serialize cleanly', () {
      const group = CustomerGroup(
        id: 7,
        name: 'VIP Pharmacy Buyers',
        amount: -5.0,
        priceCalculationType: 'percentage',
        sellingPriceGroupId: 2,
      );
      final groupDecoded = CustomerGroup.fromMap(group.toMap());
      expect(groupDecoded.id, 7);
      expect(groupDecoded.name, 'VIP Pharmacy Buyers');
      expect(groupDecoded.amount, -5.0);
      expect(groupDecoded.priceCalculationType, 'percentage');
      expect(groupDecoded.sellingPriceGroupId, 2);

      const pItem = PurchaseItem(
        productId: 10,
        productName: 'Paracetamol 500mg',
        sku: 'MED-001',
        quantity: 20,
        purchasePrice: 45.0,
        sellingPrice: 60.0,
        batchNumber: 'B-2026',
      );
      expect(pItem.subtotal, 900.0);
      final pItemDecoded = PurchaseItem.fromMap(pItem.toMap());
      expect(pItemDecoded.productId, 10);
      expect(pItemDecoded.sku, 'MED-001');
      expect(pItemDecoded.subtotal, 900.0);
    });

    test('CartItem.clone produces independent snapshot for Undo/Redo history', () {
      final prod = Product(
        id: 1,
        name: 'Sugar 1Kg',
        sku: 'SUG-1',
        barcode: 'SUG-1',
        purchasePrice: 120.0,
        sellingPrice: 150.0,
        stockQuantity: 100.0,
      );
      final original = CartItem(product: prod, quantity: 2.0, unitPrice: 150.0);
      final cloned = original.clone();
      cloned.quantity = 5.0;
      cloned.discount = 25.0;

      expect(original.quantity, 2.0);
      expect(original.discount, 0.0);
      expect(cloned.subtotal, 725.0);
    });
  });

  group('Step 2.2: Domain Repositories & Facade Consistency', () {
    test('Product, Category, Expense, Register, Settings, and Report repositories operate standalone', () async {
      final productRepo = ProductRepository(dbService);
      final expenseRepo = ExpenseRepository(dbService);
      final registerRepo = RegisterRepository(dbService);
      final reportRepo = ReportRepository(dbService);
      final settingsRepo = SettingsRepository(dbService);

      final catId = await productRepo.addCategory(
        Category(name: 'Beverages', code: 'BEV'),
      );
      expect(catId, greaterThan(0));

      final prodId = await productRepo.addProduct(
        Product(
          name: 'Green Tea Pack',
          sku: 'TEA-100',
          barcode: '8961001',
          categoryId: catId,
          categoryName: 'Beverages',
          purchasePrice: 180.0,
          sellingPrice: 250.0,
          stockQuantity: 40.0,
        ),
      );
      final fetched = await productRepo.getProductById(prodId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Green Tea Pack');
      expect((await dbService.getProducts()).any((e) => e.id == prodId), isTrue);

      final expId = await expenseRepo.addExpense(
        Expense(
          category: 'Utilities',
          amount: 1200.0,
          refNo: 'EXP-201',
          note: 'Electricity bill',
          date: '2026-11-11 10:00:00',
        ),
      );
      expect(expId, greaterThan(0));
      final expenses = await expenseRepo.getExpenses();
      expect(expenses.any((e) => e.refNo == 'EXP-201'), isTrue);

      final activeBefore = await registerRepo.getActiveRegister();
      if (activeBefore != null && activeBefore.id != null) {
        await registerRepo.closeRegister(activeBefore.id!, 0.0, 'Close baseline');
      }
      await registerRepo.openRegister('Cashier Ali', 5000.0);
      final activeNow = await registerRepo.getActiveRegister();
      expect(activeNow, isNotNull);
      expect(activeNow!.cashierName, 'Cashier Ali');
      expect(activeNow.openingAmount, 5000.0);

      final pnl = await reportRepo.getProfitAndLossReport();
      expect(pnl['totalExpenses'], 1200.0);
      expect(pnl['netProfit'], -1200.0);

      final curSettings = await settingsRepo.getBusinessSettings();
      await settingsRepo.updateBusinessSettings(
        curSettings.copyWith(businessName: 'Refactor Mart'),
      );
      expect((await dbService.getBusinessSettings()).businessName, 'Refactor Mart');
    });

    test('ContactRepository singular alias resolves ContactsRepository', () {
      final repo = ContactRepository(dbService);
      expect(repo, isA<ContactsRepository>());
      final saleRepo = SaleRepository(dbService);
      expect(saleRepo, isA<SalesRepository>());
    });
  });

  group('Step 2.3: Typed AppRoute Navigation', () {
    test('AppRoute bijectively maps all 42 tab indices and route paths', () {
      expect(AppRoute.values.length, 42);
      final indices = AppRoute.values.map((r) => r.tabIndex).toSet();
      final paths = AppRoute.values.map((r) => r.routePath).toSet();
      expect(indices.length, 42);
      expect(paths.length, 42);

      for (int i = 0; i < 42; i++) {
        final route = AppRoute.fromIndex(i);
        expect(route.tabIndex, i);
        expect(AppRoute.fromPath(route.routePath), route);
      }

      expect(AppRoute.fromIndex(999), AppRoute.dashboard);
      expect(AppRoute.fromPath('/unknown-path'), AppRoute.dashboard);
      expect(
        AppRoute.defaultPosWorkspaceForBusinessType('restaurant'),
        AppRoute.restaurantCafe,
      );
      expect(
        AppRoute.defaultPosWorkspaceForBusinessType('repair'),
        AppRoute.repairService,
      );
      expect(
        AppRoute.defaultPosWorkspaceForBusinessType('hotel'),
        AppRoute.hotelManagement,
      );
      expect(
        AppRoute.defaultPosWorkspaceForBusinessType('gym'),
        AppRoute.gymFitness,
      );
      expect(
        AppRoute.defaultPosWorkspaceForBusinessType('retail'),
        AppRoute.posTerminal,
      );
    });

    testWidgets('SmartSidebar emits typed AppRoute on tap without magic indices', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppRoute active = AppRoute.dashboard;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartSidebar(
              selectedRoute: active,
              isCollapsed: false,
              onSelect: (route) => active = route,
              settings: BusinessSettings(businessName: 'Typed Route Store'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('POS Terminal'));
      await tester.pump();
      expect(active, AppRoute.posTerminal);

      await tester.tap(find.text('Products'));
      await tester.pump();
      expect(active, AppRoute.productsList);
    });
  });

  group('Step 2.4: Riverpod State Management & Undo/Redo Cart', () {
    test('CartNotifier calculates totals and supports multi-step Undo/Redo', () {
      final container = ProviderContainer(
        overrides: [databaseServiceProvider.overrideWithValue(dbService)],
      );
      addTearDown(container.dispose);

      final prodA = Product(
        id: 1,
        name: 'Sugar',
        sku: 'S1',
        barcode: 'S1',
        purchasePrice: 100.0,
        sellingPrice: 150.0,
        stockQuantity: 20.0,
      );
      final prodB = Product(
        id: 2,
        name: 'Rice',
        sku: 'R1',
        barcode: 'R1',
        purchasePrice: 200.0,
        sellingPrice: 300.0,
        stockQuantity: 10.0,
      );

      final cart = container.read(cartProvider.notifier);
      expect(container.read(cartProvider).isEmpty, isTrue);

      cart.addProduct(prodA); // 150
      cart.addProduct(prodA); // 300 (qty 2)
      cart.addProduct(prodB); // + 300 = 600
      cart.setOrderDiscount('percentage', 10.0); // -60 => 540
      cart.setOrderTax(40.0); // 580
      cart.setShippingCharge(20.0); // 600

      var st = container.read(cartProvider);
      expect(st.subtotal, 600.0);
      expect(st.calculatedDiscount, 60.0);
      expect(st.grandTotal, 600.0);
      expect(st.canUndo, isTrue);
      expect(st.canRedo, isFalse);

      // Undo shipping -> 580
      expect(cart.undo(), isTrue);
      st = container.read(cartProvider);
      expect(st.shippingCharge, 0.0);
      expect(st.grandTotal, 580.0);
      expect(st.canRedo, isTrue);

      // Undo tax -> 540
      expect(cart.undo(), isTrue);
      expect(container.read(cartProvider).grandTotal, 540.0);

      // Redo tax -> 580
      expect(cart.redo(), isTrue);
      expect(container.read(cartProvider).grandTotal, 580.0);

      // New mutation clears redo stack
      cart.toggleWholesaleMode();
      st = container.read(cartProvider);
      expect(st.isWholesaleMode, isTrue);
      expect(st.canRedo, isFalse);

      // Reset history clear leaves stacks empty
      cart.clear(resetHistory: true);
      st = container.read(cartProvider);
      expect(st.isEmpty, isTrue);
      expect(st.canUndo, isFalse);
      expect(st.canRedo, isFalse);
    });

    test('ProductListNotifier, ActiveRegisterNotifier, and NavigationNotifier react cleanly', () async {
      final container = ProviderContainer(
        overrides: [databaseServiceProvider.overrideWithValue(dbService)],
      );
      addTearDown(container.dispose);

      // NavigationProvider
      expect(container.read(navigationProvider), AppRoute.dashboard);
      container.read(navigationProvider.notifier).goTo(AppRoute.posTerminal);
      expect(container.read(navigationProvider), AppRoute.posTerminal);

      // ProductListProvider
      await container.read(productListProvider.future);
      await ProductRepository(dbService).addProduct(
        Product(
          name: 'Reactive Milk',
          sku: 'MLK-1',
          barcode: 'MLK-1',
          purchasePrice: 90.0,
          sellingPrice: 120.0,
          stockQuantity: 15.0,
        ),
      );
      await container.read(productListProvider.notifier).refresh();
      final catalog = container.read(productListProvider).value!;
      expect(catalog.products.any((p) => p.sku == 'MLK-1'), isTrue);

      // ActiveRegisterProvider
      final curReg = await container.read(activeRegisterProvider.future);
      if (curReg != null && curReg.id != null) {
        await container
            .read(activeRegisterProvider.notifier)
            .closeRegister(curReg.id!, 0.0, 'Shift end');
        expect(container.read(activeRegisterProvider).value, isNull);
      }
      await container
          .read(activeRegisterProvider.notifier)
          .openRegister('Cashier Sara', 3000.0);
      final openedReg = container.read(activeRegisterProvider).value;
      expect(openedReg, isNotNull);
      expect(openedReg!.cashierName, 'Cashier Sara');
    });

    testWidgets('PosTerminalScreen Undo and Redo buttons revert and restore cart edits', (tester) async {
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await ProductRepository(dbService).addProduct(
          Product(
            name: 'Test Espresso Bean',
            sku: 'ESP-1',
            barcode: 'ESP-1',
            purchasePrice: 400.0,
            sellingPrice: 550.0,
            stockQuantity: 25.0,
          ),
        );
      });

      final settings = BusinessSettings(
        businessName: 'Phase 2 POS Cafe',
        currencySymbol: 'Rs',
        isConfigured: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseServiceProvider.overrideWithValue(dbService)],
          child: MaterialApp(
            home: Scaffold(
              body: PosTerminalScreen(settings: settings),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add product to cart by tapping its list row
      expect(find.text('Test Espresso Bean'), findsOneWidget);
      await tester.tap(find.text('Test Espresso Bean'));
      await tester.pump();

      expect(find.text('No products in cart'), findsNothing);

      // Tap Undo -> cart becomes empty again
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('No products in cart'), findsOneWidget);

      // Tap Redo -> product is restored in cart
      await tester.tap(find.text('Redo'));
      await tester.pump();
      expect(find.text('No products in cart'), findsNothing);
    });
  });
}

