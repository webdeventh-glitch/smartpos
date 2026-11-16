import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
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
      final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();

      // Automated membership expiry detection & auto-synchronization
      final now = DateTime.now();
      for (final m in list) {
        final id = m['id'] as int?;
        if (id == null) continue;

        final expStr = m['expiry_date']?.toString() ?? '';
        DateTime? expDate;
        try {
          final regExp = RegExp(r'\d{4}-\d{2}-\d{2}');
          final match = regExp.firstMatch(expStr);
          if (match != null) {
            expDate = DateTime.tryParse(match.group(0)!);
          }
        } catch (_) {}

        int daysLeft =
            (m['days_left'] is num) ? (m['days_left'] as num).toInt() : 0;
        final currentStatus = m['status']?.toString() ?? 'Active';

        if (expDate != null) {
          final diff = expDate.difference(now).inDays;
          daysLeft = diff;
        }

        String newStatus = currentStatus;
        if (daysLeft <= 0) {
          newStatus = 'Expired';
          daysLeft = 0;
        } else if (daysLeft <= 3) {
          newStatus = 'Expiring Soon';
        } else {
          newStatus = 'Active';
        }

        if (newStatus != currentStatus ||
            daysLeft != (m['days_left'] as num?)?.toInt()) {
          m['status'] = newStatus;
          m['days_left'] = daysLeft;
          await db.updateGymMember(id, {
            'status': newStatus,
            'days_left': daysLeft,
          });
        }
      }

      setState(() {
        _members = list;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.warning('GymFitnessScreen', 'Failed loading members', e, st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTurnstileCheckInDialog() {
    final searchCtrl = TextEditingController();
    Map<String, dynamic>? selectedMember;
    String? scanStatus; // 'granted', 'denied', 'not_found'
    String statusMessage = '';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void performScan(String rawQuery) async {
              final query = rawQuery.trim().toLowerCase();
              if (query.isEmpty) return;

              Map<String, dynamic>? found;
              for (final m in _members) {
                final memId = (m['member_id']?.toString() ?? '').toLowerCase();
                final phone = (m['phone']?.toString() ?? '').toLowerCase();
                final name = (m['name']?.toString() ?? '').toLowerCase();
                final barcode = (m['barcode']?.toString() ?? '').toLowerCase();
                final idStr = (m['id']?.toString() ?? '');

                if (memId == query ||
                    phone == query ||
                    phone.contains(query) ||
                    barcode == query ||
                    idStr == query ||
                    name.contains(query)) {
                  found = m;
                  break;
                }
              }

              if (found == null) {
                setDialogState(() {
                  selectedMember = null;
                  scanStatus = 'not_found';
                  statusMessage =
                      'Card / Barcode "$rawQuery" not registered in system';
                });
                return;
              }

              final daysLeft = (found['days_left'] is num)
                  ? (found['days_left'] as num).toInt()
                  : 0;
              final status = found['status']?.toString() ?? 'Active';

              if (status == 'Expired' || daysLeft <= 0) {
                setDialogState(() {
                  selectedMember = found;
                  scanStatus = 'denied';
                  statusMessage =
                      'ACCESS DENIED: Membership expired on ${found!['expiry_date']}';
                });
              } else {
                // Access Granted! Log checkin
                final db = await DatabaseService.initialize();
                await db.saveModuleRecord(
                  moduleKey: 'gym',
                  recordType: 'gym_checkin',
                  title: 'Turnstile: ${found['name']}',
                  status: 'checked_in',
                  data: {
                    'memberId': found['id'],
                    'memberCode': found['member_id'],
                    'name': found['name'],
                    'phone': found['phone'],
                    'locker': found['locker'],
                    'plan': found['plan'],
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );

                setDialogState(() {
                  selectedMember = found;
                  scanStatus = 'granted';
                  statusMessage = (status == 'Expiring Soon')
                      ? 'ACCESS GRANTED • Expiring in $daysLeft Days!'
                      : 'ACCESS GRANTED • Welcome, ${found!['name']}!';
                });
              }
            }

            Color statusBgColor = const Color(0xFF3B82F6);
            if (scanStatus == 'granted') {
              statusBgColor = const Color(0xFF10B981);
            }
            if (scanStatus == 'denied' || scanStatus == 'not_found') {
              statusBgColor = const Color(0xFFEF4444);
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded,
                      color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Gym Turnstile Barcode Check-In Gate',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scanner Barcode Input Field
                      TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Scan Card Barcode or Enter Member ID / Phone...',
                          prefixIcon:
                              const Icon(Icons.barcode_reader, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: () => performScan(searchCtrl.text),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (val) => performScan(val),
                      ),
                      const SizedBox(height: 18),

                      // Visual Result Card (Green / Red / Neutral)
                      if (scanStatus != null) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: statusBgColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: statusBgColor, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                scanStatus == 'granted'
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: statusBgColor,
                                size: 54,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                scanStatus == 'granted'
                                    ? 'ACCESS GRANTED'
                                    : (scanStatus == 'denied'
                                        ? 'ACCESS DENIED'
                                        : 'CARD NOT FOUND'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: statusBgColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (selectedMember != null) ...[
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Member Name:'),
                                    Text(
                                      selectedMember!['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Membership Plan:'),
                                    Text(
                                      selectedMember!['plan'] ?? 'Standard',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Locker & Trainer:'),
                                    Text(
                                      '${selectedMember!['locker'] ?? 'None'} • ${selectedMember!['trainer'] ?? 'General'}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Days Remaining:'),
                                    Text(
                                      '${selectedMember!['days_left']} Days Left',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: scanStatus == 'granted'
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                                if (scanStatus == 'denied') ...[
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.autorenew_rounded,
                                        size: 16),
                                    label: const Text(
                                        'Instant Renew Membership (+30 Days)'),
                                    onPressed: () async {
                                      await _renewMembership(selectedMember!);
                                      setDialogState(() {
                                        scanStatus = 'granted';
                                        statusMessage =
                                            'Renewed for 30 Days! Access Granted.';
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.contactless_rounded,
                                  size: 48,
                                  color: isDark
                                      ? const Color(0xFF475569)
                                      : const Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                'Awaiting barcode card swipe or scanner trigger...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadMembers();
                  },
                  child: const Text('Close Gate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _renewMembership(Map<String, dynamic> m) async {
    final id = m['id'] as int?;
    if (id == null) return;
    try {
      final db = await DatabaseService.initialize();
      await db.updateGymMember(id, {
        'status': 'Active',
        'days_left': 30,
        'expiry_date':
            '30 Days Added (${DateTime.now().add(const Duration(days: 30)).toString().substring(0, 10)})',
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
    } catch (e, st) {
      AppLogger.error(
          'GymFitness', 'Failed renewing membership for ${m['name']}', e, st);
      if (mounted) {
        await AppErrorHandler.showErrorDialog(
          context,
          title: 'Renewal Failed',
          message: 'Could not renew membership for ${m['name'] ?? 'member'}.',
          error: e,
          stackTrace: st,
          tag: 'GymFitness',
        );
      }
    }
  }

  Future<void> _deleteMember(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content:
            Text('Are you sure you want to remove "$name" from membership?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
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
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Member Full Name*',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number*',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lockerCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Assigned Locker (e.g. L-15)',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trainerCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Assigned Trainer',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Membership Fee Amount',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final db = await DatabaseService.initialize();
                  await db.addGymMember({
                    'member_id': 'GYM-${101 + _members.length}',
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'plan': plan,
                    'fee': double.tryParse(feeCtrl.text.trim()) ?? 4000.0,
                    'locker': lockerCtrl.text.trim().isEmpty
                        ? 'None'
                        : lockerCtrl.text.trim(),
                    'trainer': trainerCtrl.text.trim().isEmpty
                        ? 'General Floor'
                        : trainerCtrl.text.trim(),
                    'expiry_date': DateTime.now()
                        .add(const Duration(days: 30))
                        .toString()
                        .substring(0, 10),
                    'days_left': 30,
                    'status': 'Active',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
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
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.fitness_center_rounded,
                color: Color(0xFFEF4444), size: 22),
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white),
              onPressed: _showTurnstileCheckInDialog,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Turnstile Check-In (کارڈ سکین)'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload SQLite Data',
            onPressed: _loadMembers,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white),
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
                  // Automated Expiry Notice Banner
                  Builder(
                    builder: (context) {
                      final expiredCount = _members
                          .where((m) => m['status'] == 'Expired')
                          .length;
                      final expiringSoonCount = _members
                          .where((m) => m['status'] == 'Expiring Soon')
                          .length;
                      if (expiredCount == 0 && expiringSoonCount == 0) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded,
                                color: Color(0xFFF59E0B), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Membership Expiry Notice: $expiredCount members have expired and $expiringSoonCount members are expiring within 3 days. Send renewal alerts via WhatsApp/SMS.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                            if (expiredCount > 0)
                              TextButton(
                                onPressed: () {
                                  setState(() => _filter = 'Expired');
                                  _loadMembers();
                                },
                                child: const Text('View Expired',
                                    style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Filter Pills
                  Row(
                    children: [
                      for (final f in [
                        'All',
                        'Active',
                        'Expiring Soon',
                        'Expired'
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: _filter == f,
                            selectedColor: const Color(0xFFEF4444),
                            labelStyle: TextStyle(
                              color: _filter == f
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
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
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
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
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('SQLite Synced',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold)),
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
                                  Icon(Icons.fitness_center_outlined,
                                      size: 48,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26),
                                  const SizedBox(height: 12),
                                  Text(
                                      'No gym members found for filter: $_filter',
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54)),
                                ],
                              ),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC)),
                              columns: [
                                DataColumn(
                                    label: Text('MEMBER',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('MEMBERSHIP PLAN',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('FEE / RATE',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('LOCKER / TRAINER',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('EXPIRY DATE',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('STATUS',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                                DataColumn(
                                    label: Text('ACTIONS',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF475569)))),
                              ],
                              rows: _members.map((m) {
                                final status =
                                    m['status']?.toString() ?? 'Active';
                                Color statusColor = const Color(0xFF10B981);
                                if (status == 'Expiring Soon') {
                                  statusColor = const Color(0xFFF59E0B);
                                }
                                if (status == 'Expired') {
                                  statusColor = const Color(0xFFEF4444);
                                }

                                final feeVal = (m['fee'] is num)
                                    ? (m['fee'] as num).toDouble()
                                    : 0.0;
                                final nameVal =
                                    m['name']?.toString() ?? 'Member';
                                final memberCode = m['member_id']?.toString() ??
                                    m['id']?.toString() ??
                                    'GYM';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                const Color(0xFFEF4444)
                                                    .withValues(alpha: 0.15),
                                            child: Text(
                                              nameVal.isNotEmpty
                                                  ? nameVal.substring(0, 1)
                                                  : 'M',
                                              style: const TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(nameVal,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF0F172A))),
                                              Text(
                                                  '$memberCode • ${m['phone'] ?? ''}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF64748B))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(
                                        m['plan']?.toString() ?? 'Standard',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155)))),
                                    DataCell(Text(
                                        '$currency${feeVal.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981)))),
                                    DataCell(Text(
                                        '${m['locker'] ?? 'None'} | ${m['trainer'] ?? 'General'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B)))),
                                    DataCell(Text(
                                        m['expiry_date']?.toString() ??
                                            m['expiry']?.toString() ??
                                            'Active',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFFCBD5E1)
                                                : const Color(0xFF334155)))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(status,
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor)),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.how_to_reg,
                                                size: 18,
                                                color: Color(0xFF10B981)),
                                            tooltip: 'Mark Attendance Check-In',
                                            onPressed: () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              final db = await DatabaseService
                                                  .initialize();
                                              await db.saveModuleRecord(
                                                moduleKey: 'gym',
                                                recordType: 'attendance',
                                                title: nameVal,
                                                status: 'checked_in',
                                                data: {
                                                  'memberId': m['id'],
                                                  'name': nameVal,
                                                  'time': DateTime.now()
                                                      .toIso8601String(),
                                                },
                                              );
                                              if (!mounted) return;
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Attendance saved to database for $nameVal'),
                                                  backgroundColor:
                                                      const Color(0xFF10B981),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.autorenew_rounded,
                                                size: 18,
                                                color: Color(0xFF3B82F6)),
                                            tooltip:
                                                'Renew Membership (+30 Days)',
                                            onPressed: () =>
                                                _renewMembership(m),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: Color(0xFFEF4444)),
                                            tooltip: 'Delete Member',
                                            onPressed: () {
                                              if (m['id'] is int) {
                                                _deleteMember(
                                                    m['id'] as int, nameVal);
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
