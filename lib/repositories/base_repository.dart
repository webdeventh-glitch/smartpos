import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/app_logger.dart';
import '../services/database_service.dart';

/// Shared base class for all SQLite domain repositories.
///
/// Accepts an optional [DatabaseService] instance (useful for isolated unit
/// testing) and falls back dynamically to [DatabaseService.instance].
abstract class BaseRepository {
  final DatabaseService? _injectedDbService;

  const BaseRepository([DatabaseService? dbService])
      : _injectedDbService = dbService;

  DatabaseService get dbService =>
      _injectedDbService ?? DatabaseService.instance;

  Database get db => dbService.db;

  /// Records a non-fatal CRUD entry in `activity_log` when sync suppression is off.
  Future<void> recordActivity({
    required String action,
    required String entityType,
    int? entityId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    DatabaseExecutor? txn,
  }) async {
    if (DatabaseService.suppressSync) return;
    try {
      await dbService.authRepo.logActivity(
        action: action,
        entityType: entityType,
        entityId: entityId,
        oldValues: oldValues,
        newValues: newValues,
        txn: txn,
      );
    } catch (e, st) {
      AppLogger.warning(
        'ActivityLog',
        'Skipped activity log for $entityType/$action',
        e,
        st,
      );
    }
  }

  /// Atomically adjusts stock for a product or specific product variation,
  /// keeping parent `products.stock_quantity` synchronized to the sum of
  /// all variation quantities when [variationId] is present.
  Future<void> adjustProductAndVariationStock(
    DatabaseExecutor txn, {
    required int productId,
    int? variationId,
    required double delta,
    bool clampAtZero = false,
  }) async {
    if (variationId != null) {
      final updatedVarRows = await txn.rawUpdate(
        clampAtZero
            ? 'UPDATE variations SET stock_quantity = MAX(0, stock_quantity + ?) WHERE id = ?'
            : 'UPDATE variations SET stock_quantity = stock_quantity + ? WHERE id = ?',
        [delta, variationId],
      );
      if (updatedVarRows > 0) {
        final sumRows = await txn.rawQuery(
          'SELECT COALESCE(SUM(stock_quantity), 0.0) AS total_stock FROM variations WHERE product_id = ?',
          [productId],
        );
        final total = (sumRows.first['total_stock'] as num?)?.toDouble() ?? 0.0;
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = ? WHERE id = ?',
          [total, productId],
        );
        return;
      }
    }

    await txn.rawUpdate(
      clampAtZero
          ? 'UPDATE products SET stock_quantity = MAX(0, stock_quantity + ?) WHERE id = ?'
          : 'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
      [delta, productId],
    );
  }
}
