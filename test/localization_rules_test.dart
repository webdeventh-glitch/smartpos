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

    test(
        'Rule 4: Setup Wizard & Installation screens are 100% dynamically translatable without baked-in text',
        () {
      // 1. Urdu Primary (pure Urdu without brackets)
      final urduSettings = BusinessSettings(primaryLanguage: 'ur');
      expect(
          PosLocalization.tr('Proceed to Login Screen', settings: urduSettings),
          'لاگ ان اسکرین پر جائیں');
      expect(PosLocalization.tr('1. License Lock', settings: urduSettings),
          '1. لائسنس کی تنصیب');
      expect(
          PosLocalization.tr('Installation & Setup Completed!',
              settings: urduSettings),
          'تنصیب اور سسٹم سیٹ اپ مکمل ہو گیا!');
      expect(PosLocalization.tr('Cheque Management', settings: urduSettings),
          'چیک مینجمنٹ');
      expect(PosLocalization.tr('Turnstile Check-In', settings: urduSettings),
          'ٹرن اسٹائل چیک ان (کارڈ سکین)');
      expect(PosLocalization.tr('Live KDS Screen', settings: urduSettings),
          'لائیو کچن ڈسپلے اسکرین (KDS)');

      // 2. Arabic Primary
      final arSettings = BusinessSettings(primaryLanguage: 'ar');
      expect(
          PosLocalization.tr('Proceed to Login Screen', settings: arSettings),
          'الانتقال إلى شاشة الدخول');
      expect(
          PosLocalization.tr('Installation & Setup Completed!',
              settings: arSettings),
          'اكتمل التثبيت والإعداد بنجاح!');
      expect(
          PosLocalization.tr('Cooking', settings: arSettings), 'قيد التحضير');
      expect(PosLocalization.tr('Ready', settings: arSettings), 'جاهز');
      expect(PosLocalization.tr('Served', settings: arSettings), 'تم التقديم');

      // 3. Spanish Primary
      final esSettings = BusinessSettings(primaryLanguage: 'es');
      expect(
          PosLocalization.tr('Proceed to Login Screen', settings: esSettings),
          'Ir a la pantalla de inicio de sesión');
      expect(PosLocalization.tr('Cooking', settings: esSettings), 'Cocinando');
      expect(PosLocalization.tr('Ready', settings: esSettings), 'Listo');

      // 4. Dutch Primary
      final nlSettings = BusinessSettings(primaryLanguage: 'nl');
      expect(
          PosLocalization.tr('Proceed to Login Screen', settings: nlSettings),
          'Doorgaan naar inlogscherm');
      expect(
          PosLocalization.tr('Installation & Setup Completed!',
              settings: nlSettings),
          'Installatie en configuratie succesvol voltooid!');

      // 5. English Primary with Secondary Disabled (Clean English only)
      final enCleanSettings = BusinessSettings(
        primaryLanguage: 'en',
        enableSecondaryLanguage: false,
      );
      expect(
          PosLocalization.tr('Proceed to Login Screen',
              settings: enCleanSettings),
          'Proceed to Login Screen');
      expect(
          PosLocalization.tr('Installation & Setup Completed!',
              settings: enCleanSettings),
          'Installation & Setup Completed!');

      // 6. English Primary with Urdu Secondary Enabled (Bilingual English (Urdu))
      final enUrSettings = BusinessSettings(
        primaryLanguage: 'en',
        enableSecondaryLanguage: true,
        secondaryLanguage: 'ur',
      );
      expect(
          PosLocalization.tr('Proceed to Login Screen', settings: enUrSettings),
          'Proceed to Login Screen (لاگ ان اسکرین پر جائیں)');
      expect(PosLocalization.tr('Cheque Management', settings: enUrSettings),
          'Cheque Management (چیک مینجمنٹ)');
    });

    test(
        'Rule 5: Shortcuts and symbols are detached from translations across all languages',
        () {
      final enUrSettings = BusinessSettings(
        primaryLanguage: 'en',
        enableSecondaryLanguage: true,
        secondaryLanguage: 'ur',
      );
      final urSettings = BusinessSettings(primaryLanguage: 'ur');
      final faSettings = BusinessSettings(primaryLanguage: 'fa');

      final cashEnUr = PosLocalization.tr('Cash', settings: enUrSettings);
      expect(cashEnUr, 'Cash (نقد وصولی)');
      expect(cashEnUr.contains('[F2]'), isFalse);
      expect(PosLocalization.tr('Cash', settings: urSettings), 'نقد وصولی');
      expect(PosLocalization.tr('Recent Sales', settings: faSettings),
          'فروش‌های اخیر');

      final discLabel = PosLocalization.tr('DISCOUNT', settings: enUrSettings);
      expect(discLabel, 'DISCOUNT (رعایت)');
      expect(discLabel.contains('(-)'), isFalse);

      final taxLabel = PosLocalization.tr('ORDER TAX', settings: enUrSettings);
      expect(taxLabel, 'ORDER TAX (ٹیکس)');
      expect(taxLabel.contains('(+)'), isFalse);

      final addFirstLabel =
          PosLocalization.tr('Add First Product', settings: enUrSettings);
      expect(addFirstLabel, 'Add First Product (پہلی پروڈکٹ شامل کریں)');
      expect(addFirstLabel.contains('+'), isFalse);

      // Clean lookup never leaks shortcut tokens in any language
      expect(
          PosLocalization.tr('Scan barcode / search item / 2*SKU',
                  settings: urSettings)
              .contains('[Esc]'),
          isFalse);
      expect(
          PosLocalization.tr('Select Customer', settings: urSettings)
              .contains('(F3)'),
          isFalse);

      // Even if a legacy shortcut/symbol key is passed directly, bilingual mode strips duplicates
      final legacyCash =
          PosLocalization.tr('Cash [F2]', settings: enUrSettings);
      expect('[F2]'.allMatches(legacyCash).length, 1);
      final legacyEsc = PosLocalization.tr(
          'Scan barcode / search item / 2*SKU [Esc]',
          settings: enUrSettings);
      expect('[Esc]'.allMatches(legacyEsc).length, 1);
    });
  });
}
