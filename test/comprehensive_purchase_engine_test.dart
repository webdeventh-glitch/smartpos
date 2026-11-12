import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/screens/purchases/add_purchase_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Comprehensive Enterprise Purchase Engine Tests', () {
    test('1. Full purchase calculation, batch insertion & stock update',
        () async {
      final db =
          await DatabaseService.initialize(customPath: inMemoryDatabasePath);

      // Create a test product
      final prodId = await db.addProduct(Product(
        name: 'Amoxil 500mg Caps',
        sku: 'AMX-500',
        barcode: '8964000123',
        purchasePrice: 200.0,
        sellingPrice: 250.0,
        stockQuantity: 10.0,
      ));

      // Create a test supplier
      final supId = await db.addContact(Contact(
        type: 'supplier',
        name: 'GlaxoSmithKline Depot',
        phone: '0300-9988776',
        balance: 500.0,
      ));

      // Create a test payment account
      final accId = await db.addPaymentAccount(PaymentAccount(
        name: 'Store Cash Drawer Test',
        accountNumber: 'CASH-TEST',
        accountType: 'cash',
        openingBalance: 10000.0,
        currentBalance: 10000.0,
      ));

      // Build purchase with line items including line discount, batch, expiry
      // 5 units @ gross 200 with 10% disc = 180 net unit cost => 900 subtotal
      final items = [
        {
          'product_id': prodId,
          'product_name': 'Amoxil 500mg Caps',
          'sku': 'AMX-500',
          'quantity': 5.0,
          'unit_cost_before_discount': 200.0,
          'discount_percent': 10.0,
          'purchase_price': 180.0,
          'profit_margin': 38.8,
          'selling_price': 250.0,
          'subtotal': 900.0,
          'batch_number': 'BAT-2026-X',
          'manufacturing_date': '2026-01-01',
          'expiry_date': '2028-12-31',
        }
      ];

      // Net subtotal: 900, order discount: 50, tax: 42.5 (5% on 850), shipping: 100 => grand total: 992.50
      // Paid 500 => due 492.50
      final purchase = Purchase(
        refNo: 'PO-TEST-001',
        supplierId: supId,
        supplierName: 'GlaxoSmithKline Depot',
        totalAmount: 992.50,
        paidAmount: 500.0,
        status: 'received',
        paymentStatus: 'partial',
        createdAt: '2026-11-09 10:00:00',
        purchaseDate: '2026-11-09 10:00:00',
        itemsJson: '[{"product_id":$prodId,"quantity":5.0}]',
        discountType: 'fixed',
        discountAmount: 50.0,
        taxRate: 5.0,
        taxAmount: 42.5,
        shippingCharges: 100.0,
        paymentMethod: 'cash',
        paymentAccountId: accId,
      );

      final purchaseId =
          await db.createPurchase(purchase: purchase, items: items);
      expect(purchaseId, greaterThan(0));

      // Verify product stock increased by 5 (10 + 5 = 15) and purchase price updated
      final updatedProd = await db.getProductById(prodId);
      expect(updatedProd, isNotNull);
      expect(updatedProd!.stockQuantity, 15.0);
      expect(updatedProd.purchasePrice, 180.0);
      expect(updatedProd.expiryDate, '2028-12-31');

      // Verify batch record was automatically inserted into product_serials_batches
      final batches = await db.getActiveBatchesForProduct(prodId);
      expect(batches.isNotEmpty, isTrue);
      final testBatch =
          batches.firstWhere((b) => b.batchNumber == 'BAT-2026-X');
      expect(testBatch.purchaseId, purchaseId);
      expect(testBatch.status, 'in_stock');
      expect(testBatch.expiryDate, '2028-12-31');
      expect(testBatch.purchasePrice, 180.0);

      // Verify supplier payable balance increased by dueAmount (500 + 492.50 = 992.50)
      final updatedSup = await db.getContactById(supId);
      expect(updatedSup, isNotNull);
      expect(updatedSup!.balance, 992.50);

      // Verify payment account was debited by 500 (10000 - 500 = 9500)
      final accounts = await db.getPaymentAccounts();
      final updatedAcc = accounts.firstWhere((a) => a.id == accId);
      expect(updatedAcc.currentBalance, 9500.0);

      // Verify supplier ledger reflects bill credit and payment debit
      final ledger =
          await db.getContactLedger(contactId: supId, contactType: 'supplier');
      final entries = ledger['entries'] as List<LedgerEntry>;
      expect(entries.any((e) => e.refNo == 'PO-TEST-001'), isTrue);

      // Test delete & rollback
      final deleted = await db.deletePurchase(purchaseId);
      expect(deleted, isTrue);

      // Stock reversed back to 10.0
      final prodAfterDelete = await db.getProductById(prodId);
      expect(prodAfterDelete!.stockQuantity, 10.0);

      // Supplier balance reversed back to 500.0
      final supAfterDelete = await db.getContactById(supId);
      expect(supAfterDelete!.balance, 500.0);

      // Account balance restored back to 10000.0
      final accountsAfterDelete = await db.getPaymentAccounts();
      final accAfterDelete =
          accountsAfterDelete.firstWhere((a) => a.id == accId);
      expect(accAfterDelete.currentBalance, 10000.0);
    });

    testWidgets(
        '2. AddPurchaseScreen renders full-page layout, cards and enterprise controls',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));

      final settings = BusinessSettings(
        businessName: 'Apex Distributors',
        currencySymbol: 'Rs',
        currencyCode: 'PKR',
        branchName: 'Main Branch HQ',
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AddPurchaseScreen(
                settings: settings,
                onPurchaseSaved: () {},
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await tester.pump();
      for (int i = 0; i < 25; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.text('Add Purchase').evaluate().isNotEmpty) break;
      }

      // Verify title & subtitles
      expect(find.text('Add Purchase'), findsOneWidget);
      expect(find.text('Purchase & Supplier Details'), findsOneWidget);
      expect(find.text('Discounts, Taxes & Freight Charges'), findsOneWidget);
      expect(find.text('Payment & Supplier Settlement'), findsOneWidget);

      // Verify buttons
      expect(find.text('Add New Product'), findsOneWidget);
      expect(find.text('Browse Catalog'), findsOneWidget);
      expect(find.text('Save Purchase Invoice'), findsOneWidget);
      expect(find.text('Save & Print GRN (F2)'), findsOneWidget);
    });
  });
}
