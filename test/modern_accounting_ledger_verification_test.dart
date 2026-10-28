import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Modern Double-Entry Accounting & Ledger Verification Tests', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('smartpos_ledger_');
      dbPath = path.join(tempDir.path, 'test_ledger_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Customer Khata / Ledger: Invoices are Debit, Payments are Credit, Running Balances correct', () async {
      // 1. Add Customer
      final custId = await dbService.addContact(Contact(
        name: 'Haji Aslam Cloth House',
        phone: '03001234567',
        type: 'customer',
        balance: 0.0,
      ));

      // Product for sale
      final prodId = await dbService.addProduct(Product(
        name: 'Silk Fabric Premium',
        sku: 'SILK-001',
        barcode: 'SILK-001-BC',
        purchasePrice: 600.0,
        sellingPrice: 1000.0,
        stockQuantity: 50.0,
      ));
      final prod = (await dbService.getProductById(prodId))!;

      // 2. Initial Sale Invoice on partial payment: Total 15,000, Paid 5,000, Due 10,000
      final nowStr = '2026-10-25 10:00:00';
      final sale = Sale(
        invoiceNo: 'INV-TEST-001',
        customerId: custId,
        customerName: 'Haji Aslam Cloth House',
        subtotal: 15000.0,
        totalAmount: 15000.0,
        paidAmount: 5000.0,
        paymentMethod: 'cash',
        saleStatus: 'final',
        paymentStatus: 'partial',
        createdAt: nowStr,
      );

      final createdSale = await dbService.createSale(
        sale: sale,
        items: [CartItem(product: prod, quantity: 15.0, unitPrice: 1000.0)],
      );
      expect(createdSale.id, isNotNull);

      // Verify contact balance
      final custAfterSale = await dbService.getContactById(custId);
      expect(custAfterSale?.balance, 10000.0);

      // 3. Customer Ledger Query
      final ledger1 = await dbService.getContactLedger(contactId: custId, contactType: 'customer');
      final entries1 = ledger1['entries'] as List<LedgerEntry>;
      expect(entries1.length, 2); // 1. Invoice Dr 15000, 2. Counter Payment Cr 5000

      expect(entries1[0].transactionType, 'sale_invoice');
      expect(entries1[0].debit, 15000.0);
      expect(entries1[0].credit, 0.0);
      expect(entries1[0].runningBalance, 15000.0);

      expect(entries1[1].transactionType, 'customer_payment');
      expect(entries1[1].debit, 0.0);
      expect(entries1[1].credit, 5000.0);
      expect(entries1[1].runningBalance, 10000.0);

      expect(ledger1['closingBalance'], 10000.0);

      // 4. Customer makes subsequent installment payment of 6000
      await dbService.recordContactPayment(
        contactId: custId,
        amount: 6000.0,
        paymentMethod: 'bank_transfer',
        transactionType: 'customer_payment',
        accountName: 'Meezan Bank Operating',
        refNo: 'CHQ-8899',
        note: 'Partial installment payment via cheque',
      );

      final custAfterPay = await dbService.getContactById(custId);
      expect(custAfterPay?.balance, 4000.0);

      final ledger2 = await dbService.getContactLedger(contactId: custId, contactType: 'customer');
      final entries2 = ledger2['entries'] as List<LedgerEntry>;
      expect(entries2.length, 3);
      expect(entries2[2].transactionType, 'customer_payment');
      expect(entries2[2].credit, 6000.0);
      expect(entries2[2].runningBalance, 4000.0);
      expect(ledger2['closingBalance'], 4000.0);
    });

    test('2. Supplier Khata / Ledger: Purchases are Credit, Payments are Debit, Running Balances correct', () async {
      // 1. Add Supplier
      final suppId = await dbService.addContact(Contact(
        name: 'National Mills Lahore',
        phone: '03219876543',
        type: 'supplier',
        balance: 0.0,
      ));

      final prodId = await dbService.addProduct(Product(
        name: 'Raw Cotton Bale',
        sku: 'COT-001',
        barcode: 'COT-001-BC',
        purchasePrice: 1000.0,
        sellingPrice: 1500.0,
        stockQuantity: 10.0,
      ));
      final prod = (await dbService.getProductById(prodId))!;

      // 2. Record Purchase of 50,000 on partial payment of 20,000 (30,000 due)
      final purchase = Purchase(
        supplierId: suppId,
        supplierName: 'National Mills Lahore',
        refNo: 'PO-2026-101',
        totalAmount: 50000.0,
        paidAmount: 20000.0,
        status: 'received',
        paymentStatus: 'partial',
        createdAt: '2026-10-24 14:00:00',
      );

      final purchaseItems = [
        {
          'product_id': prod.id,
          'product_name': prod.name,
          'unit_cost': 1000.0,
          'quantity': 50.0,
          'subtotal': 50000.0,
        }
      ];

      final purchaseId = await dbService.createPurchase(purchase: purchase, items: purchaseItems);
      expect(purchaseId, isNonZero);

      // Verify contact balance
      final suppAfterPo = await dbService.getContactById(suppId);
      expect(suppAfterPo?.balance, 30000.0);

      final ledger = await dbService.getContactLedger(contactId: suppId, contactType: 'supplier');
      final entries = ledger['entries'] as List<LedgerEntry>;
      expect(entries.length, 2);

      // Purchase increases payable (Credit in supplier ledger)
      expect(entries[0].transactionType, 'purchase_bill');
      expect(entries[0].credit, 50000.0);
      expect(entries[0].debit, 0.0);
      expect(entries[0].runningBalance, 50000.0);

      // Paid amount reduces payable (Debit in supplier ledger)
      expect(entries[1].transactionType, 'supplier_payment');
      expect(entries[1].debit, 20000.0);
      expect(entries[1].credit, 0.0);
      expect(entries[1].runningBalance, 30000.0);
      expect(ledger['closingBalance'], 30000.0);
    });

    test('3. Payment Account Statement & Double-Entry Transfers', () async {
      // 1. Setup Bank Account and Cash Account
      final cashId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Main Cash Drawer',
        accountNumber: 'CASH-01',
        accountType: 'cash',
        openingBalance: 10000.0,
        currentBalance: 10000.0,
      ));

      final bankId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Meezan Current Account',
        accountNumber: 'PK36MEZN00112233',
        accountType: 'bank',
        openingBalance: 50000.0,
        currentBalance: 50000.0,
      ));

      // 2. Transfer 5,000 from Cash Drawer to Meezan Bank
      await dbService.transferAccountFunds(AccountTransfer(
        fromAccountId: cashId,
        fromAccountName: 'Main Cash Drawer',
        toAccountId: bankId,
        toAccountName: 'Meezan Current Account',
        amount: 5000.0,
        date: '2026-10-26 12:00:00',
        refNo: 'TRF-001',
        note: 'Daily cash deposit',
      ));

      // 3. Verify Account Balances
      final updatedAccounts = await dbService.getPaymentAccounts();
      final updatedCash = updatedAccounts.firstWhere((a) => a.id == cashId);
      final updatedBank = updatedAccounts.firstWhere((a) => a.id == bankId);

      expect(updatedCash.currentBalance, 5000.0);
      expect(updatedBank.currentBalance, 55000.0);

      // 4. Verify Passbook Statement for Bank Account
      final bankStatement = await dbService.getPaymentAccountStatement(
        accountId: bankId,
        accountName: 'Meezan Current Account',
      );

      expect(bankStatement['openingBalance'], 50000.0);
      expect(bankStatement['totalInflow'], 5000.0);
      expect(bankStatement['totalOutflow'], 0.0);
      expect(bankStatement['closingBalance'], 55000.0);
    });

    test('4. Double-Entry Journal Voucher Posting & Audit Trail', () async {
      final bankId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'HBL Operating',
        accountNumber: 'PK00HBL123',
        accountType: 'bank',
        openingBalance: 100000.0,
        currentBalance: 100000.0,
      ));

      // Post Journal Voucher: Dr Shop Rent 15,000 / Cr HBL Operating 15,000
      final jvId = await dbService.addJournalVoucher(
        narration: 'Shop monthly rent payment',
        debitAccount: 'Shop Rent & Utilities',
        creditAccount: 'HBL Operating',
        amount: 15000.0,
        refNo: 'JV-9001',
      );

      expect(jvId, greaterThan(0));

      // Check vouchers list
      final vouchers = await dbService.getJournalVouchers();
      expect(vouchers.isNotEmpty, isTrue);
      final v = vouchers.firstWhere((item) => item['voucherNo'] == 'JV-9001');
      expect(v['amount'], 15000.0);
      expect(v['debitAcc'], 'Shop Rent & Utilities');
      expect(v['creditAcc'], 'HBL Operating');

      // Check that HBL Operating balance was updated
      final accounts = await dbService.getPaymentAccounts();
      final hbl = accounts.firstWhere((a) => a.id == bankId);
      expect(hbl.currentBalance, 85000.0);
    });

    test('5. Live Trial Balance Equation: Assets = Liabilities + Equity', () async {
      final tb = await dbService.getFinancialTrialBalance();
      expect(tb.containsKey('totalAssets'), isTrue);
      expect(tb.containsKey('totalLiabilities'), isTrue);
      expect(tb.containsKey('ownerEquity'), isTrue);

      final totalAssets = tb['totalAssets'] as double;
      final totalLiab = tb['totalLiabilities'] as double;
      final ownerEq = tb['ownerEquity'] as double;

      // Accounting Fundamental Equation: Assets = Liabilities + Owner's Equity
      expect((totalAssets - (totalLiab + ownerEq)).abs(), lessThan(0.01));
    });
  });
}
