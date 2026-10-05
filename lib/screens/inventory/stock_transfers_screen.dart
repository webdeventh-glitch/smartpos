import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class StockTransfersScreen extends StatefulWidget {
  final BusinessSettings settings;
  final int initialTab; // 0: Transfers, 1: Adjustments

  const StockTransfersScreen({super.key, required this.settings, this.initialTab = 0});

  @override
  State<StockTransfersScreen> createState() => _StockTransfersScreenState();
}

class _StockTransfersScreenState extends State<StockTransfersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<StockTransfer> _transfers = [];
  List<StockAdjustment> _adjustments = [];
  List<BusinessLocation> _locations = [];
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DatabaseService.initialize();
    final transfers = await db.getStockTransfers();
    final adjustments = await db.getStockAdjustments();
    final locations = await db.getBusinessLocations();
    final products = await db.getProducts();

    if (mounted) {
      setState(() {
        _transfers = transfers;
        _adjustments = adjustments;
        _locations = locations;
        _products = products;
        _loading = false;
      });
    }
  }

  Future<void> _showAddTransferDialog() async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextTransferRef();

    final refCtrl = TextEditingController(text: nextRef);
    final shippingCtrl = TextEditingController(text: '0.00');
    final noteCtrl = TextEditingController();

    BusinessLocation? fromLoc = _locations.isNotEmpty ? _locations.first : null;
    BusinessLocation? toLoc = _locations.length > 1 ? _locations[1] : fromLoc;
    String status = 'completed';

    Product? selectedProduct = _products.isNotEmpty ? _products.first : null;
    final qtyCtrl = TextEditingController(text: '5');
    final unitPriceCtrl = TextEditingController(
      text: selectedProduct != null ? selectedProduct.purchasePrice.toStringAsFixed(2) : '10.00',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          final unitPrice = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
          final shipping = double.tryParse(shippingCtrl.text.trim()) ?? 0.0;
          final totalGoods = qty * unitPrice;
          final grandTotal = totalGoods + shipping;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.compare_arrows, color: Color(0xFF004EEB)),
                SizedBox(width: 8),
                Text('Add Stock Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: refCtrl,
                            decoration: const InputDecoration(labelText: 'Reference No*', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'Transfer Status*', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'in_transit', child: Text('In Transit')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            ],
                            onChanged: (val) => setDlgState(() => status = val ?? status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BusinessLocation>(
                            initialValue: fromLoc,
                            decoration: const InputDecoration(labelText: 'Transfer From*', isDense: true),
                            items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name))).toList(),
                            onChanged: (val) => setDlgState(() => fromLoc = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<BusinessLocation>(
                            initialValue: toLoc,
                            decoration: const InputDecoration(labelText: 'Transfer To*', isDense: true),
                            items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name))).toList(),
                            onChanged: (val) => setDlgState(() => toLoc = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Products to Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct,
                      decoration: const InputDecoration(labelText: 'Select Product*', isDense: true),
                      items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stockQuantity.toInt()})'))).toList(),
                      onChanged: (val) {
                        setDlgState(() {
                          selectedProduct = val;
                          if (val != null) {
                            unitPriceCtrl.text = val.purchasePrice.toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity to Transfer*', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: unitPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Unit Cost', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: shippingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Shipping Charges', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Transfer Note / Driver reference', isDense: true),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Transfer Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${widget.settings.currencySymbol}${grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF004EEB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
                onPressed: () async {
                  if (fromLoc == null || toLoc == null || selectedProduct == null || qty <= 0) return;

                  final items = [
                    StockTransferItem(
                      productId: selectedProduct!.id ?? 1,
                      productName: selectedProduct!.name,
                      sku: selectedProduct!.sku,
                      quantity: qty,
                      unitPrice: unitPrice,
                    ),
                  ];

                  final transfer = StockTransfer(
                    refNo: refCtrl.text.trim(),
                    fromLocationId: fromLoc!.id ?? 1,
                    fromLocationName: fromLoc!.name,
                    toLocationId: toLoc!.id ?? 2,
                    toLocationName: toLoc!.name,
                    status: status,
                    shippingCharges: shipping,
                    finalTotal: grandTotal,
                    date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    note: noteCtrl.text.trim(),
                    itemsJson: jsonEncode(items.map((e) => e.toMap()).toList()),
                  );

                  await db.createStockTransfer(transfer);
                  Navigator.pop(ctx);
                  _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock transfer ${transfer.refNo} saved successfully!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                child: const Text('Save Stock Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddAdjustmentDialog() async {
    final db = await DatabaseService.initialize();
    final nextRef = await db.generateNextAdjustmentRef();

    final refCtrl = TextEditingController(text: nextRef);
    final reasonCtrl = TextEditingController(text: 'Damaged during handling');
    final recoveredCtrl = TextEditingController(text: '0.00');

    BusinessLocation? location = _locations.isNotEmpty ? _locations.first : null;
    String type = 'normal';

    Product? selectedProduct = _products.isNotEmpty ? _products.first : null;
    final qtyCtrl = TextEditingController(text: '2');
    final unitPriceCtrl = TextEditingController(
      text: selectedProduct != null ? selectedProduct.purchasePrice.toStringAsFixed(2) : '15.00',
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          final unitPrice = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
          final recovered = double.tryParse(recoveredCtrl.text.trim()) ?? 0.0;
          final totalAmount = qty * unitPrice;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.tune, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Text('Add Stock Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: refCtrl,
                            decoration: const InputDecoration(labelText: 'Reference No*', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            decoration: const InputDecoration(labelText: 'Adjustment Type*', isDense: true),
                            items: const [
                              DropdownMenuItem(value: 'normal', child: Text('Normal (Breakage, Spoiled)')),
                              DropdownMenuItem(value: 'abnormal', child: Text('Abnormal (Theft, Accident)')),
                            ],
                            onChanged: (val) => setDlgState(() => type = val ?? type),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<BusinessLocation>(
                      initialValue: location,
                      decoration: const InputDecoration(labelText: 'Business Location*', isDense: true),
                      items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name))).toList(),
                      onChanged: (val) => setDlgState(() => location = val),
                    ),
                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Product to Adjust / Shrink', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct,
                      decoration: const InputDecoration(labelText: 'Select Product*', isDense: true),
                      items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stockQuantity.toInt()})'))).toList(),
                      onChanged: (val) {
                        setDlgState(() {
                          selectedProduct = val;
                          if (val != null) {
                            unitPriceCtrl.text = val.purchasePrice.toStringAsFixed(2);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity to Deduct*', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: unitPriceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Unit Cost', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: recoveredCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Recovered Amount', isDense: true),
                            onChanged: (_) => setDlgState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Reason for Adjustment', hintText: 'e.g. Broken in storage or expired', isDense: true),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Value Deducted:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${widget.settings.currencySymbol}${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () async {
                  if (location == null || selectedProduct == null || qty <= 0) return;

                  final items = [
                    StockAdjustmentItem(
                      productId: selectedProduct!.id ?? 1,
                      productName: selectedProduct!.name,
                      sku: selectedProduct!.sku,
                      quantity: qty,
                      unitPrice: unitPrice,
                    ),
                  ];

                  final adjustment = StockAdjustment(
                    refNo: refCtrl.text.trim(),
                    locationId: location!.id ?? 1,
                    locationName: location!.name,
                    adjustmentType: type,
                    totalAmount: totalAmount,
                    recoveredAmount: recovered,
                    reason: reasonCtrl.text.trim(),
                    date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                    itemsJson: jsonEncode(items.map((e) => e.toMap()).toList()),
                  );

                  await db.createStockAdjustment(adjustment);
                  Navigator.pop(ctx);
                  _loadData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock adjustment ${adjustment.refNo} recorded and deducted from stock!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                child: const Text('Record Adjustment'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteTransfer(StockTransfer transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stock Transfer?'),
        content: Text('Are you sure you want to remove transfer ${transfer.refNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && transfer.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteStockTransfer(transfer.id!);
      _loadData();
    }
  }

  Future<void> _deleteAdjustment(StockAdjustment adjustment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stock Adjustment?'),
        content: Text('Are you sure you want to remove adjustment ${adjustment.refNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && adjustment.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteStockAdjustment(adjustment.id!);
      _loadData();
    }
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

            _loading
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                : SizedBox(
                    height: 520,
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
                          child: _transfers.isEmpty
                              ? const Center(child: Text('No stock transfers recorded yet.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('From Location', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('To Location', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Shipping', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _transfers.map((t) {
                                      final isCompleted = t.status == 'completed';
                                      return DataRow(cells: [
                                        DataCell(Text(t.date.split(' ').first)),
                                        DataCell(Text(t.refNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                                        DataCell(Text(t.fromLocationName)),
                                        DataCell(Text(t.toLocationName)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              t.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text('$currency${t.shippingCharges.toStringAsFixed(2)}')),
                                        DataCell(Text('$currency${t.finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteTransfer(t),
                                            tooltip: 'Delete Transfer',
                                          ),
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                        ),

                        // Tab 2: Adjustments Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _adjustments.isEmpty
                              ? const Center(child: Text('No stock adjustments recorded yet.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    columns: const [
                                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Recovered Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _adjustments.map((a) {
                                      final isNormal = a.adjustmentType == 'normal';
                                      return DataRow(cells: [
                                        DataCell(Text(a.date.split(' ').first)),
                                        DataCell(Text(a.refNo, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004EEB)))),
                                        DataCell(Text(a.locationName)),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isNormal ? const Color(0xFFE0F2FE) : const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              a.adjustmentType.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isNormal ? const Color(0xFF0369A1) : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataCell(Text('$currency${a.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                                        DataCell(Text('$currency${a.recoveredAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                        DataCell(Text(a.reason)),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteAdjustment(a),
                                            tooltip: 'Delete Adjustment',
                                          ),
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
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
