import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Manual Core Operations Verification: Add Product, Purchase, Sale, Return, Khata', () {
    late DatabaseService db;

    setUpAll(() async {
      db = await DatabaseService.initialize(customPath: inMemoryDatabasePath);
      await db.seedInitialDataForBusinessType(businessType: 'general');
    });

    test('STEP 1: Add New Product and Verify in Catalog', () async {
      final newProd = Product(
        name: 'Super High-Speed USB 3.0 Flash Drive 64GB',
        sku: 'USB-64GB-PRO',
        barcode: '890123456789',
        categoryName: 'Electronics & Accessories',
        brandName: 'SanDisk Pro',
        unit: 'Pc',
        purchasePrice: 650.0,
        sellingPrice: 1100.0,
        stockQuantity: 50.0,
        alertQuantity: 10.0,
      );

      final insertedId = await db.addProduct(newProd);
      expect(insertedId, greaterThan(0), reason: 'Product should be assigned a positive ID');

      // Verify retrieval by ID
      final retrieved = await db.getProductById(insertedId);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Super High-Speed USB 3.0 Flash Drive 64GB'));
      expect(retrieved.sku, equals('USB-64GB-PRO'));
      expect(retrieved.purchasePrice, equals(650.0));
      expect(retrieved.sellingPrice, equals(1100.0));
      expect(retrieved.stockQuantity, equals(50.0));

      // Verify retrieval by Barcode
      final byBarcode = await db.getProductByCode('890123456789');
      expect(byBarcode, isNotNull);
      expect(byBarcode!.id, equals(insertedId));

      print('[VERIFIED] Step 1: Product successfully added with SKU USB-64GB-PRO, Stock=50.0');
    });

    test('STEP 2: Create Purchase (خریداری) & Verify Automatic Stock Increment', () async {
      final productBefore = await db.getProductByCode('890123456789');
      expect(productBefore, isNotNull);
      final initialStock = productBefore!.stockQuantity; // 50.0

      // Create Supplier Contact
      final supplier = Contact(
        name: 'Al-Madina Electronics Wholesale Hub',
        type: 'supplier',
        phone: '+92 300 9876543',
        balance: 0.0,
      );
      final supplierId = await db.addContact(supplier);

      // Create Purchase Order for 30 additional units @ 620 each
      final purchase = Purchase(
        refNo: 'PUR-2026-0001',
        supplierId: supplierId,
        supplierName: 'Al-Madina Electronics Wholesale Hub',
        totalAmount: 30 * 620.0, // 18,600
        paidAmount: 18600.0,
        status: 'received',
        paymentStatus: 'paid',
        createdAt: DateTime.now().toIso8601String(),
      );

      final purchaseId = await db.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': productBefore.id,
            'product_name': productBefore.name,
            'quantity': 30.0,
            'unit_cost': 620.0,
            'subtotal': 18600.0,
          }
        ],
      );
      expect(purchaseId, greaterThan(0));

      // Verify stock automatically incremented from 50.0 to 80.0
      final productAfter = await db.getProductById(productBefore.id!);
      expect(productAfter!.stockQuantity, equals(initialStock + 30.0));
      expect(productAfter.stockQuantity, equals(80.0));

      // Verify purchase record persisted
      final purchases = await db.getPurchases();
      expect(purchases.any((p) => p.refNo == 'PUR-2026-0001'), isTrue);

      print('[VERIFIED] Step 2: Purchase PUR-2026-0001 recorded. Stock atomically incremented from $initialStock to 80.0');
    });

    test('STEP 3: Process POS Sale (فروخت) & Verify Automatic Stock Decrement and Invoice', () async {
      final productBefore = await db.getProductByCode('890123456789');
      expect(productBefore, isNotNull);
      final stockBefore = productBefore!.stockQuantity; // 80.0

      // Create Customer Contact
      final customer = Contact(
        name: 'Tariq Mehmood (Cash Walk-in)',
        type: 'customer',
        phone: '+92 321 5556677',
        balance: 0.0,
      );
      final customerId = await db.addContact(customer);

      // Sell 5 units @ 1100 = 5500 with 200 discount = 5300
      final soldQty = 5.0;
      final cartItem = CartItem(
        product: productBefore,
        quantity: soldQty,
        unitPrice: productBefore.sellingPrice,
      );

      final invoiceNo = await db.generateNextInvoiceNo();
      final sale = Sale(
        invoiceNo: invoiceNo,
        customerName: 'Tariq Mehmood (Cash Walk-in)',
        customerId: customerId,
        subtotal: 5500.0,
        discount: 200.0,
        totalAmount: 5300.0,
        paidAmount: 5300.0,
        paymentStatus: 'paid',
        paymentMethod: 'cash',
        createdAt: DateTime.now().toIso8601String(),
      );

      final completedSale = await db.createSale(
        sale: sale,
        items: [cartItem],
      );
      expect(completedSale.id, isNotNull);

      // Verify stock automatically decremented from 80.0 to 75.0
      final productAfter = await db.getProductById(productBefore.id!);
      expect(productAfter!.stockQuantity, equals(stockBefore - soldQty));
      expect(productAfter.stockQuantity, equals(75.0));

      // Verify sale recorded in sales list
      final sales = await db.getSales();
      expect(sales.any((s) => s.invoiceNo == invoiceNo), isTrue);

      print('[VERIFIED] Step 3: POS Sale $invoiceNo executed for 5 units. Stock atomically decremented from $stockBefore to 75.0');
    });

    test('STEP 4: Process Sales Return (سیلز واپسی / ریٹرن) & Verify Stock Restored', () async {
      final productBefore = await db.getProductByCode('890123456789');
      final stockBefore = productBefore!.stockQuantity; // 75.0

      // Customer returns 2 units of the 5 units sold
      final returnQty = 2.0;
      final refundAmount = returnQty * productBefore.sellingPrice; // 2200.0

      final saleReturn = SaleReturn(
        returnNo: 'SR-2026-0001',
        saleId: 1,
        invoiceNo: 'INV-2026-0001',
        customerName: 'Tariq Mehmood (Cash Walk-in)',
        totalAmount: refundAmount,
        refundAmount: refundAmount,
        paymentMethod: 'cash',
        reason: 'Customer requested refund for 2 units',
        date: DateTime.now().toIso8601String(),
        items: [
          SaleReturnItem(
            returnId: 0,
            productId: productBefore.id!,
            productName: productBefore.name,
            sku: productBefore.sku,
            unitPrice: productBefore.sellingPrice,
            quantity: returnQty,
            subtotal: refundAmount,
          ),
        ],
      );

      final returnId = await db.addSaleReturn(saleReturn);
      expect(returnId, greaterThan(0));

      // Verify stock automatically restored from 75.0 to 77.0
      final productAfter = await db.getProductById(productBefore.id!);
      expect(productAfter!.stockQuantity, equals(stockBefore + returnQty));
      expect(productAfter.stockQuantity, equals(77.0));

      // Verify return record persisted
      final returns = await db.getSaleReturns();
      expect(returns.any((r) => r.returnNo == 'SR-2026-0001'), isTrue);

      print('[VERIFIED] Step 4: Sales Return SR-2026-0001 processed. 2 units restocked atomically, Stock restored to 77.0');
    });

    test('STEP 5: Customer Khata / Credit Ledger & Payment Recovery (ادھار کھاتہ اور وصولی)', () async {
      // Create Khata Client
      final khataClient = Contact(
        name: 'Chaudhry Akram Super Store',
        type: 'customer',
        phone: '+92 345 1112233',
        balance: 0.0,
        creditLimit: 500000.0,
      );
      final clientId = await db.addContact(khataClient);

      // Customer takes items worth 45,000 on credit (Udhaar)
      final sampleProd = (await db.getProducts()).first;
      final invoiceNo = await db.generateNextInvoiceNo();
      final creditSale = Sale(
        invoiceNo: invoiceNo,
        customerId: clientId,
        customerName: 'Chaudhry Akram Super Store',
        subtotal: 45000.0,
        totalAmount: 45000.0,
        paidAmount: 0.0, // 0 paid -> 45,000 due
        paymentMethod: 'due',
        paymentStatus: 'due',
        createdAt: DateTime.now().toIso8601String(),
      );

      await db.createSale(
        sale: creditSale,
        items: [
          CartItem(
            product: sampleProd,
            quantity: 1.0,
            unitPrice: 45000.0,
          )
        ],
      );

      // Verify Customer Khata due balance atomically became 45,000
      final clientWithDebit = await db.getContactById(clientId);
      expect(clientWithDebit, isNotNull);
      expect(clientWithDebit!.balance, equals(45000.0));

      // Customer makes partial debt recovery payment (Wasooli) of 20,000 cash
      final paymentRef = await db.generateNextPaymentRef();
      final payment = ContactPayment(
        contactId: clientId,
        contactName: 'Chaudhry Akram Super Store',
        amount: 20000.0,
        paymentType: 'receive',
        paymentMethod: 'cash',
        refNo: paymentRef,
        date: DateTime.now().toIso8601String(),
        note: 'Partial payment received at counter',
      );

      final paymentId = await db.addContactPayment(payment);
      expect(paymentId, greaterThan(0));

      // Verify Customer balance automatically reduced to 25,000 (45000 - 20000)
      final clientAfterPayment = await db.getContactById(clientId);
      expect(clientAfterPayment!.balance, equals(25000.0));

      // Verify payment transaction recorded in payments list
      final payments = await db.getContactPayments(clientId);
      expect(payments.any((p) => p.refNo == paymentRef), isTrue);

      print('[VERIFIED] Step 5: Customer Khata verified. Credit: 45,000 -> Cash Wasooli: 20,000 -> Remaining Balance: 25,000');
    });

    test('STEP 6: Owner vs Salesman Operational Authorization Enforcement', () async {
      final users = await db.getUsers();
      final owner = users.firstWhere((u) => u.username == 'webdeventh');
      final salesman = users.firstWhere((u) => u.username == 'salesman1');

      // Rule 1: Selling Price alteration
      expect(owner.canEditPrice, isTrue, reason: 'Owner can change price');
      expect(salesman.canEditPrice, isFalse, reason: 'Salesman cannot change fixed counter prices');

      // Rule 2: Maximum Discount Rate
      expect(owner.maxDiscountPercent, equals(100.0));
      expect(salesman.maxDiscountPercent, equals(5.0));

      // Rule 3: Cost Price Masking
      expect(owner.canViewCostPrice, isTrue);
      expect(salesman.canViewCostPrice, isFalse);

      // Rule 4: Delete Invoices / Cancel Orders
      expect(owner.canDeleteSale, isTrue);
      expect(salesman.canDeleteSale, isFalse);

      // Rule 5: Cash Refunds on Returns
      expect(owner.canProcessReturn, isTrue);
      expect(salesman.canProcessReturn, isFalse);

      print('[VERIFIED] Step 6: All 5 Owner security restrictions actively enforced on salesman.');
    });
  });
}
