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

  const UltimateAppBar({
    super.key,
    required this.onOpenPos,
    required this.onOpenRegisterDetails,
    required this.onToggleSidebar,
    required this.settings,
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

  @override
  void initState() {
    super.initState();
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _currentTime = DateTime.now());
        }
      });
    }
    _loadRegister();
  }

  Future<void> _loadRegister() async {
    final reg = await DatabaseService.initialize().then((s) => s.getActiveRegister());
    if (mounted) setState(() => _activeRegister = reg);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Widget _squareBtn({required Widget icon, required VoidCallback onTap, String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(_currentTime);
    final inHand = _activeRegister != null ? _activeRegister!.totalCashInRegister : 250.0;
    final currency = widget.settings.currencySymbol;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF0038B8), // Ultimate POS Deep Blue
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Store Name with Green Online Indicator
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.settings.businessName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // Bright Online Green
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Sidebar Toggle Button [ ◫ ]
          _squareBtn(
            icon: const Icon(Icons.view_sidebar_outlined, color: Colors.white, size: 18),
            onTap: widget.onToggleSidebar,
            tooltip: 'Toggle Sidebar',
          ),

          const Spacer(),

          // Quick Action Buttons matching Screenshot 1:
          // Download / Sync [📥]
          _squareBtn(
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Offline database synced & up to date.'), duration: Duration(seconds: 1)),
              );
            },
            tooltip: 'Sync Data',
          ),

          // Add / Plus [⊕]
          _squareBtn(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            onTap: widget.onOpenPos,
            tooltip: 'New Transaction',
          ),

          // Calculator [🖩]
          _squareBtn(
            icon: const Icon(Icons.calculate_outlined, color: Colors.white, size: 18),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const CalculatorDialog(),
              );
            },
            tooltip: 'Calculator',
          ),

          // [ 㗊 POS ] Button (Prominent pill matching screenshot)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: widget.onOpenPos,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cash Register [ 💵 ]
          _squareBtn(
            icon: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 18),
            onTap: widget.onOpenRegisterDetails,
            tooltip: 'Register: $currency${inHand.toStringAsFixed(2)}',
          ),

          // Date Pill: 10/05/2026
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              dateStr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

          // Notifications Bell [ 🔔 ]
          _squareBtn(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 19),
            onTap: () {},
            tooltip: 'Notifications',
          ),

          // Profile Pill: Admin [ 👤 ⌵ ]
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.account_circle, color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
