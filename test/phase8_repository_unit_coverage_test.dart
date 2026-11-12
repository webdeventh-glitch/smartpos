import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/repositories/accounting_repository.dart';
import 'package:desktop_starter/repositories/expense_repository.dart';
import 'package:desktop_starter/repositories/industry_modules_repository.dart';
import 'package:desktop_starter/repositories/inventory_repository.dart';
import 'package:desktop_starter/repositories/register_repository.dart';
import 'package:desktop_starter/repositories/settings_repository.dart';
import 'package:desktop_starter/repositories/sync_repository.dart';
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
    WindowsCredentialStore.clearTestStore();
    DatabaseEncryptionService.clearKeyCache();
    tempDir = Directory.systemTemp.createTempSync('smartpos_phase8_repos_');
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

  test('ExpenseRepository & RegisterRepository lifecycle + cash deduction',
      () async {
    final dbPath = p.join(tempDir.path, 'expense_register.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    final registerRepo = RegisterRepository(db);
    final expenseRepo = ExpenseRepository(db);

    try {
      await registerRepo.openRegister('Cashier One', 5000.0);
      final active = await registerRepo.getActiveRegister();
      expect(active, isNotNull);
      expect(active!.openingAmount, 5000.0);

      final expId = await expenseRepo.addExpense(
        Expense(
          category: 'Utilities',
          amount: 750.0,
          refNo: 'EXP-2026-001',
          date: '2026-11-12',
          paymentMethod: 'cash',
          note: 'Electricity Bill',
        ),
      );
      expect(expId, greaterThan(0));

      final expenses = await expenseRepo.getExpenses();
      expect(
          expenses.any((e) => e.refNo == 'EXP-2026-001' && e.amount == 750.0),
          isTrue);

      final afterExp = await registerRepo.getActiveRegister();
      expect(afterExp!.totalSalesCash, closeTo(-750.0, 0.01));

      await registerRepo.closeRegister(afterExp.id!, 4250.0, 'End of Shift');
      expect(await registerRepo.getActiveRegister(), isNull);

      final shiftReport =
          await registerRepo.getRegisterReport(status: 'closed');
      expect(shiftReport, isNotEmpty);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'AccountingRepository covers accounts, deposits, transfers, JVs, trial balance & closing',
      () async {
    final dbPath = p.join(tempDir.path, 'accounting.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    final accRepo = AccountingRepository(db);

    try {
      final acc1Id = await accRepo.addPaymentAccount(
        PaymentAccount(
          name: 'Cash Drawer Main',
          accountType: 'cash',
          openingBalance: 10000.0,
          currentBalance: 10000.0,
        ),
      );
      final acc2Id = await accRepo.addPaymentAccount(
        PaymentAccount(
          name: 'HBL Current',
          accountType: 'bank',
          openingBalance: 2000.0,
          currentBalance: 2000.0,
        ),
      );

      await accRepo.depositToAccount(
        accountId: acc1Id,
        amount: 2500.0,
        note: 'Opening topup',
      );

      final ref = await accRepo.generateNextAccountTransferRef();
      expect(ref, startsWith('TRF-'));
      final transferId = await accRepo.transferAccountFunds(
        AccountTransfer(
          fromAccountId: acc1Id,
          fromAccountName: 'Cash Drawer Main',
          toAccountId: acc2Id,
          toAccountName: 'HBL Current',
          amount: 4000.0,
          date: '2026-11-12',
          refNo: ref,
          note: 'Bank deposit',
        ),
      );
      expect(transferId, greaterThan(0));
      expect((await accRepo.getAccountTransfers()).length, 1);

      var accounts = await accRepo.getPaymentAccounts();
      final drawer = accounts.firstWhere((a) => a.id == acc1Id);
      final bank = accounts.firstWhere((a) => a.id == acc2Id);
      expect(drawer.currentBalance, closeTo(8500.0, 0.01));
      expect(bank.currentBalance, closeTo(6000.0, 0.01));

      final reversed = await accRepo.deleteAccountTransfer(transferId);
      expect(reversed, isTrue);

      await accRepo.addJournalVoucher(
        narration: 'Petty cash adjustment',
        debitAccount: 'HBL Current',
        creditAccount: 'Cash Drawer Main',
        amount: 500.0,
        refNo: 'JV-8001',
      );
      final jvs = await accRepo.getJournalVouchers();
      expect(jvs.any((j) => j['voucherNo'] == 'JV-8001'), isTrue);

      final stmt = await accRepo.getPaymentAccountStatement(
        accountId: acc1Id,
        accountName: 'Cash Drawer Main',
      );
      expect(stmt['entries'], isNotNull);

      final trial = await accRepo.getFinancialTrialBalance();
      expect(trial.containsKey('ownerEquity'), isTrue);

      final custId = await db.addContact(
        Contact(
          name: 'Ledger Client',
          type: 'customer',
          phone: '03001112233',
          balance: 1500.0,
        ),
      );
      await db.contactsRepo.addContactPayment(
        ContactPayment(
          contactId: custId,
          contactName: 'Ledger Client',
          paymentType: 'receive',
          amount: 500.0,
          paymentMethod: 'cash',
          date: '2026-11-12',
          refNo: 'CP-01',
        ),
      );
      final ledger = await accRepo.getContactLedger(
        contactId: custId,
        contactType: 'customer',
      );
      expect(ledger['contact'], isNotNull);
      expect((ledger['totalCredit'] as num).toDouble(), closeTo(500.0, 0.01));

      final fyId = await accRepo.closeFinancialYear(
        FinancialYear(
          yearTitle: 'FY 2025-2026',
          startDate: '2025-07-01',
          endDate: '2026-06-30',
          closingDate: '2026-06-30',
          totalSales: 500000,
          totalPurchases: 300000,
          totalExpenses: 40000,
          netProfit: 160000,
          stockValuation: 120000,
          receivables: 15000,
          payables: 8000,
          closedBy: 'Owner',
        ),
      );
      expect(fyId, greaterThan(0));
      expect((await accRepo.getFinancialYears()).length, 1);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'IndustryModulesRepository manages restaurant tables/KOT, gym, hotel & repair jobs',
      () async {
    final dbPath = p.join(tempDir.path, 'industry_modules.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    final modRepo = IndustryModulesRepository(db);

    try {
      final tId = await modRepo.addRestaurantTable({
        'name': 'T-10',
        'capacity': 4,
        'status': 'free',
        'section': 'Main Hall',
        'order_total': 0.0,
      });
      await modRepo.updateRestaurantTableStatus(tId, 'occupied',
          orderTotal: 2200.0);
      var tables = await modRepo.getRestaurantTables(section: 'Main Hall');
      expect(
          tables.any((t) => t['name'] == 'T-10' && t['status'] == 'occupied'),
          isTrue);
      await modRepo.updateRestaurantTable(tId, {'capacity': 6});
      await modRepo.deleteRestaurantTable(tId);

      final kotId = await modRepo.addRestaurantKotOrder({
        'kot_no': 'KOT-88',
        'table_name': 'T-10',
        'server_name': 'Ali',
        'items': '[]',
        'status': 'pending',
        'items_json': '[]',
        'created_at': '2026-11-12T13:00:00',
      });
      await modRepo.updateRestaurantKotStatus(kotId, 'served');
      expect(
          (await modRepo.getRestaurantKotOrders()).first['status'], 'served');
      await modRepo.deleteRestaurantKotOrder(kotId);

      final gymId = await modRepo.addGymMember({
        'name': 'Bilal',
        'phone': '03011234567',
        'plan': 'Gold',
        'fee': 3500.0,
        'expiry_date': '2027-01-01',
        'status': 'Active',
      });
      await modRepo.updateGymMember(gymId, {'plan': 'Platinum'});
      expect((await modRepo.getGymMembers(status: 'Active')).length,
          greaterThanOrEqualTo(1));
      await modRepo.deleteGymMember(gymId);

      final roomId = await modRepo.addHotelRoom({
        'room': '301',
        'type': 'Deluxe',
        'rate': 12000.0,
        'guest': 'Guest A',
        'status': 'occupied',
      });
      await modRepo.updateHotelRoom(roomId, {'status': 'available'});
      expect((await modRepo.getHotelRooms(status: 'available')).isNotEmpty,
          isTrue);
      await modRepo.deleteHotelRoom(roomId);

      final jobId = await modRepo.addRepairJob({
        'job_no': 'JOB-901',
        'customer': 'Sana',
        'device': 'iPhone 15',
        'issue': 'Battery',
        'status': 'In Progress',
        'estimated_cost': 8500.0,
      });
      await modRepo.updateRepairJob(jobId, {'status': 'Completed'});
      expect((await modRepo.getRepairJobs(status: 'Completed')).length, 1);
      await modRepo.deleteRepairJob(jobId);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });

  test(
      'InventoryRepository, SyncRepository & SettingsRepository CRUD completeness',
      () async {
    final dbPath = p.join(tempDir.path, 'inv_sync_settings.db');
    final db = await DatabaseService.initialize(customPath: dbPath);
    final invRepo = InventoryRepository(db);
    final syncRepo = SyncRepository(db);
    final settingsRepo = SettingsRepository(db);

    try {
      final prodId = await db.addProduct(
        Product(
          name: 'Solar Inverter 5kW',
          sku: 'INV-5K',
          barcode: '555666777888',
          purchasePrice: 90000,
          sellingPrice: 115000,
          stockQuantity: 10,
        ),
      );
      final compId = await db.addProduct(
        Product(
          name: 'Battery Cable Set',
          sku: 'CBL-01',
          barcode: '555666777999',
          purchasePrice: 2000,
          sellingPrice: 3000,
          stockQuantity: 30,
        ),
      );

      final adjRef = await invRepo.generateNextAdjustmentRef();
      final adjId = await invRepo.createStockAdjustment(
        StockAdjustment(
          refNo: adjRef,
          adjustmentType: 'abnormal',
          totalAmount: 90000,
          recoveredAmount: 10000,
          reason: 'Damaged in transit',
          date: '2026-11-12',
          itemsJson: jsonEncode([
            {
              'product_id': prodId,
              'product_name': 'Solar Inverter 5kW',
              'sku': 'INV-5K',
              'quantity': 2.0,
              'unit_price': 90000.0,
            }
          ]),
        ),
      );
      expect(adjId, greaterThan(0));
      expect((await invRepo.getStockAdjustments()).length, 1);
      expect(
          (await db.getProductById(prodId))!.stockQuantity, closeTo(8.0, 0.01));
      await invRepo.deleteStockAdjustment(adjId);

      final sbId = await invRepo.addProductSerialBatch(
        ProductSerialBatch(
          productId: prodId,
          productName: 'Solar Inverter 5kW',
          sku: 'INV-5K',
          serialNumber1: 'SN-5K-9901',
          expiryDate: '2030-12-31',
          status: 'in_stock',
          createdAt: '2026-11-12',
        ),
      );
      expect((await invRepo.getProductSerialByImei('SN-5K-9901'))!.id, sbId);
      await invRepo.updateProductSerialStatus(sbId, 'sold');
      expect((await invRepo.getActiveBatchesForProduct(prodId)), isEmpty);
      await invRepo.deleteProductSerialBatch(sbId);

      await invRepo.saveBundleItems(prodId, [
        ProductBundleItem(
          parentProductId: prodId,
          subProductId: compId,
          subProductName: 'Battery Cable Set',
          subSku: 'CBL-01',
          quantity: 2,
          unitPrice: 3000,
        ),
      ]);
      final bundle = await invRepo.getBundleItems(prodId);
      expect(bundle.length, 1);
      await invRepo.deleteBundleItem(bundle.first.id!);

      // SyncRepository outbox lifecycle
      final qId1 = await syncRepo.queueSyncItem(
        entityType: 'product',
        entityId: '$prodId',
        action: 'update',
        payload: {'stock': 8},
      );
      final qId2 = await syncRepo.queueSyncItem(
        entityType: 'product',
        entityId: '$compId',
        action: 'update',
        payload: {'stock': 30},
      );
      expect(await syncRepo.getPendingSyncCount(), greaterThanOrEqualTo(2));
      final pending = await syncRepo.getPendingSyncItems(limit: 10);
      expect(pending.any((r) => r['id'] == qId1), isTrue);

      await syncRepo.markSyncItemsDone([qId1]);
      await syncRepo.markSyncItemFailed(qId2, 'Timeout');
      final logs = await syncRepo.getRecentSyncLogs(limit: 20);
      expect(
          logs.any((l) => l['id'] == qId2 && l['status'] == 'failed'), isTrue);
      await syncRepo.clearCompletedSyncLogs();

      // SettingsRepository AI / SMS / TaxGroups / InvoiceNumber
      await settingsRepo.saveAiSettings(
        AiSettings(
          provider: 'gemini',
          apiKey: 'secret-test-key',
          isEnabled: true,
        ),
      );
      final ai = await settingsRepo.getAiSettings();
      expect(ai.isEnabled, isTrue);
      expect(ai.apiKey, 'secret-test-key');

      final gwId = await settingsRepo.addSmsGateway(
        SmsGateway(
          name: 'TestSMS',
          provider: 'generic_http',
          apiUrl: 'https://example.test/send',
          apiKey: 'gw-key',
          apiSecret: 'gw-secret',
          senderId: 'SMARTPOS',
          isActive: true,
          createdAt: '2026-11-12',
        ),
      );
      expect(await settingsRepo.getActiveSmsGateway(), isNotNull);
      expect((await settingsRepo.getSmsGateways()).any((g) => g.id == gwId),
          isTrue);
      await settingsRepo.deleteSmsGateway(gwId);

      await settingsRepo.addMessageLog(
        MessageLog(
          recipientName: 'Test Customer',
          phoneNumber: '03001112233',
          channel: 'whatsapp',
          messageBody: 'Hello!',
          status: 'sent',
          gatewayName: 'Local',
          createdAt: '2026-11-12',
        ),
      );
      expect((await settingsRepo.getMessageLogs()).isNotEmpty, isTrue);

      final trId = await settingsRepo.addTaxRate(
        TaxRate(name: 'GST 18%', amount: 18.0),
      );
      final tgId = await settingsRepo.addTaxGroup(
        TaxGroup(
            name: 'Standard Combo', subTaxIds: [trId], effectiveRate: 18.0),
      );
      expect(
          (await settingsRepo.getTaxGroups()).any((g) => g.id == tgId), isTrue);
      await settingsRepo.deleteTaxGroup(tgId);
      await settingsRepo.deleteTaxRate(trId);

      final invNo = await settingsRepo.generateNextInvoiceNumber();
      expect(invNo, isNotEmpty);
    } finally {
      await DatabaseService.closeOpenInstanceIfPathMatches(dbPath);
    }
  });
}
