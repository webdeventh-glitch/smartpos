import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'database_service.dart';

enum SyncState { idle, checking, syncing, success, error, offline }

class SyncStatusInfo {
  final SyncState state;
  final String mode; // 'offline', 'hybrid', 'online'
  final int pendingCount;
  final String message;
  final DateTime? lastSync;
  final bool isServerReachable;

  const SyncStatusInfo({
    this.state = SyncState.idle,
    this.mode = 'offline',
    this.pendingCount = 0,
    this.message = 'System ready',
    this.lastSync,
    this.isServerReachable = false,
  });

  SyncStatusInfo copyWith({
    SyncState? state,
    String? mode,
    int? pendingCount,
    String? message,
    DateTime? lastSync,
    bool? isServerReachable,
  }) {
    return SyncStatusInfo(
      state: state ?? this.state,
      mode: mode ?? this.mode,
      pendingCount: pendingCount ?? this.pendingCount,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
      isServerReachable: isServerReachable ?? this.isServerReachable,
    );
  }
}

class CloudSyncService {
  static final ValueNotifier<SyncStatusInfo> syncNotifier =
      ValueNotifier<SyncStatusInfo>(const SyncStatusInfo());

  static Timer? _autoSyncTimer;

  /// Clean base URL by removing trailing slashes
  static String _cleanUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Initialize service state and pending counter
  static Future<void> initialize(BusinessSettings settings) async {
    try {
      final db = await DatabaseService.initialize();
      final pending = await db.getPendingSyncCount();
      DateTime? lastSyncTime;
      if (settings.lastSyncTimestamp.isNotEmpty) {
        lastSyncTime = DateTime.tryParse(settings.lastSyncTimestamp);
      }

      syncNotifier.value = SyncStatusInfo(
        state: settings.isOfflineOnly ? SyncState.offline : SyncState.idle,
        mode: settings.syncMode,
        pendingCount: pending,
        lastSync: lastSyncTime,
        message: settings.isOfflineOnly
            ? 'Offline SQLite active (no sync)'
            : '$pending changes queued for sync',
      );

      DatabaseService.onSyncQueueUpdated = refreshPendingCount;

      if (settings.isHybridSync && settings.syncAutoIntervalMinutes > 0) {
        startPeriodicSync(settings);
      }
    } catch (_) {}
  }

  /// Refresh pending items counter for badge & UI displays
  static Future<void> refreshPendingCount() async {
    try {
      final db = await DatabaseService.initialize();
      final count = await db.getPendingSyncCount();
      syncNotifier.value = syncNotifier.value.copyWith(
        pendingCount: count,
        message: syncNotifier.value.mode == 'offline'
            ? 'Offline SQLite active (no sync)'
            : '$count changes queued for sync',
      );
    } catch (_) {}
  }

