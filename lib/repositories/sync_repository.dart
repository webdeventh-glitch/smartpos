import 'dart:convert';
import '../services/app_logger.dart';
import '../services/database_service.dart';
import '../services/mysql_service.dart';
import 'base_repository.dart';

/// Manages the offline-first MySQL / Laravel synchronization outbox queue.
class SyncRepository extends BaseRepository {
  const SyncRepository([super.dbService]);

  /// Triggers background synchronization of queued records into MySQL.
  void triggerAsyncMySqlSync() {
    if (DatabaseService.suppressSync || !db.isOpen) return;
    dbService.settingsRepo.getBusinessSettings().then((s) {
      if (!db.isOpen) return;
      if (s.isMySql) {
        MySqlService.connectAndSync(settings: s, localDb: dbService);
      }
    }).catchError((Object e, StackTrace st) {
      AppLogger.warning(
          'SyncRepository', 'Async MySQL sync skipped due to error', e, st);
    });
  }

// ===================== SYNC QUEUE OPERATIONS (MYSQL & LARAVEL) =====================

  Future<int> queueSyncItem({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    return await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload_json': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems(
      {int limit = 100}) async {
    return await db.query(
      'sync_queue',
      where: "status = 'pending'",
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markSyncItemsDone(List<int> ids) async {
    if (ids.isEmpty) return;
    final nowIso = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'sync_queue',
        {'status': 'synced', 'synced_at': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSyncItemFailed(int id, String error) async {
    await db.execute('''
      UPDATE sync_queue 
      SET status = 'failed', 
          retry_count = retry_count + 1, 
          last_error = ? 
      WHERE id = ?
    ''', [error, id]);
  }

  Future<int> getPendingSyncCount() async {
    final res = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sync_queue WHERE status = 'pending'");
    return (res.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentSyncLogs({int limit = 50}) async {
    return await db.query(
      'sync_queue',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  Future<void> clearCompletedSyncLogs() async {
    await db.delete('sync_queue', where: "status = 'synced'");
  }

  /// Step 7.6: Resolves offline-first sync conflicts via Last-Write-Wins (LWW)
  /// comparing timestamps and recording an immutable audit entry.
  Future<Map<String, dynamic>> resolveSyncConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> localRecord,
    required Map<String, dynamic> remoteRecord,
    String localUpdatedAt = '',
    String remoteUpdatedAt = '',
  }) async {
    final localDt = DateTime.tryParse(localUpdatedAt.trim()) ??
        DateTime.tryParse(
            (localRecord['updated_at'] ?? localRecord['created_at'] ?? '')
                .toString());
    final remoteDt = DateTime.tryParse(remoteUpdatedAt.trim()) ??
        DateTime.tryParse(
            (remoteRecord['updated_at'] ?? remoteRecord['created_at'] ?? '')
                .toString());

    // Default to local_won on exact ties so counter terminal data is never unexpectedly overwritten.
    final remoteIsNewer =
        remoteDt != null && (localDt == null || remoteDt.isAfter(localDt));
    final winnerSource = remoteIsNewer ? 'remote_won' : 'local_won';
    final winnerRecord = remoteIsNewer ? remoteRecord : localRecord;

    final int? numericId = int.tryParse(entityId);
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': 'conflict_resolved',
      'payload_json': jsonEncode(winnerRecord),
      'status': 'synced',
      'retry_count': 0,
      'entity_updated_at': (remoteIsNewer ? remoteUpdatedAt : localUpdatedAt),
      'conflict_resolution': winnerSource,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': DateTime.now().toIso8601String(),
    });

    await recordActivity(
      action: 'conflict_resolved',
      entityType: entityType,
      entityId: numericId,
      oldValues: {'local': localRecord, 'remote': remoteRecord},
      newValues: {
        'resolution': winnerSource,
        'localUpdatedAt': localDt?.toIso8601String() ?? localUpdatedAt,
        'remoteUpdatedAt': remoteDt?.toIso8601String() ?? remoteUpdatedAt,
      },
    );

    return {
      'winner': winnerSource,
      'record': winnerRecord,
      'localTimestamp': localDt?.toIso8601String(),
      'remoteTimestamp': remoteDt?.toIso8601String(),
    };
  }
}
