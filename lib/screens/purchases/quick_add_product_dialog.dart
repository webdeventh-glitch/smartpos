import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/searchable_select_dialog.dart';

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
  List<String> _unitOptions = const [
    'Pieces (Pc)',
    'Box (Box)',
    'Strip (Strip)',
    'Kilograms (Kg)',
    'Liters (Ltr)',
    'Pack (Pack)',
  ];
  String _unit = 'Pieces (Pc)';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _generalError;

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
    final units = await db.getUnits();
    final labels = <String>[];
    for (final u in units) {
      final label = u.shortName.isNotEmpty &&
              u.shortName.toLowerCase() != u.actualName.toLowerCase()
          ? '${u.actualName} (${u.shortName})'
          : u.actualName;
      if (!labels.contains(label)) labels.add(label);
    }
    if (mounted) {
      setState(() {
        _categories = cats;
        if (cats.isNotEmpty) _selectedCategory = cats.first;
        if (labels.isNotEmpty) {
          _unitOptions = labels;
          _unit = labels.firstWhere(
            (l) =>
                l.toLowerCase().contains('piece') ||
                l.toLowerCase().contains('(pc)'),
            orElse: () => labels.first,
          );
        }
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
    setState(() => _generalError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final db = await DatabaseService.initialize();
      final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
      final selling = double.tryParse(_sellingCtrl.text.trim()) ?? cost;
      if (cost > 0 && selling < cost) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _generalError = PosLocalization.tr(
                'Loss Guard: Selling price cannot be lower than purchase cost!');
          });
        }
        return;
      }
      final sku = _skuCtrl.text.trim().isNotEmpty
          ? _skuCtrl.text.trim()
          : 'SKU-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final barcode =
          _barcodeCtrl.text.trim().isNotEmpty ? _barcodeCtrl.text.trim() : sku;

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
        setState(() {
          _generalError = 'Failed to add product: $e';
        });
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
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final inputDeco = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor)),
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
            BoxShadow(
                color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: bgHeader,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.add_box_rounded,
                                color: Color(0xFF10B981), size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              PosLocalization.tr(
                                  'Quick Add New Product to Catalog'),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary),
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
                          if (_generalError != null) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _generalError!,
                                      style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(PosLocalization.tr('Product Name *'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _nameCtrl,
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(
                                          hintText: PosLocalization.tr(
                                              'e.g. Panadol 500mg Strip')),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Product name required'
                                              : null,
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
                                    Text(PosLocalization.tr('Category'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    SearchableDropdownField<Category>(
                                      selectedItem: _selectedCategory,
                                      items: _categories,
                                      labelBuilder: (c) => c.name,
                                      placeholder: 'Select Category...',
                                      searchHint: 'Search category...',
                                      prefixIcon: Icons.category_outlined,
                                      height: 40,
                                      allowClear: true,
                                      onChanged: (val) => setState(
                                          () => _selectedCategory = val),
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
                                    Text(PosLocalization.tr('SKU Code'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _skuCtrl,
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(
                                          hintText: PosLocalization.tr(
                                              'Leave blank to autogenerate')),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(PosLocalization.tr('Barcode'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _barcodeCtrl,
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      decoration: inputDeco.copyWith(
                                          hintText: PosLocalization.tr(
                                              'Scan or leave blank')),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(PosLocalization.tr('Unit'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    DropdownButtonFormField<String>(
                                      dropdownColor: cardBg,
                                      isExpanded: true,
                                      decoration: inputDeco,
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      initialValue: _unitOptions.contains(_unit)
                                          ? _unit
                                          : _unitOptions.first,
                                      items: _unitOptions
                                          .map((u) => DropdownMenuItem(
                                                value: u,
                                                child: Text(
                                                  u,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (val) => setState(() =>
                                          _unit = val ?? _unitOptions.first),
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
                                    Text('Cost Price ($currency) *',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _costCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      decoration: inputDeco,
                                      onChanged: _onCostChanged,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Cost required'
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(PosLocalization.tr('Profit Margin %'),
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _marginCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
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
                                    Text('Selling Price ($currency) *',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 5),
                                    TextFormField(
                                      controller: _sellingCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      style: TextStyle(
                                          fontSize: 13, color: textPrimary),
                                      decoration: inputDeco,
                                      onChanged: _onSellingChanged,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Selling price required'
                                              : null,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: bgHeader,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14)),
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(PosLocalization.tr('Cancel')),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 17),
                            label: Text(
                                PosLocalization.tr('Save & Add to Bill'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
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
