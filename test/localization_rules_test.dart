import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_starter/models/business_settings.dart';
import 'package:desktop_starter/services/localization_service.dart';

void main() {
  group('Strict Multi-Language Hierarchy & Translatability Rules', () {
    test(
        'Rule 1: When Primary Language is NOT English, secondary is strictly forbidden & ignored',
        () {
      final urduSettings = BusinessSettings(
        primaryLanguage: 'ur',
        enableSecondaryLanguage: true, // even if erroneously true
        secondaryLanguage: 'fa',
      );

      // Verify BusinessSettings getters
      expect(urduSettings.isSecondaryLanguageAllowed, false);
      expect(urduSettings.hasEffectiveSecondaryLanguage, false);
      expect(urduSettings.effectiveSecondaryLanguage, null);

      // Verify PosLocalization.tr produces 100% pure Urdu without English or secondary brackets
      expect(PosLocalization.tr('Customer', settings: urduSettings), 'گاہک');
      expect(PosLocalization.tr('POS Terminal', settings: urduSettings),
          'پوائنٹ آف سیل (POS)');
      expect(
          PosLocalization.tr('Sales', settings: urduSettings), 'سیلز و بلنگ');
      expect(PosLocalization.tr('TOTAL PAYABLE', settings: urduSettings),
          'کل واجب الادا');
      expect(PosLocalization.tr('Due', settings: urduSettings), 'واجب الادا');
      expect(PosLocalization.tr('Cleared', settings: urduSettings), 'بے باق');
    });

    test('Rule 1.1: Farsi primary produces 100% pure Farsi', () {
      final farsiSettings = BusinessSettings(
        primaryLanguage: 'fa',
        enableSecondaryLanguage: true,
        secondaryLanguage: 'ur',
      );

      expect(farsiSettings.isSecondaryLanguageAllowed, false);
      expect(farsiSettings.hasEffectiveSecondaryLanguage, false);

      expect(PosLocalization.tr('Customer', settings: farsiSettings), 'مشتری');
      expect(PosLocalization.tr('Due', settings: farsiSettings), 'بدهکار');
      expect(PosLocalization.tr('Cleared', settings: farsiSettings), 'تسویه');
      expect(PosLocalization.tr('POS Terminal', settings: farsiSettings),
          'ترمینال فروش (صندوق)');
    });

    test('Rule 1.2: Arabic primary produces 100% pure Arabic', () {
      final arabicSettings = BusinessSettings(
        primaryLanguage: 'ar',
      );

      expect(arabicSettings.isSecondaryLanguageAllowed, false);
      expect(arabicSettings.hasEffectiveSecondaryLanguage, false);

      expect(
          PosLocalization.tr('Customer', settings: arabicSettings), 'العميل');
      expect(PosLocalization.tr('Due', settings: arabicSettings), 'مستحق');
      expect(PosLocalization.tr('Cleared', settings: arabicSettings), 'خالص');
    });

    test('Rule 1.3: Pashto primary produces 100% pure Pashto', () {
      final pashtoSettings = BusinessSettings(
        primaryLanguage: 'ps',
      );

      expect(pashtoSettings.isSecondaryLanguageAllowed, false);
      expect(pashtoSettings.hasEffectiveSecondaryLanguage, false);

      expect(PosLocalization.tr('Customer', settings: pashtoSettings),
          'پیرودونکی');
      expect(PosLocalization.tr('Due', settings: pashtoSettings), 'پاتې');
      expect(PosLocalization.tr('Cleared', settings: pashtoSettings), 'پاک');
    });

    test('Rule 2: English is strictly EXCLUDED from Secondary Language options',
        () {
      final secOptions = PosLocalization.secondaryLanguageOptions;
      expect(secOptions.any((lang) => lang.code == 'en'), false,
          reason: 'English must NEVER be a secondary language option');
      expect(secOptions.any((lang) => lang.code == 'ur'), true);
      expect(secOptions.any((lang) => lang.code == 'fa'), true);
      expect(secOptions.any((lang) => lang.code == 'ar'), true);
      expect(secOptions.any((lang) => lang.code == 'ps'), true);
    });

    test(
        'Rule 3: When Primary Language is English, secondary is optional and functional',
        () {
      final enCleanSettings = BusinessSettings(
        primaryLanguage: 'en',
        enableSecondaryLanguage: false,
      );

      expect(enCleanSettings.isSecondaryLanguageAllowed, true);
      expect(enCleanSettings.hasEffectiveSecondaryLanguage, false);
      expect(PosLocalization.tr('Customer', settings: enCleanSettings),
          'Customer');
      expect(PosLocalization.tr('Due', settings: enCleanSettings), 'Due');

      final enBilingualSettings = BusinessSettings(
        primaryLanguage: 'en',
        enableSecondaryLanguage: true,
        secondaryLanguage: 'ur',
      );

      expect(enBilingualSettings.isSecondaryLanguageAllowed, true);
      expect(enBilingualSettings.hasEffectiveSecondaryLanguage, true);
      expect(enBilingualSettings.effectiveSecondaryLanguage, 'ur');
      expect(PosLocalization.tr('Customer', settings: enBilingualSettings),
          'Customer (گاہک)');
      expect(PosLocalization.tr('Due', settings: enBilingualSettings),
          'Due (واجب الادا)');
      expect(PosLocalization.tr('Cleared', settings: enBilingualSettings),
          'Cleared (بے باق)');
    });

    test('RTL detection operates correctly', () {
      expect(PosLocalization.isRtl('ur'), true);
      expect(PosLocalization.isRtl('fa'), true);
      expect(PosLocalization.isRtl('ar'), true);
      expect(PosLocalization.isRtl('ps'), true);
      expect(PosLocalization.isRtl('en'), false);
      expect(PosLocalization.isRtl('es'), false);
      expect(PosLocalization.isRtl('nl'), false);
    });
  });
}
