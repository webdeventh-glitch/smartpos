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

  Widget _fieldLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
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
          final currency = widget.settings.currencySymbol;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: 560,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF4F46E5), size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add Stock Transfer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Move inventory between branches or warehouses', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Reference No', isRequired: true),
                                  TextField(
                                    controller: refCtrl,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Transfer Status', isRequired: true),
                                  DropdownButtonFormField<String>(
                                    initialValue: status,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'completed', child: Text('Completed (Immediate Stock Move)', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'in_transit', child: Text('In Transit', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'pending', child: Text('Pending Approval', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (val) => setDlgState(() => status = val ?? status),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Transfer From (Source)', isRequired: true),
                                  DropdownButtonFormField<BusinessLocation>(
                                    initialValue: fromLoc,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name, style: const TextStyle(fontSize: 13)))).toList(),
                                    onChanged: (val) => setDlgState(() => fromLoc = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Transfer To (Destination)', isRequired: true),
                                  DropdownButtonFormField<BusinessLocation>(
                                    initialValue: toLoc,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name, style: const TextStyle(fontSize: 13)))).toList(),
                                    onChanged: (val) => setDlgState(() => toLoc = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _fieldLabel('Product to Transfer', isRequired: true),
                        DropdownButtonFormField<Product>(
                          initialValue: selectedProduct,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stockQuantity.toInt()})', style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            setDlgState(() {
                              selectedProduct = val;
                              if (val != null) {
                                unitPriceCtrl.text = val.purchasePrice.toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Quantity to Move', isRequired: true),
                                  TextField(
                                    controller: qtyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Unit Cost'),
                                  TextField(
                                    controller: unitPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '$currency ',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Shipping Cost'),
                                  TextField(
                                    controller: shippingCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '$currency ',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _fieldLabel('Transfer Note / Shipment details'),
                        TextField(
                          controller: noteCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Sent via internal dispatch courier',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Transfer Valuation:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4338CA), fontSize: 13)),
                              Text('$currency${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF312E81))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save Stock Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
          final currency = widget.settings.currencySymbol;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: 540,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFFDC2626), size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add Stock Adjustment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Deduct damaged, expired, stolen or shrinkage stock', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Reference No', isRequired: true),
                                  TextField(
                                    controller: refCtrl,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Adjustment Type', isRequired: true),
                                  DropdownButtonFormField<String>(
                                    initialValue: type,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'normal', child: Text('Normal (Breakage, Spoiled)', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'abnormal', child: Text('Abnormal (Theft, Accident)', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (val) => setDlgState(() => type = val ?? type),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _fieldLabel('Business Location', isRequired: true),
                        DropdownButtonFormField<BusinessLocation>(
                          initialValue: location,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setDlgState(() => location = val),
                        ),
                        const SizedBox(height: 14),

                        _fieldLabel('Product to Adjust / Shrink', isRequired: true),
                        DropdownButtonFormField<Product>(
                          initialValue: selectedProduct,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          items: _products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Stock: ${p.stockQuantity.toInt()})', style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            setDlgState(() {
                              selectedProduct = val;
                              if (val != null) {
                                unitPriceCtrl.text = val.purchasePrice.toStringAsFixed(2);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Qty to Deduct', isRequired: true),
                                  TextField(
                                    controller: qtyCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Unit Cost'),
                                  TextField(
                                    controller: unitPriceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '$currency ',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Recovered Value'),
                                  TextField(
                                    controller: recoveredCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: '$currency ',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _fieldLabel('Reason for Adjustment'),
                        TextField(
                          controller: reasonCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. Broken in storage or expired',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Value Deducted:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF991B1B), fontSize: 13)),
                              Text('$currency${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Record Adjustment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
                      label: const Text('Add Transfer', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showAddTransferDialog,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
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
              labelColor: const Color(0xFF4F46E5),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF4F46E5),
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
