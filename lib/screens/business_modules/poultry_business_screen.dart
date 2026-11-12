import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class PoultryBusinessScreen extends StatefulWidget {
  final BusinessSettings settings;

  const PoultryBusinessScreen({super.key, required this.settings});

  @override
  State<PoultryBusinessScreen> createState() => _PoultryBusinessScreenState();
}

class _PoultryBusinessScreenState extends State<PoultryBusinessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _flocks = [];
  List<Map<String, dynamic>> _dispatches = [];

  static const List<Map<String, dynamic>> _seedFlocks = [
    {
      'flockNo': 'FLOCK-88',
      'shed': 'Shed 1 (Environment Controlled)',
      'breed': 'Ross 308 Broiler',
      'initialChicks': 10000,
      'currentBirds': 9620,
      'mortality': 380,
      'ageDays': 32,
      'feedConsumedBags': 720,
      'avgWeightKg': 2.15,
      'status': 'Growing',
    },
    {
      'flockNo': 'FLOCK-89',
      'shed': 'Shed 2 (Semi-Control)',
      'breed': 'Cobb 500 Broiler',
      'initialChicks': 8000,
      'currentBirds': 7710,
      'mortality': 290,
      'ageDays': 36,
      'feedConsumedBags': 640,
      'avgWeightKg': 2.45,
      'status': 'Ready for Sale',
    },
    {
      'flockNo': 'FLOCK-82',
      'shed': 'Shed 3 (Layer Farm)',
      'breed': 'Hy-Line White Layer',
      'initialChicks': 15000,
      'currentBirds': 14650,
      'mortality': 350,
      'ageDays': 180,
      'feedConsumedBags': 1950,
      'avgWeightKg': 1.65,
      'status': 'Egg Production',
    },
  ];

  static const List<Map<String, dynamic>> _seedDispatches = [
    {
      'dispatchNo': 'DSP-301',
      'flock': 'FLOCK-89 (Shed 2)',
      'buyer': 'Rawalpindi Chicken Market Wholesale',
      'vehicle': 'Truck RIS-4921',
      'cratesCount': 120,
      'grossWeightKg': 4250.0,
      'emptyTareWeightKg': 720.0,
      'netBirdWeightKg': 3530.0,
      'birdsCount': 1450,
      'ratePerKg': 385.0,
      'totalAmount': 1359050.0,
      'date': '21 Oct 2026',
    },
    {
      'dispatchNo': 'DSP-302',
      'flock': 'FLOCK-82 (Egg Layer)',
      'buyer': 'Islamabad Bakers & Supermarkets',
      'vehicle': 'Van LE-221',
      'cratesCount': 85, // 85 Petian (Trays)
      'grossWeightKg': 0.0,
      'emptyTareWeightKg': 0.0,
      'netBirdWeightKg': 0.0,
      'birdsCount': 0,
      'ratePerKg': 295.0, // per dozen/tray
      'totalAmount': 175000.0,
      'date': '20 Oct 2026',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPoultryData();
  }

  Future<void> _loadPoultryData() async {
    final db = await DatabaseService.initialize();
    var flocks = await db.getModuleRecords('poultry', recordType: 'flock');
    if (flocks.isEmpty) {
      for (final f in _seedFlocks) {
        await db.saveModuleRecord(
          moduleKey: 'poultry',
          recordType: 'flock',
          title: '${f['flockNo']} • ${f['shed']}',
          status: f['status'] as String,
          data: f,
        );
      }
      flocks = await db.getModuleRecords('poultry', recordType: 'flock');
    }
    var dispatches =
        await db.getModuleRecords('poultry', recordType: 'dispatch');
    if (dispatches.isEmpty) {
      for (final d in _seedDispatches) {
        await db.saveModuleRecord(
          moduleKey: 'poultry',
          recordType: 'dispatch',
          title: '${d['dispatchNo']} • ${d['buyer']}',
          data: d,
        );
      }
      dispatches = await db.getModuleRecords('poultry', recordType: 'dispatch');
    }
    if (mounted) {
      setState(() {
        _flocks = flocks;
        _dispatches = dispatches;
      });
    }
  }

  void _showDispatchModal(Map<String, dynamic> flock) {
    final buyerCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final cratesCtrl = TextEditingController(text: '50');
    final birdsCtrl = TextEditingController(text: '500');
    final netKgCtrl = TextEditingController(text: '1000');
    final rateCtrl = TextEditingController(text: '385');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dispatch Birds — ${flock['flockNo']}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: buyerCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Buyer / Market*')),
                TextField(
                    controller: vehicleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Vehicle No.')),
                TextField(
                    controller: cratesCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Crates Count')),
                TextField(
                    controller: birdsCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Birds Count')),
                TextField(
                    controller: netKgCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Net Weight (kg)')),
                TextField(
                    controller: rateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Rate per kg')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white),
            onPressed: () async {
              final birds = int.tryParse(birdsCtrl.text) ?? 0;
              final netKg = double.tryParse(netKgCtrl.text) ?? 0.0;
              final rate = double.tryParse(rateCtrl.text) ?? 0.0;
              final dispatch = <String, dynamic>{
                'dispatchNo': 'DSP-${303 + _dispatches.length}',
                'flock': '${flock['flockNo']} (${flock['shed']})',
                'buyer': buyerCtrl.text.trim().isEmpty
                    ? 'Cash Buyer'
                    : buyerCtrl.text.trim(),
                'vehicle': vehicleCtrl.text.trim(),
                'cratesCount': int.tryParse(cratesCtrl.text) ?? 0,
                'grossWeightKg': netKg,
                'emptyTareWeightKg': 0.0,
                'netBirdWeightKg': netKg,
                'birdsCount': birds,
                'ratePerKg': rate,
                'totalAmount': netKg * rate,
                'date': 'Today',
              };
              final db = await DatabaseService.initialize();
              final dId = await db.saveModuleRecord(
                moduleKey: 'poultry',
                recordType: 'dispatch',
                title: '${dispatch['dispatchNo']} • ${dispatch['buyer']}',
                data: dispatch,
              );
              dispatch['_dbId'] = dId;
              final nextBirds =
                  ((flock['currentBirds'] as int) - birds).clamp(0, 999999);
              flock['currentBirds'] = nextBirds;
              await db.saveModuleRecord(
                id: flock['_dbId'] as int?,
                moduleKey: 'poultry',
                recordType: 'flock',
                title: '${flock['flockNo']} • ${flock['shed']}',
                status: flock['status'] as String,
                data: flock,
              );
              if (mounted) {
                setState(() => _dispatches.insert(0, dispatch));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Dispatch'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddFlockModal() {
    final flockCtrl = TextEditingController();
    final shedCtrl = TextEditingController();
    final chicksCtrl = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Start New Poultry Flock / Batch',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: flockCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Flock / Batch Number (e.g. FLOCK-90)*',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: shedCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Shed Name / Location (e.g. Shed 4)*',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chicksCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Initial Day-Old Chicks (DOC) Count*',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
            ],
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
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black),
              onPressed: () async {
                if (flockCtrl.text.trim().isNotEmpty) {
                  final chicks = int.tryParse(chicksCtrl.text) ?? 5000;
                  final flock = <String, dynamic>{
                    'flockNo': flockCtrl.text.trim(),
                    'shed': shedCtrl.text.trim().isEmpty
                        ? 'Shed 1'
                        : shedCtrl.text.trim(),
                    'breed': 'Ross 308 Broiler',
                    'initialChicks': chicks,
                    'currentBirds': chicks,
                    'mortality': 0,
                    'ageDays': 1,
                    'feedConsumedBags': 0,
                    'avgWeightKg': 0.05,
                    'status': 'Growing',
                  };
                  final db = await DatabaseService.initialize();
                  final dbId = await db.saveModuleRecord(
                    moduleKey: 'poultry',
                    recordType: 'flock',
                    title: '${flock['flockNo']} • ${flock['shed']}',
                    status: 'Growing',
                    data: flock,
                  );
                  flock['_dbId'] = dbId;
                  if (mounted) {
                    setState(() => _flocks.add(flock));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Start Flock',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.egg_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 10),
            Text(
              'Poultry Farm & Broiler / Layer Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFD97706),
          indicatorColor: const Color(0xFFF59E0B),
          unselectedLabelColor:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(
                icon: Icon(Icons.grid_view_rounded, size: 18),
                text: 'Active Flocks & Sheds'),
            Tab(
                icon: Icon(Icons.local_shipping_rounded, size: 18),
                text: 'Live Bird Dispatches & Market Sales'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black),
              onPressed: _showAddFlockModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Flock / Batch',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Flocks
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _flocks.length,
                  itemBuilder: (context, idx) {
                    final f = _flocks[idx];
                    final status = f['status'] as String;
                    Color statusColor = const Color(0xFF3B82F6);
                    if (status == 'Ready for Sale')
                      statusColor = const Color(0xFF10B981);
                    if (status == 'Egg Production')
                      statusColor = const Color(0xFFF59E0B);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${f['flockNo']} • ${f['shed']}',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('(${f['breed']})',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B))),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _flockPill(
                                  'Live Birds',
                                  '${f['currentBirds']} / ${f['initialChicks']}',
                                  const Color(0xFF10B981),
                                  isDark),
                              const SizedBox(width: 10),
                              _flockPill('Mortality', '${f['mortality']} birds',
                                  const Color(0xFFEF4444), isDark),
                              const SizedBox(width: 10),
                              _flockPill('Flock Age', '${f['ageDays']} Days',
                                  const Color(0xFF3B82F6), isDark),
                              const SizedBox(width: 10),
                              _flockPill('Avg Weight', '${f['avgWeightKg']} kg',
                                  const Color(0xFFF59E0B), isDark),
                              const SizedBox(width: 10),
                              _flockPill(
                                  'Feed Bags',
                                  '${f['feedConsumedBags']} Bags',
                                  const Color(0xFF8B5CF6),
                                  isDark),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  setState(() {
                                    f['mortality'] =
                                        (f['mortality'] as int) + 5;
                                    f['currentBirds'] =
                                        ((f['currentBirds'] as int) - 5)
                                            .clamp(0, 999999);
                                  });
                                  final db = await DatabaseService.initialize();
                                  await db.saveModuleRecord(
                                    id: f['_dbId'] as int?,
                                    moduleKey: 'poultry',
                                    recordType: 'flock',
                                    title: '${f['flockNo']} • ${f['shed']}',
                                    status: f['status'] as String,
                                    data: f,
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Recorded daily mortality entry.')),
                                  );
                                },
                                child: const Text('+ Mortality',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  setState(() {
                                    f['feedConsumedBags'] =
                                        (f['feedConsumedBags'] as int) + 20;
                                  });
                                  final db = await DatabaseService.initialize();
                                  await db.saveModuleRecord(
                                    id: f['_dbId'] as int?,
                                    moduleKey: 'poultry',
                                    recordType: 'flock',
                                    title: '${f['flockNo']} • ${f['shed']}',
                                    status: f['status'] as String,
                                    data: f,
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Feed consumption entry recorded.')),
                                  );
                                },
                                child: const Text('+ Feed Consumed',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showDispatchModal(f),
                                child: const Text('Dispatch Birds',
                                    style: TextStyle(fontSize: 11)),
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

          // Tab 2: Dispatches
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dispatches.length,
              itemBuilder: (context, idx) {
                final d = _dispatches[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d['dispatchNo']} • ${d['buyer']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text(
                            'Vehicle: ${d['vehicle']} • ${d['cratesCount']} Crates • Net Weight: ${(d['netBirdWeightKg'] as double).toStringAsFixed(0)} kg @ $currency${(d['ratePerKg'] as double).toStringAsFixed(0)}/kg',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Text(
                        '$currency${(d['totalAmount'] as double).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _flockPill(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 9.5,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569))),
          Text(val,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
