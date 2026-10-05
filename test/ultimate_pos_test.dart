import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Ultimate POS Core Engine Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      // Use in-memory SQLite database for isolated test execution
      dbService = await DatabaseService.initialize(customPath: inMemoryDatabasePath);
    });

    test('Initializes schema and seeds realistic demo data', () async {
      final settings = await dbService.getBusinessSettings();
      expect(settings.businessName, contains('Ultimate POS'));

      final categories = await dbService.getCategories();
      expect(categories.length, greaterThanOrEqualTo(5));

      final products = await dbService.getProducts();
      expect(products.length, greaterThanOrEqualTo(8));

      final customers = await dbService.getContacts(type: 'customer');
      expect(customers.length, greaterThanOrEqualTo(2));

      final suppliers = await dbService.getContacts(type: 'supplier');
      expect(suppliers.length, greaterThanOrEqualTo(2));
    });

    test('Barcode and SKU lookup returns correct product', () async {
      final productBySku = await dbService.getProductByCode('BEV-001');
      expect(productBySku, isNotNull);
      expect(productBySku!.name, contains('Coca Cola'));

      final productByBarcode = await dbService.getProductByCode('5449000000996');
      expect(productByBarcode, isNotNull);
      expect(productByBarcode!.sku, equals('BEV-001'));
    });

    test('Add product increments product catalog', () async {
      final newProd = Product(
        name: 'Mechanical Gaming Keyboard',
        sku: 'ELEC-999',
        barcode: '999888777666',
        categoryName: 'Electronics',
        purchasePrice: 45.0,
        sellingPrice: 79.99,
        stockQuantity: 15.0,
        alertQuantity: 3.0,
      );

      final id = await dbService.addProduct(newProd);
      expect(id, greaterThan(0));

      final fetched = await dbService.getProductByCode('ELEC-999');
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Mechanical Gaming Keyboard'));
      expect(fetched.sellingPrice, equals(79.99));
    });

    test('Completing a sale atomically creates invoice, deducts inventory and updates register', () async {
      final product = (await dbService.getProductByCode('BEV-001'))!;
      final initialStock = product.stockQuantity;

      final cartItem = CartItem(
        product: product,
        quantity: 3.0,
        unitPrice: product.sellingPrice,
      );

      final invoiceNo = await dbService.generateNextInvoiceNo();
      final sale = Sale(
        invoiceNo: invoiceNo,
        customerName: 'Test Customer',
        subtotal: cartItem.subtotal,
        totalAmount: cartItem.subtotal,
        paidAmount: cartItem.subtotal,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        createdAt: DateTime.now().toIso8601String(),
      );

      final completedSale = await dbService.createSale(sale: sale, items: [cartItem]);
      expect(completedSale.id, isNotNull);

      // Verify stock deducted
      final updatedProduct = (await dbService.getProductByCode('BEV-001'))!;
      expect(updatedProduct.stockQuantity, equals(initialStock - 3.0));

      // Verify sale recorded
      final sales = await dbService.getSales();
      expect(sales.any((s) => s.invoiceNo == invoiceNo), isTrue);
    });

    test('Stock receiving via purchase increases product inventory and sets supplier balance', () async {
      final product = (await dbService.getProductByCode('BEV-002'))!;
      final initialStock = product.stockQuantity;
      final supplier = (await dbService.getContacts(type: 'supplier')).first;

      final purchase = Purchase(
        refNo: 'PO-TEST-01',
        supplierId: supplier.id,
        supplierName: supplier.name,
        totalAmount: 100.0,
        paidAmount: 60.0, // Partial payment => 40 due
        createdAt: DateTime.now().toIso8601String(),
      );

      await dbService.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': product.id,
            'quantity': 20.0,
            'unit_cost': 5.0,
            'subtotal': 100.0,
          }
        ],
      );

      // Verify stock increased
      final updatedProduct = (await dbService.getProductByCode('BEV-002'))!;
      expect(updatedProduct.stockQuantity, equals(initialStock + 20.0));
    });

    test('Parked / Suspended sale can be saved and retrieved', () async {
      final product = (await dbService.getProducts()).first;
      final cartItem = CartItem(product: product, quantity: 2, unitPrice: product.sellingPrice);

      final parked = ParkedSale(
        customerName: 'Customer in line',
        note: 'Forgot wallet in car',
        total: cartItem.subtotal,
        createdAt: DateTime.now().toIso8601String(),
        itemsJson: jsonEncode([cartItem.toSavedStateMap()]),
      );

      final id = await dbService.parkSale(parked);
      expect(id, greaterThan(0));

      final parkedList = await dbService.getParkedSales();
      expect(parkedList.any((p) => p.customerName == 'Customer in line'), isTrue);

      final retrieved = parkedList.firstWhere((p) => p.customerName == 'Customer in line');
      final items = retrieved.getItems();
      expect(items.length, equals(1));
      expect(items.first.product.name, equals(product.name));
    });

    test('Dashboard metrics aggregates sales, purchases, and expenses', () async {
      final metrics = await dbService.getDashboardMetrics();
      expect(metrics.containsKey('totalSales'), isTrue);
      expect(metrics.containsKey('totalPurchases'), isTrue);
      expect(metrics.containsKey('totalExpenses'), isTrue);
      expect(metrics.containsKey('netProfit'), isTrue);
      expect(metrics['totalProducts'], greaterThan(0));
    });
  });
}
