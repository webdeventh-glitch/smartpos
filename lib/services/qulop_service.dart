import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'app_logger.dart';

enum QulopTier {
  trial,
  quarterly,
  halfYearly,
  yearly,
  custom,
  lifetime,
  expired,
  invalid,
}

class QulopStatus {
  final bool isValid;
  final QulopTier tier;
  final String tierLabel;
  final String message;
  final String? clientName;
  final String? targetMac;
  final String? businessType;
  final bool allowUpdates;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final int remainingDays;
  final bool isNearExpiry; // true if 7 days or less remaining

  const QulopStatus({
    required this.isValid,
    required this.tier,
    required this.tierLabel,
    required this.message,
    this.clientName,
    this.targetMac,
    this.businessType,
    this.allowUpdates = true,
    this.issueDate,
    this.expiryDate,
    this.remainingDays = 0,
    this.isNearExpiry = false,
  });

  bool get isTrial => tier == QulopTier.trial;
  bool get isLifetime => tier == QulopTier.lifetime;
  QulopTier get type => tier;
}

class QulopService {
  // Master Secret Key for signing & verifying Qulop SaaS tokens
  static const String _qulopSecretKey = 'QULOP_SMART_POS_MASTER_SECRET_2026_PK';
  static const String _sposSecretKey =
      'SMART_POS_SYSTEM_SAAS_MASTER_SECRET_2026_PK';
  static const String _legacySecretKey =
      'NEXUS_ENTERPRISE_POS_2026_MASTER_SECRET_9981';

  /// Reactive Qulop notifier for real-time app lockout & banners
  static final ValueNotifier<QulopStatus?> qulopNotifier =
      ValueNotifier<QulopStatus?>(null);

  /// Backward compatibility notifier
  static ValueNotifier<QulopStatus?> get licenseNotifier => qulopNotifier;

  static String? _cachedHardwareId;
  static String? _cachedMacAddress;

