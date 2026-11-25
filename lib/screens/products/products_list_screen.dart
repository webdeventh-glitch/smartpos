import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/data_table_pagination_bar.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/skeleton_loader.dart';
import 'add_product_dialog.dart';
import 'add_product_screen.dart';
import 'product_detail_dialog.dart';
import 'print_labels_screen.dart';
import '../../services/print_service.dart';
import '../../services/localization_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/universal_print_preview_dialog.dart';
import '../purchases/add_purchase_screen.dart';

class ProductsListScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback? onNavigateToAddProduct;
  final Function(Product)? onNavigateToEditProduct;
  final Function(Product)? onNavigateToDuplicateProduct;
  final Function(Product?)? onNavigateToPrintLabels;

  const ProductsListScreen({
    super.key,
    required this.settings,
    this.onNavigateToAddProduct,
    this.onNavigateToEditProduct,
    this.onNavigateToDuplicateProduct,
    this.onNavigateToPrintLabels,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  List<Brand> _brands = [];

  // Filter States
  int? _selectedCategory;
  int? _selectedBrand;
  String _stockFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  final String _typeFilter = 'all'; // 'all', 'single', 'variable'
  String _search = '';
  bool _loading = true;

  // Pagination & Server-Side Aggregate States
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalFiltered = 0;
  int _totalCatalogCount = 0;
  int _lowOrOutCount = 0;
  double _totalUnitsCount = 0.0;
  double _totalInventoryValue = 0.0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool refreshMetadata = true}) async {
    final db = await DatabaseService.initialize();
    var paged = await db.getProductsPaged(
      categoryId: _selectedCategory,
      brandId: _selectedBrand,
      search: _search,
      stockFilter: _stockFilter,
      productType: _typeFilter,
      page: _currentPage,
      pageSize: _pageSize,
    );
    if (paged.items.isEmpty &&
        paged.totalCount > 0 &&
        _currentPage > paged.totalPages) {
      _currentPage = paged.totalPages;
      paged = await db.getProductsPaged(
        categoryId: _selectedCategory,
        brandId: _selectedBrand,
        search: _search,
        stockFilter: _stockFilter,
        productType: _typeFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );
    }

    if (mounted) {
      setState(() {
        _products = paged.items;
        _totalFiltered = paged.totalCount;
        _loading = false;
      });
    }

    if (refreshMetadata || _categories.isEmpty) {
      final cats = await db.getCategories();
      final brs = await db.getBrands();
      final stats = await db.getProductCatalogStats();
      if (mounted) {
        setState(() {
          _categories = cats;
          _brands = brs;
          _totalCatalogCount = stats['totalCount']?.toInt() ?? 0;
          _lowOrOutCount = (stats['lowStockCount']?.toInt() ?? 0) +
              (stats['outOfStockCount']?.toInt() ?? 0);
          _totalUnitsCount = stats['totalUnits']?.toDouble() ?? 0.0;
          _totalInventoryValue = stats['sellingValue']?.toDouble() ?? 0.0;
        });
      }
    }
  }

  bool get _canCreateProduct =>
      AuthService.currentUser?.hasPermission('product.create') ?? true;
  bool get _canEditProduct =>
      AuthService.currentUser?.hasPermission('product.edit') ?? true;
  bool get _canDeleteProduct =>
      AuthService.currentUser?.hasPermission('product.delete') ?? true;
  bool get _canPrintLabels =>
      AuthService.currentUser?.hasPermission('product.print_labels') ?? true;
  bool get _canQuickStockIn {
    final user = AuthService.currentUser;
    if (user == null) return true;
    return user.hasPermission('purchase.create') ||
        user.hasPermission('inventory.adjust');
  }

  bool get _canViewCost =>
      AuthService.currentUser?.hasPermission('report.view_cost_price') ?? true;

  void _denyAction(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  void _openAddProduct([Product? toEdit]) {
    if (toEdit == null && !_canCreateProduct) {
      _denyAction('Access Denied: Missing product.create permission.');
      return;
    }
    if (toEdit != null && !_canEditProduct) {
      _denyAction('Access Denied: Missing product.edit permission.');
      return;
    }
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

  void _duplicateProduct(Product product) {
    if (!_canCreateProduct) {
      _denyAction('Access Denied: Missing product.create permission.');
      return;
    }
    if (widget.onNavigateToDuplicateProduct != null) {
      widget.onNavigateToDuplicateProduct!(product);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(
            settings: widget.settings,
            productToEdit: product,
            isDuplicate: true,
            onProductCreated: () {
              Navigator.pop(context);
              _load();
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  Future<void> _openStockHistoryDialog(Product product) async {
    if (product.id == null) return;
    final db = await DatabaseService.initialize();
    final history = await db.getProductStockHistory(product.id!);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock History: ${product.name}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'SKU: ${product.sku}  •  Current Stock: ${product.stockQuantity.toStringAsFixed(1)} ${product.unit}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (history.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No purchases, sales, returns, or adjustments recorded for this product yet.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final row = history[idx];
                        final delta =
                            (row['qtyChange'] as num?)?.toDouble() ?? 0.0;
                        final isIn = delta >= 0;
                        final batch = (row['batch'] ?? '').toString();
                        final party = (row['party'] ?? '').toString();
                        final price =
                            (row['unitPrice'] as num?)?.toDouble() ?? 0.0;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isIn
                                  ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.14)
                                  : const Color(0xFFEF4444)
                                      .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${isIn ? "+" : ""}${delta.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: isIn
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          title: Text(
                            '${row['type']}  •  #${row['refNo']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          subtitle: Text(
                            [
                              if (party.isNotEmpty) party,
                              if (batch.isNotEmpty) 'Batch: $batch',
                              if (price > 0)
                                'Rate: $currency ${price.toStringAsFixed(2)}',
                            ].join('  •  '),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            (row['date'] ?? '').toString().split('T').first,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBulkPriceUpdateDialog() async {
    if (!_canEditProduct) {
      _denyAction('Access Denied: Missing product.edit permission.');
      return;
    }
    int? catId = _selectedCategory;
    int? brandId = _selectedBrand;
    String mode = 'percent';
    bool updatePurchase = false;
    final sellDeltaCtrl = TextEditingController(text: '5');
    final buyDeltaCtrl = TextEditingController(text: '0');
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final currency = widget.settings.currencySymbol;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.price_change_outlined, color: Color(0xFF4F46E5)),
                SizedBox(width: 10),
                Text('Bulk Price Update',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update prices across all products or a specific Category / Brand (+ to increase, - to decrease).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    initialValue: catId,
                    decoration: const InputDecoration(
                        labelText: 'Filter by Category', isDense: true),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All Categories')),
                      ..._categories.map((c) => DropdownMenuItem<int?>(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setDlg(() => catId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: brandId,
                    decoration: const InputDecoration(
                        labelText: 'Filter by Brand', isDense: true),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('All Brands')),
                      ..._brands.map((b) => DropdownMenuItem<int?>(
                          value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setDlg(() => brandId = v),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(
                          value: 'percent', label: Text('Percentage (%)')),
                      ButtonSegment(
                          value: 'fixed',
                          label: Text('Fixed Amount ($currency)')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setDlg(() => mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellDeltaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                      labelText: mode == 'percent'
                          ? 'Selling Price Change % (e.g. 5 or -5)'
                          : 'Selling Price Change ($currency, e.g. 100 or -50)',
                      isDense: true,
                    ),
                  ),
                  if (_canViewCost) ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Also update Purchase Cost'),
                      value: updatePurchase,
                      onChanged: (v) =>
                          setDlg(() => updatePurchase = v ?? false),
                    ),
                    if (updatePurchase)
                      TextField(
                        controller: buyDeltaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        decoration: InputDecoration(
                          labelText: mode == 'percent'
                              ? 'Purchase Cost Change %'
                              : 'Purchase Cost Change ($currency)',
                          isDense: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(saving ? 'Updating...' : 'Apply Prices'),
                onPressed: saving
                    ? null
                    : () async {
                        final sellDelta =
                            double.tryParse(sellDeltaCtrl.text.trim());
                        if (sellDelta == null) return;
                        final buyDelta =
                            double.tryParse(buyDeltaCtrl.text.trim()) ?? 0.0;
                        setDlg(() => saving = true);
                        final db = await DatabaseService.initialize();
                        final count = await db.bulkUpdateProductPrices(
                          categoryId: catId,
                          brandId: brandId,
                          mode: mode,
                          sellingDelta: sellDelta,
                          purchaseDelta: buyDelta,
                          updatePurchasePrice: updatePurchase,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Updated prices on $count product(s) successfully.'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
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
                builder: (_) => PrintLabelsScreen(
                    settings: widget.settings, initialProduct: product),
              ),
            );
          }
        },
      ),
    );
  }

  void _openQuickStockIn(Product product) async {
    if (!_canQuickStockIn) {
      _denyAction('Access Denied: Missing purchase/stock-in permission.');
      return;
    }
    final db = await DatabaseService.initialize();
    final suppliers = await db.getContacts(type: 'supplier');
    final qtyCtrl = TextEditingController(text: '10');
    final costCtrl =
        TextEditingController(text: product.purchasePrice.toStringAsFixed(2));
    Contact? selectedSup = suppliers.isNotEmpty ? suppliers.first : null;
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_business_rounded,
                    color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PosLocalization.tr('Quick Stock In',
                          settings: widget.settings),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${product.name} (Current: ${product.stockQuantity.toStringAsFixed(1)} ${product.unit})',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.settings.enableSecondaryLanguage
                              ? 'اضافی سٹاک درج کریں۔ یہ خود بخود انوینٹری اور خریداری کے کھاتے میں اپ ڈیٹ ہو جائے گا۔'
                              : 'Enter incoming stock quantity. This will update inventory and purchase accounts automatically.',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    '${PosLocalization.tr("Quantity to Add", settings: widget.settings)} (${product.unit})*',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 20',
                    prefixIcon:
                        const Icon(Icons.exposure_plus_1_rounded, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                    '${PosLocalization.tr("Purchase Cost per Unit", settings: widget.settings)} ($currency)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon:
                        const Icon(Icons.attach_money_rounded, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                if (suppliers.isNotEmpty) ...[
                  Text(
                      PosLocalization.tr('Supplier (Optional)',
                          settings: widget.settings),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Contact?>(
                    initialValue: selectedSup,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: Text('Direct / Walk-in Stock In')),
                      ...suppliers.map((s) => DropdownMenuItem(
                          value: s,
                          child:
                              Text(s.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setDialogState(() => selectedSup = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: Text(
                  PosLocalization.tr('Add Stock', settings: widget.settings),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final cost = double.tryParse(costCtrl.text.trim()) ??
                    product.purchasePrice;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        backgroundColor: Colors.red,
                        content:
                            Text('Please enter a quantity greater than 0')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                try {
                  await db.createPurchase(
                    purchase: Purchase(
                      refNo:
                          'STK-${DateTime.now().millisecondsSinceEpoch % 1000000}',
                      supplierName: selectedSup?.name ?? 'Direct Stock In',
                      supplierId: selectedSup?.id,
                      createdAt: DateTime.now().toIso8601String(),
                      totalAmount: qty * cost,
                      paidAmount: qty * cost,
                      status: 'received',
                      paymentStatus: 'paid',
                      note: 'Quick Stock In for ${product.name}',
                    ),
                    items: [
                      {
                        'product_id': product.id,
                        'quantity': qty,
                        'purchase_price': cost,
                        'selling_price': product.sellingPrice,
                      }
                    ],
                  );

                  await _load();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.settings.enableSecondaryLanguage
                                    ? 'کامیابی: ${product.name} میں $qty ${product.unit} نیا سٹاک شامل کر دیا گیا! (نیا ٹوٹل: ${(product.stockQuantity + qty).toStringAsFixed(1)})'
                                    : 'Success: Added $qty ${product.unit} to ${product.name}! (New total: ${(product.stockQuantity + qty).toStringAsFixed(1)})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Error adding stock: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printPriceList(List<Product> prods) async {
    List<Product> listToPrint = prods;
    if (listToPrint.isEmpty) {
      final db = await DatabaseService.initialize();
      listToPrint = (await db.getProductsPaged(
        categoryId: _selectedCategory,
        brandId: _selectedBrand,
        search: _search,
        stockFilter: _stockFilter,
        productType: _typeFilter,
        page: 1,
        pageSize: 500,
      ))
          .items;
    }
    if (!mounted) return;
    final html = PrintService.generatePriceListHtml(
      settings: widget.settings,
      products: listToPrint,
      paperSize: widget.settings.receiptPaperSize,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Product Price List & Catalog',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  Future<void> _printDemandList() async {
    final db = await DatabaseService.initialize();
    final lowStockList = await db.getLowStockProducts();
    if (!mounted) return;
    if (lowStockList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All inventory is optimal! Zero products are currently low or out of stock.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      return;
    }
    final html = PrintService.generateDemandReorderSheetHtml(
      settings: widget.settings,
      products: lowStockList,
    );
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Stock Reorder & Demand Sheet (ری آرڈر ڈیمانڈ شیٹ)',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  Future<void> _delete(Product product) async {
    if (!_canDeleteProduct) {
      _denyAction('Access Denied: Missing product.delete permission.');
      return;
    }
    if (product.id == null) return;
    final db = await DatabaseService.initialize();
    final usage = await db.checkProductTransactionUsage(product.id!);

    if (usage['hasTransactions'] == true) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 10),
              Text(
                'Cannot Delete Product',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This product "${product.name}" cannot be deleted because it has linked transactions:',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Linked Sales: ${usage['salesCount']} invoice(s)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Linked Purchases: ${usage['purchasesCount']} purchase record(s)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اکاؤنٹنگ قوانین کے مطابق جس پروڈکٹ کی سیل یا پرچیز ہو چکی ہو اسے ڈیلیٹ نہیں کیا جا سکتا، ورنہ پرانی انوائسز اور نفع و نقصان کی رپورٹس خراب ہو جائیں گی۔\n\nاگر آپ مزید فروخت نہیں کرنا چاہتے تو اس کا اسٹاک 0 کر دیں یا نام میں (Inactive) لکھ دیں۔',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK (سمجھ گیا)'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?'),
        content: Text(
            'Are you sure you want to permanently delete "${product.name}"?\n\n(This product has 0 transactions and can be safely removed.)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && product.id != null) {
      await db.deleteProduct(product.id!);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "${product.name}" deleted successfully.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final totalFiltered = _totalFiltered;
    final totalPages = max(1, (totalFiltered / _pageSize).ceil());
    final currentPage = _currentPage > totalPages ? totalPages : _currentPage;
    final paginatedProducts = _products;

    final totalInventoryValue = _totalInventoryValue;
    final totalUnitsCount = _totalUnitsCount;
    final lowStockCount = _lowOrOutCount;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Products & Catalog',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your inventory catalog, pricing margins, SKU barcodes, and stock levels.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (_canPrintLabels)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF1E293B),
                            side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                          label: const Text('Print Labels'),
                          onPressed: () {
                            final prod =
                                _products.isNotEmpty ? _products.first : null;
                            if (widget.onNavigateToPrintLabels != null) {
                              widget.onNavigateToPrintLabels!(prod);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrintLabelsScreen(
                                      settings: widget.settings,
                                      initialProduct: prod),
                                ),
                              );
                            }
                          },
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text('Print Price List',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _printPriceList(paginatedProducts),
                      ),
                      if (_canEditProduct)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7C3AED),
                            side: const BorderSide(color: Color(0xFF7C3AED)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon:
                              const Icon(Icons.price_change_outlined, size: 18),
                          label: const Text('Update Prices',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _openBulkPriceUpdateDialog,
                        ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.assignment_turned_in_outlined,
                            size: 18),
                        label: Text(
                          lowStockCount > 0
                              ? 'Demand List ($lowStockCount)'
                              : 'Demand List',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _printDemandList,
                      ),
                      if (_canQuickStockIn)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded,
                              size: 18),
                          label: Text(
                              PosLocalization.tr('Stock In / Purchase',
                                  settings: widget.settings),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddPurchaseScreen(
                                  settings: widget.settings,
                                  onPurchaseSaved: _load,
                                ),
                              ),
                            );
                          },
                        ),
                      if (_canCreateProduct)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text('Add Product',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () => _openAddProduct(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Metrics Summary Bar
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                      'Total Products',
                      '$_totalCatalogCount SKUs',
                      Icons.inventory_2_outlined,
                      const Color(0xFF4F46E5),
                      isDark
                          ? const Color(0xFF312E81).withValues(alpha: 0.4)
                          : const Color(0xFFEEF2FF),
                      isDark: isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    'Low / Out of Stock',
                    '$lowStockCount items',
                    Icons.warning_amber_rounded,
                    lowStockCount > 0
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF059669),
                    lowStockCount > 0
                        ? (isDark
                            ? const Color(0xFF451A03).withValues(alpha: 0.4)
                            : const Color(0xFFFFEDD5))
                        : (isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFECFDF5)),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                      'Total Units in Stock',
                      '${CurrencyFormatter.count(totalUnitsCount)} Units',
                      Icons.stacked_bar_chart_rounded,
                      const Color(0xFF0284C7),
                      isDark
                          ? const Color(0xFF0C4A6E).withValues(alpha: 0.4)
                          : const Color(0xFFE0F2FE),
                      isDark: isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                      'Inventory Retail Value',
                      CurrencyFormatter.compact(totalInventoryValue,
                          currency: '$currency '),
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF059669),
                      isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                          : const Color(0xFFECFDF5),
                      isDark: isDark,
                      subtitle: totalInventoryValue.abs() >= 1e5
                          ? 'Exact: ${CurrencyFormatter.exact(totalInventoryValue, currency: "$currency ")}'
                          : null),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Comprehensive Multi-Faceted Filter Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Field
                      Expanded(
                        flex: 3,
                        child: TextField(
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          onChanged: (val) {
                            setState(() {
                              _search = val.trim();
                              _currentPage = 1;
                            });
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 220),
                              () => _load(refreshMetadata: false),
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'Search product name, SKU, or barcode...',
                            hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                            isDense: true,
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF0F172A) : Colors.white,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Category Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedCategory,
                          dropdownColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: _dropdownDeco('Category', isDark: isDark),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Categories',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                            ..._categories.map((c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A))))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val;
                              _currentPage = 1;
                            });
                            _load(refreshMetadata: false);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Brand Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedBrand,
                          dropdownColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: _dropdownDeco('Brand', isDark: isDark),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Brands',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                            ..._brands.map((b) => DropdownMenuItem<int?>(
                                value: b.id,
                                child: Text(b.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A))))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedBrand = val;
                              _currentPage = 1;
                            });
                            _load(refreshMetadata: false);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stock Status Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _stockFilter,
                          dropdownColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration:
                              _dropdownDeco('Stock Status', isDark: isDark),
                          items: [
                            DropdownMenuItem(
                                value: 'all',
                                child: Text('All Stock Levels',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                            DropdownMenuItem(
                                value: 'in_stock',
                                child: Text('In Stock',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                            DropdownMenuItem(
                                value: 'low_stock',
                                child: Text('Low Stock Alert',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                            DropdownMenuItem(
                                value: 'out_of_stock',
                                child: Text('Out of Stock',
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _stockFilter = val;
                                _currentPage = 1;
                              });
                              _load(refreshMetadata: false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reset Button
                      if (_selectedCategory != null ||
                          _selectedBrand != null ||
                          _stockFilter != 'all' ||
                          _search.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear Filters',
                          icon: Icon(Icons.refresh_rounded,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedBrand = null;
                              _stockFilter = 'all';
                              _search = '';
                              _currentPage = 1;
                            });
                            _load(refreshMetadata: false);
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
              const TableSkeletonView(rowCount: 7)
            else if (paginatedProducts.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 48,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No Products Matching Criteria',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting your search filters or click "Add Product" to add items.',
                      style: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.grey.shade600,
                          fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final minWidth = max(constraints.maxWidth, 940.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(
                                      2.8), // Product Item & Type
                                  1: FlexColumnWidth(1.5), // SKU & Barcode
                                  2: FlexColumnWidth(1.5), // Category / Brand
                                  3: FlexColumnWidth(1.4), // Selling Price
                                  4: FlexColumnWidth(1.6), // Stock Quantity
                                  5: FlexColumnWidth(1.6), // Actions
                                },
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF8FAFC)),
                                    children: [
                                      _th('Product Item', isDark: isDark),
                                      _th('SKU / Barcode', isDark: isDark),
                                      _th('Category / Brand', isDark: isDark),
                                      _th('Selling Price', isDark: isDark),
                                      _th('Current Stock', isDark: isDark),
                                      _th('Actions',
                                          alignRight: true, isDark: isDark),
                                    ],
                                  ),
                                  ...paginatedProducts.map((p) {
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        border: Border(
                                            top: BorderSide(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        // Product Item & Type
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              ProductThumbnail(
                                                imagePath: p.resolvedImagePath,
                                                imageColor: p.imageColor,
                                                size: 38,
                                                borderRadius: 8,
                                                fallbackIcon:
                                                    Icons.shopping_bag_outlined,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    InkWell(
                                                      onTap: () =>
                                                          _viewProductDetails(
                                                              p),
                                                      child: Text(
                                                        p.name,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 13,
                                                          color: isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF0F172A),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 1),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: p.isVariable
                                                                ? (isDark
                                                                    ? const Color(
                                                                            0xFF581C87)
                                                                        .withValues(
                                                                            alpha:
                                                                                0.4)
                                                                    : const Color(
                                                                        0xFFF3E8FF))
                                                                : (isDark
                                                                    ? const Color(
                                                                        0xFF334155)
                                                                    : const Color(
                                                                        0xFFF1F5F9)),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          child: Text(
                                                            p.isVariable
                                                                ? 'Variable'
                                                                : 'Single',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: p.isVariable
                                                                  ? (isDark
                                                                      ? const Color(
                                                                          0xFFC084FC)
                                                                      : const Color(
                                                                          0xFF7C3AED))
                                                                  : (isDark
                                                                      ? const Color(
                                                                          0xFFCBD5E1)
                                                                      : const Color(
                                                                          0xFF475569)),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(p.unit,
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF94A3B8)
                                                                    : const Color(
                                                                        0xFF64748B))),
                                                        if (p.batchNumber !=
                                                                null &&
                                                            p.batchNumber!
                                                                .isNotEmpty) ...[
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isDark
                                                                  ? const Color(
                                                                          0xFF1E3A8A)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4)
                                                                  : const Color(
                                                                      0xFFEFF6FF),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border: Border.all(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF2563EB)
                                                                      : const Color(
                                                                          0xFFBFDBFE)),
                                                            ),
                                                            child: Text(
                                                              'Batch: ${p.batchNumber}',
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF93C5FD)
                                                                      : const Color(
                                                                          0xFF1D4ED8)),
                                                            ),
                                                          ),
                                                        ],
                                                        if (p.expiryDate !=
                                                                null &&
                                                            p.expiryDate!
                                                                .isNotEmpty) ...[
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isDark
                                                                  ? const Color(
                                                                          0xFF450A0A)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4)
                                                                  : const Color(
                                                                      0xFFFEF2F2),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border: Border.all(
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFF7F1D1D)
                                                                      : const Color(
                                                                          0xFFFECACA)),
                                                            ),
                                                            child: Text(
                                                              'Exp: ${p.expiryDate}',
                                                              style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isDark
                                                                      ? const Color(
                                                                          0xFFF87171)
                                                                      : const Color(
                                                                          0xFFDC2626)),
                                                            ),
                                                          ),
                                                        ],
                                                        if (p.rackLocation !=
                                                                null &&
                                                            p.rackLocation!
                                                                .trim()
                                                                .isNotEmpty) ...[
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        1),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: isDark
                                                                  ? const Color(
                                                                          0xFF0F766E)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.3)
                                                                  : const Color(
                                                                      0xFFCCFBF1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                              border:
                                                                  Border.all(
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFF14B8A6)
                                                                    : const Color(
                                                                        0xFF5EEAD4),
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .shelves,
                                                                    size: 11,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF5EEAD4)
                                                                        : const Color(
                                                                            0xFF0F766E)),
                                                                const SizedBox(
                                                                    width: 3),
                                                                Text(
                                                                  p.rackLocation!,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isDark
                                                                        ? const Color(
                                                                            0xFF5EEAD4)
                                                                        : const Color(
                                                                            0xFF0F766E),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.sku,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFCBD5E1)
                                                          : const Color(
                                                              0xFF334155))),
                                              Text(p.barcode,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF64748B)
                                                          : const Color(
                                                              0xFF94A3B8))),
                                            ],
                                          ),
                                        ),

                                        // Category & Brand
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(p.categoryName,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF1E293B))),
                                              Text(p.brandName,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF94A3B8)
                                                          : const Color(
                                                              0xFF64748B))),
                                            ],
                                          ),
                                        ),

                                        // Selling Price
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Text(
                                            '$currency${p.sellingPrice.toStringAsFixed(2)}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? const Color(0xFF818CF8)
                                                    : const Color(0xFF4F46E5)),
                                          ),
                                        ),

                                        // Stock Quantity & Alert Status
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: p.isOutOfStock
                                                      ? (isDark
                                                          ? const Color(
                                                                  0xFF450A0A)
                                                              .withValues(
                                                                  alpha: 0.4)
                                                          : const Color(
                                                              0xFFFEF2F2))
                                                      : (p.isLowStock
                                                          ? (isDark
                                                              ? const Color(
                                                                      0xFF451A03)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)
                                                              : const Color(
                                                                  0xFFFFFBEB))
                                                          : (isDark
                                                              ? const Color(
                                                                      0xFF064E3B)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)
                                                              : const Color(
                                                                  0xFFECFDF5))),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${p.stockQuantity.toStringAsFixed(1)} ${p.unit}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: p.isOutOfStock
                                                        ? (isDark
                                                            ? const Color(
                                                                0xFFF87171)
                                                            : const Color(
                                                                0xFFDC2626))
                                                        : (p.isLowStock
                                                            ? (isDark
                                                                ? const Color(
                                                                    0xFFFBBF24)
                                                                : const Color(
                                                                    0xFFD97706))
                                                            : (isDark
                                                                ? const Color(
                                                                    0xFF34D399)
                                                                : const Color(
                                                                    0xFF059669))),
                                                  ),
                                                ),
                                              ),
                                              if (_canQuickStockIn)
                                                InkWell(
                                                  onTap: () =>
                                                      _openQuickStockIn(p),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                              0xFF059669)
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                          color: const Color(
                                                                  0xFF059669)
                                                              .withValues(
                                                                  alpha: 0.4)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.add_rounded,
                                                            size: 12,
                                                            color: Color(
                                                                0xFF059669)),
                                                        SizedBox(width: 2),
                                                        Text('+ Stock',
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                    0xFF059669))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Action Buttons
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 8),
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 2,
                                            runSpacing: 2,
                                            children: [
                                              IconButton(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 28,
                                                        minHeight: 28),
                                                tooltip: 'View Specs',
                                                icon: Icon(
                                                    Icons.visibility_outlined,
                                                    size: 17,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF94A3B8)
                                                        : const Color(
                                                            0xFF475569)),
                                                onPressed: () =>
                                                    _viewProductDetails(p),
                                              ),
                                              if (_canPrintLabels)
                                                IconButton(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28),
                                                  tooltip:
                                                      'Print Barcode Label',
                                                  icon: Icon(
                                                      Icons.qr_code_2_rounded,
                                                      size: 17,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : const Color(
                                                              0xFF4F46E5)),
                                                  onPressed: () {
                                                    if (widget
                                                            .onNavigateToPrintLabels !=
                                                        null) {
                                                      widget.onNavigateToPrintLabels!(
                                                          p);
                                                    } else {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PrintLabelsScreen(
                                                                  settings: widget
                                                                      .settings,
                                                                  initialProduct:
                                                                      p),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              if (_canEditProduct)
                                                IconButton(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28),
                                                  tooltip: 'Edit Product',
                                                  icon: Icon(
                                                      Icons.edit_outlined,
                                                      size: 17,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : const Color(
                                                              0xFF4F46E5)),
                                                  onPressed: () =>
                                                      _openAddProduct(p),
                                                ),
                                              if (_canDeleteProduct)
                                                IconButton(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28),
                                                  tooltip: 'Delete Product',
                                                  icon: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 17,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFF87171)
                                                          : const Color(
                                                              0xFFDC2626)),
                                                  onPressed: () => _delete(p),
                                                ),
                                              PopupMenuButton<String>(
                                                tooltip: 'More Actions',
                                                padding: EdgeInsets.zero,
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  size: 18,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF475569),
                                                ),
                                                onSelected: (val) {
                                                  if (val == 'history') {
                                                    _openStockHistoryDialog(p);
                                                  } else if (val ==
                                                      'duplicate') {
                                                    _duplicateProduct(p);
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  const PopupMenuItem(
                                                    value: 'history',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .history_rounded,
                                                            size: 16,
                                                            color: Color(
                                                                0xFF0284C7)),
                                                        SizedBox(width: 8),
                                                        Text('Stock History'),
                                                      ],
                                                    ),
                                                  ),
                                                  if (_canCreateProduct)
                                                    const PopupMenuItem(
                                                      value: 'duplicate',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .copy_rounded,
                                                              size: 16,
                                                              color: Color(
                                                                  0xFF4F46E5)),
                                                          SizedBox(width: 8),
                                                          Text(
                                                              'Duplicate Product'),
                                                        ],
                                                      ),
                                                    ),
                                                ],
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
                          );
                        },
                      ),
                    ),
                    DataTablePaginationBar(
                      currentPage: currentPage,
                      pageSize: _pageSize,
                      totalItems: totalFiltered,
                      onPageChanged: (newPage) {
                        setState(() => _currentPage = newPage);
                        _load(refreshMetadata: false);
                      },
                      onPageSizeChanged: (newSize) {
                        setState(() {
                          _pageSize = newSize;
                          _currentPage = 1;
                        });
                        _load(refreshMetadata: false);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
      String title, String value, IconData icon, Color color, Color bgColor,
      {required bool isDark, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDeco(String label, {required bool isDark}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
    );
  }

  Widget _th(String text, {bool alignRight = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }
}
