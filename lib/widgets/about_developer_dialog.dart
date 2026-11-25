import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/business_settings.dart';
import '../services/localization_service.dart';
import '../services/qulop_service.dart';
import 'system_logs_dialog.dart';

/// Professional "About Developer & Software Support" modal dialog.
/// Displays official company details for Webdeventh Software Solutions,
/// website, mobile, email, WhatsApp direct launch, and diagnostic info.
class AboutDeveloperDialog extends StatefulWidget {
  final BusinessSettings? settings;

  const AboutDeveloperDialog({super.key, this.settings});

  static Future<void> show(BuildContext context, {BusinessSettings? settings}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AboutDeveloperDialog(settings: settings),
    );
  }

  @override
  State<AboutDeveloperDialog> createState() => _AboutDeveloperDialogState();
}

class _AboutDeveloperDialogState extends State<AboutDeveloperDialog> {
  String _machineId = 'Loading...';
  final String _licenseTier = 'Enterprise Lifetime';
  bool _copied = false;

  static const String companyName = 'Webdeventh Software Solutions';
  static const String developerName = 'Engr. Muhammad Rafiq (Webdeventh)';
  static const String websiteUrl = 'https://webpixels.net';
  static const String phoneDisplay = '+92 313 8437438';
  static const String whatsappOnlyDisplay = '+92 320 1166949';
  static const String whatsappOnlyRaw = '923201166949';
  static const String emailAddress = 'webdeventh@gmail.com';
  static const String appVersion =
      'v1.1.1 (Release 2026.11.23 - Enterprise Stable)';

  @override
  void initState() {
    super.initState();
    _loadHardwareInfo();
  }

  Future<void> _loadHardwareInfo() async {
    try {
      final hwId = await QulopService.getHardwareId();
      if (mounted) {
        setState(() {
          _machineId = hwId;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _machineId = 'DESKTOP-WIN-ACTIVE';
        });
      }
    }
  }

  void _openUrl(String url) {
    try {
      if (Platform.isWindows) {
        Process.run('cmd.exe', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        Process.run('open', [url]);
      } else {
        Process.run('xdg-open', [url]);
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: url));
      _showToast(PosLocalization.trParams(
          'Link copied to clipboard: {url}', {'url': url},
          settings: widget.settings));
    }
  }

  void _openWhatsApp() {
    final businessName = widget.settings?.businessName ?? 'Our Business';
    final msg = Uri.encodeComponent(
      'Hello Smart POS Support! I am contacting you regarding Smart POS Enterprise for "$businessName" (Machine ID: $_machineId).',
    );
    final waUrl = 'https://wa.me/$whatsappOnlyRaw?text=$msg';
    _openUrl(waUrl);
  }

  void _openEmail() {
    final businessName = widget.settings?.businessName ?? 'SmartPOS Client';
    final mailto =
        'mailto:$emailAddress?subject=Smart%20POS%20Support%20Inquiry%20-%20$businessName';
    _openUrl(mailto);
  }

