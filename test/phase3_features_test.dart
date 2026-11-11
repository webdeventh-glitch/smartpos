import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/providers/providers.dart';
import 'package:desktop_starter/screens/pos/receipt_dialog.dart';
import 'package:desktop_starter/screens/reports/reports_screen.dart';
import 'package:desktop_starter/screens/users/user_management_screen.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/print_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() async {
    await AuthService.logout();
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    DatabaseService.suppressSync = false;
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase3_');
    dbPath = p.join(tempDir.path, 'phase3_test.db');
    dbService = await DatabaseService.initialize(customPath: dbPath);
  });

  tearDown(() async {
    await AuthService.logout();
    DatabaseService.suppressSync = false;
    await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Step 3.1: Item-Level Discounts', () {
    test('CartItem calculates fixed & percentage discounts and persists in SQLite sale_items', () async {
      final prodA = Product(
        id: 1,
        name: 'Surgical Mask Box',
        sku: 'MED-101',
        barcode: 'MED-101',
        purchasePrice: 80.0,
        sellingPrice: 120.0,
        stockQuantity: 100.0,
      );
      final prodB = Product(
        id: 2,
        name: 'Digital Thermometer',
        sku: 'MED-102',
        barcode: 'MED-102',
        purchasePrice: 300.0,
        sellingPrice: 500.0,
        stockQuantity: 50.0,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartProvider.notifier);

      notifier.addProduct(prodA, quantity: 2); // packValue = 240
      notifier.addProduct(prodB, quantity: 1); // packValue = 500
      notifier.setItemDiscount(0, 'percentage', 10.0); // 24.00 off -> 216.00
      notifier.updateLineItem(
        1,
        unitPrice: 500.0,
        discount: 50.0,
        discountType: 'fixed',
        discountValue: 50.0,
      ); // 50.00 off -> 450.00

      final cartState = container.read(cartProvider);
      expect(cartState.subtotal, closeTo(666.0, 0.01));
      expect(cartState.totalItemDiscounts, closeTo(74.0, 0.01));

      final created = await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-DISC-01',
          subtotal: cartState.subtotal,
          discount: 0.0,
          totalAmount: cartState.grandTotal,
          paidAmount: cartState.grandTotal,
          paymentStatus: 'paid',
          saleStatus: 'final',
          createdAt: '2026-11-11 10:00:00',
        ),
        items: cartState.items.toList(),
      );

      final loadedItems = await dbService.getSaleItems(created.id!);
      expect(loadedItems.length, 2);
      expect(loadedItems[0].discountType, 'percentage');
      expect(loadedItems[0].discountValue, 10.0);
      expect(loadedItems[0].resolvedDiscountAmount, closeTo(24.0, 0.01));
      expect(loadedItems[0].subtotal, closeTo(216.0, 0.01));

      expect(loadedItems[1].discountType, 'fixed');
      expect(loadedItems[1].discountValue, 50.0);
      expect(loadedItems[1].resolvedDiscountAmount, closeTo(50.0, 0.01));
      expect(loadedItems[1].subtotal, closeTo(450.0, 0.01));
    });

    testWidgets('ReceiptDialog displays per-item discount labels and tax breakdown', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sale = Sale(
        id: 1,
        invoiceNo: 'INV-RCPT-01',
        customerName: 'Ali Traders',
        subtotal: 90.0,
        taxAmount: 8.15,
        totalAmount: 98.15,
        paidAmount: 98.15,
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: '2026-11-11 10:30:00',
        taxBreakdownJson: '{"GST (5.0%)":5.0,"PST (3.0%)":3.15}',
        items: [
          SaleItem(
            saleId: 1,
            productName: 'Antibiotic Syrup',
            sku: 'SYR-1',
            unitPrice: 50.0,
            quantity: 2.0,
            discount: 10.0,
            discountType: 'percentage',
            discountValue: 10.0,
            subtotal: 90.0,
          ),
        ],
      );

      final html = PrintService.generateSaleInvoiceHtml(
        sale: sale,
        settings: BusinessSettings(businessName: 'Test Mart', currencySymbol: 'Rs '),
        paperSizeOverride: '80mm',
      );
      expect(html, contains('-10%'));
      expect(html, contains('GST (5.0%)'));
      expect(html, contains('PST (3.0%)'));

      final thermalSale = Sale(
        id: 2,
        invoiceNo: 'INV-RCPT-02',
        customerName: 'Walk-in Customer',
        subtotal: 90.0,
        taxAmount: 8.15,
        totalAmount: 98.15,
        paidAmount: 98.15,
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: '2026-11-11 10:30:00',
        taxBreakdownJson: '{"GST (5.0%)":5.0,"PST (3.0%)":3.15}',
        items: sale.items,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              sale: thermalSale,
              settings: BusinessSettings(
                businessName: 'Test Mart',
                currencySymbol: 'Rs ',
                receiptPaperSize: '80mm',
              ),
              tenderedAmount: 100.0,
              changeReturn: 1.85,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Item Disc: -10%'), findsOneWidget);
      expect(find.textContaining('GST (5.0%)'), findsWidgets);
      expect(find.textContaining('PST (3.0%)'), findsWidgets);

      // Verify A4 invoice template also renders multi-tax breakdown without overflow
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptDialog(
              key: const ValueKey('a4_receipt'),
              sale: sale,
              settings: BusinessSettings(
                businessName: 'Test Mart',
                currencySymbol: 'Rs ',
                receiptPaperSize: 'a4',
              ),
              tenderedAmount: 100.0,
              changeReturn: 1.85,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('10.00 (10%)'), findsOneWidget);
      expect(find.textContaining('GST (5.0%)'), findsWidgets);
    });
  });

  group('Step 3.2: Group Taxes (Compound & Additive)', () {
    test('TaxGroup computes additive vs compound rates accurately and persists CRUD + Sale breakdown', () async {
      final gstId = await dbService.addTaxRate(TaxRate(name: 'GST', amount: 5.0));
      final pstId = await dbService.addTaxRate(TaxRate(name: 'PST', amount: 3.0));
      final rates = await dbService.getTaxRates();

      final additiveGroup = TaxGroup(
        name: 'Standard Dual Tax',
        subTaxIds: [gstId, pstId],
        isCompound: false,
      );
      expect(additiveGroup.computeEffectiveRate(rates), closeTo(8.0, 0.001));
      final addBreakdown = additiveGroup.calculateBreakdown(100.0, rates);
      expect(addBreakdown['GST'], closeTo(5.0, 0.01));
      expect(addBreakdown['PST'], closeTo(3.0, 0.01));
      expect(additiveGroup.calculateTotalTax(100.0, rates), closeTo(8.0, 0.01));

      final compoundId = await dbService.addTaxGroup(
        TaxGroup(
          name: 'GST + Compound PST',
          subTaxIds: [gstId, pstId],
          isCompound: true,
        ),
      );
      final groups = await dbService.getTaxGroups();
      final savedGroup = groups.firstWhere((g) => g.id == compoundId);
      expect(savedGroup.isCompound, isTrue);
      expect(savedGroup.effectiveRate, closeTo(8.15, 0.001));

      // Verify CartNotifier dynamically computes compound breakdown on checkout items
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartProvider.notifier);
      notifier.addProduct(
        Product(
          id: 9,
          name: 'Taxable Item',
          sku: 'TX-9',
          barcode: 'TX-9',
          purchasePrice: 60.0,
          sellingPrice: 100.0,
          stockQuantity: 25.0,
          taxGroupId: savedGroup.id,
        ),
      );
      notifier.applyTaxGroup(savedGroup, rates);
      var cart = container.read(cartProvider);
      expect(cart.orderTax, closeTo(8.15, 0.01));
      expect(cart.taxBreakdown['PST'], closeTo(3.15, 0.01));
      expect(cart.grandTotal, closeTo(108.15, 0.01));

      // Increment qty to 2 (taxable = 200 -> GST 10.00 + PST 6.30 = 16.30)
      notifier.incrementQuantity(0);
      cart = container.read(cartProvider);
      expect(cart.orderTax, closeTo(16.30, 0.01));

      // Update & delete group
      await dbService.updateTaxGroup(
        TaxGroup(id: savedGroup.id, name: 'Additive Updated', subTaxIds: [gstId, pstId], isCompound: false),
      );
      final afterUpd = (await dbService.getTaxGroups()).firstWhere((g) => g.id == compoundId);
      expect(afterUpd.effectiveRate, closeTo(8.0, 0.001));

      await dbService.deleteTaxGroup(compoundId);
      expect((await dbService.getTaxGroups()).any((g) => g.id == compoundId), isFalse);
    });
  });

  group('Step 3.3: Customer Groups & Tiered Pricing', () {
    test('CustomerGroup SQLite CRUD + Contact join + CartNotifier tiered repricing work seamlessly', () async {
      final groups = await dbService.getCustomerGroups();
      expect(groups.any((g) => g.name.toLowerCase().contains('wholesale')), isTrue);

      final vipId = await dbService.addCustomerGroup(
        const CustomerGroup(
          name: 'Platinum VIP',
          amount: -15.0,
          priceCalculationType: 'percentage',
        ),
      );

      final custId = await dbService.addContact(
        Contact(
          type: 'customer',
          name: 'Dr. Kamran',
          phone: '0300-1234567',
          customerGroupId: vipId,
        ),
      );

      final fetched = await dbService.getContactById(custId);
      expect(fetched, isNotNull);
      expect(fetched!.customerGroupId, vipId);
      expect(fetched.customerGroupName, 'Platinum VIP');

      // Phone search should match via fixed c.phone LIKE ? query
      final phoneMatches = await dbService.getContacts(type: 'customer', search: '0300-123');
      expect(phoneMatches.any((c) => c.id == custId), isTrue);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartProvider.notifier);

      final med = Product(
        id: 21,
        name: 'Blood Pressure Monitor',
        sku: 'BPM-1',
        barcode: 'BPM-1',
        purchasePrice: 1200.0,
        sellingPrice: 2000.0,
        stockQuantity: 10.0,
      );
      notifier.addProduct(med);
      expect(container.read(cartProvider).items.first.unitPrice, 2000.0);

      final vipGroup = await dbService.getCustomerGroupById(vipId);
      notifier.applyCustomerGroup(vipGroup);
      expect(container.read(cartProvider).items.first.unitPrice, closeTo(1700.0, 0.01));

      // Newly added item also gets tier price immediately
      final glucometer = Product(
        id: 22,
        name: 'Glucometer Kit',
        sku: 'GLM-1',
        barcode: 'GLM-1',
        purchasePrice: 600.0,
        sellingPrice: 1000.0,
        stockQuantity: 10.0,
      );
      notifier.addProduct(glucometer);
      expect(container.read(cartProvider).items[1].unitPrice, closeTo(850.0, 0.01));

      // Reverting to Walk-in (null group) restores retail base price
      notifier.applyCustomerGroup(null);
      expect(container.read(cartProvider).items[0].unitPrice, closeTo(2000.0, 0.01));
      expect(container.read(cartProvider).items[1].unitPrice, closeTo(1000.0, 0.01));

      // Deleting group clears contact FK cleanly
      await dbService.deleteCustomerGroup(vipId);
      final afterDel = await dbService.getContactById(custId);
      expect(afterDel!.customerGroupId, isNull);
    });
  });

  group('Step 3.4: Quotation to Invoice Workflow & Funnel Metrics', () {
    test('Converts quotation atomically to final invoice, deducts stock, prevents re-conversion, and updates KPIs', () async {
      final prodId = await dbService.insertProduct(
        Product(
          name: 'Inverter Battery 180Ah',
          sku: 'BAT-180',
          barcode: 'BAT-180',
          purchasePrice: 25000.0,
          sellingPrice: 30000.0,
          stockQuantity: 10.0,
        ),
      );
      final custId = await dbService.addContact(
        Contact(type: 'customer', name: 'Solar Tech Builders', phone: '0321-0001112'),
      );
      final prod = (await dbService.getProduct(prodId))!;

      final quote = await dbService.createSale(
        sale: Sale(
          invoiceNo: 'QT-2026-01',
          customerId: custId,
          customerName: 'Solar Tech Builders',
          subtotal: 60000.0,
          totalAmount: 60000.0,
          paidAmount: 0.0,
          paymentStatus: 'due',
          saleStatus: 'quotation',
          createdAt: '2026-11-11 09:00:00',
        ),
        items: [CartItem(product: prod, quantity: 2.0, unitPrice: 30000.0)],
      );

      // Quotation must NOT deduct stock
      expect((await dbService.getProduct(prodId))!.stockQuantity, 10.0);
      expect((await dbService.getQuotations(conversionFilter: 'pending')).length, 1);

      // Convert quotation atomically with partial payment (40,000 paid, 20,000 due)
      final invoice = await dbService.convertQuotationToInvoice(
        quotationId: quote.id!,
        paymentMethod: 'cash',
        paidAmount: 40000.0,
        note: 'Confirmed PO #88',
      );
      expect(invoice.saleStatus, 'final');
      expect(invoice.paymentStatus, 'partial');
      expect(invoice.convertedFromQuotationId, quote.id);
      expect((await dbService.getProduct(prodId))!.stockQuantity, 8.0);
      expect((await dbService.getContactById(custId))!.balance, closeTo(20000.0, 0.01));

      // Pending quotes should now be empty; converted should list QT-2026-01
      expect((await dbService.getQuotations(conversionFilter: 'pending')), isEmpty);
      final convertedQuotes = await dbService.getQuotations(conversionFilter: 'converted');
      expect(convertedQuotes.length, 1);
      expect(convertedQuotes.first.convertedToSaleId, invoice.id);

      // Duplicate conversion must fail
      await expectLater(
        () => dbService.convertQuotationToInvoice(quotationId: quote.id!),
        throwsA(isA<StateError>()),
      );

      // Create second unconverted quotation -> conversion rate should be 50.0%
      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'QT-2026-02',
          customerId: custId,
          customerName: 'Solar Tech Builders',
          subtotal: 30000.0,
          totalAmount: 30000.0,
          paidAmount: 0.0,
          paymentStatus: 'due',
          saleStatus: 'quotation',
          createdAt: '2026-11-11 11:00:00',
        ),
        items: [CartItem(product: prod, quantity: 1.0, unitPrice: 30000.0)],
      );

      final stats = await dbService.getQuotationConversionStats();
      expect(stats['totalQuotations'], 2);
      expect(stats['convertedQuotations'], 1);
      expect(stats['pendingQuotations'], 1);
      expect(stats['conversionRate'], closeTo(50.0, 0.01));
    });
  });

  group('Step 3.5: Full RBAC Permissions & Role Editor', () {
    test('Custom DB role permissions load at AuthService.login and enforce granular PermissionCatalog keys', () async {
      expect(PermissionCatalog.all.length, 41);

      final roles = await dbService.getRoles();
      expect(roles.length, greaterThanOrEqualTo(4));

      final auditorRoleId = await dbService.saveRole(
        const AppRole(
          name: 'stock_auditor',
          displayName: 'Stock Auditor',
          description: 'Can inspect inventory audits & activity logs, cannot delete sales.',
          permissions: [
            'product.view',
            'inventory.audit',
            'report.view',
            'report.view_audit_log',
          ],
        ),
      );

      await dbService.addUser(
        User(
          name: 'Zainab Auditor',
          username: 'auditor_zainab',
          password: AuthService.hashPassword('AuditPass123!'),
          role: 'stock_auditor',
          roleId: auditorRoleId,
        ),
      );

      final loggedIn = await AuthService.login('auditor_zainab', 'AuditPass123!');
      expect(loggedIn, isTrue);

      final effective = AuthService.currentUser!;
      expect(effective.hasPermission('inventory.audit'), isTrue);
      expect(effective.hasPermission('report.view_audit_log'), isTrue);
      expect(effective.hasPermission('sale.delete'), isFalse);
      expect(effective.hasPermission('settings.manage'), isFalse);
      expect(effective.hasPermission('pos.edit_price'), isFalse);
    });

    testWidgets('UserManagementScreen Roles & Permissions Matrix tab displays DB roles and opens editor', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: UserManagementScreen(
            settings: BusinessSettings(businessName: 'RBAC Pharmacy'),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();

      await tester.tap(find.text('Roles & Permissions Matrix'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Create Custom Role'), findsOneWidget);
      expect(find.textContaining('Granular Role-Based Access Control'), findsOneWidget);

      await tester.tap(find.text('Create Custom Role'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Save Role Permissions'), findsOneWidget);
    });
  });

  group('Step 3.6: Activity Log / Audit Trail & ReportsScreen Tab', () {
    test('Repository CRUD actions automatically populate filterable activity_log entries', () async {
      AuthService.switchUser(
        User(id: 1, name: 'Owner Tariq', username: 'owner', password: 'x', role: 'superadmin'),
      );

      final prodId = await dbService.insertProduct(
        Product(
          name: 'Paracetamol 500mg',
          sku: 'PCM-500',
          barcode: 'PCM-500',
          purchasePrice: 20.0,
          sellingPrice: 35.0,
          stockQuantity: 200.0,
        ),
      );
      await dbService.updateProduct(
        Product(
          id: prodId,
          name: 'Paracetamol 500mg Strip',
          sku: 'PCM-500',
          barcode: 'PCM-500',
          purchasePrice: 20.0,
          sellingPrice: 40.0,
          stockQuantity: 200.0,
        ),
      );
      await dbService.deleteProduct(prodId);

      final logs = await dbService.getActivityLogs(entityType: 'product');
      expect(logs.length, greaterThanOrEqualTo(3));
      expect(logs.any((l) => l.action == 'created' && l.userName == 'Owner Tariq'), isTrue);
      expect(logs.any((l) => l.action == 'updated' && l.oldValues.isNotEmpty && l.newValues.isNotEmpty), isTrue);
      expect(logs.any((l) => l.action == 'deleted'), isTrue);
    });

    testWidgets('ReportsScreen exposes Activity Log tab and Quotation conversion funnel', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(
        () => dbService.logActivity(
          action: 'created',
          entityType: 'product',
          entityId: 99,
          newValues: {'name': 'Vitamin D3'},
          userName: 'QA Tester',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            settings: BusinessSettings(businessName: 'Analytics Store'),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final activityTab = find.text('Activity Log');
      expect(activityTab, findsOneWidget);
      await tester.ensureVisible(find.text('Purchase & Sale Report'));
      await tester.tap(find.text('Purchase & Sale Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('QUOTATION -> INVOICE CONVERSION FUNNEL'), findsOneWidget);

      await tester.ensureVisible(activityTab);
      await tester.tap(activityTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('System Activity & Audit Trail'), findsOneWidget);
      expect(find.textContaining('by QA Tester'), findsOneWidget);
    });
  });

  group('Phase 3 Audit Regression Guards', () {
    test('RBAC role revocations survive failed attempts & re-login without DB cache pollution', () async {
      final managerRole = await dbService.authRepo.getRoleByName('manager');
      expect(managerRole, isNotNull);

      await dbService.addUser(User(
        name: 'Store Manager',
        username: 'mgr_audit',
        password: AuthService.hashPassword('Mgr@12345'),
        role: 'manager',
        roleId: managerRole!.id,
        mustChangePassword: false,
      ));

      // Trigger failed_login_attempts > 0 so next login executes db.updateUser(baseUser)
      final failRes = await AuthService.loginDetailed('mgr_audit', 'WrongPass1!');
      expect(failRes.success, isFalse);

      final login1 = await AuthService.loginDetailed('mgr_audit', 'Mgr@12345');
      expect(login1.success, isTrue);
      expect(AuthService.currentUser!.hasPermission('sale.delete'), isTrue);

      // DB row must remain clean (never store __rbac__ resolved blob in users.permissions)
      final rawUsers = await dbService.getUsers();
      final dbMgr = rawUsers.firstWhere((u) => u.username == 'mgr_audit');
      expect(dbMgr.permissions.contains('__rbac__'), isFalse);

      // Revoke sale.delete from manager role
      await dbService.saveRole(AppRole(
        id: managerRole.id,
        name: managerRole.name,
        displayName: managerRole.displayName,
        description: managerRole.description,
        isSystem: managerRole.isSystem,
        permissions: managerRole.permissions.where((p) => p != 'sale.delete').toList(),
      ));

      await AuthService.logout();
      final login2 = await AuthService.loginDetailed('mgr_audit', 'Mgr@12345');
      expect(login2.success, isTrue);
      expect(AuthService.currentUser!.hasPermission('sale.delete'), isFalse);
      expect(AuthService.currentUser!.hasPermission('sales.delete'), isFalse);
      expect(AuthService.currentUser!.hasPermission('pos.access'), isTrue);
    });

    test('Default customer groups use discount signs and clearing product tax / contact group persists NULL', () async {
      final groups = await dbService.getCustomerGroups();
      expect(groups.length, greaterThanOrEqualTo(3));
      expect(groups.every((g) => g.amount <= 0.0), isTrue);

      final prodId = await dbService.addProduct(Product(
        name: 'Taxed Soap',
        sku: 'SOAP-TAX-1',
        barcode: 'SOAP-TAX-1',
        purchasePrice: 50,
        sellingPrice: 100,
        stockQuantity: 10,
        taxRateId: 1,
      ));
      final loadedProd = (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(loadedProd.taxRateId, 1);

      await dbService.updateProduct(Product(
        id: prodId,
        name: 'Taxed Soap',
        sku: 'SOAP-TAX-1',
        barcode: 'SOAP-TAX-1',
        purchasePrice: 50,
        sellingPrice: 100,
        stockQuantity: 10,
        taxRateId: null,
        taxGroupId: null,
      ));
      final clearedProd = (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(clearedProd.taxRateId, isNull);
      expect(clearedProd.taxGroupId, isNull);

      final custId = await dbService.addContact(Contact(
        name: 'Tier Buyer',
        phone: '03009998887',
        type: 'customer',
        customerGroupId: groups.last.id,
      ));
      final loadedCust = (await dbService.getContacts(type: 'customer'))
          .firstWhere((c) => c.id == custId);
      expect(loadedCust.customerGroupId, groups.last.id);

      await dbService.updateContact(Contact(
        id: custId,
        name: 'Tier Buyer',
        phone: '03009998887',
        type: 'customer',
        customerGroupId: null,
      ));
      final clearedCust = (await dbService.getContacts(type: 'customer'))
          .firstWhere((c) => c.id == custId);
      expect(clearedCust.customerGroupId, isNull);
    });

    test('getProfitAndLossReport excludes quotation & draft COGS and updateSale credits total_sales_other', () async {
      await dbService.openRegister('Cashier One', 1000.0);

      final prod = Product(
        name: 'Monitor 24',
        sku: 'MON-24',
        barcode: 'MON-24',
        purchasePrice: 400.0,
        sellingPrice: 600.0,
        stockQuantity: 10,
      );
      final prodId = await dbService.addProduct(prod);
      final savedProd = (await dbService.getProduct(prodId))!;
      final now = DateTime.now().toIso8601String();

      // Quotation (2 units => cost 800 should NOT appear in P&L COGS)
      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'QUO-PNL-1',
          subtotal: 1200.0,
          totalAmount: 1200.0,
          paidAmount: 0.0,
          paymentMethod: 'none',
          paymentStatus: 'due',
          saleStatus: 'quotation',
          createdAt: now,
        ),
        items: [CartItem(product: savedProd, quantity: 2, unitPrice: 600.0)],
      );

      // Finalized sale via updateSale with non-cash/non-card paymentMethod
      final draft = await dbService.createSale(
        sale: Sale(
          invoiceNo: 'DFT-PNL-1',
          subtotal: 600.0,
          totalAmount: 600.0,
          paidAmount: 0.0,
          paymentMethod: 'none',
          paymentStatus: 'due',
          saleStatus: 'draft',
          createdAt: now,
        ),
        items: [CartItem(product: savedProd, quantity: 1, unitPrice: 600.0)],
      );

      await dbService.updateSale(
        saleId: draft.id!,
        sale: Sale(
          id: draft.id,
          invoiceNo: 'INV-PNL-1',
          subtotal: 600.0,
          totalAmount: 600.0,
          paidAmount: 600.0,
          paymentMethod: 'bank_transfer',
          paymentStatus: 'paid',
          saleStatus: 'final',
          createdAt: now,
        ),
        items: [CartItem(product: savedProd, quantity: 1, unitPrice: 600.0)],
      );

      final pnl = await dbService.getProfitAndLossReport();
      expect(pnl['totalSales'], closeTo(600.0, 0.01));
      expect(pnl['cogs'], closeTo(400.0, 0.01));
      expect(pnl['grossProfit'], closeTo(200.0, 0.01));

      final reg = await dbService.getActiveRegister();
      expect(reg, isNotNull);
      expect(reg!.totalSalesOther, closeTo(600.0, 0.01));
    });

    test('deleteTaxRate rejects deletion while referenced by a TaxGroup and succeeds afterwards', () async {
      final taxId = await dbService.addTaxRate(TaxRate(name: 'FED Audit', amount: 3.0));
      final groupId = await dbService.addTaxGroup(TaxGroup(
        name: 'Composite Tax',
        subTaxIds: [taxId],
      ));

      await expectLater(
        () => dbService.deleteTaxRate(taxId),
        throwsA(isA<StateError>()),
      );

      await dbService.deleteTaxGroup(groupId);
      await dbService.deleteTaxRate(taxId);

      final logs = await dbService.getActivityLogs(entityType: 'tax_rate');
      expect(logs.any((l) => l.action == 'deleted' && l.entityId == taxId), isTrue);
    });

    testWidgets('ReportsScreen hides Net Profit and Cost figures when RBAC lacks report.view_profit and report.view_cost_price', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      AuthService.currentUserNotifier.value = User(
        id: 77,
        name: 'Limited Reporter',
        username: 'limited_rep',
        password: '',
        role: 'salesman',
        canAccessReports: true,
        canViewCostPrice: true,
        permissions: '__rbac__,report.view',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsScreen(
            settings: BusinessSettings(businessName: 'RBAC Reports Store'),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Restricted'), findsWidgets);
      expect(
        find.text('Profit & Loss Statement is restricted. Requires "report.view_profit" permission.'),
        findsOneWidget,
      );
    });
  });
}
