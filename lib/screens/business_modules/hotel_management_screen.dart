import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class HotelManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const HotelManagementScreen({super.key, required this.settings});

  @override
  State<HotelManagementScreen> createState() => _HotelManagementScreenState();
}

class _HotelManagementScreenState extends State<HotelManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.initialize();
      final rows = await db.getHotelRooms();
      setState(() {
        _rooms = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddRoomModal() async {
    final roomNoCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Executive Deluxe');
    final floorCtrl = TextEditingController(text: '1st Floor');
    final rateCtrl = TextEditingController(text: '7500');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Add New Room to Hotel',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNoCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Room Number (e.g. 301)*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Room Category / Type',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: floorCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Floor Location (e.g. 3rd Floor)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Nightly Rate (${widget.settings.currencySymbol})',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: () async {
                if (roomNoCtrl.text.trim().isNotEmpty) {
                  final db = await DatabaseService.initialize();
                  await db.addHotelRoom({
                    'room': roomNoCtrl.text.trim(),
                    'type': typeCtrl.text.trim(),
                    'floor': floorCtrl.text.trim(),
                    'rate': double.tryParse(rateCtrl.text.trim()) ?? 7500.0,
                    'status': 'available',
                    'guest': '',
                    'nights': 0,
                    'check_in': '',
                    'room_service': 0.0,
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadRooms();
                }
              },
              child: const Text('Add Room'),
            ),
          ],
        );
      },
    );
  }

  void _showCheckInModal(Map<String, dynamic> room) {
    final guestCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nightsCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Check-In Room ${room['room']}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: guestCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Primary Guest Full Name*',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cnicCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'CNIC / National ID / Passport No.*',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nightsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Number of Nights Stay',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: () async {
                if (guestCtrl.text.trim().isNotEmpty && room['id'] != null) {
                  final db = await DatabaseService.initialize();
                  await db.updateHotelRoom(room['id'] as int, {
                    'status': 'occupied',
                    'guest': '${guestCtrl.text.trim()} (CNIC: ${cnicCtrl.text.trim()})',
                    'nights': int.tryParse(nightsCtrl.text) ?? 1,
                    'check_in': 'Today',
                    'room_service': 0.0,
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadRooms();
                }
              },
              child: const Text('Confirm Check-In'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkOut(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    final db = await DatabaseService.initialize();
    await db.updateHotelRoom(id, {
      'status': 'cleaning',
      'guest': '',
      'nights': 0,
      'check_in': '',
      'room_service': 0.0,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room ${room['room']} checked out. Marked for housekeeping/cleaning.')),
      );
    }
    _loadRooms();
  }

  Future<void> _markAvailable(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    final db = await DatabaseService.initialize();
    await db.updateHotelRoom(id, {
      'status': 'available',
    });
    _loadRooms();
  }

  Future<void> _addServiceCharge(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    final current = (room['room_service'] is num) ? (room['room_service'] as num).toDouble() : 0.0;
    final db = await DatabaseService.initialize();
    await db.updateHotelRoom(id, {
      'room_service': current + 500.0,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room service order of Rs 500 added to Room ${room['room']}')),
      );
    }
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final totalRooms = _rooms.length;
    final occupiedRooms = _rooms.where((r) => r['status'] == 'occupied').length;
    final availableRooms = _rooms.where((r) => r['status'] == 'available').length;
    final cleaningRooms = _rooms.where((r) => r['status'] == 'cleaning').length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.hotel_rounded, color: Color(0xFF3B82F6), size: 22),
            const SizedBox(width: 10),
            Text(
              'Hotel & Room Management System',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh SQLite Data',
            onPressed: _loadRooms,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: _showAddRoomModal,
              icon: const Icon(Icons.add_home_work_rounded, size: 16),
              label: const Text('Add Room'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Metric Badges
                  Row(
                    children: [
                      _metric('Total Rooms', '$totalRooms', const Color(0xFF6366F1), isDark),
                      const SizedBox(width: 14),
                      _metric('Occupied Rooms', '$occupiedRooms', const Color(0xFF3B82F6), isDark),
                      const SizedBox(width: 14),
                      _metric('Available Rooms', '$availableRooms', const Color(0xFF10B981), isDark),
                      const SizedBox(width: 14),
                      _metric('Cleaning / Maint.', '$cleaningRooms', const Color(0xFFF59E0B), isDark),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Room Cards Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: _rooms.length,
                    itemBuilder: (context, idx) {
                      final r = _rooms[idx];
                      final status = r['status']?.toString() ?? 'available';
                      Color statusColor = const Color(0xFF10B981);
                      if (status == 'occupied') statusColor = const Color(0xFF3B82F6);
                      if (status == 'cleaning') statusColor = const Color(0xFFF59E0B);

                      final rateVal = (r['rate'] is num) ? (r['rate'] as num).toDouble() : 0.0;
                      final nightsVal = (r['nights'] is num) ? (r['nights'] as num).toInt() : 0;
                      final roomServiceVal = (r['room_service'] is num) ? (r['room_service'] as num).toDouble() : 0.0;
                      final totalBill = (rateVal * nightsVal) + roomServiceVal;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Room ${r['room']}',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('(${r['type'] ?? ''})', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Floor: ${r['floor'] ?? '1st Floor'} • Rate: $currency${rateVal.toStringAsFixed(0)} / night',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            if (status == 'occupied') ...[
                              Text(
                                'Guest: ${r['guest'] ?? 'Guest'}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Stay: $nightsVal Nights • Service: $currency${roomServiceVal.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              Text(
                                'Total Bill: $currency${totalBill.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF3B82F6)),
                              ),
                            ] else ...[
                              Text(
                                status == 'cleaning' ? 'Room is undergoing sanitization' : 'Ready for guest check-in (SQLite Saved)',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'available')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _showCheckInModal(r),
                                    child: const Text('Check-In', style: TextStyle(fontSize: 11)),
                                  )
                                else if (status == 'occupied')
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), visualDensity: VisualDensity.compact),
                                        onPressed: () => _addServiceCharge(r),
                                        child: const Text('+ Service', style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _checkOut(r),
                                        child: const Text('Check-Out', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _markAvailable(r),
                                    child: const Text('Mark Available', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metric(String title, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}
