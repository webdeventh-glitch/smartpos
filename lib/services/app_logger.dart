import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Centralized application logger with daily files, size-based rotation,
/// and automatic retention cleanup under `%LOCALAPPDATA%\SmartPOS\logs`.
class AppLogger {
  static const int defaultMaxFileSizeBytes =
      5 * 1024 * 1024; // 5 MB per log file
  static const int defaultMaxLogFiles = 14;

  static Directory? _overrideLogsDir;
  static bool _suppressFileWritesInTest =
      Platform.environment.containsKey('FLUTTER_TEST');
  static int maxFileSizeBytes = defaultMaxFileSizeBytes;
  static int maxLogFiles = defaultMaxLogFiles;

  static final List<String> _recentMemoryLogs = <String>[];
  static const int _maxMemoryLines = 300;

  /// Allows tests to direct logs to a temporary directory and verify rotation.
  static void configureForTest({
    Directory? logsDirectory,
    bool enableFileWrites = true,
    int maxBytes = defaultMaxFileSizeBytes,
    int keepFiles = defaultMaxLogFiles,
  }) {
    _overrideLogsDir = logsDirectory;
    _suppressFileWritesInTest = !enableFileWrites;
    maxFileSizeBytes = maxBytes;
    maxLogFiles = keepFiles;
  }

  /// Resets test configuration back to defaults.
  static void resetConfiguration() {
    _overrideLogsDir = null;
    _suppressFileWritesInTest =
        Platform.environment.containsKey('FLUTTER_TEST');
    maxFileSizeBytes = defaultMaxFileSizeBytes;
    maxLogFiles = defaultMaxLogFiles;
    _recentMemoryLogs.clear();
  }

  static Directory getLogsDirectory() {
    if (_overrideLogsDir != null) {
      if (!_overrideLogsDir!.existsSync()) {
        _overrideLogsDir!.createSync(recursive: true);
      }
      return _overrideLogsDir!;
    }
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.current.path;
    final dir = Directory(p.join(base, 'SmartPOS', 'logs'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  static void debug(String tag, String message) {
    log(LogLevel.debug, tag, message);
  }

  static void info(String tag, String message) {
    log(LogLevel.info, tag, message);
  }

  static void warning(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    log(LogLevel.warning, tag, message, error: error, stackTrace: stackTrace);
  }

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);
  }

  static void critical(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    log(LogLevel.critical, tag, message, error: error, stackTrace: stackTrace);
  }

  static void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();
    final levelName = level.name.toUpperCase();
    final buffer = StringBuffer()
      ..write('[${now.toIso8601String()}] [$levelName] [$tag] $message');
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    if (stackTrace != null) {
      final stackLines = stackTrace.toString().trim().split('\n').take(8);
      buffer.write('\n  Stack: ${stackLines.join('\n  ')}');
    }
    final entry = buffer.toString();

    _recentMemoryLogs.add(entry);
    if (_recentMemoryLogs.length > _maxMemoryLines) {
      _recentMemoryLogs.removeAt(0);
    }

    if (level == LogLevel.error ||
        level == LogLevel.critical ||
        !_suppressFileWritesInTest) {
      debugPrint(entry);
    }

    if (_suppressFileWritesInTest && _overrideLogsDir == null) {
      return;
    }

    try {
      _writeWithRotation(now, entry);
    } catch (ioError) {
      debugPrint('[AppLogger] Failed writing log entry: $ioError');
    }
  }

  static String _dateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static void _writeWithRotation(DateTime now, String entry) {
    final dir = getLogsDirectory();
    final stamp = _dateStamp(now);
    final activeFile = File(p.join(dir.path, 'smartpos_$stamp.log'));

    if (activeFile.existsSync()) {
      final currentSize = activeFile.lengthSync();
      if (currentSize + entry.length + 2 > maxFileSizeBytes) {
        _rotateLogFile(dir, stamp, activeFile);
      }
    }

    activeFile.writeAsStringSync(
      '$entry\n',
      mode: FileMode.append,
      flush: true,
    );

    _pruneOldLogs(dir);
  }

  static void _rotateLogFile(Directory dir, String stamp, File activeFile) {
    // Shift existing numbered backups (up to maxLogFiles)
    for (int i = maxLogFiles - 1; i >= 1; i--) {
      final src = File(p.join(dir.path, 'smartpos_$stamp.$i.log'));
      if (src.existsSync()) {
        final dst = File(p.join(dir.path, 'smartpos_$stamp.${i + 1}.log'));
        if (dst.existsSync()) {
          dst.deleteSync();
        }
        src.renameSync(dst.path);
      }
    }
    final firstArchive = File(p.join(dir.path, 'smartpos_$stamp.1.log'));
    if (firstArchive.existsSync()) {
      firstArchive.deleteSync();
    }
    if (activeFile.existsSync()) {
      activeFile.renameSync(firstArchive.path);
    }
  }

  static void _pruneOldLogs(Directory dir) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            p.basename(f.path).startsWith('smartpos_') &&
            f.path.endsWith('.log'))
        .toList();

    if (files.length <= maxLogFiles) return;

    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (int i = maxLogFiles; i < files.length; i++) {
      try {
        files[i].deleteSync();
      } catch (e) {
        debugPrint('[AppLogger] Could not delete old log ${files[i].path}: $e');
      }
    }
  }

  static List<String> getRecentMemoryLogs({int maxLines = 100}) {
    if (_recentMemoryLogs.length <= maxLines) {
      return List<String>.unmodifiable(_recentMemoryLogs);
    }
    return List<String>.unmodifiable(
      _recentMemoryLogs.sublist(_recentMemoryLogs.length - maxLines),
    );
  }

  static List<File> listLogFiles() {
    final dir = getLogsDirectory();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList();
    files
        .sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }
}

/// Centralized helper for displaying user-facing critical error dialogs.
class AppErrorHandler {
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    String tag = 'UI',
  }) async {
    AppLogger.error(tag, '$title: $message', error, stackTrace);
    if (!context.mounted) return;

    final details = [
      if (error != null) 'Error: $error',
      if (stackTrace != null) 'Stack Trace:\n$stackTrace',
    ].join('\n\n');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: const TextStyle(fontSize: 13, height: 1.45)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Technical Details',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SelectableText(
                          details,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (details.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: '$title\n$message\n\n$details'));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Error details copied to clipboard.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Details'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
