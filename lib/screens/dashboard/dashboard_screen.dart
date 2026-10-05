import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import '../pos/receipt_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback onNavigateToPos;
  final Function(int) onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.settings,
    required this.onNavigateToPos,
    required this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _metrics = {};
  List<Product> _lowStock = [];
  List<Sale> _recentSales = [];
  bool _loading = true;
  final String _dateFilter = 'This Month';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = await DatabaseService.initialize();
    final metrics = await db.getDashboardMetrics();
    final lowStock = await db.getLowStockProducts();
    final sales = await db.getSales();

    if (mounted) {
      setState(() {
        _metrics = metrics;
        _lowStock = lowStock;
        _recentSales = sales.take(5).toList();
        _loading = false;
      });
    }
  }

  Widget _heroStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    bool hasInfo = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasInfo) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline, size: 12, color: Color(0xFF94A3B8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currencySymbol;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final totalSales = (_metrics['totalSales'] as double?) ?? 0.0;
    final netProfit = (_metrics['netProfit'] as double?) ?? 0.0;
    final invoiceDue = (_metrics['invoiceDue'] as double?) ?? 0.0;
    final totalPurchases = (_metrics['totalPurchases'] as double?) ?? 0.0;
    final purchaseDue = (_metrics['purchaseDue'] as double?) ?? 0.0;
    final totalExpenses = (_metrics['totalExpenses'] as double?) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= DEEP BLUE HERO SECTION (Screenshot 1) =================
            Container(
              color: const Color(0xFF0038B8),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header + Date Filter Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Welcome Admin, 👋',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),

                      // Filter by date Dropdown Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF475569)),
                            const SizedBox(width: 8),
                            Text(
                              'Filter by date: $_dateFilter',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 8 Stat Cards in 2 Rows x 4 Columns Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final cols = width > 1100 ? 4 : (width > 600 ? 2 : 1);

                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.3,
                        children: [
                          _heroStatCard(
                            icon: Icons.shopping_cart_outlined,
                            iconBg: const Color(0xFFE0F2FE),
                            iconColor: const Color(0xFF0284C7),
                            title: 'Total Sales',
                            value: '$currency ${totalSales.toStringAsFixed(2)}',
                            onTap: () => widget.onNavigateToTab(4),
                          ),
                          _heroStatCard(
                            icon: Icons.payments_outlined,
                            iconBg: const Color(0xFFDCFCE7),
                            iconColor: const Color(0xFF16A34A),
                            title: 'Net',
                            hasInfo: true,
                            value: '$currency ${netProfit.toStringAsFixed(2)}',
                          ),
                          _heroStatCard(
                            icon: Icons.description_outlined,
                            iconBg: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                            title: 'Invoice due',
                            value: '$currency ${invoiceDue.toStringAsFixed(2)}',
                            onTap: () => widget.onNavigateToTab(6),
                          ),
                          _heroStatCard(
                            icon: Icons.swap_horiz_outlined,
                            iconBg: const Color(0xFFFFE4E6),
                            iconColor: const Color(0xFFE11D48),
                            title: 'Total Sell Return ...',
                            value: '$currency 0.00',
                          ),
                          _heroStatCard(
                            icon: Icons.arrow_downward_outlined,
                            iconBg: const Color(0xFFE0F2FE),
                            iconColor: const Color(0xFF0284C7),
                            title: 'Total purchase',
                            value: '$currency ${totalPurchases.toStringAsFixed(2)}',
                            onTap: () => widget.onNavigateToTab(5),
                          ),
                          _heroStatCard(
                            icon: Icons.warning_amber_rounded,
                            iconBg: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                            title: 'Purchase due',
                            value: '$currency ${purchaseDue.toStringAsFixed(2)}',
                            onTap: () => widget.onNavigateToTab(7),
                          ),
                          _heroStatCard(
                            icon: Icons.assignment_return_outlined,
                            iconBg: const Color(0xFFFFE4E6),
                            iconColor: const Color(0xFFE11D48),
                            title: 'Total Purchase Re...',
                            value: '$currency 0.00',
                          ),
                          _heroStatCard(
                            icon: Icons.receipt_long_outlined,
                            iconBg: const Color(0xFFFFE4E6),
                            iconColor: const Color(0xFFE11D48),
                            title: 'Expense',
                            value: '$currency ${totalExpenses.toStringAsFixed(2)}',
                            onTap: () => widget.onNavigateToTab(8),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ================= LOWER SECTION: CHARTS & TABLES =================
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Sales Last 30 Days Chart (Matching Screenshot 1)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF0284C7), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sales Last 30 Days',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF60A5FA),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.settings.businessName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 260,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 200,
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: 3,
                                    getTitlesWidget: (val, meta) => Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text('Day ${val.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ),
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 42,
                                    getTitlesWidget: (val, meta) {
                                      if (val % 200 == 0) {
                                        return Text('\$${val.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 1,
                              maxX: 30,
                              minY: 0,
                              maxY: 1000,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(1, 150),
                                    FlSpot(4, 380),
                                    FlSpot(7, 240),
                                    FlSpot(10, 620),
                                    FlSpot(14, 450),
                                    FlSpot(18, 790),
                                    FlSpot(22, 510),
                                    FlSpot(26, 890),
                                    FlSpot(30, 720),
                                  ],
                                  isCurved: true,
                                  color: const Color(0xFF60A5FA),
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stock Alerts and Recent Sales
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Low Stock
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Product Stock Alert (${_lowStock.length})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => widget.onNavigateToTab(2),
                                    child: const Text('View All', style: TextStyle(color: Color(0xFF004EEB))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_lowStock.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: Text('All products are healthy and above reorder threshold.', style: TextStyle(color: Colors.grey)),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _lowStock.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final p = _lowStock[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text('${p.sku} • ${p.categoryName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: StatusPill(status: p.isOutOfStock ? 'out_of_stock' : 'low_stock'),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${p.stockQuantity.toInt()} left',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Recent Sales
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.receipt_long, color: Color(0xFF004EEB), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Recent Sales',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () => widget.onNavigateToTab(4),
                                    child: const Text('View All', style: TextStyle(color: Color(0xFF004EEB))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_recentSales.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: Text('No sales records yet', style: TextStyle(color: Colors.grey))),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _recentSales.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final s = _recentSales[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                Text(s.customerName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: StatusPill(status: s.paymentStatus),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              '$currency${s.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(Icons.print_outlined, size: 18, color: Color(0xFF004EEB)),
                                            ),
                                            onTap: () async {
                                              final db = await DatabaseService.initialize();
                                              final items = await db.getSaleItems(s.id!);
                                              final fullSale = Sale.fromMap(s.toMap(), items: items);
                                              if (context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  builder: (_) => ReceiptDialog(
                                                    sale: fullSale,
                                                    settings: widget.settings,
                                                    tenderedAmount: fullSale.paidAmount,
                                                    changeReturn: 0.0,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
