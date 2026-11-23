import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../services/app_logger.dart';

/// Interactive System & Error Logs Viewer dialog for Super Admin / Developers.
/// Allows viewing, filtering, searching, copying, and exporting error logs.
class SystemLogsDialog extends StatefulWidget {
  const SystemLogsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const SystemLogsDialog(),
    );
  }

  @override
  State<SystemLogsDialog> createState() => _SystemLogsDialogState();
}

class _SystemLogsDialogState extends State<SystemLogsDialog> {
  List<File> _logFiles = [];
  File? _selectedFile;
  List<String> _logLines = [];
  bool _isLoading = true;
  String _filterLevel = 'ALL'; // ALL, ERROR, WARNING, INFO
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final files = AppLogger.listLogFiles();
      List<String> lines = [];

      File? targetFile;
      if (files.isNotEmpty) {
        targetFile = _selectedFile ?? files.first;
        if (targetFile.existsSync()) {
          final content = await targetFile.readAsString();
          lines =
              content.split('\n').where((l) => l.trim().isNotEmpty).toList();
        }
      }

      // If no file lines or file is empty, fallback to memory logs
      if (lines.isEmpty) {
        lines = List<String>.from(AppLogger.getRecentMemoryLogs(maxLines: 300));
      }

      if (mounted) {
        setState(() {
          _logFiles = files;
          _selectedFile = targetFile;
          _logLines = lines;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLogger.error('SystemLogsDialog', 'Failed loading logs', e, st);
      if (mounted) {
        setState(() {
          _logLines = AppLogger.getRecentMemoryLogs(maxLines: 300);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectFile(File file) async {
    setState(() {
      _selectedFile = file;
      _isLoading = true;
    });
    try {
      final content = await file.readAsString();
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _logLines = lines;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openLogsFolder() {
    final dir = AppLogger.getLogsDirectory();
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [dir.path]);
      } else if (Platform.isMacOS) {
        Process.run('open', [dir.path]);
      } else {
        Process.run('xdg-open', [dir.path]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logs folder path:\n${dir.path}')),
      );
    }
  }

  void _copyAllLogs(List<String> filtered) {
    if (filtered.isEmpty) return;
    Clipboard.setData(ClipboardData(text: filtered.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
            'Copied ${filtered.length} log lines to clipboard! Send to developer via WhatsApp/Email.'),
      ),
    );
  }

  Future<void> _exportLogsToDesktop(List<String> filtered) async {
    try {
      final desktopPath = Platform.environment['USERPROFILE'] != null
          ? p.join(Platform.environment['USERPROFILE']!, 'Desktop')
          : Directory.current.path;
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final exportFile =
          File(p.join(desktopPath, 'SmartPOS_Error_Report_$stamp.txt'));
      await exportFile.writeAsString(filtered.join('\n'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
                'Log report exported successfully to Desktop:\n${exportFile.path}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to export logs: $e'),
          ),
        );
      }
    }
  }

  List<String> _getFilteredLines() {
    return _logLines.where((line) {
      if (_filterLevel == 'ERROR' &&
          !line.contains('[ERROR]') &&
          !line.contains('[CRITICAL]')) {
        return false;
      }
      if (_filterLevel == 'WARNING' &&
          !line.contains('[WARNING]') &&
          !line.contains('[ERROR]') &&
          !line.contains('[CRITICAL]')) {
        return false;
      }
      if (_filterLevel == 'INFO' && !line.contains('[INFO]')) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !line.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  Color _getLineColor(String line) {
    if (line.contains('[CRITICAL]') || line.contains('[ERROR]')) {
      return const Color(0xFFF87171); // Soft Red
    }
    if (line.contains('[WARNING]')) {
      return const Color(0xFFFBBF24); // Amber
    }
    if (line.contains('[INFO]')) {
      return const Color(0xFF34D399); // Soft Emerald
    }
    if (line.contains('Stack:')) {
      return const Color(0xFF94A3B8); // Muted gray
    }
    return const Color(0xFFE2E8F0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _getFilteredLines();
    final logsDir = AppLogger.getLogsDirectory();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bug_report_rounded,
                        color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System & Error Logs Viewer (سسٹم اور ایرر لاگز)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Real-time diagnostic records from: ${logsDir.path}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open Logs Folder in Windows Explorer',
                    icon: const Icon(Icons.folder_open_rounded, size: 20),
                    onPressed: _openLogsFolder,
                  ),
                  IconButton(
                    tooltip: 'Refresh Logs',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadLogs,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Controls Bar: File Selector, Filter Chips, Search Field
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // File Dropdown
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Log File:',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<File?>(
                          value: _selectedFile,
                          dropdownColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : Colors.black87),
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            if (_logFiles.isEmpty)
                              DropdownMenuItem<File?>(
                                value: null,
                                child: Text(
                                    'Live Memory (Recent ${_logLines.length} lines)'),
                              )
                            else
                              ..._logFiles.map((f) => DropdownMenuItem<File?>(
                                    value: f,
                                    child: Text(
                                      '${p.basename(f.path)} (${(f.lengthSync() / 1024).toStringAsFixed(1)} KB)',
                                      style: const TextStyle(
                                          fontFamily: 'monospace'),
                                    ),
                                  )),
                          ],
                          onChanged: (file) {
                            if (file != null) _selectFile(file);
                          },
                        ),
                      ],
                    ),

                    // Level Filter Chips
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterChip(
                            'ALL', 'All Logs (${_logLines.length})'),
                        const SizedBox(width: 6),
                        _buildFilterChip('ERROR', 'Errors & Crashes',
                            color: const Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        _buildFilterChip('WARNING', 'Warnings',
                            color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        _buildFilterChip('INFO', 'Info',
                            color: const Color(0xFF10B981)),
                      ],
                    ),

                    // Search Input
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search in logs...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        onChanged: (val) => setState(
                            () => _searchQuery = val.trim().toLowerCase()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Log Output Terminal Window
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617), // Deep terminal dark
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No log entries match "$_searchQuery"'
                                    : 'No log entries found for filter level "$_filterLevel"',
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 13),
                              ),
                            )
                          : Scrollbar(
                              controller: _scrollCtrl,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, idx) {
                                  final line = filtered[idx];
                                  final color = _getLineColor(line);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 1.5),
                                    child: SelectableText(
                                      line,
                                      style: TextStyle(
                                        fontFamily: 'Consolas',
                                        fontSize: 11.5,
                                        color: color,
                                        height: 1.35,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions: Copy, Export, Open Folder, Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.length} of ${_logLines.length} lines',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text('Copy All Logs (کاپی کریں)'),
                        onPressed: () => _copyAllLogs(filtered),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon:
                            const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Export to Desktop'),
                        onPressed: () => _exportLogsToDesktop(filtered),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String level, String label, {Color? color}) {
    final isSelected = _filterLevel == level;
    final activeColor = color ?? const Color(0xFF4F46E5);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _filterLevel = level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? activeColor
                : const Color(0xFF64748B).withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
