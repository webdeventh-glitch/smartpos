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

  test('Phase 3: Cash Register, Suspend/Park Sales, and Split Payments Flow', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase3_test_');
    final dbPath = '${tempDir.path}/test_phase3.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Verify Register Open (automatically seeded or opened)
    var activeRegister = await dbService.getActiveRegister();
    expect(activeRegister, isNotNull);
    expect(activeRegister!.status, equals('open'));
    expect(activeRegister.closingAmount, equals(0.0));

    // 2. Suspend/Park a Sale order
    final cartItems = [
      CartItem(
        product: Product(
          id: 1,
          name: 'Wireless Bluetooth Mouse',
          sku: 'ACC-001',
          barcode: 'ACC-001',
          purchasePrice: 12.0,
          sellingPrice: 25.0,
          stockQuantity: 50.0,
        ),
        unitPrice: 25.0,
        quantity: 2.0,
      ),
      CartItem(
        product: Product(
          id: 2,
          name: 'Mechanical Gaming Keyboard',
          sku: 'ACC-002',
          barcode: 'ACC-002',
          purchasePrice: 40.0,
          sellingPrice: 79.99,
          stockQuantity: 20.0,
        ),
        unitPrice: 79.99,
        quantity: 1.0,
      ),
    ];

    final itemsMap = cartItems.map((e) => e.toSavedStateMap()).toList();
    final parked = ParkedSale(
      customerName: 'Ahmad Khan',
      note: 'Customer went to get wallet',
      total: 129.99,
      createdAt: DateTime.now().toIso8601String(),
      itemsJson: jsonEncode(itemsMap),
    );

    final parkedId = await dbService.parkSale(parked);
    expect(parkedId, isNonZero);

    var parkedList = await dbService.getParkedSales();
    expect(parkedList.length, equals(1));
    expect(parkedList.first.customerName, equals('Ahmad Khan'));
    expect(parkedList.first.total, equals(129.99));

    // Restore items from parked sale
    final restoredItems = parkedList.first.getItems();
    expect(restoredItems.length, equals(2));
    expect(restoredItems[0].product.name, equals('Wireless Bluetooth Mouse'));
    expect(restoredItems[0].quantity, equals(2.0));

    // Delete parked sale once resumed
    await dbService.deleteParkedSale(parkedId);
    parkedList = await dbService.getParkedSales();
    expect(parkedList.isEmpty, isTrue);

    // 3. Process Checkout with invoice generation & payment status
    final sale = Sale(
      invoiceNo: 'INV-TEST-0001',
      customerName: 'Ahmad Khan',
      subtotal: 129.99,
      discount: 0.0,
      taxAmount: 0.0,
      totalAmount: 129.99,
      paidAmount: 129.99,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      saleStatus: 'final',
      createdAt: DateTime.now().toIso8601String(),
    );

    final createdSale = await dbService.createSale(
      sale: sale,
      items: restoredItems,
    );
    expect(createdSale.id, isNotNull);

    // Verify register updated with cash sale
    activeRegister = await dbService.getActiveRegister();
    expect(activeRegister!.totalSalesCash, greaterThanOrEqualTo(129.99));

    // 4. Verify Close Register
    await dbService.closeRegister(
      activeRegister.id!,
      activeRegister.totalCashInRegister,
      'Shift end, cash reconciled successfully.',
    );

    activeRegister = await dbService.getActiveRegister();
    expect(activeRegister, isNull); // Closed, so no currently active register

    // Reopen a new register session (e.g. next shift)
    await dbService.openRegister(
      'Cashier Ali',
      300.0,
    );

    final newActiveRegister = await dbService.getActiveRegister();
    expect(newActiveRegister, isNotNull);
    expect(newActiveRegister!.openingAmount, equals(300.0));
    expect(newActiveRegister.cashierName, equals('Cashier Ali'));

    // Cleanup SQLite lock on Windows
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
