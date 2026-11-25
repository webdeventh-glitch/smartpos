import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/qulop_service.dart';

void main() {
  group('Smart POS Qulop Security & Licensing Engine Tests', () {
    test('1. Fresh installation automatically grants 30-Day Free Trial',
        () async {
      final now = DateTime.now();
      final settings = BusinessSettings(
        purchaseKey: '',
        trialStartDate: now.toIso8601String(),
      );

      final status = await QulopService.checkCurrentQulop(settings);

      expect(status.isValid, isTrue);
      expect(status.tier, QulopTier.trial);
      expect(status.remainingDays, inInclusiveRange(29, 30));
    });

    test('2. Expired 30-Day Free Trial triggers Hard Lockout', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 31));
      final settings = BusinessSettings(
        purchaseKey: '',
        trialStartDate: pastDate.toIso8601String(),
      );

      final status = await QulopService.checkCurrentQulop(settings);

      expect(status.isValid, isFalse);
      expect(status.tier, QulopTier.expired);
      expect(status.remainingDays, equals(0));
      expect(status.message, contains('30-Day Free Trial expired'));
    });

    test(
        '3. Qulop Key Generator creates signed keys for all tiers with QULOP prefix',
        () async {
      final hostMac = await QulopService.getDeviceMacAddress();

      // Yearly Key (365 days)
      final yearlyKey = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Al-Shifa Pharmacy',
        tierCode: 'YRL',
      );
      expect(yearlyKey, startsWith('QULOP-YRL-'));

      // Quarterly Key (90 days)
      final quarterlyKey = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'City Care Medicos',
        tierCode: 'QTR',
      );
      expect(quarterlyKey, startsWith('QULOP-QTR-'));

      // Custom 45-day Key
      final customKey = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Apex Health Store',
        tierCode: 'CST',
        customDays: 45,
      );
      expect(customKey, startsWith('QULOP-CST-'));

      // Lifetime Key
      final lifetimeKey = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Khyber Medicos',
        tierCode: 'LFT',
      );
      expect(lifetimeKey, startsWith('QULOP-LFT-'));

      // Verification of generated keys
      final verifyYearly = await QulopService.verifyQulopKey(yearlyKey);
      expect(verifyYearly.isValid, isTrue);
      expect(verifyYearly.tier, QulopTier.yearly);
      expect(verifyYearly.remainingDays, inInclusiveRange(364, 365));

      final verifyQuarterly = await QulopService.verifyQulopKey(quarterlyKey);
      expect(verifyQuarterly.isValid, isTrue);
      expect(verifyQuarterly.tier, QulopTier.quarterly);
      expect(verifyQuarterly.remainingDays, inInclusiveRange(89, 90));

      final verifyCustom = await QulopService.verifyQulopKey(customKey);
      expect(verifyCustom.isValid, isTrue);
      expect(verifyCustom.remainingDays, inInclusiveRange(44, 45));

      final verifyLifetime = await QulopService.verifyQulopKey(lifetimeKey);
      expect(verifyLifetime.isValid, isTrue);
      expect(verifyLifetime.tier, QulopTier.lifetime);
    });

    test('4. Qulop Key bound to another machine is rejected', () async {
      const foreignMac = 'AA-BB-CC-DD-EE-FF';
      final foreignKey = QulopService.generatePurchaseKey(
        macAddress: foreignMac,
        clientName: 'Other Store',
        tierCode: 'YRL',
      );

      final status = await QulopService.verifyQulopKey(foreignKey);

      expect(status.isValid, isFalse);
      expect(status.tier, QulopTier.invalid);
      expect(status.message, contains('locked to machine'));
    });

    test('5. Expired paid key triggers expiration lockout', () async {
      final hostMac = await QulopService.getDeviceMacAddress();
      final expiredDate = DateTime.now().subtract(const Duration(days: 2));

      final expiredKey = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Expired Store',
        tierCode: 'CST',
        customExpiryDate: expiredDate,
      );

      final status = await QulopService.verifyQulopKey(expiredKey);

      expect(status.isValid, isFalse);
      expect(status.tier, QulopTier.expired);
      expect(status.remainingDays, equals(0));
      expect(status.message, contains('expired'));
    });

    test(
        '6. WhatsApp template generator creates complete message for customer with Qulop branding',
        () {
      final template = QulopService.generateWhatsAppTemplate(
        clientName: 'Al-Madina Pharmacy',
        macAddress: 'C8-3A-35-1C-4B-40',
        tierLabel: 'Yearly Plan (365 Days)',
        key: 'QULOP-YRL-ABCD-1234',
        expiryDateStr: '21/10/2027',
      );

      expect(template, contains('Al-Madina Pharmacy'));
      expect(template, contains('C8-3A-35-1C-4B-40'));
      expect(template, contains('Yearly Plan (365 Days)'));
      expect(template, contains('QULOP-YRL-ABCD-1234'));
      expect(template, contains('21/10/2027'));
    });

    test('7. Clock rollback prior to license issue date triggers tamper alert',
        () async {
      final hostMac = await QulopService.getDeviceMacAddress();
      // License issued on a future date (e.g. tomorrow or client rolled back clock)
      final futureIssue = DateTime.now().add(const Duration(days: 2));

      final keyWithFutureIssue = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Tampering Store',
        tierCode: 'YRL',
        issueDate: futureIssue,
      );

      final status = await QulopService.verifyQulopKey(keyWithFutureIssue);
      expect(status.isValid, isFalse);
      expect(status.tier, equals(QulopTier.invalid));
      expect(status.tierLabel, contains('Clock Rollback Detected'));
      expect(status.message, contains('earlier than license issue date'));
    });

    test(
        '8. Clock rollback prior to initial trial installation triggers tamper alert',
        () async {
      // Trial was started on a future date (simulating user moving clock back)
      final futureTrialStart = DateTime.now().add(const Duration(days: 5));
      final settings = BusinessSettings(
        purchaseKey: '',
        trialStartDate: futureTrialStart.toIso8601String(),
      );

      final status = await QulopService.checkCurrentQulop(settings);
      expect(status.isValid, isFalse);
      expect(status.tier, equals(QulopTier.invalid));
      expect(status.tierLabel, contains('Clock Rollback Detected'));
      expect(
          status.message, contains('earlier than initial trial installation'));
    });

    test(
        '9. Universal ANY and WILDCARD keys validate across arbitrary machines',
        () async {
      final anyKey = QulopService.generatePurchaseKey(
        macAddress: 'ANY',
        clientName: 'Multi-Branch Enterprise',
        tierCode: 'YRL',
      );
      final wildcardKey = QulopService.generatePurchaseKey(
        macAddress: 'WILDCARD',
        clientName: 'Demo Enterprise',
        tierCode: 'LFT',
      );

      final vAny = await QulopService.verifyQulopKey(anyKey,
          hostMacOverride: '11-22-33-44-55-66');
      final vWild = await QulopService.verifyQulopKey(wildcardKey,
          hostMacOverride: 'AA-BB-CC-DD-EE-FF');

      expect(vAny.isValid, isTrue);
      expect(vAny.targetMac, equals('ANY'));
      expect(vWild.isValid, isTrue);
      expect(vWild.targetMac, equals('WILDCARD'));
      expect(vWild.isLifetime, isTrue);
    });

    test(
        '10. Hardware ID normalization preserves HWID prefix and respects hostMacOverride',
        () async {
      final hwid = await QulopService.getHardwareId();
      expect(QulopService.normalizeMac(hwid), startsWith('HWID'));

      final hwKey = QulopService.generateHardwareBoundKey(
        clientName: 'HWID Store',
        hardwareId: hwid,
        tierCode: 'YRL',
      );

      final vLocal = await QulopService.verifyQulopKey(hwKey);
      expect(vLocal.isValid, isTrue);
      expect(vLocal.targetMac, startsWith('HWID'));

      final vForeign = await QulopService.verifyQulopKey(hwKey,
          hostMacOverride: '12-34-56-78-9A-BC');
      expect(vForeign.isValid, isFalse);
      expect(vForeign.tier, QulopTier.invalid);
    });

    test(
        '11. WhatsApp backtick/whitespace copy artifacts sanitize cleanly and corrupted expiry is rejected',
        () async {
      final hostMac = await QulopService.getDeviceMacAddress();
      final key = QulopService.generatePurchaseKey(
        macAddress: hostMac,
        clientName: 'Sanitized Store',
        tierCode: 'QTR',
      );

      final messy = '  `$key\n`  ';
      final verified = await QulopService.verifyQulopKey(messy);
      expect(verified.isValid, isTrue);
      expect(verified.tier, QulopTier.quarterly);

      // Signed non-LFT payload with invalid expiry date must NOT fall back to 9999 days
      final badPayload = base64Url.encode(utf8.encode(jsonEncode({
        'c': 'Bad Expiry Store',
        'm': 'ANY',
        't': 'YRL',
        'i': DateTime.now().toIso8601String().split('T').first,
        'e': 'NOT-A-DATE',
      })));
      final hmac =
          Hmac(sha256, utf8.encode('QULOP_SMART_POS_MASTER_SECRET_2026_PK'));
      final sig = hmac
          .convert(utf8.encode(badPayload))
          .toString()
          .substring(0, 8)
          .toUpperCase();
      final forgedExpiryKey = 'QULOP-YRL-$sig-$badPayload';

      final badRes = await QulopService.verifyQulopKey(forgedExpiryKey);
      expect(badRes.isValid, isFalse);
      expect(badRes.tier, QulopTier.invalid);
    });

    test(
        '12. Vendor ignoreHardwareCheck inspects foreign-bound keys while rejecting tampered keys',
        () async {
      final foreignKey = QulopService.generatePurchaseKey(
        macAddress: 'DE-AD-BE-EF-12-34',
        clientName: 'Foreign Pharmacy',
        tierCode: 'HLF',
      );

      final inspected = await QulopService.verifyQulopKey(
        foreignKey,
        ignoreHardwareCheck: true,
      );
      expect(inspected.isValid, isTrue);
      expect(inspected.clientName, equals('Foreign Pharmacy'));
      expect(inspected.targetMac, equals('DEADBEEF1234'));

      final tampered = '${foreignKey.substring(0, foreignKey.length - 2)}XX';
      final tamperedRes = await QulopService.verifyQulopKey(
        tampered,
        ignoreHardwareCheck: true,
      );
      expect(tamperedRes.isValid, isFalse);
      expect(tamperedRes.tierLabel, contains('Forgery'));
    });
  });
}
