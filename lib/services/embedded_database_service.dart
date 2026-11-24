import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:path/path.dart' as p;
import 'app_logger.dart';

/// Embedded Database Service for Smart POS Enterprise.
///
/// Enables packaging and auto-starting a local portable MySQL or MariaDB server
/// directly with SmartPOS without requiring Laragon, XAMPP, or external installers.
/// Provides lifecycle management (auto-start, auto-shutdown, health monitoring,
/// and LAN address discovery for multi-counter POS setups).
class EmbeddedDatabaseService {
  static final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);
  static final ValueNotifier<String> statusText =
      ValueNotifier<String>('Stopped');
  static final ValueNotifier<String?> detectedEngine =
      ValueNotifier<String?>(null);

  static Process? _serverProcess;
  static Timer? _healthCheckTimer;
  static int _activePort = 3307;
  static int get activePort => _activePort;

  /// Returns the base directory where SmartPOS stores its embedded database data
  static Directory getEmbeddedDataDir() {
    final localAppData = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    final dir = Directory(p.join(localAppData, 'SmartPOS', 'embedded_mysql'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Discovers any available MySQL or MariaDB executable on this system
  static String? findEngineExecutable() {
    final searchPaths = <String>[];

    // 1. App-bundled engine folder inside Release directory
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    searchPaths.add(p.join(exeDir, 'engine', 'mariadb', 'bin', 'mysqld.exe'));
    searchPaths.add(p.join(exeDir, 'engine', 'mysql', 'bin', 'mysqld.exe'));
    searchPaths.add(p.join(exeDir, 'mariadb', 'bin', 'mysqld.exe'));
    searchPaths.add(p.join(exeDir, 'mysql', 'bin', 'mysqld.exe'));

    // 2. Current working directory engine folder
    searchPaths.add(p.join(
        Directory.current.path, 'engine', 'mariadb', 'bin', 'mysqld.exe'));
    searchPaths.add(
        p.join(Directory.current.path, 'engine', 'mysql', 'bin', 'mysqld.exe'));

    // 3. User LocalAppData engine directory
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    if (localAppData.isNotEmpty) {
      searchPaths.add(p.join(
          localAppData, 'SmartPOS', 'engine', 'mariadb', 'bin', 'mysqld.exe'));
      searchPaths.add(p.join(
          localAppData, 'SmartPOS', 'engine', 'mysql', 'bin', 'mysqld.exe'));
    }

    // 4. Laragon installations (Development or existing setup on PC)
    const laragonMysql = r'C:\laragon\bin\mysql';
    if (Directory(laragonMysql).existsSync()) {
      try {
        final entries = Directory(laragonMysql).listSync();
        for (final entry in entries) {
          if (entry is Directory) {
            final cand = p.join(entry.path, 'bin', 'mysqld.exe');
            if (File(cand).existsSync()) {
              searchPaths.add(cand);
            }
          }
        }
      } catch (_) {}
    }

    // 5. XAMPP default path
    searchPaths.add(r'C:\xampp\mysql\bin\mysqld.exe');

    for (final path in searchPaths) {
      if (File(path).existsSync()) {
        detectedEngine.value = path;
        return path;
      }
    }

    detectedEngine.value = null;
    return null;
  }

  /// Checks if a network port is already actively listening
  static Future<bool> isPortOpen(int port, {String host = '127.0.0.1'}) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 600),
      );
      await socket.close();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates a tailored my.ini configuration file for the embedded server
  static File _ensureConfigFile(String engineExe, int port, Directory dataDir) {
    final parentDir = dataDir.parent;
    final configFile = File(p.join(parentDir.path, 'my.ini'));
    final basedir = File(engineExe).parent.parent.path.replaceAll(r'\', '/');
    final datadirPath = dataDir.path.replaceAll(r'\', '/');

    final configContent = '''
[mysqld]
port=$port
bind-address=0.0.0.0
basedir="$basedir"
datadir="$datadirPath"
default_storage_engine=InnoDB
innodb_buffer_pool_size=64M
innodb_log_file_size=16M
max_connections=50
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
skip-name-resolve
default_authentication_plugin=mysql_native_password
sql_mode=NO_ENGINE_SUBSTITUTION
''';

    configFile.writeAsStringSync(configContent);
    return configFile;
  }

  /// Ensures the MySQL data directory is initialized (runs --initialize-insecure if needed)
  static Future<bool> _ensureInitialized(
      String engineExe, Directory dataDir) async {
    if (dataDir.existsSync() && dataDir.listSync().isNotEmpty) {
      return true; // Already initialized
    }

    dataDir.createSync(recursive: true);
    AppLogger.info('EmbeddedDatabase',
        'Initializing clean embedded MySQL data directory at ${dataDir.path}...');

    try {
      final binDir = File(engineExe).parent.path;
      final installDbExe = p.join(binDir, 'mysql_install_db.exe');

      if (File(installDbExe).existsSync()) {
        // MariaDB style
        final res = await Process.run(
          installDbExe,
          ['--datadir=${dataDir.path}'],
          runInShell: false,
        );
        AppLogger.info(
            'EmbeddedDatabase', 'mysql_install_db exited with ${res.exitCode}');
        return res.exitCode == 0;
      } else {
        // MySQL 8.0 / 5.7 style
        final res = await Process.run(
          engineExe,
          [
            '--initialize-insecure',
            '--datadir=${dataDir.path}',
            '--console',
          ],
          runInShell: false,
        );
        AppLogger.info('EmbeddedDatabase',
            'mysqld --initialize-insecure exited with ${res.exitCode}');
        return res.exitCode == 0;
      }
    } catch (e, st) {
      AppLogger.error('EmbeddedDatabase',
          'Failed initializing embedded data directory', e, st);
      return false;
    }
  }

  /// Starts the embedded MySQL/MariaDB server as a background service
  static Future<bool> startServer({int port = 3307}) async {
    _activePort = port;

    // 1. Check if server is already running on this port
    if (await isPortOpen(port)) {
      isRunning.value = true;
      statusText.value = 'Running (Port $port)';
      AppLogger.info('EmbeddedDatabase',
          'Database server is already running and active on port $port');
      _startHealthCheck(port);
      await _ensureDatabaseExists(port: port);
      return true;
    }

    // 2. Discover engine executable
    final engineExe = findEngineExecutable();
    if (engineExe == null) {
      statusText.value = 'No engine binary found';
      AppLogger.warning('EmbeddedDatabase',
          'Cannot start embedded server: No mysqld.exe found in engine/ or system paths.');
      return false;
    }

    final embeddedDir = getEmbeddedDataDir();
    final dataDir = Directory(p.join(embeddedDir.path, 'data'));

    // 3. Ensure data directory is initialized
    await _ensureInitialized(engineExe, dataDir);

    // 4. Generate my.ini config
    final configFile = _ensureConfigFile(engineExe, port, dataDir);

    statusText.value = 'Starting on port $port...';
    AppLogger.info('EmbeddedDatabase',
        'Launching $engineExe on port $port with config ${configFile.path}...');

    try {
      // Start as standalone detached background process
      _serverProcess = await Process.start(
        engineExe,
        [
          '--defaults-file=${configFile.path}',
          '--port=$port',
          '--bind-address=0.0.0.0',
          '--standalone',
        ],
        mode: ProcessStartMode.detached,
      );

      // Poll until port opens (up to 12 seconds)
      bool portReady = false;
      for (int i = 0; i < 24; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await isPortOpen(port)) {
          portReady = true;
          break;
        }
      }

      if (portReady) {
        isRunning.value = true;
        statusText.value = 'Running (Port $port)';
        AppLogger.info('EmbeddedDatabase',
            'Embedded database server successfully started and accepting connections on port $port');
        _startHealthCheck(port);
        await _ensureDatabaseExists(port: port);
        return true;
      } else {
        isRunning.value = false;
        statusText.value = 'Failed to bind port $port';
        AppLogger.error('EmbeddedDatabase',
            'Server process started but port $port did not respond in time.');
        return false;
      }
    } catch (e, st) {
      isRunning.value = false;
      statusText.value = 'Error: $e';
      AppLogger.error('EmbeddedDatabase',
          'Exception while starting embedded server', e, st);
      return false;
    }
  }

  /// Gracefully shuts down the embedded database server
  static Future<bool> stopServer({int port = 3307}) async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    statusText.value = 'Stopping...';
    final engineExe = findEngineExecutable();

    if (engineExe != null) {
      final binDir = File(engineExe).parent.path;
      final adminExe = p.join(binDir, 'mysqladmin.exe');

      if (File(adminExe).existsSync()) {
        try {
          AppLogger.info('EmbeddedDatabase',
              'Sending graceful shutdown signal via mysqladmin on port $port...');
          await Process.run(
            adminExe,
            ['-P', '$port', '-u', 'root', 'shutdown'],
            runInShell: false,
          );
        } catch (_) {}
      }
    }

    if (_serverProcess != null) {
      try {
        _serverProcess?.kill();
      } catch (_) {}
      _serverProcess = null;
    }

    // Wait until port closes
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!await isPortOpen(port)) {
        break;
      }
    }

    final stillOpen = await isPortOpen(port);
    isRunning.value = stillOpen;
    statusText.value = stillOpen ? 'Running (External Process)' : 'Stopped';
    return !stillOpen;
  }

  /// Automatically ensures the default smartpos database exists
  static Future<void> _ensureDatabaseExists(
      {int port = 3307, String dbName = 'smartpos'}) async {
    try {
      final conn = await MySQLConnection.createConnection(
        host: '127.0.0.1',
        port: port,
        userName: 'root',
        password: '',
        databaseName: null, // Connect without selecting a database
      );
      await conn.connect();
      await conn.execute(
          "CREATE DATABASE IF NOT EXISTS `$dbName` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
      await conn.close();
      AppLogger.info('EmbeddedDatabase',
          'Ensured database `$dbName` is ready on embedded MySQL port $port');
    } catch (e) {
      AppLogger.warning('EmbeddedDatabase',
          'Could not auto-create database `$dbName` (may already exist or requires password): $e');
    }
  }

  /// Starts periodic background health check polling
  static void _startHealthCheck(int port) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final open = await isPortOpen(port);
      if (isRunning.value != open) {
        isRunning.value = open;
        statusText.value = open ? 'Running (Port $port)' : 'Stopped';
      }
    });
  }

  /// Fetches local IPv4 addresses so other POS counters on LAN can easily connect
  static Future<List<String>> getLocalLanIpAddresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return ips;
  }
}
