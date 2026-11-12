import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_logger.dart';
import 'base_repository.dart';

/// Manages double-entry ledgers, payment accounts, fund transfers, journal vouchers, trial balance, and fiscal closing.
class AccountingRepository extends BaseRepository {
  const AccountingRepository([super.dbService]);

  // ===================== MODERN ACCOUNTING & DOUBLE-ENTRY LEDGERS =====================

  /// Retrieves a unified double-entry ledger for any contact (Customer or Supplier)
  Future<Map<String, dynamic>> getContactLedger({
    required int contactId,
    required String contactType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final contactRows = await db.query('contacts',
        where: 'id = ?', whereArgs: [contactId], limit: 1);
    if (contactRows.isEmpty) {
      return {
        'contact': null,
        'openingBalance': 0.0,
        'totalDebit': 0.0,
        'totalCredit': 0.0,
        'closingBalance': 0.0,
        'entries': <LedgerEntry>[],
      };
    }
    final contact = Contact.fromMap(contactRows.first);
    final isCustomer = contactType.toLowerCase() == 'customer';
    final List<Map<String, dynamic>> rawItems = [];

    if (isCustomer) {
      // 1. Sales for this customer
      final sales = await db.query(
        'sales',
        where: 'customer_id = ?',
        whereArgs: [contactId],
        orderBy: 'created_at ASC',
      );
      for (final s in sales) {
        final total = (s['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (s['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final due = (s['due_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = s['created_at'] as String? ?? '';
        final inv = s['invoice_no'] as String? ?? '';

        // Invoice Debit (Customer owes invoice total)
        rawItems.add({
          'date': dateStr,
          'type': 'sale_invoice',
          'refNo': inv,
          'desc':
              'Sales Invoice ($inv) - Due: ${due > 0 ? due.toStringAsFixed(2) : "Paid"}',
          'method': s['payment_method'] ?? 'cash',
          'account': 'Accounts Receivable',
          'debit': total,
          'credit': 0.0,
          'id': s['id'],
        });

        // If paid at time of sale, record immediate credit
        if (paid > 0) {
          rawItems.add({
            'date': dateStr,
            'type': 'customer_payment',
            'refNo': inv,
            'desc': 'Counter Payment received for $inv',
            'method': s['payment_method'] ?? 'cash',
            'account': s['payment_method'] == 'cash'
                ? 'Cash Register'
                : 'Bank Account',
            'debit': 0.0,
            'credit': paid,
            'id': s['id'],
          });
        }
      }

      // 2. Customer Payments (subsequent recoveries)
      final payments = await db.query(
        'contact_payments',
        where: 'contact_id = ? AND payment_type = ?',
        whereArgs: [contactId, 'receive'],
        orderBy: 'date ASC',
      );
      for (final p in payments) {
        final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = p['date'] as String? ?? '';
        final ref = p['ref_no'] as String? ?? '';
        final note = p['note'] as String? ?? '';
        rawItems.add({
          'date': dateStr,
          'type': 'customer_payment',
          'refNo': ref.isNotEmpty ? ref : 'PAY-$dateStr',
          'desc':
              'Payment received (${p['payment_method']?.toString().toUpperCase()}) ${note.isNotEmpty ? "- $note" : ""}',
          'method': p['payment_method'] ?? 'cash',
          'account':
              p['payment_method'] == 'cash' ? 'Cash Register' : 'Bank Account',
          'debit': 0.0,
          'credit': amt,
          'id': p['id'],
        });
      }

      // 3. Sales Returns
      final returns = await db.query(
        'sale_returns',
        where: 'customer_id = ?',
        whereArgs: [contactId],
        orderBy: 'date ASC',
      );
      for (final r in returns) {
        final refund = (r['refund_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = r['date'] as String? ?? '';
        final ref = r['ref_no'] as String? ?? '';
        rawItems.add({
          'date': dateStr,
          'type': 'sale_return',
          'refNo': ref,
          'desc': 'Sales Return Credit Note ($ref)',
          'method': r['refund_method'] ?? 'cash',
          'account': 'Sales Returns',
          'debit': 0.0,
          'credit': refund,
          'id': r['id'],
        });
      }
    } else {
      // 1. Supplier Purchases
      final purchases = await db.query(
        'purchases',
        where: 'supplier_id = ?',
        whereArgs: [contactId],
        orderBy: 'created_at ASC',
      );
      for (final p in purchases) {
        final total = (p['total_amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (p['paid_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = p['created_at'] as String? ?? '';
        final ref = p['ref_no'] as String? ?? '';

        // Purchase Credit (We owe supplier bill total)
        rawItems.add({
          'date': dateStr,
          'type': 'purchase_bill',
          'refNo': ref,
          'desc': 'Purchase Bill ($ref)',
          'method': 'credit',
          'account': 'Accounts Payable',
          'debit': 0.0,
          'credit': total,
          'id': p['id'],
        });

        // If paid at purchase time
        if (paid > 0) {
          rawItems.add({
            'date': dateStr,
            'type': 'supplier_payment',
            'refNo': ref,
            'desc': 'Payment made against bill $ref',
            'method': 'cash',
            'account': 'Cash / Bank',
            'debit': paid,
            'credit': 0.0,
            'id': p['id'],
          });
        }
      }

      // 2. Supplier Payments (subsequent payments)
      final payments = await db.query(
        'contact_payments',
        where: 'contact_id = ? AND payment_type = ?',
        whereArgs: [contactId, 'pay'],
        orderBy: 'date ASC',
      );
      for (final p in payments) {
        final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = p['date'] as String? ?? '';
        final ref = p['ref_no'] as String? ?? '';
        final note = p['note'] as String? ?? '';
        rawItems.add({
          'date': dateStr,
          'type': 'supplier_payment',
          'refNo': ref.isNotEmpty ? ref : 'PAY-$dateStr',
          'desc':
              'Vendor Payment (${p['payment_method']?.toString().toUpperCase()}) ${note.isNotEmpty ? "- $note" : ""}',
          'method': p['payment_method'] ?? 'cash',
          'account':
              p['payment_method'] == 'cash' ? 'Cash Register' : 'Bank Account',
          'debit': amt,
          'credit': 0.0,
          'id': p['id'],
        });
      }

      // 3. Purchase Returns
      final returns = await db.query(
        'purchase_returns',
        where: 'supplier_id = ?',
        whereArgs: [contactId],
        orderBy: 'date ASC',
      );
      for (final r in returns) {
        final refund = (r['refund_amount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = r['date'] as String? ?? '';
        final ref = r['ref_no'] as String? ?? '';
        rawItems.add({
          'date': dateStr,
          'type': 'purchase_return',
          'refNo': ref,
          'desc': 'Purchase Return Debit Note ($ref)',
          'method': r['refund_method'] ?? 'cash',
          'account': 'Purchase Returns',
          'debit': refund,
          'credit': 0.0,
          'id': r['id'],
        });
      }
    }

    // Sort chronologically
    rawItems
        .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double openingBalance = 0.0;
    final List<LedgerEntry> periodEntries = [];
    double runningBalance = 0.0;

    for (final item in rawItems) {
      final dateStr = item['date'] as String;
      DateTime? itemDate;
      try {
        itemDate = DateTime.parse(dateStr);
      } catch (e, st) {
        AppLogger.warning(
            'DatabaseService', 'Invalid contact ledger date "$dateStr"', e, st);
      }

      final dr = item['debit'] as double;
      final cr = item['credit'] as double;
      final delta = isCustomer ? (dr - cr) : (cr - dr);

      if (startDate != null &&
          itemDate != null &&
          itemDate.isBefore(startDate)) {
        openingBalance += delta;
      } else if (endDate != null &&
          itemDate != null &&
          itemDate.isAfter(endDate)) {
        // after period
      } else {
        if (periodEntries.isEmpty) {
          runningBalance = openingBalance + delta;
        } else {
          runningBalance += delta;
        }

        periodEntries.add(LedgerEntry(
          date: dateStr,
          transactionType: item['type'] as String,
          refNo: item['refNo'] as String,
          description: item['desc'] as String,
          paymentMethod: item['method'] as String,
          accountName: item['account'] as String,
          debit: dr,
          credit: cr,
          runningBalance: runningBalance,
          parentId: item['id'] as int?,
        ));
      }
    }

    final totalDebit = periodEntries.fold(0.0, (sum, e) => sum + e.debit);
    final totalCredit = periodEntries.fold(0.0, (sum, e) => sum + e.credit);
    final closingBalance = periodEntries.isNotEmpty
        ? periodEntries.last.runningBalance
        : openingBalance;

    return {
      'contact': contact,
      'openingBalance': openingBalance,
      'totalDebit': totalDebit,
      'totalCredit': totalCredit,
      'closingBalance': closingBalance,
      'entries': periodEntries,
    };
  }

  /// Retrieves a comprehensive bank/cash passbook statement for a payment account
  Future<Map<String, dynamic>> getPaymentAccountStatement({
    required int accountId,
    required String accountName,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final accRows = await db.query('payment_accounts',
        where: 'id = ?', whereArgs: [accountId], limit: 1);
    final double initialOpening = accRows.isNotEmpty
        ? ((accRows.first['opening_balance'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    final rawItems = <Map<String, dynamic>>[];

    // 1. Transactions from payment_transactions table
    final txns = await db.query(
      'payment_transactions',
      where: 'account_id = ? OR account_name LIKE ?',
      whereArgs: [accountId, '%$accountName%'],
      orderBy: 'transaction_date ASC',
    );
    for (final t in txns) {
      final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final type = t['transaction_type'] as String? ?? '';
      final isDeposit = type == 'sale' ||
          type == 'customer_payment' ||
          type == 'deposit' ||
          type == 'journal_debit';
      rawItems.add({
        'date': t['transaction_date'] ?? t['created_at'] ?? '',
        'type': type,
        'refNo': t['ref_no'] ?? '',
        'desc': '${t['note'] ?? ''} (${t['contact_name'] ?? ''})'.trim(),
        'method': t['payment_method'] ?? 'cash',
        'debit': isDeposit ? amt : 0.0,
        'credit': isDeposit ? 0.0 : amt,
        'id': t['id'],
      });
    }

    // 2. Transfers into this account
    final transfersIn = await db.query('account_transfers',
        where: 'to_account_id = ?', whereArgs: [accountId]);
    for (final tr in transfersIn) {
      final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
      rawItems.add({
        'date': tr['date'] ?? '',
        'type': 'transfer_in',
        'refNo': tr['ref_no'] ?? '',
        'desc':
            'Transfer In from ${tr['from_account_name']} ${tr['note'] != null && tr['note'].toString().isNotEmpty ? "- ${tr['note']}" : ""}'
                .trim(),
        'method': 'transfer',
        'debit': amt,
        'credit': 0.0,
        'id': tr['id'],
      });
    }

    // 3. Transfers out of this account
    final transfersOut = await db.query('account_transfers',
        where: 'from_account_id = ?', whereArgs: [accountId]);
    for (final tr in transfersOut) {
      final amt = (tr['amount'] as num?)?.toDouble() ?? 0.0;
      rawItems.add({
        'date': tr['date'] ?? '',
        'type': 'transfer_out',
        'refNo': tr['ref_no'] ?? '',
        'desc':
            'Transfer Out to ${tr['to_account_name']} ${tr['note'] != null && tr['note'].toString().isNotEmpty ? "- ${tr['note']}" : ""}'
                .trim(),
        'method': 'transfer',
        'debit': 0.0,
        'credit': amt,
        'id': tr['id'],
      });
    }

    // Sort chronologically
    rawItems
        .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double openingBalance = initialOpening;
    final List<LedgerEntry> periodEntries = [];
    double runningBalance = initialOpening;

    for (final item in rawItems) {
      final dateStr = item['date'] as String;
      DateTime? itemDate;
      try {
        itemDate = DateTime.parse(dateStr);
      } catch (e, st) {
        AppLogger.warning('DatabaseService',
            'Invalid account statement date "$dateStr"', e, st);
      }

      final dr = item['debit'] as double;
      final cr = item['credit'] as double;
      final delta = dr - cr;

      if (startDate != null &&
          itemDate != null &&
          itemDate.isBefore(startDate)) {
        openingBalance += delta;
      } else if (endDate != null &&
          itemDate != null &&
          itemDate.isAfter(endDate)) {
        // after period
      } else {
        if (periodEntries.isEmpty) {
          runningBalance = openingBalance + delta;
        } else {
          runningBalance += delta;
        }
        periodEntries.add(LedgerEntry(
          date: dateStr,
          transactionType: item['type'] as String,
          refNo: item['refNo'] as String,
          description: item['desc'] as String,
          paymentMethod: item['method'] as String,
          accountName: accountName,
          debit: dr,
          credit: cr,
          runningBalance: runningBalance,
          parentId: item['id'] as int?,
        ));
      }
    }

    final totalInflow = periodEntries.fold(0.0, (sum, e) => sum + e.debit);
    final totalOutflow = periodEntries.fold(0.0, (sum, e) => sum + e.credit);
    final closingBalance = periodEntries.isNotEmpty
        ? periodEntries.last.runningBalance
        : openingBalance;

    return {
      'accountName': accountName,
      'openingBalance': openingBalance,
      'totalInflow': totalInflow,
      'totalOutflow': totalOutflow,
      'closingBalance': closingBalance,
      'entries': periodEntries,
    };
  }

  /// Computes live financial summary for Modern Chart of Accounts & Trial Balance
  Future<Map<String, dynamic>> getFinancialTrialBalance() async {
    // 1. Cash In Hand (Active Cash Registers + Cash-type Payment Accounts)
    final regRows = await db.rawQuery(
        "SELECT SUM(opening_amount + total_sales_cash) as cash FROM cash_registers WHERE status = 'open'");
    final openRegCash = (regRows.first['cash'] as num?)?.toDouble() ?? 0.0;
    final cashAcctRows = await db.rawQuery(
        "SELECT SUM(current_balance) as cash_acct FROM payment_accounts WHERE account_type = 'cash'");
    final cashAcctBal =
        (cashAcctRows.first['cash_acct'] as num?)?.toDouble() ?? 0.0;
    final openCash = openRegCash + cashAcctBal;

    // 2. Bank Accounts
    final bankRows = await db.rawQuery(
        "SELECT SUM(current_balance) as bank_total FROM payment_accounts WHERE account_type != 'cash'");
    final bankTotal = (bankRows.first['bank_total'] as num?)?.toDouble() ?? 0.0;

    // 3. Accounts Receivable (Total customer dues)
    final arRows = await db.rawQuery(
        "SELECT SUM(balance) as ar FROM contacts WHERE type = 'customer' AND balance > 0");
    final accountsReceivable = (arRows.first['ar'] as num?)?.toDouble() ?? 0.0;

    // 4. Accounts Payable (Total supplier dues)
    final apRows = await db.rawQuery(
        "SELECT SUM(balance) as ap FROM contacts WHERE type = 'supplier' AND balance > 0");
    final accountsPayable = (apRows.first['ap'] as num?)?.toDouble() ?? 0.0;

    // 5. Inventory Valuation (Stock Quantity * Purchase Price)
    final invRows = await db.rawQuery(
        "SELECT SUM(stock_quantity * purchase_price) as stock_val FROM products WHERE stock_quantity > 0");
    final inventoryValuation =
        (invRows.first['stock_val'] as num?)?.toDouble() ?? 0.0;

    // 6. Net Sales Revenue (Gross Final Sales minus Sale Returns)
    final salesRows = await db.rawQuery(
        "SELECT SUM(total_amount) as total_rev FROM sales WHERE sale_status = 'final'");
    final grossSalesRev =
        (salesRows.first['total_rev'] as num?)?.toDouble() ?? 0.0;
    double retRev = 0.0;
    try {
      final retRows = await db
          .rawQuery('SELECT SUM(total_amount) as total_ret FROM sale_returns');
      retRev = (retRows.first['total_ret'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}
    final salesRevenue = (grossSalesRev - retRev).clamp(0.0, double.infinity);

    // 7. True Cost of Goods Sold (using unit_multiplier, net of sale returns)
    final cogsRows = await db.rawQuery(
      "SELECT SUM(si.quantity * (CASE WHEN si.unit_multiplier > 0 THEN si.unit_multiplier ELSE 1.0 END) * COALESCE(p.purchase_price, 0)) as cogs "
      "FROM sale_items si JOIN sales s ON si.sale_id = s.id LEFT JOIN products p ON si.product_id = p.id "
      "WHERE s.sale_status = 'final'",
    );
    final grossCogsTotal = (cogsRows.first['cogs'] as num?)?.toDouble() ?? 0.0;
    double returnedCogsTotal = 0.0;
    try {
      final retCogsRows = await db.rawQuery(
        'SELECT COALESCE(SUM(sri.quantity * (CASE WHEN sri.unit_multiplier > 0 THEN sri.unit_multiplier ELSE 1.0 END) * COALESCE(p.purchase_price, 0)), 0) as ret_cogs '
        'FROM sale_return_items sri LEFT JOIN products p ON sri.product_id = p.id',
      );
      returnedCogsTotal =
          (retCogsRows.first['ret_cogs'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {}
    final cogsTotal =
        (grossCogsTotal - returnedCogsTotal).clamp(0.0, double.infinity);

    // 8. Operating Expenses
    final expRows =
        await db.rawQuery("SELECT SUM(amount) as total_exp FROM expenses");
    final expensesTotal =
        (expRows.first['total_exp'] as num?)?.toDouble() ?? 0.0;

    // 9. Total Assets
    final totalAssets =
        openCash + bankTotal + accountsReceivable + inventoryValuation;

    // 10. Total Liabilities
    final totalLiabilities = accountsPayable;

    // 11. Gross & Net Profit = Net Revenue - COGS - Expenses
    final grossProfit = salesRevenue - cogsTotal;
    final netProfit = grossProfit - expensesTotal;

    // 12. Owner Equity = Assets - Liabilities
    final equity = totalAssets - totalLiabilities;

    return {
      'cashInHand': openCash,
      'bankBalances': bankTotal,
      'accountsReceivable': accountsReceivable,
      'inventoryValuation': inventoryValuation,
      'totalAssets': totalAssets,
      'accountsPayable': accountsPayable,
      'totalLiabilities': totalLiabilities,
      'salesRevenue': salesRevenue,
      'costOfGoods': cogsTotal,
      'operatingExpenses': expensesTotal,
      'grossProfit': grossProfit,
      'netProfit': netProfit,
      'ownerEquity': equity,
    };
  }

  /// Posts a balanced double-entry Journal Voucher (JV)
  Future<int> addJournalVoucher({
    required String narration,
    required String debitAccount,
    required String creditAccount,
    required double amount,
    String? refNo,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final voucherRef =
        refNo ?? 'JV-${DateTime.now().millisecondsSinceEpoch % 100000}';

    return await db.transaction((txn) async {
      // 1. Debit Entry
      await txn.insert('payment_transactions', {
        'transaction_type': 'journal_debit',
        'parent_id': 0,
        'contact_id': 0,
        'contact_name': debitAccount,
        'payment_method': 'voucher',
        'amount': amount,
        'account_name': debitAccount,
        'transaction_date': nowStr,
        'ref_no': voucherRef,
        'note': 'JV Debit: $narration (Credit to $creditAccount)',
        'created_by': 'Accountant',
        'created_at': nowStr,
      });

      // 2. Credit Entry
      final creditId = await txn.insert('payment_transactions', {
        'transaction_type': 'journal_credit',
        'parent_id': 0,
        'contact_id': 0,
        'contact_name': creditAccount,
        'payment_method': 'voucher',
        'amount': amount,
        'account_name': creditAccount,
        'transaction_date': nowStr,
        'ref_no': voucherRef,
        'note': 'JV Credit: $narration (Debit to $debitAccount)',
        'created_by': 'Accountant',
        'created_at': nowStr,
      });

      // 3. Update payment_accounts if debitAccount or creditAccount match
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE name = ?',
        [amount, debitAccount],
      );
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE name = ?',
        [amount, creditAccount],
      );

      return creditId;
    });
  }

  /// Retrieves all recorded double-entry Journal Vouchers
  Future<List<Map<String, dynamic>>> getJournalVouchers() async {
    final rows = await db.query(
      'payment_transactions',
      where: "transaction_type = 'journal_debit'",
      orderBy: 'id DESC',
    );
    final List<Map<String, dynamic>> vouchers = [];
    for (final r in rows) {
      final ref = r['ref_no'] as String? ?? '';
      // Find matching credit entry
      final crRows = await db.query(
        'payment_transactions',
        where: "transaction_type = 'journal_credit' AND ref_no = ?",
        whereArgs: [ref],
        limit: 1,
      );
      final crAccount = crRows.isNotEmpty
          ? (crRows.first['contact_name'] ??
              crRows.first['account_name'] ??
              'General')
          : 'General';
      final dateStr = (r['transaction_date'] as String? ?? '').split('T').first;
      final rawNote = r['note'] as String? ?? '';
      final narration = rawNote.replaceAll(RegExp(r'^JV Debit:\s*'), '');

      vouchers.add({
        'voucherNo': ref,
        'date': dateStr.isNotEmpty ? dateStr : 'Recent',
        'narration': narration.isNotEmpty ? narration : 'Journal Voucher',
        'debitAcc': r['contact_name'] ?? r['account_name'] ?? 'Debit Account',
        'creditAcc': crAccount,
        'amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
      });
    }
    return vouchers;
  }

  // Parked / Suspended Sales

  Future<String> generateNextAccountTransferRef() async {
    final rows =
        await db.rawQuery('SELECT MAX(id) as max_id FROM account_transfers');
    final maxId = (rows.first['max_id'] as int?) ?? 0;
    return 'TRF-2026-${(maxId + 1).toString().padLeft(4, '0')}';
  }

  Future<List<PaymentAccount>> getPaymentAccounts() async {
    final rows = await db.query('payment_accounts', orderBy: 'id ASC');
    return rows.map((e) => PaymentAccount.fromMap(e)).toList();
  }

  Future<int> addPaymentAccount(PaymentAccount account) async {
    return await db.insert('payment_accounts', account.toMap());
  }

  Future<List<AccountTransfer>> getAccountTransfers() async {
    final rows = await db.query('account_transfers', orderBy: 'id DESC');
    return rows.map((e) => AccountTransfer.fromMap(e)).toList();
  }

  Future<int> transferAccountFunds(AccountTransfer transfer) async {
    return await db.transaction((txn) async {
      final transferId =
          await txn.insert('account_transfers', transfer.toMap());

      // Deduct from sender account
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
        [transfer.amount, transfer.fromAccountId],
      );

      // Add to receiver account
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE id = ?',
        [transfer.amount, transfer.toAccountId],
      );

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'account_transfer',
        'entity_id': transferId.toString(),
        'action': 'create',
        'payload_json': jsonEncode(transfer.toMap()..['id'] = transferId),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return transferId;
    });
  }

  /// Reverses and deletes an inter-account fund transfer
  Future<bool> deleteAccountTransfer(int transferId) async {
    return await db.transaction((txn) async {
      final rows = await txn.query('account_transfers',
          where: 'id = ?', whereArgs: [transferId], limit: 1);
      if (rows.isEmpty) return false;
      final transfer = AccountTransfer.fromMap(rows.first);

      // Restore sender balance (add back)
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE id = ?',
        [transfer.amount, transfer.fromAccountId],
      );

      // Restore receiver balance (subtract back)
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
        [transfer.amount, transfer.toAccountId],
      );

      await txn.delete('account_transfers',
          where: 'id = ?', whereArgs: [transferId]);

      await txn.insert('sync_queue', {
        'entity_type': 'account_transfer',
        'entity_id': transferId.toString(),
        'action': 'delete',
        'payload_json':
            jsonEncode({'id': transferId, 'ref_no': transfer.refNo}),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    });
  }

  /// Deposit funds into a payment account (e.g. capital injection, bank interest, cash top-up)
  Future<int> depositToAccount({
    required int accountId,
    required double amount,
    required String note,
    String paymentMethod = 'cash',
  }) async {
    return await db.transaction((txn) async {
      final accRows = await txn.query('payment_accounts',
          where: 'id = ?', whereArgs: [accountId], limit: 1);
      final accName = accRows.isNotEmpty
          ? (accRows.first['name'] as String? ?? 'Account')
          : 'Account';

      // Increment account balance
      await txn.rawUpdate(
        'UPDATE payment_accounts SET current_balance = current_balance + ? WHERE id = ?',
        [amount, accountId],
      );

      final ref = 'DEP-${DateTime.now().millisecondsSinceEpoch % 1000000}';

      // Record in payment_transactions table
      final txnId = await txn.insert('payment_transactions', {
        'transaction_type': 'deposit',
        'ref_no': ref,
        'amount': amount,
        'contact_id': null,
        'contact_name': 'Bank Deposit / Self',
        'payment_method': paymentMethod,
        'account_id': accountId,
        'account_name': accName,
        'transaction_date':
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'note': note.isNotEmpty ? note : 'Deposit to $accName',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Queue for live MySQL sync
      await txn.insert('sync_queue', {
        'entity_type': 'deposit',
        'entity_id': txnId.toString(),
        'action': 'create',
        'payload_json': jsonEncode({
          'account_id': accountId,
          'account_name': accName,
          'amount': amount,
          'payment_method': paymentMethod,
          'ref_no': ref,
          'note': note,
        }),
        'status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      return txnId;
    });
  }

  // Cash Register

  // ===================== ANNUAL CLOSING =====================
  Future<List<FinancialYear>> getFinancialYears() async {
    final rows = await db.query('financial_years', orderBy: 'id DESC');
    return rows.map((r) => FinancialYear.fromMap(r)).toList();
  }

  Future<int> closeFinancialYear(FinancialYear fy) async {
    return await db.transaction((txn) async {
      final id = await txn.insert('financial_years', fy.toMap());

      // Advance start_date in business settings
      final nextYear = DateTime.now().year + 1;
      await txn.rawUpdate(
        "UPDATE business_settings SET start_date = '01/01/$nextYear'",
      );
      return id;
    });
  }
}
