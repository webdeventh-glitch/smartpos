import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/database_service.dart';

class HotelManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const HotelManagementScreen({super.key, required this.settings});

  @override
  State<HotelManagementScreen> createState() => _HotelManagementScreenState();
}

class _HotelManagementScreenState extends State<HotelManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];
  String _viewMode = 'cards'; // 'cards' or 'matrix'

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.initialize();
      final rows = await db.getHotelRooms();
      setState(() {
        _rooms = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.error('HotelManagement', 'Failed loading hotel rooms', e, st);
      if (mounted) {
        setState(() => _isLoading = false);
        await AppErrorHandler.showErrorDialog(
          context,
          title: 'Load Failed',
          message: 'Could not load hotel rooms from database.',
          error: e,
          stackTrace: st,
          tag: 'HotelManagement',
        );
      }
    }
  }

  Future<void> _showAddRoomModal() async {
    final roomNoCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Executive Deluxe');
    final floorCtrl = TextEditingController(text: '1st Floor');
    final rateCtrl = TextEditingController(text: '7500');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            'Add New Room to Hotel',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNoCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Room Number (e.g. 301)*',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Room Category / Type',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: floorCtrl,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Floor Location (e.g. 3rd Floor)',
                  labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Nightly Rate (${widget.settings.currencySymbol})',
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
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (roomNoCtrl.text.trim().isNotEmpty) {
                  final db = await DatabaseService.initialize();
                  await db.addHotelRoom({
                    'room': roomNoCtrl.text.trim(),
                    'type': typeCtrl.text.trim(),
                    'floor': floorCtrl.text.trim(),
                    'rate': double.tryParse(rateCtrl.text.trim()) ?? 7500.0,
                    'status': 'available',
                    'guest': '',
                    'nights': 0,
                    'check_in': '',
                    'room_service': 0.0,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadRooms();
                }
              },
              child: const Text('Add Room'),
            ),
          ],
        );
      },
    );
  }

  void _showCheckInModal(Map<String, dynamic> room) {
    final guestCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final nightsCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Check-In Room ${room['room']}',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: guestCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Primary Guest Full Name*',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cnicCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'CNIC / National ID / Passport No.*',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nightsCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Number of Nights Stay',
                    labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
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
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (guestCtrl.text.trim().isNotEmpty && room['id'] != null) {
                  final db = await DatabaseService.initialize();
                  await db.updateHotelRoom(room['id'] as int, {
                    'status': 'occupied',
                    'guest':
                        '${guestCtrl.text.trim()} (CNIC: ${cnicCtrl.text.trim()})',
                    'nights': int.tryParse(nightsCtrl.text) ?? 1,
                    'check_in': 'Today',
                    'room_service': 0.0,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadRooms();
                }
              },
              child: const Text('Confirm Check-In'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkOut(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    final rate = (room['rate'] is num) ? (room['rate'] as num).toDouble() : 0.0;
    final nights =
        (room['nights'] is num) ? (room['nights'] as num).toInt() : 1;
    final roomService = (room['room_service'] is num)
        ? (room['room_service'] as num).toDouble()
        : 0.0;
    final roomRent = rate * (nights > 0 ? nights : 1);
    final totalBill = roomRent + roomService;
    final currency = widget.settings.currencySymbol;

    final db = await DatabaseService.initialize();
    final folioRows = await db.getModuleRecords('hotel',
        recordType: 'hotel_folio_${room['room']}');
    final pendingFolioItems = folioRows.where((r) {
      final s = (r['_status'] ?? r['status'])?.toString();
      return s != 'settled';
    }).toList();

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFF10B981), size: 24),
              const SizedBox(width: 8),
              Text(
                'Room ${room['room']} Folio Settlement',
                style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Guest: ${room['guest'] ?? 'Hotel Guest'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(
                            'Room Type: ${room['type'] ?? 'Standard'} • Floor: ${room['floor'] ?? '1st Floor'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Invoice Charges Breakdown:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          'Room Stay ($nights Nights @ $currency${rate.toStringAsFixed(0)}):'),
                      Text('$currency${roomRent.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (pendingFolioItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Itemized Room Folio Services:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6))),
                    const SizedBox(height: 4),
                    for (final item in pendingFolioItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '• ${item['_title'] ?? item['title'] ?? item['description'] ?? 'Service'}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$currency${((item['amount'] is num) ? (item['amount'] as num).toDouble() : ((item['data']?['amount'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ] else if (roomService > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Room Service Charges:'),
                        Text('$currency${roomService.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Payable Bill:',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                      Text('$currency${totalBill.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF10B981))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Settle Bill & Check Out'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (totalBill > 0) {
      final invNo = await db.generateNextInvoiceNo();
      final nowStr = DateTime.now().toString().substring(0, 19);
      final saleItems = <CartItem>[
        CartItem(
          product: Product(
            name: 'Room ${room['room']} Stay ($nights nights)',
            sku: 'ROOM-${room['room']}',
            barcode: 'ROOM-${room['room']}',
            purchasePrice: 0,
            sellingPrice: roomRent,
            stockQuantity: 1,
          ),
          quantity: 1,
          unitPrice: roomRent,
        ),
      ];

      if (pendingFolioItems.isNotEmpty) {
        for (final item in pendingFolioItems) {
          final amt = (item['amount'] is num)
              ? (item['amount'] as num).toDouble()
              : ((item['data']?['amount'] as num?)?.toDouble() ?? 0.0);
          final title = item['_title'] as String? ??
              item['title'] as String? ??
              item['description'] as String? ??
              'Room Service';
          final itemId = item['_dbId'] ?? item['id'] ?? 1;
          saleItems.add(
            CartItem(
              product: Product(
                name: 'Room ${room['room']} - $title',
                sku: 'FOLIO-${room['room']}-$itemId',
                barcode: 'FOLIO-${room['room']}',
                purchasePrice: 0,
                sellingPrice: amt,
                stockQuantity: 1,
              ),
              quantity: 1,
              unitPrice: amt,
            ),
          );
        }
      } else if (roomService > 0) {
        saleItems.add(
          CartItem(
            product: Product(
              name: 'Room Service Charges (${room['room']})',
              sku: 'RS-${room['room']}',
              barcode: 'RS-${room['room']}',
              purchasePrice: 0,
              sellingPrice: roomService,
              stockQuantity: 1,
            ),
            quantity: 1,
            unitPrice: roomService,
          ),
        );
      }

      await db.createSale(
        sale: Sale(
          invoiceNo: invNo,
          customerName: (room['guest'] as String? ?? 'Hotel Guest')
              .split('(')
              .first
              .trim(),
          subtotal: totalBill,
          totalAmount: totalBill,
          paidAmount: totalBill,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          saleStatus: 'final',
          note: 'Hotel Checkout • Room ${room['room']} ($nights nights)',
          createdAt: nowStr,
        ),
        items: saleItems,
        enforceStock: false,
      );

      // Mark folio charges settled
      for (final item in pendingFolioItems) {
        final itemId = (item['_dbId'] ?? item['id']) as int?;
        if (itemId != null) {
          await db.saveModuleRecord(
            id: itemId,
            moduleKey: 'hotel',
            recordType: 'hotel_folio_${room['room']}',
            title: item['_title'] as String? ?? item['title'] as String? ?? '',
            status: 'settled',
            data: Map<String, dynamic>.from(item),
          );
        }
      }
    }

    await db.updateHotelRoom(id, {
      'status': 'cleaning',
      'guest': '',
      'nights': 0,
      'check_in': '',
      'room_service': 0.0,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Room ${room['room']} billed ($currency${totalBill.toStringAsFixed(0)}) & marked for housekeeping.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
    _loadRooms();
  }

  Future<void> _markAvailable(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    final db = await DatabaseService.initialize();
    await db.updateHotelRoom(id, {
      'status': 'available',
    });
    _loadRooms();
  }

  Future<void> _addServiceCharge(Map<String, dynamic> room) async {
    final id = room['id'] as int?;
    if (id == null) return;
    String selectedCategory = 'Dining & Room Service';
    final amountCtrl = TextEditingController(text: '750');
    final descCtrl =
        TextEditingController(text: 'Club Sandwich & Mineral Water');

    final categories = [
      'Dining & Room Service',
      'Laundry & Dry Cleaning',
      'Minibar & Refreshments',
      'Airport Taxi / Travel',
      'Spa, Pool & Fitness',
      'Housekeeping Addon',
      'Miscellaneous',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            title: Row(
              children: [
                const Icon(Icons.room_service_rounded,
                    color: Color(0xFF3B82F6), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Post Charge to Room ${room['room']} Folio',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guest: ${room['guest'] ?? 'Hotel Guest'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor:
                        isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Folio Charge Category',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Service Description / Items*',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText:
                          'Charge Amount (${widget.settings.currencySymbol})*',
                      labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Post to Room Folio'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    final charge = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    if (charge <= 0) return;

    final current = (room['room_service'] is num)
        ? (room['room_service'] as num).toDouble()
        : 0.0;
    final db = await DatabaseService.initialize();

    // 1. Atomically increment room_service on the room
    await db.updateHotelRoom(id, {
      'room_service': current + charge,
    });

    // 2. Log folio ledger transaction in module_records
    await db.saveModuleRecord(
      moduleKey: 'hotel',
      recordType: 'hotel_folio_${room['room']}',
      title: '$selectedCategory: ${descCtrl.text.trim()}',
      status: 'pending',
      data: {
        'roomId': id,
        'roomNo': room['room'],
        'category': selectedCategory,
        'description': descCtrl.text.trim(),
        'amount': charge,
        'postedAt': DateTime.now().toIso8601String(),
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$selectedCategory (${widget.settings.currencySymbol}${charge.toStringAsFixed(0)}) added to Room ${room['room']} folio.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
    _loadRooms();
  }

  void _showRoomStayDetailsSheet(Map<String, dynamic> room) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final rateVal =
        (room['rate'] is num) ? (room['rate'] as num).toDouble() : 0.0;
    final nightsVal =
        (room['nights'] is num) ? (room['nights'] as num).toInt() : 1;
    final roomServiceVal = (room['room_service'] is num)
        ? (room['room_service'] as num).toDouble()
        : 0.0;
    final totalBill = (rateVal * nightsVal) + roomServiceVal;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room ${room['room']} Details (${room['type'] ?? 'Room'})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('OCCUPIED',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Primary Guest: ${room['guest'] ?? 'Guest'}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                'Stay Length: $nightsVal Nights • Rate: $currency${rateVal.toStringAsFixed(0)} / night',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B))),
            Text(
                'Folio Room Service Charges: $currency${roomServiceVal.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF3B82F6))),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Accrued Balance:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                Text('$currency${totalBill.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('+ Folio Charge'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addServiceCharge(room);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Check-Out & Settle'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _checkOut(room);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    final totalRooms = _rooms.length;
    final occupiedRooms = _rooms.where((r) => r['status'] == 'occupied').length;
    final availableRooms =
        _rooms.where((r) => r['status'] == 'available').length;
    final cleaningRooms = _rooms.where((r) => r['status'] == 'cleaning').length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.hotel_rounded, color: Color(0xFF3B82F6), size: 22),
            const SizedBox(width: 10),
            Text(
              'Hotel & Room Management System',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          SegmentedButton<String>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 'cards',
                icon: Icon(Icons.grid_view_rounded, size: 16),
                label: Text('Cards View', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: 'matrix',
                icon: Icon(Icons.calendar_month_rounded, size: 16),
                label: Text('30-Day Matrix', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) {
              if (val.isNotEmpty) setState(() => _viewMode = val.first);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh SQLite Data',
            onPressed: _loadRooms,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white),
              onPressed: _showAddRoomModal,
              icon: const Icon(Icons.add_home_work_rounded, size: 16),
              label: const Text('Add Room'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viewMode == 'matrix'
              ? _buildAvailabilityMatrix(isDark, currency)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Metric Badges
                      Row(
                        children: [
                          _metric('Total Rooms', '$totalRooms',
                              const Color(0xFF6366F1), isDark),
                          const SizedBox(width: 14),
                          _metric('Occupied Rooms', '$occupiedRooms',
                              const Color(0xFF3B82F6), isDark),
                          const SizedBox(width: 14),
                          _metric('Available Rooms', '$availableRooms',
                              const Color(0xFF10B981), isDark),
                          const SizedBox(width: 14),
                          _metric('Cleaning / Maint.', '$cleaningRooms',
                              const Color(0xFFF59E0B), isDark),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Room Cards Grid
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
                        itemCount: _rooms.length,
                        itemBuilder: (context, idx) {
                          final r = _rooms[idx];
                          final status = r['status']?.toString() ?? 'available';
                          Color statusColor = const Color(0xFF10B981);
                          if (status == 'occupied') {
                            statusColor = const Color(0xFF3B82F6);
                          }
                          if (status == 'cleaning') {
                            statusColor = const Color(0xFFF59E0B);
                          }

                          final rateVal = (r['rate'] is num)
                              ? (r['rate'] as num).toDouble()
                              : 0.0;
                          final nightsVal = (r['nights'] is num)
                              ? (r['nights'] as num).toInt()
                              : 0;
                          final roomServiceVal = (r['room_service'] is num)
                              ? (r['room_service'] as num).toDouble()
                              : 0.0;
                          final totalBill =
                              (rateVal * nightsVal) + roomServiceVal;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.6),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.2 : 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Room ${r['room']}',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('(${r['type'] ?? ''})',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B))),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.15),
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
                                  'Floor: ${r['floor'] ?? '1st Floor'} • Rate: $currency${rateVal.toStringAsFixed(0)} / night',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                                ),
                                if (status == 'occupied') ...[
                                  Text(
                                    'Guest: ${r['guest'] ?? 'Guest'}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Stay: $nightsVal Nights • Service: $currency${roomServiceVal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B)),
                                  ),
                                  Text(
                                    'Total Bill: $currency${totalBill.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF3B82F6)),
                                  ),
                                ] else ...[
                                  Text(
                                    status == 'cleaning'
                                        ? 'Room is undergoing sanitization'
                                        : 'Ready for guest check-in (SQLite Saved)',
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
                                    if (status == 'available')
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _showCheckInModal(r),
                                        child: const Text('Check-In',
                                            style: TextStyle(fontSize: 11)),
                                      )
                                    else if (status == 'occupied')
                                      Row(
                                        children: [
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                                visualDensity:
                                                    VisualDensity.compact),
                                            onPressed: () =>
                                                _addServiceCharge(r),
                                            child: const Text('+ Service',
                                                style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 6),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () => _checkOut(r),
                                            child: const Text('Check-Out',
                                                style: TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      )
                                    else
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () => _markAvailable(r),
                                        child: const Text('Mark Available',
                                            style: TextStyle(fontSize: 11)),
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
    );
  }

  Widget _metric(String title, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(val,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityMatrix(bool isDark, String currency) {
    final today = DateTime.now();
    final dates = List.generate(30, (i) => today.add(Duration(days: i)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Availability Calendar Header & Legend Bar
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
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Room Availability & Occupancy Calendar Matrix',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(dates.first)} to ${DateFormat('dd MMM yyyy').format(dates.last)} • Instant check-in & occupancy forecast',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Legend
                Row(
                  children: [
                    _legendPill('Available', const Color(0xFF10B981), isDark),
                    const SizedBox(width: 8),
                    _legendPill('Occupied', const Color(0xFF3B82F6), isDark),
                    const SizedBox(width: 8),
                    _legendPill(
                        'Housekeeping', const Color(0xFFF59E0B), isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2D Scrollable Matrix Table
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 10,
                  headingRowHeight: 52,
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 58,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  ),
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: 140,
                        child: Text(
                          'ROOM / TYPE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    ...dates.asMap().entries.map((entry) {
                      final i = entry.key;
                      final d = entry.value;
                      final isToday = i == 0;
                      return DataColumn(
                        label: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: const Color(0xFF3B82F6)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('d MMM').format(d),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? const Color(0xFF3B82F6)
                                      : (isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A)),
                                ),
                              ),
                              Text(
                                isToday
                                    ? 'TODAY'
                                    : DateFormat('E').format(d).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? const Color(0xFF3B82F6)
                                      : (isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  rows: _rooms.map((room) {
                    final status = room['status']?.toString() ?? 'available';
                    final nights = (room['nights'] is num)
                        ? (room['nights'] as num).toInt()
                        : 0;
                    final guestName = room['guest']?.toString() ?? '';
                    final guestShort = guestName.split('(').first.trim();

                    return DataRow(
                      cells: [
                        // Room Name Column
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Room ${room['room']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${room['floor'] ?? '1F'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${room['type'] ?? 'Room'} • $currency${((room['rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 30 Days Columns
                        ...List.generate(30, (dayIdx) {
                          bool isOccupiedDay = false;
                          bool isCleaningDay = false;

                          if (dayIdx == 0) {
                            if (status == 'occupied') isOccupiedDay = true;
                            if (status == 'cleaning') isCleaningDay = true;
                          } else {
                            if (status == 'occupied' &&
                                dayIdx < (nights > 0 ? nights : 1)) {
                              isOccupiedDay = true;
                            }
                          }

                          Color cellColor = const Color(0xFF10B981);
                          String cellText = 'Free';
                          IconData cellIcon = Icons.add;

                          if (isOccupiedDay) {
                            cellColor = const Color(0xFF3B82F6);
                            cellText = guestShort.isNotEmpty
                                ? (guestShort.length > 8
                                    ? '${guestShort.substring(0, 8)}..'
                                    : guestShort)
                                : 'Occupied';
                            cellIcon = Icons.person;
                          } else if (isCleaningDay) {
                            cellColor = const Color(0xFFF59E0B);
                            cellText = 'Clean';
                            cellIcon = Icons.cleaning_services;
                          }

                          return DataCell(
                            InkWell(
                              onTap: () {
                                if (isOccupiedDay) {
                                  _showRoomStayDetailsSheet(room);
                                } else if (isCleaningDay) {
                                  _markAvailable(room);
                                } else {
                                  _showCheckInModal(room);
                                }
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 80,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: cellColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: cellColor.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(cellIcon, size: 12, color: cellColor),
                                    const SizedBox(height: 2),
                                    Text(
                                      cellText,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: cellColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendPill(String title, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
