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

  group('Ultimate POS Phase 1: Cash Register Lifecycle & Safe Flow', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('register_test_');
      dbPath = path.join(
          tempDir.path, 'reg_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Shift Opening: creates register with custom opening cash float',
        () async {
      // Cashier opens shift with 3500.00
      await dbService.openRegister('Irfan Khan (Cashier)', 3500.0);

      final active = await dbService.getActiveRegister();
      expect(active, isNotNull);
      expect(active!.cashierName, 'Irfan Khan (Cashier)');
      expect(active.openingAmount, 3500.0);
      expect(active.totalSalesCash, 0.0);
      expect(active.status, 'open');
    });

    test('2. Cash sales correctly increment active register cash', () async {
      await dbService.openRegister('Cashier A', 2000.0);

      final product = Product(
        name: 'Item A',
        sku: 'SKU-001',
        barcode: 'BAR-001',
        sellingPrice: 1050.0,
        purchasePrice: 800.0,
        stockQuantity: 20.0,
      );
      final prodId = await dbService.insertProduct(product);
      final savedProduct = product.copyWith(id: prodId);

      final sale = Sale(
        invoiceNo: 'INV-TEST-001',
        customerName: 'Walk-in Customer',
        subtotal: 1050.0,
        totalAmount: 1050.0,
        paidAmount: 1050.0,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      );

      final cartItems = [
        CartItem(
          product: savedProduct,
          quantity: 1,
          unitPrice: 1050.0,
        ),
      ];

      await dbService.createSale(
        sale: sale,
        items: cartItems,
      );

      final active = await dbService.getActiveRegister();
      expect(active, isNotNull);
      expect(active!.totalSalesCash, 1050.0);
      expect(
          active.totalCashInRegister, 3050.0); // 2000 opening + 1050 cash sale
    });

    test('3. Cash expense automatically updates drawer cash balance', () async {
      await dbService.openRegister('Cashier A', 5000.0);

      // Record a cash expense out of the register (e.g. Utility/Tea)
      final expense = Expense(
        category: 'Refreshments',
        amount: 300.0,
        refNo: 'EXP-001',
        note: 'Tea for guests',
        date: DateTime.now().toIso8601String(),
        paymentMethod: 'cash',
      );
      await dbService.addExpense(expense);

      final active = await dbService.getActiveRegister();
      expect(active, isNotNull);
      // Verify in-drawer calculation: 5000 opening - 300 expense
      expect(active!.totalCashInRegister, 4700.0);
    });

    test('4. Cash sale return automatically updates drawer cash balance',
        () async {
      await dbService.openRegister('Cashier A', 5000.0);

      // Record a cash return refund
      final ret = SaleReturn(
        returnNo: 'RET-001',
        invoiceNo: 'INV-TEST-001',
        customerName: 'Walk-in Customer',
        date: DateTime.now().toIso8601String(),
        totalAmount: 450.0,
        refundAmount: 450.0,
        paymentMethod: 'cash',
        reason: 'Customer returned damaged item',
        items: [],
      );
      await dbService.addSaleReturn(ret);

      final active = await dbService.getActiveRegister();
      expect(active, isNotNull);
      // 5000 opening - 450 return refund = 4550.0
      expect(active!.totalCashInRegister, 4550.0);
    });

    test('5. Shift Closing: Z-Report closing flow marks register as closed',
        () async {
      await dbService.openRegister('Cashier B', 2000.0);

      final product = Product(
        name: 'Item B',
        sku: 'SKU-002',
        barcode: 'BAR-002',
        sellingPrice: 500.0,
        purchasePrice: 300.0,
        stockQuantity: 10.0,
      );
      final prodId = await dbService.insertProduct(product);
      final savedProduct = product.copyWith(id: prodId);

      final sale = Sale(
        invoiceNo: 'INV-TEST-002',
        customerName: 'Walk-in Customer',
        subtotal: 500.0,
        totalAmount: 500.0,
        paidAmount: 500.0,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        saleStatus: 'final',
        createdAt: DateTime.now().toIso8601String(),
      );

      await dbService.createSale(
        sale: sale,
        items: [
          CartItem(
            product: savedProduct,
            quantity: 1,
            unitPrice: 500.0,
          ),
        ],
      );

      final active = await dbService.getActiveRegister();
      final expectedCash = active!.totalCashInRegister; // 2500.0
      expect(expectedCash, 2500.0);

      // Cashier counts 2500.0 and closes shift
      await dbService.closeRegister(
          active.id!, 2500.0, 'Shift closed smoothly. No discrepancy.');

      final closedCheck = await dbService.getActiveRegister();
      expect(closedCheck, isNull);

      // Verify the closed record in database
      final allRegs = await dbService.db
          .query('cash_registers', orderBy: 'id DESC', limit: 1);
      expect(allRegs.first['status'], 'closed');
      expect(allRegs.first['closing_amount'], 2500.0);
      expect(allRegs.first['note'], contains('Shift closed smoothly'));
    });
  });
}
