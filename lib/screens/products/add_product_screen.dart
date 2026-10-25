import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p_path;
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/regional_data_service.dart';

class AddProductScreen extends StatefulWidget {
  final BusinessSettings settings;
  final Product? productToEdit;
  final VoidCallback onProductCreated;
  final VoidCallback onCancel;

  const AddProductScreen({
    super.key,
    required this.settings,
    this.productToEdit,
    required this.onProductCreated,
    required this.onCancel,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _alertQtyCtrl = TextEditingController(text: '5');
  final _purchasePriceCtrl = TextEditingController(text: '100.00');
  final _profitMarginCtrl = TextEditingController(text: '25.0');
  final _sellingPriceCtrl = TextEditingController(text: '125.00');
  final _openingStockCtrl = TextEditingController(text: '50');
  final _descCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();

  // Medication / Distribution Specific Controllers
  final _batchCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _bonusQtyCtrl = TextEditingController(text: '0');
  final _packSizeCtrl = TextEditingController(text: '1');

  // Dropdown States
  String _barcodeType = 'Code 128 (C128)';
  final List<String> _barcodeTypes = ['Code 128 (C128)', 'Code 39', 'EAN-13', 'UPC-A'];

  String _productType = 'single'; // 'single' or 'variable'
  List<ProductVariation> _variations = [];

  String _selectedUnit = 'Pieces (Pc)';
  final List<String> _units = ['Pieces (Pc)', 'Box', 'Kilogram (Kg)', 'Liter (Ltr)', 'Pack'];

  List<Category> _categories = [];
  Category? _selectedCategory;

  List<Brand> _brands = [];
  Brand? _selectedBrand;

  List<Warranty> _warranties = [];
  Warranty? _selectedWarranty;

  String? _selectedSubCategory;
  final List<String> _subCategories = ['Antibiotics', 'Analgesics', 'Cardiovascular', 'Gastrointestinal', 'Vitamins'];

  bool _manageStock = true;
  final String _selectedLocation = 'Main Branch HQ';
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedColor = '#004EEB';
  String? _pickedImagePath;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _autoGenerateSku();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _alertQtyCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _profitMarginCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _openingStockCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _batchCtrl.dispose();
    _expiryCtrl.dispose();
    _bonusQtyCtrl.dispose();
    _packSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final db = await DatabaseService.initialize();
    final cats = await db.getCategories();
    final brs = await db.getBrands();
    final wars = await db.getWarranties();
    List<ProductVariation> loadedVars = [];
    if (widget.productToEdit != null && widget.productToEdit!.id != null) {
      loadedVars = await db.getProductVariations(widget.productToEdit!.id!);
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _brands = brs;
        _warranties = wars;
        if (widget.productToEdit != null) {
          final p = widget.productToEdit!;
          _nameCtrl.text = p.name;
          _skuCtrl.text = p.sku;
          _barcodeCtrl.text = p.barcode;
          _alertQtyCtrl.text = p.alertQuantity.toString();
          _purchasePriceCtrl.text = p.purchasePrice.toStringAsFixed(2);
          final margin = p.purchasePrice > 0 ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100) : 0.0;
          _profitMarginCtrl.text = margin.toStringAsFixed(1);
          _sellingPriceCtrl.text = p.sellingPrice.toStringAsFixed(2);
          _openingStockCtrl.text = p.stockQuantity.toString();
          _barcodeType = p.barcodeType;
          _productType = p.type;
          _selectedUnit = p.unit;
          if (p.imageColor != null && File(p.imageColor!).existsSync()) {
            _pickedImagePath = p.imageColor;
            _imageCtrl.text = p_path.basename(p.imageColor!);
          } else {
            _selectedColor = p.imageColor ?? '#4F46E5';
            _imageCtrl.text = 'Badge ($_selectedColor)';
          }
          _batchCtrl.text = p.batchNumber ?? '';
          _expiryCtrl.text = p.expiryDate ?? '';
          _bonusQtyCtrl.text = p.bonusQty.toString();
          _packSizeCtrl.text = p.packSize.toString();
          _selectedCategory = cats.where((c) => c.id == p.categoryId).firstOrNull ?? (cats.isNotEmpty ? cats.first : null);
          _selectedBrand = brs.where((b) => b.id == p.brandId).firstOrNull ?? (brs.isNotEmpty ? brs.first : null);
          _selectedWarranty = wars.where((w) => w.name == p.warranty).firstOrNull ?? (wars.isNotEmpty ? wars.first : null);
          _variations = List.from(loadedVars);
        } else {
          if (cats.isNotEmpty) _selectedCategory = cats.first;
          if (brs.isNotEmpty) _selectedBrand = brs.first;
          if (wars.isNotEmpty) _selectedWarranty = wars.first;
          _autoGenerateSku();
        }
        _isLoading = false;
      });
    }
  }

  void _autoGenerateSku() {
    final rand = 1000 + Random().nextInt(9000);
    final prefix = _selectedCategory?.code.isNotEmpty == true ? _selectedCategory!.code : 'PRD';
    final sku = '$prefix-$rand';
    _skuCtrl.text = sku;
    if (_barcodeCtrl.text.isEmpty) {
      _barcodeCtrl.text = sku;
    }
  }

  void _recalcSellingPrice() {
    final purchase = double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0.0;
    final margin = double.tryParse(_profitMarginCtrl.text.trim()) ?? 0.0;
    final sell = purchase * (1 + (margin / 100));
    _sellingPriceCtrl.text = sell.toStringAsFixed(2);
  }

  void _recalcMargin() {
    final purchase = double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0.0;
    final sell = double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0.0;
    if (purchase > 0) {
      final margin = ((sell - purchase) / purchase) * 100;
      _profitMarginCtrl.text = margin.toStringAsFixed(1);
    }
  }

  void _useAiDescription() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name first to generate description with AI.')),
      );
      return;
    }
    setState(() {
      _descCtrl.text =
          'Premium quality $name designed for durability and high performance. Features advanced craftsmanship, ergonomic handling, and backed by a comprehensive 1-year manufacturer warranty.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF6366F1),
        content: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('AI Description generated successfully!'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProductImage() async {
    try {
      final picked = await NativeFileHelper.pickProductImage();
      if (picked != null) {
        setState(() {
          _pickedImagePath = picked;
          _imageCtrl.text = p_path.basename(picked);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Product image selected: ${p_path.basename(picked)}'),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking product image: $e');
    }
  }

  void _removeProductImage() {
    setState(() {
      _pickedImagePath = null;
      _imageCtrl.clear();
    });
  }

  Future<void> _pickExpiryDate([TextEditingController? targetCtrl]) async {
    final ctrl = targetCtrl ?? _expiryCtrl;
    DateTime initial = DateTime.now().add(const Duration(days: 365 * 2)); // default 2 years ahead

    // Parse existing text if valid
    final text = ctrl.text.trim();
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
        ctrl.text = formatted;
      });
    }
  }

  void _useAiImage() {
    final colors = ['#004EEB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#06B6D4'];
    final pickedColor = colors[Random().nextInt(colors.length)];
    setState(() {
      _pickedImagePath = null;
      _selectedColor = pickedColor;
      _imageCtrl.text = 'Generated Badge ($pickedColor)';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF6366F1),
        content: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Smart visual badge assigned!'),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddCategory() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name*')),
            const SizedBox(height: 12),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Short Code (e.g. ELEC)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = await DatabaseService.initialize();
      final id = await db.insertCategory(Category(
        name: nameCtrl.text.trim(),
        code: codeCtrl.text.trim().toUpperCase(),
      ));
      await _loadMetadata();
      setState(() {
        _selectedCategory = _categories.firstWhere((c) => c.id == id, orElse: () => _categories.last);
      });
    }
  }

  Future<void> _quickAddBrand() async {
    final nameCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Brand', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Brand Name*')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = await DatabaseService.initialize();
      final id = await db.insertBrand(Brand(name: nameCtrl.text.trim()));
      await _loadMetadata();
      setState(() {
        _selectedBrand = _brands.firstWhere((b) => b.id == id, orElse: () => _brands.last);
      });
    }
  }

  void _showAddVariationModal() {
    final nameCtrl = TextEditingController();
    final purchaseCtrl = TextEditingController(text: _purchasePriceCtrl.text.trim());
    final sellingCtrl = TextEditingController(text: _sellingPriceCtrl.text.trim());
    final stockCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.style, color: Color(0xFF0038B8)),
            SizedBox(width: 8),
            Text('Add Product Variation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Variation Value (e.g. Small, Medium, XL, Red)*', isDense: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: purchaseCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Purchase Price*', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: sellingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Selling Price*', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Opening Stock', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0038B8), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final valName = nameCtrl.text.trim();
              final baseSku = _skuCtrl.text.trim().isEmpty ? 'PRD' : _skuCtrl.text.trim();
              final subSku = '$baseSku-${valName.toUpperCase().replaceAll(' ', '-')}';
              final pPrice = double.tryParse(purchaseCtrl.text.trim()) ?? 0.0;
              final sPrice = double.tryParse(sellingCtrl.text.trim()) ?? 0.0;
              final st = double.tryParse(stockCtrl.text.trim()) ?? 0.0;

              setState(() {
                _variations.add(
                  ProductVariation(
                    name: valName,
                    subSku: subSku,
                    purchasePrice: pPrice,
                    sellingPrice: sPrice,
                    stockQuantity: st,
                  ),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add Variation'),
          ),
        ],
      ),
    );
  }

  Future<bool> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return false;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text('Product Name is required.')),
      );
      return false;
    }

    final purchase = double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0.0;
    final selling = double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0.0;

    if (_productType == 'single') {
      if (selling <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('Selling Price must be greater than 0.')),
        );
        return false;
      }
      if (purchase < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.red, content: Text('Purchase Price cannot be negative.')),
        );
        return false;
      }
    }

    String expRaw = _expiryCtrl.text.trim().replaceAll('/', '-');
    if (expRaw.isNotEmpty) {
      final parts = expRaw.split('-');
      if (parts.length == 2) {
        int? m = int.tryParse(parts[0]);
        int? y = int.tryParse(parts[1]);
        if (m != null && y != null && m >= 1 && m <= 12) {
          if (y < 100) y += 2000;
          expRaw = '${m.toString().padLeft(2, '0')}-$y';
          _expiryCtrl.text = expRaw;
        }
      }
      final expRegex = RegExp(r'^(0[1-9]|1[0-2])-\d{4}$|^\d{4}-(0[1-9]|1[0-2])(-\d{2})?$');
      if (!expRegex.hasMatch(expRaw)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.orange, content: Text('Expiry Date format should be MM-YYYY (e.g. 12-2028). Click calendar to select.')),
        );
        return false;
      }
    }

    if (_productType == 'variable' && _variations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Please add at least one variation (e.g. Small, Medium) for variable product.'),
        ),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final db = await DatabaseService.initialize();
      final purchase = double.tryParse(_purchasePriceCtrl.text.trim()) ?? 0.0;
      final selling = double.tryParse(_sellingPriceCtrl.text.trim()) ?? 0.0;
      final stock = _manageStock ? (double.tryParse(_openingStockCtrl.text.trim()) ?? 0.0) : 999.0;
      final alert = double.tryParse(_alertQtyCtrl.text.trim()) ?? 5.0;

      final totalVarStock = _variations.fold(0.0, (sum, v) => sum + v.stockQuantity);
      final batchVal = _batchCtrl.text.trim().isNotEmpty ? _batchCtrl.text.trim() : null;
      final expVal = _expiryCtrl.text.trim().isNotEmpty ? _expiryCtrl.text.trim() : null;
      final bonusVal = double.tryParse(_bonusQtyCtrl.text.trim()) ?? 0.0;
      final packVal = double.tryParse(_packSizeCtrl.text.trim()) ?? 1.0;

      final product = Product(
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? 'SKU-${Random().nextInt(99999)}' : _skuCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? _skuCtrl.text.trim() : _barcodeCtrl.text.trim(),
        type: _productType,
        barcodeType: _barcodeType,
        categoryId: _selectedCategory?.id,
        categoryName: _selectedCategory?.name ?? 'General',
        brandId: _selectedBrand?.id,
        brandName: _selectedBrand?.name ?? 'Standard',
        unit: _selectedUnit,
        purchasePrice: _productType == 'variable' && _variations.isNotEmpty ? _variations.first.purchasePrice : purchase,
        sellingPrice: _productType == 'variable' && _variations.isNotEmpty ? _variations.first.sellingPrice : selling,
        stockQuantity: _productType == 'variable' ? totalVarStock : stock,
        alertQuantity: alert,
        imageColor: _pickedImagePath ?? _selectedColor,
        warranty: _selectedWarranty?.name,
        batchNumber: batchVal,
        expiryDate: expVal,
        bonusQty: bonusVal,
        packSize: packVal,
      );

      if (widget.productToEdit != null && widget.productToEdit!.id != null) {
        final toUpdate = Product(
          id: widget.productToEdit!.id,
          name: _nameCtrl.text.trim(),
          sku: _skuCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          type: _productType,
          barcodeType: _barcodeType,
          categoryId: _selectedCategory?.id,
          categoryName: _selectedCategory?.name ?? 'General',
          brandId: _selectedBrand?.id,
          brandName: _selectedBrand?.name ?? 'Standard',
          unit: _selectedUnit,
          purchasePrice: _productType == 'variable' && _variations.isNotEmpty ? _variations.first.purchasePrice : purchase,
          sellingPrice: _productType == 'variable' && _variations.isNotEmpty ? _variations.first.sellingPrice : selling,
          stockQuantity: _productType == 'variable' ? totalVarStock : stock,
          alertQuantity: alert,
          imageColor: _pickedImagePath ?? _selectedColor,
          warranty: _selectedWarranty?.name,
          batchNumber: batchVal,
          expiryDate: expVal,
          bonusQty: bonusVal,
          packSize: packVal,
        );
        if (_productType == 'variable' && _variations.isNotEmpty) {
          await db.updateProductWithVariations(toUpdate, _variations);
        } else {
          await db.updateProduct(toUpdate);
        }
      } else if (_productType == 'variable' && _variations.isNotEmpty) {
        await db.addProductWithVariations(product, _variations);
      } else {
        await db.insertProduct(product);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error saving product: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false, bool hasInfo = false, String info = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          if (isRequired)
            const Text(
              '*',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
          if (hasInfo) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: info.isNotEmpty ? info : label,
              child: const Icon(Icons.info, size: 14, color: Color(0xFF06B6D4)),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF004EEB), width: 1.5),
      ),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title (matching Screenshot 4: "Add new product")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.productToEdit != null ? 'Edit product' : 'Add new product',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final success = await _saveProduct();
                                if (success) {
                                  widget.onProductCreated();
                                }
                              },
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(_isSaving ? 'Saving...' : (widget.productToEdit != null ? 'Update Product' : 'Save Product')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Main Form Container Card (White Card with Border)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Product Name | SKU | Barcode Type
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Name
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Product Name', isRequired: true),
                                  TextFormField(
                                    controller: _nameCtrl,
                                    decoration: _inputDecor('Product Name'),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // SKU
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('SKU', hasInfo: true, info: 'Stock Keeping Unit unique code'),
                                  TextFormField(
                                    controller: _skuCtrl,
                                    decoration: _inputDecor('SKU').copyWith(
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF004EEB)),
                                        tooltip: 'Auto-generate SKU',
                                        onPressed: _autoGenerateSku,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Barcode Type
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Barcode Type', isRequired: true),
                                  DropdownButtonFormField<String>(
                                    initialValue: _barcodeType,
                                    decoration: _inputDecor(''),
                                    items: _barcodeTypes
                                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _barcodeType = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Stacked layout on smaller screens
                        return Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Product Name', isRequired: true),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: _inputDecor('Product Name'),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('SKU', hasInfo: true, info: 'Stock Keeping Unit'),
                                TextFormField(controller: _skuCtrl, decoration: _inputDecor('SKU')),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Barcode Type', isRequired: true),
                                DropdownButtonFormField<String>(
                                  initialValue: _barcodeType,
                                  decoration: _inputDecor(''),
                                  items: _barcodeTypes
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _barcodeType = val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    }),
                    const SizedBox(height: 20),

                    // ROW 2: Unit | Brand | Category
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Unit with [+] button
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Unit', isRequired: true),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedUnit,
                                          decoration: _inputDecor('Please Select'),
                                          items: _units
                                              .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedUnit = val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildPlusButton(() {
                                        // Quick add unit
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Unit management available in Settings.')),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Brand with [+] button
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Brand'),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<Brand>(
                                          initialValue: _selectedBrand,
                                          decoration: _inputDecor('Please Select'),
                                          items: _brands
                                              .map((b) => DropdownMenuItem(value: b, child: Text(b.name, style: const TextStyle(fontSize: 13))))
                                              .toList(),
                                          onChanged: (val) => setState(() => _selectedBrand = val),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildPlusButton(_quickAddBrand),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Category with [+] button
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Category'),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<Category>(
                                          initialValue: _selectedCategory,
                                          decoration: _inputDecor('Please Select'),
                                          items: _categories
                                              .map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 13))))
                                              .toList(),
                                          onChanged: (val) {
                                            setState(() => _selectedCategory = val);
                                            _autoGenerateSku();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildPlusButton(_quickAddCategory),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Unit', isRequired: true),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedUnit,
                                  decoration: _inputDecor('Please Select'),
                                  items: _units
                                      .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedUnit = val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Category'),
                                DropdownButtonFormField<Category>(
                                  initialValue: _selectedCategory,
                                  decoration: _inputDecor('Please Select'),
                                  items: _categories
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    }),
                    const SizedBox(height: 20),

                    // ROW 3: Sub Category | Business Locations
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sub category
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Sub category'),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedSubCategory,
                                    hint: const Text('Please Select', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                    decoration: _inputDecor('Please Select'),
                                    items: _subCategories
                                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedSubCategory = val),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Business Locations
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Business Locations', hasInfo: true, info: 'Location where product is available'),
                                  Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.close, size: 14, color: Colors.white),
                                              const SizedBox(width: 4),
                                              Text(
                                                _selectedLocation,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Warranty
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Warranty', hasInfo: true, info: 'Product warranty terms'),
                                  DropdownButtonFormField<Warranty>(
                                    initialValue: _selectedWarranty,
                                    hint: const Text('No Warranty', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                    decoration: _inputDecor('Please Select'),
                                    items: _warranties
                                        .map((w) => DropdownMenuItem(
                                              value: w,
                                              child: Text(w.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedWarranty = val),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Sub category'),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSubCategory,
                                  hint: const Text('Please Select', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                                  decoration: _inputDecor('Please Select'),
                                  items: _subCategories
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedSubCategory = val),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    }),
                    const SizedBox(height: 20),

                    // ROW 4: Manage Stock Checkbox | Alert Quantity
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _manageStock,
                          activeColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => setState(() => _manageStock = val ?? true),
                        ),
                        InkWell(
                          onTap: () => setState(() => _manageStock = !_manageStock),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'Manage Stock?',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.info, size: 14, color: Color(0xFF06B6D4)),
                                ],
                              ),
                              const Text(
                                'Enable stock management at product level',
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        if (_manageStock) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Alert quantity', hasInfo: true, info: 'Notify when stock falls below this number'),
                              SizedBox(
                                width: 160,
                                child: TextFormField(
                                  controller: _alertQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecor('Alert quantity'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Industry & Pharmacy Specific Card: Batch No, Expiry Date, Bonus Qty, Pack Size
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.settings.isPharmacy ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.settings.isPharmacy ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 18,
                                color: widget.settings.isPharmacy ? const Color(0xFF16A34A) : const Color(0xFF0038B8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.settings.isPharmacy
                                    ? 'Pharmaceutical Specifications (Batch, Expiry & Bonus Scheme)'
                                    : 'Extended Product Specifications (Batch, Expiry & Pack Size)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: widget.settings.isPharmacy ? const Color(0xFF166534) : const Color(0xFF1E293B),
                                ),
                              ),
                              if (widget.settings.isPharmacy) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Text(
                                    'Drug Act 1976 Compliant',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 800;
                            if (isWide) {
                              return Row(
                                children: [
                                  // Batch Number
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Batch Number', hasInfo: true, info: 'Manufacturer lot/batch number'),
                                        TextFormField(
                                          controller: _batchCtrl,
                                          decoration: _inputDecor('e.g. 02260 or DW001'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Expiry Date
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Expiry Date', hasInfo: true, info: 'MM-YYYY format e.g. 12-2028 (Click calendar to pick)'),
                                        TextFormField(
                                          controller: _expiryCtrl,
                                          decoration: _inputDecor('MM-YYYY (e.g. 12-2028)').copyWith(
                                            suffixIcon: IconButton(
                                              icon: const Icon(Icons.calendar_month, size: 20, color: Color(0xFF004EEB)),
                                              tooltip: 'Select Expiry Date',
                                              onPressed: () => _pickExpiryDate(_expiryCtrl),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Bonus Quantity
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Bonus Scheme / Free Qty', hasInfo: true, info: 'Free units given per deal'),
                                        TextFormField(
                                          controller: _bonusQtyCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDecor('0'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Pack Size
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Pack Size / Multiplier', hasInfo: true, info: 'Units per retail pack'),
                                        TextFormField(
                                          controller: _packSizeCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: _inputDecor('1'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Batch Number'),
                                            TextFormField(controller: _batchCtrl, decoration: _inputDecor('Batch #')),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Expiry (MM-YYYY)'),
                                            TextFormField(
                                              controller: _expiryCtrl,
                                              decoration: _inputDecor('12-2028').copyWith(
                                                suffixIcon: IconButton(
                                                  icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF004EEB)),
                                                  tooltip: 'Select Expiry Date',
                                                  onPressed: () => _pickExpiryDate(_expiryCtrl),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Bonus Qty'),
                                            TextFormField(controller: _bonusQtyCtrl, decoration: _inputDecor('0')),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildFieldLabel('Pack Size'),
                                            TextFormField(controller: _packSizeCtrl, decoration: _inputDecor('1')),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ROW 5: Product Description (with AI + WYSIWYG) & Product Image
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Description
                            Expanded(
                              flex: 7,
                              child: _buildDescriptionSection(),
                            ),
                            const SizedBox(width: 24),

                            // Product Image
                            Expanded(
                              flex: 5,
                              child: _buildImageSection(),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildDescriptionSection(),
                            const SizedBox(height: 20),
                            _buildImageSection(),
                          ],
                        );
                      }
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Pricing & Stock Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Product Type & Pricing Engine',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        // Segmented Button Toggle for Single vs Variable Product
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _productType = 'single'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _productType == 'single' ? const Color(0xFF0038B8) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Single Product',
                                    style: TextStyle(
                                      color: _productType == 'single' ? Colors.white : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => setState(() => _productType = 'variable'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _productType == 'variable' ? const Color(0xFF0038B8) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Variable Product',
                                    style: TextStyle(
                                      color: _productType == 'variable' ? Colors.white : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_productType == 'single') ...[
                      Row(
                        children: [
                          // Purchase Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Purchase Price ($currency)*', isRequired: true),
                                TextFormField(
                                  controller: _purchasePriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecor('0.00'),
                                  onChanged: (_) => _recalcSellingPrice(),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Profit Margin (%)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Profit Margin (%)'),
                                TextFormField(
                                  controller: _profitMarginCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecor('25.0'),
                                  onChanged: (_) => _recalcSellingPrice(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Selling Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Selling Price ($currency)*', isRequired: true),
                                TextFormField(
                                  controller: _sellingPriceCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: _inputDecor('0.00'),
                                  onChanged: (_) => _recalcMargin(),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Opening Stock
                          if (_manageStock)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Opening Stock (Units)'),
                                  TextFormField(
                                    controller: _openingStockCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDecor('50'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ] else ...[
                      // Variable Product Variations Matrix
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Variations Matrix (${_variations.length} variations configured)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0038B8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Variation Option'),
                            onPressed: _showAddVariationModal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_variations.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.style_outlined, size: 36, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text(
                                'No variations added yet.',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Click "+ Add Variation Option" to define variants like Small, Medium, Large or Color choices.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      else
                        Table(
                          border: TableBorder.all(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(2.5),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.2),
                            5: FixedColumnWidth(60),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: [
                                Padding(padding: EdgeInsets.all(10), child: Text('Variation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(10), child: Text('Sub-SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(10), child: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(10), child: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(10), child: Text('Opening Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                Padding(padding: EdgeInsets.all(10), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              ],
                            ),
                            ..._variations.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final v = entry.value;
                              return TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(10), child: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Padding(padding: const EdgeInsets.all(10), child: Text(v.subSku, style: const TextStyle(fontFamily: 'monospace'))),
                                  Padding(padding: const EdgeInsets.all(10), child: Text('$currency${v.purchasePrice.toStringAsFixed(2)}')),
                                  Padding(padding: const EdgeInsets.all(10), child: Text('$currency${v.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A)))),
                                  Padding(padding: const EdgeInsets.all(10), child: Text('${v.stockQuantity.toInt()} Pcs')),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => setState(() => _variations.removeAt(idx)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bottom Actions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      foregroundColor: const Color(0xFF475569),
                    ),
                    onPressed: widget.onCancel,
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      side: const BorderSide(color: Color(0xFF004EEB)),
                      foregroundColor: const Color(0xFF004EEB),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await _saveProduct();
                      if (!mounted) return;
                      if (success) {
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF10B981),
                            content: Text('Product added successfully! Enter next product.'),
                          ),
                        );
                        _nameCtrl.clear();
                        _autoGenerateSku();
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Save & Add Another', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: const Color(0xFF004EEB),
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final success = await _saveProduct();
                            if (success) {
                              widget.onProductCreated();
                            }
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlusButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF004EEB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Icon(Icons.add, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel('Product Description:'),
            InkWell(
              onTap: _useAiDescription,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Use AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Rich Editor Simulation (matching Screenshot 4 WYSIWYG)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            children: [
              // WYSIWYG Menus (My Favorites | File | Edit | View | Insert | Format | Tools | Table | Help)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in ['My Favorites', 'File', 'Edit', 'View', 'Insert', 'Format', 'Tools', 'Table', 'Help'])
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            m,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // WYSIWYG Icons Bar (Undo, Redo, Paragraph, B, I, Alignments, etc.)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.undo, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Icon(Icons.redo, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: const [
                          Text('Paragraph', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                          Icon(Icons.arrow_drop_down, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.format_bold, size: 16, color: Color(0xFF0F172A)),
                    const SizedBox(width: 8),
                    const Icon(Icons.format_italic, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 12),
                    const Icon(Icons.format_align_left, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Icon(Icons.format_align_center, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Icon(Icons.format_align_right, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Icon(Icons.format_align_justify, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 12),
                    const Icon(Icons.more_horiz, size: 16, color: Color(0xFF475569)),
                  ],
                ),
              ),

              // Actual text field area
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter product description, key highlights, specifications...',
                  hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildFieldLabel('Product image:'),
            InkWell(
              onTap: _useAiImage,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Use AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // File upload row (matching Screenshot 4)
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _imageCtrl.text.isEmpty ? 'No file selected' : _imageCtrl.text,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            InkWell(
              onTap: _pickProductImage,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF004EEB),
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.folder_open, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Browse..', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Max File size: 5MB • Formats: PNG, JPG, JPEG, WEBP\nAspect ratio: 1:1 recommended',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
        ),

        const SizedBox(height: 12),
        // Live swatch or image preview
        Row(
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: (_pickedImagePath != null && File(_pickedImagePath!).existsSync())
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_pickedImagePath!),
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Color(int.tryParse(_selectedColor.replaceFirst('#', '0xFF')) ?? 0xFF004EEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.inventory_2, color: Colors.white, size: 28),
                      ),
                    ),
            ),
            if (_pickedImagePath != null && File(_pickedImagePath!).existsSync()) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _removeProductImage,
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Remove Image', style: TextStyle(color: Colors.red, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
