import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import 'base_repository.dart';

/// Manages operating expenses, expense payments, and cash register postings.
class ExpenseRepository extends BaseRepository {
  const ExpenseRepository([super.dbService]);

  Future<List<Expense>> getExpenses() async {
    final rows = await db.query('expenses', orderBy: 'id DESC');
    return rows.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> addExpense(
    Expense expense, {
    String paymentNote = '',
    String accountName = 'Cash Register',
  }) async {
    final id = await db.transaction((txn) async {
      final insertedId = await txn.insert('expenses', expense.toMap());
      if (expense.paidAmount > 0) {
        await _applyCashRegisterDelta(
          txn,
          paymentMethod: expense.paymentMethod,
          amount: expense.paidAmount,
          isRefund: expense.isRefund,
        );
        await _insertExpensePaymentRow(
          txn,
          expenseId: insertedId,
          expense: expense,
          amount: expense.paidAmount,
          paymentMethod: expense.paymentMethod,
          paidOn: expense.date,
          note: paymentNote,
          accountName: accountName,
        );
      }
      return insertedId;
    });
    await recordActivity(
      action: 'created',
      entityType: 'expense',
      entityId: id,
      newValues: {
        'ref_no': expense.refNo,
        'title': expense.title,
        'category': expense.category,
        'amount': expense.amount,
        'paid_amount': expense.paidAmount,
        'payment_status': expense.paymentStatus,
        'payment_method': expense.paymentMethod,
      },
    );
    return id;
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id == null) return;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      if (existingRows.isNotEmpty) {
        final prev = Expense.fromMap(existingRows.first);
        if (prev.paidAmount > 0) {
          // Reverse previous cash register impact before applying updated impact.
          await _applyCashRegisterDelta(
            txn,
            paymentMethod: prev.paymentMethod,
            amount: prev.paidAmount,
            isRefund: !prev.isRefund,
          );
        }
      }
      await txn.update(
        'expenses',
        expense.toMap(),
        where: 'id = ?',
        whereArgs: [expense.id],
      );
      if (expense.paidAmount > 0) {
        await _applyCashRegisterDelta(
          txn,
          paymentMethod: expense.paymentMethod,
          amount: expense.paidAmount,
          isRefund: expense.isRefund,
        );
      }
    });
    await recordActivity(
      action: 'updated',
      entityType: 'expense',
      entityId: expense.id,
      newValues: {
        'ref_no': expense.refNo,
        'title': expense.title,
        'category': expense.category,
        'amount': expense.amount,
        'paid_amount': expense.paidAmount,
        'payment_status': expense.paymentStatus,
      },
    );
  }

  Future<void> deleteExpense(int id) async {
    Expense? deleted;
    await db.transaction((txn) async {
      final rows =
          await txn.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        deleted = Expense.fromMap(rows.first);
        if (deleted!.paidAmount > 0) {
          await _applyCashRegisterDelta(
            txn,
            paymentMethod: deleted!.paymentMethod,
            amount: deleted!.paidAmount,
            isRefund: !deleted!.isRefund,
          );
        }
      }
      await txn.delete(
        'payment_transactions',
        where: 'transaction_type = ? AND parent_id = ?',
        whereArgs: ['expense', id],
      );
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
    await recordActivity(
      action: 'deleted',
      entityType: 'expense',
      entityId: id,
      oldValues: deleted == null
          ? null
          : {
              'ref_no': deleted!.refNo,
              'category': deleted!.category,
              'amount': deleted!.amount,
            },
    );
  }

  Future<void> recordExpensePayment({
    required int expenseId,
    required double amount,
    required String paymentMethod,
    required String paidOn,
    String note = '',
    String accountName = 'Cash Register',
  }) async {
    if (amount <= 0) return;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      if (rows.isEmpty) return;
      final exp = Expense.fromMap(rows.first);
      final newPaid = (exp.paidAmount + amount).clamp(0.0, exp.amount);
      final newStatus = newPaid >= exp.amount - 0.009
          ? 'paid'
          : (newPaid > 0.009 ? 'partial' : 'due');

      await txn.update(
        'expenses',
        {
          'paid_amount': newPaid,
          'payment_status': newStatus,
          'payment_method': paymentMethod.toLowerCase(),
        },
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      await _applyCashRegisterDelta(
        txn,
        paymentMethod: paymentMethod,
        amount: amount,
        isRefund: exp.isRefund,
      );
      await _insertExpensePaymentRow(
        txn,
        expenseId: expenseId,
        expense: exp,
        amount: amount,
        paymentMethod: paymentMethod,
        paidOn: paidOn,
        note: note,
        accountName: accountName,
      );
    });
    await recordActivity(
      action: 'payment_added',
      entityType: 'expense',
      entityId: expenseId,
      newValues: {
        'amount': amount,
        'payment_method': paymentMethod,
        'paid_on': paidOn,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getExpensePayments(int expenseId) async {
    final rows = await db.query(
      'payment_transactions',
      where: 'transaction_type = ? AND parent_id = ?',
      whereArgs: ['expense', expenseId],
      orderBy: 'id ASC',
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static const List<String> defaultExpenseCategories = [
    'Store Rent',
    'Electricity & Utilities',
    'Salaries & Wages',
    'Staff Meal & Refreshments',
    'Delivery & Courier',
    'Packaging & Bags',
    'Store Maintenance',
    'Office Supplies & Stationery',
    'Rent',
    'Miscellaneous Expense',
  ];

  Future<List<String>> getExpenseCategories() async {
    try {
      final rows = await db.query('expense_categories', orderBy: 'name ASC');
      final set = <String>{...defaultExpenseCategories};
      for (final r in rows) {
        final name = (r['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) set.add(name);
      }
      final list = set.toList()..sort();
      return list;
    } catch (_) {
      return List<String>.from(defaultExpenseCategories);
    }
  }

  Future<void> addExpenseCategory(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await db.insert(
      'expense_categories',
      {
        'name': clean,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _applyCashRegisterDelta(
    Transaction txn, {
    required String paymentMethod,
    required double amount,
    required bool isRefund,
  }) async {
    if (amount <= 0 || paymentMethod.toLowerCase() != 'cash') return;
    // Normal expense deducts from cash register; refund adds back.
    final delta = isRefund ? amount : -amount;
    await txn.rawUpdate(
      "UPDATE cash_registers SET total_sales_cash = total_sales_cash + ? WHERE status = 'open'",
      [delta],
    );
  }

  Future<void> _insertExpensePaymentRow(
    Transaction txn, {
    required int expenseId,
    required Expense expense,
    required double amount,
    required String paymentMethod,
    required String paidOn,
    required String note,
    required String accountName,
  }) async {
    final payee = expense.paymentTo.isNotEmpty
        ? expense.paymentTo
        : (expense.contactName.isNotEmpty
            ? expense.contactName
            : expense.category);
    await txn.insert('payment_transactions', {
      'transaction_type': 'expense',
      'parent_id': expenseId,
      'contact_id': expense.contactId,
      'contact_name': payee,
      'payment_method': paymentMethod.toLowerCase(),
      'amount': amount,
      'account_name': accountName,
      'transaction_date': paidOn,
      'ref_no': expense.refNo,
      'note': note,
      'created_by': AuthService.currentUser?.name ?? 'Cashier',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
