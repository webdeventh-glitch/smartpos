import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/cloud_sync_service.dart';

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
    _branchIdCtrl = TextEditingController(text: widget.settings.syncBranchId.toString());
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
    } catch (_) {}
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Pinging server...';
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
      _syncResult = 'Starting bidirectional sync...';
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
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Cloud & MySQL Sync configuration saved successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildModeOption({
    required String mode,
    required String title,
    required String subtitle,
    required String urduDesc,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _syncMode == mode;

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
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (mode == 'hybrid')
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECOMMENDED',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    urduDesc,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: mode,
              groupValue: _syncMode,
              activeColor: const Color(0xFF4F46E5),
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
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
                  child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0EA5E9), size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud & MySQL Sync Engine',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Hybrid Local SQLite + Laravel / MySQL Sync Architecture (آن لائن و آف لائن ڈیٹا سنک)',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Settings (محفوظ کریں)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC7D2FE)),
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
                      color: (_syncMode == 'offline') ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
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
                              'Sync Status: ${_syncMode.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_pendingCount Pending in Queue',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.settings.lastSyncTimestamp.isNotEmpty
                              ? 'Last Synced: ${widget.settings.lastSyncTimestamp}'
                              : 'Last Synced: Never (Never synchronized with online server)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        if (_syncResult.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _syncResult,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: _isSyncing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Sync Now (ابھی سنک کریں)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSyncing ? null : _triggerSyncNow,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Choose Operating Sync Mode
            const Text(
              '1. Deployment & Sync Mode (آپریٹنگ موڈ منتخب کریں)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              mode: 'offline',
              title: 'Offline Only (صرف آف لائن لوکل SQLite)',
              subtitle: 'Runs 100% locally on this computer. Zero internet or external database connection needed.',
              urduDesc: 'کوئی انٹرنیٹ درکار نہیں، سارا ڈیٹا اسی کمپیوٹر میں محفوظ رہتا ہے',
              icon: Icons.computer_rounded,
              color: const Color(0xFF64748B),
            ),
            _buildModeOption(
              mode: 'hybrid',
              title: 'Both Online & Offline - Hybrid Sync (آن لائن اور آف لائن دونوں)',
              subtitle: 'Local SQLite guarantees instant billing without internet; automatically synchronizes with Laravel / MySQL server in the background.',
              urduDesc: 'بلنگ تیز رفتار لوکل ڈیٹا بیس میں ہوتی ہے اور انٹرنیٹ ملنے پر ڈیٹا ویب سرور پر سنک ہو جاتا ہے',
              icon: Icons.sync_alt_rounded,
              color: const Color(0xFF10B981),
            ),
            _buildModeOption(
              mode: 'online',
              title: '️ Online Cloud Server (ڈائریکٹ کلاؤڈ API)',
              subtitle: 'Connected directly to centralized Laravel REST API with local offline caching fallback.',
              urduDesc: 'مرکزی کلاؤڈ سرور سے لائیو منسلک رہتا ہے',
              icon: Icons.cloud_rounded,
              color: const Color(0xFF0EA5E9),
            ),

            const SizedBox(height: 24),

            // Section 2: Laravel / MySQL Server Configuration
            if (_syncMode != 'offline') ...[
              const Text(
                '2. Laravel / MySQL Server Configuration (آن لائن سرور سیٹنگز)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Laravel REST API Base URL *',
                        hintText: 'http://localhost:8000/api or https://pos.yourdomain.com/api',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(),
                        helperText: 'Endpoint where SyncController is hosted',
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
                            decoration: const InputDecoration(
                              labelText: 'API Key / Bearer Secret Token',
                              prefixIcon: Icon(Icons.vpn_key_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _branchIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Branch / Outlet ID',
                              prefixIcon: Icon(Icons.store_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<int>(
                            value: _intervalMinutes,
                            decoration: const InputDecoration(
                              labelText: 'Auto-Sync Interval',
                              prefixIcon: Icon(Icons.timer_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Manual Only')),
                              DropdownMenuItem(value: 1, child: Text('Every 1 min')),
                              DropdownMenuItem(value: 5, child: Text('Every 5 mins')),
                              DropdownMenuItem(value: 15, child: Text('Every 15 mins')),
                              DropdownMenuItem(value: 30, child: Text('Every 30 mins')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _intervalMinutes = val);
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
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check_rounded, size: 16),
                          label: const Text('Test Connection (کنکشن چیک کریں)'),
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
                                color: _testSuccess ? const Color(0xFF10B981) : Colors.redAccent,
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
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.terminal_rounded, color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laravel / React / Next.js Backend Templates Ready!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'We have generated mysql_schema.sql and SyncController.php in the backend_resources/ folder. You can directly import them into your Laravel/MySQL project when building your online web portal.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
                const Text(
                  'Recent Sync Queue & Activity Logs',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Logs'),
                  onPressed: _loadQueueData,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: _logs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No sync activity recorded yet. Items will appear here when saved in Hybrid mode.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (context, idx) {
                        final log = _logs[idx];
                        final status = log['status'] as String? ?? 'pending';
                        final isDone = status == 'synced';

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isDone ? Icons.check_circle_outline : Icons.pending_outlined,
                            color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                          title: Text(
                            '${(log['action'] as String? ?? '').toUpperCase()} ${(log['entity_type'] as String? ?? '').toUpperCase()} #${log['entity_id']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Queued at: ${log['created_at'] ?? 'N/A'}${log['synced_at'] != null ? ' | Synced: ${log['synced_at']}' : ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
