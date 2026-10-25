import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class InventoryAuditScreen extends StatefulWidget {
  final BusinessSettings settings;
  final int initialTab; // 0: Stock Overview, 1: Dead Stock, 2: Expiring Soon, 3: Out of Stock

  const InventoryAuditScreen({
    super.key,
    required this.settings,
    this.initialTab = 0,
  });

  @override
  State<InventoryAuditScreen> createState() => _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends State<InventoryAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Product> _allProducts = [];
  List<Product> _deadStock = [];
  List<Product> _expiringProducts = [];
  List<Product> _outOfStock = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadInventoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    final db = await DatabaseService.initialize();
    final prods = await db.getProducts();
    final dead = await db.getDeadStockProducts();
    final expiring = await db.getExpiringProducts(monthsAhead: 6);
    final oos = prods.where((p) => p.isOutOfStock || p.stockQuantity <= 0).toList();

    if (mounted) {
      setState(() {
        _allProducts = prods;
        _deadStock = dead;
        _expiringProducts = expiring;
        _outOfStock = oos;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalUnits = _allProducts.fold(0.0, (sum, p) => sum + p.stockQuantity);
    final totalValuation = _allProducts.fold(0.0, (sum, p) => sum + (p.stockQuantity * p.purchasePrice));
    final deadUnits = _deadStock.fold(0.0, (sum, p) => sum + p.stockQuantity);
    final deadValuation = _deadStock.fold(0.0, (sum, p) => sum + (p.stockQuantity * p.purchasePrice));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Audit, Dead Stock & Expiry Center',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track current on-hand quantities, stagnant/dead inventory, and impending batch expiries.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh Stock Stats', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() => _loading = true);
                    _loadInventoryData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Stat Cards Row
            Row(
              children: [
                _metricCard(
                  title: 'Total Stock In Hand',
                  value: '${totalUnits.toInt()} Units',
                  subtitle: '$currency${totalValuation.toStringAsFixed(2)} Cost Value',
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                ),
                const SizedBox(width: 14),
                _metricCard(
                  title: 'Dead Stock (No Sales)',
                  value: '${_deadStock.length} Items',
                  subtitle: '$currency${deadValuation.toStringAsFixed(2)} Tied Up',
                  icon: Icons.hourglass_disabled_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
                const SizedBox(width: 14),
                _metricCard(
                  title: 'Expiring In 6 Months',
                  value: '${_expiringProducts.length} Items',
                  subtitle: 'Immediate clearance needed',
                  icon: Icons.event_busy_rounded,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
                const SizedBox(width: 14),
                _metricCard(
                  title: 'Out of Stock Alert',
                  value: '${_outOfStock.length} Items',
                  subtitle: 'Restock order required',
                  icon: Icons.remove_shopping_cart_rounded,
                  color: const Color(0xFFE11D48),
                  bgColor: const Color(0xFFFFF1F2),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs Header
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF4F46E5),
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: const Icon(Icons.list_alt_rounded), text: 'Full Stock Inventory (${_allProducts.length})'),
                  Tab(icon: const Icon(Icons.hourglass_bottom_rounded), text: 'Dead Stock (${_deadStock.length})'),
                  Tab(icon: const Icon(Icons.event_available_rounded), text: 'Expiring Soon (6M) (${_expiringProducts.length})'),
                  Tab(icon: const Icon(Icons.warning_amber_rounded), text: 'Out of Stock / Critical (${_outOfStock.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  hintText: 'Search product by name, SKU, or batch number...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // TabBar Views
            _loading
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))))
                : SizedBox(
                    height: 560,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 0: Full Stock
                        _buildProductTable(_filterProducts(_allProducts), currency, isDeadTab: false),
                        // TAB 1: Dead Stock
                        _buildProductTable(_filterProducts(_deadStock), currency, isDeadTab: true),
                        // TAB 2: Expiring Soon
                        _buildProductTable(_filterProducts(_expiringProducts), currency, isExpiringTab: true),
                        // TAB 3: Out of Stock
                        _buildProductTable(_filterProducts(_outOfStock), currency, isOutOfStockTab: true),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> list) {
    if (_searchQuery.isEmpty) return list;
    return list.where((p) {
      final name = p.name.toLowerCase();
      final sku = p.sku.toLowerCase();
      final batch = (p.batchNumber ?? '').toLowerCase();
      return name.contains(_searchQuery) || sku.contains(_searchQuery) || batch.contains(_searchQuery);
    }).toList();
  }

  Widget _buildProductTable(
    List<Product> products,
    String currency, {
    bool isDeadTab = false,
    bool isExpiringTab = false,
    bool isOutOfStockTab = false,
  }) {
    if (products.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDeadTab
                    ? Icons.thumb_up_alt_outlined
                    : (isExpiringTab ? Icons.verified_outlined : Icons.check_circle_outline),
                size: 44,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              Text(
                isDeadTab
                    ? 'No Dead Stock Found! All inventory is turning over actively.'
                    : (isExpiringTab
                        ? 'No Products Expiring within 6 months! Shelf life is healthy.'
                        : 'No Products in this category.'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      );
    }

    final scrollCtrl = ScrollController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: scrollCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 9,
          radius: const Radius.circular(5),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 22,
                horizontalMargin: 16,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                ),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  fontSize: 12,
                ),
                dataRowMinHeight: 50,
                dataRowMaxHeight: 56,
              columns: const [
                DataColumn(label: Text('PRODUCT ITEM')),
                DataColumn(label: Text('SKU / BATCH')),
                DataColumn(label: Text('EXPIRY DATE')),
                DataColumn(label: Text('ON HAND STOCK')),
                DataColumn(label: Text('COST PRICE')),
                DataColumn(label: Text('SELLING PRICE')),
                DataColumn(label: Text('STOCK VALUE')),
                DataColumn(label: Text('ALERT STATUS')),
              ],
              rows: products.map((p) {
                final stockValue = p.stockQuantity * p.purchasePrice;
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                          Text('${p.categoryName} • ${p.brandName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(p.sku, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF334155))),
                          if (p.batchNumber != null && p.batchNumber!.isNotEmpty)
                            Text('Batch: ${p.batchNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600))
                          else
                            const Text('-', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    DataCell(
                      p.expiryDate != null && p.expiryDate!.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isExpiringTab ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isExpiringTab ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                p.expiryDate!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isExpiringTab ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                                ),
                              ),
                            )
                          : const Text('Non-expiring', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                    DataCell(
                      Text(
                        '${p.stockQuantity.toInt()} ${p.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: p.stockQuantity <= 0 ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    DataCell(Text('$currency${p.purchasePrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
                    DataCell(Text('$currency${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                    DataCell(Text('$currency${stockValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)))),
                    DataCell(
                      _buildStockStatusBadge(p, isDeadTab: isDeadTab, isExpiringTab: isExpiringTab),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStockStatusBadge(Product p, {bool isDeadTab = false, bool isExpiringTab = false}) {
    if (isDeadTab) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text('Dead Stock (Slow)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
      );
    }
    if (isExpiringTab) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text('Expiring Soon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
      );
    }
    if (p.isOutOfStock || p.stockQuantity <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Text('OUT OF STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
      );
    }
    if (p.isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Text('LOW STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Text('Optimal Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
