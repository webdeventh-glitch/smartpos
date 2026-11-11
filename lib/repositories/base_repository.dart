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
}
