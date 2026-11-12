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
import 'product_detail_dialog.dart';
import 'print_labels_screen.dart';
import '../../services/print_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';
import '../purchases/add_purchase_screen.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    if (!mounted) return;

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
                      widget.settings.enableSecondaryLanguage
                          ? 'Quick Stock In / سٹاک شامل کریں'
                          : 'Quick Stock In',
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
                    widget.settings.enableSecondaryLanguage
                        ? 'Quantity to Add / شامل کرنے والی تعداد (${product.unit})*'
                        : 'Quantity to Add (${product.unit})*',
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
                    widget.settings.enableSecondaryLanguage
                        ? 'Purchase Cost per Unit / فی یونٹ خریداری قیمت ($currency)'
                        : 'Purchase Cost per Unit ($currency)',
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
                      widget.settings.enableSecondaryLanguage
                          ? 'Supplier / سپلائر (اختیاری)'
                          : 'Supplier (Optional)',
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
                  widget.settings.enableSecondaryLanguage
                      ? 'Add Stock / سٹاک شامل کریں'
                      : 'Add Stock',
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

  Future<void> _delete(Product product) async {
    if (!_canDeleteProduct) {
      _denyAction('Access Denied: Missing product.delete permission.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
            'Are you sure you want to permanently delete "${product.name}"?'),
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
      final db = await DatabaseService.initialize();
      await db.deleteProduct(product.id!);
      _load();
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
                            final prod = _products.isNotEmpty ? _products.first : null;
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
                              widget.settings.enableSecondaryLanguage
                                  ? 'Stock In / Purchase (خریداری)'
                                  : 'Stock In / Purchase',
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
                      '${totalUnitsCount.toStringAsFixed(0)} Units',
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
                      '$currency${totalInventoryValue.toStringAsFixed(2)}',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF059669),
                      isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                          : const Color(0xFFECFDF5),
                      isDark: isDark),
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
                          value: _selectedCategory,
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
                          value: _selectedBrand,
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
                          value: _stockFilter,
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
                          final minWidth = max(constraints.maxWidth, 1180.0);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: minWidth),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(
                                      3.6), // Product Item & Type
                                  1: FlexColumnWidth(1.8), // SKU & Barcode
                                  2: FlexColumnWidth(1.8), // Category / Brand
                                  3: FlexColumnWidth(1.6), // Selling Price
                                  4: FlexColumnWidth(
                                      2.0), // Stock Quantity & Quick Stock In
                                  5: FlexColumnWidth(1.7), // Actions
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
                                                fallbackIcon: Icons.shopping_bag_outlined,
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
                                                      color:
                                                          const Color(0xFF059669)
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
                                              if (_canQuickStockIn)
                                                IconButton(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  constraints:
                                                      const BoxConstraints(
                                                          minWidth: 28,
                                                          minHeight: 28),
                                                  tooltip: widget.settings
                                                          .enableSecondaryLanguage
                                                      ? 'Quick Stock In / سٹاک شامل کریں'
                                                      : 'Quick Stock In',
                                                  icon: const Icon(
                                                      Icons.add_business_rounded,
                                                      size: 17,
                                                      color: Color(0xFF059669)),
                                                  onPressed: () =>
                                                      _openQuickStockIn(p),
                                                ),
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
                                                  tooltip: 'Print Barcode Label',
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
                                                  icon: Icon(Icons.edit_outlined,
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
      {required bool isDark}) {
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
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
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
