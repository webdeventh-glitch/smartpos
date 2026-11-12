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

  Future<void> closeRegister(
    int id,
    double closingAmount,
    String note, {
    Map<int, int>? denominations,
    double coinsAmount = 0.0,
  }) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await db.transaction((txn) async {
      await txn.update(
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

      if (denominations != null) {
        final targetId = id > 0
            ? id
            : ((await txn.query('cash_registers',
                        columns: ['id'], orderBy: 'id DESC', limit: 1))
                    .firstOrNull?['id'] as int? ??
                0);
        if (targetId > 0) {
          final totalDenomAmount = denominations.entries.fold<double>(
                0.0,
                (s, e) => s + (e.key * e.value),
              ) +
              coinsAmount;
          if (totalDenomAmount > 0 || coinsAmount > 0) {
            await txn.insert('cash_denominations', {
              'cash_register_id': targetId,
              'd5000': denominations[5000] ?? 0,
              'd1000': denominations[1000] ?? 0,
              'd500': denominations[500] ?? 0,
              'd100': denominations[100] ?? 0,
              'd50': denominations[50] ?? 0,
              'd20': denominations[20] ?? 0,
              'd10': denominations[10] ?? 0,
              'd5': denominations[5] ?? 0,
              'd2': denominations[2] ?? 0,
              'd1': (denominations[1] ?? 0) + coinsAmount.round(),
              'total_amount': totalDenomAmount,
              'created_at': now,
            });
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getRegisterReport({String? status}) =>
      dbService.reportRepo.getRegisterReport(status: status);
}
