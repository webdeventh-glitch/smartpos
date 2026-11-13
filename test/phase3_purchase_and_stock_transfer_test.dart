import 'dart:convert';
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

  group('Ultimate POS Phase 3: Purchase Lifecycle & Stock Transfers Parity',
      () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('purchase_transfer_test_');
      dbPath = path.join(
          tempDir.path, 'p3_${DateTime.now().microsecondsSinceEpoch}.db');
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
        '1. Purchase Status Ordered: Does NOT increment stock or supplier payable balance',
        () async {
      // 1. Create a supplier with 0 balance
      final supId = await dbService.addContact(Contact(
        type: 'supplier',
        name: 'Pharma Supplier Alpha',
        phone: '03001234567',
        balance: 0.0,
      ));

      // 2. Create a product with initial stock 10
      final prodId = await dbService.insertProduct(Product(
        name: 'Paracetamol 500mg',
        sku: 'PARA-500',
        barcode: 'PARA-500',
        sellingPrice: 50.0,
        purchasePrice: 30.0,
        stockQuantity: 10.0,
      ));

      // 3. Create a purchase with status = 'ordered' (Purchase Order) for 100 units
      final purchase = Purchase(
        refNo: 'PO-ORD-001',
        supplierId: supId,
        supplierName: 'Pharma Supplier Alpha',
        totalAmount: 3000.0,
        paidAmount: 0.0,
        status: 'ordered',
        paymentStatus: 'due',
        createdAt: DateTime.now().toIso8601String(),
      );

      final purchaseId = await dbService.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': prodId,
            'quantity': 100.0,
            'purchase_price': 30.0,
            'selling_price': 50.0,
          }
        ],
      );

      expect(purchaseId, isPositive);

      // Verify stock remains 10.0 (NOT 110.0)
      final prod =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prod.stockQuantity, 10.0);

      // Verify supplier ledger remains 0.0 (NOT 3000.0)
      final sup = (await dbService.getContacts(type: 'supplier'))
          .firstWhere((s) => s.id == supId);
      expect(sup.balance, 0.0);
    });

    test(
        '2. Purchase Status Pending: Does NOT increment stock or supplier balance',
        () async {
      final supId = await dbService.addContact(Contact(
        type: 'supplier',
        name: 'Hardware Supplier Beta',
        balance: 500.0,
      ));

      final prodId = await dbService.insertProduct(Product(
        name: 'Drill Bit Set',
        sku: 'DRL-001',
        barcode: 'DRL-001',
        sellingPrice: 2000.0,
        purchasePrice: 1500.0,
        stockQuantity: 5.0,
      ));

      final purchase = Purchase(
        refNo: 'PO-PND-002',
        supplierId: supId,
        supplierName: 'Hardware Supplier Beta',
        totalAmount: 15000.0,
        paidAmount: 0.0,
        status: 'pending',
        paymentStatus: 'due',
        createdAt: DateTime.now().toIso8601String(),
      );

      await dbService.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': prodId,
            'quantity': 10.0,
            'purchase_price': 1500.0,
          }
        ],
      );

      // Stock remains 5.0
      final prod =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prod.stockQuantity, 5.0);

      // Supplier balance remains 500.0
      final sup = (await dbService.getContacts(type: 'supplier'))
          .firstWhere((s) => s.id == supId);
      expect(sup.balance, 500.0);
    });

    test(
        '3. Update Purchase Status to Received: Automatically increments stock & updates supplier balance',
        () async {
      final supId = await dbService.addContact(Contact(
        type: 'supplier',
        name: 'Electronics Distributor',
        balance: 0.0,
      ));

      final prodId = await dbService.insertProduct(Product(
        name: 'USB-C Cable 1m',
        sku: 'USB-001',
        barcode: 'USB-001',
        sellingPrice: 400.0,
        purchasePrice: 200.0,
        stockQuantity: 20.0,
      ));

      // Step A: Create as 'ordered'
      final purchase = Purchase(
        refNo: 'PO-ORD-003',
        supplierId: supId,
        supplierName: 'Electronics Distributor',
        totalAmount: 10000.0, // 50 units * 200
        paidAmount: 0.0,
        status: 'ordered',
        paymentStatus: 'due',
        createdAt: DateTime.now().toIso8601String(),
      );

      final pId = await dbService.createPurchase(
        purchase: purchase,
        items: [
          {
            'product_id': prodId,
            'quantity': 50.0,
            'purchase_price': 200.0,
          }
        ],
      );

      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          20.0);

      // Step B: Mark as 'received'
      final ok = await dbService.updatePurchaseStatus(pId, 'received');
      expect(ok, isTrue);

      // Verify stock is now 20 + 50 = 70.0
      final prodReceived =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodReceived.stockQuantity, 70.0);

      // Verify supplier ledger is now 10000.0
      final supReceived = (await dbService.getContacts(type: 'supplier'))
          .firstWhere((s) => s.id == supId);
      expect(supReceived.balance, 10000.0);

      // Step C: Revert from 'received' to 'pending'
      final reverted = await dbService.updatePurchaseStatus(pId, 'pending');
      expect(reverted, isTrue);

      // Verify stock is back to 20.0
      final prodReverted =
          (await dbService.getProducts()).firstWhere((p) => p.id == prodId);
      expect(prodReverted.stockQuantity, 20.0);

      // Verify supplier balance is back to 0.0
      final supReverted = (await dbService.getContacts(type: 'supplier'))
          .firstWhere((s) => s.id == supId);
      expect(supReverted.balance, 0.0);
    });

    test('4. Delete Purchase: Safe behavior based on status', () async {
      final prodId = await dbService.insertProduct(Product(
        name: 'Test Delete Item',
        sku: 'DEL-ITM',
        barcode: 'DEL-ITM',
        sellingPrice: 100.0,
        purchasePrice: 60.0,
        stockQuantity: 15.0,
      ));

      // Case A: Delete 'ordered' purchase -> stock must remain 15.0
      final pOrdered = Purchase(
        refNo: 'PO-DEL-01',
        supplierName: 'Test Sup',
        totalAmount: 600.0,
        paidAmount: 0.0,
        status: 'ordered',
        createdAt: DateTime.now().toIso8601String(),
      );
      final p1Id = await dbService.createPurchase(
        purchase: pOrdered,
        items: [
          {'product_id': prodId, 'quantity': 10.0, 'purchase_price': 60.0}
        ],
      );
      await dbService.deletePurchase(p1Id);
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          15.0);

      // Case B: Create 'received' purchase (adds 10 -> stock becomes 25)
      final pReceived = Purchase(
        refNo: 'PO-DEL-02',
        supplierName: 'Test Sup',
        totalAmount: 600.0,
        paidAmount: 0.0,
        status: 'received',
        createdAt: DateTime.now().toIso8601String(),
      );
      final p2Id = await dbService.createPurchase(
        purchase: pReceived,
        items: [
          {'product_id': prodId, 'quantity': 10.0, 'purchase_price': 60.0}
        ],
      );
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          25.0);

      // Delete 'received' purchase -> reverses added stock back to 15.0
      await dbService.deletePurchase(p2Id);
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          15.0);
    });

    test(
        '5. Stock Transfers Status Workflow (Pending -> In-Transit -> Completed)',
        () async {
      final prodId = await dbService.insertProduct(Product(
        name: 'Transfer Item A',
        sku: 'TRF-001',
        barcode: 'TRF-001',
        sellingPrice: 500.0,
        purchasePrice: 300.0,
        stockQuantity: 50.0,
      ));

      // Step A: Create transfer with status 'pending' (No stock deducted)
      final transfer = StockTransfer(
        refNo: 'ST-TEST-001',
        fromLocationId: 1,
        fromLocationName: 'Main Warehouse',
        toLocationId: 2,
        toLocationName: 'Branch 2',
        status: 'pending',
        finalTotal: 3000.0,
        date: DateTime.now().toIso8601String(),
        itemsJson: jsonEncode([
          {
            'product_id': prodId,
            'product_name': 'Transfer Item A',
            'sku': 'TRF-001',
            'quantity': 10.0,
            'unit_price': 300.0,
          }
        ]),
      );

      final trfId = await dbService.createStockTransfer(transfer);
      expect(trfId, isPositive);

      // Stock remains 50.0
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          50.0);

      // Step B: Mark as 'in_transit' -> Stock deducted from source (50 - 10 = 40.0)
      final okTransit =
          await dbService.updateStockTransferStatus(trfId, 'in_transit');
      expect(okTransit, isTrue);
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          40.0);

      // Step C: Mark as 'completed' -> Status completed, stock stays deducted from source
      final okCompleted =
          await dbService.updateStockTransferStatus(trfId, 'completed');
      expect(okCompleted, isTrue);
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          40.0);

      // Step D: Delete completed transfer -> Restores stock back to 50.0
      await dbService.deleteStockTransfer(trfId);
      expect(
          (await dbService.getProducts())
              .firstWhere((p) => p.id == prodId)
              .stockQuantity,
          50.0);
    });
  });
}
