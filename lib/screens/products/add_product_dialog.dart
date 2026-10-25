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
  late TextEditingController _batchController;
  late TextEditingController _expiryController;
  late TextEditingController _bonusController;
  late TextEditingController _packSizeController;

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
    _batchController = TextEditingController(text: p?.batchNumber ?? '');
    _expiryController = TextEditingController(text: p?.expiryDate ?? '');
    _bonusController = TextEditingController(text: p?.bonusQty != null ? p!.bonusQty.toString() : '0');
    _packSizeController = TextEditingController(text: p?.packSize != null ? p!.packSize.toString() : '1');
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
        batchNumber: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        expiryDate: _expiryController.text.trim().isNotEmpty ? _expiryController.text.trim() : null,
        bonusQty: double.tryParse(_bonusController.text.trim()) ?? 0.0,
        packSize: double.tryParse(_packSizeController.text.trim()) ?? 1.0,
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

  Future<void> _pickExpiryDate() async {
    DateTime initial = DateTime.now().add(const Duration(days: 365 * 2));
    final text = _expiryController.text.trim();
    if (text.isNotEmpty) {
      try {
        final clean = text.replaceAll('/', '-');
        final parts = clean.split('-');
        if (parts.length == 2) {
          int m = int.tryParse(parts[0]) ?? 1;
          int y = int.tryParse(parts[1]) ?? DateTime.now().year;
          if (parts[0].length == 4) {
            y = int.tryParse(parts[0]) ?? DateTime.now().year;
            m = int.tryParse(parts[1]) ?? 1;
          }
          if (y < 100) y += 2000;
          if (m >= 1 && m <= 12) {
            initial = DateTime(y, m, 1);
          }
        }
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT EXPIRY DATE',
    );

    if (picked != null) {
      final formatted = '${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      setState(() {
        _expiryController.text = formatted;
      });
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
    _batchController.dispose();
    _expiryController.dispose();
    _bonusController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
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
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF004EEB),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.productToEdit == null ? 'Add New Product' : 'Edit Product',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

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
                      const SizedBox(height: 14),

                      // Pharma / Distribution: Batch Number & Expiry Date (MM-YYYY)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _batchController,
                              decoration: const InputDecoration(
                                labelText: 'Batch No (e.g. 02260)',
                                hintText: 'Lot number',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _expiryController,
                              decoration: InputDecoration(
                                labelText: 'Expiry Date (MM-YYYY)',
                                hintText: 'e.g. 12-2028',
                                isDense: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF004EEB)),
                                  tooltip: 'Select Expiry Date',
                                  onPressed: _pickExpiryDate,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: _bonusController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bonus Free',
                                hintText: '0',
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
                            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              elevation: 0,
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
