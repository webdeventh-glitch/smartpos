import '../models/models.dart';
import 'base_repository.dart';

/// Manages operating expenses and cash register deduction postings.
class ExpenseRepository extends BaseRepository {
  const ExpenseRepository([super.dbService]);

  Future<List<Expense>> getExpenses() async {
    final rows = await db.query('expenses', orderBy: 'id DESC');
    return rows.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> addExpense(Expense expense) async {
    final id = await db.transaction((txn) async {
      final insertedId = await txn.insert('expenses', expense.toMap());
      if (expense.paymentMethod.toLowerCase() == 'cash') {
        await txn.rawUpdate(
          'UPDATE cash_registers SET total_sales_cash = total_sales_cash - ? WHERE status = \'open\'',
          [expense.amount],
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
        'category': expense.category,
        'amount': expense.amount,
        'payment_method': expense.paymentMethod,
      },
    );
    return id;
  }

  // Payment Accounts & Fund Transfers
}
