import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class ReportsScreen extends StatefulWidget {
  final BusinessSettings settings;

  const ReportsScreen({super.key, required this.settings});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _metrics = {};
  List<Product> _lowStock = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final m = await db.getDashboardMetrics();
    final ls = await db.getLowStockProducts();
    if (mounted) {
      setState(() {
        _metrics = m;
        _lowStock = ls;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;
    final totalSales = (_metrics['totalSales'] as double?) ?? 0.0;
    final totalPurchases = (_metrics['totalPurchases'] as double?) ?? 0.0;
    final totalExpenses = (_metrics['totalExpenses'] as double?) ?? 0.0;
    final cogs = totalPurchases * 0.7; // Estimated COGS
    final grossProfit = totalSales - cogs;
    final netProfit = grossProfit - totalExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports & Financial Analytics',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detailed business profit & loss statements, stock valuation, and operational audits.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF004EEB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF004EEB),
              tabs: const [
                Tab(text: 'Profit & Loss Statement'),
                Tab(text: 'Product Stock Alert Report'),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: P&L Statement
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Profit & Loss Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _pnlRow('Gross Sales Revenue', '$currency${totalSales.toStringAsFixed(2)}', isHeader: true),
                              const Divider(),
                              _pnlRow('Cost of Goods Sold (COGS)', '($currency${cogs.toStringAsFixed(2)})'),
                              const Divider(),
                              _pnlRow('Gross Profit', '$currency${grossProfit.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
                              const Divider(),
                              _pnlRow('Total Operating Expenses', '($currency${totalExpenses.toStringAsFixed(2)})'),
                              const Divider(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: netProfit >= 0 ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('NET PROFIT / MARGIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      '$currency${netProfit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: netProfit >= 0 ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Tab 2: Stock Alerts Report
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _lowStock.isEmpty
                            ? const Center(child: Text('All stock levels are optimal.'))
                            : ListView.separated(
                                itemCount: _lowStock.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final p = _lowStock[index];
                                  return ListTile(
                                    leading: const Icon(Icons.warning, color: Color(0xFFEF4444)),
                                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('SKU: ${p.sku} • Category: ${p.categoryName}'),
                                    trailing: Text(
                                      '${p.stockQuantity.toInt()} in stock (Alert: ${p.alertQuantity.toInt()})',
                                      style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pnlRow(String title, String val, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            val,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
