import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/localization_service.dart';

class CloudSyncScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Function(BusinessSettings)? onSettingsUpdated;

  const CloudSyncScreen({
    super.key,
    required this.settings,
    this.onSettingsUpdated,
  });

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  late String _syncMode;
  late TextEditingController _urlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _branchIdCtrl;
  late int _intervalMinutes;

  bool _isTesting = false;
  String _testResult = '';
  bool _testSuccess = false;

  bool _isSyncing = false;
  String _syncResult = '';

  List<Map<String, dynamic>> _logs = [];
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _syncMode = widget.settings.syncMode;
    _urlCtrl = TextEditingController(text: widget.settings.syncServerUrl);
    _apiKeyCtrl = TextEditingController(text: widget.settings.syncApiKey);
    _branchIdCtrl =
        TextEditingController(text: widget.settings.syncBranchId.toString());
    _intervalMinutes = widget.settings.syncAutoIntervalMinutes;

    _loadQueueData();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _branchIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQueueData() async {
    try {
      final db = await DatabaseService.initialize();
      final count = await db.getPendingSyncCount();
      final recentLogs = await db.getRecentSyncLogs(limit: 20);
      if (mounted) {
        setState(() {
          _pendingCount = count;
          _logs = recentLogs;
        });
      }
    } catch (e, st) {
      AppLogger.warning(
          'CloudSyncScreen', 'Failed loading cloud sync queue', e, st);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult =
          PosLocalization.tr('Pinging server...', settings: widget.settings);
      _testSuccess = false;
    });

    final res = await CloudSyncService.testConnection(
      serverUrl: _urlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res['success'] as bool? ?? false;
        _testResult = res['message'] as String? ?? 'No response';
      });
    }
  }

  Future<void> _triggerSyncNow() async {
    setState(() {
      _isSyncing = true;
      _syncResult = PosLocalization.tr('Starting bidirectional sync...',
          settings: widget.settings);
    });

    // Create current settings snapshot
    final currentSettings = widget.settings.copyWith(
      syncMode: _syncMode,
      syncServerUrl: _urlCtrl.text.trim(),
      syncApiKey: _apiKeyCtrl.text.trim(),
      syncBranchId: int.tryParse(_branchIdCtrl.text.trim()) ?? 1,
      syncAutoIntervalMinutes: _intervalMinutes,
    );

    final res = await CloudSyncService.syncNow(currentSettings);
    await _loadQueueData();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncResult = res['message'] as String? ?? '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_syncResult),
          backgroundColor: (res['success'] as bool? ?? false)
              ? const Color(0xFF10B981)
              : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    final updated = widget.settings.copyWith(
      syncMode: _syncMode,
      syncServerUrl: _urlCtrl.text.trim(),
      syncApiKey: _apiKeyCtrl.text.trim(),
      syncBranchId: int.tryParse(_branchIdCtrl.text.trim()) ?? 1,
      syncAutoIntervalMinutes: _intervalMinutes,
    );

    final db = await DatabaseService.initialize();
    await db.updateBusinessSettings(updated);

    if (_syncMode == 'hybrid') {
      CloudSyncService.startPeriodicSync(updated);
    } else {
      CloudSyncService.stopPeriodicSync();
    }

    widget.onSettingsUpdated?.call(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(PosLocalization.tr(
                    'Cloud & MySQL Sync configuration saved successfully!',
                    settings: widget.settings)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _syncMode == mode;
    final localizedSubtitle =
        PosLocalization.trPrimary(subtitle, settings: widget.settings);
    final secondarySubtitle =
        PosLocalization.trSecondary(subtitle, settings: widget.settings);

    return InkWell(
      onTap: () => setState(() => _syncMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (mode == 'hybrid')
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            PosLocalization.tr('RECOMMENDED',
                                settings: widget.settings),
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizedSubtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                  if (secondarySubtitle != null &&
                      secondarySubtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondarySubtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            // ignore: deprecated_member_use
            Radio<String>(
              value: mode,
              // ignore: deprecated_member_use
              groupValue: _syncMode,
              activeColor: const Color(0xFF4F46E5),
              // ignore: deprecated_member_use
              onChanged: (val) {
                if (val != null) setState(() => _syncMode = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded,
                      color: Color(0xFF0EA5E9), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PosLocalization.tr('Cloud & MySQL Sync Engine',
                            settings: widget.settings),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PosLocalization.tr(
                            'Hybrid Local SQLite + Laravel / MySQL Sync Architecture',
                            settings: widget.settings),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(PosLocalization.tr('Save Settings',
                      settings: widget.settings)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _saveSettings,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Sync Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEEF2FF), Colors.white],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_syncMode == 'offline')
                          ? const Color(0xFF64748B).withValues(alpha: 0.2)
                          : const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_syncMode == 'offline')
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      color: (_syncMode == 'offline')
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF10B981),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              PosLocalization.trParams(
                                'Sync Status: {mode}',
                                {'mode': _syncMode.toUpperCase()},
                                settings: widget.settings,
                              ),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _pendingCount > 0
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                PosLocalization.trParams(
                                  '{count} Pending in Queue',
                                  {'count': '$_pendingCount'},
                                  settings: widget.settings,
                                ),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.settings.lastSyncTimestamp.isNotEmpty
                              ? PosLocalization.trParams(
                                  'Last Synced: {time}',
                                  {'time': widget.settings.lastSyncTimestamp},
                                  settings: widget.settings,
                                )
                              : PosLocalization.tr(
                                  'Last Synced: Never (Never synchronized with online server)',
                                  settings: widget.settings),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        if (_syncResult.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _syncResult,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(PosLocalization.tr('Sync Now',
                        settings: widget.settings)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSyncing ? null : _triggerSyncNow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Choose Operating Sync Mode
            Text(
              PosLocalization.tr('1. Deployment & Sync Mode',
                  settings: widget.settings),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              mode: 'offline',
              title:
                  PosLocalization.tr('Offline Only', settings: widget.settings),
              subtitle:
                  'Runs 100% locally on this computer. Zero internet or external database connection needed.',
              icon: Icons.computer_rounded,
              color: const Color(0xFF64748B),
            ),
            _buildModeOption(
              mode: 'hybrid',
              title: PosLocalization.tr('Both Online & Offline - Hybrid Sync',
                  settings: widget.settings),
              subtitle:
                  'Local SQLite guarantees instant billing without internet; automatically synchronizes with Laravel / MySQL server in the background.',
              icon: Icons.sync_alt_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildModeOption(
              mode: 'online',
              title: PosLocalization.tr('Online Cloud Server',
                  settings: widget.settings),
              subtitle:
                  'Connected directly to centralized Laravel REST API with local offline caching fallback.',
              icon: Icons.cloud_rounded,
              color: const Color(0xFF0EA5E9),
            ),

            const SizedBox(height: 24),

            // Section 2: Laravel / MySQL Server Configuration
            if (_syncMode != 'offline') ...[
              Text(
                PosLocalization.tr('2. Laravel / MySQL Server Configuration',
                    settings: widget.settings),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _urlCtrl,
                      decoration: InputDecoration(
                        labelText: PosLocalization.tr(
                            'Laravel REST API Base URL *',
                            settings: widget.settings),
                        hintText:
                            'http://localhost:8000/api or https://pos.yourdomain.com/api',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: const OutlineInputBorder(),
                        helperText: PosLocalization.tr(
                            'Endpoint where SyncController is hosted',
                            settings: widget.settings),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _apiKeyCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: PosLocalization.tr(
                                  'API Key / Bearer Secret Token',
                                  settings: widget.settings),
                              prefixIcon: const Icon(Icons.vpn_key_rounded),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _branchIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: PosLocalization.tr(
                                  'Branch / Outlet ID',
                                  settings: widget.settings),
                              prefixIcon: const Icon(Icons.store_rounded),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<int>(
                            initialValue: _intervalMinutes,
                            decoration: InputDecoration(
                              labelText: PosLocalization.tr(
                                  'Auto-Sync Interval',
                                  settings: widget.settings),
                              prefixIcon: const Icon(Icons.timer_rounded),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 0,
                                  child: Text(PosLocalization.tr('Manual Only',
                                      settings: widget.settings))),
                              DropdownMenuItem(
                                  value: 1,
                                  child: Text(PosLocalization.tr('Every 1 min',
                                      settings: widget.settings))),
                              DropdownMenuItem(
                                  value: 5,
                                  child: Text(PosLocalization.tr('Every 5 mins',
                                      settings: widget.settings))),
                              DropdownMenuItem(
                                  value: 15,
                                  child: Text(PosLocalization.tr(
                                      'Every 15 mins',
                                      settings: widget.settings))),
                              DropdownMenuItem(
                                  value: 30,
                                  child: Text(PosLocalization.tr(
                                      'Every 30 mins',
                                      settings: widget.settings))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _intervalMinutes = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check_rounded,
                                  size: 16),
                          label: Text(PosLocalization.tr('Test Connection',
                              settings: widget.settings)),
                          onPressed: _isTesting ? null : _testConnection,
                        ),
                        const SizedBox(width: 12),
                        if (_testResult.isNotEmpty)
                          Expanded(
                            child: Text(
                              _testResult,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _testSuccess
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Section 3: Laravel Backend Starter Kit Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded,
                      color: Color(0xFF10B981), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PosLocalization.tr(
                              'Laravel / React / Next.js Backend Templates Ready!',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          PosLocalization.tr(
                              'We have generated mysql_schema.sql and SyncController.php in the backend_resources/ folder. You can directly import them into your Laravel/MySQL project when building your online web portal.',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Pending Queue & Recent Activity Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  PosLocalization.tr('Recent Sync Queue & Activity Logs',
                      settings: widget.settings),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(PosLocalization.tr('Refresh Logs',
                      settings: widget.settings)),
                  onPressed: _loadQueueData,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: _logs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          PosLocalization.tr(
                              'No sync activity recorded yet. Items will appear here when saved in Hybrid mode.',
                              settings: widget.settings),
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, idx) {
                        final log = _logs[idx];
                        final status = log['status'] as String? ?? 'pending';
                        final isDone = status == 'synced';

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isDone
                                ? Icons.check_circle_outline
                                : Icons.pending_outlined,
                            color: isDone
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                          title: Text(
                            '${(log['action'] as String? ?? '').toUpperCase()} ${(log['entity_type'] as String? ?? '').toUpperCase()} #${log['entity_id']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Queued at: ${log['created_at'] ?? 'N/A'}${log['synced_at'] != null ? ' | Synced: ${log['synced_at']}' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
