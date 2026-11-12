import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../../services/database_service.dart';

class WooCommerceSyncScreen extends StatefulWidget {
  final BusinessSettings settings;

  const WooCommerceSyncScreen({super.key, required this.settings});

  @override
  State<WooCommerceSyncScreen> createState() => _WooCommerceSyncScreenState();
}

class _WooCommerceSyncScreenState extends State<WooCommerceSyncScreen> {
  final _urlCtrl = TextEditingController(text: 'https://myshop.com');
  final _ckCtrl = TextEditingController(text: '');
  final _csCtrl = TextEditingController(text: '');
  int? _configDbId;
  bool _autoSyncOrders = true;
  bool _isSyncing = false;

  List<Map<String, dynamic>> _syncLogs = [];

  @override
  void initState() {
    super.initState();
    _loadConfigAndLogs();
  }

  Future<void> _loadConfigAndLogs() async {
    final db = await DatabaseService.initialize();
    final cfgs = await db.getModuleRecords('woocommerce', recordType: 'config');
    if (cfgs.isNotEmpty) {
      final cfg = cfgs.first;
      _configDbId = cfg['_dbId'] as int?;
      _urlCtrl.text = (cfg['url'] as String?) ?? 'https://myshop.com';
      _ckCtrl.text = (cfg['ck'] as String?) ?? '';
      _csCtrl.text = (cfg['cs'] as String?) ?? '';
      _autoSyncOrders = (cfg['autoSync'] as bool?) ?? true;
    }
    final logs = await db.getModuleRecords('woocommerce', recordType: 'log');
    if (mounted) {
      setState(() => _syncLogs = logs);
    }
  }

  Future<void> _saveConfig({bool showToast = true}) async {
    final db = await DatabaseService.initialize();
    _configDbId = await db.saveModuleRecord(
      id: _configDbId,
      moduleKey: 'woocommerce',
      recordType: 'config',
      title: _urlCtrl.text.trim(),
      data: {
        'url': _urlCtrl.text.trim(),
        'ck': _ckCtrl.text.trim(),
        'cs': _csCtrl.text.trim(),
        'autoSync': _autoSyncOrders,
      },
    );
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WooCommerce API settings saved to SQLite.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _ckCtrl.dispose();
    _csCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerManualSync() async {
    final rawUrl = _urlCtrl.text.trim();
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Enter a valid store URL (https://...) before syncing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSyncing = true);
    await _saveConfig(showToast: false);
    String eventStatus = 'Failed';
    String eventDetails = '';
    try {
      final endpoint = parsed.resolve('/wp-json/wc/v3/system_status');
      final headers = <String, String>{};
      if (_ckCtrl.text.trim().isNotEmpty && _csCtrl.text.trim().isNotEmpty) {
        final creds = base64Encode(
            utf8.encode('${_ckCtrl.text.trim()}:${_csCtrl.text.trim()}'));
        headers['Authorization'] = 'Basic $creds';
      }
      final resp = await http
          .get(endpoint, headers: headers)
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        eventStatus = 'Success';
        eventDetails =
            'REST API reachable (${resp.statusCode}) at ${parsed.host}';
      } else {
        eventStatus = 'HTTP ${resp.statusCode}';
        eventDetails =
            'Endpoint ${endpoint.toString()} returned HTTP ${resp.statusCode}';
      }
    } catch (e) {
      eventStatus = 'Unreachable';
      eventDetails = 'Could not reach ${parsed.host}: $e';
    }

    final db = await DatabaseService.initialize();
    final logEntry = <String, dynamic>{
      'event': 'Manual Store Sync',
      'details': eventDetails,
      'status': eventStatus,
      'time': DateTime.now().toString().substring(0, 16),
    };
    await db.saveModuleRecord(
      moduleKey: 'woocommerce',
      recordType: 'log',
      title: eventStatus,
      status: eventStatus,
      data: logEntry,
    );
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncLogs.insert(0, logEntry);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eventDetails),
          backgroundColor: eventStatus == 'Success'
              ? const Color(0xFF10B981)
              : const Color(0xFFD97706),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded,
                color: Color(0xFF9333EA), size: 22),
            const SizedBox(width: 10),
            Text(
              'WooCommerce & Online Store Integration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9333EA),
                  foregroundColor: Colors.white),
              onPressed: _isSyncing ? null : _triggerManualSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded, size: 16),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync with Store Now'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Card
            Container(
              padding: const EdgeInsets.all(20),
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
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded,
                          color: Color(0xFF9333EA), size: 20),
                      const SizedBox(width: 8),
                      Text('WooCommerce REST API Configuration',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'WordPress / WooCommerce Store Website URL',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.link, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ckCtrl,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Consumer Key (ck_...)',
                            labelStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _csCtrl,
                          obscureText: true,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Consumer Secret (cs_...)',
                            labelStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Auto-fetch online customer orders every 5 minutes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text(
                        'Automatically imports web purchases into POS Sales List as pending orders',
                        style: TextStyle(fontSize: 11)),
                    value: _autoSyncOrders,
                    activeThumbColor: const Color(0xFF9333EA),
                    onChanged: (v) {
                      setState(() => _autoSyncOrders = v);
                      _saveConfig(showToast: false);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save API Credentials'),
                      onPressed: () => _saveConfig(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Sync Activity Logs
            Container(
              padding: const EdgeInsets.all(20),
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
                  Text('Recent Webhook & Sync Activity Logs',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _syncLogs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = _syncLogs[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cloud_done_rounded,
                                    color: Color(0xFF10B981), size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['event'] as String,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text(item['details'] as String,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            Text(item['time'] as String,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
