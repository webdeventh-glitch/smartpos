import 'package:intl/intl.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Manages active cashier till sessions (open, track shift totals, close).
class RegisterRepository extends BaseRepository {
  const RegisterRepository([super.dbService]);

  Future<CashRegister?> getActiveRegister() async {
    final rows = await db.query(
      'cash_registers',
      where: 'status = ?',
      whereArgs: ['open'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return CashRegister.fromMap(rows.first);
    return null;
  }

  Future<void> openRegister(String cashierName, double openingAmount) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await db.transaction((txn) async {
      // Close any lingering prior open register session
      await txn.update(
        'cash_registers',
        {
          'status': 'closed',
          'closed_at': now,
          'note': 'Auto-closed prior to opening new shift',
        },
        where: 'status = ?',
        whereArgs: ['open'],
      );

      await txn.insert('cash_registers', {
        'cashier_name': cashierName,
        'opening_amount': openingAmount,
        'closing_amount': 0.0,
        'total_sales_cash': 0.0,
        'total_sales_card': 0.0,
        'total_sales_other': 0.0,
        'status': 'open',
        'opened_at': now,
        'closed_at': null,
        'note': '',
      });
    });
  }

  Future<void> closeRegister(int id, double closingAmount, String note) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await db.update(
      'cash_registers',
      {
        'closing_amount': closingAmount,
        'status': 'closed',
        'closed_at': now,
        'note': note,
      },
      where: id > 0 ? 'id = ?' : 'status = ?',
      whereArgs: id > 0 ? [id] : ['open'],
    );
  }


  Future<List<Map<String, dynamic>>> getRegisterReport({String? status}) =>
      dbService.reportRepo.getRegisterReport(status: status);
}
