import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/localization_service.dart';
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
          title: Text(
              PosLocalization.tr('Add Dining Table', settings: widget.settings),
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
                  labelText: PosLocalization.tr(
                      'Table Name / Number (e.g. Table 5, VIP 3)',
                      settings: widget.settings),
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
                  labelText: PosLocalization.tr('Seating Capacity',
                      settings: widget.settings),
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
              child: Text(
                  PosLocalization.tr('Cancel', settings: widget.settings),
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
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  await _loadData();
                }
              },
              child: Text(
                  PosLocalization.tr('Add Table', settings: widget.settings)),
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
              PosLocalization.tr('Restaurant & Cafe Management (KOT & Tables)',
                  settings: widget.settings),
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
          tabs: [
            Tab(
                icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                text: PosLocalization.tr('Floor Plan & Tables',
                    settings: widget.settings)),
            Tab(
                icon: const Icon(Icons.soup_kitchen_rounded, size: 18),
                text: PosLocalization.tr('Live KOT Kitchen Queue',
                    settings: widget.settings)),
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
              label: Text(
                  PosLocalization.tr('Live KDS Screen',
                      settings: widget.settings),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
              label: Text(
                  PosLocalization.tr('Add Table', settings: widget.settings)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
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
                          _statusBadge(
                              PosLocalization.trParams('Total Tables: {count}',
                                  {'count': '${_tables.length}'},
                                  settings: widget.settings),
                              const Color(0xFF6366F1),
                              isDark),
                          const SizedBox(width: 12),
                          _statusBadge(
                              PosLocalization.trParams(
                                  'Occupied: {count}',
                                  {
                                    'count':
                                        '${_tables.where((t) => t['status'] == 'occupied').length}'
                                  },
                                  settings: widget.settings),
                              const Color(0xFFF97316),
                              isDark),
                          const SizedBox(width: 12),
                          _statusBadge(
                              PosLocalization.trParams(
                                  'Vacant: {count}',
                                  {
                                    'count':
                                        '${_tables.where((t) => t['status'] == 'vacant').length}'
                                  },
                                  settings: widget.settings),
                              const Color(0xFF10B981),
                              isDark),
                          const SizedBox(width: 12),
                          _statusBadge(
                              PosLocalization.trParams(
                                  'Billed: {count}',
                                  {
                                    'count':
                                        '${_tables.where((t) => t['status'] == 'billed').length}'
                                  },
                                  settings: widget.settings),
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
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
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
                                  color: const Color(0xFFF97316)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.table_restaurant_rounded,
                                    size: 48,
                                    color: Color(0xFFF97316)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                PosLocalization.tr('No Dining Tables Added Yet',
                                    settings: widget.settings),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                PosLocalization.tr(
                                    'Configure your restaurant floor plan by clicking "Add Table" above.',
                                    settings: widget.settings),
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
                                label: Text(
                                    PosLocalization.tr('Add First Dining Table',
                                        settings: widget.settings),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
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
                            if (status == 'occupied') {
                              statusColor = const Color(0xFFF97316);
                            }
                            if (status == 'billed') {
                              statusColor = const Color(0xFF3B82F6);
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          color: statusColor.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          PosLocalization.tr(
                                              status.toUpperCase(),
                                              settings: widget.settings),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    PosLocalization.trParams(
                                        'Section: {section} • Cap: {capacity} Seats',
                                        {
                                          'section': '${t['section']}',
                                          'capacity': '${t['capacity']}'
                                        },
                                        settings: widget.settings),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B)),
                                  ),
                                  if (status != 'vacant') ...[
                                    Text(
                                      PosLocalization.trParams(
                                          'Running Bill: {currency}{amount}',
                                          {
                                            'currency': currency,
                                            'amount': ((t['order_total'] ??
                                                    t['orderTotal'] ??
                                                    0.0) as num)
                                                .toDouble()
                                                .toStringAsFixed(2),
                                          },
                                          settings: widget.settings),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      PosLocalization.trParams(
                                          'Guests: {guests} • KOT Sent: {time}',
                                          {
                                            'guests': '${t['guests']}',
                                            'time':
                                                '${t['kot_time'] ?? t['kotTime'] ?? PosLocalization.tr('Active', settings: widget.settings)}',
                                          },
                                          settings: widget.settings),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B)),
                                    ),
                                    if (t['modifiers'] != null &&
                                        (t['modifiers'] as String)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF97316)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          PosLocalization.trParams(
                                              'Notes: {notes}',
                                              {'notes': '${t['modifiers']}'},
                                              settings: widget.settings),
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFFEA580C),
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    Text(
                                      PosLocalization.tr(
                                          'Table is ready for new guests',
                                          settings: widget.settings),
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
                                            backgroundColor:
                                                const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () async {
                                            final guestsCtrl =
                                                TextEditingController(
                                                    text: '2');
                                            final estCtrl =
                                                TextEditingController(
                                                    text: '0');
                                            final confirmed =
                                                await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(
                                                    PosLocalization.trParams(
                                                        'Seat Guests • {table}',
                                                        {
                                                          'table':
                                                              '${t['name']}'
                                                        },
                                                        settings:
                                                            widget.settings)),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller: guestsCtrl,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration: InputDecoration(
                                                          labelText: PosLocalization.tr(
                                                              'Number of Guests',
                                                              settings: widget
                                                                  .settings)),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    TextField(
                                                      controller: estCtrl,
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: PosLocalization
                                                            .trParams(
                                                                'Initial Table Order / Cover ({currency})',
                                                                {
                                                                  'currency': widget
                                                                      .settings
                                                                      .currencySymbol
                                                                },
                                                                settings: widget
                                                                    .settings),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child: Text(
                                                          PosLocalization.tr(
                                                              'Cancel',
                                                              settings: widget
                                                                  .settings))),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: Text(
                                                        PosLocalization.tr(
                                                            'Seat Table',
                                                            settings: widget
                                                                .settings)),
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
                                              final db = await DatabaseService
                                                  .initialize();
                                              await db
                                                  .updateRestaurantTable(id, {
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
                                          child: Text(
                                              PosLocalization.tr('Seat Guests',
                                                  settings: widget.settings),
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        )
                                      else
                                        Row(
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              onPressed: () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                        context);
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
                                                    table:
                                                        (t['name'] ?? 'Table')
                                                            .toString(),
                                                    waiter: (t['waiter_name'] ??
                                                            'Waiter')
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
                                                          ? PosLocalization.trParams(
                                                              'KOT Reprint printed to kitchen printer for {table}',
                                                              {
                                                                'table':
                                                                    '${t['name']}'
                                                              },
                                                              settings: widget
                                                                  .settings)
                                                          : PosLocalization.trParams(
                                                              'KOT Reprint queued for {table}',
                                                              {
                                                                'table':
                                                                    '${t['name']}'
                                                              },
                                                              settings: widget
                                                                  .settings),
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                  PosLocalization.tr(
                                                      'Print KOT',
                                                      settings:
                                                          widget.settings),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFFF97316),
                                                side: const BorderSide(
                                                    color: Color(0xFFF97316)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              onPressed: () =>
                                                  _showTableModifiersDialog(t),
                                              child: Text(
                                                  PosLocalization.tr(
                                                      'Modifiers',
                                                      settings:
                                                          widget.settings),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF10B981),
                                                side: const BorderSide(
                                                    color: Color(0xFF10B981)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              onPressed: () =>
                                                  _showSplitBillDialog(t),
                                              child: Text(
                                                  PosLocalization.tr(
                                                      'Split Bill',
                                                      settings:
                                                          widget.settings),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                            ),
                                            const SizedBox(width: 6),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF3B82F6),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact,
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
                                                    title: Text(PosLocalization
                                                        .trParams(
                                                            'Checkout • {table}',
                                                            {
                                                              'table':
                                                                  '${t['name']}'
                                                            },
                                                            settings: widget
                                                                .settings)),
                                                    content: TextField(
                                                      controller: billCtrl,
                                                      keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                      decoration:
                                                          InputDecoration(
                                                        labelText: PosLocalization
                                                            .trParams(
                                                                'Final Table Bill ({currency})',
                                                                {
                                                                  'currency': widget
                                                                      .settings
                                                                      .currencySymbol
                                                                },
                                                                settings: widget
                                                                    .settings),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, false),
                                                          child: Text(
                                                              PosLocalization.tr(
                                                                  'Cancel',
                                                                  settings: widget
                                                                      .settings))),
                                                      ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, true),
                                                        child: Text(
                                                            PosLocalization.tr(
                                                                'Complete & Print Bill',
                                                                settings: widget
                                                                    .settings)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (payConfirmed != true) {
                                                  return;
                                                }
                                                final billAmount =
                                                    double.tryParse(billCtrl
                                                            .text
                                                            .trim()) ??
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
                                                          sku:
                                                              'TBL-${t['id'] ?? 0}',
                                                          barcode:
                                                              'TBL-${t['id'] ?? 0}',
                                                          purchasePrice: 0,
                                                          sellingPrice:
                                                              billAmount,
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
                                                  await db
                                                      .updateRestaurantTable(
                                                          id, {
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
                                              child: Text(
                                                  PosLocalization.tr('Checkout',
                                                      settings:
                                                          widget.settings),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
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
                            PosLocalization.tr(
                                'Live Kitchen Order Tickets (KOT)',
                                settings: widget.settings),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
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
                            label: Text(
                                PosLocalization.tr('Open Full-Screen KDS',
                                    settings: widget.settings),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_kotOrders.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
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
                                PosLocalization.tr('No Active Kitchen Orders',
                                    settings: widget.settings),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                PosLocalization.tr(
                                    'When waitstaff or cashiers send food orders to the kitchen, live KOT tickets will queue here.',
                                    settings: widget.settings),
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
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
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
                                    child: const Icon(
                                        Icons.restaurant_menu_rounded,
                                        color: Color(0xFFF97316),
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                PosLocalization.tr(
                                                    (k['order_type'] ??
                                                        k['type'] ??
                                                        'Dine-In') as String,
                                                    settings: widget.settings),
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
                                        tooltip: PosLocalization.tr(
                                            'Change KOT Status',
                                            settings: widget.settings),
                                        initialValue: k['status'] as String?,
                                        onSelected: (newStatus) async {
                                          final id = k['id'] as int? ?? 0;
                                          final db = await DatabaseService
                                              .initialize();
                                          await db.updateRestaurantKotStatus(
                                              id, newStatus);
                                          _loadData();
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'Cooking',
                                            child: Text(PosLocalization.tr(
                                                'Cooking',
                                                settings: widget.settings)),
                                          ),
                                          PopupMenuItem(
                                            value: 'Ready',
                                            child: Text(PosLocalization.tr(
                                                'Ready',
                                                settings: widget.settings)),
                                          ),
                                          PopupMenuItem(
                                            value: 'Served',
                                            child: Text(PosLocalization.tr(
                                                'Served',
                                                settings: widget.settings)),
                                          ),
                                        ],
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: ((k['status'] == 'Ready')
                                                    ? const Color(0xFF10B981)
                                                    : (k['status'] == 'Served')
                                                        ? const Color(
                                                            0xFF64748B)
                                                        : const Color(
                                                            0xFFF59E0B))
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                PosLocalization.tr(
                                                    k['status'] as String,
                                                    settings: widget.settings),
                                                style: TextStyle(
                                                    color:
                                                        (k['status'] == 'Ready')
                                                            ? const Color(
                                                                0xFF10B981)
                                                            : (k['status'] ==
                                                                    'Served')
                                                                ? const Color(
                                                                    0xFF64748B)
                                                                : const Color(
                                                                    0xFFF59E0B),
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
                                                        ? const Color(
                                                            0xFF64748B)
                                                        : const Color(
                                                            0xFFF59E0B),
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

  Future<void> _showSplitBillDialog(Map<String, dynamic> t) async {
    final currency = widget.settings.currencySymbol;
    final total =
        ((t['order_total'] ?? t['orderTotal'] ?? 0.0) as num).toDouble();
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PosLocalization.tr(
                'No active bill to split on this table.',
                settings: widget.settings))),
      );
      return;
    }

    int splitWays = (t['guests'] as int?) ?? 2;
    if (splitWays < 2) splitWays = 2;

    double customSplitPart = total / splitWays;
    final customCtrl =
        TextEditingController(text: customSplitPart.toStringAsFixed(2));
    String splitMode = 'equal'; // 'equal' or 'custom'

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final partAmount = splitMode == 'equal'
              ? (total / splitWays)
              : (double.tryParse(customCtrl.text.trim()) ??
                  (total / splitWays));
          final remainingAmount = (total - partAmount).clamp(0.0, total);

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.call_split_rounded,
                    color: Color(0xFFF97316), size: 22),
                const SizedBox(width: 8),
                Text(
                    PosLocalization.trParams(
                        'Split Bill • {table}', {'table': '${t['name']}'},
                        settings: widget.settings),
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFFF97316).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            PosLocalization.tr('Total Table Bill:',
                                settings: widget.settings),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('$currency ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFFF97316))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(PosLocalization.tr('Split Equally',
                              settings: widget.settings)),
                          selected: splitMode == 'equal',
                          selectedColor: const Color(0xFFF97316),
                          labelStyle: TextStyle(
                              color: splitMode == 'equal' ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          onSelected: (val) {
                            if (val) setDlgState(() => splitMode = 'equal');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(PosLocalization.tr('Custom Diner Share',
                              settings: widget.settings)),
                          selected: splitMode == 'custom',
                          selectedColor: const Color(0xFFF97316),
                          labelStyle: TextStyle(
                              color:
                                  splitMode == 'custom' ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          onSelected: (val) {
                            if (val) setDlgState(() => splitMode = 'custom');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (splitMode == 'equal') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            PosLocalization.tr('Number of Diners:',
                                settings: widget.settings),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: splitWays > 2
                                  ? () => setDlgState(() => splitWays--)
                                  : null,
                            ),
                            Text('$splitWays',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: splitWays < 20
                                  ? () => setDlgState(() => splitWays++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      PosLocalization.trParams(
                          'Each Diner Pays: {currency} {amount}',
                          {
                            'currency': currency,
                            'amount': partAmount.toStringAsFixed(2)
                          },
                          settings: widget.settings),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981)),
                    ),
                  ] else ...[
                    TextField(
                      controller: customCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: PosLocalization.trParams(
                            'Enter Amount for This Diner ({currency})',
                            {'currency': currency},
                            settings: widget.settings),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      PosLocalization.trParams(
                          'Remaining Balance: {currency} {amount}',
                          {
                            'currency': currency,
                            'amount': remainingAmount.toStringAsFixed(2)
                          },
                          settings: widget.settings),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                    PosLocalization.tr('Cancel', settings: widget.settings)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: Text(PosLocalization.trParams(
                    'Pay Share ({currency} {amount})',
                    {
                      'currency': currency,
                      'amount': partAmount.toStringAsFixed(2)
                    },
                    settings: widget.settings)),
                onPressed: () async {
                  final db = await DatabaseService.initialize();
                  final inv = await db.generateNextInvoiceNo();
                  final nowStr = DateTime.now().toString().substring(0, 19);
                  await db.createSale(
                    sale: Sale(
                      invoiceNo: inv,
                      customerName: 'Split Bill • ${t['name']}',
                      subtotal: partAmount,
                      totalAmount: partAmount,
                      paidAmount: partAmount,
                      paymentMethod: 'cash',
                      paymentStatus: 'paid',
                      saleStatus: 'final',
                      note:
                          'Table Bill Split (${splitMode == "equal" ? "$splitWays-way split" : "Custom diner share"})',
                      createdAt: nowStr,
                    ),
                    items: [
                      CartItem(
                        product: Product(
                          name: 'Table ${t['name']} - Split Share',
                          sku: 'TBL-SPLIT-${t['id'] ?? 0}',
                          barcode: 'TBL-SPLIT',
                          purchasePrice: 0,
                          sellingPrice: partAmount,
                          stockQuantity: 1,
                        ),
                        quantity: 1,
                        unitPrice: partAmount,
                      ),
                    ],
                  );

                  final remaining = total - partAmount;
                  final id = t['id'] as int?;
                  if (id != null) {
                    if (remaining <= 0.01) {
                      await db.updateRestaurantTable(id, {
                        'status': 'vacant',
                        'order_total': 0.0,
                        'kot_time': null,
                      });
                    } else {
                      await db.updateRestaurantTable(id, {
                        'order_total': remaining,
                      });
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(remaining <= 0.01
                            ? PosLocalization.trParams(
                                'Table {table} fully paid and cleared!',
                                {'table': '${t['name']}'},
                                settings: widget.settings)
                            : PosLocalization.trParams(
                                'Paid {currency} {paid}. Remaining balance: {currency} {remaining}',
                                {
                                  'currency': currency,
                                  'paid': partAmount.toStringAsFixed(2),
                                  'remaining': remaining.toStringAsFixed(2),
                                },
                                settings: widget.settings)),
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

  Future<void> _showTableModifiersDialog(Map<String, dynamic> t) async {
    final noteCtrl =
        TextEditingController(text: (t['modifiers'] ?? '').toString());
    final List<String> availableModifiers = [
      'Mild Spice',
      'Medium Spicy',
      'Extra Hot / Spicy',
      'Well Done',
      'Crispy',
      'Extra Cheese (+50)',
      'Extra Sauce / Mayo',
      'No Onion / Garlic',
      'Gluten Free',
      'Sugar Free',
      'Takeaway Pack',
      'Fast Service (Child)',
    ];

    final currentMods = (t['modifiers'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.ramen_dining_rounded,
                    color: Color(0xFFF97316), size: 22),
                const SizedBox(width: 8),
                Text(
                    PosLocalization.trParams('Kitchen Modifiers • {table}',
                        {'table': '${t['name']}'}, settings: widget.settings),
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      PosLocalization.tr(
                          'Select Food & Cooking Instructions for Kitchen:',
                          settings: widget.settings),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableModifiers.map((mod) {
                      final isSel = currentMods.contains(mod);
                      return FilterChip(
                        label: Text(
                            PosLocalization.tr(mod, settings: widget.settings),
                            style: TextStyle(
                                fontSize: 12,
                                color: isSel ? Colors.white : null)),
                        selected: isSel,
                        selectedColor: const Color(0xFFF97316),
                        onSelected: (val) {
                          setDlgState(() {
                            if (val) {
                              currentMods.add(mod);
                            } else {
                              currentMods.remove(mod);
                            }
                            noteCtrl.text = currentMods.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: PosLocalization.tr(
                          'Special Chef Note / Allergen Instructions',
                          settings: widget.settings),
                      hintText: PosLocalization.tr(
                          'e.g. Serve drinks first, less salt in soup',
                          settings: widget.settings),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                      PosLocalization.tr('Cancel', settings: widget.settings))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.kitchen_rounded, size: 16),
                label: Text(PosLocalization.tr('Save & Send to Kitchen',
                    settings: widget.settings)),
                onPressed: () async {
                  final id = t['id'] as int?;
                  final text = noteCtrl.text.trim();
                  if (id != null) {
                    final db = await DatabaseService.initialize();
                    await db.updateRestaurantTable(id, {'modifiers': text});
                  } else {
                    t['modifiers'] = text;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(PosLocalization.trParams(
                            'Kitchen modifiers updated for {table}!',
                            {'table': '${t['name']}'},
                            settings: widget.settings)),
                        backgroundColor: const Color(0xFFF97316),
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
}
