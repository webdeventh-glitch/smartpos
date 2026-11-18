import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ManufacturingScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ManufacturingScreen({super.key, required this.settings});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _workOrders = [];
  List<Product> _products = [];

  static const List<Map<String, dynamic>> _seedRecipes = [
    {
      'code': 'BOM-001',
      'product': 'Organic Mango Jam (500g Jar)',
      'batchSize': 200,
      'unit': 'Jars',
      'ingredients':
          '100kg Fresh Mango Pulp, 40kg Sugar, 2kg Pectin, 200x Glass Jars & Lids',
      'totalCost': 38000.0,
      'unitCost': 190.0,
      'laborCost': 4000.0,
      'overheadCost': 3000.0,
    },
    {
      'code': 'BOM-002',
      'product': 'Cotton T-Shirt (Premium Round Neck)',
      'batchSize': 500,
      'unit': 'Pcs',
      'ingredients':
          '120kg Knitted Cotton Fabric, 500x Woven Neck Labels, 12x Thread Cones',
      'totalCost': 175000.0,
      'unitCost': 350.0,
      'laborCost': 25000.0,
      'overheadCost': 15000.0,
    },
    {
      'code': 'BOM-003',
      'product': 'Paracetamol Suspension 120ml (Pharma)',
      'batchSize': 1000,
      'unit': 'Bottles',
      'ingredients':
          '25kg Paracetamol Active API, 150L Syrup Base, 1000x Amber Bottles & Caps',
      'totalCost': 62000.0,
      'unitCost': 62.0,
      'laborCost': 8000.0,
      'overheadCost': 6000.0,
    },
  ];

  static const List<Map<String, dynamic>> _seedWorkOrders = [
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
    _loadProductionData();
  }

  Future<void> _loadProductionData() async {
    final db = await DatabaseService.initialize();
    final prods = await db.getProducts();

    var recipes = await db.getModuleRecords('manufacturing', recordType: 'bom');
    if (recipes.isEmpty) {
      for (final r in _seedRecipes) {
        await db.saveModuleRecord(
          moduleKey: 'manufacturing',
          recordType: 'bom',
          title: '${r['code']} • ${r['product']}',
          data: r,
        );
      }
      recipes = await db.getModuleRecords('manufacturing', recordType: 'bom');
    }
    var orders =
        await db.getModuleRecords('manufacturing', recordType: 'work_order');
    if (orders.isEmpty) {
      for (final o in _seedWorkOrders) {
        await db.saveModuleRecord(
          moduleKey: 'manufacturing',
          recordType: 'work_order',
          title: '${o['orderNo']} • ${o['recipe']}',
          status: o['status'] as String,
          data: o,
        );
      }
      orders =
          await db.getModuleRecords('manufacturing', recordType: 'work_order');
    }
    if (mounted) {
      setState(() {
        _products = prods;
        _recipes = recipes;
        _workOrders = orders;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddBomModal() {
    Product? selectedProduct;
    final nameCtrl = TextEditingController();
    final batchCtrl = TextEditingController(text: '100');
    final rawCtrl = TextEditingController();
    final materialCostCtrl = TextEditingController(text: '8000');
    final laborCostCtrl = TextEditingController(text: '1500');
    final overheadCostCtrl = TextEditingController(text: '1000');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final batch = double.tryParse(batchCtrl.text) ?? 100.0;
            final mat = double.tryParse(materialCostCtrl.text) ?? 0.0;
            final lab = double.tryParse(laborCostCtrl.text) ?? 0.0;
            final ovh = double.tryParse(overheadCostCtrl.text) ?? 0.0;
            final totalCost = mat + lab + ovh;
            final unitCost = batch > 0 ? totalCost / batch : 0.0;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFF14B8A6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('New Bill of Materials (BOM)',
                      style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select from existing product or type new
                      if (_products.isNotEmpty) ...[
                        DropdownButtonFormField<Product>(
                          decoration: const InputDecoration(
                            labelText:
                                'Link Existing Finished Product (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _products.take(30).map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                  '${p.name} (Stock: ${p.stockQuantity.toInt()})',
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (p) {
                            if (p != null) {
                              setDlgState(() {
                                selectedProduct = p;
                                nameCtrl.text = p.name;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Finished Product Name*',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: batchCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Batch Output Yield*',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: materialCostCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Raw Material Cost (${widget.settings.currencySymbol})',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: laborCostCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Direct Labor Cost (${widget.settings.currencySymbol})',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: overheadCostCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Machinery/Overhead (${widget.settings.currencySymbol})',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rawCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Raw Materials & Ingredients Breakdown*',
                          hintText:
                              'e.g. 100kg Material A, 20L Solution B, 100x Jars',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF14B8A6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF14B8A6)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Batch Cost: ${widget.settings.currencySymbol}${totalCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Unit Landed Cost: ${widget.settings.currencySymbol}${unitCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0D9488),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final pName = nameCtrl.text.trim();
                    if (pName.isNotEmpty) {
                      final bom = <String, dynamic>{
                        'code': 'BOM-00${_recipes.length + 1}',
                        'product': pName,
                        'productId': selectedProduct?.id,
                        'batchSize': batch.toInt(),
                        'unit': 'Units',
                        'ingredients': rawCtrl.text.trim().isNotEmpty
                            ? rawCtrl.text.trim()
                            : 'Standard raw materials list',
                        'totalCost': totalCost,
                        'unitCost': unitCost,
                        'materialCost': mat,
                        'laborCost': lab,
                        'overheadCost': ovh,
                      };
                      final db = await DatabaseService.initialize();
                      final dbId = await db.saveModuleRecord(
                        moduleKey: 'manufacturing',
                        recordType: 'bom',
                        title: '${bom['code']} • ${bom['product']}',
                        data: bom,
                      );
                      bom['_dbId'] = dbId;
                      if (mounted) {
                        setState(() => _recipes.add(bom));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save BOM Recipe'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExecuteProductionRunModal(Map<String, dynamic> wo) async {
    final currency = widget.settings.currencySymbol;
    final woNo = wo['orderNo'] as String? ?? 'WO-NEW';
    final recipeName = wo['recipe'] as String? ?? 'Custom Product';
    final targetQty = (wo['qty'] as num?)?.toDouble() ?? 100.0;

    final yieldCtrl = TextEditingController(text: targetQty.toInt().toString());
    final scrapCtrl = TextEditingController(text: '0');
    final overheadCtrl = TextEditingController(text: '2000.0');

    // Attempt to match with existing product
    final matchedProduct = _products.cast<Product?>().firstWhere(
          (p) =>
              p!.name.toLowerCase().trim() == recipeName.toLowerCase().trim() ||
              recipeName.toLowerCase().contains(p.name.toLowerCase()),
          orElse: () => _products.isNotEmpty ? _products.first : null,
        );

    final db = await DatabaseService.initialize();

    // Query bundle components (raw materials) for matched finished product
    List<Map<String, dynamic>> bundleComponents = [];
    if (matchedProduct?.id != null) {
      bundleComponents = await db.db.rawQuery(
        '''
        SELECT pb.*, p.name as product_name, p.stock_quantity as current_stock, p.unit
        FROM product_bundles pb
        LEFT JOIN products p ON pb.sub_product_id = p.id
        WHERE pb.parent_product_id = ?
        ORDER BY pb.id ASC
        ''',
        [matchedProduct!.id],
      );
    }

    Product? manualRawMaterial;
    final manualRawQtyCtrl = TextEditingController(text: '1.0');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.factory_rounded,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete Production Run • $woNo',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A))),
                        Text(
                            'Atomic inventory increment & raw material consumption',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded,
                                color: Color(0xFF14B8A6), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(recipeName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  if (matchedProduct != null)
                                    Text(
                                      'Linked Product: ${matchedProduct.name} • Current Stock: ${matchedProduct.stockQuantity.toInt()}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: yieldCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Finished Goods Produced*',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: scrapCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Defects / Scrap Units',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: overheadCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Production Overhead Expense ($currency)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Raw materials consumption preview / configuration
                      if (bundleComponents.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF14B8A6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF14B8A6)
                                    .withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.hub_rounded,
                                      size: 16, color: Color(0xFF14B8A6)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Bill of Materials (${bundleComponents.length} Raw Materials to Deduct)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...bundleComponents.map((comp) {
                                final compName = (comp['product_name'] ??
                                        'Material #${comp['sub_product_id']}')
                                    .toString();
                                final compRatio =
                                    (comp['quantity'] as num?)?.toDouble() ??
                                        1.0;
                                final curStock = (comp['current_stock'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final prodYield =
                                    double.tryParse(yieldCtrl.text) ??
                                        targetQty;
                                final totalDeduct = compRatio * prodYield;
                                final hasShortage = curStock < totalDeduct;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• $compName ($compRatio/unit)',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Deduct: ${totalDeduct.toStringAsFixed(1)} | Stock: ${curStock.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: hasShortage
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.inventory_rounded,
                                      size: 15, color: Colors.grey),
                                  SizedBox(width: 6),
                                  Text(
                                    'Deduct Raw Material Product (Optional)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<Product?>(
                                initialValue: manualRawMaterial,
                                isDense: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  hintText:
                                      'Select raw material product to deduct',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('None / Pre-deducted'),
                                  ),
                                  ..._products
                                      .where((p) => p.id != matchedProduct?.id)
                                      .take(30)
                                      .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(
                                              '${p.name} (Stock: ${p.stockQuantity.toInt()})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                ],
                                onChanged: (p) =>
                                    setDlgState(() => manualRawMaterial = p),
                              ),
                              if (manualRawMaterial != null) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: manualRawQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Raw material consumed per finished unit',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Complete & Update Inventory'),
                  onPressed: () async {
                    final producedQty =
                        double.tryParse(yieldCtrl.text) ?? targetQty;
                    final scrapQty = double.tryParse(scrapCtrl.text) ?? 0.0;
                    final overhead = double.tryParse(overheadCtrl.text) ?? 0.0;

                    // Atomic transaction: Increment finished goods & deduct raw materials
                    int rawMaterialsDeducted = 0;
                    await db.db.transaction((txn) async {
                      // 1. Increment Finished Product inventory in SQLite
                      if (matchedProduct != null && matchedProduct.id != null) {
                        await txn.rawUpdate(
                          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                          [producedQty, matchedProduct.id],
                        );
                        // Update location inventory
                        await txn.rawUpdate(
                          'UPDATE product_locations SET qty_available = qty_available + ? WHERE product_id = ?',
                          [producedQty, matchedProduct.id],
                        );
                      }

                      // 2. Deduct Raw Material components
                      if (bundleComponents.isNotEmpty) {
                        for (final comp in bundleComponents) {
                          final subProdId = comp['sub_product_id'] as int?;
                          if (subProdId != null) {
                            final compRatio =
                                (comp['quantity'] as num?)?.toDouble() ?? 1.0;
                            final deductQty = compRatio * producedQty;
                            await txn.rawUpdate(
                              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                              [deductQty, subProdId],
                            );
                            await txn.rawUpdate(
                              'UPDATE product_locations SET qty_available = qty_available - ? WHERE product_id = ?',
                              [deductQty, subProdId],
                            );
                            rawMaterialsDeducted++;
                          }
                        }
                      } else if (manualRawMaterial != null &&
                          manualRawMaterial?.id != null) {
                        final compRatio =
                            double.tryParse(manualRawQtyCtrl.text) ?? 1.0;
                        final deductQty = compRatio * producedQty;
                        await txn.rawUpdate(
                          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                          [deductQty, manualRawMaterial!.id],
                        );
                        await txn.rawUpdate(
                          'UPDATE product_locations SET qty_available = qty_available - ? WHERE product_id = ?',
                          [deductQty, manualRawMaterial!.id],
                        );
                        rawMaterialsDeducted++;
                      }

                      // 3. Log overhead expense if specified
                      if (overhead > 0) {
                        await txn.insert('expenses', {
                          'category': 'Manufacturing Overhead',
                          'amount': overhead,
                          'ref_no': 'MFG-$woNo',
                          'note':
                              'Production run overhead for $recipeName ($woNo)',
                          'date': DateTime.now().toIso8601String(),
                          'payment_method': 'cash',
                        });
                      }

                      // 4. Mark work order completed
                      wo['status'] = 'Completed';
                      wo['progress'] = 1.0;
                      wo['producedQty'] = producedQty;
                      wo['scrapQty'] = scrapQty;
                      wo['completedAt'] = DateTime.now().toIso8601String();
                      if (bundleComponents.isNotEmpty) {
                        wo['consumedComponents'] = bundleComponents
                            .map((c) => {
                                  'id': c['sub_product_id'],
                                  'name': c['product_name'],
                                  'deducted':
                                      ((c['quantity'] as num?)?.toDouble() ??
                                              1.0) *
                                          producedQty,
                                })
                            .toList();
                      } else if (manualRawMaterial != null) {
                        wo['consumedComponents'] = [
                          {
                            'id': manualRawMaterial!.id,
                            'name': manualRawMaterial!.name,
                            'deducted':
                                (double.tryParse(manualRawQtyCtrl.text) ??
                                        1.0) *
                                    producedQty,
                          }
                        ];
                      }

                      await db.saveModuleRecord(
                        id: wo['_dbId'] as int?,
                        moduleKey: 'manufacturing',
                        recordType: 'work_order',
                        title: '${wo['orderNo']} • ${wo['recipe']}',
                        status: 'Completed',
                        data: wo,
                      );
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadProductionData();

                    if (mounted) {
                      final rawMsg = rawMaterialsDeducted > 0
                          ? ' & $rawMaterialsDeducted raw materials deducted'
                          : '';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Work Order $woNo completed: +${producedQty.toInt()} units added to finished stock$rawMsg!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
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
            const Icon(Icons.precision_manufacturing_rounded,
                color: Color(0xFF14B8A6), size: 22),
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
          unselectedLabelColor:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(
                icon: Icon(Icons.receipt_long_rounded, size: 18),
                text: 'Bill of Materials (BOM)'),
            Tab(
                icon: Icon(Icons.factory_rounded, size: 18),
                text: 'Production Work Orders'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white),
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
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14B8A6)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      b['code'] as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D9488),
                                          fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    b['product'] as String,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Text(
                                'Unit Cost: $currency${((b['unitCost'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Batch Yield: ${b['batchSize']} ${b['unit'] ?? 'Units'} • Total Batch Cost: $currency${((b['totalCost'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Raw Materials Required: ${b['ingredients']}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155)),
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
                                onPressed: () async {
                                  final order = <String, dynamic>{
                                    'orderNo': 'WO-${804 + _workOrders.length}',
                                    'recipe': b['product'],
                                    'productId': b['productId'],
                                    'qty': b['batchSize'],
                                    'startDate': 'Today',
                                    'technician': 'Assembly Line 1',
                                    'status': 'Planned',
                                    'progress': 0.0,
                                  };
                                  final db = await DatabaseService.initialize();
                                  final dbId = await db.saveModuleRecord(
                                    moduleKey: 'manufacturing',
                                    recordType: 'work_order',
                                    title:
                                        '${order['orderNo']} • ${order['recipe']}',
                                    status: 'Planned',
                                    data: order,
                                  );
                                  order['_dbId'] = dbId;
                                  if (!context.mounted) return;
                                  setState(() {
                                    _workOrders.insert(0, order);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Production Work Order created for ${b['product']}')),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 16),
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
                    final status = wo['status'] as String? ?? 'Planned';
                    final isCompleted = status.toLowerCase() == 'completed';

                    Color statusColor = const Color(0xFF3B82F6);
                    if (isCompleted) statusColor = const Color(0xFF10B981);
                    if (status == 'Planned') {
                      statusColor = const Color(0xFFF59E0B);
                    }

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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${wo['orderNo']} • ${wo['recipe']}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
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
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: statusColor)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                              'Target Output: ${wo['qty']} Units • Started: ${wo['startDate']} • Assigned: ${wo['technician']}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  ((wo['progress'] as num?)?.toDouble() ?? 0.0),
                              backgroundColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              color: statusColor,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isCompleted)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () =>
                                      _showExecuteProductionRunModal(wo),
                                  icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16),
                                  label: const Text('Complete Production Run'),
                                )
                              else
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFF10B981), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Stock Incremented (+${wo['producedQty'] ?? wo['qty']} Units)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF10B981)),
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
        ],
      ),
    );
  }
}
