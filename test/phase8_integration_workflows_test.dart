import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/providers/providers.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/pdf_export_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    AuthService.resetSecurityStateForTest();
    AuthService.currentUserNotifier.value = null;
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase8_workflows_');
  });

  tearDown(() async {
    AuthService.currentUserNotifier.value = null;
    try {
      final inst = DatabaseService.instanceOrNull;
      if (inst != null &&
          inst.db.isOpen &&
          inst.dbFilePath != null &&
          inst.dbFilePath!.startsWith(tempDir.path)) {
        await DatabaseService.closeOpenInstanceIfPathMatches(inst.dbFilePath!);
      }
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test(
      'Workflow 1: Complete Sale Flow (Cart -> Checkout -> Stock & Register -> PDF Receipt)',
      () async {
    final dbPath = p.join(tempDir.path, 'workflow_sale.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    final container = ProviderContainer();

    try {
      await db.openRegister('Cashier Zara', 2000.0);
      final prodId = await db.addProduct(
        Product(
          name: 'Augmentin 625mg',
          sku: 'AUG-625',
          barcode: '8961001001',
          purchasePrice: 220.0,
          sellingPrice: 300.0,
          stockQuantity: 20.0,
        ),
      );
      final prod = (await db.getProductById(prodId))!;

      container.read(cartProvider.notifier).addProduct(prod, quantity: 3);
      final cart = container.read(cartProvider);
      expect(cart.items.length, 1);
      expect(cart.subtotal, closeTo(900.0, 0.01));

      final invNo = await db.generateNextInvoiceNo();
      final createdSale = await db.salesRepo.createSale(
        sale: Sale(
          invoiceNo: invNo,
          customerName: 'Walk-in Customer',
          subtotal: cart.subtotal,
          totalAmount: cart.subtotal,
          paidAmount: cart.subtotal,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          saleStatus: 'final',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: cart.items,
      );
      expect(createdSale.id, isNotNull);
      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(17.0, 0.01));

      final reg = await db.getActiveRegister();
      expect(reg!.totalSalesCash, closeTo(900.0, 0.01));

      final pdfBytes = await PdfExportService.generateSalePdf(
        sale: createdSale,
        settings: await db.getBusinessSettings(),
      );
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(500));
    } finally {
      container.dispose();
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Workflow 2: Purchase Flow (Create PO -> Receive GRN -> Stock Increment & Supplier Balance)',
      () async {
    final dbPath = p.join(tempDir.path, 'workflow_purchase.db');
    final db = await DatabaseService.initialize(customPath: dbPath);

    try {
      final supplierId = await db.addContact(
        Contact(
          name: 'Ferozsons Distributors',
          type: 'supplier',
          phone: '03219998877',
          balance: 0.0,
        ),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Risek 20mg',
          sku: 'RSK-20',
          barcode: '8962002002',
          purchasePrice: 180.0,
          sellingPrice: 240.0,
          stockQuantity: 10.0,
        ),
      );

      final poRef = await db.generateNextPurchaseOrderRef();
      final poItems = [
        {
          'product_id': prodId,
          'product_name': 'Risek 20mg',
          'sku': 'RSK-20',
          'quantity': 15.0,
          'received_quantity': 0.0,
          'purchase_price': 180.0,
          'selling_price': 240.0,
        }
      ];

      final poId = await db.purchaseRepo.createPurchase(
        purchase: Purchase(
          refNo: poRef,
          supplierId: supplierId,
          supplierName: 'Ferozsons Distributors',
          totalAmount: 2700.0,
          paidAmount: 0.0,
          status: 'ordered',
          paymentStatus: 'due',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: poItems,
      );

      // Stock remains 10.0 while PO is only 'ordered'
      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(10.0, 0.01));

      // Receive entire PO
      final grnId = await db.purchaseRepo.receivePurchaseOrderItems(
        poId: poId,
        paidNow: 1000.0,
        paymentMethod: 'cash',
      );
      expect(grnId, greaterThan(0));

      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(25.0, 0.01));
      final updatedPo = (await db.purchaseRepo.getPurchases())
          .firstWhere((p) => p.id == poId);
      expect(updatedPo.status, 'received');

      final supplier = await db.getContactById(supplierId);
      expect(supplier!.balance, closeTo(1700.0, 0.01));
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Workflow 3: Sale Return Flow (Completed Sale -> Return Items -> Restock & Cash Refund)',
      () async {
    final dbPath = p.join(tempDir.path, 'workflow_return.db');
    final db = await DatabaseService.initialize(customPath: dbPath);

    try {
      await db.openRegister('Cashier Ali', 5000.0);
      final custId = await db.addContact(
        Contact(name: 'Return Customer', type: 'customer', balance: 0.0),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Flagyl 400mg',
          sku: 'FLG-400',
          barcode: '8963003003',
          purchasePrice: 40.0,
          sellingPrice: 60.0,
          stockQuantity: 30.0,
        ),
      );
      final prod = (await db.getProductById(prodId))!;

      final sale = await db.salesRepo.createSale(
        sale: Sale(
          invoiceNo: 'INV-RET-01',
          customerId: custId,
          customerName: 'Return Customer',
          subtotal: 300.0,
          totalAmount: 300.0,
          paidAmount: 300.0,
          paymentMethod: 'cash',
          saleStatus: 'final',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(product: prod, quantity: 5, unitPrice: prod.sellingPrice)
        ],
      );
      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(25.0, 0.01));

      final retId = await db.salesRepo.addSaleReturn(
        SaleReturn(
          returnNo: await db.generateNextSaleReturnRef(),
          saleId: sale.id,
          invoiceNo: sale.invoiceNo,
          customerId: custId,
          customerName: 'Return Customer',
          date: '2026-11-12',
          totalAmount: 120.0,
          refundAmount: 120.0,
          paymentMethod: 'cash',
          items: [
            SaleReturnItem(
              returnId: 0,
              productId: prodId,
              productName: prod.name,
              sku: prod.sku,
              quantity: 2.0,
              unitPrice: 60.0,
              subtotal: 120.0,
            ),
          ],
        ),
      );
      expect(retId, greaterThan(0));
      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(27.0, 0.01));
      expect((await db.getSaleReturns()).length, 1);

      final reg = await db.getActiveRegister();
      expect(reg!.totalSalesCash, closeTo(180.0, 0.01));
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'Workflow 4: RBAC User Creation -> Argon2id Login -> Permission Enforcement',
      () async {
    final dbPath = p.join(tempDir.path, 'workflow_auth.db');
    final db = await DatabaseService.initialize(customPath: dbPath);

    try {
      final roleId = await db.saveRole(
        const AppRole(
          name: 'pos_operator',
          displayName: 'POS Operator',
          description: 'Restricted till access only',
          permissions: ['pos.access', 'pos.park'],
        ),
      );
      await db.setRolePermissions(roleId, ['pos.access', 'pos.park']);

      final hashed = AuthService.hashPassword('SecurePass#2026');
      await db.authRepo.addUser(
        User(
          name: 'CashierBilal',
          username: 'bilal_pos',
          password: hashed,
          role: 'pos_operator',
          roleId: roleId,
          permissions: jsonEncode(['pos.access', 'pos.park']),
          status: 'active',
        ),
      );

      final badLogin =
          await AuthService.loginDetailed('bilal_pos', 'WrongPass');
      expect(badLogin.success, isFalse);

      final goodLogin =
          await AuthService.loginDetailed('bilal_pos', 'SecurePass#2026');
      expect(goodLogin.success, isTrue);
      expect(goodLogin.user, isNotNull);
      expect(goodLogin.user!.password, startsWith('argon2id\$'));
      expect(goodLogin.user!.hasPermission('pos.access'), isTrue);
      expect(goodLogin.user!.hasPermission('pos.park'), isTrue);
      expect(goodLogin.user!.hasPermission('settings.edit'), isFalse);
      expect(goodLogin.user!.hasPermission('users.manage'), isFalse);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });
}
