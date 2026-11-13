import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/thermal_printer_service.dart';
import 'kitchen_display_system_screen.dart';

class RestaurantCafeScreen extends StatefulWidget {
  final BusinessSettings settings;

  const RestaurantCafeScreen({super.key, required this.settings});

  @override
  State<RestaurantCafeScreen> createState() => _RestaurantCafeScreenState();
}

class _RestaurantCafeScreenState extends State<RestaurantCafeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _isLoading = true;

  List<Map<String, dynamic>> _tables = [];
  List<Map<String, dynamic>> _kotOrders = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseService.initialize();
    final tables = await db.getRestaurantTables();
    final kot = await db.getRestaurantKotOrders();
    if (mounted) {
      setState(() {
        _tables = List<Map<String, dynamic>>.from(tables);
        _kotOrders = List<Map<String, dynamic>>.from(kot);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddTableModal() {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '4');
    String section = 'Main Dining';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Add Dining Table',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Table Name / Number (e.g. Table 5, VIP 3)',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Seating Capacity',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final newTable = {
                    'name': nameCtrl.text.trim(),
                    'section': section,
                    'capacity': int.tryParse(capCtrl.text) ?? 4,
                    'status': 'vacant',
                    'order_total': 0.0,
                    'kot_time': '',
                    'guests': 0,
                  };
                  final db = await DatabaseService.initialize();
                  await db.addRestaurantTable(newTable);
                  Navigator.pop(ctx);
                  await _loadData();
                }
              },
              child: const Text('Add Table'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.restaurant_rounded,
                color: Color(0xFFF97316), size: 22),
            const SizedBox(width: 10),
            Text(
              'Restaurant & Cafe Management (KOT & Tables)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFFF97316),
          indicatorColor: const Color(0xFFF97316),
          unselectedLabelColor:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(
                icon: Icon(Icons.table_restaurant_rounded, size: 18),
                text: 'Floor Plan & Tables'),
            Tab(
                icon: Icon(Icons.soup_kitchen_rounded, size: 18),
                text: 'Live KOT Kitchen Queue'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF97316),
                side: const BorderSide(color: Color(0xFFF97316)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KitchenDisplaySystemScreen(
                      settings: widget.settings,
                    ),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.fullscreen, size: 16),
              label: const Text('Live KDS Screen (کچن اسکرین)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _showAddTableModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Table'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Floor Plan & Tables
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Summary
                Row(
                  children: [
                    _statusBadge('Total Tables: ${_tables.length}',
                        const Color(0xFF6366F1), isDark),
                    const SizedBox(width: 12),
                    _statusBadge(
                        'Occupied: ${_tables.where((t) => t['status'] == 'occupied').length}',
                        const Color(0xFFF97316),
                        isDark),
                    const SizedBox(width: 12),
                    _statusBadge(
                        'Vacant: ${_tables.where((t) => t['status'] == 'vacant').length}',
                        const Color(0xFF10B981),
                        isDark),
                    const SizedBox(width: 12),
                    _statusBadge(
                        'Billed: ${_tables.where((t) => t['status'] == 'billed').length}',
                        const Color(0xFF3B82F6),
                        isDark),
                  ],
                ),
                const SizedBox(height: 20),

                if (_tables.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF97316).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.table_restaurant_rounded,
                              size: 48, color: Color(0xFFF97316)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Dining Tables Added Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure your restaurant floor plan by clicking "Add Table" above.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showAddTableModal,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add First Dining Table',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  // Table Cards Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.25,
                    ),
                    itemCount: _tables.length,
                    itemBuilder: (context, idx) {
                      final t = _tables[idx];
                      final status = t['status'] as String;
                      Color statusColor = const Color(0xFF10B981);
                      if (status == 'occupied')
                        statusColor = const Color(0xFFF97316);
                      if (status == 'billed')
                        statusColor = const Color(0xFF3B82F6);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['name'] as String,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Section: ${t['section']} • Cap: ${t['capacity']} Seats',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                            ),
                            if (status != 'vacant') ...[
                              Text(
                                'Running Bill: $currency${((t['order_total'] ?? t['orderTotal'] ?? 0.0) as num).toDouble().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Guests: ${t['guests']} • KOT Sent: ${t['kot_time'] ?? t['kotTime'] ?? 'Active'}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              ),
                            ] else ...[
                              Text(
                                'Table is ready for new guests',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B)),
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'vacant')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () async {
                                      final guestsCtrl =
                                          TextEditingController(text: '2');
                                      final estCtrl =
                                          TextEditingController(text: '0');
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text(
                                              'Seat Guests • ${t['name']}'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: guestsCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            'Number of Guests'),
                                              ),
                                              const SizedBox(height: 10),
                                              TextField(
                                                controller: estCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Initial Table Order / Cover (${widget.settings.currencySymbol})',
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Seat Table'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true) return;
                                      final guestCount = int.tryParse(
                                              guestsCtrl.text.trim()) ??
                                          2;
                                      final initTotal = double.tryParse(
                                              estCtrl.text.trim()) ??
                                          0.0;
                                      final id = t['id'] as int?;
                                      if (id != null) {
                                        final db =
                                            await DatabaseService.initialize();
                                        await db.updateRestaurantTable(id, {
                                          'status': 'occupied',
                                          'guests': guestCount,
                                          'kot_time': DateTime.now()
                                              .toString()
                                              .substring(11, 16),
                                          'order_total': initTotal,
                                        });
                                        await _loadData();
                                      } else {
                                        setState(() {
                                          t['status'] = 'occupied';
                                          t['guests'] = guestCount;
                                          t['kot_time'] = 'Just now';
                                          t['order_total'] = initTotal;
                                        });
                                      }
                                    },
                                    child: const Text('Seat Guests',
                                        style: TextStyle(fontSize: 11)),
                                  )
                                else
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          bool printed = false;
                                          try {
                                            final orderPrice =
                                                (t['order_total'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;
                                            final dummyProd = Product(
                                              name:
                                                  'Table Service / Kitchen Order',
                                              sku: 'KOT',
                                              barcode: 'KOT',
                                              purchasePrice: 0,
                                              sellingPrice: orderPrice,
                                              stockQuantity: 1,
                                            );
                                            printed =
                                                await ThermalPrinterService
                                                    .printKotTicket(
                                              table: (t['name'] ?? 'Table')
                                                  .toString(),
                                              waiter:
                                                  (t['waiter_name'] ?? 'Waiter')
                                                      .toString(),
                                              diningMode: 'dine_in',
                                              items: [
                                                CartItem(
                                                    product: dummyProd,
                                                    quantity: 1,
                                                    unitPrice: orderPrice)
                                              ],
                                              settings: widget.settings,
                                              orderNote:
                                                  'Table Reprint (${t['guests'] ?? 0} guests)',
                                            );
                                          } catch (e, st) {
                                            AppLogger.warning(
                                                'RestaurantCafeScreen',
                                                'KOT reprint error',
                                                e,
                                                st);
                                          }
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                printed
                                                    ? 'KOT Reprint printed to kitchen printer for ${t['name']}'
                                                    : 'KOT Reprint queued for ${t['name']}',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('Print KOT',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () async {
                                          final currentTotal =
                                              (t['order_total'] as num?)
                                                      ?.toDouble() ??
                                                  0.0;
                                          final billCtrl =
                                              TextEditingController(
                                            text: currentTotal > 0
                                                ? currentTotal
                                                    .toStringAsFixed(0)
                                                : '',
                                          );
                                          final payConfirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text(
                                                  'Checkout • ${t['name']}'),
                                              content: TextField(
                                                controller: billCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Final Table Bill (${widget.settings.currencySymbol})',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child:
                                                        const Text('Cancel')),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                      'Complete & Print Bill'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (payConfirmed != true) return;
                                          final billAmount = double.tryParse(
                                                  billCtrl.text.trim()) ??
                                              currentTotal;
                                          final id = t['id'] as int?;
                                          final db = await DatabaseService
                                              .initialize();
                                          if (billAmount > 0) {
                                            final inv = await db
                                                .generateNextInvoiceNo();
                                            final nowStr = DateTime.now()
                                                .toString()
                                                .substring(0, 19);
                                            await db.createSale(
                                              sale: Sale(
                                                invoiceNo: inv,
                                                customerName:
                                                    'Dine-In (${t['name']})',
                                                subtotal: billAmount,
                                                totalAmount: billAmount,
                                                paidAmount: billAmount,
                                                paymentMethod: 'cash',
                                                paymentStatus: 'paid',
                                                saleStatus: 'final',
                                                note:
                                                    'Restaurant Table Checkout (${t['guests'] ?? 1} guests)',
                                                createdAt: nowStr,
                                              ),
                                              items: [
                                                CartItem(
                                                  product: Product(
                                                    name:
                                                        'Table Service — ${t['name']}',
                                                    sku: 'TBL-${t['id'] ?? 0}',
                                                    barcode:
                                                        'TBL-${t['id'] ?? 0}',
                                                    purchasePrice: 0,
                                                    sellingPrice: billAmount,
                                                    stockQuantity: 1,
                                                  ),
                                                  quantity: 1,
                                                  unitPrice: billAmount,
                                                ),
                                              ],
                                              enforceStock: false,
                                            );
                                          }
                                          if (id != null) {
                                            await db.updateRestaurantTable(id, {
                                              'status': 'vacant',
                                              'order_total': 0.0,
                                              'guests': 0,
                                              'kot_time': '',
                                            });
                                            await _loadData();
                                          } else {
                                            setState(() {
                                              t['status'] = 'vacant';
                                              t['order_total'] = 0.0;
                                              t['guests'] = 0;
                                            });
                                          }
                                        },
                                        child: const Text('Checkout',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Tab 2: Live KOT Kitchen Queue
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Kitchen Order Tickets (KOT)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        foregroundColor: const Color(0xFFF97316),
                        side: const BorderSide(color: Color(0xFFF97316)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => KitchenDisplaySystemScreen(
                              settings: widget.settings,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                      icon: const Icon(Icons.fullscreen, size: 16),
                      label: const Text('Open Full-Screen KDS',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_kotOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Kitchen Orders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'When waitstaff or cashiers send food orders to the kitchen, live KOT tickets will queue here.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _kotOrders.length,
                    itemBuilder: (context, i) {
                      final k = _kotOrders[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.restaurant_menu_rounded,
                                  color: Color(0xFFF97316), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${k['kot_no'] ?? k['kotNo']} • ${k['table_name'] ?? k['table']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (k['order_type'] ??
                                              k['type'] ??
                                              'Dine-In') as String,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4F46E5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    k['items'] as String,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFFCBD5E1)
                                            : const Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(k['time'] as String,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8))),
                                const SizedBox(height: 6),
                                PopupMenuButton<String>(
                                  tooltip: 'Change KOT Status',
                                  initialValue: k['status'] as String?,
                                  onSelected: (newStatus) async {
                                    final id = k['id'] as int? ?? 0;
                                    final db =
                                        await DatabaseService.initialize();
                                    await db.updateRestaurantKotStatus(
                                        id, newStatus);
                                    _loadData();
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'Cooking',
                                      child: Text('Cooking (تیار ہو رہا ہے)'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Ready',
                                      child: Text('Ready (تیار ہے)'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Served',
                                      child: Text('Served (پیش کر دیا)'),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: ((k['status'] == 'Ready')
                                              ? const Color(0xFF10B981)
                                              : (k['status'] == 'Served')
                                                  ? const Color(0xFF64748B)
                                                  : const Color(0xFFF59E0B))
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          k['status'] as String,
                                          style: TextStyle(
                                              color: (k['status'] == 'Ready')
                                                  ? const Color(0xFF10B981)
                                                  : (k['status'] == 'Served')
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFFF59E0B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 14,
                                          color: (k['status'] == 'Ready')
                                              ? const Color(0xFF10B981)
                                              : (k['status'] == 'Served')
                                                  ? const Color(0xFF64748B)
                                                  : const Color(0xFFF59E0B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
      ),
    );
  }
}
