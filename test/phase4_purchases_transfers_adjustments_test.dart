import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 4: Purchases with Location, Stock Transfers, and Stock Adjustments', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase4_test_');
    final dbPath = '${tempDir.path}/test_phase4.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // Initial product stock check
    final products = await dbService.getProducts();
    expect(products.isNotEmpty, isTrue);
    final targetProd = products.first;
    final initialStock = targetProd.stockQuantity;

    // 1. Purchases with Location & Restocking
    final purchaseRef = await dbService.generateNextPurchaseRef();
    expect(purchaseRef.startsWith('PO-'), isTrue);

    final purchase = Purchase(
      refNo: purchaseRef,
      supplierId: 1,
      supplierName: 'Global Tech Distributors',
      locationId: 1,
      locationName: 'Main Branch HQ',
      totalAmount: 500.0,
      paidAmount: 300.0, // Partial payment, 200 due
      status: 'received',
      paymentStatus: 'partial',
      createdAt: DateTime.now().toIso8601String(),
      note: 'Bulk restock order',
    );

    final purchaseItems = [
      {
        'product_id': targetProd.id,
        'product_name': targetProd.name,
        'unit_cost': 25.0,
        'quantity': 20.0,
        'subtotal': 500.0,
      }
    ];

    final purchaseId = await dbService.createPurchase(purchase: purchase, items: purchaseItems);
    expect(purchaseId, isNonZero);

    // Verify stock incremented by 20
    final updatedProd = await dbService.getProductById(targetProd.id!);
    expect(updatedProd!.stockQuantity, equals(initialStock + 20.0));

    // Verify purchases list
    final allPurchases = await dbService.getPurchases();
    expect(allPurchases.any((p) => p.refNo == purchaseRef), isTrue);
    final savedPurchase = allPurchases.firstWhere((p) => p.refNo == purchaseRef);
    expect(savedPurchase.locationName, equals('Main Branch HQ'));
    expect(savedPurchase.dueAmount, equals(200.0));

    // 2. Stock Transfers between locations
    final transferRef = await dbService.generateNextTransferRef();
    expect(transferRef.startsWith('ST-'), isTrue);

    final transferItems = [
      StockTransferItem(
        productId: targetProd.id!,
        productName: targetProd.name,
        sku: targetProd.sku,
        quantity: 5.0,
        unitPrice: 25.0,
      ),
    ];

    final transfer = StockTransfer(
      refNo: transferRef,
      fromLocationId: 1,
      fromLocationName: 'Main Branch HQ',
      toLocationId: 2,
      toLocationName: 'Downtown Warehouse & Depot',
      status: 'completed',
      shippingCharges: 10.0,
      finalTotal: 135.0,
      date: DateTime.now().toIso8601String(),
      note: 'Urgent stock transfer',
      itemsJson: jsonEncode(transferItems.map((e) => e.toMap()).toList()),
    );

    final transferId = await dbService.createStockTransfer(transfer);
    expect(transferId, isNonZero);

    // Stock should be deducted by 5
    final afterTransferProd = await dbService.getProductById(targetProd.id!);
    expect(afterTransferProd!.stockQuantity, equals(initialStock + 20.0 - 5.0));

    final transfersList = await dbService.getStockTransfers();
    expect(transfersList.any((t) => t.refNo == transferRef), isTrue);

    // 3. Stock Adjustments (Shrinkage / Damage)
    final adjRef = await dbService.generateNextAdjustmentRef();
    expect(adjRef.startsWith('ADJ-'), isTrue);

    final adjItems = [
      StockAdjustmentItem(
        productId: targetProd.id!,
        productName: targetProd.name,
        sku: targetProd.sku,
        quantity: 2.0,
        unitPrice: 25.0,
      ),
    ];

    final adjustment = StockAdjustment(
      refNo: adjRef,
      locationId: 1,
      locationName: 'Main Branch HQ',
      adjustmentType: 'normal',
      totalAmount: 50.0,
      recoveredAmount: 10.0,
      reason: 'Package broken during transport',
      date: DateTime.now().toIso8601String(),
      itemsJson: jsonEncode(adjItems.map((e) => e.toMap()).toList()),
    );

    final adjId = await dbService.createStockAdjustment(adjustment);
    expect(adjId, isNonZero);

    // Stock should be further reduced by 2
    final afterAdjProd = await dbService.getProductById(targetProd.id!);
    expect(afterAdjProd!.stockQuantity, equals(initialStock + 20.0 - 5.0 - 2.0));

    final adjustmentsList = await dbService.getStockAdjustments();
    expect(adjustmentsList.any((a) => a.refNo == adjRef), isTrue);

    // 4. Deletion verification
    await dbService.deleteStockTransfer(transferId);
    final remainingTransfers = await dbService.getStockTransfers();
    expect(remainingTransfers.any((t) => t.id == transferId), isFalse);

    await dbService.deleteStockAdjustment(adjId);
    final remainingAdjs = await dbService.getStockAdjustments();
    expect(remainingAdjs.any((a) => a.id == adjId), isFalse);

    // Cleanup SQLite lock on Windows
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
