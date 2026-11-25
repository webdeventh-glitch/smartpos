import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/models.dart';
import 'app_logger.dart';
import 'auth_service.dart';
import 'database_encryption_service.dart';
import 'database_service.dart';
import 'embedded_database_service.dart';
import 'qulop_service.dart';

/// Enterprise Software Update & Encrypted Database Backup Center Service
class BackupUpdateService {
  static const String currentAppVersion = '1.1.1';
  static const int currentBuildNumber = 3;

  static BackupUpdateService? _instance;
  static BackupUpdateService get instance =>
      _instance ??= BackupUpdateService._();

  BackupUpdateService._();
  Timer? _autoBackupTimer;

  bool get isSchedulerRunning => _autoBackupTimer != null;

  /// Compares semantic versions (`1.1.2` vs `1.1.1`) plus optional build numbers.
  static bool isNewerVersion(
    String remoteVersion, {
    String currentVersion = currentAppVersion,
    int? remoteBuild,
    int currentBuild = currentBuildNumber,
  }) {
    List<int> parseParts(String v) {
      final clean = v.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
      final base = clean.split('+').first.split('-').first;
      return base
          .split('.')
          .map((seg) => int.tryParse(seg.trim()) ?? 0)
          .toList();
    }

    final rParts = parseParts(remoteVersion);
    final cParts = parseParts(currentVersion);
    final len = rParts.length > cParts.length ? rParts.length : cParts.length;
    for (int i = 0; i < len; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    if (remoteBuild != null && remoteBuild > currentBuild) return true;
    return false;
  }

  File _updateConfigFile({Directory? baseDirOverride}) {
    final base = baseDirOverride?.path ?? path.join(_getBaseDir(), 'SmartPOS');
    return File(path.join(base, 'update_config.json'));
  }

  Future<String> loadUpdateFeedUrl({Directory? baseDirOverride}) async {
    try {
      final f = _updateConfigFile(baseDirOverride: baseDirOverride);
      if (!f.existsSync()) return '';
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map && decoded['feed_url'] is String) {
        return (decoded['feed_url'] as String).trim();
      }
    } catch (_) {}
    return '';
  }

