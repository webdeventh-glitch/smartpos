import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.settings,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.login(_userCtrl.text.trim(), _passCtrl.text.trim());
      if (success) {
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid username or password. Please verify credentials.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'System authentication error: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _defaultTitle() {
    if (widget.settings.loginSideTitle.trim().isNotEmpty) {
      return widget.settings.loginSideTitle.trim();
    }
    switch (widget.settings.businessType.toLowerCase()) {
      case 'pharmacy':
        return 'Next-Generation Pharmacy & Retail Agency Engine';
      case 'supermarket':
        return 'High-Volume Supermarket & Wholesale Hub';
      case 'restaurant':
      case 'cafe':
        return 'Smart Restaurant & Cafe Management Suite';
      case 'clothing':
      case 'garments':
        return 'Fashion Boutique & Apparel Retail Suite';
      case 'gym':
        return 'Fitness Club & Gym Membership Terminal';
      case 'repair':
      case 'service':
        return 'Device Diagnostics & Repair Workstation';
      case 'fruit_wholesale':
        return 'Fruit & Sabzi Wholesale Mandi Arhat Suite';
      case 'poultry':
        return 'Poultry Farming & Feed Trade Management Engine';
      default:
        return 'Next-Generation Enterprise POS & Wholesale Engine';
    }
  }

  String _defaultSubtitle() {
    if (widget.settings.loginSideSubtitle.trim().isNotEmpty) {
      return widget.settings.loginSideSubtitle.trim();
    }
    switch (widget.settings.businessType.toLowerCase()) {
      case 'pharmacy':
        return 'Ultra-fast SQLite local architecture designed to handle over 1.5 million transactions with zero lag, instant batch-expiry control, and seamless multi-branch management.';
      case 'supermarket':
        return 'Real-time barcode scanning, multi-cashier registers, instant FIFO batch stock tracking, and dynamic thermal label printing.';
      case 'restaurant':
      case 'cafe':
        return 'Interactive visual table floor plans, Kitchen Order Tickets (KOT), waiter mobile dispatch, and precise recipe ingredient cost tracking.';
      case 'gym':
        return 'Biometric check-in attendance, member expiry notifications, locker lease management, and personal trainer scheduling.';
      case 'repair':
      case 'service':
        return 'Job ticketing, customer tracking, technician assignment, spare parts consumption, and warranty tracking.';
      default:
        return 'Ultra-fast local SQLite storage guarantees zero billing lag during peak hours, with optional hybrid sync to remote MySQL/Laravel cloud.';
    }
  }

  List<Map<String, dynamic>> _featureBadges() {
    switch (widget.settings.businessType.toLowerCase()) {
      case 'pharmacy':
        return [
          {'icon': Icons.medical_services_rounded, 'text': 'Medicine & Pharmacy Agency Ready (Form 2A & 236H)'},
          {'icon': Icons.bolt_rounded, 'text': 'Blazing Fast POS Terminal with [F1] Hotkeys'},
          {'icon': Icons.inventory_2_rounded, 'text': 'Automated Sales & Purchase Returns Restocking'},
          {'icon': Icons.calendar_month_rounded, 'text': 'Annual Financial Closing & Ledger Carry-Forward'},
        ];
      case 'supermarket':
        return [
          {'icon': Icons.qr_code_scanner_rounded, 'text': 'Barcode & Weight Scale Terminal Integration'},
          {'icon': Icons.print_rounded, 'text': 'Dynamic Shelf Label & Barcode Sticker Printing'},
          {'icon': Icons.local_offer_rounded, 'text': 'Selling Price Groups & Volume Wholesale Discounts'},
          {'icon': Icons.point_of_sale_rounded, 'text': 'Parked Sales, Shift Registers & Fast Multi-Pay'},
        ];
      case 'restaurant':
      case 'cafe':
        return [
          {'icon': Icons.table_restaurant_rounded, 'text': 'Visual Table Plan & Real-Time Floor Layout'},
          {'icon': Icons.outdoor_grill_rounded, 'text': 'Instant Kitchen Order Tickets (KOT) Dispatch'},
          {'icon': Icons.delivery_dining_rounded, 'text': 'Dine-In, Takeaway & Home Delivery Tracking'},
          {'icon': Icons.receipt_long_rounded, 'text': 'Bill Splitting, Service Charges & Tips Management'},
        ];
      case 'gym':
        return [
          {'icon': Icons.fitness_center_rounded, 'text': 'Member Subscriptions & Auto-Expiry Alerts'},
          {'icon': Icons.lock_clock_rounded, 'text': 'Smart Locker Allocation & Monthly Rentals'},
          {'icon': Icons.sports_mma_rounded, 'text': 'Personal Trainer Packages & Performance Logs'},
          {'icon': Icons.badge_rounded, 'text': 'Instant Check-in & Member Attendance Ledger'},
        ];
      case 'repair':
      case 'service':
        return [
          {'icon': Icons.build_circle_rounded, 'text': 'Device Repair Job Sheets & Barcode Tracking'},
          {'icon': Icons.sms_rounded, 'text': 'SMS Status Updates to Customers on Job Done'},
          {'icon': Icons.precision_manufacturing_rounded, 'text': 'Spare Parts Consumption & Cost Auditing'},
          {'icon': Icons.verified_user_rounded, 'text': 'Service Warranty & Defect Return Tracking'},
        ];
      default:
        return [
          {'icon': Icons.speed_rounded, 'text': 'Sub-Millisecond Offline SQLite Transactions'},
          {'icon': Icons.sync_rounded, 'text': 'Hybrid Cloud Sync to MySQL / Laravel Web Portal'},
          {'icon': Icons.menu_book_rounded, 'text': 'Customer & Supplier Double-Entry Ledgers'},
          {'icon': Icons.analytics_rounded, 'text': 'Comprehensive Profit & Loss and Stock Auditing'},
        ];
    }
  }

  Widget _buildSideBanner(bool isDark) {
    final bannerPath = widget.settings.effectiveLoginBanner;
    ImageProvider? imageProvider;

    if (bannerPath.isNotEmpty) {
      if (bannerPath.startsWith('assets/')) {
        imageProvider = AssetImage(bannerPath);
      } else {
        final f = File(bannerPath);
        if (f.existsSync()) {
          imageProvider = FileImage(f);
        }
      }
    }

    return Container(
      width: 460,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        image: imageProvider != null
            ? DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          gradient: LinearGradient(
            colors: imageProvider != null
                ? [
                    const Color(0xF21E1B4B), // 95% opacity deep indigo
                    const Color(0xFA0F172A), // 98% opacity dark slate
                  ]
                : const [
                    Color(0xFF312E81),
                    Color(0xFF1E1B4B),
                    Color(0xFF0F172A),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Branding Badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.settings.businessName.isNotEmpty
                          ? widget.settings.businessName
                          : 'Smart POS System',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Enterprise ERP & Wholesale Suite',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Middle Headline & Features
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _defaultTitle(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _defaultSubtitle(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 26),

                // Feature items with stylish icons
                for (final badge in _featureBadges())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            badge['icon'] as IconData,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            badge['text'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Bottom Engine Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF10B981),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.settings.isHybridSync
                          ? 'Hybrid Engine Active (Local SQLite FFI + MySQL Cloud Sync)'
                          : 'Offline Database Engine Connected (SQLite FFI)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
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

  Widget _buildLoginForm(bool isDark) {
    return Container(
      width: 460,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Logo & System Identification
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workstation Sign In',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Authenticate to open register & billing terminal',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error Message Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Username / Operator ID Input
            Text(
              'Username or Operator ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _userCtrl,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. admin, cashier1, or salesman',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter username' : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 14),

            // Password Input
            Text(
              'Password',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePassword,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Enter account password',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Please enter password' : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 16),

            // Remember Station Checkbox
            Row(
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _rememberMe = v ?? true),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Keep session active on this workstation',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Sign In to Terminal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 18),

            // Footer info
            Center(
              child: Text(
                'Smart POS Enterprise Edition • 256-bit Local AES Encryption',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return Container(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 920 : 460,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSideBanner(isDark),
                            _buildLoginForm(isDark),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSideBanner(isDark),
                          _buildLoginForm(isDark),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
