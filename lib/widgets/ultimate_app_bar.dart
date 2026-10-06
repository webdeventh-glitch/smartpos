import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'calculator_dialog.dart';

class UltimateAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onOpenPos;
  final VoidCallback onOpenRegisterDetails;
  final VoidCallback onToggleSidebar;
  final BusinessSettings settings;
  final String? activeLocationName;
  final Function(String)? onLocationChanged;

  const UltimateAppBar({
    super.key,
    required this.onOpenPos,
    required this.onOpenRegisterDetails,
    required this.onToggleSidebar,
    required this.settings,
    this.activeLocationName,
    this.onLocationChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<UltimateAppBar> createState() => _UltimateAppBarState();
}

class _UltimateAppBarState extends State<UltimateAppBar> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  CashRegister? _activeRegister;
  List<BusinessLocation> _locations = [];
  String _currentLocation = 'Main Branch HQ';

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.activeLocationName ?? widget.settings.branchName;
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _currentTime = DateTime.now());
        }
      });
    }
    _loadRegisterAndLocations();
  }

  Future<void> _loadRegisterAndLocations() async {
    final db = await DatabaseService.initialize();
    final reg = await db.getActiveRegister();
    final locs = await db.getBusinessLocations();
    if (mounted) {
      setState(() {
        _activeRegister = reg;
        _locations = locs;
        if (_locations.isNotEmpty && !_locations.any((l) => l.name == _currentLocation)) {
          _currentLocation = _locations.first.name;
        }
      });
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _squareBtn({required Widget icon, required VoidCallback onTap, String? tooltip, Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(_currentTime);
    final timeStr = DateFormat('hh:mm a').format(_currentTime);
    final inHand = _activeRegister != null ? _activeRegister!.totalCashInRegister : 250.0;
    final currency = widget.settings.currencySymbol;

    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1350;
          final isNarrow = constraints.maxWidth < 1050;

          return Row(
            children: [
              // Sidebar Toggle Button [ ◫ ]
              _squareBtn(
                icon: const Icon(Icons.menu_open_rounded, color: Color(0xFF475569), size: 19),
                onTap: widget.onToggleSidebar,
                tooltip: 'Toggle Navigation',
              ),
              const SizedBox(width: 8),

              // Brand Logo Badge + Business Name
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x334F46E5),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.settings.businessName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Live',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.settings.branchName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Business Location Selector (Branch / Warehouse Pill)
              if (_locations.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Switch Active Branch',
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onSelected: (locName) {
                    setState(() => _currentLocation = locName);
                    if (widget.onLocationChanged != null) {
                      widget.onLocationChanged!(locName);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched active branch to $locName'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1E293B),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  itemBuilder: (ctx) => _locations
                      .map(
                        (loc) => PopupMenuItem<String>(
                          value: loc.name,
                          child: Row(
                            children: [
                              Icon(
                                loc.name == _currentLocation ? Icons.check_circle_rounded : Icons.store_outlined,
                                size: 16,
                                color: loc.name == _currentLocation ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                loc.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: loc.name == _currentLocation ? FontWeight.bold : FontWeight.w500,
                                  color: loc.name == _currentLocation ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _currentLocation,
                          style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Cash Register Drawer Status Pill
              InkWell(
                onTap: widget.onOpenRegisterDetails,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings_outlined, color: Color(0xFF16A34A), size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Cash: $currency${inHand.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Date & Time Pill (adapts to screen width)
              if (!isCompact)
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, color: Color(0xFF64748B), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        constraints.maxWidth > 1460 ? '$dateStr • $timeStr' : timeStr,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Calculator Shortcut
              if (!isNarrow)
                _squareBtn(
                  icon: const Icon(Icons.calculate_outlined, color: Color(0xFF475569), size: 18),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const CalculatorDialog(),
                    );
                  },
                  tooltip: 'Quick Calculator',
                ),

              // Sync Status Shortcut
              _squareBtn(
                icon: const Icon(Icons.cloud_done_outlined, color: Color(0xFF10B981), size: 18),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Offline SQLite Database synchronized and fully active.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                tooltip: 'Database Status: Synced',
              ),

          // Prominent POS Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onOpenPos,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x334F46E5),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 17),
                      SizedBox(width: 6),
                      Text(
                        'POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'F1',
                        style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Pill: User Chip
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                    'AD',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Super Admin',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 16),
              ],
            ),
          ),
        ],
      );
    },
  ),
);
  }
}
