import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import 'add_product_dialog.dart';

class ProductsListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onNavigateToAddProduct;

  const ProductsListScreen({super.key, required this.settings, this.onNavigateToAddProduct});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  int? _selectedCategory;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final prods = await db.getProducts(categoryId: _selectedCategory, search: _search);
    final cats = await db.getCategories();

    if (mounted) {
      setState(() {
        _products = prods;
        _categories = cats;
        _loading = false;
      });
    }
  }

  void _openAddProduct([Product? toEdit]) {
    showDialog(
      context: context,
      builder: (_) => AddProductDialog(
        productToEdit: toEdit,
        onProductSaved: _load,
      ),
    );
  }

  Future<void> _delete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
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

    if (confirm == true && product.id != null) {
      final db = await DatabaseService.initialize();
      await db.deleteProduct(product.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalInventoryValue = _products.fold(0.0, (sum, p) => sum + (p.sellingPrice * p.stockQuantity));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Products & Catalog',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your inventory items, pricing, SKU barcodes, and stock levels.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004EEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (widget.onNavigateToAddProduct != null) {
                      widget.onNavigateToAddProduct!();
                    } else {
                      _openAddProduct();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics Summary Bar
            Row(
              children: [
                _miniMetric('Total Products', '${_products.length} SKUs', Icons.inventory_2_outlined, const Color(0xFF004EEB)),
                const SizedBox(width: 14),
                _miniMetric(
                  'Low Stock Alerts',
                  '${_products.where((p) => p.isLowStock || p.isOutOfStock).length} items',
                  Icons.warning_amber_rounded,
                  const Color(0xFFEF4444),
                ),
                const SizedBox(width: 14),
                _miniMetric(
                  'Inventory Retail Value',
                  '$currency${totalInventoryValue.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF10B981),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search product by name, SKU or barcode...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        _search = val;
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category Filter', isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedCategory = val);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Products Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                  : _products.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No products found matching criteria.', style: TextStyle(color: Colors.grey))),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569), fontSize: 12),
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('PRODUCT')),
                              DataColumn(label: Text('SKU / BARCODE')),
                              DataColumn(label: Text('CATEGORY')),
                              DataColumn(label: Text('COST PRICE')),
                              DataColumn(label: Text('SELLING PRICE')),
                              DataColumn(label: Text('CURRENT STOCK')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('ACTIONS')),
                            ],
                            rows: _products.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF004EEB)),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(p.sku, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                  DataCell(Text(p.categoryName, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text('$currency${p.purchasePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                                  DataCell(Text('$currency${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                  DataCell(Text('${p.stockQuantity.toInt()} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                  DataCell(StatusPill(status: p.isOutOfStock ? 'out_of_stock' : (p.isLowStock ? 'low_stock' : 'in_stock'))),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF004EEB)),
                                          tooltip: 'Edit Product',
                                          onPressed: () => _openAddProduct(p),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                          tooltip: 'Delete Product',
                                          onPressed: () => _delete(p),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
