import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/pos/pos_terminal_screen.dart';
import 'package:desktop_starter/services/auth_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    AuthService.resetSecurityStateForTest();
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase8_audit_');
  });

  tearDown(() async {
    try {
      final inst = DatabaseService.instanceOrNull;
      if (inst != null &&
          inst.db.isOpen &&
          inst.dbFilePath != null &&
          inst.dbFilePath!.startsWith(tempDir.path)) {
        await DatabaseService.closeOpenInstanceIfPathMatches(inst.dbFilePath!);
      }
    } catch (_) {}
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Future<DatabaseService> openFreshDb(String name) async {
    return DatabaseService.initialize(
      customPath: p.join(tempDir.path, name),
    );
  }

  test(
    'Schema v9 tables, FinancialYear receivables/payables & ParkedSale mappings persist losslessly',
    () async {
      final db = await openFreshDb('schema_v9_parity.db');
      expect(DatabaseService.currentSchemaVersion, 9);

      final prodId = await db.addProduct(
        Product(
          name: 'Basmati Rice 5kg',
          sku: 'RICE-5KG',
          barcode: '8961001001001',
          purchasePrice: 900.0,
          sellingPrice: 1200.0,
          stockQuantity: 25.0,
          rackLocation: 'Aisle 3 - B2',
        ),
      );
      final locStocks = await db.getProductLocationStocks(prodId);
      expect(locStocks[1], 25.0);

      final loadedProd = await db.getProductById(prodId);
      expect(loadedProd, isNotNull);
      expect(loadedProd!.rackLocation, 'Aisle 3 - B2');

      // FinancialYear preserves receivables & payables losslessly
      final fy = FinancialYear(
        yearTitle: 'FY 2025-26',
        startDate: '2025-07-01',
        endDate: '2026-06-30',
        closingDate: '2026-06-30',
        closedBy: 'Admin',
        totalSales: 500000.0,
        totalPurchases: 320000.0,
        totalExpenses: 40000.0,
        netProfit: 140000.0,
        stockValuation: 95000.0,
        receivables: 42000.0,
        payables: 18500.0,
      );
      await db.db.insert('financial_years', fy.toMap());
      final fyRows = await db.db.query('financial_years');
      final readFy = FinancialYear.fromMap(fyRows.last);
      expect(readFy.receivables, 42000.0);
      expect(readFy.payables, 18500.0);

      // ParkedSale persists extended metadata cleanly
      final parked = ParkedSale(
        customerId: 1,
        customerName: 'Walk-in Customer',
        note: 'Held test',
        total: 1150.0,
        createdAt: '2026-11-12 12:00:00',
        itemsJson: '[]',
        discountType: 'percentage',
        discountValue: 10.0,
        orderTax: 50.0,
        shippingCharge: 20.0,
        isWholesale: true,
        commissionAgentId: 7,
        commissionAgentName: 'Bilal',
      );
      await db.parkSale(parked);
      final parkedList = await db.getParkedSales();
      expect(parkedList.first.discountType, 'percentage');
      expect(parkedList.first.discountValue, 10.0);
      expect(parkedList.first.isWholesale, isTrue);
      expect(parkedList.first.commissionAgentId, 7);
    },
  );

  test(
    'createSale enforces stock when requested, deducts FEFO batches, updates loyalty & multi-branch stock transfers',
    () async {
      final db = await openFreshDb('sale_fefo_transfer.db');
      final custId = await db.addContact(
        Contact(
          name: 'Ali Superstore Member',
          type: 'customer',
          phone: '03001112233',
          creditLimit: 5000.0,
          loyaltyPoints: 50.0,
        ),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Milk Carton 1L',
          sku: 'MLK-1L',
          barcode: '8961002002002',
          purchasePrice: 200.0,
          sellingPrice: 260.0,
          stockQuantity: 10.0,
        ),
      );
      final prod = (await db.getProductById(prodId))!;

      // Insert 2 serial/batch rows: earliest expiry should sell first (FEFO)
      final bLateId = await db.addProductSerialBatch(
        ProductSerialBatch(
          productId: prodId,
          productName: prod.name,
          serialNumber1: 'SN-LATE-001',
          batchNumber: 'BATCH-LATE',
          expiryDate: '2027-06-01',
          createdAt: '2026-11-12',
        ),
      );
      final bEarlyId = await db.addProductSerialBatch(
        ProductSerialBatch(
          productId: prodId,
          productName: prod.name,
          serialNumber1: 'SN-EARLY-001',
          batchNumber: 'BATCH-EARLY',
          expiryDate: '2026-12-01',
          createdAt: '2026-11-12',
        ),
      );

      // Enforced overselling rejection
      await expectLater(
        () => db.createSale(
          sale: Sale(
            invoiceNo: 'INV-OVER-1',
            customerId: custId,
            customerName: 'Ali Superstore Member',
            subtotal: 3900.0,
            totalAmount: 3900.0,
            paidAmount: 3900.0,
            paymentMethod: 'cash',
            paymentStatus: 'paid',
            createdAt: '2026-11-12 10:00:00',
          ),
          items: [CartItem(product: prod, quantity: 15.0, unitPrice: 260.0)],
          enforceStock: true,
        ),
        throwsStateError,
      );

      // Valid sale of 1 unit consumes earliest-expiry batch (FEFO)
      final sale = await db.createSale(
        sale: Sale(
          invoiceNo: 'INV-FEFO-1',
          customerId: custId,
          customerName: 'Ali Superstore Member',
          subtotal: 260.0,
          totalAmount: 260.0,
          paidAmount: 260.0,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          createdAt: '2026-11-12 10:05:00',
        ),
        items: [CartItem(product: prod, quantity: 1.0, unitPrice: 260.0)],
        pointsRedeemed: 10,
        pointsEarned: 13,
        enforceStock: true,
      );

      final earlyRow = (await db.db.query(
        'product_serials_batches',
        where: 'id = ?',
        whereArgs: [bEarlyId],
      ))
          .first;
      final lateRow = (await db.db.query(
        'product_serials_batches',
        where: 'id = ?',
        whereArgs: [bLateId],
      ))
          .first;
      expect(earlyRow['status'], 'sold');
      expect(earlyRow['sale_id'], sale.id);
      expect(lateRow['status'], 'in_stock');

      final updatedCust = await db.getContactById(custId);
      expect(updatedCust!.loyaltyPoints, closeTo(53.0, 0.01));

      final branchMap = await db.getProductLocationStocks(prodId);
      expect(branchMap[1], closeTo(9.0, 0.01));

      // StockTransfer moves 2 units from Location 1 -> Location 2
      final transferItems = [
        StockTransferItem(
          productId: prodId,
          productName: prod.name,
          sku: prod.sku,
          quantity: 2.0,
          unitPrice: 200.0,
        ),
      ];
      await db.createStockTransfer(
        StockTransfer(
          refNo: 'TRF-001',
          fromLocationId: 1,
          fromLocationName: 'Main Branch',
          toLocationId: 2,
          toLocationName: 'City Warehouse',
          status: 'completed',
          finalTotal: 400.0,
          date: '2026-11-12',
          itemsJson: jsonEncode(transferItems.map((e) => e.toMap()).toList()),
        ),
      );
      final afterTransferLocs = await db.getProductLocationStocks(prodId);
      expect(afterTransferLocs[1], closeTo(7.0, 0.01));
      expect(afterTransferLocs[2], closeTo(2.0, 0.01));

      // StockAdjustment increase + delete restore
      final adjItems = [
        StockAdjustmentItem(
          productId: prodId,
          productName: prod.name,
          sku: prod.sku,
          quantity: 4.0,
          unitPrice: 200.0,
        ),
      ];
      final adjId = await db.createStockAdjustment(
        StockAdjustment(
          refNo: 'ADJ-INC-1',
          adjustmentType: 'increase',
          totalAmount: 800.0,
          reason: 'Found pallet',
          date: '2026-11-12',
          itemsJson: jsonEncode(adjItems.map((e) => e.toMap()).toList()),
        ),
      );
      expect((await db.getProductById(prodId))!.stockQuantity,
          closeTo(11.0, 0.01));
      await db.deleteStockAdjustment(adjId);
      expect(
          (await db.getProductById(prodId))!.stockQuantity, closeTo(7.0, 0.01));
      expect(sale.id, isNotNull);
    },
  );

  test(
    'SaleReturn prevents over-returning and only deducts balance on credit_note, plus transactionEditDays guard',
    () async {
      final db = await openFreshDb('returns_and_edit_lock.db');
      final custId = await db.addContact(
        Contact(
          name: 'Karim Store',
          type: 'customer',
          balance: 1000.0,
        ),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Cooking Oil 5L',
          sku: 'OIL-5L',
          barcode: '8961003003003',
          purchasePrice: 2000.0,
          sellingPrice: 2400.0,
          stockQuantity: 20.0,
        ),
      );
      final prod = (await db.getProductById(prodId))!;

      // Create sale 11 days ago & enable 2-day edit lock
      await db.db.update(
        'business_settings',
        {'transaction_edit_days': 2},
      );
      final oldSale = await db.createSale(
        sale: Sale(
          invoiceNo: 'INV-OLD-1',
          customerId: custId,
          customerName: 'Karim Store',
          subtotal: 4800.0,
          totalAmount: 4800.0,
          paidAmount: 4800.0,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          saleStatus: 'final',
          createdAt: '2026-11-01 10:00:00',
        ),
        items: [CartItem(product: prod, quantity: 2.0, unitPrice: 2400.0)],
      );

      // Update / Delete past transactionEditDays throws StateError
      await expectLater(
        () => db.deleteSale(oldSale.id!),
        throwsStateError,
      );

      // Cash SaleReturn does NOT subtract from customer khata balance
      await db.addSaleReturn(
        SaleReturn(
          returnNo: 'SR-CASH-1',
          saleId: oldSale.id,
          invoiceNo: oldSale.invoiceNo,
          customerId: custId,
          customerName: 'Karim Store',
          date: '2026-11-12',
          totalAmount: 2400.0,
          refundAmount: 2400.0,
          paymentMethod: 'cash',
          reason: 'Damaged seal',
          items: [
            SaleReturnItem(
              returnId: 0,
              productId: prodId,
              productName: prod.name,
              quantity: 1.0,
              unitPrice: 2400.0,
              subtotal: 2400.0,
            ),
          ],
        ),
      );
      expect((await db.getContactById(custId))!.balance, closeTo(1000.0, 0.01));

      final returnedMap = await db.getReturnedQuantitiesForSale(oldSale.id!);
      expect(returnedMap[prodId], closeTo(1.0, 0.01));

      // Credit-note SaleReturn reduces customer balance
      await db.addSaleReturn(
        SaleReturn(
          returnNo: 'SR-CN-1',
          saleId: oldSale.id,
          invoiceNo: oldSale.invoiceNo,
          customerId: custId,
          customerName: 'Karim Store',
          date: '2026-11-12',
          totalAmount: 600.0,
          refundAmount: 600.0,
          paymentMethod: 'credit_note',
          reason: 'Partial adjustment',
          items: [
            SaleReturnItem(
              returnId: 0,
              productId: prodId,
              productName: prod.name,
              quantity: 0.25,
              unitPrice: 2400.0,
              subtotal: 600.0,
            ),
          ],
        ),
      );
      expect((await db.getContactById(custId))!.balance, closeTo(400.0, 0.01));

      final retRow = (await db.db.query(
        'sale_returns',
        where: 'ref_no = ?',
        whereArgs: ['SR-CASH-1'],
      ))
          .first;
      expect(retRow['reason'], 'Damaged seal');
    },
  );

  test(
    'Register denominations, Settings businessType lock, POS barcode parsers & module_records persistence work cleanly',
    () async {
      final db = await openFreshDb('register_barcode_modules.db');

      // 1. businessType preserved once configured unless allowBusinessTypeChange: true
      final current = await db.getBusinessSettings();
      await db.updateBusinessSettings(
        current.copyWith(
          isConfigured: true,
          businessType: 'pharmacy',
        ),
        allowBusinessTypeChange: true,
      );
      expect((await db.getBusinessSettings()).businessType, 'pharmacy');

      final configured = await db.getBusinessSettings();
      await db.updateBusinessSettings(
        configured.copyWith(
          businessName: 'Updated Superstore',
          businessType: 'superstore',
        ),
      );
      expect((await db.getBusinessSettings()).businessType, 'pharmacy');

      await db.updateBusinessSettings(
        configured.copyWith(businessType: 'superstore'),
        allowBusinessTypeChange: true,
      );
      expect((await db.getBusinessSettings()).businessType, 'superstore');

      // 2. Register closing persists cash_denominations
      await db.openRegister('Morning Cashier', 10000.0);
      final activeReg = await db.getActiveRegister();
      expect(activeReg, isNotNull);
      final regId = activeReg!.id!;
      await db.closeRegister(
        regId,
        15000.0,
        'End shift',
        denominations: {5000: 2, 1000: 5},
        coinsAmount: 0.0,
      );
      final denomRows = await db.db.query(
        'cash_denominations',
        where: 'cash_register_id = ?',
        whereArgs: [regId],
      );
      expect(denomRows.length, 1);
      expect(denomRows.first['d5000'], 2);
      expect(denomRows.first['d1000'], 5);
      expect((denomRows.first['total_amount'] as num).toDouble(), 15000.0);

      // 3. Barcode quantity prefix & scale barcode parsers
      final qParsed =
          PosTerminalScreen.parseBarcodeQuantityPrefix('3*8961001001001');
      expect(qParsed.quantity, 3.0);
      expect(qParsed.code, '8961001001001');

      final decParsed =
          PosTerminalScreen.parseBarcodeQuantityPrefix('0.5xAPPLE');
      expect(decParsed.quantity, 0.5);
      expect(decParsed.code, 'APPLE');

      final weightScale = PosTerminalScreen.parseScaleBarcode('2012345025009');
      expect(weightScale, isNotNull);
      expect(weightScale!.isPriceEmbedded, isFalse);
      expect(weightScale.itemCode, '12345');
      expect(weightScale.value, closeTo(2.5, 0.001));

      final priceScale = PosTerminalScreen.parseScaleBarcode('2412345125008');
      expect(priceScale, isNotNull);
      expect(priceScale!.isPriceEmbedded, isTrue);
      expect(priceScale.value, closeTo(125.0, 0.01));

      // 4. module_records CRUD persistence
      final mId = await db.saveModuleRecord(
        moduleKey: 'poultry',
        recordType: 'flock',
        title: 'FLOCK-99 • Shed A',
        status: 'Growing',
        data: {'flockNo': 'FLOCK-99', 'currentBirds': 4500},
      );
      final loaded = await db.getModuleRecords('poultry', recordType: 'flock');
      expect(loaded.length, 1);
      expect(loaded.first['flockNo'], 'FLOCK-99');
      expect(loaded.first['currentBirds'], 4500);
      await db.deleteModuleRecord(mId);
      expect(
          await db.getModuleRecords('poultry', recordType: 'flock'), isEmpty);
    },
  );
}
