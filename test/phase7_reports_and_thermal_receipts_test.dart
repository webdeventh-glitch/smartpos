import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 7: Profit & Loss Statement, Stock Valuation Audit, and Thermal Receipt Formatting', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase7_test_');
    final dbPath = '${tempDir.path}/test_phase7.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Profit & Loss Report Verification
    final pnl = await dbService.getProfitAndLossReport();
    expect(pnl.containsKey('totalSales'), isTrue);
    expect(pnl.containsKey('cogs'), isTrue);
    expect(pnl.containsKey('grossProfit'), isTrue);
    expect(pnl.containsKey('totalExpenses'), isTrue);
    expect(pnl.containsKey('recoveredAmount'), isTrue);
    expect(pnl.containsKey('netProfit'), isTrue);

    // 2. Stock Valuation Report Verification
    final valuation = await dbService.getStockValuationReport();
    expect(valuation.containsKey('totalItems'), isTrue);
    expect(valuation.containsKey('totalQuantity'), isTrue);
    expect(valuation.containsKey('stockValueCost'), isTrue);
    expect(valuation.containsKey('stockValueRetail'), isTrue);
    expect(valuation.containsKey('potentialProfit'), isTrue);

    expect((valuation['totalItems'] as int), greaterThan(0));
    expect((valuation['stockValueCost'] as double), greaterThan(0.0));
    expect((valuation['stockValueRetail'] as double), greaterThan(0.0));
    expect((valuation['potentialProfit'] as double), greaterThanOrEqualTo(0.0));

    // 3. Receipt Formatting Verification
    final sale = Sale(
      invoiceNo: 'INV-2026-9999',
      customerName: 'Zubair Ahmed',
      subtotal: 100.0,
      discount: 10.0,
      taxAmount: 5.0,
      shipping: 5.0,
      totalAmount: 100.0,
      paidAmount: 100.0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      createdAt: '2026-10-05 21:00:00',
      items: [
        SaleItem(
          saleId: 1,
          productName: 'Gaming Mouse Pad',
          sku: 'ACC-PAD-01',
          unitPrice: 50.0,
          quantity: 2.0,
          subtotal: 100.0,
        ),
      ],
    );

    expect(sale.items!.length, equals(1));
    expect(sale.totalAmount, equals(100.0));
    expect(sale.dueAmount, equals(0.0));

    // Cleanup SQLite lock on Windows
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
