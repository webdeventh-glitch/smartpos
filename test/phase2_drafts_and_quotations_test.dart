import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Ultimate POS Phase 2: Drafts, Quotations & Sales Orders Lifecycle',
      () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('draft_quote_test_');
      dbPath = path.join(
          tempDir.path, 'draft_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test(
        '1. Draft Creation: Saves bill without deducting stock or affecting customer balance',
        () async {
      // 1. Create a customer with 0 balance
      final custId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Draft Customer 1',
        phone: '03001112223',
        balance: 0.0,
      ));

      // 2. Create a product with 50 stock
      final prodId = await dbService.insertProduct(Product(
        name: 'Draft Test Medicine',
        sku: 'MED-DFT-01',
        barcode: 'MED-DFT-01',
        sellingPrice: 500.0,
        purchasePrice: 350.0,
        stockQuantity: 50.0,
      ));
      final product =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);

      // 3. Save as Draft
      final draftSale = Sale(
        invoiceNo: 'DFT-001',
        customerId: custId,
        customerName: 'Draft Customer 1',
        subtotal: 1000.0,
        totalAmount: 1000.0,
        paidAmount: 0.0,
        paymentMethod: 'none',
        paymentStatus: 'due',
        saleStatus: 'draft',
        note: 'Temporary customer hold bill',
        createdAt: DateTime.now().toIso8601String(),
      );

      final createdDraft = await dbService.createSale(
        sale: draftSale,
        items: [
          CartItem(product: product, quantity: 2.0, unitPrice: 500.0),
        ],
      );

      expect(createdDraft.id, isNotNull);
      expect(createdDraft.saleStatus, 'draft');

      // 4. Verify stock was NOT deducted (must still be 50.0)
      final prodAfter =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodAfter.stockQuantity, 50.0);

      // 5. Verify customer balance was NOT updated (must still be 0.0)
      final custAfter = (await dbService.getContacts(type: 'customer'))
          .firstWhere((c) => c.id == custId);
      expect(custAfter.balance, 0.0);
    });

    test(
        '2. Quotation Creation: Saves estimate without deducting stock or adding ledger due',
        () async {
      final custId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Quotation Client A',
        phone: '03009998877',
        balance: 150.0,
      ));

      final prodId = await dbService.insertProduct(Product(
        name: 'Solar Inverter 6kW',
        sku: 'SOL-INV-6K',
        barcode: 'SOL-INV-6K',
        sellingPrice: 250000.0,
        purchasePrice: 210000.0,
        stockQuantity: 10.0,
      ));
      final product =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);

      final quote = Sale(
        invoiceNo: 'QUO-001',
        customerId: custId,
        customerName: 'Quotation Client A',
        subtotal: 500000.0,
        totalAmount: 500000.0,
        paidAmount: 0.0,
        paymentMethod: 'none',
        paymentStatus: 'due',
        saleStatus: 'quotation',
        note: 'Commercial estimation',
        createdAt: DateTime.now().toIso8601String(),
      );

      final createdQuote = await dbService.createSale(
        sale: quote,
        items: [
          CartItem(product: product, quantity: 2.0, unitPrice: 250000.0),
        ],
      );

      expect(createdQuote.id, isNotNull);
      expect(createdQuote.saleStatus, 'quotation');

      // Verify stock untouched
      final prodAfter =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodAfter.stockQuantity, 10.0);

      // Verify customer ledger untouched (150.0)
      final custAfter = (await dbService.getContacts(type: 'customer'))
          .firstWhere((c) => c.id == custId);
      expect(custAfter.balance, 150.0);
    });

    test(
        '3. Convert Draft to Final Sale: Deducts inventory and updates register & ledger',
        () async {
      await dbService.openRegister('Test Cashier', 2000.0);

      final custId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Credit Customer B',
        balance: 0.0,
      ));

      final prodId = await dbService.insertProduct(Product(
        name: 'Laptop Charger',
        sku: 'CHG-001',
        barcode: 'CHG-001',
        sellingPrice: 1500.0,
        purchasePrice: 1000.0,
        stockQuantity: 20.0,
      ));
      final product =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);

      // Step A: Save Draft first (2 items = 3000)
      final draft = Sale(
        invoiceNo: 'INV-DFT-100',
        customerId: custId,
        customerName: 'Credit Customer B',
        subtotal: 3000.0,
        totalAmount: 3000.0,
        paidAmount: 0.0,
        paymentMethod: 'none',
        paymentStatus: 'due',
        saleStatus: 'draft',
        createdAt: DateTime.now().toIso8601String(),
      );
      final savedDraft = await dbService.createSale(
        sale: draft,
        items: [
          CartItem(product: product, quantity: 2.0, unitPrice: 1500.0),
        ],
      );

      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          20.0);

      // Step B: Cashier resumes draft, customer adds 1 more item (total 3 = 4500.0), pays 2000 cash, 2500 due
      final finalizedSale = Sale(
        invoiceNo: savedDraft.invoiceNo,
        customerId: custId,
        customerName: 'Credit Customer B',
        subtotal: 4500.0,
        totalAmount: 4500.0,
        paidAmount: 2000.0,
        paymentMethod: 'cash',
        paymentStatus: 'partial',
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      );

      final updated = await dbService.updateSale(
        saleId: savedDraft.id!,
        sale: finalizedSale,
        items: [
          CartItem(product: product, quantity: 3.0, unitPrice: 1500.0),
        ],
      );

      expect(updated.saleStatus, 'final');
      expect(updated.totalAmount, 4500.0);

      // Verify stock is NOW deducted by 3 (20.0 - 3 = 17.0)
      final prodFinal =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodFinal.stockQuantity, 17.0);

      // Verify customer ledger increased by due amount (2500.0)
      final custFinal = (await dbService.getContacts(type: 'customer'))
          .firstWhere((c) => c.id == custId);
      expect(custFinal.balance, 2500.0);

      // Verify active register updated with 2000.0 cash paid
      final reg = await dbService.getActiveRegister();
      expect(reg!.totalSalesCash, 2000.0);
      expect(reg.totalCashInRegister, 4000.0); // 2000 float + 2000 cash
    });

    test('4. Delete Draft: Cleanly removes draft without modifying inventory',
        () async {
      final prodId = await dbService.insertProduct(Product(
        name: 'Item for Draft Delete',
        sku: 'DEL-001',
        barcode: 'DEL-001',
        sellingPrice: 100.0,
        purchasePrice: 60.0,
        stockQuantity: 15.0,
      ));
      final product =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);

      final draft = Sale(
        invoiceNo: 'DFT-DEL-01',
        subtotal: 200.0,
        totalAmount: 200.0,
        paidAmount: 0.0,
        saleStatus: 'draft',
        createdAt: DateTime.now().toIso8601String(),
      );
      final created = await dbService.createSale(
        sale: draft,
        items: [CartItem(product: product, quantity: 2.0, unitPrice: 100.0)],
      );

      // Delete draft
      await dbService.deleteSale(created.id!);

      final fetched = await dbService.getSaleByInvoiceNo('DFT-DEL-01');
      expect(fetched, isNull);

      // Inventory must stay at 15.0
      final prodCheck =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodCheck.stockQuantity, 15.0);
    });
  });
}
