import 'package:flutter/material.dart';
import '../../models/models.dart';

class FruitMandiScreen extends StatefulWidget {
  final BusinessSettings settings;

  const FruitMandiScreen({super.key, required this.settings});

  @override
  State<FruitMandiScreen> createState() => _FruitMandiScreenState();
}

class _FruitMandiScreenState extends State<FruitMandiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final List<Map<String, dynamic>> _auctions = [
    {
      'lotNo': 'LOT-401',
      'zamindar': 'Chaudhry Riaz (Multan Orchards)',
      'buyer': 'Haji Akram (Lahore Wholesale)',
      'item': 'Chaunsa Mango (Special Export Grade)',
      'naga': 150,
      'unitType': 'Wood Crates (Petian)',
      'grossWeight': 2250.0, // kg
      'netWeightMuns': 56.25, // 2250 / 40
      'ratePerMun': 4800.0,
      'grossTotal': 270000.0,
      'commissionPct': 6.0,
      'commissionAmount': 16200.0,
      'mazdoori': 3000.0,
      'netZamindarPayable': 250800.0,
      'date': '21 Oct 2026',
      'status': 'Billed',
    },
    {
      'lotNo': 'LOT-402',
      'zamindar': 'Malik Tariq (Sargodha)',
      'buyer': 'Bismillah Fruit Traders',
      'item': 'Kinnu (Orange Grade A)',
      'naga': 300,
      'unitType': 'Cardboard Boxes',
      'grossWeight': 3600.0,
      'netWeightMuns': 90.0,
      'ratePerMun': 2400.0,
      'grossTotal': 216000.0,
      'commissionPct': 6.0,
      'commissionAmount': 12960.0,
      'mazdoori': 4500.0,
      'netZamindarPayable': 198540.0,
      'date': '21 Oct 2026',
      'status': 'Billed',
    },
    {
      'lotNo': 'LOT-403',
      'zamindar': 'Haji Ramzan (Okara Farms)',
      'buyer': 'Karachi Sabzi Beopari',
      'item': 'Red Potato (New Crop)',
      'naga': 200,
      'unitType': 'Jute Bags (Borian)',
      'grossWeight': 10000.0,
      'netWeightMuns': 250.0,
      'ratePerMun': 1800.0,
      'grossTotal': 450000.0,
      'commissionPct': 5.0,
      'commissionAmount': 22500.0,
      'mazdoori': 6000.0,
      'netZamindarPayable': 421500.0,
      'date': '20 Oct 2026',
      'status': 'Pending Payment',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddBoliModal() {
    final zamindarCtrl = TextEditingController();
    final buyerCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final nagaCtrl = TextEditingController(text: '100');
    final weightKgCtrl = TextEditingController(text: '1200');
    final ratePerMunCtrl = TextEditingController(text: '3500');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('New Mandi Auction (Boli Entry)', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: zamindarCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Zamindar / Grower Name (Maal Malik)*',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyerCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Buyer / Khareedar (Beopari)*',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: itemCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Fruit / Veg Item (e.g. Mango Chaunsa, Potato)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nagaCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Crates / Naga / Bags',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightKgCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Total Weight (Kg)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ratePerMunCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Rate per Mun (40kg)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84CC16), foregroundColor: Colors.black),
              onPressed: () {
                if (zamindarCtrl.text.trim().isNotEmpty && buyerCtrl.text.trim().isNotEmpty) {
                  final kg = double.tryParse(weightKgCtrl.text) ?? 1000.0;
                  final rate = double.tryParse(ratePerMunCtrl.text) ?? 3000.0;
                  final muns = kg / 40.0;
                  final gross = muns * rate;
                  final comm = gross * 0.06;
                  const maz = 2000.0;

                  setState(() {
                    _auctions.insert(0, {
                      'lotNo': 'LOT-${404 + _auctions.length}',
                      'zamindar': zamindarCtrl.text.trim(),
                      'buyer': buyerCtrl.text.trim(),
                      'item': itemCtrl.text.trim().isEmpty ? 'General Fruit' : itemCtrl.text.trim(),
                      'naga': int.tryParse(nagaCtrl.text) ?? 100,
                      'unitType': 'Crates',
                      'grossWeight': kg,
                      'netWeightMuns': muns,
                      'ratePerMun': rate,
                      'grossTotal': gross,
                      'commissionPct': 6.0,
                      'commissionAmount': comm,
                      'mazdoori': maz,
                      'netZamindarPayable': gross - comm - maz,
                      'date': 'Today',
                      'status': 'Billed',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Boli / Auction', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.agriculture_rounded, color: Color(0xFF84CC16), size: 24),
            const SizedBox(width: 10),
            Text(
              'Fruit & Vegetable Wholesale / Mandi Arhat System',
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
          labelColor: const Color(0xFF65A30D),
          indicatorColor: const Color(0xFF84CC16),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.gavel_rounded, size: 18), text: 'Daily Boli & Auction Register'),
            Tab(icon: Icon(Icons.receipt_rounded, size: 18), text: 'Zamindar Khata & Net Bikri Slips'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84CC16), foregroundColor: Colors.black),
              onPressed: _showAddBoliModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Boli / Auction Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Daily Boli
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _auctions.length,
                  itemBuilder: (context, idx) {
                    final a = _auctions[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF84CC16).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(a['lotNo'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4D7C0F))),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    a['item'] as String,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Text(
                                'Gross: $currency${(a['grossTotal'] as double).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Zamindar (Seller): ${a['zamindar']}',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Buyer (Beopari): ${a['buyer']}',
                                  style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Weight: ${(a['grossWeight'] as double).toStringAsFixed(0)} kg = ${(a['netWeightMuns'] as double).toStringAsFixed(2)} Muns  •  Rate: $currency${(a['ratePerMun'] as double).toStringAsFixed(0)} / Mun  •  ${a['naga']} ${a['unitType']}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deductions: Commission (${a['commissionPct']}%) = $currency${(a['commissionAmount'] as double).toStringAsFixed(0)} | Mazdoori: $currency${(a['mazdoori'] as double).toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Net to Zamindar: $currency${(a['netZamindarPayable'] as double).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 13),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Bikri receipt printed for ${a['zamindar']}')),
                                      );
                                    },
                                    child: const Text('Bikri Slip', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
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

          // Tab 2: Zamindar Slips
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Consignor & Zamindar Settlement ledgers are ready.',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
