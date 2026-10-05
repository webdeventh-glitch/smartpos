import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('Phase 6: Payment Accounts, Double-Entry Fund Transfers, and Expense Logging', () async {
    final tempDir = await Directory.systemTemp.createTemp('pos_phase6_test_');
    final dbPath = '${tempDir.path}/test_phase6.db';

    final dbService = await DatabaseService.initialize(customPath: dbPath);

    // 1. Verify Seeded Payment Accounts
    final accounts = await dbService.getPaymentAccounts();
    expect(accounts.length, greaterThanOrEqualTo(2));
    final cashAccount = accounts.firstWhere((a) => a.accountType == 'cash');
    final bankAccount = accounts.firstWhere((a) => a.accountType == 'bank');

    final initialCashBal = cashAccount.currentBalance;
    final initialBankBal = bankAccount.currentBalance;

    // 2. Add New Payment Account
    final newAccId = await dbService.addPaymentAccount(PaymentAccount(
      name: 'Petty Cash Safe',
      accountNumber: 'SAFE-01',
      accountType: 'cash',
      openingBalance: 500.0,
      currentBalance: 500.0,
      note: 'Emergency back office cash',
    ));
    expect(newAccId, isNonZero);

    // 3. Perform Double-Entry Inter-Account Fund Transfer (Cash Drawer -> Bank Account)
    final trfRef = await dbService.generateNextAccountTransferRef();
    expect(trfRef.startsWith('TRF-'), isTrue);

    final transfer = AccountTransfer(
      fromAccountId: cashAccount.id!,
      fromAccountName: cashAccount.name,
      toAccountId: bankAccount.id!,
      toAccountName: bankAccount.name,
      amount: 400.0,
      date: DateTime.now().toIso8601String(),
      refNo: trfRef,
      note: 'Daily cash deposit to bank',
    );

    final transferId = await dbService.transferAccountFunds(transfer);
    expect(transferId, isNonZero);

    // 4. Verify Atomic Balance Updates
    final updatedAccounts = await dbService.getPaymentAccounts();
    final updatedCash = updatedAccounts.firstWhere((a) => a.id == cashAccount.id);
    final updatedBank = updatedAccounts.firstWhere((a) => a.id == bankAccount.id);

    expect(updatedCash.currentBalance, equals(initialCashBal - 400.0));
    expect(updatedBank.currentBalance, equals(initialBankBal + 400.0));

    // Verify transfer history
    final transferHistory = await dbService.getAccountTransfers();
    expect(transferHistory.any((t) => t.refNo == trfRef), isTrue);

    // 5. Verify Expense Logging
    final expenseId = await dbService.addExpense(Expense(
      category: 'Store Rent',
      amount: 1200.0,
      refNo: 'EXP-RENT-OCT',
      note: 'Monthly plaza shop rent',
      date: DateTime.now().toIso8601String(),
    ));
    expect(expenseId, isNonZero);

    final allExpenses = await dbService.getExpenses();
    expect(allExpenses.any((e) => e.refNo == 'EXP-RENT-OCT'), isTrue);
    expect(allExpenses.firstWhere((e) => e.refNo == 'EXP-RENT-OCT').amount, equals(1200.0));

    // Cleanup SQLite lock on Windows
    await dbService.db.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });
}
