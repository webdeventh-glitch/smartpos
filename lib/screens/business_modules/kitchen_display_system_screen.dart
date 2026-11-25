import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/lan_realtime_service.dart';
import '../../services/localization_service.dart';

class KitchenDisplaySystemScreen extends StatefulWidget {
  final BusinessSettings settings;

  const KitchenDisplaySystemScreen({super.key, required this.settings});

  @override
  State<KitchenDisplaySystemScreen> createState() =>
      _KitchenDisplaySystemScreenState();
}

class _KitchenDisplaySystemScreenState
    extends State<KitchenDisplaySystemScreen> {
  List<Map<String, dynamic>> _kotOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'Active'; // 'Active', 'Cooking', 'Ready', 'All'
  Timer? _refreshTimer;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  StreamSubscription? _lanSubscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Auto-refresh orders every 10 seconds for real-time kitchen updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadOrders(silent: true);
    });
    // Live digital clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // Listen to real-time LAN socket events
    _lanSubscription = LanRealtimeService.instance.events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'kot_updated' ||
          type == 'drafts_updated' ||
          type == 'stock_changed') {
        if (mounted) _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _lanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final db = await DatabaseService.initialize();
      final orders = await db.getRestaurantKotOrders();
      if (mounted) {
        setState(() {
          _kotOrders = List<Map<String, dynamic>>.from(orders);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      final db = await DatabaseService.initialize();
      await db.updateRestaurantKotStatus(id, newStatus);
      LanRealtimeService.instance
          .notifyLocalEvent('kot_updated', {'id': id, 'status': newStatus});
      await _loadOrders(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PosLocalization.trParams(
                'KOT status updated to {status}',
                {
                  'status':
                      PosLocalization.tr(newStatus, settings: widget.settings)
                },
                settings: widget.settings)),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(PosLocalization.trParams(
                'Failed to update KOT status: {error}', {'error': '$e'},
                settings: widget.settings)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'Active') {
      return _kotOrders
          .where((k) => (k['status'] ?? 'Cooking') != 'Served')
          .toList();
    } else if (_selectedFilter == 'All') {
      return _kotOrders;
    } else {
      return _kotOrders
          .where((k) =>
              (k['status'] ?? 'Cooking').toString().toLowerCase() ==
              _selectedFilter.toLowerCase())
          .toList();
    }
  }

  int _calculateElapsedMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0;
    try {
      final now = DateTime.now();
      // Check if format is "HH:mm" or "hh:mm a"
      if (timeStr.contains(':')) {
        final parts = timeStr.trim().split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);
        if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
          hour += 12;
        } else if (parts.length > 1 &&
            parts[1].toUpperCase() == 'AM' &&
            hour == 12) {
          hour = 0;
        }
        final ticketTime = DateTime(now.year, now.month, now.day, hour, minute);
        final diff = now.difference(ticketTime).inMinutes;
        return diff >= 0 ? diff : 0;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _kotOrders.where((k) => (k['status'] ?? 'Cooking') != 'Served').length;
    final cookingCount =
        _kotOrders.where((k) => (k['status'] ?? '') == 'Cooking').length;
    final readyCount =
        _kotOrders.where((k) => (k['status'] ?? '') == 'Ready').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep dark theme for KDS
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 16,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.soup_kitchen_rounded,
                  color: Color(0xFFF97316), size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PosLocalization.tr('Kitchen Display System (KDS)',
                      settings: widget.settings),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  PosLocalization.trParams(
                      'Live KOT Queue • {business}',
                      {
                        'business': widget.settings.businessName.isNotEmpty
                            ? widget.settings.businessName
                            : PosLocalization.tr('Restaurant',
                                settings: widget.settings)
                      },
                      settings: widget.settings),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Live Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_filled,
                    color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 8),
                Text(
                  DateFormat('hh:mm:ss a').format(_currentTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Refresh Button
          IconButton(
            tooltip: PosLocalization.tr('Refresh KOT Orders',
                settings: widget.settings),
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadOrders(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Top Metrics & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(
                top: BorderSide(color: Color(0xFF334155)),
                bottom: BorderSide(color: Color(0xFF334155)),
              ),
            ),
            child: Row(
              children: [
                // KPI Counters
                _buildKpiChip(
                    PosLocalization.tr('Active Orders',
                        settings: widget.settings),
                    '$activeCount',
                    const Color(0xFF38BDF8)),
                const SizedBox(width: 12),
                _buildKpiChip(
                    PosLocalization.tr('In Prep (Cooking)',
                        settings: widget.settings),
                    '$cookingCount',
                    const Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                _buildKpiChip(
                    PosLocalization.tr('Ready to Serve',
                        settings: widget.settings),
                    '$readyCount',
                    const Color(0xFF10B981)),
                const Spacer(),
                // Filter Tabs
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip(
                        'Active',
                        PosLocalization.trParams(
                            'Active ({count})', {'count': '$activeCount'},
                            settings: widget.settings)),
                    _buildFilterChip(
                        'Cooking',
                        PosLocalization.trParams(
                            'Cooking ({count})', {'count': '$cookingCount'},
                            settings: widget.settings)),
                    _buildFilterChip(
                        'Ready',
                        PosLocalization.trParams(
                            'Ready ({count})', {'count': '$readyCount'},
                            settings: widget.settings)),
                    _buildFilterChip(
                        'All',
                        PosLocalization.trParams('All Orders ({count})',
                            {'count': '${_kotOrders.length}'},
                            settings: widget.settings)),
                  ],
                ),
              ],
            ),
          ),

          // Main KOT Cards Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF97316)))
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 64,
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.6)),
                            const SizedBox(height: 16),
                            Text(
                              PosLocalization.tr('All Kitchen Orders Cleared!',
                                  settings: widget.settings),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              PosLocalization.tr(
                                  'New food orders sent from POS or Waiters will automatically pop up here.',
                                  settings: widget.settings),
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 360,
                          mainAxisExtent: 420,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final kot = _filteredOrders[index];
                          return _buildKotCard(kot);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF97316) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFF97316) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildKotCard(Map<String, dynamic> kot) {
    final id = kot['id'] as int? ?? 0;
    final kotNo = kot['kot_no'] ?? kot['kotNo'] ?? 'KOT-#';
    final tableName = kot['table_name'] ?? kot['table'] ?? 'Table';
    final orderType = kot['order_type'] ?? kot['type'] ?? 'Dine-In';
    final status = (kot['status'] as String? ?? 'Cooking');
    final timeStr = kot['time'] as String? ?? '';
    final serverName = kot['server_name'] ?? kot['serverName'] ?? 'Captain';
    final itemsStr = (kot['items'] as String? ?? '').trim();
    final elapsedMinutes = _calculateElapsedMinutes(timeStr);

    // Color logic based on status and elapsed time
    Color statusColor = const Color(0xFFF59E0B); // Amber for cooking
    if (status == 'Ready') {
      statusColor = const Color(0xFF10B981); // Emerald
    } else if (status == 'Served') {
      statusColor = const Color(0xFF64748B); // Slate
    } else if (elapsedMinutes >= 20) {
      statusColor = const Color(0xFFEF4444); // Urgent red if > 20 mins!
    }

    // Split items by comma or newline for neat itemized rows
    final itemLines = itemsStr.contains(',')
        ? itemsStr
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : itemsStr
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: elapsedMinutes >= 20 && status != 'Served' && status != 'Ready'
              ? const Color(0xFFEF4444)
              : statusColor.withValues(alpha: 0.5),
          width: elapsedMinutes >= 20 && status != 'Served' ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$kotNo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      PosLocalization.trParams(
                          '{type} • {server}',
                          {
                            'type': PosLocalization.tr(orderType.toString(),
                                settings: widget.settings),
                            'server': '$serverName',
                          },
                          settings: widget.settings),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    tableName.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Elapsed Timer & Order Time Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 13,
                        color: elapsedMinutes >= 20
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      timeStr.isNotEmpty
                          ? timeStr
                          : PosLocalization.tr('Just now',
                              settings: widget.settings),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: elapsedMinutes >= 20
                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    elapsedMinutes > 0
                        ? PosLocalization.trParams('{minutes}m elapsed',
                            {'minutes': '$elapsedMinutes'},
                            settings: widget.settings)
                        : PosLocalization.tr('< 1m elapsed',
                            settings: widget.settings),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: elapsedMinutes >= 20
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: itemLines.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Color(0xFF334155), height: 12),
              itemBuilder: (context, idx) {
                final item = itemLines[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4, right: 8),
                      child:
                          Icon(Icons.circle, size: 6, color: Color(0xFFF97316)),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Action Buttons Footer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                if (status != 'Cooking' &&
                    status != 'Ready' &&
                    status != 'Served')
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _updateStatus(id, 'Cooking'),
                      icon: const Icon(Icons.restaurant, size: 15),
                      label: Text(
                          PosLocalization.tr('Cook', settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                if (status == 'Cooking') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _updateStatus(id, 'Ready'),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: Text(
                          PosLocalization.tr('Mark Ready',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
                if (status == 'Ready') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _updateStatus(id, 'Served'),
                      icon: const Icon(Icons.done_all, size: 15),
                      label: Text(
                          PosLocalization.tr('Served',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
                if (status == 'Served') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _updateStatus(id, 'Cooking'),
                      icon: const Icon(Icons.replay, size: 15),
                      label: Text(
                          PosLocalization.tr('Re-open',
                              settings: widget.settings),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
