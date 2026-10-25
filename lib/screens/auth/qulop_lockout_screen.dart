import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/qulop_service.dart';

class QulopLockoutScreen extends StatefulWidget {
  final BusinessSettings settings;
  final ValueChanged<BusinessSettings> onLicenseActivated;

  const QulopLockoutScreen({
    super.key,
    required this.settings,
    required this.onLicenseActivated,
  });

  @override
  State<QulopLockoutScreen> createState() => _QulopLockoutScreenState();
}

class _QulopLockoutScreenState extends State<QulopLockoutScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;
  String _deviceMac = 'Loading...';
  bool _copiedMac = false;

  @override
  void initState() {
    super.initState();
    _loadMacAddress();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadMacAddress() async {
    final mac = await QulopService.getDeviceMacAddress();
    if (mounted) {
      setState(() => _deviceMac = mac);
    }
  }

  Future<void> _activateLicense() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste your Qulop License Key.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final verification = await QulopService.verifyQulopKey(key);

    if (!verification.isValid) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = verification.message;
        });
      }
      return;
    }

    // Key is valid -> Persist to SQLite
    final db = await DatabaseService.initialize();
    final updated = BusinessSettings(
      id: widget.settings.id,
      businessName: widget.settings.businessName,
      branchName: widget.settings.branchName,
      currencySymbol: widget.settings.currencySymbol,
      currencyCode: widget.settings.currencyCode,
      defaultTaxRate: widget.settings.defaultTaxRate,
      phone: widget.settings.phone,
      email: widget.settings.email,
      address: widget.settings.address,
      receiptFooter: widget.settings.receiptFooter,
      purchaseKey: key,
      businessType: widget.settings.businessType,
      drugLicenseNo: widget.settings.drugLicenseNo,
      dlWarrantor: widget.settings.dlWarrantor,
      timeZone: widget.settings.timeZone,
      currencyPlacement: widget.settings.currencyPlacement,
      financialYearStartMonth: widget.settings.financialYearStartMonth,
      stockAccountingMethod: widget.settings.stockAccountingMethod,
      transactionEditDays: widget.settings.transactionEditDays,
      dateFormat: widget.settings.dateFormat,
      timeFormat: widget.settings.timeFormat,
      currencyPrecision: widget.settings.currencyPrecision,
      quantityPrecision: widget.settings.quantityPrecision,
      defaultProfitPercent: widget.settings.defaultProfitPercent,
      startDate: widget.settings.startDate,
      isConfigured: true,
      logoPath: widget.settings.logoPath,
      trialStartDate: widget.settings.trialStartDate,
    );

    await db.updateBusinessSettings(updated);
    QulopService.qulopNotifier.value = verification;

    if (mounted) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Software Activated Successfully! ${verification.tierLabel} (${verification.remainingDays} days)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
      widget.onLicenseActivated(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate premium security screen
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Lock Icon & System Branding
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Front Title: Qulop License Required
                const Text(
                  'Qulop License Required',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Subscription Expired or Software Not Activated',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Hardware Machine ID Box (Client copies this and gives it to vendor)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.memory_rounded, size: 16, color: Color(0xFF38BDF8)),
                              SizedBox(width: 8),
                              Text(
                                'Hardware Machine ID (MAC Address)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _deviceMac));
                              setState(() => _copiedMac = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _copiedMac = false);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _copiedMac ? const Color(0xFF16A34A) : const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _copiedMac ? Icons.check_rounded : Icons.copy_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _copiedMac ? 'Copied!' : 'Copy ID',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _deviceMac,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Send this Machine ID to the software vendor via WhatsApp to receive your signed activation key.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // License Key Input Field
                const Text(
                  'Enter Qulop License Key',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _keyController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Paste key here (e.g. QULOP-YRL-XXXX-ey...)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, color: Color(0xFF94A3B8)),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _keyController.text = data!.text!.trim();
                        }
                      },
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB91C1C)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFF87171)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Activate Button
                ElevatedButton(
                  onPressed: _isVerifying ? null : _activateLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Verify & Activate Software',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 18),

                // Vendor WhatsApp Assistance Help
                Center(
                  child: Text(
                    'Need a key or renewal? Contact software vendor via WhatsApp.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef LicenseLockoutScreen = QulopLockoutScreen;
