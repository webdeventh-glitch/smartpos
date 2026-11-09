import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class QuickAddProductDialog extends StatefulWidget {
  final BusinessSettings settings;

  const QuickAddProductDialog({super.key, required this.settings});

  @override
  State<QuickAddProductDialog> createState() => _QuickAddProductDialogState();
}

class _QuickAddProductDialogState extends State<QuickAddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '100.00');
  final _marginCtrl = TextEditingController(text: '25.0');
  final _sellingCtrl = TextEditingController(text: '125.00');

  List<Category> _categories = [];
  Category? _selectedCategory;
  String _unit = 'Pc';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _costCtrl.dispose();
    _marginCtrl.dispose();
    _sellingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final db = await DatabaseService.initialize();
    final cats = await db.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (cats.isNotEmpty) _selectedCategory = cats.first;
        _isLoading = false;
      });
    }
  }

  void _onCostChanged(String val) {
    final cost = double.tryParse(val.trim()) ?? 0.0;
    final margin = double.tryParse(_marginCtrl.text.trim()) ?? 0.0;
    if (cost > 0) {
      final sell = cost * (1 + (margin / 100));
      _sellingCtrl.text = sell.toStringAsFixed(2);
    }
  }

  void _onMarginChanged(String val) {
    final margin = double.tryParse(val.trim()) ?? 0.0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    if (cost > 0) {
      final sell = cost * (1 + (margin / 100));
      _sellingCtrl.text = sell.toStringAsFixed(2);
    }
  }

  void _onSellingChanged(String val) {
    final sell = double.tryParse(val.trim()) ?? 0.0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
    if (cost > 0 && sell > cost) {
      final margin = ((sell - cost) / cost) * 100;
      _marginCtrl.text = margin.toStringAsFixed(1);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
      final selling = double.tryParse(_sellingCtrl.text.trim()) ?? cost;
      final sku = _skuCtrl.text.trim().isNotEmpty ? _skuCtrl.text.trim() : 'SKU-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final barcode = _barcodeCtrl.text.trim().isNotEmpty ? _barcodeCtrl.text.trim() : sku;

      final prod = Product(
        name: _nameCtrl.text.trim(),
        sku: sku,
        barcode: barcode,
        categoryId: _selectedCategory?.id,
        categoryName: _selectedCategory?.name ?? 'General',
        unit: _unit,
        purchasePrice: cost,
        sellingPrice: selling,
        stockQuantity: 0.0, // Quantity will be added by the purchase invoice!
        alertQuantity: 5.0,
      );

      final id = await db.addProduct(prod);
      final createdProduct = Product(
        id: id,
        name: prod.name,
        sku: prod.sku,
        barcode: prod.barcode,
        categoryId: prod.categoryId,
        categoryName: prod.categoryName,
        unit: prod.unit,
        purchasePrice: prod.purchasePrice,
        sellingPrice: prod.sellingPrice,
        stockQuantity: 0.0,
        alertQuantity: prod.alertQuantity,
      );

      if (mounted) {
        Navigator.of(context).pop(createdProduct);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add product: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgHeader = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inputDeco = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: _isLoading
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgHeader,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.add_box_rounded, color: Color(0xFF10B981), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Quick Add New Product to Catalog',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Product Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _nameCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(hintText: 'e.g. Panadol 500mg Strip'),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name required' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    DropdownButtonFormField<Category>(
                                      dropdownColor: cardBg,
                                      decoration: inputDeco,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      initialValue: _selectedCategory,
                                      items: _categories
                                          .map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: TextStyle(fontSize: 13, color: textPrimary))))
                                          .toList(),
                                      onChanged: (val) => setState(() => _selectedCategory = val),
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
                                    Text('SKU Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _skuCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(hintText: 'Leave blank to autogenerate'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Barcode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _barcodeCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(hintText: 'Scan or leave blank'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    DropdownButtonFormField<String>(
                                      dropdownColor: cardBg,
                                      decoration: inputDeco,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      initialValue: _unit,
                                      items: const [
                                        DropdownMenuItem(value: 'Pc', child: Text('Pieces (Pc)')),
                                        DropdownMenuItem(value: 'Box', child: Text('Box / Carton')),
                                        DropdownMenuItem(value: 'Strip', child: Text('Strip')),
                                        DropdownMenuItem(value: 'Kg', child: Text('Kilogram (Kg)')),
                                        DropdownMenuItem(value: 'Ltr', child: Text('Liter (Ltr)')),
                                        DropdownMenuItem(value: 'Pack', child: Text('Pack')),
                                      ],
                                      onChanged: (val) => setState(() => _unit = val ?? 'Pc'),
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
                                    Text('Cost Price ($currency) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _costCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco,
                                      onChanged: _onCostChanged,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Cost required' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Profit Margin %', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _marginCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco,
                                      onChanged: _onMarginChanged,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Selling Price ($currency) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _sellingCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: inputDeco,
                                      onChanged: _onSellingChanged,
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Selling price required' : null,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: bgHeader,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 17),
                            label: const Text('Save & Add to Bill', style: TextStyle(fontWeight: FontWeight.bold)),
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
