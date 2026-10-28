import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Smart POS Comprehensive Business Reports Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_reports_');
      dbPath = path.join(tempDir.path, 'test_rep_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Multi-dimensional report correctly aggregates Sales, Purchases, Expenses, Taxes, and Margins', () async {
      // 1. Add Product
      final prodId = await dbService.addProduct(Product(
        name: 'HP EliteBook Laptop',
        sku: 'HP-840',
        barcode: 'HP-840-BC',
        purchasePrice: 50000.0,
        sellingPrice: 70000.0,
        stockQuantity: 20.0,
      ));
      final prod = (await dbService.getProductById(prodId))!;

      // 2. Add Customer
      final custId = await dbService.addContact(Contact(
        name: 'Tech Solutions Lahore',
        phone: '03001234567',
        type: 'customer',
        balance: 0.0,
      ));

      // 3. Add Sale: 2 units * 70,000 = 140,000 (Tax 5,000, Paid 100,000, Due 45,000)
      final sale = Sale(
        invoiceNo: 'INV-REP-001',
        customerId: custId,
        customerName: 'Tech Solutions Lahore',
        subtotal: 140000.0,
        taxAmount: 5000.0,
        totalAmount: 145000.0,
        paidAmount: 100000.0,
        paymentMethod: 'cash',
        saleStatus: 'final',
        paymentStatus: 'partial',
        createdAt: '2026-10-20 12:00:00',
      );
      await dbService.createSale(
        sale: sale,
        items: [CartItem(product: prod, quantity: 2.0, unitPrice: 70000.0)],
      );

      // 4. Add Purchase: 10 units * 50,000 = 500,000 (Paid 300,000, Due 210,000)
      final suppId = await dbService.addContact(Contact(
        name: 'HP Official Distributor',
        phone: '03211234567',
        type: 'supplier',
        balance: 0.0,
      ));

      final purchase = Purchase(
        refNo: 'PO-REP-001',
        supplierId: suppId,
        supplierName: 'HP Official Distributor',
        totalAmount: 510000.0,
        paidAmount: 300000.0,
        status: 'received',
        paymentStatus: 'partial',
        createdAt: '2026-10-21 14:00:00',
      );
      await dbService.createPurchase(purchase: purchase, items: [
        {
          'product_id': prod.id,
          'product_name': prod.name,
          'unit_cost': 50000.0,
          'quantity': 10.0,
          'subtotal': 500000.0,
        }
      ]);

      // 5. Add Operating Expense
      await dbService.addExpense(Expense(
        category: 'Shop Rent & Utilities',
        amount: 25000.0,
        refNo: 'EXP-101',
        date: '2026-10-22',
        note: 'October Rent',
      ));

      // 6. Query Comprehensive Report for whole month of October 2026
      final rep = await dbService.getComprehensiveBusinessReport(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31, 23, 59, 59),
      );

      expect(rep['invoiceCount'], 1);
      expect(rep['totalSales'], 145000.0);
      expect(rep['outputTax'], 5000.0);
      expect(rep['cogs'], 100000.0); // 2 units * 50,000 purchase price
      expect(rep['grossProfit'], 45000.0); // 145,000 - 100,000
      expect(rep['totalExpenses'], 25000.0);
      expect(rep['netProfit'], 20000.0); // 45,000 - 25,000

      // Purchases
      expect(rep['totalPurchases'], 510000.0);
      expect(rep['totalDuePurchases'], 210000.0);

      // Top Selling Products
      final topProducts = rep['topSellingProducts'] as List<dynamic>;
      expect(topProducts.isNotEmpty, isTrue);
      expect(topProducts.first['name'], 'HP EliteBook Laptop');
      expect(topProducts.first['quantity'], 2.0);

      // Expense Categories
      final expCats = rep['expenseCategories'] as List<dynamic>;
      expect(expCats.isNotEmpty, isTrue);
      expect(expCats.first['category'], 'Shop Rent & Utilities');
      expect(expCats.first['amount'], 25000.0);

      // Customer & Supplier Dues
      expect(rep['totalCustomerDue'], 45000.0);
      expect(rep['totalSupplierPayable'], 210000.0);
    });
  });
}