  /// Detects the physical Hardware ID (Motherboard UUID / Disk Serial / MachineGuid / MAC Address)
  static Future<String> getHardwareId() async {
    if (_cachedHardwareId != null) return _cachedHardwareId!;
    try {
      if (Platform.isWindows) {
        bool isDegenerateHex(String hex) {
          return hex.isEmpty ||
              hex.replaceAll('0', '').isEmpty ||
              hex.replaceAll('F', '').isEmpty;
        }

        // 1. Try querying Motherboard UUID via PowerShell (5s timeout for cold CLR boot)
        try {
          final res = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            '(Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID'
          ]).timeout(const Duration(seconds: 5));
          if (res.exitCode == 0 && res.stdout != null) {
            final uuid = res.stdout.toString().trim();
            if (uuid.length >= 10 && !uuid.toLowerCase().contains('error')) {
              final clean =
                  uuid.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
              if (clean.length >= 12 && !isDegenerateHex(clean)) {
                _cachedHardwareId =
                    'HWID-${clean.substring(0, clean.length >= 16 ? 16 : clean.length)}';
                return _cachedHardwareId!;
              }
            }
          }
        } catch (e, st) {
          AppLogger.warning(
              'QulopService', 'WMI motherboard UUID lookup failed', e, st);
        }

        // 2. Fallback to Disk Drive Serial
        try {
          final res = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            '(Get-CimInstance -ClassName Win32_DiskDrive)[0].SerialNumber'
          ]).timeout(const Duration(seconds: 5));
          if (res.exitCode == 0 && res.stdout != null) {
            final diskSerial = res.stdout.toString().trim();
            final clean = diskSerial
                .replaceAll(RegExp(r'[^A-Fa-f0-9]'), '')
                .toUpperCase();
            if (clean.length >= 6 &&
                !isDegenerateHex(clean) &&
                !diskSerial.toLowerCase().contains('error')) {
              _cachedHardwareId =
                  'HWID-${clean.substring(0, clean.length >= 16 ? 16 : clean.length)}';
              return _cachedHardwareId!;
            }
          }
        } catch (e, st) {
          AppLogger.warning(
              'QulopService', 'WMI disk serial lookup failed', e, st);
        }

        // 3. Fast Windows Registry MachineGuid fallback (~10ms, survives NIC switches)
        try {
          final res = await Process.run('reg', [
            'query',
            r'HKLM\SOFTWARE\Microsoft\Cryptography',
            '/v',
            'MachineGuid',
          ]).timeout(const Duration(seconds: 3));
          if (res.exitCode == 0 && res.stdout != null) {
            final match = RegExp(r'MachineGuid\s+REG_SZ\s+([A-Za-z0-9-]+)',
                    caseSensitive: false)
                .firstMatch(res.stdout.toString());
            if (match != null) {
              final clean = match
                  .group(1)!
                  .replaceAll(RegExp(r'[^A-Fa-f0-9]'), '')
                  .toUpperCase();
              if (clean.length >= 12 && !isDegenerateHex(clean)) {
                _cachedHardwareId =
                    'HWID-${clean.substring(0, clean.length >= 16 ? 16 : clean.length)}';
                return _cachedHardwareId!;
              }
            }
          }
        } catch (e, st) {
          AppLogger.warning(
              'QulopService', 'Registry MachineGuid lookup failed', e, st);
        }
      }
    } catch (e, st) {
      AppLogger.warning('QulopService',
          'Hardware ID detection failed, falling back to MAC', e, st);
    }

    // 4. Fallback to physical MAC address
    final mac = await getDeviceMacAddress();
    final clean = normalizeMac(mac);
    _cachedHardwareId = 'HWID-$clean';
    return _cachedHardwareId!;
  }

  /// Detects the physical MAC address of the running host machine
  static Future<String> getDeviceMacAddress() async {
    if (_cachedMacAddress != null) return _cachedMacAddress!;
    try {
      if (Platform.isWindows) {
        final result = await Process.run('getmac', ['/fo', 'csv', '/nh']);
        if (result.exitCode == 0 && result.stdout != null) {
          final lines = result.stdout.toString().split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isEmpty) continue;
            final parts = line.split(',');
            if (parts.isNotEmpty) {
              final rawMac = parts[0].replaceAll('"', '').trim();
              final macPattern =
                  RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
              if (macPattern.hasMatch(rawMac) &&
                  !line.toLowerCase().contains('disconnected')) {
                _cachedMacAddress = rawMac.toUpperCase();
                return _cachedMacAddress!;
              }
            }
          }
          for (var line in lines) {
            final parts = line.split(',');
            if (parts.isNotEmpty) {
              final rawMac = parts[0].replaceAll('"', '').trim();
              final macPattern =
                  RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
              if (macPattern.hasMatch(rawMac)) {
                _cachedMacAddress = rawMac.toUpperCase();
                return _cachedMacAddress!;
              }
            }
          }
        }
      }
    } catch (e, st) {
      AppLogger.warning('QulopService',
          'MAC address detection failed, using fallback identifier', e, st);
    }

    _cachedMacAddress = 'C8-3A-35-1C-4B-40';
    return _cachedMacAddress!;
  }

  /// Normalizes MAC address, Hardware ID (`HWID-...`), or wildcard (`ANY`/`WILDCARD`) string
  static String normalizeMac(String mac) {
    final upper = mac.trim().toUpperCase();
    if (upper == 'ANY' || upper == 'WILDCARD') {
      return upper;
    }
    if (upper.startsWith('HWID')) {
      final suffix = upper.substring(4).replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      return 'HWID$suffix';
    }
    return upper.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
  }

  static String _legacyHexNormalize(String value) {
    return value.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '').toUpperCase();
  }

  /// Removes WhatsApp markdown backticks and accidental whitespace/newlines from pasted keys.
  static String sanitizeKeyInput(String rawKey) {
    return rawKey.replaceAll('`', '').replaceAll(RegExp(r'\s+'), '').trim();
  }

  /// Map 3-letter tier code to human-readable label
  static String getTierLabel(String code) {
    switch (code.toUpperCase()) {
      case 'TRL':
        return '30-Day Free Trial';
      case 'QTR':
        return 'Quarterly (3 Months)';
      case 'HLF':
        return 'Half-Yearly (6 Months)';
      case 'YRL':
        return 'Yearly (12 Months)';
      case 'CST':
        return 'Custom Date Subscription';
      case 'LFT':
        return 'Lifetime Perpetual';
      default:
        return 'Standard Plan';
    }
  }

  /// Vendor Suite: Generates a cryptographically signed Qulop key
  static String generatePurchaseKey({
    required String clientName,
    required String macAddress,
    required String tierCode, // TRL, QTR, HLF, YRL, CST, LFT
    String businessType = '',
    bool allowUpdates = true,
    DateTime? expiryDate,
    DateTime? customExpiryDate,
    int? customDays,
    DateTime? issueDate,
  }) {
    issueDate ??= DateTime.now();
    final cleanMac = normalizeMac(macAddress);

    DateTime finalExpiry;
    if (tierCode.toUpperCase() == 'LFT') {
      finalExpiry = DateTime(9999, 12, 31);
    } else if (customExpiryDate != null) {
      finalExpiry = customExpiryDate;
    } else if (expiryDate != null) {
      finalExpiry = expiryDate;
    } else if (customDays != null) {
      finalExpiry = issueDate.add(Duration(days: customDays));
    } else {
      switch (tierCode.toUpperCase()) {
        case 'TRL':
          finalExpiry = issueDate.add(const Duration(days: 30));
          break;
        case 'QTR':
          finalExpiry = issueDate.add(const Duration(days: 90));
          break;
        case 'HLF':
          finalExpiry = issueDate.add(const Duration(days: 180));
          break;
        case 'YRL':
          finalExpiry = issueDate.add(const Duration(days: 365));
          break;
        default:
          finalExpiry = issueDate.add(const Duration(days: 365));
      }
    }

    final payload = <String, dynamic>{
      'c': clientName.trim(),
      'm': cleanMac,
      't': tierCode.toUpperCase(),
      'i': issueDate.toIso8601String().split('T').first,
      'e': tierCode.toUpperCase() == 'LFT'
          ? '9999-12-31'
          : finalExpiry.toIso8601String().split('T').first,
      if (businessType.trim().isNotEmpty) 'b': businessType.trim(),
      if (!allowUpdates) 'u': 0,
    };

    final payloadJson = jsonEncode(payload);
    final payloadBase64 = base64Url.encode(utf8.encode(payloadJson));

    // Sign payload with HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(_qulopSecretKey));
    final digest = hmac.convert(utf8.encode(payloadBase64));
    final signatureHex = digest.toString().substring(0, 8).toUpperCase();

    return 'QULOP-${tierCode.toUpperCase()}-$signatureHex-$payloadBase64';
  }

  /// Generates a key bound directly to the hardware ID
  static String generateHardwareBoundKey({
    required String clientName,
    required String hardwareId,
    required String tierCode,
    DateTime? expiryDate,
    DateTime? customExpiryDate,
    int? customDays,
    DateTime? issueDate,
  }) {
    return generatePurchaseKey(
      clientName: clientName,
      macAddress: hardwareId,
      tierCode: tierCode,
      expiryDate: expiryDate,
      customExpiryDate: customExpiryDate,
      customDays: customDays,
      issueDate: issueDate,
    );
  }

  /// Validates a Qulop key against the current host machine MAC/HWID and expiration.
  /// Pass [ignoreHardwareCheck] = true when inspecting key metadata on a vendor PC.
  static Future<QulopStatus> verifyQulopKey(
    String rawKey, {
    String? hostMacOverride,
    bool ignoreHardwareCheck = false,
  }) async {
    final key = sanitizeKeyInput(rawKey);
    if (key.isEmpty) {
      return const QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Invalid',
        message: 'License key cannot be empty.',
      );
    }

    // Support QULOP-, SPOS-, and legacy prefixes
    final isQulop = key.startsWith('QULOP-');
    final isLegacySPOS = key.startsWith('SPOS-');
    final isLegacyNEX = key.startsWith('NEXPOS-');

    if (!isQulop && !isLegacySPOS && !isLegacyNEX) {
      return const QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Invalid Key',
        message: 'Invalid key prefix. Valid key must start with QULOP-.',
      );
    }

    final parts = key.split('-');
    if (parts.length < 4) {
      return const QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Corrupted Key',
        message: 'Key structure is malformed or corrupted.',
      );
    }

    final tierCode = parts[1].toUpperCase();
    final signature = parts[2].toUpperCase();
    final payloadBase64 = parts.sublist(3).join('-');

    // Verify cryptographic signature
    final primaryHmac = Hmac(sha256, utf8.encode(_qulopSecretKey));
    final expectedPrimarySig = primaryHmac
        .convert(utf8.encode(payloadBase64))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    final sposHmac = Hmac(sha256, utf8.encode(_sposSecretKey));
    final expectedSposSig = sposHmac
        .convert(utf8.encode(payloadBase64))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    final legacyHmac = Hmac(sha256, utf8.encode(_legacySecretKey));
    final expectedLegacySig = legacyHmac
        .convert(utf8.encode(payloadBase64))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    if (signature != expectedPrimarySig &&
        signature != expectedSposSig &&
        signature != expectedLegacySig) {
      return const QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Forgery Detected',
        message: 'Cryptographic signature is invalid. Key has been altered.',
      );
    }

    // Decode payload
    Map<String, dynamic> data;
    try {
      final jsonStr =
          utf8.decode(base64Url.decode(base64Url.normalize(payloadBase64)));
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, st) {
      AppLogger.warning(
          'QulopService', 'Failed decoding license payload', e, st);
      return const QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Corrupted Payload',
        message: 'Unable to decode security payload.',
      );
    }

    final clientName = data['c'] as String? ?? 'Valued Client';
    final targetMac = (data['m'] as String? ?? '').trim().toUpperCase();
    final expiryStr = data['e'] as String? ?? '';
    final issueStr = data['i'] as String? ?? '';
    final businessType = (data['b'] as String?)?.trim();
    final allowUpdates = data['u'] != 0 && data['u'] != false;

    // Hardware Lock Check
    final isWildcard = targetMac == 'WILDCARD' || targetMac == 'ANY';
    final cleanTarget = normalizeMac(targetMac);

    if (!ignoreHardwareCheck) {
      final currentMac = hostMacOverride != null
          ? normalizeMac(hostMacOverride)
          : normalizeMac(await getDeviceMacAddress());
      final currentHwId =
          hostMacOverride != null ? '' : normalizeMac(await getHardwareId());

      // Accept legacy keys where 'HWID-' had non-hex letters stripped to 'D...'
      final legacyTargetHex = _legacyHexNormalize(targetMac);
      final legacyHwHex =
          currentHwId.isNotEmpty ? _legacyHexNormalize(currentHwId) : '';

      final isMatched = isWildcard ||
          (cleanTarget.isNotEmpty &&
              (cleanTarget == currentMac ||
                  (currentHwId.isNotEmpty &&
                      (cleanTarget == currentHwId ||
                          (legacyTargetHex.isNotEmpty &&
                              legacyTargetHex == legacyHwHex)))));

      if (!isMatched) {
        final machineSummary = currentHwId.isNotEmpty
            ? '$currentHwId / MAC $currentMac'
            : currentMac;
        return QulopStatus(
          isValid: false,
          tier: QulopTier.invalid,
          tierLabel: 'Hardware Mismatch',
          message:
              'This key is locked to machine ($targetMac). Current machine is ($machineSummary).',
          clientName: clientName,
          targetMac: targetMac,
        );
      }
    }

    DateTime? expiryDate;
    if (tierCode == 'LFT') {
      expiryDate = DateTime(9999, 12, 31);
    } else {
      try {
        expiryDate = DateTime.parse(expiryStr);
      } catch (e, st) {
        AppLogger.warning(
            'QulopService', 'Invalid license expiry date "$expiryStr"', e, st);
        expiryDate = null;
      }
      if (expiryDate == null) {
        return QulopStatus(
          isValid: false,
          tier: QulopTier.invalid,
          tierLabel: 'Corrupted Key',
          message: 'License expiration date "$expiryStr" is invalid.',
          clientName: clientName,
          targetMac: targetMac,
        );
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Anti-Clock Rollback: Check if system clock was moved before license issue date
    final issueDate = DateTime.tryParse(issueStr);
    if (issueDate != null &&
        detectClockRollback(now, lastKnownActiveDate: issueDate)) {
      return QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Clock Rollback Detected',
        message:
            'System clock has been set backward earlier than license issue date (${issueDate.toIso8601String().split('T').first}). Please correct your system clock.',
        clientName: clientName,
        targetMac: targetMac,
        issueDate: issueDate,
      );
    }

    if (expiryDate.isBefore(today)) {
      return QulopStatus(
        isValid: false,
        tier: QulopTier.expired,
        tierLabel: '${getTierLabel(tierCode)} (Expired)',
        message:
            'Your software subscription expired on ${expiryDate.toIso8601String().split('T').first}. Please renew.',
        clientName: clientName,
        targetMac: targetMac,
        expiryDate: expiryDate,
        remainingDays: 0,
      );
    }

    final remaining = expiryDate.difference(today).inDays;
    final isNearExpiry = remaining <= 7 && tierCode != 'LFT';

    QulopTier qulopTier;
    switch (tierCode) {
      case 'TRL':
        qulopTier = QulopTier.trial;
        break;
      case 'QTR':
        qulopTier = QulopTier.quarterly;
        break;
      case 'HLF':
        qulopTier = QulopTier.halfYearly;
        break;
      case 'YRL':
        qulopTier = QulopTier.yearly;
        break;
      case 'CST':
        qulopTier = QulopTier.custom;
        break;
      case 'LFT':
        qulopTier = QulopTier.lifetime;
        break;
      default:
        qulopTier = QulopTier.yearly;
    }

    return QulopStatus(
      isValid: true,
      tier: qulopTier,
      tierLabel: getTierLabel(tierCode),
      message: 'Active & Verified',
      clientName: clientName,
      targetMac: targetMac,
      businessType: businessType,
      allowUpdates: allowUpdates,
      issueDate: DateTime.tryParse(issueStr),
      expiryDate: expiryDate,
      remainingDays: remaining,
      isNearExpiry: isNearExpiry,
    );
  }

  /// Evaluates current business settings against Qulop rules
  static Future<QulopStatus> checkCurrentQulop(
      BusinessSettings settings) async {
    final currentMac = await getDeviceMacAddress();

    // 1. Check if user already installed a paid/custom Qulop key
    if (settings.purchaseKey.trim().isNotEmpty) {
      final verification = await verifyQulopKey(settings.purchaseKey);
      qulopNotifier.value = verification;
      return verification;
    }

    // 2. Default: Evaluate 30-Day Free Trial
    DateTime trialStart;
    if (settings.trialStartDate.trim().isNotEmpty) {
      try {
        trialStart = DateTime.parse(settings.trialStartDate);
      } catch (e, st) {
        AppLogger.warning(
            'QulopService',
            'Invalid trialStartDate "${settings.trialStartDate}", using now',
            e,
            st);
        trialStart = DateTime.now();
      }
    } else {
      trialStart = DateTime.now();
    }

    // Anti-Clock Rollback: Check if system clock was rolled back before trial start date
    if (settings.trialStartDate.trim().isNotEmpty &&
        detectClockRollback(DateTime.now(), lastKnownActiveDate: trialStart)) {
      final status = QulopStatus(
        isValid: false,
        tier: QulopTier.invalid,
        tierLabel: 'Clock Rollback Detected',
        message:
            'System clock has been set backward earlier than initial trial installation. Please correct your system clock to continue.',
        clientName: settings.businessName,
        targetMac: currentMac,
        issueDate: trialStart,
      );
      qulopNotifier.value = status;
      return status;
    }

    final trialExpiry = trialStart.add(const Duration(days: 30));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay =
        DateTime(trialExpiry.year, trialExpiry.month, trialExpiry.day);

    final remaining = expiryDay.difference(today).inDays;

    if (remaining <= 0) {
      final status = QulopStatus(
        isValid: false,
        tier: QulopTier.expired,
        tierLabel: '30-Day Free Trial (Expired)',
        message:
            'Your 30-Day Free Trial expired on ${expiryDay.toIso8601String().split('T').first}. Please enter your Software License Key.',
        clientName: settings.businessName,
        targetMac: currentMac,
        issueDate: trialStart,
        expiryDate: trialExpiry,
        remainingDays: 0,
      );
      qulopNotifier.value = status;
      return status;
    }

    final status = QulopStatus(
      isValid: true,
      tier: QulopTier.trial,
      tierLabel: '30-Day Free Trial',
      message: '$remaining trial days remaining',
      clientName: settings.businessName,
      targetMac: currentMac,
      issueDate: trialStart,
      expiryDate: trialExpiry,
      remainingDays: remaining,
      isNearExpiry: remaining <= 7,
    );
    qulopNotifier.value = status;
    return status;
  }

  /// Static aliases for backward compatibility
  static Future<QulopStatus> verifyLicenseKey(String key,
          {String? hostMacOverride}) =>
      verifyQulopKey(key, hostMacOverride: hostMacOverride);

  static Future<QulopStatus> checkCurrentLicense(BusinessSettings settings) =>
      checkCurrentQulop(settings);

  /// Anti-Clock Tampering Check (Detects system clock rollback)
  static bool detectClockRollback(DateTime currentNow,
      {DateTime? lastKnownActiveDate}) {
    if (lastKnownActiveDate == null) return false;
    // Allow a grace window of 12 hours for time zone shifts, but flag backward jumps beyond that
    return currentNow
        .isBefore(lastKnownActiveDate.subtract(const Duration(hours: 12)));
  }

  /// Generates a ready-to-send WhatsApp / SMS message template for the customer
  static String generateWhatsAppTemplate({
    required String clientName,
    required String macAddress,
    required String tierLabel,
    required String key,
    required String expiryDateStr,
    String vendorContact = '+92 300 1234567',
  }) {
    return '''
*SMART POS OFFICIAL SOFTWARE LICENSE*
Dear *$clientName*,
Thank you for choosing *Smart POS System*! Your software license subscription has been generated.

*Subscription Details:*
• *Plan:* $tierLabel
• *Machine Hardware ID:* $macAddress
• *Valid Until:* $expiryDateStr

*Your Software Activation Key:*
`$key`

*How to Activate:*
1. Open *Smart POS System* on your PC.
2. Go to *Settings > License & Activation* (or paste into the activation screen).
3. Paste the key above and click *"Activate License"*.

For technical support or renewals, WhatsApp us: $vendorContact
''';
  }
}

/// Backward compatibility aliases for existing tests & references
typedef LicenseService = QulopService;
typedef LicenseStatus = QulopStatus;
typedef LicenseType = QulopTier;
