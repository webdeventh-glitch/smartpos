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
  Map<String, dynamic> _pnl = {};
  Map<String, dynamic> _stockValuation = {};
  List<Product> _lowStock = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseService.initialize();
    final pnl = await db.getProfitAndLossReport();
    final valuation = await db.getStockValuationReport();
    final ls = await db.getLowStockProducts();
    if (mounted) {
      setState(() {
        _pnl = pnl;
        _stockValuation = valuation;
        _lowStock = ls;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    final totalSales = (_pnl['totalSales'] as double?) ?? 0.0;
    final cogs = (_pnl['cogs'] as double?) ?? 0.0;
    final grossProfit = (_pnl['grossProfit'] as double?) ?? 0.0;
    final totalExpenses = (_pnl['totalExpenses'] as double?) ?? 0.0;
    final recovered = (_pnl['recoveredAmount'] as double?) ?? 0.0;
    final netProfit = (_pnl['netProfit'] as double?) ?? 0.0;

    final totalUnits = (_stockValuation['totalQuantity'] as double?) ?? 0.0;
    final stockCost = (_stockValuation['stockValueCost'] as double?) ?? 0.0;
    final stockRetail = (_stockValuation['stockValueRetail'] as double?) ?? 0.0;
    final potentialProfit = (_stockValuation['potentialProfit'] as double?) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports & Financial Analytics',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Detailed business profit & loss statements, stock valuation, inventory audits, and operational health.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF004EEB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF004EEB),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Profit & Loss Statement'),
                Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock Valuation & Audit'),
                Tab(icon: Icon(Icons.warning_amber_outlined), text: 'Product Stock Alerts'),
              ],
            ),
            const SizedBox(height: 16),

            _loading
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                : SizedBox(
                    height: 540,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Comprehensive Profit & Loss Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _pnlRow('Gross Sales Revenue (Final Invoices)', '$currency${totalSales.toStringAsFixed(2)}', isHeader: true),
                              const Divider(),
                              _pnlRow('Cost of Goods Sold (COGS from Sales)', '($currency${cogs.toStringAsFixed(2)})'),
                              const Divider(),
                              _pnlRow('Gross Profit', '$currency${grossProfit.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
                              const Divider(),
                              _pnlRow('Total Operating Expenses', '($currency${totalExpenses.toStringAsFixed(2)})'),
                              const Divider(),
                              _pnlRow('Stock Adjustment Recoveries', '+$currency${recovered.toStringAsFixed(2)}', color: const Color(0xFF0284C7)),
                              const Divider(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: netProfit >= 0 ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('NET PROFIT / BUSINESS MARGIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      '$currency${netProfit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 22,
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

                        // Tab 2: Stock Valuation & Inventory Audit
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Inventory Valuation & Margin Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _miniBox('Total Stock Units', '${totalUnits.toInt()} units', const Color(0xFF004EEB)),
                                  const SizedBox(width: 12),
                                  _miniBox('Total Cost Value', '$currency${stockCost.toStringAsFixed(2)}', const Color(0xFF64748B)),
                                  const SizedBox(width: 12),
                                  _miniBox('Total Retail Value', '$currency${stockRetail.toStringAsFixed(2)}', const Color(0xFF10B981)),
                                  const SizedBox(width: 12),
                                  _miniBox('Potential Gross Margin', '$currency${potentialProfit.toStringAsFixed(2)}', const Color(0xFF8B5CF6)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _pnlRow('Inventory Value by Purchase Cost', '$currency${stockCost.toStringAsFixed(2)}', isHeader: true),
                              const Divider(),
                              _pnlRow('Inventory Value by Retail Selling Price', '$currency${stockRetail.toStringAsFixed(2)}', isHeader: true),
                              const Divider(),
                              _pnlRow('Projected Retail Profit Margin', '$currency${potentialProfit.toStringAsFixed(2)}', isBold: true, color: const Color(0xFF10B981)),
                              const Divider(),
                              _pnlRow('Inventory Margin Percentage', '${stockCost > 0 ? ((potentialProfit / stockCost) * 100).toStringAsFixed(1) : "0.0"}%'),
                            ],
                          ),
                        ),

                        // Tab 3: Stock Alerts Report
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: _lowStock.isEmpty
                              ? const Center(child: Text('All stock levels are optimal. No shortages detected.'))
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

  Widget _miniBox(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
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
