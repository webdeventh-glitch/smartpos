import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/localization_service.dart';
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
  late String _hardwareId =
      PosLocalization.tr('Detecting...', settings: widget.settings);
  late String _deviceMac =
      PosLocalization.tr('Loading...', settings: widget.settings);
  bool _copiedHwId = false;
  bool _copiedMac = false;

  @override
  void initState() {
    super.initState();
    _loadMachineIdentifiers();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadMachineIdentifiers() async {
    final hwId = await QulopService.getHardwareId();
    final mac = await QulopService.getDeviceMacAddress();
    if (mounted) {
      setState(() {
        _hardwareId = hwId;
        _deviceMac = mac;
      });
    }
  }

  Future<void> _activateLicense() async {
    final key = QulopService.sanitizeKeyInput(_keyController.text);
    if (key.isEmpty) {
      setState(() => _errorMessage = PosLocalization.tr(
          'Please enter or paste your Software License Key.',
          settings: widget.settings));
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

    // Preserve every business configuration, DB credential, and module lock via copyWith
    final db = await DatabaseService.initialize();
    final updated = widget.settings.copyWith(
      purchaseKey: key,
      hardwareId: _hardwareId.startsWith('HWID-')
          ? _hardwareId
          : widget.settings.hardwareId,
      isConfigured: true,
    );

    QulopService.syncLicenseFeatureGate();
    await db.updateBusinessSettings(updated);
    QulopService.qulopNotifier.value = verification;

    if (mounted) {
      setState(() => _isVerifying = false);
      final durationLabel = verification.isLifetime
          ? PosLocalization.tr('Lifetime', settings: widget.settings)
          : PosLocalization.trParams(
              '{days} days', {'days': '${verification.remainingDays}'},
              settings: widget.settings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  PosLocalization.trParams(
                    'Software Activated Successfully! {tier} ({duration})',
                    {
                      'tier': verification.tierLabel,
                      'duration': durationLabel,
                    },
                    settings: widget.settings,
                  ),
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
      backgroundColor:
          const Color(0xFF0F172A), // Dark slate premium security screen
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
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.35),
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

                // Front Title: Software License Required
                Text(
                  PosLocalization.tr('Software License Required',
                      settings: widget.settings),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  PosLocalization.tr(
                      'Subscription Expired or Software Not Activated',
                      settings: widget.settings),
                  style: const TextStyle(
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
                          Row(
                            children: [
                              const Icon(Icons.fingerprint_rounded,
                                  size: 16, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 8),
                              Text(
                                PosLocalization.tr('Hardware Machine ID (HWID)',
                                    settings: widget.settings),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _hardwareId));
                              setState(() => _copiedHwId = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  setState(() => _copiedHwId = false);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _copiedHwId
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _copiedHwId
                                        ? Icons.check_rounded
                                        : Icons.copy_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _copiedHwId
                                        ? PosLocalization.tr('Copied!',
                                            settings: widget.settings)
                                        : PosLocalization.tr('Copy HWID',
                                            settings: widget.settings),
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
                        _hardwareId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              PosLocalization.trParams(
                                  'Physical MAC: {mac}', {'mac': _deviceMac},
                                  settings: widget.settings),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _deviceMac));
                              setState(() => _copiedMac = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _copiedMac = false);
                              });
                            },
                            child: Text(
                              _copiedMac
                                  ? PosLocalization.tr('MAC Copied!',
                                      settings: widget.settings)
                                  : PosLocalization.tr('Copy MAC',
                                      settings: widget.settings),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _copiedMac
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        PosLocalization.tr(
                            'Send either Machine HWID or Physical MAC to the software vendor via WhatsApp to receive your signed activation key.',
                            settings: widget.settings),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // License Key Input Field
                Text(
                  PosLocalization.tr('Enter Software License Key',
                      settings: widget.settings),
                  style: const TextStyle(
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
                    hintText: PosLocalization.tr(
                        'Paste key here (e.g. QULOP-YRL-XXXX-ey...)',
                        settings: widget.settings),
                    hintStyle:
                        const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                      borderSide: const BorderSide(
                          color: Color(0xFF6366F1), width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded,
                          color: Color(0xFF94A3B8)),
                      tooltip: PosLocalization.tr('Paste from clipboard',
                          settings: widget.settings),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _keyController.text =
                              QulopService.sanitizeKeyInput(data!.text!);
                        }
                      },
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB91C1C)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: Color(0xFFF87171)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              PosLocalization.tr('Verify & Activate Software',
                                  settings: widget.settings),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 18),

                // Vendor WhatsApp Assistance Help
                Center(
                  child: Text(
                    PosLocalization.tr(
                        'Need a key or renewal? Visit webpixels.net  •  Phone / WhatsApp: +92 313 8437438  •  WhatsApp Only: +92 320 1166949',
                        settings: widget.settings),
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
