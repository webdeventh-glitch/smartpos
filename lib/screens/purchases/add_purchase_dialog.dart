import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AddPurchaseDialog extends StatefulWidget {
  final VoidCallback onPurchaseSaved;

  const AddPurchaseDialog({super.key, required this.onPurchaseSaved});

  @override
  State<AddPurchaseDialog> createState() => _AddPurchaseDialogState();
}

class _AddPurchaseDialogState extends State<AddPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();
  Contact? _selectedSupplier;
  Product? _selectedProduct;
  BusinessLocation? _selectedLocation;
  List<Contact> _suppliers = [];
  List<Product> _products = [];
  List<BusinessLocation> _locations = [];
  String _status = 'received';
  bool _loading = true;
  bool _isSaving = false;

  late TextEditingController _costController;
  final TextEditingController _qtyController = TextEditingController(text: '10');
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _costController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final sups = await db.getContacts(type: 'supplier');
    final prods = await db.getProducts();
    final locs = await db.getBusinessLocations();

    if (mounted) {
      setState(() {
        _suppliers = sups;
        _products = prods;
        _locations = locs;
        if (locs.isNotEmpty) _selectedLocation = locs.first;
        if (sups.isNotEmpty) _selectedSupplier = sups.first;
        if (prods.isNotEmpty) {
          _selectedProduct = prods.first;
          _costController.text = prods.first.purchasePrice.toStringAsFixed(2);
          _recalcTotal();
        }
        _loading = false;
      });
    }
  }

  void _recalcTotal() {
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final total = cost * qty;
    _paidController.text = total.toStringAsFixed(2);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedSupplier == null || _selectedProduct == null) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final refNo = await db.generateNextPurchaseRef();
      final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
      final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
      final total = cost * qty;
      final paid = double.tryParse(_paidController.text.trim()) ?? total;
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final paymentStatus = paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'due');

      final purchase = Purchase(
        refNo: refNo,
        supplierId: _selectedSupplier!.id,
        supplierName: _selectedSupplier!.name,
        locationId: _selectedLocation?.id ?? 1,
        locationName: _selectedLocation?.name ?? 'Main Branch HQ',
        totalAmount: total,
        paidAmount: paid,
        status: _status,
        paymentStatus: paymentStatus,
        createdAt: now,
        note: _noteController.text.trim(),
      );

      final items = [
        {
          'product_id': _selectedProduct!.id,
          'product_name': _selectedProduct!.name,
          'quantity': qty,
          'purchase_price': cost,
          'subtotal': total,
        }
      ];

      await db.createPurchase(purchase: purchase, items: items);
      widget.onPurchaseSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _qtyController.dispose();
    _paidController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Widget _label(String text, {bool isRequired = false}) {
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

  @override
  Widget build(BuildContext context) {
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final total = cost * qty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Receive Stock / Add Purchase',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Restock product inventories and update supplier payables',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location & Status
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Receiving Location', isRequired: true),
                                    DropdownButtonFormField<BusinessLocation>(
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      initialValue: _selectedLocation,
                                      items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name, style: const TextStyle(fontSize: 13)))).toList(),
                                      onChanged: (val) => setState(() => _selectedLocation = val),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Purchase Status', isRequired: true),
                                    DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      initialValue: _status,
                                      items: const [
                                        DropdownMenuItem(value: 'received', child: Text('Received (Add to Stock)', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'pending', child: Text('Pending Approval', style: TextStyle(fontSize: 13))),
                                        DropdownMenuItem(value: 'ordered', child: Text('Ordered (Awaiting)', style: TextStyle(fontSize: 13))),
                                      ],
                                      onChanged: (val) => setState(() => _status = val ?? 'received'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Supplier
                          _label('Select Supplier', isRequired: true),
                          DropdownButtonFormField<Contact>(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            initialValue: _selectedSupplier,
                            items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (val) => setState(() => _selectedSupplier = val),
                          ),
                          const SizedBox(height: 14),

                          // Product to Restock
                          _label('Product to Restock', isRequired: true),
                          DropdownButtonFormField<Product>(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            initialValue: _selectedProduct,
                            items: _products
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text('${p.name} (Current: ${p.stockQuantity.toInt()})', style: const TextStyle(fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedProduct = val;
                                if (val != null) {
                                  _costController.text = val.purchasePrice.toStringAsFixed(2);
                                  _recalcTotal();
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 14),

                          // Unit Cost Price & Quantity
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Unit Cost Price'),
                                    TextFormField(
                                      controller: _costController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        prefixText: '\$ ',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      onChanged: (_) => setState(_recalcTotal),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Quantity to Receive'),
                                    TextFormField(
                                      controller: _qtyController,
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
                                      onChanged: (_) => setState(_recalcTotal),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Purchase Total Card
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
                                const Text('Total Purchase Amount:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4338CA), fontSize: 13)),
                                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF312E81))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Paid Amount & Note
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Amount Paid Now'),
                                    TextFormField(
                                      controller: _paidController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        prefixText: '\$ ',
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
                                    _label('Notes / Reference'),
                                    TextFormField(
                                      controller: _noteController,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Shipment #12',
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
                            ],
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
                            onPressed: () => Navigator.pop(context),
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
                            label: Text(
                              _isSaving ? 'Processing...' : 'Save & Restock Inventory',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: _isSaving ? null : _save,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
