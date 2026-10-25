import 'package:flutter/material.dart';
import '../../models/models.dart';

class ManufacturingScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ManufacturingScreen({super.key, required this.settings});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final List<Map<String, dynamic>> _recipes = [
    {
      'code': 'BOM-001',
      'product': 'Organic Mango Jam (500g Jar)',
      'batchSize': 200,
      'unit': 'Jars',
      'ingredients': '100kg Fresh Mango Pulp, 40kg Sugar, 2kg Pectin, 200x Glass Jars & Lids',
      'totalCost': 38000.0,
      'unitCost': 190.0,
    },
    {
      'code': 'BOM-002',
      'product': 'Cotton T-Shirt (Premium Round Neck)',
      'batchSize': 500,
      'unit': 'Pcs',
      'ingredients': '120kg Knitted Cotton Fabric, 500x Woven Neck Labels, 12x Thread Cones',
      'totalCost': 175000.0,
      'unitCost': 350.0,
    },
    {
      'code': 'BOM-003',
      'product': 'Paracetamol Suspension 120ml (Pharma)',
      'batchSize': 1000,
      'unit': 'Bottles',
      'ingredients': '25kg Paracetamol Active API, 150L Syrup Base, 1000x Amber Bottles & Caps',
      'totalCost': 62000.0,
      'unitCost': 62.0,
    },
  ];

  final List<Map<String, dynamic>> _workOrders = [
    {
      'orderNo': 'WO-801',
      'recipe': 'Organic Mango Jam (500g Jar)',
      'qty': 400,
      'startDate': '21 Oct 2026',
      'technician': 'Production Line A',
      'status': 'In Production',
      'progress': 0.65,
    },
    {
      'orderNo': 'WO-802',
      'recipe': 'Cotton T-Shirt (Premium Round Neck)',
      'qty': 1000,
      'startDate': '19 Oct 2026',
      'technician': 'Cutting & Stitching Unit',
      'status': 'Completed',
      'progress': 1.0,
    },
    {
      'orderNo': 'WO-803',
      'recipe': 'Paracetamol Suspension 120ml',
      'qty': 2500,
      'startDate': '21 Oct 2026',
      'technician': 'Liquid Filling Section',
      'status': 'Planned',
      'progress': 0.1,
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

  void _showAddBomModal() {
    final nameCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: '100');
    final rawCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('New Bill of Materials (BOM)', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Finished Product Name*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Batch Yield Quantity',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rawCtrl,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Raw Materials & Ingredients Required*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Total Estimated Batch Cost',
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final batch = int.tryParse(batchCtrl.text) ?? 100;
                  final total = double.tryParse(costCtrl.text) ?? 10000.0;
                  setState(() {
                    _recipes.add({
                      'code': 'BOM-00${_recipes.length + 1}',
                      'product': nameCtrl.text.trim(),
                      'batchSize': batch,
                      'unit': 'Units',
                      'ingredients': rawCtrl.text.trim(),
                      'totalCost': total,
                      'unitCost': total / batch,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save BOM Recipe'),
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
            const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF14B8A6), size: 22),
            const SizedBox(width: 10),
            Text(
              'Manufacturing & Production Work Orders',
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
          labelColor: const Color(0xFF14B8A6),
          indicatorColor: const Color(0xFF14B8A6),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Bill of Materials (BOM)'),
            Tab(icon: Icon(Icons.factory_rounded, size: 18), text: 'Production Work Orders'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6), foregroundColor: Colors.white),
              onPressed: _showAddBomModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New BOM Recipe'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: BOM Recipes
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recipes.length,
                  itemBuilder: (context, idx) {
                    final b = _recipes[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['code'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488), fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    b['product'] as String,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Text(
                                'Unit Cost: $currency${(b['unitCost'] as double).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Batch Yield: ${b['batchSize']} ${b['unit']} • Total Batch Cost: $currency${(b['totalCost'] as double).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Raw Materials Required: ${b['ingredients']}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF14B8A6),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _workOrders.insert(0, {
                                      'orderNo': 'WO-${804 + _workOrders.length}',
                                      'recipe': b['product'],
                                      'qty': b['batchSize'],
                                      'startDate': 'Today',
                                      'technician': 'Assembly Line 1',
                                      'status': 'Planned',
                                      'progress': 0.0,
                                    });
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Production Work Order created for ${b['product']}')),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Start Work Order'),
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

          // Tab 2: Work Orders
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _workOrders.length,
                  itemBuilder: (context, idx) {
                    final wo = _workOrders[idx];
                    final status = wo['status'] as String;
                    Color statusColor = const Color(0xFF3B82F6);
                    if (status == 'Completed') statusColor = const Color(0xFF10B981);
                    if (status == 'Planned') statusColor = const Color(0xFFF59E0B);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${wo['orderNo']} • ${wo['recipe']}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Target Output: ${wo['qty']} Units • Started: ${wo['startDate']} • Assigned: ${wo['technician']}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (wo['progress'] as double),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              color: statusColor,
                              minHeight: 6,
                            ),
                          ),
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
    );
  }
}
