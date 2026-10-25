import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../widgets/status_pill.dart';
import '../pos/receipt_dialog.dart';
import '../pos/register_details_dialog.dart';

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
  Map<String, dynamic> _todayMetrics = {};
  List<Map<String, dynamic>> _salesTrend = [];
  Map<String, double> _paymentBreakdown = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<Product> _lowStock = [];
  List<Sale> _recentSales = [];

  bool _loading = true;
  bool _refreshing = false;
  String _dateFilter = 'This Month';
  int _chartMode = 0; // 0 = Revenue, 1 = Orders Count

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() => _loading = true);
    }

    try {
      final db = await DatabaseService.initialize();
      final metrics = await db.getDashboardMetrics();
      final todayMetrics = await db.getTodaySalesMetrics();
      final trend = await db.getDailySalesTrend(days: 7);
      final paymentBreakdown = await db.getPaymentMethodBreakdown();
      final topProducts = await db.getTopSellingProducts(limit: 5);
      final lowStock = await db.getLowStockProducts();
      final sales = await db.getSales();

      if (mounted) {
        setState(() {
          _metrics = metrics;
          _todayMetrics = todayMetrics;
          _salesTrend = trend;
          _paymentBreakdown = paymentBreakdown;
          _topProducts = topProducts;
          _lowStock = lowStock;
          _recentSales = sales.take(6).toList();
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String _getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openRegisterDialog() {
    showDialog(
      context: context,
      builder: (_) => RegisterDetailsDialog(settings: widget.settings),
    );
  }

  // ================= STAT CARD =================
  Widget _heroStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    String? badgeText,
    Color? badgeBg,
    Color? badgeTextColor,
    IconData? badgeIcon,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Icon + Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (badgeTextColor ?? const Color(0xFF4F46E5)).withValues(alpha: 0.15)
                            : (badgeBg ?? const Color(0xFFEEF2FF)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (badgeTextColor ?? const Color(0xFF4F46E5)).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(badgeIcon, size: 12, color: badgeTextColor ?? const Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor ?? const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Metric Value
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Label & Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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

  // ================= SECONDARY COMPACT STAT PILL =================
  Widget _compactMetricItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String note,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  note,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= ACTION BUTTON RIBBON =================
  Widget _actionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    Color? bg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: bg ?? (isDark ? const Color(0xFF1E293B) : Colors.white),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x03000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color ?? const Color(0xFF4F46E5)),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                'Loading Enterprise Dashboard...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalSales = (_metrics['totalSales'] as double?) ?? 0.0;
    final netProfit = (_metrics['netProfit'] as double?) ?? 0.0;
    final invoiceDue = (_metrics['invoiceDue'] as double?) ?? 0.0;
    final totalPurchases = (_metrics['totalPurchases'] as double?) ?? 0.0;
    final purchaseDue = (_metrics['purchaseDue'] as double?) ?? 0.0;
    final totalExpenses = (_metrics['totalExpenses'] as double?) ?? 0.0;
    final totalProducts = (_metrics['totalProducts'] as int?) ?? 0;
    final lowStockCount = (_metrics['lowStockCount'] as int?) ?? 0;

    final todaySales = (_todayMetrics['todaySales'] as double?) ?? 0.0;
    final todayCash = (_todayMetrics['todayCash'] as double?) ?? 0.0;
    final todayOrders = (_todayMetrics['todayOrders'] as int?) ?? 0;

    final netMarginPercent = totalSales > 0 ? ((netProfit / totalSales) * 100).clamp(-100.0, 100.0) : 0.0;
    final nowFormatted = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. EXECUTIVE TOP BAR & GREETING =================
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;

                final leftGreeting = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getTimeOfDayGreeting()}, Admin',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('', style: TextStyle(fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          nowFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.settings.branchName} • Online',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final rightControls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date Filter
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 4)],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _dateFilter,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                    const SizedBox(width: 8),

                    // Refresh Button
                    Tooltip(
                      message: 'Refresh live dashboard data',
                      child: InkWell(
                        onTap: _refreshing ? null : () => _loadDashboardData(isRefresh: true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          child: Center(
                            child: _refreshing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                  )
                                : Icon(Icons.refresh_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Primary POS Button
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToPos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.amberAccent),
                      label: const Text(
                        'POS Terminal (F1)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftGreeting,
                      const SizedBox(height: 14),
                      rightControls,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leftGreeting,
                    rightControls,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // ================= 2. QUICK ACTIONS RIBBON =================
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionPill(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Point of Sale (F1)',
                  onTap: widget.onNavigateToPos,
                ),
                _actionPill(
                  icon: Icons.add_box_outlined,
                  label: 'Add Product',
                  onTap: () => widget.onNavigateToTab(11),
                ),
                _actionPill(
                  icon: Icons.receipt_long_outlined,
                  label: 'Record Expense',
                  onTap: () => widget.onNavigateToTab(8),
                ),
                _actionPill(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Log Purchase',
                  onTap: () => widget.onNavigateToTab(5),
                ),
                _actionPill(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Cash Register (F2)',
                  onTap: _openRegisterDialog,
                ),
                _actionPill(
                  icon: Icons.fact_check_outlined,
                  label: 'Stock Audit',
                  onTap: () => widget.onNavigateToTab(24),
                ),
                _actionPill(
                  icon: Icons.analytics_outlined,
                  label: 'Reports',
                  onTap: () => widget.onNavigateToTab(9),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ================= 3. TOP 4 HERO KPI CARDS =================
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
                  childAspectRatio: width > 1150 ? 1.7 : 2.1,
                  children: [
                    // Total Sales Revenue
                    _heroStatCard(
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF4F46E5),
                      iconBg: const Color(0xFFEEF2FF),
                      title: 'Total Sales Revenue',
                      value: '$currency ${totalSales.toStringAsFixed(2)}',
                      subtitle: 'Store Invoiced',
                      badgeText: '+14.8%',
                      badgeIcon: Icons.arrow_upward_rounded,
                      badgeBg: const Color(0xFFECFDF5),
                      badgeTextColor: const Color(0xFF059669),
                      onTap: () => widget.onNavigateToTab(4),
                    ),

                    // Net Operating Profit
                    _heroStatCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBg: const Color(0xFFECFDF5),
                      title: 'Net Operating Profit',
                      value: '$currency ${netProfit.toStringAsFixed(2)}',
                      subtitle: 'Revenue - COGS - Exp',
                      badgeText: '${netMarginPercent.toStringAsFixed(1)}% Margin',
                      badgeBg: const Color(0xFFF0FDF4),
                      badgeTextColor: const Color(0xFF16A34A),
                      onTap: () => widget.onNavigateToTab(9),
                    ),

                    // Outstanding Invoices (Due)
                    _heroStatCard(
                      icon: Icons.pending_actions_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Customer Receivables',
                      value: '$currency ${invoiceDue.toStringAsFixed(2)}',
                      subtitle: 'Pending Collection',
                      badgeText: invoiceDue > 0 ? 'Dues Pending' : 'Clean',
                      badgeBg: invoiceDue > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
                      badgeTextColor: invoiceDue > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                      onTap: () => widget.onNavigateToTab(6),
                    ),

                    // Today's Turnover & Drawer Cash
                    _heroStatCard(
                      icon: Icons.point_of_sale_rounded,
                      iconColor: const Color(0xFF0284C7),
                      iconBg: const Color(0xFFE0F2FE),
                      title: "Today's POS Sales",
                      value: '$currency ${todaySales.toStringAsFixed(2)}',
                      subtitle: '$todayOrders orders today',
                      badgeText: 'Cash: $currency${todayCash.toStringAsFixed(0)}',
                      badgeBg: const Color(0xFFF0F9FF),
                      badgeTextColor: const Color(0xFF0369A1),
                      onTap: _openRegisterDialog,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // ================= 4. SECONDARY 4-METRIC STRIP =================
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          _compactMetricItem(
                            icon: Icons.inventory_2_outlined,
                            color: const Color(0xFF7C3AED),
                            label: 'Total Purchases',
                            value: '$currency ${totalPurchases.toStringAsFixed(2)}',
                            note: 'Stock Inflow',
                            onTap: () => widget.onNavigateToTab(5),
                          ),
                          const SizedBox(width: 10),
                          _compactMetricItem(
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFEA580C),
                            label: 'Vendor Payables',
                            value: '$currency ${purchaseDue.toStringAsFixed(2)}',
                            note: 'Due to pay',
                            onTap: () => widget.onNavigateToTab(7),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _compactMetricItem(
                            icon: Icons.receipt_long_outlined,
                            color: const Color(0xFFDC2626),
                            label: 'Store Expenses',
                            value: '$currency ${totalExpenses.toStringAsFixed(2)}',
                            note: 'Overheads',
                            onTap: () => widget.onNavigateToTab(8),
                          ),
                          const SizedBox(width: 10),
                          _compactMetricItem(
                            icon: Icons.category_outlined,
                            color: const Color(0xFF0284C7),
                            label: 'Catalog Health',
                            value: '$totalProducts Items',
                            note: lowStockCount > 0 ? '$lowStockCount Low!' : 'Healthy',
                            onTap: () => widget.onNavigateToTab(2),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    _compactMetricItem(
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF7C3AED),
                      label: 'Total Purchases',
                      value: '$currency ${totalPurchases.toStringAsFixed(2)}',
                      note: 'Stock Inflow',
                      onTap: () => widget.onNavigateToTab(5),
                    ),
                    const SizedBox(width: 12),
                    _compactMetricItem(
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFEA580C),
                      label: 'Vendor Payables',
                      value: '$currency ${purchaseDue.toStringAsFixed(2)}',
                      note: 'Due to pay',
                      onTap: () => widget.onNavigateToTab(7),
                    ),
                    const SizedBox(width: 12),
                    _compactMetricItem(
                      icon: Icons.receipt_long_outlined,
                      color: const Color(0xFFDC2626),
                      label: 'Store Expenses',
                      value: '$currency ${totalExpenses.toStringAsFixed(2)}',
                      note: 'Overheads',
                      onTap: () => widget.onNavigateToTab(8),
                    ),
                    const SizedBox(width: 12),
                    _compactMetricItem(
                      icon: Icons.category_outlined,
                      color: const Color(0xFF0284C7),
                      label: 'Catalog Health',
                      value: '$totalProducts Items',
                      note: lowStockCount > 0 ? '$lowStockCount Low Stock' : 'Optimal',
                      onTap: () => widget.onNavigateToTab(2),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ================= 5. ANALYTICS & CHARTS SECTION =================
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;

                final trendChartWidget = _buildSalesTrendCard(currency);
                final paymentBreakdownWidget = _buildPaymentBreakdownCard(currency);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 65, child: trendChartWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 35, child: paymentBreakdownWidget),
                    ],
                  );
                }

                return Column(
                  children: [
                    trendChartWidget,
                    const SizedBox(height: 16),
                    paymentBreakdownWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ================= 6. OPERATIONAL HUB: TOP SELLERS & RECENT SALES =================
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 950;

                final topProductsWidget = _buildTopProductsCard(currency);
                final recentSalesWidget = _buildRecentSalesCard(currency);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 48, child: topProductsWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 52, child: recentSalesWidget),
                    ],
                  );
                }

                return Column(
                  children: [
                    topProductsWidget,
                    const SizedBox(height: 16),
                    recentSalesWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ================= 7. CRITICAL INVENTORY ALERTS =================
            _buildStockAlertsCard(),

            const SizedBox(height: 24),

            // ================= 8. KEYBOARD SHORTCUTS DOCK =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.keyboard_outlined, color: Colors.amberAccent, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'POWER SHORTCUTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 16,
                    children: [
                      _shortcutBadge('F1', 'POS Terminal'),
                      _shortcutBadge('F2', 'Register'),
                      _shortcutBadge('F3', 'New Product'),
                      _shortcutBadge('F4', 'Sales List'),
                      _shortcutBadge('Ctrl+R', 'Refresh Data'),
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

  Widget _shortcutBadge(String keyStr, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Text(
            keyStr,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amberAccent),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ================= 5A. SALES TREND CARD =================
  Widget _buildSalesTrendCard(String currency) {
    // Generate real spots from _salesTrend
    final List<FlSpot> spots = [];
    double maxY = 100.0;

    for (int i = 0; i < _salesTrend.length; i++) {
      final val = _chartMode == 0
          ? ((_salesTrend[i]['revenue'] as double?) ?? 0.0)
          : ((_salesTrend[i]['orderCount'] as int?) ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val;
    }

    if (spots.isEmpty) {
      spots.addAll([
        const FlSpot(0, 100),
        const FlSpot(1, 350),
        const FlSpot(2, 280),
        const FlSpot(3, 620),
        const FlSpot(4, 490),
        const FlSpot(5, 780),
        const FlSpot(6, 650),
      ]);
      maxY = 1000;
    }

    maxY = (maxY * 1.25).ceilToDouble();
    if (maxY == 0) maxY = 500;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.show_chart_rounded, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales & Revenue Velocity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _chartMode == 0 ? 'Daily revenue over the past 7 days' : 'Daily completed transactions count',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),

              // Mode toggle (Revenue vs Orders)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toggleBtn('Revenue', 0, isDark),
                    _toggleBtn('Orders', 1, isDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < _salesTrend.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _salesTrend[idx]['dayLabel'] ?? 'D$idx',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (val, meta) {
                        if (val == meta.max || val == meta.min) return const Text('');
                        final prefix = _chartMode == 0 ? currency : '';
                        return Text(
                          '$prefix${val.toInt()}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF4F46E5),
                    barWidth: 3.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: const Color(0xFF4F46E5),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4F46E5).withValues(alpha: 0.25),
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
    );
  }

  Widget _toggleBtn(String label, int mode, bool isDark) {
    final active = _chartMode == mode;
    return InkWell(
      onTap: () => setState(() => _chartMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF312E81) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ================= 5B. PAYMENT CHANNELS BREAKDOWN =================
  Widget _buildPaymentBreakdownCard(String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double totalAll = 0.0;
    _paymentBreakdown.forEach((k, v) => totalAll += v);

    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF06B6D4),
      const Color(0xFF8B5CF6),
    ];

    final sections = <PieChartSectionData>[];
    int colorIdx = 0;

    if (totalAll > 0) {
      _paymentBreakdown.forEach((method, val) {
        final percent = (val / totalAll) * 100;
        final color = colors[colorIdx % colors.length];
        colorIdx++;
        sections.add(
          PieChartSectionData(
            value: val,
            color: color,
            radius: 28,
            title: '${percent.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        );
      });
    } else {
      sections.add(
        PieChartSectionData(
          value: 100,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          radius: 28,
          title: '100%',
          titleStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Breakdown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Volume by tender method',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Chart with center label
          SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 42,
                    sectionsSpace: 3,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalAll > 0 ? '$currency${totalAll.toStringAsFixed(0)}' : 'No Sales',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text('Total', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          if (totalAll > 0)
            Column(
              children: _paymentBreakdown.entries.map((e) {
                final idx = _paymentBreakdown.keys.toList().indexOf(e.key);
                final c = colors[idx % colors.length];
                final percent = totalAll > 0 ? (e.value / totalAll) * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$currency ${e.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Complete POS sales to see payment breakdown.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ),
            ),
        ],
      ),
    );
  }

  // ================= 6A. TOP PRODUCTS LEADERBOARD =================
  Widget _buildTopProductsCard(String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.leaderboard_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Selling Products',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Ranked by transaction volume',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateToTab(2),
                child: Text('View Catalog', style: TextStyle(color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No product sales recorded yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topProducts.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final p = _topProducts[idx];
                final name = p['name'] ?? 'Product';
                final qty = (p['qty'] as double?) ?? 0.0;
                final rev = (p['revenue'] as double?) ?? 0.0;

                final medals = ['', '', ''];
                final rankStr = idx < 3 ? medals[idx] : '#${idx + 1}';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          rankStr,
                          style: TextStyle(
                            fontSize: idx < 3 ? 16 : 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${qty.toInt()} units sold',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$currency ${rev.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
  }

  // ================= 6B. RECENT SALES TRANSACTIONS =================
  Widget _buildRecentSalesCard(String currency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Transactions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Live POS sales stream',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateToTab(4),
                child: Text('View All Orders', style: TextStyle(color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_recentSales.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No recent sales found.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentSales.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final s = _recentSales[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                        child: Text(
                          s.customerName.isNotEmpty ? s.customerName[0].toUpperCase() : 'C',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  s.invoiceNo,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                                  ),
                                  child: Text(
                                    s.paymentMethod.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.customerName} • ${s.createdAt}',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(status: s.paymentStatus),
                      const SizedBox(width: 14),
                      Text(
                        '$currency ${s.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.print_outlined, size: 18, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
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
  }

  // ================= 7. CRITICAL STOCK ALERTS =================
  Widget _buildStockAlertsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
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
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _lowStock.isEmpty
                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5))
                          : (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.4) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _lowStock.isEmpty ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                      color: _lowStock.isEmpty ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Reorder & Low Stock Alerts (${_lowStock.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _lowStock.isEmpty
                            ? 'All inventory items are currently at healthy stock levels.'
                            : 'Items at or below minimum threshold requiring immediate restock.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateToTab(5), // Navigate to Purchases
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 14),
                label: const Text('Create Purchase Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_lowStock.isNotEmpty) ...[
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowStock.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
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
                            Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '${p.sku} • ${p.categoryName}',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
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
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFDC2626), fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 14),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => widget.onNavigateToTab(5),
                        child: Text(
                          'Restock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
