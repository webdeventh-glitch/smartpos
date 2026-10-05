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
          'unit_cost': cost,
          'quantity': qty,
          'subtotal': total,
        }
      ];

      await db.createPurchase(purchase: purchase, items: items);

      if (mounted) {
        widget.onPurchaseSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock received! Added ${qty.toInt()} units of ${_selectedProduct!.name} to inventory.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final total = cost * qty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping, color: Color(0xFF004EEB)),
                            SizedBox(width: 10),
                            Text(
                              'Receive Stock / Add Purchase',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Location & Status
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BusinessLocation>(
                            decoration: const InputDecoration(labelText: 'Receiving Location *', isDense: true),
                            initialValue: _selectedLocation,
                            items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc.name))).toList(),
                            onChanged: (val) => setState(() => _selectedLocation = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Purchase Status *', isDense: true),
                            initialValue: _status,
                            items: const [
                              DropdownMenuItem(value: 'received', child: Text('Received (Add to Stock)')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                              DropdownMenuItem(value: 'ordered', child: Text('Ordered (Awaiting)')),
                            ],
                            onChanged: (val) => setState(() => _status = val ?? 'received'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Supplier Dropdown
                    DropdownButtonFormField<Contact>(
                      decoration: const InputDecoration(labelText: 'Select Supplier *', isDense: true),
                      initialValue: _selectedSupplier,
                      items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (val) => setState(() => _selectedSupplier = val),
                    ),
                    const SizedBox(height: 14),

                    // Product to restock
                    DropdownButtonFormField<Product>(
                      decoration: const InputDecoration(labelText: 'Product to Restock *', isDense: true),
                      initialValue: _selectedProduct,
                      items: _products
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p.name} (Current Stock: ${p.stockQuantity.toInt()})'),
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

                    // Cost Price & Quantity
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Unit Cost Price', prefixText: '\$ ', isDense: true),
                            onChanged: (_) => setState(_recalcTotal),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity to Receive', isDense: true),
                            onChanged: (_) => setState(_recalcTotal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total & Paid Amount
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Purchase Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _paidController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount Paid to Supplier', prefixText: '\$ ', isDense: true),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'Notes / Reference', hintText: 'e.g. Shipment invoice #', isDense: true),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004EEB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(_isSaving ? 'Processing...' : 'Save & Restock Inventory', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isSaving ? null : _save,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
