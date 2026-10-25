import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class GymFitnessScreen extends StatefulWidget {
  final BusinessSettings settings;

  const GymFitnessScreen({super.key, required this.settings});

  @override
  State<GymFitnessScreen> createState() => _GymFitnessScreenState();
}

class _GymFitnessScreenState extends State<GymFitnessScreen> {
  String _filter = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.initialize();
      final rows = await db.getGymMembers(status: _filter);
      setState(() {
        _members = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renewMembership(Map<String, dynamic> m) async {
    final id = m['id'] as int?;
    if (id == null) return;
    try {
      final db = await DatabaseService.initialize();
      await db.updateGymMember(id, {
        'status': 'Active',
        'days_left': 30,
        'expiry_date': '30 Days Added (${DateTime.now().add(const Duration(days: 30)).toString().substring(0, 10)})',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Membership renewed for 30 days for ${m['name']}'),
          ),
        );
      }
      _loadMembers();
    } catch (_) {}
  }

  Future<void> _deleteMember(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to remove "$name" from membership?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DatabaseService.initialize();
      await db.deleteGymMember(id);
      _loadMembers();
    }
  }

  void _showAddMemberModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final lockerCtrl = TextEditingController();
    final trainerCtrl = TextEditingController(text: 'General Floor');
    final feeCtrl = TextEditingController(text: '4000');
    String plan = 'Monthly Basic (Rs 4,000)';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Register New Gym Member',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Member Full Name*',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number*',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lockerCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Assigned Locker (e.g. L-15)',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trainerCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Assigned Trainer',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Membership Fee Amount',
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final db = await DatabaseService.initialize();
                  await db.addGymMember({
                    'member_id': 'GYM-${101 + _members.length}',
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'plan': plan,
                    'fee': double.tryParse(feeCtrl.text.trim()) ?? 4000.0,
                    'locker': lockerCtrl.text.trim().isEmpty ? 'None' : lockerCtrl.text.trim(),
                    'trainer': trainerCtrl.text.trim().isEmpty ? 'General Floor' : trainerCtrl.text.trim(),
                    'expiry_date': DateTime.now().add(const Duration(days: 30)).toString().substring(0, 10),
                    'days_left': 30,
                    'status': 'Active',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  if (mounted) Navigator.pop(ctx);
                  _loadMembers();
                }
              },
              child: const Text('Register Member'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.fitness_center_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Text(
              'Gym & Fitness Club Membership Tracker',
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
            tooltip: 'Reload SQLite Data',
            onPressed: _loadMembers,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: _showAddMemberModal,
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add Member'),
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
                  // Filter Pills
                  Row(
                    children: [
                      for (final f in ['All', 'Active', 'Expiring Soon', 'Expired'])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: _filter == f,
                            selectedColor: const Color(0xFFEF4444),
                            labelStyle: TextStyle(
                              color: _filter == f ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _filter = f);
                                _loadMembers();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Members Table Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Members Directory (${_members.length} Enrolled in SQLite)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('SQLite Synced', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (_members.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.fitness_center_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                                  const SizedBox(height: 12),
                                  Text('No gym members found for filter: $_filter', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                                ],
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              columns: [
                                DataColumn(label: Text('MEMBER', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('MEMBERSHIP PLAN', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('FEE / RATE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('LOCKER / TRAINER', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('EXPIRY DATE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                                DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                              ],
                              rows: _members.map((m) {
                                final status = m['status']?.toString() ?? 'Active';
                                Color statusColor = const Color(0xFF10B981);
                                if (status == 'Expiring Soon') statusColor = const Color(0xFFF59E0B);
                                if (status == 'Expired') statusColor = const Color(0xFFEF4444);

                                final feeVal = (m['fee'] is num) ? (m['fee'] as num).toDouble() : 0.0;
                                final nameVal = m['name']?.toString() ?? 'Member';
                                final memberCode = m['member_id']?.toString() ?? m['id']?.toString() ?? 'GYM';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                            child: Text(
                                              nameVal.isNotEmpty ? nameVal.substring(0, 1) : 'M',
                                              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(nameVal, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                              Text('$memberCode • ${m['phone'] ?? ''}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(m['plan']?.toString() ?? 'Standard', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
                                    DataCell(Text('$currency${feeVal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                                    DataCell(Text('${m['locker'] ?? 'None'} | ${m['trainer'] ?? 'General'}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                                    DataCell(Text(m['expiry_date']?.toString() ?? m['expiry']?.toString() ?? 'Active', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.how_to_reg, size: 18, color: Color(0xFF10B981)),
                                            tooltip: 'Mark Attendance Check-In',
                                            onPressed: () {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Attendance recorded for $nameVal')),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF3B82F6)),
                                            tooltip: 'Renew Membership (+30 Days)',
                                            onPressed: () => _renewMembership(m),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            tooltip: 'Delete Member',
                                            onPressed: () {
                                              if (m['id'] is int) {
                                                _deleteMember(m['id'] as int, nameVal);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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
