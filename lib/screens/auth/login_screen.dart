import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/app_logger.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';

class LoginScreen extends StatefulWidget {
  final BusinessSettings settings;
  final VoidCallback onLoginSuccess;
  final VoidCallback? onReconfigureDatabase;

  const LoginScreen({
    super.key,
    required this.settings,
    required this.onLoginSuccess,
    this.onReconfigureDatabase,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isAuthenticating = false;
  String _loginStatusMessage = '';
  double _loginProgress = 0.0;
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
      final result = await AuthService.loginDetailed(
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (result.success) {
        if (!mounted) return;
        setState(() {
          _isAuthenticating = true;
          _loginStatusMessage = PosLocalization.tr(
              'Verifying security credentials...',
              settings: widget.settings);
          _loginProgress = 0.35;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _loginStatusMessage = PosLocalization.tr(
              'Initializing POS Engine & Data Cache...',
              settings: widget.settings);
          _loginProgress = 0.75;
        });

        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() {
          _loginStatusMessage = PosLocalization.tr(
              'Access Granted! Launching Smart POS...',
              settings: widget.settings);
          _loginProgress = 1.0;
        });

        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = result.errorMessage ??
                'Invalid username or password. Please verify credentials.';
            _isLoading = false;
            _isAuthenticating = false;
          });
        }
      }
    } catch (e, st) {
      AppLogger.error('LoginScreen', 'Login error', e, st);
      if (mounted) {
        setState(() {
          _errorMessage = 'System authentication error: $e';
          _isLoading = false;
          _isAuthenticating = false;
        });
      }
    }
  }

  String _defaultTitle() {
    if (widget.settings.loginSideTitle.trim().isNotEmpty) {
      return widget.settings.loginSideTitle.trim();
    }
    return PosLocalization.tr('Enterprise Retail & Wholesale Workstation',
        settings: widget.settings);
  }

  String _defaultSubtitle() {
    if (widget.settings.loginSideSubtitle.trim().isNotEmpty) {
      return widget.settings.loginSideSubtitle.trim();
    }
    return PosLocalization.tr(
        'Secure high-speed point of sale, inventory control, and transaction ledger.',
        settings: widget.settings);
  }

  List<Map<String, dynamic>> _featureBadges() {
    return [
      {
        'icon': Icons.qr_code_scanner_rounded,
        'text': PosLocalization.tr('Fast Counter Billing & Barcode Scanning',
            settings: widget.settings),
      },
      {
        'icon': Icons.point_of_sale_rounded,
        'text': PosLocalization.tr('Multi-Cashier & Register Reconciliation',
            settings: widget.settings),
      },
      {
        'icon': Icons.inventory_2_rounded,
        'text': PosLocalization.tr('Real-Time Inventory & Batch Tracking',
            settings: widget.settings),
      },
    ];
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
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/smartpos_icon.png',
                      fit: BoxFit.contain,
                    ),
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
                      widget.settings.branchName.isNotEmpty
                          ? widget.settings.branchName
                          : 'Main Branch HQ',
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
                          ? PosLocalization.tr(
                              'Hybrid Engine Active (Local SQLite FFI + MySQL Cloud Sync)',
                              settings: widget.settings)
                          : PosLocalization.tr(
                              'Offline Database Engine Connected (SQLite FFI)',
                              settings: widget.settings),
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
                        PosLocalization.tr('Workstation Sign In',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        PosLocalization.tr(
                            'Authenticate to open register & billing terminal',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Session Expired Notice Banner
            ValueListenableBuilder<String?>(
              valueListenable: AuthService.sessionMessageNotifier,
              builder: (context, sessionMsg, _) {
                if (sessionMsg == null || sessionMsg.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_off_outlined,
                            color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sessionMsg,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Error Message Banner
            if (_errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFDC2626), size: 18),
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
              PosLocalization.tr('Username or Operator ID',
                  settings: widget.settings),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _userCtrl,
              enabled: !_isLoading && !_isAuthenticating,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: PosLocalization.tr(
                    'e.g. admin, cashier1, or salesman',
                    settings: widget.settings),
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? PosLocalization.tr('Please enter username',
                      settings: widget.settings)
                  : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 14),

            // Password Input
            Text(
              PosLocalization.tr('Password', settings: widget.settings),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passCtrl,
              enabled: !_isLoading && !_isAuthenticating,
              obscureText: _obscurePassword,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: PosLocalization.tr('Enter account password',
                    settings: widget.settings),
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? PosLocalization.tr('Please enter password',
                      settings: widget.settings)
                  : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 16),

            // Workstation Session Timeout Policy Notice
            if (widget.settings.sessionTimeoutMinutes > 0)
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 15, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PosLocalization.tr(
                          'Workstation auto-locks after inactivity',
                          settings: widget.settings),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Submit Button or Authentication Progress Sequence
            if (_isAuthenticating)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _loginProgress == 1.0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_loginProgress == 1.0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4F46E5))
                          .withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: _loginProgress == 1.0
                              ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF10B981), size: 22)
                              : const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF4F46E5),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _loginStatusMessage,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _loginProgress == 1.0
                                  ? const Color(0xFF059669)
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _loginProgress,
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        color: _loginProgress == 1.0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF4F46E5),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            PosLocalization.tr('Sign In to Terminal',
                                settings: widget.settings),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
              ),
            const SizedBox(height: 12),

            // Setup / Reconfigure Wizard trigger
            Center(
              child: TextButton.icon(
                onPressed: () => _handleReconfigureDatabase(context),
                icon: const Icon(Icons.settings_suggest_rounded,
                    size: 15, color: Color(0xFF64748B)),
                label: Text(
                  PosLocalization.tr('Run Installation & Database Setup Wizard',
                      settings: widget.settings),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer info
            Center(
              child: Text(
                PosLocalization.tr(
                    'Smart POS Enterprise Edition • 256-bit Local AES Encryption',
                    settings: widget.settings),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReconfigureDatabase(BuildContext context) async {
    final db = DatabaseService.instance;
    final existingUsers = await db.getUsers();
    if (!context.mounted) return;

    // Security check: once at least one user exists, require Super Admin authentication
    // before launching the setup wizard to prevent unauthenticated account takeover.
    if (existingUsers.isNotEmpty) {
      final adminUserCtrl = TextEditingController();
      final adminPassCtrl = TextEditingController();
      String? dialogError;
      bool verifying = false;

      final authorized = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF4F46E5), size: 24),
                SizedBox(width: 8),
                Expanded(child: Text('Super Admin Verification Required')),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter an existing Owner / Super Admin account password to re-launch the Setup Wizard.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: adminUserCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Super Admin Username',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: adminPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Super Admin Password',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: verifying ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                onPressed: verifying
                    ? null
                    : () async {
                        final u = adminUserCtrl.text.trim();
                        final p = adminPassCtrl.text.trim();
                        if (u.isEmpty || p.isEmpty) {
                          setDlgState(() => dialogError =
                              'Username and password are required.');
                          return;
                        }
                        setDlgState(() {
                          verifying = true;
                          dialogError = null;
                        });
                        final res = await AuthService.loginDetailed(u, p);
                        if (!res.success || res.user == null) {
                          setDlgState(() {
                            verifying = false;
                            dialogError =
                                res.errorMessage ?? 'Invalid credentials.';
                          });
                          return;
                        }
                        final isSuper = res.user!.isSuperAdmin;
                        await AuthService.logout();
                        if (!isSuper) {
                          setDlgState(() {
                            verifying = false;
                            dialogError =
                                'Only an Owner / Super Admin can reconfigure the database.';
                          });
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                icon: const Icon(Icons.verified_user_rounded, size: 16),
                label: Text(verifying ? 'Verifying...' : 'Authorize & Launch'),
              ),
            ],
          ),
        ),
      );
      adminUserCtrl.dispose();
      adminPassCtrl.dispose();
      if (authorized != true) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 24),
              SizedBox(width: 8),
              Text('Database & Setup Wizard'),
            ],
          ),
          content: const Text(
            'Do you want to re-launch the Guided Setup Wizard to configure your database (MySQL / SQLite), business presets, and admin account?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: const Text('Launch Setup Wizard'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (context.mounted) {
      final current = await db.getBusinessSettings();
      await db.updateBusinessSettings(current.copyWith(isConfigured: false));
      if (widget.onReconfigureDatabase != null) {
        widget.onReconfigureDatabase!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
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
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
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