  /// Test connectivity to the Laravel / MySQL REST API endpoint
  static Future<Map<String, dynamic>> testConnection({
    required String serverUrl,
    required String apiKey,
  }) async {
    final clean = _cleanUrl(serverUrl);
    if (clean.isEmpty) {
      return {
        'success': false,
        'message': 'Server URL cannot be empty (e.g. http://localhost:8000/api)',
        'latencyMs': 0,
      };
    }

    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = Uri.parse('$clean/health');
      final res = await http.get(
        endpoint,
        headers: {
          'Accept': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 6));

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {
          'success': true,
          'message': 'Connected to Laravel/MySQL Backend (${latency}ms) - Status: ${res.statusCode}',
          'latencyMs': latency,
        };
      } else {
        return {
          'success': false,
          'message': 'Server responded with HTTP ${res.statusCode}: ${res.body}',
          'latencyMs': latency,
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'message': 'Connection failed: ${e.toString().replaceAll('Exception:', '').trim()}',
        'latencyMs': stopwatch.elapsedMilliseconds,
      };
    }
  }

  /// Execute bidirectional sync (Push local pending items to Laravel/MySQL, then Pull new items)
  static Future<Map<String, dynamic>> syncNow(BusinessSettings settings) async {
    if (settings.isOfflineOnly) {
      return {
        'success': true,
        'pushed': 0,
        'pulled': 0,
        'message': 'Offline Mode is active. All data remains in local SQLite without network sync.',
      };
    }

    final serverUrl = _cleanUrl(settings.syncServerUrl);
    if (serverUrl.isEmpty) {
      syncNotifier.value = syncNotifier.value.copyWith(
        state: SyncState.error,
        message: 'Sync failed: Server URL not configured',
      );
      return {
        'success': false,
        'pushed': 0,
        'pulled': 0,
        'message': 'Server URL is empty. Please set your Laravel backend URL in Sync Settings.',
      };
    }

    final db = await DatabaseService.initialize();
    final pendingItems = await db.getPendingSyncItems(limit: 100);

    syncNotifier.value = syncNotifier.value.copyWith(
      state: SyncState.syncing,
      pendingCount: pendingItems.length,
      message: 'Syncing ${pendingItems.length} items with Laravel / MySQL server...',
    );

    int pushedCount = 0;
    int pulledCount = 0;

    try {
      // 1. PUSH PHASE: Send pending local changes to Laravel API
      if (pendingItems.isNotEmpty) {
        final pushPayload = {
          'branch_id': settings.syncBranchId,
          'timestamp': DateTime.now().toIso8601String(),
          'batch': pendingItems.map((item) {
            return {
              'queue_id': item['id'],
              'entity_type': item['entity_type'],
              'entity_id': item['entity_id'],
              'action': item['action'],
              'payload': jsonDecode(item['payload_json'] as String? ?? '{}'),
              'created_at': item['created_at'],
            };
          }).toList(),
        };

        final pushUri = Uri.parse('$serverUrl/sync/push');
        final pushRes = await http.post(
          pushUri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (settings.syncApiKey.isNotEmpty) 'Authorization': 'Bearer ${settings.syncApiKey}',
          },
          body: jsonEncode(pushPayload),
        ).timeout(const Duration(seconds: 15));

        if (pushRes.statusCode >= 200 && pushRes.statusCode < 300) {
          final ids = pendingItems.map((e) => e['id'] as int).toList();
          await db.markSyncItemsDone(ids);
          pushedCount = ids.length;
        } else {
          throw Exception('Push failed HTTP ${pushRes.statusCode}: ${pushRes.body}');
        }
      }

      // 2. PULL PHASE: Retrieve remote changes since lastSyncTimestamp
      final pullUri = Uri.parse(
        '$serverUrl/sync/pull?since=${Uri.encodeComponent(settings.lastSyncTimestamp)}&branch_id=${settings.syncBranchId}',
      );
      final pullRes = await http.get(
        pullUri,
        headers: {
          'Accept': 'application/json',
          if (settings.syncApiKey.isNotEmpty) 'Authorization': 'Bearer ${settings.syncApiKey}',
        },
      ).timeout(const Duration(seconds: 15));

      if (pullRes.statusCode >= 200 && pullRes.statusCode < 300) {
        final pullData = jsonDecode(pullRes.body);
        if (pullData is Map<String, dynamic> && pullData.containsKey('data')) {
          final data = pullData['data'];
          if (data is Map<String, dynamic>) {
            // Apply remote updates to local SQLite if provided
            if (data['products'] is List) {
              pulledCount += (data['products'] as List).length;
            }
            if (data['customers'] is List) {
              pulledCount += (data['customers'] as List).length;
            }
          }
        }
      }

      final nowIso = DateTime.now().toIso8601String();
      final updatedSettings = settings.copyWith(lastSyncTimestamp: nowIso);
      await db.updateBusinessSettings(updatedSettings);

      final remainingPending = await db.getPendingSyncCount();

      syncNotifier.value = syncNotifier.value.copyWith(
        state: SyncState.success,
        pendingCount: remainingPending,
        lastSync: DateTime.now(),
        isServerReachable: true,
        message: 'Sync complete: Pushed $pushedCount items, pulled $pulledCount items',
      );

      return {
        'success': true,
        'pushed': pushedCount,
        'pulled': pulledCount,
        'message': 'Successfully synced with Laravel / MySQL! ($pushedCount pushed, $pulledCount pulled)',
      };
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      final remaining = await db.getPendingSyncCount();

      syncNotifier.value = syncNotifier.value.copyWith(
        state: SyncState.error,
        pendingCount: remaining,
        isServerReachable: false,
        message: 'Sync error: $errorMsg',
      );

      return {
        'success': false,
        'pushed': pushedCount,
        'pulled': pulledCount,
        'message': 'Sync error: $errorMsg',
      };
    }
  }

  /// Setup auto-sync recurring timer
  static void startPeriodicSync(BusinessSettings settings) {
    _autoSyncTimer?.cancel();
    if (!settings.isHybridSync || settings.syncAutoIntervalMinutes <= 0) return;

    _autoSyncTimer = Timer.periodic(
      Duration(minutes: settings.syncAutoIntervalMinutes),
      (_) async {
        await syncNow(settings);
      },
    );
  }

  static void stopPeriodicSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }
}
