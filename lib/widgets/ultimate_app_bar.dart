import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/theme_service.dart';
import '../services/cloud_sync_service.dart';
import 'calculator_dialog.dart';

class SmartAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onOpenPos;
  final VoidCallback onOpenRegisterDetails;
  final VoidCallback onToggleSidebar;
  final BusinessSettings settings;
  final String? activeLocationName;
  final Function(String)? onLocationChanged;

  const SmartAppBar({
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
  State<SmartAppBar> createState() => _SmartAppBarState();
}

/// Backward compatibility alias
typedef UltimateAppBar = SmartAppBar;

class _SmartAppBarState extends State<SmartAppBar> {
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

  List<Product> _alertProducts = [];
  List<Product> _expiringProducts = [];

  Future<void> _loadRegisterAndLocations() async {
    final db = await DatabaseService.initialize();
    final reg = await db.getActiveRegister();
    final locs = await db.getBusinessLocations();
    final lowStock = await db.getLowStockProducts();
    final expiring = await db.getExpiringProducts(monthsAhead: 6);
    if (mounted) {
      setState(() {
        _activeRegister = reg;
        _locations = locs;
        _alertProducts = lowStock;
        _expiringProducts = expiring;
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

  void _showInventoryAlertsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Inventory Critical Alerts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_alertProducts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      'Low Stock / Shortage Items (${_alertProducts.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _alertProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFFDE68A)),
                    itemBuilder: (context, idx) {
                      final p = _alertProducts[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text(
                              '${p.stockQuantity.toInt()} left (Alert: ${p.alertQuantity.toInt()})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_expiringProducts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Text(
                      'Impending Expiry Items (Within 6 Months) (${_expiringProducts.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _expiringProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFFECACA)),
                    itemBuilder: (context, idx) {
                      final p = _expiringProducts[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                if (p.batchNumber != null)
                                  Text('Batch: ${p.batchNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(
                                'Exp: ${p.expiryDate}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (_alertProducts.isEmpty && _expiringProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('All inventory is optimal! No items low on stock or expiring soon.'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  Widget _squareBtn({required Widget icon, required VoidCallback onTap, String? tooltip}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('dd MMM yyyy').format(_currentTime);
    final timeStr = DateFormat('hh:mm a').format(_currentTime);
    final inHand = _activeRegister != null ? _activeRegister!.totalCashInRegister : 250.0;
    final currency = widget.settings.currencySymbol;

    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1)),
        boxShadow: const [
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
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                  color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Live',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.settings.isMySql
                                      ? (isDark ? const Color(0xFF0369A1).withValues(alpha: 0.3) : const Color(0xFFE0F2FE))
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: widget.settings.isMySql ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.settings.isMySql ? Icons.dns_rounded : Icons.sd_storage_rounded,
                                      size: 10,
                                      color: widget.settings.isMySql ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.settings.isMySql ? 'MySQL: ${widget.settings.dbName}' : 'SQLite',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: widget.settings.isMySql ? const Color(0xFF0284C7) : const Color(0xFF64748B),
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
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                  color: loc.name == _currentLocation
                                      ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _currentLocation,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 16),
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
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings_outlined, color: Color(0xFF10B981), size: 15),
                      const SizedBox(width: 5),
                      Text(
                        'Cash: $currency${inHand.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
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
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        constraints.maxWidth > 1460 ? '$dateStr • $timeStr' : timeStr,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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

              // Dark / Light Mode Toggle Button
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.themeModeNotifier,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return _squareBtn(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.amberAccent : const Color(0xFF4F46E5),
                      size: 18,
                    ),
                    onTap: () => ThemeService.toggleTheme(),
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  );
                },
              ),

              // Sync Status Shortcut (Reactive with CloudSyncService)
              ValueListenableBuilder<SyncStatusInfo>(
                valueListenable: CloudSyncService.syncNotifier,
                builder: (context, syncInfo, _) {
                  final isOffline = widget.settings.isOfflineOnly;
                  final isSyncing = syncInfo.state == SyncState.syncing;

                  IconData iconData;
                  Color iconColor;
                  String tooltipText;

                  if (isOffline) {
                    iconData = Icons.cloud_off_rounded;
                    iconColor = const Color(0xFF94A3B8);
                    tooltipText = 'Database: Local Offline SQLite';
                  } else if (isSyncing) {
                    iconData = Icons.sync_rounded;
                    iconColor = const Color(0xFF6366F1);
                    tooltipText = 'Synchronizing with Laravel/MySQL...';
                  } else if (syncInfo.pendingCount > 0) {
                    iconData = Icons.cloud_upload_rounded;
                    iconColor = const Color(0xFFF59E0B);
                    tooltipText = 'Sync: ${syncInfo.pendingCount} pending changes (Click to Sync)';
                  } else {
                    iconData = Icons.cloud_done_rounded;
                    iconColor = const Color(0xFF10B981);
                    tooltipText = 'Sync: Fully Synchronized (Laravel / MySQL)';
                  }

                  return _squareBtn(
                    icon: Icon(iconData, color: iconColor, size: 18),
                    onTap: () async {
                      if (isOffline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline SQLite Database active. All data stored safely locally.'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Starting synchronization with Laravel/MySQL...'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        await CloudSyncService.syncNow(widget.settings);
                      }
                    },
                    tooltip: tooltipText,
                  );
                },
              ),

              // Stock Shortage & Expiry Alert Notification Bell
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Inventory Alerts: ${_alertProducts.length} low stock, ${_expiringProducts.length} expiring',
                  child: InkWell(
                    onTap: _showInventoryAlertsDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (_alertProducts.isNotEmpty || _expiringProducts.isNotEmpty)
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_alertProducts.isNotEmpty || _expiringProducts.isNotEmpty)
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 19,
                            color: (_alertProducts.isNotEmpty || _expiringProducts.isNotEmpty)
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF475569),
                          ),
                          if (_alertProducts.isNotEmpty || _expiringProducts.isNotEmpty)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.settings.isRestaurant
                            ? Icons.table_restaurant_rounded
                            : widget.settings.isRepair
                                ? Icons.build_circle_outlined
                                : widget.settings.isHotel
                                    ? Icons.hotel_rounded
                                    : widget.settings.isGym
                                        ? Icons.fitness_center_rounded
                                        : Icons.bolt_rounded,
                        color: Colors.amber,
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.settings.isRestaurant
                            ? 'Tables (POS)'
                            : widget.settings.isRepair
                                ? 'Jobs (POS)'
                                : widget.settings.isHotel
                                    ? 'Rooms (POS)'
                                    : widget.settings.isGym
                                        ? 'Gym (POS)'
                                        : 'POS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
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

          // Dynamic Profile Pill & Logout Menu
          ValueListenableBuilder<User?>(
            valueListenable: AuthService.currentUserNotifier,
            builder: (context, user, _) {
              final displayName = user?.name ?? 'Irfan Khan';
              final roleName = (user?.role ?? 'superadmin').toUpperCase();
              final initials = displayName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();

              return PopupMenuButton<String>(
                tooltip: 'Account & Session Options',
                offset: const Offset(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                onSelected: (val) async {
                  if (val == 'logout') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.logout_rounded, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Confirm Logout'),
                          ],
                        ),
                        content: const Text('Are you sure you want to end your current terminal session?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService.logout();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${user?.email ?? 'webdeventh@smartpos.local'} • $roleName',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 18, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        const SizedBox(width: 10),
                        const Text('My Profile & Roles', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Log Out / Exit Session', style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFEEF2FF),
                        child: Text(
                          initials.isNotEmpty ? initials : 'AD',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            roleName,
                            style: const TextStyle(
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
              );
            },
          ),
        ],
      );
    },
  ),
);
  }
}
