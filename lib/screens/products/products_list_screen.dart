import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import 'add_product_dialog.dart';
import 'product_detail_dialog.dart';
import 'print_labels_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onNavigateToAddProduct;
  final Function(Product)? onNavigateToEditProduct;
  final Function(Product?)? onNavigateToPrintLabels;

  const ProductsListScreen({
    super.key,
    required this.settings,
    this.onNavigateToAddProduct,
    this.onNavigateToEditProduct,
    this.onNavigateToPrintLabels,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  List<Product> _allProducts = [];
  List<Category> _categories = [];
  List<Brand> _brands = [];

  // Filter States
  int? _selectedCategory;
  int? _selectedBrand;
  String _stockFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  String _typeFilter = 'all'; // 'all', 'single', 'variable'
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final prods = await db.getProducts();
    final cats = await db.getCategories();
    final brs = await db.getBrands();

    if (mounted) {
      setState(() {
        _allProducts = prods;
        _categories = cats;
        _brands = brs;
        _loading = false;
      });
    }
  }

  void _openAddProduct([Product? toEdit]) {
    if (widget.onNavigateToAddProduct != null && toEdit == null) {
      widget.onNavigateToAddProduct!();
    } else if (widget.onNavigateToEditProduct != null && toEdit != null) {
      widget.onNavigateToEditProduct!(toEdit);
    } else {
      showDialog(
        context: context,
        builder: (_) => AddProductDialog(
          productToEdit: toEdit,
          onProductSaved: _load,
        ),
      );
    }
  }

  void _viewProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (_) => ProductDetailDialog(
        product: product,
        settings: widget.settings,
        onEdit: () => _openAddProduct(product),
        onPrintLabels: () {
          if (widget.onNavigateToPrintLabels != null) {
            widget.onNavigateToPrintLabels!(product);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrintLabelsScreen(settings: widget.settings, initialProduct: product),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _delete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to permanently delete "${product.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && product.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteProduct(product.id!);
      _load();
    }
  }

  List<Product> _getFilteredProducts() {
    return _allProducts.where((p) {
      if (_selectedCategory != null && p.categoryId != _selectedCategory) return false;
      if (_selectedBrand != null && p.brandId != _selectedBrand) return false;

      if (_typeFilter != 'all' && p.type != _typeFilter) return false;

      if (_stockFilter == 'in_stock' && p.isOutOfStock) return false;
      if (_stockFilter == 'low_stock' && !p.isLowStock) return false;
      if (_stockFilter == 'out_of_stock' && !p.isOutOfStock) return false;

      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final match = p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.toLowerCase().contains(q) ||
            p.categoryName.toLowerCase().contains(q) ||
            p.brandName.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final filtered = _getFilteredProducts();

    final totalInventoryValue = filtered.fold(0.0, (sum, p) => sum + (p.sellingPrice * p.stockQuantity));
    final totalUnitsCount = filtered.fold(0.0, (sum, p) => sum + p.stockQuantity);
    final lowStockCount = _allProducts.where((p) => p.isLowStock || p.isOutOfStock).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Products & Catalog',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your inventory catalog, pricing margins, SKU barcodes, and stock levels.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Print Labels'),
                      onPressed: () {
                        final prod = filtered.isNotEmpty ? filtered.first : (_allProducts.isNotEmpty ? _allProducts.first : null);
                        if (widget.onNavigateToPrintLabels != null) {
                          widget.onNavigateToPrintLabels!(prod);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrintLabelsScreen(settings: widget.settings, initialProduct: prod),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => _openAddProduct(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Metrics Summary Bar
            Row(
              children: [
                Expanded(
                  child: _metricCard('Total Products', '${_allProducts.length} SKUs', Icons.inventory_2_outlined, const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    'Low / Out of Stock',
                    '$lowStockCount items',
                    Icons.warning_amber_rounded,
                    lowStockCount > 0 ? const Color(0xFFEA580C) : const Color(0xFF059669),
                    lowStockCount > 0 ? const Color(0xFFFFEDD5) : const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard('Total Units in Stock', '${totalUnitsCount.toStringAsFixed(0)} Units', Icons.stacked_bar_chart_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard('Inventory Retail Value', '$currency${totalInventoryValue.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined, const Color(0xFF059669), const Color(0xFFECFDF5)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Comprehensive Multi-Faceted Filter Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Field
                      Expanded(
                        flex: 3,
                        child: TextField(
                          onChanged: (val) => setState(() => _search = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search product name, SKU, or barcode...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Category Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          value: _selectedCategory,
                          decoration: _dropdownDeco('Category'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Categories')),
                            ..._categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Brand Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          value: _selectedBrand,
                          decoration: _dropdownDeco('Brand'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Brands')),
                            ..._brands.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() => _selectedBrand = val),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stock Status Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _stockFilter,
                          decoration: _dropdownDeco('Stock Status'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Stock Levels')),
                            DropdownMenuItem(value: 'in_stock', child: Text('In Stock')),
                            DropdownMenuItem(value: 'low_stock', child: Text('Low Stock Alert')),
                            DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _stockFilter = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reset Button
                      if (_selectedCategory != null || _selectedBrand != null || _stockFilter != 'all' || _search.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear Filters',
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedBrand = null;
                              _stockFilter = 'all';
                              _search = '';
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Products Data Table
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No Products Matching Criteria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Try adjusting your search filters or click "Add Product" to add items.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3.0), // Product Name & Type
                      1: FlexColumnWidth(1.8), // SKU & Barcode
                      2: FlexColumnWidth(1.8), // Category / Brand
                      3: FlexColumnWidth(1.3), // Cost Price
                      4: FlexColumnWidth(1.6), // Selling Price (Margin)
                      5: FlexColumnWidth(1.4), // Stock Quantity
                      6: FlexColumnWidth(1.4), // Actions
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          _th('Product Item'),
                          _th('SKU / Barcode'),
                          _th('Category / Brand'),
                          _th('Cost Price'),
                          _th('Selling Price'),
                          _th('Current Stock'),
                          _th('Actions', alignRight: true),
                        ],
                      ),
                      ...filtered.map((p) {
                        final margin = p.purchasePrice > 0
                            ? (((p.sellingPrice - p.purchasePrice) / p.purchasePrice) * 100)
                            : 0.0;

                        return TableRow(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          children: [
                            // Product Item & Type
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                          onTap: () => _viewProductDetails(p),
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: p.isVariable ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p.isVariable ? 'Variable' : 'Single',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: p.isVariable ? const Color(0xFF7C3AED) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(p.unit, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // SKU & Barcode
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.sku, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                                  Text(p.barcode, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),

                            // Category & Brand
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.categoryName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                  Text(p.brandName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),

                            // Cost Price
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                '$currency${p.purchasePrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),

                            // Selling Price & Margin
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$currency${p.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                                  ),
                                  Text(
                                    '+${margin.toStringAsFixed(1)}% margin',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),

                            // Stock Quantity & Alert Status
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.isOutOfStock
                                      ? const Color(0xFFFEF2F2)
                                      : (p.isLowStock ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${p.stockQuantity.toStringAsFixed(1)} ${p.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.isOutOfStock
                                        ? const Color(0xFFDC2626)
                                        : (p.isLowStock ? const Color(0xFFD97706) : const Color(0xFF059669)),
                                  ),
                                ),
                              ),
                            ),

                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'View Specs',
                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                                    onPressed: () => _viewProductDetails(p),
                                  ),
                                  IconButton(
                                    tooltip: 'Print Barcode Label',
                                    icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF4F46E5)),
                                    onPressed: () {
                                      if (widget.onNavigateToPrintLabels != null) {
                                        widget.onNavigateToPrintLabels!(p);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PrintLabelsScreen(settings: widget.settings, initialProduct: p),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Edit Product',
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF4F46E5)),
                                    onPressed: () => _openAddProduct(p),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete Product',
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                    onPressed: () => _delete(p),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }

  Widget _th(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      ),
    );
  }
}
