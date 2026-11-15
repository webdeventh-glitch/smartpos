import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('UltimatePOS Parity Upgrades Test Suite (Phases 1, 2, 3)', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ultimatepos_parity_test_');
      dbPath = path.join(
          tempDir.path, 'parity_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        await dbService.db.close();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Phase 1: ModuleRegistry contains all 15+ core SaaS modules', () {
      expect(ModuleRegistry.corePos, equals('core_pos'));
      expect(ModuleRegistry.accounting, equals('accounting_crm'));
      expect(ModuleRegistry.restaurant, equals('restaurant'));
      expect(ModuleRegistry.pharmacy, equals('batch_expiry'));
      expect(ModuleRegistry.repair, equals('repair'));
      expect(ModuleRegistry.hotel, equals('hotel'));
      expect(ModuleRegistry.gym, equals('gym'));
      expect(ModuleRegistry.manufacturing, equals('manufacturing'));
      expect(ModuleRegistry.hrm, equals('hrm'));
      expect(ModuleRegistry.cloudSync, equals('cloud_sync'));
      expect(ModuleRegistry.lanMultiCounter, equals('lan_counter'));
      expect(ModuleRegistry.allModules, contains(ModuleRegistry.restaurant));
      expect(ModuleRegistry.allModules.length, greaterThanOrEqualTo(15));
    });

    test('Phase 1: CartItem supports negative line items for counter exchange',
        () {
      final product = Product(
        id: 101,
        name: 'Cotton T-Shirt Blue',
        sku: 'TSH-BLU',
        barcode: '10101010',
        purchasePrice: 400.0,
        sellingPrice: 800.0,
        stockQuantity: 20.0,
      );

      final exchangeReturnItem = CartItem(
        product: product,
        quantity: -1.0,
        unitPrice: 800.0,
      );

      expect(exchangeReturnItem.isReturnItem, isTrue);
      expect(exchangeReturnItem.quantity, equals(-1.0));
      expect(exchangeReturnItem.subtotal, equals(-800.0));
    });

    test('Phase 1: Blind return routes damaged stock to scrap quarantine',
        () async {
      final product = Product(
        name: 'LED Bulb 18W',
        sku: 'LED-18W',
        barcode: '20202020',
        purchasePrice: 150.0,
        sellingPrice: 300.0,
        stockQuantity: 50.0,
      );
      final prodId = await dbService.addProduct(product);

      final damagedReturnItem = SaleReturnItem(
        returnId: 1,
        productId: prodId,
        productName: 'LED Bulb 18W',
        quantity: 2.0,
        unitPrice: 300.0,
        subtotal: 600.0,
        isDamaged: true,
        destination: 'quarantine',
      );

      final saleReturn = SaleReturn(
        returnNo: 'RET-BLIND-001',
        saleId: null,
        invoiceNo: 'BLIND-RETURN',
        customerName: 'Walk-in',
        date: DateTime.now().toIso8601String(),
        totalAmount: 600.0,
        refundAmount: 600.0,
        refundStatus: 'paid',
        paymentMethod: 'cash',
        note: 'Customer returned shattered bulb without receipt',
        items: [damagedReturnItem],
      );

      final returnId = await dbService.addSaleReturn(saleReturn);
      expect(returnId, greaterThan(0));

      // Active stock must NOT increase for damaged scrap items
      final updatedProd = await dbService.getProduct(prodId);
      expect(updatedProd?.stockQuantity, equals(50.0));

      // Must be logged into stock_adjustments as abnormal quarantine
      final adjustments = await dbService.db.query(
        'stock_adjustments',
        where: 'adjustment_type = ?',
        whereArgs: ['abnormal'],
      );
      expect(adjustments.isNotEmpty, isTrue);
      expect(adjustments.first['total_amount'], equals(600.0));
    });

    test('Phase 2: Product Rack/Shelf/Row location saves and loads properly',
        () async {
      final product = Product(
        name: 'Ceramic Floor Tiles 60x60',
        sku: 'TILE-6060',
        barcode: '30303030',
        purchasePrice: 1200.0,
        sellingPrice: 1600.0,
        stockQuantity: 100.0,
        rackLocation: 'Aisle 4, Rack B, Row 2',
      );

      final prodId = await dbService.addProduct(product);
      final fetched = await dbService.getProduct(prodId);

      expect(fetched?.rackLocation, equals('Aisle 4, Rack B, Row 2'));
    });

    test(
        'Phase 2: Combo/Bundle BOM components auto-deduct and restore atomically',
        () async {
      // 1. Create components
      final panelId = await dbService.addProduct(Product(
        name: 'Solar Panel 550W',
        sku: 'SOL-550',
        barcode: '40404040',
        purchasePrice: 15000.0,
        sellingPrice: 18000.0,
        stockQuantity: 10.0,
      ));
      final inverterId = await dbService.addProduct(Product(
        name: 'Hybrid Inverter 6kW',
        sku: 'INV-6KW',
        barcode: '50505050',
        purchasePrice: 120000.0,
        sellingPrice: 145000.0,
        stockQuantity: 5.0,
      ));

      // 2. Create bundle product
      final bundleId = await dbService.addProduct(Product(
        name: 'Complete 3kW Solar System',
        sku: 'BNDL-SOL3KW',
        barcode: '60606060',
        type: 'combo',
        purchasePrice: 180000.0,
        sellingPrice: 220000.0,
        stockQuantity: 1.0,
      ));

      // 3. Link components into product_bundles (6 panels + 1 inverter)
      await dbService.db.insert('product_bundles', {
        'parent_product_id': bundleId,
        'sub_product_id': panelId,
        'sub_product_name': 'Solar Panel 550W',
        'quantity': 6.0,
      });
      await dbService.db.insert('product_bundles', {
        'parent_product_id': bundleId,
        'sub_product_id': inverterId,
        'sub_product_name': 'Hybrid Inverter 6kW',
        'quantity': 1.0,
      });

      // 4. Sell 1 bundle
      final bundleProd = (await dbService.getProduct(bundleId))!;
      final sale = Sale(
        invoiceNo: 'INV-BNDL-001',
        subtotal: 220000.0,
        totalAmount: 220000.0,
        paidAmount: 220000.0,
        saleStatus: 'final',
        paymentStatus: 'paid',
        createdAt: DateTime.now().toIso8601String(),
        locationId: 1,
      );
      final saleItems = [
        CartItem(
          product: bundleProd,
          quantity: 1.0,
          unitPrice: 220000.0,
        ),
      ];

      final createdSale = await dbService.salesRepo.createSale(
        sale: sale,
        items: saleItems,
      );
      final saleId = createdSale.id!;
      expect(saleId, greaterThan(0));

      // 5. Verify component stocks deducted
      final panelAfterSale = await dbService.getProduct(panelId);
      final invAfterSale = await dbService.getProduct(inverterId);
      expect(panelAfterSale?.stockQuantity, equals(4.0)); // 10 - 6 = 4
      expect(invAfterSale?.stockQuantity, equals(4.0)); // 5 - 1 = 4

      // 6. Delete sale and verify components restored
      await dbService.salesRepo.deleteSale(saleId);
      final panelAfterCancel = await dbService.getProduct(panelId);
      final invAfterCancel = await dbService.getProduct(inverterId);
      expect(panelAfterCancel?.stockQuantity, equals(10.0)); // Restored to 10
      expect(invAfterCancel?.stockQuantity, equals(5.0)); // Restored to 5
    });

    test(
        'Phase 2: Cheque clearance & bounce re-debits customer and adjusts bank',
        () async {
      // 1. Create Bank Account with Rs 50,000 balance
      final accId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Meezan Bank Operations',
        accountNumber: 'PK92MEZN001',
        accountType: 'bank',
        currentBalance: 50000.0,
      ));

      // 2. Create customer with 0 balance
      final custId = await dbService.addContact(Contact(
        type: 'customer',
        name: 'Haji Aslam Textiles',
        phone: '03001234567',
        balance: 0.0,
      ));

      // 3. Issue sale cheque of Rs 25,000
      final tx = PaymentTransaction(
        transactionType: 'sale',
        contactId: custId,
        contactName: 'Haji Aslam Textiles',
        paymentMethod: 'cheque',
        amount: 25000.0,
        accountId: accId,
        chequeNumber: 'CHQ-88201',
        bankName: 'HBL',
        chequeDueDate: '2026-11-20',
        chequeStatus: 'pending',
        transactionDate: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );
      final txId = await dbService.addPaymentTransaction(tx);

      // 4. Mark cheque as Cleared -> Bank balance increases to Rs 75,000
      await dbService.updateChequeStatus(
          transactionId: txId, newStatus: 'cleared');
      final accsCleared = await dbService.getPaymentAccounts();
      final accCleared = accsCleared.firstWhere((a) => a.id == accId);
      expect(accCleared.currentBalance, equals(75000.0));

      // 5. Dishonored / Bounced after deposit -> Bank reverses back to 50,000 and customer re-debited
      await dbService.updateChequeStatus(
          transactionId: txId, newStatus: 'bounced');

      // Customer balance should be re-debited with Rs 25,000
      final custAfterBounce =
          await dbService.contactsRepo.getContactById(custId);
      expect(custAfterBounce?.balance, equals(25000.0));

      // Bank account should be reversed back to 50,000
      final accsBounced = await dbService.getPaymentAccounts();
      final accAfterBounce = accsBounced.firstWhere((a) => a.id == accId);
      expect(accAfterBounce.currentBalance, equals(50000.0));
    });

    test('Phase 3: Restaurant KDS tracks live orders and advances statuses',
        () async {
      final kotId = await dbService.addRestaurantKotOrder({
        'kot_no': 'KOT-9021',
        'table_name': 'Table 7',
        'order_type': 'Dine-In',
        'items': '2x Zinger Burger, 1x Family Fries',
        'status': 'Cooking',
        'time': '8:15 PM',
        'server_name': 'Captain Usman',
      });

      expect(kotId, greaterThan(0));

      final orders = await dbService.getRestaurantKotOrders();
      final match = orders.firstWhere((k) => k['id'] == kotId);
      expect(match['status'], equals('Cooking'));

      // Chef marks order as Ready
      await dbService.updateRestaurantKotStatus(kotId, 'Ready');
      final updatedOrders = await dbService.getRestaurantKotOrders();
      final updatedMatch = updatedOrders.firstWhere((k) => k['id'] == kotId);
      expect(updatedMatch['status'], equals('Ready'));

      // Waiter marks order as Served
      await dbService.updateRestaurantKotStatus(kotId, 'Served');
      final servedOrders = await dbService.getRestaurantKotOrders();
      final servedMatch = servedOrders.firstWhere((k) => k['id'] == kotId);
      expect(servedMatch['status'], equals('Served'));
    });

    test('Phase 3: Pharmacy FEFO batches sorts by earliest expiry first',
        () async {
      final medId = await dbService.addProduct(Product(
        name: 'Augmentin 625mg Tablets',
        sku: 'AUG-625',
        barcode: '70707070',
        purchasePrice: 280.0,
        sellingPrice: 350.0,
        stockQuantity: 100.0,
      ));

      // Batch 1: Expiring in 2027
      await dbService.addProductSerialBatch(ProductSerialBatch(
        productId: medId,
        productName: 'Augmentin 625mg',
        sku: 'AUG-625',
        serialNumber1: '',
        serialNumber2: '',
        batchNumber: 'BATCH-2027-LATE',
        manufacturingDate: '2025-01-01',
        expiryDate: '2027-12-31',
        status: 'in_stock',
        locationId: 1,
        createdAt: DateTime.now().toIso8601String(),
      ));

      // Batch 2: Expiring earlier in 2026 (FEFO Priority)
      await dbService.addProductSerialBatch(ProductSerialBatch(
        productId: medId,
        productName: 'Augmentin 625mg',
        sku: 'AUG-625',
        serialNumber1: '',
        serialNumber2: '',
        batchNumber: 'BATCH-2026-EARLY',
        manufacturingDate: '2024-06-01',
        expiryDate: '2026-06-30',
        status: 'in_stock',
        locationId: 1,
        createdAt: DateTime.now().toIso8601String(),
      ));

      final activeBatches = await dbService.getActiveBatchesForProduct(medId);
      expect(activeBatches.length, equals(2));
      // First batch MUST be the earliest expiry (FEFO)
      expect(activeBatches.first.batchNumber, equals('BATCH-2026-EARLY'));
      expect(activeBatches.last.batchNumber, equals('BATCH-2027-LATE'));
    });
  });
}
