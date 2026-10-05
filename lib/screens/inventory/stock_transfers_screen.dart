import 'package:flutter/material.dart';
import '../../models/models.dart';

class StockTransfersScreen extends StatefulWidget {
  final BusinessSettings settings;
  final int initialTab; // 0: Transfers, 1: Adjustments

  const StockTransfersScreen({super.key, required this.settings, this.initialTab = 0});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _transfers = [
    {
      'date': '10/05/2026',
      'ref': 'ST-2026-001',
      'from': 'Awesome Shop (Main)',
      'to': 'Warehouse 1',
      'status': 'Completed',
      'shippingCharges': 15.0,
      'total': 450.0,
    },
    {
      'date': '10/04/2026',
      'ref': 'ST-2026-002',
      'from': 'Warehouse 1',
      'to': 'Awesome Shop (Main)',
      'status': 'In Transit',
      'shippingCharges': 20.0,
      'total': 1200.0,
    },
  ];

  final List<Map<String, dynamic>> _adjustments = [
    {
      'date': '10/05/2026',
      'ref': 'ADJ-001',
      'location': 'Awesome Shop',
      'adjustmentType': 'Normal',
      'totalAmount': 85.0,
      'recoveredAmount': 0.0,
      'reason': 'Damaged during unloading',
    },
    {
      'date': '10/02/2026',
      'ref': 'ADJ-002',
      'location': 'Awesome Shop',
      'adjustmentType': 'Abnormal',
      'totalAmount': 140.0,
      'recoveredAmount': 50.0,
      'reason': 'Routine inventory count discrepancy',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddTransferDialog() {
    final refCtrl = TextEditingController(text: 'ST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final amountCtrl = TextEditingController(text: '300.00');
    String from = 'Awesome Shop';
    String to = 'Warehouse 1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Stock Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference No*')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: from,
                  decoration: const InputDecoration(labelText: 'Transfer From (Location)'),
                  items: const [
                    DropdownMenuItem(value: 'Awesome Shop', child: Text('Awesome Shop')),
                    DropdownMenuItem(value: 'Warehouse 1', child: Text('Warehouse 1')),
                  ],
                  onChanged: (val) => setDlgState(() => from = val ?? from),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: to,
                  decoration: const InputDecoration(labelText: 'Transfer To (Location)'),
                  items: const [
                    DropdownMenuItem(value: 'Awesome Shop', child: Text('Awesome Shop')),
                    DropdownMenuItem(value: 'Warehouse 1', child: Text('Warehouse 1')),
                  ],
                  onChanged: (val) => setDlgState(() => to = val ?? to),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Total Goods Value (${widget.settings.currencySymbol})*'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _transfers.insert(0, {
                    'date': '10/05/2026',
                    'ref': refCtrl.text.trim(),
                    'from': from,
                    'to': to,
                    'status': 'Pending',
                    'shippingCharges': 0.0,
                    'total': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Create Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAdjustmentDialog() {
    final refCtrl = TextEditingController(text: 'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final amountCtrl = TextEditingController(text: '50.00');
    final reasonCtrl = TextEditingController(text: 'Damaged item');
    String type = 'Normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add Stock Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference No*')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Adjustment Type'),
                  items: const [
                    DropdownMenuItem(value: 'Normal', child: Text('Normal (Normal wear, breakage)')),
                    DropdownMenuItem(value: 'Abnormal', child: Text('Abnormal (Theft, fire, accident)')),
                  ],
                  onChanged: (val) => setDlgState(() => type = val ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Total Value Affected (${widget.settings.currencySymbol})*'),
                ),
                const SizedBox(height: 12),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for Adjustment')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  _adjustments.insert(0, {
                    'date': '10/05/2026',
                    'ref': refCtrl.text.trim(),
                    'location': 'Awesome Shop',
                    'adjustmentType': type,
                    'totalAmount': double.tryParse(amountCtrl.text.trim()) ?? 0.0,
                    'recoveredAmount': 0.0,
                    'reason': reasonCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Record Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Stock Transfers & Adjustments',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Transfer stock between branches, warehouses, or record inventory shrinkage/damage.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004EEB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: const Text('Add Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddTransferDialog,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Add Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddAdjustmentDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF004EEB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF004EEB),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Stock Transfers'),
                Tab(icon: Icon(Icons.balance_outlined), text: 'Stock Adjustments'),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Transfers Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Location (From)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Location (To)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Shipping', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _transfers.map((t) {
                        return DataRow(cells: [
                          DataCell(Text(t['date'])),
                          DataCell(Text(t['ref'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                          DataCell(Text(t['from'])),
                          DataCell(Text(t['to'])),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: t['status'] == 'Completed' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t['status'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: t['status'] == 'Completed' ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text('$currency${(t['shippingCharges'] as double).toStringAsFixed(2)}')),
                          DataCell(Text('$currency${(t['total'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        ]);
                      }).toList(),
                    ),
                  ),

                  // Tab 2: Adjustments Table
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Adjustment Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _adjustments.map((a) {
                        return DataRow(cells: [
                          DataCell(Text(a['date'])),
                          DataCell(Text(a['ref'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                          DataCell(Text(a['location'])),
                          DataCell(Text(a['adjustmentType'])),
                          DataCell(Text('$currency${(a['totalAmount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(a['reason'])),
                        ]);
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
