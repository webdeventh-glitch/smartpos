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

  group('Ultimate POS Phase 4: Banking, Fund Transfers & Ledger Parity', () {
    late DatabaseService dbService;
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('banking_transfer_test_');
      dbPath = path.join(tempDir.path, 'bank_${DateTime.now().microsecondsSinceEpoch}.db');
      dbService = await DatabaseService.initialize(customPath: dbPath);
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Inter-Account Fund Transfer: Atomically debits source and credits destination', () async {
      // 1. Create Counter Cash Account (Opening 50,000)
      final cashAccId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Main Counter Cash',
        accountType: 'cash',
        accountNumber: 'CASH-01',
        openingBalance: 50000.0,
        currentBalance: 50000.0,
      ));

      // 2. Create Bank Account (Opening 100,000)
      final bankAccId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Meezan Bank Current A/C',
        accountType: 'bank',
        accountNumber: 'PK99MEZN0012345678',
        openingBalance: 100000.0,
        currentBalance: 100000.0,
      ));

      // 3. Transfer 20,000 from Cash to Bank (Cash Deposit)
      final transfer = AccountTransfer(
        fromAccountId: cashAccId,
        fromAccountName: 'Main Counter Cash',
        toAccountId: bankAccId,
        toAccountName: 'Meezan Bank Current A/C',
        amount: 20000.0,
        date: DateTime.now().toIso8601String(),
        refNo: 'TRF-TEST-001',
        note: 'End of day counter cash deposit to bank',
      );

      final trfId = await dbService.transferAccountFunds(transfer);
      expect(trfId, isPositive);

      // Verify source cash account balance = 50,000 - 20,000 = 30,000.0
      final cashAfter = (await dbService.getPaymentAccounts()).firstWhere((a) => a.id == cashAccId);
      expect(cashAfter.currentBalance, 30000.0);

      // Verify destination bank account balance = 100,000 + 20,000 = 120,000.0
      final bankAfter = (await dbService.getPaymentAccounts()).firstWhere((a) => a.id == bankAccId);
      expect(bankAfter.currentBalance, 120000.0);

      // Verify transfer recorded in history
      final history = await dbService.getAccountTransfers();
      expect(history.any((t) => t.refNo == 'TRF-TEST-001' && t.amount == 20000.0), isTrue);
    });

    test('2. Delete / Reverse Fund Transfer: Restores balances to both accounts', () async {
      final accAId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Account A',
        accountType: 'bank',
        currentBalance: 15000.0,
      ));
      final accBId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Account B',
        accountType: 'bank',
        currentBalance: 5000.0,
      ));

      final transfer = AccountTransfer(
        fromAccountId: accAId,
        fromAccountName: 'Account A',
        toAccountId: accBId,
        toAccountName: 'Account B',
        amount: 5000.0,
        date: DateTime.now().toIso8601String(),
        refNo: 'TRF-REV-001',
      );

      final trfId = await dbService.transferAccountFunds(transfer);

      // Before delete: A = 10,000, B = 10,000
      expect((await dbService.getPaymentAccounts()).firstWhere((a) => a.id == accAId).currentBalance, 10000.0);
      expect((await dbService.getPaymentAccounts()).firstWhere((a) => a.id == accBId).currentBalance, 10000.0);

      // Delete transfer
      final ok = await dbService.deleteAccountTransfer(trfId);
      expect(ok, isTrue);

      // After delete: A restored to 15,000, B restored to 5,000
      expect((await dbService.getPaymentAccounts()).firstWhere((a) => a.id == accAId).currentBalance, 15000.0);
      expect((await dbService.getPaymentAccounts()).firstWhere((a) => a.id == accBId).currentBalance, 5000.0);
    });

    test('3. Direct Account Deposit: Increments balance and creates deposit transaction', () async {
      final bankId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'HBL Business Account',
        accountType: 'bank',
        openingBalance: 50000.0,
        currentBalance: 50000.0,
      ));

      // Deposit 25,000 capital injection
      await dbService.depositToAccount(
        accountId: bankId,
        amount: 25000.0,
        note: 'Director Capital Injection',
        paymentMethod: 'bank_transfer',
      );

      // Verify balance is now 75,000.0
      final acc = (await dbService.getPaymentAccounts()).firstWhere((a) => a.id == bankId);
      expect(acc.currentBalance, 75000.0);

      // Verify statement reflects deposit
      final statement = await dbService.getPaymentAccountStatement(
        accountId: bankId,
        accountName: 'HBL Business Account',
      );
      expect(statement['closingBalance'], 75000.0);
    });

    test('4. Account Passbook / Statement: Accurately tracks Transfers In and Transfers Out', () async {
      final cashId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Counter Safe',
        accountType: 'cash',
        openingBalance: 10000.0,
        currentBalance: 10000.0,
      ));
      final bankId = await dbService.addPaymentAccount(PaymentAccount(
        name: 'Allied Bank',
        accountType: 'bank',
        openingBalance: 20000.0,
        currentBalance: 20000.0,
      ));

      // Transfer 4,000 from Cash to Bank
      await dbService.transferAccountFunds(AccountTransfer(
        fromAccountId: cashId,
        fromAccountName: 'Counter Safe',
        toAccountId: bankId,
        toAccountName: 'Allied Bank',
        amount: 4000.0,
        date: DateTime.now().toIso8601String(),
        refNo: 'TRF-STMT-01',
      ));

      // Cash Statement: Outflow 4,000, Closing 6,000
      final cashStmt = await dbService.getPaymentAccountStatement(accountId: cashId, accountName: 'Counter Safe');
      expect(cashStmt['totalOutflow'], 4000.0);
      expect(cashStmt['closingBalance'], 6000.0);

      // Bank Statement: Inflow 4,000, Closing 24,000
      final bankStmt = await dbService.getPaymentAccountStatement(accountId: bankId, accountName: 'Allied Bank');
      expect(bankStmt['totalInflow'], 4000.0);
      expect(bankStmt['closingBalance'], 24000.0);
    });
  });
}