  void _copyDiagnostics() {
    final diag = StringBuffer();
    diag.writeln('=== SMART POS ENTERPRISE DIAGNOSTIC INFO ===');
    diag.writeln('Software: Smart POS Enterprise $appVersion');
    diag.writeln('Provider: $companyName');
    diag.writeln('Machine Hardware ID: $_machineId');
    diag.writeln('License: $_licenseTier');
    diag.writeln(
        'Business: ${widget.settings?.businessName ?? "Smart POS Setup"}');
    diag.writeln('Branch: ${widget.settings?.branchName ?? "Main Branch"}');
    diag.writeln(
        'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    diag.writeln('============================================');

    Clipboard.setData(ClipboardData(text: diag.toString()));
    setState(() => _copied = true);
    _showToast(PosLocalization.tr(
        'Diagnostic details copied! You can paste them in WhatsApp.',
        settings: widget.settings));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4F46E5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          width: 640,
          constraints: const BoxConstraints(maxHeight: 740),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF4F46E5),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PosLocalization.tr(
                                'About Smart POS & Developer Support',
                                settings: widget.settings),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PosLocalization.tr(
                                'Enterprise Multi-Industry Point of Sale & ERP Systems',
                                settings: widget.settings),
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: PosLocalization.tr('Close',
                          settings: widget.settings),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Banner Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    PosLocalization.tr('OFFICIAL VENDOR',
                                        settings: widget.settings),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  appVersion,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              companyName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PosLocalization.trParams(
                                'Lead Engineer: {name}',
                                {'name': developerName},
                                settings: widget.settings,
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Direct Contact & Connect Channels
                      Text(
                        PosLocalization.tr('Direct Contact & Customer Support',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Contact Grid Tiles
                      Row(
                        children: [
                          // WhatsApp Direct Button
                          Expanded(
                            child: _contactTile(
                              icon: Icons.chat_rounded,
                              iconColor: const Color(0xFF25D366),
                              bgColor: const Color(0xFF25D366)
                                  .withValues(alpha: 0.1),
                              title: PosLocalization.tr('WhatsApp Only',
                                  settings: widget.settings),
                              subtitle: whatsappOnlyDisplay,
                              actionLabel: PosLocalization.tr('Chat Now',
                                  settings: widget.settings),
                              onTap: _openWhatsApp,
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Website Link
                          Expanded(
                            child: _contactTile(
                              icon: Icons.language_rounded,
                              iconColor: const Color(0xFF0284C7),
                              bgColor: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.1),
                              title: PosLocalization.tr('Official Website',
                                  settings: widget.settings),
                              subtitle: websiteUrl.replaceAll('https://', ''),
                              actionLabel: PosLocalization.tr('Visit Site',
                                  settings: widget.settings),
                              onTap: () => _openUrl(websiteUrl),
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          // Mobile Call / WhatsApp
                          Expanded(
                            child: _contactTile(
                              icon: Icons.phone_in_talk_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              bgColor: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.1),
                              title: PosLocalization.tr('Phone / WhatsApp',
                                  settings: widget.settings),
                              subtitle: phoneDisplay,
                              actionLabel: PosLocalization.tr('Copy Phone',
                                  settings: widget.settings),
                              onTap: () {
                                Clipboard.setData(
                                    const ClipboardData(text: phoneDisplay));
                                _showToast(PosLocalization.trParams(
                                    'Phone number copied: {phone}',
                                    {'phone': phoneDisplay},
                                    settings: widget.settings));
                              },
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Email
                          Expanded(
                            child: _contactTile(
                              icon: Icons.alternate_email_rounded,
                              iconColor: const Color(0xFFD97706),
                              bgColor: const Color(0xFFD97706)
                                  .withValues(alpha: 0.1),
                              title: PosLocalization.tr('Official Email',
                                  settings: widget.settings),
                              subtitle: emailAddress,
                              actionLabel: PosLocalization.tr('Send Email',
                                  settings: widget.settings),
                              onTap: _openEmail,
                              isDark: isDark,
                              borderColor: borderColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Machine & License Diagnostic Info Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
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
                                        size: 16, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    Text(
                                      PosLocalization.tr(
                                          'Client Machine Hardware ID:',
                                          settings: widget.settings),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    PosLocalization.tr('ACTIVE LICENSE',
                                        settings: widget.settings),
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _machineId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.bug_report_rounded,
                                    size: 15,
                                    color: Color(0xFFEF4444),
                                  ),
                                  label: Text(
                                    PosLocalization.tr('View Error Logs',
                                        settings: widget.settings),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  onPressed: () =>
                                      SystemLogsDialog.show(context),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: Icon(
                                    _copied
                                        ? Icons.check
                                        : Icons.copy_all_rounded,
                                    size: 15,
                                    color: _copied
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF4F46E5),
                                  ),
                                  label: Text(
                                    _copied
                                        ? PosLocalization.tr(
                                            'Copied Diagnostic Info',
                                            settings: widget.settings)
                                        : PosLocalization.tr(
                                            'Copy Diagnostic Info for Support',
                                            settings: widget.settings),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _copied
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF4F46E5),
                                    ),
                                  ),
                                  onPressed: _copyDiagnostics,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Supported Industries Banner
                      Text(
                        PosLocalization.tr(
                            'Specialized Pakistan Industry Engines',
                            settings: widget.settings),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _industryBadge(
                              '☀️ ${PosLocalization.tr('Solar & Inverter Agencies', settings: widget.settings)}'),
                          _industryBadge(
                              '💊 ${PosLocalization.tr('Medicine & Pharmacy Distribution', settings: widget.settings)}'),
                          _industryBadge(
                              '🛒 ${PosLocalization.tr('Supermarkets & FMCG Groceries', settings: widget.settings)}'),
                          _industryBadge(
                              '🍽️ ${PosLocalization.tr('Restaurant KDS & Dining Tables', settings: widget.settings)}'),
                          _industryBadge(
                              '📱 ${PosLocalization.tr('Mobile & Laptop Repairs', settings: widget.settings)}'),
                          _industryBadge(
                              '🏗️ ${PosLocalization.tr('Manufacturing BOM & Production', settings: widget.settings)}'),
                          _industryBadge(
                              '🇵🇰 ${PosLocalization.tr('FBR & ZATCA Fiscal E-Invoicing', settings: widget.settings)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      PosLocalization.tr(
                          '© 2026 Webdeventh. All Rights Reserved.',
                          settings: widget.settings),
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(PosLocalization.tr('Close',
                          settings: widget.settings)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _industryBadge(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }
}
