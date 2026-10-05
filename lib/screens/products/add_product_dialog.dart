import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class AddProductDialog extends StatefulWidget {
  final Product? productToEdit;
  final VoidCallback onProductSaved;

  const AddProductDialog({super.key, this.productToEdit, required this.onProductSaved});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _stockController;
  late TextEditingController _alertController;

  String _selectedUnit = 'Pc';
  Category? _selectedCategory;
  Brand? _selectedBrand;
  List<Category> _categories = [];
  List<Brand> _brands = [];
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _purchasePriceController = TextEditingController(text: p != null ? p.purchasePrice.toStringAsFixed(2) : '');
    _sellingPriceController = TextEditingController(text: p != null ? p.sellingPrice.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p != null ? p.stockQuantity.toInt().toString() : '20');
    _alertController = TextEditingController(text: p != null ? p.alertQuantity.toInt().toString() : '5');
    if (p != null) _selectedUnit = p.unit;

    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final db = await DatabaseService.initialize();
    final cats = await db.getCategories();
    final brs = await db.getBrands();

    if (mounted) {
      setState(() {
        _categories = cats;
        _brands = brs;
        if (cats.isNotEmpty) {
          _selectedCategory = widget.productToEdit?.categoryId != null
              ? cats.firstWhere((c) => c.id == widget.productToEdit!.categoryId, orElse: () => cats.first)
              : cats.first;
        }
        if (brs.isNotEmpty) {
          _selectedBrand = widget.productToEdit?.brandId != null
              ? brs.firstWhere((b) => b.id == widget.productToEdit!.brandId, orElse: () => brs.first)
              : brs.first;
        }
        _loading = false;
      });
    }
  }

  void _generateSku() {
    final code = '${_selectedCategory?.code ?? "PRD"}-${1000 + Random().nextInt(9000)}';
    setState(() {
      _skuController.text = code;
      if (_barcodeController.text.isEmpty) {
        _barcodeController.text = code;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final product = Product(
        id: widget.productToEdit?.id,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? _skuController.text.trim() : _barcodeController.text.trim(),
        categoryId: _selectedCategory?.id,
        categoryName: _selectedCategory?.name ?? 'General',
        brandId: _selectedBrand?.id,
        brandName: _selectedBrand?.name ?? 'Standard',
        unit: _selectedUnit,
        purchasePrice: double.tryParse(_purchasePriceController.text.trim()) ?? 0.0,
        sellingPrice: double.tryParse(_sellingPriceController.text.trim()) ?? 0.0,
        stockQuantity: double.tryParse(_stockController.text.trim()) ?? 0.0,
        alertQuantity: double.tryParse(_alertController.text.trim()) ?? 5.0,
        imageColor: widget.productToEdit?.imageColor ?? '#004EEB',
      );

      if (widget.productToEdit == null) {
        await db.addProduct(product);
      } else {
        await db.updateProduct(product);
      }

      if (mounted) {
        widget.onProductSaved();
        Navigator.of(context).pop();
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
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _alertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.productToEdit == null ? Icons.add_box_outlined : Icons.edit_note,
                                color: const Color(0xFF004EEB),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.productToEdit == null ? 'Add New Product' : 'Edit Product',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Wireless Ergonomic Mouse',
                          isDense: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // SKU & Barcode Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              decoration: InputDecoration(
                                labelText: 'SKU (Stock Keeping Unit) *',
                                hintText: 'e.g. ELEC-1042',
                                isDense: true,
                                suffixIcon: IconButton(
                                  tooltip: 'Generate SKU',
                                  icon: const Icon(Icons.auto_fix_high, size: 18, color: Color(0xFF004EEB)),
                                  onPressed: _generateSku,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'SKU is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode (EAN/UPC/Code128)',
                                hintText: 'Leave blank to match SKU',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Category & Brand
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Category>(
                              decoration: const InputDecoration(labelText: 'Category', isDense: true),
                              initialValue: _selectedCategory,
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                              onChanged: (val) => setState(() => _selectedCategory = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<Brand>(
                              decoration: const InputDecoration(labelText: 'Brand', isDense: true),
                              initialValue: _selectedBrand,
                              items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                              onChanged: (val) => setState(() => _selectedBrand = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                              initialValue: _selectedUnit,
                              items: ['Pc', 'Kg', 'Ltr', 'Box', 'Pack', 'Can', 'Bottle', 'Bag']
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (val) => setState(() => _selectedUnit = val ?? 'Pc'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Pricing: Purchase Price & Selling Price
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Purchase / Cost Price *',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Cost price is required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Selling Price *',
                                prefixText: '\$ ',
                                isDense: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Selling price is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Initial Stock & Alert Quantity
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Opening Stock Quantity',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _alertController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Alert Quantity (Reorder Point)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004EEB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Product',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _isSaving ? null : _save,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
