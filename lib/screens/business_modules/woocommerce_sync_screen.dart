import 'package:flutter/material.dart';
import '../../models/models.dart';

class WooCommerceSyncScreen extends StatefulWidget {
  final BusinessSettings settings;

  const WooCommerceSyncScreen({super.key, required this.settings});

  @override
  State<WooCommerceSyncScreen> createState() => _WooCommerceSyncScreenState();
}

class _WooCommerceSyncScreenState extends State<WooCommerceSyncScreen> {
  final _urlCtrl = TextEditingController(text: 'https://myshop.com');
  final _ckCtrl = TextEditingController(text: 'ck_7b92f9a1234567890abcdef');
  final _csCtrl = TextEditingController(text: 'cs_8c03e1b0987654321fedcba');
  bool _autoSyncOrders = true;
  bool _isSyncing = false;

  final List<Map<String, dynamic>> _syncLogs = [
    {'event': 'Catalog Sync', 'details': 'Synced 240 products to WooCommerce store', 'status': 'Success', 'time': '21 Oct, 04:30 PM'},
    {'event': 'Order Fetch', 'details': 'Imported 4 new web orders (#WC-1081 to #WC-1084)', 'status': 'Success', 'time': '21 Oct, 03:15 PM'},
    {'event': 'Inventory Update', 'details': 'Updated stock counts for 18 sold items', 'status': 'Success', 'time': '21 Oct, 02:00 PM'},
    {'event': 'Webhook Ping', 'details': 'Order status updated to Completed', 'status': 'Success', 'time': '20 Oct, 08:20 PM'},
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    _ckCtrl.dispose();
    _csCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _syncLogs.insert(0, {
          'event': 'Manual Full Sync',
          'details': 'Product catalog & inventory level synchronized successfully',
          'status': 'Success',
          'time': 'Just now',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WooCommerce store successfully synchronized!'), backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: Color(0xFF9333EA), size: 22),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), foregroundColor: Colors.white),
              onPressed: _isSyncing ? null : _triggerManualSync,
              icon: _isSyncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: Color(0xFF9333EA), size: 20),
                      const SizedBox(width: 8),
                      Text('WooCommerce REST API Configuration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'WordPress / WooCommerce Store Website URL',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.link, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ckCtrl,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Consumer Key (ck_...)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _csCtrl,
                          obscureText: true,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Consumer Secret (cs_...)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-fetch online customer orders every 5 minutes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Automatically imports web purchases into POS Sales List as pending orders', style: TextStyle(fontSize: 11)),
                    value: _autoSyncOrders,
                    activeThumbColor: const Color(0xFF9333EA),
                    onChanged: (v) => setState(() => _autoSyncOrders = v),
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
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Webhook & Sync Activity Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A))),
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
                                const Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['event'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                    const SizedBox(height: 2),
                                    Text(item['details'] as String, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            Text(item['time'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
