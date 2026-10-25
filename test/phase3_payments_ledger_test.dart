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

  group('Smart POS Phase 3: Partial Payments, Split Tender & Credit Ledger Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_p3_');
      dbPath = path.join(tempDir.path, 'test_p3_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Walk-in customer detection strictly flags non-account customers', () async {
      // Null customer ID is walk-in
      expect(await dbService.isWalkInCustomer(null), isTrue);

      // Default walk-in customer in database
      final contacts = await dbService.getContacts(type: 'customer');
      final walkIn = contacts.firstWhere((c) => c.name.toLowerCase().contains('walk-in'), orElse: () => Contact(type: 'customer', name: 'Walk-In Customer'));
      if (walkIn.id != null) {
        expect(await dbService.isWalkInCustomer(walkIn.id), isTrue);
      }

      // Registered customer with credit account is NOT walk-in
      final registeredId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Prime Solar Installations Ltd',
        phone: '+92 311 5556677',
        balance: 0.0,
        creditLimit: 500000.0,
      ));
      expect(await dbService.isWalkInCustomer(registeredId), isFalse);
    });

    test('2. Registered Customer Credit & Partial Sale updates ledger balance', () async {
      final customerId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Ali Electronics Store',
        phone: '+92 322 1112233',
        balance: 10000.0, // initial ledger balance
        creditLimit: 100000.0,
      ));

      final now = DateTime.now().toIso8601String();
      final product = Product(
        name: 'Inverex Solar Inverter 3.2kW',
        sku: 'INV-32KW',
        barcode: 'INV-32KW-BC',
        purchasePrice: 120000.0,
        sellingPrice: 140000.0,
        stockQuantity: 10.0,
      );
      final productId = await dbService.addProduct(product);
      final pWithId = product.copyWith(id: productId);

      // Sale with Partial payment: Total 140,000, Paid 40,000, Due 100,000
      final sale = Sale(
        invoiceNo: 'INV-2026-TEST01',
        customerId: customerId,
        customerName: 'Ali Electronics Store',
        subtotal: 140000.0,
        totalAmount: 140000.0,
        paidAmount: 40000.0,
        paymentMethod: 'cash',
        paymentStatus: 'partial',
        saleStatus: 'final',
        createdAt: now,
      );

      final completedSale = await dbService.createSale(
        sale: sale,
        items: [CartItem(product: pWithId, quantity: 1.0, unitPrice: 140000.0)],
      );

      expect(completedSale.id, isNotNull);
      expect(completedSale.dueAmount, 100000.0);

      // Verify contact balance increased by due amount (10,000 + 100,000 = 110,000)
      final updatedCustomer = await dbService.getContactById(customerId);
      expect(updatedCustomer?.balance, 110000.0);

      // Verify payment transaction was logged for the initial paid amount (40,000)
      final txs = await dbService.getPaymentTransactionsForSale(completedSale.id!);
      expect(txs.length, 1);
      expect(txs.first.amount, 40000.0);
      expect(txs.first.paymentMethod, 'cash');
    });

    test('3. Multi-tender Split Payment records separate ledger transactions', () async {
      final now = DateTime.now().toIso8601String();
      final product = Product(
        name: 'Longi 580W Panel',
        sku: 'LONG-580',
        barcode: 'LONG-580-BC',
        purchasePrice: 15000.0,
        sellingPrice: 18000.0,
        stockQuantity: 50.0,
      );
      final productId = await dbService.addProduct(product);
      final pWithId = product.copyWith(id: productId);

      // 10 panels = 180,000 total. Paid via Split: Cash 80,000 + Card 100,000
      final sale = Sale(
        invoiceNo: 'INV-2026-SPLIT',
        customerName: 'Walk-in Customer',
        subtotal: 180000.0,
        totalAmount: 180000.0,
        paidAmount: 180000.0,
        paymentMethod: 'split',
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: now,
      );

      final splitTenders = [
        {'method': 'cash', 'amount': 80000.0},
        {'method': 'card', 'amount': 100000.0},
      ];

      final completedSale = await dbService.createSale(
        sale: sale,
        items: [CartItem(product: pWithId, quantity: 10.0, unitPrice: 18000.0)],
        splitTenders: splitTenders,
      );

      expect(completedSale.id, isNotNull);
      expect(completedSale.paidAmount, 180000.0);
      expect(completedSale.dueAmount, 0.0);

      // Check payment_transactions table
      final txs = await dbService.getPaymentTransactionsForSale(completedSale.id!);
      expect(txs.length, 2);
      expect(txs.any((t) => t.paymentMethod == 'cash' && t.amount == 80000.0), isTrue);
      expect(txs.any((t) => t.paymentMethod == 'card' && t.amount == 100000.0), isTrue);
    });

    test('4. settleSalePayment collects installment, reduces due and updates customer ledger', () async {
      final customerId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Saad Solar Workshop',
        balance: 0.0,
      ));

      final now = DateTime.now().toIso8601String();
      final sale = Sale(
        invoiceNo: 'INV-2026-DUE',
        customerId: customerId,
        customerName: 'Saad Solar Workshop',
        subtotal: 200000.0,
        totalAmount: 200000.0,
        paidAmount: 50000.0,
        paymentMethod: 'bank_transfer',
        paymentStatus: 'partial',
        saleStatus: 'final',
        createdAt: now,
      );

      final completedSale = await dbService.createSale(sale: sale, items: []);
      expect(completedSale.dueAmount, 150000.0);

      // Customer balance should now be 150,000 due
      var customer = await dbService.getContactById(customerId);
      expect(customer?.balance, 150000.0);

      // Now customer pays installment of 100,000
      await dbService.settleSalePayment(
        saleId: completedSale.id!,
        amountPaid: 100000.0,
        paymentMethod: 'bank_transfer',
        refNo: 'BANK-CHQ-8899',
        note: 'Installment 1 received via Meezan Bank',
      );

      // Check sale paidAmount & status
      final sales = await dbService.getSales();
      final updatedSale = sales.firstWhere((s) => s.id == completedSale.id);
      expect(updatedSale.paidAmount, 150000.0);
      expect(updatedSale.dueAmount, 50000.0);
      expect(updatedSale.paymentStatus, 'partial');

      // Customer ledger balance should have decreased from 150,000 to 50,000!
      customer = await dbService.getContactById(customerId);
      expect(customer?.balance, 50000.0);

      // Settle remaining 50,000
      await dbService.settleSalePayment(
        saleId: completedSale.id!,
        amountPaid: 50000.0,
        paymentMethod: 'cash',
        note: 'Final clearance',
      );

      final clearedSale = (await dbService.getSales()).firstWhere((s) => s.id == completedSale.id);
      expect(clearedSale.paidAmount, 200000.0);
      expect(clearedSale.dueAmount, 0.0);
      expect(clearedSale.paymentStatus, 'paid');

      customer = await dbService.getContactById(customerId);
      expect(customer?.balance, 0.0);
    });

    test('5. settlePurchasePayment settles supplier payable ledger', () async {
      final supplierId = await dbService.addContact(Contact(
        type: 'supplier',
        name: 'Longi Solar Direct Distributor',
        balance: 0.0,
      ));

      final now = DateTime.now().toIso8601String();
      final purchase = Purchase(
        refNo: 'PO-2026-LONG',
        supplierId: supplierId,
        supplierName: 'Longi Solar Direct Distributor',
        totalAmount: 500000.0,
        paidAmount: 200000.0,
        status: 'received',
        paymentStatus: 'partial',
        createdAt: now,
      );

      final purchaseId = await dbService.createPurchase(purchase: purchase, items: []);
      expect(purchaseId, isPositive);

      // Supplier balance should be 300,000 payable
      var supplier = await dbService.getContactById(supplierId);
      expect(supplier?.balance, 300000.0);

      // Settle 200,000 payment to supplier
      await dbService.settlePurchasePayment(
        purchaseId: purchaseId,
        amountPaid: 200000.0,
        paymentMethod: 'bank_transfer',
        refNo: 'PAY-IBFT-10029',
        note: 'Supplier wire transfer',
      );

      // Supplier ledger balance should drop from 300,000 to 100,000
      supplier = await dbService.getContactById(supplierId);
      expect(supplier?.balance, 100000.0);

      final purchases = await dbService.getPurchases();
      final updatedPurchase = purchases.firstWhere((p) => p.id == purchaseId);
      expect(updatedPurchase.paidAmount, 400000.0);
      expect(updatedPurchase.dueAmount, 100000.0);
    });
  });
}
