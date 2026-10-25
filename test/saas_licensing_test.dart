import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/models.dart';
import 'package:desktop_starter/services/qulop_service.dart';

void main() {
  group('Smart POS Qulop Security & Licensing Engine Tests', () {
    test('1. Fresh installation automatically grants 30-Day Free Trial', () async {
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

    test('3. Qulop Key Generator creates signed keys for all tiers with QULOP prefix', () async {
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

    test('6. WhatsApp template generator creates complete message for customer with Qulop branding', () {
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
  });
}
