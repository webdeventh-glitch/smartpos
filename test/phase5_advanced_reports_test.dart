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

  group('Ultimate POS Phase 5: Advanced Reports (Shift, Expiry, Trending Products)', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('adv_reports_test_');
      dbPath = path.join(tempDir.path, 'reports_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Cash Register Shifts Report: Audits shifts, payment methods and cash variance', () async {
      // 1. Open shift for Cashier Ahmed with Rs 10,000 float
      await dbService.openRegister('Ahmed Cashier', 10000.0);
      final active = await dbService.getActiveRegister();
      expect(active, isNotNull);
      expect(active!.cashierName, 'Ahmed Cashier');
      expect(active.openingAmount, 10000.0);

      // 2. Add cash sale (Rs 5,000) and card sale (Rs 3,000)
      final pId = await dbService.insertProduct(Product(
        name: 'Surgical Mask Box',
        sku: 'MSK-01',
        barcode: 'MSK-01',
        purchasePrice: 200.0,
        sellingPrice: 350.0,
        stockQuantity: 100,
        unit: 'Box',
      ));
      final maskProduct = (await dbService.getProducts()).firstWhere((p) => p.id == pId);

      // Sale 1: Cash Rs 5,000
      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-TEST-001',
          subtotal: 5000.0,
          totalAmount: 5000.0,
          paidAmount: 5000.0,
          saleStatus: 'final',
          paymentStatus: 'paid',
          paymentMethod: 'cash',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(product: maskProduct, quantity: 14.28, unitPrice: 350.0),
        ],
      );

      // Sale 2: Card Rs 3,000
      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-TEST-002',
          subtotal: 3000.0,
          totalAmount: 3000.0,
          paidAmount: 3000.0,
          saleStatus: 'final',
          paymentStatus: 'paid',
          paymentMethod: 'card',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(product: maskProduct, quantity: 8.57, unitPrice: 350.0),
        ],
      );

      // 3. Close shift with Rs 14,800 counted cash (Expected: 10,000 + 5,000 = 15,000 -> Rs 200 shortage)
      await dbService.closeRegister(active.id!, 14800.0, 'Shift closed with Rs 200 minor drawer deficit');

      // 4. Open second shift for Cashier Bilal with Rs 5,000 float (stays open)
      await dbService.openRegister('Bilal Shift Lead', 5000.0);

      // 5. Query register report
      final allReports = await dbService.getRegisterReport(status: 'all');
      expect(allReports.length, greaterThanOrEqualTo(2));

      // Check Ahmed's closed shift
      final ahmedShift = allReports.firstWhere((r) => r['cashier_name'] == 'Ahmed Cashier');
      expect(ahmedShift['status'], 'closed');
      expect(ahmedShift['opening_amount'], 10000.0);
      expect(ahmedShift['total_sales_cash'], 5000.0);
      expect(ahmedShift['total_sales_card'], 3000.0);
      expect(ahmedShift['total_sales'], 8000.0);
      expect(ahmedShift['expected_cash'], 15000.0);
      expect(ahmedShift['closing_amount'], 14800.0);
      expect(ahmedShift['difference'], -200.0);

      // Check Bilal's open shift
      final bilalShift = allReports.firstWhere((r) => r['cashier_name'] == 'Bilal Shift Lead');
      expect(bilalShift['status'], 'open');
      expect(bilalShift['opening_amount'], 5000.0);

      // Test status filters
      final openOnly = await dbService.getRegisterReport(status: 'open');
      expect(openOnly.any((r) => r['cashier_name'] == 'Bilal Shift Lead'), isTrue);

      final closedOnly = await dbService.getRegisterReport(status: 'closed');
      expect(closedOnly.any((r) => r['cashier_name'] == 'Ahmed Cashier'), isTrue);
    });

    test('2. Stock Expiry & Batch Traceability: Filters expired and upcoming shelf risks', () async {
      final now = DateTime.now();

      // Product 1: Already expired (10 days ago)
      final expPast = now.subtract(const Duration(days: 10));
      await dbService.insertProduct(Product(
        name: 'Expired Antibiotic Syrup',
        sku: 'MED-EXP-01',
        barcode: 'MED-EXP-01',
        batchNumber: 'BAT-PAST-99',
        expiryDate: '${expPast.year}-${expPast.month.toString().padLeft(2, '0')}-${expPast.day.toString().padLeft(2, '0')}',
        purchasePrice: 150.0,
        sellingPrice: 220.0,
        stockQuantity: 20,
        unit: 'Bottle',
      ));

      // Product 2: Expiring in 15 days (Critical - <= 30 days)
      final expCritical = now.add(const Duration(days: 15));
      await dbService.insertProduct(Product(
        name: 'Critical Eye Drops',
        sku: 'MED-CRIT-02',
        barcode: 'MED-CRIT-02',
        batchNumber: 'BAT-CRIT-15',
        expiryDate: '${expCritical.year}-${expCritical.month.toString().padLeft(2, '0')}-${expCritical.day.toString().padLeft(2, '0')}',
        purchasePrice: 300.0,
        sellingPrice: 450.0,
        stockQuantity: 10,
        unit: 'Vial',
      ));

      // Product 3: Expiring in 50 days (Warning - <= 60 days)
      final expWarning = now.add(const Duration(days: 50));
      await dbService.insertProduct(Product(
        name: 'Warning Multivitamin',
        sku: 'MED-WARN-03',
        barcode: 'MED-WARN-03',
        batchNumber: 'BAT-WARN-50',
        expiryDate: '${expWarning.year}-${expWarning.month.toString().padLeft(2, '0')}-${expWarning.day.toString().padLeft(2, '0')}',
        purchasePrice: 500.0,
        sellingPrice: 700.0,
        stockQuantity: 15,
        unit: 'Box',
      ));

      // Product 4: Valid long shelf life (2 years ahead)
      await dbService.insertProduct(Product(
        name: 'Long Life Antiseptic',
        sku: 'MED-SAFE-04',
        barcode: 'MED-SAFE-04',
        batchNumber: 'BAT-SAFE-2Y',
        expiryDate: '15 Dec 2028',
        purchasePrice: 100.0,
        sellingPrice: 150.0,
        stockQuantity: 50,
        unit: 'Bottle',
      ));

      // Product 5: Zero stock item (Should NOT appear in active shelf risk)
      await dbService.insertProduct(Product(
        name: 'Out of Stock Expired Drug',
        sku: 'MED-ZERO-05',
        barcode: 'MED-ZERO-05',
        batchNumber: 'BAT-ZERO-00',
        expiryDate: '01-2025',
        purchasePrice: 200.0,
        sellingPrice: 300.0,
        stockQuantity: 0,
        unit: 'Strip',
      ));

      // 1. All Tracked items
      final allItems = await dbService.getStockExpiryReport(filter: 'all');
      expect(allItems.length, 4, reason: 'Zero stock product must be excluded');

      // 2. Already Expired filter
      final expiredItems = await dbService.getStockExpiryReport(filter: 'expired');
      expect(expiredItems.length, 1);
      expect(expiredItems.first['sku'], 'MED-EXP-01');
      expect(expiredItems.first['status_category'], 'expired');
      expect(expiredItems.first['stock_value_cost'], 20 * 150.0); // Rs 3,000 cost at risk

      // 3. Expiring in 30 Days filter (includes expired + critical)
      final thirtyDays = await dbService.getStockExpiryReport(filter: '30_days');
      expect(thirtyDays.length, 2);
      expect(thirtyDays.any((i) => i['sku'] == 'MED-EXP-01'), isTrue);
      expect(thirtyDays.any((i) => i['sku'] == 'MED-CRIT-02'), isTrue);

      // 4. Expiring in 60 Days filter
      final sixtyDays = await dbService.getStockExpiryReport(filter: '60_days');
      expect(sixtyDays.length, 3);
      expect(sixtyDays.any((i) => i['sku'] == 'MED-WARN-03'), isTrue);

      // 5. Search query filtering
      final searched = await dbService.getStockExpiryReport(searchQuery: 'BAT-CRIT');
      expect(searched.length, 1);
      expect(searched.first['product_name'], 'Critical Eye Drops');
    });

    test('3. Expiry Date Parser Diversity: Gracefully handles various industry date formats', () {
      // Format 1: "15 Dec 2026"
      final d1 = parseExpiryDate('15 Dec 2026');
      expect(d1, isNotNull);
      expect(d1!.year, 2026);
      expect(d1.month, 12);
      expect(d1.day, 15);

      // Format 2: "02-2026" (Month-Year)
      final d2 = parseExpiryDate('02-2026');
      expect(d2, isNotNull);
      expect(d2!.year, 2026);
      expect(d2.month, 2);

      // Format 3: "2027-11-20" (ISO standard)
      final d3 = parseExpiryDate('2027-11-20');
      expect(d3, isNotNull);
      expect(d3!.year, 2027);
      expect(d3.month, 11);
      expect(d3.day, 20);

      // Format 4: "October 2027"
      final d4 = parseExpiryDate('October 2027');
      expect(d4, isNotNull);
      expect(d4!.year, 2027);
      expect(d4.month, 10);

      // Null or empty
      expect(parseExpiryDate(null), isNull);
      expect(parseExpiryDate('   '), isNull);
    });

    test('4. Trending Products Analysis: Computes volume and revenue rank accurately', () async {
      // Insert Product A: High volume, low revenue
      final idA = await dbService.insertProduct(Product(
        name: 'Bulk Sachet Pack',
        sku: 'BULK-01',
        barcode: 'BULK-01',
        purchasePrice: 10.0,
        sellingPrice: 15.0,
        stockQuantity: 500,
        unit: 'Sachet',
      ));
      final prodA = (await dbService.getProducts()).firstWhere((p) => p.id == idA);

      // Insert Product B: Low volume, high revenue
      final idB = await dbService.insertProduct(Product(
        name: 'Solar Inverter 6kW',
        sku: 'INV-6KW',
        barcode: 'INV-6KW',
        purchasePrice: 200000.0,
        sellingPrice: 280000.0,
        stockQuantity: 10,
        unit: 'Unit',
      ));
      final prodB = (await dbService.getProducts()).firstWhere((p) => p.id == idB);

      // Create Sales
      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-VOL-01',
          subtotal: 1500.0,
          totalAmount: 1500.0,
          paidAmount: 1500.0,
          saleStatus: 'final',
          paymentStatus: 'paid',
          paymentMethod: 'cash',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(product: prodA, quantity: 100, unitPrice: 15.0),
        ],
      );

      await dbService.createSale(
        sale: Sale(
          invoiceNo: 'INV-REV-01',
          subtotal: 280000.0,
          totalAmount: 280000.0,
          paidAmount: 280000.0,
          saleStatus: 'final',
          paymentStatus: 'paid',
          paymentMethod: 'card',
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [
          CartItem(product: prodB, quantity: 1, unitPrice: 280000.0),
        ],
      );

      final report = await dbService.getComprehensiveBusinessReport();
      final topList = report['topSellingProducts'] as List<dynamic>;

      expect(topList.length, 2);

      // In the raw report, sorted by volume:
      expect(topList.first['name'], 'Bulk Sachet Pack');
      expect((topList.first['quantity'] as num).toDouble(), 100.0);

      // When sorted by revenue:
      final byRev = List<Map<String, dynamic>>.from(topList);
      byRev.sort((a, b) => ((b['revenue'] as num).toDouble()).compareTo((a['revenue'] as num).toDouble()));
      expect(byRev.first['name'], 'Solar Inverter 6kW');
      expect((byRev.first['revenue'] as num).toDouble(), 280000.0);
    });
  });
}