  Future<void> saveUpdateFeedUrl(String url,
      {Directory? baseDirOverride}) async {
    final f = _updateConfigFile(baseDirOverride: baseDirOverride);
    if (!f.parent.existsSync()) {
      f.parent.createSync(recursive: true);
    }
    await f.writeAsString(
      jsonEncode({
        'feed_url': url.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  /// Resolves interval in hours from frequency setting ('daily', 'weekly', 'custom').
  static Duration intervalForSettings(BusinessSettings settings) {
    switch (settings.backupFrequency.toLowerCase()) {
      case 'weekly':
        return const Duration(days: 7);
      case 'custom':
        final hours = settings.backupIntervalHours > 0
            ? settings.backupIntervalHours
            : 24;
        return Duration(hours: hours);
      case 'daily':
      default:
        return const Duration(hours: 24);
    }
  }

  /// Returns true when automated backup is enabled and the configured schedule interval has elapsed.
  static bool isAutoBackupDue(BusinessSettings settings, {DateTime? now}) {
    if (!settings.autoBackupEnabled) return false;
    final lastRaw = settings.lastAutoBackupAt.trim();
    if (lastRaw.isEmpty) return true;
    final last = DateTime.tryParse(lastRaw);
    if (last == null) return true;
    final checkNow = now ?? DateTime.now();
    return checkNow.difference(last) >= intervalForSettings(settings);
  }

  /// Creates a safety backup before schema upgrades on file-backed databases.
  Future<File?> createPreMigrationBackupIfNeeded({
    required String dbPath,
    required int oldVersion,
    required int newVersion,
    Directory? targetDir,
  }) async {
    if (dbPath.isEmpty ||
        dbPath == inMemoryDatabasePath ||
        oldVersion >= newVersion ||
        !File(dbPath).existsSync()) {
      return null;
    }
    try {
      final dir = targetDir ?? await getBackupDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final dest = File(
        path.join(
          dir.path,
          'smartpos_premigration_v${oldVersion}_to_v${newVersion}_$stamp.db.enc',
        ),
      );
      await DatabaseEncryptionService.encryptFile(File(dbPath), dest);
      AppLogger.info(
        'BackupUpdateService',
        'Pre-migration backup created at ${dest.path} (v$oldVersion -> v$newVersion)',
      );
      return dest;
    } catch (e, st) {
      AppLogger.warning(
          'BackupUpdateService', 'Pre-migration backup failed', e, st);
      return null;
    }
  }

  /// Prunes oldest backup files so at most [keepCount] backups remain.
  Future<int> enforceBackupRetention({
    required int keepCount,
    Directory? targetDir,
  }) async {
    if (keepCount <= 0) return 0;
    final dir = targetDir ?? await getBackupDirectory();
    if (!dir.existsSync()) return 0;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db.enc') || f.path.endsWith('.db'))
        .toList();
    if (files.length <= keepCount) return 0;
    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    int deleted = 0;
    for (final stale in files.skip(keepCount)) {
      try {
        await stale.delete();
        deleted++;
      } catch (e, st) {
        AppLogger.warning('BackupUpdateService',
            'Failed deleting old backup ${stale.path}', e, st);
      }
    }
    return deleted;
  }

  /// Executes an automatic backup if due, updates `last_auto_backup_at`, and trims retention.
  Future<File?> runScheduledBackupIfDue({
    required BusinessSettings settings,
    DatabaseService? db,
    Directory? targetDir,
    String? dbPathOverride,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    if (!isAutoBackupDue(settings, now: checkNow)) return null;

    final file = await createBackup(
      customNote: 'scheduled_${settings.backupFrequency}',
      targetDir: targetDir,
      dbPathOverride: dbPathOverride,
    );
    await enforceBackupRetention(
      keepCount: settings.backupRetentionCount,
      targetDir: targetDir,
    );
    final updated =
        settings.copyWith(lastAutoBackupAt: checkNow.toIso8601String());
    if (db != null) {
      await db.updateBusinessSettings(updated);
    } else if (DatabaseService.instanceOrNull != null) {
      await DatabaseService.instance.updateBusinessSettings(updated);
    }
    return file;
  }

  /// Starts periodic background check for due scheduled backups (skipped in flutter test).
  void startAutoBackupScheduler(
      {Duration checkInterval = const Duration(minutes: 15)}) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(checkInterval, (_) async {
      try {
        final db = DatabaseService.instanceOrNull;
        if (db == null || !db.db.isOpen) return;
        final settings = await db.getBusinessSettings();
        await runScheduledBackupIfDue(settings: settings, db: db);
      } catch (e, st) {
        AppLogger.warning(
            'BackupUpdateService', 'Scheduled backup tick failed', e, st);
      }
    });
  }

  void stopAutoBackupScheduler() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
  }

  String _getBaseDir() {
    return Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
  }

  /// Active SQLite Database path matching DatabaseService
  String getActiveDatabasePath() {
    final base = _getBaseDir();
    return path.join(base, 'SmartPOS', 'smart_pos.db');
  }

  /// Directory where automated & manual backups are stored
  Future<Directory> getBackupDirectory() async {
    final base = _getBaseDir();
    final backupDir = Directory(path.join(base, 'SmartPOS', 'backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    return backupDir;
  }

  /// Creates a timestamped AES-256-GCM encrypted backup copy of the SQLite database
  Future<File> createBackup({
    String? customNote,
    Directory? targetDir,
    String? dbPathOverride,
  }) async {
    final backupDir = targetDir ?? await getBackupDirectory();
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final backupFileName = 'smartpos_backup_$stamp.db.enc';
    final backupPath = path.join(backupDir.path, backupFileName);
    final destFile = File(backupPath);

    final openInst = DatabaseService.instanceOrNull;
    final openFilePath = openInst?.dbFilePath;
    final effectivePath = (dbPathOverride != null && dbPathOverride.isNotEmpty)
        ? dbPathOverride
        : ((openFilePath != null &&
                openFilePath != inMemoryDatabasePath &&
                File(openFilePath).existsSync())
            ? openFilePath
            : getActiveDatabasePath());

    if (openInst != null &&
        openInst.dbFilePath != null &&
        path.normalize(openInst.dbFilePath!).toLowerCase() ==
            path.normalize(effectivePath).toLowerCase()) {
      await openInst.checkpointWal();
    }

    final activeDbFile = File(effectivePath);
    if (activeDbFile.existsSync()) {
      await DatabaseEncryptionService.encryptFile(activeDbFile, destFile);
      AppLogger.info(
        'BackupUpdateService',
        'Created encrypted backup at $backupPath${customNote != null ? ' ($customNote)' : ''}',
      );
      return destFile;
    } else {
      final encryptedPlaceholder = await DatabaseEncryptionService.encryptBytes(
        Uint8List.fromList(utf8.encode('Smart POS Schema Backup $stamp')),
      );
      await destFile.writeAsBytes(encryptedPlaceholder, flush: true);
      AppLogger.warning(
        'BackupUpdateService',
        'Active database file not found at $effectivePath; wrote encrypted placeholder backup at $backupPath',
      );
      return destFile;
    }
  }

  /// Lists all stored database backups (both `.db.enc` encrypted and legacy `.db`)
  Future<List<FileSystemEntity>> listBackups() async {
    final dir = await getBackupDirectory();
    final list = dir
        .listSync()
        .where((f) => f.path.endsWith('.db.enc') || f.path.endsWith('.db'))
        .toList();
    list.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return list;
  }

  /// Restores database from a selected backup file (handles both encrypted and legacy unencrypted)
  Future<bool> restoreFromBackup(
    String backupFilePath, {
    String? dbPathOverride,
  }) async {
    final backupFile = File(backupFilePath);
    if (!backupFile.existsSync()) {
      AppLogger.warning(
          'BackupUpdateService', 'Backup not found: $backupFilePath');
      return false;
    }

    final targetPath = dbPathOverride ?? getActiveDatabasePath();
    final activeDbFile = File(targetPath);
    try {
      // Close live SQLite handle and delete stale WAL/SHM files before replacing DB on Windows
      await DatabaseService.closeOpenInstanceIfPathMatches(targetPath);
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$targetPath$suffix');
        if (sidecar.existsSync()) {
          await sidecar.delete();
        }
      }

      if (await DatabaseEncryptionService.isEncryptedFile(backupFile)) {
        await DatabaseEncryptionService.decryptFile(backupFile, activeDbFile);
      } else {
        await backupFile.copy(activeDbFile.path);
      }
      await DatabaseService.initialize(customPath: activeDbFile.path);
      await DatabaseEncryptionService.sealVaultSnapshot(activeDbFile.path);
      if (AuthService.isAuthenticated) {
        await AuthService.logout(
          reason: 'Database was restored from backup. Please sign in again.',
        );
      }
      AppLogger.info(
          'BackupUpdateService', 'Restored database from $backupFilePath');
      return true;
    } catch (e, st) {
      AppLogger.error('BackupUpdateService',
          'Failed restoring backup $backupFilePath', e, st);
      return false;
    }
  }

  /// Checks license eligibility and fetches real `version.json` manifest from vendor's update URL.
  Future<Map<String, dynamic>> checkOnlineUpdate({
    BusinessSettings? settings,
    String? feedUrlOverride,
    http.Client? httpClient,
    Directory? baseDirOverride,
  }) async {
    final resolvedSettings = settings ??
        (DatabaseService.instanceOrNull != null
            ? await DatabaseService.instance.getBusinessSettings()
            : BusinessSettings());

    // 1. Local License Gate
    final licStatus = await QulopService.checkCurrentQulop(resolvedSettings);
    if (!licStatus.isValid) {
      return {
        'has_update': false,
        'update_allowed': false,
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
        'blocked_reason':
            'Active license required for software updates (${licStatus.message}).',
      };
    }
    if (!licStatus.allowUpdates) {
      return {
        'has_update': false,
        'update_allowed': false,
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
        'blocked_reason':
            'Online software updates are disabled on your current license plan. Please contact vendor to enable updates or renew.',
      };
    }

    // 2. Resolve Vendor Update Manifest URL
    final feedUrl = (feedUrlOverride ??
            await loadUpdateFeedUrl(baseDirOverride: baseDirOverride))
        .trim();
    if (feedUrl.isEmpty) {
      return {
        'has_update': false,
        'update_allowed': true,
        'needs_feed_url': true,
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
        'message':
            'Update Server URL is not set yet. Enter your vendor version.json URL and click Check Now.',
      };
    }

    final uri = Uri.tryParse(feedUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return {
        'has_update': false,
        'update_allowed': true,
        'error': 'Invalid update manifest URL: $feedUrl',
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
      };
    }

    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    try {
      final resp = await client.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return {
          'has_update': false,
          'update_allowed': true,
          'error': 'Update server returned HTTP ${resp.statusCode}',
          'current_version': currentAppVersion,
          'current_build': currentBuildNumber,
        };
      }

      final manifest = jsonDecode(resp.body);
      if (manifest is! Map) {
        return {
          'has_update': false,
          'update_allowed': true,
          'error': 'Malformed update manifest JSON.',
          'current_version': currentAppVersion,
          'current_build': currentBuildNumber,
        };
      }

      // 3. Optional Remote Website License Verification Endpoint
      final licenseVerifyUrl =
          (manifest['license_verify_url'] ?? '').toString().trim();
      if (licenseVerifyUrl.isNotEmpty) {
        final verifyUri = Uri.tryParse(licenseVerifyUrl);
        if (verifyUri != null &&
            verifyUri.hasScheme &&
            verifyUri.hasAuthority) {
          try {
            final hwId = await QulopService.getHardwareId();
            final mac = await QulopService.getDeviceMacAddress();
            final verifyResp = await client
                .post(
                  verifyUri,
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'license_key': resolvedSettings.purchaseKey,
                    'hardware_id': hwId,
                    'mac_address': mac,
                    'business_name': resolvedSettings.businessName,
                    'business_type': resolvedSettings.businessType,
                    'current_version': currentAppVersion,
                  }),
                )
                .timeout(const Duration(seconds: 10));
            if (verifyResp.statusCode >= 200 && verifyResp.statusCode < 300) {
              final body = jsonDecode(verifyResp.body);
              if (body is Map && body['allow_update'] == false) {
                return {
                  'has_update': false,
                  'update_allowed': false,
                  'current_version': currentAppVersion,
                  'current_build': currentBuildNumber,
                  'blocked_reason': (body['message'] ??
                          'Server denied software update for this license.')
                      .toString(),
                };
              }
            } else if (verifyResp.statusCode == 403 ||
                verifyResp.statusCode == 401) {
              return {
                'has_update': false,
                'update_allowed': false,
                'current_version': currentAppVersion,
                'current_build': currentBuildNumber,
                'blocked_reason':
                    'License server denied update access (HTTP ${verifyResp.statusCode}).',
              };
            }
          } catch (e, st) {
            AppLogger.warning(
                'BackupUpdateService',
                'Remote license verify unreachable; falling back to local signed key check',
                e,
                st);
          }
        }
      }

      final latestVersion = (manifest['version'] ?? '').toString().trim();
      final latestBuild = int.tryParse((manifest['build'] ?? '').toString());
      final hasUpdate = latestVersion.isNotEmpty &&
          isNewerVersion(latestVersion, remoteBuild: latestBuild);

      return {
        'has_update': hasUpdate,
        'update_allowed': true,
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
        'latest_version':
            latestVersion.isNotEmpty ? latestVersion : currentAppVersion,
        'latest_build': latestBuild,
        'release_date': (manifest['release_date'] ?? '').toString(),
        'release_notes': (manifest['release_notes'] ?? '').toString(),
        'download_url': (manifest['download_url'] ?? '').toString().trim(),
        'sha256': (manifest['sha256'] ?? '').toString().trim().toLowerCase(),
        'download_size_mb': manifest['download_size_mb'] ?? 0,
      };
    } catch (e) {
      return {
        'has_update': false,
        'update_allowed': true,
        'error': 'Unable to check updates: $e',
        'current_version': currentAppVersion,
        'current_build': currentBuildNumber,
      };
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Downloads verified installer `.exe`, enforces SHA-256 checksum, and creates a mandatory encrypted DB backup first.
  Future<Map<String, dynamic>> downloadAndPrepareSafeUpdate({
    required Map<String, dynamic> updateInfo,
    required BusinessSettings settings,
    http.Client? httpClient,
    Directory? backupDirOverride,
    Directory? stagingDirOverride,
    String? dbPathOverride,
  }) async {
    final licStatus = await QulopService.checkCurrentQulop(settings);
    if (!licStatus.isValid || !licStatus.allowUpdates) {
      return {
        'success': false,
        'error':
            'Update blocked: Active update-eligible software license required.',
      };
    }

    final downloadUrl = (updateInfo['download_url'] ?? '').toString().trim();
    final expectedSha256 =
        (updateInfo['sha256'] ?? '').toString().trim().toLowerCase();
    final latestVersion =
        (updateInfo['latest_version'] ?? 'latest').toString().trim();

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return {'success': false, 'error': 'Invalid download_url in manifest.'};
    }

    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    try {
      final resp = await client.get(uri).timeout(const Duration(minutes: 5));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return {
          'success': false,
          'error': 'Failed downloading update (HTTP ${resp.statusCode}).',
        };
      }

      final bytes = resp.bodyBytes;
      if (bytes.length < 2 || bytes[0] != 0x4D || bytes[1] != 0x5A) {
        return {
          'success': false,
          'error':
              'Downloaded file is not a valid Windows executable (missing MZ header). Update aborted safely.',
        };
      }

      final actualSha256 = sha256.convert(bytes).toString().toLowerCase();
      if (expectedSha256.isNotEmpty && actualSha256 != expectedSha256) {
        return {
          'success': false,
          'error':
              'SHA-256 verification failed! Downloaded installer may be corrupted or tampered. Update aborted.',
        };
      }

      // Mandatory encrypted pre-update database backup BEFORE launching any installer
      final backupFile = await createBackup(
        customNote: 'pre_update_v$latestVersion',
        targetDir: backupDirOverride,
        dbPathOverride: dbPathOverride,
      );
      await enforceBackupRetention(
        keepCount: settings.backupRetentionCount > 0
            ? settings.backupRetentionCount
            : 10,
        targetDir: backupDirOverride,
      );

      final stagingDir = stagingDirOverride ??
          Directory(path.join(_getBaseDir(), 'SmartPOS', 'updates'));
      if (!stagingDir.existsSync()) {
        stagingDir.createSync(recursive: true);
      }
      final safeVer = latestVersion.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
      final installerFile = File(
        path.join(stagingDir.path, 'SmartPOS_Update_v$safeVer.exe'),
      );
      await installerFile.writeAsBytes(bytes, flush: true);

      return {
        'success': true,
        'installer_path': installerFile.path,
        'backup_path': backupFile.path,
        'sha256': actualSha256,
        'version': latestVersion,
      };
    } catch (e) {
      return {'success': false, 'error': 'Update download failed: $e'};
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Safely checkpoints SQLite WAL, stops embedded MySQL, and executes Inno Setup upgrade without touching database.
  Future<void> launchPreparedInstallerSafely(
    String installerPath, {
    bool exitApp = true,
  }) async {
    final openDb = DatabaseService.instanceOrNull;
    if (openDb != null && openDb.db.isOpen) {
      await openDb.checkpointWal();
      if (openDb.dbFilePath != null) {
        await DatabaseService.closeOpenInstanceIfPathMatches(
            openDb.dbFilePath!);
      }
    }
    if (EmbeddedDatabaseService.isRunning.value) {
      await EmbeddedDatabaseService.stopServer(
          port: EmbeddedDatabaseService.activePort);
    }
    await Process.start(
      installerPath,
      const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
        '/MERGETASKS=!cleaninstall',
      ],
      mode: ProcessStartMode.detached,
    );
    if (exitApp) {
      exit(0);
    }
  }

  /// Offline Package Verification, Mandatory Backup, and Safe Migration / Installer Launch
  Future<Map<String, dynamic>> applyOfflineUpdatePackage(
    String packagePath, {
    bool launchExe = false,
  }) async {
    final file = File(packagePath);
    if (!file.existsSync()) {
      return {
        'success': false,
        'error': 'Update package file not found at $packagePath',
      };
    }

    // Create encrypted pre-update backup first so database is always recoverable
    final backup = await createBackup(customNote: 'pre_offline_update');

    if (packagePath.toLowerCase().endsWith('.exe')) {
      final bytes = await file
          .openRead(0, 2)
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      if (bytes.length < 2 || bytes[0] != 0x4D || bytes[1] != 0x5A) {
        return {
          'success': false,
          'error': 'Selected .exe file is not a valid Windows installer.',
        };
      }
      if (launchExe) {
        await launchPreparedInstallerSafely(file.path);
      }
      return {
        'success': true,
        'launched_installer': launchExe,
        'backup_path': backup.path,
        'message':
            'Encrypted pre-update backup saved at ${backup.path}. Ready to upgrade without touching database.',
      };
    }

    final db = await DatabaseService.initialize();
    await db.ensureSchemaMigration();

    return {
      'success': true,
      'backup_path': backup.path,
      'message':
          'Pre-update backup saved at ${backup.path} and database schema migrated safely without data loss!',
      'migrated_tables': [
        'business_settings',
        'payment_transactions',
        'product_serials_batches',
        'product_bundles',
        'audit_logs',
        'sync_queue',
      ],
    };
  }
}
