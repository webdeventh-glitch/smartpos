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
  String _dateFilter = 'This Month';

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

  Widget _modernStatCard({
    required IconData icon,
    required Color accentColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    String? trend,
    bool isPositiveTrend = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFFF8FAFC),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon Badge + Trend Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPositiveTrend ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPositiveTrend ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositiveTrend ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 11,
                            color: isPositiveTrend ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            trend,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isPositiveTrend ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle: Bold Metric Value
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Bottom: Label and Subtext
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color ?? const Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
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
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= CLEAN ENTERPRISE HEADER =================
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 750;
                final leftSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome Admin,',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time overview across sales, inventory & accounts.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final rightSection = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _dateFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          items: ['Today', 'This Week', 'This Month', 'This Quarter', 'This Year']
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _dateFilter = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToPos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
                      label: const Text(
                        'New Sale (F1)',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftSection,
                      const SizedBox(height: 12),
                      rightSection,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftSection),
                    const SizedBox(width: 16),
                    rightSection,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Quick Actions Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickActionPill(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS Register',
                  onTap: widget.onNavigateToPos,
                ),
                _quickActionPill(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'New Product',
                  onTap: () => widget.onNavigateToTab(11),
                ),
                _quickActionPill(
                  icon: Icons.receipt_long_outlined,
                  label: 'Record Expense',
                  onTap: () => widget.onNavigateToTab(8),
                ),
                _quickActionPill(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Log Purchase',
                  onTap: () => widget.onNavigateToTab(5),
                ),
                _quickActionPill(
                  icon: Icons.analytics_outlined,
                  label: 'Full Reports',
                  onTap: () => widget.onNavigateToTab(9),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ================= RESPONSIVE METRIC CARDS =================
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cols = width > 1150 ? 4 : (width > 650 ? 2 : 1);

                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: width > 1150 ? 1.75 : 2.1,
                  children: [
                    _modernStatCard(
                      icon: Icons.shopping_cart_outlined,
                      accentColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                      title: 'Total Sales',
                      value: '$currency${totalSales.toStringAsFixed(2)}',
                      subtitle: 'Store Revenue',
                      trend: '+12.4%',
                      isPositiveTrend: true,
                      onTap: () => widget.onNavigateToTab(4),
                    ),
                    _modernStatCard(
                      icon: Icons.trending_up_rounded,
                      accentColor: const Color(0xFF4F46E5),
                      iconBg: const Color(0xFFEEF2FF),
                      title: 'Net Profit',
                      value: '$currency${netProfit.toStringAsFixed(2)}',
                      subtitle: 'Operating Margin',
                      trend: '+8.2%',
                      isPositiveTrend: true,
                    ),
                    _modernStatCard(
                      icon: Icons.pending_actions_rounded,
                      accentColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Invoice Due',
                      value: '$currency${invoiceDue.toStringAsFixed(2)}',
                      subtitle: 'Customer Receivables',
                      trend: 'Pending',
                      isPositiveTrend: false,
                      onTap: () => widget.onNavigateToTab(6),
                    ),
                    _modernStatCard(
                      icon: Icons.assignment_return_outlined,
                      accentColor: const Color(0xFF0284C7),
                      iconBg: const Color(0xFFE0F2FE),
                      title: 'Sell Return',
                      value: '$currency 0.00',
                      subtitle: 'Customer Returns',
                    ),
                    _modernStatCard(
                      icon: Icons.inventory_2_outlined,
                      accentColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                      title: 'Total purchase',
                      value: '$currency${totalPurchases.toStringAsFixed(2)}',
                      subtitle: 'Stock Inventory',
                      onTap: () => widget.onNavigateToTab(5),
                    ),
                    _modernStatCard(
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFEA580C),
                      iconBg: const Color(0xFFFFEDD5),
                      title: 'Purchase Due',
                      value: '$currency${purchaseDue.toStringAsFixed(2)}',
                      subtitle: 'Vendor Payables',
                      onTap: () => widget.onNavigateToTab(7),
                    ),
                    _modernStatCard(
                      icon: Icons.swap_horizontal_circle_outlined,
                      accentColor: const Color(0xFF475569),
                      iconBg: const Color(0xFFF1F5F9),
                      title: 'Purchase Return',
                      value: '$currency 0.00',
                      subtitle: 'Vendor Returns',
                    ),
                    _modernStatCard(
                      icon: Icons.receipt_long_outlined,
                      accentColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEF2F2),
                      title: 'Total Expenses',
                      value: '$currency${totalExpenses.toStringAsFixed(2)}',
                      subtitle: 'Store Overhead',
                      onTap: () => widget.onNavigateToTab(8),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ================= REVENUE ANALYTICS CHART =================
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sales Last 30 Days',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Daily transaction volume across current location',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.settings.businessName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 240,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 200,
                          getDrawingHorizontalLine: (val) => const FlLine(
                            color: Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
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
                              reservedSize: 46,
                              getTitlesWidget: (val, meta) {
                                if (val % 200 == 0) {
                                  return Text('$currency${val.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
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
                            curveSmoothness: 0.35,
                            color: const Color(0xFF4F46E5),
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4F46E5).withValues(alpha: 0.2),
                                  const Color(0xFF4F46E5).withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
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

            // ================= STOCK ALERTS & RECENT SALES (RESPONSIVE) =================
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;

                final alertCard = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Low Stock Alerts (${_lowStock.length})',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigateToTab(2),
                            child: const Text('Manage Stock', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_lowStock.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Inventory healthy. No items below reorder threshold.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lowStock.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final p = _lowStock[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                                        Text('${p.sku} • ${p.categoryName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626), fontSize: 13),
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
                );

                final recentSalesCard = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Recent Sales',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => widget.onNavigateToTab(4),
                            child: const Text('View All', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_recentSales.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No recent sales transactions recorded yet.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentSales.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final s = _recentSales[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    child: Text(
                                      s.customerName.isNotEmpty ? s.customerName[0].toUpperCase() : 'C',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                                        Text(s.customerName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF4F46E5)),
                                    tooltip: 'Print Thermal Receipt',
                                    onPressed: () async {
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
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: alertCard),
                      const SizedBox(width: 16),
                      Expanded(child: recentSalesCard),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      alertCard,
                      const SizedBox(height: 16),
                      recentSalesCard,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
