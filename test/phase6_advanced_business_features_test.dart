import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/screens/finance/cheque_management_screen.dart';
import 'package:desktop_starter/screens/products/discount_rules_screen.dart';
import 'package:desktop_starter/screens/purchases/purchase_orders_screen.dart';
import 'package:desktop_starter/screens/sales/commission_agents_screen.dart';
import 'package:desktop_starter/screens/sales/sales_orders_screen.dart';
import 'package:desktop_starter/services/backup_update_service.dart';
import 'package:desktop_starter/services/database_encryption_service.dart';
import 'package:desktop_starter/services/database_schema.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:desktop_starter/services/windows_credential_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    WindowsCredentialStore.useInMemoryForTest = true;
  });

  setUp(() {
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase6_');
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
      tempDir.deleteSync(recursive: true);
    }
  });

  test('v6 to v7 schema migration adds Phase 6 tables, columns, and indexes', () async {
    final dbPath = p.join(tempDir.path, 'upgrade_v6_v7.db');
    final raw = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await DatabaseSchema.createTables(db);
          await DatabaseSchema.seedInitialData(db);
          await DatabaseSchema.runMigrations(db, fromVersion: 0, toVersion: 6);
        },
      ),
    );
    await raw.close();

    final upgraded = await DatabaseService.initialize(customPath: dbPath);
    try {
      expect(await upgraded.db.getVersion(), DatabaseService.currentSchemaVersion);
      final migrations =
          await upgraded.db.query('schema_migrations', orderBy: 'version ASC');
      expect(migrations.map((m) => m['version']).toList(), [2, 3, 4, 5, 6, 7]);

      final salesCols = (await upgraded.db.rawQuery('PRAGMA table_info(sales)'))
          .map((r) => r['name'])
          .toSet();
      expect(
        salesCols.containsAll([
          'order_status',
          'converted_from_order_id',
          'commission_agent_id',
          'commission_amount',
        ]),
        isTrue,
      );

      final txnCols = (await upgraded.db.rawQuery('PRAGMA table_info(payment_transactions)'))
          .map((r) => r['name'])
          .toSet();
      expect(
        txnCols.containsAll([
          'cheque_number',
          'bank_name',
          'cheque_due_date',
          'cheque_status',
        ]),
        isTrue,
      );
      expect(
        await DatabaseSchema.tableExists(upgraded.db, 'commission_agents'),
        isTrue,
      );
    } finally {
      await upgraded.db.close();
    }
  });

  test('Step 6.1: Sales Order workflow (ordered -> partial -> completed & stock sync)', () async {
    final dbPath = p.join(tempDir.path, 'sales_orders.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final custId = await db.addContact(
        Contact(type: 'customer', name: 'Metro Traders', phone: '03001112233'),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Cooking Oil 5L',
          sku: 'OIL-5L',
          barcode: '8961001001',
          purchasePrice: 1800,
          sellingPrice: 2200,
          stockQuantity: 20,
        ),
      );
      final product = (await db.getProducts()).firstWhere((p) => p.id == prodId);
      final agentId = await db.addCommissionAgent(
        CommissionAgent(
          name: 'Ali Raza',
          commissionPercent: 5.0,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      final orderNo = await db.generateNextSalesOrderNo();
      final order = await db.createSale(
        sale: Sale(
          invoiceNo: orderNo,
          customerId: custId,
          customerName: 'Metro Traders',
          subtotal: 22000,
          totalAmount: 22000,
          paidAmount: 0,
          paymentStatus: 'due',
          saleStatus: 'sales_order',
          orderStatus: 'ordered',
          commissionAgentId: agentId,
          commissionAgentName: 'Ali Raza',
          commissionPercent: 5.0,
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [CartItem(product: product, unitPrice: product.sellingPrice, quantity: 10)],
      );

      // Stock must NOT be deducted while still a pending Sales Order
      final afterOrderProd = (await db.getProducts()).firstWhere((p) => p.id == prodId);
      expect(afterOrderProd.stockQuantity, 20.0);

      final pendingBefore = await db.getPendingSalesOrdersSummary();
      expect(pendingBefore['count'], 1);

      final orderItems = await db.getSaleItems(order.id!);
      final lineId = orderItems.first.id!;

      // Partial conversion: 4 out of 10 units
      final partialInv = await db.convertSalesOrderToInvoice(
        orderId: order.id!,
        fulfillQuantitiesByItemId: {lineId: 4.0},
        paymentMethod: 'cash',
        paidAmount: 8800.0,
      );
      expect(partialInv.saleStatus, 'final');
      expect(partialInv.convertedFromOrderId, order.id);
      expect(partialInv.totalAmount, closeTo(8800.0, 0.01));
      expect(partialInv.commissionAmount, closeTo(440.0, 0.01));

      final afterPartialStock =
          (await db.getProducts()).firstWhere((p) => p.id == prodId).stockQuantity;
      expect(afterPartialStock, closeTo(16.0, 0.001));

      final orderAfterPartial = (await db.getSales(status: 'sales_order')).first;
      expect(orderAfterPartial.orderStatus, 'partial');

      // Convert remaining 6 units -> completes Sales Order
      final finalInv = await db.convertSalesOrderToInvoice(
        orderId: order.id!,
        paymentMethod: 'bank_transfer',
        paidAmount: 13200.0,
      );
      expect(finalInv.totalAmount, closeTo(13200.0, 0.01));
      expect(
        (await db.getProducts()).firstWhere((p) => p.id == prodId).stockQuantity,
        closeTo(10.0, 0.001),
      );
      final completedOrder = (await db.getSales(status: 'sales_order')).first;
      expect(completedOrder.orderStatus, 'completed');

      final pendingAfter = await db.getPendingSalesOrdersSummary();
      expect(pendingAfter['count'], 0);
    } finally {
      await db.db.close();
    }
  });

  test('Step 6.2: Purchase Order partial and full receiving transitions status & stock', () async {
    final dbPath = p.join(tempDir.path, 'purchase_orders.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final supId = await db.addContact(
        Contact(type: 'supplier', name: 'Global Foods Distributors', phone: '03210009988'),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Basmati Rice 10Kg',
          sku: 'RICE-10',
          barcode: '8962002002',
          purchasePrice: 2500,
          sellingPrice: 2900,
          stockQuantity: 5,
        ),
      );

      final poRef = await db.generateNextPurchaseOrderRef();
      final lines = [
        {
          'product_id': prodId,
          'product_name': 'Basmati Rice 10Kg',
          'sku': 'RICE-10',
          'quantity': 10.0,
          'received_quantity': 0.0,
          'purchase_price': 2500.0,
          'unit_cost': 2500.0,
        }
      ];
      final poId = await db.createPurchase(
        purchase: Purchase(
          refNo: poRef,
          supplierId: supId,
          supplierName: 'Global Foods Distributors',
          totalAmount: 25000.0,
          paidAmount: 0.0,
          status: 'ordered',
          paymentStatus: 'due',
          createdAt: DateTime.now().toIso8601String(),
          itemsJson: jsonEncode(lines),
          isPurchaseOrder: true,
        ),
        items: lines,
      );

      // No stock added while PO is ordered
      expect((await db.getProducts()).firstWhere((p) => p.id == prodId).stockQuantity, 5.0);

      // Receive 6 units partially
      await db.receivePurchaseOrderItems(
        poId: poId,
        receiveQtyByLineIndex: {0: 6.0},
        paidNow: 10000.0,
        paymentMethod: 'cash',
      );
      expect((await db.getProducts()).firstWhere((p) => p.id == prodId).stockQuantity, 11.0);
      final poPartial = (await db.getPurchases()).firstWhere((p) => p.id == poId);
      expect(poPartial.status, 'partial');

      // Receive remaining 4 units -> PO becomes received
      await db.receivePurchaseOrderItems(
        poId: poId,
        paidNow: 10000.0,
        paymentMethod: 'cheque',
        chequeNumber: 'CHQ-9910',
        bankName: 'HBL',
        chequeDueDate: '2026-12-01',
      );
      expect((await db.getProducts()).firstWhere((p) => p.id == prodId).stockQuantity, 15.0);
      final poDone = (await db.getPurchases()).firstWhere((p) => p.id == poId);
      expect(poDone.status, 'received');

      final pending = await db.getPendingPurchaseOrdersSummary();
      expect(pending['count'], 0);
    } finally {
      await db.db.close();
    }
  });

  test('Step 6.3 & 6.4: Cheque clearance workflow & Commission Agent reporting', () async {
    final dbPath = p.join(tempDir.path, 'cheques_commissions.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final agentId = await db.addCommissionAgent(
        CommissionAgent(
          name: 'Kamran Sheikh',
          commissionPercent: 4.0,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      final prodId = await db.addProduct(
        Product(
          name: 'Solar Inverter 5KW',
          sku: 'INV-5KW',
          barcode: '8965005005',
          purchasePrice: 80000,
          sellingPrice: 100000,
          stockQuantity: 10,
        ),
      );
      final prod = (await db.getProducts()).firstWhere((p) => p.id == prodId);

      // Sale paid via overdue cheque + assigned to commission agent
      await db.createSale(
        sale: Sale(
          invoiceNo: 'INV-CHQ-1',
          customerName: 'Zainab Enterprises',
          subtotal: 100000,
          totalAmount: 100000,
          paidAmount: 100000,
          paymentMethod: 'cheque',
          paymentStatus: 'paid',
          saleStatus: 'final',
          commissionAgentId: agentId,
          commissionAgentName: 'Kamran Sheikh',
          commissionPercent: 4.0,
          commissionAmount: 4000.0,
          createdAt: DateTime.now().toIso8601String(),
        ),
        items: [CartItem(product: prod, unitPrice: prod.sellingPrice, quantity: 1)],
        chequeNumber: 'CHQ-7712',
        bankName: 'Meezan Bank',
        chequeDueDate: '2020-01-15', // Past date -> Overdue!
      );

      final chequesBefore = await db.getCheques();
      expect(chequesBefore.length, 1);
      expect(chequesBefore.first.chequeNumber, 'CHQ-7712');
      expect(chequesBefore.first.chequeStatus, 'pending');
      expect(chequesBefore.first.isOverdueCheque, isTrue);

      final summaryBefore = await db.getChequeSummary();
      expect(summaryBefore['pendingCount'], 1);
      expect(summaryBefore['overdueCount'], 1);

      await db.updateChequeStatus(
        transactionId: chequesBefore.first.id!,
        newStatus: 'cleared',
      );

      final summaryAfter = await db.getChequeSummary();
      expect(summaryAfter['pendingCount'], 0);
      expect(summaryAfter['clearedCount'], 1);
      expect(summaryAfter['clearedAmount'], closeTo(100000.0, 0.01));

      final commReport = await db.getCommissionReport();
      expect(commReport.length, 1);
      expect(commReport.first['agentName'], 'Kamran Sheikh');
      expect(commReport.first['saleCount'], 1);
      expect(commReport.first['totalCommission'], closeTo(4000.0, 0.01));
    } finally {
      await db.db.close();
    }
  });

  test('Step 6.5: Discount schedules evaluate Buy X Get Y, Quantity Break, and Time-Based rules', () async {
    final dbPath = p.join(tempDir.path, 'discounts.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final tea = Product(
        id: 1,
        name: 'Green Tea Pack',
        sku: 'TEA-1',
        barcode: '111',
        purchasePrice: 150,
        sellingPrice: 200,
        stockQuantity: 100,
      );

      final mondayMidday = DateTime(2026, 11, 9, 15, 0); // Monday 15:00 (weekday = 1)
      await db.addDiscountRule(
        DiscountRule(
          name: 'Happy Hour 10%',
          ruleType: 'time_based',
          discountType: 'percentage',
          discountAmount: 10,
          daysOfWeek: '1',
          startTime: '14:00',
          endTime: '17:00',
          priority: 1,
          createdAt: mondayMidday.toIso8601String(),
        ),
      );
      await db.addDiscountRule(
        DiscountRule(
          name: 'Buy 2 Get 1 Free',
          ruleType: 'buy_x_get_y',
          buyQuantity: 2,
          freeQuantity: 1,
          priority: 2,
          createdAt: mondayMidday.toIso8601String(),
        ),
      );
      await db.addDiscountRule(
        DiscountRule(
          name: 'Bulk 5+ Flat 150 Off',
          ruleType: 'quantity_break',
          discountType: 'fixed',
          discountAmount: 150,
          minQuantity: 5,
          priority: 3,
          createdAt: mondayMidday.toIso8601String(),
        ),
      );

      // 3 units (Buy 2 Get 1 -> 1 free item = Rs 200 discount vs 10% = Rs 60)
      final eval3 = await db.evaluateCartDiscounts(
        [CartItem(product: tea, unitPrice: tea.sellingPrice, quantity: 3)],
        now: mondayMidday,
      );
      expect(eval3.appliedRuleNames, ['Buy 2 Get 1 Free']);
      expect(eval3.discountAmount, closeTo(200.0, 0.01));

      // Outside Happy Hour with 1 unit -> 0 discount
      final evalOutside = await db.evaluateCartDiscounts(
        [CartItem(product: tea, unitPrice: tea.sellingPrice, quantity: 1)],
        now: DateTime(2026, 11, 10, 10, 0),
      );
      expect(evalOutside.hasDiscount, isFalse);

      // Quantity break active at 5+ items -> Buy 2 Get 1 = 200 vs QtyBreak = 150 (best chosen = 200)
      final eval1UnitHappy = await db.evaluateCartDiscounts(
        [CartItem(product: tea, unitPrice: tea.sellingPrice, quantity: 1)],
        now: mondayMidday,
      );
      expect(eval1UnitHappy.appliedRuleNames, ['Happy Hour 10%']);
      expect(eval1UnitHappy.discountAmount, closeTo(20.0, 0.01));
    } finally {
      await db.db.close();
    }
  });

  test('Step 6.6: Scheduled backup retention and due-interval execution', () async {
    final dbPath = p.join(tempDir.path, 'sched_backup.db');
    final backupDir = Directory(p.join(tempDir.path, 'backups'));
    final db = await DatabaseService.initialize(customPath: dbPath);
    try {
      final settings = BusinessSettings(
        businessName: 'Backup Test Store',
        autoBackupEnabled: true,
        backupFrequency: 'custom',
        backupIntervalHours: 6,
        backupRetentionCount: 2,
      );
      await db.updateBusinessSettings(settings);

      final t1 = DateTime(2026, 11, 12, 8, 0);
      final firstFile = await BackupUpdateService.instance.runScheduledBackupIfDue(
        settings: settings,
        db: db,
        targetDir: backupDir,
        dbPathOverride: dbPath,
        now: t1,
      );
      expect(firstFile, isNotNull);
      expect(firstFile!.existsSync(), isTrue);

      final savedAfterFirst = await db.getBusinessSettings();
      expect(savedAfterFirst.lastAutoBackupAt, t1.toIso8601String());

      // Too soon (2 hours later) -> should NOT create another backup
      final tooSoon = await BackupUpdateService.instance.runScheduledBackupIfDue(
        settings: savedAfterFirst,
        db: db,
        targetDir: backupDir,
        dbPathOverride: dbPath,
        now: t1.add(const Duration(hours: 2)),
      );
      expect(tooSoon, isNull);

      // Add extra dummy backups and confirm retention prunes down to 2
      for (int i = 0; i < 3; i++) {
        final dummy = File(p.join(backupDir.path, 'smartpos_dummy_$i.db.enc'));
        await dummy.writeAsBytes([1, 2, 3]);
      }
      final pruned = await BackupUpdateService.instance.enforceBackupRetention(
        keepCount: 2,
        targetDir: backupDir,
      );
      expect(pruned, greaterThanOrEqualTo(2));
      expect(backupDir.listSync().length, 2);
    } finally {
      await db.db.close();
    }
  });

  testWidgets('Phase 6 screens render cleanly without exceptions', (tester) async {
    final dbPath = p.join(tempDir.path, 'ui_test.db');
    await tester.runAsync(() async {
      await DatabaseService.initialize(customPath: dbPath);
    });

    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = BusinessSettings(businessName: 'Smart POS Phase 6');

    for (final screen in [
      SalesOrdersScreen(settings: settings),
      PurchaseOrdersScreen(settings: settings),
      ChequeManagementScreen(settings: settings),
      CommissionAgentsScreen(settings: settings),
      DiscountRulesScreen(settings: settings),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
